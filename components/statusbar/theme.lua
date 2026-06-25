local theme = {}

theme.apply = function(settings, base_path)
    local options = {}

    options.total_height = 8
    options.total_width = 472
    options.offset_x = settings.Bars.OffsetX
    options.offset_y = settings.Bars.OffsetY

    local theme_dir = windower.addon_path .. 'assets/components/statusbar/themes/' .. settings.Theme.Name .. '/'
    options.bar_background = theme_dir .. 'bar_bg.png'
    options.bar_hp = theme_dir .. 'hp_fg.png'
    options.bar_mp = theme_dir .. 'mp_fg.png'
    options.bar_tp = theme_dir .. 'tp_fg.png'

    options.font = settings.Texts.Font
    options.font_size = settings.Texts.Size
    options.font_alpha = settings.Texts.Color.Alpha
    options.font_color_red = settings.Texts.Color.Red
    options.font_color_green = settings.Texts.Color.Green
    options.font_color_blue = settings.Texts.Color.Blue
    options.font_stroke_width = settings.Texts.Stroke.Width
    options.font_stroke_alpha = settings.Texts.Stroke.Alpha
    options.font_stroke_color_red = settings.Texts.Stroke.Red
    options.font_stroke_color_green = settings.Texts.Stroke.Green
    options.font_stroke_color_blue = settings.Texts.Stroke.Blue
    options.full_tp_color_red = settings.Texts.FullTpColor.Red
    options.full_tp_color_green = settings.Texts.FullTpColor.Green
    options.full_tp_color_blue = settings.Texts.FullTpColor.Blue
    options.text_offset = settings.Texts.Offset

    options.bar_width = settings.Theme.Bar.Width
    options.bar_spacing = settings.Theme.Bar.Spacing
    options.bar_offset = settings.Theme.Bar.Offset
    options.dim_tp_bar = settings.Theme.DimTpBar

    if settings.Theme.Compact then
        options.bar_background = windower.addon_path .. 'assets/components/statusbar/themes/' .. settings.Theme.Name .. '/bar_compact.png'
        options.total_width = 422
        options.bar_width = settings.Theme.Bar.Compact.Width
        options.bar_spacing = settings.Theme.Bar.Compact.Spacing
        options.bar_offset = settings.Theme.Bar.Compact.Offset
    end

    if settings.Theme.Name == 'ffxiv' then
        options.font_stroke_alpha = 150
        options.font_stroke_color_red = 80
        options.font_stroke_color_green = 70
        options.font_stroke_color_blue = 30
    end

    options.fill_offset_y = 2
    options.fill_width = options.bar_width
    if settings.Theme.Name == 'ffxi' then
        options.total_height = 7
        options.fill_offset_y = 3
        options.dim_tp_bar = false
        options.num_colors = { {252, 170, 168}, {218, 220, 170}, {176, 198, 242} }
        options.font_color_red, options.font_color_green, options.font_color_blue = 224, 230, 244
        options.full_tp_color_red, options.full_tp_color_green, options.full_tp_color_blue = 176, 198, 242
        options.font_stroke_alpha = 200
        options.font_stroke_color_red, options.font_stroke_color_green, options.font_stroke_color_blue = 6, 8, 16
    end

    local sc = (settings.Bars and tonumber(settings.Bars.Scale)) or 1
    if sc <= 0 then sc = 1 end
    options.scale = sc
    if sc ~= 1 then
        options.total_width = options.total_width * sc
        options.total_height = options.total_height * sc
        options.bar_width = options.bar_width * sc
        options.fill_width = options.fill_width * sc
        options.fill_offset_y = options.fill_offset_y * sc
        options.bar_spacing = options.bar_spacing * sc
        options.bar_offset = options.bar_offset * sc
        options.font_size = math.floor(options.font_size * sc + 0.5)
        options.text_offset = options.text_offset * sc
    end

    return options
end

return theme
