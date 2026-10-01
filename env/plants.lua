-- Living plants. Leaves and stems are chains of angular springs that lean
-- into the current, part around passing fish, and (vallisneria) lie along
-- the surface when they grow taller than the water.
--   val   : vallisneria, tall twisting ribbons
--   fern  : java fern, broad dark leaves anchored on wood and stone
--   stem  : a red stem plant (rotala) for a warm accent
--   grass : low carpet tufts across the foreground

local C = require("config")
local World = require("world")
local Current = require("env.current")
local Render = require("fx.render")

local Plants = {}

local random = math.random
local sin, cos, sqrt, abs, min, max, pi = math.sin, math.cos, math.sqrt, math.abs, math.min, math.max, math.pi

local list = {}
local time = 0
local pearlEvents = {}

--------------------------------------------------------------------------------
-- Angular spring chains
--------------------------------------------------------------------------------
-- Each node holds an absolute angle from vertical. Buoyancy pulls every
-- node toward its rest angle, bending stiffness couples neighbors, and the
-- current and passing fish push them aside.
local function newChain(n, length, lean, stiffness, droop)
    local c = { n = n, seg = length / n, a = {}, w = {}, rest = {}, x = {}, y = {}, stiff = stiffness or 1 }
    local curve = (random() - 0.5) * 0.15
    for i = 1, n do
        local s = i / n
        c.rest[i] = lean + curve * s + (droop or 0) * s * s * (lean >= 0 and 1 or -1)
        c.a[i], c.w[i] = c.rest[i], 0
        c.x[i], c.y[i] = 0, 0
    end
    c.phase = random() * 10
    return c
end

local function layout(c, bx, by, surfaceStop)
    local x, y = bx, by
    local flat = nil
    for i = 1, c.n do
        local theta = c.a[i]
        if flat then
            -- Leaf has reached the surface: it floats along it
            x = x + flat * c.seg
            y = C.SURFACE_Y + 5 + sin(i * 0.9 + time * 0.8 + c.phase) * 1.5
        else
            x = x + sin(theta) * c.seg
            y = y - cos(theta) * c.seg
            if surfaceStop and y < C.SURFACE_Y + 5 then
                y = C.SURFACE_Y + 5
                flat = (sin(theta) >= 0) and 1 or -1
            end
        end
        c.x[i], c.y[i] = x, y
    end
end

local function simulate(c, dt, bx, by, d, fish, flex)
    layout(c, bx, by, c.surfaceStop)
    local n = c.n
    for i = 1, n do
        local s = i / n
        local x, y = c.x[i], c.y[i]
        local fx = Current.at(x, y, d)
        -- Gentle sway of its own, plus the current's push
        local torque = (fx * 0.0012 + sin(time * 0.55 + c.phase + i * 0.35) * 0.006) * flex * (0.4 + s)
        if fish then
            for _, f in ipairs(fish) do
                local dz = abs(f.z - d)
                if dz < 0.12 then
                    local dx, dy = x - f.x, y - f.y
                    local r = f.L * 0.9 + 12
                    local d2 = dx * dx + dy * dy
                    if d2 < r * r then
                        local push = (1 - sqrt(d2) / r) * (1 - dz / 0.12)
                        local vx = cos(f.psi) * f.speed
                        torque = torque + (vx * 0.0012 + (dx >= 0 and 1 or -1) * 0.025) * push * flex
                    end
                end
            end
        end
        local buoy = c.stiff * (1.6 - 0.9 * s)
        local prev = (i == 1) and c.rest[1] or c.a[i - 1]
        local nxt = (i == n) and c.a[i] or c.a[i + 1]
        local bend = (prev + nxt - 2 * c.a[i]) * 6 * c.stiff
        c.w[i] = c.w[i] + (torque * 30 - buoy * (c.a[i] - c.rest[i]) + bend - 2.0 * c.w[i]) * dt
    end
    for i = 1, n do
        c.a[i] = max(-1.3, min(1.3, c.a[i] + c.w[i] * dt))
    end
end

