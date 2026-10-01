-- A piece of driftwood: procedural branching, baked once, with moss and
-- anchor points for epiphyte plants (java fern) to grow from.

local C = require("config")
local World = require("world")
local Render = require("fx.render")

local Driftwood = {}

local random = math.random
local cos, sin = math.cos, math.sin

local wood = nil

local function grow(x, y, angle, length, radius, level, branches)
    local step = 12
    local n = math.max(2, math.floor(length / step))
    local pts = {}
    local bend = (random() - 0.5) * 0.04
    for i = 0, n do
        local t = i / n
        pts[#pts + 1] = { x = x, y = y, r = radius * (1 - t * 0.7) * (1 + 0.12 * sin(i * 1.7 + radius)) }
        angle = angle + bend + (random() - 0.5) * 0.22
        x = x + cos(angle) * step
        y = y + sin(angle) * step
    end
    branches[#branches + 1] = pts
    if level > 0 then
        local splits = random(1, 2)
        for _ = 1, splits do
            local k = random(math.floor(n * 0.35), math.max(math.floor(n * 0.35), n - 2))
            local p = pts[k]
            local dir = random() < 0.5 and -1 or 1
            local a = angle + dir * (0.5 + random() * 0.5)
            -- Keep branches reaching upward rather than diving into the sand
            if sin(a) > 0.2 then a = -math.pi / 2 + dir * 0.6 end
            grow(p.x, p.y, a, length * (0.45 + random() * 0.2), p.r * 0.75, level - 1, branches)
        end
    end
end

local function bake(d, baseX)
    local branches = {}
    local baseY = World.floorY(baseX, d) + 6
    grow(baseX, baseY, -math.pi / 2 - 0.85, 320, 24, 2, branches)
    grow(baseX + 14, baseY, -math.pi / 2 + 0.6, 170, 17, 1, branches)
    -- Roots running along the sand
    grow(baseX - 5, baseY - 4, math.pi - 0.1, 110, 13, 0, branches)
    grow(baseX + 12, baseY - 3, 0.12, 90, 12, 0, branches)

    local canvas = love.graphics.newCanvas(C.W, C.H)
    local k = World.k(d)
    local function P(x, y)
        local sx, sy = World.project(x, y, d)
        return sx, sy
    end

    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local function stroke(pts, rScale, offY, color, alpha)
        love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
        for i = 1, #pts do
            local p = pts[i]
            local x, y = P(p.x, p.y + p.r * offY)
            local r = p.r * rScale * k
            love.graphics.circle("fill", x, y, r)
            local q = pts[i + 1]
            if q then
                local x2, y2 = P(q.x, q.y + q.r * offY)
                local r2 = q.r * rScale * k
                local dx, dy = x2 - x, y2 - y
                local l = math.sqrt(dx * dx + dy * dy) + 1e-6
                local nx, ny = -dy / l, dx / l
                love.graphics.polygon("fill",
                    x + nx * r, y + ny * r, x2 + nx * r2, y2 + ny * r2,
                    x2 - nx * r2, y2 - ny * r2, x - nx * r, y - ny * r)
            end
        end
    end

    -- Shadow side, body, then top-lit ridges
    for _, b in ipairs(branches) do stroke(b, 1.0, 0.0, { 0.16, 0.11, 0.08 }) end
    for _, b in ipairs(branches) do stroke(b, 0.78, -0.18, { 0.30, 0.22, 0.15 }) end
    for _, b in ipairs(branches) do stroke(b, 0.42, -0.42, { 0.46, 0.36, 0.26 }, 0.8) end
    for _, b in ipairs(branches) do stroke(b, 0.15, -0.62, { 0.62, 0.52, 0.40 }, 0.5) end

    -- Bark grain: long thin lines running with the wood
    love.graphics.setLineWidth(0.7)
    for _, b in ipairs(branches) do
        for _ = 1, 4 do
            local off = (random() - 0.5) * 1.4
            local line = {}
            for i = 1, #b do
                local p = b[i]
                local q = b[math.min(#b, i + 1)]
                local dx, dy = q.x - p.x, q.y - p.y
                local l = math.sqrt(dx * dx + dy * dy) + 1e-6
                local x, y = P(p.x - dy / l * p.r * off, p.y + dx / l * p.r * off)
                line[#line + 1] = x
                line[#line + 1] = y
            end
            if #line >= 4 then
                love.graphics.setColor(0.10, 0.07, 0.05, 0.35)
                love.graphics.line(line)
            end
        end
    end

    -- Knots
    for _, b in ipairs(branches) do
        for i = 2, #b - 1, 7 do
            if random() < 0.5 then
                local p = b[i]
                local x, y = P(p.x, p.y - p.r * 0.1)
                love.graphics.setColor(0.12, 0.08, 0.06, 0.8)
                love.graphics.ellipse("fill", x, y, p.r * 0.35 * k, p.r * 0.22 * k)
                love.graphics.setColor(0.55, 0.45, 0.33, 0.4)
                love.graphics.ellipse("line", x, y, p.r * 0.45 * k, p.r * 0.3 * k)
            end
        end
    end

    -- Moss on the upper surfaces, and anchors for ferns
    local anchors = {}
    for _, b in ipairs(branches) do
        for i = 2, #b - 1, 3 do
            local p = b[i]
            if random() < 0.55 then
                for _ = 1, 8 do
                    local x, y = P(p.x + (random() - 0.5) * p.r * 2, p.y - p.r * (0.7 + random() * 0.4))
                    local g = 0.35 + random() * 0.25
                    love.graphics.setColor(0.18 + random() * 0.1, g, 0.12, 0.85)
                    love.graphics.circle("fill", x, y, (1 + random() * 1.8) * k)
                end
            end
            if random() < 0.12 and p.y < baseY - 40 then
                anchors[#anchors + 1] = { x = p.x, y = p.y - p.r * 0.7, d = d + 0.01 }
            end
        end
    end
    love.graphics.pop()

    return { kind = "wood", d = d, canvas = canvas, anchors = anchors }
end

function Driftwood.init()
    wood = bake(0.36, 880)
end

function Driftwood.get() return wood end

function Driftwood.anchors() return wood and wood.anchors or {} end

function Driftwood.draw(w)
    Render.useObject(w.d, 0.9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(w.canvas)
end

return Driftwood
