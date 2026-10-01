-- Projection and tank geometry helpers

local C = require("config")

local World = {}

local sin = math.sin

--- Projected scale at depth d
function World.k(d)
    return C.K_BACK + (1 - C.K_BACK) * d
end

--- World (x, y, d) -> screen x, y, scale
function World.project(x, y, d)
    local k = C.K_BACK + (1 - C.K_BACK) * d
    return C.CX + (x - C.CX) * k, C.CY + (y - C.CY) * k, k
end

--- Screen (sx, sy) at depth d -> world x, y
function World.unproject(sx, sy, d)
    local k = C.K_BACK + (1 - C.K_BACK) * d
    return C.CX + (sx - C.CX) / k, C.CY + (sy - C.CY) / k
end

--- World y of the substrate top at (x, d)
function World.floorY(x, d)
    local back = 1 - d
    return C.FLOOR_Y - C.FLOOR_RISE * back ^ 1.3
        + 5 * sin(x * 0.0061 + d * 3.1)
        + 3 * sin(x * 0.0173 - d * 5.3 + 1.3)
end

--- Screen y of the substrate top at the front glass
function World.frontFloorScreenY(sx)
    return World.floorY(sx, 1)
end

--- Screen y of the water surface at depth d (flat, without waves)
function World.surfaceScreenY(d)
    local _, sy = World.project(0, C.SURFACE_Y, d)
    return sy
end

--- How much distance-haze to apply at depth d (0..1, before day-cycle scaling)
function World.haze(d)
    return (1 - d) ^ 1.6
end

--- World x range that stays on screen at depth d with a screen-space margin
function World.xBounds(d, margin)
    local k = World.k(d)
    return C.CX + (margin - C.CX) / k, C.CX + (C.W - margin - C.CX) / k
end

function World.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function World.lerp(a, b, t)
    return a + (b - a) * t
end

function World.smoothstep(e0, e1, x)
    local t = World.clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
end

return World
