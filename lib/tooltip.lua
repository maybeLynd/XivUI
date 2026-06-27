local occlusion = require('lib/occlusion')
local screen    = require('lib/screen')
local config    = require('config')

local function theme_ffxi()
    return (_G.XIVUI_THEME or (function()
        local ok, s = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
        return (ok and type(s) == 'table' and s.Theme) or 'ffxiv'
    end)()) == 'ffxi'
end
local function bg_for(ffxi)
    local p = windower.addon_path .. 'assets/lib/tooltip/' .. (ffxi and 'ffxi/' or '') .. 'tooltip_bg.png'
    if ffxi then local f = io.open(p, 'rb'); if f then f:close() else p = windower.addon_path .. 'assets/lib/tooltip/tooltip_bg.png' end end
    return p
end
local function txt_rgb(ffxi) return ffxi and { 214, 224, 242 } or { 238, 238, 238 } end
local PAD  = 10
local ICON = 38
local GAP  = 8

local M = {}
local Tooltip = {}
Tooltip.__index = Tooltip

local function make_bg()
    local path = bg_for(theme_ffxi())
    local img = images.new({
        pos        = { x = 0, y = 0 }, visible = false,
        color      = { alpha = 255, red = 255, green = 255, blue = 255 },
        size       = { width = 1, height = 1 },
        texture    = { path = path, fit = false },
        repeatable = { x = 1, y = 1 }, draggable = false,
    })
    img:path(path); img:fit(false); img:draggable(false); img:alpha(255); img:hide()
    return img
end

function M.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Tooltip)
    M._n = (M._n or 0) + 1
    self._occ = 'btip' .. M._n
    occlusion.push(7)
    self.bg = make_bg()
    self.icon = images.new({
        pos        = { x = 0, y = 0 }, visible = false,
        color      = { alpha = 255, red = 255, green = 255, blue = 255 },
        size       = { width = ICON, height = ICON },
        texture    = { path = bg_for(theme_ffxi()), fit = true },
        repeatable = { x = 1, y = 1 }, draggable = false,
    })
    self.icon:draggable(false); self.icon:hide()
    self.txt = texts.new('${v}', {
        pos   = { x = 0, y = 0 },
        text  = { font = opts.font or 'Arial', size = opts.size or 11,
                  stroke = { width = 2, alpha = 200, red = 8, green = 8, blue = 10 } },
        flags = { bold = false, draggable = false },
        bg    = { visible = false },
    })
    self._ffxi = theme_ffxi()
    local rgb = txt_rgb(self._ffxi)
    self.txt:color(rgb[1], rgb[2], rgb[3]); self.txt:alpha(255); self.txt.v = ''; self.txt:hide()
    self.cur_icon = nil
    self.pad = opts.pad or PAD
    self.fontsize = opts.size or 11
    occlusion.pop()
    return self
end

local function estimate_box(text_str, fontsize)
    local clean = tostring(text_str or ''):gsub('\\cs%([^)]*%)', ''):gsub('\\cr', '')
    local maxlen, lines = 0, 0
    for line in (clean .. '\n'):gmatch('(.-)\n') do
        lines = lines + 1
        if #line > maxlen then maxlen = #line end
    end
    if lines == 0 then lines = 1 end
    local fs = fontsize or 11
    return math.ceil(maxlen * fs * 0.62), math.ceil(lines * (fs + 4))
end

function Tooltip:_ensure_theme()
    local ffxi = theme_ffxi()
    if self._ffxi == ffxi then return end
    self._ffxi = ffxi
    if self.bg then self.bg:path(bg_for(ffxi)) end
    local rgb = txt_rgb(ffxi)
    if self.txt then self.txt:color(rgb[1], rgb[2], rgb[3]) end
end

function Tooltip:show(icon_path, text_str, x, y)
    if not self.bg then return end
    self:_ensure_theme()
    if self.txt.v ~= text_str then self.txt.v = text_str end
    local has_icon = icon_path ~= nil and icon_path ~= ''
    if has_icon and self.cur_icon ~= icon_path then self.icon:path(icon_path); self.cur_icon = icon_path end

    local pad = self.pad
    self._ext_cache = self._ext_cache or {}
    local w, h
    local cached = self._ext_cache[text_str]
    if cached then
        w, h = cached.w, cached.h
    else
        w, h = self.txt:extents()
        if w and w > 0 and h and h > 0 then
            self._ext_cache[text_str] = { w = w, h = h }
        else
            w, h = estimate_box(text_str, self.fontsize)
        end
    end
    local iconw = has_icon and (ICON + GAP) or 0
    local bw = pad + iconw + math.floor(w) + pad
    local bh = pad + math.max(has_icon and ICON or 0, math.floor(h)) + pad

    local sw, sh = screen.size()
    local bx, by = x, y
    if bx + bw > sw then bx = sw - bw end
    if by + bh > sh then by = sh - bh end
    if bx < 0 then bx = 0 end
    if by < 0 then by = 0 end

    self.bg:size(bw, bh); self.bg:pos(bx, by); self.bg:show()
    if has_icon then
        self.icon:size(ICON, ICON); self.icon:pos(bx + pad, by + pad); self.icon:show()
    else
        self.icon:hide()
    end
    self.txt:pos(bx + pad + iconw, by + pad); self.txt:show()
    occlusion.set(self._occ, bx, by, bw, bh, 7, true)
end

function Tooltip:hide()
    if self._occ then occlusion.clear(self._occ) end
    if self.bg then self.bg:hide() end
    if self.icon then self.icon:hide() end
    if self.txt then self.txt:hide() end
end

function Tooltip:dispose()
    if self._occ then occlusion.clear(self._occ) end
    if self.bg then self.bg:destroy(); self.bg = nil end
    if self.icon then self.icon:destroy(); self.icon = nil end
    if self.txt then self.txt:destroy(); self.txt = nil end
    self.cur_icon = nil
end

return M
