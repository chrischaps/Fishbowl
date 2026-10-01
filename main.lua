-- Fishbowl: an ambient aquarium
-- A planted tank seen through its front glass, living through a day and a night.

-- Shared libraries (LoveLibs subtree)
local PostFX = require("LoveLibs.graphics.postfx")
local Scaling = require("LoveLibs.graphics.scaling")
local Debug = require("LoveLibs.core.debug")

local C = require("config")
local World = require("world")
local Render = require("fx.render")
local DayCycle = require("env.daycycle")
local Surface = require("env.surface")
local Water = require("env.water")
local Current = require("env.current")
local Substrate = require("env.substrate")
local Driftwood = require("env.driftwood")
local Plants = require("env.plants")
local Motes = require("env.motes")
local Glass = require("env.glass")
local Fish = require("fish")
local Bubble = require("bubble")
local Food = require("food")
local Ambience = require("audio.ambience")
local UI = require("ui")
local Save = require("save")

local env = DayCycle.env
local time = 0
local snap = nil          -- { name, at } when running with --snap
local cursor = { x = 0, y = 0, active = false, still = 0 }
local drawList = {}
local saveTimer = 0
local hovered = nil

local function parseArgs(args)
    for i, a in ipairs(args or {}) do
        if a == "--snap" then
            -- --snap <time of day> <seconds> [feed]: render, save a PNG, quit
            snap = { name = args[i + 1] or "day", at = tonumber(args[i + 2]) or 4, feed = args[i + 3] == "feed" }
        elseif a == "--selftest" then
            -- Drives every interaction on a timeline, then saves a picture and quits
            snap = { name = "selftest", at = 9, selftest = true }
        elseif a == "--seed" then
            C.SCAPE_SEED = tonumber(args[i + 1]) or C.SCAPE_SEED
        end
    end
end

