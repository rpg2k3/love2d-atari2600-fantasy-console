-- src/game/demo_game.lua  Demo with level loading, ECS entity spawning, triggers
local World        = require("src.ecs.ecs")
local UpdateSystem = require("src.ecs.systems.update")
local RenderSystem = require("src.ecs.systems.render")
local Sprite       = require("src.gfx.sprite")
local SpriteAtlas  = require("src.gfx.sprite_atlas")
local Tile         = require("src.gfx.tile")
local Tilemap      = require("src.gfx.tilemap")
local Camera       = require("src.gfx.camera")
local Palette      = require("src.gfx.palette")
local Config       = require("src.config")
local Video        = require("src.platform.video")
local Input        = require("src.util.input")
local SFX          = require("src.audio.sfx")
local Music        = require("src.audio.music")
local Content      = require("src.game.content")
local Serialize    = require("src.util.serialize")
local PixelFont    = require("src.util.pixelfont")
local Mth          = require("src.util.math")

local Demo = {}

local world      = nil
local camera     = nil
local tilemap    = nil
local playerId   = nil
local score      = 0
local coins      = {}    -- coin entity IDs
local triggers   = {}    -- trigger entity IDs
local currentLevel = Config.DEFAULT_LEVEL
local spawnX, spawnY = 24, 100   -- respawn point (from player_spawn or checkpoint)
local reloadMsg  = ""
local reloadTime = 0

-- Player constants
local GRAVITY   = 300
local JUMP_VEL  = -140
local MOVE_SPD  = 50
local PLAYER_W  = 8
local PLAYER_H  = 8

-- ============================================================
-- Content registration (sprites, tiles, music)
-- ============================================================
local function registerContent()
    local saved = Serialize.load(Config.CONTENT_SAVE_PATH)
    local content = saved or Content

    if content.sprites then
        for id, def in pairs(content.sprites) do
            Sprite.define(id, def.grid, def.w, def.h)
        end
    end
    if content.tiles then
        for id, def in pairs(content.tiles) do
            Tile.define(id, def.grid, def.flags, def.w, def.h)
        end
    end
    if content.music then
        Music.import(content.music)
    end
end

-- ============================================================
-- Level loading
-- ============================================================
local function loadLevelFile(name)
    local path = Config.LEVELS_DIR .. "/" .. name .. ".lua"
    return Serialize.load(path)
end

local function buildTilemapFromLevel(level)
    local cols = level.w or Config.MAP_COLS
    local rows = level.h or Config.MAP_ROWS
    local tm = Tilemap.new(cols, rows, 2)
    if level.layers then
        if level.layers.bg then
            tm:import(level.layers.bg)
        end
        if level.layers.fg and level.layers.fg.data then
            local fgRows = level.layers.fg.data[1]
            if fgRows then tm.data[2] = fgRows end
        end
    end
    return tm
end

local function buildTilemapFromContent(content)
    content = content or Content
    local tm = Tilemap.new(
        content.tilemap and content.tilemap.cols or Config.MAP_COLS,
        content.tilemap and content.tilemap.rows or Config.MAP_ROWS,
        2
    )
    if content.tilemap and content.tilemap.data then
        tm:import(content.tilemap)
    end
    return tm
end

