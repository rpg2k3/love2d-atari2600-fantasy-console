-- src/util/log.lua  Simple logging utility
local Log = {}
Log.level = 2  -- 0=silent, 1=error, 2=warn, 3=info, 4=debug

local TAGS = { [1]="ERROR", [2]="WARN", [3]="INFO", [4]="DEBUG" }

local function emit(lvl, ...)
    if lvl > Log.level then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    print(string.format("[%s] %s", TAGS[lvl] or "?", table.concat(parts, " ")))
end

function Log.error(...) emit(1, ...) end
function Log.warn(...)  emit(2, ...) end
function Log.info(...)  emit(3, ...) end
function Log.debug(...) emit(4, ...) end

return Log
