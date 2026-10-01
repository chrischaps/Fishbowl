-- Day/night cycle: keyframed light palettes for the whole tank.
-- Phase 0 = dawn. Every frame the current palette is blended from the two
-- surrounding keyframes and published as DayCycle.env for other modules.

local C = require("config")

local DayCycle = {}

-- Keyframes. Colors are linear-ish RGB; numbers are blended smoothly.
--   water_top / water_deep : water color just under the surface / at the floor
--   fog        : distance haze color
--   light      : color of sun or lamp light entering from above
--   light_i    : light intensity (0..1)
--   angle      : slant of the light shafts (screen dx per dy)
--   sun_x      : screen x where the light pools brightest
--   caustic    : caustic strength (0..1)
--   ambient    : multiplier applied to every lit object
--   haze       : how much far objects fade into the fog
--   glow       : bioluminescence and night-lamp level (0..1)
--   air        : color of the air gap above the waterline
--   lamp       : brightness of the hood light seen above the waterline
--   vivid      : fish color saturation (fish pale at night)
--   post       : PostFX color grade and bloom
local keys = {
    { t = 0.00, name = "dawn",
      water_top = {0.30, 0.36, 0.44}, water_deep = {0.07, 0.11, 0.17}, fog = {0.20, 0.25, 0.32},
      light = {1.00, 0.76, 0.56}, light_i = 0.40, angle = 0.38, sun_x = 260, caustic = 0.35,
      ambient = {0.80, 0.76, 0.78}, haze = 0.55, glow = 0.25, air = {0.16, 0.13, 0.13}, lamp = 0.30, vivid = 0.75,
      post = { warmth = 0.06, saturation = 0.02, contrast = 0.08, shadowTint = {0.10, 0.10, 0.16},
               bloomThreshold = 0.55, bloomIntensity = 0.45, vignette = 0.32 } },
    { t = 0.12, name = "morning",
      water_top = {0.24, 0.50, 0.54}, water_deep = {0.03, 0.18, 0.24}, fog = {0.13, 0.34, 0.38},
      light = {1.00, 0.93, 0.80}, light_i = 0.85, angle = 0.22, sun_x = 420, caustic = 0.85,
      ambient = {0.98, 0.98, 0.96}, haze = 0.50, glow = 0.0, air = {0.22, 0.22, 0.20}, lamp = 0.85, vivid = 1.0,
      post = { warmth = 0.03, saturation = 0.10, contrast = 0.10, shadowTint = {0.00, 0.10, 0.14},
               bloomThreshold = 0.60, bloomIntensity = 0.50, vignette = 0.28 } },
    { t = 0.30, name = "day",
      water_top = {0.22, 0.54, 0.56}, water_deep = {0.02, 0.20, 0.25}, fog = {0.12, 0.37, 0.40},
      light = {1.00, 0.98, 0.92}, light_i = 1.00, angle = 0.02, sun_x = 660, caustic = 1.00,
      ambient = {1.00, 1.00, 1.00}, haze = 0.48, glow = 0.0, air = {0.24, 0.24, 0.23}, lamp = 1.00, vivid = 1.0,
      post = { warmth = 0.00, saturation = 0.12, contrast = 0.10, shadowTint = {0.00, 0.10, 0.14},
               bloomThreshold = 0.62, bloomIntensity = 0.50, vignette = 0.28 } },
    { t = 0.45, name = "afternoon",
      water_top = {0.26, 0.50, 0.50}, water_deep = {0.04, 0.18, 0.21}, fog = {0.15, 0.34, 0.35},
      light = {1.00, 0.92, 0.76}, light_i = 0.90, angle = -0.20, sun_x = 900, caustic = 0.90,
      ambient = {1.00, 0.97, 0.92}, haze = 0.50, glow = 0.0, air = {0.24, 0.22, 0.20}, lamp = 0.90, vivid = 1.0,
      post = { warmth = 0.04, saturation = 0.12, contrast = 0.10, shadowTint = {0.05, 0.10, 0.10},
               bloomThreshold = 0.60, bloomIntensity = 0.50, vignette = 0.28 } },
    -- The original Fishbowl palette lives on as the sunset
    { t = 0.58, name = "sunset",
      water_top = {0.35, 0.22, 0.28}, water_deep = {0.16, 0.09, 0.11}, fog = {0.30, 0.18, 0.20},
      light = {1.00, 0.68, 0.40}, light_i = 0.75, angle = -0.40, sun_x = 1050, caustic = 0.60,
      ambient = {1.00, 0.84, 0.74}, haze = 0.55, glow = 0.10, air = {0.22, 0.14, 0.11}, lamp = 0.55, vivid = 0.95,
      post = { warmth = 0.12, saturation = 0.15, contrast = 0.10, shadowTint = {0.25, 0.12, 0.05},
               bloomThreshold = 0.50, bloomIntensity = 0.60, vignette = 0.35 } },
    { t = 0.68, name = "dusk",
      water_top = {0.15, 0.14, 0.26}, water_deep = {0.04, 0.04, 0.09}, fog = {0.10, 0.10, 0.19},
      light = {0.70, 0.58, 0.85}, light_i = 0.30, angle = -0.20, sun_x = 900, caustic = 0.20,
      ambient = {0.56, 0.52, 0.66}, haze = 0.60, glow = 0.60, air = {0.09, 0.08, 0.12}, lamp = 0.15, vivid = 0.65,
      post = { warmth = 0.02, saturation = 0.00, contrast = 0.10, shadowTint = {0.08, 0.06, 0.18},
               bloomThreshold = 0.42, bloomIntensity = 0.60, vignette = 0.40 } },
    -- Night: the moonlight LED
    { t = 0.76, name = "night",
      water_top = {0.05, 0.10, 0.20}, water_deep = {0.01, 0.025, 0.06}, fog = {0.03, 0.07, 0.13},
      light = {0.55, 0.72, 1.00}, light_i = 0.32, angle = 0.04, sun_x = 640, caustic = 0.30,
      ambient = {0.30, 0.38, 0.56}, haze = 0.65, glow = 1.00, air = {0.03, 0.04, 0.07}, lamp = 0.12, vivid = 0.35,
      post = { warmth = -0.04, saturation = -0.10, contrast = 0.12, shadowTint = {0.02, 0.06, 0.16},
               bloomThreshold = 0.34, bloomIntensity = 0.70, vignette = 0.45 } },
    { t = 0.94, name = "late night",
      water_top = {0.05, 0.09, 0.18}, water_deep = {0.01, 0.02, 0.05}, fog = {0.03, 0.06, 0.12},
      light = {0.55, 0.70, 1.00}, light_i = 0.28, angle = 0.10, sun_x = 520, caustic = 0.25,
      ambient = {0.28, 0.35, 0.52}, haze = 0.65, glow = 1.00, air = {0.03, 0.035, 0.06}, lamp = 0.10, vivid = 0.35,
      post = { warmth = -0.04, saturation = -0.10, contrast = 0.12, shadowTint = {0.02, 0.06, 0.16},
               bloomThreshold = 0.34, bloomIntensity = 0.70, vignette = 0.45 } },
}

