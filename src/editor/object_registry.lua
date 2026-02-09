-- src/editor/object_registry.lua  Registry of placeable object types for the level editor
-- Defines how each type renders in the editor, its default props, and shape (point/rect).
local Palette = require("src.gfx.palette")

local Registry = {}

-- Object type definitions.
-- Fields:
--   label       : display name in editor
--   shape       : "point" or "rect"
--   color       : palette index for editor outline/marker
--   spriteId    : if set, draw this sprite from the atlas as the marker; nil = draw procedural marker
--   defaultW    : default width for rect objects (pixels)
--   defaultH    : default height for rect objects (pixels)
--   defaultProps: table of default properties
--   propDefs    : ordered list of editable property definitions
--                 each: { key, label, kind, options/min/max }
--                 kind: "int", "string", "cycle"

Registry.types = {
    player_spawn = {
        label = "SPAWN",
        shape = "point",
        color = 19,   -- lime green
        spriteId = 1, -- player sprite
        defaultProps = {},
        propDefs = {},
    },
    coin = {
        label = "COIN",
        shape = "point",
        color = 15,   -- yellow
        spriteId = 4, -- coin sprite
        defaultProps = { value = 1 },
        propDefs = {
            { key = "value", label = "VAL", kind = "int", min = 1, max = 99 },
        },
    },
    enemy = {
        label = "ENEMY",
        shape = "point",
        color = 6,    -- red
        spriteId = 3, -- enemy sprite
        defaultProps = { ai = "patrol", dir = 1 },
        propDefs = {
            { key = "ai",  label = "AI",  kind = "cycle", options = {"patrol", "chase", "static"} },
            { key = "dir", label = "DIR", kind = "int", min = -1, max = 1 },
        },
    },
    trigger = {
        label = "TRIG",
        shape = "rect",
        color = 30,   -- purple
        spriteId = nil,
        defaultW = 16,
        defaultH = 16,
        defaultProps = { kind = "exit", to = "LEVEL_02" },
        propDefs = {
            { key = "kind", label = "KIND", kind = "cycle", options = {"exit", "event", "warp"} },
            { key = "to",   label = "TO",   kind = "string" },
        },
    },
    checkpoint = {
        label = "CHECK",
        shape = "point",
        color = 23,   -- cyan
        spriteId = nil,
        defaultProps = {},
        propDefs = {},
    },
    text_hint = {
        label = "HINT",
        shape = "rect",
        color = 3,    -- medium gray
        spriteId = nil,
        defaultW = 32,
        defaultH = 8,
        defaultProps = { text = "HELLO" },
        propDefs = {
            { key = "text", label = "TXT", kind = "string" },
        },
    },
}

-- Ordered list of type keys (for cycling in editor)
Registry.typeOrder = {
    "player_spawn", "coin", "enemy", "trigger", "checkpoint", "text_hint",
}

-- Get a type definition
function Registry.get(typeName)
    return Registry.types[typeName]
end

-- Build default props for a type
function Registry.makeDefaultProps(typeName)
    local def = Registry.types[typeName]
    if not def then return {} end
    local p = {}
    for k, v in pairs(def.defaultProps) do
        p[k] = v
    end
    return p
end

-- Draw a procedural marker for types without a spriteId
-- Draws a small cross or rect outline at (x,y) in the given palette color.
function Registry.drawMarker(typeName, x, y, w, h)
    local def = Registry.types[typeName]
    if not def then return end
    Palette.setColor(def.color)
    if def.shape == "rect" then
        w = w or def.defaultW or 16
        h = h or def.defaultH or 16
        love.graphics.rectangle("line", x, y, w, h)
        -- dashed interior
        love.graphics.setColor(Palette.get(def.color)[1], Palette.get(def.color)[2], Palette.get(def.color)[3], 0.25)
        love.graphics.rectangle("fill", x, y, w, h)
    else
        -- cross marker (5x5)
        love.graphics.line(x + 1, y + 3, x + 5, y + 3)
        love.graphics.line(x + 3, y + 1, x + 3, y + 5)
    end
end

-- Draw the label tag above an object position
function Registry.drawLabel(typeName, x, y)
    local def = Registry.types[typeName]
    if not def then return end
    local c = Palette.get(def.color)
    local lbl = def.label or "?"
    love.graphics.setColor(0, 0, 0, 0.7)
    local tw = #lbl * 4
    love.graphics.rectangle("fill", x, y - 7, tw + 2, 7)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    -- Use love.graphics.print with default font for tiny label
    -- (pixelfont is uppercase which is fine)
    local PF = require("src.util.pixelfont")
    PF.print(lbl, x + 1, y - 6, 1, c[1], c[2], c[3])
end

return Registry
