-- src/ecs/systems/render.lua  Sprite render system
local Sprite = require("src.gfx.sprite")

local RenderSystem = {}
RenderSystem.__index = RenderSystem

function RenderSystem.new(camera)
    return setmetatable({ camera = camera }, RenderSystem)
end

function RenderSystem:draw(world)
    local cam = self.camera
    local cx, cy = 0, 0
    if cam then
        cx, cy = cam.x, cam.y
    end

    for id, pos, spr in world:query({"position", "sprite"}) do
        local img = Sprite.getImage(spr.spriteId)
        if img then
            local sx = spr.flipX and -1 or 1
            local sy = spr.flipY and -1 or 1
            local scale = spr.scale or 1
            local ox = spr.flipX and img:getWidth() or 0
            local oy = spr.flipY and img:getHeight() or 0
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img,
                math.floor(pos.x - cx), math.floor(pos.y - cy),
                0, sx * scale, sy * scale, ox, oy)
        end
    end
end

return RenderSystem
