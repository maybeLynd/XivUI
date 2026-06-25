local occlusion = require('lib/occlusion')
local screen    = require('lib/screen')
local config    = require('config')

local AP   = windower.addon_path
local FFXI
local function art(name)
    if FFXI then
        local p = AP .. 'assets/lib/tooltip/ffxi/' .. name
        local f = io.open(p, 'rb'); if f then f:close(); return p end
    end
    return AP .. 'assets/lib/tooltip/' .. name
end
local BG, DIV, PILL
local GRAY, TYPEC, WHT, YEL, LABEL_RGB
local CR   = '\\cr'
local GRN  = '\\cs(72,180,86)'
local LIME = '\\cs(152,224,92)'
local function set_palette(ffxi)
    FFXI = ffxi
    BG, DIV, PILL = art('tooltip_bg.png'), art('tooltip_divider.png'), art('tooltip_pill.png')
    GRAY  = ffxi and '\\cs(150,162,186)' or '\\cs(156,155,145)'
    TYPEC = ffxi and '\\cs(150,162,186)' or '\\cs(156,155,145)'
    WHT   = ffxi and '\\cs(214,224,242)' or '\\cs(250,250,250)'
    YEL   = ffxi and '\\cs(200,213,238)' or '\\cs(224,202,114)'
    LABEL_RGB = ffxi and { 150, 162, 186 } or { 156, 155, 145 }
end
set_palette((_G.XIVUI_THEME or (function()
    local ok, s = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
    return (ok and type(s) == 'table' and s.Theme) or 'ffxiv'
end)()) == 'ffxi')

local W    = 360
local PAD  = 12
local ICON = 44
local HX   = PAD + ICON + 10

local VAL_ADJ  = 8
local TEXT_ADJ = 2

local M = {}
local AT = {}
AT.__index = AT

local function img(path)
    local i = images.new({ pos = { x = 0, y = 0 }, visible = false,
        color = { alpha = 255, red = 255, green = 255, blue = 255 },
        size = { width = 8, height = 8 },
        texture = { path = path, fit = false }, repeatable = { x = 1, y = 1 }, draggable = false })
    i:path(path); i:fit(false); i:draggable(false); i:hide()
    return i
end

local function txt(size, bold, right)
    local t = texts.new('${v}', { pos = { x = 0, y = 0 },
        text = { font = 'Constantia', size = size, stroke = { width = 2, alpha = 220, red = 8, green = 8, blue = 10 } },
        flags = { bold = bold or false, draggable = false, right = right or false }, bg = { visible = false } })
    t:color(255, 255, 255); t:alpha(255); t.v = ''; t:hide()
    if right then pcall(function() t:right_justified(true) end) end
    return t
end

local function px(s, size) return #tostring(s) * size * 0.56 end

local function ext_w(t, fallback)
    local w = select(1, t:extents())
    return (w and w > 0) and w or fallback
end

local function wrap(s, maxchars)
    if not s or s == '' then return '', 0 end
    s = tostring(s):gsub('%s+', ' '):gsub('^%s', '')
    local lines, line = {}, ''
    for word in s:gmatch('%S+') do
        if #line == 0 then line = word
        elseif #line + 1 + #word <= maxchars then line = line .. ' ' .. word
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= '' then lines[#lines + 1] = line end
    return table.concat(lines, '\n'), #lines
end

function M.new()
    local self = setmetatable({}, AT)
    M._n = (M._n or 0) + 1
    self._occ = 'tooltip' .. M._n
    occlusion.push(2)
    self.bg    = img(BG)
    self.icon  = img(BG)
    self.div   = img(DIV)
    self.pill1 = img(PILL)
    self.pill2 = img(PILL)
    self.cur_icon = nil

    self.name  = txt(13, true)
    self.typ   = txt(10)
    self.rng   = txt(10)
    self.rad   = txt(10)
    self.cast_l= txt(9);  self.cast_l:color(LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3])
    self.rec_l = txt(9);  self.rec_l:color(LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3])
    self.cast_v= txt(12, true, true)
    self.rec_v = txt(12, true, true)
    self.desc  = txt(10)
    self.add   = txt(10)
    self.sub   = txt(8)
    self.dur   = txt(10)
    self.acq_l = txt(10)
    self.acq_v = txt(10)
    self.aff_l = txt(10)
    self.aff_v = txt(10)
    self.unusable = txt(10)
    self.all = { 'name','typ','rng','rad','cast_l','rec_l','cast_v','rec_v',
                 'desc','add','sub','dur','acq_l','acq_v','aff_l','aff_v','unusable' }
    self.base_sizes = { name=13, typ=10, rng=10, rad=10, cast_l=9, rec_l=9, cast_v=12, rec_v=12,
        desc=10, add=10, sub=8, dur=10, acq_l=10, acq_v=10, aff_l=10, aff_v=10, unusable=10 }
    self.scale = 1
    occlusion.pop()
    return self
