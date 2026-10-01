-- Procedural tank sound: the air pump's hum, the trickle of the bubble
-- column, pops at the surface, and small sounds for the things you do.
-- Everything is synthesized at load; nothing ships as an audio file.

local C = require("config")
local Music = require("LoveLibs.audio.music")

local Ambience = {}

local RATE = 44100
local random = math.random
local sin, exp, pi = math.sin, math.exp, math.pi

local loops = {}
local banks = {}
local muted = false
local plipTimer = 0
local volume = 1

--------------------------------------------------------------------------------
-- Synthesis helpers
--------------------------------------------------------------------------------
local function render(duration, fn)
    local n = math.floor(RATE * duration)
    local data = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local v = fn(i / RATE, i, n)
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        data:setSample(i, v)
    end
    return data
end

--- A seamless loop: the tail is crossfaded into the head
local function renderLoop(duration, fade, fn)
    local total = duration + fade
    local n = math.floor(RATE * total)
    local buf = {}
    for i = 0, n - 1 do buf[i] = fn(i / RATE, i) end
    local m = math.floor(RATE * duration)
    local f = math.floor(RATE * fade)
    local data = love.sound.newSoundData(m, RATE, 16, 1)
    for i = 0, m - 1 do
        local v = buf[i]
        if i < f then
            local t = i / f
            v = v * t + buf[m + i] * (1 - t)
        end
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        data:setSample(i, v)
    end
    return data
end

local function source(data, looping)
    local s = love.audio.newSource(data, "static")
    s:setLooping(looping or false)
    return s
end

local function bank(name, variants, copies)
    local b = { sources = {}, next = 1 }
    for _, data in ipairs(variants) do
        for _ = 1, copies do
            b.sources[#b.sources + 1] = source(data)
        end
    end
    -- Shuffle so variants interleave
    for i = #b.sources, 2, -1 do
        local j = random(i)
        b.sources[i], b.sources[j] = b.sources[j], b.sources[i]
    end
    banks[name] = b
end

local function play(name, vol, pitch, x)
    if muted then return end
    local b = banks[name]
    if not b then return end
    local s = b.sources[b.next]
    b.next = b.next % #b.sources + 1
    s:stop()
    s:setVolume((vol or 1) * volume)
    s:setPitch(pitch or 1)
    local pan = x and ((x / C.W) * 2 - 1) * 0.8 or 0
    s:setPosition(pan, 0, -1)
    s:play()
end

--------------------------------------------------------------------------------
-- Sounds
--------------------------------------------------------------------------------
local function makePlip(f0, len, bright)
    return render(len, function(t)
        local f = f0 * (1 + 0.9 * t / len)
        local env = exp(-t / (len * 0.28)) * math.min(1, t * 2000)
        return sin(2 * pi * f * t) * env * 0.5 + (random() * 2 - 1) * bright * exp(-t * 900) * 0.3
    end)
end

local function makeHum()
    local lp = 0
    return renderLoop(2.0, 0.25, function(t)
        lp = lp + ((random() * 2 - 1) - lp) * 0.02
        local hum = sin(2 * pi * 60 * t) * 0.30 + sin(2 * pi * 120 * t) * 0.20 + sin(2 * pi * 180 * t) * 0.05
        local rattle = 1 + 0.15 * sin(2 * pi * 30 * t)
        return (hum * rattle + lp * 0.9) * 0.5
    end)
end

local function makeWaterBed()
    local brown, lp = 0, 0
    return renderLoop(6.0, 1.0, function(t)
        brown = brown * 0.995 + (random() * 2 - 1) * 0.06
        lp = lp + (brown - lp) * 0.08
        local swell = 0.75 + 0.25 * sin(2 * pi * t / 3) * sin(2 * pi * t / 2)
        return lp * swell * 1.4
    end)
end

local function makeThud()
    return render(0.6, function(t)
        local body = sin(2 * pi * (88 - 30 * t) * t) * exp(-t * 9) * 0.9
        local ring = (sin(2 * pi * 1650 * t) * 0.5 + sin(2 * pi * 2890 * t) * 0.3 + sin(2 * pi * 4120 * t) * 0.15) * exp(-t * 16) * 0.35
        local click = (random() * 2 - 1) * exp(-t * 700) * 0.6
        return (body + ring + click) * 0.8
    end)
end

local function makeTick()
    return render(0.07, function(t)
        local ping = sin(2 * pi * 2300 * t) * exp(-t * 90) * 0.35
        local grit = (random() * 2 - 1) * exp(-t * 400) * 0.25
        return ping + grit
    end)
end

local function makeGulp()
    return render(0.16, function(t)
        local f = 240 - 500 * t
        local env = math.sin(pi * math.min(1, t / 0.12)) * exp(-t * 8)
        return sin(2 * pi * f * t) * env * 0.6
    end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------
function Ambience.init()
    love.audio.setDistanceModel("none")

    loops.hum = source(makeHum(), true)
    loops.water = source(makeWaterBed(), true)
    loops.hum:setVolume(0.07)
    loops.water:setVolume(0.16)
    loops.hum:play()
    loops.water:play()

    bank("plip", {
        makePlip(700, 0.04, 0.2), makePlip(900, 0.035, 0.2), makePlip(1150, 0.03, 0.3),
        makePlip(560, 0.05, 0.15), makePlip(1350, 0.025, 0.3),
    }, 3)
    bank("pop", { makePlip(1000, 0.03, 0.6), makePlip(1400, 0.025, 0.7), makePlip(800, 0.04, 0.5) }, 3)
    bank("thud", { makeThud() }, 2)
    bank("tick", { makeTick() }, 6)
    bank("gulp", { makeGulp() }, 2)

    Music.play("calm")
    Music.setVolume(0.10)
end

function Ambience.update(dt, env)
    Music.update(dt)
    -- Night is hushed; the pump never sleeps
    local quiet = 1 - env.glow * 0.45
    if loops.water then loops.water:setVolume(0.16 * quiet * volume) end
    if loops.hum then loops.hum:setVolume(0.07 * volume) end
    Music.setVolume((0.06 + 0.05 * (1 - env.glow)) * volume)

    -- The bubble column's trickle, panned to the air stone
    plipTimer = plipTimer - dt
    if plipTimer <= 0 then
        plipTimer = 0.04 + random() * 0.14
        play("plip", 0.05 + random() * 0.07, 0.85 + random() * 0.4, C.BUBBLER_X)
    end
end

function Ambience.pop(x, r)
    if random() < 0.35 then
        play("pop", 0.04 + math.min(0.12, r * 0.03), 1.4 - math.min(0.6, r * 0.12), x)
    end
end

function Ambience.sprinkle(x)
    for i = 0, 4 do
        -- A few soft ticks as the flakes land
        Ambience.later(i * 0.05 + random() * 0.04, function()
            play("tick", 0.18 + random() * 0.12, 0.8 + random() * 0.5, x)
        end)
    end
end

function Ambience.tap(x)
    play("thud", 0.9, 0.95 + random() * 0.1, x)
end

function Ambience.gulp(x)
    play("gulp", 0.35, 0.9 + random() * 0.2, x)
end

-- Tiny scheduler for staggered one-shots
local pending = {}
function Ambience.later(delay, fn)
    pending[#pending + 1] = { t = delay, fn = fn }
end

function Ambience.tick(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(pending, i)
            p.fn()
        end
    end
end

function Ambience.toggleMute()
    muted = not muted
    love.audio.setVolume(muted and 0 or 1)
    return muted
end

function Ambience.isMuted() return muted end

return Ambience
