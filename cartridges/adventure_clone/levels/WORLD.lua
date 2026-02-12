-- cartridges/adventure_clone/levels/WORLD.lua
-- Room graph, geometry, item placements, and mode variations
-- Screen: 160x192, play area is full screen, HUD overlaid at top

local W = 160  -- screen width
local H = 192  -- screen height
local WALL = 4 -- wall thickness
local EXIT_W = 24 -- exit corridor width
local EXIT_H = 24

local World = {}

-- ============================================================
-- ROOM DEFINITIONS
-- Each room: {
--   name = string,
--   bg = palette index (background color),
--   wallColor = palette index,
--   walls = { {x,y,w,h}, ... },  -- solid wall rectangles
--   exits = { up=roomId, down=roomId, left=roomId, right=roomId },
--   gate = { side="up"|"down"|"left"|"right", keyId=string, rect={x,y,w,h} } or nil,
--   items = { {id=string, x=num, y=num}, ... },  -- initial item placements (mode-dependent override)
-- }
-- ============================================================

-- Helper: standard room border walls with exits
-- Returns a table of wall rects for a room with specified open exits
local function borderWalls(openUp, openDown, openLeft, openRight)
    local walls = {}
    local cx = math.floor((W - EXIT_W) / 2)  -- center x for vertical exits
    local cy = math.floor((H - EXIT_H) / 2)  -- center y for horizontal exits

    if openUp then
        -- top wall with gap
        walls[#walls+1] = {0, 0, cx, WALL}
        walls[#walls+1] = {cx + EXIT_W, 0, W - (cx + EXIT_W), WALL}
    else
        walls[#walls+1] = {0, 0, W, WALL}
    end

    if openDown then
        walls[#walls+1] = {0, H - WALL, cx, WALL}
        walls[#walls+1] = {cx + EXIT_W, H - WALL, W - (cx + EXIT_W), WALL}
    else
        walls[#walls+1] = {0, H - WALL, W, WALL}
    end

    if openLeft then
        walls[#walls+1] = {0, 0, WALL, cy}
        walls[#walls+1] = {0, cy + EXIT_H, WALL, H - (cy + EXIT_H)}
    else
        walls[#walls+1] = {0, 0, WALL, H}
    end

    if openRight then
        walls[#walls+1] = {0 + W - WALL, 0, WALL, cy}
        walls[#walls+1] = {0 + W - WALL, cy + EXIT_H, WALL, H - (cy + EXIT_H)}
    else
        walls[#walls+1] = {W - WALL, 0, WALL, H}
    end

    return walls
end

-- Helper: castle room with portcullis gate
local function castleRoom(name, bg, wallCol, exitSide, gateSide, gateKeyId, internalWalls)
    local openUp    = (exitSide == "up") or (gateSide == "up")
    local openDown  = (exitSide == "down") or (gateSide == "down")
    local openLeft  = (exitSide == "left") or (gateSide == "left")
    local openRight = (exitSide == "right") or (gateSide == "right")

    local walls = borderWalls(openUp, openDown, openLeft, openRight)
    if internalWalls then
        for _, w in ipairs(internalWalls) do
            walls[#walls+1] = w
        end
    end

    local room = {
        name = name,
        bg = bg,
        wallColor = wallCol,
        walls = walls,
        exits = {},
        items = {},
    }

    -- Gate rect
    if gateSide and gateKeyId then
        local cx = math.floor((W - EXIT_W) / 2)
        local cy = math.floor((H - EXIT_H) / 2)
        local gr
        if gateSide == "up" then
            gr = {cx, 0, EXIT_W, WALL + 4}
        elseif gateSide == "down" then
            gr = {cx, H - WALL - 4, EXIT_W, WALL + 4}
        elseif gateSide == "left" then
            gr = {0, cy, WALL + 4, EXIT_H}
        elseif gateSide == "right" then
            gr = {W - WALL - 4, cy, WALL + 4, EXIT_H}
        end
        room.gate = { side = gateSide, keyId = gateKeyId, rect = gr }
    end

    return room
end

-- ============================================================
-- ROOMS
-- ============================================================
World.rooms = {}

-- Room 1: Yellow Castle - Throne Room (goal room, start room)
World.rooms[1] = {
    name = "Yellow Castle",
    bg = 1,
    wallColor = 15,  -- yellow walls
    walls = borderWalls(true, false, false, false),
    exits = { up = 2 },
    items = {},
    castle = "yellow",
}
-- Add castle interior decorations (throne shape)
local r1w = World.rooms[1].walls
r1w[#r1w+1] = {30, 40, 100, 6}     -- top crossbar
r1w[#r1w+1] = {30, 40, 6, 60}      -- left pillar
r1w[#r1w+1] = {124, 40, 6, 60}     -- right pillar

-- Room 2: Yellow Castle Courtyard
World.rooms[2] = {
    name = "Castle Yard",
    bg = 1,
    wallColor = 15,
    walls = borderWalls(true, true, false, false),
    exits = { up = 3 },
    items = {},
}
-- Gate on down side leading to room 1
World.rooms[2].gate = {
    side = "down", keyId = "key_yellow",
    rect = { math.floor((W-EXIT_W)/2), H - WALL - 4, EXIT_W, WALL + 4 },
}
World.rooms[2].exits.down = 1

-- Room 3: Central Kingdom
World.rooms[3] = {
    name = "Kingdom",
    bg = 1,
    wallColor = 18,  -- green
    walls = borderWalls(true, true, true, true),
    exits = { up = 4, down = 2, left = 6, right = 5 },
    items = {},
}

-- Room 4: Northern Fields
World.rooms[4] = {
    name = "North Fields",
    bg = 1,
    wallColor = 18,
    walls = borderWalls(true, true, true, true),
    exits = { down = 3, left = 8, right = 10, up = 12 },
    items = {},
}

-- Room 5: Eastern Fields
World.rooms[5] = {
    name = "East Fields",
    bg = 1,
    wallColor = 18,
    walls = borderWalls(true, true, true, false),
    exits = { left = 3, up = 10, down = 7 },
    items = {},
}
-- Internal wall: dividing hedge
local r5w = World.rooms[5].walls
r5w[#r5w+1] = {60, 60, 4, 72}

-- Room 6: Western Fields
World.rooms[6] = {
    name = "West Fields",
    bg = 1,
    wallColor = 18,
    walls = borderWalls(true, true, false, true),
    exits = { right = 3, up = 8, down = 15 },
    items = {},
}

-- Room 7: Southeast Field
World.rooms[7] = {
    name = "SE Field",
    bg = 1,
    wallColor = 18,
    walls = borderWalls(true, false, true, false),
    exits = { up = 5, left = 15 },
    items = {},
}

-- Room 8: White Castle Gate
World.rooms[8] = {
    name = "White Castle",
    bg = 1,
    wallColor = 4,  -- white walls
    walls = borderWalls(true, true, false, true),
    exits = { down = 6, right = 4 },
    items = {},
    castle = "white",
}
-- Gate on up side
World.rooms[8].gate = {
    side = "up", keyId = "key_white",
    rect = { math.floor((W-EXIT_W)/2), 0, EXIT_W, WALL + 4 },
}
World.rooms[8].exits.up = 9

-- Room 9: White Castle Interior
World.rooms[9] = {
    name = "White Interior",
    bg = 1,
    wallColor = 4,
    walls = borderWalls(false, true, false, false),
    exits = { down = 8 },
    items = {},
}
-- Internal treasure chamber walls
local r9w = World.rooms[9].walls
r9w[#r9w+1] = {20, 50, 4, 90}
r9w[#r9w+1] = {136, 50, 4, 90}

-- Room 10: Black Castle Gate
World.rooms[10] = {
    name = "Black Castle",
    bg = 1,
    wallColor = 2,  -- dark gray (black castle)
    walls = borderWalls(true, true, true, false),
    exits = { left = 4, down = 5 },
    items = {},
    castle = "black",
}
-- Gate on up side
World.rooms[10].gate = {
    side = "up", keyId = "key_black",
    rect = { math.floor((W-EXIT_W)/2), 0, EXIT_W, WALL + 4 },
}
World.rooms[10].exits.up = 11

-- Room 11: Black Castle Interior
World.rooms[11] = {
    name = "Black Interior",
    bg = 1,
    wallColor = 2,
    walls = borderWalls(false, true, false, false),
    exits = { down = 10 },
    items = {},
}
-- Maze-like interior
local r11w = World.rooms[11].walls
r11w[#r11w+1] = {40, 30, 4, 80}
r11w[#r11w+1] = {80, 50, 4, 100}
r11w[#r11w+1] = {120, 30, 4, 80}

-- Room 12: Blue Maze Entrance
World.rooms[12] = {
    name = "Maze Entry",
    bg = 1,
    wallColor = 26,  -- blue
    walls = borderWalls(true, true, false, true),
    exits = { down = 4, right = 13, up = 14 },
    items = {},
}
-- Maze walls
local r12w = World.rooms[12].walls
r12w[#r12w+1] = {30, 40, 100, 4}
r12w[#r12w+1] = {30, 80, 60, 4}
r12w[#r12w+1] = {30, 120, 100, 4}
r12w[#r12w+1] = {110, 80, 4, 40}

-- Room 13: Blue Maze Center
World.rooms[13] = {
    name = "Maze Center",
    bg = 1,
    wallColor = 26,
    walls = borderWalls(true, true, true, false),
    exits = { left = 12, up = 14, down = 17 },
    items = {},
}
-- Maze walls
local r13w = World.rooms[13].walls
r13w[#r13w+1] = {40, 30, 4, 50}
r13w[#r13w+1] = {80, 60, 4, 70}
r13w[#r13w+1] = {40, 110, 80, 4}
r13w[#r13w+1] = {120, 30, 4, 80}

-- Room 14: Blue Maze Deep
World.rooms[14] = {
    name = "Maze Deep",
    bg = 1,
    wallColor = 26,
    walls = borderWalls(false, true, false, true),
    exits = { down = 12, right = 18 },
    items = {},
}
-- Dense maze
local r14w = World.rooms[14].walls
r14w[#r14w+1] = {30, 30, 4, 60}
r14w[#r14w+1] = {60, 60, 4, 70}
r14w[#r14w+1] = {90, 30, 4, 60}
r14w[#r14w+1] = {120, 80, 4, 60}
r14w[#r14w+1] = {30, 100, 30, 4}
r14w[#r14w+1] = {90, 100, 30, 4}

-- Room 15: Catacombs Entry
World.rooms[15] = {
    name = "Catacombs",
    bg = 1,
    wallColor = 9,  -- brown
    walls = borderWalls(true, true, false, true),
    exits = { up = 6, right = 7, down = 16 },
    items = {},
}
-- Catacomb pillars
local r15w = World.rooms[15].walls
r15w[#r15w+1] = {40, 50, 10, 10}
r15w[#r15w+1] = {110, 50, 10, 10}
r15w[#r15w+1] = {40, 120, 10, 10}
r15w[#r15w+1] = {110, 120, 10, 10}
r15w[#r15w+1] = {75, 85, 10, 10}

-- Room 16: Catacombs Depths
World.rooms[16] = {
    name = "Depths",
    bg = 1,
    wallColor = 9,
    walls = borderWalls(true, false, false, true),
    exits = { up = 15, right = 17 },
    items = {},
}
-- Twisty passages
local r16w = World.rooms[16].walls
r16w[#r16w+1] = {20, 40, 60, 4}
r16w[#r16w+1] = {80, 80, 60, 4}
r16w[#r16w+1] = {20, 120, 60, 4}
r16w[#r16w+1] = {80, 140, 60, 4}

-- Room 17: Dragon's Lair
World.rooms[17] = {
    name = "Dragon Lair",
    bg = 1,
    wallColor = 6,  -- red
    walls = borderWalls(true, false, true, false),
    exits = { up = 13, left = 16 },
    items = {},
}
-- Lair interior
local r17w = World.rooms[17].walls
r17w[#r17w+1] = {50, 30, 60, 4}
r17w[#r17w+1] = {50, 30, 4, 50}
r17w[#r17w+1] = {106, 30, 4, 50}

-- Room 18: Secret Chamber (bridge access from maze deep)
World.rooms[18] = {
    name = "Secret Room",
    bg = 1,
    wallColor = 30,  -- purple
    walls = borderWalls(false, false, true, false),
    exits = { left = 14 },
    items = {},
}

-- ============================================================
-- EXIT LOOKUP (bidirectional verification done above)
-- ============================================================

-- ============================================================
-- ITEM DEFINITIONS
-- ============================================================
World.itemDefs = {
    chalice     = { name = "Chalice",     color = 15, shape = "chalice", w = 6, h = 8 },
    key_yellow  = { name = "Yellow Key",  color = 15, shape = "key",     w = 5, h = 8 },
    key_white   = { name = "White Key",   color = 4,  shape = "key",     w = 5, h = 8 },
    key_black   = { name = "Black Key",   color = 2,  shape = "key",     w = 5, h = 8 },
    sword       = { name = "Sword",       color = 4,  shape = "sword",   w = 3, h = 10 },
    bridge      = { name = "Bridge",      color = 30, shape = "bridge",  w = 16, h = 4 },
    magnet      = { name = "Magnet",      color = 6,  shape = "magnet",  w = 6, h = 6 },
    dot         = { name = "Dot",         color = 1,  shape = "dot",     w = 2, h = 2 },
}

-- ============================================================
-- MODE CONFIGURATIONS
-- mode 1: easy, mode 2: medium, mode 3: hard
-- ============================================================
World.modes = {
    -- MODE 1: Easy
    [1] = {
        dragons = {
            { id = "yorgle", color = 15, speed = 28, room = 17, x = 80, y = 100,
              scared = {"key_yellow"} },
        },
        bat = { room = 9, x = 80, y = 80, speed = 45 },
        items = {
            { id = "chalice",    room = 11, x = 80,  y = 80 },
            { id = "key_yellow", room = 5,  x = 100, y = 100 },
            { id = "key_white",  room = 15, x = 60,  y = 80 },
            { id = "key_black",  room = 12, x = 40,  y = 60 },
            { id = "sword",      room = 3,  x = 120, y = 130 },
            { id = "bridge",     room = 14, x = 100, y = 60 },
        },
        playerStart = { room = 1, x = 80, y = 140 },
    },
    -- MODE 2: Medium
    [2] = {
        dragons = {
            { id = "yorgle", color = 15, speed = 32, room = 17, x = 80, y = 100,
              scared = {"key_yellow"} },
            { id = "grundle", color = 18, speed = 35, room = 11, x = 60, y = 60,
              scared = {} },
        },
        bat = { room = 13, x = 80, y = 80, speed = 50 },
        items = {
            { id = "chalice",    room = 18, x = 80,  y = 100 },
            { id = "key_yellow", room = 16, x = 80,  y = 60 },
            { id = "key_white",  room = 7,  x = 80,  y = 100 },
            { id = "key_black",  room = 14, x = 60,  y = 50 },
            { id = "sword",      room = 9,  x = 80,  y = 120 },
            { id = "bridge",     room = 12, x = 130, y = 140 },
            { id = "magnet",     room = 6,  x = 40,  y = 80 },
        },
        playerStart = { room = 1, x = 80, y = 140 },
    },
    -- MODE 3: Hard
    [3] = {
        dragons = {
            { id = "yorgle", color = 15, speed = 38, room = 3, x = 100, y = 100,
              scared = {} },
            { id = "grundle", color = 18, speed = 40, room = 11, x = 60, y = 60,
              scared = {} },
            { id = "rhindle", color = 6, speed = 44, room = 17, x = 80, y = 100,
              scared = {} },
        },
        bat = { room = 5, x = 80, y = 80, speed = 55 },
        items = {
            { id = "chalice",    room = 18, x = 80,  y = 100 },
            { id = "key_yellow", room = 17, x = 40,  y = 140 },
            { id = "key_white",  room = 16, x = 80,  y = 160 },
            { id = "key_black",  room = 14, x = 120, y = 140 },
            { id = "sword",      room = 11, x = 100, y = 140 },
            { id = "bridge",     room = 7,  x = 80,  y = 80 },
            { id = "magnet",     room = 13, x = 40,  y = 60 },
            { id = "dot",        room = 18, x = 20,  y = 170 },
        },
        playerStart = { room = 1, x = 80, y = 140 },
    },
}

-- ============================================================
-- DRAGON NAMES (for display)
-- ============================================================
World.dragonNames = {
    yorgle  = "Yorgle",
    grundle = "Grundle",
    rhindle = "Rhindle",
}

return World
