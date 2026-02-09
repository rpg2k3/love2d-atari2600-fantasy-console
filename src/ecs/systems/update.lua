-- src/ecs/systems/update.lua  Generic update system (velocity, animation)
local UpdateSystem = {}
UpdateSystem.__index = UpdateSystem

function UpdateSystem.new()
    return setmetatable({}, UpdateSystem)
end

function UpdateSystem:update(dt, world)
    -- Apply velocity to position
    for id, pos, vel in world:query({"position", "velocity"}) do
        pos.x = pos.x + vel.vx * dt
        pos.y = pos.y + vel.vy * dt
    end

    -- Animate sprites
    for id, anim, spr in world:query({"animation", "sprite"}) do
        anim.timer = anim.timer + dt
        if anim.timer >= anim.speed then
            anim.timer = anim.timer - anim.speed
            anim.frame = anim.frame + 1
            if anim.frame > #anim.frames then
                if anim.loop then
                    anim.frame = 1
                else
                    anim.frame = #anim.frames
                end
            end
            spr.spriteId = anim.frames[anim.frame]
        end
    end
end

return UpdateSystem
