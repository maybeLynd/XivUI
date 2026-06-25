local shadow_tracker = {}

local TIER = { [66] = 1, [444] = 2, [445] = 3, [446] = 4, [36] = 2 }
shadow_tracker.ABSORB_MSGS = { [14] = true, [31] = true, [535] = true }

local count    = {}
local depleted = {}

function shadow_tracker.is_shadow(status_id)
    return TIER[status_id] ~= nil
end

function shadow_tracker.on_gain(entity_id, status_id)
    local n = TIER[status_id]
    if not n then return end
    count[entity_id]    = math.max(count[entity_id] or 0, n)
    depleted[entity_id] = nil
end

function shadow_tracker.on_absorb(entity_id, n)
    if count[entity_id] == nil then
        count[entity_id] = 3
    end
    count[entity_id] = count[entity_id] - (n or 1)
    if count[entity_id] <= 0 then
        count[entity_id]    = 0
        depleted[entity_id] = true
    end
end

function shadow_tracker.is_depleted(entity_id)
    return depleted[entity_id] == true
end

function shadow_tracker.count(entity_id)
    return count[entity_id]
end

function shadow_tracker.clear(entity_id)
    count[entity_id]    = nil
    depleted[entity_id] = nil
end

return shadow_tracker
