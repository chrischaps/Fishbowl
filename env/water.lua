-- The water volume: background absorption gradient and light shafts

local C = require("config")
local World = require("world")
local Render = require("fx.render")
local Surface = require("env.surface")

local Water = {}

local time = 0
local topY, botY

function Water.init()
    topY = World.surfaceScreenY(0)
    local _, fy = World.project(0, World.floorY(C.CX, 0), 0)
    botY = fy
end

function Water.update(dt)
    time = time + dt
end

function Water.drawBackground(env)
    local sh = Render.shader("water")
    love.graphics.setColor(1, 1, 1, 1)
    if sh then
        love.graphics.setShader(sh)
        sh:send("topColor", env.water_top)
        sh:send("deepColor", env.water_deep)
        sh:send("lightColor", env.light)
        sh:send("lightIntensity", env.light_i)
        sh:send("time", time)
        sh:send("topY", topY)
        sh:send("botY", botY)
        sh:send("sunX", env.sun_x)
    else
        love.graphics.setColor(env.water_top)
    end
    Render.quad()
    love.graphics.setShader()
end

--- Additive light shafts. strength scales the whole pass (front pass is faint).
function Water.drawRays(env, strength)
    local sh = Render.shader("rays")
    if not sh then return end
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setShader(sh)
    sh:send("lightColor", env.light)
    sh:send("intensity", env.light_i * 0.16 * strength)
    sh:send("time", time)
    sh:send("angle", env.angle)
    sh:send("topY", topY)
    sh:send("floorY", C.FLOOR_Y)
    sh:send("width", C.W)
    sh:send("surfaceTex", Surface.texture())
    love.graphics.setColor(1, 1, 1, 1)
    Render.quad()
    love.graphics.pop()
end

--- Light-shaft brightness at a screen point (mirror of rays.glsl, no ripples)
function Water.rayLight(sx, sy, env)
    local y = sy - topY
    if y < 0 then return 0 end
    local xs = sx - y * env.angle
    local spread = math.min(1, y / 600)
    xs = xs + ((C.W * 0.5 + (xs - C.W * 0.5) * 0.86) - xs) * spread
    local t = time
    local s = 0.5 + 0.5 * (0.5 * math.sin(xs * 0.011 + t * 0.13)
                         + 0.3 * math.sin(xs * 0.023 - t * 0.21 + 1.7)
                         + 0.2 * math.sin(xs * 0.047 + t * 0.37 + 4.1))
    s = s ^ 5
    local fade = math.exp(-y / 420)
    return s * fade * env.light_i
end

function Water.time() return time end

return Water
