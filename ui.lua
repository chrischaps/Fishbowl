-- Quiet UI: a caption that fades in when you rest the cursor on a fish,
-- a small toast for settings changes, and a help card on H.

local World = require("world")

local UI = {}

local captionFont, smallFont, titleFont
local caption = { fish = nil, alpha = 0, x = 0, y = 0 }
local toast = { text = nil, t = 0 }
local helpAlpha, helpOn = 0, false

function UI.init()
    captionFont = love.graphics.newFont(15)
    smallFont = love.graphics.newFont(12)
    titleFont = love.graphics.newFont(20)
end

function UI.toast(text)
    toast.text, toast.t = text, 2.4
end

function UI.toggleHelp()
    helpOn = not helpOn
end

function UI.update(dt, hovered)
    if hovered then
        if caption.fish ~= hovered then
            caption.fish = hovered
            caption.alpha = 0
        end
        caption.alpha = math.min(1, caption.alpha + dt * 2.5)
    else
        caption.alpha = math.max(0, caption.alpha - dt * 1.5)
        if caption.alpha == 0 then caption.fish = nil end
    end
    if caption.fish then
        local f = caption.fish
        local sx, sy, k = World.project(f.x, f.y, f.z)
        local tx, ty = sx, sy - f.L * k * 0.9 - 26
        caption.x = caption.x + (tx - caption.x) * math.min(1, dt * 6)
        caption.y = caption.y + (ty - caption.y) * math.min(1, dt * 6)
    end
    toast.t = math.max(0, toast.t - dt)
    helpAlpha = helpAlpha + ((helpOn and 1 or 0) - helpAlpha) * math.min(1, dt * 6)
end

local function softText(font, text, x, y, a, align, width)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0.02, 0.04, a * 0.55)
    love.graphics.printf(text, x + 1, y + 1, width, align)
    love.graphics.setColor(0.94, 0.97, 0.98, a)
    love.graphics.printf(text, x, y, width, align)
end

--- Draw in game coordinates (inside the scaling transform)
function UI.draw(moodOf)
    local f = caption.fish
    if f and caption.alpha > 0 then
        local a = caption.alpha
        local x, y = caption.x - 150, caption.y
        softText(captionFont, f.name, x, y - 4, a, "center", 300)
        softText(smallFont, f.sp.label .. "  ·  " .. moodOf(f), x, y + 14, a * 0.75, "center", 300)
    end

    if toast.text and toast.t > 0 then
        local a = math.min(1, toast.t * 2)
        softText(smallFont, toast.text, 0, 680, a * 0.85, "center", 1280)
    end

    if helpAlpha > 0.01 then
        local a = helpAlpha
        love.graphics.setColor(0.02, 0.05, 0.07, 0.55 * a)
        love.graphics.rectangle("fill", 440, 200, 400, 300, 14, 14)
        softText(titleFont, "Fishbowl", 440, 222, a, "center", 400)
        local lines = {
            "click            sprinkle food",
            "right click      tap the glass",
            "rest the cursor  meet a fish",
            "T                skip ahead in the day",
            "[  ]             slow / speed the day",
            "R                follow your clock",
            "M                mute",
            "F12              save a picture",
            "F1 - F4          post effects",
            "H                close",
        }
        for i, l in ipairs(lines) do
            softText(smallFont, l, 500, 258 + i * 21, a * 0.85, "left", 320)
        end
    end
end

return UI
