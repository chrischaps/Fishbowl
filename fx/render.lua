-- Render helpers: shaders, canvases and the shared object-lighting pass

local C = require("config")
local World = require("world")

local Render = {}

local shaders = {}
local canvases = {}
local white, blob, inverseBlob
local currentEnv
local objectHaze = -1

local function loadShader(name)
    local ok, result = pcall(love.graphics.newShader, "shaders/" .. name .. ".glsl")
    if not ok then
        print("[Fishbowl] shader error in " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

-- A soft radial falloff used for glows, shadows and motes
local function makeBlob(size, inverse)
    local data = love.image.newImageData(size, size)
    local r = size / 2
    data:mapPixel(function(x, y)
        local dx, dy = (x + 0.5 - r) / r, (y + 0.5 - r) / r
        local d = math.sqrt(dx * dx + dy * dy)
        local a = math.max(0, 1 - d)
        a = a * a * (3 - 2 * a)
        if inverse then
            local v = 1 - a * 0.92
            return v, v, v, v
        end
        return 1, 1, 1, a
    end)
    local img = love.graphics.newImage(data)
    img:setFilter("linear", "linear")
    return img
end

function Render.init()
    for _, name in ipairs({ "water", "rays", "caustics", "object", "floor", "blur", "haze", "composite" }) do
        shaders[name] = loadShader(name)
    end

    local w, h = C.W, C.H
    local hdr = { format = "rgba16f" }
    canvases.scene = love.graphics.newCanvas(w, h, hdr)
    canvases.far = love.graphics.newCanvas(w, h, hdr)
    canvases.farA = love.graphics.newCanvas(w / 2, h / 2, hdr)
    canvases.farB = love.graphics.newCanvas(w / 2, h / 2, hdr)
    canvases.caustics = love.graphics.newCanvas(w / 2, h / 2)
    for _, c in pairs(canvases) do c:setFilter("linear", "linear") end

    local px = love.image.newImageData(1, 1)
    px:setPixel(0, 0, 1, 1, 1, 1)
    white = love.graphics.newImage(px)
    blob = makeBlob(64)
    inverseBlob = makeBlob(64, true)
end

function Render.shader(name) return shaders[name] end
function Render.canvas(name) return canvases[name] end
function Render.white() return white end
function Render.blob() return blob end
function Render.inverseBlob() return inverseBlob end

--- Draw a full-rect quad with uv 0..1 (for shader passes)
function Render.quad(x, y, w, h)
    love.graphics.draw(white, x or 0, y or 0, 0, w or C.W, h or C.H)
end

--- Draw the soft blob centered at x, y with radii rx, ry
function Render.drawBlob(x, y, rx, ry, angle)
    love.graphics.draw(blob, x, y, angle or 0, rx / 32, (ry or rx) / 32, 32, 32)
end

--- Update the caustic light canvas for this frame
function Render.updateCaustics(time)
    local sh = shaders.caustics
    if not sh then return end
    love.graphics.push("all")
    love.graphics.setCanvas(canvases.caustics)
    love.graphics.setShader(sh)
    sh:send("time", time)
    sh:send("size", { C.W, C.H })
    sh:send("scale", 260)
    Render.quad(0, 0, C.W / 2, C.H / 2)
    love.graphics.pop()
end

--- Configure the object shader for this frame from the day-cycle env
function Render.beginObjects(env)
    currentEnv = env
    local sh = shaders.object
    if not sh then return end
    sh:send("ambient", env.ambient)
    sh:send("fog", env.fog)
    sh:send("caustics", canvases.caustics)
    sh:send("causticColor", env.light)
    sh:send("causticGain", env.caustic * env.light_i * 0.55)
    sh:send("size", { C.W, C.H })
    objectHaze = -1
end

--- Bind the object shader for something at depth d
function Render.useObject(d, causticScale)
    local sh = shaders.object
    if not sh then
        love.graphics.setShader()
        return
    end
    love.graphics.setShader(sh)
    local h = World.haze(d) * currentEnv.haze
    if math.abs(h - objectHaze) > 0.004 then
        sh:send("haze", h)
        objectHaze = h
    end
    if causticScale then
        sh:send("causticGain", currentEnv.caustic * currentEnv.light_i * 0.55 * causticScale)
    end
end

function Render.restoreCausticGain()
    local sh = shaders.object
    if sh and currentEnv then
        sh:send("causticGain", currentEnv.caustic * currentEnv.light_i * 0.55)
    end
end

--- Blur the far layer at half resolution (depth of field)
function Render.blurFar()
    local blur = shaders.blur
    if not blur then return canvases.far end
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.setCanvas(canvases.farA)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(blur)
    blur:send("dir", { 2.5 / C.W, 0 })
    love.graphics.draw(canvases.far, 0, 0, 0, 0.5, 0.5)

    love.graphics.setCanvas(canvases.farB)
    love.graphics.clear(0, 0, 0, 0)
    blur:send("dir", { 0, 3 / C.H })
    love.graphics.draw(canvases.farA)

    love.graphics.setCanvas(canvases.farA)
    love.graphics.clear(0, 0, 0, 0)
    blur:send("dir", { 3 / C.W, 0 })
    love.graphics.draw(canvases.farB)

    love.graphics.pop()
    return canvases.farA
end

return Render
