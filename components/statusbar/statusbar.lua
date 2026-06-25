-- statusbar: FFXIV style main bar: HP/MP/TP plus job and time.
-- XivUI component. Maintainer: maybeLynd. Version: 1.1.
-- Based on "XIV Bar" v1.0 by Edeon.

local SELF_PATH = windower.addon_path .. 'components/statusbar/'

local config = require('config')
local screen = require('lib/screen')
local defaults = require('components/statusbar/defaults')
local theme_mod = require('components/statusbar/theme')
local ui = require('components/statusbar/ui')
local ui_bounds = require('lib/ui_bounds')

local settings
local theme_options

local GLOBAL_SKIN = { ffxi = 'ffxi', ffxiv10 = 'ffxiv-legacy', ffxiv = 'ffxiv' }
local function global_skin()
    local ok, ts = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
    local id = (ok and type(ts) == 'table' and ts.Theme) or 'ffxiv'
    return GLOBAL_SKIN[id]
end

local state = {
    ready = false,
    update_hp = false,
    update_mp = false,
    update_tp = false,
    hp_bar_width = 0,
    mp_bar_width = 0,
    tp_bar_width = 0,
}

local player = {
    hpp = 0, mpp = 0, tpp = 0,
    current_hp = 0, current_mp = 0, current_tp = 0,
}

local function update_bar(bar, text, width, current, pp, flag)
    local fill_width = theme_options.fill_width or theme_options.bar_width
    local new_width = math.floor((pp / 100) * fill_width)
    if new_width < 0 then return end

    if flag == 3 and current >= 1000 then
        text:color(theme_options.full_tp_color_red, theme_options.full_tp_color_green, theme_options.full_tp_color_blue)
        if theme_options.dim_tp_bar then bar:alpha(255) end
    else
        local nc = theme_options.num_colors and theme_options.num_colors[flag]
        if nc then text:color(nc[1], nc[2], nc[3])
        else text:color(theme_options.font_color_red, theme_options.font_color_green, theme_options.font_color_blue) end
        if theme_options.dim_tp_bar then bar:alpha(180) end
    end
    text:text(tostring(current))

    if width == new_width then
        if new_width == 0 then bar:hide() end
        if flag == 1 then state.update_hp = false
        elseif flag == 2 then state.update_mp = false
        elseif flag == 3 then state.update_tp = false end
        return
    end

    local x
    if width < new_width then
        x = math.min(width + math.ceil((new_width - width) * 0.1), fill_width)
    else
        x = math.max(width - math.ceil((width - new_width) * 0.1), 0)
    end

    if flag == 1 then state.hp_bar_width = x
    elseif flag == 2 then state.mp_bar_width = x
    elseif flag == 3 then state.tp_bar_width = x end

    bar:size(x, theme_options.total_height)
    bar:show()
end

local statusbar = {}

function statusbar.init()
    settings = config.load('data/statusbar/settings.xml', defaults)
    settings.Theme.Name = global_skin() or settings.Theme.Name
    theme_options = theme_mod.apply(settings, SELF_PATH)
    ui:load(theme_options)

    local p = windower.ffxi.get_player()
    if p then
        player.hpp = p.vitals.hpp
        player.mpp = p.vitals.mpp
        player.current_hp = p.vitals.hp
        player.current_mp = p.vitals.mp
        player.current_tp = p.vitals.tp
        player.tpp = math.min(p.vitals.tp / 10, 100)
    end

    state.update_hp = true
    state.update_mp = true
    state.update_tp = true
end

function statusbar.dispose()
    state.ready = false
end

function statusbar.show()
    ui:show()
    state.ready = true
    state.update_hp = true
    state.update_mp = true
    state.update_tp = true
end

function statusbar.hide()
    ui:hide()
    state.ready = false
    ui_bounds.clear('statusbar')
end

function statusbar.push_bounds()
    if not state.ready or not theme_options then
        ui_bounds.clear('statusbar')
        return
    end
    local sw, sh = screen.size()
    local x  = sw / 2 - theme_options.total_width / 2 + theme_options.offset_x
    local y  = sh - 60 + theme_options.offset_y
    local h  = theme_options.total_height + (theme_options.font_size or 10) + 16
    ui_bounds.register('statusbar', x, y, theme_options.total_width, h)
