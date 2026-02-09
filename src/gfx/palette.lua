-- src/gfx/palette.lua  Atari-2600-ish color palette + enforcement helpers
local Palette = {}

-- 32 colors inspired by the Atari 2600 NTSC palette
-- Each entry: {r, g, b} in 0..255 (converted to 0..1 for LOVE)
local COLORS_RAW = {
    -- Row 0: Grays
    {  0,   0,   0},  -- 1  black
    { 68,  68,  68},  -- 2  dark gray
    {148, 148, 148},  -- 3  medium gray
    {236, 236, 236},  -- 4  white

    -- Row 1: Reds
    {104,  16,   0},  -- 5  dark red
    {168,  48,   0},  -- 6  red
    {228,  92,  16},  -- 7  orange-red
    {252, 152,  56},  -- 8  salmon

    -- Row 2: Oranges
    {132,  40,   0},  -- 9  brown
    {188,  80,   0},  -- 10 dark orange
    {248, 128,  24},  -- 11 orange
    {252, 188,  80},  -- 12 light orange

    -- Row 3: Yellows
    {136,  76,   0},  -- 13 dark yellow
    {200, 132,  24},  -- 14 yellow-brown
    {244, 188,  52},  -- 15 yellow
    {252, 236, 116},  -- 16 light yellow

    -- Row 4: Greens
    {  0,  80,   0},  -- 17 dark green
    { 16, 148,   0},  -- 18 green
    { 76, 208,  32},  -- 19 lime
    {152, 236, 104},  -- 20 light green

    -- Row 5: Cyan-greens
    {  0,  68,  68},  -- 21 dark teal
    {  0, 136, 136},  -- 22 teal
    { 56, 204, 176},  -- 23 cyan
    {132, 240, 212},  -- 24 light cyan

    -- Row 6: Blues
    {  0,  32, 108},  -- 25 dark blue
    { 20,  84, 176},  -- 26 blue
    { 60, 144, 228},  -- 27 light blue
    {128, 200, 252},  -- 28 sky blue

    -- Row 7: Purples / Pinks
    { 72,   0, 120},  -- 29 dark purple
    {136,  40, 176},  -- 30 purple
    {192,  96, 224},  -- 31 lavender
    {232, 160, 252},  -- 32 pink
}

-- Build 0..1 palette
Palette.colors = {}
for i, c in ipairs(COLORS_RAW) do
    Palette.colors[i] = { c[1]/255, c[2]/255, c[3]/255, 1 }
end
Palette.count = #Palette.colors

-- Transparent "color" index
Palette.TRANSPARENT = 0

-- Get RGBA table for a palette index (0 = transparent)
function Palette.get(idx)
    if idx == 0 then return {0, 0, 0, 0} end
    return Palette.colors[idx] or {1, 0, 1, 1}  -- magenta = error
end

-- Set love.graphics color from palette index
function Palette.setColor(idx)
    local c = Palette.get(idx)
    love.graphics.setColor(c[1], c[2], c[3], c[4])
end

-- Validate that a sprite grid uses <= maxColors distinct non-zero palette indices
function Palette.validateGrid(grid, maxColors)
    local used = {}
    local count = 0
    for y = 1, #grid do
        for x = 1, #grid[y] do
            local c = grid[y][x]
            if c ~= 0 and not used[c] then
                used[c] = true
                count = count + 1
            end
        end
    end
    return count <= maxColors, count
end

-- Build an ImageData from a grid of palette indices (for sprites/tiles)
function Palette.gridToImageData(grid, w, h)
    local id = love.image.newImageData(w, h)
    for y = 1, h do
        local row = grid[y]
        if row then
            for x = 1, w do
                local ci = row[x] or 0
                local c = Palette.get(ci)
                id:setPixel(x-1, y-1, c[1], c[2], c[3], c[4])
            end
        end
    end
    return id
end

return Palette
