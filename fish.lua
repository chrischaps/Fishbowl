-- Procedural fish with flowing animations
-- Enhanced with ethereal glow and wake effects

local Fish = {}

-- Wake particle storage (managed per fish)
local wakeParticles = {}

function Fish.new(x, y, color)
    local fish = {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 60,
        vy = (math.random() - 0.5) * 30,
        color = color or {1, 0.5, 0.2},

        -- Size
        bodyLength = 35 + math.random() * 20,
        bodyHeight = 15 + math.random() * 10,

        -- Animation state
        time = math.random() * 100,
        tailPhase = math.random() * math.pi * 2,
        finPhase = math.random() * math.pi * 2,

        -- Movement (slightly slower for graceful motion)
        targetX = x,
        targetY = y,
        wanderAngle = math.random() * math.pi * 2,
        wanderTimer = 0,
        speed = 30 + math.random() * 25,  -- Reduced for more meditative movement

        -- Direction (1 = right, -1 = left)
        direction = math.random() > 0.5 and 1 or -1,

        -- Personality
        curiosity = 0.3 + math.random() * 0.7,  -- 0 = shy, 1 = curious
        hunger = 0.5,

        -- State
        state = "wander",  -- wander, chase_food, flee, curious
        stateTimer = 0,

        -- Smoothed speed for animation (prevents jittery tails)
        smoothedSpeed = 0,
        lastX = x,
        lastY = y,

        -- Wake particles for this fish
        wakeTimer = 0,
        glowIntensity = 0.3 + math.random() * 0.2,  -- Individual glow strength
    }
    return fish
end

-- Wake particle functions
local function createWakeParticle(x, y, vx, vy, color)
    return {
        x = x,
        y = y,
        vx = vx * -0.3 + (math.random() - 0.5) * 10,
        vy = vy * -0.3 + (math.random() - 0.5) * 10,
        life = 1.0,
        maxLife = 0.8 + math.random() * 0.4,
        size = 1 + math.random() * 2,
        color = {color[1], color[2], color[3]},
        alpha = 0.3 + math.random() * 0.2,
    }
end

function Fish.updateWakeParticles(dt)
    for i = #wakeParticles, 1, -1 do
        local p = wakeParticles[i]
        p.life = p.life - dt / p.maxLife
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.95
        p.vy = p.vy * 0.95
        p.size = p.size * (1 - dt * 0.5)

        if p.life <= 0 then
            table.remove(wakeParticles, i)
        end
    end
end

function Fish.drawWakeParticles()
    for _, p in ipairs(wakeParticles) do
        local alpha = p.alpha * p.life * p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.5)
        love.graphics.circle("fill", p.x, p.y, p.size * 1.5)
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.circle("fill", p.x, p.y, p.size * 0.8)
    end
end

