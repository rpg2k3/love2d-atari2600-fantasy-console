-- src/gfx/sprite_atlas.lua  Stores sprite definitions (acts as registry/atlas)
-- This module manages the collection of all sprite data for save/load.
local Sprite    = require("src.gfx.sprite")
local Serialize = require("src.util.serialize")

local Atlas = {}

-- Load all sprites from a content table
function Atlas.loadFromContent(content)
    if not content or not content.sprites then return end
    for id, def in pairs(content.sprites) do
        Sprite.define(id, def.grid, def.w, def.h)
    end
end

-- Export all sprites as a serializable table
function Atlas.export()
    local data = {}
    local ids = Sprite.getAllIds()
    for _, id in ipairs(ids) do
        local def = Sprite.getDef(id)
        if def then
            data[id] = { grid = def.grid, w = def.w, h = def.h }
        end
    end
    return data
end

-- Save sprites to file
function Atlas.save(filename)
    local data = Atlas.export()
    return Serialize.save(filename, { sprites = data })
end

-- Load sprites from file
function Atlas.load(filename)
    local content = Serialize.load(filename)
    if content then
        Atlas.loadFromContent(content)
    end
end

return Atlas
