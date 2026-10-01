-- Species definitions: body shape, coloring, fins and temperament.
--
-- Profiles give the body's half-height above (top) and below (bot) the spine
-- at s = 0, 1/8, ... 1 (nose to tail base), as a fraction of `height`.
-- colors(s, v, fish) returns r, g, b[, a] for a point on the flank,
-- where v runs 0 (back) .. 1 (belly).

local Species = {}

local sin, abs, floor = math.sin, math.abs, math.floor

local function band(x, a, b, soft)
    soft = soft or 0.03
    local lo = math.min(1, math.max(0, (x - a) / soft + 0.5))
    local hi = math.min(1, math.max(0, (b - x) / soft + 0.5))
    return lo * hi
end

local function mix(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

local function hash(a, b)
    local n = sin(a * 127.1 + b * 311.7) * 43758.5453
    return n - floor(n)
end

--------------------------------------------------------------------------------
Species.neon = {
    label = "neon tetra",
    count = 12,
    length = 30, height = 0.27, thick = 0.12,
    top = { 0, 0.50, 0.80, 0.97, 1.00, 0.86, 0.60, 0.38, 0.30 },
    bot = { 0, 0.48, 0.78, 0.94, 1.00, 0.86, 0.58, 0.36, 0.30 },
    eye = { s = 0.11, r = 0.075, iris = { 0.75, 0.70, 0.55 } },
    colors = function(s, v, f)
        local back = { 0.34, 0.30, 0.22 }
        local silver = { 0.82, 0.84, 0.86 }
        local blue = { 0.10 * f.irid, 0.78 * f.irid, 1.00 * f.irid }
        local red = { 0.92, 0.14, 0.20 }
        local stripe = band(s, 0.12, 0.86, 0.06)
        local r, g, b
        if v < 0.1 then
            r, g, b = back[1], back[2], back[3]
        elseif v < 0.2 then
            r, g, b = mix(back, blue, stripe * 0.35)
        elseif v < 0.45 then
            r, g, b = mix(silver, blue, stripe)
        elseif v < 0.6 then
            r, g, b = mix(silver, red, band(s, 0.50, 1.2, 0.08))
        else
            r, g, b = mix({ 0.90, 0.88, 0.86 }, red, band(s, 0.44, 1.2, 0.08) * (v < 0.9 and 1 or 0.7))
        end
        local a = s > 0.9 and 0.8 or 1
        return r, g, b, a
    end,
    fins = {
        caudal = { len = 0.30, height = 0.36, fork = 0.55, shape = "fork", color = { 0.85, 0.85, 0.85 }, alpha = 0.30 },
        dorsal = { s0 = 0.40, s1 = 0.52, height = 0.22, rake = 0.10, color = { 0.85, 0.85, 0.82 }, alpha = 0.35 },
        anal = { s0 = 0.56, s1 = 0.80, height = 0.13, rake = 0.06, color = { 0.85, 0.85, 0.85 }, alpha = 0.30 },
        pectoral = { s = 0.22, len = 0.16, alpha = 0.25 },
        pelvic = { s = 0.42, len = 0.11, alpha = 0.25 },
    },
    cruise = 34, burst = 170, turnRate = 3.4, accel = 120,
    zone = { 0.25, 0.70 }, school = true, sociable = 0.8,
    wave = { amp = 0.07, k = 5.0, freq = 3.2 },
}

--------------------------------------------------------------------------------
Species.angel = {
    label = "angelfish",
    count = 2,
    length = 52, height = 0.74, thick = 0.10,
    top = { 0, 0.52, 0.84, 0.99, 1.00, 0.90, 0.66, 0.36, 0.17 },
    bot = { 0, 0.48, 0.80, 0.97, 1.00, 0.90, 0.66, 0.36, 0.17 },
    eye = { s = 0.12, r = 0.07, iris = { 0.85, 0.30, 0.20 } },
    colors = function(s, v, f)
        local silver = { 0.86, 0.87, 0.84 }
        local barColor = { 0.16, 0.16, 0.15 }
        local bars = math.max(band(s, 0.10, 0.18, 0.04), band(s, 0.36, 0.48, 0.05), band(s, 0.68, 0.78, 0.05))
        local r, g, b = mix(silver, barColor, bars * f.barStrength)
        if v < 0.22 and s < 0.35 then
            local t = (1 - v / 0.22) * 0.5
            r, g, b = mix({ r, g, b }, { 0.92, 0.78, 0.48 }, t)
        end
        return r, g, b, 1
    end,
    fins = {
        caudal = { len = 0.36, height = 0.36, fork = 0.25, shape = "lyre", color = { 0.85, 0.86, 0.84 }, alpha = 0.40 },
        dorsal = { s0 = 0.20, s1 = 0.86, height = 0.70, rake = 1.05, peak = 0.82, lead = 0.10, trail = 0.05, color = { 0.82, 0.82, 0.80 }, alpha = 0.60, bars = true },
        anal = { s0 = 0.28, s1 = 0.86, height = 0.68, rake = 0.95, peak = 0.82, lead = 0.10, trail = 0.05, color = { 0.82, 0.82, 0.80 }, alpha = 0.60, bars = true },
        pectoral = { s = 0.25, len = 0.18, alpha = 0.22 },
        pelvic = { s = 0.30, len = 1.05, filament = true, alpha = 0.55 },
    },
    cruise = 20, burst = 120, turnRate = 1.5, accel = 50,
    zone = { 0.18, 0.62 }, school = false, sociable = 0.3,
    wave = { amp = 0.04, k = 3.5, freq = 1.5 },
}

--------------------------------------------------------------------------------
Species.cory = {
    label = "bronze corydoras",
    count = 3,
    length = 33, height = 0.42, thick = 0.18,
    top = { 0, 0.55, 0.88, 1.00, 0.95, 0.80, 0.58, 0.38, 0.32 },
    bot = { 0, 0.35, 0.50, 0.55, 0.55, 0.50, 0.42, 0.32, 0.28 },
    eye = { s = 0.14, r = 0.08, iris = { 0.75, 0.65, 0.35 } },
    colors = function(s, v, f)
        local bronze = { 0.46, 0.38, 0.24 }
        local flank = { 0.36 * f.irid, 0.44 * f.irid, 0.32 * f.irid }
        local belly = { 0.86, 0.80, 0.66 }
        local r, g, b
        if v < 0.3 then
            r, g, b = bronze[1], bronze[2], bronze[3]
        elseif v < 0.7 then
            r, g, b = mix(bronze, flank, band(s, 0.2, 0.95, 0.15))
        else
            r, g, b = mix(flank, belly, (v - 0.7) / 0.3)
        end
        if v < 0.75 and hash(floor(s * 16) + f.seed, floor(v * 7)) > 0.72 then
            r, g, b = r * 0.55, g * 0.55, b * 0.55
        end
        return r, g, b, 1
    end,
    fins = {
        caudal = { len = 0.30, height = 0.38, fork = 0.40, shape = "fork", color = { 0.80, 0.76, 0.66 }, alpha = 0.40, spots = true },
        dorsal = { s0 = 0.22, s1 = 0.36, height = 0.36, rake = 0.14, color = { 0.55, 0.50, 0.40 }, alpha = 0.55 },
        anal = { s0 = 0.62, s1 = 0.76, height = 0.12, rake = 0.06, color = { 0.80, 0.76, 0.66 }, alpha = 0.35 },
        pectoral = { s = 0.20, len = 0.22, alpha = 0.40 },
        pelvic = { s = 0.45, len = 0.13, alpha = 0.35 },
    },
    cruise = 16, burst = 140, turnRate = 3.0, accel = 90,
    zone = { 0.85, 1.0 }, bottom = true, school = false, sociable = 0.6,
    breathes = { interval = { 70, 160 } },
    wave = { amp = 0.06, k = 4.0, freq = 3.0 },
}

--------------------------------------------------------------------------------
local bettaColors = {
    { body = { 0.10, 0.20, 0.70 }, fin = { 0.75, 0.10, 0.20 }, edge = { 0.15, 0.35, 0.95 } },
    { body = { 0.70, 0.08, 0.14 }, fin = { 0.82, 0.10, 0.16 }, edge = { 0.95, 0.75, 0.70 } },
    { body = { 0.10, 0.45, 0.60 }, fin = { 0.12, 0.40, 0.70 }, edge = { 0.70, 0.95, 1.00 } },
}

Species.betta = {
    label = "betta",
    count = 1,
    length = 40, height = 0.30, thick = 0.13,
    top = { 0, 0.50, 0.80, 0.95, 1.00, 0.92, 0.75, 0.55, 0.48 },
    bot = { 0, 0.50, 0.80, 0.96, 1.00, 0.92, 0.75, 0.55, 0.48 },
    eye = { s = 0.10, r = 0.07, iris = { 0.30, 0.10, 0.10 } },
    setup = function(f)
        f.palette = bettaColors[math.random(#bettaColors)]
    end,
    colors = function(s, v, f)
        local c = f.palette.body
        local sheen = 0.85 + 0.3 * f.irid
        local dark = 0.75 + 0.25 * (1 - math.abs(v - 0.4))
        return c[1] * sheen * dark, c[2] * sheen * dark, c[3] * sheen * dark, 1
    end,
    fins = {
        caudal = { len = 0.85, height = 0.70, shape = "veil", alpha = 0.80, flowing = true },
        dorsal = { s0 = 0.45, s1 = 0.92, height = 0.45, rake = 0.45, peak = 0.55, lead = 0.4, trail = 0.7, alpha = 0.75, flowing = true },
        anal = { s0 = 0.38, s1 = 0.96, height = 0.62, rake = 0.45, peak = 0.6, lead = 0.35, trail = 0.8, alpha = 0.75, flowing = true },
        pectoral = { s = 0.20, len = 0.15, alpha = 0.30 },
        pelvic = { s = 0.30, len = 0.40, alpha = 0.70, filament = true },
    },
    finColor = function(f) return f.palette.fin, f.palette.edge end,
    cruise = 14, burst = 90, turnRate = 2.0, accel = 40,
    zone = { 0.05, 0.40 }, school = false, sociable = 0.1,
    breathes = { interval = { 25, 60 } },
    wave = { amp = 0.05, k = 3.0, freq = 1.8 },
}

--------------------------------------------------------------------------------
-- Sunset platies keep the original Fishbowl palette alive
local platyColors = {
    { 1.00, 0.45, 0.20 }, { 1.00, 0.65, 0.30 }, { 0.95, 0.35, 0.35 },
    { 0.85, 0.25, 0.45 }, { 1.00, 0.80, 0.40 },
}

Species.platy = {
    label = "sunset platy",
    count = 3,
    length = 38, height = 0.40, thick = 0.15,
    top = { 0, 0.50, 0.84, 1.00, 1.00, 0.86, 0.62, 0.44, 0.38 },
    bot = { 0, 0.48, 0.82, 1.00, 1.00, 0.86, 0.60, 0.42, 0.36 },
    eye = { s = 0.12, r = 0.075, iris = { 0.80, 0.60, 0.30 } },
    setup = function(f)
        f.color = platyColors[math.random(#platyColors)]
    end,
    colors = function(s, v, f)
        local c = f.color
        local warm = { math.min(1, c[1] * 1.05), c[2] * 0.75, c[3] * 0.6 }
        local r, g, b = mix(c, warm, s)
        if v < 0.15 then r, g, b = r * 0.72, g * 0.62, b * 0.6 end
        if v > 0.7 then r, g, b = mix({ r, g, b }, { 1.0, 0.92, 0.75 }, (v - 0.7) * 1.2) end
        return r, g, b, 1
    end,
    fins = {
        caudal = { len = 0.30, height = 0.36, fork = 0.0, shape = "round", alpha = 0.50, tint = true },
        dorsal = { s0 = 0.38, s1 = 0.58, height = 0.30, rake = 0.16, alpha = 0.50, tint = true },
        anal = { s0 = 0.58, s1 = 0.72, height = 0.16, rake = 0.08, alpha = 0.40, tint = true },
        pectoral = { s = 0.24, len = 0.17, alpha = 0.30 },
        pelvic = { s = 0.44, len = 0.12, alpha = 0.30 },
    },
    cruise = 28, burst = 150, turnRate = 2.8, accel = 90,
    zone = { 0.15, 0.75 }, school = false, sociable = 0.5,
    wave = { amp = 0.07, k = 4.5, freq = 2.6 },
}

Species.order = { "neon", "angel", "cory", "betta", "platy" }

return Species
