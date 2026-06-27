-- requestwindow: party invite and trade request popups.
-- XivUI component. Maintainer: maybeLynd. Version: 2.0.

local ADDON_PATH = windower.addon_path
local IMG_PATH   = ADDON_PATH .. 'assets/components/requestwindow/'
if _G.XIVUI_THEME == 'ffxi' then
    local f = io.open(IMG_PATH .. 'themes/ffxi/dialog.png', 'rb')
    if f then f:close(); IMG_PATH = IMG_PATH .. 'themes/ffxi/' end
end
local _ffxi = (_G.XIVUI_THEME == 'ffxi')
local TXT_MAIN   = _ffxi and { 206, 217, 240 } or { 245, 240, 230 }
local TXT_PILL   = _ffxi and { 214, 224, 242 } or { 255, 255, 255 }
local TXT_BANNER = _ffxi and { 206, 217, 240 } or { 245, 238, 208 }
local PILL_NORMAL = IMG_PATH .. 'pill.png'
local PILL_HOVER  = IMG_PATH .. 'pill_hover.png'
local DLG_PATH    = IMG_PATH .. 'dialog.png'
local BTN_NORMAL  = { IMG_PATH .. 'btn_yes.png',       IMG_PATH .. 'btn_no.png' }
local BTN_HOVER   = { IMG_PATH .. 'btn_yes_hover.png', IMG_PATH .. 'btn_no_hover.png' }
local CLOSE_NORMAL = IMG_PATH .. 'close.png'
local CLOSE_HOVER  = IMG_PATH .. 'close_hover.png'
local BANNER_BG    = IMG_PATH .. 'banner_bg.png'

local config    = require('config')
local socket    = require('socket')
local ui_bounds = require('lib/ui_bounds')
local screen    = require('lib/screen')

local PILL_W   = 150
local PILL_H   = 34
local PILL_GAP = 5
local DLG_W    = 380
local DLG_H    = 104
local BTN_W    = 116
local BTN_H    = 36
local BTN_GAP  = 16
local BTN_Y    = DLG_H - 46
local CLOSE_W  = 34
local CLOSE_R  = 17
local CLOSE_CX = DLG_W - 24
local CLOSE_CY = 22
local MAX_PILLS = 2
local FONT     = 'Constantia'
local TTL      = 120

local BANNER_DUR  = 3.0
local BANNER_HOLD = 0.35
local BANNER_TXT  = 13
local BANNER_H    = 26

local defaults = {
    notify = { x = -1, y = -1 },
    dialog = { x = -1, y = -1 },
    scale = 1,
    dscale = 1,
}
local settings
local function rscale() return (settings and tonumber(settings.scale)) or 1 end
local function dscale() return (settings and tonumber(settings.dscale)) or 1 end

local pills = {}
local dialog
local banner_bg, banner_txt
local banner = nil
local requests = {}
local expanded = nil
local vis = require('lib/visibility').new()
local hovered_btn = 0
local hovered_pill = 0
local hovered_close = false
local last_trade_count = 0

local function make_img(path, w, h, a)
    local img = images.new({
        pos        = { x = 0, y = 0 }, visible = false,
        color      = { alpha = a or 255, red = 255, green = 255, blue = 255 },
        size       = { width = w, height = h },
        texture    = { path = path, fit = true },
        repeatable = { x = 1, y = 1 }, draggable = false,
    })
    img:path(path)
    img:fit(true)
    img:draggable(false)
    img:size(w, h)
    img:alpha(a or 255)
    img:hide()
    return img
end

local function make_txt(sz, bold)
    local t = texts.new('${v}', {
        pos   = { x = 0, y = 0 },
        text  = {
            font   = FONT,
            size   = sz,
            stroke = { width = 2, alpha = 200, red = 10, green = 10, blue = 12 },
        },
        flags = { bold = bold or false, draggable = false },
        bg    = { visible = false },
    })
    t:color(TXT_MAIN[1], TXT_MAIN[2], TXT_MAIN[3])
    t:alpha(255)
    t.v = ''
    t:hide()
    return t
end

local function req_type_label(kind) return kind == 'party' and 'Party Invite' or 'Trade Request' end

