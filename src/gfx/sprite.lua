-- src/gfx/sprite.lua  Atari-style sprite builder from tiny grids
local Palette = require("src.gfx.palette")
local Config  = require("src.config")
local Log     = require("src.util.log")

local Sprite = {}

-- Sprite definitions: { id = { grid={rows of palette indices}, w, h, image } }
local defs = {}
local images = {}

-- Register a sprite definition from a grid of palette indices
function Sprite.define(id, grid, w, h)
    w = w or Config.SPRITE_W
    h = h or Config.SPRITE_H
    -- Validate color count
    local ok, count = Palette.validateGrid(grid, Config.MAX_SPRITE_COLORS)
    if not ok then
        Log.warn("Sprite", id, "uses", count, "colors (max " .. Config.MAX_SPRITE_COLORS .. ")")
    end
    defs[id] = { grid = grid, w = w, h = h }
    images[id] = nil  -- invalidate cached image
end

-- Build or get cached Image for a sprite
function Sprite.getImage(id)
    if images[id] then return images[id] end
    local def = defs[id]
    if not def then return nil end
    local imgData = Palette.gridToImageData(def.grid, def.w, def.h)
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    images[id] = img
    return img
end

-- Invalidate a sprite's cached image (after editing)
function Sprite.invalidate(id)
    images[id] = nil
end

-- Invalidate all
function Sprite.invalidateAll()
    for k in pairs(images) do images[k] = nil end
end

-- Get the grid definition
function Sprite.getDef(id)
    return defs[id]
end

-- Get all defined sprite IDs
function Sprite.getAllIds()
    local ids = {}
    for id in pairs(defs) do ids[#ids+1] = id end
    table.sort(ids)
    return ids
end

-- Draw a sprite directly at a position (without ECS)
function Sprite.draw(id, x, y, flipX, flipY, scale)
    local img = Sprite.getImage(id)
    if not img then return end
    scale = scale or 1
    local sx = flipX and -scale or scale
    local sy = flipY and -scale or scale
    local ox = flipX and img:getWidth() or 0
    local oy = flipY and img:getHeight() or 0
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(x), math.floor(y), 0, sx, sy, ox, oy)
end

-- Get count
function Sprite.count()
    local n = 0
    for _ in pairs(defs) do n = n + 1 end
    return n
end

return Sprite
