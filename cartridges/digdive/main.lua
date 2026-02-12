-- main.lua  DigDive - Dig Dug inspired Atari-style cartridge
local Cart = {}

local api
local SW, SH          -- screen dimensions
local level           -- loaded level data

-- Constants
local TILE  = 16      -- pixels per world tile (8x8 sprite at scale 2)
local EMPTY = 0
local DIRT  = 1
local ROCK  = 2
local GEM   = 3

-- Game states
local STATE_MENU     = "MENU"
local STATE_PLAYING  = "PLAYING"
local STATE_GAMEOVER = "GAME_OVER"
local STATE_WIN      = "WIN"
local gameState

-- World
local world           -- 2D grid: world[y][x]  (0-indexed)
local cols, rows
local rockList        -- all rock entities {x, y, state, timer, fallTimer, inGrid}
local gemsLeft        -- gems remaining to collect

-- Player
local player          -- {x, y, lives, score, deepest, moveTimer, invulnTimer, alive, vx, vy, facing}

-- Camera
local camY            -- current camera y (pixels)

-- Screen shake
local shakeMag   = 0
local shakeTimer = 0
local shakeDur   = 0

-- Rendering
local offsetX         -- horizontal centering offset for wider resolutions

-- UI
local debugMode  = false
local titleBlink = 0
local time       = 0

-- Simple deterministic RNG (LCG)
local rngState = 0
local function rngNext()
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function worldGet(x, y)
    if x < 0 or x >= cols or y < 0 or y >= rows then return -1 end
    return world[y][x]
end

local function worldSet(x, y, v)
    if x >= 0 and x < cols and y >= 0 and y < rows then
        world[y][x] = v
    end
end

-----------------------------------------------------------------------
-- Screen shake
-----------------------------------------------------------------------
local function triggerShake(mag, dur)
    shakeMag   = mag
    shakeDur   = dur
    shakeTimer = dur
end

local function getShakeOffset()
    if shakeTimer <= 0 then return 0, 0 end
    local intensity = shakeTimer / shakeDur
    local sx = (math.random() * 2 - 1) * shakeMag * intensity
    local sy = (math.random() * 2 - 1) * shakeMag * intensity
    return math.floor(sx), math.floor(sy)
end

-----------------------------------------------------------------------
-- World generation
-----------------------------------------------------------------------
local function generateWorld()
    world = {}
    for y = 0, rows - 1 do
        world[y] = {}
        for x = 0, cols - 1 do
            if y < level.surface_row then
                world[y][x] = EMPTY
            else
                world[y][x] = DIRT
            end
        end
    end

    -- Place gems from level data
    gemsLeft = 0
    for _, g in ipairs(level.gems) do
        if g.x >= 0 and g.x < cols and g.y >= 0 and g.y < rows then
            world[g.y][g.x] = GEM
            gemsLeft = gemsLeft + 1
        end
    end

    -- Place rocks with deterministic RNG
    rngState = level.seed
    rockList = {}
    for y = level.surface_row + 1, rows - 1 do
        for x = 0, cols - 1 do
            if world[y][x] == DIRT and rngNext() < level.rock_density then
                -- Skip placement adjacent to gems
                local nearGem = false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if worldGet(x + dx, y + dy) == GEM then
                            nearGem = true
                        end
                    end
                end
                if not nearGem then
                    world[y][x] = ROCK
                    rockList[#rockList + 1] = {
                        x = x, y = y,
                        state = "still",
                        timer = 0,
                        fallTimer = 0,
                        inGrid = true,
                    }
                end
            end
        end
    end

    -- Clear spawn area (3x3 around spawn + entry shaft)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local sx = level.spawn_x + dx
            local sy = level.spawn_y + dy
            local t = worldGet(sx, sy)
            if t == DIRT or t == ROCK then
                worldSet(sx, sy, EMPTY)
                -- Remove rock entity if one existed here
                for i = #rockList, 1, -1 do
                    if rockList[i].x == sx and rockList[i].y == sy then
                        table.remove(rockList, i)
                    end
                end
            end
        end
    end
    worldSet(level.spawn_x, level.surface_row, EMPTY)
