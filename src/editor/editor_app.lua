-- src/editor/editor_app.lua  Editor mode router (tabs: Sprite, SFX, Music, Tiles, Level)
local UI          = require("src.util.ui")
local Input       = require("src.util.input")
local Video       = require("src.platform.video")
local PixelFont   = require("src.util.pixelfont")
local Serialize   = require("src.util.serialize")
local Config      = require("src.config")
local Palette     = require("src.gfx.palette")
local CartManager = require("src.os.cart_manager")
local Packager    = require("src.os.cart_packager")

local SpriteEditor = require("src.editor.sprite_editor")
local SfxEditor    = require("src.editor.sfx_editor")
local MusicEditor  = require("src.editor.music_editor")
local TileEditor   = require("src.editor.tile_editor")
local LevelEditor  = require("src.editor.level_editor")

local Editor = {}

local TAB_NAMES = { "SPR", "SFX", "MUS", "TILE", "LVL" }
local tabs = { SpriteEditor, SfxEditor, MusicEditor, TileEditor, LevelEditor }
local currentTab = 1
local initialized = false

-- Status toast
local editorStatus      = nil
local editorStatusTimer = 0
local EDITOR_STATUS_DUR = 3

function Editor.init()
    if initialized then return end
    for _, t in ipairs(tabs) do
        if t.init then t.init() end
    end
    initialized = true
end

function Editor.update(dt)
    local tab = tabs[currentTab]
    if tab and tab.update then tab.update(dt) end
    if editorStatusTimer > 0 then
        editorStatusTimer = editorStatusTimer - dt
        if editorStatusTimer <= 0 then
            editorStatus      = nil
            editorStatusTimer = 0
        end
    end
end

function Editor.draw()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- Tab bar at top
    local tabW = math.floor(iw / #TAB_NAMES) - 1
    local tabH = 8
    currentTab = UI.tabs(TAB_NAMES, currentTab, 0, 0, tabW, tabH)

    -- Active editor
    local tab = tabs[currentTab]
    if tab and tab.draw then tab.draw(tabH + 1) end

    -- Status toast
    if editorStatus then
        local sc = Palette.get(15)
        PixelFont.print(editorStatus, 8, ih - 16, 1, sc[1], sc[2], sc[3])
    end

    -- Bottom status (skip for level editor and music editor, which draw their own)
    if currentTab ~= 5 and currentTab ~= 3 then
        local c = {0.6, 0.6, 0.6, 1}
        PixelFont.print("F1:GAME ^S:SAVE ^E:EXPORT", 1, ih - 7, 1, c[1], c[2], c[3], c[4])
    end
end

function Editor.keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Ctrl+E: export current cart with save overrides
    if ctrl and key == "e" then
        local cur = CartManager.getCurrent()
        if cur then
            Editor.saveAll()
            local result = Packager.exportCart(cur.dir, { withSaveOverrides = true })
            if result.ok then
                editorStatus      = "EXPORTED: " .. string.upper(result.filename)
                editorStatusTimer = EDITOR_STATUS_DUR
            else
                editorStatus      = "EXPORT ERR: " .. (result.err or "?")
                editorStatusTimer = EDITOR_STATUS_DUR
            end
        else
            editorStatus      = "NO CART LOADED"
            editorStatusTimer = EDITOR_STATUS_DUR
        end
        return true
    end

    -- Ctrl+S: if on level tab, delegate to level editor; otherwise save content
    if ctrl and key == "s" then
        if currentTab == 5 then
            -- Level editor handles its own save
            LevelEditor.keypressed(key)
        else
            Editor.saveAll()
            editorStatus      = "SAVED!"
            editorStatusTimer = EDITOR_STATUS_DUR
        end
        return true
    end
    local tab = tabs[currentTab]
    if tab and tab.keypressed then return tab.keypressed(key) end
end

function Editor.saveAll()
    -- Gather all content and save
    local content = {}
    content.sprites = require("src.gfx.sprite_atlas").export()

    -- Tiles
    local Tile = require("src.gfx.tile")
    local tileIds = Tile.getAllIds()
    content.tiles = {}
    for _, id in ipairs(tileIds) do
        local def = Tile.getDef(id)
        if def then
            content.tiles[id] = { grid = def.grid, w = def.w, h = def.h, flags = def.flags }
        end
    end

    -- SFX
    local SFX = require("src.audio.sfx")
    content.sfx = {}
    for _, name in ipairs(SFX.getPresetNames()) do
        content.sfx[name] = SFX.getPreset(name)
    end

    -- Music
    local MusicMod = require("src.audio.music")
    content.music = MusicMod.export()

    -- Tilemap (from tile editor, for backward compat)
    if TileEditor.tilemap then
        content.tilemap = TileEditor.tilemap:export()
    end

    local saveDir = Config.CONTENT_SAVE_PATH:match("(.*)/")
    if saveDir then love.filesystem.createDirectory(saveDir) end
    Serialize.save(Config.CONTENT_SAVE_PATH, content)
    print("[EDITOR] Content saved to " .. Config.CONTENT_SAVE_PATH)
end

return Editor
