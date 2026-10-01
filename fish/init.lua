-- Fish behavior: 3D steering with species temperament.
-- States: wander, food, curious, startle, wary, sleep, breathe, forage

local C = require("config")
local World = require("world")
local Body = require("fish.body")
local Species = require("fish.species")

local Fish = {}

local sin, cos, sqrt, abs, atan2, min, max, pi = math.sin, math.cos, math.sqrt, math.abs, math.atan2, math.min, math.max, math.pi
local random = math.random
local clamp = World.clamp
local DEPTH = C.DEPTH_PX

local all = {}
local schoolTargets = {}
local events = {}

local names = {
    "Pip", "Juniper", "Mochi", "Basil", "Wren", "Fig", "Sable", "Luma", "Tansy", "Marlo",
    "Indigo", "Ember", "Clove", "Nori", "Sorrel", "Pebble", "Quill", "Bramble", "Moss", "Kip",
    "Saffron", "Opal", "Tilde", "Rue", "Biscuit", "Comet", "Hazel", "Minnow", "Olive", "Sprout",
    "Tamsin", "Wisp", "Yuzu", "Zephyr", "Cinder", "Dot", "Echo", "Fennel", "Gilly", "Hollis",
}

local moodWords = {
    wander = "content", school = "schooling", food = "hungry", curious = "curious",
    startle = "startled", wary = "wary", sleep = "sleeping", breathe = "taking a breath",
    forage = "foraging", rest = "resting",
}

local function wrapAngle(a)
    a = (a + pi) % (2 * pi)
    return a - pi
end

local function zoneY(sp, x, z, t)
    local top = C.SURFACE_Y + 30
    local bottom = World.floorY(x, z) - 20
    return top + (bottom - top) * (sp.zone[1] + (sp.zone[2] - sp.zone[1]) * t)
end

local function pickWanderTarget(f)
    local sp = f.sp
    local dir = random() < 0.65 and (cos(f.psi) >= 0 and 1 or -1) or (random() < 0.5 and 1 or -1)
    local tx = f.x + dir * (120 + random() * 380)
    local tz = clamp(f.z + (random() - 0.5) * 0.5, 0.12, 0.92)
    local lo, hi = World.xBounds(tz, 70)
    tx = clamp(tx, lo, hi)
    f.tx, f.ty, f.tz = tx, zoneY(sp, tx, tz, random()), tz
    f.wanderTimer = 4 + random() * 7
end

