-- src/gfx/tilemap.lua  Matrix-based tile world + draw
local Tile   = require("src.gfx.tile")
local Config = require("src.config")

local Tilemap = {}
Tilemap.__index = Tilemap

function Tilemap.new(cols, rows, layers)
    cols = cols or Config.MAP_COLS
    rows = rows or Config.MAP_ROWS
    layers = layers or 1
    local tm = setmetatable({
        cols = cols,
        rows = rows,
        tileW = Config.TILE_W,
        tileH = Config.TILE_H,
        data = {},  -- data[layer][row][col] = tileId or 0
    }, Tilemap)
    for l = 1, layers do
        tm.data[l] = {}
        for r = 1, rows do
            tm.data[l][r] = {}
            for c = 1, cols do
                tm.data[l][r][c] = 0
            end
        end
    end
    return tm
end

function Tilemap:set(layer, col, row, tileId)
    if not self.data[layer] then return end
    if row < 1 or row > self.rows or col < 1 or col > self.cols then return end
    if not self.data[layer][row] then self.data[layer][row] = {} end
    self.data[layer][row][col] = tileId
end

function Tilemap:get(layer, col, row)
    if not self.data[layer] then return 0 end
    if row < 1 or row > self.rows or col < 1 or col > self.cols then return 0 end
    local r = self.data[layer][row]
    return r and r[col] or 0
end

-- Draw visible tiles for a layer given camera offset and view size
function Tilemap:draw(layer, camX, camY, viewW, viewH)
    camX = camX or 0
    camY = camY or 0
    viewW = viewW or (self.cols * self.tileW)
    viewH = viewH or (self.rows * self.tileH)

    local startCol = math.max(1, math.floor(camX / self.tileW) + 1)
    local startRow = math.max(1, math.floor(camY / self.tileH) + 1)
    local endCol   = math.min(self.cols, math.floor((camX + viewW) / self.tileW) + 2)
    local endRow   = math.min(self.rows, math.floor((camY + viewH) / self.tileH) + 2)

    local layerData = self.data[layer]
    if not layerData then return end

    love.graphics.setColor(1, 1, 1, 1)
    for row = startRow, endRow do
        local rowData = layerData[row]
        if rowData then
            for col = startCol, endCol do
                local tid = rowData[col]
                if tid and tid > 0 then
                    local img = Tile.getImage(tid)
                    if img then
                        local px = (col - 1) * self.tileW - camX
                        local py = (row - 1) * self.tileH - camY
                        love.graphics.draw(img, math.floor(px), math.floor(py))
                    end
                end
            end
        end
    end
end

-- Check if a pixel position collides with a solid tile
function Tilemap:isSolid(px, py, layer)
    layer = layer or 1
    local col = math.floor(px / self.tileW) + 1
    local row = math.floor(py / self.tileH) + 1
    local tid = self:get(layer, col, row)
    return tid > 0 and Tile.isSolid(tid)
end

-- Get pixel dimensions
function Tilemap:getPixelWidth()  return self.cols * self.tileW end
function Tilemap:getPixelHeight() return self.rows * self.tileH end

-- Export data for serialization
function Tilemap:export()
    return {
        cols = self.cols,
        rows = self.rows,
        data = self.data,
    }
end

-- Import data
function Tilemap:import(d)
    self.cols = d.cols or self.cols
    self.rows = d.rows or self.rows
    self.data = d.data or self.data
end

return Tilemap
