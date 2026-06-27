-- expbar — EXP / merit-point progress bar.
-- XivUI component. Maintainer: maybeLynd. Version: 0.3.0.
-- Based on "BarFiller" v0.2.5 by Morath.

local SELF_PATH = windower.addon_path .. 'assets/components/expbar/'

local config    = require('config')
local ui_bounds = require('lib/ui_bounds')
local screen    = require('lib/screen')

local function deep_copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deep_copy(v) end
    return r
end

local function strip_lowercase_keys(t)
    if type(t) ~= 'table' then return end
    for k, v in pairs(t) do
        if type(k) == 'string' and k:match('^%l') then
            t[k] = nil
        else
            strip_lowercase_keys(v)
        end
    end
end

local defaults = {}
defaults.scale = 1
defaults.Images = {}
defaults.Images.Background = {}
defaults.Images.Background.Pos = { AllowDecenter = false, X = 164, Y = 6 }
defaults.Images.Background.Visible = true
defaults.Images.Background.Texture = { Path = 'bar_bg.png', Fit = true }
defaults.Images.Background.Color = { Alpha = 255, Red = 255, Green = 255, Blue = 255 }
defaults.Images.Background.Size = { Height = 5, Width = 472 }
defaults.Images.Background.Repeatable = { X = 1, Y = 1 }
defaults.Images.Background.Draggable = false
defaults.Images.Foreground = {}
defaults.Images.Foreground.Pos = { X = 166, Y = 6 }
defaults.Images.Foreground.Visible = true
defaults.Images.Foreground.Texture = { Path = 'bar_fg.png', Fit = false }
defaults.Images.Foreground.Color = { Alpha = 255, Red = 255, Green = 255, Blue = 255 }
defaults.Images.Foreground.Size = { Height = 5, Width = 1 }
defaults.Images.Foreground.Repeatable = { X = 1, Y = 1 }
defaults.Images.Foreground.Draggable = false
defaults.Images.RestedBonus = {}
defaults.Images.RestedBonus.Pos = { X = 636, Y = 6 }
defaults.Images.RestedBonus.Visible = true
defaults.Images.RestedBonus.Texture = { Path = 'moon.png', Fit = true }
defaults.Images.RestedBonus.Color = { Alpha = 255, Red = 255, Green = 255, Blue = 255 }
defaults.Images.RestedBonus.Size = { Height = 32, Width = 32 }
defaults.Images.RestedBonus.Repeatable = { X = 1, Y = 1 }
defaults.Images.RestedBonus.Draggable = false
defaults.Texts = {}
defaults.Texts.Exp = {}
defaults.Texts.Exp.Pos = { X = 159, Y = 13 }
defaults.Texts.Exp.Background = { Alpha = 0, Red = 0, Green = 0, Blue = 0, Visible = false }
defaults.Texts.Exp.Flags = { Right = false, Bottom = false, Bold = false, Draggable = false, Italic = false }
defaults.Texts.Exp.Padding = 0
defaults.Texts.Exp.Text = {
    Size = 11, Font = 'Constantia', Fonts = {'Ubuntu Mono', 'sans-serif'},
    Alpha = 255, Red = 255, Green = 245, Blue = 191,
    Stroke = { Width = 2, Alpha = 255, Red = 0, Green = 0, Blue = 0 }
}
defaults.Stats = { Enable = false }

local settings
local cur_theme = 'ffxiv'
local bg_img
local fg_img
local rest_img
local exp_text

local xp = { registry = {}, total = 0, rate = 0, current = 0, tnl = 0 }
local chunk_update = false
local function escale() return (settings and tonumber(settings.scale)) or 1 end
local ready = false

local function mog_house_check()
    if windower.ffxi.get_info().mog_house then
        rest_img:show()
    else
        rest_img:hide()
    end
end

