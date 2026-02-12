-- LEVEL_01.lua  World generation parameters for DigDive
-- Deterministic seed ensures same world each play
-- World: 10 columns x 80 rows, 16px per tile
-- Surface (rows 0-2): empty sky
-- Underground (rows 3-79): dirt with embedded rocks and gems

return {
    name   = "UNDERGROUND",
    seed   = 42,

    -- World dimensions (in tiles)
    cols   = 10,
    rows   = 80,

    -- Surface starts at row 3 (rows 0-2 are sky)
    surface_row = 3,

    -- Player spawn (tile coords, 0-indexed)
    spawn_x = 4,
    spawn_y = 1,

    -- Rock density: fraction of underground tiles that are rocks
    -- Applied from row 4 onward (row 3 = surface layer, kept clear)
    rock_density = 0.08,

    -- Gem placement: explicit positions for deterministic layout
    -- 18 gems spread across depth zones
    gems = {
        -- Shallow zone (rows 5-20): easy gems, 6 total
        { x=2, y=6  },
        { x=7, y=8  },
        { x=4, y=11 },
        { x=8, y=14 },
        { x=1, y=17 },
        { x=5, y=20 },

        -- Mid zone (rows 21-45): 6 gems, denser rocks around them
        { x=3, y=24 },
        { x=6, y=28 },
        { x=1, y=33 },
        { x=8, y=37 },
        { x=4, y=40 },
        { x=7, y=44 },

        -- Deep zone (rows 46-75): 6 gems, hardest to reach
        { x=2, y=50 },
        { x=9, y=55 },
        { x=5, y=60 },
        { x=0, y=65 },
        { x=7, y=70 },
        { x=3, y=75 },
    },

    -- Scoring
    gem_score    = 100,
    depth_score  = 10,   -- per new deepest row reached

    -- Player
    lives        = 3,
    invuln_time  = 1.5,  -- seconds of invulnerability after hit
    move_cooldown = 0.10, -- seconds between moves

    -- Rock physics
    rock_warning_time = 0.5,  -- seconds of wiggle before falling
    rock_fall_speed   = 0.08, -- seconds per tile when falling

    -- Win condition
    total_gems = 18,
}
