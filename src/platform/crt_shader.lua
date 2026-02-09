-- src/platform/crt_shader.lua  CRT simulation shader + presets
local CRT = {}

-- ============================================================
-- Shared distortion constant (must match GLSL curve() exactly)
-- ============================================================
-- The barrel distortion coefficient applied as:
--   uv_centered *= 1.0 + CURVE_K * r2 * enableCurve * intensity
-- where r2 = x*x + y*y in centered (-1..1) space.
CRT.CURVE_K = 0.15

-- Single-pass CRT shader: scanlines, vignette, shadow mask, barrel distortion, noise
local SHADER_CODE = [[
extern float u_time;
extern float u_intensity;     // 0..1 master intensity
extern vec2  u_resolution;    // internal resolution (e.g. 160,192)
extern vec2  u_screenRes;     // output viewport size in pixels
extern float u_enableCurve;   // 0 or 1
extern float u_enableMask;    // 0 or 1
extern float u_enableNoise;   // 0 or 1

// Barrel distortion — coefficient MUST match CRT.CURVE_K in Lua
vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    float r2 = uv.x*uv.x + uv.y*uv.y;
    uv *= 1.0 + 0.15 * r2 * u_enableCurve * u_intensity;
    uv = (uv + 1.0) * 0.5;
    return uv;
}

// Simple pseudo-random
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (u_intensity < 0.01) {
        return Texel(tex, tc) * color;
    }

    vec2 uv = curve(tc);

    // Out-of-bounds after curvature -> black
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Chromatic aberration (subtle)
    float ca = 0.001 * u_intensity;
    float r = Texel(tex, vec2(uv.x + ca, uv.y)).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, vec2(uv.x - ca, uv.y)).b;
    vec3 col = vec3(r, g, b);

    // Scanlines: darken every other row based on internal pixel position
    float scanY = uv.y * u_resolution.y;
    float scanline = 1.0 - 0.25 * u_intensity * (1.0 - step(0.5, fract(scanY * 0.5)));

    // Another scanline approach: sine-based for smoother look
    float scan2 = 1.0 - 0.15 * u_intensity * (0.5 + 0.5 * sin(scanY * 3.14159));
    scanline = min(scanline, scan2);

    col *= scanline;

    // Shadow mask / phosphor grille (subtle RGB pattern on output pixels)
    if (u_enableMask > 0.5) {
        float maskX = mod(sc.x, 3.0);
        vec3 mask;
        if (maskX < 1.0) {
            mask = vec3(1.0, 0.7, 0.7);
        } else if (maskX < 2.0) {
            mask = vec3(0.7, 1.0, 0.7);
        } else {
            mask = vec3(0.7, 0.7, 1.0);
        }
        col *= mix(vec3(1.0), mask, 0.2 * u_intensity);
    }

    // Vignette
    vec2 vig = uv * (1.0 - uv);
    float vigAmount = vig.x * vig.y * 15.0;
    vigAmount = pow(vigAmount, 0.25 * u_intensity);
    col *= vigAmount;

    // Noise / flicker
    if (u_enableNoise > 0.5) {
        float noise = rand(uv * u_resolution + vec2(u_time * 7.0, u_time * 13.0));
        col += (noise - 0.5) * 0.04 * u_intensity;
        // Subtle brightness flicker
        col *= 1.0 + 0.01 * u_intensity * sin(u_time * 60.0);
    }

    return vec4(col, 1.0) * color;
}
]]

function CRT.init()
    local ok, shader = pcall(love.graphics.newShader, SHADER_CODE)
    if not ok then
        print("[CRT] Shader compile error: " .. tostring(shader))
        CRT.shader = nil
        return
    end
    CRT.shader = shader
    CRT.enabled = true
    CRT.enableCurve = 1.0
    CRT.enableMask  = 1.0
    CRT.enableNoise = 1.0
    CRT.time = 0
end

function CRT.update(dt)
    CRT.time = CRT.time + dt
end

function CRT.send(intensity, internalW, internalH, screenW, screenH)
    if not CRT.shader then return end
    CRT.shader:send("u_time", CRT.time)
    CRT.shader:send("u_intensity", intensity)
    CRT.shader:send("u_resolution", {internalW, internalH})
    -- screen resolution uniform (defensive: supports either name)
    if CRT.shader:hasUniform("u_screenRes") then
        CRT.shader:send("u_screenRes", {screenW, screenH})
    elseif CRT.shader:hasUniform("u_resolution") then
        CRT.shader:send("u_resolution", {screenW, screenH})
    end
    CRT.shader:send("u_enableCurve", CRT.enableCurve)
    CRT.shader:send("u_enableMask",  CRT.enableMask)
    CRT.shader:send("u_enableNoise", CRT.enableNoise)
end

-- ============================================================
-- Lua-side distortion queries (for mouse inverse mapping)
-- ============================================================

-- Is CRT barrel curvature currently active?
function CRT.isCurvatureEnabled()
    if not CRT.enabled then return false end
    if CRT.enableCurve < 0.5 then return false end
    local Config = require("src.config")
    local preset = Config.CRT_PRESETS[Config.CRT_INDEX]
    if preset and preset.intensity < 0.01 then return false end
    return true
end

-- Effective curve strength = CURVE_K * enableCurve * intensity
function CRT.getEffectiveCurveAmount()
    if not CRT.enabled then return 0 end
    local Config = require("src.config")
    local preset = Config.CRT_PRESETS[Config.CRT_INDEX]
    local intensity = preset and preset.intensity or 0
    return CRT.CURVE_K * CRT.enableCurve * intensity
end

function CRT.getParams()
    local Config = require("src.config")
    local preset = Config.CRT_PRESETS[Config.CRT_INDEX]
    return {
        enabled       = CRT.enabled,
        intensity     = preset and preset.intensity or 0,
        curveK        = CRT.CURVE_K,
        enableCurve   = CRT.enableCurve,
        enableMask    = CRT.enableMask,
        enableNoise   = CRT.enableNoise,
        effectiveCurve = CRT.getEffectiveCurveAmount(),
    }
end

return CRT
