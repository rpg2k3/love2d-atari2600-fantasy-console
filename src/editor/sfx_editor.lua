-- src/editor/sfx_editor.lua  Basic parameter editing: wave, freq, envelope, noise
local UI       = require("src.util.ui")
local Video    = require("src.platform.video")
local SFX      = require("src.audio.sfx")
local Input    = require("src.util.input")
local PixelFont = require("src.util.pixelfont")

local SE = {}

local presetNames = {}
local selectedIdx = 1
local params = nil

local WAVES = { "square", "triangle", "saw", "sine", "noise" }
local waveIdx = 1

local function loadPreset()
    presetNames = SFX.getPresetNames()
    if #presetNames == 0 then
        presetNames = {"custom"}
        SFX.setPreset("custom", {
            wave = "square", freq = 440, duration = 0.3, volume = 0.5,
            attack = 0.01, decay = 0.05, sustain = 0.3, release = 0.1,
            freqSweep = 0,
        })
    end
    if selectedIdx > #presetNames then selectedIdx = #presetNames end
    params = {}
    local p = SFX.getPreset(presetNames[selectedIdx])
    if p then
        for k, v in pairs(p) do params[k] = v end
    end
    -- Find wave index
    for i, w in ipairs(WAVES) do
        if w == params.wave then waveIdx = i; break end
    end
end

function SE.init()
    loadPreset()
end

function SE.update(dt) end

function SE.draw(yOff)
    local iw = Video.getInternalWidth()
    yOff = yOff or 10
    if not params then loadPreset() end

    local x = 2
    local y = yOff + 1

    -- Preset selector
    UI.text("SFX: " .. string.upper(presetNames[selectedIdx] or "?"), x, y, UI.COL_HI)
    if UI.button("<", x + 60, y - 1, 10, 8) then
        selectedIdx = math.max(1, selectedIdx - 1)
        loadPreset()
    end
    if UI.button(">", x + 72, y - 1, 10, 8) then
        selectedIdx = math.min(#presetNames, selectedIdx + 1)
        loadPreset()
    end
    y = y + 10

    -- Wave selector
    UI.text("WAVE: " .. string.upper(WAVES[waveIdx]), x, y, UI.COL_TEXT)
    if UI.button("<", x + 60, y - 1, 10, 8) then
        waveIdx = ((waveIdx - 2) % #WAVES) + 1
        params.wave = WAVES[waveIdx]
    end
    if UI.button(">", x + 72, y - 1, 10, 8) then
        waveIdx = (waveIdx % #WAVES) + 1
        params.wave = WAVES[waveIdx]
    end
    y = y + 10

    -- Sliders
    local sliderW = math.min(80, iw - 50)
    local function drawSlider(label, key, lo, hi)
        UI.text(label, x, y, UI.COL_TEXT)
        local norm = ((params[key] or lo) - lo) / (hi - lo)
        norm = UI.slider(x + 38, y + 1, sliderW, norm)
        params[key] = lo + norm * (hi - lo)
        local valStr = string.format("%.0f", params[key])
        if hi <= 1 then valStr = string.format("%.2f", params[key]) end
        UI.text(valStr, x + 40 + sliderW, y, UI.COL_TEXT)
        y = y + 9
    end

    drawSlider("FREQ",  "freq",      20, 2000)
    drawSlider("DUR",   "duration",  0.05, 2.0)
    drawSlider("VOL",   "volume",    0, 1)
    drawSlider("ATK",   "attack",    0, 0.5)
    drawSlider("DEC",   "decay",     0, 0.5)
    drawSlider("SUS",   "sustain",   0, 1)
    drawSlider("REL",   "release",   0, 1)
    drawSlider("SWEEP", "freqSweep", -2000, 2000)

    -- Play button
    y = y + 2
    if UI.button("PLAY", x, y, 24, 10, UI.COL_ACTIVE) then
        SFX.setPreset(presetNames[selectedIdx], params)
        SFX.play(presetNames[selectedIdx])
    end
    UI.text("SPACE=PLAY", x + 30, y + 2, 3)
end

function SE.keypressed(key)
    if key == "space" then
        SFX.setPreset(presetNames[selectedIdx], params)
        SFX.play(presetNames[selectedIdx])
    end
end

return SE
