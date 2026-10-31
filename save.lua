-- Remembers your fish between visits: their names, how much they trust
-- you, and how often you have fed them.

local Save = {}

local FILE = "tank.lua"

--- Keep the tank in another file. The self-test uses its own, so a test
--- never meets, feeds or renames the fish you know.
function Save.use(file) FILE = file end

function Save.file() return FILE end

local function serialize(v, indent)
    indent = indent or ""
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local out = { "{\n" }
        for _, k in ipairs(keys) do
            out[#out + 1] = string.format("%s  [%q] = %s,\n", indent, tostring(k), serialize(v[k], indent .. "  "))
        end
        out[#out + 1] = indent .. "}"
        return table.concat(out)
    elseif type(v) == "string" then
        return string.format("%q", v)
    else
        return tostring(v)
    end
end

function Save.load()
    if not love.filesystem.getInfo(FILE) then return nil end
    local ok, chunk = pcall(love.filesystem.load, FILE)
    if not ok or not chunk then return nil end
    local ok2, data = pcall(chunk)
    if ok2 and type(data) == "table" then return data end
    return nil
end

function Save.write(data)
    love.filesystem.write(FILE, "return " .. serialize(data) .. "\n")
end

return Save