local function req_question(kind, name)
    if kind == 'party' then return 'Join ' .. name .. "'s party?" end
    return 'Trade with ' .. name .. '?'
end

local function invite_banner_text(kind, name)
    if kind == 'party' then return name .. ' invites you to a party.' end
    return name .. ' wants to trade with you.'
end

local function send_trade(type_code)
    local ok = pcall(packets.inject, 'outgoing', 0x033, {
        ['Type']        = type_code,
        ['Trade Count'] = last_trade_count,
    })
    if not ok then windower.add_to_chat(123, 'XivUI: failed to send trade response.') end
end

local function req_yes(kind)
    if kind == 'party' then windower.send_command('input /join') else send_trade(0) end
end
local function req_no(kind)
    if kind == 'party' then windower.send_command('input /decline') else send_trade(1) end
end

local function find_request(kind)
    for i, r in ipairs(requests) do
        if r.kind == kind then return i, r end
    end
end

local function add_request(kind, name)
    local _, r = find_request(kind)
    if r then
        r.name = name
        r.expire = socket.gettime() + TTL
    else
        requests[#requests + 1] = { kind = kind, name = name, expire = socket.gettime() + TTL }
    end
    vis:show()
end

local function remove_request(kind)
    local i = find_request(kind)
    if i then table.remove(requests, i) end
    if expanded == kind then expanded = nil end
end

local function show_banner(text)
    banner = { text = text, start = socket.gettime() }
end

local function pill_pos(i)
    return settings.notify.x, settings.notify.y - (i - 1) * (PILL_H + PILL_GAP)
end

local function render_banner(now)
    if not banner_bg then return end
    if not banner then banner_bg:hide(); banner_txt:hide(); return end
    local prog = (now - banner.start) / BANNER_DUR
    if prog >= 1 then banner = nil; banner_bg:hide(); banner_txt:hide(); return end

    local a = 255
    if prog > BANNER_HOLD then
        local fp = (prog - BANNER_HOLD) / (1 - BANNER_HOLD)
        a = math.floor(255 * (1 - fp * fp * (3 - 2 * fp)) + 0.5)
    end
    a = math.max(0, math.min(255, a))

    local rx, ry = screen.size()
    local cx = rx / 2
    local cy = math.floor(ry * 0.52)

    banner_txt.v = banner.text
    local w, h = banner_txt:extents()
    if not w or w <= 0 then w = #banner.text * BANNER_TXT * 0.5 end
    if not h or h <= 0 then h = BANNER_TXT end

    banner_bg:hide()

    banner_txt:pos(math.floor(cx - w / 2), math.floor(cy - h / 2))
    banner_txt:alpha(a)
    banner_txt:stroke_alpha(math.floor(a * 150 / 255 + 0.5))
    banner_txt:show()
end

local function hide_pill(i)
    local p = pills[i]
    if p then p.bg:hide(); p.type:hide(); p.name:hide(); p.num:hide() end
end

local function hide_pills()
    for i = 1, MAX_PILLS do hide_pill(i) end
end

local function hide_dialog()
    if not dialog then return end
    dialog.bg:hide(); dialog.q:hide(); dialog.close:hide()
    for i = 1, 2 do dialog.btns[i].bg:hide() end
end

local function hide_all_objects()
    hide_pills()
    hide_dialog()
end

local function set_path(holder, img, path)
    if holder.cur ~= path then img:path(path); holder.cur = path end
end

local function render_pill(i, kind, name, count)
    local p = pills[i]
    local s = rscale()
    local pw, ph = math.floor(PILL_W * s), math.floor(PILL_H * s)
    local px, py = pill_pos(i)
    set_path(p, p.bg, hovered_pill == i and PILL_HOVER or PILL_NORMAL)
    p.bg:size(pw, ph); p.bg:pos(px, py); p.bg:show()
    p.type:size(9 * s);  p.type.v = req_type_label(kind); p.type:pos(px + math.floor(12 * s), py + math.floor(3 * s)); p.type:show()
    p.name:size(9 * s);  p.name.v = name;                 p.name:pos(px + math.floor(12 * s), py + math.floor(14 * s)); p.name:show()
    p.num:size(17 * s);  p.num.v = tostring(count);       p.num:pos(px + pw - math.floor(12 * s), py + math.floor(8 * s)); p.num:show()
end

local function render_pills(list)
    local n = math.min(#list, MAX_PILLS)
    for i = 1, n do render_pill(i, list[i].kind, list[i].name, #list) end
    for i = n + 1, MAX_PILLS do hide_pill(i) end
end

local function render_dialog(kind, name)
    local s = dscale()
    local dx, dy = settings.dialog.x, settings.dialog.y
    local dw, dh = math.floor(DLG_W * s), math.floor(DLG_H * s)
    local cw = math.floor(CLOSE_W * s)
    local bw, bh = math.floor(BTN_W * s), math.floor(BTN_H * s)
    dialog.bg:size(dw, dh); dialog.bg:pos(dx, dy); dialog.bg:show()
    dialog.q.v = req_question(kind, name)
    dialog.q:size(math.max(6, math.floor(14 * s)))
    dialog.q:pos(dx + math.floor(22 * s), dy + math.floor(20 * s)); dialog.q:show()

    local cwant = hovered_close and CLOSE_HOVER or CLOSE_NORMAL
    if dialog.close_cur ~= cwant then dialog.close:path(cwant); dialog.close_cur = cwant end
    dialog.close:size(cw, cw)
    dialog.close:pos(dx + math.floor(CLOSE_CX * s) - math.floor(cw / 2), dy + math.floor(CLOSE_CY * s) - math.floor(cw / 2))
    dialog.close:show()

    local gap = math.floor(BTN_GAP * s)
    local total = 2 * bw + gap
    local sx = dx + math.floor((dw - total) / 2)
    local by = dy + math.floor(BTN_Y * s)
    for i = 1, 2 do
        local b = dialog.btns[i]
        local bx = sx + (i - 1) * (bw + gap)
        set_path(b, b.bg, hovered_btn == i and BTN_HOVER[i] or BTN_NORMAL[i])
        b.bg:size(bw, bh); b.bg:pos(bx, by); b.bg:show()
    end
end

local requestwindow = {}

function requestwindow.init()
    settings = config.load('data/requestwindow/settings.xml', defaults)

    local rx, ry = screen.size()
    if settings.notify.x < 0 or settings.notify.y < 0 then
        settings.notify.x = rx - PILL_W - 24
        settings.notify.y = ry - PILL_H - 70
    end
    if settings.dialog.x < 0 or settings.dialog.y < 0 then
        settings.dialog.x = math.floor((rx - DLG_W) / 2)
        settings.dialog.y = math.floor(ry * 0.42)
    end
    config.save(settings)

    for i = 1, MAX_PILLS do
        pills[i] = {
            bg    = make_img(PILL_NORMAL, PILL_W, PILL_H, 255),
            cur   = PILL_NORMAL,
            type  = make_txt(10, false),
            name  = make_txt(9, false),
            num   = make_txt(17, true),
        }
        pills[i].type:color(TXT_PILL[1], TXT_PILL[2], TXT_PILL[3])
        pills[i].name:color(TXT_PILL[1], TXT_PILL[2], TXT_PILL[3])
        pills[i].num:color(TXT_PILL[1], TXT_PILL[2], TXT_PILL[3])
        pills[i].num:right_justified(true)
    end

    dialog = {
        bg    = make_img(DLG_PATH, DLG_W, DLG_H, 255),
        q     = make_txt(14, false),
        close = make_img(CLOSE_NORMAL, CLOSE_W, CLOSE_W, 255),
        close_cur = CLOSE_NORMAL,
        btns  = {},
    }
    for i = 1, 2 do
        dialog.btns[i] = { bg = make_img(BTN_NORMAL[i], BTN_W, BTN_H, 255), cur = BTN_NORMAL[i] }
    end

    banner_bg = make_img(BANNER_BG, 400, BANNER_H, 255)
    banner_txt = make_txt(BANNER_TXT, false)
    banner_txt:color(TXT_BANNER[1], TXT_BANNER[2], TXT_BANNER[3])
end

function requestwindow.dispose()
    for i = 1, MAX_PILLS do
        local p = pills[i]
        if p then p.bg:destroy(); p.type:destroy(); p.name:destroy(); p.num:destroy() end
    end
    if dialog then
        dialog.bg:destroy(); dialog.q:destroy(); dialog.close:destroy()
        for i = 1, 2 do dialog.btns[i].bg:destroy() end
    end
    if banner_bg then banner_bg:destroy(); banner_txt:destroy(); banner_bg, banner_txt = nil, nil end
    pills = {}
    dialog = nil
    banner = nil
    requests = {}
    expanded = nil
    ui_bounds.clear('requestwindow')
end

function requestwindow.show()
    vis:show()
end

function requestwindow.hide()
    vis:hide()
    hide_all_objects()
    banner = nil
    if banner_bg then banner_bg:hide(); banner_txt:hide() end
    ui_bounds.clear('requestwindow')
end

function requestwindow.hud_preview(on) vis:preview(on) end

function requestwindow.push_bounds()
    if vis:skip() or not dialog then ui_bounds.clear('requestwindow'); return end
    if vis:previewing() then
        local s = rscale()
        ui_bounds.register('requestwindow', settings.notify.x, settings.notify.y, math.floor(PILL_W * s), math.floor(PILL_H * s)); return
    end
    if expanded and find_request(expanded) then
        local s = dscale()
        ui_bounds.register('requestwindow', settings.dialog.x, settings.dialog.y, math.floor(DLG_W * s), math.floor(DLG_H * s)); return
    end
    local n = math.min(#requests, MAX_PILLS)
    if n > 0 then
        local topy = settings.notify.y - (n - 1) * (PILL_H + PILL_GAP)
        ui_bounds.register('requestwindow', settings.notify.x, topy, PILL_W, n * PILL_H + (n - 1) * PILL_GAP)
    else
        ui_bounds.clear('requestwindow')
    end
end

function requestwindow.on_incoming_chunk(id, original)
    if id == 0x0DC then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if not ok or not p then return end
        local name = p['Inviter Name']
        if name then name = name:gsub('%z.*', '') end
        if not name or name == '' then name = 'Someone' end
        add_request('party', name)
        show_banner(invite_banner_text('party', name))
    elseif id == 0x021 then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if not ok or not p then return end
        last_trade_count = 0
        local mob = p['Player'] and windower.ffxi.get_mob_by_id(p['Player'])
        local tname = mob and mob.name or 'Someone'
        add_request('trade', tname)
        show_banner(invite_banner_text('trade', tname))
    elseif id == 0x023 then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if ok and p and p['Trade Count'] then last_trade_count = p['Trade Count'] end
    end
end

function requestwindow.on_prerender()
    if vis:skip() or not dialog then return end

    if vis:previewing() then
        render_dialog('party', 'PlayerName')
        render_pills({ { kind = 'party', name = 'PlayerName' } })
        return
    end

    render_banner(socket.gettime())

    local now = socket.gettime()
    for i = #requests, 1, -1 do
        if now >= requests[i].expire then
            if expanded == requests[i].kind then expanded = nil end
            table.remove(requests, i)
        end
    end

    local er
    if expanded then local _i; _i, er = find_request(expanded) end
    if er then
        hide_pills()
        render_dialog(er.kind, er.name)
    else
        hide_dialog()
        render_pills(requests)
    end
end

local function pill_at(ux, uy)
    local n = math.min(#requests, MAX_PILLS)
    for i = 1, n do
        local px, py = pill_pos(i)
        if ux >= px and ux <= px + PILL_W and uy >= py and uy <= py + PILL_H then return i end
    end
    return 0
end

local function button_at(ux, uy)
    local s = dscale()
    local dx, dy = settings.dialog.x, settings.dialog.y
    local bw  = math.floor(BTN_W * s)
    local gap = math.floor(BTN_GAP * s)
    local total = 2 * bw + gap
    local sx = dx + math.floor((math.floor(DLG_W * s) - total) / 2)
    local by = dy + math.floor(BTN_Y * s)
    if uy < by or uy > by + math.floor(BTN_H * s) then return 0 end
    for i = 1, 2 do
        local bx = sx + (i - 1) * (bw + gap)
        if ux >= bx and ux <= bx + bw then return i end
    end
    return 0
end

local function close_hit(ux, uy)
    local s = dscale()
    local cx = settings.dialog.x + math.floor(CLOSE_CX * s)
    local cy = settings.dialog.y + math.floor(CLOSE_CY * s)
    local r = CLOSE_R * s
    return (ux - cx) * (ux - cx) + (uy - cy) * (uy - cy) <= r * r
end

function requestwindow.on_mouse(mtype, x, y, delta, blocked)
    if vis:hidden() or not dialog then return false end
    local ux, uy = ui_bounds.to_ui(x, y)

    local er
    if expanded then local _i; _i, er = find_request(expanded) end

    hovered_pill = 0

    if er then
        local dx, dy = settings.dialog.x, settings.dialog.y
        local s = dscale()
        local on = ux >= dx and ux <= dx + math.floor(DLG_W * s) and uy >= dy and uy <= dy + math.floor(DLG_H * s)
        if mtype == 0 then
            hovered_close = close_hit(ux, uy)
            hovered_btn = hovered_close and 0 or button_at(ux, uy)
            return on
        elseif mtype == 1 and on then
            return true
        elseif mtype == 2 and on then
            if close_hit(ux, uy) then
                expanded = nil; hovered_btn = 0; hovered_close = false
                return true
            end
            local b = button_at(ux, uy)
            if b > 0 then
                local kind, nm = er.kind, er.name
                remove_request(kind)
                hovered_btn = 0
                if b == 1 then
                    req_yes(kind)
                    if kind == 'party' then show_banner('You join ' .. nm .. "'s party.") end
                else
                    req_no(kind)
                end
            end
            return true
        end
        return false
    else
        hovered_btn = 0; hovered_close = false
        if mtype == 2 then
            local i = pill_at(ux, uy)
            if i > 0 then expanded = requests[i].kind; hovered_pill = 0; return true end
        elseif mtype == 1 then
            if pill_at(ux, uy) > 0 then return true end
        elseif mtype == 0 then
            hovered_pill = pill_at(ux, uy)
            return hovered_pill > 0
        end
        return false
    end
end

function requestwindow.handle_command(args)
    if not settings then log('requestwindow: not loaded — log in / enable it first.'); return end
    local cmd = args and args[1] and tostring(args[1]):lower() or 'help'
    if cmd == 'move' or cmd == 'reposition' or cmd == 'setup' then
        (_G.xivui_echo or log)('requestwindow: use the HUD Layout editor (XivUI Menu) to move the pill and dialog.')
    elseif cmd == 'pos' then
        local which = args[2] and tostring(args[2]):lower()
        local nx, ny = tonumber(args[3]), tonumber(args[4])
        if (which == 'notify' or which == 'dialog') and nx and ny then
            settings[which].x = math.floor(nx)
            settings[which].y = math.floor(ny)
            config.save(settings)
            log('requestwindow: ' .. which .. ' moved to ' .. settings[which].x .. ', ' .. settings[which].y .. '.')
        else
            log('Usage: //xui request pos <notify|dialog> <x> <y>')
        end
    elseif cmd == 'scale' then
        if args[2] and tostring(args[2]):lower() == 'dialog' then
            local f = tonumber(args[3])
            if f then settings.dscale = math.max(0.5, math.min(2.5, f)); config.save(settings)
                log('requestwindow: dialog scale ' .. settings.dscale .. '.')
            else log('Usage: //xui request scale dialog <factor>') end
        else
            local f = tonumber(args[2])
            if f then settings.scale = math.max(0.5, math.min(2.5, f)); config.save(settings)
                log('requestwindow: pill scale ' .. settings.scale .. '.')
            else log('Usage: //xui request scale [dialog] <factor>') end
        end
    elseif cmd == 'test' then
        local kind = args[2] and tostring(args[2]):lower() == 'trade' and 'trade' or 'party'
        add_request(kind, 'TestPlayer')
        show_banner(invite_banner_text(kind, 'TestPlayer'))
        log('requestwindow: showing a test ' .. kind .. ' notification (click it to expand).')
    else
        log('requestwindow commands:')
        log('  pos <notify|dialog> <x> <y> — set exact position (or use HUD Layout)')
        log('  scale [dialog] <0.5-2.5> — scale the pill, or the dialog (or use HUD Layout)')
        log('  test [party|trade] — show a sample notification')
    end
end

return requestwindow
