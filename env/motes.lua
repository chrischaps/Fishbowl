-- Suspended particulate: tiny motes drifting in the current, sparkling
-- when they cross a light shaft. Back motes sit behind the tank's life,
-- front motes drift between the fish and the glass.

local C = require("config")
local World = require("world")
local Current = require("env.current")
local Water = require("env.water")
local Render = require("fx.render")

local Motes = {}

local random = math.random
local sin = math.sin

local list = {}
local time = 0

local function respawn(m, anywhere)
    m.d = random()
    local lo, hi = World.xBounds(m.d, -20)
    m.x = lo + random() * (hi - lo)
    m.y = anywhere and (C.SURFACE_Y + 20 + random() * (C.FLOOR_Y - C.SURFACE_Y - 40)) or (C.FLOOR_Y - 30)
    m.size = 0.5 + random() ^ 3 * 1.8
    m.base = 0.06 + random() * 0.12
    m.phase = random() * 10
    m.sink = (random() - 0.6) * 3
end

function Motes.init(count)
    list = {}
    for i = 1, count or 130 do
        local m = {}
        respawn(m, true)
        list[i] = m
    end
end

function Motes.update(dt)
    time = time + dt
    for _, m in ipairs(list) do
        local cx, cy = Current.at(m.x, m.y, m.d)
        m.x = m.x + (cx * 0.35 + sin(time * 0.3 + m.phase) * 2) * dt
        m.y = m.y + (cy * 0.35 + m.sink + sin(time * 0.23 + m.phase * 1.7) * 1.5) * dt
        local floor = World.floorY(m.x, m.d)
        local lo, hi = World.xBounds(m.d, -30)
        if m.y < C.SURFACE_Y + 6 or m.y > floor or m.x < lo or m.x > hi then
            respawn(m, true)
        end
    end
end

local function drawRange(env, dMin, dMax)
    local lc = env.light
    for _, m in ipairs(list) do
        if m.d >= dMin and m.d < dMax then
            local sx, sy, k = World.project(m.x, m.y, m.d)
            local lit = Water.rayLight(sx, sy, env)
            local twinkle = 0.75 + 0.25 * sin(time * 1.3 + m.phase)
            local a = (m.base * (0.3 + 0.7 * env.light_i) + lit * 0.9) * twinkle
            local haze = World.haze(m.d) * 0.6
            love.graphics.setColor(
                lc[1] * (1 - haze) + env.fog[1] * haze,
                lc[2] * (1 - haze) + env.fog[2] * haze,
                lc[3] * (1 - haze) + env.fog[3] * haze, math.min(0.9, a))
            local r = m.size * k * (m.d > 0.9 and 1.6 or 1)
            if r > 1.2 then
                Render.drawBlob(sx, sy, r * 1.8)
            else
                love.graphics.circle("fill", sx, sy, r)
            end
        end
    end
end

function Motes.drawBack(env) drawRange(env, 0, 0.5) end
function Motes.drawFront(env) drawRange(env, 0.5, 1.01) end

return Motes