local function position_images()
    local x
    if settings.Images.Background.Pos.AllowDecenter ~= false then
        x = settings.Images.Background.Pos.X
    else
        x = screen.w() / 2 - settings.Images.Background.Size.Width / 2
    end
    local y = settings.Images.Background.Pos.Y
    bg_img:pos(x, y)
    fg_img:pos(x + 2, y + math.floor((settings.Images.Background.Size.Height - settings.Images.Foreground.Size.Height) / 2))
    rest_img:pos(x + settings.Images.Background.Size.Width,
        y + math.floor((settings.Images.Background.Size.Height - settings.Images.RestedBonus.Size.Height) / 2))
end

local function position_text()
    local bar_h = settings.Images.Background.Size.Height
    local font_sz = settings.Texts.Exp.Text.Size
    exp_text:pos(bg_img:pos_x() + 8, bg_img:pos_y() + math.floor((bar_h - font_sz) / 2))
end

local function move_to(x, y)
    settings.Images.Background.Pos.AllowDecenter = true
    settings.Images.Background.Pos.X = math.floor(tonumber(x) or settings.Images.Background.Pos.X or 0)
    settings.Images.Background.Pos.Y = math.floor(tonumber(y) or settings.Images.Background.Pos.Y or 0)
    position_images()
    position_text()
end

local function fmt_duration(sec)
    sec = math.floor(sec or 0)
    if sec <= 0 then return '--' end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format('%dh%02dm', h, m) end
    if m > 0 then return string.format('%dm', m) end
    return string.format('%ds', sec)
end

local function update_strings()
    local info = windower.ffxi.get_player()
    if not info then return end
    exp_text:clear()
    exp_text:append('Lv ' .. info.main_job_level)
    exp_text:append('  ' .. xp.current .. '/' .. xp.total)
    if settings.Stats and settings.Stats.Enable then
        local rate = xp.rate or 0
        exp_text:append('  |  ' .. rate .. '/hr')
        local remaining = (xp.total or 0) - (xp.current or 0)
        if rate > 0 and remaining > 0 then
            exp_text:append('  TNL ' .. fmt_duration(remaining / (rate / 3600)))
        end
    end
end

local function calc_new_width()
    if xp.current > 0 and xp.total > 0 then
        local t = os.time()
        local running = 0
        local max_ts = 0
        for ts, pts in pairs(xp.registry) do
            local diff = t - ts
            if diff > 600 then
                xp.registry[ts] = nil
            else
                running = running + pts
                if diff > max_ts then max_ts = diff end
            end
        end
        xp.rate = max_ts >= 30 and math.floor((running / max_ts) * 3600) or 0
        return math.floor((xp.current / xp.total) * 468)
    end
end

local expbar = {}

