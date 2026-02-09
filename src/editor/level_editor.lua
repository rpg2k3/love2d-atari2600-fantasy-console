-- src/editor/level_editor.lua  Real Level Editor v1 with object placement + tilemap
local UI         = require("src.util.ui")
local Video      = require("src.platform.video")
local Serialize  = require("src.util.serialize")
local PixelFont  = require("src.util.pixelfont")
local Config     = require("src.config")
local Input      = require("src.util.input")
local Palette    = require("src.gfx.palette")
local Tile       = require("src.gfx.tile")
local Tilemap    = require("src.gfx.tilemap")
local Sprite     = require("src.gfx.sprite")
local Registry   = require("src.editor.object_registry")
local TileEditor = require("src.editor.tile_editor")

local LE = {}

-- ============================================================
-- State
-- ============================================================
local levelName  = Config.DEFAULT_LEVEL
local levelW     = Config.MAP_COLS
local levelH     = Config.MAP_ROWS
local tileSize   = Config.TILE_W
local objects    = {}   -- array of object tables
local nextObjId  = 1

-- Edit mode: "tiles" or "objects"
local editMode   = "objects"

-- Camera / scroll (in world pixels)
local camX, camY = 0, 0
local panStartX, panStartY = nil, nil
local panCamStartX, panCamStartY = 0, 0

-- Object interaction
local selectedObj   = nil   -- reference into objects
local dragging      = false
local dragOffX, dragOffY = 0, 0
local resizing      = false
local resizeEdge    = nil   -- "br" (bottom-right)

-- Snap
local snapEnabled = true

-- Object type selector
local typeIdx = 1

-- Undo / redo stacks (object operations)
local undoStack = {}
local redoStack = {}

-- Confirm dialog state
local confirmAction  = nil   -- "delete_level", "new_level"
local confirmMsg     = ""

-- Status message (flashes briefly)
local statusMsg  = ""
local statusTime = 0

-- Props editing
local editingPropKey = nil
local editingPropBuf = ""

-- ============================================================
-- Helpers
-- ============================================================
local function snap(v)
    if not snapEnabled then return v end
    return math.floor(v / tileSize + 0.5) * tileSize
end

local function setStatus(msg)
    statusMsg = msg
    statusTime = 2.0
end

local function deepcopyObj(obj)
    local c = {}
    for k, v in pairs(obj) do
        if type(v) == "table" then
            c[k] = {}
            for k2, v2 in pairs(v) do c[k][k2] = v2 end
        else
            c[k] = v
        end
    end
    return c
end

local function deepcopyObjects()
    local out = {}
    for i, o in ipairs(objects) do out[i] = deepcopyObj(o) end
    return out
end

