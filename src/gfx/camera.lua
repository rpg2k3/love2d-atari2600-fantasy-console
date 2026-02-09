-- src/gfx/camera.lua  Simple 2D camera with follow and bounds
local Mth = require("src.util.math")

local Camera = {}
Camera.__index = Camera

function Camera.new(x, y)
    return setmetatable({
        x = x or 0,
        y = y or 0,
        targetX = 0,
        targetY = 0,
        smoothing = 5,    -- higher = snappier
        boundsMinX = nil,
        boundsMinY = nil,
        boundsMaxX = nil,
        boundsMaxY = nil,
    }, Camera)
end

function Camera:follow(tx, ty, viewW, viewH)
    -- Center target in view
    self.targetX = tx - viewW / 2
    self.targetY = ty - viewH / 2
end

function Camera:update(dt)
    local s = self.smoothing * dt
    if s > 1 then s = 1 end
    self.x = Mth.lerp(self.x, self.targetX, s)
    self.y = Mth.lerp(self.y, self.targetY, s)
    -- Clamp to bounds
    if self.boundsMinX then self.x = math.max(self.x, self.boundsMinX) end
    if self.boundsMinY then self.y = math.max(self.y, self.boundsMinY) end
    if self.boundsMaxX then self.x = math.min(self.x, self.boundsMaxX) end
    if self.boundsMaxY then self.y = math.min(self.y, self.boundsMaxY) end
    -- Snap to pixels
    self.x = math.floor(self.x)
    self.y = math.floor(self.y)
end

function Camera:setBounds(minX, minY, maxX, maxY)
    self.boundsMinX = minX
    self.boundsMinY = minY
    self.boundsMaxX = maxX
    self.boundsMaxY = maxY
end

return Camera
