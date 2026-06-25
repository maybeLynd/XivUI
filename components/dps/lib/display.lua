require('sets')
local texts  = require('texts')
local images = require('images')
local res    = require('resources')
local ui_bounds = require('lib/ui_bounds')
local occlusion = require('lib/occlusion')
local screen    = require('lib/screen')

local FILL = windower.addon_path .. 'assets/components/dps/fill_white.png'
local ICONS = windower.addon_path .. 'assets/components/dps/jobs/'

local config = require('config')
local HEADER_COL, SELF_COL
local function theme_colors(id)
    HEADER_COL = (id == 'ffxi') and {206, 216, 236} or {222, 215, 190}
    SELF_COL   = (id == 'ffxi') and {200, 222, 255} or {255, 255, 160}
end
theme_colors(_G.XIVUI_THEME or (function()
    local ok, s = pcall(config.load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
    return (ok and type(s) == 'table' and s.Theme) or 'ffxiv'
end)())

local ROLE_COLOR = {
    dps     = {200, 3, 8},
    tank    = {41, 112, 243},
    healer  = {107, 240, 86},
    support = {181, 126, 220},
    pet     = {205, 175, 125},
    special = {230, 184, 64},
    other   = {150, 150, 150},
}

local JOB_ROLE = {
    pld = 'tank', run = 'tank',
    whm = 'healer', sch = 'healer',
    brd = 'support', cor = 'support', geo = 'support', rdm = 'support',
    war = 'dps', mnk = 'dps', drk = 'dps', sam = 'dps', drg = 'dps',
    thf = 'dps', bst = 'dps', rng = 'dps', nin = 'dps', smn = 'dps',
    blu = 'dps', pup = 'dps', dnc = 'dps', blm = 'dps',
    spc = 'special', mon = 'dps',
}

local function role_of(job)
    if not job then return 'other' end
    local key = tostring(job):lower()
    if key == 'spc' then return 'special' end
    return JOB_ROLE[key] or 'dps'
end

local function resolve_role(p, job)
    if p.role_override and ROLE_COLOR[p.role_override] then return p.role_override end
    if p.is_sc or p.is_mb then return 'special' end
    if p.is_pet then return 'pet' end
    return role_of(job)
end

local COLUMNS = {
    { key = 'dmg',  label = 'DMG',  w = 44 },
    { key = 'dps',  label = 'DPS',  w = 32 },
    { key = 'dmgp', label = 'DMG%', w = 34 },
    { key = 'crit', label = 'Crit', w = 28 },
    { key = 'blk',  label = 'Blk',  w = 26 },
    { key = 'par',  label = 'Par',  w = 26 },
    { key = 'eva',  label = 'Eva',  w = 26 },
    { key = 'grd',  label = 'Grd',  w = 26 },
    { key = 'hps',  label = 'HPS',  w = 36 },
}
local COL_GAP = 4

local Display = {}
Display.__index = Display

local function mk_text(settings, right)
    local t = texts.new('', {
        pos   = { x = -1000, y = -1000 },
        text  = { size = settings.fontsize, font = settings.font, fonts = { settings.font, 'Arial', 'sans-serif' },
                  stroke = { width = 2, alpha = 200, red = 0, green = 0, blue = 0 } },
        flags = { bold = false, draggable = false, right = right and true or false },
        bg    = { visible = false },
    })
    t:hide()
    if right then occlusion.mark_right(t) end
    return t
end

local function mk_image(path, draggable)
    local i = images.new({
        pos = { x = -1000, y = -1000 }, visible = false,
        color = { alpha = 255, red = 255, green = 255, blue = 255 },
        size = { width = 1, height = 1 },
        texture = { path = path, fit = false },
        repeatable = { x = 1, y = 1 },
        draggable = draggable and true or false,
    })
    i:hide()
    return i
end

local function mk_row_cols(settings)
    local cols = {}
    for _, c in ipairs(COLUMNS) do cols[c.key] = mk_text(settings, true) end
    return cols
end

function Display.new(settings, db, clock, job_by_name)
    local self = setmetatable({}, Display)
    self.settings = settings
    self.db = db
    self.clock = clock
    self.job_by_name = job_by_name
    self.visible = settings.visible
    self.rows = {}
    self.poolsize = 0

    self.backdrop = mk_image(FILL, true)
    self.backdrop:color(0, 0, 0)
    self.backdrop:draggable(false)
    self.backdrop:pos(settings.pos.x or 600, settings.pos.y or 200)
    self.encounter = mk_text(settings)
    self.header = { name = mk_text(settings, false), cols = mk_row_cols(settings) }

    self:build_pool()
    self.last_x, self.last_y = nil, nil
    return self
end

function Display:build_pool()
    local n = self.settings.numplayers or 12
    for i = #self.rows, n + 1, -1 do
        local r = self.rows[i]
        r.bg:destroy(); r.bar:destroy(); r.icon:destroy(); r.name:destroy()
        for _, t in pairs(r.cols) do t:destroy() end
        self.rows[i] = nil
    end
    for i = #self.rows + 1, n do
        self.rows[i] = {
            bg = mk_image(FILL, false), bar = mk_image(FILL, false),
            icon = mk_image(ICONS .. 'war.png', false),
            name = mk_text(self.settings, false), cols = mk_row_cols(self.settings),
        }
    end
    self.poolsize = n
end

function Display:set_db(db, clock)
    self.db = db
    self.clock = clock
end

function Display:set_position(x, y)
    self.backdrop:pos(x, y)
    self.last_x, self.last_y = nil, nil
end

function Display.set_theme(id)
    theme_colors(id)
end

function Display:recolor()
    self.encounter:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3])
    self.header.name:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3])
    for _, t in pairs(self.header.cols) do t:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3]) end
