-- content.lua  DigDive assets
-- 8x8 sprites drawn at scale 2 to fill 16x16 world tiles
-- Palette: 19=lime, 15=yellow, 4=white, 1=black
--          9=brown, 13=dark yellow, 3=gray, 2=dark gray
--          23=cyan, 24=light cyan, 16=light yellow

local _ = 0  -- transparent

return {
    sprites = {
        -- 1: Player (miner) front-facing
        -- Colors: 15=yellow helmet, 19=lime body, 4=white eyes, 1=black
        [1] = { w=8, h=8, grid={
            {_, _, 15, 15, 15, 15, _, _},
            {_, 15, 15, 15, 15, 15, 15, _},
            {_, 19,  4, 19, 19,  4, 19, _},
            {_, 19, 19, 19, 19, 19, 19, _},
            {_, _, 19, 19, 19, 19, _, _},
            {_, 19, 19, 19, 19, 19, 19, _},
            {_, 19, _, _, _, _, 19, _},
            {_, _, _, _, _, _, _, _},
        }},

        -- 2: Rock (boulder)
        -- Colors: 3=medium gray, 2=dark gray (cracks)
        [2] = { w=8, h=8, grid={
            {_, _,  3,  3,  3,  3, _, _},
            {_,  3,  3,  3,  3,  3,  3, _},
            { 3,  3,  3,  2,  3,  3,  3,  3},
            { 3,  3,  2,  2,  3,  3,  3,  3},
            { 3,  3,  3,  3,  3,  2,  3,  3},
            { 3,  3,  3,  3,  2,  2,  3,  3},
            {_,  3,  3,  3,  3,  3,  3, _},
            {_, _,  3,  3,  3,  3, _, _},
        }},

        -- 3: Gem (diamond shape)
        -- Colors: 23=cyan, 24=light cyan, 16=light yellow sparkle
        [3] = { w=8, h=8, grid={
            {_, _, _, 16, _, _, _, _},
            {_, _, 23, 24, 23, _, _, _},
            {_, 23, 24, 24, 24, 23, _, _},
            {23, 24, 24, 16, 24, 24, 23, _},
            {_, 23, 24, 24, 24, 23, _, _},
            {_, _, 23, 24, 23, _, _, _},
            {_, _, _, 23, _, _, _, _},
            {_, _, _, _, _, _, _, _},
        }},

        -- 4: Dirt tile (brown with texture dots)
        -- Colors: 9=brown base, 13=dark yellow detail
        [4] = { w=8, h=8, grid={
            { 9,  9,  9, 13,  9,  9,  9,  9},
            { 9,  9,  9,  9,  9,  9, 13,  9},
            { 9, 13,  9,  9,  9,  9,  9,  9},
            { 9,  9,  9,  9, 13,  9,  9,  9},
            { 9,  9,  9,  9,  9,  9,  9, 13},
            { 9,  9, 13,  9,  9,  9,  9,  9},
            { 9,  9,  9,  9,  9, 13,  9,  9},
            {13,  9,  9,  9,  9,  9,  9,  9},
        }},

        -- 5: Surface grass top
        -- Colors: 17=dark green, 18=green, 19=lime
        [5] = { w=8, h=8, grid={
            {_, 19, _, _, 19, _, _, 19},
            {19, 18, 19, 19, 18, 19, 19, 18},
            {18, 18, 18, 18, 18, 18, 18, 18},
            {18, 17, 18, 17, 18, 17, 18, 17},
            {17, 17, 17, 17, 17, 17, 17, 17},
            { 9,  9,  9,  9,  9,  9,  9,  9},
            { 9,  9,  9,  9,  9,  9,  9,  9},
            { 9,  9,  9,  9,  9,  9,  9,  9},
        }},
    },

    tiles = {},

    music = {
        bpm   = 120,
        speed = 4,
        instruments = {
            [1] = { wave="square",   attack=0.01, decay=0.10, sustain=0.4,  release=0.15, volume=0.18 },
            [2] = { wave="triangle", attack=0.01, decay=0.12, sustain=0.6,  release=0.20, volume=0.24 },
            [3] = { wave="noise",    attack=0.005,decay=0.04, sustain=0.10, release=0.04, volume=0.08 },
        },
        patterns = {
            -- Pattern 1: Underground groove (E minor)
            [1] = { channels = {
                [1] = {{"E3",1},false,false,false, {"G3",1},false,false,false,
                       {"A3",1},false,{"B3",1},false, {"A3",1},false,{"G3",1},false},
                [2] = {{"E2",2},false,false,false, false,false,{"E2",2},false,
                       false,false,false,false, {"E2",2},false,false,false},
                [3] = {{"C4",3},false,false,{"C4",3}, false,false,{"C4",3},false,
                       {"C4",3},false,false,{"C4",3}, false,false,{"C4",3},false},
            }},
            -- Pattern 2: Tension build
            [2] = { channels = {
                [1] = {{"B3",1},false,{"A3",1},false, {"G3",1},false,false,false,
                       {"E3",1},false,{"D3",1},false, {"E3",1},false,false,false},
                [2] = {{"B2",2},false,false,false, {"A2",2},false,false,false,
                       {"G2",2},false,false,false, {"E2",2},false,false,false},
                [3] = {{"C4",3},false,{"C4",3},false, {"C4",3},false,{"C4",3},false,
                       {"C4",3},false,{"C4",3},false, {"C4",3},false,{"C4",3},false},
            }},
            -- Pattern 3: Deeper groove
            [3] = { channels = {
                [1] = {{"E3",1},false,{"E3",1},false, {"D3",1},false,{"C3",1},false,
                       {"D3",1},false,false,false, {"E3",1},false,false,false},
                [2] = {{"C2",2},false,false,{"C2",2}, false,false,{"D2",2},false,
                       false,{"D2",2},false,false, {"E2",2},false,false,false},
                [3] = {false,false,{"C4",3},false, {"C4",3},false,false,{"C4",3},
                       false,false,{"C4",3},false, false,{"C4",3},false,false},
            }},
        },
        order = {
            1, 1, 2, 1,   -- intro + groove
            1, 3, 2, 1,   -- variation
            3, 3, 2, 2,   -- deeper
            1, 1, 3, 1,   -- return
        },
    },
}
