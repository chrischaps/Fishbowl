-- Background rendering: gradient water, sand, rocks, light rays
-- Enhanced for meditative atmosphere

local background = {}

-- State
local time = 0
local rocks = {}
local lightRays = {}
local moodPhase = 0  -- For subtle color shifts

-- Warm sunset palette colors
local waterTop = {0.35, 0.22, 0.28}      -- Warm dusky mauve
local waterBottom = {0.18, 0.10, 0.12}   -- Deep warm brown
local sandColor = {0.85, 0.65, 0.40}     -- Warm golden sand
local sandDark = {0.70, 0.50, 0.30}      -- Amber shadow
local rockColor = {0.40, 0.28, 0.25}     -- Warm brown rock
local rockHighlight = {0.55, 0.40, 0.35} -- Amber-tinted highlight

-- Mood system for subtle warm color drifts
local moodColors = {
    { shift = {0, 0, 0}, name = "neutral" },
    { shift = {0.04, 0.02, 0.01}, name = "golden" },
    { shift = {0.02, 0.0, -0.02}, name = "amber" },
    { shift = {0.03, 0.01, 0.02}, name = "rose" },
}

function background.init(w, h)
    -- Use provided dimensions or fall back to window size
    w = w or love.graphics.getWidth()
    h = h or love.graphics.getHeight()

    -- Generate random rocks
    rocks = {}
    local numRocks = math.random(4, 7)
    for i = 1, numRocks do
        local rock = {
            x = math.random(50, w - 50),
            y = h - math.random(40, 70),
            width = math.random(40, 100),
            height = math.random(25, 50),
            points = {}
        }
        -- Generate irregular rock shape
        local segments = math.random(6, 10)
        for j = 1, segments do
            local angle = (j - 1) * (2 * math.pi / segments)
            local radiusX = rock.width / 2 * (0.7 + math.random() * 0.3)
            local radiusY = rock.height / 2 * (0.7 + math.random() * 0.3)
            table.insert(rock.points, rock.x + math.cos(angle) * radiusX)
            table.insert(rock.points, rock.y + math.sin(angle) * radiusY * 0.7)
        end
        table.insert(rocks, rock)
    end

    -- Generate warm golden light rays
    lightRays = {}
    local numRays = math.random(6, 8)
    for i = 1, numRays do
        table.insert(lightRays, {
            x = math.random(0, w),
            width = math.random(40, 100),
            speed = 0.05 + math.random() * 0.1,  -- Slower, more graceful
            alpha = 0.03 + math.random() * 0.04, -- Slightly brighter for warm glow
            offset = math.random() * math.pi * 2,
            -- Warm sunset rays - all in golden/amber range
            warmth = 0.6 + math.random() * 0.4,  -- 0.6-1.0 = warm gold to deep amber
            pulseSpeed = 0.2 + math.random() * 0.3,
            softness = 0.3 + math.random() * 0.4,
        })
    end
end

-- Expose light rays for particle system
function background.getLightRays()
    return lightRays
end

function background.getTime()
    return time
end

function background.update(dt)
    time = time + dt
    -- Very slow mood cycling (full cycle ~120 seconds)
    moodPhase = (moodPhase + dt * 0.05) % (math.pi * 2)
end