function Fish.update(fish, dt, screenW, screenH, mouseX, mouseY, foodParticles, allFish)
    fish.time = fish.time + dt
    fish.wanderTimer = fish.wanderTimer + dt
    fish.stateTimer = fish.stateTimer + dt

    -- Increase hunger over time
    fish.hunger = math.min(1, fish.hunger + dt * 0.02)

    -- Check for nearby food
    local nearestFood = nil
    local nearestFoodDist = 200

    for i, food in ipairs(foodParticles) do
        local dx = food.x - fish.x
        local dy = food.y - fish.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < nearestFoodDist and fish.hunger > 0.3 then
            nearestFood = food
            nearestFoodDist = dist
        end

        -- Eat food if close enough
        if dist < 20 then
            table.remove(foodParticles, i)
            fish.hunger = math.max(0, fish.hunger - 0.3)
            break
        end
    end

    -- Check mouse proximity
    local mouseDx = mouseX - fish.x
    local mouseDy = mouseY - fish.y
    local mouseDist = math.sqrt(mouseDx * mouseDx + mouseDy * mouseDy)

    -- State machine
    if nearestFood then
        fish.state = "chase_food"
        fish.targetX = nearestFood.x
        fish.targetY = nearestFood.y
    elseif mouseDist < 150 then
        if fish.curiosity > 0.6 then
            fish.state = "curious"
            -- Approach mouse but keep distance
            local approachDist = 80
            if mouseDist > approachDist then
                fish.targetX = fish.x + mouseDx * 0.3
                fish.targetY = fish.y + mouseDy * 0.3
            end
        elseif fish.curiosity < 0.4 then
            fish.state = "flee"
            fish.targetX = fish.x - mouseDx * 0.5
            fish.targetY = fish.y - mouseDy * 0.5
        else
            fish.state = "wander"
        end
    else
        fish.state = "wander"
    end

    -- Wandering behavior
    if fish.state == "wander" then
        if fish.wanderTimer > 2 + math.random() * 3 then
            fish.wanderTimer = 0
            fish.wanderAngle = fish.wanderAngle + (math.random() - 0.5) * math.pi
            local wanderDist = 100 + math.random() * 150
            fish.targetX = fish.x + math.cos(fish.wanderAngle) * wanderDist
            fish.targetY = fish.y + math.sin(fish.wanderAngle) * wanderDist
        end
    end

    -- Separation: push away from fish that are too close
    local separationX, separationY = 0, 0
    local separationDist = 60  -- Minimum comfortable distance

    for _, other in ipairs(allFish) do
        if other ~= fish then
            local dx = other.x - fish.x
            local dy = other.y - fish.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < separationDist and dist > 0 then
                -- Push away, stronger when closer
                local force = (separationDist - dist) / separationDist
                separationX = separationX - (dx / dist) * force
                separationY = separationY - (dy / dist) * force
            end
        end
    end

    -- Apply separation force directly to velocity
    fish.vx = fish.vx + separationX * 150 * dt
    fish.vy = fish.vy + separationY * 150 * dt

    -- Schooling: slightly attracted to nearby fish (but not too close)
    local schoolX, schoolY, schoolCount = 0, 0, 0
    for _, other in ipairs(allFish) do
        if other ~= fish then
            local dx = other.x - fish.x
            local dy = other.y - fish.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < 200 and dist > separationDist then
                schoolX = schoolX + other.x
                schoolY = schoolY + other.y
                schoolCount = schoolCount + 1
            end
        end
    end

    if schoolCount > 0 and fish.state == "wander" then
        schoolX = schoolX / schoolCount
        schoolY = schoolY / schoolCount
        fish.targetX = fish.targetX * 0.85 + schoolX * 0.15
        fish.targetY = fish.targetY * 0.85 + schoolY * 0.15
    end

    -- Move towards target
    local dx = fish.targetX - fish.x
    local dy = fish.targetY - fish.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 5 then
        local moveSpeed = fish.speed
        if fish.state == "chase_food" then
            moveSpeed = moveSpeed * 1.5
        elseif fish.state == "flee" then
            moveSpeed = moveSpeed * 1.8
        end

        local ax = (dx / dist) * moveSpeed * 2
        local ay = (dy / dist) * moveSpeed * 2

        fish.vx = fish.vx + ax * dt
        fish.vy = fish.vy + ay * dt
    end

    -- Apply drag
    fish.vx = fish.vx * (1 - dt * 2)
    fish.vy = fish.vy * (1 - dt * 2)

    -- Clamp velocity
    local maxSpeed = fish.speed * 2
    local currentSpeed = math.sqrt(fish.vx * fish.vx + fish.vy * fish.vy)
    if currentSpeed > maxSpeed then
        fish.vx = (fish.vx / currentSpeed) * maxSpeed
        fish.vy = (fish.vy / currentSpeed) * maxSpeed
    end

    -- Update position
    fish.x = fish.x + fish.vx * dt
    fish.y = fish.y + fish.vy * dt

    -- Calculate actual movement speed (for smooth animation)
    local actualDx = fish.x - fish.lastX
    local actualDy = fish.y - fish.lastY
    local actualSpeed = math.sqrt(actualDx * actualDx + actualDy * actualDy) / dt
    fish.smoothedSpeed = fish.smoothedSpeed * 0.9 + actualSpeed * 0.1
    fish.lastX = fish.x
    fish.lastY = fish.y

    -- Update direction based on velocity
    if math.abs(fish.vx) > 5 then
        fish.direction = fish.vx > 0 and 1 or -1
    end

    -- Wall avoidance with margins
    local margin = 80
    local sandMargin = 100

    if fish.x < margin then
        fish.vx = fish.vx + 200 * dt
        fish.targetX = margin + 50
    elseif fish.x > screenW - margin then
        fish.vx = fish.vx - 200 * dt
        fish.targetX = screenW - margin - 50
    end

    if fish.y < margin then
        fish.vy = fish.vy + 200 * dt
        fish.targetY = margin + 50
    elseif fish.y > screenH - sandMargin then
        fish.vy = fish.vy - 200 * dt
        fish.targetY = screenH - sandMargin - 50
    end

    -- Keep in bounds
    fish.x = math.max(20, math.min(screenW - 20, fish.x))
    fish.y = math.max(20, math.min(screenH - 80, fish.y))

    -- Spawn wake particles when moving fast
    fish.wakeTimer = fish.wakeTimer + dt
    if fish.smoothedSpeed > 25 and fish.wakeTimer > 0.08 then
        fish.wakeTimer = 0
        -- Spawn particle behind the fish
        local tailX = fish.x - fish.direction * fish.bodyLength * 0.8
        local tailY = fish.y
        table.insert(wakeParticles, createWakeParticle(tailX, tailY, fish.vx, fish.vy, fish.color))
    end
