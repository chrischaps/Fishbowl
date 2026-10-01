-- The water surface: a 1D spring-column height field plus gentle ambient
-- swell. It is uploaded as a 1-pixel-tall texture each frame so the rays and
-- the final composite can read heights, slopes and curvature.

local C = require("config")

local Surface = {}

local N = 160
local dx = C.W / N
local h, v = {}, {}
local total = {}
local data, image
local time = 0
local acc = 0

local STIFF = 7.0
local DAMP = 1.6
local SPREAD = 2200

function Surface.init()
    for i = 0, N + 1 do
        h[i], v[i], total[i] = 0, 0, 0
    end
    data = love.image.newImageData(N, 1)
    image = love.graphics.newImage(data)
    image:setFilter("linear", "linear")
    image:setWrap("clamp", "clamp")
end

local function swell(x, t)
    return 1.3 * math.sin(x * 0.010 + t * 0.8)
         + 0.7 * math.sin(x * 0.027 - t * 1.3 + 2.0)
         + 0.35 * math.sin(x * 0.061 + t * 2.2 + 4.0)
end

local function step(sdt)
    for i = 1, N do
        local lap = (h[i - 1] + h[i + 1] - 2 * h[i]) / (dx * dx)
        v[i] = v[i] + (-STIFF * h[i] - DAMP * v[i] + SPREAD * lap) * sdt
    end
    for i = 1, N do
        h[i] = h[i] + v[i] * sdt
    end
    h[0], h[N + 1] = h[1], h[N]
end

function Surface.update(dt, agitation)
    time = time + dt
    acc = math.min(acc + dt, 0.1)
    local sdt = 1 / 120
    while acc >= sdt do
        step(sdt)
        acc = acc - sdt
    end

    local calm = 1 + (agitation or 0)
    for i = 0, N + 1 do
        total[i] = h[i] + swell((i - 0.5) * dx, time) * calm
    end

    for i = 1, N do
        local t = total[i]
        local curv = (total[i - 1] + total[i + 1] - 2 * t) / (dx * dx)
        local slope = (total[i + 1] - total[i - 1]) / (2 * dx)
        local r = math.max(0, math.min(1, (t + 16) / 32))
        local g = math.max(0, math.min(1, 0.5 + curv * 20))
        local b = math.max(0, math.min(1, 0.5 + slope * 4))
        data:setPixel(i - 1, 0, r, g, b, 1)
    end
    image:replacePixels(data)
end

--- Push the surface at screen x (positive = down)
function Surface.disturb(x, amount, radius)
    radius = radius or 2
    local c = math.floor(x / dx) + 1
    for i = c - radius, c + radius do
        if i >= 1 and i <= N then
            local fall = 1 - math.abs(i - c) / (radius + 1)
            v[i] = v[i] + amount * 60 * fall
        end
    end
end

--- Height offset at screen x (pixels, positive = down)
function Surface.heightAt(x)
    local f = x / dx + 0.5
    local i = math.max(0, math.min(N, math.floor(f)))
    local t = f - i
    return total[i] + ((total[i + 1] or total[i]) - total[i]) * t
end

function Surface.texture() return image end

return Surface
