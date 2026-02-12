-- src/audio/music.lua  Multi-channel chiptune music engine (2-3 channels)
-- Backward-compatible: old single-channel patterns still work on channel 1
local Synth  = require("src.audio.synth")
local Config = require("src.config")

local Music = {}

---------------------------------------------------------------------------
-- Note frequency table (octaves 0-7, C to B)
---------------------------------------------------------------------------
local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local noteFreqs = {}
for oct = 0, 7 do
    for i, name in ipairs(NOTE_NAMES) do
        local midi = (oct + 1) * 12 + (i - 1)
        local freq = 440 * 2^((midi - 69) / 12)
        -- Support both "C-4" and "C4" formats
        noteFreqs[name .. "-" .. oct] = freq
        noteFreqs[name .. oct] = freq
    end
end

Music.noteFreqs   = noteFreqs
Music.NOTE_NAMES  = NOTE_NAMES
Music.NUM_CHANNELS = 3

function Music.noteToFreq(note)
    return noteFreqs[note] or 440
end

---------------------------------------------------------------------------
-- Default instruments
---------------------------------------------------------------------------
local DEFAULT_INSTRUMENTS = {
    [1] = { wave="square",   attack=0.01, decay=0.1, sustain=0.6, release=0.2, volume=0.3 },
    [2] = { wave="triangle", attack=0.01, decay=0.1, sustain=0.5, release=0.2, volume=0.3 },
    [3] = { wave="saw",      attack=0.01, decay=0.08,sustain=0.4, release=0.15,volume=0.25},
    [4] = { wave="noise",    attack=0.005,decay=0.1, sustain=0.2, release=0.1, volume=0.2 },
}

---------------------------------------------------------------------------
-- Song state
---------------------------------------------------------------------------
local song = {
    bpm         = 120,
    speed       = 4,        -- steps per beat
    instruments = {},
    patterns    = {},       -- patterns[id] = { channels = { [ch] = { step1, step2, ... } } }
    order       = {},       -- ordered list of pattern IDs
}

-- Deep-copy default instruments
for k, v in pairs(DEFAULT_INSTRUMENTS) do
    song.instruments[k] = {}
    for kk, vv in pairs(v) do song.instruments[k][kk] = vv end
end

---------------------------------------------------------------------------
-- Playback state
---------------------------------------------------------------------------
local playing         = false
local currentOrderIdx = 1
local currentStep     = 1
local stepTimer       = 0
local channelSources  = {}  -- [ch] = love.audio.Source
local masterVolume    = 1.0
local loopPattern     = false  -- if true, loop current pattern only
local lastUpdateTime  = -1    -- prevent double-update in same frame

---------------------------------------------------------------------------
-- Legacy pattern storage (backward compat)
---------------------------------------------------------------------------
local legacyPatterns = {}
local legacySong     = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getStepDuration()
    local bpm   = song.bpm or 120
    local speed = song.speed or 4
    return 60 / bpm / speed
end

local function getInstrument(id)
    return song.instruments[id] or song.instruments[1] or DEFAULT_INSTRUMENTS[1]
end

local function getPatternStepCount(patId)
    local pat = song.patterns[patId]
    if not pat or not pat.channels then return 16 end
    local maxLen = 0
    for ch = 1, Music.NUM_CHANNELS do
        local track = pat.channels[ch]
        if track then
            if #track > maxLen then maxLen = #track end
        end
    end
    return maxLen > 0 and maxLen or 16
end

---------------------------------------------------------------------------
-- Pattern management
---------------------------------------------------------------------------
function Music.getPattern(id)
    return song.patterns[id]
end

function Music.ensurePattern(id)
    if not song.patterns[id] then
        local channels = {}
        for ch = 1, Music.NUM_CHANNELS do
            channels[ch] = {}
            for s = 1, 16 do
                channels[ch][s] = false  -- rest
            end
        end
        song.patterns[id] = { channels = channels }
    end
    return song.patterns[id]
