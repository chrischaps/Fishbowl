-- Flake food: sprinkled on the surface, it floats a moment, then tumbles
-- down. Whatever the fish miss settles on the sand for the corydoras.

local C = require("config")
local World = require("world")
local Current = require("env.current")

local Food = {}

local random = math.random
local sin, cos, abs = math.sin, math.cos, math.abs

local list = {}
local events = {}

local flakeColors = {
    { 0.86, 0.36, 0.22 }, { 0.92, 0.74, 0.32 }, { 0.48, 0.62, 0.26 },
    { 0.76, 0.46, 0.30 }, { 0.62, 0.30, 0.24 }, { 0.90, 0.58, 0.28 },
}

local function flakeShape(size)
    local pts = {}
    local n = random(4, 6)
    for i = 1, n do
        local a = (i / n) * math.pi * 2 + (random() - 0.5) * 0.6
        local r = size * (0.6 + random() * 0.5)
        pts[#pts + 1] = cos(a) * r
        pts[#pts + 1] = sin(a) * r
    end
    return pts
end

-- The most flakes in the water at once. A wall frame has guests who tap and
-- tap; past this the tank has had enough, and a pinch does nothing.
Food.MAX = 300

--- Sprinkle a pinch of flakes at screen x
function Food.sprinkle(sx)
    local n = math.min(random(6, 10), Food.MAX - #list)
    if n <= 0 then return end
    for _ = 1, n do
        local d = 0.5 + random() * 0.45
        local wx = World.unproject(sx + (random() - 0.5) * 50, 0, d)
        local size = 1.8 + random() * 2.0
        list[#list + 1] = {
            kind = "food", x = wx, y = C.SURFACE_Y + 2, d = d,
            state = "float", timer = 0.8 + random() * 3.5,
            rot = random() * 6.28, spin = (random() - 0.5) * 4,
            sink = 12 + random() * 9, vy = 0,
            size = size, shape = flakeShape(size),
            color = flakeColors[random(#flakeColors)],
            life = 0, alpha = 1,
        }
    end
    events[#events + 1] = { type = "sprinkle", x = sx }
end

function Food.update(dt)
    for i = #list, 1, -1 do
        local f = list[i]
        f.life = f.life + dt
        if f.eaten then
            table.remove(list, i)
        elseif f.state == "float" then
            local cx = Current.at(f.x, f.y, f.d)
            f.x = f.x + cx * 0.5 * dt
            f.y = C.SURFACE_Y + 2 + sin(f.life * 2 + f.rot) * 0.8
            f.timer = f.timer - dt
            if f.timer <= 0 then f.state = "sink" end
        elseif f.state == "sink" then
            local cx, cy = Current.at(f.x, f.y, f.d)
            f.rot = f.rot + f.spin * dt
            f.vy = f.vy + (f.sink - f.vy) * math.min(1, dt * 2)
            -- A falling flake slips sideways as it tilts
            f.x = f.x + (sin(f.rot) * 9 + cx * 0.4) * dt
            f.y = f.y + (f.vy + cy * 0.2) * dt * (0.75 + 0.25 * abs(cos(f.rot)))
            local floor = World.floorY(f.x, f.d) - 1
            if f.y >= floor then
                f.y = floor
                f.state = "settled"
                f.timer = 40 + random() * 20
            end
        elseif f.state == "settled" then
            f.timer = f.timer - dt
            if f.timer < 5 then f.alpha = math.max(0, f.timer / 5) end
            if f.timer <= 0 then table.remove(list, i) end
        end
    end
end

function Food.all() return list end

function Food.drainEvents()
    local e = events
    events = {}
    return e
end

function Food.draw(f, env)
    local sx, sy, k = World.project(f.x, f.y, f.d)
    local c = f.color
    local tilt = f.state == "settled" and 0.45 or (0.25 + 0.75 * abs(cos(f.rot)))
    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(f.rot * 0.3)
    love.graphics.scale(k, k * tilt)
    love.graphics.setColor(c[1], c[2], c[3], 0.95 * f.alpha)
    love.graphics.polygon("fill", f.shape)
    love.graphics.setColor(1, 0.95, 0.85, 0.25 * f.alpha)
    love.graphics.circle("fill", -f.size * 0.2, -f.size * 0.2, f.size * 0.35)
    love.graphics.pop()
end

return Food
