_addon.name = 'XivUI'
_addon.author = 'maybeLynd'
_addon.version = '0.2.0'
_addon.commands = {'xivui', 'xui', 'htb'}

config = require('config')
texts = require('texts')
images = require('images')
packets = require('packets')
res = require('resources')
resources = res
require('logger')
require('strings')
require('lists')
require('tables')

do
    local real_gws = windower.get_windower_settings
    local cached, last = nil, 0
    windower.get_windower_settings = function()
        local now = os.clock()
        if not cached or now - last > 2 then cached, last = real_gws(), now end
        return cached
    end
end

local zone_state   = require('lib/zone_state')
local player_state = require('lib/player_state')
local ui_bounds    = require('lib/ui_bounds')
local occlusion    = require('lib/occlusion')

local perf_clock = (function()
    if _G.socket and _G.socket.gettime then return _G.socket.gettime end
    local ok, sock = pcall(require, 'socket')
    if ok and sock and sock.gettime then return sock.gettime end
    return os.clock
end)()
_G.XIVUI_PERF = { on = false, t = {}, frames = 0, mem0 = 0, start = 0, clock = perf_clock }

_G.XIVUI_FPSCAP = { on = false, n = 0, t0 = 0, mode = '' }

do
    local ok, ts = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
    _G.XIVUI_THEME = (ok and type(ts) == 'table' and ts.Theme) or 'ffxiv'
end

local statusbar  = require('components/statusbar/statusbar')
local expbar     = require('components/expbar/expbar')
local targetbar  = require('components/targetbar/targetbar')
local xivparty   = require('components/xivparty/xivparty')
local xivhotbar3 = require('components/xivhotbar3/xivhotbar3')
local aggrolist  = require('components/aggrolist/aggrolist')
local dps        = require('components/dps/dps')
local requestwindow = require('components/requestwindow/requestwindow')
local notification  = require('components/notification/notification')
local castbar       = require('components/castbar/castbar')
local enemyloot     = require('components/enemyloot/enemyloot')
local enemyweak     = require('components/enemyweak/enemyweak')
local xivuimenu     = require('components/xivuimenu/xivuimenu')

local components = {
    { name = 'statusbar',     mod = statusbar },
    { name = 'expbar',        mod = expbar },
    { name = 'targetbar',     mod = targetbar },
    { name = 'xivparty',      mod = xivparty },
    { name = 'xivhotbar3',    mod = xivhotbar3 },
    { name = 'aggrolist',     mod = aggrolist },
    { name = 'dps',           mod = dps, enabled = false },
    { name = 'requestwindow', mod = requestwindow },
    { name = 'notification',  mod = notification },
    { name = 'castbar',       mod = castbar, enabled = false },
    { name = 'enemyloot',     mod = enemyloot, enabled = false },
    { name = 'enemyweak',     mod = enemyweak, enabled = false },
    { name = 'xivuimenu',     mod = xivuimenu },
}
for _, c in ipairs(components) do if c.enabled == nil then c.enabled = true end end

local comp_enabled = config.load('data/xivui/components.xml', { enabled = {} })
for _, c in ipairs(components) do
    local saved = comp_enabled.enabled and comp_enabled.enabled[c.name]
    if saved ~= nil and c.name ~= 'xivuimenu' then
        c.enabled = (saved == true or saved == 'true')
    end
end
local function save_comp_enabled(name, on)
    comp_enabled.enabled = comp_enabled.enabled or {}
    comp_enabled.enabled[name] = on and true or false
    config.save(comp_enabled)
end

local dbg
local DISPATCH_AREA = {
    init = 'life', dispose = 'life', show = 'life', hide = 'life',
}

local dispatch_err = {}
local function dispatch(c, ev, ...)
    local fn = c.enabled and c.mod[ev]
    if not fn then return nil end
    if _G.XIVUI_DEBUG then
        local area = DISPATCH_AREA[ev]
        if area then dbg(area, c.name .. ':' .. ev) end
    end
    local ok, ret = pcall(fn, ...)
    if ok then return ret end
    local key = c.name .. '.' .. ev
    if not dispatch_err[key] then
        dispatch_err[key] = true
        windower.add_to_chat(167, ('[XivUI] %s.%s error (further suppressed): %s'):format(c.name, ev, tostring(ret)))
    end
    if _G.XIVUI_DEBUG then dbg('error', ('%s.%s error: %s'):format(c.name, ev, tostring(ret))) end
    return nil
end

local function dispatch_menu_err(fn, err)
    local key = 'xivuimenu.' .. fn
    if not dispatch_err[key] then
        dispatch_err[key] = true
        windower.add_to_chat(167, ('[XivUI] xivuimenu.%s error (further suppressed): %s'):format(fn, tostring(err)))
    end
end

local DEBUG_FLAG = windower.addon_path .. 'data/debug_enabled'
local DEBUG_NOISY = { mouse = true, key = true, vitals = true, packet = true }
local DEBUG_AREAS = { 'event', 'life', 'enable', 'cmd', 'firstrun', 'target', 'menu', 'error',
                      'mouse', 'key', 'vitals', 'packet' }
local dbg_area_off = {}
local dbg_area_on  = {}
do
    local f = io.open(DEBUG_FLAG, 'r')
    if f then
        local body = f:read('*all') or ''
        f:close()
        _G.XIVUI_DEBUG = true
        _G.XIVUI_DEBUG_VERBOSE = body:find('verbose') ~= nil
    else
        _G.XIVUI_DEBUG = false
        _G.XIVUI_DEBUG_VERBOSE = false
    end
