-- The front glass: a faint film of algae, a nerite snail grazing it clean,
-- a soft glare streak, and the ripple of a tap.

local C = require("config")
local World = require("world")
local Render = require("fx.render")

local Glass = {}

local random = math.random
local sin, cos, atan2, pi = math.sin, math.cos, math.atan2, math.pi

local algae
local snail
local tap = { x = 0, y = 0, age = 10, strength = 0 }
local time = 0
local regrow = 0

local function speck(x, y)
    local g = 0.35 + random() * 0.25
    love.graphics.setColor(0.25 + random() * 0.1, g, 0.12, 0.03 + random() * 0.07)
    love.graphics.circle("fill", x, y, 0.6 + random() ^ 2 * 2.2)
end

local function seedAlgae()
    algae = love.graphics.newCanvas(C.W, C.H)
    love.graphics.push("all")
    love.graphics.setCanvas(algae)
    love.graphics.clear(0, 0, 0, 0)
    -- Algae favors the corners and the lit band below the waterline
    for _ = 1, 1600 do
        local x, y
        local r = random()
        if r < 0.35 then
            x, y = random() * C.W, C.SURFACE_Y + 30 + random() ^ 2 * 120
        elseif r < 0.6 then
            local left = random() < 0.5
            x = left and random() ^ 2 * 220 or C.W - random() ^ 2 * 220
            y = C.SURFACE_Y + random() * (C.H - C.SURFACE_Y)
        else
            x, y = random() * C.W, C.FLOOR_Y - random() ^ 2 * 90
        end
        speck(x, y)
    end
    love.graphics.pop()
end

local function newSnail()
    return {
        x = 120 + random() * (C.W - 240), y = 200 + random() * 300,
        heading = random() * pi * 2, turn = 0,
        speed = 0, pause = 2, t = 0,
        size = 1.0,
    }
end

function Glass.init()
    seedAlgae()
    snail = newSnail()
end

function Glass.tap(x, y)
    tap.x, tap.y, tap.age, tap.strength = x, y, 0, 1
end

function Glass.tapUniform()
    if tap.age > 1.6 then return { 0, 0, 0, 0 } end
    return { tap.x, tap.y, tap.age, tap.strength }
end

function Glass.update(dt)
    time = time + dt
    tap.age = tap.age + dt

    -- Snail: slow wandering, frequent pauses to graze
    local s = snail
    s.t = s.t + dt
    if s.pause > 0 then
        s.pause = s.pause - dt
        s.speed = s.speed * (1 - dt * 2)
    else
        s.speed = s.speed + (4.5 - s.speed) * dt
        if random() < dt * 0.08 then s.pause = 3 + random() * 8 end
    end
    s.turn = s.turn + (random() - 0.5) * dt * 0.8
    s.turn = s.turn * (1 - dt * 0.3)
    s.heading = s.heading + s.turn * dt
    -- Stay on the glass, below the waterline and above the gravel
    local top, bottom = C.SURFACE_Y + 40, C.H - 26
    local cx, cy = C.W / 2, (top + bottom) / 2
    if s.x < 60 or s.x > C.W - 60 or s.y < top or s.y > bottom then
        local want = atan2(cy - s.y, cx - s.x)
        local diff = (want - s.heading + pi) % (2 * pi) - pi
        s.heading = s.heading + diff * dt * 0.6
    end
    s.x = s.x + cos(s.heading) * s.speed * dt
    s.y = s.y + sin(s.heading) * s.speed * dt

    -- The snail grazes the algae it passes over
    if algae then
        love.graphics.push("all")
        love.graphics.setCanvas(algae)
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Render.inverseBlob(), s.x, s.y, 0, 15 / 32, 15 / 32, 32, 32)

        -- ...and slowly the algae comes back
        regrow = regrow + dt
        if regrow > 0.5 then
            regrow = 0
            love.graphics.setBlendMode("alpha")
            for _ = 1, 3 do speck(random() * C.W, C.SURFACE_Y + random() * (C.H - C.SURFACE_Y)) end
        end
        love.graphics.pop()
    end
