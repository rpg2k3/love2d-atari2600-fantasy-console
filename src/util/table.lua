-- src/util/table.lua  Table helpers
local T = {}

function T.deepcopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[T.deepcopy(k)] = T.deepcopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
end

function T.merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

function T.keys(t)
    local ks = {}
    for k in pairs(t) do ks[#ks+1] = k end
    return ks
end

function T.contains(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

function T.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function T.clear(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

return T
