-- enemyweak: weakness icons just right of an enemy target's name on the targetbar HP bar. Weaknesses show weakest first. 
-- A gold X after them reveals the resistanced ordered by least resisted to most resisted, with immune then absorb last. 
-- Hovering any icon shows its value (exact % from SDT, or Weak/Resist/Immune/Absorb). 
-- Data = authoritative LandSandBoat server SQL, generated for each zone into weak/<zone>.lua; only the current zone.
-- XivUI component. Maintainer: maybeLynd. Linked to the target bar.

local config      = require('config')
local res         = require('resources')
local ui_bounds   = require('lib/ui_bounds')
local imgcache    = require('lib/img')
local occlusion   = require('lib/occlusion')

local ELEM_DIR    = windower.addon_path .. 'assets/components/enemyweak/elements/'
local PHYS_DIR    = windower.addon_path .. 'assets/components/enemyweak/'
local BUFFS_DIR   = windower.addon_path .. 'assets/components/targetbar/buffs/'
local X_ICON      = windower.addon_path .. 'assets/components/enemyweak/Expand/resist_expand.png'
local MAGNIFY     = windower.addon_path .. 'assets/components/enemyweak/Expand/Magnifying Glass.png'
if _G.XIVUI_THEME == 'ffxi' then
    local function _swap(name, cur)
        local p = windower.addon_path .. 'assets/components/enemyweak/themes/ffxi/' .. name
        local f = io.open(p, 'rb'); if f then f:close(); return p end
        return cur
    end
    X_ICON  = _swap('resist_expand.png', X_ICON)
    MAGNIFY = _swap('Magnifying Glass.png', MAGNIFY)
end
local ZONE_DIR    = windower.addon_path .. 'components/enemyweak/weak/'

local MAX_ICONS = 24
local GAP       = 2
local WTIP_SIZE = 10

local ELEMS = { Fire=1, Ice=1, Wind=1, Earth=1, Lightning=1, Water=1, Light=1, Dark=1 }
local PHYS_FILE = { Slashing='slashing.jpg', Piercing='piercing.jpg', H2H='h2h.jpg', Impact='blunt.jpg', Ranged='ranged.jpg' }

local SAMPLE = {
    { 'Ice', 'd', 150 }, { 'Fire', 'k', -3 }, { 'Lightning', 'k', -2 },
    { 'Earth', 'k', 4 }, { 'Light', 'd', 0 }, { 'Dark', 'd', -20 },
    { 'Bind', 't', 1118 }, { 'Silence', 't', 625 }, { 'Sleep', 't', 231 },
}

local defaults = { always_show = false, show_status = false, off = { x = 0, y = 0 } }

local settings
local phys_ok = {}
local ready, preview = false, false

local icons      = {}
local icon_rects = {}
local wtip, wtip_sz, tip_label
local glass_img, g_alpha
local x_img, x_alpha
local layout_sig
local lz_sx, lz_iy, lz_icon, lz_name, lz_wopen, lz_ropen

local last_raw, last_data

local weak_open, resist_open = false, false
local hit   = { x = 0, y = 0, w = 0, h = 0 }
local whit  = { x = 0, y = 0, w = 0, h = 0 }
local rhit  = { x = 0, y = 0, w = 0, h = 0 }
local has_weak, has_rest = false, false
local hovered_seg = nil
local cur_t = nil

local function file_exists(p)
    local f = io.open(p, 'r'); if f then f:close(); return true end; return false
end

local function run_file(path)
    local chunk = loadfile(path)
    if not chunk then return nil end
    local ok, d = pcall(chunk)
    return (ok and type(d) == 'table') and d or nil
end

local function current_zone()
    local info = windower.ffxi.get_info()
    local z = info and info.zone and res.zones[info.zone]
    return z and z.en and tostring(z.en):lower() or nil
end

local function sanitize_zone(z)
    if not z or z == '' then return nil end
    return (z:gsub('[^a-z0-9]+', '_'))
end

local zoneless_data
local function load_zoneless()
    if zoneless_data == nil then zoneless_data = run_file(ZONE_DIR .. '_zoneless.lua') or false end
    return zoneless_data or nil
end

local cur_zone_key, cur_zone_data
local function load_zone(zone)
    local key = sanitize_zone(zone)
    if key ~= cur_zone_key then
        cur_zone_key = key
        cur_zone_data = key and run_file(ZONE_DIR .. key .. '.lua') or false
    end
    return cur_zone_data or nil
end

