-- Sea monkeys: a small colony of brine shrimp, the tiniest swimmers in the tank.
-- Each one rows along on its back, belly to the light as real ones do, with a
-- flicker of feathery legs: a short dart tilted upward, then a slow drift down.
-- They keep loosely together, follow the light across the tank as the day
-- turns, and crowd a passing flake without eating it. At night they sink lower
-- and rest longer between darts.
--
-- Each is a thing in the water, sorted by depth with the plants and the fish
-- (main.lua), so they pass in front of one leaf and behind the next.

local C = require("config")
local World = require("world")
local Current = require("env.current")
local Water = require("env.water")
local Render = require("fx.render")

local SeaMonkeys = {}

local random = math.random
local sin, cos, atan2, sqrt, abs, exp, pi = math.sin, math.cos, math.atan2, math.sqrt, math.abs, math.exp, math.pi
local clamp, lerp, smoothstep = World.clamp, World.lerp, World.smoothstep

local DEPTH = C.DEPTH_PX

-- How close to the tank's faces a body may come: far enough that nose and tail
-- stay inside at any angle (a sea monkey is about 18 px long)
local D_MIN, D_MAX = 0.06, 0.94
local WALL_GAP = 30      -- screen px, at the sides
local SURFACE_GAP = 20   -- world px, under the water surface
local FLOOR_GAP = 16     -- world px, above the sand and the rocks

local DRAG = 3.4         -- how fast a dart dies away (1/s)
local CURRENT = 0.45     -- how much the water carries them
local REACH = 240        -- how far off a flake is noticed (px)

local list = {}
local time = 0
local activity = 1       -- 0 asleep by moonlight .. 1 busy in full light
local colony = { x = 0, y = 0, d = 0.5 }

-- Pale salmon to amber: warm against the teal, and blue-grey under the moon
local tints = {
    { 0.98, 0.74, 0.62 }, { 0.98, 0.66, 0.60 }, { 0.96, 0.80, 0.58 }, { 1.00, 0.80, 0.70 },
}

SeaMonkeys.darts = 0     -- darts swum since init, for the self-test

--- The lowest world y a body may reach at (x, d): above the sand, and above
--- any rock it is passing over. Each rock is a hill with sloping sides, so a
--- sea monkey low in the water rises over it rather than popping up.
local function floorAt(x, d, rocks)
    local floor = World.floorY(x, d)
    for _, r in ipairs(rocks or {}) do
        local beyond = math.max(abs(x - r.x) - r.w * 0.6, abs((d - r.d) * DEPTH) - 40, 0)
        floor = math.min(floor, r.y - r.h + beyond * 1.5)
    end
    return floor - FLOOR_GAP
end