end
local real_print, real_log = print, log
_G.xivui_echo = function(...)
    if real_log then real_log(...) else real_print(...) end
end
_G.print = function(...) if _G.XIVUI_DEBUG then real_print(...) end end
_G.log = function(...)
    if _G.XIVUI_DEBUG then
        if real_log then real_log(...) else real_print(...) end
    end
end
local function dbg_area_enabled(area)
    if not _G.XIVUI_DEBUG then return false end
    if dbg_area_off[area] then return false end
    if DEBUG_NOISY[area] then return _G.XIVUI_DEBUG_VERBOSE == true or dbg_area_on[area] == true end
    return true
end
_G.xivui_dbg = function(area, msg)
    if not dbg_area_enabled(area) then return end
    windower.add_to_chat(207, '[XivUI:' .. area .. '] ' .. tostring(msg))
end
dbg = _G.xivui_dbg
local function save_debug_flag()
    if _G.XIVUI_DEBUG then
        if windower.create_dir then pcall(windower.create_dir, windower.addon_path .. 'data') end
        local f = io.open(DEBUG_FLAG, 'w')
        if f then f:write(_G.XIVUI_DEBUG_VERBOSE and 'on verbose\n' or 'on\n'); f:close() end
    else
        os.remove(DEBUG_FLAG)
    end
end
local function set_debug(on)
    _G.XIVUI_DEBUG = on == true
    if not on then _G.XIVUI_DEBUG_VERBOSE = false end
    save_debug_flag()
end

local comp = {}
for _, c in ipairs(components) do comp[c.name] = c end

local cmd_to_comp = {
    status  = 'statusbar',
    exp     = 'expbar',
    target  = 'targetbar',
    party   = 'xivparty',
    aggro   = 'aggrolist',
    dps     = 'dps',
    request = 'requestwindow',
    notify  = 'notification',
    cast    = 'castbar',
    loot    = 'enemyloot',
    weak    = 'enemyweak',
    menu    = 'xivuimenu',
    xivuimenu = 'xivuimenu',
}
local COMPONENT_WORDS = 'status, exp, target, party, aggro, dps, hotbar, request, notify, cast, loot, weak, menu'

local is_logged_in = false
local is_cutscene = false
local ui_hidden = false
local zone_reveal_pending = false

local SCRLK_DIK = 70
local F12_DIK   = 88

local ffxidb_hidden_by_us = false
local ffxidb_x            = nil
local ffxidb_y            = nil

local function read_ffxidb_pos()
    local base = windower.addon_path:match('(.+)[/\\][Aa]ddons[/\\]')
    if not base then return nil end
    local f = io.open(base .. '/plugins/settings/ffxidb.xml', 'r')
    if not f then return nil end
    local content = f:read('*all')
    f:close()
    local player = windower.ffxi.get_player()
    local name   = player and player.name
    local x, y
    if name then
        local section = content:match('<' .. name .. '>(.-)</' .. name .. '>')
        if section then
            x = tonumber(section:match('<X>([-%.%d]+)</X>'))
            y = tonumber(section:match('<Y>([-%.%d]+)</Y>'))
        end
    end
    if not x or not y then
        local global = content:match('<global>(.-)</global>')
        if global then
            x = tonumber(global:match('<X>([-%.%d]+)</X>'))
            y = tonumber(global:match('<Y>([-%.%d]+)</Y>'))
        end
    end
    if not x or not y or x <= -9000 or y <= -9000 then return nil end
    return x, y
end

local function init_ffxidb_pos()
    local x, y = read_ffxidb_pos()
    ffxidb_x = x or 0
    ffxidb_y = y or 0
end

local function capture_ffxidb_pos()
    if ffxidb_hidden_by_us then return end
    local x, y = read_ffxidb_pos()
    if x and y then ffxidb_x, ffxidb_y = x, y end
end

local function hide_external()
    if not ffxidb_hidden_by_us then
        capture_ffxidb_pos()
    end
    if ffxidb_x and not ffxidb_hidden_by_us then
        windower.send_command('ffxidb pos -9999 -9999')
        ffxidb_hidden_by_us = true
    end
end

local function show_external()
    if ffxidb_hidden_by_us and ffxidb_x then
        windower.send_command('ffxidb pos ' .. ffxidb_x .. ' ' .. ffxidb_y)
        ffxidb_hidden_by_us = false
    end
end

local function hide_components()
    for _, c in ipairs(components) do
        dispatch(c, 'hide')
    end
end

local function show_all()
    if ui_hidden then dbg('life', 'show_all skipped (UI hidden)'); return end
    dbg('life', 'show_all')
    for _, c in ipairs(components) do
        dispatch(c, 'show')
    end
    show_external()
end

local function hide_all()
    dbg('life', 'hide_all')
    hide_components()
    hide_external()
end

local drag_lock_id = nil
local ui_shift_held = false
local function release_ui_shift()
    if ui_shift_held then
        windower.send_command('setkey lshift up')
        ui_shift_held = false
    end
