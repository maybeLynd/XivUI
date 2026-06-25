-- enemyloot: a bag icon below an enemy target's HP bar; click it to see that enemy's possible drops, grouped into collapsible categories (drops / steal / despoil / etc) with % chances.
-- Data is split into zone files under loot/ (only the current zone is loaded at a time. loot/_zoneless.lua holds zone-less rows). 
-- 'XivUI component. Maintainer: maybeLynd. Linked to the targetbar.

local config    = require('config')
local res       = require('resources')
local packets   = require('packets')
local ui_bounds = require('lib/ui_bounds')
local occlusion = require('lib/occlusion')
local imgcache  = require('lib/img')
local screen    = require('lib/screen')

local LEARNED_PATH = require('lib/cache').path('enemyloot', 'learned.lua')

local BAG       = windower.addon_path .. 'assets/components/enemyloot/drops.png'
if _G.XIVUI_THEME == 'ffxi' then
    local p = windower.addon_path .. 'assets/components/enemyloot/themes/ffxi/drops.png'
    local f = io.open(p, 'rb'); if f then f:close(); BAG = p end
end
local BAG_BASE  = 22
local GAP_BELOW = 4
local PANEL_BG  = windower.addon_path .. 'assets/components/enemyloot/tooltip_bg.png'
if _G.XIVUI_THEME == 'ffxi' then
    local p = windower.addon_path .. 'assets/components/enemyloot/themes/ffxi/tooltip_bg.png'
    local f = io.open(p, 'rb'); if f then f:close(); PANEL_BG = p end
end

local PAD          = 5
local HDR_SIZE     = 10
local ITEM_SIZE    = 8
local HDR_H        = HDR_SIZE + 7
local ITEM_H       = ITEM_SIZE + 6
local SECTION_GAP  = 5
local INDENT       = 9
local VISIBLE_ROWS = 12
local SB_W         = 5

local CAT_LABEL = { d = 'Drops', g = 'Gil', s = 'Steal', p = 'Despoil', c = 'Crystal', r = 'Content Rewards' }
local CAT_RGB   = { d = {150,210,150}, g = {235,205,120}, s = {150,200,255}, p = {220,180,255}, c = {130,225,235}, r = {255,210,140} }

local defaults = { pos = { x = -1, y = -1 }, scale = 1, off = { x = 0, y = 0 }, steal_plus = 0, despoil_plus = 0, th = 0 }
local settings
local bag_img
local hovered    = false
local ready      = false
local preview    = false
local cur_t      = nil
local bag_x, bag_y = 0, 0
local bag_lx, bag_ly, bag_lsz, bag_shown, bag_alpha

local panel_bg
local row_t = {}
local row_sz = {}
local sb_track, sb_thumb
local collapsed = {}
local panel = { open = false, target = nil, groups = {}, rows = {}, total = 0, scroll = 0,
                w = 0, h = 0, x = 0, y = 0, has_sb = false, hdr = {}, hdr_n = 0,
                ver = 0 }

local link_scale = 1
local function sscale() return link_scale * ((settings and tonumber(settings.scale)) or 1) end
local function bag_size() return math.floor(BAG_BASE * sscale()) end
local function S(n) return math.max(1, math.floor(n * sscale() + 0.5)) end
local function hdr_size()  return S(HDR_SIZE) end
local function item_size() return S(ITEM_SIZE) end
local function hdr_h()     return hdr_size() + S(7) end
local function item_h()    return item_size() + S(6) end

local ZONE_DIR = windower.addon_path .. 'components/enemyloot/loot/'
local function run_file(path)
  local chunk = loadfile(path)
  if not chunk then return nil end
  local ok, d = pcall(chunk)
  return (ok and type(d) == 'table') and d or nil
end
local function sanitize_zone(z)
  if not z or z == '' then return nil end
  return (z:gsub('[^a-z0-9]+', '_'))
end

local zoneless_data
local function load_zoneless()
  if zoneless_data == nil then
    zoneless_data = run_file(ZONE_DIR .. '_zoneless.lua') or false
  end
  return zoneless_data or nil
end