local function newSeaMonkey(cx, cy)
    local a = random() * pi * 2
    local r = sqrt(random()) * 150
    local home = 0.14 + random() * 0.8
    local lo, hi = World.xBounds(home, WALL_GAP)
    return {
        kind = "seamonkey",
        x = clamp(cx + cos(a) * r, lo, hi),
        y = clamp(cy + sin(a) * r * 0.6, C.SURFACE_Y + SURFACE_GAP, C.FLOOR_Y - 120),
        d = home,
        vx = 0, vy = 0, vd = 0,
        home = home,                       -- the depth it likes
        band = (random() - 0.5) * 120,     -- how high it likes to hang, relative to the others
        offset = (random() - 0.5) * 220,   -- where in the light it likes to be
        rest = random() * 1.5,
        sink = 3.5 + random() * 2.5,
        size = 0.95 + random() * 0.3,
        tint = tints[random(#tints)],
        eggs = random() < 0.35,            -- a brood pouch at the base of the tail
        phase = random() * 10,
        beat = random(),
        kick = 0,                          -- 1 just after a dart, fading
        face = random() < 0.5 and -1 or 1, -- -1 facing left .. 1 facing right, through a roll
        pitch = 0,
    }
end

function SeaMonkeys.init(count)
    list = {}
    time = 0
    SeaMonkeys.darts = 0
    local cx, cy = C.W * (0.35 + random() * 0.3), 200 + random() * 120
    for i = 1, count or C.SEAMONKEYS do
        list[i] = newSeaMonkey(cx, cy)
    end
    colony.x, colony.y, colony.d = cx, cy, 0.5
end

local function nearestFlake(m, foods)
    local best, bestD = nil, REACH
    for _, f in ipairs(foods or {}) do
        if not f.eaten and f.state ~= "settled" then
            local dx, dy, dz = f.x - m.x, f.y - m.y, (f.d - m.d) * DEPTH
            local dist = sqrt(dx * dx + dy * dy + dz * dz)
            if dist < bestD then best, bestD = f, dist end
        end
    end
    return best, bestD
end

-- A dart: pick a way to go, mostly upward, from everything this one wants
local function dart(m, ctx)
    local env = ctx.env
    local gx, gy, gz = 0, 0, 0

    -- A restless wander, mostly level
    local a = random() * pi * 2
    gx, gz = cos(a) * 0.7, sin(a) * 0.7

    -- Back toward the others once too far out; a looser crowd at night
    local dx, dy, dz = colony.x - m.x, colony.y - m.y, (colony.d - m.d) * DEPTH
    local dist = sqrt(dx * dx + dy * dy + dz * dz) + 0.001
    local pull = math.max(0, dist - lerp(170, 105, activity)) / 110
    gx, gy, gz = gx + dx / dist * pull, gy + dy / dist * pull, gz + dz / dist * pull * 0.5

    -- ...but not on top of anyone
    for _, n in ipairs(list) do
        if n ~= m then
            local ox, oy, oz = m.x - n.x, m.y - n.y, (m.d - n.d) * DEPTH
            local o2 = ox * ox + oy * oy + oz * oz
            if o2 < 26 * 26 and o2 > 0.01 then
                local o = sqrt(o2)
                local push = (26 - o) / 26 * 1.2
                gx, gy, gz = gx + ox / o * push, gy + oy / o * push, gz + oz / o * push
            end
        end
    end

    -- Toward the light: along under the brightest pool, a drifting patch of it
    -- by day. By moonlight the pull is faint and they hang lower.
    local lightX = World.unproject(env.sun_x + m.offset + sin(time * 0.04 + 1.3) * 170, 0, m.d)
    local wantY = lerp(440, 170, activity) + m.band
    gx = gx + clamp((lightX - m.x) / 260, -1, 1) * (0.25 + 0.75 * activity)
    gz = gz + clamp((m.home - m.d) * DEPTH / 110, -1, 1)

    -- Every dart tilts upward. How much depends on how far below where it
    -- wants to be; only the slow sink between darts ever takes one down.
    local up = 0.5 + 0.5 * clamp((m.y - wantY) / 120, -0.8, 1)

    -- A flake in reach outweighs all that
    local flake, flakeD = nearestFlake(m, ctx.foods)
    local eager = 0
    if flake then
        eager = 1
        local n = flakeD + 0.001
        local w = 2.4 * clamp(n / 30, 0.25, 1)  -- close by, it only fusses around it
        gx = gx + (flake.x - m.x) / n * w
        gy = gy + (flake.y - m.y) / n * w
        gz = gz + (flake.d - m.d) * DEPTH / n * w
        up = up * 0.25
    end
    gy = gy - up

    -- Keep off the faces of the tank
    local lo, hi = World.xBounds(m.d, WALL_GAP + 40)
    if m.x < lo then gx = gx + 1.4 elseif m.x > hi then gx = gx - 1.4 end
    if m.y < C.SURFACE_Y + SURFACE_GAP + 34 and not flake then gy = gy + 1.6 end
    if m.y > floorAt(m.x, m.d, ctx.rocks) - 40 then gy = gy - 1.6 end
    if m.d < D_MIN + 0.05 then gz = gz + 1 elseif m.d > D_MAX - 0.05 then gz = gz - 1 end

    local n = sqrt(gx * gx + gy * gy + gz * gz) + 0.001
    local speed = (40 + random() * 34) * lerp(0.42, 1, activity) * (1 + eager * 0.35)
    m.vx = m.vx * 0.3 + gx / n * speed
    m.vy = m.vy * 0.3 + gy / n * speed
    m.vd = m.vd * 0.3 + gz / n * speed

    m.kick = 1
    local a0, a1 = lerp(2.6, 0.5, activity), lerp(6.5, 1.8, activity)
    m.rest = (a0 + random() * (a1 - a0)) * (1 - eager * 0.55)
    SeaMonkeys.darts = SeaMonkeys.darts + 1
end

function SeaMonkeys.update(dt, ctx)
    time = time + dt
    local env = ctx.env
    activity = smoothstep(0.30, 0.85, env.light_i)

    local sx, sy, sd = 0, 0, 0
    for _, m in ipairs(list) do sx, sy, sd = sx + m.x, sy + m.y, sd + m.d end
    local count = math.max(1, #list)
    colony.x, colony.y, colony.d = sx / count, sy / count, sd / count

    local drag = exp(-dt * DRAG)
    for _, m in ipairs(list) do
        m.rest = m.rest - dt
        if m.rest <= 0 then dart(m, ctx) end

        m.vx = m.vx * drag
        m.vy = m.vy * drag + m.sink * lerp(0.7, 1, activity) * (1 - drag)
        m.vd = m.vd * drag

        local cx, cy = Current.at(m.x, m.y, m.d)
        m.x = m.x + (m.vx + cx * CURRENT) * dt
        m.y = m.y + (m.vy + cy * CURRENT) * dt
        m.d = m.d + m.vd / DEPTH * dt

        -- The glass, the sand and the surface are not to be argued with
        if m.d < D_MIN then m.d, m.vd = D_MIN, 0 elseif m.d > D_MAX then m.d, m.vd = D_MAX, 0 end
        local lo, hi = World.xBounds(m.d, WALL_GAP)
        if m.x < lo then m.x, m.vx = lo, 0 elseif m.x > hi then m.x, m.vx = hi, 0 end
        local top, floor = C.SURFACE_Y + SURFACE_GAP, floorAt(m.x, m.d, ctx.rocks)
        if m.y < top then m.y, m.vy = top, 0 elseif m.y > floor then m.y, m.vy = floor, 0 end

        -- The pose follows the swim: legs race in a dart and idle in a drift, a
        -- swimmer heading for the glass or away from it is foreshortened, and
        -- one changing direction rolls over through edge-on.
        m.kick = m.kick * exp(-dt * 4.5)
        m.beat = m.beat + dt * (lerp(1.2, 3.6, activity) + m.kick * 11)
        local across = sqrt(m.vx * m.vx + m.vy * m.vy)
        local speed = sqrt(across * across + m.vd * m.vd)
        if speed > 5 then
            local side = abs(m.vx) > 1.5 and (m.vx > 0 and 1 or -1) or (m.face >= 0 and 1 or -1)
            m.face = m.face + (side * math.max(0.5, across / speed) - m.face) * math.min(1, dt * 9)
            local want = clamp(atan2(m.vy, abs(m.vx)), -1.15, 1.15)
            m.pitch = m.pitch + (want - m.pitch) * math.min(1, dt * 8)
        else
            -- Hanging in the water, nose a little up, breathing with the current
            local want = -0.22 + sin(time * 0.7 + m.phase) * 0.1
            m.pitch = m.pitch + (want - m.pitch) * math.min(1, dt * 1.6)
        end
    end
end

function SeaMonkeys.all() return list end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
-- A row of legs as one zigzag line, each leg a stroke out and a stroke back,
-- rippling from head to tail: the fringe reads as feathers at this size.
local LEGS = 5
local LEG_ROOT, LEG_GAP = 4.3, 1.75
local fringe = {}
local function drawLegs(m, shift, reach)
    local n = 0
    for i = 0, LEGS - 1 do
        local x = LEG_ROOT - i * LEG_GAP
        local ph = (m.beat + shift) * pi * 2 - i * 1.25
        local long = reach * (0.72 + 0.28 * sin((i + 0.5) / LEGS * pi))
        fringe[n + 1], fringe[n + 2] = x, -0.5
        fringe[n + 3] = x - 0.7 + sin(ph) * 1.5
        fringe[n + 4] = -0.5 - long * (0.74 + 0.26 * cos(ph))
        n = n + 4
    end
    fringe[n + 1], fringe[n + 2] = LEG_ROOT - LEGS * LEG_GAP, -0.5
    love.graphics.line(fringe)
end

-- The body is drawn in its own little space: 1 unit is about 1 px, the head at
-- +x, the belly and legs toward -y, the thorax at the origin.
function SeaMonkeys.draw(m, env)
    local g = love.graphics
    local sx, sy, k = World.project(m.x, m.y, m.d)
    local t = m.tint

    -- Translucent, and dimmer by moonlight on top of what the shader does;
    -- crossing a light shaft they catch it, like the motes do
    local lit = Water.rayLight(sx, sy, env)
    local a = lerp(0.62, 1, activity)
    local glow = math.min(0.7, lit * 1.1)
    local lc = env.light
    local r = lerp(t[1], lc[1], glow)
    local gr = lerp(t[2], lc[2], glow)
    local b = lerp(t[3], lc[3], glow)

    local join = g.getLineJoin()
    g.setLineJoin("none")
    g.push()
    g.translate(sx, sy)
    local f = m.face
    g.rotate(m.pitch * clamp(f * 3, -1, 1))
    local scale = k * m.size
    g.scale(scale * (f >= 0 and 1 or -1) * math.max(abs(f), 0.3), scale)

    -- The tail bends behind it, snapping with a dart and swaying at rest
    local sway = sin(time * (1.4 + m.kick * 9) + m.phase) * (0.5 + m.kick * 1.3)
    local function spine(x)
        local u = (1 - x) / 9
        return x, u * u * sway * 2.2
    end

    -- A faint body of light around it all
    g.setColor(r, gr, b, (0.10 + glow * 0.3) * a)
    Render.drawBlob(-1, 0, 10, 3.4)
    if m.eggs then
        g.setColor(0.74, 0.38, 0.18, 0.8 * a)
        local ex, ey = spine(-3)
        Render.drawBlob(ex, ey - 1, 2.6, 2)
    end

    -- Forked tail
    local x4, y4 = spine(-8)
    local fan = 1.6 + sin(m.beat * pi * 2) * 0.3
    g.setLineWidth(0.7)
    g.setColor(r, gr, b, 0.6 * a)
    g.line(x4, y4, x4 - 3.4, y4 + sway * 0.8 - fan)
    g.line(x4, y4, x4 - 3.4, y4 + sway * 0.8 + fan)

    -- Abdomen: long, thin, tapering to the fork
    local x1, y1 = spine(1)
    local x2, y2 = spine(-2)
    local x3, y3 = spine(-5)
    g.setLineWidth(1.25)
    g.setColor(r, gr, b, 0.5 * a)
    g.line(x1, y1, x2, y2, x3, y3)
    g.setLineWidth(0.9)
    g.line(x3, y3, x4, y4)

    -- Thorax and head
    g.setLineWidth(1.9)
    g.setColor(r, gr, b, 0.55 * a)
    g.line(-1, y1 * 0.4, 4, 0)
    g.setLineWidth(1.5)
    g.line(4, 0, 5.6, 0)

    -- Both rows of legs: the far row fainter and half a beat behind
    g.setLineWidth(0.6)
    local shimmer = 0.5 + m.kick * 0.3
    g.setColor(r, gr, b, shimmer * 0.5 * a)
    drawLegs(m, 0.5, 3.4)
    g.setColor(lerp(r, 1, 0.3), lerp(gr, 1, 0.3), lerp(b, 1, 0.3), shimmer * a)
    drawLegs(m, 0, 4.4)

    -- The gut shows through, olive with the algae it has eaten
    g.setLineWidth(0.65)
    g.setColor(0.34, 0.30, 0.10, 0.8 * a)
    g.line(4.2, 0, x1, y1, x2, y2, x3, y3, x4 + 0.8, y4)

    -- Two eyes on stalks
    g.setLineWidth(0.5)
    g.setColor(r, gr, b, 0.7 * a)
    g.line(5.2, -0.3, 6.6, -2.0)
    g.line(5.2, 0.3, 6.6, 2.0)
    g.setColor(0.03, 0.02, 0.02, lerp(0.75, 1, activity))
    Render.drawBlob(6.8, -2.1, 1.7)
    Render.drawBlob(6.8, 2.1, 1.7)

    g.pop()
    g.setLineWidth(1)
    g.setLineJoin(join)
end

return SeaMonkeys
