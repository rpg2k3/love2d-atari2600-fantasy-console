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

-- Variant B: Warm / sepia-shifted Atari palette
local COLORS_WARM = {
    {  0,   0,   0},  {  76,  68,  56},  { 156, 144, 128},  { 240, 232, 216},
    { 120,  24,   0},  { 184,  56,   8},  { 240, 100,  24},  { 252, 160,  64},
    { 148,  48,   0},  { 200,  88,   8},  { 252, 136,  32},  { 252, 196,  88},
    { 148,  84,   0},  { 212, 140,  32},  { 252, 196,  60},  { 252, 240, 124},
    {   8,  72,  16},  {  24, 136,  16},  {  84, 196,  40},  { 160, 228, 112},
    {   0,  60,  56},  {   8, 124, 120},  {  64, 192, 164},  { 140, 232, 204},
    {   8,  28,  96},  {  28,  76, 160},  {  68, 136, 216},  { 136, 192, 244},
    {  80,   8, 108},  { 144,  48, 164},  { 200, 104, 212},  { 236, 168, 244},
}

-- Variant C: Cool / blue-shifted CRT phosphor palette
local COLORS_COOL = {
    {  0,   0,   4},  {  60,  64,  76},  { 136, 144, 160},  { 228, 236, 244},
    {  88,  16,  24},  { 152,  44,  32},  { 212,  84,  48},  { 244, 144,  80},
    { 116,  36,  16},  { 172,  72,  24},  { 232, 120,  48},  { 244, 180,  96},
    { 120,  68,  16},  { 184, 124,  40},  { 228, 180,  64},  { 244, 228, 128},
    {   0,  88,  24},  {   8, 156,  24},  {  68, 216,  56},  { 144, 244, 120},
    {   0,  76,  80},  {   0, 144, 148},  {  48, 212, 188},  { 124, 244, 220},
    {   0,  40, 124},  {  16,  92, 192},  {  52, 152, 240},  { 120, 208, 252},
    {  64,   0, 136},  { 128,  36, 192},  { 184,  88, 236},  { 224, 152, 252},
}

-- All variant tables (indexed by variant ID)
local VARIANT_TABLES = {
    COLORS_RAW,   -- 1 = default
    COLORS_WARM,  -- 2 = warm
    COLORS_COOL,  -- 3 = cool
}

Palette.VARIANT_NAMES = { "DEFAULT", "WARM", "COOL" }
Palette.VARIANT_COUNT = #VARIANT_TABLES

local currentVariant = 1

-- Build 0..1 palette from a raw table
local function buildColors(raw)
    local cols = {}
    for i, c in ipairs(raw) do
        cols[i] = { c[1]/255, c[2]/255, c[3]/255, 1 }
    end
    return cols
end

-- Build 0..1 palette
Palette.colors = buildColors(COLORS_RAW)
Palette.count = #Palette.colors

-- Transparent "color" index
Palette.TRANSPARENT = 0

-- Set palette variant (1..VARIANT_COUNT)
function Palette.setVariant(id)
    id = math.max(1, math.min(#VARIANT_TABLES, id or 1))
    currentVariant = id
    Palette.colors = buildColors(VARIANT_TABLES[id])
    Palette.count = #Palette.colors
end

function Palette.getVariant()
    return currentVariant
end

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
