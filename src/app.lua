-- src/app.lua  Boot + cartridge + state switching (boot <-> cart <-> editor)
local Config      = require("src.config")
local Video       = require("src.platform.video")
local Input       = require("src.util.input")
local PixelFont   = require("src.util.pixelfont")
local Palette     = require("src.gfx.palette")
local Music       = require("src.audio.music")

local CartManager = require("src.os.cart_manager")
local BootMenu    = require("src.os.boot_menu")
local Editor      = require("src.editor.editor_app")

local App = {}

local state       = Config.MODE_BOOT  -- "boot", "cart", "editor"
local helpVisible = false
local activeCart   = nil   -- cart module with load/update/draw/keypressed/unload

function App.load()
    PixelFont.init()
    Video.init()
    BootMenu.init()
    Editor.init()
end

function App.update(dt)
    Video.update(dt)

    if state == Config.MODE_BOOT then
        BootMenu.update(dt)
        local selected = BootMenu.getSelected()
        if selected then
            App.startCart(selected)
        end
    elseif state == Config.MODE_CART then
        if activeCart and activeCart.update then
            activeCart.update(dt)
        end
    elseif state == Config.MODE_EDITOR then
        Editor.update(dt)
    end
end

function App.draw()
    Video.beginFrame()

    if state == Config.MODE_BOOT then
        BootMenu.draw()
    elseif state == Config.MODE_CART then
        if activeCart and activeCart.draw then
            activeCart.draw()
        end
    elseif state == Config.MODE_EDITOR then
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

-- ============================================================
-- Cart lifecycle
-- ============================================================
function App.startCart(cartInfo)
    local cartMod = CartManager.loadCart(cartInfo)
    if cartMod then
        activeCart = cartMod
        state = Config.MODE_CART
    end
    BootMenu.clearSelection()
end

function App.stopCart()
    if activeCart and activeCart.unload then
        activeCart.unload()
    end
    CartManager.unloadCart()
    activeCart = nil
    state = Config.MODE_BOOT
    BootMenu.refresh()
end

-- ============================================================
-- Input
-- ============================================================
function App.keypressed(key)
    Input.keypressed(key)

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    -- Global F-keys (work in all states)
    if key == "f2" then
        if shift then
            Video.toggleEditorCurve()
            if state == Config.MODE_EDITOR then
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
    end

    -- Escape closes help in any state
    if key == "escape" and helpVisible then
        helpVisible = false
        return
    end

    -- State-specific keys
    if state == Config.MODE_BOOT then
        BootMenu.keypressed(key)

    elseif state == Config.MODE_CART then
        if key == "f1" then
            -- Switch to editor
            state = Config.MODE_EDITOR
            Video.setEditorCurvatureOverride(true)
            return
        elseif key == "escape" then
            -- Return to boot menu
            App.stopCart()
            return
        end
        -- Pass to cart
        if activeCart and activeCart.keypressed then
            activeCart.keypressed(key)
        end

    elseif state == Config.MODE_EDITOR then
        if key == "f1" then
            -- Apply edits and return to cart
            local SE = require("src.editor.sprite_editor")
            SE.applyGrid()
            local TE = require("src.editor.tile_editor")
            TE.applyTile()
            state = Config.MODE_CART
            Video.setEditorCurvatureOverride(false)
            return
        end
        Editor.keypressed(key)
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

-- ============================================================
-- Debug overlay
-- ============================================================
function App.drawDebug()
    local iw = Video.getInternalWidth()
    local vx, vy, vw, vh = Video.getViewportRect()

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", iw - 66, 0, 66, 49)

    local c = Palette.get(19)
    local y = 1
    PixelFont.print("FPS:" .. love.timer.getFPS(), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print("RES:" .. iw .. "X" .. Video.getInternalHeight(), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print(Video.getCRTLabel(), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print("MODE:" .. string.upper(state), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    PixelFont.print(string.format("VP:%d,%d", vw, vh), iw - 64, y, 1, c[1], c[2], c[3])
    y = y + 7
    local cartName = CartManager.getCurrentName()
    if cartName then
        PixelFont.print(string.sub(cartName, 1, 10), iw - 64, y, 1, c[1], c[2], c[3])
    end
end

-- ============================================================
-- Help overlay
-- ============================================================
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
        "F1      CART/EDITOR",
        "F2      CRT SHADER",
        "F3      DEBUG OVERLAY",
        "F4      CRT PRESET",
        "F5      RESOLUTION",
        "F12     THIS HELP",
        "ESC     BACK TO BOOT",
        "",
        "=== GAME ===",
        "ARROWS  MOVE",
        "Z       JUMP",
        "",
        "=== EDITOR ===",
        "TAB     TILE/OBJ MODE",
        "G       SNAP ON/OFF",
        "L.CLK   PLACE/DRAG",
        "R.CLK   ERASE",
        "M.BTN   PAN",
        "DEL     DELETE",
        "CTRL+Z  UNDO",
        "CTRL+Y  REDO",
        "CTRL+S  SAVE",
    }
    for _, line in ipairs(lines) do
        if line:sub(1, 3) == "===" then
            PixelFont.print(line, x, y, 1, c[1], c[2], c[3])
        else
            PixelFont.print(line, x, y, 1, h[1], h[2], h[3])
        end
        y = y + 7
    end
end

return App