--------------------------------------------------------------------------------
-- Builders
--------------------------------------------------------------------------------
local function addVal(x, d, count, tall)
    local p = { kind = "plant", type = "val", x = x, d = d, y = World.floorY(x, d) + 3, leaves = {} }
    for i = 1, count do
        local length = (tall and 380 or 170) + random() * (tall and 320 or 170)
        local c = newChain(14, length, (random() - 0.5) * 0.3, 1.0)
        c.surfaceStop = true
        c.width = 5 + random() * 3
        c.ox = (i - (count + 1) / 2) * 4 + (random() - 0.5) * 6
        c.tint = 0.85 + random() * 0.3
        c.twist = random() * 10
        c.mesh = love.graphics.newMesh(c.n * 2 + 2, "strip", "stream")
        c.glows = random() < 0.4
        p.leaves[i] = c
    end
    list[#list + 1] = p
end

local function addFern(x, y, d, count)
    local p = { kind = "plant", type = "fern", x = x, d = d, y = y, leaves = {} }
    for i = 1, count do
        local lean = (i / count - 0.5) * 1.8 + (random() - 0.5) * 0.3
        local c = newChain(6, 38 + random() * 34, lean, 1.6, 0.6)
        c.width = 8 + random() * 5
        c.mesh = love.graphics.newMesh(c.n * 2 + 2, "strip", "stream")
        c.dark = 0.85 + random() * 0.25
        p.leaves[i] = c
    end
    list[#list + 1] = p
end

local function addStem(x, d, count)
    local p = { kind = "plant", type = "stem", x = x, d = d, y = World.floorY(x, d) + 3, leaves = {} }
    for i = 1, count do
        local c = newChain(14, 110 + random() * 110, (random() - 0.5) * 0.25, 1.2)
        c.ox = (i - (count + 1) / 2) * 7
        c.leafSize = 6 + random() * 3
        p.leaves[i] = c
    end
    list[#list + 1] = p
end

local function addGrass(x, d)
    local p = { kind = "plant", type = "grass", x = x, d = d, y = World.floorY(x, d) + 2, blades = {} }
    for i = 1, random(10, 18) do
        p.blades[i] = {
            ox = (random() - 0.5) * 26, len = 10 + random() * 24,
            lean = (random() - 0.5) * 0.6, phase = random() * 10,
            g = 0.42 + random() * 0.16, glows = random() < 0.15,
        }
    end
    list[#list + 1] = p
end

function Plants.init(anchors)
    list = {}
    -- Vallisneria: a tall screen along the back, a few mid-ground clumps
    addVal(40, 0.12, 8, true)
    addVal(190, 0.06, 9, true)
    addVal(330, 0.16, 7, true)
    addVal(640, 0.05, 8, true)
    addVal(1010, 0.10, 8, true)
    addVal(1150, 0.18, 9, true)
    addVal(1260, 0.30, 7, true)
    addVal(90, 0.42, 6, false)
    addVal(1200, 0.55, 5, false)

    addStem(500, 0.24, 4)
    addStem(1070, 0.58, 3)

    for _, a in ipairs(anchors or {}) do
        addFern(a.x, a.y, a.d, random(4, 6))
    end
    addFern(1150, World.floorY(1150, 0.42) - 60, 0.43, 6)
    addFern(250, World.floorY(250, 0.64) - 46, 0.645, 5)

    -- Foreground carpet, leaving open sand in the middle
    for _ = 1, 26 do
        local x = random() * C.W
        if abs(x - 640) > 160 or random() < 0.25 then
            addGrass(x, 0.70 + random() * 0.28)
        end
    end
end

function Plants.all() return list end

function Plants.update(dt, fish, env)
    time = time + dt
    for _, p in ipairs(list) do
        if p.leaves then
            local flex = p.type == "fern" and 0.4 or (p.type == "stem" and 0.7 or 1)
            for _, c in ipairs(p.leaves) do
                simulate(c, dt, p.x + (c.ox or 0), p.y, p.d, fish, flex)
            end
        end
    end

    -- Pearling: in strong light, plants release tiny oxygen bubbles
    local rate = max(0, env.light_i - 0.6) * 3
    if rate > 0 and random() < dt * rate then
        local p = list[random(#list)]
        if p.leaves and p.type ~= "fern" then
            local c = p.leaves[random(#p.leaves)]
            local i = random(math.floor(c.n * 0.3), c.n)
            if c.y[i] > C.SURFACE_Y + 20 then
                pearlEvents[#pearlEvents + 1] = { x = c.x[i], y = c.y[i], d = p.d }
            end
        end
    end
end

function Plants.drainPearls()
    local e = pearlEvents
    pearlEvents = {}
    return e
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local stripVerts = {}
for i = 1, 64 do stripVerts[i] = { 0, 0, 0, 0, 1, 1, 1, 1 } end

local function drawRibbon(c, d, bx, by, env, colorAt, widthAt)
    local n = c.n
    local idx = 0
    local function put(x, y, s, side)
        local sx, sy = World.project(x, y, d)
        idx = idx + 1
        local v = stripVerts[idx]
        v[1], v[2] = sx, sy
        local r, g, b, a = colorAt(s, side)
        v[5], v[6], v[7], v[8] = r, g, b, a
    end
    -- Base
    put(bx - 1, by, 0, -1)
    put(bx + 1, by, 0, 1)
    local px, py = bx, by
    for i = 1, n do
        local x, y = c.x[i], c.y[i]
        local nx_, ny_ = c.x[min(n, i + 1)], c.y[min(n, i + 1)]
        local tx, ty = nx_ - px, ny_ - py
        local tl = sqrt(tx * tx + ty * ty) + 1e-6
        local nx, ny = -ty / tl, tx / tl
        local s = i / n
        local w = widthAt(s)
        put(x - nx * w, y - ny * w, s, -1)
        put(x + nx * w, y + ny * w, s, 1)
        px, py = x, y
    end
    c.mesh:setVertices(stripVerts, 1, idx)
    c.mesh:setDrawRange(1, idx)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c.mesh)
end

local function drawVal(p, env)
    for _, c in ipairs(p.leaves) do
        local bx = p.x + c.ox
        local light = env.light_i
        local twistNow = time * 0.15 + c.twist
        drawRibbon(c, p.d, bx, p.y, env,
            function(s, side)
                local tw = abs(cos(s * pi * 1.4 + twistNow))
                local face = 0.55 + 0.45 * tw
                local r = (0.20 + 0.18 * s) * c.tint
                local g = (0.40 + 0.22 * s) * c.tint
                local b = (0.14 + 0.08 * s) * c.tint
                -- Thin leaves glow when backlit
                local back = light * 0.12 * s
                return r * face + back * 0.8, g * face + back, b * face + back * 0.4, 0.96
            end,
            function(s)
                local tw = 0.22 + 0.78 * abs(cos(s * pi * 1.4 + twistNow))
                return c.width * (1 - s ^ 4 * 0.75) * tw
            end)
    end
end

local function drawFern(p, env)
    for _, c in ipairs(p.leaves) do
        drawRibbon(c, p.d, p.x, p.y, env,
            function(s, side)
                local k = c.dark * (0.8 + 0.2 * s)
                return 0.13 * k, 0.30 * k, 0.12 * k, 1
            end,
            function(s)
                local blade = sin(pi * min(1, (s - 0.12) / 0.88)) ^ 0.7
                if s < 0.12 then blade = 0.08 end
                return c.width * blade * (1 + 0.08 * sin(s * 30))
            end)
        -- Midrib
        local pts = {}
        local sx, sy = World.project(p.x, p.y, p.d)
        pts[1], pts[2] = sx, sy
        for i = 1, c.n - 1 do
            local x, y = World.project(c.x[i], c.y[i], p.d)
            pts[#pts + 1] = x
            pts[#pts + 1] = y
        end
        love.graphics.setLineWidth(0.8)
        love.graphics.setColor(0.32, 0.48, 0.22, 0.5)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)
    end
end

local function drawStem(p, env)
    local k = World.k(p.d)
    for _, c in ipairs(p.leaves) do
        local bx = p.x + c.ox
        local pts = {}
        local sx, sy = World.project(bx, p.y, p.d)
        pts[1], pts[2] = sx, sy
        for i = 1, c.n do
            local x, y = World.project(c.x[i], c.y[i], p.d)
            pts[#pts + 1] = x
            pts[#pts + 1] = y
        end
        love.graphics.setLineWidth(1.6 * k)
        love.graphics.setColor(0.42, 0.30, 0.18, 1)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)

        -- Leaf pairs, green below to coral at the light-hungry tips
        for i = 2, c.n do
            local s = i / c.n
            local x, y = pts[2 * i + 1], pts[2 * i + 2]
            local px, py = pts[2 * i - 1], pts[2 * i]
            local ang = math.atan2(y - py, x - px)
            local size = c.leafSize * k * (1 - s * 0.35)
            local r = 0.30 + 0.62 * s ^ 1.5
            local g = 0.48 - 0.20 * s ^ 1.2
            local b = 0.18 + 0.12 * s
            for side = -1, 1, 2 do
                local la = ang + side * (1.0 + 0.15 * sin(time + i)) - pi * 0.15 * side
                love.graphics.setColor(r * 0.85, g * 0.85, b * 0.85, 1)
                love.graphics.push()
                love.graphics.translate(x + cos(la) * size * 0.8, y + sin(la) * size * 0.8)
                love.graphics.rotate(la)
                love.graphics.ellipse("fill", 0, 0, size * 0.95, size * 0.36, 10)
                love.graphics.setColor(r, g * 1.1, b, 0.5)
                love.graphics.line(-size * 0.8, 0, size * 0.8, 0)
                love.graphics.pop()
            end
        end
    end
end

local function drawGrass(p, env)
    local k = World.k(p.d)
    love.graphics.setLineWidth(1.3 * k)
    for _, b in ipairs(p.blades) do
        local bx = p.x + b.ox
        local fx = Current.at(bx, p.y - b.len, p.d)
        local sway = sin(time * 0.9 + b.phase) * 0.12 + fx * 0.012 + b.lean
        local x1, y1 = World.project(bx, p.y, p.d)
        local mx, my = World.project(bx + sin(sway) * b.len * 0.5, p.y - b.len * 0.5, p.d)
        local x2, y2 = World.project(bx + sin(sway) * b.len * 1.1, p.y - cos(sway) * b.len, p.d)
        love.graphics.setColor(0.16, b.g * 0.62, 0.12, 1)
        love.graphics.line(x1, y1, mx, my)
        love.graphics.setColor(0.24, b.g * 0.85, 0.16, 1)
        love.graphics.line(mx, my, x2, y2)
        b.tx, b.ty = x2, y2
    end
    love.graphics.setLineWidth(1)
end

function Plants.draw(p, env)
    Render.useObject(p.d)
    if p.type == "val" then drawVal(p, env)
    elseif p.type == "fern" then drawFern(p, env)
    elseif p.type == "stem" then drawStem(p, env)
    elseif p.type == "grass" then drawGrass(p, env)
    end
end

--- Bioluminescent tips, drawn additively after the scene (night only)
function Plants.drawGlow(env)
    local g = env.glow
    if g < 0.05 then return end
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for _, p in ipairs(list) do
        local fade = 1 - World.haze(p.d) * 0.6
        if p.type == "val" then
            for _, c in ipairs(p.leaves) do
                if c.glows then
                    local pulse = 0.6 + 0.4 * sin(time * 0.7 + c.phase)
                    local x, y, k = World.project(c.x[c.n], c.y[c.n], p.d)
                    love.graphics.setColor(0.30, 0.85, 0.75, 0.35 * g * pulse * fade)
                    Render.drawBlob(x, y, 10 * k)
                    love.graphics.setColor(0.70, 1.0, 0.95, 0.5 * g * pulse * fade)
                    Render.drawBlob(x, y, 3 * k)
                end
            end
        elseif p.type == "grass" then
            for _, b in ipairs(p.blades) do
                if b.glows and b.tx then
                    local pulse = 0.5 + 0.5 * sin(time * 0.9 + b.phase)
                    love.graphics.setColor(0.40, 0.95, 0.85, 0.45 * g * pulse)
                    Render.drawBlob(b.tx, b.ty, 5)
                end
            end
        end
    end
    love.graphics.pop()
end

return Plants
