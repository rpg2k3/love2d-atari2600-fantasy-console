----------------------------------------------------------------------------
-- PITFALL-ISH  --  Atari 2600 Pitfall! clone for 9LivesK9 Fantasy Console
----------------------------------------------------------------------------
local Cart = {}
local api

-- screen dimensions (set in Cart.load)
local W, H

------------------ CONSTANTS --------------------------------------------------

local HUD_H        = 14
local SKY_Y        = 14
local CANOPY_Y     = 42
local CANOPY_H     = 14
local SURFACE_Y    = 100   -- ground surface top
local GROUND_H     = 8
local TUNNEL_CEIL  = 118
local TUNNEL_FLOOR = 160
local TFLOOR_H     = 8

local PW = 8               -- player width
local PH = 14              -- player height

local RUN_SPEED    = 48
local JUMP_VY      = -155
local GRAVITY      = 430
local CLIMB_SPEED  = 38
local LOG_SPEED    = 34
local VINE_LEN     = 34
local VINE_SPD     = 3.2
local VINE_AMP     = 0.52

local GAME_TIME       = 1200  -- 20 minutes
local WORLD_SEED      = 31415
local SCREEN_COUNT    = 255
local TREASURE_COUNT  = 32
local PIT_PENALTY     = 100
local LOG_PENALTY     = 150
local INVULN_TIME     = 1.5

local TREASURE_TYPES = {
    { name = "MONEY BAG",    value = 2000, col = 15 },
    { name = "SILVER BAR",   value = 3000, col = 4  },
    { name = "GOLD BAR",     value = 4000, col = 14 },
    { name = "DIAMOND RING", value = 5000, col = 28 },
}

local SCREEN_TYPES = {
    "pit_vine","pit_vine","pit_vine",
    "pit_logs","pit_logs",
    "croc_pond","croc_pond",
    "quicksand","quicksand",
    "snake","snake",
    "scorpion","scorpion",
    "fire",
    "open","open",
}

------------------ PALETTE SHORTHAND ------------------------------------------

local C = {
    BLK=1,  DGRY=2, GRY=3,  WHT=4,
    DRED=5, RED=6,  ORED=7, SAL=8,
    BRN=9,  DORG=10,ORG=11, LORG=12,
    DYEL=13,YBRN=14,YEL=15, LYEL=16,
    DGRN=17,GRN=18, LIM=19, LGRN=20,
    DTEA=21,TEA=22, CYA=23, LCYA=24,
    DBLU=25,BLU=26, LBLU=27,SKY=28,
    DPUR=29,PUR=30, LAV=31, PNK=32,
}

------------------ PRNG -------------------------------------------------------

local function lcg(s)
    return (s * 1103515245 + 12345) % 2147483648
end

local function makeRng(seed)
    local st = seed
    local r = {}
    function r:next()    st = lcg(st); return st end
    function r:int(mx)   st = lcg(st); return st % mx end
    function r:float()   st = lcg(st); return st / 2147483648 end
    return r
end

------------------ STATE ------------------------------------------------------

local screens     = {}
local treasureMap = {}
local game, player
local gameTime   = 0
local vineTimer  = 0
local vineAngle  = 0

------------------ WORLD GENERATION -------------------------------------------

