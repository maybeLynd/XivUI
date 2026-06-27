-- castbar: FFXIV style spell cast bar with a smaller yellow auto-attack bar above it.
-- XivUI component. Maintainer: maybeLynd.

local SELF_PATH = windower.addon_path .. 'components/castbar/'
local IMG = windower.addon_path .. 'assets/components/castbar/'

local config     = require('config')
local imgcache   = require('lib/img')
local screen     = require('lib/screen')
local defaults   = require('components/castbar/defaults')
local socket     = require('socket')
local ui_bounds  = require('lib/ui_bounds')
local cast_state = require('lib/cast_state')

local CAST_W, CAST_H     = 180, 10
local SWING_W, SWING_H   = 90, 5
local RANGED_W, RANGED_H = 70, 4
local GAP                = 3
local SENTINEL         = -99999
local SCALE_MIN, SCALE_MAX = 0.4, 3.0

local castbar = {}

local settings
local vis = require('lib/visibility').new()
function castbar.hud_preview(on) vis:preview(on) end
local player_id = nil
local test_end  = 0

local cast = { hold = true }
local swing = { last = nil, est = nil, hits = 1, landed = false }
local ranged = { last = nil, est = nil, hits = 1 }
local SWING_MIN = 0.3
local SWING_FLOOR, SWING_CEIL = 0.8, 10.0
local RANGED_MIN = 0.3
local RANGED_FLOOR, RANGED_CEIL = 1.0, 20.0

local cast_visible   = false
local swing_visible  = false
local ranged_visible = false

local CAST_FILL = IMG .. 'cast_fill.png'
local CAST_RED  = IMG .. 'cast_fill_red.png'

local function img_setup()  return { draggable = false } end
local function text_setup() return { flags = { draggable = false } } end

local cast_bg     = images.new(img_setup())
local cast_fill   = images.new(img_setup())
local cast_frame  = images.new(img_setup())
local swing_bg    = images.new(img_setup())
local swing_fill  = images.new(img_setup())
local swing_frame = images.new(img_setup())
local ranged_bg    = images.new(img_setup())
local ranged_fill  = images.new(img_setup())
local ranged_frame = images.new(img_setup())
local cast_name   = texts.new(text_setup())
local cast_time   = texts.new(text_setup())
local swing_mult  = texts.new(text_setup())
local swing_int   = texts.new(text_setup())
local ranged_mult = texts.new(text_setup())
local ranged_int  = texts.new(text_setup())

local function set_cast_fill(path) imgcache.set_path(cast_fill, path) end

local function setup_image(image, path)
    image:path(path)
    image:repeat_xy(1, 1)
    image:fit(false)
    image:draggable(false)
    image:hide()
end

local function setup_text(t, right)
    t:bg_visible(false)
    t:bg_alpha(0)
    t:font('Constantia')
    t:size(11)
    t:color(250, 250, 250)
    t:stroke_width(2)
    t:stroke_transparency(200)
    t:stroke_color(20, 20, 20)
    t:right_justified(right and true or false)
    t:hide()
end

local function build_ui()
    setup_image(cast_bg, IMG .. 'track.png')
    setup_image(cast_fill, CAST_FILL)
    setup_image(cast_frame, IMG .. 'frame.png')
    setup_image(swing_bg, IMG .. 'track.png')
    setup_image(swing_fill, IMG .. 'swing_fill.png')
    setup_image(swing_frame, IMG .. 'frame.png')
    setup_text(cast_name, false)
    setup_text(cast_time, true)
    setup_text(swing_mult, true)
    swing_mult:color(255, 232, 150)
    setup_text(swing_int, false)
    swing_int:color(190, 215, 255)
    setup_image(ranged_bg, IMG .. 'track.png')
    setup_image(ranged_fill, IMG .. 'ranged_fill.png')
    setup_image(ranged_frame, IMG .. 'frame.png')
    setup_text(ranged_mult, true)
    ranged_mult:color(150, 225, 255)
    setup_text(ranged_int, false)
    ranged_int:color(190, 215, 255)
end

local function hide_all_imgs()
    cast_bg:hide(); cast_fill:hide(); cast_frame:hide(); cast_name:hide(); cast_time:hide()
    swing_bg:hide(); swing_fill:hide(); swing_frame:hide(); swing_mult:hide(); swing_int:hide()
    ranged_bg:hide(); ranged_fill:hide(); ranged_frame:hide(); ranged_mult:hide(); ranged_int:hide()
    cast_visible = false
    swing_visible = false
    ranged_visible = false
end