-- ============================================================
-- Entity spawning from level objects
-- ============================================================
local function spawnFromObjects(objs)
    coins    = {}
    triggers = {}
    spawnX, spawnY = 24, 100  -- default

    if not objs then return end

    for _, obj in ipairs(objs) do
        if obj.type == "player_spawn" then
            spawnX = obj.x
            spawnY = obj.y

        elseif obj.type == "coin" then
            local cid = world:newEntity()
            world:addComponent(cid, "position", { x = obj.x, y = obj.y })
            world:addComponent(cid, "sprite",   { spriteId = 4, flipX = false, flipY = false, scale = 1 })
            world:addComponent(cid, "coin", { value = (obj.props and obj.props.value) or 1 })
            coins[#coins + 1] = cid

        elseif obj.type == "enemy" then
            local eid = world:newEntity()
            local ai = (obj.props and obj.props.ai) or "patrol"
            local dir = (obj.props and obj.props.dir) or 1
            world:addComponent(eid, "position", { x = obj.x, y = obj.y })
            world:addComponent(eid, "velocity", { vx = 15 * dir, vy = 0 })
            world:addComponent(eid, "sprite",   { spriteId = 3, flipX = dir < 0, flipY = false, scale = 1 })
            world:addComponent(eid, "enemy",    { minX = obj.x - 40, maxX = obj.x + 40, ai = ai })

        elseif obj.type == "trigger" then
            local tid = world:newEntity()
            local tw = obj.w or 16
            local th = obj.h or 16
            world:addComponent(tid, "position", { x = obj.x, y = obj.y })
            world:addComponent(tid, "trigger", {
                w     = tw,
                h     = th,
                kind  = (obj.props and obj.props.kind) or "event",
                to    = (obj.props and obj.props.to) or "",
            })
            triggers[#triggers + 1] = tid

        elseif obj.type == "checkpoint" then
            -- Checkpoint: when player touches, update respawn point
            local cid = world:newEntity()
            world:addComponent(cid, "position", { x = obj.x, y = obj.y })
            world:addComponent(cid, "checkpoint", { activated = false })
        end
    end
end

local function spawnDefaultEntities()
    -- Fallback: spawn coins/enemies like original demo when no level file
    coins = {}
    triggers = {}
    spawnX, spawnY = 24, 100

    local coinPositions = {
        {x = 72, y = 120}, {x = 88, y = 120}, {x = 104, y = 120},
        {x = 152, y = 80}, {x = 168, y = 80},
        {x = 40, y = 56},  {x = 56, y = 56},
    }
    for _, cp in ipairs(coinPositions) do
        local cid = world:newEntity()
        world:addComponent(cid, "position", { x = cp.x, y = cp.y })
        world:addComponent(cid, "sprite",   { spriteId = 4, flipX = false, flipY = false, scale = 1 })
        world:addComponent(cid, "coin", { value = 1 })
        coins[#coins + 1] = cid
    end

    local eid = world:newEntity()
    world:addComponent(eid, "position", { x = 120, y = 144 })
    world:addComponent(eid, "velocity", { vx = 15, vy = 0 })
    world:addComponent(eid, "sprite",   { spriteId = 3, flipX = false, flipY = false, scale = 1 })
    world:addComponent(eid, "enemy",    { minX = 96, maxX = 176, ai = "patrol" })
end

-- ============================================================
-- Init / load level
-- ============================================================
local function initLevel(name)
    currentLevel = name or Config.DEFAULT_LEVEL
    registerContent()

    -- Try loading level file first
    local level = loadLevelFile(currentLevel)
    if level then
        tilemap = buildTilemapFromLevel(level)
    else
        -- Fallback to built-in content
        tilemap = buildTilemapFromContent()
    end

    -- Share tilemap with tile editor
    local TileEditor = require("src.editor.tile_editor")
    TileEditor.setTilemap(tilemap)

    -- Setup camera
    camera = Camera.new(0, 0)
    camera:setBounds(0, 0,
        math.max(0, tilemap:getPixelWidth() - Video.getInternalWidth()),
        math.max(0, tilemap:getPixelHeight() - Video.getInternalHeight()))

    -- Build ECS world
    world = World.new()
    world:addSystem(UpdateSystem.new())
    world:addSystem(RenderSystem.new(camera))

    -- Spawn entities from level objects or fallback
    if level and level.objects and #level.objects > 0 then
        spawnFromObjects(level.objects)
    else
        spawnDefaultEntities()
    end

    -- Spawn player at spawn point
    playerId = world:newEntity()
    world:addComponent(playerId, "position", { x = spawnX, y = spawnY })
    world:addComponent(playerId, "velocity", { vx = 0, vy = 0 })
    world:addComponent(playerId, "sprite",   { spriteId = 1, flipX = false, flipY = false, scale = 1 })
    world:addComponent(playerId, "animation", { frames = {1, 2}, frame = 1, timer = 0, speed = 0.25, loop = true })
    world:addComponent(playerId, "player", { onGround = false })

    score = 0
    Music.play()
end

function Demo.init()
    initLevel(Config.DEFAULT_LEVEL)
end

-- Reload current level from disk (F6)
function Demo.reload()
    Music.stop()
    world = nil
    initLevel(currentLevel)
    reloadMsg  = "RELOADED: " .. currentLevel
    reloadTime = 2.0
end

-- Load a specific level by name (for trigger transitions)
function Demo.loadLevel(name)
    Music.stop()
    world = nil
    initLevel(name)
end

-- ============================================================
-- Update
-- ============================================================
function Demo.update(dt)
    if not world then return end

    if reloadTime > 0 then
        reloadTime = reloadTime - dt
        if reloadTime <= 0 then reloadMsg = "" end
    end

    -- Player input
    local pos = world:getComponent(playerId, "position")
    local vel = world:getComponent(playerId, "velocity")
    local plr = world:getComponent(playerId, "player")
    local spr = world:getComponent(playerId, "sprite")

    if pos and vel and plr then
        -- Horizontal movement
        vel.vx = 0
        if Input.isDown("left") then
            vel.vx = -MOVE_SPD
            spr.flipX = true
        end
        if Input.isDown("right") then
            vel.vx = MOVE_SPD
            spr.flipX = false
        end

        -- Gravity
        vel.vy = vel.vy + GRAVITY * dt

        -- Jump
        if plr.onGround and Input.justPressed("action1") then
            vel.vy = JUMP_VEL
            plr.onGround = false
            SFX.play("jump")
        end
    end

    -- ECS update (applies velocity, animation, etc.)
    world:update(dt)

    -- Post-update: collision with tilemap
    if pos and vel and plr then
        -- Horizontal collision
        local testX = pos.x + (vel.vx > 0 and PLAYER_W - 1 or 0)
        if tilemap:isSolid(testX, pos.y + 2) or tilemap:isSolid(testX, pos.y + PLAYER_H - 2) then
            pos.x = pos.x - vel.vx * dt
            vel.vx = 0
        end

        -- Vertical collision (feet)
        plr.onGround = false
        if vel.vy >= 0 then
            if tilemap:isSolid(pos.x + 2, pos.y + PLAYER_H) or
               tilemap:isSolid(pos.x + PLAYER_W - 2, pos.y + PLAYER_H) then
                local tileRow = math.floor((pos.y + PLAYER_H) / Config.TILE_H)
                pos.y = tileRow * Config.TILE_H - PLAYER_H
                vel.vy = 0
                plr.onGround = true
            end
        elseif vel.vy < 0 then
            if tilemap:isSolid(pos.x + 2, pos.y) or
               tilemap:isSolid(pos.x + PLAYER_W - 2, pos.y) then
                vel.vy = 0
            end
        end

        -- Clamp to world bounds
        pos.x = math.max(0, math.min(pos.x, tilemap:getPixelWidth() - PLAYER_W))
        if pos.y > tilemap:getPixelHeight() then
            pos.x = spawnX
            pos.y = spawnY
            vel.vy = 0
            SFX.play("hit")
        end
    end

    -- Enemy AI (bounce between min/max)
    for id, epos, evel, enemy in world:query({"position", "velocity", "enemy"}) do
        if enemy.ai == "patrol" or not enemy.ai then
            if epos.x <= enemy.minX then
                evel.vx = math.abs(evel.vx)
                local espr = world:getComponent(id, "sprite")
                if espr then espr.flipX = false end
            elseif epos.x >= enemy.maxX then
                evel.vx = -math.abs(evel.vx)
                local espr = world:getComponent(id, "sprite")
                if espr then espr.flipX = true end
            end
        end
    end

    -- Coin pickup
    if pos then
        for i = #coins, 1, -1 do
            local cid = coins[i]
            local cpos = world:getComponent(cid, "position")
            local coinData = world:getComponent(cid, "coin")
            if cpos then
                local dx = math.abs(pos.x + 4 - cpos.x - 4)
                local dy = math.abs(pos.y + 4 - cpos.y - 4)
                if dx < 7 and dy < 7 then
                    local val = (type(coinData) == "table" and coinData.value) or 1
                    world:removeEntity(cid)
                    table.remove(coins, i)
                    score = score + val * 10
                    SFX.play("coin")
                end
            end
        end
    end

    -- Trigger overlap
    if pos then
        for _, tid in ipairs(triggers) do
            local tpos = world:getComponent(tid, "position")
            local trig = world:getComponent(tid, "trigger")
            if tpos and trig then
                if Mth.aabb(pos.x, pos.y, PLAYER_W, PLAYER_H,
                            tpos.x, tpos.y, trig.w, trig.h) then
                    if trig.kind == "exit" and trig.to and #trig.to > 0 then
                        Demo.loadLevel(trig.to)
                        return  -- stop updating this frame
                    end
                end
            end
        end
    end

    -- Checkpoint overlap
    if pos then
        for id, cpos, cp in world:query({"position", "checkpoint"}) do
            if not cp.activated then
                local dx = math.abs(pos.x + 4 - cpos.x - 4)
                local dy = math.abs(pos.y + 4 - cpos.y - 4)
                if dx < 8 and dy < 8 then
                    cp.activated = true
                    spawnX = cpos.x
                    spawnY = cpos.y
                    SFX.play("menuSelect")
                end
            end
        end
    end

    -- Camera follow
    if pos then
        camera:follow(pos.x + 4, pos.y + 4, Video.getInternalWidth(), Video.getInternalHeight())
        camera:update(dt)
    end

    -- Music update is handled globally by App.update
end

-- ============================================================
-- Draw
-- ============================================================
function Demo.draw()
    if not world then return end

    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Sky background
    Palette.setColor(25)  -- dark blue
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- Draw tilemap layer 1 (bg/main)
    tilemap:draw(1, camera.x, camera.y, iw, ih)

    -- Draw ECS entities (sprites)
    world:draw()

    -- Draw tilemap layer 2 (fg)
    tilemap:draw(2, camera.x, camera.y, iw, ih)

    -- Draw trigger outlines (debug-visible in game for now)
    -- (Only visible with F3 debug overlay)
    if Config.DEBUG_OVERLAY then
        for _, tid in ipairs(triggers) do
            local tpos = world:getComponent(tid, "position")
            local trig = world:getComponent(tid, "trigger")
            if tpos and trig then
                love.graphics.setColor(0.7, 0.3, 0.9, 0.4)
                love.graphics.rectangle("line",
                    math.floor(tpos.x - camera.x),
                    math.floor(tpos.y - camera.y),
                    trig.w, trig.h)
            end
        end
    end

    -- HUD
    local c = Palette.get(15)
    PixelFont.print("SCORE:" .. score, 2, 2, 1, c[1], c[2], c[3])

    -- Level name
    local nc = Palette.get(3)
    PixelFont.print(currentLevel, iw - #currentLevel * 4 - 2, 2, 1, nc[1], nc[2], nc[3])

    -- Reload message
    if #reloadMsg > 0 then
        local rc = Palette.get(19)
        PixelFont.print(reloadMsg, 2, 10, 1, rc[1], rc[2], rc[3])
    end
end

-- ============================================================
-- Keypressed
-- ============================================================
function Demo.keypressed(key)
    -- F6: reload current level from disk
    if key == "f6" then
        Demo.reload()
    end
end

function Demo.shutdown()
    Music.stop()
    world = nil
end

return Demo
