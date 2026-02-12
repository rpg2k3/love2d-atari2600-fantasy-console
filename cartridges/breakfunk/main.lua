-- cartridges/breakfunk/main.lua
-- BreakFunk: Atari 2600-style Breakout with funky multi-channel music
-- Paddle + ball + brick grid, combo system, screen shake, procedural SFX

local Cart = {}

-- ============================================================
-- CONSTANTS
-- ============================================================
local PADDLE_W     = 16
local PADDLE_H     = 4
local PADDLE_SPD   = 90    -- pixels/sec
local BALL_W       = 4
local BALL_H       = 4
local START_LIVES  = 3
local WALL_TOP     = 12    -- top boundary (below score bar)
local WALL_LEFT    = 0
local SERVE_DELAY  = 1.0   -- seconds before auto-serve
local MAX_BALL_SPD = 160
local SPEED_INC    = 4     -- speed increase per brick hit

-- ============================================================
-- STATE
-- ============================================================
local api
local screenW, screenH
local state           -- "title", "serve", "playing", "dying", "gameover", "win"
local stateTimer
local score, lives, level
local paddle          -- { x, y }
local ball            -- { x, y, dx, dy, speed }
local bricks          -- array from level data
local bricksAlive     -- count of living bricks
local combo           -- consecutive brick hits without paddle bounce
local shakeTimer      -- screen shake countdown
local shakeX, shakeY  -- current shake offset
local wallRight       -- right boundary

-- ============================================================
-- SFX PRESETS (procedural)
-- ============================================================
local function setupSFX()
    api.sfx.setPreset("paddle_hit", {
        wave = "square", freq = 300, duration = 0.08, volume = 0.3,
        attack = 0.005, decay = 0.02, sustain = 0.3, release = 0.03,
        freqSweep = 150,
    })
    api.sfx.setPreset("wall_hit", {
        wave = "triangle", freq = 250, duration = 0.06, volume = 0.2,
        attack = 0.005, decay = 0.02, sustain = 0.2, release = 0.02,
        freqSweep = 80,
    })
    api.sfx.setPreset("brick_break", {
        wave = "square", freq = 500, duration = 0.1, volume = 0.35,
        attack = 0.005, decay = 0.03, sustain = 0.3, release = 0.03,
        freqSweep = 300,
    })
    api.sfx.setPreset("lose_life", {
        wave = "square", freq = 400, duration = 0.5, volume = 0.4,
        attack = 0.01, decay = 0.1, sustain = 0.3, release = 0.2,
        freqSweep = -350,
    })
end

-- ============================================================
-- LEVEL LOADING
-- ============================================================
local function loadLevel()
    package.loaded["cartridges.breakfunk.levels.LEVEL_01"] = nil
    local lvl = require("cartridges.breakfunk.levels.LEVEL_01")

    bricks = {}
    bricksAlive = 0
    for _, b in ipairs(lvl.bricks) do
        bricks[#bricks + 1] = {
            x      = b.x,
            y      = b.y,
            w      = b.w,
            h      = b.h,
            sprite = b.sprite,
            score  = b.score,
            alive  = true,
        }
        bricksAlive = bricksAlive + 1
    end

    paddle = {
        x = math.floor((screenW - PADDLE_W) / 2),
        y = lvl.paddleY,
    }

    ball = {
        x     = 0,
        y     = 0,
        dx    = 0,
        dy    = 0,
        speed = lvl.ballSpeed,
    }

    wallRight = screenW
end

-- Place ball on paddle for serve
local function resetBall()
    ball.x  = paddle.x + math.floor(PADDLE_W / 2) - math.floor(BALL_W / 2)
    ball.y  = paddle.y - BALL_H
    ball.dx = 0
    ball.dy = 0
end

-- Launch ball upward with slight angle
local function serveBall()
    local angle = -0.8 + math.random() * 0.6  -- slight random bias
    ball.dx = math.sin(angle)
    ball.dy = math.cos(angle) * -1  -- always upward
    -- Normalize
    local len = math.sqrt(ball.dx * ball.dx + ball.dy * ball.dy)
    ball.dx = ball.dx / len
    ball.dy = ball.dy / len
end

