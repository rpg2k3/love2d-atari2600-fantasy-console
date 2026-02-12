-- cartridges/breakfunk/levels/LEVEL_01.lua
-- Brick layout for BreakFunk level 1
-- Each row: { col, row, spriteId }
-- spriteId: 3=blue, 4=orange, 5=red, 6=yellow
-- Layout designed for 160x192 internal resolution
-- Playfield: bricks start at y=20, each brick is 16x6
-- 9 bricks per row (16*9 = 144), centered with 8px margin each side

local level = {}

-- Generate a classic Breakout-style grid: 6 rows of 9 bricks
-- Row 1-2: red (top, highest value)
-- Row 3-4: orange (mid value)
-- Row 5-6: yellow/blue (lowest value)
level.bricks = {}

local BRICK_W   = 16
local BRICK_H   = 6
local COLS       = 9
local START_X    = 8   -- centering offset for 160px wide screen
local START_Y    = 24  -- top of brick area (below score HUD)
local GAP        = 1   -- 1px gap between rows

local rowColors = { 5, 5, 4, 4, 6, 3 }  -- red, red, orange, orange, yellow, blue
local rowScores = { 7, 7, 5, 5, 3, 1 }  -- point multiplier per row

for row = 1, 6 do
    for col = 1, COLS do
        local bx = START_X + (col - 1) * BRICK_W
        local by = START_Y + (row - 1) * (BRICK_H + GAP)
        level.bricks[#level.bricks + 1] = {
            x       = bx,
            y       = by,
            w       = BRICK_W,
            h       = BRICK_H,
            sprite  = rowColors[row],
            score   = rowScores[row] * 10,
            alive   = true,
        }
    end
end

level.paddleY   = 176  -- paddle vertical position
level.ballSpeed = 80   -- initial ball speed in pixels/sec

return level
