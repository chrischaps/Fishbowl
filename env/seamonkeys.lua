-- Sea monkeys: a loose drift of brine shrimp. Each one hops in a short dart,
-- tilted up, then hangs and sinks while its legs slow. Like real Artemia they
-- swim on their backs, so the legs are always on the side toward the light.
--
-- They keep together loosely, follow the light across the tank through the
-- day, and turn toward falling flakes without eating them. A fish that
-- comes too close scatters the ones it nears. By night they sink lower and
-- hardly stir.
--
-- Unlike the motes they aren't split into a back and a front pass: each one
-- goes in main.lua's painter's list by its depth, as the fish and the flakes
-- do. That's what puts one between two plants, and blurs one past C.FAR_D.

local C = require("config")
local World = require("world")
local Current = require("env.current")
local Water = require("env.water")
local Render = require("fx.render")

local SeaMonkeys = {}

local random = math.random
local sin, cos, sqrt, exp, abs = math.sin, math.cos, math.sqrt, math.exp, math.abs
local min, max = math.min, math.max
local clamp, smoothstep = World.clamp, World.smoothstep

local SPINE = 6          -- points along the body, head first
local MAX_L = 21         -- longest body (world px); the margins below allow for it
local EDGE = MAX_L + 4   -- closest a head comes to the edge of the screen
local TOP = MAX_L + 6    -- ...to the surface
local BOTTOM = MAX_L + 9 -- ...to the sand
local D_LO, D_HI = 0.06, 0.94 -- ...to the back and front glass (a body is about 0.05 of depth)
local BAND = 46          -- how far out from those limits they start to turn back

local DRAG = 2.4         -- how quickly a dart dies away (1/s)
local LOOSE = 95         -- how far from the others one may stray before it minds
local ELBOW = 32         -- how close another may come before it minds that
local SMELL = 190        -- how far off a falling flake is noticed
local NOSE = 45          -- how close one comes to a flake before it's close enough

-- Half the body's width at each spine point, as a share of its length
local WIDTH = { 0.075, 0.120, 0.105, 0.065, 0.042, 0.022 }
local LEGS = 7

local tints = {
    { 0.99, 0.70, 0.50 }, -- peach
    { 0.98, 0.58, 0.46 }, -- coral
    { 0.99, 0.82, 0.56 }, -- pale gold
    { 0.99, 0.68, 0.64 }, -- shell pink
}

local list = {}
local time = 0
local darts = 0
local bodyMesh
local bodyVerts = {}
local px, py = {}, {}

--- How lively the tank's light makes them: about 0.3 by moonlight, 1 by day
function SeaMonkeys.vigor(env)
    return 0.3 + 0.7 * smoothstep(0.28, 0.9, env.light_i)
end

local function limits(x, d)
    local lo, hi = World.xBounds(d, EDGE)
    return lo, hi, C.SURFACE_Y + TOP, World.floorY(x, d) - BOTTOM
end