-- ============================================================
-- SCREEN SHAKE
-- ============================================================
local function triggerShake()
    shakeTimer = 0.12
end

local function updateShake(dt)
    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        local intensity = math.min(shakeTimer / 0.12, 1.0) * 2
        shakeX = math.floor((math.random() * 2 - 1) * intensity + 0.5)
        shakeY = math.floor((math.random() * 2 - 1) * intensity + 0.5)
    else
        shakeTimer = 0
        shakeX = 0
        shakeY = 0
    end
end

-- ============================================================
-- COMBO / MUSIC VOLUME
-- ============================================================
local function updateMusicVolume()
    -- Subtle volume increase with combo: base 0.7, up to 1.0
    local vol = 0.7 + math.min(combo, 10) * 0.03
    api.music.setVolume(vol)
end

-- ============================================================
-- COLLISION HELPERS
-- ============================================================
-- AABB overlap test
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- ============================================================
-- BALL UPDATE
-- ============================================================
local function updateBall(dt)
    local speed = ball.speed
    local nx = ball.x + ball.dx * speed * dt
    local ny = ball.y + ball.dy * speed * dt

    -- Wall collisions (left/right)
    if nx < WALL_LEFT then
        nx = WALL_LEFT
        ball.dx = -ball.dx
        api.sfx.play("wall_hit")
    elseif nx + BALL_W > wallRight then
        nx = wallRight - BALL_W
        ball.dx = -ball.dx
        api.sfx.play("wall_hit")
    end

    -- Top wall
    if ny < WALL_TOP then
        ny = WALL_TOP
        ball.dy = -ball.dy
        api.sfx.play("wall_hit")
    end

    -- Bottom: lose life
    if ny + BALL_H > screenH then
        state = "dying"
        stateTimer = 0
        combo = 0
        updateMusicVolume()
        api.sfx.play("lose_life")
        api.music.stop()
        return
    end

    -- Paddle collision
    if ball.dy > 0 and aabb(nx, ny, BALL_W, BALL_H, paddle.x, paddle.y, PADDLE_W, PADDLE_H) then
        ny = paddle.y - BALL_H
        -- Angle based on hit position: center=straight up, edges=angled
        local hitPos = (nx + BALL_W / 2 - paddle.x) / PADDLE_W  -- 0..1
        local angle = (hitPos - 0.5) * 1.2  -- -0.6 to 0.6 radians
        ball.dx = math.sin(angle)
        ball.dy = -math.abs(math.cos(angle))
        -- Normalize
        local len = math.sqrt(ball.dx * ball.dx + ball.dy * ball.dy)
        ball.dx = ball.dx / len
        ball.dy = ball.dy / len
        -- Reset combo on paddle hit
        combo = 0
        updateMusicVolume()
        api.sfx.play("paddle_hit")
    end

    -- Brick collisions
    for i = 1, #bricks do
        local b = bricks[i]
        if b.alive and aabb(nx, ny, BALL_W, BALL_H, b.x, b.y, b.w, b.h) then
            b.alive = false
            bricksAlive = bricksAlive - 1
            score = score + b.score * (1 + math.floor(combo / 3))
            combo = combo + 1
            updateMusicVolume()
            api.sfx.play("brick_break")
            triggerShake()

            -- Speed up slightly
            ball.speed = math.min(ball.speed + SPEED_INC, MAX_BALL_SPD)

            -- Determine bounce direction based on overlap depth
            local overlapL = (nx + BALL_W) - b.x
            local overlapR = (b.x + b.w) - nx
            local overlapT = (ny + BALL_H) - b.y
            local overlapB = (b.y + b.h) - ny
            local minOverlapX = math.min(overlapL, overlapR)
            local minOverlapY = math.min(overlapT, overlapB)

            if minOverlapX < minOverlapY then
                ball.dx = -ball.dx
                if overlapL < overlapR then
                    nx = b.x - BALL_W
                else
                    nx = b.x + b.w
                end
            else
                ball.dy = -ball.dy
                if overlapT < overlapB then
                    ny = b.y - BALL_H
                else
                    ny = b.y + b.h
                end
            end

            -- Check win
            if bricksAlive <= 0 then
                state = "win"
                stateTimer = 0
                api.music.stop()
                break
            end

            -- Only bounce off one brick per frame
            break
        end
    end

    ball.x = nx
    ball.y = ny