end

local function drawSnail(env)
    local s = snail
    local amb = env.ambient
    local function col(r, g, b, a)
        love.graphics.setColor(r * amb[1], g * amb[2], b * amb[3], a or 1)
    end
    love.graphics.push()
    love.graphics.translate(s.x, s.y)
    love.graphics.rotate(s.heading)
    love.graphics.scale(0.62)

    -- Shell behind the foot: a zebra nerite seen from below
    col(0.20, 0.17, 0.10, 0.95)
    love.graphics.ellipse("fill", -3, 0, 20, 17)
    love.graphics.setLineWidth(2.2)
    for i = 0, 6 do
        local a = -1.2 + i * 0.4
        col(0.75, 0.62, 0.22, 0.75)
        love.graphics.arc("line", "open", -3, 0, 15 + (i % 2) * 3, a, a + 0.22)
    end
    love.graphics.setLineWidth(1)
    col(0.10, 0.08, 0.05, 0.6)
    love.graphics.ellipse("line", -3, 0, 20, 17)

    -- Foot pressed on the glass, with muscular waves running along it
    col(0.62, 0.58, 0.52, 0.88)
    love.graphics.ellipse("fill", 1, 0, 15, 9.5)
    local glide = s.t * (0.6 + s.speed * 0.5)
    for i = 0, 5 do
        local u = ((i / 6 + glide) % 1)
        local x = -13 + u * 26
        col(0.40, 0.37, 0.33, 0.35 * sin(u * pi))
        love.graphics.ellipse("fill", x, 0, 1.6, 8.2 * sin(math.acos(math.max(-1, math.min(1, (x - 1) / 15)))))
    end
    col(0.85, 0.82, 0.76, 0.3)
    love.graphics.ellipse("line", 1, 0, 15, 9.5)

    -- Head, mouth working the glass, tentacles
    col(0.55, 0.50, 0.45, 0.95)
    love.graphics.ellipse("fill", 15, 0, 5, 6)
    local chew = 0.5 + 0.5 * sin(s.t * 5)
    col(0.25, 0.18, 0.15, 0.8)
    love.graphics.ellipse("fill", 17, 0, 1.4 + chew * 0.8, 2.2 + chew)
    love.graphics.setLineWidth(1.6)
    col(0.50, 0.46, 0.42, 0.9)
    local wave = sin(s.t * 1.3) * 0.15
    for side = -1, 1, 2 do
        local a = side * (0.55 + wave * side)
        love.graphics.line(18, side * 3, 18 + cos(a) * 11, side * 3 + sin(a) * 11)
    end
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

--- Everything on (and in) the glass, drawn over the tank
function Glass.draw(env, mouseX)
    love.graphics.setColor(env.ambient[1] * 0.9 + 0.1, env.ambient[2] * 0.9 + 0.1, env.ambient[3] * 0.9 + 0.1, 1)
    love.graphics.draw(algae)
    drawSnail(env)

    -- Glare: a soft diagonal sheen that shifts a little as you move
    local par = ((mouseX or C.W / 2) - C.W / 2) * 0.04
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    local glare = 0.035 * (0.3 + 0.7 * env.lamp)
    for i, g in ipairs({ { x = 330, w = 90, a = 1 }, { x = 470, w = 26, a = 0.7 }, { x = 980, w = 50, a = 0.45 } }) do
        love.graphics.setColor(1, 1, 1, glare * g.a)
        love.graphics.push()
        love.graphics.translate(g.x + par * (1 + i * 0.3), C.H / 2)
        love.graphics.shear(-0.55, 0)
        Render.drawBlob(0, 0, g.w, C.H * 0.75)
        love.graphics.pop()
    end
    love.graphics.pop()
end

return Glass