local function ensure_positions()
    if not settings then return end
    local sw, sh = screen.size()
    if settings.Cast.X <= SENTINEL or settings.Cast.Y <= SENTINEL then
        local cw = CAST_W * settings.Cast.Scale
        settings.Cast.X = math.floor(sw / 2 - cw / 2)
        settings.Cast.Y = math.floor(sh * 0.58)
    end
    if settings.Swing.X <= SENTINEL or settings.Swing.Y <= SENTINEL then
        local cw = CAST_W * settings.Cast.Scale
        local sw = SWING_W * settings.Swing.Scale
        local sh = SWING_H * settings.Swing.Scale
        local center = settings.Cast.X + cw / 2
        settings.Swing.X = math.floor(center - sw / 2)
        settings.Swing.Y = math.floor(settings.Cast.Y - sh - GAP)
    end
    if settings.Ranged.X <= SENTINEL or settings.Ranged.Y <= SENTINEL then
        local cw = CAST_W * settings.Cast.Scale
        local rw = RANGED_W * settings.Ranged.Scale
        local rh = RANGED_H * settings.Ranged.Scale
        settings.Ranged.X = math.floor(settings.Cast.X + cw - rw)
        settings.Ranged.Y = math.floor(settings.Swing.Y - rh - GAP)
    end
end

local function set_scale(which, s)
    s = math.max(SCALE_MIN, math.min(SCALE_MAX, s))
    local function rescale(cfg, bw, bh)
        local ow, oh = bw * cfg.Scale, bh * cfg.Scale
        local cx, cy = cfg.X + ow / 2, cfg.Y + oh / 2
        cfg.Scale = s
        cfg.X = math.floor(cx - (bw * s) / 2)
        cfg.Y = math.floor(cy - (bh * s) / 2)
    end
    if which == 'cast' or which == 'both' then rescale(settings.Cast, CAST_W, CAST_H) end
    if which == 'swing' or which == 'both' then rescale(settings.Swing, SWING_W, SWING_H) end
    if which == 'ranged' or which == 'both' then rescale(settings.Ranged, RANGED_W, RANGED_H) end
end

local function engaged()
    local p = windower.ffxi.get_player()
    return p and p.status == 1
end

local function swing_progress()
    if not engaged() then swing.landed = false; return nil end
    if not swing.last or not swing.landed then return nil end
    local now = socket.gettime()
    if now - swing.last > 30 then return nil end
    return math.max(0, math.min(1, (now - swing.last) / (swing.est or 3.0)))
end

local function ranged_progress()
    if not engaged() then return nil end
    if not ranged.last then return nil end
    local now = socket.gettime()
    if now - ranged.last > 30 then return nil end
    return math.max(0, math.min(1, (now - ranged.last) / (ranged.est or 5.0)))
end

local function place_bar(bg, fill, frame, x, y, w, h, prog)
    w, h = math.floor(w), math.floor(h)
    bg:pos(x, y)
    bg:size(w, h)
    bg:show()
    local pad = math.max(1, math.floor(h * 0.2))
    local innerW, innerH = w - 2 * pad, h - 2 * pad
    fill:pos(x + pad, y + pad)
    fill:size(math.max(0, math.floor(innerW * prog)), innerH)
    if prog > 0 then fill:show() else fill:hide() end
    frame:pos(x, y)
    frame:size(w, h)
    frame:show()
end

