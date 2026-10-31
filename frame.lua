-- The frame: Fishbowl hung on a wall under Easel, the launcher for a
-- Raspberry Pi with a 7" touch panel (chrischaps/easel#35).
--
--   love . --frame
--
-- The window is the whole 1280 x 720 panel, with no border and no cursor
-- (conf.lua). There's no mouse and no keyboard, only a finger on the glass:
--
--   a tap              a pinch of food, from the surface above the finger
--   a finger held      a hand on the glass: the curious fish come to meet it,
--                      and resting it on one tells you its name
--
-- Every touch rings the glass faintly, so the tank answers the moment a
-- finger lands. The tank keeps the room's hours, so night in the tank is
-- night in the room. Easel stops an app with SIGTERM, which SDL turns into
-- love.quit, and main.lua saves the fish there.
--
-- Easel is told the tank is on screen by EASEL_READY on stdout, printed once
-- the first frame has been drawn.

local Scaling = require("LoveLibs.graphics.scaling")
local DayCycle = require("env.daycycle")
local Food = require("food")
local Glass = require("env.glass")

local Frame = {}

Frame.HOLD = 0.35  -- seconds a finger stays before it's a hand, not a tap
Frame.DRIFT = 24   -- how far (game px) a tap may wander and still be a tap
Frame.RING = 0.6   -- how hard a touch rings the glass (a right-click tap is 1)

local on = false
local finger = nil -- the one finger we follow: { id, x, y, x0, y0, t, held }
local frames = 0

function Frame.parse(args)
    for _, a in ipairs(args or {}) do
        if a == "--frame" then on = true end
    end
end

function Frame.active() return on end

--- Called once everything has loaded
function Frame.setup()
    if not on then return end
    love.mouse.setVisible(false)
    if not DayCycle.isLiveClock() then DayCycle.toggleLiveClock() end
    print(string.format("[frame] %dx%d", love.graphics.getWidth(), love.graphics.getHeight()))
    io.stdout:flush()
end

function Frame.update(dt)
    frames = frames + 1
    -- love.run presents each frame after love.draw, so by the second update
    -- the first frame is on the screen
    if on and frames == 2 then
        print("EASEL_READY")
        io.stdout:flush()
    end
    if finger then
        finger.t = finger.t + dt
        if finger.t >= Frame.HOLD then finger.held = true end
    end
end

--- A finger lands (id is a touch id, or "mouse"); x, y are window pixels
function Frame.press(id, x, y)
    if finger then return end -- one finger at a time
    local gx, gy = Scaling.toGame(x, y)
    finger = { id = id, x = gx, y = gy, x0 = gx, y0 = gy, t = 0, held = false }
    Glass.tap(gx, gy, Frame.RING)
end

function Frame.move(id, x, y)
    if not finger or finger.id ~= id then return end
    finger.x, finger.y = Scaling.toGame(x, y)
    local dx, dy = finger.x - finger.x0, finger.y - finger.y0
    if dx * dx + dy * dy > Frame.DRIFT * Frame.DRIFT then finger.held = true end
end

function Frame.release(id, x, y)
    if not finger or finger.id ~= id then return end
    Frame.move(id, x, y)
    if not finger.held then Food.sprinkle(finger.x) end
    finger = nil
end

--- Where a hand rests on the glass, in game pixels, or nil if none does.
--- A tap is over too soon to be one.
function Frame.hand()
    if finger and finger.held then return finger.x, finger.y end
    return nil
end

return Frame