end

-- ============================================================
-- DRAWING HELPERS
-- ============================================================
local function drawCentered(text, y, scale, r, g, b)
    scale = scale or 1
    local tw = api.font.measure(text, scale)
    local x = math.floor((screenW - tw) / 2)
    api.font.print(text, x, y, scale, r or 1, g or 1, b or 1, 1)
end

local function drawBricks()
    for i = 1, #bricks do
        local b = bricks[i]
        if b.alive then
            -- At high combo, bricks get a brightness flash via alternating sprite
            api.sprite.draw(b.sprite, b.x, b.y)
        end
    end
end

local function drawPaddle()
    api.sprite.draw(1, paddle.x, paddle.y)
end

local function drawBall()
    api.sprite.draw(2, math.floor(ball.x), math.floor(ball.y))
end

local function drawHUD()
    -- Score
    api.palette.setColor(4)
    api.font.print("SCORE", 1, 1, 1, 1, 1, 1, 1)
    api.palette.setColor(15)
    api.font.print(tostring(score), 26, 1, 1, 1, 1, 0, 1)

    -- Combo display (when active)
    if combo > 1 then
        api.palette.setColor(11)
        local comboTxt = "X" .. tostring(combo)
        local tw = api.font.measure(comboTxt, 1)
        api.font.print(comboTxt, math.floor(screenW / 2 - tw / 2), 1, 1, 1, 0.5, 0, 1)
    end

    -- Lives
    local livesX = screenW - 6
    for i = 1, lives - 1 do
        api.sprite.draw(7, livesX - (i * 7), 1)
    end
end

local function drawField()
    -- Top border line
    api.palette.setColor(26)
    api.gfx.rectangle("fill", 0, WALL_TOP - 1, screenW, 1)
end

-- ============================================================
-- CART INTERFACE
-- ============================================================
function Cart.load(engineAPI)
    api = engineAPI
    screenW = api.getWidth()
    screenH = api.getHeight()

    setupSFX()

    score      = 0
    lives      = START_LIVES
    level      = 1
    combo      = 0
    shakeTimer = 0
    shakeX     = 0
    shakeY     = 0
    stateTimer = 0

    loadLevel()
    resetBall()

    -- Load multi-channel song
    local content = require("cartridges.breakfunk.content")
    api.music.loadSong(content.music)

    state = "title"
end

function Cart.update(dt)
    if dt > 0.05 then dt = 0.05 end

    updateShake(dt)

    if state == "title" then
        stateTimer = stateTimer + dt

    elseif state == "serve" then
        stateTimer = stateTimer + dt
        -- Paddle movement during serve
        if api.input.isDown("left") then
            paddle.x = math.max(WALL_LEFT, paddle.x - PADDLE_SPD * dt)
        end
        if api.input.isDown("right") then
            paddle.x = math.min(wallRight - PADDLE_W, paddle.x + PADDLE_SPD * dt)
        end
        -- Ball tracks paddle
        resetBall()
        -- Auto-serve after delay or on keypress (handled in keypressed)
        if stateTimer >= SERVE_DELAY then
            -- Wait for input
        end

    elseif state == "playing" then
        api.music.update(dt)

        -- Paddle movement
        if api.input.isDown("left") then
            paddle.x = math.max(WALL_LEFT, paddle.x - PADDLE_SPD * dt)
        end
        if api.input.isDown("right") then
            paddle.x = math.min(wallRight - PADDLE_W, paddle.x + PADDLE_SPD * dt)
        end

        updateBall(dt)

    elseif state == "dying" then
        stateTimer = stateTimer + dt
        if stateTimer >= 1.0 then
            lives = lives - 1
            if lives <= 0 then
                state = "gameover"
                stateTimer = 0
            else
                resetBall()
                state = "serve"
                stateTimer = 0
                api.music.play()
            end
        end

    elseif state == "win" then
        stateTimer = stateTimer + dt
        if stateTimer >= 2.0 then
            level = level + 1
            loadLevel()
            resetBall()
            -- Increase base ball speed for next level
            ball.speed = ball.speed + 10
            state = "serve"
            stateTimer = 0
            api.music.play()
        end

    elseif state == "gameover" then
        stateTimer = stateTimer + dt
    end
