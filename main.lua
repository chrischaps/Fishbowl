-- Fishbowl: an ambient aquarium
-- A planted tank seen through its front glass, living through a day and a night.

-- Shared libraries (LoveLibs subtree)
local PostFX = require("LoveLibs.graphics.postfx")
local Scaling = require("LoveLibs.graphics.scaling")

local C = require("config")
local World = require("world")
local Render = require("fx.render")
local DayCycle = require("env.daycycle")
local Surface = require("env.surface")
local Water = require("env.water")
local Current = require("env.current")
local Substrate = require("env.substrate")

local env = DayCycle.env
local time = 0
local snap = nil  -- { name, at, frames } when running with --snap

local function parseArgs(args)
    for i, a in ipairs(args or {}) do
        if a == "--snap" then
            snap = { name = args[i + 1] or "day", at = tonumber(args[i + 2]) or 4 }
        end
    end
end

function love.load(args)
    parseArgs(args)
    love.graphics.setBackgroundColor(0, 0, 0)
    math.randomseed(os.time())

    Scaling.init(C.W, C.H)
    Render.init()
    DayCycle.init()
    if snap then
        DayCycle.set(DayCycle.presets[snap.name] or DayCycle.presets.day)
        DayCycle.setSpeed(0)
    end
    Surface.init()
    Water.init()
    Substrate.init()

    PostFX.init(C.W, C.H, {
        distortion = { enabled = true, strength = 0.0012, speed = 0.5 },
        bloom = { enabled = true, threshold = 0.6, intensity = 0.5 },
        colorGrade = { enabled = true, vignetteRadius = 0.68, highlightTint = { 1.02, 1.01, 0.99 } },
    })
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    time = time + dt

    DayCycle.update(dt)
    DayCycle.applyPost(PostFX)
    Current.update(dt)
    Surface.update(dt)
    Water.update(dt)
    Substrate.update(dt)
    PostFX.update(dt)

    if snap then
        if time >= snap.at and not snap.taken then
            love.filesystem.createDirectory("snaps")
            love.graphics.captureScreenshot("snaps/" .. snap.name .. ".png")
            snap.taken = time
        elseif snap.taken and time > snap.taken + 0.3 then
            love.event.quit()
        end
    end
end

local function drawScene()
    local scene = Render.canvas("scene")
    love.graphics.setCanvas(scene)
    love.graphics.clear(0, 0, 0, 1)

    Water.drawBackground(env)
    Water.drawRays(env, 1.0)
    Substrate.drawBed(env, Water.time())

    Render.beginObjects(env)
    for _, r in ipairs(Substrate.getRocks()) do
        Substrate.drawRock(r)
    end
    love.graphics.setShader()

    Water.drawRays(env, 0.35)
    Substrate.drawFront()

    love.graphics.setCanvas()
end

local function composite()
    local sh = Render.shader("composite")
    love.graphics.setColor(1, 1, 1, 1)
    if sh then
        love.graphics.setShader(sh)
        sh:send("surfaceTex", Surface.texture())
        sh:send("frontY", C.SURFACE_Y)
        sh:send("backY", World.surfaceScreenY(0))
        sh:send("airColor", env.air)
        sh:send("lamp", env.lamp)
        sh:send("lightColor", env.light)
        sh:send("lightI", env.light_i)
        sh:send("time", time)
        sh:send("size", { C.W, C.H })
        sh:send("tap", { 0, 0, 0, 0 })
        sh:send("aberration", 0.010)
        sh:send("grain", 0.012)
    end
    love.graphics.draw(Render.canvas("scene"))
    love.graphics.setShader()
end

function love.draw()
    Render.updateCaustics(Water.time())
    drawScene()

    PostFX.beginScene()
    composite()
    local scale, ox, oy = Scaling.getTransform()
    PostFX.endScene(scale, ox, oy)
end

function love.resize(w, h)
    Scaling.update()
    PostFX.resize(C.W, C.H)
end

function love.keypressed(key)
    PostFX.handleKeyPress(key)
    if key == "t" then DayCycle.skip() end
    if key == "escape" then love.event.quit() end
end
