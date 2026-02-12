-- src/util/input.lua  Unified keyboard + gamepad action mapping
local Config = require("src.config")

local Input = {}

-- ============================================================
-- Keyboard action bindings (unchanged from original)
-- ============================================================
Input.bindings = {
    left      = {"left", "a"},
    right     = {"right", "d"},
    up        = {"up", "w"},
    down      = {"down", "s"},
    action1   = {"z", "j"},
    action2   = {"x", "k"},
    start     = {"return"},
    select    = {"rshift", "lshift"},
}

-- ============================================================
-- Keyboard state
-- ============================================================
local pressed  = {}
local released = {}

function Input.keypressed(key)
    pressed[key] = true
end

function Input.keyreleased(key)
    released[key] = true
end

-- ============================================================
-- Gamepad state
-- ============================================================
local activeGamepad = nil
local gpPressed  = {}
local gpReleased = {}
local gpHeld     = {}

-- Stick digital state
local stickValues  = {}   -- raw axis values (for debug)
local stickDigital = {}   -- past deadzone: ["leftx+"] = true
local stickJustOn  = {}   -- crossed into zone this frame
local stickJustOff = {}   -- crossed out this frame

-- Gamepad button → action mapping
local GP_BUTTON_TO_ACTION = {
    dpleft  = "left",
    dpright = "right",
    dpup    = "up",
    dpdown  = "down",
    a       = "action1",
    b       = "action2",
    x       = "action2",   -- alt secondary
    start   = "start",
    back    = "select",
}

-- Stick axis → action mapping
local STICK_TO_ACTION = {
    ["leftx-"] = "left",
    ["leftx+"] = "right",
    ["lefty-"] = "up",
    ["lefty+"] = "down",
}

-- ============================================================
-- Init: detect already-connected gamepads
-- ============================================================
function Input.init()
    local joysticks = love.joystick.getJoysticks()
    for _, j in ipairs(joysticks) do
        if j:isGamepad() then
            activeGamepad = j
            break
        end
    end
end

-- ============================================================
-- Gamepad callbacks
-- ============================================================
function Input.gamepadpressed(joystick, button)
    if joystick ~= activeGamepad then return end
    gpPressed[button] = true
    gpHeld[button]    = true
end

function Input.gamepadreleased(joystick, button)
    if joystick ~= activeGamepad then return end
    gpReleased[button] = true
    gpHeld[button]     = nil
end

function Input.joystickadded(joystick)
    if not activeGamepad and joystick:isGamepad() then
        activeGamepad = joystick
    end
end

function Input.joystickremoved(joystick)
    if joystick == activeGamepad then
        activeGamepad = nil
        gpHeld     = {}
        stickDigital = {}
        stickValues  = {}
        -- Try to find another gamepad
        for _, j in ipairs(love.joystick.getJoysticks()) do
            if j ~= joystick and j:isGamepad() then
                activeGamepad = j
                break
            end
        end
    end
end

-- ============================================================
-- Stick polling (call once per frame from App.update)
-- ============================================================
function Input.updateGamepad()
    stickJustOn  = {}
    stickJustOff = {}

    if not activeGamepad then return end
    if not activeGamepad:isConnected() then
        activeGamepad = nil
        gpHeld     = {}
        stickDigital = {}
        stickValues  = {}
        return
    end

    local dz = Config.STICK_DEADZONE
    for _, axis in ipairs({"leftx", "lefty"}) do
        local val = activeGamepad:getGamepadAxis(axis)
        stickValues[axis] = val

        local posK = axis .. "+"
        local negK = axis .. "-"
        local wasPos = stickDigital[posK] or false
        local wasNeg = stickDigital[negK] or false
        local isPos  = val >  dz
        local isNeg  = val < -dz

        if isPos and not wasPos then stickJustOn[posK]  = true end
        if isNeg and not wasNeg then stickJustOn[negK]  = true end
        if not isPos and wasPos then stickJustOff[posK] = true end
        if not isNeg and wasNeg then stickJustOff[negK] = true end

        stickDigital[posK] = isPos
        stickDigital[negK] = isNeg
    end
end

-- ============================================================
-- Unified queries: keyboard + gamepad
-- ============================================================
function Input.isDown(action)
    -- Keyboard
    local keys = Input.bindings[action]
    if keys then
        for _, k in ipairs(keys) do
            if love.keyboard.isDown(k) then return true end
        end
    elseif love.keyboard.isDown(action) then
        return true
    end

    -- Gamepad buttons
    if activeGamepad then
        for btn, act in pairs(GP_BUTTON_TO_ACTION) do
            if act == action and gpHeld[btn] then return true end
        end
        -- Stick digital
        for stickK, act in pairs(STICK_TO_ACTION) do
            if act == action and stickDigital[stickK] then return true end
        end
    end

    return false
end

function Input.justPressed(action)
    -- Keyboard
    local keys = Input.bindings[action]
    if keys then
        for _, k in ipairs(keys) do
            if pressed[k] then return true end
        end
    elseif pressed[action] then
        return true
    end

    -- Gamepad buttons
    if activeGamepad then
        for btn, act in pairs(GP_BUTTON_TO_ACTION) do
            if act == action and gpPressed[btn] then return true end
        end
        -- Stick digital
        for stickK, act in pairs(STICK_TO_ACTION) do
            if act == action and stickJustOn[stickK] then return true end
        end
    end

    return false
end

function Input.justReleased(action)
    -- Keyboard
    local keys = Input.bindings[action]
    if keys then
        for _, k in ipairs(keys) do
            if released[k] then return true end
        end
    elseif released[action] then
        return true
    end

    -- Gamepad buttons
    if activeGamepad then
        for btn, act in pairs(GP_BUTTON_TO_ACTION) do
            if act == action and gpReleased[btn] then return true end
        end
        -- Stick digital
        for stickK, act in pairs(STICK_TO_ACTION) do
            if act == action and stickJustOff[stickK] then return true end
        end
    end

    return false
end

-- ============================================================
-- Raw key queries (for editor/system keys - unchanged)
-- ============================================================
function Input.keyDown(key)    return love.keyboard.isDown(key) end
function Input.keyPressed(key) return pressed[key] or false end

-- ============================================================
-- End of frame: clear per-frame state
-- ============================================================
function Input.endFrame()
    for k in pairs(pressed)    do pressed[k]    = nil end
    for k in pairs(released)   do released[k]   = nil end
    for k in pairs(gpPressed)  do gpPressed[k]  = nil end
    for k in pairs(gpReleased) do gpReleased[k] = nil end
end

-- ============================================================
-- Mouse helpers (unchanged)
-- ============================================================
function Input.mouse()
    return love.mouse.getPosition()
end

function Input.mouseDown(btn)
    return love.mouse.isDown(btn or 1)
end

Input.mousePressedThisFrame = false
Input.mouseReleasedThisFrame = false

function Input.mousepressed()  Input.mousePressedThisFrame  = true end
function Input.mousereleased() Input.mouseReleasedThisFrame = true end

function Input.endMouseFrame()
    Input.mousePressedThisFrame  = false
    Input.mouseReleasedThisFrame = false
end

-- ============================================================
-- Gamepad debug accessors
-- ============================================================
function Input.getActiveGamepad()
    return activeGamepad
end

function Input.getStickValues()
    return stickValues
end

function Input.getGamepadHeld()
    return gpHeld
end

function Input.getStickJustPressed()
    return stickJustOn
end

function Input.hasGamepad()
    return activeGamepad ~= nil
end

return Input
