-- cartridges/breakfunk/content.lua
-- Sprites, tiles, and multi-channel music for BreakFunk
-- Palette indices: 0=transparent, 1=black, 4=white, 6=red, 11=orange, 15=yellow, 26=blue

local Content = {}

-- ============================================================
-- SPRITES
-- ============================================================
Content.sprites = {
    -- 1: Paddle (16x4 bright white bar with orange accents)
    [1] = { w = 16, h = 4, grid = {
        {  0, 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11,  0 },
        { 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11 },
        { 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11 },
        {  0, 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11,  0 },
    }},

    -- 2: Ball (4x4 white circle)
    [2] = { w = 4, h = 4, grid = {
        {  0,  4,  4,  0 },
        {  4,  4,  4,  4 },
        {  4,  4,  4,  4 },
        {  0,  4,  4,  0 },
    }},

    -- 3: Brick standard (16x6 blue block)
    [3] = { w = 16, h = 6, grid = {
        { 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26 },
        { 26,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 26 },
        { 26,  4, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,  4, 26 },
        { 26,  4, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,  4, 26 },
        { 26,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 26 },
        { 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26 },
    }},

    -- 4: Brick orange (16x6)
    [4] = { w = 16, h = 6, grid = {
        { 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 },
        { 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11 },
        { 11,  4, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,  4, 11 },
        { 11,  4, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,  4, 11 },
        { 11,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 11 },
        { 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 },
    }},

    -- 5: Brick red (16x6)
    [5] = { w = 16, h = 6, grid = {
        {  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6 },
        {  6,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  6 },
        {  6,  4,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  6 },
        {  6,  4,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  6 },
        {  6,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  6 },
        {  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6 },
    }},

    -- 6: Brick yellow (16x6)
    [6] = { w = 16, h = 6, grid = {
        { 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15 },
        { 15,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 15 },
        { 15,  4, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,  4, 15 },
        { 15,  4, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,  4, 15 },
        { 15,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4, 15 },
        { 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15 },
    }},

    -- 7: Life icon (small heart, 5x5)
    [7] = { w = 5, h = 5, grid = {
        {  0,  6,  0,  6,  0 },
        {  6,  6,  6,  6,  6 },
        {  6,  6,  6,  6,  6 },
        {  0,  6,  6,  6,  0 },
        {  0,  0,  6,  0,  0 },
    }},
}

-- ============================================================
-- TILES (not used for breakout, but included for completeness)
-- ============================================================
Content.tiles = {}

-- ============================================================
-- MUSIC: Multi-channel funky chiptune (new music system)
-- BPM 130, 2 channels: square melody + triangle bass
-- 16 steps per pattern, funky syncopated groove
-- ============================================================
Content.music = {
    bpm   = 130,
    speed = 4,

    instruments = {
        [1] = { wave = "square",   attack = 0.01, decay = 0.08, sustain = 0.5, release = 0.15, volume = 0.22 },
        [2] = { wave = "triangle", attack = 0.01, decay = 0.1,  sustain = 0.6, release = 0.2,  volume = 0.28 },
        [3] = { wave = "noise",    attack = 0.005,decay = 0.05, sustain = 0.15,release = 0.05, volume = 0.12 },
    },

    patterns = {
        -- Pattern 1: Funky melody (ch1) + walking bass (ch2) + hat (ch3)
        [1] = { channels = {
            -- Channel 1: Square lead melody - syncopated funk riff
            [1] = {
                {"E4", 1}, false,    {"G4", 1}, false,
                {"A4", 1}, {"A4",1}, false,     {"G4", 1},
                false,     {"E4",1}, false,     {"D4", 1},
                {"E4", 1}, false,    false,     false,
            },
            -- Channel 2: Triangle bass - funk groove root notes
            [2] = {
                {"A2", 2}, false,    false,     {"A2", 2},
                false,     {"C3",2}, false,     false,
                {"D3", 2}, false,    {"D3", 2}, false,
                {"E3", 2}, false,    false,     {"E2", 2},
            },
            -- Channel 3: Noise hi-hat pattern
            [3] = {
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
            },
        }},

        -- Pattern 2: Variation - higher melody + same bass + hat
        [2] = { channels = {
            [1] = {
                {"A4", 1}, false,    {"C5", 1}, false,
                {"D5", 1}, {"C5",1}, false,     {"A4", 1},
                false,     {"G4",1}, false,     {"E4", 1},
                {"G4", 1}, false,    {"A4", 1}, false,
            },
            [2] = {
                {"A2", 2}, false,    false,     {"C3", 2},
                false,     {"D3",2}, false,     false,
                {"E3", 2}, false,    {"D3", 2}, false,
                {"C3", 2}, false,    false,     {"A2", 2},
            },
            [3] = {
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, {"C4",3}, {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, {"C4", 3},
            },
        }},

        -- Pattern 3: Breakdown - sparse melody, deep bass
        [3] = { channels = {
            [1] = {
                {"E5", 1}, false,    false,     false,
                {"D5", 1}, false,    false,     {"C5", 1},
                false,     false,    {"A4", 1}, false,
                false,     false,    false,     false,
            },
            [2] = {
                {"A2", 2}, false,    {"A2", 2}, false,
                {"G2", 2}, false,    {"G2", 2}, false,
                {"F2", 2}, false,    {"F2", 2}, false,
                {"E2", 2}, false,    {"E2", 2}, false,
            },
            [3] = {
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, false,    {"C4", 3}, false,
                {"C4", 3}, {"C4",3}, {"C4", 3}, {"C4", 3},
            },
        }},

        -- Pattern 4: Build-up - ascending riff
        [4] = { channels = {
            [1] = {
                {"A3", 1}, {"C4",1}, {"D4", 1}, {"E4", 1},
                {"G4", 1}, {"A4",1}, {"C5", 1}, {"D5", 1},
                {"E5", 1}, {"D5",1}, {"C5", 1}, {"A4", 1},
                {"G4", 1}, {"E4",1}, {"D4", 1}, {"C4", 1},
            },
            [2] = {
                {"A2", 2}, false,    {"C3", 2}, false,
                {"D3", 2}, false,    {"E3", 2}, false,
                {"A2", 2}, false,    {"C3", 2}, false,
                {"D3", 2}, false,    {"E3", 2}, false,
            },
            [3] = {
                {"C4", 3}, {"C4",3}, {"C4", 3}, {"C4", 3},
                {"C4", 3}, {"C4",3}, {"C4", 3}, {"C4", 3},
                {"C4", 3}, {"C4",3}, {"C4", 3}, {"C4", 3},
                {"C4", 3}, {"C4",3}, {"C4", 3}, {"C4", 3},
            },
        }},
    },

    order = { 1, 2, 1, 3, 1, 2, 4, 3 },
}

return Content
