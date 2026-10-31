-- Developer modes for checking the tank without sitting in front of it.
--   --snap <time of day> <seconds>           save snaps/<time of day>.png and quit
--   --snap <time of day> <seconds> feed      ...after sprinkling food at 1s
--   --snap <time of day> <seconds> strip <id> also film snaps/stripNN.png following a fish
--   --selftest                               drive every interaction, report, quit: exit 0 if
--                                            every check held, 1 if one failed or the game erred
--   --bench <seconds>                        time that many seconds of frames, after 3 s to settle,
--                                            print median / p95 / worst, quit (try it with --frame)
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
local Frame = require("frame")

local Dev = {}

local mode = nil
local cursorOverride = nil

-- A test that errs has to say so and exit, not wait on LÖVE's error screen:
-- Easel runs --selftest as a release's smoke test, with no one to close it
local function exitOnError(tag)
    function love.errorhandler(msg)
        print(debug.traceback(string.format("[%s] FAIL %s", tag, tostring(msg)), 2))
        io.stdout:flush()
        return function() return 1 end
    end
end

function Dev.parse(args)
    for i, a in ipairs(args or {}) do
        if a == "--snap" then
            mode = {
                name = args[i + 1] or "day", at = tonumber(args[i + 2]) or 4,
                feed = args[i + 3] == "feed", strip = args[i + 3] == "strip" and args[i + 4],
            }
        elseif a == "--selftest" then
            mode = { name = "selftest", at = 9, selftest = true, steps = {}, failed = 0 }
            -- a tank of its own, fresh each time
            Save.use("selftest-tank.lua")
            love.filesystem.remove("selftest-tank.lua")
            exitOnError("selftest")
        elseif a == "--bench" then
            mode = { name = "day", bench = tonumber(args[i + 1]) or 20, times = {} }
            exitOnError("bench")
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
    local function check(what, ok)
        print(string.format("[selftest]   %s: %s", ok and "ok" or "FAIL", what))
        if not ok then mode.failed = mode.failed + 1 end
    end
    -- the flakes in the water before this frame's step (nothing eats them in
    -- the middle of Dev.update)
    local food = #Food.all()
    if Frame.active() then
        at(0.2, "frame", function()
            local _, _, flags = love.window.getMode()
            check("the frame is fullscreen, borderless and has no cursor",
                love.window.getFullscreen() and flags.borderless and not love.mouse.isVisible())
        end)
    end
    -- a click on a desktop, a tap on the frame
    at(0.5, "feed", function()
        love.mousepressed(400, 300, 1)
        love.mousereleased(400, 300, 1)
        check("a click feeds the fish", #Food.all() > food)
    end)
    at(1.5, "tap", function() love.mousepressed(700, 380, 2) end)
    at(2.0, "keys", function()
        for _, k in ipairs({ "]", "[", "h", "m", "r", "r", "t", "f11", "f12" }) do love.keypressed(k) end
        love.keypressed("space")
        check("the button's key (space) feeds the fish", #Food.all() > food)
    end)
    at(3.0, "hover", function() cursorOverride = true end)
    at(4.5, "resize", function() love.resize(1000, 700) end)
    at(4.8, "save", function()
        Save.write(Fish.snapshot())
        local back = Save.load()
        local f = Fish.all()[1]
        check("the tank saves and loads (" .. Save.file() .. ")",
            back and back[f.id] and back[f.id].name == f.name)
    end)
    at(5.0, "night", function()
        love.keypressed("h")
        love.keypressed("m")
        DayCycle.set(DayCycle.presets.night)
    end)
    -- a finger on the frame's glass (frame.lua), driven directly so it's
    -- checked whether or not this run is --frame
    at(5.2, "finger tap", function()
        Frame.press("selftest", 640, 360)
        Frame.release("selftest", 640, 360)
        check("a tap on the glass feeds the fish", #Food.all() > food)
        check("a tap isn't a hand", Frame.hand() == nil)
    end)
    at(5.4, "finger held", function() Frame.press("selftest", 500, 420) end)
    at(5.4 + Frame.HOLD + 0.3, "finger lifted", function()
        check("a finger held on the glass is a hand", Frame.hand() ~= nil)
        Frame.release("selftest", 500, 420)
        check("a hand doesn't feed the fish", #Food.all() == food)
        check("a lifted hand has gone", Frame.hand() == nil)
    end)
    at(6.5, "a guest who taps and taps", function()
        for _ = 1, 200 do
            Frame.press("selftest", 640, 360)
            Frame.release("selftest", 640, 360)
        end
        check("the tank takes no more than " .. Food.MAX .. " flakes", #Food.all() <= Food.MAX)
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

-- Frame times as the screen sees them: love.timer's delta is the whole of a
-- frame, its wait for vsync included, so 60 fps reads as about 16.7 ms
local function bench(time)
    local settle = 3
    if time < settle then return end
    local t = mode.times
    t[#t + 1] = love.timer.getDelta() * 1000
    if time < settle + mode.bench then return end
    table.sort(t)
    local function q(p) return t[math.max(1, math.ceil(#t * p))] end
    print(string.format("[bench] %d frames at %dx%d, %s: median %.2f ms, p95 %.2f, worst %.2f (%.1f fps)",
        #t, love.graphics.getWidth(), love.graphics.getHeight(), DayCycle.env.name or "?",
        q(0.5), q(0.95), t[#t], #t / mode.bench))
    io.stdout:flush()
    love.event.quit(0)
end

function Dev.update(time)
    if not mode then return end
    if mode.hooks then
        if mode.hooks.update then mode.hooks.update(time) end
        return
    end
    if mode.bench then
        bench(time)
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
        if mode.selftest then
            print(mode.failed == 0 and "[selftest] all checks held"
                or string.format("[selftest] FAIL %d check(s)", mode.failed))
            love.event.quit(mode.failed == 0 and 0 or 1)
        else
            love.event.quit()
        end
    end
end

return Dev
