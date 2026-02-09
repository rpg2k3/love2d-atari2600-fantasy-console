-- src/game/content.lua  Default built-in sprites/tiles/sfx/music as Lua tables
-- All sprites and tiles use palette indices from palette.lua
-- These are intentionally blocky and low-detail for Atari 2600 aesthetics.

local Content = {}

-- Sprite definitions: { id = { grid = {rows}, w, h } }
-- Grid rows are top-to-bottom; each value is a palette index (0 = transparent)
Content.sprites = {
    -- 1: Player character (blocky humanoid, 8x8)
    [1] = { w = 8, h = 8, grid = {
        { 0, 0, 7, 7, 7, 7, 0, 0 },
        { 0, 0, 7, 4, 4, 7, 0, 0 },
        { 0, 0, 0, 7, 7, 0, 0, 0 },
        { 0, 7, 7, 7, 7, 7, 7, 0 },
        { 0, 0, 0, 7, 7, 0, 0, 0 },
        { 0, 0, 0, 7, 7, 0, 0, 0 },
        { 0, 0, 7, 0, 0, 7, 0, 0 },
        { 0, 0, 7, 0, 0, 7, 0, 0 },
    }},
    -- 2: Player walk frame 2
    [2] = { w = 8, h = 8, grid = {
        { 0, 0, 7, 7, 7, 7, 0, 0 },
        { 0, 0, 7, 4, 4, 7, 0, 0 },
        { 0, 0, 0, 7, 7, 0, 0, 0 },
        { 0, 7, 7, 7, 7, 7, 7, 0 },
        { 0, 0, 0, 7, 7, 0, 0, 0 },
        { 0, 0, 7, 7, 7, 7, 0, 0 },
        { 0, 7, 0, 0, 0, 0, 7, 0 },
        { 0, 7, 0, 0, 0, 0, 7, 0 },
    }},
    -- 3: Enemy (simple ghost/invader, 8x8)
    [3] = { w = 8, h = 8, grid = {
        { 0, 0,18,18,18,18, 0, 0 },
        { 0,18,18,18,18,18,18, 0 },
        { 0,18, 1,18,18, 1,18, 0 },
        { 0,18,18,18,18,18,18, 0 },
        { 18,18,18,18,18,18,18,18 },
        { 18,18,18,18,18,18,18,18 },
        { 18, 0,18,18,18,18, 0,18 },
        { 0, 0,18, 0, 0,18, 0, 0 },
    }},
    -- 4: Coin/pickup (4x4-ish in 8x8 frame)
    [4] = { w = 8, h = 8, grid = {
        { 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0,15,15,15,15, 0, 0 },
        { 0,15,16,16,16,15,15, 0 },
        { 0,15,16,15,15,16,15, 0 },
        { 0,15,16,15,15,16,15, 0 },
        { 0,15,16,16,16,15,15, 0 },
        { 0, 0,15,15,15,15, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0 },
    }},
    -- 5: Bullet (tiny, 8x8 with center dot)
    [5] = { w = 8, h = 8, grid = {
        { 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 4, 4, 0, 0, 0 },
        { 0, 0, 4, 8, 8, 4, 0, 0 },
        { 0, 0, 4, 8, 8, 4, 0, 0 },
        { 0, 0, 0, 4, 4, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0 },
    }},
}