local cur_zone_key
local cur_zone_data
local function load_zone(zone)
  local key = sanitize_zone(zone)
  if key ~= cur_zone_key then
    cur_zone_key = key
    cur_zone_data = key and run_file(ZONE_DIR .. key .. '.lua') or false
  end
  return cur_zone_data or nil
end

local CRYSTAL_DIR  = windower.addon_path .. 'components/enemyloot/crystal_zones.lua'
local ELEMENT_NAME = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' }
local EFFECT_BUFF  = { signet = 253, sanction = 256, sigil = 268, ionis = 512 }
local crystal_zones
local function load_crystal_zones()
  if crystal_zones == nil then crystal_zones = run_file(CRYSTAL_DIR) or false end
  return crystal_zones or nil
end

local function crystal_rate_for(zone)
  local cz = load_crystal_zones()
  local ctx = cz and zone and cz[sanitize_zone(zone)]
  if not ctx then return nil end
  local buff_id = EFFECT_BUFF[ctx[1]]
  local p = windower.ffxi.get_player()
  if not (p and buff_id and p.buffs) then return nil end
  local has = false
  for _, b in ipairs(p.buffs) do if b == buff_id then has = true; break end end
  if not has then return nil end
  local party = windower.ffxi.get_party()
  local in_party = party and (tonumber(party.party1_count) or 1) > 1
  return in_party and ctx[3] or ctx[2]
end

local function enemy_target()
  local t = _G.XIVUI_TMOB
  if not t or (t.id or 0) == 0 or not t.name then return nil end
  if t.is_npc ~= true or t.in_party == true or t.spawn_type ~= 16 then return nil end
  return t
end

local function set_bag_path(p) imgcache.set_path(bag_img, p) end

local function new_row()
  local t = texts.new('${v}', {
    pos = { x = 0, y = 0 }, text = { font = 'Arial', size = ITEM_SIZE,
      stroke = { width = 2, alpha = 200, red = 8, green = 8, blue = 10 } },
    flags = { bold = false, draggable = false }, bg = { visible = false },
  })
  t.v = ''; t:alpha(255); t:hide()
  return t
end

local function strip(s) return (tostring(s):gsub('\\cs%([^)]*%)', ''):gsub('\\cr', '')) end

local PLACEHOLDER = {
  ['information needed'] = true, ['more data needed'] = true, ['no data'] = true,
  ['unknown'] = true, ['none'] = true, ['npcs'] = true, ['edit'] = true, ['[ edit'] = true,
  ['steal'] = true, ['despoil'] = true, ['mugged'] = true, ['drops'] = true,
  ['normal drops'] = true, ['weakness'] = true, ['temporary'] = true, ['key item'] = true,
  ['relic armor'] = true, ['relic weapons'] = true, ['nightmare monsters'] = true,
}
local function is_placeholder(name)
  local s = tostring(name):lower():gsub('%s*%.%s*$', ''):gsub('^%s+', ''):gsub('%s+$', '')
  return PLACEHOLDER[s] == true
end

