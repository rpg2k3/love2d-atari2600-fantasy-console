-- src/util/ui.lua  Immediate-mode pixel-styled UI widgets
local PixelFont = require("src.util.pixelfont")
local Palette   = require("src.gfx.palette")
local Input     = require("src.util.input")
local Video     = require("src.platform.video")

local UI = {}

-- Colors (palette indices)
UI.COL_BG     = 1   -- black
UI.COL_PANEL  = 2   -- dark gray
UI.COL_TEXT   = 4   -- white
UI.COL_HI     = 15  -- yellow
UI.COL_BUTTON = 26  -- blue
UI.COL_ACTIVE = 18  -- green
UI.COL_DANGER = 6   -- red

-- Get internal mouse position
local function imouse()
    local mx, my = Input.mouse()
    return Video.screenToInternal(mx, my)
end
UI.imouse = imouse

-- Draw a filled rectangle with a palette color
function UI.rect(x, y, w, h, colIdx)
    Palette.setColor(colIdx)
    love.graphics.rectangle("fill", x, y, w, h)
end

-- Draw a border rectangle
function UI.border(x, y, w, h, colIdx)
    Palette.setColor(colIdx)
    love.graphics.rectangle("line", x, y, w, h)
end

-- Draw text
function UI.text(str, x, y, colIdx, scale)
    local c = Palette.get(colIdx or UI.COL_TEXT)
    PixelFont.print(str, x, y, scale or 1, c[1], c[2], c[3], c[4])
end

-- Button: returns true if clicked this frame
function UI.button(label, x, y, w, h, colIdx)
    colIdx = colIdx or UI.COL_BUTTON
    local mx, my = imouse()
    local hover = mx >= x and mx < x+w and my >= y and my < y+h
    local col = hover and UI.COL_HI or colIdx
    UI.rect(x, y, w, h, col)
    UI.border(x, y, w, h, UI.COL_TEXT)
    local tw = PixelFont.measure(label)
    UI.text(label, x + math.floor((w - tw) / 2), y + math.floor((h - PixelFont.GLYPH_H) / 2), UI.COL_TEXT)
    return hover and Input.mousePressedThisFrame
end

-- Horizontal slider: returns new value (0..1)
function UI.slider(x, y, w, value, colIdx)
    colIdx = colIdx or UI.COL_BUTTON
    local h = 5
    UI.rect(x, y, w, h, UI.COL_PANEL)
    -- fill bar
    local fw = math.floor(value * (w - 2))
    UI.rect(x + 1, y + 1, fw, h - 2, colIdx)
    -- handle
    local mx, my = imouse()
    if Input.mouseDown(1) and mx >= x and mx <= x+w and my >= y-2 and my <= y+h+2 then
        value = (mx - x) / w
        if value < 0 then value = 0 end
        if value > 1 then value = 1 end
    end
    return value
end

-- Tab bar: returns selected tab index
function UI.tabs(labels, selected, x, y, tabW, tabH)
    for i, label in ipairs(labels) do
        local tx = x + (i - 1) * (tabW + 1)
        local col = (i == selected) and UI.COL_ACTIVE or UI.COL_PANEL
        if UI.button(label, tx, y, tabW, tabH, col) then
            selected = i
        end
    end
    return selected
end

-- Palette picker: returns selected palette index
function UI.palettePicker(x, y, cellSize, selected, maxCols)
    maxCols = maxCols or 8
    local count = Palette.count
    for i = 1, count do
        local col = (i - 1) % maxCols
        local row = math.floor((i - 1) / maxCols)
        local cx = x + col * (cellSize + 1)
        local cy = y + row * (cellSize + 1)
        Palette.setColor(i)
        love.graphics.rectangle("fill", cx, cy, cellSize, cellSize)
        if i == selected then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", cx - 1, cy - 1, cellSize + 2, cellSize + 2)
        end
        -- click
        local mx, my = imouse()
        if Input.mousePressedThisFrame and mx >= cx and mx < cx+cellSize and my >= cy and my < cy+cellSize then
            selected = i
        end
    end
    return selected
end

