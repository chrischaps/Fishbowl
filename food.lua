-- Fish food particles

local Food = {}

function Food.new(x, y)
    return {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 20,
        vy = 0,
        size = 3 + math.random() * 2,
        sinkSpeed = 15 + math.random() * 10,
        wobblePhase = math.random() * math.pi * 2,
        time = 0,
        -- Warm sunset food colors (coral, amber, gold)
        color = {
            0.9 + math.random() * 0.1,   -- Rich warm red
            0.55 + math.random() * 0.25, -- Amber to coral
            0.25 + math.random() * 0.15  -- Low blue warmth
        },
    }
end

function Food.updateAll(foodParticles, dt, screenH)
    for i = #foodParticles, 1, -1 do
        local f = foodParticles[i]
        f.time = f.time + dt

        -- Sink slowly
        f.vy = f.vy + f.sinkSpeed * dt
        f.vy = math.min(f.vy, f.sinkSpeed * 2)

        -- Wobble horizontally
        f.x = f.x + math.sin(f.time * 3 + f.wobblePhase) * 10 * dt
        f.y = f.y + f.vy * dt

        -- Apply horizontal velocity with drag
        f.x = f.x + f.vx * dt
        f.vx = f.vx * 0.98

        -- Remove if at bottom
        if f.y > screenH - 50 then
            table.remove(foodParticles, i)
        end
    end
end

function Food.draw(food)
    local f = food

    -- Food particle
    love.graphics.setColor(f.color[1], f.color[2], f.color[3], 0.9)
    love.graphics.circle("fill", f.x, f.y, f.size)

    -- Warm golden highlight
    love.graphics.setColor(1, 0.95, 0.8, 0.6)
    love.graphics.circle("fill", f.x - f.size * 0.3, f.y - f.size * 0.3, f.size * 0.4)
end

return Food