end

function Cart.draw()
    -- Clear to black
    api.gfx.setColor(0, 0, 0, 1)
    api.gfx.rectangle("fill", 0, 0, screenW, screenH)

    if state == "title" then
        -- Draw bricks as preview
        api.gfx.push()
        drawField()
        drawBricks()
        api.gfx.pop()

        -- Darken overlay
        api.gfx.setColor(0, 0, 0, 0.7)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        -- Title
        local blink = math.floor(stateTimer * 3) % 2 == 0
        drawCentered("BREAKFUNK", screenH / 2 - 30, 2, 1, 0.5, 0)
        drawCentered("BUST BRICKS", screenH / 2 - 6, 1, 1, 1, 1)
        drawCentered("GET FUNKY", screenH / 2 + 6, 1, 1, 1, 1)
        if blink then
            drawCentered("PRESS ENTER", screenH / 2 + 24, 1, 1, 1, 0)
        end
        drawCentered("BY 9LIVESK9", screenH - 14, 1, 0.5, 0.5, 0.5)

    elseif state == "serve" then
        -- Apply shake to world only
        api.gfx.push()
        api.gfx.translate(shakeX, shakeY)
        drawField()
        drawBricks()
        drawPaddle()
        drawBall()
        api.gfx.pop()

        drawHUD()

        -- "READY" text
        local blink = math.floor(stateTimer * 4) % 2 == 0
        if blink then
            drawCentered("PRESS Z", screenH / 2 + 20, 1, 1, 1, 0)
        end

    elseif state == "playing" then
        -- Apply shake to world only
        api.gfx.push()
        api.gfx.translate(shakeX, shakeY)
        drawField()
        drawBricks()
        drawPaddle()
        drawBall()
        api.gfx.pop()

        drawHUD()

    elseif state == "dying" then
        api.gfx.push()
        api.gfx.translate(shakeX, shakeY)
        drawField()
        drawBricks()
        drawPaddle()
        -- Flash ball
        local show = math.floor(stateTimer * 8) % 2 == 0
        if show then drawBall() end
        api.gfx.pop()

        drawHUD()

    elseif state == "win" then
        drawField()
        drawPaddle()
        drawHUD()

        -- Flash screen celebration
        local flash = math.floor(stateTimer * 4) % 2 == 0
        if flash then
            api.gfx.setColor(1, 1, 1, 0.15)
            api.gfx.rectangle("fill", 0, 0, screenW, screenH)
        end
        drawCentered("LEVEL CLEAR!", screenH / 2 - 4, 1, 0, 1, 0)

    elseif state == "gameover" then
        drawField()
        drawBricks()
        drawHUD()

        -- Darken
        api.gfx.setColor(0, 0, 0, 0.6)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        drawCentered("GAME OVER", screenH / 2 - 10, 2, 1, 0, 0)
        drawCentered("SCORE " .. tostring(score), screenH / 2 + 10, 1, 1, 1, 1)
        local blink = math.floor(stateTimer * 3) % 2 == 0
        if blink then
            drawCentered("PRESS ENTER", screenH / 2 + 24, 1, 1, 1, 0)
        end
    end

    -- Reset color
    api.gfx.setColor(1, 1, 1, 1)
end

function Cart.keypressed(key)
    if state == "title" then
        if key == "return" or key == "z" then
            state = "serve"
            stateTimer = 0
            api.music.play()
        end

    elseif state == "serve" then
        if key == "z" or key == "return" or key == "space" or key == "up" then
            serveBall()
            state = "playing"
            stateTimer = 0
        end

    elseif state == "gameover" then
        if key == "return" or key == "z" then
            -- Full restart
            score      = 0
            lives      = START_LIVES
            level      = 1
            combo      = 0
            shakeTimer = 0
            shakeX     = 0
            shakeY     = 0
            loadLevel()
            resetBall()
            state = "serve"
            stateTimer = 0
            api.music.play()
        end
    end
end

function Cart.unload()
    api.music.stop()
    package.loaded["cartridges.breakfunk.levels.LEVEL_01"] = nil
    package.loaded["cartridges.breakfunk.content"] = nil
end

return Cart
