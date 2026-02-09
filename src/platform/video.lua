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

-- Convert screen (window) mouse coords to internal canvas coords
function Video.screenToInternal(sx, sy)
    local ix = (sx - viewportX) / scaleFactor
    local iy = (sy - viewportY) / (viewportH / internalH)
    return ix, iy
end

-- Getters
function Video.getInternalWidth()  return internalW end
function Video.getInternalHeight() return internalH end
function Video.getViewportRect()   return viewportX, viewportY, viewportW, viewportH end
function Video.getCanvas()         return canvas end
function Video.getScale()          return scaleFactor end

-- CRT controls
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

return Video
