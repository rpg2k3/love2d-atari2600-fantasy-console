-- src/editor/tile_editor.lua  Paint tiles into tilemap; pick tile, save/load
local UI       = require("src.util.ui")
local Video    = require("src.platform.video")
local Tile     = require("src.gfx.tile")
local Tilemap  = require("src.gfx.tilemap")
local Palette  = require("src.gfx.palette")
local Config   = require("src.config")
local Input    = require("src.util.input")
local PixelFont = require("src.util.pixelfont")

local TE = {}

-- Shared tilemap for editor and game
TE.tilemap = nil

local selectedTile  = 1
local selectedColor = 6
local editMode = "tile"  -- "tile" = paint tile defs, "map" = paint tilemap
local tileGrid = nil
local mapScrollX = 0
local mapScrollY = 0

local function ensureTilemap()
    if not TE.tilemap then
        TE.tilemap = Tilemap.new(Config.MAP_COLS, Config.MAP_ROWS, 2)
    end
end

local function ensureTileGrid()
    if tileGrid then return end
    local def = Tile.getDef(selectedTile)
    if def then
        tileGrid = {}
        for y = 1, #def.grid do
            tileGrid[y] = {}
            for x = 1, #def.grid[y] do
                tileGrid[y][x] = def.grid[y][x]
            end
        end
    else
        tileGrid = {}
        for y = 1, Config.TILE_H do
            tileGrid[y] = {}
            for x = 1, Config.TILE_W do
                tileGrid[y][x] = 0
            end
        end
    end
end

function TE.init()
    ensureTilemap()
    ensureTileGrid()
end

-- Integration helpers for level editor
function TE.getTilemap()
    ensureTilemap()
    return TE.tilemap
end

function TE.setTilemap(tm)
    TE.tilemap = tm
end

function TE.ensureLayer(layerIdx)
    ensureTilemap()
    if not TE.tilemap.data[layerIdx] then
        TE.tilemap.data[layerIdx] = {}
        for r = 1, TE.tilemap.rows do
            TE.tilemap.data[layerIdx][r] = {}
            for c = 1, TE.tilemap.cols do
                TE.tilemap.data[layerIdx][r][c] = 0
            end
        end
    end
end

function TE.getSelectedTile()
    return selectedTile
end

function TE.update(dt)
end

function TE.draw(yOff)
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    yOff = yOff or 10

    ensureTilemap()

    local x = 2
    local y = yOff + 1

    -- Mode toggle
    if UI.button("TILE DEF", x, y, 34, 8, editMode == "tile" and UI.COL_ACTIVE or UI.COL_PANEL) then
        editMode = "tile"
    end
    if UI.button("MAP", x + 36, y, 20, 8, editMode == "map" and UI.COL_ACTIVE or UI.COL_PANEL) then
        editMode = "map"
    end

    -- Tile ID
    UI.text("T#" .. selectedTile, x + 60, y, UI.COL_HI)
    if UI.button("<", x + 78, y - 1, 10, 8) then
        TE.applyTile()
        selectedTile = math.max(1, selectedTile - 1)
        tileGrid = nil
    end
    if UI.button(">", x + 90, y - 1, 10, 8) then
        TE.applyTile()
        selectedTile = selectedTile + 1
        tileGrid = nil
    end

    y = y + 10

    if editMode == "tile" then
        TE.drawTileDefEditor(x, y, iw, ih)
    else
        TE.drawMapEditor(x, y, iw, ih)
    end
end