function expbar.init()
    settings = config.load('data/expbar/settings.xml', defaults)
    strip_lowercase_keys(settings)
    do local ok,ts=pcall(config.load,'data/theme/settings.xml',{Theme='ffxiv'}); cur_theme=(ok and type(ts)=='table' and ts.Theme) or 'ffxiv' end
    if cur_theme == 'ffxi' then
        settings.Images.Background.Size.Height = 7
        settings.Images.Foreground.Size.Height = 5
    end

    local function tex(img_def, fallback)
        local p = img_def.Texture and img_def.Texture.Path
        p = (p and p:match('[^/\\]+$')) or fallback
        img_def.Texture.Path = p
        local themed = SELF_PATH .. 'themes/' .. cur_theme .. '/' .. p
        local f = io.open(themed, 'rb')
        if f then f:close(); return themed end
        return SELF_PATH .. p
    end
    local bg_path   = tex(settings.Images.Background, 'bar_bg.png')
    local fg_path   = tex(settings.Images.Foreground, 'bar_fg.png')
    local rest_path = tex(settings.Images.RestedBonus, 'moon.png')

    bg_img   = images.new(deep_copy(settings.Images.Background))
    fg_img   = images.new(deep_copy(settings.Images.Foreground))
    rest_img = images.new(deep_copy(settings.Images.RestedBonus))
    exp_text = texts.new(deep_copy(settings.Texts.Exp))

    xp = { registry = {}, total = 0, rate = 0, current = 0, tnl = 0 }

    bg_img:path(bg_path)
    bg_img:fit(false)
    bg_img:size(settings.Images.Background.Size.Width, settings.Images.Background.Size.Height)
    bg_img:draggable(false)
    bg_img:show()

    fg_img:path(fg_path)
    fg_img:size(1, settings.Images.Foreground.Size.Height)
    fg_img:fit(false)
    fg_img:draggable(false)
    fg_img:show()

    rest_img:path(rest_path)
    rest_img:draggable(false)

    exp_text:bg_alpha(0)
    exp_text:bg_visible(false)
    exp_text:font((cur_theme=='ffxi') and 'Constantia' or settings.Texts.Exp.Text.Font, unpack(settings.Texts.Exp.Text.Fonts))
    exp_text:size(settings.Texts.Exp.Text.Size)
    if cur_theme == 'ffxi' then
        exp_text:color(196, 206, 222)
    else
        exp_text:color(settings.Texts.Exp.Text.Red, settings.Texts.Exp.Text.Green, settings.Texts.Exp.Text.Blue)
    end
    exp_text:stroke_alpha(255)
    exp_text:stroke_color(0, 0, 0)
    exp_text:stroke_width(2)
    exp_text:show()

    position_images()
    position_text()
    update_strings()
    chunk_update = false
end

function expbar.dispose()
    ready = false
    ui_bounds.clear('expbar')
end

function expbar.apply_theme(id)
    if not bg_img or id == cur_theme then return end
    local was_ready = ready
    expbar.hide()
    bg_img:destroy(); fg_img:destroy(); rest_img:destroy(); exp_text:destroy()
    bg_img, fg_img, rest_img, exp_text = nil, nil, nil, nil
    expbar.init()
    if was_ready then expbar.show() end
end

function expbar.push_bounds()
    if not ready or not bg_img then ui_bounds.clear('expbar'); return end
    local x = bg_img:pos_x()
    local y = bg_img:pos_y()
    local s  = escale()
    local bw = (settings.Images.Background.Size.Width or 472) * s
    local bh = (settings.Images.Background.Size.Height or 6) * s
    local mh = ((settings.Images.RestedBonus and settings.Images.RestedBonus.Size and settings.Images.RestedBonus.Size.Height) or 32) * s
    local mw = ((settings.Images.RestedBonus and settings.Images.RestedBonus.Size and settings.Images.RestedBonus.Size.Width) or 32) * s
    ui_bounds.register('expbar', x, math.floor(y + (bh - mh) / 2), math.floor(bw + mw), math.floor(mh))
end

function expbar.show()
    if not bg_img then return end
    bg_img:show()
    fg_img:show()
    exp_text:show()
    mog_house_check()
    ready = true
end

function expbar.hide()
    if not bg_img then return end
    bg_img:hide()
    fg_img:hide()
    rest_img:hide()
    exp_text:hide()
    ready = false
    ui_bounds.clear('expbar')
end

function expbar.on_prerender()
    if not ready then return end

    local s  = escale()
    local bw = math.floor(settings.Images.Background.Size.Width * s)
    local bh = math.max(1, math.floor(settings.Images.Background.Size.Height * s))
    local fh = math.max(1, math.floor(settings.Images.Foreground.Size.Height * s))
    local mw = math.floor((settings.Images.RestedBonus.Size.Width or 32) * s)
    local mh = math.floor((settings.Images.RestedBonus.Size.Height or 32) * s)
    local tsz = math.max(6, math.floor(settings.Texts.Exp.Text.Size * s))

    bg_img:size(bw, bh)
    rest_img:size(mw, mh)
    exp_text:size(tsz)

    local bx = bg_img:pos_x()
    local by = bg_img:pos_y()
    fg_img:pos(bx + 2, by + math.floor((bh - fh) / 2))
    rest_img:pos(bx + bw, by + math.floor((bh - mh) / 2))
    exp_text:pos(bx + math.floor(8 * s), by + math.floor((bh - tsz) / 2))
    if fg_img:width() > bw then fg_img:size(bw, fh) else fg_img:size(fg_img:width(), fh) end

    if chunk_update then
        local old_w = fg_img:width()
        local new_w = calc_new_width()
        if new_w and new_w > 0 then
            new_w = math.floor(new_w * s)
            if old_w < new_w then
                fg_img:size(old_w + math.ceil((new_w - old_w) * 0.1), fh)
            else
                fg_img:size(new_w, fh)
                chunk_update = false
            end
            update_strings()
        end
    end
