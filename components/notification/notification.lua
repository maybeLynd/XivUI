-- notification: loot toast that shows drops obtained.
-- XivUI component. Maintainer: maybeLynd. Version: 2.0.

local config    = require('config')
local socket    = require('socket')
local res        = require('resources')
local ui_bounds = require('lib/ui_bounds')

local FONT       = 'Constantia'
local FONT_SZ    = 9
local DURATION   = 1.5
local RISE       = 20
local FADE_START = 0.1
local QUEUE_CAP  = 30
local SETUP_W    = 180
local SETUP_H    = 16
local JOIN_SETUP_W = 230
local JOIN_SETUP_H = 18

local defaults = { pos = { x = 20, y = 300 }, join = { x = 360, y = 220 }, show_party = false, scale = 1, jscale = 1 }
local settings
local function nscale() return (settings and tonumber(settings.scale)) or 1 end
local function jscale() return (settings and tonumber(settings.jscale)) or 1 end

local JOIN_DURATION = 4
local JOIN_FONT_SZ  = 12
local TOAST_MAX     = 1
local toast_pool = {}
local join_txt
local join_active = nil
local queue = {}
local actives = {}
local vis = require('lib/visibility').new()

local function make_txt()
    local t = texts.new('${v}', {
        pos   = { x = 0, y = 0 },
        text  = {
            font   = FONT,
            size   = FONT_SZ,
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

local function member_names()
    local set = {}
    local p = windower.ffxi.get_player()
    if p and p.name then set[p.name:lower()] = true end
    local party = windower.ffxi.get_party()
    if party then
        for i = 0, 5 do
            local m = party['p' .. i]
            if m and m.name then set[m.name:lower()] = true end
        end
    end
    return set
end

local function strip_codes(s)
    local c1e, c1f = string.char(0x1E), string.char(0x1F)
    s = s:gsub(c1e .. '.', ''):gsub(c1f .. '.', '')
    s = s:gsub('%c', '')
    return s
end

local function self_name()
    local p = windower.ffxi.get_player()
    return p and p.name or 'You'
end

local function item_name(id)
    local it = id and id > 0 and res and res.items and res.items[id]
    return it and (it.enl or it.name or it.en) or nil
end

local function norm(s)
    s = s:lower():gsub('^the ', ''):gsub('^an? ', ''):gsub('^%d+ ', '')
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function enqueue(display)
    queue[#queue + 1] = display
    while #queue > QUEUE_CAP do table.remove(queue, 1) end
end

local DEDUP_WINDOW = 4
local recent = {}
local function emit_party(recipient, item, now)
    local k = recipient:lower() .. '|' .. norm(item)
    if recent[k] and now < recent[k] then return end
    for key, exp in pairs(recent) do if now >= exp then recent[key] = nil end end
    recent[k] = now + DEDUP_WINDOW
    enqueue(recipient .. ' obtained ' .. item)
end

local slots = {}
local inv_synced = false
local pending_gains = {}
local recent_dec = {}
local GAIN_SETTLE = 0.5
local GAIN_BURST  = 4

local function trackable(item_id) return item_id and item_id ~= 0 and item_id ~= 0xFFFF end

local function slot_item_id(bag, index)
    local ok, it = pcall(windower.ffxi.get_items, bag, index)
    return (ok and type(it) == 'table' and it.id and it.id ~= 0) and it.id or nil
end

local PRIME_BAGS = {}
for b = 0, 16 do PRIME_BAGS[#PRIME_BAGS + 1] = b end
local function prime_inventory()
    local any = false
    for _, bag in ipairs(PRIME_BAGS) do
        local ok, b = pcall(windower.ffxi.get_items, bag)
        if ok and type(b) == 'table' then
            for index, it in ipairs(b) do
                if type(it) == 'table' and it.id and it.id ~= 0 then
                    slots[bag * 256 + index] = { id = it.id, count = it.count or 1 }
                    any = true
                end
            end
        end
    end
    return any
end

local function cancel_move(item_id, amount, now)
    for i = #recent_dec, 1, -1 do
        local d = recent_dec[i]
        if now >= d.exp then table.remove(recent_dec, i)
        elseif d.item == item_id then table.remove(recent_dec, i); return true end
    end
    return false
end

local function cancel_pending_at(item_id, amount)
    for i = #pending_gains, 1, -1 do
        if amount <= 0 then break end
        local g = pending_gains[i]
        if g.item == item_id then
            local take = math.min(g.count, amount)
            g.count = g.count - take
            amount = amount - take
            if g.count <= 0 then table.remove(pending_gains, i) end
        end
    end
    return amount
end

local notification = {}

function notification.init()
    settings = config.load('data/notification/settings.xml', defaults)
    for i = 1, TOAST_MAX do toast_pool[i] = make_txt() end
    join_txt = make_txt()
    pending_gains = {}
    recent_dec = {}
    slots = {}
    inv_synced = prime_inventory()
end

function notification.dispose()
    for i = 1, #toast_pool do if toast_pool[i] then toast_pool[i]:destroy() end end
    toast_pool = {}
    if join_txt then join_txt:destroy(); join_txt = nil end
    join_active = nil
    queue = {}
    actives = {}
    recent = {}
    pending_gains = {}
    recent_dec = {}
    slots = {}
    inv_synced = false
    ui_bounds.clear('notification')
end

function notification.show()
    vis:show()
end

function notification.hide()
    vis:hide()
    for i = 1, #toast_pool do if toast_pool[i] then toast_pool[i]:hide() end end
    if join_txt then join_txt:hide() end
    ui_bounds.clear('notification')
end

function notification.hud_preview(on) vis:preview(on) end

function notification.hud_set_scale(v)
    settings.scale = math.max(0.5, math.min(2.5, tonumber(v) or 1)); config.save(settings)
end
function notification.hud_set_join_scale(v)
    settings.jscale = math.max(0.5, math.min(2.5, tonumber(v) or 1)); config.save(settings)
end

local function text_extents(t, fw, fh)
    local w, h = 0, 0
    if t then pcall(function() w, h = t:extents() end) end
    w, h = tonumber(w) or 0, tonumber(h) or 0
    if w <= 4 then w = fw end
    if h <= 4 then h = fh end
    return w, h
end

function notification.push_bounds()
    if vis:hidden() or not vis:previewing() then
        ui_bounds.clear('notification'); ui_bounds.clear('notification_join'); return
    end
    local s, js = nscale(), jscale()
    local lw, lh = text_extents(toast_pool and toast_pool[1], SETUP_W * s, SETUP_H * s)
    ui_bounds.register('notification', settings.pos.x, settings.pos.y - 2, math.floor(lw), math.floor(lh))
    local jw, jh = text_extents(join_txt, JOIN_SETUP_W * js, JOIN_SETUP_H * js)
    ui_bounds.register('notification_join', settings.join.x, settings.join.y - 2, math.floor(jw), math.floor(jh))
end

function notification.on_incoming_text(original)
    if vis:hidden() then return end
    local text = strip_codes(original or ''):gsub('^%s+', '')

    local joiner = text:match('^(%a+) joins the party')
    if joiner then
        join_active = { text = joiner .. ' has joined the party.', start = socket.gettime() }
        return
    end

    if not settings.show_party then return end
    local who, item = text:match('^(.-) [Oo]btains? (.+)%.')
    if not item then
        who, item = text:match('^(.-) [Ss]teals? (.-) from ')
    end
    if not who or who == '' or not item then return end
    local sn = self_name()
    if who == 'You' or who:lower() == sn:lower() then return end
    if not member_names()[who:lower()] then return end
    emit_party(who, item, socket.gettime())
end

local function candidate_gain(item_id, amount, now, key)
    if not trackable(item_id) or amount <= 0 then return end
    if not inv_synced then return end
    if vis:hidden() then return end
    if cancel_move(item_id, amount, now) then return end
    pending_gains[#pending_gains + 1] = { item = item_id, count = amount, t = now, key = key }
end

function notification.on_incoming_chunk(id, original)
    if id == 0x00B then
        slots = {}; inv_synced = false; pending_gains = {}; recent_dec = {}
        return
    end
    local count, item_id, bag, index
    if id == 0x020 then
        count   = original:unpack('I', 0x05)
        item_id = original:unpack('H', 0x0D)
        bag     = original:byte(0x0F)
        index   = original:byte(0x10)
    elseif id == 0x01E then
        count = original:unpack('I', 0x05)
        bag   = original:byte(0x09)
        index = original:byte(0x0A)
    else
        return
    end
    if not count or not bag or not index then return end

    local key  = bag * 256 + index
    local prev = slots[key]
    if not item_id then item_id = (prev and prev.id) or slot_item_id(bag, index) end

    local now = socket.gettime()
    if prev == nil then
        slots[key] = { id = item_id, count = count }
        if inv_synced and item_id and id == 0x020 then candidate_gain(item_id, count, now, key) end
        return
    end
    slots[key] = { id = item_id, count = count }

    if item_id == 0xFFFF then
        local delta = count - prev.count
        if delta > 0 and inv_synced and not vis:hidden() then
            enqueue(('Obtained %d gil.'):format(delta))
        end
        return
    end

    if prev.id == item_id then
        local delta = count - prev.count
        if delta == 0 then return end
        if delta < 0 then
            local left = cancel_pending_at(item_id, -delta)
            if left > 0 and trackable(item_id) then
                recent_dec[#recent_dec + 1] = { item = item_id, amount = left, exp = now + GAIN_SETTLE }
            end
            return
        end
        candidate_gain(item_id, delta, now, key)
    else
        if trackable(prev.id) and prev.count > 0 then
            local left = cancel_pending_at(prev.id, prev.count)
            if left > 0 then
                recent_dec[#recent_dec + 1] = { item = prev.id, amount = left, exp = now + GAIN_SETTLE }
            end
        end
        candidate_gain(item_id, count, now, key)
    end
end

local function flush_gains(now)
    if #pending_gains == 0 then return end
    if now - pending_gains[1].t < GAIN_SETTLE then return end
    local batch = pending_gains
    pending_gains = {}
    if #batch <= GAIN_BURST then
        for _, g in ipairs(batch) do
            local name = item_name(g.item) or ('item #' .. tostring(g.item))
            if g.count > 1 then enqueue(('Obtained %d %s.'):format(g.count, name))
            else enqueue('Obtained ' .. name .. '.') end
        end
    end
end

function notification.on_prerender()
    if vis:skip() or not toast_pool[1] then return end

    local pnow = socket.gettime()
    if not inv_synced then
        if prime_inventory() then inv_synced = true
        elseif #pending_gains == 0 and next(slots) ~= nil then inv_synced = true end
    end
    flush_gains(pnow)

    if join_txt then
        if vis:previewing() then
            join_txt.v = 'Player has joined the party.'
            join_txt:size(JOIN_FONT_SZ * jscale())
            join_txt:pos(settings.join.x, settings.join.y)
            join_txt:alpha(255); join_txt:stroke_alpha(200)
            join_txt:show()
        elseif join_active then
            local jp = (socket.gettime() - join_active.start) / JOIN_DURATION
            if jp >= 1 then
                join_active = nil; join_txt:hide()
            else
                local fa = jp < 0.7 and 255 or math.floor(255 * (1 - (jp - 0.7) / 0.3) + 0.5)
                join_txt.v = join_active.text
                join_txt:size(JOIN_FONT_SZ * jscale())
                join_txt:pos(settings.join.x, settings.join.y)
                join_txt:alpha(fa); join_txt:stroke_alpha(math.floor(fa * 200 / 255 + 0.5))
                join_txt:show()
            end
        else
            join_txt:hide()
        end
    end

    local s = nscale()
    local line_h = math.floor((FONT_SZ + 5) * s + 0.5)

    if vis:previewing() then
        local prev = { 'Obtained a fire crystal.', 'Obtained a sheepskin.' }
        for i = 1, #toast_pool do
            local t = toast_pool[i]
            if prev[i] then
                t.v = prev[i]; t:size(FONT_SZ * s)
                t:pos(settings.pos.x, settings.pos.y + (i - 1) * line_h)
                t:alpha(255); t:stroke_alpha(200); t:show()
            else t:hide() end
        end
        return
    end

    local now = socket.gettime()
    while #actives < TOAST_MAX and #queue > 0 do
        actives[#actives + 1] = { text = table.remove(queue, 1), start = now }
    end

    local wr = 0
    for i = 1, #actives do
        local act = actives[i]
        local prog = (now - act.start) / DURATION
        if prog < 1 then
            wr = wr + 1
            actives[wr] = act
            local t = toast_pool[wr]
            local rise = RISE * (1 - (1 - prog) * (1 - prog))
            local fp = (prog - FADE_START) / (1 - FADE_START); if fp < 0 then fp = 0 end
            local a = math.max(0, math.min(255, math.floor(255 * (1 - fp) * (1 - fp) + 0.5)))
            t.v = act.text
            t:size(FONT_SZ * s)
            t:pos(settings.pos.x, settings.pos.y + (wr - 1) * line_h - rise)
            t:alpha(a); t:stroke_alpha(math.floor(a * 200 / 255 + 0.5))
            t:show()
        end
    end
    for i = #actives, wr + 1, -1 do actives[i] = nil end
    for i = wr + 1, #toast_pool do toast_pool[i]:hide() end
end

function notification.handle_command(args)
    if not settings then log('notification: not loaded — log in / enable it first.'); return end
    local cmd = args and args[1] and tostring(args[1]):lower() or 'help'
    if cmd == 'move' or cmd == 'reposition' or cmd == 'setup' then
        (_G.xivui_echo or log)('notification: use the HUD Layout editor (XivUI Menu) to move the toasts.')
    elseif cmd == 'pos' then
        if args[2] and tostring(args[2]):lower() == 'join' then
            local nx, ny = tonumber(args[3]), tonumber(args[4])
            if nx and ny then
                settings.join.x = math.floor(nx)
                settings.join.y = math.floor(ny)
                config.save(settings)
                log('notification: join popup moved to ' .. settings.join.x .. ', ' .. settings.join.y .. '.')
            else
                log('Usage: //xui notify pos join <x> <y>')
            end
            return
        end
        local nx, ny = tonumber(args[2]), tonumber(args[3])
        if nx and ny then
            settings.pos.x = math.floor(nx)
            settings.pos.y = math.floor(ny)
            config.save(settings)
            log('notification: moved to ' .. settings.pos.x .. ', ' .. settings.pos.y .. '.')
        else
            log('Usage: //xui notify pos <x> <y>')
        end
    elseif cmd == 'scale' then
        if args[2] and tostring(args[2]):lower() == 'join' then
            local f = tonumber(args[3])
            if f then settings.jscale = math.max(0.5, math.min(2.5, f)); config.save(settings)
                log('notification: join scale ' .. settings.jscale .. '.')
            else log('Usage: //xui notify scale join <factor>') end
        else
            local f = tonumber(args[2])
            if f then settings.scale = math.max(0.5, math.min(2.5, f)); config.save(settings)
                log('notification: toast scale ' .. settings.scale .. '.')
            else log('Usage: //xui notify scale [join] <factor>') end
        end
    elseif cmd == 'party' or cmd == 'partyloot' then
        local arg = args[2] and tostring(args[2]):lower()
        if arg == 'on' then settings.show_party = true
        elseif arg == 'off' then settings.show_party = false
        else settings.show_party = not settings.show_party end
        config.save(settings)
        log('notification: party-member loot ' .. (settings.show_party and 'shown.' or 'hidden (only your own loot).'))
    elseif cmd == 'test' then
        queue[#queue + 1] = 'Obtained a fresh mythril sand.'
        log('notification: queued a test toast.')
    elseif cmd == 'clear' then
        queue = {}
        actives = {}
        for i = 1, #toast_pool do if toast_pool[i] then toast_pool[i]:hide() end end
        log('notification: cleared.')
    else
        log('notification commands:')
        log('  pos <x> <y> — set exact start position (pos join <x> <y> for the party join popup)')
        log('  scale <0.5-2.5> — scale the toast text (scale join <f> for the party join popup)')
        log('  party [on|off] — also show what party members obtain (default: off, you only)')
        log('  test — queue a sample loot toast')
        log('  clear — drop the queue and current toast')
    end
end

return notification