local function newFish(sp, key, index, saved)
    local z = 0.2 + random() * 0.7
    local lo, hi = World.xBounds(z, 100)
    local x = lo + random() * (hi - lo)
    local f = {
        kind = "fish", key = key, index = index, sp = sp,
        x = x, y = zoneY(sp, x, z, random()), z = z, d = z,
        psi = random() < 0.5 and 0 or pi, phi = 0,
        speed = sp.cruise * 0.5, targetSpeed = sp.cruise,
        yawRate = 0, turnBend = 0, turnDir = 0,
        phase = random() * 10, finPhase = random() * 10, amp = sp.wave.amp,
        time = random() * 100, seed = random() * 100,
        L = sp.length * (0.85 + random() * 0.3),
        state = "wander", stateTimer = 0, wanderTimer = 0,
        hunger = 0.3 + random() * 0.3,
        curiosity = 0.2 + random() * 0.6,
        boldness = 0.2 + random() * 0.8,
        trust = 0, fed = 0,
        irid = 1, vivid = 1, lookX = 0, lookY = 0,
        barStrength = 0.8 + random() * 0.2,
        breathTimer = sp.breathes and (sp.breathes.interval[1] + random() * sp.breathes.interval[2]) or nil,
        name = names[random(#names)],
    }
    if saved then
        f.name = saved.name or f.name
        f.trust = saved.trust or 0
        f.fed = saved.fed or 0
    end
    if sp.setup then sp.setup(f, saved and saved.color) end
    f.mesh = Body.newMesh()
    pickWanderTarget(f)
    return f
end

function Fish.init(saved)
    Body.init()
    all = {}
    saved = saved or {}
    local used = {}
    for _, key in ipairs(Species.order) do
        local sp = Species[key]
        for i = 1, sp.count do
            local id = key .. i
            local f = newFish(sp, key, i, saved[id])
            -- Avoid duplicate names among fresh fish
            while used[f.name] and not saved[id] do f.name = names[random(#names)] end
            used[f.name] = true
            f.id = id
            all[#all + 1] = f
        end
    end
end

function Fish.all() return all end

function Fish.snapshot()
    local out = {}
    for _, f in ipairs(all) do
        out[f.id] = { name = f.name, trust = f.trust, fed = f.fed, color = f.colorIndex }
    end
    return out
end

function Fish.mood(f)
    if f.state == "wander" and f.hunger > 0.75 then return "peckish" end
    if f.state == "curious" and f.trust > 0.5 then return "says hello" end
    return moodWords[f.state] or f.state
end

--------------------------------------------------------------------------------
-- Interaction
--------------------------------------------------------------------------------
--- A tap on the glass at screen (sx, sy)
function Fish.startle(sx, sy)
    for _, f in ipairs(all) do
        local fx, fy = World.project(f.x, f.y, f.z)
        local dx, dy = fx - sx, fy - sy
        local dist = sqrt(dx * dx + dy * dy)
        local reach = 300 + f.z * 200
        if dist < reach and f.state ~= "sleep" or (f.state == "sleep" and dist < 160) then
            local fear = (1 - dist / reach) * (1.2 - f.boldness * 0.6)
            if fear > 0.15 then
                f.state = "startle"
                f.stateTimer = 0.35 + fear * 0.6
                local l = max(dist, 1)
                f.tx = f.x + dx / l * 260
                f.ty = f.y + dy / l * 160
                f.tz = clamp(f.z - 0.5, 0.05, 0.9)
                -- C-start: an instant kick of speed and a sharp turn
                f.speed = f.sp.burst
                f.turnBend = (random() < 0.5 and -1 or 1) * 0.35
            end
        end
    end
end

function Fish.at(sx, sy)
    local best, bestD
    for _, f in ipairs(all) do
        local fx, fy, r = Body.screenBounds(f)
        local d = sqrt((fx - sx) ^ 2 + (fy - sy) ^ 2)
        if d < r * 1.3 + 6 and (not bestD or f.z > best.z) then
            best, bestD = f, d
        end
    end
    return best
end

function Fish.drainEvents()
    local e = events
    events = {}
    return e
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------
local function nearestFood(f, foods)
    local best, bestD = nil, 230
    for _, food in ipairs(foods) do
        if not food.eaten then
            local onFloor = food.state == "settled"
            if not onFloor or f.sp.bottom or f.hunger > 0.85 then
                local dx, dy, dz = food.x - f.x, food.y - f.y, (food.d - f.z) * DEPTH
                local d = sqrt(dx * dx + dy * dy + dz * dz)
                if d < bestD then best, bestD = food, d end
            end
        end
    end
    return best, bestD
end

local function chooseState(f, ctx)
    local sp = f.sp
    local env = ctx.env
    local night = env.glow > 0.7

    if f.state == "startle" then
        if f.stateTimer <= 0 then
            f.state = "wary"
            f.stateTimer = 3 + random() * 3
            pickWanderTarget(f)
            f.tz = clamp(f.z, 0.05, 0.4)
        end
        return
    end
    if f.state == "breathe" and f.stateTimer > 0 then return end

    -- Hungry fish wake for food even at night
    local food, foodD = nil, nil
    if f.hunger > 0.18 then food, foodD = nearestFood(f, ctx.foods) end
    if food and (not night or foodD < 120) then
        f.state = "food"
        f.food = food
        return
    end
    f.food = nil

    if f.state == "wary" and f.stateTimer > 0 then return end

    if night then
        if f.state ~= "sleep" then
            f.state = "sleep"
            local z = clamp(f.z + (random() - 0.5) * 0.3, 0.15, 0.85)
            local tx = clamp(f.x + (random() - 0.5) * 200, World.xBounds(z, 90))
            f.tx, f.tz = tx, z
            f.ty = sp.bottom and (World.floorY(tx, z) - f.L * 0.2) or
                (World.floorY(tx, z) - 40 - random() * (f.key == "betta" and 120 or 160))
        end
        return
    end

    if sp.breathes and f.breathTimer and f.breathTimer <= 0 then
        f.state = "breathe"
        f.stateTimer = 9
        f.tx, f.tz = f.x + (cos(f.psi) >= 0 and 60 or -60), clamp(f.z, 0.3, 0.9)
        f.ty = C.SURFACE_Y + f.L * 0.15
        f.breathTimer = sp.breathes.interval[1] + random() * sp.breathes.interval[2]
        return
    end

    -- Curious fish come to the glass near the cursor
    local cur = ctx.cursor
    if cur.active then
        local fx, fy = World.project(f.x, f.y, f.z)
        local dist = sqrt((fx - cur.x) ^ 2 + (fy - cur.y) ^ 2)
        local interest = f.curiosity * 0.6 + f.trust * 0.8
        if dist < 220 + interest * 260 and interest > 0.45 and cur.still > 0.6 then
            f.state = "curious"
            return
        end
    end

    if sp.bottom then
        f.state = "forage"
    else
        f.state = sp.school and "school" or "wander"
    end
end

local function steer(f, ctx, dt)
    local sp = f.sp
    local env = ctx.env
    local dx, dy, dz = 0, 0, 0
    local speedGoal = sp.cruise

    local function seek(tx, ty, tz, w)
        local ax, ay, az = tx - f.x, ty - f.y, (tz - f.z) * DEPTH * 0.7
        local l = sqrt(ax * ax + ay * ay + az * az) + 1e-6
        dx, dy, dz = dx + ax / l * w, dy + ay / l * w, dz + az / l * w
        return l
    end

    local st = f.state
    if st == "wander" or st == "wary" or st == "school" then
        f.wanderTimer = f.wanderTimer - dt
        local dist = seek(f.tx, f.ty, f.tz, st == "school" and 0.35 or 1)
        if dist < 30 or f.wanderTimer <= 0 then pickWanderTarget(f) end
        if st == "wary" then speedGoal = sp.cruise * 1.2 end
        -- Occasional pauses: hover and look around
        if f.pause and f.pause > 0 then
            f.pause = f.pause - dt
            speedGoal = sp.cruise * 0.12
        elseif random() < dt * 0.04 then
            f.pause = 1.5 + random() * 3
        end
    elseif st == "food" and f.food then
        local food = f.food
        local dist = seek(food.x, food.y, food.d, 1.5)
        speedGoal = min(sp.burst * 0.55, sp.cruise * 1.2 + dist * 0.6)
        f.lookX, f.lookY = clamp((food.x - f.x) / 60, -1, 1), clamp((food.y - f.y) / 60, -1, 1)
        if dist < f.L * 0.38 then
            food.eaten = true
            f.hunger = max(0, f.hunger - 0.32)
            f.fed = f.fed + 1
            f.trust = min(1, f.trust + 0.035)
            f.food = nil
            events[#events + 1] = { type = "eat", x = f.x, y = f.y, d = f.z, fish = f }
            if food.state == "settled" then
                events[#events + 1] = { type = "puff", x = food.x, y = food.y, d = food.d }
            end
        end
    elseif st == "curious" then
        local cur = ctx.cursor
        local wx, wy = World.unproject(cur.x, cur.y, 0.93)
        local side = (f.x < wx) and -1 or 1
        local dist = seek(wx + side * f.L * 0.9, wy + (f.seed % 3 - 1) * 14, 0.93, 1.2)
        speedGoal = clamp(dist * 0.5, 2, sp.cruise * 1.1)
        f.lookX, f.lookY = clamp((wx - f.x) / 80, -1, 1), clamp((wy - f.y) / 80, -1, 1)
    elseif st == "startle" then
        seek(f.tx, f.ty, f.tz, 2)
        speedGoal = sp.burst
    elseif st == "sleep" then
        local dist = seek(f.tx, f.ty, f.tz, 0.6)
        speedGoal = dist > 40 and sp.cruise * 0.5 or 1.5 + sin(f.time * 0.4) * 1.5
    elseif st == "breathe" then
        local dist = seek(f.tx, f.ty, f.tz, 1.6)
        speedGoal = sp.cruise * 1.8
        if dist < f.L * 0.5 or f.y < C.SURFACE_Y + f.L * 0.3 then
            -- Gulp at the surface, then head back down
            events[#events + 1] = { type = "gulp", x = f.x, y = C.SURFACE_Y, d = f.z, fish = f }
            f.state = "wander"
            f.stateTimer = 0
            pickWanderTarget(f)
            f.ty = zoneY(sp, f.tx, f.tz, 0.8)
            f.bubbleOnDive = 1.0
        end
    elseif st == "forage" then
        -- Corydoras: shuffle along the floor, nose down, sifting sand
        local fy = World.floorY(f.x, f.z)
        if not f.tx or f.wanderTimer <= 0 or abs(f.x - f.tx) < 12 then
            local tz = clamp(f.z + (random() - 0.5) * 0.3, 0.2, 0.95)
            f.tx = clamp(f.x + (random() - 0.5) * 260, World.xBounds(tz, 70))
            f.tz = tz
            f.wanderTimer = 3 + random() * 6
            f.sift = random() < 0.6 and (1.5 + random() * 3) or 0
        end
        f.wanderTimer = f.wanderTimer - dt
        f.ty = World.floorY(f.tx, f.tz) - f.L * 0.16
        seek(f.tx, f.ty, f.tz, 1)
        local hover = fy - f.y
        if f.sift and f.sift > 0 then
            f.sift = f.sift - dt
            speedGoal = 3
            f.phiBias = -0.35
            if random() < dt * 2.5 and hover < f.L * 0.5 then
                events[#events + 1] = { type = "puff", x = f.x + cos(f.psi) * f.L * 0.5, y = fy, d = f.z }
            end
        else
            f.phiBias = 0
            speedGoal = sp.cruise
        end
    end

    -- Schooling (boids) for schooling species
    if sp.school and st ~= "startle" and st ~= "sleep" and st ~= "curious" then
        local key = f.key
        local stg = schoolTargets[key]
        local cx, cy, cz, ax, ay, az, sx_, sy_, sz_, n = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        for _, o in ipairs(all) do
            if o ~= f and o.key == key and o.state ~= "sleep" then
                local ox, oy, oz = o.x - f.x, o.y - f.y, (o.z - f.z) * DEPTH
                local d2 = ox * ox + oy * oy + oz * oz
                if d2 < 140 * 140 then
                    n = n + 1
                    cx, cy, cz = cx + ox, cy + oy, cz + oz
                    ax = ax + cos(o.psi)
                    az = az + sin(o.psi)
                    ay = ay - sin(o.phi)
                    local sep = f.L * 1.1
                    if d2 < sep * sep then
                        local d = sqrt(d2) + 0.01
                        local push = (sep - d) / sep
                        sx_, sy_, sz_ = sx_ - ox / d * push, sy_ - oy / d * push, sz_ - oz / d * push
                    end
                end
            end
        end
        if n > 0 then
            local cl = sqrt(cx * cx + cy * cy + cz * cz) + 1e-6
            dx, dy, dz = dx + cx / cl * 0.6, dy + cy / cl * 0.6, dz + cz / cl * 0.6
            local al = sqrt(ax * ax + ay * ay + az * az) + 1e-6
            dx, dy, dz = dx + ax / al * 0.9, dy + ay / al * 0.9, dz + az / al * 0.9
            dx, dy, dz = dx + sx_ * 2.2, dy + sy_ * 2.2, dz + sz_ * 2.2
        end
        if st == "school" and stg then
            seek(stg.x, stg.y, stg.z, 0.7)
        end
    end

    -- Personal space with everyone
    for _, o in ipairs(all) do
        if o ~= f and not (sp.school and o.key == f.key) then
            local ox, oy, oz = o.x - f.x, o.y - f.y, (o.z - f.z) * DEPTH
            local r = (f.L + o.L) * 0.55
            local d2 = ox * ox + oy * oy + oz * oz
            if d2 < r * r then
                local d = sqrt(d2) + 0.01
                local push = (r - d) / r * 1.5
                dx, dy, dz = dx - ox / d * push, dy - oy / d * push, dz - oz / d * push
            end
        end
    end

    -- Tank bounds (soft)
    local lo, hi = World.xBounds(f.z, 50)
    local m = 70
    if f.x < lo + m then dx = dx + (lo + m - f.x) / m * 2 end
    if f.x > hi - m then dx = dx - (f.x - (hi - m)) / m * 2 end
    local top = C.SURFACE_Y + f.L * 0.35
    local floor = World.floorY(f.x, f.z) - f.L * (sp.bottom and 0.12 or 0.45)
    if st ~= "breathe" and f.y < top + 40 then dy = dy + (top + 40 - f.y) / 40 * 1.5 end
    if f.y > floor - 30 and not (sp.bottom or st == "sleep") then dy = dy - (f.y - (floor - 30)) / 30 * 1.5 end
    if f.z < 0.1 then dz = dz + (0.1 - f.z) * 30 end
    if f.z > 0.94 then dz = dz - (f.z - 0.94) * 30 end

    -- Rocks: glide over them
    for _, r in ipairs(ctx.rocks) do
        local rx, rz = f.x - r.x, (f.z - r.d) * DEPTH
        if abs(rx) < r.w * 0.6 + f.L * 0.4 and abs(rz) < 40 and f.y > r.y - r.h - f.L * 0.3 then
            dy = dy - 2.5
        end
    end

    return dx, dy, dz, speedGoal
end

function Fish.update(dt, ctx)
    local env = ctx.env

    -- Shared school targets drift across the tank
    for _, key in ipairs(Species.order) do
        local sp = Species[key]
        if sp.school then
            local t = schoolTargets[key]
            if not t or t.timer <= 0 then
                local z = 0.25 + random() * 0.6
                local lo, hi = World.xBounds(z, 160)
                local x = lo + random() * (hi - lo)
                t = { x = x, y = zoneY(sp, x, z, random()), z = z, timer = 6 + random() * 8 }
                schoolTargets[key] = t
            end
            t.timer = t.timer - dt
        end
    end

    for _, f in ipairs(all) do
        local sp = f.sp
        f.time = f.time + dt
        f.stateTimer = f.stateTimer - dt
        f.hunger = min(1, f.hunger + dt * 0.010)
        if f.breathTimer then f.breathTimer = f.breathTimer - dt end

        chooseState(f, ctx)
        local dx, dy, dz, speedGoal = steer(f, ctx, dt)

        -- Desired heading
        local hz = sqrt(dx * dx + dz * dz)
        if hz > 1e-4 or abs(dy) > 1e-4 then
            local psiD = atan2(dz, dx)
            local diff = wrapAngle(psiD - f.psi)
            -- Reversals: commit to turning toward or away from the glass
            if abs(diff) > pi - 0.25 then
                if f.turnDir == 0 then f.turnDir = (f.z < 0.55) and 1 or -1 end
                diff = abs(diff) * f.turnDir
            elseif abs(diff) < 0.3 then
                f.turnDir = 0
            end
            local rate = sp.turnRate * (f.state == "startle" and 2.2 or 1)
            local want = clamp(diff * 3.5, -rate, rate)
            f.yawRate = f.yawRate + (want - f.yawRate) * min(1, dt * 6)
            f.psi = wrapAngle(f.psi + f.yawRate * dt)

            local maxPitch = sp.bottom and 0.5 or 0.55
            local phiD = clamp(atan2(-dy, max(hz, 0.2)), -maxPitch, maxPitch) + (f.phiBias or 0)
            if f.state == "breathe" then phiD = clamp(atan2(-dy, max(hz, 0.15)), -1.1, 1.1) end
            f.phi = f.phi + (phiD - f.phi) * min(1, dt * 2.5)
        end
        -- Fish level out when resting
        if f.speed < sp.cruise * 0.3 and f.state ~= "forage" then
            f.phi = f.phi * (1 - dt * 1.5)
        end

        -- Speed
        local acc = sp.accel * (f.state == "startle" and 3 or 1)
        if f.speed < speedGoal then
            f.speed = min(speedGoal, f.speed + acc * dt)
        else
            f.speed = max(speedGoal, f.speed - acc * 0.8 * dt)
        end

        -- Move
        local cp, sp_, ct, st = cos(f.psi), sin(f.psi), cos(f.phi), sin(f.phi)
        f.x = f.x + cp * ct * f.speed * dt
        f.y = f.y - st * f.speed * dt
        f.z = clamp(f.z + sp_ * ct * f.speed * dt / DEPTH, 0.04, 0.98)
        local lo, hi = World.xBounds(f.z, 20)
        f.x = clamp(f.x, lo, hi)
        f.y = clamp(f.y, C.SURFACE_Y + f.L * 0.15, World.floorY(f.x, f.z) - f.L * 0.1)
        f.d = f.z

        -- Swimming motion
        local w = sp.wave
        local effort = min(1.6, f.speed / sp.cruise)
        f.phase = f.phase + dt * 2 * pi * w.freq * (0.35 + effort * 0.8)
        local ampGoal = w.amp * (0.3 + 0.7 * min(1.3, effort))
        f.amp = f.amp + (ampGoal - f.amp) * min(1, dt * 3)
        f.finPhase = f.finPhase + dt * 2 * pi * (1.2 + (1 - min(1, effort)) * 2.2)
        local bendGoal = clamp(-f.yawRate * 0.07, -0.3, 0.3)
        f.turnBend = f.turnBend + (bendGoal - f.turnBend) * min(1, dt * 5)

        -- Gaze relaxes toward straight ahead
        f.lookX = f.lookX * (1 - dt * 2)
        f.lookY = f.lookY * (1 - dt * 2)

        -- Colors: iridescence shifts with viewing angle, fade when asleep
        f.irid = 0.78 + 0.28 * cos(f.psi * 2 + f.time * 0.3) * cos(f.phi * 3)
        local vividGoal = (f.state == "sleep") and env.vivid or math.max(env.vivid, 0.85)
        f.vivid = f.vivid + (vividGoal - f.vivid) * min(1, dt * 0.5)

        if f.bubbleOnDive then
            f.bubbleOnDive = f.bubbleOnDive - dt
            if f.bubbleOnDive < 0.7 and random() < dt * 4 then
                events[#events + 1] = { type = "bubble", x = f.x + cos(f.psi) * f.L * 0.5, y = f.y, d = f.z }
            end
            if f.bubbleOnDive <= 0 then f.bubbleOnDive = nil end
        end
    end
end

function Fish.draw(f, env)
    Body.draw(f, env)
end

return Fish
