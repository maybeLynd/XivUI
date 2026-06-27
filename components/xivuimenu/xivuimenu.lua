-- xivuimenu: FFXIV "Actions & Traits" styled palette: browse every spell / job ability / weaponskill (unavailable ones greyed), drag learned actions onto the hotbar, build custom macros, and pick icons visually.
-- XivUI component. Maintainer: maybeLynd. Version: 0.1.0.

local config    = require('config')
local res       = require('resources')
local defaults  = require('components/xivuimenu/defaults')
local ui_bounds = require('lib/ui_bounds')
local draggable = require('lib/draggable')
local catalog   = require('components/xivuimenu/catalog')
local iconpicker = require('components/xivuimenu/iconpicker')
local action_tooltip = require('lib/action_tooltip')
local formatter      = require('components/xivhotbar3/lib/text_formatter')
local database       = require('components/xivhotbar3/priv_res/database')
local occlusion      = require('lib/occlusion')
local hotbar         = require('components/xivhotbar3/xivhotbar3')
local recast_cache   = require('components/xivhotbar3/lib/recast_cache')
local glyph_width    = require('components/xivuimenu/glyph')
local build_config_cats = require('components/xivuimenu/config_cats')

local xivuimenu = {}
local function build()

local MD = require('components/xivuimenu/menudata')

local ART      = (function()
    local base = windower.addon_path .. 'assets/components/xivuimenu/'
    local theme = _G.XIVUI_THEME or 'ffxiv'
    if theme and theme ~= 'ffxiv' then
        local tp = base .. 'themes/' .. theme .. '/'
        local f = io.open(tp .. 'window.png', 'r')
        if f then f:close(); return tp end
    end
    return base
end)()
local ART_JOBS = windower.addon_path .. 'assets/components/xivuimenu/jobs/'

local C = {
    cr            = '\\cr',
    gray          = '\\cs(156,155,145)',
    title         = '\\cs(200,200,200)',
    level         = '\\cs(244,223,179)',
    job           = '\\cs(251,217,150)',
    rail          = '\\cs(251,217,150)',
    banner        = '\\cs(227,208,166)',
    sub           = '\\cs(199,199,199)',
    name          = '\\cs(243,222,179)',
    lv            = '\\cs(184,169,139)',
    value         = '\\cs(227,208,166)',
    card_name_on  = '\\cs(227,208,166)',
    card_name_off = '\\cs(112,112,112)',
    card_lv_on    = '\\cs(190,178,150)',
    card_lv_off   = '\\cs(94,94,94)',
    section       = '\\cs(227,208,166)',
    chip_off      = '\\cs(178,178,180)',
    placeholder   = '\\cs(120,120,120)',
    hint          = '\\cs(120,120,128)',
    desc          = '\\cs(140,140,150)',
    pick_on       = '\\cs(216,216,216)',
    pick_lv       = '\\cs(140,140,140)',
}
C._def = {}; for k, v in pairs(C) do C._def[k] = v end
C._ffxipal = {
    gray='\\cs(150,162,186)', title='\\cs(196,210,238)', level='\\cs(212,220,236)', job='\\cs(230,234,244)',
    rail='\\cs(188,206,240)', banner='\\cs(188,206,240)', sub='\\cs(150,162,186)', name='\\cs(212,220,236)',
    lv='\\cs(150,162,186)', value='\\cs(206,216,236)', card_name_on='\\cs(206,216,236)', card_name_off='\\cs(100,108,124)',
    card_lv_on='\\cs(150,162,186)', card_lv_off='\\cs(80,86,100)', section='\\cs(188,206,240)', chip_off='\\cs(150,160,182)',
    placeholder='\\cs(104,112,132)', hint='\\cs(110,120,144)', desc='\\cs(134,144,168)', pick_on='\\cs(206,216,236)',
    pick_lv='\\cs(130,140,164)',
}
C.swap = function(id)
    for k, v in pairs(C._def) do C[k] = v end
    C._ffxi = false
    if id == 'ffxi' then
        for k, v in pairs(C._ffxipal) do C[k] = v end
        C._ffxi = true
    end
end
C.swap(_G.XIVUI_THEME or 'ffxiv')

local W, H = 840, 496
local D = {
    title_h = 32, rail_w = 140, margin = 14,
    content_r = 24,
    banner_h = 40,
    pool_rows = 6, card_h = 52, card_gap = 8, col_gap = 10, header_h = 24, section_gap = 8,
    cursor_w = 16, cursor_h = 8, cursor_hx = 14, cursor_hy = 3,
    grab_w = 8, grab_h = 8, grab_hx = 5, grab_hy = 4,
    _ms = 1, _texts = {},
    _scale_fields = { 'title_h','rail_w','margin','content_r','banner_h','card_h','card_gap','col_gap',
                      'header_h','section_gap','cursor_w','cursor_h','cursor_hx','cursor_hy',
                      'grab_w','grab_h','grab_hx','grab_hy' },
}

local settings
local ready = false
local open  = false
local shown = true

local panel_bg, banner_bg, scroll_thumb, mj_icon, sj_icon, rail_hl_sel, rail_hl_hover
local title_t, close_t, banner_t, subtitle_t, hint_t, wip_t
local lvl_t, job_t, slvl_t, sjob_t
local rail_texts = {}
local cur_mj_path, cur_sj_path
local drag_state = { dragging = false }
local panel_rect, title_rect, close_rect

local rail_items    = {
    { key = 'actions', label = 'ACTIONS' },
    { key = 'macros',  label = 'MACROS' },
    { key = 'choice',  label = 'CHOICE' },
    { key = 'autogen', label = 'AUTOGEN' },
    { key = 'config',  label = 'CONFIG' },
    { key = 'hudlayout', label = 'HUD LAYOUT' },
}
local selected_rail = 'actions'
local hovered_rail  = nil
local rail_rects    = {}

local cards        = {}
local headers      = {}
local cat          = {}
local groups       = {}
local collapsed    = {}
for k, v in pairs(catalog.DEFAULT_COLLAPSED or { Trusts = true }) do collapsed[k] = v end
local cat_sig      = nil
local scroll_y     = 0
local content_total = 0
local hovered_card = nil
local card_rects   = {}
local header_rects = {}
local tip, tip_entry
local tip_info, tip_px, tip_py
local tip_refresh = 0
local cursor_img
local grab_img
local mouse_down = false

local drag = { active = false, entry = nil, row = nil, slot = nil, holding = false,
               bar = { vis = false, dragging = false } }
drag.cam = function(on)
    if _G.XIVUI_STATE and _G.XIVUI_STATE.hud_camera_lock then
        _G.XIVUI_STATE.hud_camera_lock(on and true or false)
    end
end
local drag_icon

local picker = { open = false, key = nil, entry = nil, scroll = 0, total = 0, collapsed = {} }
local pick_bg, pick_title_t, pick_close_t, pick_hl
local pick_thumbs  = {}
local pick_thumb_cur = {}
local pick_headers = {}
local pick_rects   = {}
local pick_hdr_rects = {}
local pick_rect, pick_close_rect
local hovered_thumb
local last_icon_click = { t = 0, key = nil }
local redraw_count = 0

local macro = { kind = 'ja', target = 'me', action = '', alias = '', cmd = '', body = '',
                icon = nil, icon_abs = nil, scroll = 0, total = 0, bodyscroll = 0 }
local macro_more   = false
local IMPORT_FILE  = windower.addon_path .. 'data/xivuimenu/import.txt'
do local i = IMPORT_FILE:lower():find('addons'); macro.file = i and IMPORT_FILE:sub(i) or IMPORT_FILE end
local import_poll  = 0
local import_last  = nil
local macro_chips  = {}
local macro_texts  = {}
local macro_icon_img, macro_out_img, macro_body_thumb
local macro_rects  = {}
local macro_out_rect
local hovered_macro

local cfg = { cats = nil, collapsed = {}, rects = {}, hdr_rects = {}, scroll = 0, total = 0 }
local cfg_settings = {}
local dd = { open = false, kind = nil, groups = {}, collapsed = {}, scroll = 0, total = 0,
             x = 0, y = 0, w = 0, h = 0, mx = 0, my = 0, close = nil }
local dd_bg, dd_title_t, dd_close_t
local dd_rows  = {}
local dd_rects = {}

local function in_rect(u, v, r)
    return r and u >= r.x and u <= r.x + r.w and v >= r.y and v <= r.y + r.h
end

local function default_target(entry)
    if not entry then return 'me' end
    if entry.type == 'ws' then return 't' end
    local pool = entry.type == 'ma' and res.spells or res.job_abilities
    local data = pool and entry.id and pool[entry.id]
    local tg = data and data.targets
    if type(tg) ~= 'table' then return 'me' end
    local function has(key)
        if tg[key] then return true end
        for k, v in pairs(tg) do if v and tostring(k):lower() == key:lower() then return true end end
        return false
    end
    local self_only = has('Self')
    local friendly  = has('Player') or has('Party') or has('Ally')
    local hostile   = has('Enemy') or has('NPC')
    if hostile then return 't' end
    if friendly then return 'stpc' end
    if self_only then return 'me' end
    return 'me'
end

local alt_held = false
local function set_alt(held)
    if held == alt_held then return end
    alt_held = held
    windower.send_command('setkey lalt ' .. (held and 'down' or 'up'))
end

local function hide_tip()
    if tip then tip:hide() end
    tip_entry = nil
    tip_info = nil
    tip_refresh = 0
end

local function img(path)
    local i = images.new({ pos = { x = 0, y = 0 }, visible = false,
        color = { alpha = 255, red = 255, green = 255, blue = 255 },
        size = { width = 8, height = 8 },
        texture = { path = path, fit = true }, repeatable = { x = 1, y = 1 }, draggable = false })
    i:path(path); i:fit(true); i:draggable(false); i:hide()
    return i
end

local FONT = 'Constantia'

