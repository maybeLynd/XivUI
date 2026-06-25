local zone_state = {}

zone_state.is_zoning = false
zone_state.grace_until = nil

local GRACE = 1.0

function zone_state.zone_start()
    zone_state.is_zoning = true
    zone_state.grace_until = nil
end

local function begin_grace()
    if zone_state.is_zoning then
        zone_state.is_zoning = false
        zone_state.grace_until = os.clock() + GRACE
    end
    return false
end

zone_state.zone_packet = begin_grace
zone_state.zone_complete = begin_grace

function zone_state.status_changed()
    return false
end

function zone_state.hidden()
    if zone_state.is_zoning then return true end
    if zone_state.grace_until then
        local p = windower.ffxi.get_player()
        if os.clock() < zone_state.grace_until or not p or p.status == 4 then
            return true
        end
        zone_state.grace_until = nil
    end
    return false
end

return zone_state
