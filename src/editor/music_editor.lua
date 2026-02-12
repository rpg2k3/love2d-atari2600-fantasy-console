-- src/editor/music_editor.lua  Tracker-style multi-channel music editor
local UI        = require("src.util.ui")
local Video     = require("src.platform.video")
local Music     = require("src.audio.music")
local Input     = require("src.util.input")
local PixelFont = require("src.util.pixelfont")
local Config    = require("src.config")

local ME = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local NOTES       = Music.NOTE_NAMES  -- {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local WAVES       = { "square", "triangle", "saw", "noise" }
local WAVE_SHORT  = { square="SQ", triangle="TR", saw="SW", noise="NS" }
local NUM_CH      = Music.NUM_CHANNELS  -- 3
local MAX_STEPS   = 32
local ROW_H       = 7
local MAX_UNDO    = Config.MAX_UNDO or 40

---------------------------------------------------------------------------
-- Editor modes
---------------------------------------------------------------------------
local MODE_PATTERN    = "pattern"
local MODE_INSTRUMENT = "instrument"
local MODE_ORDER      = "order"

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local mode            = MODE_PATTERN
local currentPatId    = 1
local cursorRow       = 1
local cursorCol       = 1   -- 1..NUM_CH  (which channel column)
local scrollY         = 0

-- Note input state
local inputNote       = 1   -- index into NOTES
local inputOctave     = 4
local inputInstrument = 1

-- Instrument editor state
local instSlot        = 1
local instWaveIdx     = 1

-- Order editor state
local orderCursor     = 1

-- Undo / Redo stacks
local undoStack = {}
local redoStack = {}

---------------------------------------------------------------------------
-- Undo / Redo helpers
---------------------------------------------------------------------------
local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepcopy(v) end
    return r
end

local function pushUndo(tag)
    local pat = Music.getPattern(currentPatId)
    if not pat then return end
    local snapshot = {
        tag        = tag or "edit",
        patId      = currentPatId,
        channels   = deepcopy(pat.channels),
        instruments = deepcopy(Music.getInstruments()),
        order      = deepcopy(Music.getOrder()),
        bpm        = Music.getBPM(),
        speed      = Music.getSpeed(),
    }
    undoStack[#undoStack + 1] = snapshot
    if #undoStack > MAX_UNDO then
        table.remove(undoStack, 1)
    end
    -- Clear redo on new action
    redoStack = {}
end

local function restoreSnapshot(snap)
    if snap.channels then
        local pat = Music.ensurePattern(snap.patId)
        pat.channels = snap.channels
    end
    if snap.instruments then
        local song = Music.getSong()
        song.instruments = snap.instruments
    end
    if snap.order then
        Music.setOrder(snap.order)
    end
    if snap.bpm then Music.setBPM(snap.bpm) end
    if snap.speed then Music.setSpeed(snap.speed) end
end

local function doUndo()
    if #undoStack == 0 then return end
    -- Save current state to redo
    local pat = Music.getPattern(currentPatId)
    if pat then
        redoStack[#redoStack + 1] = {
            patId      = currentPatId,
            channels   = deepcopy(pat.channels),
            instruments = deepcopy(Music.getInstruments()),
            order      = deepcopy(Music.getOrder()),
            bpm        = Music.getBPM(),
            speed      = Music.getSpeed(),
        }
    end
    local snap = table.remove(undoStack)
    restoreSnapshot(snap)
end

local function doRedo()
    if #redoStack == 0 then return end
    -- Save current to undo
    local pat = Music.getPattern(currentPatId)
    if pat then
        undoStack[#undoStack + 1] = {
            patId      = currentPatId,
            channels   = deepcopy(pat.channels),
            instruments = deepcopy(Music.getInstruments()),
            order      = deepcopy(Music.getOrder()),
            bpm        = Music.getBPM(),
            speed      = Music.getSpeed(),
        }
    end
    local snap = table.remove(redoStack)
    restoreSnapshot(snap)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getTrackLen(patId)
    local pat = Music.getPattern(patId)
    if not pat or not pat.channels then return 16 end
    local maxLen = 0
    for ch = 1, NUM_CH do
        local t = pat.channels[ch]
        if t and #t > maxLen then maxLen = #t end
    end
    return maxLen > 0 and maxLen or 16
end

local function ensureTrackLen(patId, len)
    local pat = Music.ensurePattern(patId)
    for ch = 1, NUM_CH do
        if not pat.channels[ch] then pat.channels[ch] = {} end
        while #pat.channels[ch] < len do
            pat.channels[ch][#pat.channels[ch] + 1] = false
        end
    end
end

local function formatNote(cell)
    if not cell or type(cell) ~= "table" or not cell[1] then
        return "---", "-"
    end
    return cell[1], tostring(cell[2] or 1)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function ME.init()
    Music.ensurePattern(1)
    ensureTrackLen(1, 16)
    if #Music.getOrder() == 0 then
        Music.setOrder({1})
    end
    Music.ensureInstrument(1)
    Music.ensureInstrument(2)
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------
function ME.update(dt) end

---------------------------------------------------------------------------
-- Draw: Pattern mode
---------------------------------------------------------------------------
local function drawPatternMode(yOff, iw, ih)
    local pat = Music.ensurePattern(currentPatId)
    local x = 2
    local y = yOff

    -- Header row: pattern # + BPM + SPD
    UI.text("P:" .. currentPatId, x, y, UI.COL_HI)
    UI.text("BPM:" .. Music.getBPM(), x + 24, y, UI.COL_TEXT)
    UI.text("SPD:" .. Music.getSpeed(), x + 56, y, UI.COL_TEXT)

    -- Play/stop buttons
    if UI.button(">>", iw - 16, y - 1, 14, 8, UI.COL_ACTIVE) then
        Music.setLoopPattern(true)
        Music.setSong(Music.getOrder())
        -- Find which order index has our pattern
        local oi = 1
        for i, pid in ipairs(Music.getOrder()) do
            if pid == currentPatId then oi = i; break end
        end
        Music.play(oi)
    end
    if UI.button("[]", iw - 32, y - 1, 14, 8, 5) then
        Music.stop()
        Music.setLoopPattern(false)
    end

    y = y + 9

    -- Channel headers
    local colW = math.floor((iw - 14) / NUM_CH)
    UI.text("##", x, y, 3)
    for ch = 1, NUM_CH do
        local cx = 14 + (ch - 1) * colW
        local label = "CH" .. ch
        local col = (ch == cursorCol) and UI.COL_HI or 3
        UI.text(label, cx, y, col)
    end
    y = y + 7

    -- Pattern grid
    local trackLen   = getTrackLen(currentPatId)
    local maxVisible = math.floor((ih - y - 16) / ROW_H)

    -- Auto-scroll
    if cursorRow - scrollY > maxVisible then scrollY = cursorRow - maxVisible end
    if cursorRow - scrollY < 1 then scrollY = cursorRow - 1 end

    local playStep = Music.isPlaying() and Music.getCurrentStep() or -1

    for vi = 1, math.min(maxVisible, trackLen) do
        local si = vi + scrollY
        if si > trackLen then break end

        local ry = y + (vi - 1) * ROW_H
        local isCursorRow = (si == cursorRow)

        -- Playing highlight
        if si == playStep and Music.isPlaying() then
            UI.rect(x, ry, iw - 4, ROW_H, 25)
        end

        -- Row number
        local numCol = isCursorRow and UI.COL_HI or 3
        UI.text(string.format("%02d", si), x, ry + 1, numCol)

        -- Channel cells
        for ch = 1, NUM_CH do
            local cx = 14 + (ch - 1) * colW
            local track = pat.channels[ch]
            local cell  = track and track[si]
            local isCursorCell = (isCursorRow and ch == cursorCol)

            -- Cursor highlight
            if isCursorCell then
                UI.rect(cx - 1, ry, colW - 1, ROW_H, 26)
            end

            local noteStr, instStr = formatNote(cell)
            local noteCol = UI.COL_TEXT
            if noteStr == "---" then noteCol = 2 end
            if isCursorCell then noteCol = UI.COL_HI end

            -- Compact display: "C-4:1" or "---:-"
            local display = noteStr .. ":" .. instStr
            -- Truncate to fit column
            if #display > 6 then display = display:sub(1, 6) end
            UI.text(display, cx, ry + 1, noteCol)
        end
    end

    -- Input status bar (shows what note will be placed)
    local statusY = ih - 22
    local curNote = NOTES[inputNote] .. "-" .. inputOctave
    UI.rect(0, statusY, iw, 8, UI.COL_PANEL)
    UI.text("NOTE:" .. curNote, 2, statusY + 1, UI.COL_HI)
    UI.text("I:" .. inputInstrument, 52, statusY + 1, UI.COL_ACTIVE)
    UI.text("OCT:" .. inputOctave, 72, statusY + 1, UI.COL_TEXT)

    -- Footer help
    local fy = ih - 14
    UI.text("I:INST O:ORD TAB:CH", 2, fy, 3)
    UI.text("RET:SET DEL:CLR ^Z/Y", 2, fy + 7, 3)
end

---------------------------------------------------------------------------
-- Draw: Instrument mode
---------------------------------------------------------------------------
local function drawInstrumentMode(yOff, iw, ih)
    local x = 2
    local y = yOff

    UI.text("INSTRUMENTS", x, y, UI.COL_HI)
    y = y + 9

    -- Instrument slot selector
    instSlot = UI.spinner("SLOT", x, y, instSlot, 1, 8, 1, 24)
    y = y + 10

    local inst = Music.ensureInstrument(instSlot)

    -- Waveform cycler
    local wIdx = 1
    for i, w in ipairs(WAVES) do
        if w == inst.wave then wIdx = i; break end
    end
    local newWIdx = UI.cycler("WAVE", x, y, WAVES, wIdx, 28)
    if newWIdx ~= wIdx then
        pushUndo("inst_wave")
        inst.wave = WAVES[newWIdx]
    end
    y = y + 10

    -- ADSR sliders
    local function adsrSlider(label, key, yy)
        UI.text(label, x, yy + 1, UI.COL_TEXT)
        local val = inst[key] or 0
        -- Map to 0..1 range (max 2 seconds for A/D/R, 0..1 for S)
        local maxVal = (key == "sustain") and 1.0 or 2.0
        local norm = val / maxVal
        local newNorm = UI.slider(x + 22, yy, iw - 28, norm, UI.COL_BUTTON)
        local newVal = newNorm * maxVal
        -- Quantize to 0.01
        newVal = math.floor(newVal * 100 + 0.5) / 100
        if math.abs(newVal - val) > 0.005 then
            pushUndo("inst_" .. key)
            inst[key] = newVal
        end
        -- Display value
        UI.text(string.format("%.2f", inst[key]), iw - 24, yy + 1, UI.COL_HI)
        return yy + 9
    end

    y = adsrSlider("ATK", "attack", y)
    y = adsrSlider("DEC", "decay", y)
    y = adsrSlider("SUS", "sustain", y)
    y = adsrSlider("REL", "release", y)

    -- Volume slider
    UI.text("VOL", x, y + 1, UI.COL_TEXT)
    local vol = inst.volume or 0.3
    local newVol = UI.slider(x + 22, y, iw - 28, vol, UI.COL_ACTIVE)
    newVol = math.floor(newVol * 100 + 0.5) / 100
    if math.abs(newVol - vol) > 0.005 then
        pushUndo("inst_vol")
        inst.volume = newVol
    end
    UI.text(string.format("%.2f", inst.volume), iw - 24, y + 1, UI.COL_HI)
    y = y + 12

    -- Test play button
    if UI.button("TEST", x, y, 28, 9, UI.COL_ACTIVE) then
        local Synth = require("src.audio.synth")
        local freq = Music.noteToFreq("C-4")
        local sd = Synth.generate({
            wave    = inst.wave,
            freq    = freq,
            duration = 0.5,
            volume  = inst.volume or 0.3,
            attack  = inst.attack or 0.01,
            decay   = inst.decay or 0.05,
            sustain = inst.sustain or 0.4,
            release = inst.release or 0.1,
        })
        local src = love.audio.newSource(sd, "static")
        src:play()
    end

    -- Footer
    UI.text("ESC:BACK TO PATTERN", 2, ih - 7, 3)
end

---------------------------------------------------------------------------
-- Draw: Order mode
---------------------------------------------------------------------------
local function drawOrderMode(yOff, iw, ih)
    local x = 2
    local y = yOff

    UI.text("SONG ORDER", x, y, UI.COL_HI)
    y = y + 9

    local order = Music.getOrder()

    if #order == 0 then
        UI.text("(EMPTY)", x, y, 2)
        y = y + 8
    else
        for i, pid in ipairs(order) do
            local isCursor = (i == orderCursor)
            if isCursor then
                UI.rect(x, y, iw - 4, 8, 26)
            end
            local col = isCursor and UI.COL_HI or UI.COL_TEXT
            UI.text(string.format("%02d: PAT %d", i, pid), x + 1, y + 1, col)
            y = y + 8
            if y > ih - 30 then break end
        end
    end

    y = y + 4

    -- Buttons
    if UI.button("+ADD", x, y, 28, 9, UI.COL_ACTIVE) then
        pushUndo("order_add")
        local o = Music.getOrder()
        o[#o + 1] = currentPatId
        Music.setOrder(o)
    end

    if UI.button("-DEL", x + 32, y, 28, 9, UI.COL_DANGER) then
        local o = Music.getOrder()
        if #o > 0 and orderCursor >= 1 and orderCursor <= #o then
            pushUndo("order_del")
            table.remove(o, orderCursor)
            if orderCursor > #o then orderCursor = math.max(1, #o) end
            Music.setOrder(o)
        end
    end

    -- Play whole song button
    y = y + 12
    if UI.button("PLAY", x, y, 28, 9, UI.COL_ACTIVE) then
        Music.setLoopPattern(false)
        Music.setSong(Music.getOrder())
        Music.play(1)
    end
    if UI.button("STOP", x + 32, y, 28, 9, 5) then
        Music.stop()
    end

    -- Footer
    UI.text("UP/DN:NAV RET:EDIT", 2, ih - 14, 3)
    UI.text("+/-:PAT# ESC:BACK", 2, ih - 7, 3)
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------
function ME.draw(yOff)
    local iw = Video.getInternalWidth()
    local ih = Video.getInternalHeight()
    yOff = yOff or 10

    if mode == MODE_PATTERN then
        drawPatternMode(yOff, iw, ih)
    elseif mode == MODE_INSTRUMENT then
        drawInstrumentMode(yOff, iw, ih)
    elseif mode == MODE_ORDER then
        drawOrderMode(yOff, iw, ih)
    end
end

---------------------------------------------------------------------------
-- Keypressed: Pattern mode
---------------------------------------------------------------------------
local function keypressedPattern(key, ctrl)
    local trackLen = getTrackLen(currentPatId)

    if key == "up" then
        cursorRow = cursorRow - 1
        if cursorRow < 1 then cursorRow = trackLen end
    elseif key == "down" then
        cursorRow = cursorRow + 1
        if cursorRow > trackLen then cursorRow = 1 end
    elseif key == "left" then
        cursorCol = cursorCol - 1
        if cursorCol < 1 then cursorCol = NUM_CH end
    elseif key == "right" then
        cursorCol = cursorCol + 1
        if cursorCol > NUM_CH then cursorCol = 1 end
    elseif key == "tab" then
        cursorCol = (cursorCol % NUM_CH) + 1
    elseif key == "return" then
        -- Place note at cursor
        pushUndo("set_note")
        local pat = Music.ensurePattern(currentPatId)
        local noteName = NOTES[inputNote] .. "-" .. inputOctave
        pat.channels[cursorCol][cursorRow] = { noteName, inputInstrument }
        -- Auto-advance
        cursorRow = cursorRow + 1
        if cursorRow > trackLen then cursorRow = 1 end
    elseif key == "delete" or key == "backspace" then
        pushUndo("del_note")
        local pat = Music.ensurePattern(currentPatId)
        pat.channels[cursorCol][cursorRow] = false
    elseif key == "space" then
        if Music.isPlaying() then
            Music.stop()
            Music.setLoopPattern(false)
        else
            Music.setLoopPattern(true)
            -- Build temp order with just this pattern
            Music.setSong(Music.getOrder())
            local oi = 1
            for i, pid in ipairs(Music.getOrder()) do
                if pid == currentPatId then oi = i; break end
            end
            Music.play(oi)
        end

    -- Note selection (keyboard piano-style)
    elseif key == "z" then inputNote = 1   -- C
    elseif key == "s" and not ctrl then inputNote = 2   -- C#
    elseif key == "x" then inputNote = 3   -- D
    elseif key == "d" and not ctrl then inputNote = 4   -- D#
    elseif key == "c" then inputNote = 5   -- E
    elseif key == "v" then inputNote = 6   -- F
    elseif key == "g" then inputNote = 7   -- F#
    elseif key == "b" then inputNote = 8   -- G
    elseif key == "h" then inputNote = 9   -- G#
    elseif key == "n" then inputNote = 10  -- A
    elseif key == "j" then inputNote = 11  -- A#
    elseif key == "m" then inputNote = 12  -- B

    -- Octave
    elseif key == "[" then
        inputOctave = math.max(0, inputOctave - 1)
    elseif key == "]" then
        inputOctave = math.min(7, inputOctave + 1)

    -- Instrument select
    elseif key == "," then
        inputInstrument = math.max(1, inputInstrument - 1)
    elseif key == "." then
        inputInstrument = math.min(8, inputInstrument + 1)

    -- BPM / Speed
    elseif key == "=" or key == "kp+" then
        pushUndo("bpm")
        Music.setBPM(Music.getBPM() + 5)
    elseif key == "-" or key == "kp-" then
        pushUndo("bpm")
        Music.setBPM(Music.getBPM() - 5)

    -- Pattern navigation
    elseif key == "pageup" then
        currentPatId = math.max(1, currentPatId - 1)
        Music.ensurePattern(currentPatId)
        ensureTrackLen(currentPatId, 16)
        cursorRow = 1
    elseif key == "pagedown" then
        currentPatId = currentPatId + 1
        Music.ensurePattern(currentPatId)
        ensureTrackLen(currentPatId, 16)
        cursorRow = 1

    -- Add/remove rows
    elseif key == "home" then
        -- Add row to end of pattern
        local tl = getTrackLen(currentPatId)
        if tl < MAX_STEPS then
            pushUndo("add_row")
            ensureTrackLen(currentPatId, tl + 1)
        end
    elseif key == "end" then
        -- Remove last row
        local tl = getTrackLen(currentPatId)
        if tl > 1 then
            pushUndo("rem_row")
            local pat = Music.getPattern(currentPatId)
            for ch = 1, NUM_CH do
                if pat.channels[ch] and #pat.channels[ch] > 1 then
                    table.remove(pat.channels[ch])
                end
            end
            if cursorRow > getTrackLen(currentPatId) then
                cursorRow = getTrackLen(currentPatId)
            end
        end

    -- Switch modes
    elseif key == "i" then
        mode = MODE_INSTRUMENT
    elseif key == "o" then
        mode = MODE_ORDER

    -- Undo/Redo
    elseif ctrl and key == "z" then
        doUndo()
    elseif ctrl and key == "y" then
        doRedo()
    end
end

---------------------------------------------------------------------------
-- Keypressed: Instrument mode
---------------------------------------------------------------------------
local function keypressedInstrument(key, ctrl)
    if key == "escape" or key == "i" then
        mode = MODE_PATTERN
    elseif key == "up" then
        instSlot = math.max(1, instSlot - 1)
    elseif key == "down" then
        instSlot = math.min(8, instSlot + 1)
    elseif ctrl and key == "z" then
        doUndo()
    elseif ctrl and key == "y" then
        doRedo()
    end
end

---------------------------------------------------------------------------
-- Keypressed: Order mode
---------------------------------------------------------------------------
local function keypressedOrder(key, ctrl)
    local order = Music.getOrder()

    if key == "escape" or key == "o" then
        mode = MODE_PATTERN
    elseif key == "up" then
        orderCursor = math.max(1, orderCursor - 1)
    elseif key == "down" then
        orderCursor = math.min(math.max(1, #order), orderCursor + 1)
    elseif key == "return" then
        -- Edit selected order entry: set to current pattern
        if #order > 0 and orderCursor >= 1 and orderCursor <= #order then
            pushUndo("order_edit")
            order[orderCursor] = currentPatId
            Music.setOrder(order)
        end
    elseif key == "=" or key == "kp+" then
        -- Increase pattern # at cursor
        if #order > 0 and orderCursor >= 1 and orderCursor <= #order then
            pushUndo("order_inc")
            order[orderCursor] = (order[orderCursor] or 1) + 1
            Music.setOrder(order)
        end
    elseif key == "-" or key == "kp-" then
        -- Decrease pattern # at cursor
        if #order > 0 and orderCursor >= 1 and orderCursor <= #order then
            pushUndo("order_dec")
            order[orderCursor] = math.max(1, (order[orderCursor] or 1) - 1)
            Music.setOrder(order)
        end
    elseif key == "insert" or key == "a" then
        pushUndo("order_add")
        table.insert(order, orderCursor + 1, currentPatId)
        Music.setOrder(order)
        orderCursor = math.min(orderCursor + 1, #order)
    elseif key == "delete" then
        if #order > 0 then
            pushUndo("order_del")
            table.remove(order, orderCursor)
            if orderCursor > #order then orderCursor = math.max(1, #order) end
            Music.setOrder(order)
        end
    elseif key == "space" then
        if Music.isPlaying() then
            Music.stop()
        else
            Music.setLoopPattern(false)
            Music.setSong(Music.getOrder())
            Music.play(1)
        end
    elseif ctrl and key == "z" then
        doUndo()
    elseif ctrl and key == "y" then
        doRedo()
    end
end

---------------------------------------------------------------------------
-- Main keypressed
---------------------------------------------------------------------------
function ME.keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Ctrl+S is handled by editor_app, skip here
    if ctrl and key == "s" then return end

    if mode == MODE_PATTERN then
        keypressedPattern(key, ctrl)
    elseif mode == MODE_INSTRUMENT then
        keypressedInstrument(key, ctrl)
    elseif mode == MODE_ORDER then
        keypressedOrder(key, ctrl)
    end
end

return ME
