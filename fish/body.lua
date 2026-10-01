-- Fish rendering: a 3D spine with a traveling swim wave, projected through
-- the tank, skinned with a vertex-colored mesh and dressed with translucent
-- fins. Because the body lives in 3D, turns read as real yaw turns: the fish
-- foreshortens, shows its face, and its tail fin flashes as it beats.

local C = require("config")
local World = require("world")
local Render = require("fx.render")

local Body = {}

local sin, cos, sqrt, abs, max, min, pi = math.sin, math.cos, math.sqrt, math.abs, math.max, math.min, math.pi

local SEG = 14
local ROWS = { 0, 0.14, 0.28, 0.40, 0.55, 0.75, 1 }
local NR = #ROWS

local scaleTex
local vertexMap

local function buildScaleTexture()
    local n = 32
    local data = love.image.newImageData(n, n)
    data:mapPixel(function(x, y)
        -- Staggered rows of overlapping crescents
        local u, v = x / n * 2, y / n * 2
        local row = math.floor(v)
        local cu = (u + (row % 2) * 0.5) % 1
        local cv = v % 1
        local dx, dy = cu - 0.5, cv - 0.1
        local d = sqrt(dx * dx + dy * dy * 1.6)
        local edge = math.max(0, 1 - abs(d - 0.5) * 9)
        local val = 1 - edge * 0.16 - (cv * 0.05)
        return val, val, val, 1
    end)
    scaleTex = love.graphics.newImage(data)
    scaleTex:setWrap("repeat", "repeat")
    scaleTex:setFilter("linear", "linear")
end

