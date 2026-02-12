-- content.lua  RhythmGroove assets
-- Arrow sprites (8x8) for 4 lanes + judgement targets
-- Lane colors: Left=7(orange-red) Down=27(blue) Up=19(lime) Right=15(yellow)

local L = 7   -- left
local D = 27  -- down
local U = 19  -- up
local R = 15  -- right
local _ = 0   -- transparent

return {
    sprites = {
        -- 1: Left arrow
        [1] = { w=8, h=8, grid={
            {_,_,_,L,_,_,_,_},
            {_,_,L,L,_,_,_,_},
            {_,L,L,L,L,L,L,_},
            {L,L,L,L,L,L,L,L},
            {L,L,L,L,L,L,L,L},
            {_,L,L,L,L,L,L,_},
            {_,_,L,L,_,_,_,_},
            {_,_,_,L,_,_,_,_},
        }},
        -- 2: Down arrow
        [2] = { w=8, h=8, grid={
            {D,_,_,_,_,_,_,D},
            {D,D,_,_,_,_,D,D},
            {D,D,D,_,_,D,D,D},
            {D,D,D,D,D,D,D,D},
            {_,D,D,D,D,D,D,_},
            {_,_,D,D,D,D,_,_},
            {_,_,_,D,D,_,_,_},
            {_,_,_,_,_,_,_,_},
        }},
        -- 3: Up arrow
        [3] = { w=8, h=8, grid={
            {_,_,_,_,_,_,_,_},
            {_,_,_,U,U,_,_,_},
            {_,_,U,U,U,U,_,_},
            {_,U,U,U,U,U,U,_},
            {U,U,U,U,U,U,U,U},
            {U,U,U,_,_,U,U,U},
            {U,U,_,_,_,_,U,U},
            {U,_,_,_,_,_,_,U},
        }},
        -- 4: Right arrow
        [4] = { w=8, h=8, grid={
            {_,_,_,_,R,_,_,_},
            {_,_,_,_,R,R,_,_},
            {_,R,R,R,R,R,R,_},
            {R,R,R,R,R,R,R,R},
            {R,R,R,R,R,R,R,R},
            {_,R,R,R,R,R,R,_},
            {_,_,_,_,R,R,_,_},
            {_,_,_,_,R,_,_,_},
        }},
    },

    tiles = {},

    music = {
        bpm   = 130,
        speed = 4,
        instruments = {
            [1] = { wave="square",   attack=0.01, decay=0.08, sustain=0.5,  release=0.15, volume=0.20 },
            [2] = { wave="triangle", attack=0.01, decay=0.10, sustain=0.6,  release=0.20, volume=0.26 },
            [3] = { wave="noise",    attack=0.005,decay=0.04, sustain=0.15, release=0.04, volume=0.10 },
            [4] = { wave="saw",      attack=0.01, decay=0.06, sustain=0.35, release=0.10, volume=0.14 },
        },
        patterns = {
            -- Pattern 1: Intro (mellow)
            [1] = { channels = {
                [1] = {{"E4",1},false,false,false, {"G4",1},false,false,false,
                       {"B4",1},false,false,false, {"A4",1},false,false,false},
                [2] = {{"E2",2},false,false,false, false,false,false,false,
                       {"E2",2},false,false,false, false,false,false,false},
                [3] = {false,false,{"C4",3},false, false,false,{"C4",3},false,
                       false,false,{"C4",3},false, false,false,{"C4",3},false},
            }},
            -- Pattern 2: Verse (building)
            [2] = { channels = {
                [1] = {{"E4",1},false,{"G4",1},false, {"A4",1},false,{"B4",1},false,
                       {"A4",1},false,{"G4",1},false, {"E4",1},false,{"D4",1},false},
                [2] = {{"E2",2},false,false,{"E2",2}, false,false,{"A2",2},false,
                       false,{"A2",2},false,false, {"B2",2},false,false,{"B2",2}},
                [3] = {{"C4",3},false,false,{"C4",3}, {"C4",3},false,false,{"C4",3},
                       {"C4",3},false,false,{"C4",3}, {"C4",3},false,false,{"C4",3}},
            }},
            -- Pattern 3: Chorus (energetic)
            [3] = { channels = {
                [1] = {{"E4",1},false,{"E4",4},{"G4",1}, false,{"A4",1},false,{"B4",4},
                       false,{"B4",1},{"A4",4},false, {"G4",1},false,{"E4",1},false},
                [2] = {{"E2",2},false,{"E2",2},false, {"A2",2},false,{"A2",2},false,
                       {"B2",2},false,{"B2",2},false, {"A2",2},false,{"A2",2},false},
                [3] = {{"C4",3},false,{"C4",3},false, {"C4",3},false,{"C4",3},false,
                       {"C4",3},false,{"C4",3},false, {"C4",3},false,{"C4",3},false},
            }},
            -- Pattern 4: Bridge
            [4] = { channels = {
                [1] = {{"D4",1},false,false,{"F#4",4}, false,false,{"A4",1},false,
                       false,{"D5",1},false,false, {"A4",4},false,{"F#4",1},false},
                [2] = {{"D2",2},false,false,false, {"D2",2},false,false,false,
                       {"G2",2},false,false,false, {"A2",2},false,false,false},
                [3] = {{"C4",3},false,false,false, false,false,{"C4",3},false,
                       {"C4",3},false,false,false, false,false,{"C4",3},false},
            }},
            -- Pattern 5: Outro (wind down)
            [5] = { channels = {
                [1] = {{"E4",1},false,false,false, {"D4",1},false,false,false,
                       {"B3",1},false,false,false, false,false,false,false},
                [2] = {{"E2",2},false,false,false, false,false,false,false,
                       {"E2",2},false,false,false, false,false,false,false},
                [3] = {false,false,false,false, {"C4",3},false,false,false,
                       false,false,false,false, {"C4",3},false,false,false},
            }},
        },
        -- 24 entries x 4 beats = 96 beats total
        order = {
            1,1,          -- 8 beats: intro
            2,2,2,2,      -- 16 beats: verse
            3,3,3,3,      -- 16 beats: chorus
            4,4,          -- 8 beats: bridge
            3,3,3,3,      -- 16 beats: chorus
            2,2,          -- 8 beats: verse
            3,3,3,3,      -- 16 beats: final chorus
            5,5,          -- 8 beats: outro
        },
    },
}
