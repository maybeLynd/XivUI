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






local dispatch_err = {}
local function dispatch(c, ev, ...)
    local fn = c.enabled and c.mod[ev]
    if not fn then return nil end
    local ok, ret = pcall(fn, ...)
    if ok then return ret end
    local key = c.name .. '.' .. ev
    if not dispatch_err[key] then
        dispatch_err[key] = true
        windower.add_to_chat(167, ('[XivUI] %s.%s error (further suppressed): %s'):format(c.name, ev, tostring(ret)))
    end
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
do
    local f = io.open(DEBUG_FLAG, 'r')
    _G.XIVUI_DEBUG = f ~= nil
    if f then f:close() end
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
local function set_debug(on)
    _G.XIVUI_DEBUG = on == true
    if on then
        local f = io.open(DEBUG_FLAG, 'w')
        if f then f:write('1'); f:close() end
    else
        os.remove(DEBUG_FLAG)
    end
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

local hud_hidden    = false
local menu_was_open = false

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
    if hud_hidden then return end
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
    if ui_hidden then return end
    for _, c in ipairs(components) do
        if not (hud_hidden and c.name == 'xivparty') then dispatch(c, 'show') end
    end
    show_external()
end

local function hide_all()
    hide_components()
    hide_external()
end

local function set_hud_hidden(hidden)
    if hidden == hud_hidden then return end
    hud_hidden = hidden
    if hidden then
        capture_ffxidb_pos()
        if ffxidb_x then
            windower.send_command('ffxidb pos -9999 -9999')
            ffxidb_hidden_by_us = true
        end
        if comp.xivparty.enabled and xivparty.hide then xivparty.hide() end
    else
        if ffxidb_hidden_by_us and ffxidb_x then
            windower.send_command('ffxidb pos ' .. ffxidb_x .. ' ' .. ffxidb_y)
            ffxidb_hidden_by_us = false
        end
        if comp.xivparty.enabled and xivparty.show
           and is_logged_in and not ui_hidden and not zone_state.hidden() and not is_cutscene then
            xivparty.show()
        end
    end
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
    elseif not on and hud_camera_locked then
        windower.send_command('setkey lshift up'); hud_camera_locked = false
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

    ui_shift_held = false
    windower.send_command('setkey lshift up')
    for _, c in ipairs(components) do
        dispatch(c, 'init')
    end
    register_drag_camera_lock()
end





local LAYOUT_FILE   = windower.addon_path .. 'components/xivuimenu/hud_layout/hud_layout.lua'
local LAYOUT_MARKER = windower.addon_path .. 'data/hud_layout_applied'
local first_run_apply_due = nil
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
    first_run_apply_due = os.clock() + 4.0
end

local function dispose_all()
    for _, c in ipairs(components) do


        if c.enabled and c.mod.dispose then pcall(c.mod.dispose) end
    end
    set_hud_camera_lock(false)
    release_ui_shift()
    if drag_lock_id then windower.unregister_event(drag_lock_id); drag_lock_id = nil end
end



local function set_component_enabled(c, on)
    if on then
        if not c.enabled then
            c.enabled = true
            if is_logged_in then
                if c.mod.init then c.mod.init() end
                if not zone_state.hidden() and not is_cutscene and c.mod.show then c.mod.show() end
            end
        end
    else
        if c.enabled then
            c.enabled = false
            if c.mod.hide then c.mod.hide() end
            if c.mod.dispose then c.mod.dispose() end
        end
    end
    save_comp_enabled(c.name, on)
end


_G.XIVUI_STATE = {
    components  = components,
    set_enabled = function(name, on) local c = comp[name]; if c then set_component_enabled(c, on) end end,
    hud_camera_lock = set_hud_camera_lock,
}

windower.register_event('load', function()
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
    is_logged_in = false
    is_cutscene = false
    hide_components()
    dispose_all()
end)

windower.register_event('unload', function()


    dispose_all()
    if ffxidb_hidden_by_us and ffxidb_x then
        windower.send_command('ffxidb pos ' .. ffxidb_x .. ' ' .. ffxidb_y)
    end
end)