end

-----------------------------------------------------------------------
-- Player
-----------------------------------------------------------------------
local function initPlayer()
    player = {
        x = level.spawn_x,
        y = level.spawn_y,
        lives = level.lives,
        score = 0,
        deepest = level.spawn_y,
        moveTimer = 0,
        invulnTimer = 0,
        alive = true,
        vx = level.spawn_x * TILE,
        vy = level.spawn_y * TILE,
        facing = "down",
    }
end

local function hitPlayer()
    if not player.alive then return end
    if player.invulnTimer > 0 then return end

    player.lives = player.lives - 1
    player.invulnTimer = level.invuln_time
    api.sfx.play("hit")
    triggerShake(4, 0.3)

    if player.lives <= 0 then
        player.alive = false
        gameState = STATE_GAMEOVER
        api.music.stop()
        api.sfx.play("death")
    end
end

local function movePlayer(dx, dy)
    if player.moveTimer > 0 then return end

    local nx = player.x + dx
    local ny = player.y + dy

    -- Bounds
    if nx < 0 or nx >= cols or ny < 0 or ny >= rows then return end

    local tile = worldGet(nx, ny)

    -- Can't walk into rocks
    if tile == ROCK then return end

    -- Dig dirt
    if tile == DIRT then
        worldSet(nx, ny, EMPTY)
        api.sfx.play("dig")
    end

    -- Collect gem
    if tile == GEM then
        worldSet(nx, ny, EMPTY)
        player.score = player.score + level.gem_score
        gemsLeft = gemsLeft - 1
        api.sfx.play("gem")
        if gemsLeft <= 0 then
            player.x = nx
            player.y = ny
            gameState = STATE_WIN
            api.music.stop()
            api.sfx.play("win")
            return
        end
    end

    player.x = nx
    player.y = ny
    player.moveTimer = level.move_cooldown

    -- Facing direction
    if     dx < 0 then player.facing = "left"
    elseif dx > 0 then player.facing = "right"
    elseif dy < 0 then player.facing = "up"
    else                player.facing = "down"
    end

    -- Depth scoring
    if ny > player.deepest then
        player.score = player.score + (ny - player.deepest) * level.depth_score
        player.deepest = ny
    end

    -- Check if any falling rock is at new position
    for _, r in ipairs(rockList) do
        if r.state == "falling" and r.x == nx and r.y == ny then
            hitPlayer()
        end
    end
end

-----------------------------------------------------------------------
-- Rock physics
-----------------------------------------------------------------------
local function updateRocks(dt)
    for _, r in ipairs(rockList) do
        if r.state == "still" then
            -- Check tile below
            if r.y + 1 < rows and worldGet(r.x, r.y + 1) == EMPTY then
                r.state = "warning"
                r.timer = level.rock_warning_time
            end

        elseif r.state == "warning" then
            r.timer = r.timer - dt
            if r.timer <= 0 then
                r.state = "falling"
                r.fallTimer = 0
                if r.inGrid then
                    worldSet(r.x, r.y, EMPTY)
                    r.inGrid = false
                end
            end

        elseif r.state == "falling" then
            r.fallTimer = r.fallTimer + dt
            if r.fallTimer >= level.rock_fall_speed then
                r.fallTimer = r.fallTimer - level.rock_fall_speed

                local nextY = r.y + 1
                local below = worldGet(r.x, nextY)

                if below == EMPTY and nextY < rows then
                    r.y = nextY

                    -- Collision with player
                    if player.alive and r.x == player.x and r.y == player.y then
                        hitPlayer()
                    end
                else
                    -- Land
                    if worldGet(r.x, r.y) == EMPTY then
                        worldSet(r.x, r.y, ROCK)
                        r.inGrid = true
                    end
                    r.state = "still"
                    triggerShake(2, 0.15)
                    api.sfx.play("land")
                end
            end
        end
    end
end

