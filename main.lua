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
local Dev = require("dev")
local Frame = require("frame")

local env = DayCycle.env
local time = 0
local cursor = { x = 0, y = 0, active = false, still = 0 }
local drawList = {}
local saveTimer = 0
local hovered = nil

function love.load(args)
    Dev.parse(args)
    Frame.parse(args)
    love.graphics.setBackgroundColor(0, 0, 0)

    Scaling.init(C.W, C.H)
    Render.init()
    DayCycle.init()
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
    Dev.setup()
    Frame.setup()

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

-- The cursor the fish know: the mouse on a desktop, a hand resting on the
-- glass on the frame (frame.lua), or the self-test's stand-in
local function updateCursor(dt)
    local gx, gy = Dev.cursor()
    local present = gx ~= nil
    if present then
        -- the self-test's
    elseif Frame.active() then
        gx, gy = Frame.hand()
        present = gx ~= nil
        if not present then gx, gy = cursor.x, cursor.y end
    else
        gx, gy = Scaling.toGame(love.mouse.getPosition())
        present = love.window.hasMouseFocus()
    end
    local moved = math.abs(gx - cursor.x) + math.abs(gy - cursor.y)
    cursor.x, cursor.y = gx, gy
    cursor.active = present and gx > 0 and gx < C.W and gy > C.SURFACE_Y and gy < C.H
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

    Frame.update(dt)
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
    if saveTimer > 30 and not Dev.active() then
        saveTimer = 0
        Save.write(Fish.snapshot())
    end

    Dev.update(time)
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
    elseif kind == "airstone" then
        Render.useObject(o.d, 0.6)
        Bubble.drawStone(env)
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
    drawList[#drawList + 1] = Bubble.stone()
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
-- On the frame a finger is all there is (frame.lua). SDL also reports each
-- touch as a mouse event marked istouch; those are left to the touch
-- callbacks, so a panel that sends either kind is read once.
function love.touchpressed(id, x, y)
    if Frame.active() then Frame.press(id, x, y) end
end

function love.touchmoved(id, x, y)
    if Frame.active() then Frame.move(id, x, y) end
end

function love.touchreleased(id, x, y)
    if Frame.active() then Frame.release(id, x, y) end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if Frame.active() and not istouch then Frame.move("mouse", x, y) end
end

function love.mousereleased(x, y, button, istouch)
    if Frame.active() and button == 1 and not istouch then Frame.release("mouse", x, y) end
end

function love.mousepressed(x, y, button, istouch)
    if Frame.active() then
        if button == 1 and not istouch then Frame.press("mouse", x, y) end
        return
    end
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
    if key == "space" then
        -- a pinch somewhere along the middle of the tank: on the frame, its
        -- button feeds the fish
        Food.sprinkle(C.W * (0.3 + math.random() * 0.4))
    elseif key == "t" then
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
    if not Dev.active() then Save.write(Fish.snapshot()) end
end
