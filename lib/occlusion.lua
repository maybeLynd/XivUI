local texts = require('texts')
local images = require('images')
local M = {}

local _list     = {}
local _layer    = setmetatable({}, { __mode = 'k' })
local _kind     = setmetatable({}, { __mode = 'k' })
local _occluded = setmetatable({}, { __mode = 'k' })
local _ext      = setmetatable({}, { __mode = 'k' })
local _rjust    = setmetatable({}, { __mode = 'k' })
local _want     = setmetatable({}, { __mode = 'k' })
local _otvis, _otshow, _othide = texts.visible, texts.show, texts.hide
local _oivis, _oishow, _oihide = images.visible, images.show, images.hide
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
    texts.visible = function(t, v) if v ~= nil then _want[t] = v and true or false end return _otvis(t, v) end
    texts.show    = function(t) _want[t] = true;  return _otshow(t) end
    texts.hide    = function(t) _want[t] = false; return _othide(t) end
end

if not images._xivui_occ then
    images._xivui_occ = true
    local orig = images.new
    images.new = function(...)
        local t = orig(...)
        _layer[t] = _cur
        _kind[t] = 'img'
        _list[#_list + 1] = t
        return t
    end
    images.visible = function(t, v) if v ~= nil then _want[t] = v and true or false end return _oivis(t, v) end
    images.show    = function(t) _want[t] = true;  return _oishow(t) end
    images.hide    = function(t) _want[t] = false; return _oihide(t) end
end

function M.push(n) _stack[#_stack + 1] = _cur; _cur = n or 0 end
function M.pop()   _cur = _stack[#_stack] or 0; _stack[#_stack] = nil end

function M.mark_right(t) if t then _rjust[t] = true end end

local function scrw()
    return ((windower.get_windower_settings() or {}).ui_x_res) or 1920
end

local function is_right(t)
    local r = _rjust[t]
    if r == nil then
        local okr, v = pcall(t.right_justified, t)
        r = (okr and v) and true or false
        _rjust[t] = r
    end
    return r
end

function M.set(id, x, y, w, h, layer, text_only)
    if w and h and w > 0 and h > 0 then
        _occ[id] = { x = x, y = y, w = w, h = h, layer = layer or 1, text_only = text_only == true }
    else
        _occ[id] = nil
    end
end

function M.clear(id) _occ[id] = nil end

local function covered(tl, x, y, w, h, m, is_img)
    m = m or 0
    for _, r in pairs(_occ) do
        if not (is_img and r.text_only)
            and tl < r.layer
            and x < r.x + r.w + m and x + w > r.x - m
            and y < r.y + r.h + m and y + h > r.y - m then
            return true
        end
    end
    return false
end

local HYST = 3

local function raw_set(t, v)
    if _kind[t] == 'img' then pcall(_oivis, t, v) else pcall(_otvis, t, v) end
end

local function restore(t)
    local w = _want[t]
    if w == nil then w = true end
    raw_set(t, w)
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
        elseif vis or _occluded[t] then
            wr = wr + 1; _list[wr] = t
            local is_img = _kind[t] == 'img'
            local lx, y, e
            if is_img then
                local okp, x, iy = pcall(t.pos, t)
                if okp then
                    x, y = x or 0, iy or 0
                    e = _ext[t]
                    if not _occluded[t] then
                        local okx, ex, ey = pcall(t.get_extents, t)
                        if okx and ex then
                            local ew, eh = ex - x, (ey or y) - y
                            if ew and ew > 0 then
                                if e then e.w, e.h = ew, eh or 0 else e = { w = ew, h = eh or 0 }; _ext[t] = e end
                            end
                        end
                    end
                    lx = x
                end
            else
                local okl, gx, gy = pcall(windower.text.get_location, t._name)
                if okl and gx then
                    y = gy or 0
                    e = _ext[t]
                    if vis and (not e or remeasure) then
                        local oke, w2, h2 = pcall(t.extents, t)
                        if oke and w2 and w2 > 0 then
                            if e then e.w, e.h = w2, h2 or 0 else e = { w = w2, h = h2 or 0 }; _ext[t] = e end
                        end
                    end
                    e = e or { w = 0, h = 0 }
                    lx = is_right(t) and (gx - e.w) or gx
                end
            end
            if lx then
                e = e or { w = 0, h = 0 }
                if _occluded[t] then
                    if covered(_layer[t] or 0, lx, y, e.w, e.h, HYST, is_img) then
                        raw_set(t, false)
                    else
                        restore(t)
                    end
                elseif vis and covered(_layer[t] or 0, lx, y, e.w, e.h, 0, is_img) then
                    _ext[t] = e
                    _occluded[t] = true
                    raw_set(t, false)
                end
            end
        else
            wr = wr + 1; _list[wr] = t
        end
    end
    for i = wr + 1, n do _list[i] = nil end
end

function M.dump()
    local out = _G.xivui_echo or print
    if next(_occ) == nil then
        out(('[occ] no active occluders — update() is idle (early-returns). %d primitives tracked.'):format(#_list))
        return
    end
    out(('[occ] %d primitives tracked; update() is iterating them every frame:'):format(#_list))
    out('[occ] occluders:')
    for id, r in pairs(_occ) do
        out(('  %s  L%d  x%d y%d %dx%d%s'):format(id, r.layer, r.x, r.y, r.w, r.h,
            r.text_only and '  text_only' or ''))
    end
    out('[occ] VISIBLE layer-0 images overlapping the menu (excludes menu/tooltip imgs):')
    local n, shown, leaks = #_list, 0, 0
    for i = 1, n do
        local t = _list[i]
        local is_img = _kind[t] == 'img'
        local lyr = _layer[t] or 0
        local okv, vis = pcall(t.visible, t)
        if is_img and lyr == 0 and okv and vis then
            local okp, px, py = pcall(t.pos, t)
            local okx, ex, ey = pcall(t.get_extents, t)
            local x = (okp and px) or 0
            local y = (okp and py) or 0
            local w = (okx and ex and (ex - x)) or 0
            local h = (okx and ey and (ey - y)) or 0
            local hit = false
            for _, r in pairs(_occ) do
                if x < r.x + r.w and x + w > r.x and y < r.y + r.h and y + h > r.y then hit = true; break end
            end
            if hit then
                local cov = covered(lyr, x, y, w, h, 0, is_img)
                if not cov then leaks = leaks + 1 end
                if shown < 60 then
                    shown = shown + 1
                    out(('  img L%d [%d,%d %dx%d] cov=%s%s'):format(
                        lyr, x, y, w, h, tostring(cov), cov and '' or '  <== LEAK'))
                end
            end
        end
    end
    out(('[occ] %d overlapping the menu, %d are leaks (cov=false), %d tracked total'):format(shown, leaks, n))
end

return M
