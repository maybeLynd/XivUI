local ui_bounds = require('lib/ui_bounds')

local draggable = {}

function draggable.handle(state, mtype, x, y, opts)
    local ux, uy = ui_bounds.to_ui(x, y)
    local over = (opts.bounds == nil) or opts.bounds(ux, uy)

    if mtype == 1 then
        if over and opts.can_drag ~= false then
            local px, py = opts.get()
            state.dragging = true
            state.ox, state.oy = ux - px, uy - py
        end
        return over
    elseif mtype == 0 then
        if state.dragging then
            opts.set(math.floor(ux - state.ox), math.floor(uy - state.oy))
            return true
        end
        return over
    elseif mtype == 2 then
        if state.dragging then
            state.dragging = false
            opts.set(math.floor(ux - state.ox), math.floor(uy - state.oy))
            if opts.save then opts.save() end
            return true
        end
        return over
    end
    return false
end

return draggable
