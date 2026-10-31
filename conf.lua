local function has(flag)
    for _, a in ipairs(arg or {}) do
        if a == flag then return true end
    end
    return false
end

function love.conf(t)
    t.identity = "Fishbowl"
    t.version = "11.5"
    t.window.title = "Fishbowl"
    t.window.width = 1280
    t.window.height = 720
    t.window.vsync = 1
    if has("--frame") then
        -- --frame (frame.lua): all of the wall frame's 1280 x 720 panel, with
        -- nothing around it, as Easel's app contract asks
        t.window.fullscreen = true
        t.window.fullscreentype = "desktop"
        t.window.borderless = true
        t.window.resizable = false
    else
        t.console = true -- a console window for debug output (Windows)
        t.window.resizable = true
        t.window.minwidth = 800
        t.window.minheight = 600
    end
end
