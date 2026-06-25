local M = {}

local cx, cy, last = 1920, 1080, -1

function M.size(force)
    local now = os.clock()
    if force or last < 0 or now - last > 2 then
        local ws = windower.get_windower_settings()
        if ws then cx = ws.ui_x_res or cx; cy = ws.ui_y_res or cy end
        last = now
    end
    return cx, cy
end

function M.w() return (select(1, M.size())) end
function M.h() return (select(2, M.size())) end

return M