end

function statusbar.on_prerender()
    if not state.ready then return end
    if state.update_hp then
        update_bar(ui.hp_bar, ui.hp_text, state.hp_bar_width, player.current_hp, player.hpp, 1)
    end
    if state.update_mp then
        update_bar(ui.mp_bar, ui.mp_text, state.mp_bar_width, player.current_mp, player.mpp, 2)
    end
    if state.update_tp then
        update_bar(ui.tp_bar, ui.tp_text, state.tp_bar_width, player.current_tp, player.tpp, 3)
    end
end

function statusbar.on_hp_change(new)
    player.current_hp = new
    state.update_hp = true
end

function statusbar.on_hpp_change(new)
    player.hpp = new
    state.update_hp = true
end

function statusbar.on_mp_change(new)
    player.current_mp = new
    state.update_mp = true
end

function statusbar.on_mpp_change(new)
    player.mpp = new
    state.update_mp = true
end

function statusbar.on_tp_change(new)
    player.current_tp = new
    player.tpp = math.min(new / 10, 100)
    state.update_tp = true
end

local THEMES = { ffxi = true, ffxiv = true, ['ffxiv-legacy'] = true }

local function reapply_theme()
    if not settings then return end
    theme_options = theme_mod.apply(settings, SELF_PATH)
    ui:load(theme_options)
    if state.ready then
        state.hp_bar_width, state.mp_bar_width, state.tp_bar_width = 0, 0, 0
        state.update_hp, state.update_mp, state.update_tp = true, true, true
    else
        ui:hide()
    end
end

function statusbar.apply_theme(id)
    if not settings then return end
    local skin = GLOBAL_SKIN[id]
    if not skin then return end
    settings.Theme.Name = skin
    config.save(settings)
    reapply_theme()
end

function statusbar.handle_command(args)
    local cmd = args[1] and args[1]:lower() or ''
    if not settings then log('statusbar: not loaded yet — log in first.'); return end
    if cmd == 'reposition' or cmd == 'move' then
        (_G.xivui_echo or log)('statusbar: use the HUD Layout editor (XivUI Menu) to move the bars.')
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            theme_options.offset_x = x
            theme_options.offset_y = y
            settings.Bars.OffsetX = math.floor(x)
            settings.Bars.OffsetY = math.floor(y)
            ui:position(theme_options)
            config.save(settings)
            log('statusbar: moved to ' .. settings.Bars.OffsetX .. ', ' .. settings.Bars.OffsetY .. '.')
        else
            log('Usage: //xui status pos <x> <y>')
        end
    elseif cmd == 'theme' then
        local name = args[2] and args[2]:lower()
        if not name then
            log('statusbar: theme is "' .. settings.Theme.Name .. '"  (available: ffxi, ffxiv, ffxiv-legacy)')
        elseif THEMES[name] then
            settings.Theme.Name = name
            config.save(settings)
            reapply_theme()
            log('statusbar: theme set to ' .. name .. '.')
        else
            log('statusbar: unknown theme "' .. name .. '". Available: ffxi, ffxiv, ffxiv-legacy.')
        end
    elseif cmd == 'compact' then
        local a = args[2] and args[2]:lower()
        if a == 'on' or a == 'true' then settings.Theme.Compact = true
        elseif a == 'off' or a == 'false' then settings.Theme.Compact = false
        else settings.Theme.Compact = not settings.Theme.Compact end
        config.save(settings)
        reapply_theme()
        log('statusbar: compact ' .. (settings.Theme.Compact and 'on' or 'off') .. '.')
    elseif cmd == 'scale' then
        local f = tonumber(args[2])
        if f then
            settings.Bars.Scale = math.max(0.5, math.min(2.5, f))
            config.save(settings)
            reapply_theme()
            log('statusbar: scale ' .. settings.Bars.Scale .. '.')
        else
            log('Usage: //xui status scale <factor>')
        end
    else
        log('statusbar commands:')
        log('  pos <x> <y> — set exact status bar offset (or use HUD Layout)')
        log('  scale <0.5-2.5> — set the bar scale (or use HUD Layout)')
        log('  theme <ffxi|ffxiv|ffxiv-legacy> — change the bar skin')
        log('  compact <on|off> — toggle the compact bar layout')
    end
end

return statusbar
