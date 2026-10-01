-- Developer modes for checking the tank without sitting in front of it.
--   --snap <time of day> <seconds>           save snaps/<time of day>.png and quit
--   --snap <time of day> <seconds> feed      ...after sprinkling food at 1s
--   --snap <time of day> <seconds> strip <id> also film snaps/stripNN.png following a fish
--   --selftest                               drive every interaction, report, quit
--   --seed <n>                               try a different aquascape
--   --script <file.lua>                      run a capture or test script; it runs before
--                                            anything loads and may return { setup, update(time) }
-- Pictures land in the LÖVE save directory (%APPDATA%/LOVE/Fishbowl/snaps).
-- Scripts are looked up in the save directory first, then the project.

local C = require("config")
local World = require("world")
local DayCycle = require("env.daycycle")
local Fish = require("fish")
local Food = require("food")
local Save = require("save")

local Dev = {}

local mode = nil
local cursorOverride = nil

function Dev.parse(args)
    for i, a in ipairs(args or {}) do
        if a == "--snap" then
            mode = {
                name = args[i + 1] or "day", at = tonumber(args[i + 2]) or 4,
                feed = args[i + 3] == "feed", strip = args[i + 3] == "strip" and args[i + 4],
            }
        elseif a == "--selftest" then
            mode = { name = "selftest", at = 9, selftest = true, steps = {} }
        elseif a == "--seed" then
            C.SCAPE_SEED = tonumber(args[i + 1]) or C.SCAPE_SEED
        elseif a == "--script" then
            local chunk = assert(love.filesystem.load(args[i + 1]))
            mode = { name = "script", hooks = chunk() or {} }
        end
    end
end

function Dev.active() return mode ~= nil end

--- Called after modules are initialized
function Dev.setup()
    if not mode then return end
    if mode.hooks then
        love.audio.setVolume(0)
        if mode.hooks.setup then mode.hooks.setup() end
        return
    end
    DayCycle.set(DayCycle.presets[mode.name] or DayCycle.presets.day)
    DayCycle.setSpeed(0)
    love.audio.setVolume(0)
end

--- The cursor position to use instead of the mouse, if any
function Dev.cursor()
    if not cursorOverride then return nil end
    local f = Fish.all()[1]
    local sx, sy = World.project(f.x, f.y, f.z)
    return sx, sy
end

local function selftest(time)
    local steps = mode.steps
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
    at(3.0, "hover", function() cursorOverride = true end)
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

local function strip()
    mode.frame = (mode.frame or 0) + 1
    if mode.frame % 6 ~= 0 or mode.frame > 6 * 24 then return end
    for _, f in ipairs(Fish.all()) do
        if f.id == mode.strip then
            if mode.frame == 6 then
                -- Bring it near the glass and send it back the way it came, to film a turn
                f.z = 0.85
                f.tx, f.ty, f.tz = f.x - math.cos(f.psi) * 400, f.y, f.z
                f.wanderTimer, f.state = 20, "wander"
            end
            local sx, sy = World.project(f.x, f.y, f.z)
            local n = mode.frame / 6
            love.filesystem.createDirectory("snaps")
            love.graphics.captureScreenshot(string.format("snaps/strip%02d.png", n))
            print(string.format("[strip] %02d %d %d %.2f", n, sx, sy, f.psi))
        end
    end
end

function Dev.update(time)
    if not mode then return end
    if mode.hooks then
        if mode.hooks.update then mode.hooks.update(time) end
        return
    end
    if mode.selftest then selftest(time) end
    if mode.strip and time > 2 then strip() end
    if mode.feed and time > 1 and not mode.fed then
        mode.fed = true
        Food.sprinkle(560)
        Food.sprinkle(760)
    end
    if time >= mode.at and not mode.taken then
        love.filesystem.createDirectory("snaps")
        love.graphics.captureScreenshot("snaps/" .. mode.name .. ".png")
        print(string.format("[snap] %s  fps %d", mode.name, love.timer.getFPS()))
        mode.taken = time
    elseif mode.taken and time > mode.taken + 0.3 then
        love.event.quit()
    end
end

return Dev
