-- cartridges/pacmaze/main.lua
-- PacMaze: Atari 2600-style maze chase game
-- Eat dots, dodge ghosts, grab power pellets!

local Cart = {}

-- ============================================================
-- CONSTANTS
-- ============================================================
local TILE       = 8       -- tile size in pixels
local COLS       = 20      -- maze columns
local ROWS       = 24      -- maze rows
local PLAYER_SPD = 50      -- pixels/sec
local GHOST_SPD  = 38      -- pixels/sec
local FRIGHT_SPD = 25      -- frightened ghost speed
local FRIGHT_DUR = 6       -- frightened mode seconds
local DEATH_DUR  = 1.2     -- death pause seconds
local READY_DUR  = 2       -- ready screen seconds
local WIN_DUR    = 2       -- level clear pause seconds
local DOT_SCORE  = 10
local PELLET_SCORE = 50
local GHOST_EAT_BASE = 200 -- doubles each ghost eaten per pellet
local START_LIVES = 3
local CHOMP_TOGGLE_DIST = 4 -- pixels between chomp sound alternation

-- Direction vectors: dx, dy
local DIR = {
    left  = { dx = -1, dy =  0 },
    right = { dx =  1, dy =  0 },
    up    = { dx =  0, dy = -1 },
    down  = { dx =  0, dy =  1 },
    none  = { dx =  0, dy =  0 },
}
local OPPOSITE = { left = "right", right = "left", up = "down", down = "up", none = "none" }

-- ============================================================
-- STATE
-- ============================================================
local api               -- engine API reference
local state             -- "title", "ready", "playing", "dying", "win", "gameover"
local score, lives, level
local maze              -- 2D wall grid [row][col] = 0 or 1
local tilemap           -- engine Tilemap instance
local dots              -- [row][col] = "dot" | "pellet" | nil
local totalDots, dotsEaten
local player            -- { gx, gy, px, py, dir, nextDir, moveTimer, sprId, animTimer }
local ghosts            -- array of ghost tables
local frightTimer       -- countdown for frightened mode
local ghostsEatenCombo  -- multiplier for ghost eat score in current fright
local stateTimer        -- generic timer for ready/dying/win states
local chompHigh         -- toggle for alternating chomp pitch
local screenW, screenH  -- internal resolution

-- ============================================================
-- HELPERS
-- ============================================================

-- Check if a grid cell is walkable (path, not wall)
local function isWalkable(col, row)
    if row < 1 or row > ROWS then return false end
    -- Tunnel wrap: columns wrap around
    if col < 1 then col = COLS end
    if col > COLS then col = 1 end
    return maze[row] and maze[row][col] == 0
end

-- Pixel position of a tile's top-left corner
local function tileToPixel(col, row)
    return (col - 1) * TILE, (row - 1) * TILE
end

-- Grid position from pixel center
local function pixelToTile(px, py)
    return math.floor(px / TILE) + 1, math.floor(py / TILE) + 1
end

-- Center pixel of a tile
local function tileCenter(col, row)
    return (col - 1) * TILE + TILE / 2, (row - 1) * TILE + TILE / 2
end

-- Distance squared between two points
local function distSq(x1, y1, x2, y2)
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
end

-- Count available exits from a tile (excluding a given direction)
local function countExits(col, row, excludeDir)
    local n = 0
    for name, d in pairs(DIR) do
        if name ~= "none" and name ~= excludeDir then
            if isWalkable(col + d.dx, row + d.dy) then
                n = n + 1
            end
        end
    end
    return n
end