function love.load(args)
    parseArgs(args)
    love.graphics.setBackgroundColor(0, 0, 0)

    Scaling.init(C.W, C.H)
    Render.init()
    DayCycle.init()
    if snap then
        DayCycle.set(DayCycle.presets[snap.name] or DayCycle.presets.day)
        DayCycle.setSpeed(0)
    end
    Surface.init()
    Water.init()

    math.randomseed(C.SCAPE_SEED)
    Substrate.init()
    Driftwood.init()
    Plants.init(Driftwood.anchors())
    math.randomseed(os.time())

    Motes.init(140)
    Glass.init()
    Fish.init(Save.load())
    UI.init()
    Ambience.init()
    if snap then love.audio.setVolume(0) end

    PostFX.init(C.W, C.H, {
        distortion = { enabled = true, strength = 0.0010, speed = 0.5 },
        bloom = { enabled = true, threshold = 0.6, intensity = 0.5 },
        colorGrade = { enabled = true, vignetteRadius = 0.68, highlightTint = { 1.02, 1.01, 0.99 } },
    })

    Debug.addGlobalInfo("Time of day", function() return env.name end)
    Debug.addGlobalInfo("Day speed", function() return DayCycle.getSpeed() .. "x" end)
    Debug.addGlobalInfo("Bubbles", function() return tostring(#Bubble.all()) end)
    Debug.addGlobalInfo("Food", function() return tostring(#Food.all()) end)
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------
local cursorOverride = nil

local debugInfo = {
    getDebugInfo = function()
        local info = { { section = "Fish" } }
        for _, f in ipairs(Fish.all()) do
            if f.key ~= "neon" then
                info[#info + 1] = { key = f.name, value = f.state .. string.format("  trust %.2f", f.trust) }
            end
        end
        return info
    end,
}

local function selftest()
    local steps = snap.steps or {}
    snap.steps = steps
    local function at(t, name, fn)
        if time >= t and not steps[name] then
            steps[name] = true
            print("[selftest] " .. name)
            fn()
        end
    end
    at(0.5, "feed", function() love.mousepressed(400, 300, 1) end)
    at(1.5, "tap", function() love.mousepressed(700, 380, 2) end)
    at(2.0, "keys", function()
        for _, k in ipairs({ "]", "[", "h", "m", "r", "r", "t", "f11", "f12" }) do love.keypressed(k) end
    end)
    at(3.0, "hover", function()
        local f = Fish.all()[1]
        local sx, sy = World.project(f.x, f.y, f.z)
        cursorOverride = { sx, sy }
    end)
    at(4.5, "resize", function() love.resize(1000, 700) end)
    at(4.8, "save", function()
        Save.write(Fish.snapshot())
        local back = Save.load()
        local f = Fish.all()[1]
        print("[selftest] save round trip: " .. tostring(back and back[f.id] and back[f.id].name == f.name))
    end)
    at(5.0, "night", function()
        love.keypressed("h")
        love.keypressed("m")
        DayCycle.set(DayCycle.presets.night)
    end)
end

local function updateCursor(dt)
    local mx, my = love.mouse.getPosition()
    local gx, gy = Scaling.toGame(mx, my)
    if cursorOverride then
        local f = Fish.all()[1]
        cursorOverride[1], cursorOverride[2] = World.project(f.x, f.y, f.z)
        gx, gy = cursorOverride[1], cursorOverride[2]
    end
    local moved = math.abs(gx - cursor.x) + math.abs(gy - cursor.y)
    cursor.x, cursor.y = gx, gy
    cursor.active = (cursorOverride or love.window.hasMouseFocus()) and gx > 0 and gx < C.W and gy > C.SURFACE_Y and gy < C.H
    if moved < 2 then
        cursor.still = cursor.still + dt
    else
        cursor.still = math.max(0, cursor.still - moved * 0.02)
    end
end

local function handleEvents()
    for _, e in ipairs(Fish.drainEvents()) do
        if e.type == "puff" then
            Substrate.puff(e.x, e.y, e.d, 5)
        elseif e.type == "gulp" then
            local sx = World.project(e.x, e.y, e.d)
            Surface.disturb(sx, 1.4, 2)
            Ambience.gulp(sx)
        elseif e.type == "bubble" then
            Bubble.spawn(e.x, e.y, e.d, 1.2 + math.random() * 1.6, "fish")
        end
    end
    for _, p in ipairs(Bubble.drainPops()) do
        local sx = World.project(p.x, C.SURFACE_Y, p.d)
        Surface.disturb(sx, 0.12 + p.r * 0.08, 1)
        Ambience.pop(sx, p.r)
    end
    for _, e in ipairs(Food.drainEvents()) do
        if e.type == "sprinkle" then
            Surface.disturb(e.x, 1.6, 3)
            Ambience.sprinkle(e.x)
        end
    end
    for _, p in ipairs(Plants.drainPearls()) do
        Bubble.spawn(p.x, p.y, p.d, 0.5 + math.random() * 0.6, "pearl")
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    time = time + dt

    updateCursor(dt)
    DayCycle.update(dt)
    DayCycle.applyPost(PostFX)
    Current.update(dt)
    Surface.update(dt)
    Water.update(dt)
    Substrate.update(dt)
    Fish.update(dt, { env = env, foods = Food.all(), cursor = cursor, rocks = Substrate.getRocks() })
    Plants.update(dt, Fish.all(), env)
    Bubble.update(dt, env)
    Food.update(dt)
    Motes.update(dt)
    Glass.update(dt)
    handleEvents()
    Ambience.update(dt, env)
    Ambience.tick(dt)
    PostFX.update(dt)

    hovered = (cursor.active and cursor.still > 0.25) and Fish.at(cursor.x, cursor.y) or nil
    UI.update(dt, hovered)

    saveTimer = saveTimer + dt
    if saveTimer > 30 and not snap then
        saveTimer = 0
        Save.write(Fish.snapshot())
    end

    if snap then
        if snap.selftest then selftest() end
        if snap.feed and time > 1 and not snap.fed then
            snap.fed = true
            Food.sprinkle(560)
            Food.sprinkle(760)
        end
        if time >= snap.at and not snap.taken then
            love.filesystem.createDirectory("snaps")
            love.graphics.captureScreenshot("snaps/" .. snap.name .. ".png")
            print(string.format("[snap] %s  fps %d", snap.name, love.timer.getFPS()))
            snap.taken = time
        elseif snap.taken and time > snap.taken + 0.3 then
            love.event.quit()
        end
    end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
local function drawObject(o)
    local kind = o.kind
    if kind == "fish" then
        Render.useObject(o.d)
        Fish.draw(o, env)
    elseif kind == "plant" then
        Plants.draw(o, env)
    elseif kind == "bubble" then
        Render.useObject(o.d, 0)
        Bubble.draw(o, env)
    elseif kind == "food" then
        Render.useObject(o.d)
        Food.draw(o, env)
    elseif kind == "rock" then
        Substrate.drawRock(o)
    elseif kind == "wood" then
        Driftwood.draw(o)
    end
end

local function drawShadows()
    for _, f in ipairs(Fish.all()) do
        local height = World.floorY(f.x, f.z) - f.y
        local a = 0.24 * env.light_i * math.max(0, 1 - height / 520)
        if a > 0.01 then
            Substrate.drawShadow(f.x - height * env.angle * 0.6, f.z, f.L * (0.55 + height / 480), a)
        end
    end
    for _, r in ipairs(Substrate.getRocks()) do
        Substrate.drawShadow(r.x + 6, r.d, r.w * 0.7, 0.30 * (0.4 + 0.6 * env.light_i))
    end
end

local function drawScene()
    local scene = Render.canvas("scene")
    love.graphics.setCanvas(scene)
    love.graphics.clear(0, 0, 0, 1)

    Water.drawBackground(env)
    Water.drawRays(env, 1.0)
    Substrate.drawBed(env, Water.time())
    drawShadows()
    Motes.drawBack(env)

    -- Everything in the water, painted back to front
    for i = #drawList, 1, -1 do drawList[i] = nil end
    local function add(list)
        for _, o in ipairs(list) do drawList[#drawList + 1] = o end
    end
    add(Substrate.getRocks())
    drawList[#drawList + 1] = Driftwood.get()
    add(Plants.all())
    add(Fish.all())
    add(Bubble.all())
    add(Food.all())
    table.sort(drawList, function(a, b) return a.d < b.d end)

    Render.beginObjects(env)

    -- The far layer is drawn soft, as a shallow depth of field
    love.graphics.setCanvas(Render.canvas("far"))
    love.graphics.clear(0, 0, 0, 0)
    local i = 1
    while drawList[i] and drawList[i].d < C.FAR_D do
        drawObject(drawList[i])
        i = i + 1
    end
    love.graphics.setShader()
    local soft = Render.blurFar()
    love.graphics.setCanvas(scene)
    local hz = Render.shader("haze")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    if hz then
        love.graphics.setShader(hz)
        hz:send("fog", env.fog)
        hz:send("haze", 0.0)
    end
    love.graphics.draw(soft, 0, 0, 0, 2, 2)
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    for j = i, #drawList do drawObject(drawList[j]) end
    love.graphics.setShader()

    Substrate.drawPuffs(env)
    Plants.drawGlow(env)
    Water.drawRays(env, 0.3)
    Motes.drawFront(env)
    Substrate.drawFront()
    Glass.draw(env, cursor.x)

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
        sh:send("tap", Glass.tapUniform())
        sh:send("aberration", 0.010)
        sh:send("grain", 0.010)
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

    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale)
    UI.draw(Fish.mood)
    love.graphics.pop()

    Debug.draw(debugInfo)
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
function love.mousepressed(x, y, button)
    local gx, gy = Scaling.toGame(x, y)
    if button == 1 then
        Food.sprinkle(gx)
    elseif button == 2 then
        Glass.tap(gx, gy)
        Fish.startle(gx, gy)
        Ambience.tap(gx)
    end
end

function love.keypressed(key)
    PostFX.handleKeyPress(key)
    if key == "t" then
        DayCycle.skip()
    elseif key == "[" or key == "]" then
        local s = DayCycle.getSpeed()
        s = key == "]" and math.min(32, s * 2) or math.max(0.25, s / 2)
        DayCycle.setSpeed(s)
        UI.toast("day speed " .. s .. "x")
    elseif key == "r" then
        UI.toast(DayCycle.toggleLiveClock() and "following your clock" or "running on tank time")
    elseif key == "m" then
        UI.toast(Ambience.toggleMute() and "muted" or "sound on")
    elseif key == "h" then
        UI.toggleHelp()
    elseif key == "f11" then
        Debug.toggle()
    elseif key == "f12" then
        love.filesystem.createDirectory("snaps")
        local name = os.date("snaps/fishbowl-%Y%m%d-%H%M%S.png")
        love.graphics.captureScreenshot(name)
        UI.toast("saved " .. name)
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.resize(w, h)
    Scaling.update()
    PostFX.resize(C.W, C.H)
end

function love.quit()
    if not snap then Save.write(Fish.snapshot()) end
end
