-- hud.lua: FFXIV style HUD Layout editor for XivUI.
-- Dims the screen, lays a fine reference grid over it, and draws a box for every component.
-- Components that aren't visible are read from their settings and drawn greyed out so they can still be grabbed.
-- Left click a box to focus it, drag to move, scroll-wheel to scale.
-- Moves persist through each component's `pos` command; scale persists only where the component supports it.
-- XivUI Menu component lib. Maintainer: maybeLynd.

local images    = require('images')
local texts     = require('texts')
local config    = require('config')
local ui_bounds = require('lib/ui_bounds')

local M = { open = false }

local ASSET = windower.addon_path .. 'assets/components/xivuimenu/'
local WHITE = ASSET .. 'white.png'
local GRID  = ASSET .. 'grid.png'
local FONT  = 'Constantia'

local floor, max, min = math.floor, math.max, math.min
local function screen() local ws = windower.get_windower_settings(); return ws.ui_x_res, ws.ui_y_res end
local function send(s) windower.send_command('xui ' .. s) end
local function num(v, d) v = tonumber(v); if v == nil then return d end; return v end
local function load_cfg(file, def)
    local ok, s = pcall(config.load, file, def or {})
    if ok and s then return s end
    return nil
end

local DESC = {
    { id = 'statusbar', label = 'Status Bars', file = 'data/statusbar/settings.xml',
      def = { Bars = { OffsetX = 0, OffsetY = 0, Scale = 1 } }, w = 500, h = 40, scale_keeps_pos = true,
      pos = function(s) local rx, ry = screen(); local b = s and s.Bars or {}
            return floor(rx / 2 - 250 + num(b.OffsetX, 0)), floor(ry - 60 + num(b.OffsetY, 0)) end,
      scale = function(s) return num(s and s.Bars and s.Bars.Scale, 1) end,
      setpos = function(r) local rx, ry = screen(); send('status pos ' .. floor(r.x - rx / 2 + r.w / 2) .. ' ' .. floor(r.y - ry + 60)) end,
      setscale = function(r) send('status scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'expbar', label = 'EXP Bar', file = 'data/expbar/settings.xml',
      def = { scale = 1, Images = { Background = { Pos = { X = 0, Y = 0 } } } }, w = 504, h = 32, scale_keeps_pos = true,
      pos = function(s) local p = s and s.Images and s.Images.Background and s.Images.Background.Pos or {}
            local sc = num(s and s.scale, 1)
            return floor(num(p.X, 100)), floor(num(p.Y, 100) - 13.5 * sc) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('exp pos ' .. floor(r.x) .. ' ' .. floor(r.y + 13.5 * (r.scale or 1))) end,
      setscale = function(r) send('exp scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'targetbar', label = 'Target Bar', file = 'data/targetbar/settings.xml',
      def = { pos = { x = 0, y = 0 }, scale = 1 }, w = 598, h = 42,
      pos = function(s) local p = s and s.pos or {}; return floor(num(p.x, 360)), floor(num(p.y, 50)) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('target pos ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('target scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'aggrolist', label = 'Aggro List', file = 'data/aggrolist/settings.xml',
      def = { pos = { x = 0, y = 0 }, scale = 1 }, w = 95, h = 150,
      pos = function(s) local p = s and s.pos or {}; return floor(num(p.x, 30)), floor(num(p.y, 120)) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('aggro pos ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('aggro scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'dps', label = 'DPS Parser', file = 'data/dps/settings.xml',
      def = { pos = { x = 0, y = 0 }, scale = 1 }, w = 500, h = 220,
      pos = function(s) local p = s and s.pos or {}; return floor(num(p.x, 30)), floor(num(p.y, 300)) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('dps pos ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('dps scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'notification', label = 'Loot Toast', file = 'data/notification/settings.xml',
      def = { pos = { x = 0, y = 0 }, scale = 1 }, w = 200, h = 20,
      pos = function(s) local p = s and s.pos or {}; return floor(num(p.x, 600)), floor(num(p.y, 400)) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('notify pos ' .. floor(r.x) .. ' ' .. floor(r.y + 2)) end,
      setscale = function(r)
            local ok, m = pcall(require, 'components/notification/notification')
            if ok and m.hud_set_scale then m.hud_set_scale(r.scale)
            else send('notify scale ' .. string.format('%.2f', r.scale)) end end },

    { id = 'requestwindow', label = 'Requests', file = 'data/requestwindow/settings.xml',
      def = { notify = { x = 0, y = 0 }, scale = 1 }, w = 150, h = 34,
      pos = function(s) local p = s and s.notify or {}; return floor(num(p.x, 1100)), floor(num(p.y, 700)) end,
      scale = function(s) return num(s and s.scale, 1) end,
      setpos = function(r) send('request pos notify ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('request scale ' .. string.format('%.2f', r.scale)) end },

    { id = 'requestwindow_dialog', label = 'Request Dialog', file = 'data/requestwindow/settings.xml',
      def = { dialog = { x = 0, y = 0 }, dscale = 1 }, w = 380, h = 104,
      pos = function(s) local p = s and s.dialog or {}; local rx, ry = screen()
            return floor(num(p.x, rx / 2 - 190)), floor(num(p.y, ry / 2 - 52)) end,
      scale = function(s) return num(s and s.dscale, 1) end,
      setpos = function(r) send('request pos dialog ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('request scale dialog ' .. string.format('%.2f', r.scale)) end },

    { id = 'notification_join', label = 'Join Popup', file = 'data/notification/settings.xml',
      def = { join = { x = 0, y = 0 }, jscale = 1 }, w = 260, h = 22,
      pos = function(s) local p = s and s.join or {}; local rx, ry = screen()
            return floor(num(p.x, rx / 2 - 130)), floor(num(p.y, ry * 0.25)) end,
      scale = function(s) return num(s and s.jscale, 1) end,
      setpos = function(r) send('notify pos join ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r)
            local ok, m = pcall(require, 'components/notification/notification')
            if ok and m.hud_set_join_scale then m.hud_set_join_scale(r.scale)
            else send('notify scale join ' .. string.format('%.2f', r.scale)) end end },

    { id = 'castbar', label = 'Cast Bar', file = 'data/castbar/settings.xml',
      def = { Cast = { X = 0, Y = 0, Scale = 1 } }, w = 240, h = 22,
      pos = function(s) local c = s and s.Cast or {}; return floor(num(c.X, 700)), floor(num(c.Y, 500)) end,
      scale = function(s) return num(s and s.Cast and s.Cast.Scale, 1) end,
      setpos = function(r) send('cast pos cast ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('cast scale cast ' .. string.format('%.2f', r.scale)) end },

    { id = 'castbar_swing', label = 'Auto-Attack', file = 'data/castbar/settings.xml',
      def = { Swing = { X = 0, Y = 0, Scale = 1 } }, w = 160, h = 22,
      pos = function(s) local c = s and s.Swing or {}; return floor(num(c.X, 700)), floor(num(c.Y, 530)) end,
      scale = function(s) return num(s and s.Swing and s.Swing.Scale, 1) end,
      setpos = function(r) send('cast pos swing ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('cast scale swing ' .. string.format('%.2f', r.scale)) end },

    { id = 'castbar_ranged', label = 'Ranged Attack', file = 'data/castbar/settings.xml',
      def = { Ranged = { X = 0, Y = 0, Scale = 1 } }, w = 140, h = 20,
      pos = function(s) local c = s and s.Ranged or {}; return floor(num(c.X, 700)), floor(num(c.Y, 510)) end,
      scale = function(s) return num(s and s.Ranged and s.Ranged.Scale, 1) end,
      setpos = function(r) send('cast pos ranged ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('cast scale ranged ' .. string.format('%.2f', r.scale)) end },

    { id = 'xivuimenu', label = 'XivUI Menu', file = 'data/xivuimenu/settings.xml',
      def = { Pos = { X = -99999, Y = -99999 }, Scale = 1 }, w = 840, h = 496,
      pos = function(s) local rx, ry = screen(); local p = s and s.Pos or {}
            local x, y = num(p.X, -99999), num(p.Y, -99999)
            if x <= -9000 or y <= -9000 then return floor(rx / 2 - 420), floor(ry / 2 - 248) end
            return floor(x), floor(y) end,
      scale = function(s) return num(s and s.Scale, 1) end,
      setpos = function(r) send('menu pos ' .. floor(r.x) .. ' ' .. floor(r.y)) end,
      setscale = function(r) send('menu scale ' .. string.format('%.2f', r.scale)) end },
}

local PV = {
    statusbar     = { {0.01,0.12,0.98,0.18}, {0.01,0.40,0.98,0.18}, {0.01,0.68,0.98,0.18} },
    expbar        = { {0.0,0.42,0.93,0.16}, {0.94,0.05,0.06,0.90} },
    targetbar     = { {0.0,0.05,0.45,0.30}, {0.0,0.55,1.0,0.22} },
    xivparty      = { {0.04,0.08,0.92,0.10}, {0.04,0.26,0.92,0.10}, {0.04,0.44,0.92,0.10}, {0.04,0.62,0.92,0.10}, {0.04,0.80,0.92,0.10} },
    aggrolist     = { {0.06,0.10,0.88,0.12}, {0.06,0.32,0.88,0.12}, {0.06,0.54,0.88,0.12}, {0.06,0.76,0.88,0.12} },
    dps           = { {0.05,0.04,0.90,0.14}, {0.05,0.30,0.90,0.10}, {0.05,0.46,0.90,0.10}, {0.05,0.62,0.90,0.10}, {0.05,0.78,0.90,0.10} },
    notification  = { {0.0,0.32,0.75,0.34} },
    notification_join = { {0.0,0.2,1.0,0.6} },
    requestwindow = { {0.04,0.18,0.92,0.62} },
    requestwindow_dialog = { {0.03,0.08,0.94,0.30}, {0.08,0.55,0.36,0.32}, {0.56,0.55,0.36,0.32} },
    castbar       = { {0.0,0.32,1.0,0.40} },
    castbar_swing = { {0.0,0.32,1.0,0.40} },
    xivuimenu     = { {0.0,0.0,0.20,1.0}, {0.22,0.04,0.76,0.10},
                      {0.22,0.18,0.36,0.20}, {0.61,0.18,0.36,0.20},
                      {0.22,0.42,0.36,0.20}, {0.61,0.42,0.36,0.20},
                      {0.22,0.66,0.36,0.20}, {0.61,0.66,0.36,0.20} },
}

local built = false
local dim, grid, hint, donebg, donetx, cancelbg, canceltx
local fills, labels, prev = {}, {}, {}
local ring = {}
local sl_head, sl_track, sl_fill, sl_knob, sl_lab, sl_val
local sl_notch, sl_notch_lab = {}, {}

local function mkimg(r, g, b, a)
    local i = images.new()
    i:draggable(false); i:fit(false); i:path(WHITE)
    i:color(r or 255, g or 255, b or 255); i:alpha(a or 255); i:hide()
    return i
end
local function mktxt(size)
    local t = texts.new('${v}', { pos = { x = 0, y = 0 },
        text = { font = FONT, size = size, stroke = { width = 1, alpha = 170, red = 0, green = 0, blue = 0 } },
        flags = { bold = false, draggable = false }, bg = { visible = false } })
    t:color(255, 255, 255); t:alpha(255); t.v = ''; t:hide()
    pcall(function() t:font(FONT) end)
    return t
end
local function build()
    if built then return end
    dim  = mkimg(8, 9, 14, 150)
    grid = images.new(); grid:draggable(false); grid:fit(false); grid:path(GRID); grid:alpha(255); grid:hide()
    for i = 1, 4 do ring[i] = mkimg(255, 150, 40, 255) end
    donebg = mkimg(36, 38, 46, 235)
    donetx = mktxt(13)
    cancelbg = mkimg(46, 36, 36, 235)
    canceltx = mktxt(13)
    hint   = mktxt(12)
    sl_head  = mkimg(44, 48, 60, 235)
    sl_track = mkimg(30, 32, 40, 230)
    sl_fill  = mkimg(90, 150, 230, 180)
    sl_knob  = mkimg(235, 200, 110, 255)
    sl_lab   = mktxt(12)
    sl_val   = mktxt(12)
    built  = true
end

local boxes  = {}
local focus  = nil
local drag   = { active = false, i = nil, dx = 0, dy = 0, scaled = false, dirty = false }
local nudge_pending = false
local live_move
local slot_edit = nil
local last_box_click = { id = nil, t = 0 }
local done_rect2 = nil
local orig, moved, scaled = {}, {}, {}
local commit, commit_scale
local done_rect = { x = 0, y = 0, w = 0, h = 0 }
local resnap_frames = 0
local cur_env = nil

local SL_MIN, SL_MAX, SL_PW = 0.5, 2.5, 78
local SLIDER_CFG = 'data/xivuimenu/hud_slider.xml'
local slider = { mode = nil, dx = 0, dy = 0, x = nil, y = nil,
                 head = nil, knob = nil, track = nil, cx = 0, ytop = 0, h = 1 }

local function slider_load()
    local s = load_cfg(SLIDER_CFG, { Slider = { X = -1, Y = -1 } })
    local sx = (s and s.Slider and num(s.Slider.X, -1)) or -1
    local sy = (s and s.Slider and num(s.Slider.Y, -1)) or -1
    return sx, sy
end
local function slider_save(x, y)
    local s = load_cfg(SLIDER_CFG, { Slider = { X = -1, Y = -1 } })
    if s and s.Slider then s.Slider.X = floor(x); s.Slider.Y = floor(y); pcall(config.save, s) end
end
local function slider_set_from_y(y, persist)
    if not slider.h or slider.h <= 0 then return end
    local frac = (slider.ytop + slider.h - y) / slider.h
    frac = max(0, min(1, frac))
    local sc = SL_MIN + frac * (SL_MAX - SL_MIN)
    sc = floor(sc / 0.05 + 0.5) * 0.05
    if sc < SL_MIN then sc = SL_MIN elseif sc > SL_MAX then sc = SL_MAX end
    local ok, hb = pcall(require, 'components/xivhotbar3/xivhotbar3')
    if not ok then return end
    if persist then
        if hb.hud_set_scale then pcall(hb.hud_set_scale, sc) end
    elseif hb.hud_set_scale_live then pcall(hb.hud_set_scale_live, sc)
    elseif hb.hud_set_scale then pcall(hb.hud_set_scale, sc) end
end

local function camera_lock(on)
    if _G.XIVUI_STATE and _G.XIVUI_STATE.hud_camera_lock then _G.XIVUI_STATE.hud_camera_lock(on) end
end

local PREVIEW_COMPONENTS = { 'targetbar', 'aggrolist', 'dps', 'notification', 'castbar', 'requestwindow', 'xivparty', 'xivhotbar3', 'enemyloot', 'enemyweak' }
local forced_on = {}

local function is_enabled(name)
    local st = _G.XIVUI_STATE
    if st and st.components then
        for _, c in ipairs(st.components) do if c.name == name then return c.enabled end end
    end
    return true
end

local function set_previews(on)
    if _G.xivui_dbg then _G.xivui_dbg('menu', 'HUD preview ' .. (on and 'ON — force-enabling components for preview' or 'OFF — restoring disabled components')) end
    _G.XIVUI_FORCING = true
    if on then
        for _, name in ipairs(PREVIEW_COMPONENTS) do
            if not is_enabled(name) and _G.XIVUI_STATE and _G.XIVUI_STATE.set_enabled then
                pcall(_G.XIVUI_STATE.set_enabled, name, true); forced_on[name] = true
            end
            local ok, mod = pcall(require, 'components/' .. name .. '/' .. name)
            if ok and type(mod) == 'table' and mod.hud_preview then pcall(mod.hud_preview, true) end
        end
    else
        for _, name in ipairs(PREVIEW_COMPONENTS) do
            local ok, mod = pcall(require, 'components/' .. name .. '/' .. name)
            if ok and type(mod) == 'table' and mod.hud_preview then pcall(mod.hud_preview, false) end
            if forced_on[name] and _G.XIVUI_STATE and _G.XIVUI_STATE.set_enabled then
                pcall(_G.XIVUI_STATE.set_enabled, name, false); forced_on[name] = nil
            end
        end
    end
    _G.XIVUI_FORCING = false
end

local function clamp_box(b, rx, ry)
    local nx = max(0, min(b.x, rx - b.w))
    local ny = max(0, min(b.y, ry - b.h))
    local moved = nx ~= b.x or ny ~= b.y
    b.x, b.y = nx, ny
    return moved
end

local function snapshot()
    boxes, focus = {}, nil
    local live = ui_bounds.all()
    for _, d in ipairs(DESC) do
        local s  = load_cfg(d.file, d.def)
        local sc = (d.scale and d.scale(s)) or 1
        local lr = live[d.id]
        local b
        if lr then
            b = { x = lr.x, y = lr.y, w = lr.w, h = lr.h, bw = lr.w / sc, bh = lr.h / sc, live = true }
        else
            local px, py = d.pos(s)
            b = { x = px, y = py, w = floor(d.w * sc), h = floor(d.h * sc), bw = d.w, bh = d.h, live = false }
        end
        b.id, b.d, b.scale, b.label = d.id, d, sc, d.label
        boxes[#boxes + 1] = b
    end
    local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
    if ok and hotbar.hud_bars then
        local hb_ok, bars = pcall(hotbar.hud_bars)
        local hsc = (hotbar.hud_get_scale and hotbar.hud_get_scale()) or 1
        if hsc <= 0 then hsc = 1 end
        if hb_ok and type(bars) == 'table' then
            for _, hb in ipairs(bars) do
                if slot_edit and slot_edit.hb == hb.index and hotbar.hud_slot_rects then
                    local sok, slots = pcall(hotbar.hud_slot_rects, hb.index)
                    if sok and type(slots) == 'table' then
                        for _, s in ipairs(slots) do
                            local ssc = s.scale or 1; if ssc <= 0 then ssc = 1 end
                            boxes[#boxes + 1] = { id = 'hotslot:' .. hb.index .. ':' .. s.i,
                                kind = 'hotslot', hb = hb.index, si = s.i,
                                label = (s.i == 1) and ('Bar ' .. hb.index .. ' slots — drag to move, scroll to scale, double-click to rejoin, click empty space to exit') or '',
                                x = s.x, y = s.y, w = s.w, h = s.h, bw = s.w / ssc, bh = s.h / ssc, scale = ssc, live = true }
                        end
                    end
                elseif not hb.hidden then
                    local bsc = hb.scale or 1; if bsc <= 0 then bsc = 1 end
                    boxes[#boxes + 1] = { id = 'hotbar:' .. hb.index, kind = 'hotbar', hb = hb.index,
                        label = 'Hotbar ' .. hb.index, x = hb.x, y = hb.y, w = hb.w, h = hb.h,
                        bw = hb.w / bsc, bh = hb.h / bsc, scale = bsc, live = true }
                end
            end
        end
        local et = hotbar.hud_env_text and hotbar.hud_env_text()
        if et then local esc = et.scale or 1; if esc <= 0 then esc = 1 end
            boxes[#boxes + 1] = { id = 'hotbar_env', kind = 'hotbar_env', label = 'Main/Gen Text',
            x = et.x, y = et.y, w = et.w, h = et.h, bw = et.w / esc, bh = et.h / esc, scale = esc, live = true } end
        local iv = hotbar.hud_inv_text and hotbar.hud_inv_text()
        if iv then local isc = iv.scale or 1; if isc <= 0 then isc = 1 end
            boxes[#boxes + 1] = { id = 'hotbar_inv', kind = 'hotbar_inv', label = 'Inventory Count',
            x = iv.x, y = iv.y, w = iv.w, h = iv.h, bw = iv.w / isc, bh = iv.h / isc, scale = isc, live = true } end
        local sr = hotbar.hud_sets_rect and hotbar.hud_sets_rect()
        if sr then local ssc = sr.scale or 1; if ssc <= 0 then ssc = 1 end
            boxes[#boxes + 1] = { id = 'hotbar_sets', kind = 'hotbar_sets', label = 'Hotbar Sets',
            x = sr.x, y = sr.y, w = sr.w, h = sr.h, bw = sr.w / ssc, bh = sr.h / ssc, scale = ssc, live = sr.visible } end
        local at = hotbar.hud_action_tip_rect and hotbar.hud_action_tip_rect()
        local atsc = (hotbar.hud_get_action_tip_scale and hotbar.hud_get_action_tip_scale()) or 1
        if atsc <= 0 then atsc = 1 end
        if at then boxes[#boxes + 1] = { id = 'hotbar_tip', kind = 'hotbar_tip', label = 'Skill Tooltip',
            x = at.x, y = at.y, w = at.w, h = at.h, bw = at.w / atsc, bh = at.h / atsc, scale = atsc, live = true } end
        local cr = hotbar.hud_choice_rect and hotbar.hud_choice_rect()
        local csc = (cr and cr.scale) or 1; if csc <= 0 then csc = 1 end
        if cr then boxes[#boxes + 1] = { id = 'hotbar_choice', kind = 'hotbar_choice', label = 'Choice Bar',
            x = cr.x, y = cr.y, w = cr.w, h = cr.h, bw = cr.w / csc, bh = cr.h / csc, scale = csc, live = cr.visible ~= false } end
        local ci = hotbar.hud_choice_ind_rect and hotbar.hud_choice_ind_rect()
        local cisc = (ci and ci.scale) or 1; if cisc <= 0 then cisc = 1 end
        if ci then boxes[#boxes + 1] = { id = 'hotbar_choice_ind', kind = 'hotbar_choice_ind', label = 'Choice Mode Text',
            x = ci.x, y = ci.y, w = ci.w, h = ci.h, bw = ci.w / cisc, bh = ci.h / cisc, scale = cisc, live = ci.visible ~= false } end
    end
    local pok, party = pcall(require, 'components/xivparty/xivparty')
    if pok and party.hud_panels then
        local p_ok, panels = pcall(party.hud_panels)
        if p_ok and type(panels) == 'table' then
            for _, pn in ipairs(panels) do
                local psc = pn.scale or 1; if psc <= 0 then psc = 1 end
                boxes[#boxes + 1] = { id = 'party:' .. pn.index, kind = 'party', pi = pn.index, label = pn.label,
                    x = pn.x, y = pn.y, w = floor(pn.w * psc), h = floor(pn.h * psc),
                    bw = pn.w, bh = pn.h, scale = psc, live = pn.visible }
            end
        end
    end
    local rx, ry = screen()
    for _, b in ipairs(boxes) do
        clamp_box(b, rx, ry)
    end
    for _, b in ipairs(boxes) do
        if not moved[b.id] and not scaled[b.id] then
            local c = {}
            for k, v in pairs(b) do c[k] = v end
            orig[b.id] = c
        end
    end
end

function M.open_editor()
    build(); M.open = true
    camera_lock(true)
    orig, moved, scaled = {}, {}, {}
    set_previews(true)
    local hbok, hbmod = pcall(require, 'components/xivhotbar3/xivhotbar3')
    cur_env = hbok and hbmod.hud_env and hbmod.hud_env() or nil
    snapshot()
    resnap_frames = 6
    slider.x, slider.y = slider_load()
    slider.mode = nil
    dim:show(); grid:show(); hint:show(); donebg:show(); donetx:show(); cancelbg:show(); canceltx:show()
end

function M.cancel()
    drag.active = false; drag.dirty = false; nudge_pending = false
    for id in pairs(scaled) do
        local o = orig[id]
        if o then commit_scale(o) end
    end
    for id in pairs(moved) do
        local o = orig[id]
        if o and not scaled[id] then commit(o) end
    end
    for id in pairs(scaled) do
        local o = orig[id]
        if o then commit(o) end
    end
    M.close()
end

function M.close()
    if nudge_pending and focus and boxes[focus] then commit(boxes[focus]) end
    nudge_pending = false
    if drag.active and drag.i and boxes[drag.i] then commit(boxes[drag.i]) end
    M.open = false; drag.active = false; drag.dirty = false; slot_edit = nil
    camera_lock(false)
    local tok, tb = pcall(require, 'components/targetbar/targetbar')
    if tok and tb and tb.hide and tb.show then pcall(tb.hide); pcall(tb.show) end
    set_previews(false)
    if not built then return end
    dim:hide(); grid:hide(); hint:hide(); donebg:hide(); donetx:hide()
    if cancelbg then cancelbg:hide() end
    if canceltx then canceltx:hide() end
    for _, e in pairs(ring)   do e:hide() end
    for _, f in pairs(fills)  do f:hide() end
    for _, l in pairs(labels) do l:hide() end
    for _, p in pairs(prev)   do p:hide() end
    slider.mode = nil
    for _, e in pairs({ sl_head, sl_track, sl_fill, sl_knob, sl_lab, sl_val }) do if e then e:hide() end end
    for _, e in pairs(sl_notch)     do e:hide() end
    for _, e in pairs(sl_notch_lab) do e:hide() end
end

function M.toggle() if M.open then M.close() else M.open_editor() end end

local function preview_rects(b)
    if b.kind == 'hotbar' then
        local n = max(1, floor(b.w / max(1, b.h)))
        local gap, out = 2, {}
        local sw = (b.w - gap * (n + 1)) / n
        for i = 1, n do out[#out + 1] = { x = b.x + gap + (i - 1) * (sw + gap), y = b.y + gap, w = sw, h = b.h - gap * 2 } end
        return out
    end
    if b.kind == 'party' then
        local out = {}
        for i = 0, 4 do out[#out + 1] = { x = b.x + b.w * 0.04, y = b.y + b.h * (0.06 + i * 0.18), w = b.w * 0.92, h = b.h * 0.1 } end
        return out
    end
    local pv = PV[b.id]
    if not pv then return nil end
    local out = {}
    for _, r in ipairs(pv) do
        out[#out + 1] = { x = b.x + r[1] * b.w, y = b.y + r[2] * b.h, w = r[3] * b.w, h = r[4] * b.h }
    end
    return out
end

local function put(t, s, x, y) t.v = s; t:pos(x, y); t:show() end

function M.render()
    if not M.open then return end
    _G.XIVUI_HUD_PREVIEW = true
    if resnap_frames > 0 then
        resnap_frames = resnap_frames - 1
        if resnap_frames == 0 and not drag.active then snapshot() end
    end
    if not drag.active then
        local hbok, hbmod = pcall(require, 'components/xivhotbar3/xivhotbar3')
        local e = hbok and hbmod.hud_env and hbmod.hud_env()
        if e and e ~= cur_env then cur_env = e; snapshot() end
    end
    if drag.active and drag.dirty and boxes[drag.i] then
        live_move(boxes[drag.i]); drag.dirty = false
    end
    local rx, ry = screen()
    dim:pos(0, 0); dim:size(rx, ry); dim:show()
    grid:pos(0, 0); grid:size(rx, ry); grid:show()
    local envlbl = (cur_env == 'field') and 'GENERAL (out of combat)' or 'MAIN (combat)'
    put(hint, 'HUD LAYOUT   showing ' .. envlbl .. '  ·  press \\ to switch Main/General  ·  drag to move  ·  scroll to scale  ·  double-click a bar = move single slots', 6, 2)

    local dw, dh = 118, 28
    done_rect = { x = rx - dw - 12, y = 4, w = dw, h = dh }
    donebg:pos(done_rect.x, done_rect.y); donebg:size(dw, dh); donebg:show()
    donetx.v = 'Save & Close'
    local tw, th = 0, 0
    pcall(function() tw, th = donetx:extents() end)
    if not tw or tw <= 0 then tw, th = 78, 15 end
    donetx:pos(floor(done_rect.x + (dw - tw) / 2), floor(done_rect.y + (dh - th) / 2))
    donetx:show()

    local cw2 = 86
    done_rect2 = { x = done_rect.x - cw2 - 8, y = 4, w = cw2, h = dh }
    cancelbg:pos(done_rect2.x, done_rect2.y); cancelbg:size(cw2, dh); cancelbg:show()
    canceltx.v = 'Cancel'
    local ctw, cth = 0, 0
    pcall(function() ctw, cth = canceltx:extents() end)
    if not ctw or ctw <= 0 then ctw, cth = 42, 15 end
    canceltx:pos(floor(done_rect2.x + (cw2 - ctw) / 2), floor(done_rect2.y + (dh - cth) / 2))
    canceltx:show()

    do
        local live = ui_bounds.all()
        for i, b in ipairs(boxes) do
            local lr = b.live and live[b.id]
            if lr and not (drag.active and drag.i == i) then
                b.x, b.y, b.w, b.h = lr.x, lr.y, lr.w, lr.h
            end
        end
    end

    for i, b in ipairs(boxes) do
        local f = fills[i]; if not f then f = mkimg(); fills[i] = f end
        local l = labels[i]; if not l then l = mktxt(12); labels[i] = l end
        local foc = (focus == i)
        if foc then f:color(255, 175, 70); f:alpha(64)
        elseif b.live then f:color(120, 170, 255); f:alpha(40)
        else f:color(150, 150, 160); f:alpha(26) end
        f:pos(b.x, b.y); f:size(b.w, b.h); f:show()
        local tag = b.live and '' or '  \\cs(150,150,160)(hidden)\\cr'
        l:color(255, 255, 255); l:alpha(b.live and 255 or 175)
        local ly = (b.y >= 16) and (b.y - 13) or (b.y + b.h + 1)
        put(l, (b.label or b.id) .. tag, b.x + 2, ly)
    end
    for i = #boxes + 1, #fills  do fills[i]:hide() end
    for i = #boxes + 1, #labels do labels[i]:hide() end

    local pc = 0
    for _, b in ipairs(boxes) do
        if not b.live or b.kind == 'party' then
            local rs = preview_rects(b)
            if rs then
                local a = (b.kind == 'party') and 30 or 90
                for _, r in ipairs(rs) do
                    pc = pc + 1
                    local pi = prev[pc]; if not pi then pi = mkimg(210, 215, 230, a); prev[pc] = pi end
                    pi:color(210, 215, 230); pi:alpha(a)
                    pi:pos(floor(r.x), floor(r.y)); pi:size(max(1, floor(r.w)), max(1, floor(r.h))); pi:show()
                end
            end
        end
    end
    for i = pc + 1, #prev do prev[i]:hide() end

    if focus and boxes[focus] then
        local b = boxes[focus]; local t = 2
        local x, y, w, h = b.x + 2, b.y + 2, b.w - 4, b.h - 4
        ring[1]:pos(x, y);         ring[1]:size(w, t); ring[1]:show()
        ring[2]:pos(x, y + h - t); ring[2]:size(w, t); ring[2]:show()
        ring[3]:pos(x, y);         ring[3]:size(t, h); ring[3]:show()
        ring[4]:pos(x + w - t, y); ring[4]:size(t, h); ring[4]:show()
    else
        for _, e in pairs(ring) do e:hide() end
    end

    do
        local hbok, hb = pcall(require, 'components/xivhotbar3/xivhotbar3')
        local sc = (hbok and hb.hud_get_scale and hb.hud_get_scale()) or 1
        if sc < SL_MIN then sc = SL_MIN elseif sc > SL_MAX then sc = SL_MAX end
        local H = floor(min(ry * 0.42, 300))
        local headh = 18
        local sx = (slider.x and slider.x >= 0) and slider.x or (rx - SL_PW - 12)
        local sy = (slider.y and slider.y >= 0) and slider.y or floor(ry * 0.22)
        sx = max(0, min(sx, rx - SL_PW))
        sy = max(0, min(sy, ry - (H + headh + 30)))
        slider.x, slider.y = sx, sy
        local cx = sx + floor(SL_PW / 2)
        local ytop = sy + headh + 6
        local ybot = ytop + H
        slider.cx, slider.ytop, slider.h = cx, ytop, H
        local tw, kw, kh = 8, 28, 12
        local frac = (sc - SL_MIN) / (SL_MAX - SL_MIN)
        local ky = floor(ybot - frac * H)
        slider.head  = { x = sx, y = sy, w = SL_PW, h = headh }
        slider.knob  = { x = floor(cx - kw / 2), y = floor(ky - kh / 2), w = kw, h = kh }
        slider.track = { x = sx, y = floor(ytop - kh / 2), w = SL_PW, h = H + kh }
        sl_head:color(slider.mode == 'move' and 70 or 44, slider.mode == 'move' and 80 or 48, slider.mode == 'move' and 102 or 60)
        sl_head:pos(sx, sy); sl_head:size(SL_PW, headh); sl_head:show()
        put(sl_lab, 'All Hotbars', sx + 6, sy + 2)
        sl_track:pos(floor(cx - tw / 2), ytop); sl_track:size(tw, H); sl_track:show()
        sl_fill:pos(floor(cx - tw / 2), ky); sl_fill:size(tw, max(1, ybot - ky)); sl_fill:show()
        local ni, v = 0, SL_MIN
        while v <= SL_MAX + 1e-6 do
            ni = ni + 1
            local ny = floor(ybot - ((v - SL_MIN) / (SL_MAX - SL_MIN)) * H)
            local major = math.abs(v * 2 - floor(v * 2 + 0.5)) < 1e-6
            local nimg = sl_notch[ni]; if not nimg then nimg = mkimg(200, 205, 220, 200); sl_notch[ni] = nimg end
            nimg:color(200, 205, 220); nimg:alpha(major and 220 or 150)
            nimg:pos(floor(cx + tw / 2 + 2), ny); nimg:size(major and 9 or 5, major and 2 or 1); nimg:show()
            local lab = sl_notch_lab[ni]
            if major then
                if not lab then lab = mktxt(10); sl_notch_lab[ni] = lab end
                put(lab, string.format('%.1f', v), sx - 4, ny - 7)
            elseif lab then lab:hide() end
            v = v + 0.25
        end
        for j = ni + 1, #sl_notch do sl_notch[j]:hide() end
        for j = ni + 1, #sl_notch_lab do if sl_notch_lab[j] then sl_notch_lab[j]:hide() end end
        sl_knob:color(slider.mode == 'scale' and 255 or 235, slider.mode == 'scale' and 215 or 200, slider.mode == 'scale' and 90 or 110)
        sl_knob:pos(slider.knob.x, slider.knob.y); sl_knob:size(kw, kh); sl_knob:show()
        put(sl_val, string.format('%.2fx', sc), cx - 14, ybot + 5)
    end
end

local function in_rect(x, y, r) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end
local function box_at(x, y)
    local hidden_hit = nil
    for i = #boxes, 1, -1 do
        local b = boxes[i]
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if b.live then return i end
            if not hidden_hit then hidden_hit = i end
        end
    end
    return hidden_hit
end
function live_move(b)
    if b.kind == 'hotbar' or b.kind == 'hotbar_env' or b.kind == 'hotbar_inv' or b.kind == 'hotbar_sets'
       or b.kind == 'hotbar_choice' or b.kind == 'hotbar_choice_ind' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if not ok then return false end
        if b.kind == 'hotbar' and hotbar.hud_move_bar_live then pcall(hotbar.hud_move_bar_live, b.hb, b.x, b.y)
        elseif b.kind == 'hotbar_env' and hotbar.hud_move_env_text_live then pcall(hotbar.hud_move_env_text_live, b.x, b.y)
        elseif b.kind == 'hotbar_inv' and hotbar.hud_move_inv_text_live then pcall(hotbar.hud_move_inv_text_live, b.x, b.y)
        elseif b.kind == 'hotbar_sets' and hotbar.hud_move_sets_live then pcall(hotbar.hud_move_sets_live, b.x, b.y)
        elseif b.kind == 'hotbar_choice' and hotbar.hud_move_choice_live then pcall(hotbar.hud_move_choice_live, b.x, b.y)
        elseif b.kind == 'hotbar_choice_ind' and hotbar.hud_move_choice_ind_live then pcall(hotbar.hud_move_choice_ind_live, b.x, b.y) end
        return true
    end
    if b.kind == 'hotslot' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_move_slot_live then pcall(hotbar.hud_move_slot_live, b.hb, b.si, b.x, b.y) end
        return true
    end
    return false
end

function commit(b)
    moved[b.id] = true
    if b.kind == 'hotbar' or b.kind == 'hotbar_env' or b.kind == 'hotbar_inv' or b.kind == 'hotbar_sets' or b.kind == 'hotbar_tip'
       or b.kind == 'hotbar_choice' or b.kind == 'hotbar_choice_ind' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok then
            if b.kind == 'hotbar' and hotbar.hud_move_bar then pcall(hotbar.hud_move_bar, b.hb, b.x, b.y)
            elseif b.kind == 'hotbar_env' and hotbar.hud_move_env_text then pcall(hotbar.hud_move_env_text, b.x, b.y)
            elseif b.kind == 'hotbar_inv' and hotbar.hud_move_inv_text then pcall(hotbar.hud_move_inv_text, b.x, b.y)
            elseif b.kind == 'hotbar_sets' and hotbar.hud_move_sets then pcall(hotbar.hud_move_sets, b.x, b.y)
            elseif b.kind == 'hotbar_tip' and hotbar.hud_move_action_tip then pcall(hotbar.hud_move_action_tip, b.x, b.y)
            elseif b.kind == 'hotbar_choice' and hotbar.hud_move_choice then pcall(hotbar.hud_move_choice, b.x, b.y)
            elseif b.kind == 'hotbar_choice_ind' and hotbar.hud_move_choice_ind then pcall(hotbar.hud_move_choice_ind, b.x, b.y) end
        end
        return
    end
    if b.kind == 'hotslot' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_move_slot then pcall(hotbar.hud_move_slot, b.hb, b.si, b.x, b.y) end
        return
    end
    if b.kind == 'party' then
        local ok, party = pcall(require, 'components/xivparty/xivparty')
        if ok and party.hud_move_panel then pcall(party.hud_move_panel, b.pi, b.x, b.y) end
        return
    end
    if b.d and b.d.setpos then pcall(b.d.setpos, b) end
    if b.d and b.d.setscale and drag.scaled then pcall(b.d.setscale, b) end
end

function commit_scale(b)
    scaled[b.id] = true
    if b.kind == 'hotbar' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_bar_scale then pcall(hotbar.hud_set_bar_scale, b.hb, b.scale) end
    elseif b.kind == 'hotslot' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_slot_scale then pcall(hotbar.hud_set_slot_scale, b.hb, b.si, b.scale) end
    elseif b.kind == 'hotbar_all' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_scale then pcall(hotbar.hud_set_scale, b.scale) end
    elseif b.kind == 'hotbar_env' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_env_text_scale then pcall(hotbar.hud_set_env_text_scale, b.scale) end
    elseif b.kind == 'hotbar_inv' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_inv_text_scale then pcall(hotbar.hud_set_inv_text_scale, b.scale) end
    elseif b.kind == 'hotbar_sets' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_sets_scale then pcall(hotbar.hud_set_sets_scale, b.scale) end
    elseif b.kind == 'hotbar_tip' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_action_tip_scale then pcall(hotbar.hud_set_action_tip_scale, b.scale) end
    elseif b.kind == 'hotbar_choice' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_choice_scale then pcall(hotbar.hud_set_choice_scale, b.scale) end
    elseif b.kind == 'hotbar_choice_ind' then
        local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
        if ok and hotbar.hud_set_choice_ind_scale then pcall(hotbar.hud_set_choice_ind_scale, b.scale) end
    elseif b.kind == 'party' then
        local ok, party = pcall(require, 'components/xivparty/xivparty')
        if ok and party.hud_set_panel_scale then pcall(party.hud_set_panel_scale, b.pi, b.scale) end
    elseif b.d and b.d.setscale then
        pcall(b.d.setscale, b)
        if not b.d.scale_keeps_pos then pcall(b.d.setpos, b) end
    end
end

local applied_names = nil
local default_tries = 0
local maybe_tick = 0
local MARKER = windower.addon_path .. 'data/xivuimenu/hud_defaults.lua'

local function load_marker()
    if applied_names then return applied_names end
    applied_names = {}
    local chunk = loadfile(MARKER)
    if chunk then
        local ok, t = pcall(chunk)
        if ok and type(t) == 'table' then
            for _, n in ipairs(t) do applied_names[n] = true end
        end
    end
    return applied_names
end

local function mark_applied(name)
    if not name or name == '' then return end
    load_marker()
    if applied_names[name] then return end
    applied_names[name] = true
    if windower.create_dir then pcall(windower.create_dir, windower.addon_path .. 'data/xivuimenu') end
    local f = io.open(MARKER, 'w')
    if not f then return end
    f:write('-- characters whose first-run default HUD layout has been applied. Auto-written.\nreturn {\n')
    local names = {}
    for n in pairs(applied_names) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do f:write(string.format('  %q,\n', n)) end
    f:write('}\n')
    f:close()
end

function M.apply_default_layout()
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return false end
    snapshot()
    if #boxes == 0 then return false end
    local rx, ry = screen()
    local by_id, bars = {}, {}
    for _, b in ipairs(boxes) do
        by_id[b.id] = b
        if b.kind == 'hotbar' then bars[#bars + 1] = b end
    end
    table.sort(bars, function(a, b2) return a.hb < b2.hb end)

    local function place(b, x, y)
        if not b then return end
        b.x, b.y = floor(x), floor(y)
        clamp_box(b, rx, ry)
        commit(b)
    end
    local function center_x(b) return (rx - b.w) / 2 end
    local gap = max(6, floor(ry * 0.006))

    local cur = ry - floor(ry * 0.015)
    local sb = by_id.statusbar
    if sb then cur = cur - sb.h; place(sb, center_x(sb), cur); cur = cur - gap end
    local xp = by_id.expbar
    if xp then cur = cur - xp.h; place(xp, center_x(xp), cur); cur = cur - gap end
    local first_bar = nil
    for _, hb in ipairs(bars) do
        cur = cur - hb.h
        place(hb, center_x(hb), cur)
        first_bar = first_bar or hb
        cur = cur - gap
    end
    if first_bar then
        local et = by_id.hotbar_env
        if et then place(et, first_bar.x + first_bar.w + 14, first_bar.y) end
        local iv = by_id.hotbar_inv
        if iv then place(iv, first_bar.x + first_bar.w + 14, first_bar.y + 20) end
    end
    local cb = by_id.castbar
    if cb then place(cb, center_x(cb), cur - cb.h - floor(ry * 0.02)) end
    local sw = by_id.castbar_swing
    if sw then place(sw, center_x(sw), cb and (cb.y + cb.h + 6) or (cur - sw.h - floor(ry * 0.02))) end

    local tb = by_id.targetbar
    if tb then place(tb, center_x(tb), floor(ry * 0.03)) end

    local lx = floor(rx * 0.008)
    local mainp, a1, a2, pets = by_id['party:0'], by_id['party:1'], by_id['party:2'], by_id['party:3']
    if a1 then place(a1, lx, floor(ry * 0.05)) end
    if a2 then place(a2, lx + ((a1 and a1.w) or 0) + floor(rx * 0.008), floor(ry * 0.05)) end
    local ly = floor(ry * 0.30)
    if mainp then place(mainp, lx, ly); ly = ly + mainp.h + floor(ry * 0.015) end
    if pets then place(pets, lx, ly); ly = ly + pets.h + floor(ry * 0.015) end
    local ag = by_id.aggrolist
    if ag then place(ag, lx, ly) end

    local dp = by_id.dps
    if dp then place(dp, rx - dp.w - floor(rx * 0.008), floor(ry * 0.35)) end
    local nt = by_id.notification
    if nt then place(nt, floor(rx * 0.60), floor(ry * 0.52)) end
    local rq = by_id.requestwindow
    if rq then place(rq, rx - rq.w - floor(rx * 0.008), floor(ry * 0.82)) end

    local p = windower.ffxi.get_player()
    if p and p.name then mark_applied(p.name) end
    return true
end

function M.maybe_apply_defaults()
    if M.open then return end
    maybe_tick = (maybe_tick + 1) % 20
    if maybe_tick ~= 0 then return end
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return end
    local p = windower.ffxi.get_player()
    if not p or not p.name or p.name == '' then return end
    if load_marker()[p.name] then return end
    local f = io.open(windower.addon_path .. 'components/xivhotbar3/data/' .. p.name .. '/hotbar_global.lua', 'r')
    if f then f:close(); mark_applied(p.name); return end
    default_tries = default_tries + 1
    local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
    local bars_ready = false
    if ok and hotbar.hud_bars then
        local hb_ok, hb = pcall(hotbar.hud_bars)
        bars_ready = hb_ok and type(hb) == 'table' and #hb > 0
    end
    if not bars_ready and default_tries < 900 then return end
    if M.apply_default_layout() then
        windower.add_to_chat(207, 'XivUI: applied the default HUD layout. Use HUD LAYOUT in the menu (//xui menu) to customize it.')
    end
    mark_applied(p.name)
end

local ARROW = { [203] = { -1, 0 }, [205] = { 1, 0 }, [200] = { 0, -1 }, [208] = { 0, 1 } }
function M.on_keyboard(key, down)
    if not M.open then return false end
    local d = ARROW[key]
    if not d then return false end
    local b = focus and boxes[focus]
    if not b or b.native then return false end
    if not down then
        if nudge_pending then nudge_pending = false; commit(b) end
        return true
    end
    b.x = b.x + d[1]; b.y = b.y + d[2]
    clamp_box(b, screen())
    if live_move(b) then nudge_pending = true
    else commit(b) end
    return true
end

function M.on_mouse(mtype, x, y, delta)
    if not M.open then return false end

    if slider.mode then
        if mtype == 0 then
            if slider.mode == 'scale' then
                slider_set_from_y(y, false)
            else
                slider.x = x - slider.dx; slider.y = y - slider.dy
                local rx, ry = screen()
                slider.x = max(0, min(slider.x, rx - SL_PW))
                slider.y = max(0, min(slider.y, ry - 40))
            end
        elseif mtype == 2 then
            if slider.mode == 'scale' then slider_set_from_y(y, true)
            else slider_save(slider.x, slider.y) end
            slider.mode = nil
        end
        return true
    end

    if drag.active then
        if mtype == 0 then
            local b = boxes[drag.i]
            if b then
                b.x = x - drag.dx; b.y = y - drag.dy
                local rx, ry = screen()
                clamp_box(b, rx, ry)
                drag.dirty = true
            end
        elseif mtype == 2 then
            local b = boxes[drag.i]
            if b then commit(b) end
            drag.active = false; drag.dirty = false
        end
        return true
    end

    if mtype == 1 then
        if in_rect(x, y, done_rect) then M.close(); return true end
        if in_rect(x, y, done_rect2) then M.cancel(); return true end
        if in_rect(x, y, slider.head) then
            slider.mode = 'move'; slider.dx = x - slider.x; slider.dy = y - slider.y; focus = nil
            return true
        end
        if in_rect(x, y, slider.knob) or in_rect(x, y, slider.track) then
            slider.mode = 'scale'; focus = nil; slider_set_from_y(y, false)
            return true
        end
        local i = box_at(x, y)
        if i then
            local b = boxes[i]
            local now = os.clock()
            if last_box_click.id == b.id and (now - last_box_click.t) < 0.4 then
                last_box_click = { id = nil, t = 0 }
                if b.kind == 'hotbar' then
                    slot_edit = { hb = b.hb }; focus = nil; snapshot(); return true
                elseif b.kind == 'hotslot' then
                    local ok, hotbar = pcall(require, 'components/xivhotbar3/xivhotbar3')
                    if ok and hotbar.hud_reset_slot then pcall(hotbar.hud_reset_slot, b.hb, b.si) end
                    focus = nil; snapshot(); return true
                end
            end
            last_box_click = { id = b.id, t = now }
            focus = i
            if not b.native then
                drag.active, drag.i, drag.dx, drag.dy, drag.scaled = true, i, x - b.x, y - b.y, false
            end
        else
            focus = nil
            if slot_edit then slot_edit = nil; snapshot() end
        end
        return true
    end

    if mtype == 10 and focus and boxes[focus] and not boxes[focus].native then
        local b = boxes[focus]
        b.scale = max(0.5, min(2.5, b.scale + (delta > 0 and 0.05 or -0.05)))
        b.w, b.h = floor(b.bw * b.scale), floor(b.bh * b.scale)
        commit_scale(b)
        return true
    end

    return true
end

local LAYOUT_DIR  = windower.addon_path .. 'components/xivuimenu/hud_layout'
local LAYOUT_FILE = LAYOUT_DIR .. '/hud_layout.lua'

local function hb_module()
    local ok, hb = pcall(require, 'components/xivhotbar3/xivhotbar3')
    if ok then return hb end
    return nil
end

local function xp_module()
    local ok, xp = pcall(require, 'components/xivparty/xivparty')
    if ok then return xp end
    return nil
end

local HB_SUB = {
    { 'hotbar_sets',       'hud_sets_rect',       'hud_move_sets',       'hud_set_sets_scale' },
    { 'hotbar_env',        'hud_env_text',        'hud_move_env_text',   'hud_set_env_text_scale' },
    { 'hotbar_inv',        'hud_inv_text',        'hud_move_inv_text',   'hud_set_inv_text_scale' },
    { 'hotbar_choice',     'hud_choice_rect',     'hud_move_choice',     'hud_set_choice_scale' },
    { 'hotbar_choice_ind', 'hud_choice_ind_rect', 'hud_move_choice_ind', 'hud_set_choice_ind_scale', 'hud_get_choice_ind_scale' },
    { 'hotbar_tip',        'hud_action_tip_rect', 'hud_move_action_tip', 'hud_set_action_tip_scale', 'hud_get_action_tip_scale' },
}

function M.capture_layout()
    local rx, ry = screen()
    if not rx or rx <= 0 or not ry or ry <= 0 then return nil end
    local out = { res = { x = rx, y = ry } }
    for _, d in ipairs(DESC) do
        local s = load_cfg(d.file, d.def)
        local x, y = d.pos(s)
        if x and y then
            local e = { fx = x / rx, fy = y / ry }
            if d.scale then e.sc = d.scale(s) end
            out[d.id] = e
        end
    end
    local hb = hb_module()
    if hb then
        if hb.hud_get_scale then
            local ok, g = pcall(hb.hud_get_scale)
            if ok and g then out['hotbar_global'] = { sc = g } end
        end
        if hb.hud_bars then
            local bok, bars = pcall(hb.hud_bars)
            if bok and type(bars) == 'table' then
                for _, b in ipairs(bars) do
                    if b.x and b.y then out['hotbar:' .. b.index] = { fx = b.x / rx, fy = b.y / ry, sc = b.scale } end
                end
            end
        end
        for _, e in ipairs(HB_SUB) do
            local rectfn = hb[e[2]]
            if rectfn then
                local ok, r = pcall(rectfn)
                if ok and type(r) == 'table' and r.x then
                    local sc = r.scale
                    if sc == nil and e[5] and hb[e[5]] then local ok2, g = pcall(hb[e[5]]); if ok2 then sc = g end end
                    out[e[1]] = { fx = r.x / rx, fy = r.y / ry, sc = sc }
                end
            end
        end
    end
    local xp = xp_module()
    if xp and xp.hud_panels then
        local ok, panels = pcall(xp.hud_panels)
        if ok and type(panels) == 'table' then
            for _, p in ipairs(panels) do
                if p.x and p.y then out['xivparty:' .. p.index] = { fx = p.x / rx, fy = p.y / ry, sc = p.scale } end
            end
        end
    end
    return out
end

function M.apply_layout(data)
    if type(data) ~= 'table' then return false end
    local rx, ry = screen()
    if not rx or rx <= 0 or not ry or ry <= 0 then return false end
    local cap_rx = (data.res and tonumber(data.res.x)) or rx
    if not cap_rx or cap_rx <= 0 then cap_rx = rx end
    local ratio = rx / cap_rx
    if _G.xivui_dbg then _G.xivui_dbg('menu', ('apply_layout: this res %dx%d, captured at %d, scale ratio %.3f'):format(rx, ry, cap_rx, ratio)) end
    for _, d in ipairs(DESC) do
        local f = data[d.id]
        if f and f.fx then
            if f.sc and d.setscale then d.setscale({ scale = f.sc * ratio }) end
            d.setpos({ x = floor(f.fx * rx), y = floor(f.fy * ry), w = d.w, scale = (f.sc or 1) * ratio })
        end
    end
    local hb = hb_module()
    if hb then
        local g = data['hotbar_global']
        if g and g.sc and hb.hud_set_scale then pcall(hb.hud_set_scale, g.sc * ratio) end
        if hb.hud_bars and hb.hud_move_bar then
            if hb.hud_default_apply then pcall(hb.hud_default_apply, true) end
            local bok, bars = pcall(hb.hud_bars)
            if bok and type(bars) == 'table' then
                for _, b in ipairs(bars) do
                    local f = data['hotbar:' .. b.index]
                    if f and f.fx then
                        if f.sc and hb.hud_set_bar_scale then pcall(hb.hud_set_bar_scale, b.index, f.sc) end
                        pcall(hb.hud_move_bar, b.index, floor(f.fx * rx), floor(f.fy * ry))
                    end
                end
            end
            if hb.hud_default_apply then pcall(hb.hud_default_apply, false) end
        end
        for _, e in ipairs(HB_SUB) do
            local f = data[e[1]]
            if f and f.fx then
                if f.sc and hb[e[4]] then pcall(hb[e[4]], f.sc * ratio) end
                if hb[e[3]] then pcall(hb[e[3]], floor(f.fx * rx), floor(f.fy * ry)) end
            end
        end
    end
    local xp = xp_module()
    if xp and xp.hud_move_panel then
        for i = 0, 3 do
            local f = data['xivparty:' .. i]
            if f and f.fx then pcall(xp.hud_move_panel, i, floor(f.fx * rx), floor(f.fy * ry)) end
        end
    end
    return true
end

local function serialize_layout(t)
    local lines = { 'return {' }
    if t.res then lines[#lines + 1] = string.format('  res = { x = %d, y = %d },', t.res.x or 0, t.res.y or 0) end
    local ids = {}
    for id, f in pairs(t) do if id ~= 'res' and type(f) == 'table' then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local f = t[id]
        local parts = {}
        if f.fx then parts[#parts + 1] = string.format('fx = %.6f, fy = %.6f', f.fx, f.fy) end
        if f.sc then parts[#parts + 1] = string.format('sc = %.4f', f.sc) end
        lines[#lines + 1] = string.format('  [%q] = { %s },', id, table.concat(parts, ', '))
    end
    lines[#lines + 1] = '}'
    return table.concat(lines, '\n') .. '\n'
end

function M.save_defaults()
    local data = M.capture_layout()
    if not data then return false end
    if windower.create_dir then pcall(windower.create_dir, LAYOUT_DIR) end
    local f = io.open(LAYOUT_FILE, 'w')
    if not f then return false end
    f:write(serialize_layout(data)); f:close()
    return true, data.res
end

function M.load_defaults()
    local chunk = loadfile(LAYOUT_FILE)
    if not chunk then return nil end
    local ok, t = pcall(chunk)
    if ok and type(t) == 'table' then return t end
    return nil
end

function M.apply_saved_defaults()
    local d = M.load_defaults()
    if not d then return false, 'no saved layout (run "savedefaults" first)' end
    return M.apply_layout(d)
end

return M