function castbar.on_prerender()
    if vis:skip() or not settings then return end
    ensure_positions()
    local now = socket.gettime()
    if cast.start_time and not cast_state.is_interrupt(cast) then
        local me = windower.ffxi.get_player()
        if me and cast_state.has_incapacitate(me.buffs) then cast_state.interrupt(cast) end
    end
    local preview = now < test_end or vis:previewing()

    local cprog, cname, ctime
    if settings.ShowCast or vis:previewing() then
        if preview then
            cprog = (now * 0.18) % 1
            cname = 'Cure III'
            ctime = string.format('%.1f', (1 - cprog) * 4)
        else
            cprog = cast_state.progress(cast)
            if cprog then
                if cast_state.is_interrupt(cast) then
                    cname = 'Interrupted'
                    ctime = ''
                else
                    cname = cast.name or ''
                    ctime = cast.duration and string.format('%.1f', math.max(0, cast.duration * (1 - cprog))) or ''
                end
            end
        end
    end
    if cprog then
        local cw = CAST_W * settings.Cast.Scale
        local ch = CAST_H * settings.Cast.Scale
        local cx, cy = settings.Cast.X, settings.Cast.Y
        set_cast_fill(cast_state.is_interrupt(cast) and CAST_RED or CAST_FILL)
        place_bar(cast_bg, cast_fill, cast_frame, cx, cy, cw, ch, cprog)
        local cfs = math.max(6, math.floor(11 * settings.Cast.Scale + 0.5))
        cast_name:size(cfs)
        cast_name:pos(cx + 2, cy + ch + 1)
        cast_name:text(cname or '')
        if cast_state.is_interrupt(cast) then cast_name:color(255, 120, 120) else cast_name:color(250, 250, 250) end
        cast_name:show()
        cast_time:size(cfs)
        cast_time:pos(cx + cw - 2, cy + ch + 1)
        cast_time:text(ctime or '')
        cast_time:show()
        cast_visible = true
    else
        cast_bg:hide(); cast_fill:hide(); cast_frame:hide(); cast_name:hide(); cast_time:hide()
        cast_visible = false
    end

    local sprog
    if settings.ShowSwing or vis:previewing() then
        if preview then sprog = (now * 0.30) % 1 else sprog = swing_progress() end
    end
    if sprog then
        local sw = SWING_W * settings.Swing.Scale
        local sh = SWING_H * settings.Swing.Scale
        local sx = settings.Swing.X
        local sy = settings.Swing.Y
        place_bar(swing_bg, swing_fill, swing_frame, sx, sy, sw, sh, sprog)
        swing_visible = true
        if settings.ShowSwingText then
            local lbl_sz = math.max(6, math.floor(8 * settings.Swing.Scale + 0.5))
            local hits = preview and 2 or swing.hits
            if hits and hits >= 2 then
                swing_mult:size(lbl_sz)
                swing_mult:pos(math.floor(sx + sw), math.floor(sy - sh * 0.55))
                swing_mult:text('x' .. hits)
                swing_mult:show()
            else
                swing_mult:hide()
            end
            local iv = preview and 3.0 or swing.est
            if iv then
                swing_int:size(lbl_sz)
                swing_int:pos(math.floor(sx), math.floor(sy - sh * 0.55))
                swing_int:text(string.format('%.1f', iv))
                swing_int:show()
            else
                swing_int:hide()
            end
        else
            swing_mult:hide(); swing_int:hide()
        end
    else
        swing_bg:hide(); swing_fill:hide(); swing_frame:hide(); swing_mult:hide(); swing_int:hide()
        swing_visible = false
    end

    local rprog
    if settings.ShowRanged or vis:previewing() then
        if preview then rprog = (now * 0.22) % 1 else rprog = ranged_progress() end
    end
    if rprog then
        local rw = RANGED_W * settings.Ranged.Scale
        local rh = RANGED_H * settings.Ranged.Scale
        local rx, ry = settings.Ranged.X, settings.Ranged.Y
        place_bar(ranged_bg, ranged_fill, ranged_frame, rx, ry, rw, rh, rprog)
        ranged_visible = true
        if settings.ShowSwingText then
            local lbl_sz = math.max(6, math.floor(8 * settings.Ranged.Scale + 0.5))
            local hits = preview and 2 or ranged.hits
            if hits and hits >= 2 then
                ranged_mult:size(lbl_sz)
                ranged_mult:pos(math.floor(rx + rw), math.floor(ry - rh * 0.55))
                ranged_mult:text('x' .. hits)
                ranged_mult:show()
            else
                ranged_mult:hide()
            end
            local iv = preview and 5.0 or ranged.est
            if iv then
                ranged_int:size(lbl_sz)
                ranged_int:pos(math.floor(rx), math.floor(ry - rh * 0.55))
                ranged_int:text(string.format('%.1f', iv))
                ranged_int:show()
            else
                ranged_int:hide()
            end
        else
            ranged_mult:hide(); ranged_int:hide()
        end
    else
        ranged_bg:hide(); ranged_fill:hide(); ranged_frame:hide(); ranged_mult:hide(); ranged_int:hide()
        ranged_visible = false
    end
end

local function me_id()
    if player_id then return player_id end
    local p = windower.ffxi.get_player()
    if p then player_id = p.id end
    return player_id
end

