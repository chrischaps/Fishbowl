-- Rising bubble particle system
-- Enhanced with iridescent shimmer and varied sizes

local Bubble = {}

-- Create a single bubble with varied properties
function Bubble.new(x, y, sizeOverride)
    -- Most bubbles are small (champagne-like), occasional larger ones
    local sizeRoll = math.random()
    local size
    if sizeOverride then
        size = sizeOverride
    elseif sizeRoll < 0.7 then
        size = 1 + math.random() * 2  -- Tiny bubbles (most common)
    elseif sizeRoll < 0.9 then
        size = 2 + math.random() * 3  -- Medium bubbles
    else
        size = 4 + math.random() * 5  -- Large bubbles (rare)
    end

    return {
        x = x,
        y = y,
        startX = x,
        size = size,
        speed = 20 + math.random() * 30 + (10 - size) * 3,  -- Smaller = faster rise
        wobbleSpeed = 0.8 + math.random() * 1.5,
        wobbleAmount = 8 + math.random() * 15,
        phase = math.random() * math.pi * 2,
        time = 0,
        alpha = 0.35 + math.random() * 0.25,
        displaySize = size,
        -- Iridescent shimmer properties
        shimmerPhase = math.random() * math.pi * 2,
        shimmerSpeed = 2 + math.random() * 3,
    }
end

-- Create a cluster of bubbles
function Bubble.newCluster(x, y, count)
    local bubbles = {}
    count = count or math.random(2, 4)
    for i = 1, count do
        local offsetX = (math.random() - 0.5) * 15
        local offsetY = math.random() * 10
        local delay = math.random() * 0.3
        local b = Bubble.new(x + offsetX, y + offsetY, 1 + math.random() * 2)
        b.time = -delay  -- Stagger the start
        table.insert(bubbles, b)
    end
    return bubbles
end

function Bubble.updateAll(bubbles, dt, screenW, screenH)
    for i = #bubbles, 1, -1 do
        local b = bubbles[i]
        b.time = b.time + dt

        -- Rise upward
        b.y = b.y - b.speed * dt

        -- Wobble side to side
        b.x = b.startX + math.sin(b.time * b.wobbleSpeed + b.phase) * b.wobbleAmount

        -- Slight size pulse
        b.displaySize = b.size * (1 + math.sin(b.time * 3) * 0.1)

        -- Remove if above screen
        if b.y < -10 then
            table.remove(bubbles, i)
        end
    end
end

function Bubble.draw(bubble)
    local b = bubble

    -- Don't draw bubbles that haven't "started" yet (for cluster delays)
    if b.time < 0 then return end

    -- Calculate warm sunset shimmer (golden-coral-magenta)
    local shimmer = math.sin(b.time * b.shimmerSpeed + b.shimmerPhase)
    local shimmerR = 1.0
    local shimmerG = 0.75 + math.sin(b.time * b.shimmerSpeed + b.shimmerPhase + 2) * 0.15
    local shimmerB = 0.6 + math.sin(b.time * b.shimmerSpeed + b.shimmerPhase + 4) * 0.2

    -- Soft warm outer glow (for larger bubbles)
    if b.displaySize > 3 then
        love.graphics.setColor(1, 0.85, 0.75, b.alpha * 0.15)
        love.graphics.circle("fill", b.x, b.y, b.displaySize * 1.4)
    end

    -- Main bubble body with warm shimmer
    love.graphics.setColor(shimmerR, shimmerG, shimmerB, b.alpha * 0.4)
    love.graphics.circle("fill", b.x, b.y, b.displaySize)

    -- Secondary color layer - warm amber tint
    love.graphics.setColor(0.95, 0.7, 0.55, b.alpha * 0.25)
    love.graphics.circle("fill", b.x + b.displaySize * 0.1, b.y + b.displaySize * 0.1, b.displaySize * 0.9)

    -- Main highlight (top-left)
    love.graphics.setColor(1, 1, 1, b.alpha * 0.85)
    love.graphics.circle("fill",
        b.x - b.displaySize * 0.3,
        b.y - b.displaySize * 0.3,
        b.displaySize * 0.28
    )

    -- Secondary smaller highlight
    if b.displaySize > 2 then
        love.graphics.setColor(1, 1, 1, b.alpha * 0.4)
        love.graphics.circle("fill",
            b.x + b.displaySize * 0.2,
            b.y + b.displaySize * 0.35,
            b.displaySize * 0.12
        )
    end

    -- Warm sunset edge shimmer (golden to coral)
    local edgeR = 1.0
    local edgeG = 0.8 + math.sin(b.time * 4 + b.shimmerPhase) * 0.1
    local edgeB = 0.6 + math.sin(b.time * 4 + b.shimmerPhase + 2.1) * 0.15

    love.graphics.setColor(edgeR, edgeG, edgeB, b.alpha * 0.35)
    love.graphics.setLineWidth(b.displaySize > 3 and 1.5 or 1)
    love.graphics.circle("line", b.x, b.y, b.displaySize)
    love.graphics.setLineWidth(1)
end

return Bubble