local function buildVertexMap()
    vertexMap = {}
    for j = 0, SEG - 2 do
        for r = 0, NR - 2 do
            local a = j * NR + r + 1
            local b = a + 1
            local c = a + NR
            local d = c + 1
            for _, i in ipairs({ a, c, b, b, c, d }) do vertexMap[#vertexMap + 1] = i end
        end
    end
end

function Body.init()
    buildScaleTexture()
    buildVertexMap()
end

function Body.newMesh()
    local mesh = love.graphics.newMesh(SEG * NR, "triangles", "stream")
    mesh:setVertexMap(vertexMap)
    mesh:setTexture(scaleTex)
    return mesh
end

-- Profile lookup (9 control points, smoothly interpolated)
local function profile(p, s)
    local f = s * 8
    local i = math.floor(f)
    if i >= 8 then return p[9] end
    local t = f - i
    t = t * t * (3 - 2 * t)
    return p[i + 1] + (p[i + 2] - p[i + 1]) * t
end

--------------------------------------------------------------------------------
-- Per-frame frame of reference
--------------------------------------------------------------------------------
local fr = { fwd = {}, lat = {}, up = {} }
local P = {}       -- spine points, 3D (x, y, zpx)
local S = {}       -- spine points projected (sx, sy, k)
for j = 1, SEG do P[j] = { 0, 0, 0 }; S[j] = { 0, 0, 1 } end

local function project3(x, y, z)
    return World.project(x, y, z / C.DEPTH_PX)
end

local function spineAt(f, s, out)
    local sp = f.sp
    local L = f.L
    local w = sp.wave
    local amp = f.amp * L * s * s * sin(f.phase - s * w.k) + f.turnBend * L * s * s
    out[1] = f.hx - fr.fwd[1] * L * s + fr.lat[1] * amp
    out[2] = f.hy - fr.fwd[2] * L * s + fr.lat[2] * amp
    out[3] = f.hz - fr.fwd[3] * L * s + fr.lat[3] * amp
    return out
end

local tmp = { 0, 0, 0 }

local function setupFrame(f)
    local cp, sp_, ct, st = cos(f.psi), sin(f.psi), cos(f.phi), sin(f.phi)
    local fwd, lat, up = fr.fwd, fr.lat, fr.up
    fwd[1], fwd[2], fwd[3] = cp * ct, -st, sp_ * ct
    lat[1], lat[2], lat[3] = -sp_, 0, cp
    up[1], up[2], up[3] = -st * cp, -ct, -st * sp_
    -- Head position: the fish's position marks the middle of its body
    local zpx = f.z * C.DEPTH_PX
    f.hx = f.x + fwd[1] * f.L * 0.45
    f.hy = f.y + fwd[2] * f.L * 0.45
    f.hz = zpx + fwd[3] * f.L * 0.45
end

--------------------------------------------------------------------------------
-- Fins
--------------------------------------------------------------------------------
local function finColor(f, spec)
    local base, edge
    if f.sp.finColor then
        base, edge = f.sp.finColor(f)
    elseif spec.tint and f.color then
        local c = f.color
        base = { min(1, c[1] * 1.05), c[2] * 0.85, c[3] * 0.8 }
    else
        base = spec.color or { 0.85, 0.85, 0.85 }
    end
    return base, edge or base
end

-- Fins are drawn as gradient fans: denser at the root, glassy at the edge
local fanMesh
local fanVerts = {}
for i = 1, 48 do fanVerts[i] = { 0, 0, 0, 0, 1, 1, 1, 1 } end

local finPts = {}   -- { sx, sy, w } with w = 0 at the root .. 1 at the free edge
local function clearFinPts()
    for i = #finPts, 1, -1 do finPts[i] = nil end
end

local function addPt3(x, y, z, w)
    local sx, sy = project3(x, y, z)
    finPts[#finPts + 1] = { sx, sy, w or 1 }
end

local function drawFin(rx, ry, color, edge, alpha, rays)
    local n = math.min(#finPts, 46)
    if n < 2 then return end
    if not fanMesh then fanMesh = love.graphics.newMesh(48, "fan", "stream") end
    local v = fanVerts[1]
    v[1], v[2] = rx, ry
    v[5], v[6], v[7], v[8] = color[1], color[2], color[3], min(1, alpha * 1.25)
    for i = 1, n do
        local p = finPts[i]
        local m = p[3] * 0.75
        local vv = fanVerts[i + 1]
        vv[1], vv[2] = p[1], p[2]
        vv[5] = color[1] + (edge[1] - color[1]) * m
        vv[6] = color[2] + (edge[2] - color[2]) * m
        vv[7] = color[3] + (edge[3] - color[3]) * m
        vv[8] = alpha * (1 - 0.55 * p[3])
    end
    fanMesh:setVertices(fanVerts, 1, n + 1)
    fanMesh:setDrawRange(1, n + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fanMesh)

    -- Fin rays fan out from the root
    if rays then
        love.graphics.setLineWidth(0.5)
        love.graphics.setColor(edge[1] * 0.7, edge[2] * 0.7, edge[3] * 0.7, alpha * 0.35)
        for i = 1, n, rays do
            local p = finPts[i]
            if p[3] > 0.5 then love.graphics.line(rx, ry, p[1], p[2]) end
        end
        love.graphics.setLineWidth(1)
    end
end

local function drawCaudal(f)
    local spec = f.sp.fins.caudal
    local L = f.L
    local up = fr.up
    local base = P[SEG]
    local prev = P[SEG - 2]
    local tx, ty, tz = base[1] - prev[1], base[2] - prev[2], base[3] - prev[3]
    local tl = sqrt(tx * tx + ty * ty + tz * tz) + 1e-6
    tx, ty, tz = tx / tl, ty / tl, tz / tl

    local len, H = spec.len * L, spec.height * L
    local hp = profile(f.sp.top, 1) * f.sp.height * L * 0.5
    -- The fin flexes behind the beat: its edge lags the peduncle
    local lag = f.amp * L * 0.9 * sin(f.phase - f.sp.wave.k - 1.1)
    local slow = 1 - min(1, f.speed / (f.sp.cruise * 1.5))
    local droop = spec.flowing and (0.25 + 0.2 * slow) or 0

    clearFinPts()
    local function pt(a, b)
        local t = a / len
        local fl = t ^ 1.5
        local flutter = spec.flowing and sin(f.time * 3.1 + t * 4 + b * 0.05) * 0.06 * L * t or 0
        addPt3(
            base[1] + tx * a + up[1] * b + fr.lat[1] * (lag + flutter) * fl,
            base[2] + ty * a + up[2] * b + fr.lat[2] * (lag + flutter) * fl + droop * len * t * t,
            base[3] + tz * a + up[3] * b + fr.lat[3] * (lag + flutter) * fl,
            min(1, t * 1.3))
    end

    if spec.shape == "fork" or spec.shape == "lyre" then
        local tipA = spec.shape == "lyre" and 1.25 or 1.0
        pt(0, hp)
        pt(len * 0.55, H * 0.75)
        pt(len * tipA, H)
        pt(len * (spec.fork + 0.25), H * 0.12)
        pt(len * spec.fork, 0)
        pt(len * (spec.fork + 0.25), -H * 0.12)
        pt(len * tipA, -H)
        pt(len * 0.55, -H * 0.75)
        pt(0, -hp)
    else
        -- round / veil: a fan with a softly ruffled edge
        local n = spec.shape == "veil" and 14 or 9
        pt(0, hp)
        for i = 0, n do
            local a = pi * 0.5 - pi * i / n
            local ruffle = spec.shape == "veil" and (1 + 0.07 * sin(i * 2.3 + f.time * 2.4)) or 1
            pt(len * (0.35 + 0.65 * cos(a) ^ 0.7) * ruffle, H * sin(a) * ruffle)
        end
        pt(0, -hp)
    end

    local color, edge = finColor(f, spec)
    local rx, ry = project3(base[1], base[2], base[3])
    drawFin(rx, ry, color, edge, spec.alpha, spec.shape == "veil" and 1 or 2)
end

local function drawMedian(f, spec, dir)
    -- Dorsal (dir = 1) or anal (dir = -1) fin along the back or belly
    if not spec then return end
    local L = f.L
    local up = fr.up
    local fwd = fr.fwd
    local prof = dir > 0 and f.sp.top or f.sp.bot
    local hh = f.sp.height * L * 0.5
    local height, rake = spec.height * L, spec.rake * L
    local flow = spec.flowing and (0.6 + 0.4 * sin(f.time * 2.2 + dir)) or 1
    local wob = sin(f.time * 2.7 + dir * 1.3) * 0.05 * height

    clearFinPts()
    local n = 6
    -- Base along the body
    for i = 0, n do
        local s = spec.s0 + (spec.s1 - spec.s0) * i / n
        spineAt(f, s, tmp)
        local h = profile(prof, s) * hh * 0.92 * dir
        addPt3(tmp[1] + up[1] * h, tmp[2] + up[2] * h, tmp[3] + up[3] * h, 0)
    end
    -- Free edge, swept back
    for i = n, 0, -1 do
        local t = i / n
        local s = spec.s0 + (spec.s1 - spec.s0) * t
        spineAt(f, s, tmp)
        local h = profile(prof, s) * hh * 0.92 * dir
        -- Sail profile: leading edge rises to a peak, trailing edge falls away
        local peak, lead, trail = spec.peak or 0.3, spec.lead or 0.45, spec.trail or 0.3
        local e
        if t < peak then
            e = lead + (1 - lead) * (t / peak) ^ 0.8
        else
            e = 1 + (trail - 1) * ((t - peak) / (1 - peak)) ^ 1.4
        end
        local tipH = height * e * dir
        local back = rake * t ^ 1.3 * flow
        local droop = spec.flowing and (t * t * height * 0.35) or 0
        addPt3(
            tmp[1] + up[1] * (h + tipH) - fwd[1] * back + fr.lat[1] * wob * t,
            tmp[2] + up[2] * (h + tipH) - fwd[2] * back + droop,
            tmp[3] + up[3] * (h + tipH) - fwd[3] * back + fr.lat[3] * wob * t, 1)
    end

    local color, edge = finColor(f, spec)
    if spec.bars and f.barStrength then
        local k = 1 - 0.35 * f.barStrength
        color = { color[1] * k, color[2] * k, color[3] * k }
    end
    local mid = finPts[math.floor(n / 2) + 1]
    drawFin(mid[1], mid[2], color, edge, spec.alpha, nil)
    -- Rays: from base points to matching edge points
    love.graphics.setLineWidth(0.5)
    love.graphics.setColor(edge[1] * 0.7, edge[2] * 0.7, edge[3] * 0.7, spec.alpha * 0.35)
    local m = #finPts
    for i = 1, n + 1, 2 do
        local a, b = finPts[i], finPts[m - i + 1]
        love.graphics.line(a[1], a[2], b[1], b[2])
    end
    love.graphics.setLineWidth(1)
end

local function drawPaired(f, spec, side, kind)
    if not spec then return end
    local L = f.L
    local up, fwd, lat = fr.up, fr.fwd, fr.lat
    spineAt(f, spec.s, tmp)
    local hb = profile(f.sp.bot, spec.s) * f.sp.height * L * 0.5
    local tw = profile(f.sp.top, spec.s) * f.sp.thick * L * 0.8
    local rx = tmp[1] - up[1] * hb * (kind == "pelvic" and 0.95 or 0.35) + lat[1] * side * tw
    local ry = tmp[2] - up[2] * hb * (kind == "pelvic" and 0.95 or 0.35) + lat[2] * side * tw
    local rz = tmp[3] - up[3] * hb * (kind == "pelvic" and 0.95 or 0.35) + lat[3] * side * tw

    local len = spec.len * L
    local color = spec.color or { 0.9, 0.9, 0.9 }
    if f.sp.finColor then color = f.sp.finColor(f) end

    if spec.filament then
        -- Long trailing ventral filaments (angelfish, betta)
        local sway = sin(f.time * 1.7 + side) * 0.15
        local pts = {}
        for i = 0, 6 do
            local t = i / 6
            local x = rx - fwd[1] * len * t * 0.55 + lat[1] * side * len * 0.08 * t
            local y = ry + len * t * 0.8 + sin(t * 3 + f.time * 1.3) * len * 0.04
            local z = rz - fwd[3] * len * t * 0.55 + lat[3] * side * len * (0.08 + sway) * t
            local sx, sy = project3(x, y, z)
            pts[#pts + 1] = sx
            pts[#pts + 1] = sy
        end
        love.graphics.setLineWidth(1.2 * World.k(f.z))
        love.graphics.setColor(color[1], color[2], color[3], spec.alpha)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)
        return
    end

    -- Sculling: faster when hovering, tucked when dashing
    local hover = 1 - min(1, f.speed / f.sp.cruise)
    local beat = sin(f.finPhase * (kind == "pelvic" and 0.6 or 1) + side * 1.3)
    local a = 0.35 + 0.35 * hover + beat * (0.25 + 0.35 * hover)
    local dx = -fwd[1] * cos(a) + lat[1] * side * sin(a) * 0.9 - up[1] * 0.45
    local dy = -fwd[2] * cos(a) + lat[2] * side * sin(a) * 0.9 - up[2] * 0.45
    local dz = -fwd[3] * cos(a) + lat[3] * side * sin(a) * 0.9 - up[3] * 0.45

    clearFinPts()
    addPt3(rx + (dx + up[1] * 0.3) * len, ry + (dy + up[2] * 0.3) * len, rz + (dz + up[3] * 0.3) * len)
    addPt3(rx + dx * len * 1.08, ry + dy * len * 1.08, rz + dz * len * 1.08)
    addPt3(rx + (dx - up[1] * 0.3) * len * 0.85, ry + (dy - up[2] * 0.3) * len * 0.85, rz + (dz - up[3] * 0.3) * len * 0.85)
    local sx, sy = project3(rx, ry, rz)
    drawFin(sx, sy, color, color, spec.alpha, 1)
end

--------------------------------------------------------------------------------
-- Body mesh
--------------------------------------------------------------------------------
local verts = {}
for i = 1, SEG * NR do verts[i] = { 0, 0, 0, 0, 1, 1, 1, 1 } end

local function buildBody(f, env)
    local sp = f.sp
    local L = f.L
    local hh = sp.height * L * 0.5
    local up, lat = fr.up, fr.lat
    local vivid = f.vivid
    local light = env.light_i

    for j = 1, SEG do
        local s = (j - 1) / (SEG - 1)
        spineAt(f, s, P[j])
        local sx, sy, k = project3(P[j][1], P[j][2], P[j][3])
        S[j][1], S[j][2], S[j][3] = sx, sy, k
    end

    -- Projected "up" direction (for choosing the dorsal side of each normal)
    local ux, uy = up[1], up[2]

    local uScale = L / 7
    for j = 1, SEG do
        local s = (j - 1) / (SEG - 1)
        local a = S[math.max(1, j - 1)]
        local b = S[math.min(SEG, j + 1)]
        local tx, ty = a[1] - b[1], a[2] - b[2]
        local tl = sqrt(tx * tx + ty * ty)
        if tl < 1e-4 then
            tx, ty = 1, 0
        else
            tx, ty = tx / tl, ty / tl
        end
        local nx, ny = -ty, tx
        if nx * ux + ny * uy < 0 then nx, ny = -nx, -ny end

        local k = S[j][3]
        local ht = profile(sp.top, s) * hh * k
        local hb = profile(sp.bot, s) * hh * k
        local th = (profile(sp.top, s) + profile(sp.bot, s)) * 0.5 * sp.thick * L * k
        -- Support radius of the projected cross-section ellipse along the normal
        local na = nx * ux + ny * uy
        local nb = nx * lat[1]
        local rt = sqrt((na * ht) ^ 2 + (nb * th) ^ 2)
        local rb = sqrt((na * hb) ^ 2 + (nb * th) ^ 2)

        local topX, topY = S[j][1] + nx * rt, S[j][2] + ny * rt
        local botX, botY = S[j][1] - nx * rb, S[j][2] - ny * rb

        for r = 1, NR do
            local v = ROWS[r]
            local vert = verts[(j - 1) * NR + r]
            vert[1] = topX + (botX - topX) * v
            vert[2] = topY + (botY - topY) * v
            vert[3] = s * uScale
            vert[4] = v * 2.2

            local cr, cg, cb, ca = sp.colors(s, v, f)
            ca = ca or 1
            -- Pale at night, as real fish fade when resting
            local gray = cr * 0.3 + cg * 0.59 + cb * 0.11
            cr = gray + (cr - gray) * vivid
            cg = gray + (cg - gray) * vivid
            cb = gray + (cb - gray) * vivid
            -- Roundness: edges fall off, the back catches the light
            local shade = 0.74 + 0.26 * sin(pi * (0.08 + v * 0.84)) + 0.07 * (1 - v)
            local sheen = (v > 0.18 and v < 0.36) and (0.10 * light) or 0
            vert[5] = min(1, cr * shade + sheen)
            vert[6] = min(1, cg * shade + sheen)
            vert[7] = min(1, cb * shade + sheen)
            vert[8] = ca
        end
    end
    f.mesh:setVertices(verts)
end

local function drawEye(f, side)
    local vis = (side * cos(f.psi) + 0.3) / 0.45
    if vis <= 0 then return end
    vis = min(1, vis)
    local sp = f.sp
    local L = f.L
    local up, lat = fr.up, fr.lat
    spineAt(f, sp.eye.s, tmp)
    local h = profile(sp.top, sp.eye.s) * sp.height * L * 0.5 * 0.28
    local tw = profile(sp.top, sp.eye.s) * sp.thick * L * 0.7
    local sx, sy, k = project3(
        tmp[1] + up[1] * h + lat[1] * side * tw,
        tmp[2] + up[2] * h + lat[2] * side * tw,
        tmp[3] + up[3] * h + lat[3] * side * tw)
    local r = sp.eye.r * L * k
    local iris = sp.eye.iris
    local fx, fy = fr.fwd[1], fr.fwd[2]

    love.graphics.setColor(0.04, 0.04, 0.05, vis)
    love.graphics.circle("fill", sx, sy, r * 1.12)
    love.graphics.setColor(iris[1], iris[2], iris[3], vis)
    love.graphics.circle("fill", sx, sy, r)
    love.graphics.setColor(0.02, 0.02, 0.03, vis)
    love.graphics.circle("fill", sx + fx * r * 0.15 + f.lookX * r * 0.2, sy + f.lookY * r * 0.2, r * 0.62)
    love.graphics.setColor(1, 1, 1, 0.85 * vis)
    love.graphics.circle("fill", sx - r * 0.32, sy - r * 0.36, r * 0.24)
end

local function drawGill(f, side)
    local vis = side * cos(f.psi)
    if vis <= 0.2 then return end
    local sp = f.sp
    local s = sp.eye.s + 0.1
    local L = f.L
    local up, lat = fr.up, fr.lat
    spineAt(f, s, tmp)
    local ht = profile(sp.top, s) * sp.height * L * 0.5
    local hb = profile(sp.bot, s) * sp.height * L * 0.5
    local tw = profile(sp.top, s) * sp.thick * L * 0.85
    local pts = {}
    for i = 0, 4 do
        local t = i / 4
        local hgt = ht * 0.75 * (1 - t) - hb * 0.75 * t
        local bulge = sin(t * pi) * L * 0.025
        local sx, sy = project3(
            tmp[1] + up[1] * hgt - fr.fwd[1] * bulge + lat[1] * side * tw,
            tmp[2] + up[2] * hgt - fr.fwd[2] * bulge,
            tmp[3] + up[3] * hgt - fr.fwd[3] * bulge + lat[3] * side * tw)
        pts[#pts + 1] = sx
        pts[#pts + 1] = sy
    end
    love.graphics.setLineWidth(0.8)
    love.graphics.setColor(0, 0, 0, 0.16 * vis)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)
end

--- Draw one fish (the object shader should already be configured for its depth)
function Body.draw(f, env)
    setupFrame(f)
    buildBody(f, env)

    local fins = f.sp.fins
    local cp = cos(f.psi)
    local near = cp >= 0 and 1 or -1
    local far = -near
    local away = sin(f.psi) < -0.35

    drawPaired(f, fins.pectoral, far, "pectoral")
    drawPaired(f, fins.pelvic, far, "pelvic")
    if not away then drawCaudal(f) end
    drawMedian(f, fins.dorsal, 1)
    drawMedian(f, fins.anal, -1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(f.mesh)

    -- Seen nearly head- or tail-on, the strip collapses: draw the cross-section
    local plen = sqrt((S[1][1] - S[SEG][1]) ^ 2 + (S[1][2] - S[SEG][2]) ^ 2)
    local kk = S[1][3]
    local faceOn = 1 - World.smoothstep(0.25, 0.5, plen / (f.L * kk))
    if faceOn > 0 then
        local cr, cg, cb = f.sp.colors(0.3, 0.45, f)
        local front = sin(f.psi) > 0 and 3 or SEG - 3
        local hh = f.sp.height * f.L * 0.5 * kk
        local th = f.sp.thick * f.L * kk
        love.graphics.setColor(cr * 0.9, cg * 0.9, cb * 0.9, faceOn)
        love.graphics.ellipse("fill", S[front][1], S[front][2], th, hh * 0.95)
        love.graphics.setColor(1, 1, 1, 0.12 * faceOn)
        love.graphics.ellipse("fill", S[front][1], S[front][2] - hh * 0.35, th * 0.6, hh * 0.35)
    end

    drawGill(f, near)
    drawEye(f, near)
    if abs(cp) < 0.4 then drawEye(f, far) end

    if away then drawCaudal(f) end
    drawPaired(f, fins.pelvic, near, "pelvic")
    drawPaired(f, fins.pectoral, near, "pectoral")
end

--- Approximate screen position and radius (for hover and shadows)
function Body.screenBounds(f)
    local sx, sy, k = World.project(f.x, f.y, f.z)
    return sx, sy, f.L * k * 0.6
end

return Body