local function newBody()
    local s = {
        kind = "seamonkey",
        L = 13 + random() * (MAX_L - 13),
        tint = tints[random(#tints)],
        home = 0, -- the depth this one keeps to
        level = (random() - 0.5) * 130, -- and how far above or below the others it hangs
        sink = 4.5 + random() * 2.5,
        phase = random() * 10,
        brood = random() < 0.3,
        vx = 0, vy = 0, vz = 0,
        hx = random() < 0.5 and -1 or 1, hy = 0, hz = 0, -- which way it faces
        side = 1, -- which side its legs are on: they roll over as it turns
        kick = 0, -- 1 just after a dart, falling to 0
        beat = random() * 10,
        wait = random() * 2,
        scared = 0,
        lit = 0,
        dirs = {},
        spine = {},
    }
    for i = 1, SPINE do
        s.dirs[i] = { x = s.hx, y = 0, z = 0 }
        s.spine[i] = { x = 0, y = 0, d = 0 }
    end
    return s
end

local function layBody(s)
    local seg = s.L / (SPINE - 1)
    local p = s.spine[1]
    p.x, p.y, p.d = s.x, s.y, s.d
    for i = 2, SPINE do
        local a, u, q = s.spine[i - 1], s.dirs[i - 1], s.spine[i]
        q.x = a.x - u.x * seg
        q.y = a.y - u.y * seg
        q.d = a.d - u.z * seg / C.DEPTH_PX
    end
end

local function buildMesh()
    if bodyMesh then return end
    for i = 1, SPINE * 3 do bodyVerts[i] = { 0, 0, 0, 0, 1, 1, 1, 1 } end
    bodyMesh = love.graphics.newMesh(SPINE * 3, "triangles", "stream")
    local map = {}
    for i = 0, SPINE - 2 do
        local a = i * 3
        for _, v in ipairs({ a + 1, a + 2, a + 5, a + 1, a + 5, a + 4, a + 2, a + 3, a + 6, a + 2, a + 6, a + 5 }) do
            map[#map + 1] = v
        end
    end
    bodyMesh:setVertexMap(map)
end

function SeaMonkeys.init(count)
    buildMesh()
    list = {}
    local n = count or C.SEAMONKEYS
    for i = 1, n do
        local s = newBody()
        -- spread evenly through the water, so some are always behind the
        -- plants and some before them
        s.home = 0.12 + 0.78 * (i - 0.5 + (random() - 0.5) * 0.6) / n
        s.d = s.home
        s.x = C.CX + (random() - 0.5) * 260
        s.y = 150 + random() * 170
        layBody(s)
        list[i] = s
    end
end

function SeaMonkeys.all() return list end

--- How many darts they've made since the tank opened (the self-test counts them)
function SeaMonkeys.darts() return darts end

--- Whether all of a body is in the water: on screen, between the glass panes,
--- below the surface and above the sand
function SeaMonkeys.inTank(s)
    for _, p in ipairs(s.spine) do
        local lo, hi = World.xBounds(p.d, 0)
        if p.d <= 0 or p.d >= 1 or p.x < lo or p.x > hi
            or p.y <= C.SURFACE_Y or p.y >= World.floorY(p.x, p.d) then
            return false
        end
    end
    return true
end

-- One hop: everything it wants, added up, then tipped upward
local function dart(s, env, vigor, cx, cy, foods)
    local wx, wy, wz = (random() - 0.5) * 2.2, (random() - 0.5) * 0.7, (random() - 0.5) * 1.2

    -- Stay with the others, without crowding them
    local dx, dy = cx - s.x, cy - s.y
    local apart = sqrt(dx * dx + dy * dy)
    if apart > LOOSE then
        local pull = min(1.4, (apart - LOOSE) / LOOSE) / apart
        wx, wy = wx + dx * pull, wy + dy * pull
    end
    for _, o in ipairs(list) do
        if o ~= s then
            -- (depth counts for less: two at different depths in one spot
            -- still overlap on the screen, and read as a clump)
            local ox, oy, oz = s.x - o.x, s.y - o.y, (s.d - o.d) * C.DEPTH_PX * 0.3
            local d2 = ox * ox + oy * oy + oz * oz
            if d2 < ELBOW * ELBOW and d2 > 0.01 then
                local dist = sqrt(d2)
                local push = 1.8 * (1 - dist / ELBOW) / dist
                wx, wy, wz = wx + ox * push, wy + oy * push, wz + oz * push
            end
        end
    end

    -- Toward the light: along under the brightest pool, wandering a little to
    -- either side of it, and up, unless it's a night for hanging low
    local sunX = World.unproject(env.sun_x, 0, s.d) + sin(time * 0.037) * 150 + sin(time * 0.017 + 1) * 90
    wx = wx + clamp((sunX - s.x) / 260, -1, 1) * (0.25 + 0.5 * vigor)
    local depth = C.FLOOR_Y - C.SURFACE_Y
    local hang = C.SURFACE_Y + depth * (0.62 - 0.40 * (vigor - 0.3) / 0.7) + s.level
    wy = wy + clamp((hang - s.y) / 90, -1.4, 1.4)
    wz = wz + clamp((s.home - s.d) * C.DEPTH_PX / 120, -1, 1)

    -- A falling flake nearby turns it and quickens it a little: they crowd
    -- round to look, but they don't eat, and they don't pile on
    local nearest, best = nil, SMELL * SMELL
    for _, f in ipairs(foods) do
        if f.state == "sink" and not f.eaten then
            local fx, fy, fz = f.x - s.x, f.y - s.y, (f.d - s.d) * C.DEPTH_PX
            local d2 = fx * fx + fy * fy + fz * fz
            if d2 < best then nearest, best = f, d2 end
        end
    end
    local eager = 1
    if nearest then
        local dist = max(1, sqrt(best))
        if dist > NOSE then
            local pull = 1.1 / dist
            wx = wx + (nearest.x - s.x) * pull
            wy = wy + (nearest.y - s.y) * pull
            wz = wz + (nearest.d - s.d) * C.DEPTH_PX * pull
        end
        eager = 1.3
    end

    wy = wy - 0.38
    local len = max(0.01, sqrt(wx * wx + wy * wy + wz * wz))
    local speed = (46 + random() * 52) * (0.42 + 0.58 * vigor)
    s.vx = s.vx + wx / len * speed
    s.vy = s.vy + wy / len * speed
    s.vz = s.vz + wz / len * speed * 0.8
    s.kick = 1
    s.wait = (0.55 + random() * 1.5) / vigor / eager
    darts = darts + 1
end

-- A fish too close: straight away from it, and no thinking about it
local function flinch(s, dx, dy, dz, vigor)
    local len = max(0.01, sqrt(dx * dx + dy * dy + dz * dz))
    local speed = (95 + random() * 45) * (0.5 + 0.5 * vigor)
    s.vx = s.vx + dx / len * speed
    s.vy = s.vy + dy / len * speed - 12
    s.vz = s.vz + dz / len * speed * 0.8
    s.kick = 1
    s.scared = 0.9
    s.wait = 0.5 + random()
    darts = darts + 1
end

-- The body turns toward where it's going when it's really swimming, and when
-- it isn't it hangs with its nose a little up rather than following its sink
local function steerBody(s, dt)
    local swim = sqrt(s.vx * s.vx + s.vy * s.vy + s.vz * s.vz)
    local tx, ty, tz
    if swim > 9 then
        tx, ty, tz = s.vx / swim, s.vy / swim * 0.75, s.vz / swim
    else
        tx, ty, tz = s.hx < 0 and -1 or 1, -0.22, s.hz * 0.5
    end
    local rate = min(1, dt * (1.2 + 9 * min(1, swim / 30)))
    local hx = s.hx + (tx - s.hx) * rate
    local hy = s.hy + (ty - s.hy) * rate - 0.002
    local hz = s.hz + (tz - s.hz) * rate
    local len = sqrt(hx * hx + hy * hy + hz * hz)
    if len > 0.01 then s.hx, s.hy, s.hz = hx / len, hy / len, hz / len end

    -- Each segment lags the one ahead, so the tail follows through a turn
    local u = s.dirs[1]
    u.x, u.y, u.z = s.hx, s.hy, s.hz
    for i = 2, SPINE - 1 do
        local a, b = s.dirs[i - 1], s.dirs[i]
        local k = min(1, dt * (15 - i * 1.7))
        local bx = b.x + (a.x - b.x) * k
        local by = b.y + (a.y - b.y) * k
        local bz = b.z + (a.z - b.z) * k
        local bl = sqrt(bx * bx + by * by + bz * bz)
        if bl > 0.01 then b.x, b.y, b.z = bx / bl, by / bl, bz / bl end
    end

    -- Legs on the side toward the light, unless it's pointing straight up
    if abs(s.hx) > 0.2 then
        local want = s.hx < 0 and 1 or -1
        s.side = s.side + (want - s.side) * min(1, dt * 7)
    end
end

function SeaMonkeys.update(dt, env, foods, fishes)
    time = time + dt
    local vigor = SeaMonkeys.vigor(env)
    local n = #list
    if n == 0 then return end
    local cx, cy = 0, 0
    for _, s in ipairs(list) do cx, cy = cx + s.x, cy + s.y end
    cx, cy = cx / n, cy / n

    local fade = exp(-dt * DRAG)
    for _, s in ipairs(list) do
        s.wait = s.wait - dt
        s.scared = s.scared - dt
        if s.wait <= 0 then dart(s, env, vigor, cx, cy, foods) end
        if s.scared <= 0 then
            for _, f in ipairs(fishes) do
                local dx, dy, dz = s.x - f.x, s.y - f.y, (s.d - f.z) * C.DEPTH_PX
                local r = f.L * 0.7 + 22
                if dx * dx + dy * dy + dz * dz < r * r then
                    flinch(s, dx, dy, dz, vigor)
                    break
                end
            end
        end

        s.vx, s.vy, s.vz = s.vx * fade, s.vy * fade, s.vz * fade

        local fx, fy = Current.at(s.x, s.y, s.d)
        local sway = sin(time * 0.9 + s.phase) * 3
        s.x = s.x + (s.vx + fx * 0.55 + sway) * dt
        s.y = s.y + (s.vy + fy * 0.55 + s.sink * (0.65 + 0.35 * vigor)) * dt
        s.d = s.d + s.vz / C.DEPTH_PX * dt

        -- Turn back before a limit, and never pass it
        s.d = clamp(s.d, D_LO, D_HI)
        local lo, hi, top, floor = limits(s.x, s.d)
        local shy = 90 * dt
        if s.x < lo + BAND then s.vx = s.vx + shy * (lo + BAND - s.x) / BAND end
        if s.x > hi - BAND then s.vx = s.vx - shy * (s.x - hi + BAND) / BAND end
        if s.y < top + BAND then s.vy = s.vy + shy * (top + BAND - s.y) / BAND end
        if s.y > floor - BAND then s.vy = s.vy - shy * (s.y - floor + BAND) / BAND end
        local nearGlass = 0.09
        if s.d < D_LO + nearGlass then s.vz = s.vz + shy * (D_LO + nearGlass - s.d) / nearGlass end
        if s.d > D_HI - nearGlass then s.vz = s.vz - shy * (s.d - D_HI + nearGlass) / nearGlass end
        if s.x < lo then s.x, s.vx = lo, max(0, s.vx) end
        if s.x > hi then s.x, s.vx = hi, min(0, s.vx) end
        if s.y < top then s.y, s.vy = top, max(0, s.vy) end
        if s.y > floor then s.y, s.vy = floor, min(0, s.vy) end

        s.kick = s.kick * exp(-dt * 2.6)
        s.beat = s.beat + dt * (5 + 24 * s.kick) * (0.45 + 0.55 * vigor)

        steerBody(s, dt)
        layBody(s)
    end
end

local function shade(c, gray, vivid, glint, light)
    local v = gray + (c - gray) * vivid
    return v + (light - v) * glint
end

--- One sea monkey. The caller has bound the object shader (Render.useObject).
function SeaMonkeys.draw(s, env)
    local hx, hy, k = World.project(s.x, s.y, s.d)
    px[1], py[1] = hx, hy
    for i = 2, SPINE do
        local p = s.spine[i]
        px[i], py[i] = World.project(p.x, p.y, p.d)
    end

    -- The way the head is pointing on screen, and what's square to that
    local tx, ty = px[1] - px[2], py[1] - py[2]
    local tl = sqrt(tx * tx + ty * ty)
    if tl < 0.01 then tx, ty, tl = (s.hx < 0 and -1 or 1), 0, 1 end
    tx, ty = tx / tl, ty / tl
    local nx, ny = -ty, tx

    local L = s.L * k

    -- A little shiver down the body, more just after a dart
    local shiver = (0.012 + 0.05 * s.kick) * L
    for i = 2, SPINE do
        local w = sin(s.beat * 0.5 - i * 1.15) * shiver * (i - 1) / (SPINE - 1)
        px[i], py[i] = px[i] + nx * w, py[i] + ny * w
    end

    -- Translucent: dimmer by night, and lit through when it crosses a shaft
    local dim = 0.62 + 0.38 * smoothstep(0.28, 0.9, env.light_i)
    local lit = Water.rayLight(hx, hy, env)
    local glint = min(0.45, lit * 1.5)
    local c = s.tint
    local gray = c[1] * 0.3 + c[2] * 0.6 + c[3] * 0.1
    local vivid = 0.35 + 0.65 * env.vivid
    local lc = env.light
    local r = shade(c[1], gray, vivid, glint, lc[1])
    local g = shade(c[2], gray, vivid, glint, lc[2])
    local b = shade(c[3], gray, vivid, glint, lc[3])

    -- A faint glow in the water around it, stronger in a shaft of light
    love.graphics.setColor(r, g, b, (0.045 + lit * 0.42) * dim)
    Render.drawBlob(px[3], py[3], L * 0.85)

    -- Legs: a wave running down the row of them, on the side toward the light
    local side = s.side
    love.graphics.setLineWidth(max(0.75, 0.055 * L))
    for i = 1, LEGS do
        local u = 1.35 + (i - 1) / (LEGS - 1) * 2.1
        local at = math.floor(u)
        local f = u - at
        local bx = px[at] + (px[at + 1] - px[at]) * f
        local by = py[at] + (py[at + 1] - py[at]) * f
        local wave = sin(s.beat - i * 0.85)
        local sweep = 0.30 + 0.62 * wave
        local reach = L * (0.34 - 0.016 * i)
        local across, back = cos(sweep) * reach * side, sin(sweep) * reach
        local mx, my = bx + nx * across * 0.55 - tx * back * 0.55, by + ny * across * 0.55 - ty * back * 0.55
        local ex, ey = bx + nx * across - tx * back, by + ny * across - ty * back
        local a = (0.42 + 0.30 * wave * wave + 0.22 * s.kick) * dim
        love.graphics.setColor(r, g, b, a)
        love.graphics.line(bx, by, ex, ey)
        -- ...each with a barb or two, for the feathering
        love.graphics.setColor(r, g, b, a * 0.6)
        local fan = reach * 0.34
        love.graphics.line(mx, my, mx + nx * fan * side * 0.4 + tx * fan, my + ny * fan * side * 0.4 + ty * fan)
        love.graphics.line(mx, my, mx + nx * fan * side * 0.4 - tx * fan, my + ny * fan * side * 0.4 - ty * fan)
    end

    -- The forked tail
    local ex, ey = px[SPINE], py[SPINE]
    local bx, by = ex - px[SPINE - 1], ey - py[SPINE - 1]
    local bl = max(0.01, sqrt(bx * bx + by * by))
    bx, by = bx / bl, by / bl
    local tail = L * 0.20
    love.graphics.setLineWidth(max(0.7, 0.055 * L))
    love.graphics.setColor(r, g, b, 0.62 * dim)
    for fork = -1, 1, 2 do
        local open = 0.42 + 0.14 * sin(s.beat * 0.4 + fork)
        local ca, sa = cos(open * fork), sin(open * fork)
        love.graphics.line(ex, ey, ex + (bx * ca - by * sa) * tail, ey + (by * ca + bx * sa) * tail)
    end

    -- The body: soft-edged, more solid at the shoulders, glassy down the tail
    local v = 1
    for i = 1, SPINE do
        local a0 = (i < SPINE) and (px[i] - px[i + 1]) or (px[i - 1] - px[i])
        local a1 = (i < SPINE) and (py[i] - py[i + 1]) or (py[i - 1] - py[i])
        local al = max(0.01, sqrt(a0 * a0 + a1 * a1))
        local mx, my = -a1 / al, a0 / al
        local w = WIDTH[i] * L
        local core = (0.84 - 0.07 * i) * dim
        local edge = core * 0.14
        local lv, cv, rv = bodyVerts[v], bodyVerts[v + 1], bodyVerts[v + 2]
        lv[1], lv[2], lv[5], lv[6], lv[7], lv[8] = px[i] + mx * w, py[i] + my * w, r, g, b, edge
        cv[1], cv[2], cv[5], cv[6], cv[7], cv[8] = px[i], py[i], r, g, b, core
        rv[1], rv[2], rv[5], rv[6], rv[7], rv[8] = px[i] - mx * w, py[i] - my * w, r, g, b, edge
        v = v + 3
    end
    bodyMesh:setVertices(bodyVerts)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bodyMesh)

    -- The thread of the gut, seen through the body, and a brood pouch on some
    love.graphics.setLineWidth(max(0.6, 0.042 * L))
    love.graphics.setColor(0.34, 0.20, 0.12, 0.5 * dim)
    love.graphics.line(px[2], py[2], px[3], py[3], px[4], py[4], px[5], py[5])
    if s.brood then
        love.graphics.setColor(0.72, 0.36, 0.16, 0.8 * dim)
        love.graphics.circle("fill", px[4] + (px[3] - px[4]) * 0.3, py[4] + (py[3] - py[4]) * 0.3, max(0.8, 0.07 * L))
    end

    -- Feelers and two eyes on stalks
    love.graphics.setLineWidth(max(0.55, 0.035 * L))
    love.graphics.setColor(r, g, b, 0.42 * dim)
    local fw, fs = L * 0.22, L * 0.12
    love.graphics.line(hx, hy, hx + tx * fw + nx * fs, hy + ty * fw + ny * fs)
    love.graphics.line(hx, hy, hx + tx * fw - nx * fs, hy + ty * fw - ny * fs)
    local er = max(0.65, 0.052 * L)
    local ea = L * 0.115
    love.graphics.setColor(0.05, 0.04, 0.06, 0.92)
    love.graphics.circle("fill", hx + tx * ea * 0.5 + nx * ea, hy + ty * ea * 0.5 + ny * ea, er)
    love.graphics.circle("fill", hx + tx * ea * 0.5 - nx * ea, hy + ty * ea * 0.5 - ny * ea, er)
    love.graphics.setLineWidth(1)
end

return SeaMonkeys
