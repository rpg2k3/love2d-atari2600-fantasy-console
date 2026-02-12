-- main.lua  RhythmGroove - Atari-style rhythm dance game
local Cart = {}

local api
local song           -- chart data from SONG_01
local SW, SH         -- screen width/height

-- States
local STATE_TITLE   = "title"
local STATE_PLAYING = "playing"
local STATE_RESULTS = "results"
local gameState

-- Layout
local LANE_W    = 18     -- pixels per lane (at 2x sprite scale = 16 + 2 gap)
local JUDGE_Y            -- y of judgement line
local TOP_Y     = -16    -- notes spawn above screen
local laneX     = {}     -- center-x per lane [1..4]
local LANE_COLORS = {7, 27, 19, 15}  -- palette: orange-red, blue, lime, yellow
local LANE_NAMES  = {"LEFT","DOWN","UP","RIGHT"}

-- Approach / scroll
local BASE_APPROACH = 2.2  -- seconds at start (slow)
local MIN_APPROACH  = 1.1  -- seconds at end (fast)

-- Judgement windows (seconds)
local PERFECT_W = 0.08
local GOOD_W    = 0.16
-- Assist mode widens these
local ASSIST_PERFECT = 0.13
local ASSIST_GOOD    = 0.24

-- Scoring
local PERFECT_PTS = 100
local GOOD_PTS    = 50

-- Playback state
local songTime       -- seconds elapsed since play started
local beatTime       -- seconds per beat
local notePool       -- all notes with state
local nextSpawn      -- index of next note to activate
local activeNotes    -- currently visible notes
local score, combo, maxCombo
local perfects, goods, misses
local totalNotes
local songFinished

-- Assist mode
local assistMode = false

-- Visual flash
local judgeFlash = {0,0,0,0}  -- per-lane flash timer
local hitAnim    = {}          -- recent hit animations

-- Dancer
local dancerPose  = 0   -- 0=idle, 1-4 = lane direction
local dancerTimer = 0

-- Title blink
local titleBlink = 0

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

local function getApproachTime()
    if not song then return BASE_APPROACH end
    local progress = songTime / (song.length * beatTime)
    return lerp(BASE_APPROACH, MIN_APPROACH, progress)
end

local function getPerfectW()
    return assistMode and ASSIST_PERFECT or PERFECT_W
end

local function getGoodW()
    return assistMode and ASSIST_GOOD or GOOD_W
end

-----------------------------------------------------------------------
-- Draw helpers
-----------------------------------------------------------------------
local function drawArrowAt(lane, x, y, alpha)
    if alpha and alpha < 1 then
        api.gfx.setColor(alpha, alpha, alpha, alpha)
    else
        api.gfx.setColor(1, 1, 1, 1)
    end
    api.sprite.draw(lane, x, y, false, false, 2)
    api.gfx.setColor(1, 1, 1, 1)
end

