-- src/gfx/tile.lua  Tile definitions (tiny grids of palette indices)
local Palette = require("src.gfx.palette")
local Config  = require("src.config")

local Tile = {}

-- Tile definitions: { id = { grid, w, h, image, flags } }
-- flags: { solid=bool, hazard=bool }
local defs   = {}
local images = {}

function Tile.define(id, grid, flags, w, h)
    w = w or Config.TILE_W
    h = h or Config.TILE_H
    flags = flags or {}
    defs[id] = { grid = grid, w = w, h = h, flags = flags }
    images[id] = nil
end

function Tile.getImage(id)
    if images[id] then return images[id] end
    local def = defs[id]
    if not def then return nil end
    local imgData = Palette.gridToImageData(def.grid, def.w, def.h)
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    images[id] = img
    return img
end

function Tile.invalidate(id)
    images[id] = nil
end

function Tile.invalidateAll()
    for k in pairs(images) do images[k] = nil end
end

function Tile.getDef(id)
    return defs[id]
end

function Tile.getFlags(id)
    local def = defs[id]
    return def and def.flags or {}
end

function Tile.isSolid(id)
    local f = Tile.getFlags(id)
    return f.solid or false
end

function Tile.isHazard(id)
    local f = Tile.getFlags(id)
    return f.hazard or false
end

function Tile.getAllIds()
    local ids = {}
    for id in pairs(defs) do ids[#ids+1] = id end
    table.sort(ids)
    return ids
end

function Tile.count()
    local n = 0
    for _ in pairs(defs) do n = n + 1 end
    return n
end

return Tile
