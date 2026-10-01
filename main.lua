-- Fishbowl: Ambient Fish Tank Simulation
-- A meditative procedural aquarium
-- Enhanced with atmospheric particles, ethereal glows, and dreamy effects
-- Now with custom post-processing shaders!

-- Add shared library path
package.path = package.path .. ";../lib/?.lua;../lib/?/init.lua"

-- Shared libraries
local PostFX = require("postfx")
local Scaling = require("scaling")
local Particles = require("particles")

-- Game modules
local background = require("background")
local Fish = require("fish")
local Bubble = require("bubble")
local Plant = require("plant")
local Food = require("food")

-- Game state
local fish = {}
local bubbles = {}
local plants = {}
local foodParticles = {}
local mouseX, mouseY = 0, 0

-- Configuration
local NUM_FISH = 6
local NUM_PLANTS = 12

-- Virtual/native resolution (content is designed for this size)
local NATIVE_WIDTH = 1280
local NATIVE_HEIGHT = 720

-- Bubble cluster timer (for occasional grouped bubbles)
local clusterTimer = 0
local clusterInterval = 8 + math.random() * 6

function love.load()
    love.graphics.setBackgroundColor(0, 0, 0)  -- Black letterbox/pillarbox
    math.randomseed(os.time())

    -- Initialize scaling system
    Scaling.init(NATIVE_WIDTH, NATIVE_HEIGHT)

    -- Initialize background with native resolution
    background.init(NATIVE_WIDTH, NATIVE_HEIGHT)

    -- Warm sunset palette - cohesive, stylized colors
    local fishColors = {
        {1.0, 0.45, 0.2},   -- Warm orange
        {1.0, 0.65, 0.3},   -- Golden amber
        {0.95, 0.35, 0.35}, -- Coral red
        {0.85, 0.25, 0.45}, -- Deep magenta
        {1.0, 0.8, 0.4},    -- Soft gold
    }

    for i = 1, NUM_FISH do
        local color = fishColors[(i - 1) % #fishColors + 1]
        local newFish = Fish.new(
            math.random(100, NATIVE_WIDTH - 100),
            math.random(100, NATIVE_HEIGHT - 150),
            color
        )
        table.insert(fish, newFish)
    end

    -- Spawn plants along the bottom
    for i = 1, NUM_PLANTS do
        local x = (i - 1) * (NATIVE_WIDTH / NUM_PLANTS) + math.random(-30, 30) + 50
        local plantType = math.random(1, 3)
        table.insert(plants, Plant.new(x, NATIVE_HEIGHT - 50, plantType))
    end

    -- Initialize floating particles with warm sunset colors
    Particles.init(NATIVE_WIDTH, NATIVE_HEIGHT, {
        colors = {
            normal = {1, 0.85, 0.7},      -- Warm amber
            lit = {1, 0.9, 0.7},          -- Bright golden
            glow = {1, 0.9, 0.75}         -- Warm glow
        }
    })
    Particles.setLightRays(background.getLightRays())

    -- Initialize post-processing with warm sunset color grading
    PostFX.init(NATIVE_WIDTH, NATIVE_HEIGHT, {
        distortion = { enabled = true, strength = 0.006, speed = 0.7 },
        bloom = { enabled = true, threshold = 0.50, intensity = 0.6 },
        colorGrade = {
            enabled = true,
            saturation = 0.15,
            contrast = 0.10,
            warmth = 0.12,
            vignetteStrength = 0.35,
            vignetteRadius = 0.65,
            shadowTint = {0.25, 0.12, 0.05},
            highlightTint = {1.04, 1.02, 0.98}
        }
    })
end

function love.update(dt)
    -- Convert mouse position to game coordinates
    local screenMouseX, screenMouseY = love.mouse.getPosition()
    mouseX, mouseY = Scaling.toGame(screenMouseX, screenMouseY)

    -- Update background effects
    background.update(dt)

    -- Update floating particles
    Particles.update(dt, NATIVE_WIDTH, NATIVE_HEIGHT)

    -- Update fish (use native resolution)
    for i, f in ipairs(fish) do
        Fish.update(f, dt, NATIVE_WIDTH, NATIVE_HEIGHT, mouseX, mouseY, foodParticles, fish)
    end

    -- Update fish wake particles
    Fish.updateWakeParticles(dt)

    -- Update bubbles
    Bubble.updateAll(bubbles, dt, NATIVE_WIDTH, NATIVE_HEIGHT)

    -- Spawn new bubbles occasionally (more frequent small bubbles)
    if math.random() < dt * 0.8 then
        table.insert(bubbles, Bubble.new(math.random(50, NATIVE_WIDTH - 50), NATIVE_HEIGHT - 30))
    end

    -- Occasional bubble clusters for visual interest
    clusterTimer = clusterTimer + dt
    if clusterTimer > clusterInterval then
        clusterTimer = 0
        clusterInterval = 6 + math.random() * 8
        local clusterX = math.random(80, NATIVE_WIDTH - 80)
        local clusterBubbles = Bubble.newCluster(clusterX, NATIVE_HEIGHT - 30, math.random(3, 5))
        for _, b in ipairs(clusterBubbles) do
            table.insert(bubbles, b)
        end
    end

    -- Update plants
    for _, p in ipairs(plants) do
        Plant.update(p, dt, fish)
    end

    -- Update food particles
    Food.updateAll(foodParticles, dt, NATIVE_HEIGHT)

    -- Update post-processing time
    PostFX.update(dt)
end

function love.draw()
    -- Begin post-processing pipeline (render to canvas at native resolution)
    PostFX.beginScene()

    -- Draw background (gradient, light rays)
    background.drawBack(NATIVE_WIDTH, NATIVE_HEIGHT)

    -- Draw back-layer floating particles (behind everything)
    Particles.drawBack()

    -- Draw plants (behind fish)
    for _, p in ipairs(plants) do
        Plant.draw(p)
    end

    -- Draw fish wake particles (behind fish bodies)
    Fish.drawWakeParticles()

    -- Draw fish
    for _, f in ipairs(fish) do
        Fish.draw(f)
    end

    -- Draw bubbles
    for _, b in ipairs(bubbles) do
        Bubble.draw(b)
    end

    -- Draw front-layer floating particles (in front of fish)
    Particles.drawFront()

    -- Draw food
    for _, food in ipairs(foodParticles) do
        Food.draw(food)
    end

    -- Draw foreground effects (caustics on sand)
    background.drawFront(NATIVE_WIDTH, NATIVE_HEIGHT)

    -- End post-processing (apply effects and output to screen with scaling)
    local scale, offsetX, offsetY = Scaling.getTransform()
    PostFX.endScene(scale, offsetX, offsetY)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Convert screen coordinates to game coordinates
        local gameX, gameY = Scaling.toGame(x, y)

        -- Drop food at cursor position (in game coordinates)
        for i = 1, math.random(3, 5) do
            local ox = math.random(-20, 20)
            local oy = math.random(-10, 10)
            table.insert(foodParticles, Food.new(gameX + ox, gameY + oy))
        end
    end
end

function love.resize(w, h)
    -- Update scaling factors
    Scaling.update()

    -- Recreate shader canvases at native resolution
    PostFX.resize(NATIVE_WIDTH, NATIVE_HEIGHT)
end

function love.keypressed(key)
    -- Pass to post-processing controls (F1-F4)
    PostFX.handleKeyPress(key)

    -- ESC to quit
    if key == "escape" then
        love.event.quit()
    end
end