local function txt(size, bold, right, stroke)
    stroke = stroke or { 8, 8, 10, 100 }
    local t = texts.new('${v}', { pos = { x = 0, y = 0 },
        text = { font = FONT, size = size, stroke = { width = 1, alpha = stroke[4] or 150, red = stroke[1], green = stroke[2], blue = stroke[3] } },
        flags = { bold = false, draggable = false, right = right or false }, bg = { visible = false } })
    t:color(255, 255, 255); t:alpha(255); t.v = ''; t:hide()
    pcall(function() t:font(FONT) end)
    if right then pcall(function() t:right_justified(true) end) end
    if size and size > 0 then t:size(math.max(6, math.floor(size * D._ms))) end
    D._texts[#D._texts + 1] = { t, size or 0 }
    return t
end

local function build_ui()
    if panel_bg then return end
    occlusion.push(5)
    panel_bg     = img(ART .. 'window.png')
    banner_bg    = img(ART .. 'banner.png')
    scroll_thumb = img(ART .. 'scroll_thumb.png')
    mj_icon      = img(ART_JOBS .. 'war.png')
    sj_icon      = img(ART_JOBS .. 'war.png')
    rail_hl_sel   = img(ART .. 'rail_hl.png'); rail_hl_sel:color(150, 116, 56);  rail_hl_sel:alpha(100)
    rail_hl_hover = img(ART .. 'rail_hl.png'); rail_hl_hover:color(92, 92, 98);  rail_hl_hover:alpha(82)
    title_t   = txt(15, true)
    close_t   = txt(13, true)
    banner_t  = txt(14, true)
    subtitle_t= txt(11)
    hint_t    = txt(10)
    wip_t     = txt(9, false, false, { 8, 8, 10, 25 })
    if C._ffxi then wip_t:color(170, 182, 206) else wip_t:color(205, 190, 155) end; wip_t:alpha(95)
    lvl_t     = txt(12, true)
    job_t     = txt(14, true)
    slvl_t    = txt(9, true)
    sjob_t    = txt(10, true)
    for i = 1, #rail_items do rail_texts[i] = txt(13, true) end
    cards.grow = function(n)
        for i = #cards + 1, n do
            cards[i] = { bg = img(ART .. 'row.png'), icon = img(ART .. 'row.png'),
                         name = txt(13, true), lv = txt(10), cur_icon = nil, cur_bg = nil }
        end
    end
    headers.grow = function(n)
        for i = #headers + 1, n do
            headers[i] = { line = img(ART .. 'section_line.png'), text = txt(13), desc = txt(9),
                           sym = img(ART .. 'caret_down.png'), cur_sym = nil }
        end
    end
    cards.grow(36)
    headers.grow(24)
    for i = 1, 40 do
        local c = { bg = img(ART .. 'row.png'), text = txt(11, true), cur = nil, pcur = nil,
                    lc = img(ART .. 'chip_l.png'), mc = img(ART .. 'chip_m.png'), rc = img(ART .. 'chip_r.png') }
        c.lc:fit(false); c.mc:fit(false); c.rc:fit(false)
        macro_chips[i] = c
    end
    for i = 1, 30 do macro_texts[i] = txt(11) end
    macro_icon_img = img(ART .. 'icon_placeholder.png')
    macro_out_img  = img(ART .. 'icon_placeholder.png')
    macro_body_thumb = img(ART .. 'scroll_thumb.png')
    occlusion.push(6)
    pick_bg      = img(ART .. 'pick_window.png')
    pick_hl      = img(ART .. 'row_hover.png'); pick_hl:alpha(150)
    pick_title_t = txt(14, true)
    pick_close_t = txt(13, true)
    for i = 1, 120 do pick_thumbs[i] = img(ART .. 'icon_placeholder.png'); pick_thumbs[i].cur = nil end
    for i = 1, 20 do
        pick_headers[i] = { line = img(ART .. 'section_line.png'), text = txt(12),
                            sym = img(ART .. 'caret_down.png'), cur_sym = nil }
    end
    dd_bg = img(ART .. 'pick_window.png')
    dd_title_t = txt(14, true)
    dd_close_t = txt(13, true)
    for i = 1, 18 do dd_rows[i] = { bg = img(ART .. 'row.png'), text = txt(12),
                                    sym = img(ART .. 'caret_down.png'), cur = nil, cur_sym = nil } end
    occlusion.pop()

    tip = action_tooltip.new()
    if tip.set_scale then tip:set_scale(D._ms) end
    occlusion.push(8)
    cursor_img = img(ART .. 'cursor.png')
    grab_img   = img(ART .. 'cursor_grab.png')
    drag_icon  = img(ART .. 'icon_placeholder.png')
    occlusion.pop()
    occlusion.pop()
end

local IMGS = function() return { panel_bg, banner_bg, scroll_thumb, mj_icon, sj_icon, rail_hl_sel, rail_hl_hover } end
local TXTS = function() return { title_t, close_t, banner_t, subtitle_t, hint_t, wip_t, lvl_t, job_t, slvl_t, sjob_t } end

local function hide_all()
    for _, o in ipairs(IMGS()) do if o then o:hide() end end
    for _, o in ipairs(TXTS()) do if o then o:hide() end end
    for _, o in ipairs(rail_texts) do if o then o:hide() end end
    for _, c in ipairs(cards) do c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
    for _, h in ipairs(headers) do h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
    for _, c in ipairs(macro_chips) do c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
    for _, t in ipairs(macro_texts) do t:hide() end
    if macro_icon_img then macro_icon_img:hide() end
    if macro_out_img then macro_out_img:hide() end
    if macro_body_thumb then macro_body_thumb:hide() end
    if cursor_img then cursor_img:hide() end
    if grab_img then grab_img:hide() end
    if drag_icon then drag_icon:hide() end
    if pick_bg then pick_bg:hide() end
    if pick_hl then pick_hl:hide() end
    if pick_title_t then pick_title_t:hide() end
    if pick_close_t then pick_close_t:hide() end
    for _, t in ipairs(pick_thumbs) do t:hide() end
    for _, h in ipairs(pick_headers) do h.line:hide(); h.text:hide(); h.sym:hide() end
    if dd_bg then dd_bg:hide() end
    if dd_title_t then dd_title_t:hide() end
    if dd_close_t then dd_close_t:hide() end
    for _, r in ipairs(dd_rows) do r.bg:hide(); r.text:hide(); r.sym:hide() end
end

local function ensure_position()
    if not settings then return end
    local ws = windower.get_windower_settings()
    local sw = (ws and ws.ui_x_res) or 1920
    local sh = (ws and ws.ui_y_res) or 1080
    if settings.Pos.X <= -9000 or settings.Pos.Y <= -9000 then
        settings.Pos.X = math.floor(sw / 2 - W / 2)
        settings.Pos.Y = math.floor(sh / 2 - H / 2)
    end
end

local function apply_scale(s)
    s = tonumber(s) or 1
    if s < 0.5 then s = 0.5 elseif s > 2.5 then s = 2.5 end
    if not D._base then
        D._base = { W = W, H = H }
        for _, k in ipairs(D._scale_fields) do D._base[k] = D[k] end
    end
    if D._ms == s and D._applied then return end
    D._ms = s; D._applied = true
    cfg._ms = s; macro._ms = s; picker._ms = s
    if tip and tip.set_scale then tip:set_scale(s) end
    W = math.floor(D._base.W * s)
    H = math.floor(D._base.H * s)
    for _, k in ipairs(D._scale_fields) do D[k] = math.floor(D._base[k] * s) end
    for _, e in ipairs(D._texts) do
        local t, bs = e[1], e[2]
        if t and bs and bs > 0 then pcall(t.size, t, math.max(6, math.floor(bs * s))) end
    end
end

local function tw(s, size) return #tostring(s) * size * D._ms * 0.52 end

local function jobfull(jid, abbr)
    if jid and res.jobs and res.jobs[jid] and res.jobs[jid].en then return res.jobs[jid].en end
    return tostring(abbr or '---')
end

local function put(t, s, x, y)
    if drag.panel_drag then t:hide(); return end
    if t._pv ~= s then t.v = s; t._pv = s end
    if t._px ~= x or t._py ~= y then t:pos(x, y); t._px, t._py = x, y end
    t:show()
end

local TBAR_PAD = 6
local TEXT_PAD = 4
local function bot_y(y, vh) return y + D.title_h - math.floor(TBAR_PAD * D._ms) - vh end
local function tvh(size) return math.floor((size + TEXT_PAD) * D._ms) end
local CEN_LIFT = 3
local function cen_y(top, boxh, size, lift) return math.floor(top + boxh / 2 - (TEXT_PAD + size / 2 + (lift or CEN_LIFT)) * D._ms) end
local function measure(t, fallback)
    local w = select(1, t:extents())
    return (w and w > 0) and w or fallback
end
local function put_b(t, s, x, y, size)
    if drag.panel_drag then t:hide(); return end
    if t._pv ~= s then t.v = s; t._pv = s end
    t:show()
    local py = bot_y(y, tvh(size or 12))
    if t._px ~= x or t._py ~= py then t:pos(x, py); t._px, t._py = x, py end
end

local function draw_job_cluster(x, y)
    if drag.panel_drag then
        for _, t in ipairs({ lvl_t, job_t, slvl_t, sjob_t }) do t:hide() end
        mj_icon:hide(); sj_icon:hide()
        return
    end
    local p = windower.ffxi.get_player()
    if not p then
        for _, t in ipairs({ lvl_t, job_t, slvl_t, sjob_t }) do t:hide() end
        mj_icon:hide(); sj_icon:hide()
        return
    end
    local mj    = p.main_job or '---'
    local m_lvl = 'LEVEL ' .. (p.main_job_level or 0)
    local m_job = jobfull(p.main_job_id, mj):upper()
    local sj    = p.sub_job
    local sl    = p.sub_job_level or 0
    local has_sub = sj and sj ~= 'NON' and sl and sl > 0
    local MI, SI = math.floor(22 * D._ms), math.floor(16 * D._ms)
    local IGAP, SEP = math.floor(3 * D._ms), math.floor(10 * D._ms)
    local IDROP = math.floor(5 * D._ms)

    lvl_t.v = C.level .. m_lvl .. C.cr; lvl_t:show()
    job_t.v = C.job .. m_job .. C.cr;   job_t:show()
    local s_lvl, s_job
    if has_sub then
        s_lvl = 'LEVEL ' .. sl
        s_job = jobfull(p.sub_job_id, sj):upper()
        slvl_t.v = C.level .. s_lvl .. C.cr; slvl_t:show()
        sjob_t.v = C.job .. s_job .. C.cr;   sjob_t:show()
    else
        slvl_t:hide(); sjob_t:hide(); sj_icon:hide()
    end

    local w_ml = measure(lvl_t, tw(m_lvl, 12))
    local w_mj = measure(job_t, tw(m_job, 14))
    local mw = w_ml + IGAP + MI + IGAP + w_mj
    local w_sl, w_sj, sw = 0, 0, 0
    if has_sub then
        w_sl = measure(slvl_t, tw(s_lvl, 9))
        w_sj = measure(sjob_t, tw(s_job, 10))
        sw = SEP + w_sl + IGAP + SI + IGAP + w_sj
    end

    local cx = (x + W - math.floor(34 * D._ms)) - mw - sw
    lvl_t:pos(cx, bot_y(y, tvh(12))); cx = cx + w_ml + IGAP
    local mp = ART_JOBS .. mj:lower() .. '.png'
    if cur_mj_path ~= mp then mj_icon:path(mp); cur_mj_path = mp end
    mj_icon:size(MI, MI); mj_icon:pos(cx, bot_y(y, MI) + IDROP); mj_icon:show(); cx = cx + MI + IGAP
    job_t:pos(cx, bot_y(y, tvh(14))); cx = cx + w_mj

    if has_sub then
        cx = cx + SEP
        slvl_t:pos(cx, bot_y(y, tvh(9))); cx = cx + w_sl + IGAP
        local sp = ART_JOBS .. sj:lower() .. '.png'
        if cur_sj_path ~= sp then sj_icon:path(sp); cur_sj_path = sp end
        sj_icon:size(SI, SI); sj_icon:pos(cx, bot_y(y, SI) + IDROP); sj_icon:show(); cx = cx + SI + IGAP
        sjob_t:pos(cx, bot_y(y, tvh(10)))
    end
end

local function ensure_catalog()
    local p = windower.ffxi.get_player()
    local sig = p and (tostring(p.main_job_id) .. ':' .. tostring(p.main_job_level)
        .. '/' .. tostring(p.sub_job_id) .. ':' .. tostring(p.sub_job_level)) or ''
    if sig ~= cat_sig then
        cat = catalog.build()
        groups = catalog.group(cat)
        cat_sig = sig
        scroll_y = 0
    end
end

local function set_path(im, c, field, path)
    if c[field] ~= path then im:path(path); c[field] = path end
end

local function draw_scrollbar(total, viewport, scroll, panel_x, panel_y, set_scroll)
    local trk_h = H - D.title_h - math.floor(28 * D._ms)
    local b = drag.bar
    if total > viewport then
        local th = math.max(math.floor(20 * D._ms), math.floor(trk_h * viewport / total))
        local ty = math.floor((trk_h - th) * scroll / math.max(1, total - viewport))
        local tx, ty0 = panel_x + W - math.floor(13 * D._ms), panel_y + D.title_h + math.floor(14 * D._ms)
        scroll_thumb:size(math.max(2, math.floor(4 * D._ms)), th); scroll_thumb:pos(tx, ty0 + ty); scroll_thumb:show()
        b.vis, b.set = true, set_scroll
        b.total, b.viewport, b.trk_h, b.th = total, viewport, trk_h, th
        b.track_x, b.track_y, b.thumb_y = tx, ty0, ty0 + ty
    else
        scroll_thumb:hide()
        b.vis = false
    end
end

local function draw_card(c, entry, cardx, cardy, col_w)
    local hov = (hovered_card == entry)
    set_path(c.bg, c, 'cur_bg', ART .. (hov and 'row_hover.png' or 'row.png'))
    if entry.status == 'nosub' or entry.status == 'wsnotjob' then c.bg:color(214, 96, 96)
    elseif entry.status == 'merit' or entry.status == 'wsquest' then c.bg:color(216, 196, 110)
    elseif entry.status == 'wsweapon' then c.bg:color(235, 150, 65)
    else c.bg:color(255, 255, 255) end
    c.bg:size(col_w, D.card_h); c.bg:pos(cardx, cardy); c.bg:show()
    if entry.icon then
        set_path(c.icon, c, 'cur_icon', entry.icon)
        c.icon:alpha(entry.learned and 255 or 105)
    else
        set_path(c.icon, c, 'cur_icon', ART .. 'icon_placeholder.png')
        c.icon:alpha(255)
    end
    local isz, ipad = math.floor(40 * D._ms), math.floor(6 * D._ms)
    c.icon:size(isz, isz); c.icon:pos(cardx + ipad, cardy + ipad); c.icon:show()
    local tx = cardx + math.floor(56 * D._ms)
    local sub = entry.sub or (entry.level and entry.level > 0 and ('Lv. ' .. entry.level)) or nil
    put(c.name, (entry.learned and C.card_name_on or C.card_name_off) .. entry.name .. C.cr,
        tx, sub and (cardy + math.floor(9 * D._ms)) or cen_y(cardy, D.card_h, 13))
    if sub then
        local sc = entry.sub and C.gray or (entry.learned and C.card_lv_on or C.card_lv_off)
        put(c.lv, sc .. sub .. C.cr, tx, cardy + math.floor(28 * D._ms))
    else
        c.lv:hide()
    end
end

local function draw_header(h, gx, sy, cw, category)
    if h.desc then h.desc:hide() end
    put(h.text, C.section .. category .. C.cr, gx, cen_y(sy, D.header_h, 13))
    h.line:size(cw, math.max(1, math.floor(D._ms))); h.line:pos(gx, sy + D.header_h - math.floor(4 * D._ms)); h.line:show()
    local sp = ART .. (collapsed[category] and 'caret_right.png' or 'caret_down.png')
    if h.cur_sym ~= sp then h.sym:path(sp); h.cur_sym = sp end
    local sym = math.floor(9 * D._ms)
    h.sym:size(sym, sym); h.sym:pos(gx + cw - math.floor(14 * D._ms), sy + math.floor((D.header_h - sym) / 2)); h.sym:show()
end

local function render_card_grid(gx, gy, cw, view_h, items, ncols, total, scroll, out_cards, out_headers)
    local col_w = math.floor((cw - (ncols - 1) * D.col_gap) / ncols)
    scroll = math.max(0, math.min(scroll, math.max(0, total - view_h)))
    local scr = math.floor(scroll)
    local nc, nh = 0, 0
    local ncards, nheaders = #cards, #headers
    for i = 1, ncards do cards[i]._used = false end
    for i = 1, nheaders do headers[i]._used = false end
    for _, it in ipairs(items) do
        local ih = (it.kind == 'h') and D.header_h or D.card_h
        local sy = gy + it.vy - scr
        local idx
        if it.kind == 'h' then idx = nh; nh = nh + 1 else idx = nc; nc = nc + 1 end
        if sy >= gy and sy + ih <= gy + view_h then
            if it.kind == 'h' then
                local h = headers[idx % nheaders + 1]; h._used = true
                draw_header(h, gx, sy, cw, it.cat)
                if out_headers then out_headers[#out_headers + 1] = { x = gx, y = sy, w = cw, h = D.header_h, cat = it.cat } end
            else
                local c = cards[idx % ncards + 1]; c._used = true
                local cardx = gx + (it.col or 0) * (col_w + D.col_gap)
                draw_card(c, it.entry, cardx, sy, col_w)
                if out_cards then
                    local r = it.hit or {}
                    local ip, isz = math.floor(6 * D._ms), math.floor(40 * D._ms)
                    r.x, r.y, r.w, r.h = cardx, sy, col_w, D.card_h
                    r.ix, r.iy, r.iw, r.ih = cardx + ip, sy + ip, isz, isz
                    r.entry = it.entry
                    out_cards[#out_cards + 1] = r
                end
            end
        end
    end
    for i = 1, ncards do local c = cards[i]; if not c._used then c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end end
    for i = 1, nheaders do local h = headers[i]; if not h._used then h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end end
    return scroll, col_w
end

local function render_sections(gx, gy, cw, view_h)
    local sig = 'ms' .. tostring(D._ms)
    for _, g in ipairs(groups) do if collapsed[g.category] then sig = sig .. '|' .. g.category end end
    if groups._sig ~= sig then
        local items, vy = {}, 0
        for _, g in ipairs(groups) do
            items[#items + 1] = { kind = 'h', cat = g.category, vy = vy }
            vy = vy + D.header_h
            if not collapsed[g.category] then
                for i, entry in ipairs(g.entries) do
                    items[#items + 1] = { kind = 'c', entry = entry, col = (i - 1) % 3,
                        vy = vy + math.floor((i - 1) / 3) * (D.card_h + D.card_gap) }
                end
                vy = vy + math.ceil(#g.entries / 3) * (D.card_h + D.card_gap)
            end
            vy = vy + D.section_gap
        end
        groups._items, groups._sig, groups._total = items, sig, vy
    end
    content_total = groups._total
    card_rects, header_rects = {}, {}
    scroll_y = render_card_grid(gx, gy, cw, view_h, groups._items, 3, content_total, scroll_y, card_rects, header_rects)
end

local macro_icon_cur, macro_out_cur

local function macro_icon_path()
    if macro.icon_abs and macro.icon_abs ~= '' then return macro.icon_abs end
    if macro.icon and macro.icon ~= '' then
        return windower.addon_path .. 'assets/components/hotbar/icons/' .. macro.icon .. '.png'
    end
    return ART .. 'icon_placeholder.png'
end

local function macro_entry()
    local icon = macro_icon_path()
    local icon_save
    if macro.icon_abs and macro.icon_abs ~= '' then
        icon_save = macro.icon_abs:gsub('\\', '/'):gsub('.*assets/components/hotbar/icons/', ''):gsub('%.png$', '')
    elseif macro.icon and macro.icon ~= '' then
        icon_save = macro.icon
    end
    if macro.kind == 'macro' or macro.kind == 'input' then
        local txt = (macro.kind == 'macro') and macro.body or macro.cmd
        txt = txt:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('%s*\n%s*', ';;')
        return { type = 'input', name = txt, action = txt, target = macro.target,
                 alias = (macro.alias ~= '' and macro.alias) or 'Macro', icon = icon, icon_save = icon_save, learned = true }
    end
    local act = macro.action
    return { type = macro.kind, name = act, action = act, target = macro.target,
             alias = (macro.alias ~= '' and macro.alias) or act, icon = icon, icon_save = icon_save, learned = true }
end

local function render_macros(cx, gy, cw, view_h)
    macro_rects = {}
    macro.scroll = math.max(0, math.min(macro.scroll, math.max(0, macro.total - view_h)))
    local ms = macro._ms or 1
    local mf = math.floor
    local SR = mf(20 * ms)
    local GAPC, WRAP, LBLY, FLDH = mf(8 * ms), mf(30 * ms), mf(22 * ms), mf(26 * ms)
    local CH = mf(24 * ms)
    local ci, ti = 0, 0
    local left, right = cx, cx + cw - SR
    local vtop, vbot = gy, gy + view_h
    local function vis(y, h) return y >= vtop and y + h <= vbot end
    local function lbl(s, x, y, color)
        ti = ti + 1; local t = macro_texts[ti]
        if y >= vtop and y + mf(14 * ms) <= vbot then put(t, (color or C.sub) .. s .. C.cr, x, y) else t:hide() end
    end
    local CHIP_PAD = mf(18 * ms)
    local function chipw(s) return mf(glyph_width(s) * ms) + CHIP_PAD end
    local function chip(s, x, y, sel, kind, val)
        ci = ci + 1; local c = macro_chips[ci]
        local w = chipw(s)
        if vis(y, CH) then
            local sfx = sel and '_on' or ''
            local lp = ART..'chip'..sfx..'_l.png'
            if c.pcur ~= lp then
                c.lc:path(lp); c.mc:path(ART..'chip'..sfx..'_m.png'); c.rc:path(ART..'chip'..sfx..'_r.png'); c.pcur = lp
            end
            local cap = mf(8 * ms)
            c.bg:hide()
            c.lc:size(cap, CH); c.lc:pos(x, y); c.lc:show()
            c.rc:size(cap, CH); c.rc:pos(x + w - cap, y); c.rc:show()
            c.mc:size(math.max(1, w - 2 * cap), CH); c.mc:pos(x + cap, y); c.mc:show()
            put(c.text, (sel and C.card_name_on or C.chip_off) .. s .. C.cr,
                x + mf(CHIP_PAD / 2), cen_y(y, CH, 11))
            macro_rects[#macro_rects + 1] = { x = x, y = y, w = w, h = CH, kind = kind, val = val }
        else
            c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide()
        end
        return w
    end
    local function flow_chips(items, y, get)
        local x = left
        for _, it in ipairs(items) do
            local s, sel, kind, val = get(it)
            if x > left and x + chipw(s) > right then x = left; y = y + WRAP end
            x = x + chip(s, x, y, sel, kind, val) + GAPC
        end
        return y + WRAP
    end
    local function field(val, x, y, w, hint, kind, h)
        ci = ci + 1; local c = macro_chips[ci]
        h = h or FLDH
        c.lc:hide(); c.mc:hide(); c.rc:hide()
        if vis(y, h) then
            local path = ART .. 'field.png'
            if c.cur ~= path then c.bg:path(path); c.cur = path end
            c.bg:color(255, 255, 255); c.bg:size(w, h); c.bg:pos(x, y); c.bg:show()
            local color = (val ~= '') and C.card_name_on or C.placeholder
            put(c.text, color .. (val ~= '' and val or hint) .. C.cr, x + mf(10 * ms), cen_y(y, h, 11))
            macro_rects[#macro_rects + 1] = { x = x, y = y, w = w, h = h, kind = kind }
        else
            c.bg:hide(); c.text:hide()
        end
    end
    local function body_field(x, y, w, h)
        ci = ci + 1; local c = macro_chips[ci]
        c.lc:hide(); c.mc:hide(); c.rc:hide()
        if not vis(y, h) then c.bg:hide(); c.text:hide(); macro_body_thumb:hide(); return end
        local path = ART .. 'field_tall.png'
        if c.cur ~= path then c.bg:path(path); c.cur = path end
        c.bg:color(255, 255, 255); c.bg:size(w, h); c.bg:pos(x, y); c.bg:show()
        macro_rects[#macro_rects + 1] = { x = x, y = y, w = w, h = h, kind = 'body' }
        local LH, PAD = mf(18 * ms), mf(6 * ms)
        local visN = math.max(1, math.floor((h - PAD) / LH))
        local lines = {}
        for ln in (macro.body .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = ln end
        if #lines == 1 and lines[1] == '' then lines = {} end
        if #lines == 0 then
            put(c.text, C.placeholder .. 'type in the [macro] section of import.txt (loads live)' .. C.cr, x + mf(10 * ms), y + PAD)
            macro_body_thumb:hide()
            return
        end
        local maxs = math.max(0, #lines - visN)
        macro.bodyscroll = math.max(0, math.min(macro.bodyscroll, maxs))
        local seg = {}
        for i = 1, visN do local l = lines[i + macro.bodyscroll]; if l then seg[#seg + 1] = l end end
        put(c.text, C.card_name_on .. table.concat(seg, '\n') .. C.cr, x + mf(10 * ms), y + PAD)
        if #lines > visN then
            local trk = h - mf(8 * ms)
            local th = math.max(mf(12 * ms), math.floor(trk * visN / #lines))
            local ty = math.floor((trk - th) * macro.bodyscroll / maxs)
            macro_body_thumb:size(math.max(2, mf(3 * ms)), th); macro_body_thumb:pos(x + w - mf(6 * ms), y + mf(4 * ms) + ty); macro_body_thumb:show()
        else
            macro_body_thumb:hide()
        end
    end

    local top = gy - macro.scroll
    local y = top
    lbl('Edit macros, commands & aliases in this file (changes load live):', cx, y, C.sub); y = y + LBLY
    lbl(macro.file, cx, y, C.gray); y = y + LBLY + mf(6 * ms)
    lbl('Type', cx, y); y = y + LBLY
    y = flow_chips(MD.MACRO_KINDS, y, function(kd) return kd.l, macro.kind == kd.k, 'kind', kd.k end) + mf(10 * ms)

    if macro.kind == 'use_equip' then
        lbl('Slot', cx, y); y = y + LBLY
        y = flow_chips(MD.EQUIP_SLOTS, y, function(s) return s.l, macro.target == s.k, 'target', s.k end) + mf(10 * ms)
    elseif macro.kind ~= 'input' and macro.kind ~= 'macro' then
        lbl('Target', cx, y); y = y + LBLY
        y = flow_chips(MD.MACRO_TARGETS, y, function(t) return '<' .. t .. '>', macro.target == t, 'target', t end)
        lbl((macro_more and '[-]' or '[+]') .. ' More targets', cx, y, C.gray)
        if y >= vtop and y + mf(18 * ms) <= vbot then
            macro_rects[#macro_rects + 1] = { x = cx, y = y - mf(2 * ms), w = mf(160 * ms), h = mf(18 * ms), kind = 'more' }
        end
        y = y + LBLY
        if macro_more then
            y = flow_chips(MD.MACRO_TARGETS_MORE, y, function(t) return '<' .. t .. '>', macro.target == t, 'target', t end)
        end
        y = y + mf(10 * ms)
    end

    if macro.kind == 'macro' then
        lbl('Macro  (edit the [macro] section in import.txt — up to 6 lines, <wait N>)', cx, y); y = y + LBLY
        body_field(cx, y, cw - SR, mf(120 * ms))
        y = y + mf(138 * ms)
    elseif macro.kind == 'input' then
        lbl('Command  (edit the [command] section in import.txt)', cx, y); y = y + LBLY
        field(macro.cmd, cx, y, cw - SR, 'type in the [command] section of import.txt (loads live)', 'action', FLDH)
        y = y + mf(44 * ms)
    else
        lbl(macro.kind == 'use_equip' and 'Gear' or 'Action', cx, y); y = y + LBLY
        field(macro.action, cx, y, cw - SR, 'click to choose from the list', 'action', FLDH)
        y = y + mf(44 * ms)
    end
    lbl('Alias', cx, y); y = y + LBLY
    field(macro.alias, cx, y, mf(220 * ms), 'set via the [alias] section in import.txt', 'alias', FLDH)
    y = y + mf(44 * ms)

    local IS, OS = mf(44 * ms), mf(48 * ms)
    local out_x = right - OS
    local out_label = 'Output  (drag to a hotbar slot)'
    lbl('Icon', cx, y)
    lbl(out_label, math.floor(right - tw(out_label, 11)), y)
    y = y + LBLY
    local ip = macro_icon_path()
    if vis(y, IS) then
        if macro_icon_cur ~= ip then macro_icon_img:path(ip); macro_icon_img:fit(true); macro_icon_cur = ip end
        macro_icon_img:size(IS, IS); macro_icon_img:pos(cx, y); macro_icon_img:show()
        macro_rects[#macro_rects + 1] = { x = cx, y = y, w = IS, h = IS, kind = 'icon' }
        lbl('double-click to choose', cx + IS + mf(10 * ms), cen_y(y, IS, 11, 1), C.gray)
        if macro_out_cur ~= ip then macro_out_img:path(ip); macro_out_img:fit(true); macro_out_cur = ip end
        macro_out_img:size(OS, OS); macro_out_img:pos(out_x, y); macro_out_img:show()
        macro_out_rect = { x = out_x, y = y, w = OS, h = OS }
    else
        macro_icon_img:hide(); macro_out_img:hide(); macro_out_rect = nil
    end
    y = y + OS + mf(8 * ms)

    macro.total = y - top
    for i = ci + 1, #macro_chips do local c = macro_chips[i]; c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
    for i = ti + 1, #macro_texts do macro_texts[i]:hide() end
end

local function apick_list(kind)
    if kind == 'ws' then return { { category = 'Weapon Skills', entries = catalog.weapon_skills() } } end
    if kind == 'item' then return catalog.usable_items() end
    if kind == 'use_equip' then return catalog.enchanted_gear(macro.target) end
    ensure_catalog()
    local sub = {}
    for _, e in ipairs(cat or {}) do if e.type == kind then sub[#sub + 1] = e end end
    return catalog.group(sub)
end

local function open_apick()
    dd.dest = 'macro'
    dd.kind = macro.kind
    dd.groups = apick_list(dd.kind)
    if #dd.groups == 0 then
        dd.open = false
        if dd.kind == 'use_equip' then log('XivUI Menu: no enchanted gear in your bags fits that slot.') end
        return
    end
    dd.collapsed = {}
    for _, g in ipairs(dd.groups) do dd.collapsed[g.category] = true end
    dd.scroll = 0
    dd.open = true
end

local function ensure_import_file()
    local f = io.open(IMPORT_FILE, 'r')
    if f then f:close(); return end
    if windower.create_dir then pcall(windower.create_dir, windower.addon_path .. 'data/xivuimenu') end
    f = io.open(IMPORT_FILE, 'w')
    if not f then return end
    f:write('# XivUI Menu macro import. Type below each [section], SAVE, and it loads in-game\n')
    f:write('# live (no reload). Lines starting with # are ignored.\n')
    f:write('#  [alias]   -> the short hotbar label\n')
    f:write('#  [command] -> a single line, used when Type = Command\n')
    f:write('#  [macro]   -> up to 6 lines, used when Type = Macro (supports <wait N>)\n\n')
    f:write('[alias]\n\n\n[command]\n\n\n[macro]\n\n\n')
    f:close()
end

local function poll_import()
    import_poll = import_poll + 1
    if import_poll < 20 then return end
    import_poll = 0
    local f = io.open(IMPORT_FILE, 'r')
    if not f then return end
    local raw = f:read('*a'); f:close()
    if raw == import_last then return end
    import_last = raw
    local secs = { alias = {}, command = {}, macro = {} }
    local cur
    for line in (raw:gsub('\r\n', '\n'):gsub('\r', '\n') .. '\n'):gmatch('([^\n]*)\n') do
        local h = line:match('^%s*%[(%a+)%]%s*$')
        if h then cur = secs[h:lower()]
        elseif cur and not line:match('^%s*#') then cur[#cur + 1] = line end
    end
    local function clean(t, maxn)
        local out = {}
        for _, l in ipairs(t) do out[#out + 1] = l end
        while #out > 0 and out[1]:match('^%s*$')    do table.remove(out, 1) end
        while #out > 0 and out[#out]:match('^%s*$') do out[#out] = nil end
        for i = #out, (maxn or #out) + 1, -1 do out[i] = nil end
        return out
    end
    local al = clean(secs.alias, 1)
    local cm = clean(secs.command, 1)
    macro.alias = (al[1] or ''):gsub('^%s+', ''):gsub('%s+$', '')
    macro.cmd   = (cm[1] or ''):gsub('^%s+', ''):gsub('%s+$', '')
    macro.body  = table.concat(clean(secs.macro, 6), '\n')
end

local function hide_apick_pool()
    if dd_bg then dd_bg:hide() end
    if dd_title_t then dd_title_t:hide() end
    if dd_close_t then dd_close_t:hide() end
    for _, r in ipairs(dd_rows) do r.bg:hide(); r.text:hide(); r.sym:hide() end
    dd_rects = {}
    occlusion.clear('xivuimenu_dd')
end

local function render_apick()
    if not dd.open then hide_apick_pool(); return end
    local ws = windower.get_windower_settings()
    local sw, sh = (ws and ws.ui_x_res) or 1920, (ws and ws.ui_y_res) or 1080
    local ms, mf = D._ms or 1, math.floor
    local AW, AH, TH, PAD, RH = mf(440 * ms), mf(480 * ms), mf(30 * ms), mf(12 * ms), mf(24 * ms)
    local px, py = math.floor(sw / 2 - AW / 2), math.floor(sh / 2 - AH / 2)
    dd.x, dd.y, dd.w, dd.h = px, py, AW, AH
    dd_bg:size(AW, AH); dd_bg:pos(px, py); dd_bg:show()
    local label = ({ ja = 'Choose Ability', ma = 'Choose Spell', ws = 'Choose Weapon Skill',
                     item = 'Choose Item', use_equip = 'Choose Gear' })[dd.kind] or 'Choose Action'
    put_b(dd_title_t, C.title .. label .. C.cr, px + mf(14 * ms), py, 14)
    put_b(dd_close_t, C.gray .. 'X' .. C.cr, px + AW - mf(24 * ms), py, 13)
    dd.close = { x = px + AW - mf(28 * ms), y = py + mf(6 * ms), w = mf(22 * ms), h = mf(22 * ms) }

    local gx, gy = px + PAD, py + TH + mf(6 * ms)
    local cw, view_h = AW - 2 * PAD, (py + AH - mf(10 * ms)) - (py + TH + mf(6 * ms))

    local items, vy = {}, 0
    for _, g in ipairs(dd.groups) do
        items[#items + 1] = { kind = 'h', cat = g.category, vy = vy }; vy = vy + RH
        if not dd.collapsed[g.category] then
            for _, e in ipairs(g.entries) do items[#items + 1] = { kind = 'a', e = e, vy = vy }; vy = vy + RH end
        end
        vy = vy + mf(4 * ms)
    end
    dd.total = vy
    dd.scroll = math.max(0, math.min(dd.scroll, math.max(0, dd.total - view_h)))

    dd_rects = {}
    local ri = 0
    for _, it in ipairs(items) do
        local sy = gy + it.vy - dd.scroll
        if sy >= gy and sy + RH <= gy + view_h and ri < #dd_rows then
            ri = ri + 1; local row = dd_rows[ri]
            if it.kind == 'h' then
                row.bg:hide()
                local sp = ART .. (dd.collapsed[it.cat] and 'caret_right.png' or 'caret_down.png')
                if row.cur_sym ~= sp then row.sym:path(sp); row.cur_sym = sp end
                local sym = mf(9 * ms)
                row.sym:size(sym, sym); row.sym:pos(gx + mf(2 * ms), sy + math.floor((RH - sym) / 2)); row.sym:show()
                put(row.text, C.section .. it.cat .. C.cr, gx + mf(16 * ms), cen_y(sy, RH, 12))
                dd_rects[#dd_rects + 1] = { x = gx, y = sy, w = cw, h = RH, kind = 'h', cat = it.cat }
            else
                row.sym:hide()
                row.bg:hide()
                local e = it.e
                local ok = e.learned
                local hov = ok and in_rect(dd.mx, dd.my, { x = gx, y = sy, w = cw, h = RH - mf(2 * ms) })
                local nm = ok and (hov and C.card_name_on or C.pick_on) or C.placeholder
                local lv = (e.level and e.level > 0) and (' ' .. C.pick_lv .. 'Lv.' .. e.level) or ''
                put(row.text, nm .. e.name .. lv .. C.cr, gx + mf(16 * ms), cen_y(sy, RH - mf(2 * ms), 12))
                dd_rects[#dd_rects + 1] = { x = gx, y = sy, w = cw, h = RH - mf(2 * ms), kind = 'a',
                    name = e.name, icon = e.icon, ok = ok, entry = e }
            end
        end
    end
    for i = ri + 1, #dd_rows do dd_rows[i].bg:hide(); dd_rows[i].text:hide(); dd_rows[i].sym:hide() end
    occlusion.set('xivuimenu_dd', px, py, AW, AH, 6)
end

local function apick_mouse(mtype, ux, uy, delta)
    dd.mx, dd.my = ux, uy
    local over = in_rect(ux, uy, { x = dd.x, y = dd.y, w = dd.w, h = dd.h })
    set_alt(over)
    if grab_img then grab_img:hide() end
    if cursor_img then
        if over then cursor_img:size(D.cursor_w, D.cursor_h); cursor_img:pos(ux - D.cursor_hx, uy - D.cursor_hy); cursor_img:show()
        else cursor_img:hide() end
    end
    if mtype == 10 then
        dd.scroll = math.max(0, dd.scroll + (delta > 0 and -48 or 48)); return true
    elseif mtype == 1 then
        if in_rect(ux, uy, dd.close) then dd.open = false; return true end
        for _, r in ipairs(dd_rects) do
            if in_rect(ux, uy, r) then
                if r.kind == 'h' then
                    dd.collapsed[r.cat] = not dd.collapsed[r.cat]
                elseif r.ok then
                    if dd.dest == 'choice' then
                        if dd.choice_add_entry then dd.choice_add_entry(dd.kind, r.name, r.icon, r.entry) end
                    elseif dd.dest == 'expand' then
                        if dd.expand_set_pending then dd.expand_set_pending(dd.kind, r.name, r.icon, r.entry) end
                    else
                        macro.action = r.name
                        macro.icon_abs = r.icon
                    end
                    dd.open = false
                end
                return true
            end
        end
        if not over then dd.open = false end
    end
    return true
end

local function hide_picker_pool()
    if pick_bg then pick_bg:hide() end
    if pick_hl then pick_hl:hide() end
    if pick_title_t then pick_title_t:hide() end
    if pick_close_t then pick_close_t:hide() end
    for _, t in ipairs(pick_thumbs) do t:hide() end
    for _, h in ipairs(pick_headers) do h.line:hide(); h.text:hide(); h.sym:hide() end
end

local function close_picker()
    picker.open = false; picker.key, picker.entry = nil, nil; hovered_thumb = nil
    hide_picker_pool()
    occlusion.clear('xivuimenu_pick'); ui_bounds.clear('xivuimenu_pick')
end

local function open_picker(key, entry)
    picker.open = true; picker.key, picker.entry = key, entry; picker.scroll = 0
    picker.collapsed = {}
    for _, g in ipairs(iconpicker.index()) do picker.collapsed[g.folder] = true end
    hide_tip()
end

local function render_picker()
    if not picker.open then hide_picker_pool(); occlusion.clear('xivuimenu_pick'); ui_bounds.clear('xivuimenu_pick'); return end
    local ms = picker._ms or 1
    local mf = math.floor
    local PICK_W, PICK_H   = mf(540 * ms), mf(452 * ms)
    local PICK_TITLE_H     = mf(28 * ms)
    local PICK_PAD         = mf(12 * ms)
    local THUMB, THUMB_GAP = mf(38 * ms), mf(4 * ms)
    local PICK_HEADER_H    = mf(22 * ms)
    local ws = windower.get_windower_settings()
    local sw, sh = (ws and ws.ui_x_res) or 1920, (ws and ws.ui_y_res) or 1080
    local px, py = math.floor(sw / 2 - PICK_W / 2), math.floor(sh / 2 - PICK_H / 2)
    pick_rect = { x = px, y = py, w = PICK_W, h = PICK_H }

    pick_bg:size(PICK_W, PICK_H); pick_bg:pos(px, py); pick_bg:show()
    put_b(pick_title_t, C.title .. 'Choose Icon ' .. C.gray .. (picker.entry and picker.entry.name or '') .. C.cr, px + mf(14 * ms), py, 14)
    put_b(pick_close_t, C.gray .. 'X' .. C.cr, px + PICK_W - mf(24 * ms), py, 13)
    pick_close_rect = { x = px + PICK_W - mf(28 * ms), y = py + mf(6 * ms), w = mf(22 * ms), h = mf(22 * ms) }

    local gx, gy = px + PICK_PAD, py + PICK_TITLE_H + mf(8 * ms)
    local cw = PICK_W - 2 * PICK_PAD
    local view_h = (py + PICK_H - mf(10 * ms)) - gy
    local cols = math.max(1, math.floor((cw + THUMB_GAP) / (THUMB + THUMB_GAP)))

    local items, vy = {}, 0
    for _, g in ipairs(iconpicker.index()) do
        items[#items + 1] = { kind = 'h', folder = g.folder, vy = vy }
        vy = vy + PICK_HEADER_H
        if not picker.collapsed[g.folder] then
            for i, value in ipairs(g.icons) do
                items[#items + 1] = { kind = 't', value = value, col = (i - 1) % cols,
                                      vy = vy + math.floor((i - 1) / cols) * (THUMB + THUMB_GAP) }
            end
            vy = vy + math.ceil(#g.icons / cols) * (THUMB + THUMB_GAP)
        end
        vy = vy + mf(6 * ms)
    end
    picker.total = vy
    picker.scroll = math.max(0, math.min(picker.scroll, math.max(0, picker.total - view_h)))

    pick_rects, pick_hdr_rects = {}, {}
    local ti, hi = 0, 0
    for _, it in ipairs(items) do
        local sy = gy + it.vy - picker.scroll
        local ih = (it.kind == 'h') and PICK_HEADER_H or THUMB
        if sy >= gy and sy + ih <= gy + view_h then
            if it.kind == 'h' then
                hi = hi + 1
                local h = pick_headers[hi]
                if h then
                    put(h.text, C.section .. it.folder .. C.cr, gx, cen_y(sy, PICK_HEADER_H, 12))
                    local sym = mf(9 * ms)
                    h.line:size(cw, math.max(1, mf(ms))); h.line:pos(gx, sy + PICK_HEADER_H - mf(4 * ms)); h.line:show()
                    local sp = ART .. (picker.collapsed[it.folder] and 'caret_right.png' or 'caret_down.png')
                    if h.cur_sym ~= sp then h.sym:path(sp); h.cur_sym = sp end
                    h.sym:size(sym, sym); h.sym:pos(gx + cw - mf(14 * ms), sy + math.floor((PICK_HEADER_H - sym) / 2)); h.sym:show()
                    pick_hdr_rects[#pick_hdr_rects + 1] = { x = gx, y = sy, w = cw, h = PICK_HEADER_H, folder = it.folder }
                end
            else
                ti = ti + 1
                local t = pick_thumbs[ti]
                if t then
                    local tx = gx + it.col * (THUMB + THUMB_GAP)
                    local p = iconpicker.path(it.value) or (ART .. 'icon_placeholder.png')
                    if pick_thumb_cur[ti] ~= p then t:path(p); t:fit(false); pick_thumb_cur[ti] = p end
                    local th2 = THUMB - mf(2 * ms)
                    t:size(th2, th2); t:pos(tx, sy); t:show()
                    pick_rects[#pick_rects + 1] = { x = tx, y = sy, w = th2, h = th2, value = it.value }
                end
            end
        end
    end
    for i = ti + 1, #pick_thumbs do pick_thumbs[i]:hide() end
    for i = hi + 1, #pick_headers do local h = pick_headers[i]; h.line:hide(); h.text:hide(); h.sym:hide() end

    if hovered_thumb then pick_hl:size(THUMB, THUMB); pick_hl:pos(hovered_thumb.x - mf(ms), hovered_thumb.y - mf(ms)); pick_hl:show()
    else pick_hl:hide() end

    occlusion.set('xivuimenu_pick', px, py, PICK_W, PICK_H, 6)
    ui_bounds.register('xivuimenu_pick', px, py, PICK_W, PICK_H)
end

local function hide_action_grid()
    for _, c in ipairs(cards)   do c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
    for _, h in ipairs(headers) do h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
    card_rects, header_rects = {}, {}
end
local function hide_macro_form()
    for _, c in ipairs(macro_chips) do c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
    for _, t in ipairs(macro_texts) do t:hide() end
    if macro_icon_img then macro_icon_img:hide() end
    if macro_out_img then macro_out_img:hide() end
    if macro_body_thumb then macro_body_thumb:hide() end
    macro_rects, macro_out_rect = {}, nil
end
local function hide_macro_extras()
    if macro_body_thumb then macro_body_thumb:hide() end
    macro_rects, macro_out_rect = {}, nil
end

local function ensure_config_cats() build_config_cats(cfg, cfg_settings) end

local function render_config(gx, gy, cw, view_h)
    ensure_config_cats()
    card_rects, header_rects = {}, {}
    cfg.rects = cfg.rects or {}; cfg.hdr_rects = cfg.hdr_rects or {}
    hint_t:hide()
    if not cfg.cats then
        for _, c in ipairs(cards) do c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
        for _, h in ipairs(headers) do h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
        cfg.total = 0; return
    end
    local ms = cfg._ms or 1
    local COLS = 3
    local GAP, HEAD_H, CELL_H, SEC_GAP = math.floor(8 * ms), math.floor(48 * ms), math.floor(52 * ms), math.floor(14 * ms)
    local col_w = math.floor((cw - (COLS - 1) * GAP) / COLS)
    local label_w = col_w - math.floor(65 * ms)
    local function clip(s, px, cper)
        local maxc = math.floor((px or label_w) / (cper or 7))
        if maxc < 3 then maxc = 3 end
        if #s > maxc then return s:sub(1, maxc - 1) .. '..' end
        return s
    end
    local vit, vy = cfg._vit, cfg._vit_total
    if not vit or cfg._vit_cw ~= cw then
        vit, vy = {}, 0
        local nc, nh = 0, 0
        for _, cat in ipairs(cfg.cats) do
            vit[#vit + 1] = { kind = 'h', cat = cat, vy = vy, hidx = nh,
                              name_str = C.section .. cat.name .. C.cr,
                              desc_str = C.desc .. (cat.desc or '') .. C.cr }
            nh = nh + 1; vy = vy + HEAD_H
            if not cfg.collapsed[cat.name] then
                for i, it in ipairs(cat.items) do
                    local e = { kind = 'cell', it = it, col = (i - 1) % COLS, cidx = nc,
                                vy = vy + math.floor((i - 1) / COLS) * CELL_H,
                                name_str = C.card_name_on .. clip(it.label, label_w, math.floor(8 * ms)) .. C.cr }
                    if it.kind ~= 'choice' and it.kind ~= 'keybind' and it.kind ~= 'button' then
                        e.desc_str = C.desc .. clip(it.desc, col_w - math.floor(22 * ms), math.floor(6 * ms)) .. C.cr
                    end
                    vit[#vit + 1] = e; nc = nc + 1
                end
                vy = vy + math.ceil(#cat.items / COLS) * CELL_H
            end
            vy = vy + SEC_GAP
        end
        cfg._vit, cfg._vit_total, cfg._vit_cw, cfg._nc, cfg._nh = vit, vy, cw, nc, nh
    end
    cfg.total = vy
    cfg.scroll = math.max(0, math.min(cfg.scroll, math.max(0, cfg.total - view_h)))
    local scr = math.floor(cfg.scroll)
    local ncards, nheaders = #cards, #headers
    for i = 1, ncards do cards[i]._used = false end
    for i = 1, nheaders do headers[i]._used = false end
    local rects, hrects = cfg.rects, cfg.hdr_rects
    local cr, chr = 0, 0
    local mf = math.floor
    local p1, p2, p4, p6, p9 = mf(ms), mf(2 * ms), mf(4 * ms), mf(6 * ms), mf(9 * ms)
    local p16, p18, p20, p23, p27 = mf(16 * ms), mf(18 * ms), mf(20 * ms), mf(23 * ms), mf(27 * ms)
    local p22, tog_w, tog_h, tog_off, cper7 = mf(22 * ms), mf(40 * ms), mf(20 * ms), mf(50 * ms), mf(7 * ms)
    for _, v in ipairs(vit) do
        local sy = gy + v.vy - scr
        local ih = (v.kind == 'h') and HEAD_H or CELL_H
        if sy >= gy and sy + ih - p6 <= gy + view_h then
            if v.kind == 'h' then
                local h = headers[v.hidx % nheaders + 1]; h._used = true
                local sp = ART .. ((not cfg.collapsed[v.cat.name]) and 'caret_down.png' or 'caret_right.png')
                if h.cur_sym ~= sp then h.sym:path(sp); h.cur_sym = sp end
                h.sym:size(p9, p9); h.sym:pos(gx + p1, sy + p4); h.sym:show()
                put(h.text, v.name_str, gx + p16, sy)
                h.line:size(cw, math.max(2, p2)); h.line:pos(gx, sy + p23); h.line:show()
                if h.desc then put(h.desc, v.desc_str, gx + p2, sy + math.floor(30 * ms)) end
                chr = chr + 1; local r = hrects[chr] or {}; r.x, r.y, r.w, r.h, r.cat = gx, sy - p2, cw, p20, v.cat.name; hrects[chr] = r
            else
                local c = cards[v.cidx % ncards + 1]; c._used = true; local it, cx2 = v.it, gx + v.col * (col_w + GAP)
                set_path(c.bg, c, 'cur_bg', ART .. 'row.png')
                c.bg:color(255, 255, 255); c.bg:size(col_w, CELL_H - p6); c.bg:pos(cx2, sy); c.bg:show()
                put(c.name, v.name_str, cx2 + p9, sy + p6)
                if it.kind == 'choice' then
                    put(c.lv, C.value .. clip(tostring(it.get()), col_w - p22, cper7) .. '  ' .. C.hint .. '(tap)' .. C.cr, cx2 + p9, sy + p27)
                    c.icon:hide()
                elseif it.kind == 'button' then
                    local on = it.active and it.active()
                    put(c.lv, (on and '\\cs(120,230,120)> selected'
                              or (C.desc .. clip(it.desc, col_w - p22, cper7) .. '  ' .. C.hint .. '(tap)')) .. C.cr,
                        cx2 + p9, sy + p27)
                    c.icon:hide()
                elseif it.kind == 'keybind' then
                    if cfg.capturing then
                        put(c.lv, '\\cs(120,255,120)press a key…  ' .. C.hint .. '(Esc cancels)' .. C.cr, cx2 + p9, sy + p27)
                    else
                        put(c.lv, C.value .. clip(tostring(it.get()), col_w - p22, cper7) .. '  ' .. C.hint .. '(tap)' .. C.cr, cx2 + p9, sy + p27)
                    end
                    c.icon:hide()
                else
                    set_path(c.icon, c, 'cur_icon', ART .. (it.get() and 'toggle_on.png' or 'toggle_off.png'))
                    c.icon:alpha(255); c.icon:size(tog_w, tog_h); c.icon:pos(cx2 + col_w - tog_off, sy + p6); c.icon:show()
                    put(c.lv, v.desc_str, cx2 + p9, sy + p27)
                end
                cr = cr + 1; local r = rects[cr] or {}; r.x, r.y, r.w, r.h, r.item = cx2, sy, col_w, CELL_H - p6, it; rects[cr] = r
            end
        end
    end
    rects[cr + 1] = nil; hrects[chr + 1] = nil
    for i = 1, ncards do local c = cards[i]; if not c._used then c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end end
    for i = 1, nheaders do local h = headers[i]; if not h._used then h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end end
end

local function redraw_modal()
    for _, o in ipairs(IMGS()) do if o then o:hide() end end
    for _, o in ipairs(TXTS()) do if o then o:hide() end end
    for _, o in ipairs(rail_texts) do if o then o:hide() end end
    for _, c in ipairs(cards) do c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
    for _, h in ipairs(headers) do h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
    for _, c in ipairs(macro_chips) do c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
    for _, t in ipairs(macro_texts) do t:hide() end
    if macro_icon_img then macro_icon_img:hide() end
    if macro_out_img then macro_out_img:hide() end
    if macro_body_thumb then macro_body_thumb:hide() end
    if drag_icon then drag_icon:hide() end
    if scroll_thumb then scroll_thumb:hide() end
    render_picker()
    render_apick()
    redraw_count = redraw_count + 1
end

local function redraw()
    drag.bar.vis = false
    if not (ready and open and shown and settings) then
        if not drag.menu_hidden then hide_all(); drag.menu_hidden = true end
        return
    end
    drag.menu_hidden = false

    if picker.open or dd.open then redraw_modal(); return end

    local x, y = settings.Pos.X, settings.Pos.Y

    panel_bg:size(W, H); panel_bg:pos(x, y); panel_bg:show()

    put_b(title_t, C.title .. 'XivUI Menu' .. C.cr, x + math.floor(16 * D._ms), y, 15)
    draw_job_cluster(x, y)
    put_b(close_t, C.gray .. 'X' .. C.cr, x + W - math.floor(26 * D._ms), y, 13)

    local railw = D.rail_w - math.floor(14 * D._ms)
    local pad2, pad4 = math.floor(2 * D._ms), math.floor(4 * D._ms)
    local rx, ry, ih = x + math.floor(8 * D._ms), y + D.title_h + math.floor(6 * D._ms), math.floor(26 * D._ms)
    rail_rects = {}
    local sel_shown, hov_shown = false, false
    for i, item in ipairs(rail_items) do
        local iy = ry + (i - 1) * ih
        rail_rects[i] = { x = rx, y = iy, w = railw, h = ih, key = item.key }
        if item.key == selected_rail then
            rail_hl_sel:size(railw, ih - pad4); rail_hl_sel:pos(rx, iy + pad2); rail_hl_sel:show(); sel_shown = true
        elseif item.key == hovered_rail then
            rail_hl_hover:size(railw, ih - pad4); rail_hl_hover:pos(rx, iy + pad2); rail_hl_hover:show(); hov_shown = true
        end
        put(rail_texts[i], C.rail .. item.label .. C.cr, rx + math.floor(12 * D._ms), cen_y(iy + pad2, ih - pad4, 13, 1))
    end
    if not sel_shown then rail_hl_sel:hide() end
    if not hov_shown then rail_hl_hover:hide() end

    local cx = x + D.rail_w + D.margin
    local cw = W - D.rail_w - D.margin - D.content_r
    local by_banner = y + D.title_h + math.floor(12 * D._ms)
    banner_bg:size(cw, D.banner_h); banner_bg:pos(cx, by_banner); banner_bg:show()
    local BANNER_LABEL = { actions = 'ACTIONS', macros = 'MACROS', choice = 'CHOICE', autogen = 'AUTOGEN', config = 'CONFIG' }
    local BANNER_SUB   = {
        actions = 'List of actions that can be assigned to the hotbar.',
        macros  = 'Build a custom hotbar slot or macro, then drag it to the hotbar.',
        choice  = 'Build multi-action choice slots.',
        autogen = 'Auto-fill bars per job. Toggle off to restore your manual setup.',
        config  = 'XivUI and hotbar settings.',
    }
    put(banner_t, C.banner .. (BANNER_LABEL[selected_rail] or 'ACTIONS') .. C.cr, cx + math.floor(14 * D._ms), cen_y(by_banner, D.banner_h, 14))
    if selected_rail == 'macros' then
        wip_t.v = 'WIP'; wip_t:pos(cx + math.floor(106 * D._ms), cen_y(by_banner, D.banner_h, 14) + math.floor(5 * D._ms)); wip_t:show()
    else
        wip_t:hide()
    end
    put(subtitle_t, C.sub .. (BANNER_SUB[selected_rail] or '') .. C.cr,
        cx + pad2, by_banner + D.banner_h + math.floor(8 * D._ms))

    local gy = by_banner + D.banner_h + math.floor(40 * D._ms)
    local view_h = (y + H - math.floor(12 * D._ms)) - gy
    if selected_rail == 'actions' then
        hide_macro_form(); hint_t:hide()
        ensure_catalog()
        render_sections(cx, gy, cw, view_h)
        draw_scrollbar(content_total, view_h, scroll_y, x, y, function(v) scroll_y = v end)
    elseif selected_rail == 'macros' then
        hide_action_grid(); hint_t:hide()
        render_macros(cx, gy, cw, view_h)
        draw_scrollbar(macro.total, view_h, macro.scroll, x, y, function(v) macro.scroll = v end)
    elseif selected_rail == 'config' then
        hide_macro_form()
        render_config(cx, gy, cw, view_h)
        draw_scrollbar(cfg.total, view_h - math.floor(46 * D._ms), cfg.scroll, x, y, function(v) cfg.scroll = v end)
    elseif selected_rail == 'autogen' then
        hint_t:hide(); hide_macro_extras()
        if dd.autogen_render then dd.autogen_render(cx, gy, cw, view_h, x, y) end
    else
        hint_t:hide(); hide_macro_extras()
        if dd.choice_render then dd.choice_render(cx, gy, cw, view_h, x, y) end
    end

    panel_rect = { x = x, y = y, w = W, h = H }
    title_rect = { x = x, y = y, w = W - math.floor(40 * D._ms), h = D.title_h }
    close_rect = { x = x + W - math.floor(30 * D._ms), y = y + math.floor(8 * D._ms), w = math.floor(22 * D._ms), h = math.floor(22 * D._ms) }

    render_apick()
    render_picker()
    redraw_count = redraw_count + 1
end

local function set_open(v)
    if _G.xivui_dbg and (open ~= v) then _G.xivui_dbg('menu', 'menu ' .. (v and 'opened' or 'closed')) end
    open = v
    cfg.capturing = false; cfg.shift_held = false
    drag.bar.dragging = false
    if open then
        if settings then apply_scale(settings.Scale) end
        ensure_position()
    else dd.open = false; hide_all(); set_alt(false); hide_tip(); close_picker(); drag.cam(false); drag.holding = false end
end

function xivuimenu.is_hud_open()
    local hud = require('components/xivuimenu/hud')
    return hud.open == true
end

function xivuimenu.on_keyboard(key, down)
    local hud = require('components/xivuimenu/hud')
    if hud.open and hud.on_keyboard then return hud.on_keyboard(key, down) end
    if cfg.capturing and open and shown then
        if key == 42 or key == 54 then cfg.shift_held = down; return true end
        if not down then return true end
        cfg.capturing = false
        if key ~= 1 then
            local hb = require('components/xivhotbar3/xivhotbar3')
            if hb.hud_set_choice_key_dik then hb.hud_set_choice_key_dik(key, cfg.shift_held == true) end
        end
        cfg.shift_held = false
        return true
    end
    return false
end

function xivuimenu.on_prerender()
    if not ready then return end
    local hud = require('components/xivuimenu/hud')
    if hud.maybe_apply_defaults then pcall(hud.maybe_apply_defaults) end
    if hud.open then hud.render() end
    if open and shown and selected_rail == 'macros' then poll_import() end
    redraw()
    if tip and tip_info and tip_refresh > 0 then
        tip:show(tip_info, tip_px, tip_py)
        tip_refresh = tip_refresh - 1
    end
end

local function begin_drag(entry, ux, uy)
    drag.active = true
    drag.entry  = entry
    drag.row, drag.slot = nil, nil
    hotbar.set_drag_block(true)
    set_alt(false)
    hide_tip()
    if drag_icon then
        drag_icon:path(entry.icon or (ART .. 'icon_placeholder.png'))
        drag_icon:size(40, 40); drag_icon:pos(ux - 20, uy - 20); drag_icon:alpha(210); drag_icon:show()
    end
end

local function update_drag(ux, uy, sx, sy)
    local r, c, bx, by, bw, bh = hotbar.slot_box_at(sx, sy)
    drag.row, drag.slot = r, c
    if not drag_icon then return end
    if r and bx then
        drag_icon:size(bw, bh); drag_icon:pos(bx, by); drag_icon:alpha(255)
    else
        drag_icon:size(40, 40); drag_icon:pos(ux - 20, uy - 20); drag_icon:alpha(210)
    end
    drag_icon:show()
end

local function end_drag(sx, sy)
    if drag.active and drag.entry then
        local e = drag.entry
        local ok, err
        if e.section and hotbar.assign_expand_action then
            ok, err = pcall(hotbar.assign_expand_action, sx or -1, sy or -1, e.section,
                { type = e.type, action = e.name, target = e.target or default_target(e),
                  alias = e.alias, icon = e.icon_save })
        else
            ok, err = pcall(hotbar.assign_action, sx or -1, sy or -1,
                { type = e.type, action = e.name, target = e.target or default_target(e),
                  alias = e.alias, icon = e.icon_save })
        end
        if not ok then log('xivuimenu: drop failed: ' .. tostring(err)) end
    end
    drag.active = false
    drag.entry  = nil
    drag.row, drag.slot = nil, nil
    hotbar.set_drag_block(false)
    if drag_icon then drag_icon:hide() end
end

local function picker_mouse(mtype, ux, uy, delta)
    local over_pick = in_rect(ux, uy, pick_rect)
    set_alt(over_pick)
    if grab_img then grab_img:hide() end
    if cursor_img then
        if over_pick then cursor_img:size(D.cursor_w, D.cursor_h); cursor_img:pos(ux - D.cursor_hx, uy - D.cursor_hy); cursor_img:show()
        else cursor_img:hide() end
    end
    hovered_thumb = nil
    for _, r in ipairs(pick_rects) do if in_rect(ux, uy, r) then hovered_thumb = r; break end end
    if mtype == 10 then
        picker.scroll = math.max(0, picker.scroll + (delta > 0 and -50 or 50)); return true
    elseif mtype == 1 then
        if in_rect(ux, uy, pick_close_rect) then close_picker(); return true end
        for _, r in ipairs(pick_hdr_rects) do
            if in_rect(ux, uy, r) then picker.collapsed[r.folder] = not picker.collapsed[r.folder]; return true end
        end
        if hovered_thumb then
            if picker.key == 'macro_icon' then
                macro.icon = hovered_thumb.value; macro.icon_abs = nil; macro_icon_cur, macro_out_cur = nil, nil
            elseif picker.key == 'choice_icon' then
                if dd.choice_set_icon then dd.choice_set_icon(hovered_thumb.value) end
            else
                iconpicker.set(picker.key, hovered_thumb.value)
                cat_sig = nil
            end
            close_picker(); return true
        end
        if not in_rect(ux, uy, pick_rect) then close_picker() end
    end
    return true
end

local function macro_mouse(mtype, ux, uy, delta)
    hovered_macro = nil
    for _, r in ipairs(macro_rects) do if in_rect(ux, uy, r) then hovered_macro = r; break end end
    if mtype == 10 then
        if hovered_macro and hovered_macro.kind == 'body' then
            macro.bodyscroll = math.max(0, macro.bodyscroll + (delta > 0 and -1 or 1))
        else
            macro.scroll = math.max(0, macro.scroll + (delta > 0 and -45 or 45))
        end
        return true
    end

    local has_action = (macro.kind == 'macro' and macro.body ~= '')
        or (macro.kind == 'input' and macro.cmd ~= '')
        or (macro.kind ~= 'macro' and macro.kind ~= 'input' and macro.action ~= '')
    if mtype == 1 and macro_out_rect and in_rect(ux, uy, macro_out_rect) and has_action then
        begin_drag(macro_entry(), ux, uy); return true
    end
    if mtype == 1 and hovered_macro then
        local r = hovered_macro
        if r.kind == 'action' then
            if macro.kind == 'input' then
                log('XivUI Menu: edit the [command] section in ' .. IMPORT_FILE)
            else
                open_apick()
            end
            return true
        end
        if r.kind == 'body' or r.kind == 'alias' then
            log('XivUI Menu: edit the [' .. (r.kind == 'body' and 'macro' or 'alias') ..
                '] section in ' .. IMPORT_FILE)
            return true
        end
        if r.kind == 'kind' then
            macro.kind = r.val
            local is_slot = false
            for _, s in ipairs(MD.EQUIP_SLOTS) do if s.k == macro.target then is_slot = true; break end end
            if r.val == 'use_equip' and not is_slot then macro.target = 'ring1'; macro.action = ''
            elseif r.val ~= 'use_equip' and is_slot then macro.target = 'me' end
            return true
        end
        if r.kind == 'target' then
            if macro.kind == 'use_equip' and macro.target ~= r.val then macro.action = '' end
            macro.target = r.val; return true
        end
        if r.kind == 'more' then macro_more = not macro_more; return true end
        if r.kind == 'icon' then
            local now = os.clock()
            if last_icon_click.key == 'macro_icon' and (now - last_icon_click.t) < 0.45 then
                last_icon_click.t = 0; open_picker('macro_icon', { name = 'Macro' })
            else last_icon_click = { t = now, key = 'macro_icon' } end
            return true
        end
        return true
    end
    return false
end

local function update_tooltip(hov_icon, ux, uy)
    if hov_icon == tip_entry then return end
    tip_entry = hov_icon
    tip_info = nil
    if hov_icon and tip then
        if database.ma and next(database.ma) == nil and database.import then
            pcall(database.import, database)
        end
        local info = formatter.build_action_info(database, { type = hov_icon.type, action = hov_icon.name })
        if info then
            info.icon_path = hov_icon.icon or (ART .. 'icon_placeholder.png')
            if info.recast_id and not info.recast then
                local cached = recast_cache.get and recast_cache.get(info.recast_id)
                info.recast = (cached and formatter.fmt_time(cached)) or '?'
            end
            if hov_icon.status and hov_icon.status ~= 'ok' then
                info.unusable = hov_icon.reason or MD.UNUSABLE_REASON[hov_icon.status]
            end
            tip_info, tip_px, tip_py = info, ux + 20, uy + 8
            tip_refresh = 4
            tip:show(info, tip_px, tip_py)
        elseif tip then
            tip:hide()
        end
    elseif tip then
        tip:hide()
    end
end

function xivuimenu.on_mouse(mtype, x, y, delta, blocked)
    local hud = require('components/xivuimenu/hud')
    if hud.open then
        return hud.on_mouse(mtype, x, y, delta)
    end
    if not (ready and open and settings) then
        if drag.active then end_drag(-1, -1) end
        set_alt(false); hide_tip()
        if cursor_img then cursor_img:hide() end
        if grab_img then grab_img:hide() end
        if drag_icon then drag_icon:hide() end
        mouse_down = false
        drag.cam(false); drag.holding = false
        return false
    end
    local ux, uy = ui_bounds.to_ui(x, y)

    if mtype == 1 then drag.cam(true); drag.holding = true
    elseif mtype == 2 then drag.cam(false); drag.holding = false end

    if picker.open then return picker_mouse(mtype, ux, uy, delta) end
    if dd.open then return apick_mouse(mtype, ux, uy, delta) end

    if blocked then
        if drag.active then end_drag(-1, -1) end
        set_alt(false); hide_tip()
        if cursor_img then cursor_img:hide() end
        if grab_img then grab_img:hide() end
        if drag_icon then drag_icon:hide() end
        mouse_down = false
        drag.cam(false); drag.holding = false
        return false
    end

    if drag.active then
        hide_tip()
        if cursor_img then cursor_img:hide() end
        if grab_img then grab_img:hide() end
        if mtype == 2 then end_drag(x, y)
        elseif mtype == 0 then update_drag(ux, uy, x, y) end
        return true
    end

    if drag_state.dragging then
        hide_tip()
        if cursor_img then cursor_img:hide() end
        if grab_img then grab_img:size(D.grab_w, D.grab_h); grab_img:pos(ux - D.grab_hx, uy - D.grab_hy); grab_img:show() end
        if mtype == 0 then
            settings.Pos.X, settings.Pos.Y = math.floor(ux - drag_state.ox), math.floor(uy - drag_state.oy)
        elseif mtype == 2 then
            settings.Pos.X, settings.Pos.Y = math.floor(ux - drag_state.ox), math.floor(uy - drag_state.oy)
            drag_state.dragging = false; config.save(settings)
        end
        drag.panel_drag = drag_state.dragging
        return true
    end

    local sbar = drag.bar
    local function sb_apply(uyy)
        local travel = math.max(1, sbar.trk_h - sbar.th)
        local ny = math.max(0, math.min(travel, uyy - sbar.track_y - sbar.off))
        sbar.set(ny / travel * math.max(0, sbar.total - sbar.viewport))
    end
    if sbar.dragging then
        if mtype == 0 and sbar.vis and sbar.set then sb_apply(uy) end
        if mtype == 2 then sbar.dragging = false end
        return true
    end
    if mtype == 1 and sbar.vis and sbar.set
       and ux >= sbar.track_x - 7 and ux <= sbar.track_x + 11
       and uy >= sbar.track_y and uy <= sbar.track_y + sbar.trk_h then
        if uy >= sbar.thumb_y and uy <= sbar.thumb_y + sbar.th then
            sbar.off = uy - sbar.thumb_y
        else
            sbar.off = sbar.th / 2; sb_apply(uy)
        end
        sbar.dragging = true
        return true
    end

    local over = in_rect(ux, uy, panel_rect)
    set_alt(over)

    if mtype == 1 then mouse_down = true elseif mtype == 2 then mouse_down = false end

    if cursor_img and grab_img then
        if over then
            local cur, w, h, hx, hy
            if mouse_down then cur, w, h, hx, hy = grab_img, D.grab_w, D.grab_h, D.grab_hx, D.grab_hy
            else cur, w, h, hx, hy = cursor_img, D.cursor_w, D.cursor_h, D.cursor_hx, D.cursor_hy end
            cur:size(w, h); cur:pos(ux - hx, uy - hy); cur:show()
            ;(mouse_down and cursor_img or grab_img):hide()
        else
            cursor_img:hide(); grab_img:hide()
        end
    end

    hovered_rail = nil
    for _, r in ipairs(rail_rects) do
        if in_rect(ux, uy, r) then hovered_rail = r.key; break end
    end

    if selected_rail == 'macros' then
        if macro_mouse(mtype, ux, uy, delta) then return true end
    end

    if selected_rail == 'choice' and dd.choice_mouse then
        if dd.choice_mouse(mtype, ux, uy, delta) then return true end
    end

    if selected_rail == 'autogen' and dd.autogen_mouse then
        if dd.autogen_mouse(mtype, ux, uy, delta) then return true end
    end

    if selected_rail == 'config' then
        if mtype == 10 then
            cfg.scroll = math.max(0, cfg.scroll + (delta > 0 and -30 or 30)); return true
        elseif mtype == 1 then
            for _, r in ipairs(cfg.hdr_rects) do
                if in_rect(ux, uy, r) then cfg.collapsed[r.cat] = not cfg.collapsed[r.cat]; cfg._vit = nil; return true end
            end
            for _, r in ipairs(cfg.rects) do
                if in_rect(ux, uy, r) then
                    local it = r.item
                    if it.kind == 'choice' then
                        local cur, idx = it.get(), 1
                        for i, o in ipairs(it.options) do if o == cur then idx = i; break end end
                        it.set(it.options[(idx % #it.options) + 1])
                    elseif it.kind == 'keybind' then
                        it.set()
                    elseif it.kind == 'button' then
                        it.set()
                    else
                        it.set(not it.get())
                    end
                    return true
                end
            end
        end
    end

    hovered_card = nil
    local hov_icon = nil
    if selected_rail == 'actions' then
        for _, r in ipairs(card_rects) do
            if in_rect(ux, uy, r) then
                hovered_card = r.entry
                if r.ix and ux >= r.ix and ux <= r.ix + r.iw and uy >= r.iy and uy <= r.iy + r.ih then
                    hov_icon = r.entry
                end
                break
            end
        end
    end
    update_tooltip(hov_icon, ux, uy)

    if mtype == 1 and hov_icon then
        local key = hov_icon.type .. '|' .. tostring(hov_icon.name):lower()
        local now = os.clock()
        if last_icon_click.key == key and (now - last_icon_click.t) < 0.45 then
            last_icon_click.t = 0
            open_picker(key, hov_icon)
            return true
        end
        last_icon_click = { t = now, key = key }
        if hov_icon.learned then begin_drag(hov_icon, ux, uy); return true end
    end

    if mtype == 1 and selected_rail == 'actions' then
        for _, r in ipairs(header_rects) do
            if in_rect(ux, uy, r) then
                collapsed[r.cat] = not collapsed[r.cat]
                return true
            end
        end
    end

    if mtype == 10 then
        scroll_y = math.max(0, scroll_y + (delta > 0 and -45 or 45))
        return true
    end

    if mtype == 1 and in_rect(ux, uy, close_rect) then
        set_open(false)
        config.save(settings)
        return true
    end

    if mtype == 1 and hovered_rail then
        if hovered_rail == 'hudlayout' then
            hud.open_editor(); set_open(false); return true
        end
        if selected_rail ~= hovered_rail then dd.open = false end
        if hovered_rail == 'actions' then cat_sig = nil end
        selected_rail = hovered_rail
        return true
    end

    local handled = draggable.handle(drag_state, mtype, x, y, {
        bounds = function(u, v) return in_rect(u, v, title_rect) end,
        get    = function() return settings.Pos.X, settings.Pos.Y end,
        set    = function(nx, ny) settings.Pos.X = nx; settings.Pos.Y = ny end,
        save   = function() config.save(settings) end,
    })
    drag.panel_drag = drag_state.dragging
    if handled then return true end

    if in_rect(ux, uy, panel_rect) then return true end
    return false
end

;(function()
    local choice_groups = require('components/xivhotbar3/lib/choice_groups')
    local CHOICE_KINDS = { { k = 'ja', l = 'Ability' }, { k = 'ma', l = 'Spell' },
                           { k = 'ws', l = 'Wpn Skill' }, { k = 'item', l = 'Item' } }
    local cm = { tab = 'maker', maker_mode = 'smart', editing = nil, scroll = 0, total = 0,
                 list = nil, smart_list = nil, smart_sig = nil, rects = {}, sub_rects = {}, out_rect = nil,
                 ex_trigger = nil, ex_pending = nil }

    local function cm_player() return windower.ffxi.get_player() end

    local function cm_job_sig()
        local p = windower.ffxi.get_player()
        if not p then return cm.last_sig or '' end
        cm.last_sig = tostring(p.main_job) .. tostring(p.main_job_level) .. '/' ..
                      tostring(p.sub_job) .. tostring(p.sub_job_level)
        return cm.last_sig
    end

    local function cm_icon_rel(icon_path)
        if not icon_path or icon_path == '' then return nil end
        local rel = tostring(icon_path):gsub('\\', '/'):gsub('.*assets/components/hotbar/icons/', ''):gsub('%.png$', '')
        if rel == '' then return nil end
        return rel
    end

    local function open_choice_apick(kind, dest)
        dd.dest = dest or 'choice'
        dd.kind = kind
        dd.groups = apick_list(kind)
        if #dd.groups == 0 then dd.open = false; return end
        dd.collapsed = {}
        for _, g in ipairs(dd.groups) do dd.collapsed[g.category] = true end
        dd.scroll = 0
        dd.open = true
    end

    function dd.choice_add_entry(kind, name, icon_path, e)
        if not cm.editing or not name or name == '' then return end
        local short = (_G.shorten_ability_name and _G.shorten_ability_name(name)) or name
        cm.editing.entries[#cm.editing.entries + 1] = {
            type = kind, action = name,
            target = default_target(e or { type = kind }),
            alias = short, icon = cm_icon_rel(icon_path),
        }
        choice_groups:save_user_group(cm_player(), cm.editing)
    end

    function dd.expand_set_pending(kind, name, icon_path, e)
        if not name or name == '' then return end
        local short = (_G.shorten_ability_name and _G.shorten_ability_name(name)) or name
        cm.ex_pending = { type = kind, name = name, alias = short,
            icon_abs = icon_path, icon_rel = cm_icon_rel(icon_path),
            target = default_target(e or { type = kind }) }
        macro_out_cur = nil
    end

    function dd.choice_set_icon(value)
        if not cm.editing then return end
        cm.editing.icon = value; cm.editing.icon_cur = nil; macro_out_cur = nil
        if cm.editing.is_smart then
            choice_groups:set_icon_override(cm_player(), cm.editing.action, value)
        else
            choice_groups:save_user_group(cm_player(), cm.editing)
        end
    end

    function dd.choice_render(cx, gy, cw, view_h, px, py)
        cm.rects, cm.sub_rects, cm.out_rect = {}, {}, nil
        local ms, mf = D._ms or 1, math.floor
        local ci, ti = 0, 0
        local SR, CH = mf(20 * ms), mf(24 * ms)
        local left, right = cx, cx + cw - SR
        local gw = cw - SR
        local cabot = gy + view_h

        local function lbl(s, x, y, color)
            if ti >= #macro_texts then return end
            ti = ti + 1; put(macro_texts[ti], (color or C.sub) .. s .. C.cr, x, y)
        end
        local CHIP_PAD = mf(18 * ms)
        local function chipw(s) return mf(glyph_width(s) * ms) + CHIP_PAD end
        local function chip(s, x, y, sel)
            if ci >= #macro_chips then return chipw(s) end
            ci = ci + 1; local c = macro_chips[ci]
            local w = chipw(s)
            local sfx = sel and '_on' or ''
            local lp = ART..'chip'..sfx..'_l.png'
            if c.pcur ~= lp then
                c.lc:path(lp); c.mc:path(ART..'chip'..sfx..'_m.png'); c.rc:path(ART..'chip'..sfx..'_r.png'); c.pcur = lp
            end
            local cap = mf(8 * ms)
            c.bg:hide()
            c.lc:size(cap, CH); c.lc:pos(x, y); c.lc:show()
            c.rc:size(cap, CH); c.rc:pos(x + w - cap, y); c.rc:show()
            c.mc:size(math.max(1, w - 2 * cap), CH); c.mc:pos(x + cap, y); c.mc:show()
            put(c.text, (sel and C.card_name_on or C.chip_off) .. s .. C.cr,
                x + mf(CHIP_PAD / 2), cen_y(y, CH, 11))
            return w
        end

        if cm.icon_map_sig ~= cm_job_sig() then
            ensure_catalog()
            local m = {}
            for _, ce in ipairs(cat or {}) do
                if ce.name and ce.icon then m[tostring(ce.type or '') .. '|' .. tostring(ce.name):lower()] = ce.icon end
            end
            cm.icon_map = m; cm.icon_map_sig = cm_job_sig()
        end
        local function action_icon(e)
            if not e then return nil end
            local key = tostring(e.type or '') .. '|' .. tostring(e.action or ''):lower()
            return (cm.icon_map and cm.icon_map[key]) or (e.icon and iconpicker.path(e.icon)) or nil
        end

        local SUBS = { { k = 'maker', l = 'Choice Maker' }, { k = 'expand', l = 'Dynamic Pet Slots' },
                       { k = 'toggle', l = 'Drag Toggle' } }
        local sx = left
        for _, s in ipairs(SUBS) do
            local w = chip(s.l, sx, gy, cm.tab == s.k)
            cm.sub_rects[#cm.sub_rects + 1] = { x = sx, y = gy, w = w, h = CH, val = s.k }
            sx = sx + w + mf(8 * ms)
        end

        local y = gy + mf(40 * ms)
        local items, total, grid_y = nil, 0, nil
        local out_shown = false

        if cm.tab == 'expand' then
            lbl('Dynamic Pet Slots', left, y, C.banner); y = y + mf(22 * ms)
            lbl('A "pet bar" is a set of slots that pop onto your hotbar while a pet is out and', left, y, C.gray); y = y + mf(16 * ms)
            lbl('vanish when it leaves — pet commands for BST / SMN / PUP / DRG / etc.', left, y, C.gray); y = y + mf(24 * ms)
            local trigs = (hotbar.expand_triggers and hotbar.expand_triggers()) or {}
            if #trigs == 0 then
                lbl('No pet bars for your job yet. Bring a pet out (charm, summon, activate) and it', left, y, C.gray); y = y + mf(16 * ms)
                lbl('will appear here as a bar you can fill.', left, y, C.gray)
            else
                lbl('Step 1  —  Pick the pet bar', left, y, C.name); y = y + mf(20 * ms)
                local tx, ty2 = left, y
                for _, t in ipairs(trigs) do
                    local cap = t.note and (t.section .. ' (' .. t.note .. ')') or t.section
                    local w = chipw(cap)
                    if tx > left and tx + w > right then tx = left; ty2 = ty2 + mf(30 * ms) end
                    chip(cap, tx, ty2, cm.ex_trigger == t.section)
                    cm.rects[#cm.rects + 1] = { kind = 'extrig', val = t.section, x = tx, y = ty2, w = w, h = CH }
                    tx = tx + w + mf(8 * ms)
                end
                y = ty2 + mf(34 * ms)
                if cm.ex_trigger then
                    local still = false
                    for _, t in ipairs(trigs) do if t.section == cm.ex_trigger then still = true; break end end
                    if not still then cm.ex_trigger, cm.ex_pending = nil, nil end
                end
                if not cm.ex_trigger then
                    lbl('Click a pet bar above to begin.', left, y, C.gray)
                else
                    lbl('Step 2  —  Pick an action (opens a picker)', left, y, C.name); y = y + mf(20 * ms)
                    local ax = left
                    for _, kd in ipairs(CHOICE_KINDS) do
                        local w = chip(kd.l, ax, y, false)
                        cm.rects[#cm.rects + 1] = { kind = 'exkind', val = kd.k, x = ax, y = y, w = w, h = CH }
                        ax = ax + w + mf(8 * ms)
                    end
                    y = y + mf(30 * ms)
                    if cm.ex_pending then
                        local p = cm.ex_pending
                        local OS = mf(48 * ms)
                        lbl('Step 3  —  Drag this onto the hotbar slot it should use:', left, y + mf(2 * ms), C.name)
                        lbl(p.name, left, y + mf(22 * ms), C.card_name_on)
                        local ip = p.icon_abs or (ART .. 'icon_frame.png')
                        if macro_out_cur ~= ip then macro_out_img:path(ip); macro_out_img:fit(true); macro_out_cur = ip end
                        macro_out_img:size(OS, OS); macro_out_img:pos(right - OS, y); macro_out_img:alpha(255); macro_out_img:show()
                        cm.out_rect = { x = right - OS, y = y, w = OS, h = OS, expand = true }
                        out_shown = true
                        y = y + OS + mf(10 * ms)
                    else
                        lbl('Then drag the chosen action onto a real hotbar slot on screen.', left, y, C.gray); y = y + mf(22 * ms)
                    end
                    lbl('On this pet bar (X removes):', left, y, C.sub); y = y + mf(22 * ms)
                    local ents = (hotbar.expand_section_entries and hotbar.expand_section_entries(cm.ex_trigger)) or {}
                    items = {}
                    for i, e in ipairs(ents) do
                        items[#items + 1] = { kind = 'c', col = (i - 1) % 2, vy = math.floor((i - 1) / 2) * (D.card_h + D.card_gap),
                            entry = { icon = action_icon(e), name = (e.type ~= 'choice' and e.action ~= '' and e.action) or e.alias or e.action,
                                      sub = 'bar ' .. tostring(e.row) .. '  slot ' .. tostring(e.slot), learned = true },
                            hit = { kind = 'exentry', del = 'exdel', dele = e } }
                    end
                    total = math.ceil(#ents / 2) * (D.card_h + D.card_gap)
                    grid_y = y
                    if #ents == 0 then lbl('Empty — do steps 2 and 3 to add your first action.', left, y, C.gray) end
                end
            end
        elseif cm.tab == 'toggle' then
            lbl('Choice Drag Toggle', left, y, C.banner); y = y + mf(24 * ms)
            lbl('When on, dropping an action onto an occupied hotbar slot - dragged from another', left, y, C.gray); y = y + mf(18 * ms)
            lbl('slot or from this menu - merges the two into a choice slot.', left, y, C.gray); y = y + mf(26 * ms)
            local on = (hotbar.get_choice_drag_merge and hotbar.get_choice_drag_merge()) == true
            local woff = chip('Off', left, y, not on)
            cm.rects[#cm.rects + 1] = { kind = 'dragmerge', val = false, x = left, y = y, w = woff, h = CH }
            local won = chip('On', left + woff + mf(8 * ms), y, on)
            cm.rects[#cm.rects + 1] = { kind = 'dragmerge', val = true, x = left + woff + mf(8 * ms), y = y, w = won, h = CH }
            y = y + mf(36 * ms)
            lbl('Dropping onto one of your custom choice slots adds the action to it instead.', left, y, C.gray); y = y + mf(18 * ms)
            lbl('Built-in choice slots and macros still swap. Merged choices appear under', left, y, C.gray); y = y + mf(18 * ms)
            lbl('Choice Maker > Manual, where their icon and actions can be edited.', left, y, C.gray)
        elseif not cm.editing then
            local MODES = { { k = 'smart', l = 'Smart Assist' }, { k = 'manual', l = 'Manual' } }
            local mx = left
            for _, m in ipairs(MODES) do
                local w = chip(m.l, mx, y, cm.maker_mode == m.k)
                cm.rects[#cm.rects + 1] = { kind = 'mode', val = m.k, x = mx, y = y, w = w, h = CH }
                mx = mx + w + mf(8 * ms)
            end
            y = y + mf(36 * ms)

            if cm.maker_mode == 'smart' then
                lbl('Choices for your job — click one to preview, set an icon and drag it to a bar.', left, y, C.gray); y = y + mf(24 * ms)
                local sig = cm_job_sig()
                if cm.smart_sig ~= sig then
                    cm.smart_list = (hotbar.choice_autogen_list and hotbar.choice_autogen_list()) or {}
                    cm.smart_sig = sig
                end
                local pl = cm_player()
                items = {}
                for i, e in ipairs(cm.smart_list) do
                    local ov = choice_groups:get_icon_override(pl, e.action)
                    local ic = (ov and iconpicker.path(ov))
                        or action_icon({ type = e.rep_type, action = e.rep_action })
                        or (e.icon and iconpicker.path(e.icon)) or nil
                    items[#items + 1] = { kind = 'c', col = (i - 1) % 2, vy = math.floor((i - 1) / 2) * (D.card_h + D.card_gap),
                        entry = { icon = ic, name = e.label, sub = 'click to preview', learned = true },
                        hit = { kind = 'smart', action = e.action, label = e.label } }
                end
                total = math.ceil(#cm.smart_list / 2) * (D.card_h + D.card_gap)
                grid_y = y
                if #cm.smart_list == 0 then lbl('No choices for your current job.', left, y, C.gray) end
            else
                cm.list = choice_groups:user_groups_list(cm_player())
                local wn = chip('+ New Choice', left, y, false)
                cm.rects[#cm.rects + 1] = { kind = 'newchoice', x = left, y = y, w = wn, h = CH }
                y = y + mf(36 * ms)
                items = {}
                for i, g in ipairs(cm.list) do
                    local n = #g.entries
                    local gic = (g.icon and iconpicker.path(g.icon)) or action_icon(g.entries[1]) or nil
                    items[#items + 1] = { kind = 'c', col = (i - 1) % 2, vy = math.floor((i - 1) / 2) * (D.card_h + D.card_gap),
                        entry = { icon = gic, name = g.label, sub = n .. (n == 1 and ' action' or ' actions'), learned = true },
                        hit = { kind = 'group', id = g.id, del = 'groupdel', delid = g.id } }
                end
                total = math.ceil(#cm.list / 2) * (D.card_h + D.card_gap)
                grid_y = y
                if #cm.list == 0 then lbl('No custom choices yet — click "New Choice" to build one.', left, y, C.gray) end
            end
        else
            local ed = cm.editing
            local wb = chip('< Back', left, y, false)
            cm.rects[#cm.rects + 1] = { kind = 'back', x = left, y = y, w = wb, h = CH }
            y = y + mf(34 * ms)
            lbl('Name', left, y, C.sub); lbl(ed.label, left + mf(60 * ms), y, C.card_name_on); y = y + mf(26 * ms)
            lbl('Icon  (double-click to choose)', left, y, C.sub); lbl('Drag to a slot', right - mf(120 * ms), y, C.sub); y = y + mf(20 * ms)
            local IS, OS = mf(44 * ms), mf(48 * ms)
            local ip = (ed.icon and iconpicker.path(ed.icon)) or (ART .. 'icon_frame.png')
            if ed.icon_cur ~= ip then macro_icon_img:path(ip); macro_icon_img:fit(true); ed.icon_cur = ip end
            macro_icon_img:size(IS, IS); macro_icon_img:pos(left, y); macro_icon_img:show()
            cm.rects[#cm.rects + 1] = { kind = 'icon', x = left, y = y, w = IS, h = IS }
            if #ed.entries > 0 then
                if macro_out_cur ~= ip then macro_out_img:path(ip); macro_out_img:fit(true); macro_out_cur = ip end
                macro_out_img:size(OS, OS); macro_out_img:pos(right - OS, y); macro_out_img:alpha(255); macro_out_img:show()
                cm.out_rect = { x = right - OS, y = y, w = OS, h = OS }
            else macro_out_img:hide() end
            y = y + OS + mf(10 * ms)
            if not ed.is_smart then
                lbl('Add action', left, y, C.sub); y = y + mf(20 * ms)
                local ax = left
                for _, kd in ipairs(CHOICE_KINDS) do
                    local w = chip(kd.l, ax, y, false)
                    cm.rects[#cm.rects + 1] = { kind = 'addkind', val = kd.k, x = ax, y = y, w = w, h = CH }
                    ax = ax + w + mf(8 * ms)
                end
                y = y + mf(30 * ms)
            end
            lbl(ed.is_smart and 'Actions in this choice' or 'Actions  (drag to reorder, X removes)', left, y, C.sub); y = y + mf(22 * ms)
            items = {}
            for i, e in ipairs(ed.entries) do
                local real = (e.type ~= 'choice' and e.action ~= '' and e.action) or e.alias or e.action
                local sub  = (e.alias and e.alias ~= '' and e.alias ~= real) and ('alias: ' .. e.alias) or ''
                items[#items + 1] = { kind = 'c', col = (i - 1) % 2, vy = math.floor((i - 1) / 2) * (D.card_h + D.card_gap),
                    entry = { icon = action_icon(e), name = real, sub = sub, learned = true },
                    hit = { kind = 'entry', del = (not ed.is_smart) and 'entrydel' or nil, delidx = i } }
            end
            total = math.ceil(#ed.entries / 2) * (D.card_h + D.card_gap)
            grid_y = y
            if #ed.entries == 0 then
                lbl(ed.is_smart and 'No usable actions right now.' or 'Add actions above, then drag the icon onto a hotbar slot.', left, y, C.gray)
            end
        end

        if items and grid_y then
            local gview = cabot - grid_y
            cm.scroll = render_card_grid(left, grid_y, gw, gview, items, 2, total, cm.scroll, cm.rects)
            cm.total = total
            local dels, n0 = {}, #cm.rects
            for i = 1, n0 do
                local r = cm.rects[i]
                if r.del then
                    r.w = r.w - mf(26 * ms)
                    lbl('X', r.x + r.w + mf(8 * ms), r.y + mf(8 * ms), '\\cs(214,120,120)')
                    dels[#dels + 1] = { kind = r.del, id = r.delid, idx = r.delidx, e = r.dele, x = r.x + r.w, y = r.y + mf(4 * ms), w = mf(26 * ms), h = mf(26 * ms) }
                end
            end
            for _, d in ipairs(dels) do cm.rects[#cm.rects + 1] = d end
            if px then draw_scrollbar(total, gview, cm.scroll, px, py, function(v) cm.scroll = v end) else scroll_thumb:hide() end
        else
            cm.total = 0; scroll_thumb:hide()
            for i = 1, #cards do local c = cards[i]; c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
            for i = 1, #headers do local h = headers[i]; h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
        end

        for i = ci + 1, #macro_chips do local c = macro_chips[i]; c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
        for i = ti + 1, #macro_texts do macro_texts[i]:hide() end
        if cm.editing == nil then
            macro_icon_img:hide()
            if not out_shown then macro_out_img:hide() end
        end
    end

    function dd.choice_mouse(mtype, ux, uy, delta)
        local hovered = nil
        for _, r in ipairs(cm.rects) do if in_rect(ux, uy, r) then hovered = r; break end end
        if mtype == 10 then
            cm.scroll = math.max(0, cm.scroll + (delta > 0 and -40 or 40)); return true
        end

        if cm.mv and mtype == 0 then
            if not cm.mv.drag and (math.abs(ux - cm.mv.x) + math.abs(uy - cm.mv.y)) > 6 then cm.mv.drag = true end
            if cm.mv.drag and drag_icon then
                if cm.mv.icon and cm.mv.cur ~= cm.mv.icon then drag_icon:path(cm.mv.icon); cm.mv.cur = cm.mv.icon end
                drag_icon:size(34, 34); drag_icon:pos(ux - 17, uy - 17); drag_icon:alpha(220); drag_icon:show()
            end
            return true
        end
        if cm.mv and mtype == 2 then
            local mv = cm.mv; cm.mv = nil
            if drag_icon then drag_icon:hide() end
            if mv.drag and cm.editing and not cm.editing.is_smart then
                local target
                for _, r in ipairs(cm.rects) do
                    if r.kind == 'entry' and r.delidx and r.delidx ~= mv.idx and in_rect(ux, uy, r) then target = r.delidx; break end
                end
                if target then
                    local ents = cm.editing.entries
                    local moved = table.remove(ents, mv.idx)
                    if moved then
                        local tgt = (mv.idx < target) and (target - 1) or target
                        table.insert(ents, tgt, moved)
                        choice_groups:save_user_group(cm_player(), cm.editing)
                    end
                end
            end
            return true
        end

        if mtype ~= 1 then return false end

        for _, r in ipairs(cm.sub_rects) do
            if in_rect(ux, uy, r) then
                if cm.tab ~= r.val then cm.tab = r.val; cm.editing = nil; cm.ex_pending = nil; cm.mv = nil; cm.scroll = 0 end
                return true
            end
        end

        if cm.out_rect and in_rect(ux, uy, cm.out_rect) then
            if cm.out_rect.expand and cm.ex_pending and cm.ex_trigger then
                local p = cm.ex_pending
                begin_drag({ type = p.type, name = p.name, target = p.target, alias = p.alias,
                             icon = p.icon_abs, icon_save = p.icon_rel, section = cm.ex_trigger }, ux, uy)
                return true
            elseif cm.editing and #cm.editing.entries > 0 then
                local ed = cm.editing
                local gid = ed.action or ed.id
                begin_drag({ type = 'choice', name = gid, action = gid, target = '', alias = ed.label,
                             icon = (ed.icon and iconpicker.path(ed.icon)) or nil, icon_save = ed.icon }, ux, uy)
                return true
            end
        end

        if not hovered then return false end
        local r, pl = hovered, cm_player()
        if r.kind == 'mode' then
            if cm.maker_mode ~= r.val then cm.maker_mode = r.val; cm.scroll = 0 end
        elseif r.kind == 'smart' then
            local pre = (hotbar.choice_preview and hotbar.choice_preview(r.action)) or {}
            cm.editing = { action = r.action, label = r.label, is_smart = true, icon_cur = nil,
                           icon = choice_groups:get_icon_override(pl, r.action), entries = pre }
            cm.scroll = 0
        elseif r.kind == 'newchoice' then
            local id = choice_groups:new_user_group_id(pl, 'choice')
            local n = (cm.list and #cm.list or 0) + 1
            cm.editing = { id = id, label = 'Choice ' .. n, icon = nil, icon_cur = nil, entries = {} }
            choice_groups:save_user_group(pl, cm.editing)
        elseif r.kind == 'group' then
            local g = choice_groups:get_user_group(pl, r.id)
            if g then
                local es = {}
                for _, e in ipairs(g.entries) do
                    es[#es + 1] = { type = e.type, action = e.action, target = e.target, alias = e.alias, icon = e.icon }
                end
                cm.editing = { id = g._user_id, label = g.label, icon = g.icon, icon_cur = nil, entries = es }
                cm.scroll = 0
            end
        elseif r.kind == 'groupdel' then
            choice_groups:delete_user_group(pl, r.id)
            if not choice_groups:exists(r.id) and hotbar.remove_choice_slots then
                hotbar.remove_choice_slots(r.id)
            end
        elseif r.kind == 'back' then
            if cm.editing and not cm.editing.is_smart then choice_groups:save_user_group(pl, cm.editing) end
            cm.editing = nil; cm.mv = nil; cm.scroll = 0
        elseif r.kind == 'addkind' then
            open_choice_apick(r.val)
        elseif r.kind == 'extrig' then
            if cm.ex_trigger ~= r.val then cm.ex_trigger = r.val; cm.scroll = 0 end
        elseif r.kind == 'exkind' then
            open_choice_apick(r.val, 'expand')
        elseif r.kind == 'exdel' then
            if cm.ex_trigger and r.e and hotbar.remove_expand_action then
                hotbar.remove_expand_action(cm.ex_trigger, r.e)
            end
        elseif r.kind == 'dragmerge' then
            if hotbar.set_choice_drag_merge then hotbar.set_choice_drag_merge(r.val) end
        elseif r.kind == 'entry' then
            if cm.editing and not cm.editing.is_smart and r.delidx then
                cm.mv = { idx = r.delidx, x = ux, y = uy, drag = false,
                          icon = r.entry and r.entry.icon or nil, cur = nil }
            end
        elseif r.kind == 'entrydel' then
            if cm.editing and cm.editing.entries[r.idx] then
                table.remove(cm.editing.entries, r.idx)
                choice_groups:save_user_group(pl, cm.editing)
            end
        elseif r.kind == 'icon' then
            local now = os.clock()
            if last_icon_click.key == 'choice_icon' and (now - last_icon_click.t) < 0.45 then
                last_icon_click.t = 0
                open_picker('choice_icon', { name = (cm.editing and cm.editing.label) or 'Choice' })
            else
                last_icon_click = { t = now, key = 'choice_icon' }
            end
        end
        return true
    end
end)()

;(function()
    local ag = { scroll = 0, total = 0, cat = nil, data = nil, sig = nil, dirty = true, rects = {} }
    local agmv = nil

    local function ag_sig()
        local p = windower.ffxi.get_player()
        if not p then return ag.sig or '' end
        return tostring(p.main_job) .. tostring(p.main_job_level) .. '/' ..
               tostring(p.sub_job) .. tostring(p.sub_job_level)
    end

    local function ag_data()
        local sig = ag_sig()
        if ag.data and not ag.dirty and ag.sig == sig then return ag.data end
        ag.data = (hotbar.autogen_panel and hotbar.autogen_panel()) or nil
        ag.sig, ag.dirty = sig, false
        if ag.data and ag.cat then
            local still = false
            for _, c in ipairs(ag.data.cats) do if c.key == ag.cat then still = true; break end end
            if not still then ag.cat = nil end
        end
        return ag.data
    end

    function dd.autogen_render(cx, gy, cw, view_h, px, py)
        ag.rects = {}
        local ms, mf = D._ms or 1, math.floor
        local ci, ti = 0, 0
        local SR, CH = mf(20 * ms), mf(24 * ms)
        local left, right = cx, cx + cw - SR
        local gw = cw - SR
        local cabot = gy + view_h
        local function lbl(s, x, y, color)
            if ti >= #macro_texts then return end
            ti = ti + 1; put(macro_texts[ti], (color or C.sub) .. s .. C.cr, x, y)
        end
        local CHIP_PAD = mf(18 * ms)
        local function chipw(s) return mf(glyph_width(s) * ms) + CHIP_PAD end
        local function chip(s, x, y, sel)
            if ci >= #macro_chips then return chipw(s) end
            ci = ci + 1; local c = macro_chips[ci]
            local w = chipw(s)
            local sfx = sel and '_on' or ''
            local lp = ART..'chip'..sfx..'_l.png'
            if c.pcur ~= lp then
                c.lc:path(lp); c.mc:path(ART..'chip'..sfx..'_m.png'); c.rc:path(ART..'chip'..sfx..'_r.png'); c.pcur = lp
            end
            local cap = mf(8 * ms)
            c.bg:hide()
            c.lc:size(cap, CH); c.lc:pos(x, y); c.lc:show()
            c.rc:size(cap, CH); c.rc:pos(x + w - cap, y); c.rc:show()
            c.mc:size(math.max(1, w - 2 * cap), CH); c.mc:pos(x + cap, y); c.mc:show()
            put(c.text, (sel and C.card_name_on or C.chip_off) .. s .. C.cr,
                x + mf(CHIP_PAD / 2), cen_y(y, CH, 11))
            return w
        end

        local data = ag_data()
        local y = gy
        local items, total, grid_y = nil, 0, nil
        if not data then
            lbl('Autogen preview unavailable (hotbar not ready).', left, y, C.gray)
        else
            local cap = 'Autogen for ' .. data.job .. ':'
            lbl(cap, left, y + mf(5 * ms), C.sub)
            local tx = left + mf(glyph_width(cap) * ms) + mf(14 * ms)
            local woff = chip('Off', tx, y, not data.overlay)
            ag.rects[#ag.rects + 1] = { kind = 'toggle', val = false, x = tx, y = y, w = woff, h = CH }
            local won = chip('On', tx + woff + mf(8 * ms), y, data.overlay)
            ag.rects[#ag.rects + 1] = { kind = 'toggle', val = true, x = tx + woff + mf(8 * ms), y = y, w = won, h = CH }
            y = y + mf(30 * ms)
            lbl('On fills the assigned bars automatically; Off restores your manual bars untouched.', left, y, C.gray)
            y = y + mf(26 * ms)

            local cxp, cyp = left, y
            for _, c in ipairs(data.cats) do
                local capn = c.label .. (c.bar and (' [' .. c.bar .. ']') or '')
                local w = chipw(capn)
                if cxp > left and cxp + w > right then cxp = left; cyp = cyp + mf(30 * ms) end
                chip(capn, cxp, cyp, ag.cat == c.key)
                ag.rects[#ag.rects + 1] = { kind = 'cat', val = c.key, x = cxp, y = cyp, w = w, h = CH }
                cxp = cxp + w + mf(8 * ms)
            end
            y = cyp + mf(34 * ms)

            if not ag.cat then
                lbl('Pick a category to preview its actions, set its bar, and skip entries.', left, y, C.gray)
            else
                local cur_bar, cur_label = nil, ag.cat
                for _, c in ipairs(data.cats) do
                    if c.key == ag.cat then cur_bar, cur_label = c.bar, c.label end
                end
                local bcap = 'Bar for ' .. cur_label .. ':'
                lbl(bcap, left, y + mf(5 * ms), C.sub)
                local bx = left + mf(glyph_width(bcap) * ms) + mf(14 * ms)
                local wn = chip('None', bx, y, cur_bar == nil)
                ag.rects[#ag.rects + 1] = { kind = 'bar', val = 0, x = bx, y = y, w = wn, h = CH }
                bx = bx + wn + mf(6 * ms)
                for b = 1, 6 do
                    local wb = chip(tostring(b), bx, y, cur_bar == b)
                    ag.rects[#ag.rects + 1] = { kind = 'bar', val = b, x = bx, y = y, w = wb, h = CH }
                    bx = bx + wb + mf(6 * ms)
                end
                y = y + mf(30 * ms)
                lbl('Drag a card onto another to reorder. X skips an entry.', left, y, C.gray)
                y = y + mf(22 * ms)

                items = {}
                local n = 0
                for _, e in ipairs(data.entries) do
                    if e.category == ag.cat then
                        n = n + 1
                        local usable = (e.known ~= false) and (e.accessible ~= false)
                        local sub = '#' .. n .. (((e.level or 0) > 0) and ('  Lv. ' .. e.level) or '')
                        if e.excluded then sub = sub .. '  skipped' end
                        items[#items + 1] = { kind = 'c', col = (n - 1) % 2, vy = math.floor((n - 1) / 2) * (D.card_h + D.card_gap),
                            entry = { icon = (e.icon and iconpicker.path(e.icon)) or catalog.icon_for_action(e.type, e.action),
                                      name = (e.type ~= 'choice' and e.action ~= '' and e.action) or e.alias or e.action, sub = sub,
                                      learned = usable and not e.excluded,
                                      status = e.excluded and 'nosub' or nil },
                            hit = { kind = 'entry', del = 'agx', agkey = e.key } }
                    end
                end
                total = math.ceil(n / 2) * (D.card_h + D.card_gap)
                grid_y = y
                if n == 0 then lbl('Nothing in this category for ' .. data.job .. '.', left, y, C.gray) end
            end
        end

        if items and grid_y then
            local gview = cabot - grid_y
            ag.scroll = render_card_grid(left, grid_y, gw, gview, items, 2, total, ag.scroll, ag.rects)
            ag.total = total
            local dels, n0 = {}, #ag.rects
            for i = 1, n0 do
                local r = ag.rects[i]
                if r.del then
                    r.w = r.w - mf(26 * ms)
                    lbl('X', r.x + r.w + mf(8 * ms), r.y + mf(8 * ms), '\\cs(214,120,120)')
                    dels[#dels + 1] = { kind = r.del, agkey = r.agkey, x = r.x + r.w, y = r.y + mf(4 * ms), w = mf(26 * ms), h = mf(26 * ms) }
                end
            end
            for _, d in ipairs(dels) do ag.rects[#ag.rects + 1] = d end
            if px then draw_scrollbar(total, gview, ag.scroll, px, py, function(v) ag.scroll = v end) else scroll_thumb:hide() end
        else
            ag.total = 0; scroll_thumb:hide()
            for i = 1, #cards do local c = cards[i]; c.bg:hide(); c.icon:hide(); c.name:hide(); c.lv:hide() end
            for i = 1, #headers do local h = headers[i]; h.line:hide(); h.text:hide(); h.sym:hide(); if h.desc then h.desc:hide() end end
        end

        for i = ci + 1, #macro_chips do local c = macro_chips[i]; c.bg:hide(); c.text:hide(); c.lc:hide(); c.mc:hide(); c.rc:hide() end
        for i = ti + 1, #macro_texts do macro_texts[i]:hide() end
        if macro_icon_img then macro_icon_img:hide() end
        if macro_out_img then macro_out_img:hide() end
    end

    function dd.autogen_mouse(mtype, ux, uy, delta)
        if mtype == 10 then
            ag.scroll = math.max(0, ag.scroll + (delta > 0 and -40 or 40)); return true
        end

        if agmv and mtype == 0 then
            if not agmv.drag and (math.abs(ux - agmv.x) + math.abs(uy - agmv.y)) > 6 then agmv.drag = true end
            if agmv.drag and drag_icon then
                if agmv.icon and agmv.cur ~= agmv.icon then drag_icon:path(agmv.icon); agmv.cur = agmv.icon end
                drag_icon:size(34, 34); drag_icon:pos(ux - 17, uy - 17); drag_icon:alpha(220); drag_icon:show()
            end
            return true
        end
        if agmv and mtype == 2 then
            local mv = agmv; agmv = nil
            if drag_icon then drag_icon:hide() end
            if mv.drag and ag.cat and ag.data then
                local target = nil
                for _, r in ipairs(ag.rects) do
                    if r.kind == 'entry' and r.agkey and in_rect(ux, uy, r) then target = r.agkey; break end
                end
                if target and target ~= mv.key then
                    local out = {}
                    for _, e in ipairs(ag.data.entries) do
                        if e.category == ag.cat and e.key ~= mv.key then
                            if e.key == target then out[#out + 1] = mv.key end
                            out[#out + 1] = e.key
                        end
                    end
                    if hotbar.autogen_set_order then hotbar.autogen_set_order(ag.cat, out) end
                    ag.dirty = true
                end
            end
            return true
        end

        if mtype ~= 1 then return false end
        for _, r in ipairs(ag.rects) do
            if in_rect(ux, uy, r) then
                if r.kind == 'toggle' then
                    if hotbar.autogen_set_enabled then hotbar.autogen_set_enabled(r.val) end
                    ag.dirty = true
                elseif r.kind == 'cat' then
                    if ag.cat ~= r.val then ag.cat = r.val; ag.scroll = 0 end
                elseif r.kind == 'bar' then
                    if ag.cat and hotbar.autogen_set_bar then hotbar.autogen_set_bar(ag.cat, r.val) end
                    ag.dirty = true
                elseif r.kind == 'agx' then
                    if r.agkey and hotbar.autogen_toggle_exclude then hotbar.autogen_toggle_exclude(r.agkey) end
                    ag.dirty = true
                elseif r.kind == 'entry' and r.agkey then
                    agmv = { key = r.agkey, x = ux, y = uy, drag = false,
                             icon = r.entry and r.entry.icon or nil, cur = nil }
                end
                return true
            end
        end
        return false
    end
end)()

function xivuimenu.covers(x, y)
    if not (ready and shown) then return false end
    if picker.open or dd.open then return true end
    if drag.active then return true end
    if drag.panel_drag then return true end
    if drag.holding then return true end
    if open and panel_rect and in_rect(x, y, panel_rect) then return true end
    return false
end

function xivuimenu.push_bounds()
    if ready and open and shown and settings then
        ui_bounds.register('xivuimenu', settings.Pos.X, settings.Pos.Y, W, H)
        occlusion.set('xivuimenu', settings.Pos.X, settings.Pos.Y, W, H, 5)
    else
        ui_bounds.clear('xivuimenu')
        occlusion.clear('xivuimenu')
    end
end

function xivuimenu.init()
    if not settings then settings = config.load('data/xivuimenu/settings.xml', defaults) end
    build_ui()
    ensure_position()
    ensure_import_file()
    alt_held = false
    windower.send_command('setkey lalt up')
    ready = true
end

function xivuimenu.dispose()
    ready = false
    open = false
    dd.open = false
    drag.active = false; hotbar.set_drag_block(false)
    drag.cam(false); drag.holding = false
    close_picker()
    hide_all()
    set_alt(false)
    hide_tip()
    ui_bounds.clear('xivuimenu')
    occlusion.clear('xivuimenu')
end

function xivuimenu.apply_theme(id)
    local base = windower.addon_path .. 'assets/components/xivuimenu/'
    ART = base
    if id and id ~= 'ffxiv' then
        local tp = base .. 'themes/' .. id .. '/'
        local f = io.open(tp .. 'window.png', 'r')
        if f then f:close(); ART = tp end
    end
    C.swap(id)
    if panel_bg then panel_bg:path(ART .. 'window.png') end
    if banner_bg then banner_bg:path(ART .. 'banner.png') end
    if scroll_thumb then scroll_thumb:path(ART .. 'scroll_thumb.png') end
    if rail_hl_sel then rail_hl_sel:path(ART .. 'rail_hl.png') end
    if rail_hl_hover then rail_hl_hover:path(ART .. 'rail_hl.png') end
    if pick_bg then pick_bg:path(ART .. 'pick_window.png') end
    if pick_hl then pick_hl:path(ART .. 'row_hover.png') end
    if dd_bg then dd_bg:path(ART .. 'pick_window.png') end
    if macro_body_thumb then macro_body_thumb:path(ART .. 'scroll_thumb.png') end
    if cursor_img then cursor_img:path(ART .. 'cursor.png') end
    if grab_img then grab_img:path(ART .. 'cursor_grab.png') end
    cfg._vit = nil
    for i = 1, #headers do if headers[i].line then headers[i].line:path(ART .. 'section_line.png') end end
    for i = 1, #pick_headers do if pick_headers[i].line then pick_headers[i].line:path(ART .. 'section_line.png') end end
end

function xivuimenu.show()
    shown = true
end

function xivuimenu.hide()
    shown = false
    dd.open = false
    drag.active = false; hotbar.set_drag_block(false)
    close_picker()
    hide_all()
    set_alt(false)
    hide_tip()
    ui_bounds.clear('xivuimenu')
    occlusion.clear('xivuimenu')
end

function xivuimenu.handle_command(args)
    if not settings then settings = config.load('data/xivuimenu/settings.xml', defaults) end
    local cmd = args[1] and args[1]:lower() or ''
    local echo = _G.xivui_echo or log

    if cmd == '' or cmd == 'toggle' then
        set_open(not open)
        log('xivuimenu: ' .. (open and 'opened.' or 'closed.'))
    elseif cmd == 'open' then
        set_open(true)
    elseif cmd == 'close' then
        set_open(false)
    elseif cmd == 'import' then
        ensure_import_file()
        import_last = nil
        log('XivUI Menu: macro import file is ' .. IMPORT_FILE)
        if windower.open_url then pcall(windower.open_url, 'file:///' .. IMPORT_FILE:gsub('\\', '/')) end
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            settings.Pos.X, settings.Pos.Y = math.floor(x), math.floor(y)
            config.save(settings)
            log('xivuimenu: moved to ' .. settings.Pos.X .. ', ' .. settings.Pos.Y .. '.')
        else
            log('Usage: //xui menu pos <x> <y>')
        end
    elseif cmd == 'scale' then
        local sc = tonumber(args[2])
        if sc then
            settings.Scale = sc
            config.save(settings)
            if open then apply_scale(sc); ensure_position() end
            log('xivuimenu: scale ' .. string.format('%.2f', sc) .. '.')
        else
            log('Usage: //xui menu scale <factor>')
        end
    elseif cmd == 'reset' then
        settings.Pos.X, settings.Pos.Y = -99999, -99999
        ensure_position()
        config.save(settings)
        log('xivuimenu: position reset.')
    elseif cmd == 'debugpick' then
        echo(string.format('menu: open=%s rail=%s redraws=%d cards=%d', tostring(open),
            tostring(selected_rail), redraw_count, #card_rects))
        echo(string.format('picker: open=%s key=%s hdrs=%d thumbs=%d', tostring(picker.open),
            tostring(picker.key), #pick_hdr_rects, #pick_rects))
        echo(string.format('drag: active=%s dd.open=%s hud.open=%s', tostring(drag.active),
            tostring(dd.open), tostring(require('components/xivuimenu/hud').open)))
    elseif cmd == 'huddefault' or cmd == 'hudreset' then
        local hud = require('components/xivuimenu/hud')
        if hud.apply_default_layout and hud.apply_default_layout() then
            echo('xivuimenu: default HUD layout applied.')
        else
            echo('xivuimenu: could not apply the default HUD layout (not logged in?).')
        end
    else
        echo('xivuimenu commands: (no arg) toggle | open | close | pos <x> <y> | reset | huddefault')
    end
end

end

build()
return xivuimenu
