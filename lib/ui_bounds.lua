local M = {}
local images = require('images')
local _rects = {}
local _imgs = {}

local function ensure_img(id)
    local img = _imgs[id]
    if not img then
        img = images.new()
        img:draggable(false)
        img:fit(false)
        img:alpha(0)
        _imgs[id] = img
    end
    return img
end

function M.register(id, x, y, w, h)
    if w > 0 and h > 0 then
        _rects[id] = { x = x, y = y, w = w, h = h }
        local ex, ey = w * 0.01, h * 0.01
        local img = ensure_img(id)
        img:pos(x - ex, y - ey)
        img:size(w + 2 * ex, h + 2 * ey)
        img:alpha(0)
        img:show()
    end
end

function M.clear(id)
    _rects[id] = nil
    local img = _imgs[id]
    if img then img:hide() end
end

function M.all()
    local out = {}
    for id, r in pairs(_rects) do out[id] = { x = r.x, y = r.y, w = r.w, h = r.h } end
    return out
end

function M.to_ui(px, py)
    return px, py
end

function M.hover_test(px, py)
    for id, img in pairs(_imgs) do
        if _rects[id] and img:hover(px, py) then return true end
    end
    return false
end

return M