local function drawDancer(x, y)
    local pose = dancerPose
    -- Head
    api.gfx.setColor(0.9, 0.85, 0.7, 1)
    api.gfx.rectangle("fill", x+3, y, 10, 10)
    -- Eyes
    api.gfx.setColor(0.1, 0.1, 0.1, 1)
    api.gfx.rectangle("fill", x+5, y+3, 2, 2)
    api.gfx.rectangle("fill", x+9, y+3, 2, 2)
    -- Body
    api.gfx.setColor(0.2, 0.6, 0.9, 1)
    api.gfx.rectangle("fill", x+4, y+11, 8, 14)
    -- Arms + Legs based on pose
    if pose == 1 then       -- left
        api.gfx.setColor(0.9, 0.85, 0.7, 1)
        api.gfx.rectangle("fill", x-4, y+12, 8, 3)   -- left arm out
        api.gfx.rectangle("fill", x+12, y+14, 5, 3)   -- right arm down
        api.gfx.setColor(0.15, 0.3, 0.6, 1)
        api.gfx.rectangle("fill", x+2, y+25, 4, 10)   -- left leg
        api.gfx.rectangle("fill", x+10, y+25, 4, 10)  -- right leg
    elseif pose == 2 then   -- down
        api.gfx.setColor(0.9, 0.85, 0.7, 1)
        api.gfx.rectangle("fill", x-2, y+14, 6, 3)
        api.gfx.rectangle("fill", x+12, y+14, 6, 3)
        api.gfx.setColor(0.15, 0.3, 0.6, 1)
        api.gfx.rectangle("fill", x+1, y+25, 5, 7)    -- squat
        api.gfx.rectangle("fill", x+10, y+25, 5, 7)
    elseif pose == 3 then   -- up
        api.gfx.setColor(0.9, 0.85, 0.7, 1)
        api.gfx.rectangle("fill", x+1, y+2, 3, 10)    -- left arm up
        api.gfx.rectangle("fill", x+12, y+2, 3, 10)   -- right arm up
        api.gfx.setColor(0.15, 0.3, 0.6, 1)
        api.gfx.rectangle("fill", x+4, y+25, 4, 10)
        api.gfx.rectangle("fill", x+8, y+25, 4, 10)
    elseif pose == 4 then   -- right
        api.gfx.setColor(0.9, 0.85, 0.7, 1)
        api.gfx.rectangle("fill", x-1, y+14, 5, 3)    -- left arm down
        api.gfx.rectangle("fill", x+12, y+12, 8, 3)   -- right arm out
        api.gfx.setColor(0.15, 0.3, 0.6, 1)
        api.gfx.rectangle("fill", x+2, y+25, 4, 10)
        api.gfx.rectangle("fill", x+10, y+25, 4, 10)
    else                    -- idle
        api.gfx.setColor(0.9, 0.85, 0.7, 1)
        api.gfx.rectangle("fill", x-1, y+12, 5, 3)
        api.gfx.rectangle("fill", x+12, y+12, 5, 3)
        api.gfx.setColor(0.15, 0.3, 0.6, 1)
        api.gfx.rectangle("fill", x+4, y+25, 4, 10)
        api.gfx.rectangle("fill", x+8, y+25, 4, 10)
    end
end

local function drawLaneBG()
    local totalW = 4 * LANE_W
    local startX = laneX[1] - 1
    -- Dark lane background
    api.gfx.setColor(0.06, 0.06, 0.1, 0.9)
    api.gfx.rectangle("fill", startX, 0, totalW, SH)
    -- Lane dividers
    for i = 0, 4 do
        api.gfx.setColor(0.2, 0.2, 0.3, 0.5)
        api.gfx.rectangle("fill", startX + i * LANE_W, 0, 1, SH)
    end
end

-----------------------------------------------------------------------
-- Game logic
-----------------------------------------------------------------------
local function resetGame()
    songTime     = -2.0  -- 2-second countdown before beat 1
    notePool     = {}
    nextSpawn    = 1
    activeNotes  = {}
    score        = 0
    combo        = 0
    maxCombo     = 0
    perfects     = 0
    goods        = 0
    misses       = 0
    songFinished = false
    dancerPose   = 0
    dancerTimer  = 0
    hitAnim      = {}
    for i = 1, 4 do judgeFlash[i] = 0 end

    -- Build note pool from chart
    for i, n in ipairs(song.notes) do
        notePool[i] = {
            beat   = n.beat,
            lane   = n.lane,
            time   = (n.beat - 1) * beatTime,  -- seconds
            active = false,
            hit    = false,
            missed = false,
        }
    end
    totalNotes = #notePool
end

local function startPlaying()
    resetGame()
    gameState = STATE_PLAYING
    -- Music starts when songTime reaches 0 (see update countdown logic)
end

