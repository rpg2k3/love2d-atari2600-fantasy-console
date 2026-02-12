-- src/os/settings.lua  System settings: persist + settings screen UI
local Config    = require("src.config")
local Serialize = require("src.util.serialize")
local Palette   = require("src.gfx.palette")
local PixelFont = require("src.util.pixelfont")
local Video     = require("src.platform.video")
local Music     = require("src.audio.music")
local SFX       = require("src.audio.sfx")

local Settings = {}

-- Current settings (runtime state)
local data = {
    version       = 1,
    masterVolume  = 0.8,
    crtPreset     = 2,       -- 1=off, 2=subtle, 3=strong
    paletteVariant = 1,      -- 1=default, 2=warm, 3=cool
}

-- UI state
local cursor = 1
local NUM_ROWS = 3  -- volume, crt, palette

-- ============================================================
-- Persistence
-- ============================================================
function Settings.loadFromDisk()
    love.filesystem.createDirectory(Config.SYSTEM_DIR)
    local saved = Serialize.load(Config.SETTINGS_PATH)
    if saved and type(saved) == "table" then
        if saved.masterVolume  then data.masterVolume  = saved.masterVolume end
        if saved.crtPreset     then data.crtPreset     = saved.crtPreset end
        if saved.paletteVariant then data.paletteVariant = saved.paletteVariant end
    end
    Settings.applyAll()
end

function Settings.saveToDisk()
    love.filesystem.createDirectory(Config.SYSTEM_DIR)
    Serialize.save(Config.SETTINGS_PATH, data)
end

-- ============================================================
-- Apply settings to engine
-- ============================================================
function Settings.applyAll()
    -- Master volume
    Music.setVolume(data.masterVolume)
    SFX.setMasterVolume(data.masterVolume)

    -- CRT preset
    Config.CRT_INDEX = math.max(1, math.min(#Config.CRT_PRESETS, data.crtPreset))

    -- Palette variant
    Palette.setVariant(data.paletteVariant)
end

-- ============================================================
-- Getters for external use
-- ============================================================
function Settings.get()
    return data
end

function Settings.getMasterVolume()
    return data.masterVolume
end

-- ============================================================
-- UI: init / reset cursor
-- ============================================================
function Settings.initUI()
    cursor = 1
end

-- ============================================================
-- UI: draw
-- ============================================================
function Settings.draw()
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()

    -- Background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, iw, ih)

    -- Top bar
    local barColors = {6, 7, 15, 19}
    local barH = 2
    for i, ci in ipairs(barColors) do
        Palette.setColor(ci)
        love.graphics.rectangle("fill", 0, (i - 1) * barH, iw, barH)
    end

    local y = #barColors * barH + 4

    -- Title
    local title = "SYSTEM SETTINGS"
    local tw = PixelFont.measure(title)
    local tc = Palette.get(15)
    PixelFont.print(title, math.floor((iw - tw) / 2), y, 1, tc[1], tc[2], tc[3])
    y = y + 12

    -- Divider
    local dc = Palette.get(2)
    for x = 8, iw - 8, 2 do
        love.graphics.setColor(dc[1], dc[2], dc[3], 1)
        love.graphics.rectangle("fill", x, y, 1, 1)
    end
    y = y + 6

    -- Rows
    local rowH = 14
    local rows = {
        { label = "VOLUME",  value = math.floor(data.masterVolume * 100) .. "%" },
        { label = "CRT",     value = Config.CRT_PRESETS[data.crtPreset].label:upper() },
        { label = "PALETTE", value = Palette.VARIANT_NAMES[data.paletteVariant] or "?" },
    }

    for i, row in ipairs(rows) do
        local ry = y + (i - 1) * rowH
        local isSelected = (i == cursor)

        if isSelected then
            local hc = Palette.get(19)
            love.graphics.setColor(hc[1], hc[2], hc[3], 0.15)
            love.graphics.rectangle("fill", 6, ry - 1, iw - 12, rowH - 2)

            local ac = Palette.get(19)
            PixelFont.print(">", 8, ry + 2, 1, ac[1], ac[2], ac[3])
        end

        local lc = isSelected and Palette.get(4) or Palette.get(3)
        PixelFont.print(row.label, 16, ry + 2, 1, lc[1], lc[2], lc[3])

        -- Value on the right side
        local vw = PixelFont.measure(row.value)
        local vc = isSelected and Palette.get(15) or Palette.get(2)
        PixelFont.print(row.value, iw - 10 - vw, ry + 2, 1, vc[1], vc[2], vc[3])

        -- Draw volume bar for first row
        if i == 1 then
            local barX = 50
            local barW = iw - 70 - vw
            local barY = ry + 3
            local fill = math.floor(barW * data.masterVolume)
            love.graphics.setColor(dc[1], dc[2], dc[3], 0.5)
            love.graphics.rectangle("fill", barX, barY, barW, 3)
            local fc = isSelected and Palette.get(19) or Palette.get(18)
            love.graphics.setColor(fc[1], fc[2], fc[3], 1)
            love.graphics.rectangle("fill", barX, barY, fill, 3)
        end
    end

    -- Controls at bottom
    local bottomY = ih - 12
    local cc = Palette.get(2)
    PixelFont.print("[UP/DN] SELECT  [L/R] ADJUST  [ESC] BACK", 8, bottomY, 1, cc[1], cc[2], cc[3])
end

-- ============================================================
-- UI: keypressed
-- ============================================================
function Settings.keypressed(key)
    if key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = NUM_ROWS end
        SFX.play("menuMove")
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > NUM_ROWS then cursor = 1 end
        SFX.play("menuMove")
    elseif key == "left" then
        Settings.adjust(-1)
    elseif key == "right" or key == "return" then
        Settings.adjust(1)
    end
end

function Settings.adjust(dir)
    if cursor == 1 then
        -- Volume: step by 0.05
        data.masterVolume = math.max(0, math.min(1,
            math.floor((data.masterVolume + dir * 0.05) * 20 + 0.5) / 20))
        Music.setVolume(data.masterVolume)
        SFX.setMasterVolume(data.masterVolume)
        SFX.play("menuMove")
    elseif cursor == 2 then
        -- CRT preset: cycle 1..#CRT_PRESETS
        data.crtPreset = data.crtPreset + dir
        if data.crtPreset < 1 then data.crtPreset = #Config.CRT_PRESETS end
        if data.crtPreset > #Config.CRT_PRESETS then data.crtPreset = 1 end
        Config.CRT_INDEX = data.crtPreset
        SFX.play("menuMove")
    elseif cursor == 3 then
        -- Palette variant: cycle 1..VARIANT_COUNT
        data.paletteVariant = data.paletteVariant + dir
        if data.paletteVariant < 1 then data.paletteVariant = Palette.VARIANT_COUNT end
        if data.paletteVariant > Palette.VARIANT_COUNT then data.paletteVariant = 1 end
        Palette.setVariant(data.paletteVariant)
        SFX.play("menuMove")
    end
end

return Settings
