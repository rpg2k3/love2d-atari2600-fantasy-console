-- src/editor/sprite_editor.lua  Grid paint, palette, preview, frame switcher
local UI       = require("src.util.ui")
local Video    = require("src.platform.video")
local Sprite   = require("src.gfx.sprite")
local Palette  = require("src.gfx.palette")
local Config   = require("src.config")
local Input    = require("src.util.input")
local PixelFont = require("src.util.pixelfont")

local SE = {}

local selectedSprite = 1
local selectedColor  = 6   -- default red
local grid = nil
local sprW = Config.SPRITE_W
local sprH = Config.SPRITE_H

local function ensureGrid()
    if grid then return end
    local def = Sprite.getDef(selectedSprite)
    if def then
        -- Deep copy grid
        grid = {}
        for y = 1, #def.grid do
            grid[y] = {}
            for x = 1, #def.grid[y] do
                grid[y][x] = def.grid[y][x]
            end
        end
    else
        grid = {}
        for y = 1, sprH do
            grid[y] = {}
            for x = 1, sprW do
                grid[y][x] = 0
            end
        end
    end
end

function SE.init()
    ensureGrid()
end

function SE.update(dt)
end

function SE.draw(yOff)
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    yOff = yOff or 10

    ensureGrid()

    -- Calculate cell size to fit nicely
    local availW = math.floor(iw * 0.55)
    local cellSize = math.floor(math.min(availW / sprW, (ih - yOff - 50) / sprH))
    if cellSize < 2 then cellSize = 2 end

    -- Grid editor
    local gridX = 2
    local gridY = yOff + 2
    grid = UI.gridEditor(grid, gridX, gridY, cellSize, selectedColor, sprW, sprH)

    -- Preview (actual size)
    local previewX = gridX + sprW * cellSize + 4
    UI.text("PREVIEW", previewX, yOff, UI.COL_TEXT)
    -- Build temp image from grid
    local imgData = Palette.gridToImageData(grid, sprW, sprH)
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, previewX, yOff + 8, 0, 2, 2)
    love.graphics.draw(img, previewX + sprW * 2 + 4, yOff + 8)

    -- Sprite ID selector
    local idY = yOff + 8 + sprH * 2 + 4
    UI.text("SPR #" .. selectedSprite, previewX, idY, UI.COL_TEXT)
    if UI.button("<", previewX, idY + 8, 10, 8) then
        SE.applyGrid()
        selectedSprite = math.max(1, selectedSprite - 1)
        grid = nil
        ensureGrid()
    end
    if UI.button(">", previewX + 14, idY + 8, 10, 8) then
        SE.applyGrid()
        selectedSprite = selectedSprite + 1
        grid = nil
        ensureGrid()
    end

    -- Color count validation
    local ok, count = Palette.validateGrid(grid, Config.MAX_SPRITE_COLORS)
    local valStr = "COLS:" .. count .. "/" .. Config.MAX_SPRITE_COLORS
    local valCol = ok and UI.COL_ACTIVE or 7
    UI.text(valStr, previewX, idY + 20, valCol)

    -- Palette picker below grid
    local palY = gridY + sprH * cellSize + 3
    UI.text("PALETTE", gridX, palY, UI.COL_TEXT)
    selectedColor = UI.palettePicker(gridX, palY + 7, math.max(cellSize, 4), selectedColor, 8)

    -- Eraser (color 0)
    local eraseX = gridX + 8 * (math.max(cellSize, 4) + 1) + 2
    if UI.button("CLR", eraseX, palY + 7, 14, 8) then
        selectedColor = 0
    end
    if selectedColor == 0 then
        UI.text("*ERASE", eraseX, palY, 15)
    end
end

function SE.applyGrid()
    if grid then
        Sprite.define(selectedSprite, grid, sprW, sprH)
    end
end

function SE.keypressed(key)
    if key == "return" then
        SE.applyGrid()
    end
end

return SE