-----------------------------------------------------------------------
-- Camera
-----------------------------------------------------------------------
local function updateCamera(dt)
    local targetY = player.y * TILE - SH / 2 + TILE
    targetY = clamp(targetY, 0, math.max(0, rows * TILE - SH))
    camY = camY + (targetY - camY) * math.min(1, dt * 6)
end

-----------------------------------------------------------------------
-- New game / restart
-----------------------------------------------------------------------
local function startGame()
    generateWorld()
    initPlayer()
    camY = clamp(player.y * TILE - SH / 2, 0, math.max(0, rows * TILE - SH))
    shakeMag   = 0
    shakeTimer = 0
    gameState  = STATE_PLAYING
    time       = 0
    api.music.play()
end

-----------------------------------------------------------------------
-- Drawing
-----------------------------------------------------------------------
local function drawSky(sx, sy)
    -- Sky background above surface
    local skyBottom = level.surface_row * TILE - math.floor(camY) + sy
    if skyBottom > 0 then
        local sc = api.palette.get(28)
        api.gfx.setColor(sc[1], sc[2], sc[3], 1)
        api.gfx.rectangle("fill", 0, sy, SW, math.min(skyBottom, SH))
    end
end

local function drawWorld(sx, sy)
    local startRow = math.max(0, math.floor(camY / TILE) - 1)
    local endRow   = math.min(rows - 1, math.floor((camY + SH) / TILE) + 1)

    -- Build set of warning rock positions to skip in grid draw
    local warningSet = {}
    for _, r in ipairs(rockList) do
        if r.state == "warning" then
            warningSet[r.y * cols + r.x] = true
        end
    end

    for y = startRow, endRow do
        for x = 0, cols - 1 do
            local tile = world[y][x]
            local px = offsetX + x * TILE + sx
            local py = y * TILE - math.floor(camY) + sy

            if tile == DIRT then
                if y == level.surface_row then
                    api.sprite.draw(5, px, py, false, false, 2)
                else
                    api.sprite.draw(4, px, py, false, false, 2)
                end
            elseif tile == GEM then
                -- Dirt background behind gem
                api.sprite.draw(4, px, py, false, false, 2)
                -- Gem with sparkle
                api.sprite.draw(3, px, py, false, false, 2)
                -- Sparkle highlight
                local sparkle = math.sin(time * 5 + x * 3 + y * 7)
                if sparkle > 0.3 then
                    local sc = api.palette.get(16)
                    api.gfx.setColor(sc[1], sc[2], sc[3], sparkle * 0.4)
                    api.gfx.rectangle("fill", px + 4, py + 2, 2, 2)
                    api.gfx.setColor(1, 1, 1, 1)
                end
            elseif tile == ROCK and not warningSet[y * cols + x] then
                api.sprite.draw(2, px, py, false, false, 2)
            end
        end
    end
end

local function drawRocks(sx, sy)
    for _, r in ipairs(rockList) do
        local px = offsetX + r.x * TILE + sx
        local py = r.y * TILE - math.floor(camY) + sy

        if r.state == "warning" then
            -- Wiggle
            local wiggle = math.sin(time * 30) * 2
            api.sprite.draw(2, px + wiggle, py, false, false, 2)
        elseif r.state == "falling" and not r.inGrid then
            api.sprite.draw(2, px, py, false, false, 2)
        end
    end
end

local function drawPlayer(sx, sy)
    if not player.alive then return end

    -- Invulnerability blink
    if player.invulnTimer > 0 and math.floor(time * 10) % 2 == 0 then
        return
    end

    local px = offsetX + math.floor(player.vx) + sx
    local py = math.floor(player.vy) - math.floor(camY) + sy

    local flipX = player.facing == "left"
    api.sprite.draw(1, px, py, flipX, false, 2)
end

