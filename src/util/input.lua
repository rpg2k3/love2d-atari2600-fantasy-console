-- src/util/input.lua  Action mapping + key repeat helpers
local Input = {}

-- Action -> key mapping
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

-- Pressed / released this frame
local pressed  = {}
local released = {}
local held     = {}

function Input.keypressed(key)
    pressed[key] = true
    held[key] = true
end

function Input.keyreleased(key)
    released[key] = true
    held[key] = nil
end

function Input.endFrame()
    for k in pairs(pressed)  do pressed[k]  = nil end
    for k in pairs(released) do released[k] = nil end
end

function Input.isDown(action)
    local keys = Input.bindings[action]
    if not keys then return love.keyboard.isDown(action) end
    for _, k in ipairs(keys) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end

function Input.justPressed(action)
    local keys = Input.bindings[action]
    if not keys then return pressed[action] or false end
    for _, k in ipairs(keys) do
        if pressed[k] then return true end
    end
    return false
end

function Input.justReleased(action)
    local keys = Input.bindings[action]
    if not keys then return released[action] or false end
    for _, k in ipairs(keys) do
        if released[k] then return true end
    end
    return false
end

-- Raw key queries (for editor/system keys)
function Input.keyDown(key) return love.keyboard.isDown(key) end
function Input.keyPressed(key) return pressed[key] or false end

-- Mouse helpers (screen coords - caller converts via video.screenToInternal)
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

return Input