local function hitNote(note, quality)
    note.hit = true
    if quality == "perfect" then
        perfects = perfects + 1
        score = score + PERFECT_PTS * (1 + math.floor(combo / 10))
        api.sfx.play("perfect")
    else
        goods = goods + 1
        score = score + GOOD_PTS * (1 + math.floor(combo / 10))
        api.sfx.play("good")
    end
    combo = combo + 1
    if combo > maxCombo then maxCombo = combo end
    judgeFlash[note.lane] = 0.25
    dancerPose  = note.lane
    dancerTimer = 0.35
    -- Add hit animation
    hitAnim[#hitAnim+1] = {
        x = laneX[note.lane], y = JUDGE_Y,
        timer = 0.4, quality = quality, lane = note.lane,
    }
end

local function missNote(note)
    note.missed = true
    misses = misses + 1
    combo  = 0
    api.sfx.play("miss")
end

local function tryHitLane(lane)
    -- Find closest active unhit note in this lane within good window
    local best     = nil
    local bestDist = math.huge
    local gw = getGoodW()
    for _, n in ipairs(activeNotes) do
        if n.lane == lane and not n.hit and not n.missed then
            local dist = math.abs(n.time - songTime)
            if dist <= gw and dist < bestDist then
                best = n
                bestDist = dist
            end
        end
    end
    if best then
        local pw = getPerfectW()
        if bestDist <= pw then
            hitNote(best, "perfect")
        else
            hitNote(best, "good")
        end
    end
end

-----------------------------------------------------------------------
-- Cart interface
-----------------------------------------------------------------------
function Cart.load(a)
    api = a
    SW = api.getWidth()
    SH = api.getHeight()
    JUDGE_Y = SH - 30

    -- Calculate lane positions (centered)
    local totalW = 4 * LANE_W
    local startX = math.floor((SW - totalW) / 2)
    for i = 1, 4 do
        laneX[i] = startX + (i - 1) * LANE_W + 1  -- +1 for centering in lane
    end

    -- Load chart
    song = require("cartridges.rhythmgroove.levels.SONG_01")
    beatTime = 60 / song.bpm

    -- Define SFX
    api.sfx.setPreset("perfect", {
        wave="square", freq=880, duration=0.1, volume=0.3,
        attack=0.005, decay=0.02, sustain=0.3, release=0.05, freqSweep=440,
    })
    api.sfx.setPreset("good", {
        wave="triangle", freq=660, duration=0.1, volume=0.25,
        attack=0.005, decay=0.02, sustain=0.2, release=0.05, freqSweep=200,
    })
    api.sfx.setPreset("miss", {
        wave="noise", freq=120, duration=0.15, volume=0.2,
        attack=0.005, decay=0.05, sustain=0.1, release=0.05, freqSweep=-60,
    })
    api.sfx.setPreset("countdown", {
        wave="square", freq=440, duration=0.12, volume=0.25,
        attack=0.005, decay=0.02, sustain=0.3, release=0.05, freqSweep=0,
    })

    gameState = STATE_TITLE
    titleBlink = 0
end