end

function Fish.draw(fish)
    local bodyLen = fish.bodyLength
    local bodyH = fish.bodyHeight
    local r, g, b = fish.color[1], fish.color[2], fish.color[3]

    -- Draw ethereal glow behind fish (before transformations)
    -- Use many layers for smooth gradient (reduces banding)
    local glowSize = bodyLen * 1.8
    local glowAlpha = fish.glowIntensity * (0.12 + math.sin(fish.time * 0.8) * 0.04)

    -- Multi-layer glow for smooth falloff (8 layers)
    local layers = 8
    for i = layers, 1, -1 do
        local t = i / layers  -- 1.0 to 0.125
        local radius = glowSize * t
        local alpha = glowAlpha * (1 - t) * 0.15  -- Fade out toward edges

        -- Blend toward white in the center
        local colorMix = 1 - t
        local gr = r + (1 - r) * colorMix * 0.3
        local gg = g + (1 - g) * colorMix * 0.3
        local gb = b + (1 - b) * colorMix * 0.3

        love.graphics.setColor(gr, gg, gb, alpha)
        love.graphics.circle("fill", fish.x, fish.y, radius)
    end

    love.graphics.push()
    love.graphics.translate(fish.x, fish.y)

    -- Flip based on direction
    love.graphics.scale(fish.direction, 1)

    -- Calculate animation values based on smoothed actual movement
    local speed = fish.smoothedSpeed or 0
    local swimFreq = 3 + speed * 0.03
    local tailWave = math.sin(fish.time * swimFreq + fish.tailPhase) * 0.4
    local bodyWave = math.sin(fish.time * swimFreq * 0.8) * 0.1

    -- Draw shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.ellipse("fill", 2, 4, bodyLen * 0.8, bodyH * 0.5)

    -- Draw tail
    local tailLen = bodyLen * 0.6
    local tailH = bodyH * 0.9
    local tailX = -bodyLen * 0.6
    local tailWaveOffset = tailWave * tailLen * 0.5

    love.graphics.setColor(r * 0.9, g * 0.9, b * 0.9)
    love.graphics.polygon("fill",
        tailX, 0,
        tailX - tailLen + tailWaveOffset, -tailH,
        tailX - tailLen * 0.7 + tailWaveOffset * 0.7, 0,
        tailX - tailLen + tailWaveOffset, tailH
    )

    -- Draw body
    love.graphics.setColor(r, g, b)
    love.graphics.ellipse("fill", 0, bodyWave * 5, bodyLen, bodyH)

    -- Body highlight
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.ellipse("fill", bodyLen * 0.1, -bodyH * 0.3, bodyLen * 0.5, bodyH * 0.3)

    -- Draw dorsal fin
    local finWave = math.sin(fish.time * 4 + fish.finPhase) * 0.3
    local dorsalH = bodyH * 0.7
    love.graphics.setColor(r * 0.85, g * 0.85, b * 0.85)
    love.graphics.polygon("fill",
        bodyLen * 0.2, -bodyH * 0.8,
        -bodyLen * 0.2, -bodyH - dorsalH + finWave * 10,
        -bodyLen * 0.4, -bodyH * 0.7
    )

    -- Draw pectoral fin
    local pectoralWave = math.sin(fish.time * 5 + fish.finPhase + 1) * 0.4
    love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 0.8)
    love.graphics.polygon("fill",
        0, bodyH * 0.3,
        -bodyLen * 0.3, bodyH + 8 + pectoralWave * 5,
        -bodyLen * 0.5, bodyH * 0.5
    )

    -- Draw eye
    local eyeX = bodyLen * 0.5
    local eyeY = -bodyH * 0.1
    local eyeSize = bodyH * 0.25

    -- Eye white
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", eyeX, eyeY, eyeSize)

    -- Eye pupil
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", eyeX + eyeSize * 0.2, eyeY, eyeSize * 0.6)

    -- Eye highlight
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", eyeX + eyeSize * 0.3, eyeY - eyeSize * 0.2, eyeSize * 0.25)

    -- Mouth
    love.graphics.setColor(r * 0.6, g * 0.6, b * 0.6)
    love.graphics.arc("line", bodyLen * 0.8, bodyH * 0.1, 4, 0, math.pi * 0.5)

    love.graphics.pop()
end

return Fish