end

function Music.getAllPatternIds()
    local ids = {}
    for id in pairs(song.patterns) do ids[#ids+1] = id end
    table.sort(ids)
    return ids
end

---------------------------------------------------------------------------
-- Song accessors / mutators
---------------------------------------------------------------------------
function Music.getSong()
    return song
end

function Music.getBPM()        return song.bpm or 120 end
function Music.getSpeed()      return song.speed or 4 end
function Music.getOrder()      return song.order end
function Music.getInstruments() return song.instruments end
function Music.getInstrument(id) return getInstrument(id) end

function Music.setBPM(v)   song.bpm   = math.max(40, math.min(300, v)) end
function Music.setSpeed(v) song.speed = math.max(1, math.min(16, v)) end

function Music.setOrder(orderTable)
    song.order = orderTable or {}
end

function Music.setInstrument(id, inst)
    song.instruments[id] = inst
end

function Music.ensureInstrument(id)
    if not song.instruments[id] then
        local base = DEFAULT_INSTRUMENTS[((id - 1) % #DEFAULT_INSTRUMENTS) + 1]
        song.instruments[id] = {}
        for k, v in pairs(base) do song.instruments[id][k] = v end
    end
    return song.instruments[id]
end

---------------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------------
function Music.play(fromOrder)
    playing         = true
    currentOrderIdx = fromOrder or 1
    currentStep     = 1
    stepTimer       = 0
end

function Music.stop()
    playing = false
    for ch = 1, Music.NUM_CHANNELS do
        if channelSources[ch] then
            channelSources[ch]:stop()
            channelSources[ch] = nil
        end
    end
end

function Music.isPlaying()
    return playing
end

---------------------------------------------------------------------------
-- Pause / Resume (for global pause system)
---------------------------------------------------------------------------
local paused = false

function Music.pause()
    if not playing or paused then return end
    paused = true
    -- Silence active channel sources without losing playback position
    for ch = 1, Music.NUM_CHANNELS do
        if channelSources[ch] then
            channelSources[ch]:stop()
        end
    end
end

function Music.resume()
    paused = false
end

function Music.isPaused()
    return paused
end

function Music.setVolume(v)
    masterVolume = math.max(0, math.min(1, v))
end

function Music.getVolume()
    return masterVolume
end

function Music.setLoopPattern(v)
    loopPattern = v
end

function Music.getCurrentStep()
    return currentStep
end

function Music.getCurrentOrderIdx()
    return currentOrderIdx
end

function Music.update(dt)
    if not playing or paused then return end

    -- Guard against double-update in the same frame (cart + app both calling)
    local t = love.timer.getTime()
    if t == lastUpdateTime then return end
    lastUpdateTime = t

    local order = song.order
    if not order or #order == 0 then
        playing = false
        return
    end

    if currentOrderIdx > #order then
        currentOrderIdx = 1  -- loop song
    end

    local patId = order[currentOrderIdx]
    local pat   = song.patterns[patId]
    if not pat then
        playing = false
        return
    end

    local stepDur = getStepDuration()
    stepTimer = stepTimer + dt

    if stepTimer >= stepDur then
        stepTimer = stepTimer - stepDur

        -- Play notes on each channel
        local channels = pat.channels or {}
        for ch = 1, Music.NUM_CHANNELS do
            local track = channels[ch]
            if track then
                local cell = track[currentStep]
                if cell and type(cell) == "table" and cell[1] then
                    local noteName = cell[1]
                    local instId   = cell[2] or 1
                    local inst     = getInstrument(instId)
                    local freq     = Music.noteToFreq(noteName)
                    local vol      = (inst.volume or 0.3) * masterVolume

                    local sd = Synth.generate({
                        wave     = inst.wave or "square",
                        freq     = freq,
                        duration = stepDur * 0.9,
                        volume   = vol,
                        attack   = inst.attack  or 0.01,
                        decay    = inst.decay   or 0.05,
                        sustain  = inst.sustain  or 0.4,
                        release  = inst.release  or 0.1,
                    })
                    if channelSources[ch] then
                        channelSources[ch]:stop()
                    end
                    channelSources[ch] = love.audio.newSource(sd, "static")
                    channelSources[ch]:play()
                end
                -- nil / false = rest (don't stop previous note, just skip)
            end
        end

        -- Advance step
        local stepCount = getPatternStepCount(patId)
        currentStep = currentStep + 1
        if currentStep > stepCount then
            currentStep = 1
            if not loopPattern then
                currentOrderIdx = currentOrderIdx + 1
                if currentOrderIdx > #order then
                    currentOrderIdx = 1  -- loop whole song
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Legacy API (backward compatible)
-- Old format: patterns[id] = { steps={...}, bpm=120, stepsPerBeat=4 }
-- Converted to new multi-channel format on import
---------------------------------------------------------------------------
function Music.definePattern(id, data)
    -- Store legacy format
    legacyPatterns[id] = data

    -- Convert to new format: old steps go to channel 1
    local channels = {}
    for ch = 1, Music.NUM_CHANNELS do
        channels[ch] = {}
    end

    if data.steps then
        for i, step in ipairs(data.steps) do
            if step and step.note then
                -- Map old wave names to instrument IDs
                local instId = 1
                if step.wave == "triangle" then instId = 2
                elseif step.wave == "saw" then instId = 3
                elseif step.wave == "noise" then instId = 4 end
                channels[1][i] = { step.note, instId }
            else
                channels[1][i] = false
            end
            -- Fill other channels with rests
            for ch = 2, Music.NUM_CHANNELS do
                channels[ch][i] = false
            end
        end
    end

    song.patterns[id] = { channels = channels }

    -- Update BPM/speed from legacy pattern
    if data.bpm then song.bpm = data.bpm end
    if data.stepsPerBeat then song.speed = data.stepsPerBeat end
end

function Music.setSong(patternIds)
    song.order = patternIds or {}
    legacySong = patternIds or {}
end

---------------------------------------------------------------------------
-- Runtime API for cartridges
---------------------------------------------------------------------------
function Music.loadSong(songTable)
    if not songTable then return end
    if songTable.bpm then song.bpm = songTable.bpm end
    if songTable.speed then song.speed = songTable.speed end
    if songTable.instruments then
        song.instruments = songTable.instruments
    end
    if songTable.patterns then
        song.patterns = songTable.patterns
    end
    if songTable.order then
        song.order = songTable.order
    end
end

---------------------------------------------------------------------------
-- Export / import (save-safe, backward compatible)
---------------------------------------------------------------------------
function Music.export()
    return {
        bpm         = song.bpm,
        speed       = song.speed,
        instruments = song.instruments,
        patterns    = song.patterns,
        order       = song.order,
        -- Keep legacy fields for old carts
        _legacy_patterns = legacyPatterns,
        _legacy_song     = legacySong,
    }
end

function Music.import(data)
    if not data then return end

    -- New format
    if data.bpm then song.bpm = data.bpm end
    if data.speed then song.speed = data.speed end
    if data.instruments then song.instruments = data.instruments end
    if data.order then song.order = data.order end

    if data.patterns then
        -- Check if new format (has channels) or old format (has steps)
        local isNewFormat = false
        for _, pat in pairs(data.patterns) do
            if pat.channels then
                isNewFormat = true
                break
            end
        end

        if isNewFormat then
            song.patterns = data.patterns
        else
            -- Old format: convert each pattern
            for id, pat in pairs(data.patterns) do
                Music.definePattern(id, pat)
            end
        end
    end

    -- Restore legacy data if present
    if data._legacy_patterns then legacyPatterns = data._legacy_patterns end
    if data._legacy_song then legacySong = data._legacy_song end

    -- Old-style import: { patterns = {id={steps=..}}, song = {1,2} }
    if data.song and not data.order then
        song.order = data.song
    end
end

return Music