function castbar.on_incoming_chunk(id, original)
    if id == 0x029 then
        local message_id = original:unpack('H', 0x19) % 32768
        if cast_state.INTERRUPT_MSGS[message_id]
           and original:unpack('I', 0x05) == me_id() and cast.start_time then
            cast_state.interrupt(cast)
        end
        return
    end
    if id ~= 0x028 then return end
    local ok, act = pcall(windower.packets.parse_action, original)
    if not ok or not act or not act.actor_id then return end
    if act.actor_id ~= me_id() then return end
    local cat = act.category

    if cat == 8 then
        local a1 = act.targets and act.targets[1] and act.targets[1].actions
                   and act.targets[1].actions[1]
        local sid = a1 and a1.param
        local spell = sid and res.spells and res.spells[sid]
        if spell and spell.cast_time and spell.cast_time > 0 then
            cast_state.start(cast, spell.cast_time, spell.en or '...', sid)
        end
    elseif cat == 4 then
        local a1 = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1]
        local msg = a1 and a1.message
        if msg and (cast_state.INTERRUPT_MSGS[msg] or msg == 28) then
            cast_state.interrupt(cast)
        else
            cast_state.complete(cast)
        end
    elseif cat == 1 then
        local now = socket.gettime()
        if swing.last and (now - swing.last) < SWING_MIN then
            return
        end
        if swing.last then
            local d = now - swing.last
            if not swing.est then
                swing.est = math.min(SWING_CEIL, math.max(SWING_FLOOR, d))
            elseif d >= swing.est * 0.6 and d <= swing.est * 1.7 then
                swing.est = swing.est * 0.7 + d * 0.3
            elseif d < swing.est * 0.6 then
                swing.est = math.max(SWING_FLOOR, swing.est * 0.8 + d * 0.2)
            elseif d <= swing.est * 2.5 then
                swing.est = math.min(SWING_CEIL, swing.est * 0.85 + d * 0.15)
            end
        end
        swing.last = now
        local hits = 0
        for _, tgt in ipairs(act.targets or {}) do
            for _, a in ipairs(tgt.actions or {}) do
                local m = a.message
                local landed = (a.param and a.param > 0) or m == 1 or m == 67
                if landed and m ~= 15 and m ~= 63 then
                    hits = hits + 1
                end
            end
        end
        swing.hits = math.max(1, hits)
        swing.landed = true
    elseif cat == 2 then
        local now = socket.gettime()
        if ranged.last and (now - ranged.last) < RANGED_MIN then return end
        if ranged.last then
            local d = now - ranged.last
            if not ranged.est then
                ranged.est = math.min(RANGED_CEIL, math.max(RANGED_FLOOR, d))
            elseif d >= ranged.est * 0.6 and d <= ranged.est * 1.7 then
                ranged.est = ranged.est * 0.7 + d * 0.3
            elseif d < ranged.est * 0.6 then
                ranged.est = math.max(RANGED_FLOOR, ranged.est * 0.8 + d * 0.2)
            elseif d <= ranged.est * 2.5 then
                ranged.est = math.min(RANGED_CEIL, ranged.est * 0.85 + d * 0.15)
            end
        end
        ranged.last = now
        local hits = 0
        for _, tgt in ipairs(act.targets or {}) do
            for _, a in ipairs(tgt.actions or {}) do
                local m = a.message
                local landed = (a.param and a.param > 0) or m == 1 or m == 67
                if landed and m ~= 15 and m ~= 63 then hits = hits + 1 end
            end
        end
        ranged.hits = math.max(1, hits)
    end
end

local function ensure_settings()
    if not settings then settings = config.load('data/castbar/settings.xml', defaults) end
    return settings
end

function castbar.init()
    ensure_settings()
    build_ui()
    ensure_positions()
    player_id = nil
    me_id()
end

function castbar.on_login()
    player_id = nil
    me_id()
end

function castbar.dispose()
    vis:hide()
    hide_all_imgs()
end

function castbar.show()
    vis:show()
end

function castbar.hide()
    vis:hide()
    hide_all_imgs()
    ui_bounds.clear('castbar')
    ui_bounds.clear('castbar_swing')
    ui_bounds.clear('castbar_ranged')
end

function castbar.push_bounds()
    if vis:hidden() or not settings then
        ui_bounds.clear('castbar'); ui_bounds.clear('castbar_swing')
        return
    end
    if cast_visible then
        ui_bounds.register('castbar', settings.Cast.X, settings.Cast.Y,
            CAST_W * settings.Cast.Scale, CAST_H * settings.Cast.Scale)
    else
        ui_bounds.clear('castbar')
    end
    if swing_visible then
        ui_bounds.register('castbar_swing', settings.Swing.X, settings.Swing.Y,
            SWING_W * settings.Swing.Scale, SWING_H * settings.Swing.Scale)
    else
        ui_bounds.clear('castbar_swing')
    end
    if ranged_visible then
        ui_bounds.register('castbar_ranged', settings.Ranged.X, settings.Ranged.Y,
            RANGED_W * settings.Ranged.Scale, RANGED_H * settings.Ranged.Scale)
    else
        ui_bounds.clear('castbar_ranged')
    end
