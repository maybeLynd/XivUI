-- aggrolist — enemy aggro / claim list.
-- XivUI component. Maintainer: maybeLynd. Version: 1.0.

local ADDON_PATH      = windower.addon_path


local XIV             = ADDON_PATH .. 'assets/components/aggrolist/'
local AGGRO           = XIV
local BG_TOP_PATH     = XIV .. 'BgTop.png'
local BG_MID_PATH     = XIV .. 'BgMid.png'
local BG_BOT_PATH     = XIV .. 'BgBottom.png'
local BAR_BG_PATH     = XIV .. 'BarBG.png'
local BAR_FILL_PATH   = XIV .. 'Bar.png'
local BAR_FG_PATH     = XIV .. 'BarFG.png'
local ORB_SELF_PATH   = AGGRO .. 'aggro_icon.png'
local ORB_PARTY_PATH  = AGGRO .. 'subaggro_icon.png'
local HOVER_PATH      = XIV .. 'Hover.png'
local CURSOR_PATH     = XIV .. 'Cursor.png'

local config     = require('config')
local socket     = require('socket')
local ui_bounds  = require('lib/ui_bounds')




local MAX_ROWS    = 10
local ROW_H       = 26
local ROW_GAP     = 1
local PANEL_PAD   = 3
local BG_TOP_H    = 8
local BG_BOT_H    = 8
local CONTENT_X   = 6
local BAR_W       = 83
local PANEL_W     = PANEL_PAD + CONTENT_X + BAR_W + PANEL_PAD
local ORB_SIZE       = 22
local ORB_PARTY_SIZE = ORB_SIZE
local ORB_X_OFF   = -13
local ORB_Y_OFF   = 2
local NAME_Y_OFF  = 1
local BAR_Y_OFF   = -5
local BAR_H       = 42
local BAR_FILL_OX = 8
local BAR_FILL_MAX= 66
local FONT_SZ     = 10
local FONT        = 'Constantia'

local AGGRO_TTL = 8

local HUD_SAMPLE = { { id = 0, name = 'Aggro List', hpp = 100, is_red = true },
    { id = 0, name = 'Monster', hpp = 62, is_red = false }, { id = 0, name = 'Monster', hpp = 28, is_red = true } }
local defaults  = { pos = { x = 10, y = 400 }, scale = 1 }
local settings
local function ascale() return (settings and tonumber(settings.scale)) or 1 end

local bg_top
local bg_mid
local bg_bot
local rows = {}

local aggro_track = {}
local aggro_list  = {}
local last_build  = 0
local BUILD_INTERVAL = 0.1

local vis = require('lib/visibility').new()
local press_row   = 0
local hovered_row = 0
local pending_target_id    = nil
local pending_search_start = 0
local pending_next_tab     = 0
local pending_tab_count    = 0
local pending_fired_from   = {}
local pending_last_fired   = -1



local function make_img(path, w, h, r, g, b, a)
    local img = images.new({
        pos        = { x = 0, y = 0 }, visible = false,
        color      = { alpha = a, red = r, green = g, blue = b },
        size       = { width = w, height = h },
        texture    = { path = path, fit = true },
        repeatable = { x = 1, y = 1 }, draggable = false,
    })
    img:color(r, g, b)
    img:alpha(a)
    img:path(path)
    img:fit(true)
    img:draggable(false)
    img:size(w, h)
    img:hide()
    return img
end

local function make_txt(sz)
    local t = texts.new('${v}', {
        pos   = { x = 0, y = 0 },
        text  = {
            font   = FONT,
            size   = sz or FONT_SZ,
            stroke = { width = 2, alpha = 200, red = 6, green = 45, blue = 84 },
        },
        flags = { bold = false, draggable = false },
        bg    = { visible = false },
    })
    t:color(240, 255, 255)
    t:alpha(255)
    t.v = ''
    t:hide()
    return t
end

local function panel_height(count)
    local s = ascale()
    return math.floor((BG_TOP_H + count * ROW_H + math.max(0, count - 1) * ROW_GAP + BG_BOT_H) * s)
end



local function get_member_ids()
    local ids = {}
    local player = windower.ffxi.get_player()
    if player and player.id and player.id > 0 then
        ids[player.id] = true
    end
    local party = windower.ffxi.get_party()
    for i = 0, 5 do
        local m = party['p' .. i]
        if m and m.mob then
            if m.mob.id and m.mob.id > 0 then
                ids[m.mob.id] = true
            end
            if m.mob.pet_index and m.mob.pet_index > 0 then
                local pet = windower.ffxi.get_mob_by_index(m.mob.pet_index)
                if pet and pet.id and pet.id > 0 then
                    ids[pet.id] = true
                end
            end
        end
    end
    return ids
end



