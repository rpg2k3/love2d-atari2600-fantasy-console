-- src/audio/sfx.lua  SFX presets + play
local Synth = require("src.audio.synth")

local SFX = {}

-- Cache of generated sources
local cache = {}

-- SFX preset definitions
SFX.presets = {
    jump = {
        wave = "square", freq = 200, duration = 0.2, volume = 0.4,
        attack = 0.01, decay = 0.05, sustain = 0.2, release = 0.1,
        freqSweep = 600,
    },
    hit = {
        wave = "noise", freq = 100, duration = 0.15, volume = 0.5,
        attack = 0.005, decay = 0.05, sustain = 0.3, release = 0.05,
        freqSweep = -200,
    },
    coin = {
        wave = "square", freq = 600, duration = 0.15, volume = 0.35,
        attack = 0.005, decay = 0.02, sustain = 0.4, release = 0.05,
        freqSweep = 400,
    },
    menuMove = {
        wave = "triangle", freq = 300, duration = 0.08, volume = 0.3,
        attack = 0.005, decay = 0.02, sustain = 0.2, release = 0.03,
        freqSweep = 100,
    },
    menuSelect = {
        wave = "square", freq = 500, duration = 0.12, volume = 0.35,
        attack = 0.005, decay = 0.03, sustain = 0.3, release = 0.05,
        freqSweep = 200,
    },
    explosion = {
        wave = "noise", freq = 80, duration = 0.5, volume = 0.6,
        attack = 0.01, decay = 0.1, sustain = 0.4, release = 0.3,
        freqSweep = -60,
    },
}

-- Build and cache a source for a preset
local function getSource(name)
    if cache[name] then return cache[name] end
    local p = SFX.presets[name]
    if not p then return nil end
    local src = Synth.newSource(p)
    cache[name] = src
    return src
end

-- Play a preset SFX
function SFX.play(name)
    local src = getSource(name)
    if not src then return end
    src:stop()
    src:play()
end

-- Play from custom params (not cached)
function SFX.playCustom(params)
    local src = Synth.newSource(params)
    src:play()
    return src
end

-- Clear cache (e.g. after editing SFX params)
function SFX.clearCache()
    for k in pairs(cache) do cache[k] = nil end
end

-- Get preset params (for editor)
function SFX.getPreset(name)
    return SFX.presets[name]
end

-- Set/update a preset
function SFX.setPreset(name, params)
    SFX.presets[name] = params
    cache[name] = nil  -- invalidate cache
end

-- List all preset names
function SFX.getPresetNames()
    local names = {}
    for k in pairs(SFX.presets) do names[#names+1] = k end
    table.sort(names)
    return names
end

return SFX
