-- Bubbles: the air-stone column, oxygen pearls from plants, and breaths
-- from fish. Rendered as real bubbles look underwater: a bright rim and
-- highlight around an almost invisible body. They pop at the surface.

local C = require("config")
local World = require("world")
local Current = require("env.current")
local Render = require("fx.render")

local Bubble = {}

local random = math.random
local sin = math.sin

local list = {}
local pops = {}
local stoneTimer = 0

function Bubble.spawn(x, y, d, r, kind)
    list[#list + 1] = {
        kind = "bubble", x = x, y = y, d = d, r = r, source = kind or "stone",
        t = 0, phase = random() * 10, wobble = 6 + random() * 9,
        wobbleSpeed = 5 + random() * 5, vx = 0,
    }
end

function Bubble.update(dt, env)
    -- The air stone: a fine, steady column
    stoneTimer = stoneTimer - dt
    while stoneTimer <= 0 do
        stoneTimer = stoneTimer + 1 / 22
        local r = random() < 0.85 and (0.9 + random() * 1.6) or (2.2 + random() * 2.2)
        local floor = World.floorY(C.BUBBLER_X, C.BUBBLER_D) - 6
        Bubble.spawn(C.BUBBLER_X + (random() - 0.5) * 8, floor, C.BUBBLER_D + (random() - 0.5) * 0.02, r, "stone")
    end

    for i = #list, 1, -1 do
        local b = list[i]
        b.t = b.t + dt
        local rise = 22 + b.r * 15
        local cx, cy = Current.at(b.x, b.y, b.d)
        -- Small bubbles zigzag; larger ones rock and spiral
        local zig = sin(b.t * b.wobbleSpeed + b.phase) * b.wobble * (0.4 + b.r * 0.15)
        b.vx = b.vx + (cx * 0.6 + zig - b.vx) * math.min(1, dt * 3)
        b.x = b.x + b.vx * dt
        b.y = b.y + (cy * 0.3 - rise) * dt
        if b.y <= C.SURFACE_Y + b.r then
            pops[#pops + 1] = { x = b.x, d = b.d, r = b.r }
            table.remove(list, i)
        end
    end
end

function Bubble.drainPops()
    local p = pops
    pops = {}
    return p
end

function Bubble.all() return list end

function Bubble.draw(b, env)
    local sx, sy, k = World.project(b.x, b.y, b.d)
    local r = b.r * k
    local lr, lg, lb = 0.85 + env.light[1] * 0.15, 0.95, 1.0
    if r < 1.4 then
        love.graphics.setColor(lr, lg, lb, 0.55)
        love.graphics.circle("fill", sx, sy, math.max(0.7, r))
        return
    end
    local wob = sin(b.t * 9 + b.phase) * math.min(0.14, b.r * 0.03)
    local rx, ry = r * (1 + wob), r * (1 - wob) * 0.94

    love.graphics.setColor(lr, lg, lb, 0.07)
    love.graphics.ellipse("fill", sx, sy, rx, ry)
    love.graphics.setLineWidth(0.6)
    love.graphics.setColor(0.05, 0.1, 0.15, 0.18)
    love.graphics.ellipse("line", sx, sy, rx * 0.72, ry * 0.72)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(lr, lg, lb, 0.62)
    love.graphics.ellipse("line", sx, sy, rx, ry)
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.circle("fill", sx - rx * 0.36, sy - ry * 0.4, r * 0.26)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle("fill", sx + rx * 0.34, sy + ry * 0.42, r * 0.14)
end

return Bubble