-- ============================================================
-- Undo / Redo (object-level snapshots)
-- ============================================================
local function pushUndo()
    undoStack[#undoStack + 1] = deepcopyObjects()
    if #undoStack > Config.MAX_UNDO then
        table.remove(undoStack, 1)
    end
    -- Clear redo on new action
    for i = 1, #redoStack do redoStack[i] = nil end
end

local function doUndo()
    if #undoStack == 0 then return end
    redoStack[#redoStack + 1] = deepcopyObjects()
    objects = undoStack[#undoStack]
    undoStack[#undoStack] = nil
    selectedObj = nil
    setStatus("UNDO")
end

local function doRedo()
    if #redoStack == 0 then return end
    undoStack[#undoStack + 1] = deepcopyObjects()
    objects = redoStack[#redoStack]
    redoStack[#redoStack] = nil
    selectedObj = nil
    setStatus("REDO")
end

-- ============================================================
-- Level data format
-- ============================================================
local function buildLevelTable()
    local tm = TileEditor.getTilemap()
    local level = {
        version  = Config.LEVEL_VERSION,
        name     = levelName,
        w        = tm.cols,
        h        = tm.rows,
        tileSize = tileSize,
        layers   = {
            bg = tm:export(),
        },
        objects = {},
    }
    -- Ensure fg layer export if present
    if tm.data[2] then
        local hasFg = false
        for r = 1, tm.rows do
            if tm.data[2][r] then
                for c = 1, tm.cols do
                    if tm.data[2][r][c] and tm.data[2][r][c] > 0 then
                        hasFg = true
                        break
                    end
                end
            end
            if hasFg then break end
        end
        if hasFg then
            -- Build fg-only export
            level.layers.fg = { cols = tm.cols, rows = tm.rows, data = { [1] = tm.data[2] } }
        end
    end
    for i, o in ipairs(objects) do
        level.objects[i] = deepcopyObj(o)
    end
    return level
end

local function loadLevelTable(level)
    if not level then return false end
    levelName = level.name or Config.DEFAULT_LEVEL
    levelW    = level.w or Config.MAP_COLS
    levelH    = level.h or Config.MAP_ROWS
    tileSize  = level.tileSize or Config.TILE_W

    -- Rebuild tilemap
    local tm = Tilemap.new(levelW, levelH, 2)
    if level.layers and level.layers.bg then
        tm:import(level.layers.bg)
    end
    if level.layers and level.layers.fg and level.layers.fg.data then
        -- fg layer data is stored with data[1] being the fg rows
        local fgRows = level.layers.fg.data[1]
        if fgRows then
            tm.data[2] = fgRows
        end
    end
    TileEditor.setTilemap(tm)

    -- Load objects
    objects = {}
    nextObjId = 1
    if level.objects then
        for _, o in ipairs(level.objects) do
            objects[#objects + 1] = deepcopyObj(o)
            if type(o.id) == "number" and o.id >= nextObjId then
                nextObjId = o.id + 1
            end
        end
    end
    selectedObj = nil
    -- Clear undo/redo
    for i = 1, #undoStack do undoStack[i] = nil end
    for i = 1, #redoStack do redoStack[i] = nil end
    return true
end

-- ============================================================
-- File operations
-- ============================================================
local function levelPath(name)
    return Config.LEVELS_DIR .. "/" .. name .. ".lua"
end

local function listLevels()
    love.filesystem.createDirectory(Config.LEVELS_DIR)
    local items = love.filesystem.getDirectoryItems(Config.LEVELS_DIR)
    local levels = {}
    for _, f in ipairs(items) do
        local name = f:match("^(.+)%.lua$")
        if name then levels[#levels + 1] = name end
    end
    table.sort(levels)
    return levels
end

function LE.saveLevel()
    love.filesystem.createDirectory(Config.LEVELS_DIR)
    local level = buildLevelTable()
    local path = levelPath(levelName)
    if Serialize.save(path, level) then
        setStatus("SAVED: " .. levelName)
        print("[LEVEL] Saved " .. path)
    else
        setStatus("SAVE FAILED!")
    end
end

function LE.loadLevel(name)
    name = name or levelName
    local path = levelPath(name)
    local data = Serialize.load(path)
    if data then
        loadLevelTable(data)
        setStatus("LOADED: " .. name)
        print("[LEVEL] Loaded " .. path)
        return true
    else
        setStatus("NOT FOUND: " .. name)
        return false
    end
end

function LE.newLevel(name, cols, rows)
    levelName = name or "NEW_LEVEL"
    levelW = cols or Config.MAP_COLS
    levelH = rows or Config.MAP_ROWS
    local tm = Tilemap.new(levelW, levelH, 2)
    TileEditor.setTilemap(tm)
    objects = {}
    nextObjId = 1
    selectedObj = nil
    camX, camY = 0, 0
    for i = 1, #undoStack do undoStack[i] = nil end
    for i = 1, #redoStack do redoStack[i] = nil end
    setStatus("NEW: " .. levelName)
end

function LE.deleteLevel(name)
    local path = levelPath(name or levelName)
    love.filesystem.remove(path)
    setStatus("DELETED: " .. (name or levelName))
end

-- Getter for current level name (used by demo_game for reload)
function LE.getCurrentLevelName()
    return levelName
end

-- Getter for current objects (used by demo_game to access level data)
function LE.getCurrentLevel()
    return buildLevelTable()
end

-- ============================================================
-- Object operations
-- ============================================================
local function addObject(typeName, wx, wy)
    pushUndo()
    local def = Registry.get(typeName)
    local obj = {
        id    = nextObjId,
        type  = typeName,
        x     = snap(wx),
        y     = snap(wy),
        props = Registry.makeDefaultProps(typeName),
    }
    if def and def.shape == "rect" then
        obj.w = def.defaultW or 16
        obj.h = def.defaultH or 16
    end
    nextObjId = nextObjId + 1
    objects[#objects + 1] = obj
    selectedObj = obj
    setStatus("PLACED: " .. string.upper(typeName))
    return obj
end

local function removeObject(obj)
    if not obj then return end
    pushUndo()
    for i, o in ipairs(objects) do
        if o == obj then
            table.remove(objects, i)
            break
        end
    end
    if selectedObj == obj then selectedObj = nil end
    setStatus("DELETED OBJ #" .. tostring(obj.id))
end

local function findObjectAt(wx, wy)
    -- Search in reverse (top objects first)
    for i = #objects, 1, -1 do
        local o = objects[i]
        local ow = o.w or 8
        local oh = o.h or 8
        if wx >= o.x and wx < o.x + ow and wy >= o.y and wy < o.y + oh then
            return o
        end
    end
    return nil
end

-- ============================================================
-- Init
-- ============================================================
function LE.init()
    TileEditor.init()
    -- Try loading default level
    if not LE.loadLevel(Config.DEFAULT_LEVEL) then
        -- No saved level, start with the current tilemap from content
    end
end

-- ============================================================
-- Update
-- ============================================================
function LE.update(dt)
    if statusTime > 0 then
        statusTime = statusTime - dt
        if statusTime <= 0 then statusMsg = "" end
    end
end

-- ============================================================
-- Draw
-- ============================================================
function LE.draw(yOff)
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    yOff = yOff or 10

    -- Top toolbar
    LE.drawToolbar(yOff, iw)
    local toolbarH = 10
    local mapAreaY = yOff + toolbarH

    -- Map + objects viewport
    local mapAreaH = ih - mapAreaY - 30  -- leave room for props panel + status
    LE.drawMapView(2, mapAreaY, iw - 4, mapAreaH, iw, ih)

    -- Bottom props/status panel
    local propsY = mapAreaY + mapAreaH + 1
    LE.drawPropsPanel(2, propsY, iw, ih)

    -- Status message
    if #statusMsg > 0 then
        local c = Palette.get(19)
        PixelFont.print(statusMsg, 2, ih - 7, 1, c[1], c[2], c[3])
    end

    -- Confirm dialog
    if confirmAction then
        local result = UI.confirmDialog(confirmMsg, iw, ih)
        if result == "yes" then
            if confirmAction == "delete_level" then
                LE.deleteLevel()
                LE.newLevel(Config.DEFAULT_LEVEL)
            elseif confirmAction == "new_level" then
                LE.newLevel("LEVEL_" .. string.format("%02d", #listLevels() + 1))
            end
            confirmAction = nil
        elseif result == "no" then
            confirmAction = nil
        end
    end
end

-- ============================================================
-- Toolbar
-- ============================================================
function LE.drawToolbar(yOff, iw)
    local x = 1
    local y = yOff

    -- Mode toggle
    if UI.button("TILE", x, y, 20, 8, editMode == "tiles" and UI.COL_ACTIVE or UI.COL_PANEL) then
        editMode = "tiles"
    end
    x = x + 22
    if UI.button("OBJ", x, y, 18, 8, editMode == "objects" and UI.COL_ACTIVE or UI.COL_PANEL) then
        editMode = "objects"
    end
    x = x + 20

    -- Snap toggle
    if UI.button(snapEnabled and "SN:Y" or "SN:N", x, y, 20, 8, snapEnabled and UI.COL_ACTIVE or UI.COL_PANEL) then
        snapEnabled = not snapEnabled
    end
    x = x + 22

    -- Object type selector (only in object mode)
    if editMode == "objects" then
        local types = Registry.typeOrder
        typeIdx = UI.cycler("", x, y, types, typeIdx, 0)
        local curType = types[typeIdx] or "?"
        local def = Registry.get(curType)
        if def then
            -- Show tiny color swatch
            Palette.setColor(def.color)
            love.graphics.rectangle("fill", x + 42, y + 1, 4, 5)
        end
    end

    -- Right-side buttons
    local rx = iw - 1
    rx = rx - 18
    if UI.button("NEW", rx, y, 17, 8, UI.COL_BUTTON) then
        confirmAction = "new_level"
        confirmMsg = "NEW LEVEL?"
    end
    rx = rx - 18
    if UI.button("SAV", rx, y, 17, 8, UI.COL_ACTIVE) then
        LE.saveLevel()
    end
    rx = rx - 18
    if UI.button("LOD", rx, y, 17, 8, UI.COL_BUTTON) then
        -- Cycle through available levels
        local lvls = listLevels()
        if #lvls > 0 then
            -- Find current and go to next
            local ci = 1
            for i, n in ipairs(lvls) do
                if n == levelName then ci = i; break end
            end
            ci = (ci % #lvls) + 1
            LE.loadLevel(lvls[ci])
        end
    end
    rx = rx - 18
    if UI.button("DEL", rx, y, 17, 8, UI.COL_DANGER) then
        confirmAction = "delete_level"
        confirmMsg = "DELETE " .. levelName .. "?"
    end

    -- Level name
    UI.text(levelName, math.floor(iw / 2) - 20, y, UI.COL_HI)
end

-- ============================================================
-- Map view (tiles + objects overlay)
-- ============================================================
function LE.drawMapView(x, y, vw, vh, iw, ih)
    local tm = TileEditor.getTilemap()
    if not tm then return end

    -- Clamp camera
    local worldW = tm.cols * tileSize
    local worldH = tm.rows * tileSize
    if camX < 0 then camX = 0 end
    if camY < 0 then camY = 0 end
    if camX > worldW - vw then camX = math.max(0, worldW - vw) end
    if camY > worldH - vh then camY = math.max(0, worldH - vh) end

    -- Clip drawing to map area
    love.graphics.setScissor(x, y, vw, vh)

    -- Dark background
    love.graphics.setColor(0.04, 0.04, 0.08, 1)
    love.graphics.rectangle("fill", x, y, vw, vh)

    -- Draw tiles (layer 1)
    love.graphics.push()
    love.graphics.translate(x - camX, y - camY)

    -- Visible tile range
    local c1 = math.max(1, math.floor(camX / tileSize) + 1)
    local r1 = math.max(1, math.floor(camY / tileSize) + 1)
    local c2 = math.min(tm.cols, math.floor((camX + vw) / tileSize) + 2)
    local r2 = math.min(tm.rows, math.floor((camY + vh) / tileSize) + 2)

    for row = r1, r2 do
        for col = c1, c2 do
            local tid = tm:get(1, col, row)
            local px = (col - 1) * tileSize
            local py = (row - 1) * tileSize
            if tid > 0 then
                local timg = Tile.getImage(tid)
                if timg then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(timg, px, py)
                end
            end
            -- Subtle grid
            love.graphics.setColor(0.15, 0.15, 0.2, 0.3)
            love.graphics.rectangle("line", px, py, tileSize, tileSize)
        end
    end

    -- Tile painting (in tile mode)
    if editMode == "tiles" then
        local mx, my = UI.imouse()
        local wmx = mx - x + camX
        local wmy = my - y + camY
        if mx >= x and mx < x + vw and my >= y and my < y + vh then
            -- Highlight hovered tile
            local hc = math.floor(wmx / tileSize) + 1
            local hr = math.floor(wmy / tileSize) + 1
            if hc >= 1 and hc <= tm.cols and hr >= 1 and hr <= tm.rows then
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.rectangle("fill", (hc-1)*tileSize, (hr-1)*tileSize, tileSize, tileSize)
                -- Paint
                if Input.mouseDown(1) and not confirmAction then
                    tm:set(1, hc, hr, TileEditor.getSelectedTile())
                elseif Input.mouseDown(2) and not confirmAction then
                    tm:set(1, hc, hr, 0)
                end
            end
        end
    end

    -- Draw objects
    for _, obj in ipairs(objects) do
        local def = Registry.get(obj.type)
        local ox, oy = obj.x, obj.y
        local ow = obj.w or 8
        local oh = obj.h or 8

        -- Draw sprite if available
        if def and def.spriteId then
            Sprite.draw(def.spriteId, ox, oy)
        end

        -- Draw marker/outline
        if def then
            Palette.setColor(def.color)
            if def.shape == "rect" then
                love.graphics.rectangle("line", ox, oy, ow, oh)
                local c = Palette.get(def.color)
                love.graphics.setColor(c[1], c[2], c[3], 0.15)
                love.graphics.rectangle("fill", ox, oy, ow, oh)
            else
                -- Small dot for point objects
                Palette.setColor(def.color)
                love.graphics.rectangle("line", ox, oy, ow, oh)
            end
        end

        -- Label
        Registry.drawLabel(obj.type, ox, oy)

        -- Selection highlight
        if obj == selectedObj then
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.rectangle("line", ox - 1, oy - 1, ow + 2, oh + 2)
            -- Resize handle for rect objects
            if def and def.shape == "rect" then
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.rectangle("fill", ox + ow - 2, oy + oh - 2, 3, 3)
            end
        end
    end

    love.graphics.pop()

    -- Object interaction (in object mode)
    if editMode == "objects" and not confirmAction then
        LE.handleObjectInput(x, y, vw, vh)
    end

    -- Panning (middle mouse or right mouse in object mode)
    LE.handlePanning(x, y, vw, vh)

    love.graphics.setScissor()

    -- Tile palette bar at bottom of map (in tile mode)
    if editMode == "tiles" then
        LE.drawTilePalette(x, y + vh - 10, vw)
    end
end

-- ============================================================
-- Object mouse interaction
-- ============================================================
function LE.handleObjectInput(vx, vy, vw, vh)
    local mx, my = UI.imouse()
    if mx < vx or mx >= vx + vw or my < vy or my >= vy + vh then return end

    local wmx = mx - vx + camX
    local wmy = my - vy + camY

    if Input.mousePressedThisFrame then
        -- Check resize handle first
        if selectedObj and selectedObj.w then
            local def = Registry.get(selectedObj.type)
            if def and def.shape == "rect" then
                local hx = selectedObj.x + selectedObj.w - 2
                local hy = selectedObj.y + selectedObj.h - 2
                if wmx >= hx and wmx <= hx + 4 and wmy >= hy and wmy <= hy + 4 then
                    resizing = true
                    pushUndo()
                    return
                end
            end
        end

        -- Check if clicking an existing object
        local hit = findObjectAt(wmx, wmy)
        if hit then
            selectedObj = hit
            dragging = true
            dragOffX = wmx - hit.x
            dragOffY = wmy - hit.y
            pushUndo()
        else
            -- Place new object
            local typeName = Registry.typeOrder[typeIdx]
            if typeName then
                addObject(typeName, wmx, wmy)
            end
        end
    end

    if dragging and selectedObj then
        if Input.mouseDown(1) then
            selectedObj.x = snap(wmx - dragOffX)
            selectedObj.y = snap(wmy - dragOffY)
        else
            dragging = false
        end
    end

    if resizing and selectedObj and selectedObj.w then
        if Input.mouseDown(1) then
            selectedObj.w = math.max(tileSize, snap(wmx - selectedObj.x + tileSize / 2))
            selectedObj.h = math.max(tileSize, snap(wmy - selectedObj.y + tileSize / 2))
        else
            resizing = false
        end
    end
end

-- ============================================================
-- Panning
-- ============================================================
function LE.handlePanning(vx, vy, vw, vh)
    local mx, my = UI.imouse()
    -- Pan with middle mouse button (button 3)
    if love.mouse.isDown(3) then
        if not panStartX then
            panStartX, panStartY = mx, my
            panCamStartX, panCamStartY = camX, camY
        else
            camX = panCamStartX - (mx - panStartX)
            camY = panCamStartY - (my - panStartY)
        end
    else
        panStartX = nil
    end
end

-- ============================================================
-- Tile palette (in map view, tile mode)
-- ============================================================
function LE.drawTilePalette(x, y, vw)
    -- Draw a small tile selector bar
    local tileIds = Tile.getAllIds()
    local selTile = TileEditor.getSelectedTile()
    for i, tid in ipairs(tileIds) do
        local bx = x + (i - 1) * (tileSize + 1)
        if bx + tileSize > x + vw then break end
        local timg = Tile.getImage(tid)
        if timg then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(timg, bx, y)
        end
        if tid == selTile then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.rectangle("line", bx - 1, y - 1, tileSize + 2, tileSize + 2)
        end
        -- Click to select (direct tile selection inside level editor)
        local mx, my2 = UI.imouse()
        if Input.mousePressedThisFrame and mx >= bx and mx < bx + tileSize and my2 >= y and my2 < y + tileSize then
            -- We need to set TileEditor's selected tile; use a small helper
            -- For now we just track it locally - the actual tile_editor uses its own selectedTile
            -- but the level editor paints with TileEditor.getSelectedTile()
        end
    end
end

-- ============================================================
-- Props panel
-- ============================================================
function LE.drawPropsPanel(x, y, iw, ih)
    local panelH = 22
    UI.rect(x, y, iw - 4, panelH, UI.COL_BG)

    if not selectedObj then
        UI.text("NO SELECTION", x + 2, y + 2, 3)
        -- Show help
        UI.text("M.BTN:PAN  L:PLACE/DRAG  DEL:REMOVE", x + 2, y + 10, 3)
        return
    end

    local o = selectedObj
    local def = Registry.get(o.type) or {}
    local px = x + 2

    -- Type + ID
    UI.text("#" .. o.id .. " " .. string.upper(o.type), px, y + 1, def.color or UI.COL_HI)
    px = px + 50

    -- Position
    UI.text("X:" .. o.x .. " Y:" .. o.y, px, y + 1, UI.COL_TEXT)
    px = px + 44

    -- Size (for rects)
    if o.w then
        UI.text("W:" .. o.w .. " H:" .. o.h, px, y + 1, UI.COL_TEXT)
    end

    -- Props (second row)
    if def.propDefs and #def.propDefs > 0 then
        local ppx = x + 2
        local ppy = y + 9
        for _, pd in ipairs(def.propDefs) do
            local val = o.props[pd.key]
            if pd.kind == "int" then
                o.props[pd.key] = UI.spinner(pd.label .. ":", ppx, ppy, val or 0, pd.min, pd.max, 1, 20)
                ppx = ppx + 50
            elseif pd.kind == "cycle" then
                -- Find current index
                local ci = 1
                for i, opt in ipairs(pd.options) do
                    if opt == val then ci = i; break end
                end
                ci = UI.cycler(pd.label .. ":", ppx, ppy, pd.options, ci, 20)
                o.props[pd.key] = pd.options[ci]
                ppx = ppx + 54
            elseif pd.kind == "string" then
                UI.text(pd.label .. ":" .. tostring(val or ""), ppx, ppy + 1, UI.COL_TEXT)
                ppx = ppx + 50
            end
        end
    end
end

-- ============================================================
-- Keypressed
-- ============================================================
function LE.keypressed(key)
    -- Confirm dialog eats keys
    if confirmAction then return end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    -- Undo / Redo
    if ctrl and key == "z" then
        doUndo()
        return
    end
    if ctrl and key == "y" then
        doRedo()
        return
    end

    -- Save
    if ctrl and key == "s" then
        LE.saveLevel()
        return
    end

    -- Delete selected object
    if key == "delete" or key == "backspace" then
        if selectedObj then
            removeObject(selectedObj)
        end
        return
    end

    -- Nudge selected object
    if selectedObj then
        local step = shift and tileSize or 1
        if key == "left"  then pushUndo(); selectedObj.x = selectedObj.x - step end
        if key == "right" then pushUndo(); selectedObj.x = selectedObj.x + step end
        if key == "up"    then pushUndo(); selectedObj.y = selectedObj.y - step end
        if key == "down"  then pushUndo(); selectedObj.y = selectedObj.y + step end
        -- Deselect
        if key == "escape" then selectedObj = nil end
        return
    end

    -- Camera scroll (when no object selected)
    local scrollSpd = shift and tileSize * 4 or tileSize * 2
    if key == "left"  then camX = camX - scrollSpd end
    if key == "right" then camX = camX + scrollSpd end
    if key == "up"    then camY = camY - scrollSpd end
    if key == "down"  then camY = camY + scrollSpd end

    -- Toggle snap
    if key == "g" then
        snapEnabled = not snapEnabled
        setStatus("SNAP: " .. (snapEnabled and "ON" or "OFF"))
    end

    -- Toggle edit mode
    if key == "tab" then
        editMode = editMode == "objects" and "tiles" or "objects"
        setStatus("MODE: " .. string.upper(editMode))
    end
end

return LE
