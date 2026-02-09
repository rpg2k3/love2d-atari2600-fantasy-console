-- src/app.lua  Boot + state switching (game <-> editor)
local Config    = require("src.config")
local Video     = require("src.platform.video")
local Input     = require("src.util.input")
local PixelFont = require("src.util.pixelfont")
local Palette   = require("src.gfx.palette")
local Music     = require("src.audio.music")

local DemoGame = require("src.game.demo_game")
local Editor   = require("src.editor.editor_app")

local App = {}

local mode = Config.MODE_GAME  -- "game" or "editor"
local helpVisible = false

function App.load()
    PixelFont.init()
    Video.init()
    DemoGame.init()
    Editor.init()
end

function App.update(dt)
    Video.update(dt)

    if mode == Config.MODE_GAME then
        DemoGame.update(dt)
    else
        Editor.update(dt)
    end
end

function App.draw()
    Video.beginFrame()

    if mode == Config.MODE_GAME then
        DemoGame.draw()
    else
        Editor.draw()
    end

    -- Debug overlay
    if Config.DEBUG_OVERLAY then
        App.drawDebug()
    end

    -- Help overlay
    if helpVisible then
        App.drawHelp()
    end

    Video.endFrame()
end

function App.keypressed(key)
    Input.keypressed(key)

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    -- Global keys
    if key == "f1" then
        if mode == Config.MODE_GAME then
            mode = Config.MODE_EDITOR
            Video.setEditorCurvatureOverride(true)
        else
            -- Apply edits before switching back
            local SE = require("src.editor.sprite_editor")
            SE.applyGrid()
            local TE = require("src.editor.tile_editor")
            TE.applyTile()
            mode = Config.MODE_GAME
            Video.setEditorCurvatureOverride(false)
        end
        return
    elseif key == "f2" then
        if shift then
            -- Shift+F2: toggle editor curvature override
            Video.toggleEditorCurve()
            -- Re-apply if we're in editor
            if mode == Config.MODE_EDITOR then
                Video.setEditorCurvatureOverride(true)
            end
        else
            Video.toggleCRT()
        end
        return
    elseif key == "f3" then
        Config.DEBUG_OVERLAY = not Config.DEBUG_OVERLAY
        return
    elseif key == "f4" then
        Video.cycleCRTPreset()
        return
    elseif key == "f5" then
        Video.cycleResolution()
        return
    elseif key == "f7" then
        Video.mouseDebug = not Video.mouseDebug
        return
    elseif key == "f12" then
        helpVisible = not helpVisible
        return
    elseif key == "escape" then
        if helpVisible then
            helpVisible = false
            return
        end
    end

    -- Pass to active mode
    if mode == Config.MODE_EDITOR then
        Editor.keypressed(key)
    else
        DemoGame.keypressed(key)
    end
end

function App.keyreleased(key)
    Input.keyreleased(key)
end

function App.mousepressed(x, y, button)
    Input.mousepressed()
end

function App.mousereleased(x, y, button)
    Input.mousereleased()
end

function App.resize(w, h)
    Video.recalcViewport()
end

function App.endFrame()
    Input.endFrame()
    Input.endMouseFrame()
end

-- Debug overlay
function App.drawDebug()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    local vx, vy, vw, vh = Video.getViewportRect()

    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", iw - 66, 0, 66, 42)

    local c = Palette.get(19)
    local y = 1
    PixelFont.print("FPS:" .. love.timer.getFPS(), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print("RES:" .. iw .. "X" .. ih, iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print(Video.getCRTLabel(), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print("MODE:" .. string.upper(mode), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print(string.format("VP:%d,%d", vw, vh), iw - 64, y, 1, c[1], c[2], c[3])
end

-- Help overlay
function App.drawHelp()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 4, 4, iw - 8, ih - 8)

    local c = Palette.get(15)
    local y = 8
    local x = 8
    PixelFont.print("=== CONTROLS ===", x, y, 1, c[1], c[2], c[3])
    y = y + 10

    local h = Palette.get(4)
    local lines = {
        "F1      TOGGLE GAME/EDITOR",
        "F2      TOGGLE CRT SHADER",
        "SHFT+F2 EDITOR CURVATURE",
        "F3      DEBUG OVERLAY",
        "F4      CYCLE CRT PRESET",
        "F5      CYCLE RESOLUTION",
        "F6      RELOAD LEVEL",
        "F7      MOUSE DEBUG",
        "F12     THIS HELP",
        "",
        "=== GAME ===",
        "ARROWS MOVE",
        "Z      JUMP",
        "",
        "=== LEVEL EDITOR ===",
        "TAB    TILE/OBJECT MODE",
        "G      TOGGLE SNAP",
        "L.CLK  PLACE/SELECT/DRAG",
        "R.CLK  ERASE TILE",
        "M.BTN  PAN CAMERA",
        "DEL    DELETE OBJECT",
        "CTRL+Z UNDO  CTRL+Y REDO",
        "CTRL+S SAVE",
    }
    for _, line in ipairs(lines) do
        if line:sub(1,3) == "===" then
            PixelFont.print(line, x, y, 1, c[1], c[2], c[3])
        else
            PixelFont.print(line, x, y, 1, h[1], h[2], h[3])
        end
        y = y + 7
    end
end

return App