windower.register_event('status change', function(status)
    if not is_logged_in then return end
    player_state.status = status

    if comp.xivparty.enabled and xivparty.on_status_change then xivparty.on_status_change(status) end

    if status == 4 then
        is_cutscene = true
        hide_all()
        zone_reveal_pending = true
    elseif is_cutscene then
        is_cutscene = false
    end
end)

windower.register_event('incoming chunk', function(id, original, modified, is_injected, is_blocked)
    if is_injected then return end

    if id == 0x00B then
        zone_state.zone_start()
        hide_all()
        zone_reveal_pending = true
    elseif id == 0x00A then
        zone_state.zone_packet()
    elseif id == 0x01D then
        zone_state.zone_complete()
    end

    for _, c in ipairs(components) do
        dispatch(c, 'on_incoming_chunk', id, original, modified, is_injected, is_blocked)
    end
end)

windower.register_event('incoming text', function(original, modified, original_mode, modified_mode, blocked)
    if not is_logged_in then return end
    for _, c in ipairs(components) do
        dispatch(c, 'on_incoming_text', original, modified, original_mode, modified_mode, blocked)
    end
end)

windower.register_event('prerender', function()
    if not is_logged_in or ui_hidden or zone_state.hidden() or is_cutscene then return end

    if zone_reveal_pending then
        zone_reveal_pending = false
        show_all()
    end

    if first_run_apply_due and os.clock() >= first_run_apply_due then
        first_run_apply_due = nil
        mark_layout_applied()
        local ok, hud = pcall(require, 'components/xivuimenu/hud')
        if ok and hud.apply_saved_defaults then
            local applied = pcall(hud.apply_saved_defaults)
            if applied then
                (_G.xivui_echo or print)('XivUI: applying the default HUD layout, scaled to your resolution (first run)…')
                first_run_reload_due = os.clock() + 1.5
            end
        end
    end

    if first_run_reload_due and os.clock() >= first_run_reload_due then
        first_run_reload_due = nil
        windower.send_command('lua r xivui')
    end

    local info = windower.ffxi.get_info()
    local p = windower.ffxi.get_player()





    _G.XIVUI_TMOB = (comp.targetbar.enabled or comp.enemyloot.enabled)
                    and windower.ffxi.get_mob_by_target('t') or nil
    local engaged = p and p.status == 1
    local should_hide = ((info and info.menu_open) and not engaged) and true or false
    if should_hide ~= menu_was_open then
        menu_was_open = should_hide
        set_hud_hidden(should_hide)
    end

    for _, c in ipairs(components) do
        dispatch(c, 'on_prerender')
    end

    for _, c in ipairs(components) do
        dispatch(c, 'push_bounds')
    end


    occlusion.update()
end)

windower.register_event('hp change', function(new, old)
    player_state.hp = new
    if comp.statusbar.enabled and statusbar.on_hp_change then statusbar.on_hp_change(new) end
end)

windower.register_event('hpp change', function(new, old)
    player_state.hpp = new
    if comp.statusbar.enabled and statusbar.on_hpp_change then statusbar.on_hpp_change(new) end
end)

windower.register_event('mp change', function(new, old)
    player_state.mp = new
    if comp.statusbar.enabled and statusbar.on_mp_change then statusbar.on_mp_change(new) end
end)

windower.register_event('mpp change', function(new, old)
    player_state.mpp = new
    if comp.statusbar.enabled and statusbar.on_mpp_change then statusbar.on_mpp_change(new) end
end)

windower.register_event('tp change', function(new, old)
    player_state.tp = new
    player_state.tpp = math.min(new / 10, 100)
    if comp.statusbar.enabled and statusbar.on_tp_change then statusbar.on_tp_change(new) end
end)





windower.register_event('target change', function(index)
    if comp.targetbar.enabled and targetbar.on_target_change then targetbar.on_target_change(index) end
end)

windower.register_event('job change', function()
    player_state.refresh()
end)

windower.register_event('level up', function()
    player_state.refresh()
    if comp.expbar.enabled and expbar.on_level_up then expbar.on_level_up() end
end)