-- Get list of valid directions from a tile (optionally excluding reverse)
local function getValidDirs(col, row, excludeDir)
    local dirs = {}
    for _, name in ipairs({"up", "down", "left", "right"}) do
        if name ~= excludeDir then
            local d = DIR[name]
            if isWalkable(col + d.dx, row + d.dy) then
                dirs[#dirs + 1] = name
            end
        end
    end
    return dirs
end

-- ============================================================
-- SFX SETUP (procedural, cart-local presets)
-- ============================================================
local function setupSFX()
    api.sfx.setPreset("chomp_hi", {
        wave = "square", freq = 500, duration = 0.07, volume = 0.3,
        attack = 0.005, decay = 0.02, sustain = 0.3, release = 0.02,
    })
    api.sfx.setPreset("chomp_lo", {
        wave = "square", freq = 420, duration = 0.07, volume = 0.3,
        attack = 0.005, decay = 0.02, sustain = 0.3, release = 0.02,
    })
    api.sfx.setPreset("power", {
        wave = "square", freq = 200, duration = 0.3, volume = 0.35,
        attack = 0.01, decay = 0.05, sustain = 0.3, release = 0.1,
        freqSweep = 600,
    })
    api.sfx.setPreset("ghost_eat", {
        wave = "square", freq = 700, duration = 0.25, volume = 0.35,
        attack = 0.005, decay = 0.05, sustain = 0.3, release = 0.1,
        freqSweep = -500,
    })
    api.sfx.setPreset("death", {
        wave = "square", freq = 300, duration = 0.6, volume = 0.4,
        attack = 0.01, decay = 0.1, sustain = 0.3, release = 0.2,
        freqSweep = -250,
    })
    api.sfx.setPreset("levelup", {
        wave = "square", freq = 400, duration = 0.4, volume = 0.35,
        attack = 0.01, decay = 0.05, sustain = 0.4, release = 0.1,
        freqSweep = 500,
    })
end

-- ============================================================
-- LEVEL LOADING
-- ============================================================
local function loadLevel()
    local lvl = require("cartridges.pacmaze.levels.LEVEL_01")

    -- Copy maze grid
    maze = {}
    for r = 1, ROWS do
        maze[r] = {}
        for c = 1, COLS do
            maze[r][c] = lvl.maze[r][c]
        end
    end

    -- Build tilemap
    tilemap = api.tilemap.new(COLS, ROWS, 1)
    for r = 1, ROWS do
        for c = 1, COLS do
            tilemap:set(1, c, r, maze[r][c])
        end
    end

    -- Generate dots on all walkable tiles
    dots = {}
    totalDots = 0
    dotsEaten = 0
    local spawnPositions = {} -- positions to exclude from dots

    -- Mark spawn positions (player + ghosts)
    for _, obj in ipairs(lvl.objects) do
        local gc = math.floor(obj.x / TILE) + 1
        local gr = math.floor(obj.y / TILE) + 1
        spawnPositions[gr * 1000 + gc] = true
    end

    -- Place dots on walkable non-spawn tiles
    for r = 1, ROWS do
        dots[r] = {}
        for c = 1, COLS do
            if maze[r][c] == 0 and not spawnPositions[r * 1000 + c] then
                dots[r][c] = "dot"
                totalDots = totalDots + 1
            end
        end
    end

    -- Place power pellets (replace dots)
    for _, pp in ipairs(lvl.powerPellets) do
        local c, r = pp.col, pp.row
        if dots[r] and dots[r][c] == "dot" then
            -- Was already counted as a dot, just change type
            dots[r][c] = "pellet"
        elseif maze[r][c] == 0 then
            dots[r][c] = "pellet"
            totalDots = totalDots + 1
        end
    end

    -- Create player from spawn
    local pObj = lvl.objects[1]
    local pgx = math.floor(pObj.x / TILE) + 1
    local pgy = math.floor(pObj.y / TILE) + 1
    player = {
        gx = pgx, gy = pgy,
        px = (pgx - 1) * TILE, py = (pgy - 1) * TILE,
        dir = "left", nextDir = "left",
        moving = false,
        animTimer = 0, animFrame = 1,
    }

    -- Create ghosts from enemy objects
    ghosts = {}
    for i = 2, #lvl.objects do
        local obj = lvl.objects[i]
        local ggx = math.floor(obj.x / TILE) + 1
        local ggy = math.floor(obj.y / TILE) + 1
        local ghost = {
            gx = ggx, gy = ggy,
            px = (ggx - 1) * TILE, py = (ggy - 1) * TILE,
            dir = "up",
            ai = obj.props.ai or "chase",
            spriteId = obj.props.ghostColor or 3,
            homeGx = ggx, homeGy = ggy,
            mode = "normal",   -- "normal", "frightened", "eaten"
            exitDelay = (i - 2) * 2,  -- stagger ghost exits
        }
        ghosts[#ghosts + 1] = ghost
    end
end

-- Reset positions after death (keep dots, score, etc.)
local function resetPositions()
    -- Reset player to spawn
    local lvl = require("cartridges.pacmaze.levels.LEVEL_01")
    local pObj = lvl.objects[1]
    local pgx = math.floor(pObj.x / TILE) + 1
    local pgy = math.floor(pObj.y / TILE) + 1
    player.gx = pgx
    player.gy = pgy
    player.px = (pgx - 1) * TILE
    player.py = (pgy - 1) * TILE
    player.dir = "left"
    player.nextDir = "left"
    player.moving = false
    player.animTimer = 0
    player.animFrame = 1

    -- Reset ghosts to spawn positions
    for i, ghost in ipairs(ghosts) do
        ghost.gx = ghost.homeGx
        ghost.gy = ghost.homeGy
        ghost.px = (ghost.homeGx - 1) * TILE
        ghost.py = (ghost.homeGy - 1) * TILE
        ghost.dir = "up"
        ghost.mode = "normal"
        ghost.exitDelay = (i - 1) * 2
    end

    frightTimer = 0
    ghostsEatenCombo = 0
end

-- ============================================================
-- MOVEMENT
-- ============================================================

-- Move an entity one step toward its current direction
-- Returns true if it reached the next tile center
local function moveEntity(ent, speed, dt)
    if ent.dir == "none" then return false end

    local d = DIR[ent.dir]
    local targetX = (ent.gx - 1) * TILE
    local targetY = (ent.gy - 1) * TILE

    -- Calculate next tile target
    local nextCol = ent.gx + d.dx
    local nextRow = ent.gy + d.dy

    -- Tunnel wrap
    if nextCol < 1 then nextCol = COLS end
    if nextCol > COLS then nextCol = 1 end

    if not isWalkable(nextCol, nextRow) then
        -- Can't move in this direction, snap to current tile
        ent.px = targetX
        ent.py = targetY
        return false
    end

    -- Move toward next tile
    local nextX = (nextCol - 1) * TILE
    local nextY = (nextRow - 1) * TILE

    -- Handle tunnel wrap pixel movement
    local dx = nextX - ent.px
    local dy = nextY - ent.py

    -- For tunnel wrapping, take the shorter path
    if math.abs(dx) > COLS * TILE / 2 then
        if dx > 0 then dx = dx - COLS * TILE
        else dx = dx + COLS * TILE end
    end

    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.5 then
        -- Arrived at next tile
        ent.gx = nextCol
        ent.gy = nextRow
        ent.px = nextX
        ent.py = nextY
        return true
    end

    local step = speed * dt
    if step >= dist then
        ent.gx = nextCol
        ent.gy = nextRow
        ent.px = nextX
        ent.py = nextY
        return true
    else
        ent.px = ent.px + (dx / dist) * step
        ent.py = ent.py + (dy / dist) * step

        -- Wrap pixel position for tunnels
        if ent.px < -TILE then ent.px = ent.px + COLS * TILE end
        if ent.px >= COLS * TILE then ent.px = ent.px - COLS * TILE end

        return false
    end
end

-- ============================================================
-- GHOST AI
-- ============================================================
local function ghostPickDirection(ghost)
    local excludeDir = OPPOSITE[ghost.dir]
    local dirs = getValidDirs(ghost.gx, ghost.gy, excludeDir)

    if #dirs == 0 then
        -- Dead end, reverse
        dirs = getValidDirs(ghost.gx, ghost.gy, nil)
        if #dirs == 0 then
            ghost.dir = "none"
            return
        end
    end

    if #dirs == 1 then
        ghost.dir = dirs[1]
        return
    end

    -- Choose based on AI type
    if ghost.mode == "frightened" then
        -- Random direction when frightened
        ghost.dir = dirs[math.random(#dirs)]
        return
    end

    if ghost.ai == "chase" then
        -- Target player directly
        local bestDir = dirs[1]
        local bestDist = math.huge
        for _, name in ipairs(dirs) do
            local d = DIR[name]
            local nc = ghost.gx + d.dx
            local nr = ghost.gy + d.dy
            local dd = distSq(nc, nr, player.gx, player.gy)
            if dd < bestDist then
                bestDist = dd
                bestDir = name
            end
        end
        ghost.dir = bestDir

    elseif ghost.ai == "ambush" then
        -- Target 4 tiles ahead of player
        local pd = DIR[player.dir]
        local targetCol = player.gx + pd.dx * 4
        local targetRow = player.gy + pd.dy * 4
        local bestDir = dirs[1]
        local bestDist = math.huge
        for _, name in ipairs(dirs) do
            local d = DIR[name]
            local nc = ghost.gx + d.dx
            local nr = ghost.gy + d.dy
            local dd = distSq(nc, nr, targetCol, targetRow)
            if dd < bestDist then
                bestDist = dd
                bestDir = name
            end
        end
        ghost.dir = bestDir

    elseif ghost.ai == "patrol" then
        -- Alternate: chase player half the time, go home the other half
        local targetCol, targetRow
        if math.floor(stateTimer or 0) % 10 < 5 then
            targetCol, targetRow = player.gx, player.gy
        else
            targetCol, targetRow = ghost.homeGx, ghost.homeGy
        end
        local bestDir = dirs[1]
        local bestDist = math.huge
        for _, name in ipairs(dirs) do
            local d = DIR[name]
            local nc = ghost.gx + d.dx
            local nr = ghost.gy + d.dy
            local dd = distSq(nc, nr, targetCol, targetRow)
            if dd < bestDist then
                bestDist = dd
                bestDir = name
            end
        end
        ghost.dir = bestDir

    else
        -- "random" AI: pick a random valid direction
        ghost.dir = dirs[math.random(#dirs)]
    end
end

-- ============================================================
-- UPDATE
-- ============================================================
local function updatePlaying(dt)
    stateTimer = (stateTimer or 0) + dt

    -- Poll held direction keys for responsive controls
    if api.input.isDown("left")  then player.nextDir = "left" end
    if api.input.isDown("right") then player.nextDir = "right" end
    if api.input.isDown("up")    then player.nextDir = "up" end
    if api.input.isDown("down")  then player.nextDir = "down" end

    -- Update frightened timer
    if frightTimer > 0 then
        frightTimer = frightTimer - dt
        if frightTimer <= 0 then
            frightTimer = 0
            ghostsEatenCombo = 0
            for _, ghost in ipairs(ghosts) do
                if ghost.mode == "frightened" then
                    ghost.mode = "normal"
                end
            end
        end
    end

    -- Player movement: try to turn in nextDir, else continue in dir
    local atCenter = (player.px == (player.gx - 1) * TILE) and
                     (player.py == (player.gy - 1) * TILE)

    if atCenter then
        -- Try buffered direction first
        local nd = DIR[player.nextDir]
        if isWalkable(player.gx + nd.dx, player.gy + nd.dy) then
            player.dir = player.nextDir
            player.moving = true
        else
            -- Try current direction
            local cd = DIR[player.dir]
            if isWalkable(player.gx + cd.dx, player.gy + cd.dy) then
                player.moving = true
            else
                player.moving = false
            end
        end

        -- Check for dot/pellet at current position
        if dots[player.gy] and dots[player.gy][player.gx] then
            local dotType = dots[player.gy][player.gx]
            dots[player.gy][player.gx] = nil
            dotsEaten = dotsEaten + 1

            if dotType == "pellet" then
                score = score + PELLET_SCORE
                frightTimer = FRIGHT_DUR
                ghostsEatenCombo = 0
                api.sfx.play("power")
                for _, ghost in ipairs(ghosts) do
                    if ghost.mode == "normal" then
                        ghost.mode = "frightened"
                        -- Reverse direction
                        ghost.dir = OPPOSITE[ghost.dir]
                    end
                end
            else
                score = score + DOT_SCORE
                chompHigh = not chompHigh
                if chompHigh then
                    api.sfx.play("chomp_hi")
                else
                    api.sfx.play("chomp_lo")
                end
            end

            -- Check win
            if dotsEaten >= totalDots then
                state = "win"
                stateTimer = 0
                api.sfx.play("levelup")
                api.music.stop()
                return
            end
        end
    end

    if player.moving then
        local arrived = moveEntity(player, PLAYER_SPD, dt)
        -- Animate mouth
        player.animTimer = player.animTimer + dt
        if player.animTimer > 0.12 then
            player.animTimer = 0
            player.animFrame = 3 - player.animFrame  -- toggle 1<->2
        end
    else
        player.animFrame = 1  -- closed mouth when stopped
    end

    -- Ghost updates
    for _, ghost in ipairs(ghosts) do
        -- Exit delay
        if ghost.exitDelay > 0 then
            ghost.exitDelay = ghost.exitDelay - dt
            if ghost.exitDelay <= 0 then
                ghost.exitDelay = 0
                -- Just became active, pick initial direction
                ghostPickDirection(ghost)
            end
        else
            local speed = GHOST_SPD
            if ghost.mode == "frightened" then
                speed = FRIGHT_SPD
            elseif ghost.mode == "eaten" then
                speed = GHOST_SPD * 2
            end

            local arrived = moveEntity(ghost, speed, dt)
            if arrived then
                -- At new tile center, pick direction
                ghostPickDirection(ghost)

                -- Check if eaten ghost reached home
                if ghost.mode == "eaten" and
                   ghost.gx == ghost.homeGx and ghost.gy == ghost.homeGy then
                    ghost.mode = "normal"
                end
            else
                -- If stuck at tile center with invalid direction, repick
                local atCenter = (ghost.px == (ghost.gx - 1) * TILE) and
                                 (ghost.py == (ghost.gy - 1) * TILE)
                if atCenter then
                    local d = DIR[ghost.dir]
                    if not isWalkable(ghost.gx + d.dx, ghost.gy + d.dy) then
                        ghostPickDirection(ghost)
                    end
                end
            end
        end
    end

    -- Collision: player vs ghosts
    for _, ghost in ipairs(ghosts) do
        if ghost.exitDelay <= 0 and ghost.mode ~= "eaten" then
            local dx = player.px - ghost.px
            local dy = player.py - ghost.py
            if dx * dx + dy * dy < 36 then  -- ~6px collision radius
                if ghost.mode == "frightened" then
                    -- Eat ghost
                    ghost.mode = "eaten"
                    ghostsEatenCombo = ghostsEatenCombo + 1
                    local bonus = GHOST_EAT_BASE * ghostsEatenCombo
                    score = score + bonus
                    api.sfx.play("ghost_eat")
                else
                    -- Player dies
                    state = "dying"
                    stateTimer = 0
                    api.sfx.play("death")
                    api.music.stop()
                    return
                end
            end
        end
    end
end

-- ============================================================
-- DRAWING
-- ============================================================
local function drawMaze()
    tilemap:draw(1, 0, 0, screenW, screenH)
end

local function drawDots()
    for r = 1, ROWS do
        if dots[r] then
            for c = 1, COLS do
                local dt = dots[r][c]
                if dt then
                    local px, py = tileToPixel(c, r)
                    if dt == "dot" then
                        -- Small 2x2 dot in center of tile
                        api.palette.setColor(4)  -- white
                        api.gfx.rectangle("fill", px + 3, py + 3, 2, 2)
                    elseif dt == "pellet" then
                        -- Larger 4x4 pellet, blinking
                        local blink = math.floor((stateTimer or 0) * 5) % 2 == 0
                        if blink then
                            api.palette.setColor(4)  -- white
                            api.gfx.rectangle("fill", px + 2, py + 2, 4, 4)
                        end
                    end
                end
            end
        end
    end
end

local function drawPlayer()
    local sprId = player.animFrame  -- 1=closed, 2=open
    local flipX = false
    local flipY = false

    -- Rotate mouth direction using flip
    if player.dir == "left" then
        flipX = false  -- sprite 2 already faces right, flip for left? Actually sprite faces right
        -- Sprite 2 has mouth opening to the right. For left, flip horizontally
        if sprId == 2 then flipX = true end
    elseif player.dir == "right" then
        flipX = false
    elseif player.dir == "up" then
        -- For up/down, we just use the closed sprite or swap to a simple open variant
        -- Since we only have left/right mouth, just use closed for up/down
        if sprId == 2 then sprId = 1 end
    elseif player.dir == "down" then
        if sprId == 2 then sprId = 1 end
    end

    api.sprite.draw(sprId, math.floor(player.px), math.floor(player.py), flipX, flipY)
end

local function drawGhosts()
    for _, ghost in ipairs(ghosts) do
        do  -- always draw ghosts (even during exit delay, they're just stationary)
            local sprId = ghost.spriteId
            if ghost.mode == "frightened" then
                -- Flash between blue and white near end
                if frightTimer < 2 and math.floor(frightTimer * 5) % 2 == 1 then
                    sprId = ghost.spriteId  -- flash back to normal color briefly
                else
                    sprId = 7  -- frightened blue sprite
                end
            elseif ghost.mode == "eaten" then
                -- TODO: show just eyes. For now, don't draw
                -- Just skip drawing eaten ghosts for simplicity
                sprId = nil
            end

            if sprId then
                api.sprite.draw(sprId, math.floor(ghost.px), math.floor(ghost.py))
            end
        end
    end
end

local function drawHUD()
    -- Score at top-left
    api.palette.setColor(4)  -- white
    api.font.print("SCORE", 1, 1, 1, 1, 1, 1, 1)
    api.palette.setColor(15)  -- yellow
    api.font.print(tostring(score), 26, 1, 1, 1, 1, 0, 1)

    -- Level at top-right area
    api.palette.setColor(4)
    local lvlText = "L" .. tostring(level)
    local tw = api.font.measure(lvlText, 1)
    api.font.print(lvlText, screenW - tw - 1, 1, 1, 1, 1, 1, 1)

    -- Lives at bottom
    api.palette.setColor(15) -- yellow
    for i = 1, lives - 1 do  -- show remaining lives (not counting current)
        api.sprite.draw(1, 2 + (i - 1) * 10, screenH - 9)
    end
end

local function drawCentered(text, y, scale, r, g, b)
    scale = scale or 1
    local tw = api.font.measure(text, scale)
    local x = math.floor((screenW - tw) / 2)
    api.font.print(text, x, y, scale, r or 1, g or 1, b or 1, 1)
end

-- ============================================================
-- CART INTERFACE
-- ============================================================
function Cart.load(engineAPI)
    api = engineAPI
    screenW = api.getWidth()
    screenH = api.getHeight()

    setupSFX()

    score = 0
    lives = START_LIVES
    level = 1
    chompHigh = false
    frightTimer = 0
    ghostsEatenCombo = 0
    stateTimer = 0

    loadLevel()

    state = "title"
end

function Cart.update(dt)
    -- Cap dt to prevent tunneling on lag spikes
    if dt > 0.05 then dt = 0.05 end

    if state == "title" then
        -- Wait for Enter
        stateTimer = (stateTimer or 0) + dt

    elseif state == "ready" then
        stateTimer = stateTimer + dt
        if stateTimer >= READY_DUR then
            state = "playing"
            stateTimer = 0
            api.music.play()
        end

    elseif state == "playing" then
        api.music.update(dt)
        updatePlaying(dt)

    elseif state == "dying" then
        stateTimer = stateTimer + dt
        if stateTimer >= DEATH_DUR then
            lives = lives - 1
            if lives <= 0 then
                state = "gameover"
                stateTimer = 0
            else
                resetPositions()
                state = "ready"
                stateTimer = 0
            end
        end

    elseif state == "win" then
        stateTimer = stateTimer + dt
        if stateTimer >= WIN_DUR then
            -- Next level (replay same maze with slightly faster ghosts)
            level = level + 1
            GHOST_SPD = GHOST_SPD + 3
            FRIGHT_DUR = math.max(2, FRIGHT_DUR - 0.5)

            -- Clear and reload the level module for fresh state
            package.loaded["cartridges.pacmaze.levels.LEVEL_01"] = nil
            loadLevel()
            state = "ready"
            stateTimer = 0
        end

    elseif state == "gameover" then
        stateTimer = (stateTimer or 0) + dt
    end
end

function Cart.draw()
    -- Clear to black
    api.gfx.setColor(0, 0, 0, 1)
    api.gfx.rectangle("fill", 0, 0, screenW, screenH)

    if state == "title" then
        drawMaze()
        drawDots()

        -- Darken overlay
        api.gfx.setColor(0, 0, 0, 0.7)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        -- Title text
        local blink = math.floor((stateTimer or 0) * 3) % 2 == 0
        drawCentered("PACMAZE", screenH / 2 - 30, 2, 1, 1, 0)

        api.palette.setColor(4)
        drawCentered("EAT DOTS", screenH / 2 - 6, 1, 1, 1, 1)
        drawCentered("DODGE GHOSTS", screenH / 2 + 6, 1, 1, 1, 1)

        if blink then
            drawCentered("PRESS ENTER", screenH / 2 + 24, 1, 1, 1, 0)
        end

        -- Credits
        drawCentered("BY 9LIVESK9", screenH - 14, 1, 0.5, 0.5, 0.5)

    elseif state == "ready" then
        drawMaze()
        drawDots()
        drawPlayer()
        drawGhosts()
        drawHUD()

        -- "READY!" text
        drawCentered("READY!", screenH / 2 - 4, 1, 1, 1, 0)

    elseif state == "playing" then
        drawMaze()
        drawDots()
        drawPlayer()
        drawGhosts()
        drawHUD()

    elseif state == "dying" then
        drawMaze()
        drawDots()
        -- Flash player
        local show = math.floor(stateTimer * 8) % 2 == 0
        if show then drawPlayer() end
        drawGhosts()
        drawHUD()

    elseif state == "win" then
        drawMaze()
        drawPlayer()
        drawGhosts()
        drawHUD()

        -- Flash maze walls
        local flash = math.floor(stateTimer * 4) % 2 == 0
        if flash then
            api.gfx.setColor(1, 1, 1, 0.3)
            api.gfx.rectangle("fill", 0, 0, screenW, screenH)
        end
        drawCentered("LEVEL CLEAR!", screenH / 2 - 4, 1, 0, 1, 0)

    elseif state == "gameover" then
        drawMaze()
        drawDots()
        drawHUD()

        -- Darken
        api.gfx.setColor(0, 0, 0, 0.6)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        drawCentered("GAME OVER", screenH / 2 - 10, 2, 1, 0, 0)
        local blink = math.floor(stateTimer * 3) % 2 == 0
        if blink then
            drawCentered("PRESS ENTER", screenH / 2 + 14, 1, 1, 1, 1)
        end
    end

    -- Reset color
    api.gfx.setColor(1, 1, 1, 1)
end

function Cart.keypressed(key)
    if state == "title" then
        if key == "return" or key == "z" then
            state = "ready"
            stateTimer = 0
        end

    elseif state == "playing" or state == "ready" then
        if key == "left"  or key == "a" then player.nextDir = "left" end
        if key == "right" or key == "d" then player.nextDir = "right" end
        if key == "up"    or key == "w" then player.nextDir = "up" end
        if key == "down"  or key == "s" then player.nextDir = "down" end

    elseif state == "gameover" then
        if key == "return" or key == "z" then
            -- Full restart
            score = 0
            lives = START_LIVES
            level = 1
            GHOST_SPD = 38
            FRIGHT_DUR = 6
            chompHigh = false
            frightTimer = 0
            ghostsEatenCombo = 0
            package.loaded["cartridges.pacmaze.levels.LEVEL_01"] = nil
            loadLevel()
            state = "ready"
            stateTimer = 0
        end
    end
end

function Cart.unload()
    api.music.stop()
    -- Clean up require cache
    package.loaded["cartridges.pacmaze.levels.LEVEL_01"] = nil
end

return Cart
