local ui = {}

local screen = require('lib/screen')

ui.background = images.new({ draggable = false })
ui.hp_bar = images.new({ draggable = false })
ui.mp_bar = images.new({ draggable = false })
ui.tp_bar = images.new({ draggable = false })
ui.hp_text = texts.new({ flags = { draggable = false } })
ui.mp_text = texts.new({ flags = { draggable = false } })
ui.tp_text = texts.new({ flags = { draggable = false } })

local function setup_image(image, path, fit_to_texture)
    if fit_to_texture then image:fit(true) end
    image:path(path)
    image:repeat_xy(1, 1)
    image:draggable(false)
    if not fit_to_texture then image:fit(false) end
    image:show()
end

local function setup_text(text, opts)
    text:bg_alpha(0)
    text:bg_visible(false)
    text:font(opts.font)
    text:size(opts.font_size)
    text:color(opts.font_color_red, opts.font_color_green, opts.font_color_blue)
    text:stroke_transparency(opts.font_stroke_alpha)
    text:stroke_color(opts.font_stroke_color_red, opts.font_stroke_color_green, opts.font_stroke_color_blue)
    text:stroke_width(opts.font_stroke_width)
    text:right_justified()
    text:show()
end

function ui:load(opts)
    setup_image(self.background, opts.bar_background)
    setup_image(self.hp_bar, opts.bar_hp)
    setup_image(self.mp_bar, opts.bar_mp)
    setup_image(self.tp_bar, opts.bar_tp)
    setup_text(self.hp_text, opts)
    setup_text(self.mp_text, opts)
    setup_text(self.tp_text, opts)
    self:position(opts)
end

function ui:position(opts)
    local sw, sh = screen.size()
    local sc = opts.scale or 1
    local x = sw / 2 - (opts.total_width / 2) + opts.offset_x
    local y = sh - 60 + opts.offset_y

    local fy = opts.fill_offset_y or (2 * sc)
    local ty = 2 * sc
    self.background:size(opts.total_width, opts.bg_height)
    self.background:pos(x, y)
    self.hp_bar:pos(x + 15 * sc + opts.bar_offset, y + fy)
    self.mp_bar:pos(x + 25 * sc + opts.bar_offset + opts.bar_width + opts.bar_spacing, y + fy)
    self.tp_bar:pos(x + 35 * sc + opts.bar_offset + (opts.bar_width * 2) + (opts.bar_spacing * 2), y + fy)
    self.hp_bar:width(0)
    self.mp_bar:width(0)
    self.tp_bar:width(0)
    self.hp_text:pos(x + 65 * sc + opts.text_offset, y + ty)
    self.mp_text:pos(x + 80 * sc + opts.text_offset + opts.bar_width + opts.bar_spacing, y + ty)
    self.tp_text:pos(x + 90 * sc + opts.text_offset + (opts.bar_width * 2) + (opts.bar_spacing * 2), y + ty)
end

function ui:hide()
    self.background:hide()
    self.hp_bar:hide()
    self.hp_text:hide()
    self.mp_bar:hide()
    self.mp_text:hide()
    self.tp_bar:hide()
    self.tp_text:hide()
end

function ui:show()
    self.background:show()
    self.hp_bar:show()
    self.hp_text:show()
    self.mp_bar:show()
    self.mp_text:show()
    self.tp_bar:show()
    self.tp_text:show()
end

return ui
