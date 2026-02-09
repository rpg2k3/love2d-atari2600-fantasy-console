-- src/platform/video.lua  4:3 canvas pipeline + scaling + CRT shader pass
local Config = require("src.config")
local CRT    = require("src.platform.crt_shader")

local Video = {}

-- State
local canvas       = nil   -- internal render target
local internalW    = 160
local internalH    = 192
local viewportX    = 0     -- where the 4:3 area starts on real window
local viewportY    = 0
local viewportW    = 960
local viewportH    = 720
local scaleFactor  = 1

-- Mouse debug crosshair toggle (F7)
Video.mouseDebug   = false
-- Editor curvature override: when true, force curvature OFF in editor
Video.editorCurveOff = true

function Video.init()
    CRT.init()
    Video.setResolution(Config.RES_INDEX)
end

function Video.setResolution(presetIndex)
    Config.RES_INDEX = presetIndex
    local p = Config.RES_PRESETS[presetIndex]
    internalW = p.w
    internalH = p.h
    canvas = love.graphics.newCanvas(internalW, internalH)
    canvas:setFilter("nearest", "nearest")
    Video.recalcViewport()
end

function Video.cycleResolution()
    local idx = Config.RES_INDEX % #Config.RES_PRESETS + 1
    Video.setResolution(idx)
end

function Video.recalcViewport()
    local ww, wh = love.graphics.getDimensions()
    -- Compute largest 4:3 rectangle that fits in window
    local targetAspect = Config.ASPECT_W / Config.ASPECT_H
    local windowAspect = ww / wh
    if windowAspect > targetAspect then
        -- pillarbox
        viewportH = wh
        viewportW = math.floor(wh * targetAspect)
    else
        -- letterbox
        viewportW = ww
        viewportH = math.floor(ww / targetAspect)
    end
    viewportX = math.floor((ww - viewportW) / 2)
    viewportY = math.floor((wh - viewportH) / 2)
    scaleFactor = viewportW / internalW
end

function Video.beginFrame()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function Video.endFrame()
    -- Draw mouse debug crosshair BEFORE leaving the internal canvas
    -- (so it appears in internal-pixel space and gets CRT-warped with everything else)
    if Video.mouseDebug then
        Video.drawMouseDebug()
    end

    love.graphics.setCanvas()

    -- Clear entire window to black (for letterbox/pillarbox bars)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")

    -- Apply CRT shader if enabled
    local crtPreset = Config.CRT_PRESETS[Config.CRT_INDEX]
    if CRT.shader and CRT.enabled and crtPreset.intensity > 0 then
        CRT.send(crtPreset.intensity, internalW, internalH, viewportW, viewportH)
        love.graphics.setShader(CRT.shader)
    end

    -- Draw internal canvas scaled to viewport
    love.graphics.draw(canvas, viewportX, viewportY, 0,
        viewportW / internalW, viewportH / internalH)

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
end

function Video.update(dt)
    CRT.update(dt)
end

-- ============================================================
-- CRT barrel distortion (Lua-side, matches GLSL curve() exactly)
-- ============================================================
-- Forward distortion: given a UV in 0..1 viewport space,
-- return the distorted UV the shader would sample from.
-- This is the same math as the GLSL curve() function.
--   uv_centered = uv * 2 - 1
--   r2 = x*x + y*y
--   uv_centered *= 1 + k * r2
--   return (uv_centered + 1) * 0.5
local function distortUV(ux, uy, k)
    local cx = ux * 2 - 1
    local cy = uy * 2 - 1
    local r2 = cx * cx + cy * cy
    local scale = 1 + k * r2
    cx = cx * scale
    cy = cy * scale
    return (cx + 1) * 0.5, (cy + 1) * 0.5
end

-- Inverse distortion via iterative Newton-style correction.
-- Given a screen-space UV (where the pixel visually appears after
-- the shader warps it), find the original UV that maps to it.
-- 8 iterations with damping is plenty at editor frame rates.
local function undistortUV(tx, ty, k)
    if k < 0.0001 then return tx, ty end
    local ux, uy = tx, ty
    for _ = 1, 8 do
        local dx, dy = distortUV(ux, uy, k)
        local ex, ey = dx - tx, dy - ty
        ux = ux - ex * 0.6
        uy = uy - ey * 0.6
        -- Clamp to avoid divergence at extreme edges
        if ux < 0 then ux = 0 elseif ux > 1 then ux = 1 end
        if uy < 0 then uy = 0 elseif uy > 1 then uy = 1 end
    end
    return ux, uy
end