end

function AT:set_scale(s) self.scale = math.max(0.5, math.min(2.5, tonumber(s) or 1)) end

function AT:hide()
    if not self.bg then return end
    if self._occ then occlusion.clear(self._occ) end
    self.bg:hide(); self.icon:hide(); self.div:hide(); self.pill1:hide(); self.pill2:hide()
    for _, k in ipairs(self.all) do self[k]:hide() end
end

local function put(t, s) t.v = s; t:show() end

function AT:show(info, x, y)
    if not self.bg or not info then return end
    local want = (_G.XIVUI_THEME or 'ffxiv') == 'ffxi'
    if want ~= FFXI then set_palette(want) end
    if self._art_ffxi ~= FFXI then
        self.bg:path(BG); self.div:path(DIV); self.pill1:path(PILL); self.pill2:path(PILL)
        self.cast_l:color(LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3])
        self.rec_l:color(LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3])
        self._art_ffxi = FFXI
    end
    self:hide()

    if info.icon_path and info.icon_path ~= '' and self.cur_icon ~= info.icon_path then
        self.icon:path(info.icon_path); self.cur_icon = info.icon_path
    end

    local s = self.scale or 1
    local function S(n) return math.floor(n * s + 0.5) end
    local W, PAD, ICON = S(360), S(12), S(44)
    local HX = PAD + ICON + S(10)
    for k, base in pairs(self.base_sizes) do self[k]:size(math.max(6, S(base))) end

    local oy_name = PAD
    local oy_sub  = PAD + S(22)
    local colw    = (W - 2 * PAD) / 2
    local lcx     = PAD + colw / 2
    local rcx     = PAD + colw + colw / 2
    local oy_cl, oy_cv, oy_pill, oy_div, oy_body
    local compact = info.is_choice or (info.cast == nil)

    if compact then
        oy_div  = PAD + ICON + S(8)
        oy_body = oy_div + S(8)
    else
        oy_cl   = oy_sub + S(22)
        oy_cv   = oy_cl + S(16)
        oy_pill = oy_cv + S(15)
        oy_div  = oy_cv + S(30)
        oy_body = oy_div + S(7)
    end

    local LH, LHS = S(18), S(14)
    local blocks = {}
    if info.is_choice then
        local mw, mn = wrap(info.members or '', 48)
        if mn > 0 then blocks[#blocks + 1] = { obj = self.desc, v = WHT .. mw .. CR, n = mn, lh = LH } end
    else
        local dwrap, dn = wrap(info.desc, 43)
        if dn > 0 then blocks[#blocks + 1] = { obj = self.desc, v = WHT .. dwrap .. CR, n = dn, lh = LH } end
        if info.add_effect then
            blocks[#blocks + 1] = { obj = self.add, v = GRN .. 'Additional Effect: ' .. CR .. YEL .. info.add_effect .. CR, n = 1, lh = LH }
            if info.add_effect_desc then
                local sw, sn = wrap(info.add_effect_desc, 64)
                blocks[#blocks + 1] = { obj = self.sub, v = GRAY .. sw .. CR, n = sn, lh = LHS }
            end
        end
        if info.duration then
            blocks[#blocks + 1] = { obj = self.dur, v = GRN .. 'Duration: ' .. CR .. WHT .. info.duration .. CR, n = 1, lh = LH }
        end
    end

    local body_h = 0
    for _, b in ipairs(blocks) do body_h = body_h + b.n * b.lh end
    local u_wrapped, u_lines
    if info.unusable then u_wrapped, u_lines = wrap('Not Usable: ' .. info.unusable, 44) end
    local rows_h = 0
    if info.acquired then rows_h = rows_h + LH end
    if info.affinity then
        local _, an = wrap(info.affinity, 42)
        rows_h = rows_h + math.max(1, an) * LH
    end
    if info.unusable then rows_h = rows_h + math.max(1, u_lines or 1) * LH end
    local total_h = oy_body + body_h + rows_h + PAD

    local sw, sh = screen.size()
    local bx, by = x, y
    if bx + W > sw then bx = sw - W end
    if by + total_h > sh then by = sh - total_h end
    if bx < 0 then bx = 0 end
    if by < 0 then by = 0 end

    self.bg:size(W, total_h); self.bg:pos(bx, by); self.bg:show()
    occlusion.set(self._occ, bx, by, W, total_h, 2)
    self.icon:size(ICON, ICON); self.icon:pos(bx + PAD, by + PAD); self.icon:show()
    put(self.name, WHT .. (info.name or '') .. CR); self.name:pos(bx + HX, by + oy_name)

    if info.is_choice then
        put(self.typ, TYPEC .. 'Choice' .. CR); self.typ:pos(bx + HX, by + oy_sub)
    else
        put(self.typ, TYPEC .. (info.type or '') .. CR); self.typ:pos(bx + HX, by + oy_sub)
        if info.range then put(self.rng, GRAY .. 'Range ' .. CR .. WHT .. info.range .. CR); self.rng:pos(bx + S(150), by + oy_sub) end
        if info.radius then put(self.rad, GRAY .. 'Radius ' .. CR .. WHT .. info.radius .. CR); self.rad:pos(bx + S(252), by + oy_sub) end
        if info.cast then
            local uxr = (windower.get_windower_settings() or {}).ui_x_res or sw
            local lfs = math.max(6, S(9))
            local lr  = lfs / 9
            local vadj, tadj = math.floor(VAL_ADJ * lr + 0.5), math.floor(TEXT_ADJ * lr + 0.5)
            put(self.cast_l, 'Cast')
            local cl_w = px('Cast', lfs)
            local cl_x = lcx - cl_w / 2
            self.cast_l:pos(bx + cl_x, by + oy_cl)
            local p1l, p1r = PAD + S(6), cl_x + cl_w
            self.pill1:size(p1r - p1l, S(8)); self.pill1:pos(bx + p1l + vadj, by + oy_pill); self.pill1:show()
            put(self.cast_v, info.cast); self.cast_v:pos(bx + p1r + vadj + tadj - uxr, by + oy_cv)
            if not info.no_recast then
                put(self.rec_l, 'Recast')
                local rl_w = px('Recast', lfs)
                local rl_x = rcx - rl_w / 2
                self.rec_l:pos(bx + rl_x, by + oy_cl)
                local p2l, p2r = PAD + colw + S(6), rl_x + rl_w
                self.pill2:size(p2r - p2l, S(8)); self.pill2:pos(bx + p2l + vadj, by + oy_pill); self.pill2:show()
                if info.recast then put(self.rec_v, info.recast); self.rec_v:pos(bx + p2r + vadj + tadj - uxr, by + oy_cv) end
            end
        end
    end

    self.div:size(W - 2 * PAD, S(2)); self.div:pos(bx + PAD, by + oy_div); self.div:show()

    local cy = by + oy_body
    for _, b in ipairs(blocks) do
        put(b.obj, b.v); b.obj:pos(bx + PAD, cy)
        cy = cy + b.n * b.lh
    end

    if info.acquired then
        put(self.acq_l, GRAY .. 'Acquired' .. CR); self.acq_l:pos(bx + PAD, cy)
        put(self.acq_v, LIME .. info.acquired .. CR); self.acq_v:pos(bx + PAD + S(78), cy)
        cy = cy + LH
    end
    if info.affinity then
        local aw, an = wrap(info.affinity, 42)
        put(self.aff_l, GRAY .. 'Affinity' .. CR); self.aff_l:pos(bx + PAD, cy)
        put(self.aff_v, WHT .. aw .. CR); self.aff_v:pos(bx + PAD + S(78), cy)
        cy = cy + math.max(1, an) * LH
    end
    if info.unusable then
        put(self.unusable, '\\cs(236,120,96)' .. u_wrapped .. '\\cr')
        self.unusable:pos(bx + PAD, cy)
    end
end

function AT:dispose()
    if not self.bg then return end
    self.bg:destroy(); self.icon:destroy(); self.div:destroy(); self.pill1:destroy(); self.pill2:destroy()
    for _, k in ipairs(self.all) do self[k]:destroy() end
    self.bg = nil
end

return M