function TE.drawTileDefEditor(x, y, iw, ih)
    ensureTileGrid()

    local cellSize = math.floor(math.min((iw * 0.5) / Config.TILE_W, (ih - y - 40) / Config.TILE_H))
    if cellSize < 2 then cellSize = 2 end

    tileGrid = UI.gridEditor(tileGrid, x, y, cellSize, selectedColor, Config.TILE_W, Config.TILE_H)

    -- Solid/hazard flags
    local flagsY = y + Config.TILE_H * cellSize + 2
    local def = Tile.getDef(selectedTile)
    local flags = def and def.flags or {}
    if UI.button(flags.solid and "SOLID:Y" or "SOLID:N", x, flagsY, 30, 8, flags.solid and UI.COL_ACTIVE or UI.COL_PANEL) then
        flags.solid = not flags.solid
        Tile.define(selectedTile, tileGrid, flags, Config.TILE_W, Config.TILE_H)
    end
    if UI.button(flags.hazard and "HAZ:Y" or "HAZ:N", x + 32, flagsY, 26, 8, flags.hazard and 7 or UI.COL_PANEL) then
        flags.hazard = not flags.hazard
        Tile.define(selectedTile, tileGrid, flags, Config.TILE_W, Config.TILE_H)
    end

    -- Palette
    local palY = flagsY + 10
    UI.text("PAL", x, palY, UI.COL_TEXT)
    selectedColor = UI.palettePicker(x, palY + 7, math.max(cellSize, 4), selectedColor, 8)

    -- Preview
    local prevX = x + Config.TILE_W * cellSize + 4
    UI.text("PREVIEW", prevX, y, UI.COL_TEXT)
    local imgData = Palette.gridToImageData(tileGrid, Config.TILE_W, Config.TILE_H)
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, prevX, y + 8, 0, 2, 2)
end

function TE.drawMapEditor(x, y, iw, ih)
    -- Draw tilemap miniview
    local viewW = iw - 4
    local tm = TE.tilemap

    -- Tile palette bar (list of defined tiles)
    local tileIds = Tile.getAllIds()
    local barY = y
    local barH = 10
    for i, tid in ipairs(tileIds) do
        local bx = x + (i - 1) * (Config.TILE_W + 2)
        if bx + Config.TILE_W > iw then break end
        local timg = Tile.getImage(tid)
        if timg then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(timg, bx, barY)
        end
        if tid == selectedTile then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.rectangle("line", bx - 1, barY - 1, Config.TILE_W + 2, Config.TILE_H + 2)
        end
        -- Click to select
        local mx, my = Video.screenToInternal(Input.mouse())
        if Input.mousePressedThisFrame and mx >= bx and mx < bx + Config.TILE_W and my >= barY and my < barY + Config.TILE_H then
            selectedTile = tid
        end
    end
    y = barY + barH + 2

    -- Draw visible map cells
    local cellSize = math.min(
        math.floor(viewW / math.min(tm.cols, 20)),
        math.floor((ih - y - 6) / math.min(tm.rows, 16))
    )
    if cellSize < 2 then cellSize = 2 end

    local visibleCols = math.floor(viewW / cellSize)
    local visibleRows = math.floor((ih - y - 6) / cellSize)

    for row = 1, math.min(visibleRows, tm.rows) do
        for col = 1, math.min(visibleCols, tm.cols) do
            local mc = col + mapScrollX
            local mr = row + mapScrollY
            local tid = tm:get(1, mc, mr)
            local px = x + (col - 1) * cellSize
            local py = y + (row - 1) * cellSize
            if tid > 0 then
                local timg = Tile.getImage(tid)
                if timg then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(timg, px, py, 0, cellSize / Config.TILE_W, cellSize / Config.TILE_H)
                end
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 1)
                love.graphics.rectangle("fill", px, py, cellSize, cellSize)
            end
            -- Grid line
            love.graphics.setColor(0.2, 0.2, 0.3, 0.3)
            love.graphics.rectangle("line", px, py, cellSize, cellSize)

            -- Paint on click
            local mx, my = Video.screenToInternal(Input.mouse())
            if Input.mouseDown(1) and mx >= px and mx < px + cellSize and my >= py and my < py + cellSize then
                tm:set(1, mc, mr, selectedTile)
            elseif Input.mouseDown(2) and mx >= px and mx < px + cellSize and my >= py and my < py + cellSize then
                tm:set(1, mc, mr, 0)
            end
        end
    end
end

function TE.applyTile()
    if tileGrid then
        local def = Tile.getDef(selectedTile)
        local flags = def and def.flags or {}
        Tile.define(selectedTile, tileGrid, flags, Config.TILE_W, Config.TILE_H)
    end
end

function TE.keypressed(key)
    if editMode == "map" then
        if key == "left"  then mapScrollX = math.max(0, mapScrollX - 1) end
        if key == "right" then mapScrollX = mapScrollX + 1 end
        if key == "up"    then mapScrollY = math.max(0, mapScrollY - 1) end
        if key == "down"  then mapScrollY = mapScrollY + 1 end
    end
    if key == "return" then
        TE.applyTile()
    end
end

return TE