end

local TARGETS = { both = 'both', cast = 'cast', swing = 'swing', aa = 'swing', auto = 'swing', ranged = 'ranged', ra = 'ranged' }

function castbar.handle_command(args)
    ensure_settings()
    local cmd = args[1] and args[1]:lower() or ''

    if cmd == 'move' or cmd == 'reposition' then
        (_G.xivui_echo or log)('castbar: use the HUD Layout editor (XivUI Menu) to move/scale the cast & auto-attack bars.')
    elseif cmd == 'pos' then
        local tgt = args[2] and TARGETS[args[2]:lower()]
        local x, y = tonumber(args[3]), tonumber(args[4])
        if (tgt == 'cast' or tgt == 'swing' or tgt == 'ranged') and x and y then
            local cfg = (tgt == 'cast' and settings.Cast) or (tgt == 'ranged' and settings.Ranged) or settings.Swing
            cfg.X, cfg.Y = math.floor(x), math.floor(y)
            config.save(settings)
            log('castbar: ' .. tgt .. ' moved to ' .. cfg.X .. ', ' .. cfg.Y .. '.')
        else
            log('Usage: //xui cast pos <cast|swing|ranged> <x> <y>')
        end
    elseif cmd == 'scale' then
        local tgt = args[2] and TARGETS[args[2]:lower()] or 'both'
        local f = tonumber(args[3])
        if f then
            set_scale(tgt, f)
            config.save(settings)
            log('castbar: scale (' .. tgt .. ') set.')
        else
            log('Usage: //xui cast scale <cast|swing|ranged|both> <factor>  (e.g. 1.5)')
        end
    elseif cmd == 'cast' or cmd == 'spell' then
        local a = args[2] and args[2]:lower()
        if a == 'on' then settings.ShowCast = true
        elseif a == 'off' then settings.ShowCast = false
        else settings.ShowCast = not settings.ShowCast end
        config.save(settings)
        log('castbar: cast bar ' .. (settings.ShowCast and 'on' or 'off') .. '.')
    elseif cmd == 'swing' or cmd == 'aa' then
        local a = args[2] and args[2]:lower()
        if a == 'on' then settings.ShowSwing = true
        elseif a == 'off' then settings.ShowSwing = false
        else settings.ShowSwing = not settings.ShowSwing end
        config.save(settings)
        log('castbar: swing bar ' .. (settings.ShowSwing and 'on' or 'off') .. '.')
    elseif cmd == 'ranged' or cmd == 'ra' then
        local a = args[2] and args[2]:lower()
        if a == 'on' then settings.ShowRanged = true
        elseif a == 'off' then settings.ShowRanged = false
        else settings.ShowRanged = not settings.ShowRanged end
        config.save(settings)
        log('castbar: ranged bar ' .. (settings.ShowRanged and 'on' or 'off') .. '.')
    elseif cmd == 'swingtext' or cmd == 'aatext' then
        local a = args[2] and args[2]:lower()
        if a == 'on' then settings.ShowSwingText = true
        elseif a == 'off' then settings.ShowSwingText = false
        else settings.ShowSwingText = not settings.ShowSwingText end
        config.save(settings)
        log('castbar: swing-bar text (xN + interval) ' .. (settings.ShowSwingText and 'on' or 'off') .. '.')
    elseif cmd == 'test' then
        test_end = socket.gettime() + 6
        log('castbar: showing a 6s preview.')
    elseif cmd == 'reset' then
        settings.Cast.X, settings.Cast.Y, settings.Cast.Scale = SENTINEL, SENTINEL, 1.0
        settings.Swing.X, settings.Swing.Y, settings.Swing.Scale = SENTINEL, SENTINEL, 1.0
        settings.Ranged.X, settings.Ranged.Y, settings.Ranged.Scale = SENTINEL, SENTINEL, 1.0
        ensure_positions()
        config.save(settings)
        log('castbar: positions and scale reset.')
    else
        log('castbar commands:')
        log('  pos <cast|swing|ranged> <x> <y> — set an exact position')
        log('  scale <cast|swing|ranged|both> <factor> — set scale (0.4–3.0)')
        log('  cast [on|off] — show/hide the spell cast bar')
        log('  swing [on|off] — show/hide the melee auto-attack bar')
        log('  ranged [on|off] — show/hide the ranged-attack bar')
        log('  swingtext [on|off] — show/hide the interval on the attack bars')
        log('  test — show a 6 second preview of both bars')
        log('  reset — recenter and reset scale')
    end
end

return castbar