local function drawHUD()
    local pc = api.palette.get(15)
    api.font.print("SCORE:" .. player.score, 2, 2, 1, pc[1], pc[2], pc[3])

    -- Lives as hearts
    local lc = api.palette.get(6)
    api.font.print("LIVES:" .. player.lives, 2, 10, 1, lc[1], lc[2], lc[3])

    -- Gems remaining
    local gc = api.palette.get(23)
    local gemStr = "GEMS:" .. gemsLeft
    local gw = api.font.measure(gemStr, 1)
    api.font.print(gemStr, SW - gw - 2, 2, 1, gc[1], gc[2], gc[3])

    -- Depth
    local dc = api.palette.get(4)
    local depth = math.max(0, player.y - level.surface_row)
    local depthStr = "DEPTH:" .. depth
    local dw = api.font.measure(depthStr, 1)
    api.font.print(depthStr, SW - dw - 2, 10, 1, dc[1], dc[2], dc[3])
end

local function drawDebug()
    if not debugMode then return end

    local c = api.palette.get(19)
    local y = 20
    api.font.print("=DEBUG=", 2, y, 1, c[1], c[2], c[3]); y = y + 8
    api.font.print("POS:" .. player.x .. "," .. player.y, 2, y, 1, c[1], c[2], c[3]); y = y + 8
    api.font.print("CAM:" .. math.floor(camY), 2, y, 1, c[1], c[2], c[3]); y = y + 8

    local falling = 0
    for _, r in ipairs(rockList) do
        if r.state == "falling" then falling = falling + 1 end
    end
    api.font.print("ROCKS:" .. #rockList .. " F:" .. falling, 2, y, 1, c[1], c[2], c[3]); y = y + 8
    api.font.print("GEMS:" .. gemsLeft .. "/" .. level.total_gems, 2, y, 1, c[1], c[2], c[3])
end

-----------------------------------------------------------------------
-- Menu screen
-----------------------------------------------------------------------
local function drawMenu()
    -- Background
    api.gfx.setColor(0, 0, 0, 1)
    api.gfx.rectangle("fill", 0, 0, SW, SH)

    -- Title
    local tc = api.palette.get(19)
    local title = "DIGDIVE"
    local tw = api.font.measure(title, 2)
    api.font.print(title, math.floor((SW - tw) / 2), 20, 2, tc[1], tc[2], tc[3])

    -- Subtitle
    local sc = api.palette.get(15)
    local sub = "DIG DEEP. DODGE ROCKS."
    local sw2 = api.font.measure(sub, 1)
    api.font.print(sub, math.floor((SW - sw2) / 2), 42, 1, sc[1], sc[2], sc[3])

    -- Draw preview sprites
    local cx = math.floor(SW / 2)
    api.sprite.draw(1, cx - 24, 56, false, false, 2)  -- player
    api.sprite.draw(3, cx - 4,  56, false, false, 2)   -- gem
    api.sprite.draw(2, cx + 16, 56, false, false, 2)   -- rock

    -- Instructions
    local ic = api.palette.get(4)
    local y = 82
    local lines = {
        "ARROWS: DIG & MOVE",
        "COLLECT ALL 18 GEMS",
        "AVOID FALLING ROCKS!",
        "",
        "R: RESTART",
        "C: DEBUG OVERLAY",
    }
    for _, line in ipairs(lines) do
        if line ~= "" then
            local lw = api.font.measure(line, 1)
            api.font.print(line, math.floor((SW - lw) / 2), y, 1, ic[1], ic[2], ic[3])
        end
        y = y + 9
    end

    -- Start prompt
    if math.floor(titleBlink * 2.5) % 2 == 0 then
        local gc2 = api.palette.get(23)
        local start = "PRESS Z TO DIG!"
        local startW = api.font.measure(start, 1)
        api.font.print(start, math.floor((SW - startW) / 2), SH - 20, 1, gc2[1], gc2[2], gc2[3])
    end
end

-----------------------------------------------------------------------
-- Game over screen
-----------------------------------------------------------------------
local function drawGameOver()
    api.gfx.setColor(0, 0, 0, 0.7)
    api.gfx.rectangle("fill", 0, 0, SW, SH)

    local rc = api.palette.get(6)
    local title = "GAME OVER"
    local tw = api.font.measure(title, 2)
    api.font.print(title, math.floor((SW - tw) / 2), math.floor(SH / 2) - 30, 2, rc[1], rc[2], rc[3])

    local sc = api.palette.get(15)
    local scoreStr = "SCORE: " .. player.score
    local sw2 = api.font.measure(scoreStr, 1)
    api.font.print(scoreStr, math.floor((SW - sw2) / 2), math.floor(SH / 2) - 6, 1, sc[1], sc[2], sc[3])

    local dc = api.palette.get(4)
    local depth = math.max(0, player.deepest - level.surface_row)
    local depthStr = "DEPTH: " .. depth
    local dw = api.font.measure(depthStr, 1)
    api.font.print(depthStr, math.floor((SW - dw) / 2), math.floor(SH / 2) + 6, 1, dc[1], dc[2], dc[3])

    local collected = level.total_gems - gemsLeft
    local gc2 = api.palette.get(23)
    local gemStr = "GEMS: " .. collected .. "/" .. level.total_gems
    local gw = api.font.measure(gemStr, 1)
    api.font.print(gemStr, math.floor((SW - gw) / 2), math.floor(SH / 2) + 18, 1, gc2[1], gc2[2], gc2[3])

    if math.floor(titleBlink * 2.5) % 2 == 0 then
        local hc = api.palette.get(4)
        local hint = "Z:RETRY  ESC:QUIT"
        local hw = api.font.measure(hint, 1)
        api.font.print(hint, math.floor((SW - hw) / 2), SH - 20, 1, hc[1], hc[2], hc[3])
    end
end

-----------------------------------------------------------------------
-- Win screen
-----------------------------------------------------------------------
local function drawWin()
    api.gfx.setColor(0, 0, 0, 0.7)
    api.gfx.rectangle("fill", 0, 0, SW, SH)

    local gc2 = api.palette.get(15)
    local title = "YOU WIN!"
    local tw = api.font.measure(title, 2)
    api.font.print(title, math.floor((SW - tw) / 2), math.floor(SH / 2) - 30, 2, gc2[1], gc2[2], gc2[3])

    local sc = api.palette.get(23)
    local sub = "ALL GEMS COLLECTED!"
    local sw2 = api.font.measure(sub, 1)
    api.font.print(sub, math.floor((SW - sw2) / 2), math.floor(SH / 2) - 6, 1, sc[1], sc[2], sc[3])

    local pc = api.palette.get(15)
    local scoreStr = "FINAL SCORE: " .. player.score
    local pw = api.font.measure(scoreStr, 1)
    api.font.print(scoreStr, math.floor((SW - pw) / 2), math.floor(SH / 2) + 10, 1, pc[1], pc[2], pc[3])

    local dc = api.palette.get(4)
    local depth = math.max(0, player.deepest - level.surface_row)
    local depthStr = "MAX DEPTH: " .. depth
    local dw = api.font.measure(depthStr, 1)
    api.font.print(depthStr, math.floor((SW - dw) / 2), math.floor(SH / 2) + 22, 1, dc[1], dc[2], dc[3])

    if math.floor(titleBlink * 2.5) % 2 == 0 then
        local hc = api.palette.get(4)
        local hint = "Z:PLAY AGAIN  ESC:QUIT"
        local hw = api.font.measure(hint, 1)
        api.font.print(hint, math.floor((SW - hw) / 2), SH - 20, 1, hc[1], hc[2], hc[3])
    end
end

-----------------------------------------------------------------------
-- Cart interface
-----------------------------------------------------------------------
function Cart.load(a)
    api = a
    SW = api.getWidth()
    SH = api.getHeight()

    -- Centering offset for wider resolutions (world = 10 tiles * 16px = 160px)
    offsetX = math.floor((SW - 10 * TILE) / 2)

    -- Load level
    level = require("cartridges.digdive.levels.LEVEL_01")
    cols  = level.cols
    rows  = level.rows

    -- Define SFX
    api.sfx.setPreset("dig", {
        wave="noise", freq=200, duration=0.08, volume=0.2,
        attack=0.005, decay=0.03, sustain=0.1, release=0.03, freqSweep=-100,
    })
    api.sfx.setPreset("gem", {
        wave="square", freq=660, duration=0.2, volume=0.3,
        attack=0.005, decay=0.03, sustain=0.4, release=0.1, freqSweep=880,
    })
    api.sfx.setPreset("hit", {
        wave="noise", freq=300, duration=0.25, volume=0.35,
        attack=0.005, decay=0.05, sustain=0.2, release=0.1, freqSweep=-200,
    })
    api.sfx.setPreset("death", {
        wave="square", freq=440, duration=0.5, volume=0.3,
        attack=0.01, decay=0.1, sustain=0.2, release=0.2, freqSweep=-400,
    })
    api.sfx.setPreset("land", {
        wave="noise", freq=100, duration=0.12, volume=0.25,
        attack=0.005, decay=0.04, sustain=0.15, release=0.03, freqSweep=-50,
    })
    api.sfx.setPreset("win", {
        wave="square", freq=523, duration=0.4, volume=0.3,
        attack=0.005, decay=0.05, sustain=0.5, release=0.15, freqSweep=500,
    })

    gameState  = STATE_MENU
    titleBlink = 0
end

function Cart.update(dt)
    time = time + dt
    titleBlink = titleBlink + dt

    if gameState == STATE_PLAYING and player.alive then
        -- Move cooldown
        if player.moveTimer > 0 then
            player.moveTimer = player.moveTimer - dt
        end

        -- Invulnerability timer
        if player.invulnTimer > 0 then
            player.invulnTimer = player.invulnTimer - dt
        end

        -- Held-key movement (continuous digging)
        if player.moveTimer <= 0 then
            if     api.input.isDown("left")  then movePlayer(-1,  0)
            elseif api.input.isDown("right") then movePlayer( 1,  0)
            elseif api.input.isDown("up")    then movePlayer( 0, -1)
            elseif api.input.isDown("down")  then movePlayer( 0,  1)
            end
        end

        -- Rock physics
        updateRocks(dt)

        -- Camera
        updateCamera(dt)

        -- Shake timer
        if shakeTimer > 0 then
            shakeTimer = shakeTimer - dt
        end

        -- Smooth visual interpolation for player sprite
        player.vx = player.vx + (player.x * TILE - player.vx) * math.min(1, dt * 18)
        player.vy = player.vy + (player.y * TILE - player.vy) * math.min(1, dt * 18)
    end
end

function Cart.draw()
    if gameState == STATE_MENU then
        drawMenu()
        return
    end

    -- Black background
    api.gfx.setColor(0, 0, 0, 1)
    api.gfx.rectangle("fill", 0, 0, SW, SH)

    -- Shake offset
    local sx, sy = getShakeOffset()

    -- Draw world layers
    drawSky(sx, sy)
    drawWorld(sx, sy)
    drawRocks(sx, sy)
    drawPlayer(sx, sy)

    -- HUD (no shake)
    drawHUD()
    drawDebug()

    -- Overlay screens
    if gameState == STATE_GAMEOVER then
        drawGameOver()
    elseif gameState == STATE_WIN then
        drawWin()
    end
end

function Cart.keypressed(key)
    if gameState == STATE_MENU then
        if key == "z" or key == "j" or key == "return" then
            startGame()
        end

    elseif gameState == STATE_PLAYING then
        -- Instant tap movement (first press)
        if     key == "left"  then movePlayer(-1,  0)
        elseif key == "right" then movePlayer( 1,  0)
        elseif key == "up"    then movePlayer( 0, -1)
        elseif key == "down"  then movePlayer( 0,  1)
        end

        -- Debug toggle
        if key == "c" then
            debugMode = not debugMode
        end

        -- Restart
        if key == "r" then
            startGame()
        end

    elseif gameState == STATE_GAMEOVER or gameState == STATE_WIN then
        if key == "z" or key == "j" or key == "return" then
            startGame()
        end
    end
end

function Cart.unload()
    api.music.stop()
end

return Cart
