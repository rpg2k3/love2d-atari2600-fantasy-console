-- src/audio/music.lua  Simple chiptune step sequencer (1 channel, expandable to 2-3)
local Synth  = require("src.audio.synth")
local Config = require("src.config")

local Music = {}

-- Note frequency table (octaves 2-6, C to B)
local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local noteFreqs = {}
for oct = 2, 6 do
    for i, name in ipairs(NOTE_NAMES) do
        local midi = (oct + 1) * 12 + (i - 1)
        local freq = 440 * 2^((midi - 69) / 12)
        noteFreqs[name .. oct] = freq
    end
end

Music.noteFreqs = noteFreqs
Music.NOTE_NAMES = NOTE_NAMES

function Music.noteToFreq(note)
    return noteFreqs[note] or 440
end

-- Pattern: array of steps, each step = { note="C4", wave="square", duration=0.15 } or nil/false for rest
-- A song is a list of pattern indices + a pattern bank

local patterns = {}    -- patterns[id] = { steps = {...}, bpm = 120, stepsPerBeat = 4 }
local song = {}        -- ordered list of pattern IDs
local playing = false
local currentPattern = 1
local currentStep = 1
local stepTimer = 0
local currentSource = nil

function Music.definePattern(id, data)
    patterns[id] = data
end

function Music.setSong(patternIds)
    song = patternIds
end

function Music.play()
    playing = true
    currentPattern = 1
    currentStep = 1
    stepTimer = 0
end

function Music.stop()
    playing = false
    if currentSource then
        currentSource:stop()
        currentSource = nil
    end
end

function Music.isPlaying()
    return playing
end

function Music.update(dt)
    if not playing then return end
    if #song == 0 then return end

    local patId = song[currentPattern]
    local pat = patterns[patId]
    if not pat then
        playing = false
        return
    end

    local bpm = pat.bpm or 120
    local spb = pat.stepsPerBeat or 4
    local stepDur = 60 / bpm / spb

    stepTimer = stepTimer + dt
    if stepTimer >= stepDur then
        stepTimer = stepTimer - stepDur

        -- Play current step
        local step = pat.steps[currentStep]
        if step and step.note then
            local freq = Music.noteToFreq(step.note)
            local sd = Synth.generate({
                wave = step.wave or "square",
                freq = freq,
                duration = step.duration or (stepDur * 0.9),
                volume = step.volume or 0.3,
                attack = 0.005,
                decay = 0.02,
                sustain = 0.4,
                release = 0.05,
            })
            if currentSource then currentSource:stop() end
            currentSource = love.audio.newSource(sd, "static")
            currentSource:play()
        end

        -- Advance step
        currentStep = currentStep + 1
        if currentStep > #pat.steps then
            currentStep = 1
            currentPattern = currentPattern + 1
            if currentPattern > #song then
                currentPattern = 1  -- loop
            end
        end
    end
end

-- Get pattern data
function Music.getPattern(id)
    return patterns[id]
end

function Music.getAllPatternIds()
    local ids = {}
    for id in pairs(patterns) do ids[#ids+1] = id end
    table.sort(ids)
    return ids
end

-- Export/import for serialization
function Music.export()
    return { patterns = patterns, song = song }
end

function Music.import(data)
    if data.patterns then patterns = data.patterns end
    if data.song then song = data.song end
end

return Music
