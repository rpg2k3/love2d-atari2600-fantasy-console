-- cartridges/adventure_clone/content.lua
-- Palette colors, sprite defs, song tables, SFX params for Adventure-ish
-- All art is blocky Atari 2600 style using palette indices

local Content = {}

-- ============================================================
-- PALETTE REFERENCE (subset used)
-- 1=black, 2=dk gray, 3=med gray, 4=white
-- 5=dk red, 6=red, 7=orange-red, 8=salmon
-- 9=brown, 10=dk orange, 11=orange, 12=lt orange
-- 13=dk yellow, 14=yellow-brown, 15=yellow, 16=lt yellow
-- 17=dk green, 18=green, 19=lime, 20=lt green
-- 21=dk teal, 22=teal, 23=cyan, 24=lt cyan
-- 25=dk blue, 26=blue, 27=lt blue, 28=sky blue
-- 29=dk purple, 30=purple, 31=lavender, 32=pink
-- ============================================================

-- ============================================================
-- SPRITES (not used by tilemap - we draw with primitives)
-- Provided for editor compatibility
-- ============================================================
Content.sprites = {}
Content.tiles   = {}

-- ============================================================
-- MUSIC: Mystery dungeon theme
-- Channel 1: square melody, Channel 2: triangle bass, Channel 3: noise perc
-- ============================================================
Content.music = {
    bpm   = 100,
    speed = 4,
    instruments = {
        [1] = { wave = "square",   attack = 0.01, decay = 0.08, sustain = 0.4, release = 0.15, volume = 0.22 },
        [2] = { wave = "triangle", attack = 0.01, decay = 0.10, sustain = 0.5, release = 0.20, volume = 0.28 },
        [3] = { wave = "noise",    attack = 0.005,decay = 0.04, sustain = 0.1, release = 0.05, volume = 0.12 },
        [4] = { wave = "square",   attack = 0.01, decay = 0.06, sustain = 0.3, release = 0.10, volume = 0.18 },
    },
    patterns = {
        -- Pattern 1: Main dungeon theme (16 steps)
        [1] = { channels = {
            [1] = { -- melody (square)
                {"E3",1}, false, {"G3",1}, false,
                {"A3",1}, false, {"G3",1}, false,
                {"E3",1}, false, {"D3",1}, false,
                {"E3",1}, false, false,    false,
            },
            [2] = { -- bass (triangle)
                {"A2",2}, false, false,    false,
                {"E2",2}, false, false,    false,
                {"A2",2}, false, false,    false,
                {"E2",2}, false, false,    false,
            },
            [3] = { -- perc (noise)
                {"C4",3}, false, false,    {"C4",3},
                false,    false, {"C4",3}, false,
                {"C4",3}, false, false,    {"C4",3},
                false,    false, {"C4",3}, false,
            },
        }},
        -- Pattern 2: Variation
        [2] = { channels = {
            [1] = {
                {"A3",1}, false, {"B3",1}, false,
                {"C4",1}, false, {"B3",1}, false,
                {"A3",1}, false, {"G3",1}, false,
                {"A3",1}, false, false,    false,
            },
            [2] = {
                {"A2",2}, false, false,    false,
                {"D2",2}, false, false,    false,
                {"E2",2}, false, false,    false,
                {"A2",2}, false, false,    false,
            },
            [3] = {
                {"C4",3}, false, false,    {"C4",3},
                false,    false, {"C4",3}, false,
                {"C4",3}, false, false,    false,
                {"C4",3}, false, {"C4",3}, false,
            },
        }},
        -- Pattern 3: Tension
        [3] = { channels = {
            [1] = {
                {"E3",1}, false, {"F3",4}, false,
                {"E3",1}, false, {"D#3",4},false,
                {"E3",1}, false, {"F3",4}, false,
                {"G3",1}, false, {"F3",4}, false,
            },
            [2] = {
                {"E2",2}, false, false,    false,
                {"F2",2}, false, false,    false,
                {"E2",2}, false, false,    false,
                {"D2",2}, false, false,    false,
            },
            [3] = {
                {"C4",3}, false, {"C4",3}, false,
                {"C4",3}, false, {"C4",3}, false,
                {"C4",3}, false, {"C4",3}, false,
                {"C4",3}, false, {"C4",3}, false,
            },
        }},
        -- Pattern 4: Menu theme (calmer)
        [4] = { channels = {
            [1] = {
                {"C3",4}, false, false,    false,
                {"E3",4}, false, false,    false,
                {"G3",4}, false, false,    false,
                {"E3",4}, false, false,    false,
            },
            [2] = {
                {"C2",2}, false, false,    false,
                false,    false, false,    false,
                {"G2",2}, false, false,    false,
                false,    false, false,    false,
            },
            [3] = {
                false,    false, false,    false,
                false,    false, false,    false,
                false,    false, false,    false,
                false,    false, false,    false,
            },
        }},
    },
    order = { 1, 2, 1, 3 },  -- game song order (set at runtime)
}

-- ============================================================
-- SFX PRESET PARAMS (registered in main.lua via api.sfx.setPreset)
-- ============================================================
Content.sfxPresets = {
    pickup = {
        wave = "square", freq = 400, duration = 0.12, volume = 0.35,
        attack = 0.005, decay = 0.02, sustain = 0.3, release = 0.05,
        freqSweep = 500,
    },
    drop = {
        wave = "square", freq = 500, duration = 0.10, volume = 0.25,
        attack = 0.005, decay = 0.02, sustain = 0.2, release = 0.04,
        freqSweep = -300,
    },
    unlock = {
        wave = "square", freq = 300, duration = 0.3, volume = 0.35,
        attack = 0.01, decay = 0.05, sustain = 0.4, release = 0.1,
        freqSweep = 400,
    },
    swordHit = {
        wave = "noise", freq = 150, duration = 0.2, volume = 0.4,
        attack = 0.005, decay = 0.05, sustain = 0.3, release = 0.08,
        freqSweep = -100,
    },
    dragonBite = {
        wave = "noise", freq = 80, duration = 0.35, volume = 0.45,
        attack = 0.01, decay = 0.08, sustain = 0.35, release = 0.15,
        freqSweep = -60,
    },
    dragonDie = {
        wave = "square", freq = 600, duration = 0.4, volume = 0.35,
        attack = 0.005, decay = 0.08, sustain = 0.3, release = 0.15,
        freqSweep = -500,
    },
    batSteal = {
        wave = "triangle", freq = 800, duration = 0.15, volume = 0.3,
        attack = 0.005, decay = 0.03, sustain = 0.25, release = 0.05,
        freqSweep = -400,
    },
    winJingle = {
        wave = "square", freq = 523, duration = 0.6, volume = 0.4,
        attack = 0.01, decay = 0.05, sustain = 0.5, release = 0.2,
        freqSweep = 300,
    },
    menuSelect = {
        wave = "square", freq = 500, duration = 0.1, volume = 0.3,
        attack = 0.005, decay = 0.02, sustain = 0.3, release = 0.04,
        freqSweep = 200,
    },
    menuMove = {
        wave = "triangle", freq = 300, duration = 0.06, volume = 0.25,
        attack = 0.005, decay = 0.02, sustain = 0.2, release = 0.02,
        freqSweep = 80,
    },
    respawn = {
        wave = "triangle", freq = 200, duration = 0.3, volume = 0.3,
        attack = 0.01, decay = 0.05, sustain = 0.3, release = 0.1,
        freqSweep = 300,
    },
}

return Content
