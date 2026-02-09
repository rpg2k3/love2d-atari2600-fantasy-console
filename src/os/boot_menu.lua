-- src/os/boot_menu.lua  Atari-styled cartridge selection screen
local Config      = require("src.config")
local Video       = require("src.platform.video")
local Palette     = require("src.gfx.palette")
local PixelFont   = require("src.util.pixelfont")
local SFX         = require("src.audio.sfx")
local CartManager = require("src.os.cart_manager")

local Boot = {}

local carts    = {}
local cursor   = 1
local selected = nil   -- set when user confirms selection
local timer    = 0

-- ============================================================
-- Init / refresh
-- ============================================================
function Boot.init()
    carts    = CartManager.discover()
    cursor   = 1
    selected = nil
end

function Boot.refresh()
    carts    = CartManager.discover()
    cursor   = math.min(cursor, math.max(1, #carts))
    selected = nil
end

-- ============================================================
-- Update
-- ============================================================
function Boot.update(dt)
    timer = timer + dt
end

-- ============================================================
-- Draw
-- ============================================================
function Boot.draw()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- Decorative colored bars at top (Atari rainbow)
    local barColors = {6, 7, 15, 19, 27, 30}
    local barH = 2
    for i, ci in ipairs(barColors) do
        Palette.setColor(ci)
        love.graphics.rectangle("fill", 0, (i - 1) * barH, iw, barH)
    end

    -- Bottom bars (mirror)
    for i, ci in ipairs(barColors) do
        Palette.setColor(ci)
        love.graphics.rectangle("fill", 0, ih - i * barH, iw, barH)
    end

    local topY = #barColors * barH + 4

    -- Title (pulsing color)
    local title = "FANTASY CONSOLE 2600"
    local titleW = PixelFont.measure(title)
    local titleX = math.floor((iw - titleW) / 2)
    local titleCol = math.floor(timer * 2) % 2 == 0 and 15 or 16
    local tc = Palette.get(titleCol)
    PixelFont.print(title, titleX, topY, 1, tc[1], tc[2], tc[3])
    topY = topY + 12

    -- Dotted divider
    local dc = Palette.get(2)
    for x = 8, iw - 8, 2 do
        love.graphics.setColor(dc[1], dc[2], dc[3], 1)
        love.graphics.rectangle("fill", x, topY, 1, 1)
    end
    topY = topY + 4

    -- Empty state
    if #carts == 0 then
        local nc = Palette.get(6)
        PixelFont.print("NO CARTRIDGES FOUND!", 8, topY, 1, nc[1], nc[2], nc[3])
        topY = topY + 10
        local hc = Palette.get(3)
        PixelFont.print("ADD CARTS TO:", 8, topY, 1, hc[1], hc[2], hc[3])
        topY = topY + 8
        PixelFont.print("CARTRIDGES/<NAME>/", 8, topY, 1, hc[1], hc[2], hc[3])
        topY = topY + 8
        PixelFont.print("WITH CART.LUA + MAIN.LUA", 8, topY, 1, hc[1], hc[2], hc[3])
        return
    end

    -- "SELECT CARTRIDGE" label
    local sc = Palette.get(3)
    PixelFont.print("SELECT CARTRIDGE:", 8, topY, 1, sc[1], sc[2], sc[3])
    topY = topY + 10

    -- Cart list
    local listX  = 12
    local listY  = topY
    local lineH  = 9

    -- Visible range with scrolling
    local maxVisible = math.floor((ih - listY - 60) / lineH)
    maxVisible = math.max(3, maxVisible)
    local scrollOff = 0
    if cursor > maxVisible then
        scrollOff = cursor - maxVisible
    end

    for i = 1, math.min(#carts, maxVisible) do
        local ci = i + scrollOff
        if ci > #carts then break end
        local cart = carts[ci]
        local cy = listY + (i - 1) * lineH

        if ci == cursor then
            -- Selection highlight bar
            local hc = Palette.get(cart.color or 19)
            love.graphics.setColor(hc[1], hc[2], hc[3], 0.2)
            love.graphics.rectangle("fill", listX - 2, cy - 1, iw - listX * 2 + 4, lineH)

            -- Blinking cursor arrow
            if math.floor(timer * 3) % 2 == 0 then
                local ac = Palette.get(19)
                PixelFont.print(">", listX - 6, cy, 1, ac[1], ac[2], ac[3])
            end

            -- Highlighted name
            local nc = Palette.get(cart.color or 4)
            PixelFont.print(string.upper(cart.name), listX, cy, 1, nc[1], nc[2], nc[3])
        else
            -- Normal name
            local nc = Palette.get(3)
            PixelFont.print(string.upper(cart.name), listX, cy, 1, nc[1], nc[2], nc[3])
        end
    end

    -- Scroll indicators
    if scrollOff > 0 then
        local ic = Palette.get(3)
        PixelFont.print("^", iw - 12, listY, 1, ic[1], ic[2], ic[3])
    end
    if scrollOff + maxVisible < #carts then
        local ic = Palette.get(3)
        PixelFont.print("V", iw - 12, listY + (maxVisible - 1) * lineH, 1, ic[1], ic[2], ic[3])
    end

    -- Cart info panel
    local infoY = listY + maxVisible * lineH + 4

    -- Divider
    for x = 8, iw - 8, 2 do
        love.graphics.setColor(dc[1], dc[2], dc[3], 1)
        love.graphics.rectangle("fill", x, infoY, 1, 1)
    end
    infoY = infoY + 4

    local cart = carts[cursor]
    if cart then
        -- Name + version
        local nc = Palette.get(cart.color or 4)
        PixelFont.print(string.upper(cart.name) .. " V" .. (cart.version or "1.0"),
            8, infoY, 1, nc[1], nc[2], nc[3])
        infoY = infoY + 8

        -- Author
        local ac = Palette.get(27)
        PixelFont.print("BY " .. string.upper(cart.author or "UNKNOWN"),
            8, infoY, 1, ac[1], ac[2], ac[3])
        infoY = infoY + 8

        -- Description
        if cart.description and #cart.description > 0 then
            local dtc = Palette.get(3)
            PixelFont.print(string.upper(cart.description),
                8, infoY, 1, dtc[1], dtc[2], dtc[3])
        end
    end

    -- Bottom controls (above bars)
    local bottomY = ih - #barColors * barH - 10
    local cc = Palette.get(2)
    PixelFont.print("[Z/ENTER] PLAY  [F12] HELP", 8, bottomY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- Input
-- ============================================================
function Boot.keypressed(key)
    if #carts == 0 then return end

    if key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = #carts end
        SFX.play("menuMove")
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > #carts then cursor = 1 end
        SFX.play("menuMove")
    elseif key == "return" or key == "z" then
        selected = carts[cursor]
        SFX.play("menuSelect")
    end
end

-- ============================================================
-- Selection accessors
-- ============================================================
function Boot.getSelected()
    return selected
end

function Boot.clearSelection()
    selected = nil
end

return Boot