local SEP_F, PAT = string.char(4), '[^' .. string.char(3) .. ']+'
local function decode_weak(s)
    if not s or s == '' then return nil end
    local out = {}
    for tok in s:gmatch(PAT) do
        local f1 = tok:find(SEP_F, 1, true)
        local f2 = f1 and tok:find(SEP_F, f1 + 1, true)
        if f1 and f2 then
            out[#out + 1] = { tok:sub(1, f1 - 1), tok:sub(f1 + 1, f2 - 1), tonumber(tok:sub(f2 + 1)) or 0 }
        end
    end
    return out[1] and out or nil
end

local function icon_path(elem)
    if ELEMS[elem] then return ELEM_DIR .. elem .. '.png' end
    local f = PHYS_FILE[elem]
    return (f and phys_ok[elem]) and (PHYS_DIR .. f) or nil
end

local RANK_PCT = { 150, 130, 115, 100, 85, 70, 60, 50, 40, 30, 25, 20, 15, 10, 5 }

local function classify(src, value)
    local pct
    if src == 'd' then
        pct = value
    else
        local idx = value + 4
        if idx < 1 then idx = 1 elseif idx > #RANK_PCT then idx = #RANK_PCT end
        pct = RANK_PCT[idx]
    end
    if pct < 0 then    return 'absorb', 'Absorb', 2000, 255 end
    if pct == 0 then   return 'immune', 'Immune', 1000, 255 end
    if pct == 100 then return nil end
    if pct > 100 then  return 'weak',   pct .. '%', 200 - pct, 255 end
    return 'resist', pct .. '%', 200 - pct, 255
end

local function build(entries)
    local all = {}
    local show_status = not (settings and settings.show_status == false)
    for _, e in ipairs(entries) do
        local elem, src, value = e[1], e[2], e[3]
        if src == 't' then
            if show_status then
                local sid  = math.floor(value / 100)
                local rank = (value % 100) - 20
                local cat, val, tier
                if rank >= 11 then
                    cat, val, tier = 'immune', 'Immune', 1000
                else
                    local idx = rank + 4; if idx < 1 then idx = 1 elseif idx > #RANK_PCT then idx = #RANK_PCT end
                    local pct = RANK_PCT[idx]
                    if pct >= 100 then cat, val, tier = 'weak', pct .. '%', 200 - pct
                    else cat, val, tier = 'resist', pct .. '%', 200 - pct end
                end
                all[#all + 1] = { path = BUFFS_DIR .. sid .. '.png', name = elem, cat = cat, val = val,
                                  score = 20000 + tier, alpha = 255 }
            end
        else
            local ip = icon_path(elem)
            local cat, val, tier, alpha = classify(src, value)
            if ip and cat then
                local kind = ELEMS[elem] and 0 or 1
                all[#all + 1] = { path = ip, name = elem, cat = cat, val = val,
                                  score = kind * 10000 + tier, alpha = alpha }
            end
        end
    end
    table.sort(all, function(a, b) if a.score == b.score then return a.name < b.name end return a.score < b.score end)
    local weak, rest = {}, {}
    for _, e in ipairs(all) do
        if e.cat == 'weak' then weak[#weak + 1] = e else rest[#rest + 1] = e end
    end
    return { weak = weak, rest = rest }
end

local function lookup(name)
    if preview then return build(SAMPLE) end
    if name == last_raw then return last_data end
    last_raw = name
    local key = tostring(name):lower()
    local zt, zl = load_zone(current_zone()), load_zoneless()
    local s = (zt and zt[key]) or (zl and zl[key])
    local entries = decode_weak(s)
    local d = entries and build(entries) or nil
    if d and (#d.weak > 0 or #d.rest > 0) then last_data = d else last_data = false end
    return last_data or nil
end

local function publish_hit(active, x, y, w, h)
    local wr = _G.XIVUI_WEAK_RECT
    if not wr then wr = {}; _G.XIVUI_WEAK_RECT = wr end
    wr.active = active and true or false
    if active then wr.x, wr.y, wr.w, wr.h = x, y, w, h end
end

local function hide_wtip() if wtip then wtip:hide() end; tip_label = nil end

local function hide_all()
    hovered_seg = nil
    for i = 1, #icons do icons[i]:hide() end
    if glass_img then glass_img:hide() end
    if x_img then x_img:hide() end
    icon_rects = {}
    has_weak, has_rest = false, false
    hide_wtip()
    layout_sig = nil
    lz_sx, lz_name = nil, nil
    publish_hit(false)
    ui_bounds.clear('enemyweak')
end

local function name_width(name, font) return math.ceil(#tostring(name) * (font or 10) * 0.52) end

local enemyweak = {}

function enemyweak.init()
    settings = config.load('data/enemyweak/settings.xml', defaults)
    for elem, fn in pairs(PHYS_FILE) do phys_ok[elem] = file_exists(PHYS_DIR .. fn) end
    for i = 1, MAX_ICONS do
        local im = images.new()
        im:fit(false); im:draggable(false); im:alpha(255); im:hide()
        icons[i] = im
    end
    occlusion.push(2)
    wtip = texts.new('${v}', {
        pos = { x = 0, y = 0 }, text = { font = 'Constantia', size = WTIP_SIZE,
            stroke = { width = 2, alpha = 220, red = 8, green = 8, blue = 10 } },
        flags = { bold = false, draggable = false }, bg = { visible = false },
    })
    wtip:color(238, 238, 238); wtip:alpha(255); wtip.v = ''; wtip:hide()
    occlusion.pop()
    glass_img = images.new()
    glass_img:fit(false); glass_img:draggable(false); glass_img:path(MAGNIFY)
    glass_img:size(14, 14); glass_img:alpha(200); glass_img:hide()
    x_img = images.new()
    x_img:fit(false); x_img:draggable(false); x_img:path(X_ICON)
    x_img:size(14, 14); x_img:alpha(200); x_img:hide()
    weak_open = settings.always_show and true or false
    ready = true
    coroutine.schedule(function() pcall(load_zoneless); pcall(load_zone, current_zone()) end, 6)
end

function enemyweak.dispose()
    ready = false
    for i = 1, #icons do if icons[i] then icons[i]:destroy() end end
    if wtip then wtip:destroy(); wtip = nil end
    if glass_img then glass_img:destroy(); glass_img = nil end
    if x_img then x_img:destroy(); x_img = nil end
    icons, icon_rects, tip_label = {}, {}, nil
    layout_sig, has_weak, has_rest, hovered_seg = nil, false, false, nil
    last_raw, last_data = nil, nil
    publish_hit(false)
    ui_bounds.clear('enemyweak')
end

function enemyweak.show() if x_img then ready = true end end
function enemyweak.hide() if x_img then hide_all() end; ready = false end
function enemyweak.hud_preview(on) preview = on and true or false end

function enemyweak.on_prerender()
    if not ready or not x_img then return end
    local g = _G.XIVUI_TARGET
    local active = preview or (g and g.visible and g.monster)
    cur_t = active and g or nil
    if not active then hide_all(); return end

    local name = preview and 'Sample Enemy' or (g.name or '')
    local data = lookup(name)
    if not data then hide_all(); return end

    if not preview and not g.name_right_exact then hide_all(); return end

    if preview and (not g or not g.visible) then
        local ws = windower.get_windower_settings()
        g = { x = ((ws and ws.ui_x_res) or 1920) / 2 - 300, y = 80, w = 600, h = 8,
              font = 12, name = name, visible = true, monster = true, name_right_exact = true }
        g.name_right = g.x + 4 + name_width(name, g.font)
        cur_t = g
    end

    local pf = g.font or 10
    local sc = g.scale or 1
    local ox, oy = settings.off.x or 0, settings.off.y or 0
    local sx = (g.name_right or ((g.x or 0) + 4 + name_width(name, pf))) + math.floor(3 * sc + 0.5) + ox
    local wopen = weak_open or preview
    local ropen = resist_open or preview
    local wsz = math.max(6, math.floor(WTIP_SIZE * sc + 0.5))
    if wtip and wtip_sz ~= wsz then wtip:size(wsz); wtip_sz = wsz end

    local ICON = math.max(math.floor(12 * sc + 0.5), math.ceil(pf))
    local iy = (g.y or 0) - math.floor(ICON / 2) - math.floor(pf * 0.25) + oy

    if sx ~= lz_sx or iy ~= lz_iy or ICON ~= lz_icon or name ~= lz_name or wopen ~= lz_wopen or ropen ~= lz_ropen then
        lz_sx, lz_iy, lz_icon, lz_name, lz_wopen, lz_ropen = sx, iy, ICON, name, wopen, ropen
        icon_rects = {}
        local gap = math.max(1, math.floor(GAP * sc + 0.5))
        local btn = ICON
        local by  = iy
        local x, n = sx, 0
        local function place(e)
            if n >= MAX_ICONS then return end
            n = n + 1
            local ic = icons[n]
            imgcache.set_path(ic, e.path)
            ic:alpha(e.alpha); ic:size(ICON, ICON); ic:pos(x, iy); ic:show()
            icon_rects[n] = { x = x, y = iy, w = ICON, h = ICON, name = e.name, cat = e.cat, val = e.val }
            x = x + ICON + gap
        end
        has_weak, has_rest = #data.weak > 0, #data.rest > 0

        if has_weak then
            local seg = x
            if wopen then
                glass_img:hide(); g_alpha = nil
                for _, e in ipairs(data.weak) do place(e) end
            else
                glass_img:size(btn, btn); glass_img:pos(x, by); glass_img:show(); g_alpha = nil
                x = x + btn + gap
            end
            whit.x, whit.y, whit.w, whit.h = seg, iy, x - seg, ICON
        else
            glass_img:hide(); g_alpha = nil; whit.w = 0
        end

        if has_rest then
            local seg = x
            if ropen then
                x_img:hide(); x_alpha = nil
                for _, e in ipairs(data.rest) do place(e) end
            else
                x_img:size(btn, btn); x_img:pos(x, by); x_img:show(); x_alpha = nil
                x = x + btn + gap
            end
            rhit.x, rhit.y, rhit.w, rhit.h = seg, iy, x - seg, ICON
        else
            x_img:hide(); x_alpha = nil; rhit.w = 0
        end

        for i = n + 1, MAX_ICONS do icons[i]:hide() end
        hit.x, hit.y, hit.w, hit.h = sx - 2, iy - 2, (x - sx) + 2, ICON + 4
    end

    if has_weak and not wopen then
        local a = hovered_seg == 'w' and 255 or 200
        if g_alpha ~= a then glass_img:alpha(a); g_alpha = a end
    end
    if has_rest and not ropen then
        local a = hovered_seg == 'r' and 255 or 200
        if x_alpha ~= a then x_img:alpha(a); x_alpha = a end
    end
    layout_sig = true
    ui_bounds.register('enemyweak', hit.x, hit.y, hit.w, hit.h)
    publish_hit(true, hit.x, hit.y, hit.w, hit.h)
end

local CAT_COLOR = { weak = '\\cs(120,230,120)', resist = '\\cs(235,120,120)', immune = '\\cs(180,180,180)', absorb = '\\cs(200,150,255)' }

local function in_rect(rt, x, y) return rt.w > 0 and x >= rt.x and x <= rt.x + rt.w and y >= rt.y and y <= rt.y + rt.h end

function enemyweak.on_mouse(mtype, x, y, delta, blocked)
    if not ready or not cur_t or not layout_sig then hovered_seg = nil; hide_wtip(); return false end
    local in_w = has_weak and in_rect(whit, x, y)
    local in_r = has_rest and in_rect(rhit, x, y)
    if mtype == 0 then
        hovered_seg = (in_w and not weak_open) and 'w' or (in_r and not resist_open) and 'r' or nil
        local r
        for i = 1, #icon_rects do
            local ir = icon_rects[i]
            if x >= ir.x and x <= ir.x + ir.w and y >= ir.y and y <= ir.y + ir.h then r = ir; break end
        end
        if r and wtip then
            local col = CAT_COLOR[r.cat]
            local label = r.name .. ' ' .. (col and (col .. r.val .. '\\cr') or r.val)
            local plain = r.name .. ' ' .. r.val
            if tip_label ~= label then
                wtip.v = label
                local ws = wtip_sz or WTIP_SIZE
                local est_w = math.ceil(#plain * ws * 0.5)
                wtip:pos(math.floor(r.x + r.w / 2 - est_w / 2), r.y - ws - 4)
                wtip:show()
                tip_label = label
            end
        else
            hide_wtip()
        end
        return false
    elseif mtype == 1 then
        if in_w then weak_open = not weak_open; return true
        elseif in_r then resist_open = not resist_open; return true end
    end
    return false
end

local function want(arg, cur)
    arg = arg and tostring(arg):lower() or nil
    if arg == 'on' or arg == 'true' or arg == '1' then return true end
    if arg == 'off' or arg == 'false' or arg == '0' then return false end
    return not cur
end

function enemyweak.handle_command(args)
    local cmd = args[1] and args[1]:lower() or ''
    local log = _G.xivui_echo or function(s) windower.add_to_chat(207, 'enemyweak: ' .. s) end
    if cmd == 'always' then
        settings.always_show = want(args[2], settings.always_show); config.save(settings)
        log('enemyweak: always-expanded ' .. (settings.always_show and 'on' or 'off') .. '.')
    elseif cmd == 'status' then
        settings.show_status = want(args[2], settings.show_status); config.save(settings)
        last_raw, last_data = nil, nil; layout_sig = nil
        log('enemyweak: status ailments ' .. (settings.show_status and 'shown' or 'hidden') .. '.')
    elseif cmd == 'off' or cmd == 'offset' then
        local nx, ny = tonumber(args[2]), tonumber(args[3])
        if nx and ny then settings.off.x = math.floor(nx); settings.off.y = math.floor(ny); config.save(settings)
            log('enemyweak: offset ' .. nx .. ', ' .. ny .. '.')
        else log('Usage: //xui weak off <dx> <dy>') end
    else
        log('enemyweak commands: always | status [on|off] | off <dx> <dy>')
    end
end

return enemyweak