-- Get current mood color shift
local function getMoodShift()
    local moodIndex = math.floor((moodPhase / (math.pi * 2)) * #moodColors) + 1
    local nextIndex = (moodIndex % #moodColors) + 1
    local t = (moodPhase / (math.pi * 2)) * #moodColors - (moodIndex - 1)

    local current = moodColors[moodIndex].shift
    local next = moodColors[nextIndex].shift

    return {
        current[1] + (next[1] - current[1]) * t,
        current[2] + (next[2] - current[2]) * t,
        current[3] + (next[3] - current[3]) * t,
    }
end

function background.drawBack(w, h)
    local mood = getMoodShift()

    -- Draw water gradient with mood influence
    -- Use many segments for smooth gradient (reduces banding)
    local segments = math.max(60, math.floor(h / 8))
    for i = 0, segments - 1 do
        local t = i / segments
        local y1 = t * h
        local y2 = (t + 1 / segments) * h

        local r = waterTop[1] + (waterBottom[1] - waterTop[1]) * t + mood[1]
        local g = waterTop[2] + (waterBottom[2] - waterTop[2]) * t + mood[2]
        local b = waterTop[3] + (waterBottom[3] - waterTop[3]) * t + mood[3]

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", 0, y1, w, y2 - y1 + 1)
    end

    -- Draw enhanced light rays with soft edges
    for _, ray in ipairs(lightRays) do
        local rayX = ray.x + math.sin(time * ray.speed + ray.offset) * 50

        -- Slower, more gentle breathing
        local breathe = math.sin(time * ray.pulseSpeed + ray.offset)
        local alpha = ray.alpha * (0.6 + 0.4 * breathe)

        -- Color varies from cool blue to warm gold based on warmth
        local rayR = 0.7 + ray.warmth * 0.3
        local rayG = 0.85 + ray.warmth * 0.1
        local rayB = 1.0 - ray.warmth * 0.2

        -- Draw multiple layers for soft edges (gradient falloff)
        local layers = 4
        for layer = layers, 1, -1 do
            local layerScale = 1 + (layer - 1) * ray.softness * 0.3
            local layerAlpha = alpha / (layer * 1.5)

            local layerWidth = ray.width * layerScale

            love.graphics.setColor(rayR, rayG, rayB, layerAlpha)
            love.graphics.polygon("fill",
                rayX - layerWidth * 0.15 * (layer - 1), 0,
                rayX + layerWidth + layerWidth * 0.1 * (layer - 1), 0,
                rayX + layerWidth * 1.6 + layerWidth * 0.2 * (layer - 1), h,
                rayX - layerWidth * 0.4 - layerWidth * 0.15 * (layer - 1), h
            )
        end
    end

    -- Draw sand bottom
    local sandHeight = 60
    local sandY = h - sandHeight

    -- Sand gradient
    for i = 0, sandHeight do
        local t = i / sandHeight
        local r = sandColor[1] - t * 0.1
        local g = sandColor[2] - t * 0.1
        local b = sandColor[3] - t * 0.05
        love.graphics.setColor(r, g, b)
        love.graphics.line(0, sandY + i, w, sandY + i)
    end

    -- Sand texture (small dots)
    love.graphics.setColor(sandDark[1], sandDark[2], sandDark[3], 0.3)
    for i = 1, 100 do
        local x = (i * 17 + time * 0) % w
        local y = sandY + 10 + (i * 7) % (sandHeight - 15)
        love.graphics.circle("fill", x, y, 1 + (i % 3))
    end

    -- Draw rocks
    for _, rock in ipairs(rocks) do
        if #rock.points >= 6 then
            -- Rock shadow
            love.graphics.setColor(0, 0, 0, 0.2)
            local shadowPoints = {}
            for i = 1, #rock.points, 2 do
                table.insert(shadowPoints, rock.points[i] + 3)
                table.insert(shadowPoints, rock.points[i + 1] + 3)
            end
            love.graphics.polygon("fill", shadowPoints)

            -- Rock body
            love.graphics.setColor(rockColor)
            love.graphics.polygon("fill", rock.points)

            -- Rock highlight
            love.graphics.setColor(rockHighlight[1], rockHighlight[2], rockHighlight[3], 0.5)
            love.graphics.polygon("line", rock.points)
        end
    end
end

function background.drawFront(w, h)
    -- Draw enhanced caustic light patterns on sand
    local sandY = h - 60

    -- Multiple caustic layers for richer effect
    for layer = 1, 2 do
        local layerAlpha = layer == 1 and 0.06 or 0.04
        local layerSpeed = layer == 1 and 0.3 or 0.2
        local layerOffset = layer * 50

        for i = 1, 10 do
            local cx = (i * 140 + layerOffset + math.sin(time * layerSpeed + i) * 120) % (w + 100) - 50
            local cy = sandY + 15 + math.sin(time * 0.4 + i * 0.7) * 12
            local size = 35 + math.sin(time * 0.35 + i * 1.3) * 20

            -- Golden amber caustic color
            local warmth = 0.75 + math.sin(time * 0.2 + i) * 0.1
            love.graphics.setColor(1, warmth, 0.5, layerAlpha * 1.2)

            -- Draw wobbly caustic shape
            local points = {}
            local numPoints = 10
            for j = 1, numPoints do
                local angle = (j - 1) * (2 * math.pi / numPoints)
                local wobble = math.sin(time * 0.8 + i + j * 0.5) * 0.35
                local radius = size * (0.5 + wobble)
                table.insert(points, cx + math.cos(angle) * radius)
                table.insert(points, cy + math.sin(angle) * radius * 0.4)
            end

            if #points >= 6 then
                love.graphics.polygon("fill", points)
            end
        end
    end

    -- Warm-tinted vignette effect
    local vignetteAlpha = 0.35

    -- Top vignette - warm dark brown tint
    local topHeight = 80
    for i = 0, topHeight do
        local t = i / topHeight
        local alpha = vignetteAlpha * (1 - t) * (1 - t)
        love.graphics.setColor(0.1, 0.05, 0.02, alpha)
        love.graphics.line(0, i, w, i)
    end

    -- Bottom vignette - deeper warm brown
    local bottomHeight = 40
    for i = 0, bottomHeight do
        local t = i / bottomHeight
        local alpha = vignetteAlpha * 0.4 * (1 - t) * (1 - t)
        love.graphics.setColor(0.08, 0.04, 0.02, alpha)
        love.graphics.line(0, h - i, w, h - i)
    end

    -- Side vignettes - warm tint
    local sideWidth = 60
    for i = 0, sideWidth do
        local t = i / sideWidth
        local alpha = vignetteAlpha * 0.25 * (1 - t) * (1 - t)
        love.graphics.setColor(0.1, 0.05, 0.02, alpha)
        love.graphics.line(i, 0, i, h)
        love.graphics.line(w - i, 0, w - i, h)
    end

    -- Warm corner darkening for depth
    local cornerRadius = 150
    for corner = 1, 4 do
        local cx = (corner == 1 or corner == 4) and 0 or w
        local cy = (corner == 1 or corner == 2) and 0 or h
        for ring = 1, 5 do
            local ringAlpha = 0.03 * (6 - ring) / 5
            love.graphics.setColor(0.1, 0.05, 0.02, ringAlpha)
            love.graphics.circle("fill", cx, cy, cornerRadius * ring / 5)
        end
    end
end

return background