end
local hud_camera_locked = false
local function set_hud_camera_lock(on)
    if on and not hud_camera_locked then
        release_ui_shift()
        windower.send_command('setkey lshift down'); hud_camera_locked = true
        dbg('menu', 'HUD camera lock ON')
    elseif not on and hud_camera_locked then
        windower.send_command('setkey lshift up'); hud_camera_locked = false
        dbg('menu', 'HUD camera lock OFF')
    end
end
local function register_drag_camera_lock()
    if drag_lock_id then windower.unregister_event(drag_lock_id); drag_lock_id = nil end
    drag_lock_id = windower.register_event('mouse', function(type, x, y, delta, blocked)
        if hud_camera_locked then return end
        if ui_hidden or is_cutscene or zone_state.hidden() then return end
        if type == 2 or type == 4 then release_ui_shift() end
        if type == 1 and ui_bounds.hover_test(x, y) then
            release_ui_shift()
            windower.send_command('setkey lshift down')
            ui_shift_held = true
        end
    end)
end

local function init_all()
    local on = {}
    for _, c in ipairs(components) do if c.enabled then on[#on + 1] = c.name end end
    dbg('life', 'init_all — enabled: ' .. (#on > 0 and table.concat(on, ', ') or '(none)'))
    ui_shift_held = false
    windower.send_command('setkey lshift up')
    for _, c in ipairs(components) do
        dispatch(c, 'init')
        if c.enabled then c.inited = true end
    end
    register_drag_camera_lock()
end

local LAYOUT_FILE   = windower.addon_path .. 'components/xivuimenu/hud_layout/hud_layout.lua'
local LAYOUT_MARKER = windower.addon_path .. 'data/hud_layout_applied'
local first_run_apply_due = nil
local first_run_deadline = nil
local first_run_reload_due = nil

local function _file_present(p) local f = io.open(p, 'r'); if f then f:close(); return true end; return false end

local function mark_layout_applied()
    if windower.create_dir then pcall(windower.create_dir, windower.addon_path .. 'data') end
    local f = io.open(LAYOUT_MARKER, 'w'); if f then f:write('applied\n'); f:close() end
end
_G.XIVUI_MARK_LAYOUT_APPLIED = mark_layout_applied

local function schedule_first_run_apply()
    if first_run_apply_due then return end
    if not _file_present(LAYOUT_FILE) then return end
    if _file_present(LAYOUT_MARKER) then return end
    first_run_apply_due = os.clock() + 0.2
    first_run_deadline  = os.clock() + 6.0
end

local function dispose_all()
    dbg('life', 'dispose_all')
    for _, c in ipairs(components) do
        if c.inited and c.mod.dispose then pcall(c.mod.dispose) end
        c.inited = false
    end
    set_hud_camera_lock(false)
    release_ui_shift()
    if drag_lock_id then windower.unregister_event(drag_lock_id); drag_lock_id = nil end
end

local COMPONENT_PREREQS = { enemyweak = { 'targetbar' }, enemyloot = { 'targetbar' } }

local function missing_prereq(c)
    for _, req in ipairs(COMPONENT_PREREQS[c.name] or {}) do
        local rc = comp[req]
        if not (rc and rc.enabled) then return req end
    end
    return nil
end

local function set_component_enabled(c, on)
    local echo = _G.xivui_echo or print
    dbg('enable', ('toggle %s -> %s (forcing=%s)'):format(c.name, on and 'ON' or 'OFF', tostring(_G.XIVUI_FORCING == true)))
    if on then
        if not c.enabled then
            if not _G.XIVUI_FORCING then
                local req = missing_prereq(c)
                if req then
                    echo(('[XivUI] %s requires %s — enable %s first (//xui enable %s).'):format(c.name, req, req, req))
                    dbg('enable', ('%s enable REFUSED — prerequisite %s is disabled'):format(c.name, req))
                    return
                end
            end
            c.enabled = true
            if is_logged_in then
                local ok, err = pcall(function()
                    if not c.inited and c.mod.init then c.mod.init() end
                    c.inited = true
                    if c.mod.activate then c.mod.activate() end
                    if not zone_state.hidden() and not is_cutscene and c.mod.show then c.mod.show() end
                end)
                if not ok then
                    echo(('[XivUI] %s failed to enable: %s'):format(c.name, tostring(err)))
                    dbg('enable', ('%s enable FAILED, rolled back: %s'):format(c.name, tostring(err)))
                    c.enabled = false
                    c.inited = false
                    if c.mod.hide then pcall(c.mod.hide) end
                    save_comp_enabled(c.name, false)
                    return
                end
            end
            save_comp_enabled(c.name, true)
            dbg('enable', c.name .. ' ENABLED' .. (is_logged_in and (c.inited and ' (shown)' or '') or ' (deferred to login)'))
        else
            dbg('enable', c.name .. ' already enabled — no change')
        end
    else
        if c.enabled then
            c.enabled = false
            local ok, err = pcall(function()
                if c.mod.hide then c.mod.hide() end
                if c.mod.deactivate then c.mod.deactivate() end
            end)
            if not ok then echo(('[XivUI] %s error while disabling: %s'):format(c.name, tostring(err))) end
            save_comp_enabled(c.name, false)
            dbg('enable', c.name .. ' DISABLED (hidden; objects retained)')
            if not _G.XIVUI_FORCING then
                for dep, reqs in pairs(COMPONENT_PREREQS) do
                    for _, req in ipairs(reqs) do
                        if req == c.name then
                            local dc = comp[dep]
                            if dc and dc.enabled then
                                dbg('enable', ('cascade: disabling %s because its prerequisite %s was disabled'):format(dep, c.name))
                                set_component_enabled(dc, false)
                                echo(('[XivUI] %s requires %s — disabling %s too.'):format(dep, c.name, dep))
                            end
                        end
                    end
                end
            end
        else
            dbg('enable', c.name .. ' already disabled — no change')
        end
    end
end

for dep in pairs(COMPONENT_PREREQS) do
    local dc = comp[dep]
    if dc and dc.enabled and missing_prereq(dc) then
        dc.enabled = false
        save_comp_enabled(dep, false)
        dbg('enable', ('load reconcile: %s forced OFF (prerequisite %s is disabled in components.xml)'):format(dep, missing_prereq(dc) or '?'))
    end
end

_G.XIVUI_STATE = {
    components  = components,
    set_enabled = function(name, on) local c = comp[name]; if c then set_component_enabled(c, on) end end,
    hud_camera_lock = set_hud_camera_lock,
}

windower.register_event('load', function()
    dbg('event', 'load (logged_in=' .. tostring(windower.ffxi.get_info().logged_in) .. ')')
    if windower.ffxi.get_info().logged_in then
        player_state.refresh()
        init_ffxidb_pos()
        init_all()
        show_all()
        is_logged_in = true
        schedule_first_run_apply()
    end
end)

windower.register_event('login', function()
    dbg('event', 'login')
    player_state.refresh()
    ui_hidden = false
    init_ffxidb_pos()
    init_all()
    show_all()
    is_logged_in = true
    is_cutscene = false
    if comp.targetbar.enabled and targetbar.on_login then targetbar.on_login() end
    if comp.dps.enabled and dps.on_login then dps.on_login() end
    if comp.castbar.enabled and castbar.on_login then castbar.on_login() end
    schedule_first_run_apply()
end)

windower.register_event('logout', function()
    dbg('event', 'logout')
    is_logged_in = false
    is_cutscene = false
    hide_components()
    dispose_all()
end)

windower.register_event('unload', function()
    dbg('event', 'unload')
    dispose_all()
    local st = windower.text and windower.text.saved_texts
    if st then for i = #st, 1, -1 do if st[i] then pcall(texts.destroy, st[i]) end end end
    local si = _G.saved_images
    if si then for i = #si, 1, -1 do if si[i] then pcall(images.destroy, si[i]) end end end
    if ffxidb_hidden_by_us and ffxidb_x then
        windower.send_command('ffxidb pos ' .. ffxidb_x .. ' ' .. ffxidb_y)
    end
end)

windower.register_event('status change', function(status)
    if not is_logged_in then return end
    player_state.status = status

    if comp.xivparty.enabled and xivparty.on_status_change then xivparty.on_status_change(status) end

    if status == 4 then
        dbg('event', 'status change -> 4 (cutscene) — hiding UI')
        is_cutscene = true
        hide_all()
        zone_reveal_pending = true
    elseif is_cutscene then
        dbg('event', 'status change -> ' .. tostring(status) .. ' (leaving cutscene)')
        is_cutscene = false
    else
        dbg('event', 'status change -> ' .. tostring(status))
    end
end)

windower.register_event('incoming chunk', function(id, original, modified, is_injected, is_blocked)
    if is_injected then return end
    if _G.XIVUI_DEBUG then dbg('packet', ('incoming chunk 0x%03X'):format(id)) end

    if id == 0x00B then
        dbg('event', 'zone start (0x00B) — hiding UI')
        zone_state.zone_start()
        hide_all()
        zone_reveal_pending = true
    elseif id == 0x00A then
        if _G.XIVUI_DEBUG and zone_state.is_zoning then dbg('event', 'zone-in packet (0x00A)') end
        zone_state.zone_packet()
    elseif id == 0x01D then
        if _G.XIVUI_DEBUG and zone_state.is_zoning then dbg('event', 'zone complete (inventory ready, 0x01D)') end
        zone_state.zone_complete()
    end

    for _, c in ipairs(components) do
        dispatch(c, 'on_incoming_chunk', id, original, modified, is_injected, is_blocked)
    end
end)

windower.register_event('incoming text', function(original, modified, original_mode, modified_mode, blocked)
    if not is_logged_in then return end
    if _G.XIVUI_DEBUG then dbg('packet', 'incoming text (mode ' .. tostring(original_mode) .. ')') end
    for _, c in ipairs(components) do
        dispatch(c, 'on_incoming_text', original, modified, original_mode, modified_mode, blocked)
    end
end)

local htbauto = { on = false, idx = 0, t0 = 0, n = 0, hold = 10, delay = 1, results = {},
    seq = { 'base', 'disabled', 'all', 'img', 'text', 'icons', 'bg', 'frames', 'outline', 'overlay', 'recasts', 'keys', 'names', 'cost' } }
local function htbauto_start()
    htbauto.on, htbauto.idx, htbauto.t0, htbauto.n, htbauto.results = true, 0, perf_clock(), 0, {}
    pcall(xivhotbar3.htbtest, 'off')
    local total = #htbauto.seq * htbauto.hold + htbauto.delay
    local out = _G.xivui_echo or print
    out(('htbtest AUTO: starting in 1s. SPIN THE CAMERA CONTINUOUSLY for ~%ds until results print.'):format(total))
end
local function htbauto_cancel()
    if not htbauto.on then return false end
    htbauto.on = false
    pcall(xivhotbar3.htbtest, 'off')
    local out = _G.xivui_echo or print
    out('htbtest AUTO: cancelled.')
    return true
end
local function htbauto_announce()
    local out = _G.xivui_echo or print
    out(('htbtest AUTO [%d/%d]: %s — keep spinning'):format(
        htbauto.idx, #htbauto.seq, htbauto.seq[htbauto.idx]))
end
local function htbauto_tick()
    if not htbauto.on then return end
    local now = perf_clock()
    if htbauto.idx == 0 then
        if now - htbauto.t0 >= htbauto.delay then
            htbauto.idx, htbauto.t0, htbauto.n = 1, now, 0
            pcall(xivhotbar3.htbtest, htbauto.seq[1])
            htbauto_announce()
        end
        return
    end
    htbauto.n = htbauto.n + 1
    if now - htbauto.t0 >= htbauto.hold then
        local dt = now - htbauto.t0
        htbauto.results[#htbauto.results + 1] = { mode = htbauto.seq[htbauto.idx], fps = htbauto.n / dt }
        htbauto.idx = htbauto.idx + 1
        if htbauto.idx > #htbauto.seq then
            htbauto.on = false
            pcall(xivhotbar3.htbtest, 'off')
            local out = _G.xivui_echo or print
            local base_fps
            for _, r in ipairs(htbauto.results) do if r.mode == 'base' then base_fps = r.fps end end
            table.sort(htbauto.results, function(a, b) return a.fps > b.fps end)
            out('=== htbtest AUTO results (fps per mode; higher = hiding that category helped more) ===')
            for _, r in ipairs(htbauto.results) do
                local tag = (base_fps and r.mode ~= 'base') and (('  (%+.1f vs base)'):format(r.fps - base_fps)) or ''
                out(('  %-9s %.1f fps%s'):format(r.mode, r.fps, tag))
            end
        else
            htbauto.t0, htbauto.n = now, 0
            pcall(xivhotbar3.htbtest, htbauto.seq[htbauto.idx])
            htbauto_announce()
        end
    end
end

windower.register_event('prerender', function()
    if not is_logged_in or ui_hidden or zone_state.hidden() or is_cutscene then return end

    if zone_reveal_pending then
        dbg('event', 'zone reveal — showing UI')
        zone_reveal_pending = false
        show_all()
    end

    if first_run_apply_due and os.clock() >= first_run_apply_due then
        local ready = true
        if comp.xivhotbar3.enabled then
            local ok, bars = pcall(xivhotbar3.hud_bars)
            ready = ok and type(bars) == 'table' and #bars > 0
        end
        if ready or os.clock() >= first_run_deadline then
            first_run_apply_due = nil
            dbg('firstrun', ready and 'hotbar ready — applying default layout' or 'deadline reached — applying default layout')
            mark_layout_applied()
            local ok, hud = pcall(require, 'components/xivuimenu/hud')
            if ok and hud.apply_saved_defaults then
                local applied = pcall(hud.apply_saved_defaults)
                if applied then
                    (_G.xivui_echo or print)('XivUI: applying the default HUD layout, scaled to your resolution (first run)…')
                    dbg('firstrun', 'default layout applied — reload scheduled in 0.3s')
                    first_run_reload_due = os.clock() + 0.3
                else
                    dbg('firstrun', 'apply_saved_defaults returned false (no saved layout?)')
                end
            else
                dbg('firstrun', 'hud module / apply_saved_defaults unavailable')
            end
        end
    end

    if first_run_reload_due and os.clock() >= first_run_reload_due then
        first_run_reload_due = nil
        dbg('firstrun', 'first-run self-reload now (lua r xivui)')
        windower.send_command('lua r xivui')
    end

    _G.XIVUI_TMOB = (comp.targetbar.enabled or comp.enemyloot.enabled)
                    and windower.ffxi.get_mob_by_target('t') or nil
    htbauto_tick()
    if _G.XIVUI_FPSCAP.on then _G.XIVUI_FPSCAP.n = _G.XIVUI_FPSCAP.n + 1 end
    local P = _G.XIVUI_PERF
    if P.on then
        P.frames = P.frames + 1
        local pc = P.clock
        for _, c in ipairs(components) do
            local t0 = pc()
            dispatch(c, 'on_prerender')
            P.t[c.name] = (P.t[c.name] or 0) + (pc() - t0)
        end
        for _, c in ipairs(components) do
            local t0 = pc()
            dispatch(c, 'push_bounds')
            P.t[c.name] = (P.t[c.name] or 0) + (pc() - t0)
        end
        local t0 = pc()
        occlusion.update()
        P.t.occlusion = (P.t.occlusion or 0) + (pc() - t0)
    else
        for _, c in ipairs(components) do dispatch(c, 'on_prerender') end
        for _, c in ipairs(components) do dispatch(c, 'push_bounds') end
        occlusion.update()
    end
end)

windower.register_event('hp change', function(new, old)
    player_state.hp = new
    if _G.XIVUI_DEBUG then dbg('vitals', 'hp ' .. tostring(old) .. ' -> ' .. tostring(new)) end
    if comp.statusbar.enabled and statusbar.on_hp_change then statusbar.on_hp_change(new) end
end)

windower.register_event('hpp change', function(new, old)
    player_state.hpp = new
    if _G.XIVUI_DEBUG then dbg('vitals', 'hpp ' .. tostring(new) .. '%') end
    if comp.statusbar.enabled and statusbar.on_hpp_change then statusbar.on_hpp_change(new) end
end)

windower.register_event('mp change', function(new, old)
    player_state.mp = new
    if _G.XIVUI_DEBUG then dbg('vitals', 'mp ' .. tostring(old) .. ' -> ' .. tostring(new)) end
    if comp.statusbar.enabled and statusbar.on_mp_change then statusbar.on_mp_change(new) end
end)

windower.register_event('mpp change', function(new, old)
    player_state.mpp = new
    if _G.XIVUI_DEBUG then dbg('vitals', 'mpp ' .. tostring(new) .. '%') end
    if comp.statusbar.enabled and statusbar.on_mpp_change then statusbar.on_mpp_change(new) end
end)

windower.register_event('tp change', function(new, old)
    player_state.tp = new
    player_state.tpp = math.min(new / 10, 100)
    if _G.XIVUI_DEBUG then dbg('vitals', 'tp ' .. tostring(old) .. ' -> ' .. tostring(new)) end
    if comp.statusbar.enabled and statusbar.on_tp_change then statusbar.on_tp_change(new) end
end)

windower.register_event('target change', function(index)
    dbg('target', 'target change -> index ' .. tostring(index))
    if comp.targetbar.enabled and targetbar.on_target_change then targetbar.on_target_change(index) end
end)

windower.register_event('job change', function()
    dbg('event', 'job change')
    player_state.refresh()
end)

windower.register_event('level up', function()
    dbg('event', 'level up')
    player_state.refresh()
    if comp.expbar.enabled and expbar.on_level_up then expbar.on_level_up() end
end)

windower.register_event('level down', function()
    dbg('event', 'level down')
    player_state.refresh()
    if comp.expbar.enabled and expbar.on_level_down then expbar.on_level_down() end
end)

windower.register_event('zone change', function(new_id, old_id)
    dbg('event', 'zone change ' .. tostring(old_id) .. ' -> ' .. tostring(new_id))
    if comp.expbar.enabled and expbar.on_zone_change then expbar.on_zone_change() end
    if comp.targetbar.enabled and targetbar.on_zone_change then targetbar.on_zone_change() end
end)

windower.register_event('keyboard', function(key, down, flags, blocked)
    if _G.XIVUI_DEBUG then dbg('key', ('key=%s down=%s flags=%s blocked=%s'):format(
        tostring(key), tostring(down), tostring(flags), tostring(blocked))) end
    if (key == SCRLK_DIK or key == F12_DIK) and down then
        ui_hidden = not ui_hidden
        dbg('event', 'UI ' .. (ui_hidden and 'HIDDEN' or 'SHOWN') .. ' via hotkey (ScrollLock/F12)')
        if ui_hidden then
            hide_all()
        elseif is_logged_in and not zone_state.hidden() and not is_cutscene then
            show_all()
        end
        return true
    end
    if comp.xivuimenu.enabled and xivuimenu.on_keyboard then
        local ok, consumed = pcall(xivuimenu.on_keyboard, key, down)
        if not ok then dispatch_menu_err('on_keyboard', consumed)
        elseif consumed then return true end
    end
    if comp.xivparty.enabled and xivparty.on_keyboard then
        if xivparty.on_keyboard(key, down) then return true end
    end
end)

local last_click = { t = 0, x = -1, y = -1, c = -1 }
local last_move_t = 0
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if ui_hidden or is_cutscene or zone_state.hidden() then return end
    if type == 0 then
        local now = os.clock()
        if now - last_move_t < 0.015 then return end
        last_move_t = now
    end
    local is_click = (type == 1 or type == 3)
    if is_click then
        local now = os.clock()
        if type == last_click.t and x == last_click.x and y == last_click.y and (now - last_click.c) < 0.15 then
            last_click.c = now
            return
        end
        last_click.t, last_click.x, last_click.y, last_click.c = type, x, y, now
    end
    if _G.XIVUI_DEBUG and type ~= 0 then dbg('mouse', ('mouse type=%s (%s,%s)'):format(tostring(type), tostring(x), tostring(y))) end
    local menu = comp.xivuimenu and comp.xivuimenu.enabled and xivuimenu
    local function menu_on_mouse()
        local ok, ret = pcall(xivuimenu.on_mouse, type, x, y, delta, blocked)
        if not ok then dispatch_menu_err('on_mouse', ret); return nil end
        return ret
    end
    local result = (function()
        if menu and xivuimenu.is_hud_open then
            local ok, hud_open = pcall(xivuimenu.is_hud_open)
            if not ok then dispatch_menu_err('is_hud_open', hud_open)
            elseif hud_open then
                return menu_on_mouse()
            end
        end
        if menu and xivuimenu.covers then
            local ok, covered = pcall(xivuimenu.covers, x, y)
            if not ok then dispatch_menu_err('covers', covered)
            elseif covered then
                return menu_on_mouse()
            end
        end
        for _, c in ipairs(components) do
            if dispatch(c, 'on_mouse', type, x, y, delta, blocked) then return true end
        end
    end)()
    if is_click then last_click.c = os.clock() end
    return result
end)

windower.register_event('addon command', function(cmd1, ...)
    local cmd = cmd1 and cmd1:lower() or ''
    local args = T{...}
    local log = _G.xivui_echo

    if _G.XIVUI_DEBUG then
        local parts = {}
        for i = 1, #args do parts[i] = tostring(args[i]) end
        dbg('cmd', '//xui ' .. cmd .. (#parts > 0 and (' ' .. table.concat(parts, ' ')) or ''))
    end

    local function run_cmd(label, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            windower.add_to_chat(167, ('[XivUI] %s command error: %s'):format(label, tostring(err)))
        end
    end

    local cname = cmd_to_comp[cmd]
    if cname then
        run_cmd(cname, comp[cname].mod.handle_command, args)
    elseif cmd == 'debug' then
        local sub = args[1] and tostring(args[1]):lower() or ''
        local val = args[2] and tostring(args[2]):lower() or nil
        local function want(cur) return (val == 'on') or (val ~= 'off' and not cur) end
        if sub == '' or sub == 'on' or sub == 'off' then
            local on = (sub == 'on') or (sub ~= 'off' and not _G.XIVUI_DEBUG)
            set_debug(on)
            log('debug ' .. (on and 'ON — scenario + component messages show. Add "//xui debug verbose" for per-frame/packet noise.' or 'OFF — XivUI runs silent.'))
        elseif sub == 'verbose' or sub == 'v' then
            local on = want(_G.XIVUI_DEBUG_VERBOSE)
            if on and not _G.XIVUI_DEBUG then _G.XIVUI_DEBUG = true end
            _G.XIVUI_DEBUG_VERBOSE = on
            save_debug_flag()
            log('debug verbose (mouse/key/vitals/packet) ' .. (on and 'ON — master forced ON.' or 'OFF'))
        elseif sub == 'occ' or sub == 'occlusion' then
            run_cmd('occ', occlusion.dump)
        elseif sub == 'areas' or sub == 'status' or sub == 'list' then
            log('debug: ' .. (_G.XIVUI_DEBUG and 'ON' or 'OFF') .. (_G.XIVUI_DEBUG_VERBOSE and '  +verbose' or ''))
            local parts = {}
            for _, a in ipairs(DEBUG_AREAS) do
                parts[#parts + 1] = a .. (dbg_area_enabled(a) and '*' or '') .. (DEBUG_NOISY[a] and '~' or '')
            end
            log('areas (* active, ~ noisy): ' .. table.concat(parts, '  '))
        else
            local is_area = false
            for _, a in ipairs(DEBUG_AREAS) do if a == sub then is_area = true; break end end
            if not is_area then
                log('debug: unknown option "' .. sub .. '".')
                log('usage: //xui debug [on|off] | verbose [on|off] | areas | occ | <area> [on|off]')
                log('areas: ' .. table.concat(DEBUG_AREAS, ', '))
            else
                if not _G.XIVUI_DEBUG then set_debug(true) end
                local on = want(dbg_area_enabled(sub))
                if DEBUG_NOISY[sub] then
                    dbg_area_on[sub] = on or nil; dbg_area_off[sub] = nil
                else
                    dbg_area_off[sub] = (not on) or nil; dbg_area_on[sub] = nil
                end
                log('debug area "' .. sub .. '" ' .. (on and 'ON' or 'OFF'))
            end
        end
    elseif cmd == 'perf' then
        local P = _G.XIVUI_PERF
        if not P.on then
            P.t = {}; P.frames = 0; P.mem0 = collectgarbage('count'); P.start = perf_clock(); P.on = true
            log('perf: capturing per-component frame cost — play normally, then run //xui perf again for the report.')
        else
            P.on = false
            local elapsed = math.max(0.001, perf_clock() - P.start)
            local frames = math.max(1, P.frames)
            local rows = {}
            for name, secs in pairs(P.t) do rows[#rows + 1] = { name = name, ms = secs * 1000 } end
            table.sort(rows, function(a, b) return a.ms > b.ms end)
            log(('perf: %d frames in %.1fs (%.0f fps), cost per frame:'):format(P.frames, elapsed, frames / elapsed))
            for _, r in ipairs(rows) do
                if r.ms / frames >= 0.001 then
                    log(('  %-13s %.3f ms/frame  (%.0f%% of capture)'):format(r.name, r.ms / frames, r.ms / (elapsed * 1000) * 100))
                end
            end
            local mem = collectgarbage('count')
            log(('mem: %.1f MB Lua (%+.2f MB during capture); texts=%d images=%d'):format(
                mem / 1024, (mem - P.mem0) / 1024,
                #(windower.text.saved_texts or {}), #(_G.saved_images or {})))
        end
    elseif cmd == 'xptest' then
        local mode = args[1] and tostring(args[1]):lower() or 'status'
        local FC = _G.XIVUI_FPSCAP
        if FC.on then
            local dt = math.max(0.001, perf_clock() - FC.t0)
            log(('xptest[%s] = %.1f fps  (%d frames / %.1fs)'):format(FC.mode, FC.n / dt, FC.n, dt))
            FC.on = false
        end
        if mode == 'buffs' then
            _G.XIVUI_XP_NOBUFFS = true; log('xptest: hiding ALL party buff icons.')
        elseif mode == 'base' or mode == 'off' then
            _G.XIVUI_XP_NOBUFFS = nil; log('xptest: party buffs shown (' .. mode .. ').')
        else
            log('xptest modes: base | buffs | off  (capture FPS with trusts + hotbar up, spinning the camera)')
        end
        if mode == 'base' or mode == 'buffs' then
            _G.XIVUI_FPSCAP = { on = true, n = 0, t0 = perf_clock(), mode = 'xp:' .. mode }
            log(('xptest[%s]: capturing — spin the camera ~10s, then run the next xptest (or off) to print its FPS.'):format(mode))
        end
    elseif cmd == 'htbtest' then
        local mode = args[1] and tostring(args[1]):lower() or 'status'
        if mode == 'auto' then
            htbauto_start()
        elseif mode == 'off' and htbauto_cancel() then
        else
            local FC = _G.XIVUI_FPSCAP
            if FC.on then
                local dt = math.max(0.001, perf_clock() - FC.t0)
                log(('htbtest[%s] = %.1f fps  (%d frames / %.1fs)'):format(FC.mode, FC.n / dt, FC.n, dt))
                FC.on = false
            end
            run_cmd('htbtest', function() xivhotbar3.htbtest(mode) end)
            if mode ~= 'off' and mode ~= 'status' then
                _G.XIVUI_FPSCAP = { on = true, n = 0, t0 = perf_clock(), mode = mode }
                log(('htbtest[%s]: capturing — spin the camera ~5s, then run the next //xui htbtest <mode> (or off) to print its FPS.'):format(mode))
            end
        end
    elseif cmd == 'sc' then
        run_cmd('targetbar', targetbar.handle_sc_command, args)
    elseif cmd == 'theme' then
        local id = args[1] and tostring(args[1]):lower() or ''
        local NAMES = { ffxi = 'FFXI', ffxiv10 = 'FFXIV 1.0', ffxiv = 'FFXIV' }
        if NAMES[id] then
            _G.XIVUI_THEME = id
            local ok, ts = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
            if ok and ts then ts.Theme = id; config.save(ts) end
            log('Theme: ' .. NAMES[id] .. ' selected — reloading XivUI…')
            windower.send_command('lua r xivui')
        else
            log('Usage: //xui theme <ffxi|ffxiv10|ffxiv>')
        end
    elseif cmd == 'layout' then
        local sub = args[1] and tostring(args[1]):lower() or ''
        local ok, hud = pcall(require, 'components/xivuimenu/hud')
        if not ok then log('layout: HUD module unavailable.'); return end
        if sub == 'savedefaults' or sub == 'save' then
            local saved, res = hud.save_defaults()
            if saved then
                mark_layout_applied()
                log(string.format('layout: captured current placements as the resolution-independent default (at %dx%d). Sync components/xivuimenu/hud_layout/hud_layout.lua to the repo to ship it.',
                    (res and res.x) or 0, (res and res.y) or 0))
            else
                log('layout: could not capture (no UI resolution?).')
            end
        elseif sub == 'apply' then
            local applied, err = hud.apply_saved_defaults()
            if applied then mark_layout_applied(); log('layout: applied the saved default layout, scaled to this resolution.')
            else log('layout: ' .. tostring(err or 'apply failed') .. '.') end
        else
            log('layout commands:')
            log('  savedefaults — capture your CURRENT placements as the scalable default (run on your tuned screen)')
            log('  apply — re-apply that default layout, scaled to THIS resolution')
        end
    elseif cmd == 'enable' or cmd == 'disable' then
        local word = args[1] and args[1]:lower()
        local name = (word == 'hotbar' and 'xivhotbar3') or (word and cmd_to_comp[word]) or (word and comp[word] and word)
        local c = name and comp[name]
        if not c then
            log('Unknown component: ' .. (word or '(none)'))
            log('Components: ' .. COMPONENT_WORDS)
        else
            set_component_enabled(c, cmd == 'enable')
            if cmd == 'enable' then
                if c.enabled then log(word .. ' enabled') end
            else
                log(word .. ' disabled')
            end
        end
    elseif cmd == '' then
        log('XivUI v' .. _addon.version)
        log('  //xui status <cmd>   — HP/MP/TP + job/time bar')
        log('  //xui exp <cmd>      — EXP bar')
        log('  //xui target <cmd>   — target HP + buff/debuff strip')
        log('  //xui sc [on|off]    — toggle the skillchain display')
        log('  //xui dps <cmd>      — DPS parser (visible|reset|pos|set|log|filter)')
        log('  //xui aggro <cmd>    — aggro list (move|pos)')
        log('  //xui party <cmd>    — party list')
        log('  //xui request <cmd>  — party/trade request popups')
        log('  //xui notify <cmd>   — loot toasts')
        log('  //xui cast <cmd>     — cast bar + auto-attack timer')
        log('  //xui menu <cmd>     — XivUI Menu (toggle | open | close | pos)')
        log('  //htb <cmd>          — action hotbars (also works as //xui <hotbar-cmd>)')
        log('  //xui enable|disable <component> — toggle a component on/off')
        log('  //xui debug [on|off] — scenario + component messages (default: silent)')
        log('  //xui debug verbose  — also log per-frame/packet/input/vitals')
        log('  //xui debug areas    — list debug areas; //xui debug <area> [on|off]')
        log('  Components: ' .. COMPONENT_WORDS)
    else
        run_cmd('hotbar', xivhotbar3.handle_command, cmd1, table.unpack(args))
    end
end)