-- Named presets for --snap and the T key (phases chosen mid-keyframe)
DayCycle.presets = {
    dawn = 0.02, morning = 0.14, day = 0.32, afternoon = 0.46,
    sunset = 0.59, dusk = 0.68, night = 0.80,
}

-- Real-clock anchors: phase at each keyframe expressed as an hour of the day
local clockHours = { 6.0, 8.0, 12.5, 16.0, 18.5, 19.6, 21.0, 29.0 } -- 29 = 5am next day

local phase = DayCycle.presets.morning
local speed = 1
local glideTarget = nil
local liveClock = false

DayCycle.env = {}

local function lerp(a, b, t) return a + (b - a) * t end

local function blend(a, b, t, out)
    for k, va in pairs(a) do
        local vb = b[k]
        if type(va) == "number" then
            out[k] = lerp(va, vb, t)
        elseif type(va) == "table" then
            out[k] = out[k] or {}
            blend(va, vb, t, out[k])
        elseif k ~= "name" then
            out[k] = va
        end
    end
    return out
end

local function evaluate(p)
    local n = #keys
    local a, b = keys[n], keys[1]
    local span, t
    for i = 1, n do
        local k1 = keys[i]
        local k2 = keys[i % n + 1]
        local t1, t2 = k1.t, k2.t
        if i == n then t2 = 1 + keys[1].t end
        local pp = p
        if i == n and p < k1.t then pp = p + 1 end
        if pp >= t1 and pp < t2 then
            a, b = k1, k2
            span = t2 - t1
            t = (pp - t1) / span
            break
        end
    end
    t = t or 0
    t = t * t * (3 - 2 * t)  -- smoothstep: palettes ease in and out of each key
    blend(a, b, t, DayCycle.env)
    DayCycle.env.name = (t < 0.5) and a.name or b.name
    DayCycle.env.phase = p
end

local function phaseFromClock()
    local d = os.date("*t")
    local h = d.hour + d.min / 60 + d.sec / 3600
    if h < clockHours[1] then h = h + 24 end
    for i = 1, #keys do
        local h1 = clockHours[i]
        local h2 = clockHours[i + 1] or (clockHours[1] + 24)
        if h >= h1 and h < h2 then
            local t2 = keys[i + 1] and keys[i + 1].t or 1
            return keys[i].t + (t2 - keys[i].t) * (h - h1) / (h2 - h1)
        end
    end
    return 0
end

function DayCycle.init(startPhase)
    phase = startPhase or phase
    evaluate(phase)
end

function DayCycle.update(dt)
    if liveClock then
        phase = phaseFromClock()
    elseif glideTarget then
        -- Fast but smooth travel to the requested time of day
        local dist = (glideTarget - phase) % 1
        local step = dt * 0.12
        if dist <= step then
            phase = glideTarget
            glideTarget = nil
        else
            phase = (phase + step) % 1
        end
    else
        phase = (phase + dt * speed / C.CYCLE_SECONDS) % 1
    end
    evaluate(phase)
end

--- Glide forward to the next keyframe
function DayCycle.skip()
    liveClock = false
    local nextT
    for _, k in ipairs(keys) do
        if k.t > phase + 0.01 then nextT = k.t break end
    end
    glideTarget = (nextT or keys[1].t) + 0.005
end

function DayCycle.set(p)
    phase = p % 1
    glideTarget = nil
    evaluate(phase)
end

function DayCycle.setSpeed(s) speed = math.max(0, s) end
function DayCycle.getSpeed() return speed end

function DayCycle.toggleLiveClock()
    liveClock = not liveClock
    glideTarget = nil
    return liveClock
end

function DayCycle.isLiveClock() return liveClock end

--- Apply the current grade to the LoveLibs PostFX config
function DayCycle.applyPost(PostFX)
    local p = DayCycle.env.post
    local cg = PostFX.config.colorGrade
    cg.warmth = p.warmth
    cg.saturation = p.saturation
    cg.contrast = p.contrast
    cg.vignetteStrength = p.vignette
    cg.shadowTint = p.shadowTint
    PostFX.config.bloom.threshold = p.bloomThreshold
    PostFX.config.bloom.intensity = p.bloomIntensity
end

return DayCycle