-- ============================================================
-- screenToInternal: CRT-aware mouse mapping
-- ============================================================
-- Convert window (screen) mouse coords to internal canvas pixel coords.
-- Returns ix, iy, inViewport
function Video.screenToInternal(sx, sy)
    -- Step 1: window coords -> viewport-local coords (0..viewportW, 0..viewportH)
    local lx = sx - viewportX
    local ly = sy - viewportY

    -- Step 2: normalize to 0..1 UV within the viewport
    local ux = lx / viewportW
    local uy = ly / viewportH

    local inViewport = (ux >= 0 and ux <= 1 and uy >= 0 and uy <= 1)

    -- Step 3: if CRT curvature is active, apply inverse distortion
    local k = CRT.getEffectiveCurveAmount()
    if k > 0.0001 then
        ux, uy = undistortUV(ux, uy, k)
    end

    -- Step 4: UV -> internal pixel coords
    local ix = ux * internalW
    local iy = uy * internalH

    return ix, iy, inViewport
end

-- ============================================================
-- Mouse debug crosshair (F7)
-- ============================================================
-- Drawn in internal canvas space so the crosshair gets CRT-warped
-- and should visually sit exactly under the OS cursor.
function Video.drawMouseDebug()
    local sx, sy = love.mouse.getPosition()
    local ix, iy, inv = Video.screenToInternal(sx, sy)

    if not inv then return end

    local pix = math.floor(ix)
    local piy = math.floor(iy)

    -- Crosshair (lime green)
    love.graphics.setColor(0.3, 1, 0.3, 0.9)
    -- Horizontal line
    love.graphics.line(0, piy + 0.5, internalW, piy + 0.5)
    -- Vertical line
    love.graphics.line(pix + 0.5, 0, pix + 0.5, internalH)
    -- Center dot (bright)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.rectangle("fill", pix, piy, 1, 1)

    -- Text readout at top-left (small, avoid covering too much)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 64, 22)
    -- Use PixelFont if loaded, else fallback to love default font
    local ok, PF = pcall(require, "src.util.pixelfont")
    if ok and PF then
        PF.print(string.format("W:%d,%d", math.floor(sx), math.floor(sy)), 1, 1, 1, 0.3, 1, 0.3)
        PF.print(string.format("I:%d,%d", pix, piy), 1, 8, 1, 1, 1, 0.3)
        local k = CRT.getEffectiveCurveAmount()
        PF.print(string.format("K:%.3f", k), 1, 15, 1, 0.6, 0.6, 0.6)
    end
end

-- ============================================================
-- Getters
-- ============================================================
function Video.getInternalWidth()  return internalW end
function Video.getInternalHeight() return internalH end
function Video.getViewportRect()   return viewportX, viewportY, viewportW, viewportH end
function Video.getCanvas()         return canvas end
function Video.getScale()          return scaleFactor end

-- ============================================================
-- CRT controls
-- ============================================================
function Video.toggleCRT()
    CRT.enabled = not CRT.enabled
end

function Video.cycleCRTPreset()
    Config.CRT_INDEX = Config.CRT_INDEX % #Config.CRT_PRESETS + 1
end

function Video.getCRTLabel()
    if not CRT.enabled then return "CRT: Disabled" end
    return "CRT: " .. Config.CRT_PRESETS[Config.CRT_INDEX].label
end

function Video.getResLabel()
    return Config.RES_PRESETS[Config.RES_INDEX].label
end

-- Toggle editor curvature override (Shift+F2)
function Video.toggleEditorCurve()
    Video.editorCurveOff = not Video.editorCurveOff
end

-- Call this when entering/leaving editor to enforce the override
function Video.setEditorCurvatureOverride(isEditor)
    if isEditor and Video.editorCurveOff then
        CRT.enableCurve = 0.0
    else
        CRT.enableCurve = 1.0
    end
end

-- ============================================================
-- TODO: Next Phase — Cartridges + Boot Menu
-- ============================================================
-- Planned architecture for cartridge system:
--
-- Directory layout:
--   cartridges/<game_name>/
--     main.lua       -- entry point, receives engine API table
--     content.lua    -- sprites, tiles, sfx, music as Lua tables
--     levels/        -- level files (same format as save/levels/)
--
-- Boot menu:
--   - On startup, scan cartridges/ for subdirectories
--   - Display a selection screen (Atari-styled, pixel font, CRT)
--   - Selected cartridge loads its content.lua, then runs main.lua
--   - Provide a sandboxed API table to the cartridge (sprites, ecs,
--     audio, input, video dimensions, etc.) — no raw love.* access
--   - "Reset" key (e.g. Escape) returns to boot menu
--
-- Implementation notes:
--   - Cartridge main.lua should export { load, update, draw, keypressed }
--   - Engine manages the love.* lifecycle; cartridge only sees the API
--   - Editor can target a cartridge directory for save/load paths
--   - Content registration (sprites/tiles) scoped per cartridge
-- ============================================================

return Video
