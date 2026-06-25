local texts = require('texts')
local M = {}

local _list     = {}
local _layer    = setmetatable({}, { __mode = 'k' })
local _occluded = setmetatable({}, { __mode = 'k' })
local _ext      = setmetatable({}, { __mode = 'k' })
local _rjust    = setmetatable({}, { __mode = 'k' })
local _scrw
local _occ      = {}
local _cur      = 0
local _stack    = {}
local _frame    = 0
local REMEASURE = 20

if not texts._xivui_occ then
    texts._xivui_occ = true
    local orig = texts.new
    texts.new = function(...)
        local t = orig(...)
        _layer[t] = _cur
        _list[#_list + 1] = t
        return t
    end
end

function M.push(n) _stack[#_stack + 1] = _cur; _cur = n or 0 end
function M.pop()   _cur = _stack[#_stack] or 0; _stack[#_stack] = nil end

function M.mark_right(t) if t then _rjust[t] = true end end

function M.set(id, x, y, w, h, layer)
    if w and h and w > 0 and h > 0 then
        _occ[id] = { x = x, y = y, w = w, h = h, layer = layer or 1 }
    else
        _occ[id] = nil
    end
end

function M.clear(id) _occ[id] = nil end

local function covered(tl, x, y, w, h, m)
    m = m or 0
    for _, r in pairs(_occ) do
        if tl < r.layer
            and x < r.x + r.w + m and x + w > r.x - m
            and y < r.y + r.h + m and y + h > r.y - m then
            return true
        end
    end
    return false
end

local HYST = 3

local function restore(t)
    pcall(t.visible, t, true)
    _occluded[t] = nil
end

function M.update()
    if next(_occ) == nil then
        for t in pairs(_occluded) do restore(t) end
        return
    end
    _frame = _frame + 1
    local remeasure = _frame % REMEASURE == 0
    local n, wr = #_list, 0
    for i = 1, n do
        local t = _list[i]
        local okv, vis = pcall(t.visible, t)
        if not okv then
            _occluded[t] = nil; _ext[t] = nil
        else
            wr = wr + 1; _list[wr] = t
            local okp, x, y = pcall(t.pos, t)
            if okp then
                x, y = x or 0, y or 0
                local e = _ext[t]
                if vis and not _occluded[t] and (not e or remeasure) then
                    local oke, ew, eh = pcall(t.extents, t)
                    if oke and ew and ew > 0 then
                        if e then e.w, e.h = ew, eh or 0 else e = { w = ew, h = eh or 0 }; _ext[t] = e end
                    end
                end
                e = e or { w = 0, h = 0 }
                local lx = x
                if _rjust[t] then
                    _scrw = _scrw or ((windower.get_windower_settings() or {}).ui_x_res or 1920)
                    lx = x + _scrw - e.w
                end
                if _occluded[t] then
                    if covered(_layer[t] or 0, lx, y, e.w, e.h, HYST) then
                        pcall(t.visible, t, false)
                    else
                        restore(t)
                    end
                elseif vis and covered(_layer[t] or 0, lx, y, e.w, e.h) then
                    _ext[t] = e
                    _occluded[t] = true
                    pcall(t.visible, t, false)
                end
            end
        end
    end
    for i = wr + 1, n do _list[i] = nil end
end

return M
