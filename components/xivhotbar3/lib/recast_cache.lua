-- recast_cache: remembers ability recast durations across sessions.
-- The action tooltip shows the cached value, or "?" until the ability has been used once.
-- Keyed by recast_id (what get_ability_recasts and the hotbar use).

local recast_cache = {}

local PATH    = require('lib/cache').path('xivhotbar3', 'recast_cache.lua')
local data    = {}
local prev    = {}
local inited  = false
local dirty   = false

function recast_cache.load()
    local ok, t = pcall(function()
        local f = loadfile(PATH)
        return f and f() or nil
    end)
    if ok and type(t) == 'table' then
        data = {}
        for k, v in pairs(t) do data[tonumber(k) or k] = tonumber(v) end
    end
end

function recast_cache.save()
    if not dirty then return end
    local f = io.open(PATH, 'w')
    if not f then return end
    f:write('-- xivhotbar3 learned ability recasts (auto-generated)\nreturn {\n')
    for id, v in pairs(data) do
        f:write(string.format('  [%s] = %s,\n', tostring(id), tostring(v)))
    end
    f:write('}\n')
    f:close()
    dirty = false
end

function recast_cache.get(recast_id)
    recast_id = tonumber(recast_id)
    return recast_id and data[recast_id] or nil
end

function recast_cache.observe_live(recasts)
    if type(recasts) ~= 'table' then return end
    for id, rem in pairs(recasts) do
        rem = tonumber(rem) or 0
        local p = prev[id] or 0
        if inited and p < 2 and rem > 2 then
            if data[id] ~= rem then data[id] = rem; dirty = true end
        end
        prev[id] = rem
    end
    inited = true
    if dirty then recast_cache.save() end
end

return recast_cache