local function build_aggro_list()
    local now     = socket.gettime()
    if now - last_build < BUILD_INTERVAL then return end
    last_build = now
    local player  = windower.ffxi.get_player()
    local self_id = player and player.id or 0
    local new_list = {}

    for mob_idx, entry in pairs(aggro_track) do
        if now - entry.time > AGGRO_TTL then
            aggro_track[mob_idx] = nil
        else
            local mob = windower.ffxi.get_mob_by_index(mob_idx)
            if mob and mob.hpp and mob.hpp > 0 then
                new_list[#new_list + 1] = {
                    id     = mob_idx,
                    name   = mob.name or '???',
                    hpp    = mob.hpp,
                    is_red = (entry.target_id == self_id),
                }
            else
                aggro_track[mob_idx] = nil
            end
        end
    end

    table.sort(new_list, function(a, b)
        if a.is_red ~= b.is_red then return a.is_red end
        return a.name < b.name
    end)

    aggro_list = new_list
end



local function hide_row(i)
    local r = rows[i]
    if r then
        r.hover:hide();  r.cursor:hide()
        r.orb_self:hide(); r.orb_party:hide()
        r.name:hide();     r.hpp_val:hide()
        r.hp_bg:hide();    r.hp_bar:hide(); r.hp_fg:hide()
    end
end

local function hp_color(hpp)
    if hpp >= 75 then return 255, 255, 255
    elseif hpp >= 50 then return 243, 243, 124
    elseif hpp >= 25 then return 248, 186, 128
    else return 252, 129, 130
    end
end

local function render_row(i, entry, px, py)
    local r  = rows[i]
    local s  = ascale()
    local F  = function(v) return math.floor(v * s) end
    local panel_w, row_h, content_x = F(PANEL_W), F(ROW_H), F(CONTENT_X)
    local bar_w, bar_h, bar_y = F(BAR_W), F(BAR_H), F(BAR_Y_OFF)
    local rx = px + F(PANEL_PAD)
    local ry = py + F(BG_TOP_H) + (i - 1) * (row_h + F(ROW_GAP))
    local orb_y = ry + F(ORB_Y_OFF)

    r.hover:size(panel_w, row_h);  r.hover:pos(px, ry)
    r.cursor:size(panel_w, row_h); r.cursor:pos(px, ry)

    local cur = windower.ffxi.get_mob_by_target('t')
    local cur_idx = cur and cur.index or 0
    if cur_idx > 0 and cur_idx == entry.id then
        r.cursor:alpha(255); r.cursor:show()
    else
        r.cursor:hide()
    end

    local orb_x = rx + F(ORB_X_OFF)
    if entry.is_red then
        local osz = F(ORB_SIZE)
        r.orb_self:size(osz, osz)
        r.orb_self:pos(orb_x, orb_y);  r.orb_self:show()
        r.orb_party:hide()
    else
        local ps  = F(ORB_PARTY_SIZE)
        local off = math.floor((F(ORB_SIZE) - ps) / 2)
        r.orb_party:size(ps, ps)
        r.orb_party:pos(orb_x + off, orb_y + off); r.orb_party:show()
        r.orb_self:hide()
    end

    r.name:size(math.max(6, F(FONT_SZ)))
    r.name.v = entry.name
    r.name:pos(rx + content_x, ry + F(NAME_Y_OFF))
    r.name:show()

    r.hp_bg:size(bar_w, bar_h)
    r.hp_bg:pos(rx + content_x, ry + bar_y)
    r.hp_bg:show()

    local fill_w = math.max(1, math.floor(F(BAR_FILL_MAX) * entry.hpp / 100))
    r.hp_bar:size(fill_w, bar_h)
    r.hp_bar:color(hp_color(entry.hpp))
    r.hp_bar:pos(rx + content_x + F(BAR_FILL_OX), ry + bar_y)
    r.hp_bar:show()

    r.hp_fg:size(bar_w, bar_h)
    r.hp_fg:pos(rx + content_x, ry + bar_y)
    r.hp_fg:show()

    r.hpp_val:size(math.max(6, F(9)))
    r.hpp_val.v = tostring(entry.hpp)
    r.hpp_val:color(hp_color(entry.hpp))
    r.hpp_val:pos(rx + content_x + bar_w - F(18), ry + bar_y + math.floor(bar_h / 2) - F(3))
    r.hpp_val:show()
end

