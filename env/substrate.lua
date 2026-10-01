-- The substrate: a sand-and-gravel bed receding toward the back glass, the
-- gravel cross-section seen through the front glass, rocks, and sand puffs.

local C = require("config")
local World = require("world")
local Render = require("fx.render")

local Substrate = {}

local bedCanvas, frontCanvas, frontTop
local rocks = {}
local puffs = {}
local time = 0

local random = math.random

-- Natural aquarium sand and gravel tones
local palette = {
    { 0.80, 0.71, 0.54 }, { 0.74, 0.64, 0.48 }, { 0.66, 0.58, 0.47 },
    { 0.86, 0.81, 0.68 }, { 0.58, 0.52, 0.44 }, { 0.48, 0.43, 0.37 },
    { 0.70, 0.66, 0.60 }, { 0.38, 0.35, 0.33 }, { 0.78, 0.62, 0.44 },
}

local function pick()
    local c = palette[random(#palette)]
    local j = (random() - 0.5) * 0.06
    return c[1] + j, c[2] + j, c[3] + j * 0.8
end

local function pebble(x, y, rx, ry, r, g, b, light)
    -- Contact shadow, body, then a top-lit highlight: reads as a rounded stone
    love.graphics.setColor(r * 0.35, g * 0.33, b * 0.32, 0.55)
    love.graphics.ellipse("fill", x + rx * 0.12, y + ry * 0.35, rx * 1.05, ry * 0.95)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.ellipse("fill", x, y, rx, ry)
    if rx > 1.2 then
        love.graphics.setColor(math.min(1, r * 1.25 + 0.05), math.min(1, g * 1.25 + 0.05), math.min(1, b * 1.22 + 0.05), 0.55 * light)
        love.graphics.ellipse("fill", x - rx * 0.22, y - ry * 0.32, rx * 0.5, ry * 0.42)
    end
end

--------------------------------------------------------------------------------
-- Bake: the sand bed (floor plane, all depths)
--------------------------------------------------------------------------------
local function bakeBed()
    bedCanvas = love.graphics.newCanvas(C.W, C.H)
    love.graphics.push("all")
    love.graphics.setCanvas(bedCanvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Base surface as a mesh over the floor plane
    local xs, ds = 48, 14
    local x0, x1 = -260, C.W + 260
    local verts = {}
    local function vert(x, d)
        local sx, sy = World.project(x, World.floorY(x, d), d)
        local n = 0.04 * math.sin(x * 0.013 + d * 7) + 0.03 * math.sin(x * 0.041 - d * 13)
        local front = 0.94 + 0.06 * d
        return { sx, sy, 0, 0, (0.64 + n) * front, (0.56 + n) * front, (0.43 + n * 0.8) * front, 1 }
    end
    for i = 0, xs - 1 do
        local xa = x0 + (x1 - x0) * i / xs
        local xb = x0 + (x1 - x0) * (i + 1) / xs
        for j = 0, ds - 1 do
            local da, db = j / ds, (j + 1) / ds
            local a, b, c, d = vert(xa, da), vert(xb, da), vert(xb, db), vert(xa, db)
            for _, v in ipairs({ a, b, c, a, c, d }) do verts[#verts + 1] = v end
        end
    end
    local mesh = love.graphics.newMesh(verts, "triangles", "static")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)

    -- Grains and pebbles, back to front
    local stones = {}
    for _ = 1, 5200 do
        local d = random() ^ 0.8
        local r = 0.7 + random() ^ 3 * 2.4
        stones[#stones + 1] = { x = x0 + random() * (x1 - x0), d = d, r = r }
    end
    for _ = 1, 90 do
        stones[#stones + 1] = { x = x0 + random() * (x1 - x0), d = random(), r = 3 + random() * 4.5 }
    end
    table.sort(stones, function(a, b) return a.d < b.d end)
    for _, s in ipairs(stones) do
        local sx, sy, k = World.project(s.x, World.floorY(s.x, s.d), s.d)
        if sx > -10 and sx < C.W + 10 then
            local r, g, b = pick()
            -- Seen at a grazing angle, stones squash vertically
            pebble(sx, sy - s.r * k * 0.2, s.r * k, s.r * k * 0.5, r, g, b, 1)
        end
    end

    -- Fine speckle
    for _ = 1, 6000 do
        local x, d = x0 + random() * (x1 - x0), random()
        local sx, sy = World.project(x, World.floorY(x, d), d)
        local r, g, b = pick()
        love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 0.5)
        love.graphics.points(sx, sy)
    end

    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- Bake: gravel cross-section against the front glass
--------------------------------------------------------------------------------
local function bakeFront()
    frontTop = {}
    local minTop = C.H
    for x = 0, C.W do
        frontTop[x] = World.floorY(x, 1)
        if frontTop[x] < minTop then minTop = frontTop[x] end
    end

    frontCanvas = love.graphics.newCanvas(C.W, C.H)
    love.graphics.push("all")
    love.graphics.setCanvas({ frontCanvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)

    local poly = { 0, C.H + 2 }
    for x = 0, C.W, 8 do
        poly[#poly + 1] = x
        poly[#poly + 1] = frontTop[x]
    end
    poly[#poly + 1] = C.W
    poly[#poly + 1] = C.H + 2

    local function shape()
        local tris = love.math.triangulate(poly)
        for _, t in ipairs(tris) do love.graphics.polygon("fill", t) end
    end

    love.graphics.stencil(shape, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setColor(0.30, 0.26, 0.22, 1)
    shape()

    -- Densely packed gravel; deeper stones sit in shadow
    for _ = 1, 3400 do
        local x = random() * C.W
        local top = frontTop[math.floor(x)] or minTop
        local y = top - 2 + random() ^ 0.9 * (C.H - top + 8)
        local depth = (y - top) / (C.H - top + 1)
        local occl = 1 - depth * 0.55
        local r = 1.6 + random() ^ 2 * 4.8
        local cr, cg, cb = pick()
        pebble(x, y, r * (0.9 + random() * 0.3), r * (0.75 + random() * 0.25),
            cr * occl, cg * occl, cb * occl, occl)
    end

    -- Sand settled between the stones near the top
    for _ = 1, 2500 do
        local x = random() * C.W
        local top = frontTop[math.floor(x)] or minTop
        local y = top + random() ^ 2.5 * 26
        local r, g, b = pick()
        love.graphics.setColor(r, g, b, 0.85)
        love.graphics.circle("fill", x, y, 0.6 + random() * 0.8)
    end

    -- Darken toward the bottom
    local steps = 24
    for i = 0, steps - 1 do
        local t = i / steps
        local y = minTop + (C.H - minTop) * t
        love.graphics.setColor(0.04, 0.03, 0.02, t * t * 0.55)
        love.graphics.rectangle("fill", 0, y, C.W, (C.H - minTop) / steps + 1)
    end

    love.graphics.setStencilTest()

    -- Where the bed meets the glass: a lit rim
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.92, 0.86, 0.72, 0.35)
    local line = {}
    for x = 0, C.W, 4 do
        line[#line + 1] = x
        line[#line + 1] = frontTop[x] + 0.5
    end
    love.graphics.line(line)
    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- Rocks
--------------------------------------------------------------------------------
local rockStyles = {
    { base = { 0.44, 0.45, 0.46 }, vein = { 0.78, 0.79, 0.78 } },  -- seiryu grey
    { base = { 0.47, 0.41, 0.36 }, vein = { 0.66, 0.58, 0.50 } },  -- warm river stone
    { base = { 0.36, 0.37, 0.38 }, vein = { 0.62, 0.64, 0.64 } },
}

local function bakeRock(w, h, style)
    local pad = 8
    local cw, ch = math.ceil(w + pad * 2), math.ceil(h + pad * 2)
    local canvas = love.graphics.newCanvas(cw, ch)
    local ox, oy = cw / 2, ch - pad  -- ground contact at bottom center

    -- Outline: an irregular dome with a flat buried base
    local pts = {}
    local n = random(7, 11)
    for i = 0, n do
        local a = math.pi + math.pi * i / n
        local rx = w / 2 * (0.8 + random() * 0.25)
        local ry = h * (0.75 + random() * 0.3)
        pts[#pts + 1] = { ox + math.cos(a) * rx, oy + math.sin(a) * ry }
    end
    pts[1][2], pts[#pts][2] = oy + 2, oy + 2

    local peak = { ox - w * 0.12 + (random() - 0.5) * w * 0.15, oy - h * 0.62 }
    local lx, ly = -0.35, -1
    local ll = math.sqrt(lx * lx + ly * ly)
    lx, ly = lx / ll, ly / ll

    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)

    local flat = {}
    for _, p in ipairs(pts) do flat[#flat + 1] = p[1]; flat[#flat + 1] = p[2] end
    flat[#flat + 1] = ox
    flat[#flat + 1] = oy + 2
    local function outline()
        for _, t in ipairs(love.math.triangulate(flat)) do love.graphics.polygon("fill", t) end
    end
    love.graphics.stencil(outline, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local b = style.base
    love.graphics.setColor(b[1] * 0.7, b[2] * 0.7, b[3] * 0.7)
    outline()

    -- Facets fanned from the peak, shaded by which way they face
    for i = 1, #pts - 1 do
        local p1, p2 = pts[i], pts[i + 1]
        local mx, my = (p1[1] + p2[1]) / 2 - peak[1], (p1[2] + p2[2]) / 2 - peak[2]
        local ml = math.sqrt(mx * mx + my * my) + 0.001
        local face = (mx / ml) * lx + (my / ml) * ly
        local shade = 0.62 + 0.38 * (-face) + (random() - 0.5) * 0.08
        shade = math.max(0.45, math.min(1.15, shade))
        love.graphics.setColor(b[1] * shade, b[2] * shade, b[3] * shade)
        love.graphics.polygon("fill", peak[1], peak[2], p1[1], p1[2], p2[1], p2[2])
    end

    -- Soft vertical gradient: lit top, dark base
    for i = 0, 10 do
        local t = i / 10
        love.graphics.setColor(0, 0, 0, t * t * 0.35)
        love.graphics.rectangle("fill", 0, oy - h * (1 - t), cw, h / 10 + 1)
    end
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.ellipse("fill", peak[1] - w * 0.05, peak[2] + h * 0.1, w * 0.25, h * 0.18)

    -- Mineral veins
    local v = style.vein
    for _ = 1, random(2, 5) do
        local y = oy - h * (0.15 + random() * 0.7)
        local slope = (random() - 0.5) * 0.5
        love.graphics.setColor(v[1], v[2], v[3], 0.25 + random() * 0.25)
        love.graphics.setLineWidth(0.6 + random() * 1.2)
        local line = {}
        for x = 0, cw, 6 do
            line[#line + 1] = x
            line[#line + 1] = y + (x - ox) * slope + math.sin(x * 0.2 + y) * 1.2
        end
        love.graphics.line(line)
    end

    -- Specks and pits
    for _ = 1, math.floor(w * h / 40) do
        local x, y = ox + (random() - 0.5) * w, oy - random() * h
        local dark = random() < 0.6
        love.graphics.setColor(dark and 0 or 1, dark and 0 or 1, dark and 0 or 1, 0.08 + random() * 0.08)
        love.graphics.circle("fill", x, y, 0.5 + random() * 1.2)
    end

    love.graphics.setStencilTest()

    -- Sand banked against the base
    for _ = 1, math.floor(w / 2) do
        local x = ox + (random() - 0.5) * w * 1.1
        local r, g, bb = pick()
        love.graphics.setColor(r, g, bb, 0.9)
        love.graphics.ellipse("fill", x, oy + 1 - random() * 3, 1 + random() * 2.5, 0.8 + random() * 1.2)
    end
    love.graphics.pop()

    return canvas, ox, oy
end

local function addRock(x, d, w, h, styleIndex)
    local canvas, ox, oy = bakeRock(w, h, rockStyles[styleIndex or random(#rockStyles)])
    rocks[#rocks + 1] = {
        kind = "rock", x = x, d = d, w = w, h = h,
        canvas = canvas, ox = ox, oy = oy,
        y = World.floorY(x, d),
    }
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------
function Substrate.init()
    bakeBed()
    bakeFront()
    rocks = {}
    addRock(250, 0.62, 120, 62, 1)
    addRock(330, 0.48, 70, 40, 1)
    addRock(560, 0.30, 90, 54, 3)
    addRock(1040, 0.78, 84, 36, 2)
    addRock(1150, 0.40, 130, 80, 1)
    addRock(760, 0.86, 44, 20, 2)
end

function Substrate.getRocks() return rocks end

function Substrate.update(dt)
    time = time + dt
    for i = #puffs, 1, -1 do
        local p = puffs[i]
        p.age = p.age + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * (1 - dt * 1.5)
        p.vy = p.vy * (1 - dt * 1.5) + 6 * dt
        if p.age > p.life then table.remove(puffs, i) end
    end
end

--- Draw the sand bed with floor caustics
function Substrate.drawBed(env, time)
    local sh = Render.shader("floor")
    if sh then
        love.graphics.setShader(sh)
        sh:send("ambient", env.ambient)
        sh:send("fog", env.fog)
        sh:send("hazeMax", env.haze)
        sh:send("time", time)
        sh:send("causticAmt", env.caustic * env.light_i)
        sh:send("causticColor", env.light)
        sh:send("view", { C.CX, C.CY, C.K_BACK })
        sh:send("floorY", C.FLOOR_Y)
        sh:send("floorRise", C.FLOOR_RISE)
        sh:send("depthPx", C.DEPTH_PX)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bedCanvas)
    love.graphics.setShader()
end

--- Draw the gravel cross-section (in front of everything in the tank)
function Substrate.drawFront()
    Render.useObject(1, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(frontCanvas)
    Render.restoreCausticGain()
    love.graphics.setShader()
end

function Substrate.drawRock(r)
    local sx, sy, k = World.project(r.x, r.y, r.d)
    Render.useObject(r.d, 0.9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(r.canvas, sx, sy + 2 * k, 0, k, k, r.ox, r.oy)
end

--- A soft contact shadow on the floor
function Substrate.drawShadow(x, d, radius, alpha)
    local sx, sy, k = World.project(x, World.floorY(x, d), d)
    love.graphics.setColor(0, 0, 0, alpha)
    Render.drawBlob(sx, sy, radius * k, radius * k * 0.32)
end

--- Kick up a little cloud of sand
function Substrate.puff(x, y, d, n)
    for _ = 1, n or 4 do
        puffs[#puffs + 1] = {
            x = x + (random() - 0.5) * 6, y = y, d = d,
            vx = (random() - 0.5) * 30, vy = -8 - random() * 14,
            age = 0, life = 0.8 + random() * 0.9, r = 2 + random() * 3,
        }
    end
end

function Substrate.drawPuffs(env)
    for _, p in ipairs(puffs) do
        local sx, sy, k = World.project(p.x, p.y, p.d)
        local t = p.age / p.life
        local a = (1 - t) * 0.35
        love.graphics.setColor(0.78 * env.ambient[1], 0.70 * env.ambient[2], 0.55 * env.ambient[3], a)
        Render.drawBlob(sx, sy, p.r * k * (1 + t * 2))
    end
end

return Substrate
