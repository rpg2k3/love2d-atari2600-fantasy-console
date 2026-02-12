-- cartridges/adventure_clone/main.lua
-- Adventure-ish: Atari 2600 Adventure clone
-- Full gameplay: room exploration, item carry, dragons, bat, castles, win condition

local Cart = {}

-- ============================================================
-- ENGINE API + WORLD DATA (set in load)
-- ============================================================
local api
local World
local Content
local screenW, screenH

-- ============================================================
-- CONSTANTS
-- ============================================================
local PLAYER_W     = 6
local PLAYER_H     = 8
local PLAYER_SPEED = 55
local DRAGON_W     = 12
local DRAGON_H     = 10
local BAT_W        = 8
local BAT_H        = 6
local ATTACK_DUR   = 0.2    -- sword attack window
local ATTACK_RANGE = 16     -- sword reach
local BITE_STUN    = 0.8    -- freeze time when bitten
local SHAKE_DUR    = 0.3
local SHAKE_AMP    = 2
local BAT_HOLD_DUR = 2.0    -- how long bat holds item before dropping
local BAT_IDLE_DUR = 3.0    -- how long bat idles before picking new target

-- ============================================================
-- GAME STATE
-- ============================================================
local state         -- "MENU", "PLAYING", "PAUSED", "WIN", "DEAD_FREEZE"
local gameMode      -- 1, 2, or 3
local menuSel       -- menu selection index (1-3)
local timer         -- elapsed play time
local deaths        -- death count
local bestTimes     -- { [1]=sec, [2]=sec, [3]=sec }
local debugOn       -- debug overlay toggle

-- Player
local player  -- { x, y, room, dir, carrying, attacking, attackTimer }

-- Items: keyed by item id
local items   -- { [id] = { id, def, room, x, y, carried } }

-- Dragons
local dragons -- array of dragon tables

-- Bat
local bat     -- { room, x, y, targetItem, holding, holdTimer, idleTimer, dir, speed }

-- Gates (open/closed per castle)
local gates   -- { yellow=bool, white=bool, black=bool }

-- Screen shake
local shakeTimer, shakeX, shakeY

-- Win jingle played flag
local winJinglePlayed

-- Dead freeze timer (brief pause before respawn)
local deadFreezeTimer

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local initGame, updatePlaying, drawRoom, drawPlayer, drawItems
local drawDragons, drawBat, drawHUD, drawDebug
local moveEntity, checkWallCollision, resolveWalls
local roomTransition, pickupItem, dropItem, tryUnlock, attackSword
local updateDragons, updateBat, triggerShake
local saveHighscores, loadHighscores, formatTime
local drawCentered, rectOverlap, pointInRect, clamp