local function build_groups(loot)
  local groups, idx = {}, {}
  for _, r in ipairs(loot or {}) do
    if not is_placeholder(r[1]) then
      local cat = r[3] or 'd'
      local g = idx[cat]
      if not g then g = { cat = cat, items = {} }; groups[#groups + 1] = g; idx[cat] = g end
      g.items[#g.items + 1] = { item = r[1], rate = r[2] }
    end
  end
  local out = {}
  for _, g in ipairs(groups) do if #g.items > 0 then out[#out + 1] = g end end
  local CAT_ORDER = { d = 1, s = 2, p = 3, g = 4, c = 5, r = 6 }
  table.sort(out, function(a, b) return (CAT_ORDER[a.cat] or 99) < (CAT_ORDER[b.cat] or 99) end)
  return out
end

local function flatten()
  local rows = {}
  if #panel.groups == 0 then
    rows[1] = { kind = 'i', text = '\\cs(170,170,170)Missing Data.\\cr', h = item_h(), toff = 1 }
  else
    local sgap = S(SECTION_GAP)
    for gi, g in ipairs(panel.groups) do
      local c = CAT_RGB[g.cat] or { 200, 200, 200 }
      local sign = collapsed[g.cat] and '+' or '-'
      local first = gi == 1
      rows[#rows + 1] = { kind = 'h', cat = g.cat,
        text = ('\\cs(%d,%d,%d)%s %s\\cr'):format(c[1], c[2], c[3], sign, CAT_LABEL[g.cat] or '?'),
        h = hdr_h() + (first and 0 or sgap), toff = (first and 0 or sgap) + 1 }
      if not collapsed[g.cat] then
        for _, it in ipairs(g.items) do
          local line = '\\cs(228,228,228)' .. it.item .. '\\cr'
          if it.rate then
            local suffix = (g.cat == 'g') and (tostring(it.rate) .. ' gil') or (tostring(it.rate) .. '%')
            local rc = CAT_RGB[g.cat] or { 150, 210, 150 }
            line = line .. ('  \\cs(%d,%d,%d)%s\\cr'):format(rc[1], rc[2], rc[3], suffix)
          end
          rows[#rows + 1] = { kind = 'i', text = line, h = item_h(), toff = 1 }
        end
      end
    end
  end
  panel.rows = rows
  panel.total = #rows
  panel.has_sb = panel.total > VISIBLE_ROWS
  panel.ver = panel.ver + 1
  if panel.scroll > math.max(0, panel.total - VISIBLE_ROWS) then
    panel.scroll = math.max(0, panel.total - VISIBLE_ROWS)
  end
end

local function panel_width()
  local hs, is = hdr_size(), item_size()
  local maxw = S(70)
  for _, g in ipairs(panel.groups) do
    local hw = math.ceil((#CAT_LABEL[g.cat] + 2) * hs * 0.6) + S(4)
    if hw > maxw then maxw = hw end
    for _, it in ipairs(g.items) do
      local s = it.item .. (it.rate and ('  ' .. it.rate .. (g.cat == 'g' and ' gil' or '%')) or '')
      local w = math.ceil(#s * is * 0.6) + S(INDENT) + S(6)
      if w > maxw then maxw = w end
    end
  end
  if #panel.groups == 0 then maxw = S(90) end
  return math.min(maxw, S(320)) + S(PAD) * 2 + (panel.has_sb and (S(SB_W) + S(4)) or 0)
end

local function close_panel()
  panel.open, panel.target = false, nil
  panel.s_px, panel.s_py, panel.s_w, panel.s_h, panel.s_scroll, panel.s_ver = nil, nil, nil, nil, nil, nil
  panel.s_scale = nil
  panel_bg:hide(); sb_track:hide(); sb_thumb:hide()
  for i = 1, #row_t do row_t[i]:hide() end
  occlusion.clear('enemyloot_panel')
end

local function current_zone()
  local info = windower.ffxi.get_info()
  local z = info and info.zone and res.zones[info.zone]
  return z and z.en and tostring(z.en):lower() or nil
end

local learned = {}

local function q(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end

local function load_learned()
  learned = {}
  local ok, chunk = pcall(loadfile, LEARNED_PATH)
  if not ok or not chunk then return end
  local ok2, t = pcall(chunk)
  if not ok2 or type(t) ~= 'table' then return end
  for name, zs in pairs(t) do
    local zm = {}; learned[name] = zm
    for zone, items in pairs(zs) do
      local m = {}; zm[zone] = m
      for _, e in ipairs(items) do local c = e[2] or 'd'; m[tostring(e[1]):lower() .. '|' .. c] = { e[1], c } end
    end
  end
end

local function save_learned()
  local f = io.open(LEARNED_PATH, 'w')
  if not f then return end
  f:write('-- auto-maintained by enemyloot: loot the player actually obtained, filling wiki gaps.\n')
  f:write('return {\n')
  for name, zs in pairs(learned) do
    local zparts = {}
    for zone, zt in pairs(zs) do
      local items = {}
      for _, e in pairs(zt) do items[#items + 1] = '{' .. q(e[1]) .. ',' .. q(e[2]) .. '}' end
      if #items > 0 then zparts[#zparts + 1] = '[' .. q(zone) .. ']={' .. table.concat(items, ',') .. '}' end
    end
    if #zparts > 0 then f:write('[' .. q(name) .. ']={' .. table.concat(zparts, ',') .. '},\n') end
  end
  f:write('}\n'); f:close()
end

local SEP_F    = string.char(4)
local PAT_ITEM = '[^' .. string.char(3) .. ']+'

local SEP_LVL = string.char(1)
local SEP_PFX = string.char(2)
local function strip_level(s)
  if not s then return nil, nil, nil end
  local p = s:find(SEP_LVL, 1, true)
  if not p then return s, nil, nil end
  local prefix = s:sub(1, p - 1)
  local items  = s:sub(p + 1)
  local lvpart, elem = prefix, nil
  local q = prefix:find(SEP_PFX, 1, true)
  if q then lvpart = prefix:sub(1, q - 1); elem = tonumber(prefix:sub(q + 1)) end
  local lo, hi = lvpart:match('(%d+)%-(%d+)')
  return items, (tonumber(hi) or tonumber(lo) or tonumber(lvpart)), elem
end

local function decode_items(s)
  if not s or s == '' then return nil end
  local rows = {}
  for it in s:gmatch(PAT_ITEM) do
    local f1 = it:find(SEP_F, 1, true)
    local f2 = f1 and it:find(SEP_F, f1 + 1, true)
    if f1 and f2 then
      local rt  = it:sub(f1 + 1, f2 - 1)
      local cat = it:sub(f2 + 1)
      local rate = (cat == 'g') and (rt ~= '' and rt or nil) or (rt ~= '' and tonumber(rt) or nil)
      rows[#rows + 1] = { it:sub(1, f1 - 1), rate, cat }
    end
  end
  return rows
end

local function thf_level()
  local p = windower.ffxi.get_player()
  if not p then return 0 end
  if p.main_job == 'THF' then return tonumber(p.main_job_level) or 0 end
  if p.sub_job == 'THF' then return tonumber(p.sub_job_level) or 0 end
  return 0
end

local function thf_rates(maxlvl)
  if not maxlvl then return nil, nil end
  local thf = thf_level()
  if thf <= 0 then return nil, nil end
  local function clamp(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end
  local sp = (settings and tonumber(settings.steal_plus)) or 0
  local dp = (settings and tonumber(settings.despoil_plus)) or 0
  local steal = clamp(50 + 2 * sp + thf - maxlvl)
  local despoil = (thf >= 77) and clamp(50 + 2 * dp + thf - maxlvl) or nil
  return steal, despoil
end

local TH_TABLE = {
  [0]  = {2400,1500,1000, 500, 100, 50, 10}, [1]  = {4800,3000,1200, 600, 150, 75, 20},
  [2]  = {5600,4000,1500, 700, 200,100, 30}, [3]  = {6000,4250,1650, 750, 225,120, 35},
  [4]  = {6400,4500,1800, 800, 250,140, 40}, [5]  = {6666,4750,1900, 850, 300,160, 45},
  [6]  = {6800,5000,2000, 900, 350,180, 50}, [7]  = {6900,5250,2100, 950, 400,200, 60},
  [8]  = {7050,5500,2250,1050, 475,230, 70}, [9]  = {7200,5750,2400,1150, 550,260, 80},
  [10] = {7350,6000,2650,1250, 650,300, 90}, [11] = {7400,6250,2800,1350, 750,350,100},
  [12] = {7600,6500,2950,1550, 825,400,115}, [13] = {7800,6750,3100,1750, 900,450,130},
  [14] = {8000,7000,3250,2000,1000,500,150},
}
local TH_BRACKET = { 2400, 1500, 1000, 500, 100, 50, 0 }

local function th_drop_rate(pct)
  local th = (settings and tonumber(settings.th)) or 0
  if not th or th <= 0 or not pct then return pct end
  if th > 14 then th = 14 end
  local r = pct * 100
  if r <= 0 or r >= 10000 then return pct end
  local bracket = #TH_BRACKET
  for i = 1, #TH_BRACKET do if r >= TH_BRACKET[i] then bracket = i; break end end
  local nr = TH_TABLE[th][bracket]
  if not nr then return pct end
  local np = nr / 100
  if np < pct then np = pct end
  return math.floor(np * 10 + 0.5) / 10
end

local function already_known(name, zone, il, cat)
  local key = il .. '|' .. cat
  local lm = learned[name]
  if lm and ((lm[zone] and lm[zone][key]) or (lm['*'] and lm['*'][key])) then return true end
  local zt, zl = load_zone(zone), load_zoneless()
  local function has(rows) if rows then for _, r in ipairs(rows) do if tostring(r[1]):lower() == il and (r[3] or 'd') == cat then return true end end end return false end
  return has(decode_items((strip_level(zt and zt[name])))) or has(decode_items((strip_level(zl and zl[name]))))
end

local function learn(mob, item, cat)
  if not mob or not item then return end
  mob = tostring(mob):lower()
  local disp = tostring(item):gsub('^%s+', ''):gsub('%s+$', '')
  local il = disp:lower()
  if disp == '' or il == 'gil' or il:find('gil$') or is_placeholder(disp) then return end
  if il:find('crystal$') or il:find('cluster$') then return end
  cat = cat or 'd'
  local zone = current_zone() or '*'
  if already_known(mob, zone, il, cat) then return end
  local lm = learned[mob]; if not lm then lm = {}; learned[mob] = lm end
  local zt = lm[zone]; if not zt then zt = {}; lm[zone] = zt end
  zt[il .. '|' .. cat] = { disp, cat }
  save_learned()
end

local function rows_from_learned(name, zone)
  local out, lm = {}, learned[name]
  if not lm then return out end
  local function add(zt) if zt then for _, e in pairs(zt) do out[#out + 1] = { e[1], nil, e[2] } end end end
  add(lm[zone]); add(lm['*'])
  return out
end

local name2id
local function canon_key(name)
  local k = tostring(name or ''):lower()
  if not name2id then
    name2id = {}
    for id, it in pairs(res.items) do
      if type(it) == 'table' then
        if it.en then name2id[it.en:lower()] = id end
        if it.enl then local e = it.enl:lower(); if name2id[e] == nil then name2id[e] = id end end
      end
    end
  end
  local id = name2id[k]
  return id and ('\0' .. id) or k
end

local function loot_for(t)
  local name = tostring(t.name):lower()
  local zone = current_zone()
  local zt, zl = load_zone(zone), load_zoneless()
  local zitems, maxlvl, zelem = strip_level(zt and zt[name])
  local litems        = strip_level(zl and zl[name])
  local steal_pct, despoil_pct = thf_rates(maxlvl)
  local list, seen = {}, {}
  local function append(src)
    for _, r in ipairs(src or {}) do
      local k = canon_key(r[1]) .. '|' .. (r[3] or 'd')
      if not seen[k] then
        seen[k] = true
        if r[2] == nil then
          if r[3] == 's' then r[2] = steal_pct
          elseif r[3] == 'p' then r[2] = despoil_pct end
        elseif r[3] == 'd' then
          r[2] = th_drop_rate(r[2])
        end
        list[#list + 1] = r
      end
    end
  end
  append(decode_items(zitems))
  append(decode_items(litems))
  append(rows_from_learned(name, zone))
  if zelem and zelem >= 1 and zelem <= 8 then
    local rate = crystal_rate_for(zone)
    if rate then append({ { (ELEMENT_NAME[zelem] or 'Fire') .. ' Crystal', rate, 'c' } }) end
  end
  return list
end

local function open_panel(t)
  panel.groups = build_groups(loot_for(t))
  panel.scroll = 0
  panel.target = tostring(t.name):lower()
  panel.open   = true
  flatten()
  panel.w = panel_width()
end

local function render_panel()
  local bs = bag_size()
  local sw, sh = screen.size()
  if panel.s_scale ~= sscale() then
    flatten(); panel.w = panel_width(); panel.s_scale = sscale()
  end
  local pad, indent, sbw = S(PAD), S(INDENT), S(SB_W)
  local vis = math.min(panel.total, VISIBLE_ROWS)
  local maxscroll = math.max(0, panel.total - vis)
  if panel.scroll > maxscroll then panel.scroll = maxscroll end

  local maxright = 0
  for i = 1, math.min(vis, #row_t) do
    local row = panel.rows[panel.scroll + i]
    if row then
      local ew = row_t[i]:extents()
      if ew then
        local right = (row.kind == 'i' and indent or 0) + ew
        if right > maxright then maxright = right end
      end
    end
  end
  local need = math.ceil(maxright) + pad * 2 + (panel.has_sb and (sbw + S(4)) or 0)
  if need > panel.w then panel.w = need end

  local hsum = 0
  for i = 1, vis do hsum = hsum + (panel.rows[panel.scroll + i].h or item_h()) end
  panel.h = hsum + pad * 2

  local px = bag_x + bs - panel.w
  local py = bag_y + bs + S(4)
  if py + panel.h > sh then py = bag_y - panel.h - S(4) end
  if px < 0 then px = 0 end
  if px + panel.w > sw then px = sw - panel.w end
  if py < 0 then py = 0 end
  panel.x, panel.y = px, py

  if px == panel.s_px and py == panel.s_py and panel.w == panel.s_w and panel.h == panel.s_h
     and panel.scroll == panel.s_scroll and panel.ver == panel.s_ver then return end
  panel.s_px, panel.s_py, panel.s_w, panel.s_h, panel.s_scroll, panel.s_ver =
    px, py, panel.w, panel.h, panel.scroll, panel.ver

  panel_bg:size(panel.w, panel.h); panel_bg:pos(px, py); panel_bg:show()

  local hsz, isz = hdr_size(), item_size()
  local y = py + pad
  panel.hdr_n = 0
  for i = 1, vis do
    local row = panel.rows[panel.scroll + i]
    local t = row_t[i]
    local sz = row.kind == 'h' and hsz or isz
    if row_sz[i] ~= sz then t:size(sz); row_sz[i] = sz end
    t.v = row.text
    t:pos(px + pad + (row.kind == 'i' and indent or 0), y + (row.toff or 1))
    t:show()
    if row.kind == 'h' then
      panel.hdr_n = panel.hdr_n + 1
      local hr = panel.hdr[panel.hdr_n] or {}; panel.hdr[panel.hdr_n] = hr
      hr.x, hr.y, hr.w, hr.h, hr.cat = px, y, panel.w, row.h, row.cat
    end
    y = y + (row.h or item_h())
  end
  for i = vis + 1, #row_t do row_t[i]:hide() end

  if panel.has_sb then
    local track_x = px + panel.w - sbw - S(3)
    local track_y = py + pad
    local track_h = panel.h - pad * 2
    sb_track:size(sbw, track_h); sb_track:pos(track_x, track_y); sb_track:show()
    local th = math.max(12, math.floor(track_h * vis / panel.total))
    local ty = track_y + (maxscroll > 0 and math.floor((panel.scroll / maxscroll) * (track_h - th)) or 0)
    sb_thumb:size(sbw, th); sb_thumb:pos(track_x, ty); sb_thumb:show()
  else
    sb_track:hide(); sb_thumb:hide()
  end

  occlusion.set('enemyloot_panel', px, py, panel.w, panel.h, 2)
end

local enemyloot = {}

function enemyloot.init()
  settings = config.load('data/enemyloot/settings.xml', defaults)
  local rx, ry = screen.size()
  if settings.pos.x < 0 or settings.pos.y < 0 then
    settings.pos.x = rx - 64
    settings.pos.y = math.floor(ry * 0.62)
    config.save(settings)
  end
  bag_img = images.new()
  bag_img:draggable(false); bag_img:fit(false); bag_img:alpha(255)
  set_bag_path(BAG)
  bag_img:hide()

  occlusion.push(2)
  panel_bg = images.new()
  panel_bg:path(PANEL_BG); panel_bg:fit(false); panel_bg:draggable(false); panel_bg:alpha(255); panel_bg:hide()
  sb_track = images.new(); sb_track:fit(false); sb_track:draggable(false); sb_track:color(20, 20, 24); sb_track:alpha(180); sb_track:hide()
  sb_thumb = images.new(); sb_thumb:fit(false); sb_thumb:draggable(false); sb_thumb:color(180, 180, 190); sb_thumb:alpha(230); sb_thumb:hide()
  for i = 1, VISIBLE_ROWS do row_t[i] = new_row() end
  occlusion.pop()
  load_learned()
  ready = true
  coroutine.schedule(function()
    pcall(load_zoneless)
    pcall(load_zone, current_zone())
  end, 12)
end

function enemyloot.dispose()
  ready = false
  close_panel()
  if bag_img then bag_img:destroy(); bag_img = nil end
  if panel_bg then panel_bg:destroy(); panel_bg = nil end
  if sb_track then sb_track:destroy(); sb_track = nil end
  if sb_thumb then sb_thumb:destroy(); sb_thumb = nil end
  for i = 1, #row_t do if row_t[i] then row_t[i]:destroy() end end
  row_t = {}
  bag_shown, bag_lx, bag_ly, bag_lsz, bag_alpha = false, nil, nil, nil, nil
  ui_bounds.clear('enemyloot')
end

function enemyloot.show() if bag_img then ready = true end end
function enemyloot.hide()
  if bag_img then bag_img:hide(); bag_shown = false end
  close_panel()
  ready = false
  ui_bounds.clear('enemyloot')
end

function enemyloot.hud_preview(on) preview = on and true or false end

function enemyloot.on_prerender()
  if not ready or not bag_img then return end
  local t = enemy_target()
  cur_t = t
  local g = _G.XIVUI_TARGET
  if (not t and not preview) or (g and g.visible and g.sc_active) then
    if bag_shown then bag_img:hide(); bag_shown = false end
    close_panel(); ui_bounds.clear('enemyloot'); return
  end
  link_scale = (g and g.visible and g.monster and (g.scale or 1)) or 1
  local bs = bag_size()
  if g and g.visible and g.monster then
    bag_x = g.x + g.w - bs + (settings.off.x or 0)
    bag_y = g.y + g.h + math.floor(GAP_BELOW * sscale() + 0.5) + (settings.off.y or 0)
  else
    bag_x, bag_y = settings.pos.x, settings.pos.y
  end
  set_bag_path(BAG)
  if bag_lsz ~= bs then bag_img:size(bs, bs); bag_lsz = bs end
  if bag_lx ~= bag_x or bag_ly ~= bag_y then bag_img:pos(bag_x, bag_y); bag_lx, bag_ly = bag_x, bag_y end
  local a = (hovered or panel.open) and 255 or 170
  if bag_alpha ~= a then bag_img:alpha(a); bag_alpha = a end
  if not bag_shown then bag_img:show(); bag_shown = true end
  ui_bounds.register('enemyloot', bag_x, bag_y, bs, bs)

  if panel.open then
    if t and panel.target ~= tostring(t.name):lower() then open_panel(t) end
    render_panel()
  end
end

function enemyloot.on_incoming_chunk(id, original)
  if id ~= 0x0D2 or not ready then return end
  local ok, p = pcall(packets.parse, 'incoming', original)
  if not ok or not p or p['Old'] then return end
  local itf  = p['Item']
  local item_id = (type(itf) == 'table' and itf.id) or (type(itf) == 'number' and itf) or nil
  local item = (item_id and res.items[item_id]) or (type(itf) == 'table' and itf) or nil
  local mob  = p['Dropper'] and p['Dropper'] > 0 and windower.ffxi.get_mob_by_id(p['Dropper'])
  if item and item.en and mob and mob.name then
    learn(mob.name, item.en, 'd')
    if panel.open and panel.target == tostring(mob.name):lower() then open_panel(cur_t or mob) end
  end
end

function enemyloot.on_incoming_text(original)
  if not ready or not original then return end
  if not original:find('steal') and not original:find('despoil') then return end
  local item, mob = original:match('steals?%s+(.-)%s+from%s+(.+)')
  local cat = 's'
  if not item then item, mob = original:match('despoils?%s+(.-)%s+from%s+(.+)'); cat = 'p' end
  if not item or not mob then return end
  item = item:gsub('^an?%s+', ''):gsub('^some%s+', '')
  mob  = mob:gsub('^[Tt]he%s+', ''):gsub('[%.%s]+$', '')
  learn(mob, item, cat)
end

function enemyloot.on_mouse(mtype, x, y, delta, blocked)
  if not ready or not bag_img then hovered = false; return false end
  local bs = bag_size()
  local over_bag = x >= bag_x and x <= bag_x + bs and y >= bag_y and y <= bag_y + bs
  if mtype == 0 then
    hovered = over_bag
    return false
  elseif mtype == 1 then
    if over_bag and cur_t then
      if panel.open then close_panel() else open_panel(cur_t) end
      return true
    end
    if panel.open then
      for i = 1, panel.hdr_n do
        local hr = panel.hdr[i]
        if x >= hr.x and x <= hr.x + hr.w and y >= hr.y and y <= hr.y + hr.h then
          collapsed[hr.cat] = not collapsed[hr.cat]
          flatten()
          panel.w = panel_width()
          return true
        end
      end
    end
    return false
  elseif mtype == 10 and panel.open then
    if x >= panel.x and x <= panel.x + panel.w and y >= panel.y and y <= panel.y + panel.h then
      panel.scroll = math.max(0, panel.scroll + (delta > 0 and -1 or 1))
      return true
    end
  end
  return false
end

function enemyloot.handle_command(args)
  local cmd = args[1] and args[1]:lower() or ''
  local log = _G.xivui_echo or function(s) windower.add_to_chat(207, 'enemyloot: ' .. s) end
  if cmd == 'pos' then
    local nx, ny = tonumber(args[2]), tonumber(args[3])
    if nx and ny then settings.pos.x = math.floor(nx); settings.pos.y = math.floor(ny); config.save(settings)
      log('enemyloot: bag moved to ' .. settings.pos.x .. ', ' .. settings.pos.y .. '.')
    else log('Usage: //xui loot pos <x> <y>') end
  elseif cmd == 'off' or cmd == 'offset' then
    local nx, ny = tonumber(args[2]), tonumber(args[3])
    if nx and ny then settings.off.x = math.floor(nx); settings.off.y = math.floor(ny); config.save(settings)
      log('enemyloot: bag offset ' .. settings.off.x .. ', ' .. settings.off.y .. '.')
    else log('Usage: //xui loot off <dx> <dy>') end
  elseif cmd == 'scale' then
    local f = tonumber(args[2])
    if f then settings.scale = math.max(0.5, math.min(2.5, f)); config.save(settings); log('enemyloot: scale ' .. settings.scale .. '.')
    else log('Usage: //xui loot scale <factor>') end
  elseif cmd == 'learned' then
    local mobs, items = 0, 0
    for _, zs in pairs(learned) do
      mobs = mobs + 1
      for _, zt in pairs(zs) do for _ in pairs(zt) do items = items + 1 end end
    end
    log(('enemyloot: learned %d item(s) across %d mob(s).'):format(items, mobs))
  elseif cmd == 'forget' then
    learned = {}; save_learned()
    if panel.open and cur_t then open_panel(cur_t) end
    log('enemyloot: cleared the learned-loot cache.')
  elseif cmd == 'steal' or cmd == 'despoil' then
    local n = tonumber(args[2])
    if n then
      settings[cmd .. '_plus'] = math.max(0, math.floor(n)); config.save(settings)
      if panel.open and cur_t then open_panel(cur_t) end
      log(('enemyloot: %s+ set to %d (used in the live %s%% estimate).'):format(cmd, settings[cmd .. '_plus'], cmd))
    else
      log('Usage: //xui loot ' .. cmd .. ' <your total ' .. cmd .. '+ from gear>')
    end
  elseif cmd == 'th' then
    local n = tonumber(args[2])
    if n then
      settings.th = math.max(0, math.min(14, math.floor(n))); config.save(settings)
      if panel.open and cur_t then open_panel(cur_t) end
      log(('enemyloot: Treasure Hunter set to %d (boosts displayed DROP rates; 0 = off).'):format(settings.th))
    else
      log('Usage: //xui loot th <0-14>   (your assumed TH level)')
    end
  else
    log('enemyloot commands: pos <x> <y> | off <dx> <dy> | scale <factor> | steal <n> | despoil <n> | th <n> | learned | forget')
  end
end

return enemyloot
