-- targetbar/skillchain: the skillchain / magicburst display shown under the target HP bar. 
-- Reads resonating properties from the hotbar's skillchains lib. 
-- Based on "SkillChains" v2.20.08.25 by Ivaar.

local texts  = require('texts')
local socket = require('socket')

local _priv = require('lib/priv_res')
local htb_skillchains = (function() local ok, t = pcall(require, 'components/xivhotbar3/lib/skillchains') return ok and t or nil end)()

local SC_GAP    = 6
local SC_WAIT   = 3
local SC_WINDOW = 10
local SC_PLUS_COLOR  = {255, 215, 0}
local SC_MINUS_COLOR = {160, 160, 160}
local SC_WAIT_COLOR  = {255, 60, 60}
local SC_GO_COLOR    = {80, 255, 80}
local SC_RESERVE_CHARS = 34
local SC_CHAR_W_FACTOR = 0.62

local SC_COLORS = {
    Transfixion={255,255,255}, Radiance={255,255,255}, Light={255,255,255}, ['Double Light']={255,255,255},
    Compression={185,175,255}, Darkness={185,175,255}, Umbra={185,175,255}, ['Double Darkness']={185,175,255},
    Induration={0,255,255},    Reverberation={90,140,255}, Scission={205,140,70},
    Detonation={102,255,102},  Liquefaction={255,80,80},   Impaction={255,90,255},
    Gravitation={185,120,75},  Fragmentation={250,156,247}, Fusion={255,120,120}, Distortion={90,170,255},
}
local SC_DISPLAY_NAME = { ['Double Light'] = 'Radiance', ['Double Darkness'] = 'Umbra' }
local function sc_name(prop) return SC_DISPLAY_NAME[prop] or prop end

local function sc_color(rgb)
    return ('\\cs(%d,%d,%d)'):format(rgb[1], rgb[2], rgb[3])
end

local skillchain = {}

local SC_TREE_FONT  = 'Consolas'
local SC_TREE_COLOR = {150, 150, 150}

local SC_MAX_ROWS = 12

local settings
local sc_font_size, sc_prop_font_size
local head_text, prop_text
local tree_rows   = {}
local branch_rows = {}
local cache_key   = nil
local header_label = ''
local prop_label   = ''
local branch_list  = {}
local tree_list    = {}
local tree_indent  = 0
local start_time   = 0
local box_width    = 0
local head_h       = 0
local prop_h       = 0
local box_x, box_y, box_h = nil, nil, 0

