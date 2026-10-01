-- Water circulation driven by the air-stone bubbler: an upwelling column,
-- outflow along the surface, a slow return along the floor, and a little
-- turbulence. Bubbles, food, motes and plants all sample the same field.

local C = require("config")

local Current = {}

local time = 0
local exp, sin, cos = math.exp, math.sin, math.cos

function Current.update(dt)
    time = time + dt
end

--- Flow velocity (px/s) at world position x, y (depth only weakens it)
function Current.at(x, y, d)
    local dx = x - C.BUBBLER_X
    local adx = math.abs(dx)
    local side = dx >= 0 and 1 or -1
    local near = exp(-((d or 0.5) - C.BUBBLER_D) ^ 2 * 3)

    local vx, vy = 0, 0

    -- Upwelling over the air stone
    local column = exp(-(dx / 55) ^ 2)
    vy = vy - 34 * column * near

    -- Outflow along the surface, fading with distance from the column
    local surf = exp(-((y - C.SURFACE_Y) / 70) ^ 2)
    vx = vx + side * 22 * surf * exp(-adx / 900) * (1 - column)

    -- Slow return along the floor
    local floor = exp(-((C.FLOOR_Y - y) / 90) ^ 2)
    vx = vx - side * 7 * floor * exp(-adx / 1100)

    -- Lazy tank-wide drift and turbulence
    vx = vx + 3.5 * sin(time * 0.05 + y * 0.004)
    vx = vx + 2.5 * sin(x * 0.021 + time * 0.7) * cos(y * 0.017 - time * 0.5)
    vy = vy + 1.8 * cos(x * 0.015 - time * 0.6) * sin(y * 0.019 + time * 0.4)

    return vx, vy
end

return Current
