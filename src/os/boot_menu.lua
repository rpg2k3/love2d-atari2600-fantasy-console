-- src/os/boot_menu.lua  Atari-styled cartridge selection screen with manage tools
local Config      = require("src.config")
local Video       = require("src.platform.video")
local Palette     = require("src.gfx.palette")
local PixelFont   = require("src.util.pixelfont")
local SFX         = require("src.audio.sfx")
local CartManager = require("src.os.cart_manager")
local Packager    = require("src.os.cart_packager")
local Settings    = require("src.os.settings")
local CartInfo    = require("src.os.cart_info")

local Boot = {}

local carts    = {}
local cursor   = 1
local selected = nil   -- set when user confirms selection
local timer    = 0

-- Mode: "normal", "import", "confirmDelete", "settings", "info"
local mode = "normal"

-- Status message
local statusMsg   = nil
local statusTimer = 0
local STATUS_DUR  = 3

-- Import mode state
local importList   = {}
local importCursor = 1

-- Delete confirm target
local deleteTarget = nil

-- Splash state
local splashActive = true
local splashTimer  = 0
local SPLASH_DUR   = 1.5

-- Insert animation state
local insertActive = false
local insertTimer  = 0
local insertCart    = nil
local INSERT_DUR   = 0.8

-- ============================================================
-- Init / refresh
-- ============================================================
function Boot.init()
    carts    = CartManager.discover()
    cursor   = 1
    selected = nil
    mode     = "normal"
    statusMsg   = nil
    statusTimer = 0
    -- Load system settings from disk
    Settings.loadFromDisk()
    -- Start splash on first init
    splashActive = true
    splashTimer  = 0
end

