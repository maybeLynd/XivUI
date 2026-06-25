local packets = require('packets')
local socket  = require('socket')

local targeting = {}

local pending = nil
local prerender_id = nil

local function inject_target_index(index)
    index = tonumber(index)
    if not index or index <= 0 then return false end
    local ok = pcall(function()
        packets.inject(packets.new('outgoing', 0x016, { ['Target Index'] = index }))
    end)
    return ok == true
end

local function command_target_name(name)
    if name and tostring(name) ~= '' then
        windower.chat.input('/target ' .. tostring(name))
        return true
    end
    return false
end

local function cleanup_pending()
    pending = nil
end

local function current_target_index()
    local cur = windower.ffxi.get_mob_by_target('t')
    return cur and cur.index or 0
end

local function target_exists(index)
    local want = windower.ffxi.get_mob_by_index(index)
    return want and want.id and want.id > 0 and (want.hpp == nil or want.hpp > 0)
end

local function pending_prerender()
    if not pending then return end

    local now = socket.gettime()
    local ci = current_target_index()
    if ci == pending.index then
        cleanup_pending()
        return
    end

    if not target_exists(pending.index) then
        cleanup_pending()
        return
    end

    if now - pending.started_at > pending.timeout then
        cleanup_pending()
        return
    end

    if now >= pending.next_attempt then
        pending.attempts = pending.attempts + 1

        inject_target_index(pending.index)

        if pending.attempts == 1 and pending.name then
            command_target_name(pending.name)
        end

        if pending.attempts > 1 then
            if pending.seen[ci] then
                cleanup_pending()
                return
            end
            pending.seen[ci] = true
            windower.send_command('setkey tab down; wait 0.02; setkey tab up')
        end

        pending.next_attempt = now + pending.interval
    end
end

local function ensure_prerender()
    if not prerender_id then
        prerender_id = windower.register_event('prerender', pending_prerender)
    end
end

function targeting.target_index(index, name)
    index = tonumber(index)
    if not index or index <= 0 then
        return command_target_name(name)
    end

    local now = socket.gettime()
    pending = {
        index = index,
        name = name,
        started_at = now,
        next_attempt = now + 0.05,
        attempts = 0,
        timeout = 3.0,
        interval = 0.12,
        seen = {},
    }
    ensure_prerender()

    inject_target_index(index)
    if name then command_target_name(name) end
    return true
end

function targeting.assist_current(index, name)
    windower.chat.input('/assist <t>')
    if index and tonumber(index) and tonumber(index) > 0 then
        return targeting.target_index(index, name)
    end
    return true
end

function targeting.target_mob(mob_or_index, name)
    if type(mob_or_index) == 'table' then
        return targeting.target_index(mob_or_index.index, mob_or_index.name or name)
    end
    local idx = tonumber(mob_or_index)
    if idx and idx > 0 then
        local mob = windower.ffxi.get_mob_by_index(idx)
        return targeting.target_index(idx, (mob and mob.name) or name)
    end
    return command_target_name(name)
end

function targeting.target_id(id, name)
    local mob = id and windower.ffxi.get_mob_by_id(id)
    if mob and mob.index and mob.index > 0 then
        return targeting.target_index(mob.index, mob.name or name)
    end
    return command_target_name(name)
end

function targeting.dispose()
    pending = nil
    if prerender_id then
        windower.unregister_event(prerender_id)
        prerender_id = nil
    end
end

return targeting