function Cart.update(dt)
    titleBlink = titleBlink + dt

    if gameState == STATE_PLAYING then
        local prevTime = songTime
        songTime = songTime + dt

        -- Countdown beeps
        if prevTime < -1 and songTime >= -1 then api.sfx.play("countdown") end
        if prevTime < 0  and songTime >= 0  then api.sfx.play("countdown") end

        -- Start music at beat 1
        if prevTime < 0 and songTime >= 0 then
            api.music.play()
        end

        local approach = getApproachTime()

        -- Spawn notes that should become visible
        while nextSpawn <= #notePool do
            local n = notePool[nextSpawn]
            if songTime >= n.time - approach then
                n.active = true
                activeNotes[#activeNotes+1] = n
                nextSpawn = nextSpawn + 1
            else
                break
            end
        end

        -- Update active notes
        local gw = getGoodW()
        local newActive = {}
        for _, n in ipairs(activeNotes) do
            if n.hit then
                -- keep briefly for fade-out, then drop
            elseif n.missed then
                -- already counted
            elseif songTime > n.time + gw then
                -- missed
                missNote(n)
            else
                newActive[#newActive+1] = n
            end
        end
        activeNotes = newActive

        -- Assist mode: auto-hit notes about to be missed
        if assistMode then
            for _, n in ipairs(activeNotes) do
                if not n.hit and not n.missed then
                    local diff = songTime - n.time
                    if diff > gw * 0.85 then
                        hitNote(n, "good")
                    end
                end
            end
        end

        -- Check song end
        local songLen = song.length * beatTime
        if songTime > songLen + 1.5 then
            gameState = STATE_RESULTS
            api.music.stop()
        end

        -- Update flash timers
        for i = 1, 4 do
            if judgeFlash[i] > 0 then
                judgeFlash[i] = judgeFlash[i] - dt
            end
        end

        -- Update dancer
        if dancerTimer > 0 then
            dancerTimer = dancerTimer - dt
            if dancerTimer <= 0 then
                dancerPose = 0
            end
        end

        -- Update hit animations
        local newHitAnim = {}
        for _, h in ipairs(hitAnim) do
            h.timer = h.timer - dt
            if h.timer > 0 then
                newHitAnim[#newHitAnim+1] = h
            end
        end
        hitAnim = newHitAnim
    end
end

function Cart.draw()
    -- Background
    api.gfx.setColor(0.02, 0.02, 0.05, 1)
    api.gfx.rectangle("fill", 0, 0, SW, SH)

    if gameState == STATE_TITLE then
        Cart.drawTitle()
    elseif gameState == STATE_PLAYING then
        Cart.drawPlaying()
    elseif gameState == STATE_RESULTS then
        Cart.drawResults()
    end
end

-----------------------------------------------------------------------
-- Title screen
-----------------------------------------------------------------------
function Cart.drawTitle()
    -- Title
    local title = "RHYTHMGROOVE"
    local tw = api.font.measure(title, 2)
    local c = {0.95, 0.75, 0.2}
    api.font.print(title, math.floor((SW - tw) / 2), 20, 2, c[1], c[2], c[3])

    -- Subtitle
    local sub = "DANCE TO THE BEAT!"
    local sw2 = api.font.measure(sub, 1)
    api.font.print(sub, math.floor((SW - sw2) / 2), 42, 1, 0.7, 0.7, 0.8)

    -- Draw demo arrows
    local cx = math.floor(SW / 2)
    for i = 1, 4 do
        local ax = cx - 36 + (i - 1) * 20
        drawArrowAt(i, ax, 60, 0.8)
    end

    -- Instructions
    local y = 95
    local lines = {
        "ARROW KEYS: HIT NOTES",
        "MATCH THE RHYTHM!",
        "",
        "PERFECT = 100 PTS",
        "GOOD    =  50 PTS",
        "",
        "COMBO BONUS EVERY 10!",
    }
    for _, line in ipairs(lines) do
        if line ~= "" then
            local lw = api.font.measure(line, 1)
            api.font.print(line, math.floor((SW - lw) / 2), y, 1, 0.6, 0.6, 0.7)
        end
        y = y + 8
    end

    -- Assist mode indicator
    local assistTxt = "A: ASSIST MODE [" .. (assistMode and "ON" or "OFF") .. "]"
    local aw = api.font.measure(assistTxt, 1)
    local ac = assistMode and {0.3, 0.9, 0.4} or {0.5, 0.5, 0.5}
    api.font.print(assistTxt, math.floor((SW - aw) / 2), SH - 30, 1, ac[1], ac[2], ac[3])

    -- Start prompt
    if math.floor(titleBlink * 2.5) % 2 == 0 then
        local start = "PRESS Z TO START"
        local startW = api.font.measure(start, 1)
        api.font.print(start, math.floor((SW - startW) / 2), SH - 18, 1, 1, 1, 1)
    end
end

-----------------------------------------------------------------------
-- Playing screen
-----------------------------------------------------------------------
function Cart.drawPlaying()
    drawLaneBG()

    local approach = getApproachTime()

    -- Judgement line
    for i = 1, 4 do
        local glow = judgeFlash[i] > 0 and 0.9 or 0.3
        api.gfx.setColor(glow, glow, glow, glow)
        api.sprite.draw(i, laneX[i], JUDGE_Y, false, false, 2)
    end

    -- Judgement line bar
    local barX = laneX[1] - 1
    local barW = 4 * LANE_W
    api.gfx.setColor(0.5, 0.5, 0.6, 0.6)
    api.gfx.rectangle("fill", barX, JUDGE_Y + 16, barW, 1)

    -- Active notes
    for _, n in ipairs(activeNotes) do
        if not n.hit and not n.missed then
            local remaining = n.time - songTime
            local progress = 1 - (remaining / approach)
            local ny = TOP_Y + progress * (JUDGE_Y - TOP_Y)
            if ny >= -16 and ny <= SH then
                drawArrowAt(n.lane, laneX[n.lane], math.floor(ny), 1)
            end
        end
    end

    -- Hit animations (expanding ring)
    for _, h in ipairs(hitAnim) do
        local t = 1 - (h.timer / 0.4)
        local alpha = 1 - t
        local expand = t * 6
        local c = LANE_COLORS[h.lane]
        local pc = api.palette.get(c)
        api.gfx.setColor(pc[1], pc[2], pc[3], alpha * 0.7)
        api.gfx.rectangle("fill",
            h.x - expand, h.y - expand,
            16 + expand * 2, 16 + expand * 2)
        -- Quality text
        if h.timer > 0.2 then
            local qt = h.quality == "perfect" and "PERFECT!" or "GOOD"
            local qw = api.font.measure(qt, 1)
            local qc = h.quality == "perfect" and {1, 1, 0.3} or {0.4, 0.9, 0.4}
            api.font.print(qt, h.x + 8 - math.floor(qw / 2),
                math.floor(h.y - 8 - (1-h.timer/0.4)*12), 1, qc[1], qc[2], qc[3])
        end
    end

    -- Dancer (right side)
    local dancerX = laneX[4] + LANE_W + 8
    if dancerX + 20 < SW then
        drawDancer(dancerX, SH - 60)
    end

    -- Score + combo (top)
    api.font.print("SCORE", 2, 2, 1, 0.6, 0.6, 0.7)
    api.font.print(tostring(score), 2, 10, 1, 1, 1, 1)

    if combo > 1 then
        local ct = tostring(combo) .. "X"
        local cw = api.font.measure(ct, 1)
        api.font.print(ct, SW - cw - 2, 2, 1, 1, 0.9, 0.2)
        api.font.print("COMBO", SW - api.font.measure("COMBO",1) - 2, 10, 1, 0.6, 0.6, 0.7)
    end

    -- Countdown
    if songTime < 0 then
        local cd = math.ceil(-songTime)
        local cdStr = tostring(cd)
        local cdW = api.font.measure(cdStr, 3)
        local flash = math.abs(math.sin(songTime * 4))
        api.font.print(cdStr, math.floor((SW-cdW)/2), math.floor(SH/2)-10, 3, 1, flash, flash)
    end

    -- Assist indicator
    if assistMode then
        api.font.print("ASSIST", 2, SH - 8, 1, 0.3, 0.8, 0.3)
    end

    -- Progress bar (bottom)
    if songTime > 0 then
        local songLen = song.length * beatTime
        local prog = math.min(1, songTime / songLen)
        api.gfx.setColor(0.15, 0.15, 0.2, 1)
        api.gfx.rectangle("fill", 0, SH - 2, SW, 2)
        api.gfx.setColor(0.3, 0.7, 0.9, 1)
        api.gfx.rectangle("fill", 0, SH - 2, math.floor(SW * prog), 2)
    end
end

-----------------------------------------------------------------------
-- Results screen
-----------------------------------------------------------------------
function Cart.drawResults()
    -- Title
    local title = "RESULTS"
    local tw = api.font.measure(title, 2)
    api.font.print(title, math.floor((SW - tw) / 2), 12, 2, 0.95, 0.75, 0.2)

    local y = 38
    local x = 20
    local gap = 10

    -- Score
    api.font.print("SCORE", x, y, 1, 0.6, 0.6, 0.7)
    local sv = tostring(score)
    api.font.print(sv, SW - api.font.measure(sv, 1) - x, y, 1, 1, 1, 1)
    y = y + gap

    -- Max combo
    api.font.print("MAX COMBO", x, y, 1, 0.6, 0.6, 0.7)
    local mc = tostring(maxCombo) .. "X"
    api.font.print(mc, SW - api.font.measure(mc, 1) - x, y, 1, 1, 0.9, 0.2)
    y = y + gap

    -- Perfects
    api.font.print("PERFECT", x, y, 1, 1, 1, 0.3)
    local pv = tostring(perfects)
    api.font.print(pv, SW - api.font.measure(pv, 1) - x, y, 1, 1, 1, 0.3)
    y = y + gap

    -- Goods
    api.font.print("GOOD", x, y, 1, 0.4, 0.9, 0.4)
    local gv = tostring(goods)
    api.font.print(gv, SW - api.font.measure(gv, 1) - x, y, 1, 0.4, 0.9, 0.4)
    y = y + gap

    -- Misses
    api.font.print("MISS", x, y, 1, 0.9, 0.3, 0.3)
    local mv = tostring(misses)
    api.font.print(mv, SW - api.font.measure(mv, 1) - x, y, 1, 0.9, 0.3, 0.3)
    y = y + gap + 4

    -- Accuracy
    local hitCount = perfects + goods
    local acc = totalNotes > 0 and math.floor(hitCount / totalNotes * 100) or 0
    api.font.print("ACCURACY", x, y, 1, 0.6, 0.6, 0.7)
    local av = acc .. "%"
    api.font.print(av, SW - api.font.measure(av, 1) - x, y, 1, 1, 1, 1)
    y = y + gap + 4

    -- Grade
    local grade, gc
    if acc >= 95 then     grade = "S"  gc = {1, 0.85, 0.1}
    elseif acc >= 85 then grade = "A"  gc = {0.3, 0.9, 0.3}
    elseif acc >= 70 then grade = "B"  gc = {0.3, 0.7, 0.9}
    elseif acc >= 50 then grade = "C"  gc = {0.9, 0.6, 0.2}
    else                  grade = "D"  gc = {0.9, 0.3, 0.3}
    end
    local gw2 = api.font.measure(grade, 3)
    api.font.print(grade, math.floor((SW - gw2) / 2), y, 3, gc[1], gc[2], gc[3])
    y = y + 26

    -- Assist tag
    if assistMode then
        local at = "(ASSIST MODE)"
        local atw = api.font.measure(at, 1)
        api.font.print(at, math.floor((SW - atw)/2), y, 1, 0.4, 0.7, 0.4)
        y = y + 10
    end

    -- Restart prompt
    if math.floor(titleBlink * 2.5) % 2 == 0 then
        local rt = "Z: RETRY"
        local rw = api.font.measure(rt, 1)
        api.font.print(rt, math.floor((SW - rw) / 2), SH - 18, 1, 1, 1, 1)
    end
end

-----------------------------------------------------------------------
-- Input
-----------------------------------------------------------------------
function Cart.keypressed(key)
    if gameState == STATE_TITLE then
        if key == "z" or key == "j" or key == "return" then
            startPlaying()
        elseif key == "a" then
            assistMode = not assistMode
        end

    elseif gameState == STATE_PLAYING then
        -- Lane hits via arrow keys
        if     key == "left"  then tryHitLane(1)
        elseif key == "down"  then tryHitLane(2)
        elseif key == "up"    then tryHitLane(3)
        elseif key == "right" then tryHitLane(4)
        end

    elseif gameState == STATE_RESULTS then
        if key == "z" or key == "j" or key == "return" then
            gameState = STATE_TITLE
        end
    end
end

function Cart.unload()
    api.music.stop()
end

return Cart