function Boot.refresh()
    carts    = CartManager.discover()
    cursor   = math.min(cursor, math.max(1, #carts))
    selected = nil
    mode     = "normal"
end

-- ============================================================
-- Status helpers
-- ============================================================
local function setStatus(msg)
    statusMsg   = msg
    statusTimer = STATUS_DUR
end

-- ============================================================
-- Splash state queries
-- ============================================================
function Boot.isSplashActive()
    return splashActive
end

function Boot.isInsertActive()
    return insertActive
end

function Boot.getInsertCart()
    return insertCart
end

-- ============================================================
-- Update
-- ============================================================
function Boot.update(dt)
    timer = timer + dt

    -- Splash screen timer
    if splashActive then
        splashTimer = splashTimer + dt
        if splashTimer >= SPLASH_DUR then
            splashActive = false
        end
        return  -- don't process anything else during splash
    end

    -- Insert animation timer
    if insertActive then
        insertTimer = insertTimer + dt
        if insertTimer >= INSERT_DUR then
            insertActive = false
            -- Signal the cart to load
            selected = insertCart
            insertCart = nil
        end
        return
    end

    if statusTimer > 0 then
        statusTimer = statusTimer - dt
        if statusTimer <= 0 then
            statusMsg   = nil
            statusTimer = 0
        end
    end
end

-- ============================================================
-- Draw
-- ============================================================
function Boot.draw()
    -- Splash screen
    if splashActive then
        Boot.drawSplash()
        return
    end

    -- Insert animation
    if insertActive then
        Boot.drawInsert()
        return
    end

    -- Settings screen
    if mode == "settings" then
        Settings.draw()
        return
    end

    -- Cart info screen
    if mode == "info" then
        CartInfo.draw()
        return
    end

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

    -- Dispatch to mode-specific draw
    if mode == "import" then
        Boot.drawImport(iw, ih, topY, dc, barColors, barH)
    else
        Boot.drawNormal(iw, ih, topY, dc, barColors, barH)
    end

    -- Status toast (above bottom bars)
    if statusMsg then
        local toastY = ih - #barColors * barH - 18
        local sc = Palette.get(15)
        PixelFont.print(statusMsg, 8, toastY, 1, sc[1], sc[2], sc[3])
    end

    -- Confirm delete overlay
    if mode == "confirmDelete" and deleteTarget then
        Boot.drawConfirmDelete(iw, ih)
    end
end

-- ============================================================
-- Draw: splash screen
-- ============================================================
function Boot.drawSplash()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Black background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    local midX = math.floor(iw / 2)
    local midY = math.floor(ih / 2)

    -- Fade in/out
    local alpha = 1.0
    if splashTimer < 0.3 then
        alpha = splashTimer / 0.3
    elseif splashTimer > SPLASH_DUR - 0.3 then
        alpha = (SPLASH_DUR - splashTimer) / 0.3
    end

    -- Draw a simple Atari-ish logo from rectangles
    -- Stylized "console" shape: a rectangle with a slot
    local logoW = 40
    local logoH = 20
    local logoX = midX - math.floor(logoW / 2)
    local logoY = midY - 30

    -- Console body
    local bc = Palette.get(2)
    love.graphics.setColor(bc[1], bc[2], bc[3], alpha * 0.8)
    love.graphics.rectangle("fill", logoX, logoY, logoW, logoH)

    -- Top ridge
    local rc = Palette.get(6)
    love.graphics.setColor(rc[1], rc[2], rc[3], alpha)
    love.graphics.rectangle("fill", logoX, logoY, logoW, 3)

    -- Cartridge slot
    local slotW = 16
    local slotH = 6
    local slotX = midX - math.floor(slotW / 2)
    local slotY = logoY + 5
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", slotX, slotY, slotW, slotH)

    -- LED indicator (blinking)
    if math.floor(splashTimer * 4) % 2 == 0 then
        local lc = Palette.get(19)
        love.graphics.setColor(lc[1], lc[2], lc[3], alpha)
    else
        local lc = Palette.get(18)
        love.graphics.setColor(lc[1], lc[2], lc[3], alpha * 0.5)
    end
    love.graphics.rectangle("fill", logoX + 3, logoY + logoH - 4, 2, 2)

    -- Joystick ports (two small squares)
    local pc = Palette.get(3)
    love.graphics.setColor(pc[1], pc[2], pc[3], alpha * 0.6)
    love.graphics.rectangle("fill", logoX + logoW - 10, logoY + logoH - 5, 3, 3)
    love.graphics.rectangle("fill", logoX + logoW - 5, logoY + logoH - 5, 3, 3)

    -- Rainbow stripe below console
    local stripeColors = {6, 7, 15, 19, 27, 30}
    for i, ci in ipairs(stripeColors) do
        local sc = Palette.get(ci)
        love.graphics.setColor(sc[1], sc[2], sc[3], alpha * 0.7)
        love.graphics.rectangle("fill", logoX, logoY + logoH + (i - 1), logoW, 1)
    end

    -- Title text
    local title = "9LIVESK9"
    local tw = PixelFont.measure(title)
    local tc = Palette.get(15)
    PixelFont.print(title, midX - math.floor(tw / 2), midY + 4, 1,
        tc[1], tc[2], tc[3], alpha)

    local sub = "FANTASY CONSOLE"
    local sw = PixelFont.measure(sub)
    local sc = Palette.get(7)
    PixelFont.print(sub, midX - math.floor(sw / 2), midY + 14, 1,
        sc[1], sc[2], sc[3], alpha)

    -- "Press any key" after a delay
    if splashTimer > 0.6 then
        local blink = math.floor(splashTimer * 3) % 2 == 0
        if blink then
            local pk = Palette.get(3)
            local msg = "PRESS ANY KEY"
            local mw = PixelFont.measure(msg)
            PixelFont.print(msg, midX - math.floor(mw / 2), midY + 32, 1,
                pk[1], pk[2], pk[3], alpha * 0.7)
        end
    end
end

-- ============================================================
-- Draw: insert cartridge animation
-- ============================================================
function Boot.drawInsert()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Black background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    local midX = math.floor(iw / 2)
    local midY = math.floor(ih / 2)

    -- Console slot (stationary)
    local slotW = 24
    local slotH = 4
    local slotX = midX - math.floor(slotW / 2)
    local slotY = midY + 2

    -- Slot opening
    local sc = Palette.get(2)
    love.graphics.setColor(sc[1], sc[2], sc[3], 1)
    love.graphics.rectangle("fill", slotX - 4, slotY, slotW + 8, slotH + 8)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", slotX, slotY, slotW, slotH)

    -- Cartridge sliding down into slot
    local progress = math.min(1.0, insertTimer / (INSERT_DUR * 0.7))
    -- Ease-in: accelerate
    local ease = progress * progress
    local cartH = 16
    local cartW = 20
    local cartX = midX - math.floor(cartW / 2)
    local startY = midY - 40
    local endY   = slotY - cartH + 2
    local cartY  = startY + (endY - startY) * ease

    -- Cart body
    local cc = Palette.get(insertCart and insertCart.color or 6)
    love.graphics.setColor(cc[1], cc[2], cc[3], 1)
    love.graphics.rectangle("fill", cartX, cartY, cartW, cartH)

    -- Cart label stripe
    local lc = Palette.get(4)
    love.graphics.setColor(lc[1], lc[2], lc[3], 0.8)
    love.graphics.rectangle("fill", cartX + 3, cartY + 3, cartW - 6, 5)

    -- Cart grip notch
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", cartX + math.floor(cartW/2) - 2, cartY, 4, 2)

    -- Text below
    local textY = slotY + slotH + 14
    local name = insertCart and string.upper(insertCart.name) or "CARTRIDGE"
    local msg = "INSERTING " .. name .. "..."
    -- Truncate if too long
    local maxChars = math.floor((iw - 16) / 4)
    if #msg > maxChars then
        msg = msg:sub(1, maxChars - 2) .. ".."
    end
    local mw = PixelFont.measure(msg)
    local tc = Palette.get(15)
    PixelFont.print(msg, midX - math.floor(mw / 2), textY, 1, tc[1], tc[2], tc[3])

    -- Blinking dots
    if insertTimer > INSERT_DUR * 0.5 then
        local dots = math.floor(insertTimer * 4) % 4
        local dotStr = string.rep(".", dots)
        local dc = Palette.get(19)
        PixelFont.print(dotStr, midX - 4, textY + 10, 1, dc[1], dc[2], dc[3])
    end
end

-- ============================================================
-- Draw: normal cart list
-- ============================================================
function Boot.drawNormal(iw, ih, topY, dc, barColors, barH)
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
        -- Controls even in empty state (I to import, S for settings)
        local bottomY = ih - #barColors * barH - 10
        local cc = Palette.get(2)
        PixelFont.print("[I]MPORT [S]ETTINGS", 8, bottomY, 1, cc[1], cc[2], cc[3])
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
    end

    -- Bottom controls (above bars) - three lines
    local bottomY = ih - #barColors * barH - 26
    local cc = Palette.get(2)
    PixelFont.print("[Z/ENTER] PLAY  [X] EXPORT", 8, bottomY, 1, cc[1], cc[2], cc[3])
    bottomY = bottomY + 8
    PixelFont.print("[I]MPORT [D]UP [DEL]ETE", 8, bottomY, 1, cc[1], cc[2], cc[3])
    bottomY = bottomY + 8
    PixelFont.print("[S]ETTINGS [C]ART INFO", 8, bottomY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- Draw: import mode (list exports)
-- ============================================================
function Boot.drawImport(iw, ih, topY, dc, barColors, barH)
    local sc = Palette.get(15)
    PixelFont.print("IMPORT CARTRIDGE:", 8, topY, 1, sc[1], sc[2], sc[3])
    topY = topY + 10

    if #importList == 0 then
        local nc = Palette.get(6)
        PixelFont.print("NO EXPORTS FOUND!", 8, topY, 1, nc[1], nc[2], nc[3])
        topY = topY + 10
        local hc = Palette.get(3)
        PixelFont.print("EXPORT A CART FIRST (X)", 8, topY, 1, hc[1], hc[2], hc[3])
    else
        local listX = 12
        local lineH = 9
        local maxVisible = math.floor((ih - topY - 40) / lineH)
        maxVisible = math.max(3, maxVisible)
        local scrollOff = 0
        if importCursor > maxVisible then
            scrollOff = importCursor - maxVisible
        end

        for i = 1, math.min(#importList, maxVisible) do
            local ci = i + scrollOff
            if ci > #importList then break end
            local exp = importList[ci]
            local cy = topY + (i - 1) * lineH

            -- Truncate filename for display
            local displayName = exp.filename
            local maxChars = math.floor((iw - listX - 8) / 4) -- approx 4px per char
            if #displayName > maxChars then
                displayName = displayName:sub(1, maxChars - 2) .. ".."
            end

            if ci == importCursor then
                local hc = Palette.get(19)
                love.graphics.setColor(hc[1], hc[2], hc[3], 0.2)
                love.graphics.rectangle("fill", listX - 2, cy - 1, iw - listX * 2 + 4, lineH)
                if math.floor(timer * 3) % 2 == 0 then
                    local ac = Palette.get(19)
                    PixelFont.print(">", listX - 6, cy, 1, ac[1], ac[2], ac[3])
                end
                local nc = Palette.get(15)
                PixelFont.print(string.upper(displayName), listX, cy, 1, nc[1], nc[2], nc[3])
            else
                local nc = Palette.get(3)
                PixelFont.print(string.upper(displayName), listX, cy, 1, nc[1], nc[2], nc[3])
            end
        end

        -- Scroll indicators
        if scrollOff > 0 then
            local ic = Palette.get(3)
            PixelFont.print("^", iw - 12, topY, 1, ic[1], ic[2], ic[3])
        end
        if scrollOff + maxVisible < #importList then
            local ic = Palette.get(3)
            PixelFont.print("V", iw - 12, topY + (maxVisible - 1) * lineH, 1, ic[1], ic[2], ic[3])
        end
    end

    -- Bottom controls
    local bottomY = ih - #barColors * barH - 10
    local cc = Palette.get(2)
    PixelFont.print("[ENTER] IMPORT  [ESC] BACK", 8, bottomY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- Draw: confirm delete overlay
-- ============================================================
function Boot.drawConfirmDelete(iw, ih)
    -- Dim overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    local midY = math.floor(ih / 2) - 16

    local wc = Palette.get(6)
    PixelFont.print("DELETE CARTRIDGE?", 8, midY, 1, wc[1], wc[2], wc[3])
    midY = midY + 10

    local nc = Palette.get(15)
    local name = deleteTarget and string.upper(deleteTarget.name or deleteTarget.dir) or "?"
    PixelFont.print(name, 8, midY, 1, nc[1], nc[2], nc[3])
    midY = midY + 14

    local yc = Palette.get(6)
    PixelFont.print("[Y] YES, DELETE", 8, midY, 1, yc[1], yc[2], yc[3])
    midY = midY + 10
    local cc = Palette.get(3)
    PixelFont.print("[N/ESC] CANCEL", 8, midY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- Input
-- ============================================================
function Boot.keypressed(key)
    -- Splash: any key skips
    if splashActive then
        splashActive = false
        return
    end

    -- Insert animation: ignore keys
    if insertActive then
        return
    end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    -- Settings mode
    if mode == "settings" then
        if key == "escape" then
            Settings.saveToDisk()
            mode = "normal"
        else
            Settings.keypressed(key)
        end
        return
    end

    -- Cart info mode
    if mode == "info" then
        if key == "escape" then
            mode = "normal"
        elseif key == "return" then
            -- Launch the cart from info screen
            local infoCart = CartInfo.getCart()
            if infoCart then
                mode = "normal"
                Boot.beginInsert(infoCart)
            end
        else
            CartInfo.keypressed(key)
        end
        return
    end

    -- Confirm delete mode
    if mode == "confirmDelete" then
        if key == "y" then
            if deleteTarget then
                local result = Packager.deleteCart(deleteTarget.dir)
                if result.ok then
                    setStatus("DELETED: " .. string.upper(deleteTarget.dir))
                else
                    setStatus("ERR: " .. (result.err or "?"))
                end
                Boot.refresh()
            end
            mode = "normal"
            deleteTarget = nil
        elseif key == "n" or key == "escape" then
            mode = "normal"
            deleteTarget = nil
        end
        return
    end

    -- Import mode
    if mode == "import" then
        if key == "escape" then
            mode = "normal"
            return
        end
        if key == "up" then
            importCursor = importCursor - 1
            if importCursor < 1 then importCursor = math.max(1, #importList) end
            SFX.play("menuMove")
        elseif key == "down" then
            importCursor = importCursor + 1
            if importCursor > #importList then importCursor = 1 end
            SFX.play("menuMove")
        elseif key == "return" and #importList > 0 then
            local exp = importList[importCursor]
            if exp then
                local result = Packager.importCart(exp.path)
                if result.ok then
                    setStatus("IMPORTED: " .. string.upper(result.cartId))
                    Boot.refresh()
                else
                    setStatus("ERR: " .. (result.err or "?"))
                end
                mode = "normal"
            end
        end
        return
    end

    -- Normal mode
    if #carts == 0 then
        -- Only allow import and settings when no carts
        if key == "i" then
            importList   = Packager.listExports()
            importCursor = 1
            mode         = "import"
        elseif key == "s" then
            Settings.initUI()
            mode = "settings"
        end
        return
    end

    if key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = #carts end
        SFX.play("menuMove")
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > #carts then cursor = 1 end
        SFX.play("menuMove")
    elseif key == "return" or key == "z" then
        -- Launch via insert animation
        local cart = carts[cursor]
        if cart then
            SFX.play("menuSelect")
            Boot.beginInsert(cart)
        end

    -- Settings
    elseif key == "s" then
        Settings.initUI()
        mode = "settings"

    -- Cart Info
    elseif key == "c" then
        local cart = carts[cursor]
        if cart then
            CartInfo.setCart(cart)
            mode = "info"
        end

    -- Export
    elseif key == "x" then
        local cart = carts[cursor]
        if cart then
            local opts = {}
            if shift then opts.withSaveOverrides = true end
            local result = Packager.exportCart(cart.dir, opts)
            if result.ok then
                local label = shift and "EXPORTED+SAVES: " or "EXPORTED: "
                setStatus(label .. string.upper(result.filename))
            else
                setStatus("ERR: " .. (result.err or "?"))
            end
        end

    -- Import
    elseif key == "i" then
        importList   = Packager.listExports()
        importCursor = 1
        mode         = "import"

    -- Duplicate
    elseif key == "d" then
        local cart = carts[cursor]
        if cart then
            local result = Packager.duplicateCart(cart.dir)
            if result.ok then
                setStatus("DUPLICATED: " .. string.upper(result.cartId))
                Boot.refresh()
            else
                setStatus("ERR: " .. (result.err or "?"))
            end
        end

    -- Delete
    elseif key == "delete" then
        local cart = carts[cursor]
        if cart then
            deleteTarget = cart
            mode = "confirmDelete"
        end
    end
end

-- ============================================================
-- Begin insert animation
-- ============================================================
function Boot.beginInsert(cartMeta)
    insertActive = true
    insertTimer  = 0
    insertCart    = cartMeta
    selected     = nil
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

-- ============================================================
-- Get current cart list (for external use)
-- ============================================================
function Boot.getCarts()
    return carts
end

function Boot.getCursor()
    return cursor
end

return Boot
