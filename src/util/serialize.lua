-- src/util/serialize.lua  Safe Lua table serialization (save/load)
local Serialize = {}

local function serializeValue(v, indent)
    local t = type(v)
    if t == "number" then
        return tostring(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        return Serialize.encode(v, indent)
    else
        return "nil"
    end
end

function Serialize.encode(tbl, indent)
    indent = indent or 0
    local pad  = string.rep("  ", indent)
    local pad1 = string.rep("  ", indent + 1)
    local parts = { "{\n" }
    -- array part
    local n = #tbl
    for i = 1, n do
        parts[#parts+1] = pad1 .. serializeValue(tbl[i], indent+1) .. ",\n"
    end
    -- hash part
    local seen = {}
    for i = 1, n do seen[i] = true end
    for k, v in pairs(tbl) do
        if not seen[k] then
            local ks
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                ks = k
            else
                ks = "[" .. serializeValue(k, indent+1) .. "]"
            end
            parts[#parts+1] = pad1 .. ks .. " = " .. serializeValue(v, indent+1) .. ",\n"
        end
    end
    parts[#parts+1] = pad .. "}"
    return table.concat(parts)
end

function Serialize.save(filename, tbl)
    local data = "return " .. Serialize.encode(tbl, 0) .. "\n"
    local ok, err = love.filesystem.write(filename, data)
    if not ok then
        print("[SERIALIZE] save error: " .. tostring(err))
    end
    return ok
end

function Serialize.load(filename)
    if not love.filesystem.getInfo(filename) then return nil end
    local data, err = love.filesystem.read(filename)
    if not data then
        print("[SERIALIZE] read error: " .. tostring(err))
        return nil
    end
    -- LuaJIT (Lua 5.1): loadstring + setfenv
    -- Lua 5.2+: load with env parameter
    local fn, lerr
    if setfenv then
        fn, lerr = loadstring(data)
        if fn then setfenv(fn, {}) end
    else
        fn, lerr = load(data, "chunk", "t", {})
    end
    if not fn then
        print("[SERIALIZE] parse error: " .. tostring(lerr))
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        print("[SERIALIZE] exec error: " .. tostring(result))
        return nil
    end
    return result
end

return Serialize
