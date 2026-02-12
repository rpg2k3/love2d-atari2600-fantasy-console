-- src/os/cart_info.lua  Cartridge info display screen
local Video     = require("src.platform.video")
local Palette   = require("src.gfx.palette")
local PixelFont = require("src.util.pixelfont")
local SFX       = require("src.audio.sfx")

local CartInfo = {}

local cart = nil   -- cart metadata table
local scrollY = 0  -- scroll offset for long descriptions/history

-- ============================================================
-- Set the cart to display
-- ============================================================
function CartInfo.setCart(cartMeta)
    cart = cartMeta
    scrollY = 0
end

function CartInfo.getCart()
    return cart
end

-- ============================================================
-- Word-wrap helper: break text into lines of maxW pixels
-- ============================================================
local function wrapText(text, maxChars)
    if not text or text == "" then return {} end
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if #line <= maxChars then
            lines[#lines + 1] = line
        else
            -- Word wrap
            local cur = ""
            for word in line:gmatch("%S+") do
                if #cur + #word + 1 > maxChars then
                    lines[#lines + 1] = cur
                    cur = word
                else
                    cur = cur == "" and word or (cur .. " " .. word)
                end
            end
            if cur ~= "" then lines[#lines + 1] = cur end
        end
    end
    return lines
end

-- ============================================================
-- Draw
-- ============================================================
function CartInfo.draw()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- Top bars
    local barColors = {6, 27, 30}
    local barH = 2
    for i, ci in ipairs(barColors) do
        Palette.setColor(ci)
        love.graphics.rectangle("fill", 0, (i - 1) * barH, iw, barH)
    end

    local y = #barColors * barH + 4

    -- Title header
    local title = "CARTRIDGE INFO"
    local tw = PixelFont.measure(title)
    local tc = Palette.get(15)
    PixelFont.print(title, math.floor((iw - tw) / 2), y, 1, tc[1], tc[2], tc[3])
    y = y + 12

    if not cart then
        local ec = Palette.get(6)
        PixelFont.print("NO CART SELECTED", 8, y, 1, ec[1], ec[2], ec[3])
        return
    end

    -- Divider
    local dc = Palette.get(2)
    for x = 8, iw - 8, 2 do
        love.graphics.setColor(dc[1], dc[2], dc[3], 1)
        love.graphics.rectangle("fill", x, y, 1, 1)
    end
    y = y + 4

    -- Apply scroll
    y = y - scrollY

    -- Cart name
    local nc = Palette.get(cart.color or 4)
    PixelFont.print(string.upper(cart.name or "?"), 8, y, 1, nc[1], nc[2], nc[3])
    y = y + 9

    -- Author
    local ac = Palette.get(27)
    PixelFont.print("BY " .. string.upper(cart.author or "UNKNOWN"), 8, y, 1, ac[1], ac[2], ac[3])
    y = y + 9

    -- Version
    local vc = Palette.get(19)
    PixelFont.print("VERSION " .. (cart.version or "1.0"), 8, y, 1, vc[1], vc[2], vc[3])
    y = y + 12

    -- Description
    local lc = Palette.get(3)
    PixelFont.print("DESCRIPTION:", 8, y, 1, lc[1], lc[2], lc[3])
    y = y + 8

    local maxChars = math.floor((iw - 16) / 4)  -- approx 4px per char
    local desc = cart.description or ""
    if desc == "" then desc = "NO DESCRIPTION PROVIDED." end
    local descLines = wrapText(desc, maxChars)
    local txc = Palette.get(4)
    for _, line in ipairs(descLines) do
        PixelFont.print(string.upper(line), 8, y, 1, txc[1], txc[2], txc[3])
        y = y + 7
    end
    y = y + 5

    -- Version history
    local hc = Palette.get(3)
    PixelFont.print("HISTORY:", 8, y, 1, hc[1], hc[2], hc[3])
    y = y + 8

    if cart.history and type(cart.history) == "table" and #cart.history > 0 then
        for _, entry in ipairs(cart.history) do
            local vc2 = Palette.get(15)
            PixelFont.print("V" .. (entry.version or "?"), 8, y, 1, vc2[1], vc2[2], vc2[3])
            y = y + 7
            if entry.notes then
                local noteLines = wrapText(entry.notes, maxChars - 2)
                local ntc = Palette.get(2)
                for _, nl in ipairs(noteLines) do
                    PixelFont.print("  " .. string.upper(nl), 8, y, 1, ntc[1], ntc[2], ntc[3])
                    y = y + 7
                end
            end
            y = y + 2
        end
    else
        local nhc = Palette.get(2)
        PixelFont.print("NO HISTORY PROVIDED.", 8, y, 1, nhc[1], nhc[2], nhc[3])
    end

    -- Controls at bottom (fixed, not scrolled)
    local bottomY = ih - 12
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, bottomY - 2, iw, 14)
    local cc = Palette.get(2)
    PixelFont.print("[ESC] BACK  [ENTER] PLAY  [UP/DN] SCROLL", 8, bottomY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- Input
-- ============================================================
function CartInfo.keypressed(key)
    if key == "up" then
        scrollY = math.max(0, scrollY - 7)
    elseif key == "down" then
        scrollY = scrollY + 7
    end
    -- "return" and "escape" handled by boot_menu
end

return CartInfo
