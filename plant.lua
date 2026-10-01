-- Underwater plants with swaying animation
-- Enhanced with slower, hypnotic movement and subtle bioluminescence

local Plant = {}

-- Plant types:
-- 1 = tall seaweed
-- 2 = short grass
-- 3 = leafy plant

function Plant.new(x, y, plantType)
    local plant = {
        x = x,
        y = y,
        plantType = plantType or 1,
        time = math.random() * 100,
        phase = math.random() * math.pi * 2,
        swaySpeed = 0.4 + math.random() * 0.3,  -- Slower, more hypnotic
        swayAmount = 4 + math.random() * 8,      -- Slightly reduced for elegance
        segments = {},
        -- Warm sunset plant colors - olive greens and amber-tinged
        color = {
            0.35 + math.random() * 0.15,   -- Warm olive-amber
            0.40 + math.random() * 0.15,   -- Muted green
            0.15 + math.random() * 0.1     -- Low blue for warmth
        },
        fishInfluence = 0,
        -- Bioluminescence properties
        glowIntensity = 0.1 + math.random() * 0.15,
        glowPhase = math.random() * math.pi * 2,
        glowSpeed = 0.3 + math.random() * 0.4,
    }

    -- Generate segments based on plant type
    if plantType == 1 then
        -- Tall seaweed
        local numSegments = 8 + math.floor(math.random() * 5)
        local height = 80 + math.random() * 60
        for i = 1, numSegments do
            table.insert(plant.segments, {
                length = height / numSegments,
                width = 8 - (i * 0.5),
                phaseOffset = i * 0.3,
            })
        end
    elseif plantType == 2 then
        -- Short grass (multiple blades)
        local numBlades = 5 + math.floor(math.random() * 4)
        for i = 1, numBlades do
            table.insert(plant.segments, {
                length = 20 + math.random() * 30,
                width = 2 + math.random() * 2,
                offsetX = (i - numBlades / 2) * 6,
                phaseOffset = i * 0.5,
            })
        end
    else
        -- Leafy plant
        local numLeaves = 4 + math.floor(math.random() * 3)
        local stemHeight = 40 + math.random() * 30
        for i = 1, numLeaves do
            table.insert(plant.segments, {
                stemLength = stemHeight * (0.5 + i * 0.1),
                leafSize = 15 + math.random() * 10,
                angle = (i / numLeaves) * math.pi - math.pi / 2 + (math.random() - 0.5) * 0.5,
                phaseOffset = i * 0.4,
            })
        end
    end

    return plant
end

function Plant.update(plant, dt, fish)
    plant.time = plant.time + dt

    -- Check for nearby fish influence
    plant.fishInfluence = plant.fishInfluence * 0.95  -- Decay

    for _, f in ipairs(fish) do
        local dx = f.x - plant.x
        local dy = f.y - plant.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 100 then
            local influence = (1 - dist / 100) * 0.5
            local direction = dx > 0 and 1 or -1
            plant.fishInfluence = plant.fishInfluence + direction * influence * math.abs(f.vx) * 0.01
        end
    end

    -- Clamp fish influence
    plant.fishInfluence = math.max(-1, math.min(1, plant.fishInfluence))
end

function Plant.draw(plant)
    local p = plant
    local baseX, baseY = p.x, p.y

    -- Calculate glow intensity (subtle breathing)
    local glowPulse = math.sin(p.time * p.glowSpeed + p.glowPhase)
    local currentGlow = p.glowIntensity * (0.5 + 0.5 * glowPulse)

    love.graphics.setLineWidth(1)

    if p.plantType == 1 then
        -- Tall seaweed - segmented with flow
        local currentX, currentY = baseX, baseY
        local tipX, tipY = currentX, currentY  -- Track tip position for glow

        for i, seg in ipairs(p.segments) do
            local sway = math.sin(p.time * p.swaySpeed + seg.phaseOffset + p.phase) * p.swayAmount
            sway = sway + p.fishInfluence * 20 * (i / #p.segments)

            local nextX = currentX + sway * (i / #p.segments)
            local nextY = currentY - seg.length

            -- Draw segment
            local alpha = 0.7 + 0.3 * (1 - i / #p.segments)
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
            love.graphics.setLineWidth(seg.width)
            love.graphics.line(currentX, currentY, nextX, nextY)

            currentX, currentY = nextX, nextY
            tipX, tipY = nextX, nextY
        end

        -- Warm amber glow at tip
        love.graphics.setColor(1.0, 0.7, 0.3, currentGlow * 0.4)
        love.graphics.circle("fill", tipX, tipY, 6)
        love.graphics.setColor(1.0, 0.85, 0.5, currentGlow * 0.6)
        love.graphics.circle("fill", tipX, tipY, 3)

    elseif p.plantType == 2 then
        -- Short grass - individual blades
        for i, seg in ipairs(p.segments) do
            local bladeX = baseX + seg.offsetX
            local sway = math.sin(p.time * p.swaySpeed + seg.phaseOffset + p.phase) * p.swayAmount * 0.5
            sway = sway + p.fishInfluence * 15

            local tipX = bladeX + sway
            local tipY = baseY - seg.length

            love.graphics.setColor(p.color[1], p.color[2], p.color[3], 0.8)
            love.graphics.setLineWidth(seg.width)
            love.graphics.line(bladeX, baseY, tipX, tipY)

            -- Subtle warm glow at grass tips
            if i % 2 == 0 then  -- Only some blades glow
                love.graphics.setColor(1.0, 0.75, 0.4, currentGlow * 0.25)
                love.graphics.circle("fill", tipX, tipY, 2)
            end
        end

    else
        -- Leafy plant
        for i, seg in ipairs(p.segments) do
            local sway = math.sin(p.time * p.swaySpeed * 0.7 + seg.phaseOffset + p.phase) * 0.2
            sway = sway + p.fishInfluence * 0.3

            local angle = seg.angle + sway

            -- Draw stem
            local stemEndX = baseX + math.cos(angle + math.pi / 2) * seg.stemLength * 0.3
            local stemEndY = baseY - seg.stemLength

            love.graphics.setColor(p.color[1] * 0.8, p.color[2] * 0.8, p.color[3] * 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.line(baseX, baseY, stemEndX, stemEndY)

            -- Draw leaf
            local leafX = stemEndX + math.cos(angle) * seg.leafSize
            local leafY = stemEndY + math.sin(angle) * seg.leafSize * 0.5
            local leafCenterX = (stemEndX + leafX) / 2
            local leafCenterY = (stemEndY + leafY) / 2

            love.graphics.setColor(p.color[1], p.color[2], p.color[3], 0.85)
            love.graphics.ellipse("fill", leafCenterX, leafCenterY,
                seg.leafSize * 0.6, seg.leafSize * 0.25, angle)

            -- Subtle warm glow on leaf edges
            love.graphics.setColor(1.0, 0.8, 0.4, currentGlow * 0.2)
            love.graphics.ellipse("line", leafCenterX, leafCenterY,
                seg.leafSize * 0.65, seg.leafSize * 0.28, angle)
        end
    end

    love.graphics.setLineWidth(1)
end

return Plant