end

local function icon_path(job)
    if job and job ~= '' then return ICONS .. job .. '.png' end
    return ICONS .. 'mon.png'
end

function Display:sorted_entries()
    local list = {}
    local total = 0
    for name, p in pairs(self.db.players) do
        total = total + p.damage
        list[#list + 1] = p
    end
    table.sort(list, function(a, b) return a.damage > b.damage end)
    return list, total
end

function Display:hide_all()
    self.backdrop:hide()
    self.encounter:hide()
    self.header.name:hide()
    for _, t in pairs(self.header.cols) do t:hide() end
    for _, r in ipairs(self.rows) do
        r.bar:hide(); r.bg:hide(); r.icon:hide(); r.name:hide()
        for _, t in pairs(r.cols) do t:hide() end
    end
end

function Display:set_visible(v)
    self.visible = v
    if not v then self:hide_all() end
end

function Display:destroy()
    self:hide_all()
    self.backdrop:destroy(); self.encounter:destroy()
    self.header.name:destroy()
    for _, t in pairs(self.header.cols) do t:destroy() end
    for _, r in ipairs(self.rows) do
        r.bar:destroy(); r.bg:destroy(); r.icon:destroy(); r.name:destroy()
        for _, t in pairs(r.cols) do t:destroy() end
    end
    self.rows = {}
end

function Display:current_bounds()
    return self._bx, self._by, self._w, self._h
end

function Display:push_bounds()
    if self._bx then
        ui_bounds.register('dps', self._bx, self._by, self._w, self._h)
    end
end

function Display:update()
    if self.settings.numplayers ~= self.poolsize then self:build_pool() end

    local s = self.settings
    self.self_name = (windower.ffxi.get_player() or {}).name
    local sc = tonumber(s.scale) or 1; if sc <= 0 then sc = 1 end
    local rowh = math.floor((s.rowheight or 18) * sc)
    local w = math.floor((s.width or 360) * sc)
    local pad = math.floor(6 * sc)
    local fs = math.max(6, math.floor((s.fontsize or 10) * sc))
    local line = fs + 4

    local bx = self.backdrop:pos_x()
    local by = self.backdrop:pos_y()
    if bx ~= self.last_x or by ~= self.last_y then
        if self.last_x ~= nil then
            s.pos.x, s.pos.y = bx, by
            local now = os.clock()
            if not self._last_save or now - self._last_save > 1 then
                config.save(s)
                self._last_save = now
            end
        end
        self.last_x, self.last_y = bx, by
    end

    local entries, total = self:sorted_entries()
    local clock = self.clock.clock
    local topdps = 0
    for _, p in ipairs(entries) do
        local d = p:get_dps(clock)
        if d > topdps then topdps = d end
    end

    local zone = res.zones[windower.ffxi.get_info().zone]
    local zonename = zone and zone.en or '?'
    local enemy = (not self.db.filter:empty()) and self.db.filter:concat(', ') or
                  ((windower.ffxi.get_mob_by_target('t') or {}).name or '---')
    local alli_dps = clock > 0 and (total / clock) or 0
    self.encounter:text(('Time: %s   Total DPS: %.0f\nZone: %s   Enemy: %s'):format(
        self.clock:to_string(), alli_dps, zonename, enemy))

    local nx = bx + pad + rowh
    local ui_x = screen.w()
    local total_num = 0
    for _, c in ipairs(COLUMNS) do total_num = total_num + c.w + COL_GAP end
    total_num = total_num - COL_GAP
    local block_left = bx + w - pad - total_num
    local lx = block_left
    for _, c in ipairs(COLUMNS) do
        c._left = lx
        c._right = lx + c.w - ui_x
        lx = lx + c.w + COL_GAP
    end
    local name_chars = math.max(3, math.floor((block_left - nx) / (fs * 0.62)))

    local gap = 8
    local header_h = 2 * line + gap
    local rowsY = by + pad + header_h + line
    local nshown = math.min(#entries, self.poolsize)
    local panel_h = pad + header_h + line + nshown * rowh + pad

    self.backdrop:size(w, panel_h)
    self.backdrop:alpha(s.background and (s.bgalpha or 150) or 0)
    self.backdrop:pos(bx, by)
    self.backdrop:show()

    self.encounter:size(fs)
    self.encounter:pos(bx + pad, by + pad)
    self.encounter:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3])
    self.encounter:show()

    local header_y = by + pad + header_h
    self.header.name:size(fs)
    self.header.name:pos(nx, header_y)
    self.header.name:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3])
    self.header.name:text('Name')
    self.header.name:show()
    for _, c in ipairs(COLUMNS) do
        local t = self.header.cols[c.key]
        t:size(fs)
        t:pos(c._right, header_y)
        t:color(HEADER_COL[1], HEADER_COL[2], HEADER_COL[3])
        t:text(c.label)
        t:show()
    end

    for i = 1, self.poolsize do
        local r = self.rows[i]
        local p = entries[i]
        if p and i <= nshown then
            local y = rowsY + (i - 1) * rowh
            local ty = y + math.floor((rowh - line) / 2)
            local dps = p:get_dps(clock)
            local job = p.job or self.job_by_name[p.name]
            local role = resolve_role(p, job)
            local col = ROLE_COLOR[role] or ROLE_COLOR.other

            r.bg:pos(bx, y); r.bg:size(w, rowh)
            r.bg:color(0, 0, 0); r.bg:alpha((i % 2 == 0) and 100 or 40)
            r.bg:show()

            local bw = (topdps > 0) and math.max(2, math.floor(w * dps / topdps)) or 2
            r.bar:pos(bx, y); r.bar:size(bw, rowh)
            r.bar:color(col[1], col[2], col[3]); r.bar:alpha(s.baralpha or 90)
            r.bar:show()

            local ipath = (p.is_sc or p.is_mb) and (ICONS .. 'mon.png') or icon_path(job)
            r.icon:pos(bx + 1, y + 1); r.icon:size(rowh - 2, rowh - 2)
            r.icon:path(ipath); r.icon:show()

            local sw     = p:swings_at_me()
            local vals = {
                dmg  = ('%.0f'):format(p.damage),
                dps  = ('%.0f'):format(dps),
                dmgp = total > 0 and ('%.0f%%'):format(100 * p.damage / total) or '-',
                crit = (p.m_hits + p.m_crits) > 0 and ('%.0f%%'):format(p:crit_pct()) or '-',
                blk  = sw > 0 and ('%.0f%%'):format(p:block_pct()) or '-',
                par  = sw > 0 and ('%.0f%%'):format(p:parry_pct()) or '-',
                eva  = sw > 0 and ('%.0f%%'):format(p:eva_pct()) or '-',
                grd  = sw > 0 and ('%.0f%%'):format(p:guard_pct()) or '-',
                hps  = p.heal_amount > 0 and ('%.0f'):format(p:get_hps(clock)) or '-',
            }
            if p.is_sc or p.is_mb then
                vals.crit, vals.blk, vals.par, vals.eva, vals.grd, vals.hps = '-','-','-','-','-','-'
            end

            local cr, cg, cb = 255, 255, 255
            if p.name == self.self_name then cr, cg, cb = SELF_COL[1], SELF_COL[2], SELF_COL[3] end

            r.name:size(fs)
            r.name:pos(nx, ty)
            r.name:text((p.name or ''):sub(1, name_chars))
            r.name:color(cr, cg, cb)
            r.name:show()
            for _, c in ipairs(COLUMNS) do
                local t = r.cols[c.key]
                t:size(fs)
                t:pos(c._right, ty)
                t:text(vals[c.key])
                t:color(cr, cg, cb)
                t:show()
            end
        else
            r.bar:hide(); r.bg:hide(); r.icon:hide(); r.name:hide()
            for _, t in pairs(r.cols) do t:hide() end
        end
    end

    self._bx, self._by, self._w, self._h = bx, by, w, panel_h
end

return Display