end

function expbar.on_incoming_chunk(id, original)
    if id == 0x2D then
        local p = packets.parse('incoming', original)
        if p and p['Param 1'] and p['Message'] then
            local val, msg = p['Param 1'], p['Message']
            if msg == 8 or msg == 105 or msg == 253 then
                local t = os.time()
                xp.registry[t] = (xp.registry[t] or 0) + val
                xp.current = math.min(xp.current + val, 55999)
                if xp.current > xp.tnl then
                    xp.current = xp.current - xp.tnl
                end
                chunk_update = true
            end
        end
    elseif id == 0x61 then
        local p = packets.parse('incoming', original)
        if p then
            xp.current = p['Current EXP'] or xp.current
            xp.total = p['Required EXP'] or xp.total
            xp.tnl = xp.total - xp.current
            chunk_update = true
            update_strings()
        end
    end
end

function expbar.on_level_up()
    update_strings()
end

function expbar.on_level_down()
    update_strings()
end

function expbar.on_zone_change()
    mog_house_check()
end

function expbar.handle_command(args)
    if not settings then log('expbar: not loaded — log in / enable it first.'); return end
    local cmd = args[1] and args[1]:lower() or ''
    if cmd == 'clear' or cmd == 'c' then
        xp = { registry = {}, total = xp.total, rate = 0, current = xp.current, tnl = xp.tnl }
        update_strings()
        log('expbar: EXP rate counter reset.')
    elseif cmd == 'visible' or cmd == 'v' then
        if ready then expbar.hide() else expbar.show() end
    elseif cmd == 'stats' or cmd == 'rate' then
        settings.Stats = settings.Stats or { Enable = false }
        local a = args[2] and args[2]:lower()
        if a == 'on' then settings.Stats.Enable = true
        elseif a == 'off' then settings.Stats.Enable = false
        else settings.Stats.Enable = not settings.Stats.Enable end
        config.save(settings)
        update_strings()
        log('expbar: barfiller stats (EXP/hr + time-to-level) ' .. (settings.Stats.Enable and 'ON' or 'OFF') .. '.')
    elseif cmd == 'move' or cmd == 'reposition' then
        (_G.xivui_echo or log)('expbar: use the HUD Layout editor (XivUI Menu) to move the EXP bar.')
    elseif cmd == 'scale' then
        local f = tonumber(args[2])
        if f then
            settings.scale = math.max(0.5, math.min(2.5, f))
            config.save(settings)
            chunk_update = true
            log('expbar: scale ' .. settings.scale .. '.')
        else
            log('Usage: //xui exp scale <factor>')
        end
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            move_to(x, y)
            config.save(settings)
            log('expbar: moved to ' .. settings.Images.Background.Pos.X .. ', ' .. settings.Images.Background.Pos.Y .. '.')
        else
            log('Usage: //xui exp pos <x> <y>')
        end
    else
        log('expbar commands:')
        log('  clear — reset EXP rate counter')
        log('  visible — toggle visibility')
        log('  pos <x> <y> — set exact EXP bar position (or use HUD Layout)')
        log('  scale <0.5-2.5> — set the EXP bar scale (or use HUD Layout)')
    end
end

return expbar
