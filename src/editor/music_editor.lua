-- src/editor/music_editor.lua  Minimal tracker-style pattern editor
local UI       = require("src.util.ui")
local Video    = require("src.platform.video")
local Music    = require("src.audio.music")
local Input    = require("src.util.input")
local PixelFont = require("src.util.pixelfont")

local ME = {}

local NOTES = Music.NOTE_NAMES
local currentPatternId = 1
local cursorStep = 1
local cursorField = 1  -- 1=note, 2=octave, 3=wave
local WAVES = { "square", "triangle", "saw", "sine" }
local octave = 4
local noteIdx = 1
local waveIdx = 1
local scrollY = 0

local function ensurePattern()
    local pat = Music.getPattern(currentPatternId)
    if not pat then
        local steps = {}
        for i = 1, 16 do
            steps[i] = false  -- rest
        end
        Music.definePattern(currentPatternId, {
            steps = steps,
            bpm = 120,
            stepsPerBeat = 4,
        })
        Music.setSong({ currentPatternId })
    end
end

function ME.init()
    ensurePattern()
end

function ME.update(dt) end

function ME.draw(yOff)
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    yOff = yOff or 10

    ensurePattern()
    local pat = Music.getPattern(currentPatternId)
    local x = 2
    local y = yOff + 1

    -- Header
    UI.text("PAT #" .. currentPatternId, x, y, UI.COL_HI)
    local bpmStr = "BPM:" .. (pat.bpm or 120)
    UI.text(bpmStr, x + 40, y, UI.COL_TEXT)

    if UI.button("PLAY", iw - 30, y - 1, 24, 8, UI.COL_ACTIVE) then
        Music.setSong({ currentPatternId })
        Music.play()
    end
    if UI.button("STOP", iw - 58, y - 1, 24, 8, 5) then
        Music.stop()
    end

    y = y + 10

    -- Step grid
    local stepH = 7
    local maxVisible = math.floor((ih - y - 10) / stepH)
    local totalSteps = #pat.steps

    -- Adjust scroll
    if cursorStep - scrollY > maxVisible then scrollY = cursorStep - maxVisible end
    if cursorStep - scrollY < 1 then scrollY = cursorStep - 1 end

    -- Column headers
    UI.text("# NOTE OCT WAV", x, y, 3)
    y = y + 8

    for i = 1, math.min(maxVisible, totalSteps) do
        local si = i + scrollY
        if si > totalSteps then break end
        local step = pat.steps[si]
        local isCursor = (si == cursorStep)

        -- Highlight current step
        if isCursor then
            UI.rect(x, y, iw - 4, stepH, 25)
        end

        -- Step number
        local numStr = string.format("%02d", si)
        UI.text(numStr, x, y + 1, isCursor and UI.COL_HI or 3)

        if step and step.note then
            -- Parse note name (e.g. "C4" -> note="C", oct=4)
            local notePart = step.note:match("^(.-)%d")
            local octPart  = step.note:match("%d$")
            UI.text(notePart or "?", x + 14, y + 1, UI.COL_TEXT)
            UI.text(octPart or "?", x + 30, y + 1, UI.COL_TEXT)
            UI.text(string.sub(step.wave or "SQ", 1, 3), x + 42, y + 1, UI.COL_TEXT)
        else
            UI.text("---", x + 14, y + 1, 2)
        end

        y = y + stepH
    end

    -- Instructions
    UI.text("UP/DN:NAV  L/R:FIELD", 2, ih - 14, 3)
    UI.text("Z:SET  X:DEL  +/-:BPM", 2, ih - 7, 3)
end

function ME.keypressed(key)
    ensurePattern()
    local pat = Music.getPattern(currentPatternId)
    local totalSteps = #pat.steps

    if key == "up" then
        cursorStep = math.max(1, cursorStep - 1)
    elseif key == "down" then
        cursorStep = math.min(totalSteps, cursorStep + 1)
    elseif key == "left" then
        if cursorField == 1 then
            noteIdx = ((noteIdx - 2) % #NOTES) + 1
        elseif cursorField == 2 then
            octave = math.max(2, octave - 1)
        elseif cursorField == 3 then
            waveIdx = ((waveIdx - 2) % #WAVES) + 1
        end
    elseif key == "right" then
        if cursorField == 1 then
            noteIdx = (noteIdx % #NOTES) + 1
        elseif cursorField == 2 then
            octave = math.min(6, octave + 1)
        elseif cursorField == 3 then
            waveIdx = (waveIdx % #WAVES) + 1
        end
    elseif key == "tab" then
        cursorField = (cursorField % 3) + 1
    elseif key == "z" or key == "return" then
        -- Set note at cursor
        local noteName = NOTES[noteIdx] .. octave
        pat.steps[cursorStep] = {
            note = noteName,
            wave = WAVES[waveIdx],
            duration = 0.15,
            volume = 0.3,
        }
    elseif key == "x" or key == "delete" then
        pat.steps[cursorStep] = false
    elseif key == "=" or key == "kp+" then
        pat.bpm = math.min(300, (pat.bpm or 120) + 5)
    elseif key == "-" or key == "kp-" then
        pat.bpm = math.max(40, (pat.bpm or 120) - 5)
    elseif key == "space" then
        if Music.isPlaying() then
            Music.stop()
        else
            Music.setSong({ currentPatternId })
            Music.play()
        end
    end
end

return ME
