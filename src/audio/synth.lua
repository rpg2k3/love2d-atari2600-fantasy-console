-- src/audio/synth.lua  Wave/noise generator -> SoundData
-- Generates procedural audio for the Atari-2600 style fantasy console.
local Config = require("src.config")

local Synth = {}

local RATE = Config.SAMPLE_RATE
local PI2  = math.pi * 2

-- Waveform generators (return -1..1)
local function waveSine(phase)
    return math.sin(phase * PI2)
end

local function waveSquare(phase)
    return phase < 0.5 and 1 or -1
end

local function waveTriangle(phase)
    return math.abs(phase * 4 - 2) - 1
end

local function waveSaw(phase)
    return 2 * phase - 1
end

local rngState = 1
local function waveNoise()
    -- Simple LFSR-style noise
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return (rngState / 1073741824) - 1
end

local WAVES = {
    sine     = waveSine,
    square   = waveSquare,
    triangle = waveTriangle,
    saw      = waveSaw,
    noise    = waveNoise,
}

-- ADSR envelope (returns 0..1)
local function adsr(t, a, d, s, r, duration)
    if t < a then
        return t / a
    elseif t < a + d then
        return 1 - (1 - s) * ((t - a) / d)
    elseif t < duration - r then
        return s
    elseif t < duration then
        return s * (1 - (t - (duration - r)) / r)
    else
        return 0
    end
end

-- Generate a SoundData
-- params:
--   wave: "sine","square","triangle","saw","noise"
--   freq: base frequency Hz
--   duration: seconds
--   volume: 0..1
--   attack, decay, sustain, release: ADSR (seconds except sustain=level)
--   freqSweep: Hz/sec pitch change
--   vibrato: Hz of vibrato
--   vibratoDepth: Hz
function Synth.generate(params)
    local wave     = WAVES[params.wave or "square"] or waveSquare
    local freq     = params.freq or 440
    local dur      = params.duration or 0.3
    local vol      = params.volume or 0.5
    local att      = params.attack or 0.01
    local dec      = params.decay or 0.05
    local sus      = params.sustain or 0.3
    local rel      = params.release or 0.1
    local sweep    = params.freqSweep or 0
    local vib      = params.vibrato or 0
    local vibD     = params.vibratoDepth or 0
    local isNoise  = (params.wave == "noise")

    local samples  = math.floor(dur * RATE)
    local sd = love.sound.newSoundData(samples, RATE, Config.BIT_DEPTH, 1)

    local phase = 0
    for i = 0, samples - 1 do
        local t = i / RATE
        local env = adsr(t, att, dec, sus, rel, dur)
        local f = freq + sweep * t
        if vib > 0 then
            f = f + math.sin(t * vib * PI2) * vibD
        end
        local val
        if isNoise then
            val = waveNoise()
        else
            val = wave(phase)
        end
        val = val * env * vol
        -- Clamp
        if val > 1 then val = 1 elseif val < -1 then val = -1 end
        sd:setSample(i, val)
        -- Advance phase
        phase = phase + f / RATE
        phase = phase - math.floor(phase)
    end
    return sd
end

-- Quick Source from params
function Synth.newSource(params)
    local sd = Synth.generate(params)
    return love.audio.newSource(sd, "static")
end

return Synth
