-- src/util/math.lua  Math helpers
local M = {}

function M.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.sign(x)
    if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end
end

function M.round(x)
    return math.floor(x + 0.5)
end

function M.wrap(x, lo, hi)
    return lo + (x - lo) % (hi - lo)
end

function M.distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

function M.aabb(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx+bw and ax+aw > bx and ay < by+bh and ay+ah > by
end

return M