local function generateTreasureMap()
    treasureMap = {}
    local rng = makeRng(WORLD_SEED * 12345)
    local cands = {}
    for i = 0, SCREEN_COUNT - 1 do
        cands[#cands+1] = { idx = i, score = rng:next() }
    end
    table.sort(cands, function(a,b) return a.score < b.score end)
    for i = 1, TREASURE_COUNT do
        treasureMap[cands[i].idx] = ((i-1) % 4) + 1
    end
end

local function generateScreen(idx)
    if screens[idx] then return screens[idx] end

    local rng  = makeRng(WORLD_SEED + idx * 7919)
    local ti   = rng:int(#SCREEN_TYPES) + 1
    local st   = SCREEN_TYPES[ti]

    local scr = {
        type   = st,
        gaps   = {},          -- {x,w}
        haz    = {},          -- surface hazards
        thaz   = {},          -- tunnel hazards
        vine   = nil,         -- {x}
        ladder = nil,         -- {x}
        logs   = {},          -- {x,dir}
        treas  = treasureMap[idx],
        treasX = 0, treasY = 0,
    }

    local pitX = 50 + rng:int(35)
    local pitW = 28 + rng:int(18)

    if st == "pit_vine" then
        scr.gaps[1] = { x=pitX, w=pitW }
        scr.vine    = { x=pitX + math.floor(pitW/2) }

    elseif st == "pit_logs" then
        scr.gaps[1] = { x=pitX, w=math.min(pitW,28) }
        local d = rng:int(2)==0 and 1 or -1
        scr.logs[1] = { x = d==1 and -14 or W, dir=d }
        scr.logs[2] = { x = d==1 and -74 or (W+60), dir=d }

    elseif st == "croc_pond" then
        local pw = pitW + 12
        scr.gaps[1] = { x=pitX-4, w=pw }
        for ci = 0, 2 do
            scr.haz[#scr.haz+1] = {
                type="croc", x=pitX + ci*15, y=SURFACE_Y-4, w=12, h=6
            }
        end
        scr.vine = { x = pitX + math.floor(pw/2) }

    elseif st == "quicksand" then
        scr.gaps[1] = { x=pitX, w=pitW }
        scr.haz[1] = { type="quicksand", x=pitX, y=SURFACE_Y, w=pitW, h=8 }
        scr.vine = { x = pitX + math.floor(pitW/2) }

    elseif st == "snake" then
        scr.haz[1] = {
            type="snake", x=35+rng:int(80), y=SURFACE_Y-6, w=12, h=6
        }
        if rng:int(3) > 0 then
            scr.gaps[1] = { x=pitX, w=math.min(pitW,24) }
        end

    elseif st == "scorpion" then
        scr.haz[1] = {
            type="scorpion", x=35+rng:int(80), y=SURFACE_Y-6, w=10, h=6
        }
        scr.ladder = { x = 18 + rng:int(120) }

    elseif st == "fire" then
        scr.haz[1] = {
            type="fire", x=50+rng:int(55), y=SURFACE_Y-10, w=10, h=10
        }
        if rng:int(3) > 0 then
            scr.gaps[1] = { x=pitX, w=math.min(pitW,24) }
        end

    else -- "open"
        if rng:int(3) > 0 then
            scr.gaps[1] = { x=pitX, w=math.min(pitW,20) }
        end
    end

    -- random ladder on some screens
    if not scr.ladder and rng:int(5) == 0 then
        scr.ladder = { x = 15 + rng:int(125) }
    end

    -- tunnel scorpion
    if rng:int(3) == 0 then
        scr.thaz[1] = {
            type="scorpion", x=25+rng:int(105), y=TUNNEL_FLOOR-6, w=10, h=6
        }
    end

    -- place treasure
    if scr.treas then
        local tx = 18 + rng:int(120)
        for _, g in ipairs(scr.gaps) do
            if tx >= g.x - 4 and tx <= g.x + g.w + 4 then
                tx = g.x - 14
                if tx < 8 then tx = g.x + g.w + 8 end
            end
        end
        if tx < 4 then tx = 4 end
        if tx > W - 12 then tx = W - 12 end
        scr.treasX = tx
        scr.treasY = SURFACE_Y - 12
    end

    screens[idx] = scr
    return scr
end

------------------ HELPERS ----------------------------------------------------

local function rect(c, x, y, w, h)
    api.palette.setColor(c)
    api.gfx.rectangle("fill", x, y, w, h)
end

local function pget(idx)
    return api.palette.get(idx)
end

local function fprint(txt, x, y, sc, cidx)
    local c = pget(cidx)
    api.font.print(txt, x, y, sc, c[1], c[2], c[3], c[4])
end

local function fcenter(txt, y, sc, cidx)
    local tw = api.font.measure(txt, sc)
    fprint(txt, math.floor((W - tw) / 2), y, sc, cidx)
end

local function addShake(amt)
    game.shake = amt
    game.shakeT = 0.15
end

local function jumpInput()
    return api.input.justPressed("action1") or api.input.keyPressed("space")
end

------------------ HIGH SCORE -------------------------------------------------

local function saveHS()
    api.save("highscore.lua", { best = game.hs })
end

local function loadHS()
    local d = api.load("highscore.lua")
    if d and d.best then game.hs = d.best end
end

------------------ SFX SETUP --------------------------------------------------

local function setupSFX()
    api.sfx.setPreset("pf_jump", {
        wave="square", freq=200, duration=0.15, volume=0.3,
        attack=0.01, decay=0.05, sustain=0.2, release=0.05,
        freqSweep=400,
    })
    api.sfx.setPreset("pf_vine", {
        wave="triangle", freq=300, duration=0.2, volume=0.25,
        attack=0.01, decay=0.08, sustain=0.3, release=0.08,
        freqSweep=200,
    })
    api.sfx.setPreset("pf_treasure", {
        wave="square", freq=500, duration=0.35, volume=0.35,
        attack=0.01, decay=0.1, sustain=0.5, release=0.12,
        freqSweep=500,
    })
    api.sfx.setPreset("pf_log_hit", {
        wave="noise", freq=120, duration=0.15, volume=0.3,
        attack=0.005, decay=0.06, sustain=0.2, release=0.04,
        freqSweep=-60,
    })
    api.sfx.setPreset("pf_fall", {
        wave="triangle", freq=380, duration=0.3, volume=0.3,
        attack=0.01, decay=0.1, sustain=0.2, release=0.1,
        freqSweep=-320,
    })
    api.sfx.setPreset("pf_death", {
        wave="noise", freq=200, duration=0.45, volume=0.4,
        attack=0.01, decay=0.15, sustain=0.3, release=0.15,
        freqSweep=-150,
    })
    api.sfx.setPreset("pf_ladder", {
        wave="triangle", freq=250, duration=0.1, volume=0.2,
        attack=0.01, decay=0.04, sustain=0.2, release=0.04,
        freqSweep=100,
    })
end

------------------ MUSIC SETUP ------------------------------------------------

local function setupMusic()
    api.music.setInstrument(1, {
        wave="square", attack=0.01, decay=0.08,
        sustain=0.4, release=0.1, volume=0.20,
    })
    api.music.setInstrument(2, {
        wave="triangle", attack=0.01, decay=0.1,
        sustain=0.5, release=0.15, volume=0.25,
    })
    api.music.setInstrument(3, {
        wave="noise", attack=0.005, decay=0.04,
        sustain=0.1, release=0.02, volume=0.15,
    })

    api.music.setBPM(122)
    api.music.setSpeed(4)

    -- Pattern 1 : main jungle melody
    api.music.ensurePattern(1)
    local p1 = api.music.getPattern(1)
    p1.channels[1] = {
        {"E-4",1}, false, {"G-4",1}, false,
        {"A-4",1}, false, {"G-4",1}, false,
        {"E-4",1}, false, {"D-4",1}, false,
        {"E-4",1}, false, false, false,
    }
    p1.channels[2] = {
        {"C-3",2}, false, false, false,
        {"C-3",2}, false, false, false,
        {"A-2",2}, false, false, false,
        {"G-2",2}, false, false, false,
    }
    p1.channels[3] = {
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
    }

    -- Pattern 2 : variation
    api.music.ensurePattern(2)
    local p2 = api.music.getPattern(2)
    p2.channels[1] = {
        {"A-4",1}, false, {"C-5",1}, false,
        {"A-4",1}, false, {"G-4",1}, false,
        {"E-4",1}, false, {"G-4",1}, false,
        {"A-4",1}, false, false, false,
    }
    p2.channels[2] = {
        {"F-2",2}, false, false, false,
        {"F-2",2}, false, false, false,
        {"C-3",2}, false, false, false,
        {"C-3",2}, false, false, false,
    }
    p2.channels[3] = {
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
    }

    -- Pattern 3 : tension / climb
    api.music.ensurePattern(3)
    local p3 = api.music.getPattern(3)
    p3.channels[1] = {
        {"E-4",1}, false, {"E-4",1}, false,
        {"G-4",1}, false, {"G-4",1}, false,
        {"A-4",1}, false, {"A-4",1}, false,
        {"B-4",1}, false, {"C-5",1}, false,
    }
    p3.channels[2] = {
        {"A-2",2}, false, false, false,
        {"A-2",2}, false, false, false,
        {"E-2",2}, false, false, false,
        {"E-2",2}, false, false, false,
    }
    p3.channels[3] = {
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, {"C-3",3}, {"C-4",3}, {"C-3",3},
    }

    -- Pattern 4 : bridge / descending
    api.music.ensurePattern(4)
    local p4 = api.music.getPattern(4)
    p4.channels[1] = {
        {"C-5",1}, false, {"A-4",1}, false,
        {"G-4",1}, false, {"E-4",1}, false,
        {"D-4",1}, false, {"E-4",1}, false,
        {"G-4",1}, false, false, false,
    }
    p4.channels[2] = {
        {"G-2",2}, false, false, false,
        {"G-2",2}, false, false, false,
        {"C-3",2}, false, false, false,
        {"C-3",2}, false, false, false,
    }
    p4.channels[3] = {
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
        {"C-4",3}, false, {"C-3",3}, false,
    }

    api.music.setOrder({1, 2, 1, 3, 1, 4, 2, 3})
end

------------------ INIT -------------------------------------------------------

local function initPlayer()
    player = {
        x=20, y=SURFACE_Y-PH,
        vx=0, vy=0,
        onGnd=true, under=false,
        onVine=false, onLad=false,
        face=1, rf=0, rt=0,
        inv=0, alive=true,
        vineT=0,
    }
end

local function startGame()
    game.state  = "playing"
    game.score  = 2000
    game.lives  = 3
    game.timer  = GAME_TIME
    game.scrIdx = 0
    game.coll   = {}
    game.nColl  = 0
    game.shake  = 0
    game.shakeT = 0
    game.flashT = 0
    screens = {}
    generateTreasureMap()
    for i = 0, SCREEN_COUNT-1 do generateScreen(i) end
    initPlayer()
end

local function initGame()
    game = {
        state   = "menu",
        score   = 2000,
        lives   = 3,
        timer   = GAME_TIME,
        scrIdx  = 0,
        hs      = 0,
        coll    = {},
        nColl   = 0,
        shake   = 0,
        shakeT  = 0,
        flashT  = 0,
        blink   = 0,
        dbg     = false,
    }
    initPlayer()
    screens = {}
    generateTreasureMap()
    for i = 0, SCREEN_COUNT-1 do generateScreen(i) end
end

------------------ PHYSICS / UPDATE -------------------------------------------

local function overGap(px, scr)
    local cx = px + PW * 0.5
    for _, g in ipairs(scr.gaps) do
        if cx >= g.x and cx <= g.x + g.w then return true end
    end
    return false
end

local function aabb(ax,ay,aw,ah, bx,by,bw,bh)
    return ax < bx+bw and ax+aw > bx and ay < by+bh and ay+ah > by
end

local function hurtPlayer()
    game.lives = game.lives - 1
    player.inv = INVULN_TIME
    addShake(3)
    api.sfx.play("pf_death")
    if game.lives <= 0 then
        player.alive = false
        game.state = "gameover"
        if game.score > game.hs then game.hs = game.score; saveHS() end
    end
end

local function updateLogs(dt, scr)
    for _, lg in ipairs(scr.logs) do
        lg.x = lg.x + lg.dir * LOG_SPEED * dt
        if lg.dir > 0 and lg.x > W + 20  then lg.x = -20 end
        if lg.dir < 0 and lg.x < -20     then lg.x = W + 20 end
    end
end

local function updatePlayer(dt, scr)
    if not player.alive then return end

    -- invuln countdown
    if player.inv > 0 then player.inv = player.inv - dt end

    ---------------------------------------------------------------- VINE
    if player.onVine then
        player.vineT = player.vineT + dt
        vineAngle = math.sin(player.vineT * VINE_SPD) * VINE_AMP
        local topX = scr.vine.x
        local topY = CANOPY_Y + CANOPY_H
        player.x = topX + math.sin(vineAngle) * VINE_LEN - PW * 0.5
        player.y = topY + math.cos(vineAngle) * VINE_LEN

        if jumpInput() then
            player.onVine = false
            local angV = math.cos(player.vineT * VINE_SPD) * VINE_AMP * VINE_SPD
            player.vx = angV * VINE_LEN * 1.6
            player.vy = -85
            player.onGnd = false
            api.sfx.play("pf_jump")
        end
        return
    end

    ---------------------------------------------------------------- LADDER
    if player.onLad then
        local mv = 0
        if api.input.isDown("up")   then mv = -CLIMB_SPEED * dt end
        if api.input.isDown("down") then mv =  CLIMB_SPEED * dt end
        player.y = player.y + mv
        player.rf = player.rf + math.abs(mv) * 0.4

        -- reached surface
        if player.y + PH <= SURFACE_Y + 2 and player.under then
            player.onLad = false
            player.under = false
            player.y     = SURFACE_Y - PH
            player.onGnd = true
            api.sfx.play("pf_ladder")
        end
        -- reached tunnel floor
        if player.y + PH >= TUNNEL_FLOOR and not player.under then
            player.onLad = false
            player.under = true
            player.y     = TUNNEL_FLOOR - PH
            player.onGnd = true
            api.sfx.play("pf_ladder")
        end
        return
    end

    ---------------------------------------------------------------- MOVE
    player.vx = 0
    if api.input.isDown("left")  then player.vx = -RUN_SPEED; player.face = -1 end
    if api.input.isDown("right") then player.vx =  RUN_SPEED; player.face =  1 end

    ---------------------------------------------------------------- JUMP / VINE GRAB
    if player.onGnd and jumpInput() then
        -- try vine grab first
        if not player.under and scr.vine then
            local vbx = scr.vine.x + math.sin(vineAngle) * VINE_LEN
            local vby = CANOPY_Y + CANOPY_H + math.cos(vineAngle) * VINE_LEN
            local dx = (player.x + PW*0.5) - vbx
            local dy = player.y - vby
            if math.abs(dx) < 16 and math.abs(dy) < 22 then
                player.onVine = true
                player.vineT  = vineTimer   -- sync with current angle
                api.sfx.play("pf_vine")
                return
            end
        end
        player.vy    = JUMP_VY
        player.onGnd = false
        api.sfx.play("pf_jump")
    end

    ---------------------------------------------------------------- LADDER ENTER
    if scr.ladder then
        local lx = scr.ladder.x
        local onLadX = player.x + PW > lx and player.x < lx + 10
        if onLadX then
            if not player.under and player.onGnd and api.input.isDown("down") then
                player.onLad = true
                player.x = lx + 1
                api.sfx.play("pf_ladder")
                return
            end
            if player.under and player.onGnd and api.input.isDown("up") then
                player.onLad = true
                player.x = lx + 1
                api.sfx.play("pf_ladder")
                return
            end
        end
    end

    ---------------------------------------------------------------- GRAVITY
    if not player.onGnd then
        player.vy = player.vy + GRAVITY * dt
    end

    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt

    -- run animation
    if player.vx ~= 0 and player.onGnd then
        player.rf = player.rf + math.abs(player.vx) * dt * 0.3
    end

    ---------------------------------------------------------------- GROUND COLLISION
    if player.under then
        if player.y + PH >= TUNNEL_FLOOR then
            player.y = TUNNEL_FLOOR - PH
            player.vy = 0
            player.onGnd = true
        else
            player.onGnd = false
        end
    else
        if player.y + PH >= SURFACE_Y then
            if overGap(player.x, scr) then
                -- falling into pit
                if player.y + PH > SURFACE_Y + GROUND_H + 12 then
                    game.score = math.max(0, game.score - PIT_PENALTY)
                    player.y = SURFACE_Y - PH
                    player.x = 20
                    player.vy = 0
                    player.onGnd = true
                    addShake(2)
                    api.sfx.play("pf_fall")
                end
            else
                player.y = SURFACE_Y - PH
                player.vy = 0
                player.onGnd = true
            end
        else
            player.onGnd = false
        end
    end

    -- ceiling clamp
    if player.y < HUD_H then player.y = HUD_H end
    -- tunnel ceiling
    if player.under and player.y < TUNNEL_CEIL then
        player.y = TUNNEL_CEIL
        player.vy = 0
    end

    ---------------------------------------------------------------- SCREEN TRANSITION
    if player.x + PW < 0 then
        game.scrIdx = (game.scrIdx - 1) % SCREEN_COUNT
        player.x = W - PW - 1
    elseif player.x > W then
        game.scrIdx = (game.scrIdx + 1) % SCREEN_COUNT
        player.x = 1
    end
end

local function checkCollisions(scr)
    if not player.alive or player.inv > 0 then return end
    if player.onVine or player.onLad then return end

    local px, py = player.x, player.y

    if not player.under then
        -- surface hazards
        for _, h in ipairs(scr.haz) do
            if aabb(px,py,PW,PH, h.x,h.y,h.w,h.h) then
                if h.type=="snake" or h.type=="scorpion"
                   or h.type=="croc" or h.type=="fire"
                   or h.type=="quicksand" then
                    hurtPlayer()
                    if h.type == "quicksand" then
                        player.y = SURFACE_Y - PH
                        player.x = 20
                    end
                    return
                end
            end
        end

        -- log collision
        for _, lg in ipairs(scr.logs) do
            if aabb(px,py,PW,PH, lg.x,SURFACE_Y-6,14,6) then
                game.score = math.max(0, game.score - LOG_PENALTY)
                player.x = player.x - lg.dir * 20
                player.inv = 0.5
                addShake(2)
                api.sfx.play("pf_log_hit")
                return
            end
        end

        -- treasure
        if scr.treas and not game.coll[game.scrIdx] then
            if aabb(px,py,PW,PH, scr.treasX,scr.treasY,8,10) then
                game.coll[game.scrIdx] = true
                game.nColl = game.nColl + 1
                game.score = game.score + TREASURE_TYPES[scr.treas].value
                game.flashT = 0.25
                api.sfx.play("pf_treasure")
                if game.score > game.hs then game.hs = game.score; saveHS() end
            end
        end
    else
        -- tunnel hazards
        for _, h in ipairs(scr.thaz) do
            if aabb(px,py,PW,PH, h.x,h.y,h.w,h.h) then
                hurtPlayer()
                return
            end
        end
    end
end

------------------ DRAWING: BACKGROUND ----------------------------------------

local function drawBG(scr)
    -- sky
    rect(C.DBLU, 0, HUD_H, W, CANOPY_Y - HUD_H)

    -- canopy
    rect(C.DGRN, 0, CANOPY_Y, W, CANOPY_H)
    -- canopy leaf clusters
    rect(C.GRN,  8,  CANOPY_Y+2, 28, CANOPY_H-4)
    rect(C.GRN,  48, CANOPY_Y+1, 22, CANOPY_H-3)
    rect(C.GRN,  82, CANOPY_Y+2, 30, CANOPY_H-4)
    rect(C.GRN, 125, CANOPY_Y+1, 28, CANOPY_H-3)
    rect(C.LIM,  15, CANOPY_Y+3, 10, CANOPY_H-6)
    rect(C.LIM,  92, CANOPY_Y+3, 12, CANOPY_H-6)

    -- tree trunks
    rect(C.BRN,  3,  CANOPY_Y+CANOPY_H, 7, SURFACE_Y - CANOPY_Y - CANOPY_H)
    rect(C.BRN, 150, CANOPY_Y+CANOPY_H, 7, SURFACE_Y - CANOPY_Y - CANOPY_H)
    -- trunk detail
    rect(C.DORG, 5,  CANOPY_Y+CANOPY_H+4, 3, SURFACE_Y - CANOPY_Y - CANOPY_H - 8)
    rect(C.DORG, 152, CANOPY_Y+CANOPY_H+4, 3, SURFACE_Y - CANOPY_Y - CANOPY_H - 8)

    -- ground
    rect(C.DORG, 0, SURFACE_Y, W, GROUND_H)
    rect(C.BRN,  0, SURFACE_Y + GROUND_H, W, TUNNEL_CEIL - SURFACE_Y - GROUND_H)

    -- cut gaps
    for _, g in ipairs(scr.gaps) do
        rect(C.BLK, g.x, SURFACE_Y, g.w, TUNNEL_CEIL - SURFACE_Y)
    end

    -- underground
    rect(C.BLK,  0, TUNNEL_CEIL, W, TUNNEL_FLOOR - TUNNEL_CEIL)
    rect(C.DGRY, 0, TUNNEL_CEIL, W, 2)                      -- ceiling line
    rect(C.DGRY, 0, TUNNEL_FLOOR, W, TFLOOR_H)              -- floor
    rect(C.BRN,  0, TUNNEL_FLOOR + TFLOOR_H, W, H - TUNNEL_FLOOR - TFLOOR_H)
end

------------------ DRAWING: FEATURES ------------------------------------------

local function drawVine(scr)
    if not scr.vine then return end
    local topX = scr.vine.x
    local topY = CANOPY_Y + CANOPY_H
    local bx = topX + math.sin(vineAngle) * VINE_LEN
    local by = topY + math.cos(vineAngle) * VINE_LEN
    api.palette.setColor(C.DGRN)
    api.gfx.line(topX, topY, bx, by)
    api.gfx.line(topX+1, topY, bx+1, by)
    -- knot at bottom
    rect(C.GRN, bx-1, by-1, 3, 3)
end

local function drawLadder(scr)
    if not scr.ladder then return end
    local lx = scr.ladder.x
    api.palette.setColor(C.YBRN)
    api.gfx.rectangle("fill", lx, SURFACE_Y, 2, TUNNEL_FLOOR - SURFACE_Y)
    api.gfx.rectangle("fill", lx+8, SURFACE_Y, 2, TUNNEL_FLOOR - SURFACE_Y)
    for ry = SURFACE_Y+6, TUNNEL_FLOOR-4, 8 do
        api.gfx.rectangle("fill", lx+2, ry, 6, 2)
    end
end

local function drawHazard(h, t)
    if h.type == "snake" then
        api.palette.setColor(C.GRN)
        for i = 0, 9 do
            local sy = h.y + 2 + math.sin((i + t*4)*1.5) * 2
            api.gfx.rectangle("fill", h.x+i, math.floor(sy), 2, 2)
        end
        rect(C.LIM, h.x, h.y+1, 3, 3)
        rect(C.RED, h.x+1, h.y+1, 1, 1)

    elseif h.type == "scorpion" then
        rect(C.DRED, h.x+2, h.y+2, 6, 3)
        rect(C.DRED, h.x+7, h.y, 2, 3)
        rect(C.DRED, h.x+6, h.y-1, 2, 2)
        rect(C.DRED, h.x, h.y+1, 3, 2)

    elseif h.type == "croc" then
        rect(C.DGRN, h.x, h.y, h.w, h.h)
        rect(C.YEL, h.x+1, h.y, 2, 2)
        if math.sin(t * 2.2) > 0 then
            rect(C.RED, h.x+h.w-3, h.y+1, 3, h.h-2)
        end
        rect(C.BLU, h.x-2, h.y+h.h-2, h.w+4, 3)

    elseif h.type == "quicksand" then
        rect(C.YBRN, h.x, h.y, h.w, h.h)
        local bx = h.x + 5 + math.floor(math.sin(t*3)*8)
        rect(C.DORG, bx, h.y+1, 2, 2)
        local bx2 = h.x + h.w - 10 + math.floor(math.cos(t*2.5)*5)
        rect(C.DORG, bx2, h.y+2, 2, 2)

    elseif h.type == "fire" then
        local cols = { C.RED, C.ORG, C.YEL, C.ORG, C.RED }
        for i = 0, 4 do
            local fy = h.y + math.floor(math.sin(t*9 + i*1.3) * 3)
            rect(cols[i+1], h.x + i*2, fy, 2, h.h - (fy - h.y))
        end
    end
end

local function drawLog(lg)
    rect(C.BRN,  lg.x, SURFACE_Y-6, 14, 6)
    rect(C.DORG, lg.x+1, SURFACE_Y-5, 12, 4)
    rect(C.BRN,  lg.x+4, SURFACE_Y-5, 1, 4)
    rect(C.BRN,  lg.x+9, SURFACE_Y-5, 1, 4)
end

local function drawTreasure(scr, t)
    if not scr.treas then return end
    if game.coll[game.scrIdx] then return end
    local tt = TREASURE_TYPES[scr.treas]
    local tx, ty = scr.treasX, scr.treasY

    -- glow
    local glow = 0.5 + 0.5 * math.sin(t * 6)
    if glow > 0.7 then
        rect(C.WHT, tx-1, ty-1, 10, 12)
    end
    rect(tt.col, tx, ty, 8, 10)
    -- sparkle
    if math.sin(t*5) > 0.3 then
        rect(C.WHT, tx+2, ty+2, 2, 2)
        rect(C.WHT, tx+5, ty+6, 1, 1)
    end
end

------------------ DRAWING: PLAYER --------------------------------------------

local function drawPlayer(p, t)
    if not p.alive then return end
    if p.inv > 0 and math.floor(t*10) % 2 == 0 then return end

    local x = math.floor(p.x)
    local y = math.floor(p.y)

    -- hat
    rect(C.DRED, x+1, y, 6, 2)

    -- head
    rect(C.LORG, x+2, y+2, 4, 2)

    -- body
    rect(C.GRN, x+1, y+4, 6, 5)

    if p.onLad then
        -- climbing arms
        local ao = math.floor(p.rf) % 2 == 0 and -2 or 2
        rect(C.LORG, x+ao, y+5, 2, 2)
        rect(C.LORG, x+6-ao, y+5, 2, 2)
        rect(C.BRN, x+2, y+9, 2, 3)
        rect(C.BRN, x+4, y+9, 2, 3)
        rect(C.BLK, x+2, y+12, 2, 2)
        rect(C.BLK, x+4, y+12, 2, 2)
    elseif p.onVine then
        -- arm up
        rect(C.LORG, x+3, y-2, 2, 4)
        rect(C.BRN, x+2, y+9, 4, 3)
        rect(C.BLK, x+2, y+12, 4, 2)
    elseif not p.onGnd then
        -- jump spread
        rect(C.BRN, x,   y+9, 3, 3)
        rect(C.BRN, x+5, y+9, 3, 3)
        rect(C.BLK, x,   y+12, 3, 2)
        rect(C.BLK, x+5, y+12, 3, 2)
    else
        -- run cycle
        local fr = math.floor(p.rf) % 4
        if fr == 1 or fr == 3 then
            rect(C.BRN, x+1, y+9, 2, 3)
            rect(C.BRN, x+5, y+9, 2, 3)
            rect(C.BLK, x+1, y+12, 2, 2)
            rect(C.BLK, x+5, y+12, 2, 2)
        else
            rect(C.BRN, x+2, y+9, 2, 3)
            rect(C.BRN, x+4, y+9, 2, 3)
            rect(C.BLK, x+2, y+12, 2, 2)
            rect(C.BLK, x+4, y+12, 2, 2)
        end
    end
end

------------------ DRAWING: HUD -----------------------------------------------

local function drawHUD()
    rect(C.BLK, 0, 0, W, HUD_H)

    -- score
    fprint("SC:" .. game.score, 2, 2, 1, C.WHT)

    -- timer
    local m = math.floor(game.timer / 60)
    local s = math.floor(game.timer % 60)
    local ts = string.format("%02d:%02d", m, s)
    local tc = game.timer < 60 and C.RED or C.YEL
    fcenter(ts, 2, 1, tc)

    -- lives
    for i = 1, game.lives do
        rect(C.SAL, W - 7*i, 3, 5, 8)
        rect(C.DRED, W - 7*i + 1, 3, 3, 2)  -- tiny hat on life icon
    end

    -- separator
    rect(C.DGRY, 0, HUD_H-1, W, 1)
end

------------------ DRAWING: SCREENS -------------------------------------------

local function drawMenu()
    rect(C.BLK, 0, 0, W, H)

    -- decorative jungle
    rect(C.DGRN, 0, 90, W, 25)
    rect(C.BRN, 12, 78, 8, 45)
    rect(C.BRN, 140, 78, 8, 45)
    rect(C.GRN, 6, 68, 20, 15)
    rect(C.GRN, 134, 68, 20, 15)
    rect(C.DORG, 0, 123, W, 8)
    rect(C.BRN, 0, 131, W, H - 131)

    -- title
    fcenter("PITFALL-ISH", 18, 2, C.YEL)
    fcenter("JUNGLE ADVENTURE", 38, 1, C.LGRN)

    -- high score
    fcenter("BEST:" .. game.hs, 54, 1, C.WHT)

    -- blink
    if math.floor(game.blink * 2) % 2 == 0 then
        fcenter("PRESS ENTER", 105, 1, C.WHT)
    end

    -- controls
    fprint("ARROWS:MOVE", 8, 145, 1, C.GRY)
    fprint("SPACE:JUMP", 8, 155, 1, C.GRY)
    fprint("DOWN:LADDER", 8, 165, 1, C.GRY)
    fprint("P:PAUSE R:REDO", 8, 178, 1, C.GRY)
end

local function drawPaused()
    api.gfx.setColor(0, 0, 0, 0.55)
    api.gfx.rectangle("fill", 0, 0, W, H)
    fcenter("PAUSED", 75, 2, C.WHT)
    fcenter("P TO RESUME", 100, 1, C.GRY)
end

local function drawGameOver()
    api.gfx.setColor(0, 0, 0, 0.72)
    api.gfx.rectangle("fill", 0, 0, W, H)

    local won = game.nColl >= TREASURE_COUNT
    if won then
        fcenter("VICTORY!", 30, 2, C.YEL)
    else
        fcenter("GAME OVER", 30, 2, C.RED)
    end

    fcenter("SCORE:" .. game.score, 60, 1, C.WHT)
    fcenter("TREASURE:" .. game.nColl .. "/" .. TREASURE_COUNT, 74, 1, C.YEL)
    fcenter("BEST:" .. game.hs, 88, 1, C.LGRN)

    if game.score >= game.hs and game.score > 2000 then
        if math.floor(gameTime * 3) % 2 == 0 then
            fcenter("NEW HIGH SCORE!", 104, 1, C.YEL)
        end
    end

    if math.floor(game.blink * 2) % 2 == 0 then
        fcenter("R:RETRY  ENTER:MENU", 130, 1, C.WHT)
    end
end

local function drawDebug(scr)
    if not game.dbg then return end
    fprint("SCR:" .. game.scrIdx, 2, HUD_H+2, 1, C.CYA)
    fprint(scr.type, 2, HUD_H+10, 1, C.CYA)
    fprint(player.under and "TUNNEL" or "SURFACE", 2, HUD_H+18, 1, C.CYA)
    if scr.treas then fprint("TREAS:" .. TREASURE_TYPES[scr.treas].name, 2, HUD_H+26, 1, C.CYA) end
    fprint("SEED:" .. WORLD_SEED, 2, HUD_H+34, 1, C.CYA)
    fprint("Y:" .. math.floor(player.y), 2, HUD_H+42, 1, C.CYA)
end

------------------ CART LIFECYCLE ----------------------------------------------

function Cart.load(engineAPI)
    api = engineAPI
    W = api.getWidth()
    H = api.getHeight()

    setupSFX()
    setupMusic()
    initGame()
    loadHS()
end

function Cart.update(dt)
    gameTime  = gameTime + dt
    game.blink = game.blink + dt

    -- vine always gently swings (visual)
    vineTimer = vineTimer + dt
    if not player.onVine then
        vineAngle = math.sin(vineTimer * VINE_SPD) * VINE_AMP * 0.6
    end

    -- shake decay
    if game.shakeT > 0 then
        game.shakeT = game.shakeT - dt
        if game.shakeT <= 0 then game.shake = 0 end
    end
    if game.flashT > 0 then game.flashT = game.flashT - dt end

    if game.state == "menu" then
        -- gamepad start support
        if api.input.justPressed("start") then
            startGame()
            api.music.play()
        end

    elseif game.state == "playing" then
        game.timer = game.timer - dt
        if game.timer <= 0 then
            game.timer = 0
            game.state = "gameover"
            if game.score > game.hs then game.hs = game.score; saveHS() end
        end

        local scr = screens[game.scrIdx]
        if scr then
            updateLogs(dt, scr)
            updatePlayer(dt, scr)
            checkCollisions(scr)
        end

        if game.nColl >= TREASURE_COUNT then
            game.state = "gameover"
            if game.score > game.hs then game.hs = game.score; saveHS() end
        end

        -- gamepad pause
        if api.input.justPressed("start") then
            game.state = "paused"
            api.music.pause()
        end

    elseif game.state == "paused" then
        if api.input.justPressed("start") then
            game.state = "playing"
            api.music.resume()
        end
    end

    api.music.update(dt)
end

function Cart.draw()
    api.gfx.setColor(0, 0, 0, 1)
    api.gfx.rectangle("fill", 0, 0, W, H)

    if game.state == "menu" then
        drawMenu()
        return
    end

    -- shake offset
    local sx, sy = 0, 0
    if game.shake > 0 and game.shakeT > 0 then
        sx = (math.random() * 2 - 1) * game.shake
        sy = (math.random() * 2 - 1) * game.shake
    end

    api.gfx.push()
    api.gfx.translate(math.floor(sx), math.floor(sy))

    local scr = screens[game.scrIdx]
    if scr then
        drawBG(scr)
        drawLadder(scr)
        drawVine(scr)

        for _, h in ipairs(scr.haz) do drawHazard(h, gameTime) end
        for _, lg in ipairs(scr.logs) do drawLog(lg) end
        drawTreasure(scr, gameTime)
        for _, h in ipairs(scr.thaz) do drawHazard(h, gameTime) end

        drawPlayer(player, gameTime)
    end

    api.gfx.pop()

    drawHUD()

    if scr then drawDebug(scr) end

    -- flash
    if game.flashT > 0 then
        api.gfx.setColor(1, 1, 1, game.flashT * 3)
        api.gfx.rectangle("fill", 0, 0, W, H)
    end

    if game.state == "paused" then
        drawPaused()
    elseif game.state == "gameover" then
        drawGameOver()
    end
end

function Cart.keypressed(key)
    if game.state == "menu" then
        if key == "return" or key == "z" or key == "space" then
            startGame()
            api.music.play()
        end

    elseif game.state == "playing" then
        if key == "p" then
            game.state = "paused"
            api.music.pause()
        elseif key == "r" then
            startGame()
        elseif key == "c" then
            game.dbg = not game.dbg
        end

    elseif game.state == "paused" then
        if key == "p" then
            game.state = "playing"
            api.music.resume()
        end

    elseif game.state == "gameover" then
        if key == "r" then
            startGame()
            api.music.play()
        elseif key == "return" then
            game.state = "menu"
            api.music.stop()
        end
    end
end

function Cart.unload()
    api.music.stop()
end

return Cart