windower.register_event('level down', function()
    player_state.refresh()
    if comp.expbar.enabled and expbar.on_level_down then expbar.on_level_down() end
end)

windower.register_event('zone change', function(new_id, old_id)
    if comp.expbar.enabled and expbar.on_zone_change then expbar.on_zone_change() end
    if comp.targetbar.enabled and targetbar.on_zone_change then targetbar.on_zone_change() end
end)

windower.register_event('keyboard', function(key, down)
    if (key == SCRLK_DIK or key == F12_DIK) and down then
        ui_hidden = not ui_hidden
        if ui_hidden then
            hide_all()
        elseif is_logged_in and not zone_state.hidden() and not is_cutscene then
            show_all()
        end
        return true
    end
    if comp.xivuimenu.enabled and xivuimenu.on_keyboard then
        if xivuimenu.on_keyboard(key, down) then return true end
    end
    if comp.xivparty.enabled and xivparty.on_keyboard then
        if xivparty.on_keyboard(key, down) then return true end
    end
end)

local last_click = { t = 0, x = -1, y = -1, c = -1 }
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if ui_hidden or is_cutscene or zone_state.hidden() then return end




    if type == 1 or type == 3 then
        local now = os.clock()
        if type == last_click.t and x == last_click.x and y == last_click.y and (now - last_click.c) < 0.15 then
            return
        end
        last_click.t, last_click.x, last_click.y, last_click.c = type, x, y, now
    end




    local menu = comp.xivuimenu and comp.xivuimenu.enabled and xivuimenu
    if menu and xivuimenu.is_hud_open then
        local ok, hud_open = pcall(xivuimenu.is_hud_open)
        if not ok then dispatch_menu_err('is_hud_open', hud_open)
        elseif hud_open then
            return xivuimenu.on_mouse(type, x, y, delta, blocked)
        end
    end




    if menu and xivuimenu.covers then
        local ok, covered = pcall(xivuimenu.covers, x, y)
        if not ok then dispatch_menu_err('covers', covered)
        elseif covered then
            return xivuimenu.on_mouse(type, x, y, delta, blocked)
        end
    end
    for _, c in ipairs(components) do
        if dispatch(c, 'on_mouse', type, x, y, delta, blocked) then return true end
    end
end)

windower.register_event('addon command', function(cmd1, ...)
    local cmd = cmd1 and cmd1:lower() or ''
    local args = T{...}
    local log = _G.xivui_echo

    local cname = cmd_to_comp[cmd]
    if cname then
        local ok, err = pcall(comp[cname].mod.handle_command, args)
        if not ok then log('[XivUI] ' .. cname .. ' command error: ' .. tostring(err)) end
    elseif cmd == 'debug' then
        local arg = args[1] and tostring(args[1]):lower()
        local on = (arg == 'on') or (arg ~= 'off' and not _G.XIVUI_DEBUG)
        set_debug(on)
        log('debug output ' .. (on and 'ON — component messages show.' or 'OFF — XivUI runs silent.'))
    elseif cmd == 'sc' then
        targetbar.handle_sc_command(args)
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
            log(word .. (cmd == 'enable' and ' enabled' or ' disabled'))
        end
    elseif cmd == 'menudebug' then
        local info = windower.ffxi.get_info() or {}
        local keys = {}
        for k, v in pairs(info) do
            if type(v) ~= 'table' and type(v) ~= 'function' then keys[#keys + 1] = k end
        end
        table.sort(keys)
        local line = ''
        for _, k in ipairs(keys) do
            local piece = k .. '=' .. tostring(info[k]) .. '  '
            if #line + #piece > 100 then log(line); line = '' end
            line = line .. piece
        end
        if line ~= '' then log(line) end
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
        log('  //xui debug [on|off] — show component chat output (default: silent)')
        log('  Components: ' .. COMPONENT_WORDS)
    else
        local ok, err = pcall(xivhotbar3.handle_command, cmd1, table.unpack(args))
        if not ok then log('[XivUI] xivhotbar3 command error: ' .. tostring(err)) end
    end
end)