-- ============================================================
-- HELPERS
-- ============================================================
clamp = function(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

rectOverlap = function(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

pointInRect = function(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

formatTime = function(t)
    if not t then return "--:--" end
    local m = math.floor(t / 60)
    local s = math.floor(t % 60)
    local cs = math.floor((t * 10) % 10)
    return string.format("%d:%02d.%d", m, s, cs)
end

drawCentered = function(text, y, scale, r, g, b)
    scale = scale or 1
    local tw = api.font.measure(text, scale)
    local x = math.floor((screenW - tw) / 2)
    api.font.print(text, x, y, scale, r or 1, g or 1, b or 1, 1)
end

-- ============================================================
-- HIGHSCORE PERSISTENCE
-- ============================================================
loadHighscores = function()
    local data = api.load("highscore.lua")
    if data and data.best then
        bestTimes = data.best
    else
        bestTimes = {}
    end
end

saveHighscores = function()
    api.save("highscore.lua", { best = bestTimes })
end

-- ============================================================
-- WALL COLLISION
-- ============================================================
-- Check if a rect overlaps any wall in the current room
checkWallCollision = function(room, x, y, w, h)
    local roomDef = World.rooms[room]
    if not roomDef then return false end
    for _, wall in ipairs(roomDef.walls) do
        if rectOverlap(x, y, w, h, wall[1], wall[2], wall[3], wall[4]) then
            return true
        end
    end
    -- Check gate if closed
    if roomDef.gate and not gates[roomDef.gate.keyId] then
        local gr = roomDef.gate.rect
        if rectOverlap(x, y, w, h, gr[1], gr[2], gr[3], gr[4]) then
            return true
        end
    end
    return false
end

-- Move entity and resolve wall collisions, returns final x, y
resolveWalls = function(room, ox, oy, nx, ny, w, h)
    -- Try full move
    if not checkWallCollision(room, nx, ny, w, h) then
        return nx, ny
    end
    -- Try X only
    if not checkWallCollision(room, nx, oy, w, h) then
        return nx, oy
    end
    -- Try Y only
    if not checkWallCollision(room, ox, ny, w, h) then
        return ox, ny
    end
    -- Blocked
    return ox, oy
end

-- ============================================================
-- ROOM TRANSITIONS
-- ============================================================
roomTransition = function(ent, w, h)
    local roomDef = World.rooms[ent.room]
    if not roomDef then return end
    local exits = roomDef.exits

    local entered -- direction entity entered from (for spawn nudge)

    if ent.y < -2 and exits.up then
        ent.room = exits.up
        ent.y = screenH - h - 6
        entered = "down"
    elseif ent.y + h > screenH + 2 and exits.down then
        ent.room = exits.down
        ent.y = 6
        entered = "up"
    elseif ent.x < -2 and exits.left then
        ent.room = exits.left
        ent.x = screenW - w - 6
        entered = "right"
    elseif ent.x + w > screenW + 2 and exits.right then
        ent.room = exits.right
        ent.x = 6
        entered = "left"
    end

    if entered then
        -- Nudge spawn out of walls/gates (up to 24px inward)
        for _ = 1, 24 do
            if not checkWallCollision(ent.room, ent.x, ent.y, w, h) then break end
            if entered == "down" then ent.y = ent.y - 1
            elseif entered == "up" then ent.y = ent.y + 1
            elseif entered == "right" then ent.x = ent.x - 1
            elseif entered == "left" then ent.x = ent.x + 1
            end
        end
        return true
    end
    return false
end

-- ============================================================
-- ITEM MANAGEMENT
-- ============================================================
pickupItem = function(itemId)
    if player.carrying then
        -- Drop current first
        dropItem()
    end
    local it = items[itemId]
    if it then
        it.carried = true
        it.room = player.room
        player.carrying = itemId
        api.sfx.play("pickup")
    end
end

dropItem = function()
    if not player.carrying then return end
    local it = items[player.carrying]
    if it then
        it.carried = false
        it.room = player.room
        it.x = player.x
        it.y = player.y + PLAYER_H + 2
        -- Clamp to screen
        it.x = clamp(it.x, 8, screenW - 8)
        it.y = clamp(it.y, 8, screenH - 8)
    end
    api.sfx.play("drop")
    player.carrying = nil
end

tryUnlock = function()
    if not player.carrying then return end
    local roomDef = World.rooms[player.room]
    if not roomDef or not roomDef.gate then return end
    local gate = roomDef.gate
    if gates[gate.keyId] then return end  -- already open
    if player.carrying == gate.keyId then
        -- Unlock! Key is consumed (dropped at gate)
        gates[gate.keyId] = true
        local it = items[player.carrying]
        if it then
            it.carried = false
            it.room = player.room
            it.x = gate.rect[1] + gate.rect[3] / 2
            it.y = gate.rect[2] + gate.rect[4] / 2
        end
        player.carrying = nil
        api.sfx.play("unlock")
    end
end

attackSword = function()
    if player.carrying ~= "sword" then return end
    if player.attacking then return end
    player.attacking = true
    player.attackTimer = ATTACK_DUR
    api.sfx.play("swordHit")
    triggerShake()

    -- Check dragon hits
    local ax, ay, aw, ah
    if player.dir == "up" then
        ax, ay = player.x - 2, player.y - ATTACK_RANGE
        aw, ah = PLAYER_W + 4, ATTACK_RANGE
    elseif player.dir == "down" then
        ax, ay = player.x - 2, player.y + PLAYER_H
        aw, ah = PLAYER_W + 4, ATTACK_RANGE
    elseif player.dir == "left" then
        ax, ay = player.x - ATTACK_RANGE, player.y - 2
        aw, ah = ATTACK_RANGE, PLAYER_H + 4
    else -- right
        ax, ay = player.x + PLAYER_W, player.y - 2
        aw, ah = ATTACK_RANGE, PLAYER_H + 4
    end

    for _, d in ipairs(dragons) do
        if d.alive and d.room == player.room then
            if rectOverlap(ax, ay, aw, ah, d.x, d.y, DRAGON_W, DRAGON_H) then
                d.alive = false
                api.sfx.play("dragonDie")
            end
        end
    end
end

-- ============================================================
-- SCREEN SHAKE
-- ============================================================
triggerShake = function()
    shakeTimer = SHAKE_DUR
end

local function updateShake(dt)
    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        shakeX = math.random(-SHAKE_AMP, SHAKE_AMP)
        shakeY = math.random(-SHAKE_AMP, SHAKE_AMP)
        if shakeTimer <= 0 then
            shakeX, shakeY = 0, 0
        end
    end
end

-- ============================================================
-- DRAGON AI
-- ============================================================
updateDragons = function(dt)
    for _, d in ipairs(dragons) do
        if d.alive then
            if d.room == player.room then
                -- Pursue player
                local dx = player.x - d.x
                local dy = player.y - d.y
                local dist = math.sqrt(dx * dx + dy * dy)

                -- Check if scared of carried item
                local scared = false
                if player.carrying and d.scared then
                    for _, sc in ipairs(d.scared) do
                        if player.carrying == sc then
                            scared = true
                            break
                        end
                    end
                end

                if dist > 1 then
                    local speed = d.speed * dt
                    local mx, my
                    if scared then
                        -- Flee
                        mx = d.x - (dx / dist) * speed
                        my = d.y - (dy / dist) * speed
                    else
                        mx = d.x + (dx / dist) * speed
                        my = d.y + (dy / dist) * speed
                    end
                    -- Resolve walls
                    d.x, d.y = resolveWalls(d.room, d.x, d.y, mx, my, DRAGON_W, DRAGON_H)
                end

                -- Check bite
                if not scared and not player.attacking then
                    if rectOverlap(player.x, player.y, PLAYER_W, PLAYER_H,
                                   d.x, d.y, DRAGON_W, DRAGON_H) then
                        -- Player bitten!
                        api.sfx.play("dragonBite")
                        triggerShake()
                        deaths = deaths + 1
                        -- Drop carried item at bite location
                        if player.carrying then
                            local it = items[player.carrying]
                            if it then
                                it.carried = false
                                it.room = player.room
                                it.x = player.x
                                it.y = player.y
                            end
                            player.carrying = nil
                        end
                        state = "DEAD_FREEZE"
                        deadFreezeTimer = BITE_STUN
                        return
                    end
                end
            else
                -- Wander slowly in own room
                d.wanderTimer = (d.wanderTimer or 0) - dt
                if d.wanderTimer <= 0 then
                    d.wanderDx = (math.random() - 0.5) * 2
                    d.wanderDy = (math.random() - 0.5) * 2
                    d.wanderTimer = 1.5 + math.random() * 2
                end
                local speed = d.speed * 0.3 * dt
                local mx = d.x + d.wanderDx * speed
                local my = d.y + d.wanderDy * speed
                d.x, d.y = resolveWalls(d.room, d.x, d.y, mx, my, DRAGON_W, DRAGON_H)
                -- Keep in bounds
                d.x = clamp(d.x, 8, screenW - DRAGON_W - 8)
                d.y = clamp(d.y, 8, screenH - DRAGON_H - 8)
            end
        end
    end
end

-- ============================================================
-- BAT AI
-- ============================================================
updateBat = function(dt)
    if not bat then return end

    -- Update bat regardless of room
    if bat.holding then
        -- Bat is carrying an item, fly to a random room and drop it
        bat.holdTimer = bat.holdTimer - dt
        if bat.holdTimer <= 0 then
            -- Drop item in current room
            local it = items[bat.holding]
            if it then
                it.carried = false
                it.room = bat.room
                it.x = bat.x
                it.y = bat.y
            end
            bat.holding = nil
            bat.idleTimer = BAT_IDLE_DUR
        else
            -- Fly towards exit
            local roomDef = World.rooms[bat.room]
            if roomDef then
                local exits = roomDef.exits
                -- Pick a random exit direction
                if not bat.exitDir then
                    local dirs = {}
                    if exits.up then dirs[#dirs+1] = "up" end
                    if exits.down then dirs[#dirs+1] = "down" end
                    if exits.left then dirs[#dirs+1] = "left" end
                    if exits.right then dirs[#dirs+1] = "right" end
                    if #dirs > 0 then
                        bat.exitDir = dirs[math.random(#dirs)]
                    end
                end
                if bat.exitDir then
                    local tx, ty = bat.x, bat.y
                    if bat.exitDir == "up" then ty = -5
                    elseif bat.exitDir == "down" then ty = screenH + 5
                    elseif bat.exitDir == "left" then tx = -5
                    elseif bat.exitDir == "right" then tx = screenW + 5
                    end
                    local dx = tx - bat.x
                    local dy = ty - bat.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 1 then
                        bat.x = bat.x + (dx / dist) * bat.speed * dt
                        bat.y = bat.y + (dy / dist) * bat.speed * dt
                    end
                    -- Room transition for bat
                    if roomTransition(bat, BAT_W, BAT_H) then
                        bat.exitDir = nil
                    end
                end
            end
        end
    elseif bat.idleTimer and bat.idleTimer > 0 then
        -- Idle: flutter around
        bat.idleTimer = bat.idleTimer - dt
        bat.x = bat.x + math.sin(timer * 5) * 0.5
        bat.y = bat.y + math.cos(timer * 4) * 0.3
    else
        -- Look for an item to steal
        bat.targetItem = nil
        local candidates = {}
        for id, it in pairs(items) do
            if not it.carried or (it.carried and it.room == bat.room) then
                candidates[#candidates+1] = id
            end
        end
        if #candidates > 0 then
            bat.targetItem = candidates[math.random(#candidates)]
        end

        if bat.targetItem then
            local it = items[bat.targetItem]
            if it then
                -- If item is in a different room, fly towards exit
                if it.room ~= bat.room then
                    -- Just wander toward a random exit
                    local roomDef = World.rooms[bat.room]
                    if roomDef then
                        local dirs = {}
                        local exits = roomDef.exits
                        if exits.up then dirs[#dirs+1] = "up" end
                        if exits.down then dirs[#dirs+1] = "down" end
                        if exits.left then dirs[#dirs+1] = "left" end
                        if exits.right then dirs[#dirs+1] = "right" end
                        if #dirs > 0 then
                            if not bat.exitDir then
                                bat.exitDir = dirs[math.random(#dirs)]
                            end
                            local tx, ty = bat.x, bat.y
                            if bat.exitDir == "up" then ty = -5
                            elseif bat.exitDir == "down" then ty = screenH + 5
                            elseif bat.exitDir == "left" then tx = -5
                            elseif bat.exitDir == "right" then tx = screenW + 5
                            end
                            local dx = tx - bat.x
                            local dy = ty - bat.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist > 1 then
                                bat.x = bat.x + (dx / dist) * bat.speed * dt
                                bat.y = bat.y + (dy / dist) * bat.speed * dt
                            end
                            if roomTransition(bat, BAT_W, BAT_H) then
                                bat.exitDir = nil
                            end
                        end
                    end
                else
                    -- Same room: fly to item
                    local tx, ty = it.x, it.y
                    if it.carried then
                        -- Item is carried by player - fly to player
                        tx, ty = player.x, player.y
                    end
                    local dx = tx - bat.x
                    local dy = ty - bat.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 1 then
                        bat.x = bat.x + (dx / dist) * bat.speed * dt
                        bat.y = bat.y + (dy / dist) * bat.speed * dt
                    end
                    -- Check grab
                    if rectOverlap(bat.x, bat.y, BAT_W, BAT_H, tx, ty, 8, 8) then
                        -- Steal from player if carried
                        if it.carried and player.carrying == bat.targetItem then
                            player.carrying = nil
                            api.sfx.play("batSteal")
                        end
                        it.carried = true
                        it.room = bat.room
                        bat.holding = bat.targetItem
                        bat.holdTimer = BAT_HOLD_DUR + math.random() * 2
                        bat.exitDir = nil
                        bat.targetItem = nil
                    end
                end
            end
        else
            -- No target, just flutter
            bat.x = bat.x + math.sin(timer * 5) * 0.3
            bat.y = bat.y + math.cos(timer * 4) * 0.2
        end
    end

    -- Move held item with bat
    if bat.holding then
        local it = items[bat.holding]
        if it then
            it.room = bat.room
            it.x = bat.x
            it.y = bat.y + BAT_H
        end
    end
end

-- ============================================================
-- INIT GAME
-- ============================================================
initGame = function(mode)
    gameMode = mode
    timer = 0
    deaths = 0
    debugOn = false
    shakeTimer = 0
    shakeX, shakeY = 0, 0
    winJinglePlayed = false
    deadFreezeTimer = 0

    local modeData = World.modes[mode]

    -- Player
    player = {
        x = modeData.playerStart.x,
        y = modeData.playerStart.y,
        room = modeData.playerStart.room,
        dir = "up",
        carrying = nil,
        attacking = false,
        attackTimer = 0,
    }

    -- Items
    items = {}
    for _, itemCfg in ipairs(modeData.items) do
        items[itemCfg.id] = {
            id = itemCfg.id,
            def = World.itemDefs[itemCfg.id],
            room = itemCfg.room,
            x = itemCfg.x,
            y = itemCfg.y,
            carried = false,
        }
    end

    -- Dragons
    dragons = {}
    for _, dcfg in ipairs(modeData.dragons) do
        dragons[#dragons+1] = {
            id = dcfg.id,
            color = dcfg.color,
            speed = dcfg.speed,
            room = dcfg.room,
            x = dcfg.x,
            y = dcfg.y,
            alive = true,
            scared = dcfg.scared or {},
            wanderDx = 0,
            wanderDy = 0,
            wanderTimer = 0,
        }
    end

    -- Bat
    if modeData.bat then
        local bc = modeData.bat
        bat = {
            room = bc.room,
            x = bc.x,
            y = bc.y,
            speed = bc.speed,
            holding = nil,
            holdTimer = 0,
            idleTimer = BAT_IDLE_DUR,
            targetItem = nil,
            exitDir = nil,
        }
    else
        bat = nil
    end

    -- Gates (all locked)
    gates = {}

    -- Music
    api.music.loadSong({
        bpm = Content.music.bpm,
        speed = Content.music.speed,
        instruments = Content.music.instruments,
        patterns = Content.music.patterns,
        order = { 1, 2, 1, 3 },
    })
    api.music.play()

    state = "PLAYING"
end

-- ============================================================
-- RESPAWN (after dragon bite)
-- ============================================================
local function respawnPlayer()
    local modeData = World.modes[gameMode]
    player.x = modeData.playerStart.x
    player.y = modeData.playerStart.y
    player.room = modeData.playerStart.room
    player.dir = "up"
    player.attacking = false
    player.attackTimer = 0
    api.sfx.play("respawn")
    state = "PLAYING"
end

-- ============================================================
-- CHECK WIN
-- ============================================================
local function checkWin()
    -- Chalice must be in Yellow Castle (room 1) and carried by player
    if player.carrying == "chalice" and player.room == 1 then
        state = "WIN"
        api.music.stop()
        if not winJinglePlayed then
            api.sfx.play("winJingle")
            winJinglePlayed = true
        end
        -- Update best time
        if not bestTimes[gameMode] or timer < bestTimes[gameMode] then
            bestTimes[gameMode] = timer
            saveHighscores()
        end
    end
end

-- ============================================================
-- UPDATE: PLAYING
-- ============================================================
updatePlaying = function(dt)
    timer = timer + dt

    -- Player movement
    local dx, dy = 0, 0
    if api.input.isDown("left")  then dx = dx - 1; player.dir = "left" end
    if api.input.isDown("right") then dx = dx + 1; player.dir = "right" end
    if api.input.isDown("up")    then dy = dy - 1; player.dir = "up" end
    if api.input.isDown("down")  then dy = dy + 1; player.dir = "down" end

    if dx ~= 0 or dy ~= 0 then
        -- Normalize diagonal
        if dx ~= 0 and dy ~= 0 then
            local len = math.sqrt(dx * dx + dy * dy)
            dx = dx / len
            dy = dy / len
        end
        local nx = player.x + dx * PLAYER_SPEED * dt
        local ny = player.y + dy * PLAYER_SPEED * dt
        player.x, player.y = resolveWalls(player.room, player.x, player.y, nx, ny, PLAYER_W, PLAYER_H)
    end

    -- Room transition
    if roomTransition(player, PLAYER_W, PLAYER_H) then
        -- Move carried item with player
        if player.carrying then
            local it = items[player.carrying]
            if it then
                it.room = player.room
            end
        end
    end

    -- Attack timer
    if player.attacking then
        player.attackTimer = player.attackTimer - dt
        if player.attackTimer <= 0 then
            player.attacking = false
        end
    end

    -- Update dragons
    updateDragons(dt)

    -- Update bat
    updateBat(dt)

    -- Update shake
    updateShake(dt)

    -- Move carried item with player
    if player.carrying then
        local it = items[player.carrying]
        if it then
            it.room = player.room
            it.x = player.x
            it.y = player.y - 2
        end
    end

    -- Check win
    checkWin()
end

-- ============================================================
-- DRAW: ITEM SHAPES
-- ============================================================
local function drawItemShape(def, x, y)
    local c = def.color
    api.palette.setColor(c)

    if def.shape == "key" then
        -- Key: small rectangle handle + shaft
        api.gfx.rectangle("fill", x, y, 5, 3)
        api.gfx.rectangle("fill", x + 1, y + 3, 2, 5)
        api.gfx.rectangle("fill", x + 3, y + 6, 2, 2)
    elseif def.shape == "chalice" then
        -- Chalice: cup shape
        api.gfx.rectangle("fill", x + 1, y, 4, 2)
        api.gfx.rectangle("fill", x, y + 2, 6, 3)
        api.gfx.rectangle("fill", x + 2, y + 5, 2, 2)
        api.gfx.rectangle("fill", x + 1, y + 7, 4, 1)
    elseif def.shape == "sword" then
        -- Sword: thin vertical line + crossguard
        api.gfx.rectangle("fill", x + 1, y, 1, 7)
        api.gfx.rectangle("fill", x, y + 3, 3, 1)
        api.gfx.rectangle("fill", x + 1, y + 7, 1, 3)
    elseif def.shape == "bridge" then
        -- Bridge: horizontal plank
        api.gfx.rectangle("fill", x, y, 16, 2)
        api.gfx.rectangle("fill", x, y + 2, 2, 2)
        api.gfx.rectangle("fill", x + 14, y + 2, 2, 2)
    elseif def.shape == "magnet" then
        -- Magnet: U shape
        api.gfx.rectangle("fill", x, y, 2, 6)
        api.gfx.rectangle("fill", x + 4, y, 2, 6)
        api.gfx.rectangle("fill", x, y, 6, 2)
    elseif def.shape == "dot" then
        -- Dot: tiny pixel
        api.gfx.rectangle("fill", x, y, 2, 2)
    end
end

-- ============================================================
-- DRAW: ROOM
-- ============================================================
drawRoom = function()
    local roomDef = World.rooms[player.room]
    if not roomDef then return end

    -- Background
    api.palette.setColor(roomDef.bg)
    api.gfx.rectangle("fill", 0, 0, screenW, screenH)

    -- Walls
    api.palette.setColor(roomDef.wallColor)
    for _, wall in ipairs(roomDef.walls) do
        api.gfx.rectangle("fill", wall[1], wall[2], wall[3], wall[4])
    end

    -- Gate (if closed)
    if roomDef.gate then
        if not gates[roomDef.gate.keyId] then
            -- Draw portcullis
            local gr = roomDef.gate.rect
            api.palette.setColor(roomDef.wallColor)
            api.gfx.rectangle("fill", gr[1], gr[2], gr[3], gr[4])
            -- Draw bars
            api.palette.setColor(1) -- black bars
            local barSpacing = 4
            if gr[3] > gr[4] then
                -- Horizontal gate
                for by = gr[2] + 1, gr[2] + gr[4] - 1, barSpacing do
                    api.gfx.rectangle("fill", gr[1], by, gr[3], 1)
                end
            else
                -- Vertical gate
                for bx = gr[1] + 1, gr[1] + gr[3] - 1, barSpacing do
                    api.gfx.rectangle("fill", bx, gr[2], 1, gr[4])
                end
            end
        end
    end
end

-- ============================================================
-- DRAW: PLAYER
-- ============================================================
drawPlayer = function()
    -- Player square with direction notch
    api.palette.setColor(15)  -- yellow
    api.gfx.rectangle("fill", player.x, player.y, PLAYER_W, PLAYER_H)

    -- Direction notch (2x2 darker square)
    api.palette.setColor(13) -- dark yellow
    if player.dir == "up" then
        api.gfx.rectangle("fill", player.x + 2, player.y, 2, 2)
    elseif player.dir == "down" then
        api.gfx.rectangle("fill", player.x + 2, player.y + PLAYER_H - 2, 2, 2)
    elseif player.dir == "left" then
        api.gfx.rectangle("fill", player.x, player.y + 3, 2, 2)
    elseif player.dir == "right" then
        api.gfx.rectangle("fill", player.x + PLAYER_W - 2, player.y + 3, 2, 2)
    end

    -- Sword attack visual
    if player.attacking then
        api.palette.setColor(4) -- white flash
        if player.dir == "up" then
            api.gfx.rectangle("fill", player.x + 2, player.y - ATTACK_RANGE, 2, ATTACK_RANGE)
        elseif player.dir == "down" then
            api.gfx.rectangle("fill", player.x + 2, player.y + PLAYER_H, 2, ATTACK_RANGE)
        elseif player.dir == "left" then
            api.gfx.rectangle("fill", player.x - ATTACK_RANGE, player.y + 3, ATTACK_RANGE, 2)
        elseif player.dir == "right" then
            api.gfx.rectangle("fill", player.x + PLAYER_W, player.y + 3, ATTACK_RANGE, 2)
        end
    end
end

-- ============================================================
-- DRAW: ITEMS
-- ============================================================
drawItems = function()
    for _, it in pairs(items) do
        if it.room == player.room and not it.carried then
            drawItemShape(it.def, it.x, it.y)
        end
    end
    -- Draw carried item above player
    if player.carrying then
        local it = items[player.carrying]
        if it and it.room == player.room then
            drawItemShape(it.def, player.x, player.y - it.def.h - 1)
        end
    end
end

-- ============================================================
-- DRAW: DRAGONS
-- ============================================================
drawDragons = function()
    for _, d in ipairs(dragons) do
        if d.alive and d.room == player.room then
            api.palette.setColor(d.color)
            -- Body
            api.gfx.rectangle("fill", d.x, d.y, DRAGON_W, DRAGON_H)
            -- Eyes (2 white dots)
            api.palette.setColor(4)
            api.gfx.rectangle("fill", d.x + 2, d.y + 2, 2, 2)
            api.gfx.rectangle("fill", d.x + DRAGON_W - 4, d.y + 2, 2, 2)
            -- Mouth: triangle approximation (3 rects)
            api.palette.setColor(6) -- red
            local mouthDir = "right"
            if player.room == d.room then
                if player.x < d.x then mouthDir = "left" end
            end
            if mouthDir == "right" then
                api.gfx.rectangle("fill", d.x + DRAGON_W, d.y + 3, 4, 1)
                api.gfx.rectangle("fill", d.x + DRAGON_W, d.y + 4, 3, 1)
                api.gfx.rectangle("fill", d.x + DRAGON_W, d.y + 5, 2, 1)
            else
                api.gfx.rectangle("fill", d.x - 4, d.y + 3, 4, 1)
                api.gfx.rectangle("fill", d.x - 3, d.y + 4, 3, 1)
                api.gfx.rectangle("fill", d.x - 2, d.y + 5, 2, 1)
            end
        end
    end
end

-- ============================================================
-- DRAW: BAT
-- ============================================================
drawBat = function()
    if not bat then return end
    if bat.room ~= player.room then return end

    api.palette.setColor(2) -- dark gray
    -- Body
    api.gfx.rectangle("fill", bat.x + 2, bat.y + 2, 4, 4)
    -- Wings (animated flutter)
    local wingUp = math.floor(timer * 8) % 2 == 0
    if wingUp then
        api.gfx.rectangle("fill", bat.x, bat.y, 2, 3)
        api.gfx.rectangle("fill", bat.x + 6, bat.y, 2, 3)
    else
        api.gfx.rectangle("fill", bat.x, bat.y + 3, 2, 3)
        api.gfx.rectangle("fill", bat.x + 6, bat.y + 3, 2, 3)
    end
    -- Eyes
    api.palette.setColor(4)
    api.gfx.rectangle("fill", bat.x + 3, bat.y + 2, 1, 1)
    api.gfx.rectangle("fill", bat.x + 5, bat.y + 2, 1, 1)
end

-- ============================================================
-- DRAW: HUD (overlay at top)
-- ============================================================
drawHUD = function()
    -- Semi-transparent background for HUD
    api.gfx.setColor(0, 0, 0, 0.6)
    api.gfx.rectangle("fill", 0, 0, screenW, 10)

    -- Mode
    api.font.print("M" .. gameMode, 1, 2, 1, 0.6, 0.6, 0.6, 1)

    -- Timer
    local timeStr = formatTime(timer)
    api.font.print(timeStr, 20, 2, 1, 1, 1, 1, 1)

    -- Carried item
    if player.carrying then
        local it = items[player.carrying]
        if it then
            local name = it.def.name
            local tw = api.font.measure(name, 1)
            api.font.print(name, screenW - tw - 1, 2, 1, 1, 1, 0, 1)
        end
    end

    -- Best time (small)
    local best = bestTimes[gameMode]
    if best then
        local bstr = "B:" .. formatTime(best)
        local bw = api.font.measure(bstr, 1)
        api.font.print(bstr, screenW - bw - 1, screenH - 8, 1, 0.5, 0.5, 0.5, 1)
    end

    -- Room name (bottom left)
    local roomDef = World.rooms[player.room]
    if roomDef then
        api.font.print(roomDef.name, 1, screenH - 8, 1, 0.4, 0.4, 0.4, 1)
    end
end

-- ============================================================
-- DRAW: DEBUG OVERLAY
-- ============================================================
drawDebug = function()
    if not debugOn then return end
    api.gfx.setColor(0, 0, 0, 0.5)
    api.gfx.rectangle("fill", 0, 10, 80, 70)
    local y = 12
    api.font.print("ROOM:" .. player.room, 2, y, 1, 0, 1, 0, 1); y = y + 8
    api.font.print("X:" .. math.floor(player.x) .. " Y:" .. math.floor(player.y), 2, y, 1, 0, 1, 0, 1); y = y + 8
    api.font.print("CARRY:" .. tostring(player.carrying or "NONE"), 2, y, 1, 0, 1, 0, 1); y = y + 8
    for i, d in ipairs(dragons) do
        local ds = d.alive and "ALIVE" or "DEAD"
        api.font.print("D" .. i .. ":" .. ds .. " R" .. d.room, 2, y, 1, 0, 1, 0, 1); y = y + 8
    end
    if bat then
        api.font.print("BAT:R" .. bat.room .. " H:" .. tostring(bat.holding or "-"), 2, y, 1, 0, 1, 0, 1); y = y + 8
    end

    -- Draw exit markers
    local roomDef = World.rooms[player.room]
    if roomDef and roomDef.exits then
        api.palette.setColor(19) -- lime
        local cx = math.floor(screenW / 2)
        local cy = math.floor(screenH / 2)
        if roomDef.exits.up then api.gfx.rectangle("fill", cx - 1, 0, 3, 3) end
        if roomDef.exits.down then api.gfx.rectangle("fill", cx - 1, screenH - 3, 3, 3) end
        if roomDef.exits.left then api.gfx.rectangle("fill", 0, cy - 1, 3, 3) end
        if roomDef.exits.right then api.gfx.rectangle("fill", screenW - 3, cy - 1, 3, 3) end
    end

    -- Draw wall collision rects
    if roomDef then
        api.gfx.setColor(1, 0, 0, 0.3)
        for _, wall in ipairs(roomDef.walls) do
            api.gfx.rectangle("line", wall[1], wall[2], wall[3], wall[4])
        end
        -- Gate rect (yellow outline if locked)
        if roomDef.gate and not gates[roomDef.gate.keyId] then
            api.gfx.setColor(1, 1, 0, 0.5)
            local gr = roomDef.gate.rect
            api.gfx.rectangle("line", gr[1], gr[2], gr[3], gr[4])
        end
    end
end

-- ============================================================
-- ROOM VALIDATOR (runs once on load, prints warnings)
-- ============================================================
local function validateRooms()
    local cx = math.floor(screenW / 2)
    local cy = math.floor(screenH / 2)
    for id, room in pairs(World.rooms) do
        if room.exits then
            for dir, _ in pairs(room.exits) do
                local tx, ty
                if dir == "up" then tx, ty = cx, 1
                elseif dir == "down" then tx, ty = cx, screenH - 2
                elseif dir == "left" then tx, ty = 1, cy
                elseif dir == "right" then tx, ty = screenW - 2, cy
                end
                -- Check walls only (gates are expected to block when locked)
                if tx then
                    for _, wall in ipairs(room.walls) do
                        if rectOverlap(tx - 2, ty - 2, 4, 4, wall[1], wall[2], wall[3], wall[4]) then
                            print("[WORLD] Room " .. id .. " (" .. room.name .. "): " .. dir .. " exit blocked by wall!")
                            break
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- CART INTERFACE: LOAD
-- ============================================================
function Cart.load(engineAPI)
    api = engineAPI
    screenW = api.getWidth()
    screenH = api.getHeight()

    -- Load world data
    World   = require("cartridges.adventure_clone.levels.WORLD")
    Content = require("cartridges.adventure_clone.content")

    -- Register SFX presets
    for name, params in pairs(Content.sfxPresets) do
        api.sfx.setPreset(name, params)
    end

    -- Validate room geometry (prints warnings to console)
    validateRooms()

    -- Load highscores
    loadHighscores()

    -- Init shake state (needed before first initGame call)
    shakeTimer = 0
    shakeX, shakeY = 0, 0
    deadFreezeTimer = 0
    timer = 0
    deaths = 0

    -- Start at menu
    state = "MENU"
    menuSel = 1
    gameMode = 1
end

-- ============================================================
-- CART INTERFACE: UPDATE
-- ============================================================
function Cart.update(dt)
    -- Cap dt
    if dt > 0.05 then dt = 0.05 end

    if state == "PLAYING" then
        api.music.update(dt)
        updatePlaying(dt)

    elseif state == "DEAD_FREEZE" then
        updateShake(dt)
        deadFreezeTimer = deadFreezeTimer - dt
        if deadFreezeTimer <= 0 then
            respawnPlayer()
        end

    elseif state == "PAUSED" then
        -- Nothing to update

    elseif state == "MENU" then
        -- Menu music
        api.music.update(dt)

    elseif state == "WIN" then
        -- Just wait for input
    end
end

-- ============================================================
-- CART INTERFACE: DRAW
-- ============================================================
function Cart.draw()
    -- Apply screen shake
    if shakeTimer > 0 then
        api.gfx.push()
        api.gfx.translate(shakeX, shakeY)
    end

    if state == "MENU" then
        -- Menu screen
        api.gfx.setColor(0, 0, 0, 1)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        drawCentered("ADVENTURE-ISH", 20, 1, 1, 1, 0)

        -- Mode selection
        local modes = {"EASY", "MEDIUM", "HARD"}
        for i = 1, 3 do
            local sel = (i == menuSel)
            local y = 55 + (i - 1) * 18
            if sel then
                api.palette.setColor(15)
                api.gfx.rectangle("fill", 30, y - 1, 100, 12)
                api.font.print("> MODE " .. i .. ": " .. modes[i], 32, y + 1, 1, 0, 0, 0, 1)
            else
                api.font.print("  MODE " .. i .. ": " .. modes[i], 32, y + 1, 1, 0.7, 0.7, 0.7, 1)
            end
            -- Best time
            local bt = bestTimes[i]
            if bt then
                api.font.print(formatTime(bt), 105, y + 1, 1, 0.5, 0.8, 0.5, 1)
            end
        end

        -- Instructions
        drawCentered("FIND THE CHALICE", 120, 1, 0.6, 0.6, 0.6)
        drawCentered("BRING IT TO", 130, 1, 0.6, 0.6, 0.6)
        drawCentered("YELLOW CASTLE", 140, 1, 1, 1, 0)

        -- Controls hint
        drawCentered("ARROWS:MOVE SPACE:ACTION", 162, 1, 0.4, 0.4, 0.4)
        drawCentered("ENTER:START", 172, 1, 0.5, 0.5, 0.5)

        -- Blink
        local blink = math.floor(love.timer.getTime() * 3) % 2 == 0
        if blink then
            drawCentered("PRESS ENTER", 182, 1, 1, 1, 1)
        end

    elseif state == "PLAYING" or state == "DEAD_FREEZE" then
        drawRoom()
        drawItems()
        drawDragons()
        drawBat()
        drawPlayer()
        drawHUD()
        drawDebug()

        -- Death flash
        if state == "DEAD_FREEZE" then
            local flash = math.floor(deadFreezeTimer * 10) % 2 == 0
            if flash then
                api.gfx.setColor(1, 0, 0, 0.3)
                api.gfx.rectangle("fill", 0, 0, screenW, screenH)
            end
        end

    elseif state == "PAUSED" then
        drawRoom()
        drawItems()
        drawDragons()
        drawBat()
        drawPlayer()
        drawHUD()

        -- Pause overlay
        api.gfx.setColor(0, 0, 0, 0.6)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)
        drawCentered("PAUSED", screenH / 2 - 10, 2, 1, 1, 1)
        drawCentered("P TO RESUME", screenH / 2 + 10, 1, 0.7, 0.7, 0.7)
        drawCentered("R TO RESTART", screenH / 2 + 22, 1, 0.7, 0.7, 0.7)

    elseif state == "WIN" then
        -- Victory screen
        api.gfx.setColor(0, 0, 0, 1)
        api.gfx.rectangle("fill", 0, 0, screenW, screenH)

        drawCentered("YOU WIN!", 30, 2, 1, 1, 0)

        -- Chalice icon
        api.palette.setColor(15)
        drawItemShape(World.itemDefs.chalice, math.floor(screenW / 2) - 3, 60)

        local modes = {"EASY", "MEDIUM", "HARD"}
        drawCentered("MODE: " .. modes[gameMode], 80, 1, 1, 1, 1)
        drawCentered("TIME: " .. formatTime(timer), 95, 1, 1, 1, 1)
        drawCentered("DEATHS: " .. deaths, 108, 1, 1, 0.7, 0.7)

        local best = bestTimes[gameMode]
        if best then
            local isNew = (math.abs(best - timer) < 0.1)
            if isNew then
                drawCentered("NEW BEST!", 125, 1, 0, 1, 0)
            end
            drawCentered("BEST: " .. formatTime(best), 138, 1, 0.5, 1, 0.5)
        end

        drawCentered("ENTER:MENU  R:RETRY", 165, 1, 0.6, 0.6, 0.6)

        local blink = math.floor(love.timer.getTime() * 3) % 2 == 0
        if blink then
            drawCentered("PRESS ENTER", 180, 1, 1, 1, 1)
        end
    end

    -- Pop shake transform
    if shakeTimer > 0 then
        api.gfx.pop()
    end

    -- Reset color
    api.gfx.setColor(1, 1, 1, 1)
end

-- ============================================================
-- CART INTERFACE: KEYPRESSED
-- ============================================================
function Cart.keypressed(key)
    if state == "MENU" then
        if key == "up" or key == "w" then
            menuSel = menuSel - 1
            if menuSel < 1 then menuSel = 3 end
            api.sfx.play("menuMove")
        elseif key == "down" or key == "s" then
            menuSel = menuSel + 1
            if menuSel > 3 then menuSel = 1 end
            api.sfx.play("menuMove")
        elseif key == "return" or key == "space" or key == "z" then
            api.sfx.play("menuSelect")
            api.music.stop()
            initGame(menuSel)
        end

    elseif state == "PLAYING" then
        if key == "space" or key == "z" then
            -- Action: try unlock gate, or attack with sword, or pickup/drop
            local roomDef = World.rooms[player.room]

            -- Priority 1: unlock gate if near and carrying key
            if roomDef and roomDef.gate and not gates[roomDef.gate.keyId] then
                if player.carrying == roomDef.gate.keyId then
                    local gr = roomDef.gate.rect
                    local near = rectOverlap(player.x - 8, player.y - 8, PLAYER_W + 16, PLAYER_H + 16,
                                             gr[1], gr[2], gr[3], gr[4])
                    if near then
                        tryUnlock()
                        return
                    end
                end
            end

            -- Priority 2: attack with sword
            if player.carrying == "sword" then
                attackSword()
                return
            end

            -- Priority 3: pickup or drop
            if player.carrying then
                dropItem()
            else
                -- Find nearest item in room
                local bestDist = 20  -- pickup range
                local bestId = nil
                for id, it in pairs(items) do
                    if it.room == player.room and not it.carried then
                        local dx = (it.x) - player.x
                        local dy = (it.y) - player.y
                        local d = math.sqrt(dx * dx + dy * dy)
                        if d < bestDist then
                            bestDist = d
                            bestId = id
                        end
                    end
                end
                if bestId then
                    pickupItem(bestId)
                end
            end

        elseif key == "p" then
            state = "PAUSED"
            api.music.pause()

        elseif key == "r" then
            api.music.stop()
            initGame(gameMode)

        elseif key == "c" then
            debugOn = not debugOn
        end

    elseif state == "PAUSED" then
        if key == "p" then
            state = "PLAYING"
            api.music.resume()
        elseif key == "r" then
            api.music.stop()
            initGame(gameMode)
        end

    elseif state == "WIN" then
        if key == "return" or key == "space" then
            state = "MENU"
            menuSel = gameMode
            -- Start menu music
            api.music.loadSong({
                bpm = Content.music.bpm,
                speed = Content.music.speed,
                instruments = Content.music.instruments,
                patterns = Content.music.patterns,
                order = { 4, 4 },
            })
            api.music.play()
        elseif key == "r" then
            initGame(gameMode)
        end
    end
end

-- ============================================================
-- CART INTERFACE: UNLOAD
-- ============================================================
function Cart.unload()
    api.music.stop()
    -- Clear require caches
    package.loaded["cartridges.adventure_clone.levels.WORLD"] = nil
    package.loaded["cartridges.adventure_clone.content"] = nil
end

return Cart
