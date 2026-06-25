local socket = require('socket')

local cast_state = {}

cast_state.BLINK_HALF  = 0.14
cast_state.BLINK_COUNT = 3

cast_state.INTERRUPT_MSGS = {
    [16] = true, [29] = true, [84] = true, [106] = true, [49] = true, [47] = true,
    [71] = true, [78] = true, [328] = true, [313] = true, [700] = true,
}

cast_state.INCAPACITATE_BUFFS = { [10] = true, [2] = true, [19] = true, [7] = true, [28] = true }

function cast_state.has_incapacitate(buffs)
    if not buffs then return false end
    for _, b in ipairs(buffs) do
        if cast_state.INCAPACITATE_BUFFS[tonumber(b) or -1] then return true end
    end
    return false
end

function cast_state.blink_phase(start)
    local e = socket.gettime() - start
    if e >= cast_state.BLINK_HALF * 2 * cast_state.BLINK_COUNT then return 'done' end
    return (math.floor(e / cast_state.BLINK_HALF) % 2 == 0) and 'on' or 'off'
end

function cast_state.start(s, duration, name, spell_id)
    s.start_time = socket.gettime()
    s.duration   = duration
    s.name       = name
    s.spell_id   = spell_id
    s.clear_time = nil
    s.flash_end  = nil
    s.intr_start = nil
end

function cast_state.complete(s)
    if s.start_time then
        if s.calib and s.spell_id then
            local actual   = socket.gettime() - s.start_time
            local expected = s.duration or 3
            if actual >= 0.1 and actual <= expected * 2.5 then
                local prev = s.calib[s.spell_id]
                s.calib[s.spell_id] = prev and (prev * 0.7 + actual * 0.3) or actual
            end
        end
        s.clear_time = socket.gettime()
    end
    s.start_time = nil
    s.duration   = nil
    s.flash_end  = nil
end

function cast_state.cancel(s)
    s.start_time = nil
    s.duration   = nil
    s.spell_id   = nil
    s.name       = nil
    s.clear_time = nil
    s.flash_end  = nil
    s.intr_start = nil
end

function cast_state.interrupt(s)
    local p = cast_state.progress(s) or 1
    s.intr_prog  = math.max(0.06, p)
    s.intr_start = socket.gettime()
    s.start_time = nil
    s.duration   = nil
    s.spell_id   = nil
    s.name       = nil
    s.clear_time = nil
    s.flash_end  = nil
end

function cast_state.flash(s, name, secs)
    s.name       = name
    s.flash_end  = socket.gettime() + secs
    s.start_time = nil
    s.duration   = nil
    s.clear_time = nil
    s.intr_start = nil
end

function cast_state.is_interrupt(s)
    return s.intr_start ~= nil
end

function cast_state.progress(s)
    if s.intr_start then
        local ph = cast_state.blink_phase(s.intr_start)
        if ph == 'done' then s.intr_start = nil; s.intr_prog = nil; s.name = nil; return nil end
        if ph == 'on' then return s.intr_prog or 1 end
        return nil
    end
    if s.flash_end then
        if socket.gettime() < s.flash_end then return 1 end
        s.flash_end = nil; s.name = nil; return nil
    end
    if s.clear_time then
        if socket.gettime() - s.clear_time < 0.15 then return 1 end
        s.clear_time = nil; s.name = nil; return nil
    end
    if not s.start_time or not s.duration or s.duration <= 0 then return nil end
    local e = socket.gettime() - s.start_time
    if e >= s.duration then
        if s.hold and e < s.duration + (s.hold_grace or 12) then
            return 0.99
        end
        s.clear_time = socket.gettime()
        s.start_time = nil
        s.duration   = nil
        s.spell_id   = nil
        return 1
    end
    return e / s.duration
end

return cast_state