-- Tile definitions: { id = { grid, w, h, flags } }
Content.tiles = {
    -- 1: Ground/platform (brown brick)
    [1] = { w = 8, h = 8, flags = { solid = true }, grid = {
        { 9, 9, 9, 2, 9, 9, 9, 9 },
        { 9,10,10, 2,10,10,10, 9 },
        {10,10,10, 2,10,10,10,10 },
        { 2, 2, 2, 2, 2, 2, 2, 2 },
        { 9, 9, 9, 9, 9, 2, 9, 9 },
        {10,10,10, 9,10, 2,10,10 },
        {10,10,10,10,10, 2,10,10 },
        { 2, 2, 2, 2, 2, 2, 2, 2 },
    }},
    -- 2: Sky / empty (dark blue)
    [2] = { w = 8, h = 8, flags = {}, grid = {
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
        {25,25,25,25,25,25,25,25 },
    }},
    -- 3: Grass top
    [3] = { w = 8, h = 8, flags = { solid = true }, grid = {
        {18,19,18,19,18,19,18,19 },
        {17,18,17,18,17,18,17,18 },
        { 9, 9, 9, 9, 9, 9, 9, 9 },
        { 9,10,10,10,10,10, 9, 9 },
        {10,10,10,10,10,10,10,10 },
        {10,10,10,10,10,10,10,10 },
        {10,10,10,10,10,10,10,10 },
        {10,10,10,10,10,10,10,10 },
    }},
    -- 4: Hazard (spikes, red)
    [4] = { w = 8, h = 8, flags = { solid = true, hazard = true }, grid = {
        { 0, 0, 0, 6, 0, 0, 0, 6 },
        { 0, 0, 6, 7, 0, 0, 6, 7 },
        { 0, 6, 7, 7, 0, 6, 7, 7 },
        { 6, 7, 7, 7, 6, 7, 7, 7 },
        { 5, 5, 5, 5, 5, 5, 5, 5 },
        { 5, 5, 5, 5, 5, 5, 5, 5 },
        { 5, 5, 5, 5, 5, 5, 5, 5 },
        { 5, 5, 5, 5, 5, 5, 5, 5 },
    }},
}

-- Default tilemap layout (20 cols x 24 rows, layer 1)
-- 0=empty, 1=brick, 2=sky, 3=grass, 4=hazard
Content.tilemap = {
    cols = 32, rows = 24,
    data = nil,  -- will be generated below
}

-- Generate a simple demo level
local function genLevel()
    local d = {}
    -- Layer 1 (main)
    d[1] = {}
    for r = 1, 24 do
        d[1][r] = {}
        for c = 1, 32 do
            if r >= 21 then
                -- Ground
                d[1][r][c] = 1
            elseif r == 20 then
                -- Grass top
                d[1][r][c] = 3
            else
                d[1][r][c] = 0  -- empty (sky drawn as bg color)
            end
        end
    end
    -- Some platforms
    for c = 8, 12 do d[1][16][c] = 3 end
    for c = 18, 22 do d[1][13][c] = 3 end
    for c = 5, 7 do d[1][10][c] = 3 end
    -- Hazard
    d[1][20][15] = 4
    d[1][20][16] = 4
    -- Layer 2 (foreground, empty)
    d[2] = {}
    for r = 1, 24 do
        d[2][r] = {}
        for c = 1, 32 do d[2][r][c] = 0 end
    end
    return d
end
Content.tilemap.data = genLevel()

-- Music patterns
Content.music = {
    patterns = {
        [1] = {
            bpm = 140,
            stepsPerBeat = 4,
            steps = {
                { note = "C4",  wave = "square", duration = 0.12, volume = 0.25 },
                false,
                { note = "E4",  wave = "square", duration = 0.12, volume = 0.25 },
                false,
                { note = "G4",  wave = "square", duration = 0.12, volume = 0.25 },
                false,
                { note = "E4",  wave = "square", duration = 0.12, volume = 0.25 },
                false,
                { note = "C4",  wave = "triangle", duration = 0.12, volume = 0.25 },
                false,
                { note = "D4",  wave = "triangle", duration = 0.12, volume = 0.25 },
                false,
                { note = "E4",  wave = "square", duration = 0.12, volume = 0.25 },
                { note = "D4",  wave = "square", duration = 0.12, volume = 0.25 },
                { note = "C4",  wave = "square", duration = 0.15, volume = 0.25 },
                false,
            },
        },
    },
    song = { 1 },
}

return Content