local function render_panel(display_list)
    local count     = math.min(#display_list, MAX_ROWS)
    local s         = ascale()
    local F         = function(v) return math.floor(v * s) end
    local px        = settings.pos.x
    local py        = settings.pos.y
    local panel_w   = F(PANEL_W)
    local content_h = count * F(ROW_H) + math.max(0, count - 1) * F(ROW_GAP)

    bg_top:size(panel_w, F(BG_TOP_H))
    bg_top:pos(px, py)
    bg_top:show()

    bg_mid:size(panel_w, content_h)
    bg_mid:pos(px, py + F(BG_TOP_H))
    bg_mid:show()

    bg_bot:size(panel_w, F(BG_BOT_H))
    bg_bot:pos(px, py + F(BG_TOP_H) + content_h)
    bg_bot:show()

    for i = 1, count            do render_row(i, display_list[i], px, py) end
    for i = count + 1, MAX_ROWS do hide_row(i) end
end




local aggrolist = {}

function aggrolist.init()
    settings = config.load('data/aggrolist/settings.xml', defaults)

    bg_top = make_img(BG_TOP_PATH, PANEL_W, BG_TOP_H, 255, 255, 255, 221)
    bg_mid = make_img(BG_MID_PATH, PANEL_W, BG_TOP_H, 255, 255, 255, 221)
    bg_bot = make_img(BG_BOT_PATH, PANEL_W, BG_BOT_H, 255, 255, 255, 221)


    for i = 1, MAX_ROWS do
        rows[i] = {
            hover  = make_img(HOVER_PATH,  PANEL_W, ROW_H, 255, 255, 255, 170),
            cursor = make_img(CURSOR_PATH, PANEL_W, ROW_H, 255, 255, 255, 255),
        }
    end
    for i = 1, MAX_ROWS do
        local r = rows[i]
        r.hp_bg     = make_img(BAR_BG_PATH,   BAR_W,        BAR_H, 255, 255, 255, 220)
        r.hp_bar    = make_img(BAR_FILL_PATH,  BAR_FILL_MAX, BAR_H, 255, 255, 255, 255)
        r.hp_fg     = make_img(BAR_FG_PATH,    BAR_W,        BAR_H, 255, 255, 255, 200)
        r.orb_self  = make_img(ORB_SELF_PATH,  ORB_SIZE, ORB_SIZE,  255, 255, 255, 255)
        r.orb_party = make_img(ORB_PARTY_PATH, ORB_SIZE, ORB_SIZE,  255, 255, 255, 255)
        r.name      = make_txt(FONT_SZ)
        r.hpp_val   = make_txt(9)
    end
end

function aggrolist.dispose()
    if bg_top then bg_top:destroy(); bg_top = nil end
    if bg_mid then bg_mid:destroy(); bg_mid = nil end
    if bg_bot then bg_bot:destroy(); bg_bot = nil end
    for i = 1, MAX_ROWS do
        local r = rows[i]
        if r then
            r.hover:destroy();    r.cursor:destroy()
            r.hp_bg:destroy();    r.hp_bar:destroy();  r.hp_fg:destroy()
            r.orb_self:destroy(); r.orb_party:destroy()
            r.name:destroy();     r.hpp_val:destroy()
        end
    end
    rows        = {}
    aggro_track = {}
    aggro_list  = {}
    press_row              = 0
    hovered_row            = 0
    pending_target_id      = nil
    pending_search_start   = 0
    pending_next_tab       = 0
    pending_tab_count      = 0
    pending_fired_from     = {}
    pending_last_fired     = -1
    ui_bounds.clear('aggrolist')
end

function aggrolist.show()
    vis:show()
end

function aggrolist.hud_preview(on) vis:preview(on) end

function aggrolist.push_bounds()
    if vis:skip() or not bg_top then ui_bounds.clear('aggrolist'); return end
    local display = (vis:previewing() and HUD_SAMPLE) or aggro_list
    local count   = math.min(#display, MAX_ROWS)
    if count == 0 then ui_bounds.clear('aggrolist'); return end
    ui_bounds.register('aggrolist', settings.pos.x, settings.pos.y, math.floor(PANEL_W * ascale()), panel_height(count))
end

function aggrolist.hide()
    vis:hide()
    if bg_top then bg_top:hide() end
    if bg_mid then bg_mid:hide() end
    if bg_bot then bg_bot:hide() end
    for i = 1, MAX_ROWS do hide_row(i) end
    ui_bounds.clear('aggrolist')
end

function aggrolist.on_incoming_chunk(id, original)
    if id ~= 0x028 then return end
    local ok, action = pcall(windower.packets.parse_action, original)
    if not ok or not action or not action.actor_id or action.actor_id == 0 then return end

    local actor = windower.ffxi.get_mob_by_id(action.actor_id)
    if not actor or not actor.is_npc or actor.in_party then return end
    if not actor.hpp or actor.hpp <= 0 then return end

    local member_ids = get_member_ids()

    for _, tgt in ipairs(action.targets or {}) do
        if tgt.id and tgt.id > 0 and member_ids[tgt.id] then
            aggro_track[actor.index] = {
                target_id = tgt.id,
                time      = socket.gettime(),
            }
            break
        end
    end
end

function aggrolist.on_prerender()
    if vis:skip() or not bg_top then return end

    if vis:previewing() then
        render_panel(HUD_SAMPLE)
        return
    end

    if pending_target_id then
        local now = socket.gettime()
        local cur = windower.ffxi.get_mob_by_target('t')

        local ci = cur and cur.index or 0


        if ci == pending_target_id then
            pending_target_id = nil; pending_tab_count = 0
            pending_fired_from = {}; pending_last_fired = -1
            return
        end


        local want = windower.ffxi.get_mob_by_index(pending_target_id)
        if not want or not want.hpp or want.hpp <= 0 then
            pending_target_id = nil; pending_tab_count = 0
            pending_fired_from = {}; pending_last_fired = -1
            return
        end


        if now - pending_search_start > 5.0 then
            pending_target_id = nil; pending_tab_count = 0
            pending_fired_from = {}; pending_last_fired = -1
            return
        end


        if now >= pending_next_tab and ci ~= pending_last_fired then

            if pending_tab_count > 0 and pending_fired_from[ci] then
                pending_target_id = nil; pending_tab_count = 0
                pending_fired_from = {}; pending_last_fired = -1
                return
            end
            pending_fired_from[ci] = true
            pending_last_fired = ci
            windower.send_command('setkey tab down; wait 0.02; setkey tab up')
            pending_next_tab  = now + 0.15
            pending_tab_count = pending_tab_count + 1
        end
    end

    build_aggro_list()

    if #aggro_list == 0 then
        bg_top:hide(); bg_mid:hide(); bg_bot:hide()
        for i = 1, MAX_ROWS do hide_row(i) end
        return
    end

    render_panel(aggro_list)
end

function aggrolist.on_mouse(type, x, y, delta, blocked)
    if vis:hidden() or not bg_top then return false end
    local ux, uy = ui_bounds.to_ui(x, y)

    local count    = math.min(#aggro_list, MAX_ROWS)
    if count == 0 then return false end

    local px      = settings.pos.x
    local py      = settings.pos.y
    local ph      = panel_height(count)
    local on_panel = ux >= px and ux <= px + PANEL_W
                  and uy >= py and uy <= py + ph

    if not on_panel then
        if hovered_row > 0 and rows[hovered_row] then rows[hovered_row].hover:hide() end
        hovered_row = 0
        return false
    end

    if type == 0 then
        local new_hover = 0
        for i = 1, count do
            local ry = py + BG_TOP_H + (i - 1) * (ROW_H + ROW_GAP)
            if uy >= ry and uy < ry + ROW_H then
                new_hover = i
                break
            end
        end
        if new_hover ~= hovered_row then
            if hovered_row > 0 and rows[hovered_row] then rows[hovered_row].hover:hide() end
            hovered_row = new_hover
            if hovered_row > 0 and rows[hovered_row] then rows[hovered_row].hover:show() end
        end
    elseif type == 1 then
        press_row = 0
        for i = 1, count do
            local ry = py + BG_TOP_H + (i - 1) * (ROW_H + ROW_GAP)
            if uy >= ry and uy < ry + ROW_H then
                press_row = i
                break
            end
        end
    elseif type == 2 and press_row > 0 then
        local entry = aggro_list[press_row]
        press_row = 0
        if entry then
            pending_target_id     = entry.id
            pending_search_start  = socket.gettime()
            pending_next_tab      = 0
            pending_tab_count     = 0
            pending_fired_from    = {}
            pending_last_fired    = -1
        end
    end
    return true
end


function aggrolist.handle_command(args)
    local cmd = args and args[1] and tostring(args[1]):lower() or 'help'
    if not settings then log('aggrolist: not loaded yet — log in first (or enable the component).'); return end
    if cmd == 'move' or cmd == 'reposition' or cmd == 'setup' then
        (_G.xivui_echo or log)('aggrolist: use the HUD Layout editor (XivUI Menu) to move the aggro list.')
    elseif cmd == 'scale' then
        local f = tonumber(args[2])
        if f then settings.scale = math.max(0.5, math.min(2.5, f)); config.save(settings)
            log('aggrolist: scale ' .. settings.scale .. '.')
        else log('Usage: //xui aggro scale <factor>') end
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            settings.pos.x = math.floor(x)
            settings.pos.y = math.floor(y)
            config.save(settings)
            vis:show()
            log('aggrolist: moved to ' .. settings.pos.x .. ', ' .. settings.pos.y .. '.')
        else
            log('Usage: //xui aggro pos <x> <y>')
        end
    else
        log('aggrolist commands:')
        log('  pos <x> <y> — set exact aggro list position (or use HUD Layout)')
        log('  scale <0.5-2.5> — set the aggro list scale (or use HUD Layout)')
    end
end

return aggrolist
