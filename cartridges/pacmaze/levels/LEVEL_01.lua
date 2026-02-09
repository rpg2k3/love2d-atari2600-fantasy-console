-- cartridges/pacmaze/levels/LEVEL_01.lua
-- Pac-Man inspired maze: 20 columns x 24 rows
-- Tile 1 = wall (solid blue), 0 = path (empty)
-- Symmetric left-right, tunnel at row 13, ghost area center

local W = 1  -- wall
local _ = 0  -- path

-- Maze grid: 24 rows x 20 columns
local maze = {
--   1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
    {W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W}, -- 1  top border
    {W,_,_,_,_,_,_,_,_,W,W,_,_,_,_,_,_,_,_,W}, -- 2
    {W,_,W,W,_,W,W,W,_,W,W,_,W,W,W,_,W,W,_,W}, -- 3
    {W,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,W}, -- 4
    {W,_,W,W,_,W,_,W,W,W,W,W,W,_,W,_,W,W,_,W}, -- 5
    {W,_,_,_,_,W,_,_,_,W,W,_,_,_,W,_,_,_,_,W}, -- 6
    {W,W,W,W,_,W,W,W,_,_,_,_,W,W,W,_,W,W,W,W}, -- 7
    {W,W,W,W,_,W,_,_,_,W,W,_,_,_,W,_,W,W,W,W}, -- 8
    {W,W,W,W,_,_,_,W,_,_,_,_,W,_,_,_,W,W,W,W}, -- 9
    {W,W,W,W,_,W,_,W,W,W,W,W,W,_,W,_,W,W,W,W}, -- 10
    {W,W,W,W,_,W,_,_,_,_,_,_,_,_,W,_,W,W,W,W}, -- 11
    {W,W,W,W,_,W,_,W,W,W,W,W,W,_,W,_,W,W,W,W}, -- 12
    {_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_}, -- 13 tunnel row
    {W,W,W,W,_,W,_,W,W,W,W,W,W,_,W,_,W,W,W,W}, -- 14
    {W,_,_,_,_,_,_,_,_,W,W,_,_,_,_,_,_,_,_,W}, -- 15
    {W,_,W,W,_,W,W,W,_,W,W,_,W,W,W,_,W,W,_,W}, -- 16
    {W,_,_,W,_,_,_,_,_,_,_,_,_,_,_,_,W,_,_,W}, -- 17
    {W,W,_,W,_,W,_,W,W,W,W,W,W,_,W,_,W,_,W,W}, -- 18
    {W,_,_,_,_,W,_,_,_,W,W,_,_,_,W,_,_,_,_,W}, -- 19
    {W,_,W,W,W,W,W,W,_,W,W,_,W,W,W,W,W,W,_,W}, -- 20
    {W,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,W}, -- 21
    {W,_,W,W,_,W,W,W,_,W,W,_,W,W,W,_,W,W,_,W}, -- 22
    {W,_,_,_,_,_,_,_,_,W,W,_,_,_,_,_,_,_,_,W}, -- 23
    {W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W,W}, -- 24 bottom border
}

-- Convert maze grid to tilemap layer format
local function buildTilemapData()
    local layer = {}
    for r = 1, 24 do
        layer[r] = {}
        for c = 1, 20 do
            layer[r][c] = maze[r][c]
        end
    end
    return { [1] = layer }
end

-- Power pellet positions (grid coords: col, row)
-- Placed near the four corners of the walkable area
local powerPellets = {
    { col = 2,  row = 4  },
    { col = 19, row = 4  },
    { col = 2,  row = 21 },
    { col = 19, row = 21 },
}

return {
    version  = 1,
    name     = "LEVEL_01",
    w        = 20,
    h        = 24,
    tileSize = 8,
    maze     = maze,     -- raw maze grid for game logic
    layers = {
        bg = {
            cols = 20,
            rows = 24,
            data = buildTilemapData(),
        },
    },
    objects = {
        -- Player spawn: col 10, row 17 (bottom-center open area)
        -- pixel = (col-1)*8, (row-1)*8
        { id = 1, type = "player_spawn", x = 72,  y = 128, props = {} },
        -- Ghost spawns: center corridor (row 11, cols 9-12)
        { id = 2, type = "enemy", x = 64,  y = 80, props = { ai = "chase",  ghostColor = 3 } },
        { id = 3, type = "enemy", x = 72,  y = 80, props = { ai = "ambush", ghostColor = 4 } },
        { id = 4, type = "enemy", x = 80,  y = 80, props = { ai = "random", ghostColor = 5 } },
        { id = 5, type = "enemy", x = 88,  y = 80, props = { ai = "patrol", ghostColor = 6 } },
    },
    powerPellets = powerPellets,
}