local function compute_sc(target_id)
    if not htb_skillchains then return nil end
    if not htb_skillchains.is_initialized then htb_skillchains:initialize() end

    local disp = htb_skillchains:get_chain_display(target_id)
    if not disp then return nil end

    local primary = disp.props[1]
    local header
    if disp.source_name and disp.source_name ~= '' then
        header = sc_color(SC_COLORS[primary] or {255,255,255}) .. disp.source_name .. '\\cr'
    else
        header = sc_color(SC_COLORS[primary] or {255,255,255}) .. sc_name(primary or '?') .. '\\cr'
    end

    local parts = {}
    for _, p in ipairs(disp.props) do
        if p and p ~= 'None' and p ~= '' then
            parts[#parts+1] = sc_color(SC_COLORS[p] or {255,255,255}) .. sc_name(p) .. '\\cr'
        end
    end
    local props = table.concat(parts, ' / ')

    local abilities = windower.ffxi.get_abilities()
    local ws_ids = (abilities and abilities.weapon_skills) or {}
    local entries = {}
    for _, ws_id in ipairs(ws_ids) do
        local ws = _priv.weapon_skill(ws_id)
        if ws then
            local best
            for _, p in ipairs({ ws.skillchain_a, ws.skillchain_b, ws.skillchain_c }) do
                if p and p ~= 'None' and p ~= '' then
                    local opt = disp.options[p]
                    if opt then best = opt; break end
                end
            end
            if best then
                entries[#entries+1] = {
                    name    = ws.en or ws.english or '?',
                    result  = best.property,
                    level   = best.level,
                    upgrade = best.level > disp.current_level,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.upgrade ~= b.upgrade then return a.upgrade end
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)

    local names, tree = {}, {}
    local n = math.min(#entries, SC_MAX_ROWS)
    for i = 1, n do
        local e = entries[i]
        local mark = e.upgrade and (sc_color(SC_PLUS_COLOR) .. '+\\cr') or (sc_color(SC_MINUS_COLOR) .. '-\\cr')
        local name = sc_color(SC_COLORS[e.result] or {255,255,255}) .. e.name .. '\\cr'
        names[i] = name .. ' ' .. mark
        tree[i]  = (i == n) and '└─' or '├─'
    end

    return header, props, names, tree
end

local function sc_scale() return (settings and tonumber(settings.scale)) or 1 end
local function compute_sizes()
    local sc = sc_scale()
    sc_font_size      = math.max(1, math.floor(((settings.font_size or 10) - 2) * sc + 0.5))
    sc_prop_font_size = math.max(1, sc_font_size - math.max(1, math.floor(2 * sc + 0.5)))
    tree_indent = math.ceil(sc_font_size * 1.9)
    box_width   = math.ceil(SC_RESERVE_CHARS * sc_font_size * SC_CHAR_W_FACTOR)
    head_h      = sc_font_size + math.floor(4 * sc + 0.5)
    prop_h      = sc_prop_font_size + math.floor(4 * sc + 0.5)
end

function skillchain.init(s)
    settings = s
    compute_sizes()
    local function mk_cfg(sz)
        return {
            pos   = { x = -300, y = -300 },
            text  = { size = sz, font = settings.font, fonts = {settings.font},
                      stroke = { width = 2, alpha = 200, red = 0, green = 0, blue = 0 } },
            flags = { bold = true, draggable = false },
            bg    = { visible = false },
        }
    end
    head_text   = texts.new('', mk_cfg(sc_font_size))
    prop_text   = texts.new('', mk_cfg(sc_prop_font_size))
    head_text:color(255, 255, 255); head_text:hide()
    prop_text:color(255, 255, 255); prop_text:hide()
    for i = 1, SC_MAX_ROWS do
        local tree_cfg = mk_cfg(sc_font_size)
        tree_cfg.text.font  = SC_TREE_FONT
        tree_cfg.text.fonts = { SC_TREE_FONT, 'Courier New' }
        tree_rows[i]   = texts.new('', tree_cfg)
        tree_rows[i]:color(SC_TREE_COLOR[1], SC_TREE_COLOR[2], SC_TREE_COLOR[3])
        tree_rows[i]:hide()
        branch_rows[i] = texts.new('', mk_cfg(sc_font_size))
        branch_rows[i]:color(255, 255, 255)
        branch_rows[i]:hide()
    end
    cache_key, header_label, prop_label = nil, '', ''
    branch_list, tree_list = {}, {}
    if htb_skillchains and settings.sc_visible and not htb_skillchains.is_initialized then
        htb_skillchains:initialize()
    end
end

function skillchain.apply_scale()
    if not head_text then return end
    compute_sizes()
    head_text:size(sc_font_size); prop_text:size(sc_prop_font_size)
    for i = 1, SC_MAX_ROWS do
        if tree_rows[i] then tree_rows[i]:size(sc_font_size) end
        if branch_rows[i] then branch_rows[i]:size(sc_font_size) end
    end
end

local function hide_rows()
    for i = 1, SC_MAX_ROWS do tree_rows[i]:hide(); branch_rows[i]:hide() end
end

function skillchain.hide()
    if head_text then head_text:hide(); prop_text:hide(); hide_rows() end
    cache_key = nil
    box_x = nil
end

function skillchain.update(target, is_enemy, hpp, bar_x, bar_y, bar_w, bar_h)
    if not head_text then return end
    local function hide_sc() head_text:hide(); prop_text:hide(); hide_rows(); box_x = nil end

    local data = settings.sc_visible and is_enemy and hpp > 0 and htb_skillchains
        and htb_skillchains.sc_properties[target.id] or nil
    local active = data and #data.props > 0 and (os.time() - data.last_update) <= SC_WINDOW
    if not active then
        if data and (os.time() - data.last_update) > SC_WINDOW then
            htb_skillchains.sc_properties[target.id] = nil
        end
        cache_key = nil
        hide_sc()
        return
    end

    local key = target.id .. ':' .. data.last_update
    if key ~= cache_key then
        local hdr, prp, names, tree = compute_sc(target.id)
        header_label = hdr or ''
        prop_label   = prp or ''
        branch_list  = names or {}
        tree_list    = tree or {}
        cache_key    = key
        start_time   = socket.gettime()
    end
    if header_label == '' then hide_sc(); return end

    local elapsed = socket.gettime() - start_time
    local timer_str
    if elapsed < SC_WAIT then
        timer_str = sc_color(SC_WAIT_COLOR) .. ('%.1f'):format(math.max(0, SC_WAIT - elapsed)) .. '\\cr'
    else
        timer_str = sc_color(SC_GO_COLOR) .. ('%.1f'):format(math.max(0, SC_WINDOW - elapsed)) .. '\\cr'
    end

    local off = settings.sc_offset or { x = 0, y = 0 }
    local x = bar_x + bar_w - box_width + (off.x or 0)
    local y = bar_y + bar_h + math.floor(SC_GAP * sc_scale() + 0.5) + (off.y or 0)

    head_text:text('Skillchain: ' .. header_label .. '  ' .. timer_str)
    head_text:pos(x, y)
    head_text:show()

    local next_y = y + head_h
    if prop_label ~= '' then
        prop_text:text('  ' .. prop_label)
        prop_text:pos(x, next_y)
        prop_text:show()
        next_y = next_y + prop_h
    else
        prop_text:hide()
    end

    local rows = #branch_list
    for i = 1, SC_MAX_ROWS do
        if i <= rows then
            local ry = next_y + (i - 1) * prop_h
            tree_rows[i]:text(tree_list[i] or '')
            tree_rows[i]:pos(x, ry)
            tree_rows[i]:show()
            branch_rows[i]:text(branch_list[i] or '')
            branch_rows[i]:pos(x + tree_indent, ry)
            branch_rows[i]:show()
        else
            tree_rows[i]:hide()
            branch_rows[i]:hide()
        end
    end
    next_y = next_y + rows * prop_h
    box_x, box_y, box_h = x, y, next_y - y
end

function skillchain.bounds()
    if box_x and box_y then return box_x, box_y, box_width, box_h end
    return nil
end

function skillchain.on_toggle()
    if settings.sc_visible then
        if htb_skillchains and not htb_skillchains.is_initialized then htb_skillchains:initialize() end
    else
        skillchain.hide()
    end
end

return skillchain
