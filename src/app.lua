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
local paused      = false  -- global pause (only active in cart state)

function App.load()
    PixelFont.init()
    Video.init()
    Input.init()
    BootMenu.init()
    Editor.init()
end

function App.update(dt)
    -- Poll gamepad stick axes + convert to digital
    Input.updateGamepad()

    -- Synthesize key events from stick movement
    local stickJP = Input.getStickJustPressed()
    if stickJP["lefty-"] then App.keypressed("up")    end
    if stickJP["lefty+"] then App.keypressed("down")  end
    if stickJP["leftx-"] then App.keypressed("left")  end
    if stickJP["leftx+"] then App.keypressed("right") end

    Video.update(dt)

    -- Music engine runs in all modes (cart playback + editor preview)
    Music.update(dt)

    if state == Config.MODE_BOOT then
        BootMenu.update(dt)
        local selected = BootMenu.getSelected()
        if selected then
            App.startCart(selected)
        end
    elseif state == Config.MODE_CART then
        if not paused and activeCart and activeCart.update then
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
        if paused then
            App.drawPauseOverlay()
        end
    elseif state == Config.MODE_EDITOR then
        Editor.draw()
    end

    -- Debug overlay
    if Config.DEBUG_OVERLAY then
        App.drawDebug()
    end

    -- Gamepad debug overlay
    if Config.GAMEPAD_DEBUG then
        App.drawGamepadDebug()
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
    if paused then
        Music.resume()
        paused = false
    end
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
    elseif key == "f9" then
        Config.GAMEPAD_DEBUG = not Config.GAMEPAD_DEBUG
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
        -- P toggles pause
        if key == "p" then
            paused = not paused
            if paused then
                Music.pause()
            else
                Music.resume()
            end
            return
        end
        if key == "f1" then
            -- Switch to editor (pause state preserved)
            state = Config.MODE_EDITOR
            Video.setEditorCurvatureOverride(true)
            return
        elseif key == "escape" then
            -- Return to boot menu (resets pause)
            App.stopCart()
            return
        end
        -- While paused, don't pass keys to cart
        if paused then return end
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

-- ============================================================
-- Gamepad input
-- ============================================================
function App.gamepadpressed(joystick, button)
    Input.gamepadpressed(joystick, button)

    -- D-pad → direct key mapping (all states)
    if     button == "dpup"    then App.keypressed("up")    return
    elseif button == "dpdown"  then App.keypressed("down")  return
    elseif button == "dpleft"  then App.keypressed("left")  return
    elseif button == "dpright" then App.keypressed("right") return
    end

    -- A (bottom face): confirm in menus, action1 in game, unpause when paused
    if button == "a" then
        if state == Config.MODE_CART then
            if paused then
                App.keypressed("p")      -- unpause
            else
                App.keypressed("z")      -- action1
            end
        else
            App.keypressed("return")     -- confirm in menus
        end
        return
    end

    -- B (right face): back in menus, action2 in game, escape when paused
    if button == "b" then
        if state == Config.MODE_CART and not paused then
            App.keypressed("x")          -- action2
        else
            App.keypressed("escape")     -- back / exit
        end
        return
    end

    -- Start/Plus: pause in cart, confirm in menus
    if button == "start" then
        if state == Config.MODE_CART then
            App.keypressed("p")          -- toggle pause
        else
            App.keypressed("return")     -- confirm
        end
        return
    end

    -- Back/Minus: always escape
    if button == "back" then
        App.keypressed("escape")
        return
    end

    -- Y button: settings shortcut in boot menu
    if button == "y" then
        if state == Config.MODE_BOOT then
            App.keypressed("s")
        end
        return
    end
end

function App.gamepadreleased(joystick, button)
    Input.gamepadreleased(joystick, button)
end

function App.joystickadded(joystick)
    Input.joystickadded(joystick)
end

function App.joystickremoved(joystick)
    Input.joystickremoved(joystick)
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
        "F9      GAMEPAD DEBUG",
        "F12     THIS HELP",
        "ESC     BACK TO BOOT",
        "",
        "=== GAME ===",
        "P       PAUSE",
        "ARROWS  MOVE",
        "Z/A BTN ACTION",
        "",
        "=== GAMEPAD ===",
        "D-PAD   NAVIGATE/MOVE",
        "STICK   NAVIGATE/MOVE",
        "A BTN   CONFIRM/ACTION",
        "B BTN   BACK/ACTION2",
        "START   PAUSE/CONFIRM",
        "",
        "=== EDITOR ===",
        "CTRL+S  SAVE",
        "CTRL+Z  UNDO",
        "CTRL+Y  REDO",
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

-- ============================================================
-- Gamepad debug overlay (F9)
-- ============================================================
function App.drawGamepadDebug()
    local iw = Video.getInternalWidth()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, iw, 32)

    local c = Palette.get(23)
    local y = 2
    local gp = Input.getActiveGamepad()

    if gp then
        local name = gp:getName() or "?"
        PixelFont.print("PAD:" .. name:sub(1, 20):upper(), 2, y, 1, c[1], c[2], c[3])
        y = y + 7
        -- Held buttons
        local btns = ""
        for b in pairs(Input.getGamepadHeld()) do btns = btns .. b:upper() .. " " end
        if btns == "" then btns = "-" end
        PixelFont.print("BTN:" .. btns:sub(1, 28), 2, y, 1, c[1], c[2], c[3])
        y = y + 7
        -- Stick values
        local sv = Input.getStickValues()
        PixelFont.print(string.format("LX:%.2f LY:%.2f", sv.leftx or 0, sv.lefty or 0),
            2, y, 1, c[1], c[2], c[3])
        y = y + 7
        -- Deadzone indicator
        local dz = Config.STICK_DEADZONE
        local lx = math.abs(sv.leftx or 0)
        local ly = math.abs(sv.lefty or 0)
        local dzLabel = (lx > dz or ly > dz) and "ACTIVE" or "IDLE"
        PixelFont.print("STICK:" .. dzLabel .. " DZ:" .. dz, 2, y, 1, c[1], c[2], c[3])
    else
        PixelFont.print("NO GAMEPAD CONNECTED", 2, y, 1, c[1], c[2], c[3])
        y = y + 7
        local jc = love.joystick.getJoystickCount()
        PixelFont.print("JOYSTICKS:" .. jc, 2, y, 1, c[1], c[2], c[3])
    end
end

-- ============================================================
-- Pause overlay
-- ============================================================
function App.drawPauseOverlay()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- "PAUSED" centered
    local title = "PAUSED"
    local hint  = Input.hasGamepad() and "A:RESUME  B:MENU" or "P:RESUME  ESC:MENU"
    local tw = #title * 6   -- PixelFont char width ~5px + 1px spacing
    local hw = #hint * 6
    local c = Palette.get(15)  -- bright white/yellow
    local h = Palette.get(4)   -- muted colour for hint

    PixelFont.print(title, math.floor((iw - tw) / 2), math.floor(ih / 2) - 6, 1, c[1], c[2], c[3])
    PixelFont.print(hint,  math.floor((iw - hw) / 2), math.floor(ih / 2) + 4, 1, h[1], h[2], h[3])
end

return App
