-- SONG_01.lua  "Funky Groove" chart for RhythmGroove
-- lane: 1=left, 2=down, 3=up, 4=right
-- beat: 1-based, fractional OK (e.g. 4.5 = half-beat after beat 4)
-- BPM must match content.lua music (130)
-- Max 2 simultaneous notes at any timestamp
-- Accessibility: first 25% is easy single notes, then gradual ramp

return {
    name   = "FUNKY GROOVE",
    bpm    = 130,
    length = 96,  -- total beats

    notes  = {
        ---------------------------------------------------------------
        -- Phase 1: Beats 1-24 (intro + early verse) - EASY
        -- Single notes, well-spaced, no rapid lane changes
        ---------------------------------------------------------------
        { beat=4,   lane=3 },
        { beat=6,   lane=2 },
        { beat=8,   lane=4 },
        { beat=10,  lane=1 },
        { beat=12,  lane=3 },
        { beat=14,  lane=4 },
        { beat=16,  lane=2 },
        { beat=18,  lane=1 },
        { beat=20,  lane=3 },
        { beat=22,  lane=4 },
        { beat=24,  lane=2 },

        ---------------------------------------------------------------
        -- Phase 2: Beats 25-56 (verse + chorus) - MEDIUM
        -- Tighter spacing, first doubles around beat 41
        ---------------------------------------------------------------
        { beat=25,   lane=1 },
        { beat=26.5, lane=3 },
        { beat=28,   lane=4 },
        { beat=29,   lane=2 },
        { beat=31,   lane=1 },
        { beat=32,   lane=3 },
        { beat=33.5, lane=4 },
        { beat=35,   lane=2 },
        { beat=36,   lane=1 },
        { beat=37.5, lane=3 },
        { beat=39,   lane=4 },
        { beat=40,   lane=2 },
        -- first doubles
        { beat=41,   lane=1 },
        { beat=41,   lane=4 },
        { beat=43,   lane=3 },
        { beat=44,   lane=2 },
        { beat=45.5, lane=1 },
        { beat=47,   lane=4 },
        { beat=48,   lane=2 },
        { beat=48,   lane=3 },
        { beat=49.5, lane=1 },
        { beat=51,   lane=4 },
        { beat=52,   lane=3 },
        { beat=53,   lane=2 },
        { beat=54,   lane=1 },
        { beat=54,   lane=4 },
        { beat=55.5, lane=3 },

        ---------------------------------------------------------------
        -- Phase 3: Beats 57-96 (bridge + final choruses) - HARD
        -- Dense patterns, more doubles, syncopation
        ---------------------------------------------------------------
        { beat=57,   lane=2 },
        { beat=58,   lane=4 },
        { beat=58.5, lane=1 },
        { beat=59.5, lane=3 },
        { beat=60,   lane=2 },
        { beat=60,   lane=4 },
        { beat=61,   lane=1 },
        { beat=62,   lane=3 },
        { beat=62.5, lane=4 },
        { beat=63.5, lane=2 },
        { beat=64,   lane=1 },
        { beat=64,   lane=3 },
        { beat=65,   lane=4 },
        { beat=66,   lane=2 },
        { beat=66.5, lane=1 },
        { beat=67.5, lane=3 },
        { beat=68,   lane=4 },
        { beat=68,   lane=2 },
        { beat=69,   lane=1 },
        { beat=70,   lane=3 },
        { beat=71,   lane=4 },
        { beat=71.5, lane=2 },
        { beat=72,   lane=1 },
        { beat=72,   lane=3 },
        { beat=73,   lane=4 },
        { beat=74,   lane=2 },
        { beat=75,   lane=1 },
        { beat=75.5, lane=3 },
        { beat=76,   lane=4 },
        { beat=76,   lane=2 },
        { beat=77,   lane=1 },
        { beat=78,   lane=3 },
        { beat=79,   lane=4 },
        { beat=80,   lane=2 },
        { beat=80.5, lane=1 },
        { beat=81,   lane=3 },
        { beat=81,   lane=4 },
        { beat=82,   lane=2 },
        { beat=83,   lane=1 },
        { beat=84,   lane=4 },
        { beat=85,   lane=2 },
        { beat=85,   lane=1 },
        { beat=86,   lane=4 },
        { beat=87,   lane=3 },
        { beat=88,   lane=2 },
        { beat=89,   lane=1 },
        { beat=90,   lane=3 },
        { beat=91,   lane=4 },
        { beat=92,   lane=2 },
        { beat=93,   lane=1 },
        { beat=94,   lane=3 },
        { beat=95,   lane=4 },
        { beat=96,   lane=2 },
    },
}