-- Grid editor: draw a pixel grid and handle painting. Returns modified grid.
function UI.gridEditor(grid, x, y, cellSize, selectedColor, w, h)
    w = w or #grid[1]
    h = h or #grid
    for gy = 1, h do
        for gx = 1, w do
            local ci = grid[gy] and grid[gy][gx] or 0
            local cx = x + (gx - 1) * cellSize
            local cy = y + (gy - 1) * cellSize
            if ci == 0 then
                -- checkerboard for transparent
                love.graphics.setColor(0.15, 0.15, 0.15, 1)
                love.graphics.rectangle("fill", cx, cy, cellSize, cellSize)
                love.graphics.setColor(0.25, 0.25, 0.25, 1)
                if (gx + gy) % 2 == 0 then
                    love.graphics.rectangle("fill", cx, cy, cellSize, cellSize)
                end
            else
                Palette.setColor(ci)
                love.graphics.rectangle("fill", cx, cy, cellSize, cellSize)
            end
        end
    end
    -- Grid lines
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    for gx = 0, w do
        local lx = x + gx * cellSize
        love.graphics.line(lx, y, lx, y + h * cellSize)
    end
    for gy = 0, h do
        local ly = y + gy * cellSize
        love.graphics.line(x, ly, x + w * cellSize, ly)
    end
    -- Paint
    local mx, my = imouse()
    if Input.mouseDown(1) then
        local gx = math.floor((mx - x) / cellSize) + 1
        local gy = math.floor((my - y) / cellSize) + 1
        if gx >= 1 and gx <= w and gy >= 1 and gy <= h then
            if not grid[gy] then grid[gy] = {} end
            grid[gy][gx] = selectedColor
        end
    elseif Input.mouseDown(2) then
        local gx = math.floor((mx - x) / cellSize) + 1
        local gy = math.floor((my - y) / cellSize) + 1
        if gx >= 1 and gx <= w and gy >= 1 and gy <= h then
            if not grid[gy] then grid[gy] = {} end
            grid[gy][gx] = 0  -- erase with right click
        end
    end
    return grid
end

-- Number spinner: label + value + < > buttons.  Returns new value.
function UI.spinner(label, x, y, value, lo, hi, step, labelW)
    step = step or 1
    labelW = labelW or 24
    UI.text(label, x, y + 1, UI.COL_TEXT)
    local bx = x + labelW
    if UI.button("<", bx, y, 8, 7) then
        value = value - step
    end
    local valStr = tostring(value)
    if math.floor(value) ~= value then valStr = string.format("%.1f", value) end
    UI.text(valStr, bx + 10, y + 1, UI.COL_HI)
    local tw = PixelFont.measure(valStr)
    if UI.button(">", bx + 12 + tw, y, 8, 7) then
        value = value + step
    end
    if lo and value < lo then value = lo end
    if hi and value > hi then value = hi end
    return value
end

-- Cycling selector: label + current option string + < > buttons. Returns new index.
function UI.cycler(label, x, y, options, idx, labelW)
    labelW = labelW or 24
    UI.text(label, x, y + 1, UI.COL_TEXT)
    local bx = x + labelW
    if UI.button("<", bx, y, 8, 7) then
        idx = idx - 1
        if idx < 1 then idx = #options end
    end
    local cur = options[idx] or "?"
    if type(cur) == "table" then cur = cur.label or tostring(cur) end
    cur = string.upper(tostring(cur))
    UI.text(cur, bx + 10, y + 1, UI.COL_HI)
    local tw = PixelFont.measure(cur)
    if UI.button(">", bx + 12 + tw, y, 8, 7) then
        idx = idx + 1
        if idx > #options then idx = 1 end
    end
    return idx
end

-- Label + value (read-only display)
function UI.labelVal(label, val, x, y, labelCol, valCol)
    UI.text(label, x, y, labelCol or UI.COL_TEXT)
    local tw = PixelFont.measure(label)
    UI.text(tostring(val), x + tw + 2, y, valCol or UI.COL_HI)
end

-- Confirm dialog: draws a centered panel with YES/NO.
-- Returns "yes", "no", or nil (still showing).
-- Caller must persist `visible` state externally.
function UI.confirmDialog(title, iw, ih)
    local pw, ph = 80, 30
    local px = math.floor((iw - pw) / 2)
    local py = math.floor((ih - ph) / 2)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", px - 1, py - 1, pw + 2, ph + 2)
    UI.rect(px, py, pw, ph, UI.COL_PANEL)
    UI.border(px, py, pw, ph, UI.COL_TEXT)
    UI.text(title, px + 3, py + 3, UI.COL_HI)
    if UI.button("YES", px + 8, py + 16, 24, 10, UI.COL_ACTIVE) then
        return "yes"
    end
    if UI.button("NO", px + 40, py + 16, 24, 10, UI.COL_DANGER) then
        return "no"
    end
    return nil
end

return UI
