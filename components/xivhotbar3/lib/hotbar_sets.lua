-- hotbar_sets: the 3x3 saved-set grid: save/load a job's full hotbar layout per slot, plus save interaction. 
-- XivUI hotbar lib. Maintainer: maybeLynd.
local hotbar_sets = {}

local NODE_COUNT = 9
local COLS = 3
local ROWS = 3
local DOT_BASE = 26

local COLOR_EMPTY = { 120, 120, 120 }
local COLOR_SAVED = { 88, 222, 188 }

local dots = {}
local title_text
local panel_bg, divider
local rings = {}
local function sets_path(name)
  if _G.XIVUI_THEME == 'ffxi' then
    local p = HTB_ART .. 'themes/ffxi/' .. name
    local f = io.open(p, 'rb'); if f then f:close(); return p end
  end
  return HTB_ART .. 'other/' .. name
end

local base_x = 1380
local base_y = 980
local spacing = 34
local dot_scale = 1.0

local visible = false
local ext_hidden = false
local hovered_node = nil

local label_text_setup = {
  flags = { draggable = false, bold = true },
}

local function player_name(self)
  local p = self.player
  if p and p.name and p.name ~= '' then return p.name end
  return nil
end

local function player_job(self)
  local p = self.player
  if p and p.main_job and p.main_job ~= '' then return p.main_job end
  return nil
end

local function char_dir(self)
  local name = player_name(self)
  if not name then return nil end
  return HTB_PATH .. 'data/' .. name .. '/'
end

local function sets_dir(self)
  local dir = char_dir(self)
  if not dir then return nil end
  return dir .. 'sets/'
end

local function job_file_path(self, job)
  local dir = char_dir(self)
  if not dir then return nil end
  return dir .. job .. '.lua'
end

local function layout_file_path(self, job)
  local dir = char_dir(self)
  if not dir then return nil end
  return dir .. 'layout_' .. job .. '.lua'
end

local function content_path(self, job, n)
  local dir = sets_dir(self)
  if not dir then return nil end
  return dir .. job .. '_' .. n .. '.lua'
end

local function set_layout_path(self, job, n)
  local dir = sets_dir(self)
  if not dir then return nil end
  return dir .. job .. '_' .. n .. '_layout.lua'
end

local function names_path(self, job)
  local dir = sets_dir(self)
  if not dir then return nil end
  return dir .. job .. '_names.lua'
end

local function ensure_dir(self)
  local dir = sets_dir(self)
  if not dir then return false end
  if windower.dir_exists and windower.dir_exists(dir) then return true end
  if windower.create_dir then pcall(windower.create_dir, dir) end
  return true
end

local function file_exists(path)
  if not path then return false end
  local f = io.open(path, 'r')
  if f then f:close(); return true end
  return false
end

local function read_all(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*all')
  f:close()
  return content
end

local function write_all(path, content)
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

local function load_names(self)
  local job = player_job(self)
  if not job then return {} end
  local path = names_path(self, job)
  if not path then return {} end
  local chunk = loadfile(path)
  if not chunk then return {} end
  local ok, t = pcall(chunk)
  if ok and type(t) == 'table' then return t end
  return {}
end

local function save_names(self, names)
  local job = player_job(self)
  if not job then return false end
  ensure_dir(self)
  local lines = { 'return {' }
  for i = 1, NODE_COUNT do
    if names[i] and names[i] ~= '' then
      lines[#lines + 1] = string.format('  [%d] = %q,', i, names[i])
    end
  end
  lines[#lines + 1] = '}'
  return write_all(names_path(self, job), table.concat(lines, '\n') .. '\n')
end

function hotbar_sets:has_set(n)
  local job = player_job(self)
  if not job then return false end
  return file_exists(content_path(self, job, n))
end

function hotbar_sets:get_name(n)
  return load_names(self)[n]
end

function hotbar_sets:get_names()
  return load_names(self)
end

function hotbar_sets:save_set(n, name)
  local job = player_job(self)
  if not job then return false, 'no job' end
  ensure_dir(self)
  local content = read_all(job_file_path(self, job))
  if not content then return false, 'no job file' end
  if not write_all(content_path(self, job, n), content) then return false, 'write failed' end

  local layout = read_all(layout_file_path(self, job))
  if layout then
    write_all(set_layout_path(self, job, n), layout)
  else
    os.remove(set_layout_path(self, job, n))
  end
  local names = load_names(self)
  local final = (name and name ~= '') and name or names[n] or ('Set ' .. n)
  names[n] = final
  save_names(self, names)
  self:refresh_colors()
  return true, final
end

function hotbar_sets:load_set(n)
  local job = player_job(self)
  if not job then return false end
  local content = read_all(content_path(self, job, n))
  if not content then return false end
  if not write_all(job_file_path(self, job), content) then return false end
  local layout = read_all(set_layout_path(self, job, n))
  if layout then
    write_all(layout_file_path(self, job), layout)
  end
  return true
end

function hotbar_sets:clear_set(n)
  local job = player_job(self)
  if not job then return false end
  local path = content_path(self, job, n)
  if path then os.remove(path) end
  local lpath = set_layout_path(self, job, n)
  if lpath then os.remove(lpath) end
  local names = load_names(self)
  names[n] = nil
  save_names(self, names)
  self:refresh_colors()
  return true
end

local function dot_size()
  return math.max(8, math.floor(DOT_BASE * dot_scale))
end

local function eff_spacing()
  return spacing * dot_scale
end

local function node_xy(i)
  local col = (i - 1) % COLS
  local row = math.floor((i - 1) / COLS)
  local sp = eff_spacing()
  return base_x + col * sp, base_y + row * sp
end

function hotbar_sets:grid_bounds()
  local ds = dot_size()
  local sp = eff_spacing()
  local w = (COLS - 1) * sp + ds
  local h = (ROWS - 1) * sp + ds
  return base_x, base_y, w, h
end

function hotbar_sets:setup(theme_options)
  self.theme = theme_options
end

function hotbar_sets:set_player(player)
  self.player = player
end

function hotbar_sets:apply_settings(hs)
  if not hs then return end
  if hs.Pos then
    base_x = tonumber(hs.Pos.X) or base_x
    base_y = tonumber(hs.Pos.Y) or base_y
  end
  spacing = tonumber(hs.Spacing) or spacing
  dot_scale = tonumber(hs.DotScale) or dot_scale
  visible = hs.Visible == true
end

function hotbar_sets:init_grid()
  self:destroy()
  local ds = dot_size()

  panel_bg = images.new()
  panel_bg:draggable(false); panel_bg:fit(false); panel_bg:path(sets_path('sets_panel.png')); panel_bg:alpha(255); panel_bg:hide()

  for i = 1, NODE_COUNT do
    local img = images.new()
    img:draggable(false)
    img:fit(false)
    img:path(HTB_ART .. 'other/dot.png')
    img:size(ds, ds)
    img:alpha(255)
    img:color(COLOR_EMPTY[1], COLOR_EMPTY[2], COLOR_EMPTY[3])
    img:hide()
    dots[i] = img
  end

  for i = 1, NODE_COUNT do
    local r = images.new()
    r:draggable(false); r:fit(false); r:path(sets_path('sets_ring.png')); r:alpha(255); r:hide()
    rings[i] = r
  end

  divider = images.new()
  divider:draggable(false); divider:fit(false); divider:path(sets_path('sets_divider.png')); divider:alpha(255); divider:hide()

  title_text = texts.new(table.copy(label_text_setup, true), true)
  title_text:bg_alpha(0)
  title_text:bg_visible(false)
  title_text:font('Constantia')
  title_text:size(11)
  if _G.XIVUI_THEME == 'ffxi' then title_text:color(206, 217, 240)
  else title_text:color(220, 222, 226) end
  title_text:stroke_transparency(200)
  title_text:stroke_color(20, 20, 20)
  title_text:stroke_width(2)
  title_text:text('Hotbar Sets')
  title_text:hide()

  self:update_positions()
  self:refresh_colors()
end

function hotbar_sets:update_positions()
  local ds = dot_size()
  local gw = (COLS - 1) * eff_spacing() + ds
  local gh = (ROWS - 1) * eff_spacing() + ds
  local PAD = math.floor(12 * dot_scale)
  local head = math.floor(48 * dot_scale)
  if panel_bg then
    panel_bg:pos(base_x - PAD, base_y - head)
    panel_bg:size(gw + 2 * PAD, gh + head + math.floor(12 * dot_scale))
  end
  if divider then
    divider:pos(base_x, base_y - math.floor(16 * dot_scale))
    divider:size(gw, math.max(2, math.floor(7 * dot_scale)))
  end
  for i = 1, NODE_COUNT do
    local x, y = node_xy(i)
    if dots[i] then
      dots[i]:size(ds, ds)
      dots[i]:pos(x, y)
    end
    if rings[i] then
      rings[i]:size(ds + 2, ds + 2)
      rings[i]:pos(x - 1, y - 1)
    end
  end
  if title_text then
    title_text:size(math.max(8, math.floor(11 * dot_scale)))
    title_text:pos(base_x, base_y - math.floor(36 * dot_scale))
  end
end

function hotbar_sets:set_hover(node)
  if node == hovered_node then return end
  hovered_node = node
  if self._hold == nil then self:refresh_colors() end
end

function hotbar_sets:refresh_colors()
  for i = 1, NODE_COUNT do
    if dots[i] then
      local c = self:has_set(i) and COLOR_SAVED or COLOR_EMPTY
      if i == hovered_node then
        dots[i]:color(math.min(255, c[1] + 70), math.min(255, c[2] + 70), math.min(255, c[3] + 70))
      else
        dots[i]:color(c[1], c[2], c[3])
      end
    end
  end
end

function hotbar_sets:set_hold(node, progress)
  if not (node and dots[node]) then return end
  progress = math.max(0, math.min(1, progress or 0))
  local function lerp(a, b) return math.floor(a + (b - a) * progress + 0.5) end
  dots[node]:color(lerp(COLOR_EMPTY[1], 255), lerp(COLOR_EMPTY[2], 215), lerp(COLOR_EMPTY[3], 0))
  if title_text then title_text:text(('Hold to save set %d…  %d%%'):format(node, math.floor(progress * 100 + 0.5))) end
end

function hotbar_sets:clear_hold()
  self:update_positions()
  self:refresh_colors()
  if title_text then title_text:text('Hotbar Sets') end
end

function hotbar_sets:set_saved_title(n)
  if title_text then title_text:text(('Saved to set %d — release'):format(n)) end
end

local HOLD_SECS = 3
function hotbar_sets:begin_hold(node)
  if not node then return end
  self._hold = { node = node, t = os.clock(), saved = false }
end
function hotbar_sets:hold_node() return self._hold and self._hold.node or nil end
function hotbar_sets:hold_saved() return self._hold ~= nil and self._hold.saved == true end
function hotbar_sets:mark_hold_saved() if self._hold then self._hold.saved = true end end
function hotbar_sets:hold_progress()
  if not self._hold then return nil end
  local p = (os.clock() - self._hold.t) / HOLD_SECS
  if p < 0 then p = 0 elseif p > 1 then p = 1 end
  return p
end
function hotbar_sets:tick_hold()
  local p = self:hold_progress()
  if p then self:set_hold(self._hold.node, p) end
  return p
end
function hotbar_sets:end_hold()
  self._hold = nil
  self:clear_hold()
end

local function draw(self, on)
  if panel_bg then if on then panel_bg:show() else panel_bg:hide() end end
  for i = 1, NODE_COUNT do
    if dots[i] then if on then dots[i]:show() else dots[i]:hide() end end
    if rings[i] then if on then rings[i]:show() else rings[i]:hide() end end
  end
  if divider then if on then divider:show() else divider:hide() end end
  if title_text then if on then title_text:show() else title_text:hide() end end
end

function hotbar_sets:is_visible()
  return visible
end

function hotbar_sets:set_visible(b)
  visible = b == true
  self:refresh_visibility()
  return visible
end

function hotbar_sets:toggle_visible()
  return self:set_visible(not visible)
end

function hotbar_sets:set_force_shown(force)
  self._force = force == true
  self:refresh_visibility()
end

function hotbar_sets:set_ext_hidden(hidden)
  ext_hidden = hidden == true
  self:refresh_visibility()
end

function hotbar_sets:refresh_visibility()
  local on = (visible or self._force) and not ext_hidden
  draw(self, on)
end

function hotbar_sets:show()
  ext_hidden = false
  self:refresh_visibility()
end

function hotbar_sets:hide()
  ext_hidden = true
  self:refresh_visibility()
end

function hotbar_sets:destroy()
  if panel_bg then pcall(panel_bg.destroy, panel_bg); panel_bg = nil end
  if divider then pcall(divider.destroy, divider); divider = nil end
  for i = 1, NODE_COUNT do
    if dots[i] then pcall(dots[i].hide, dots[i]); dots[i] = nil end
    if rings[i] then pcall(rings[i].destroy, rings[i]); rings[i] = nil end
  end
  if title_text then pcall(title_text.hide, title_text); title_text = nil end
end

function hotbar_sets:get_pos()
  return base_x, base_y
end

function hotbar_sets:move_to(x, y)
  base_x = math.floor(x)
  base_y = math.floor(y)
  self:update_positions()
end

function hotbar_sets:ensure_on_screen()
  local ok, ws = pcall(windower.get_windower_settings)
  if not ok or not ws then return false end
  local sw = ws.ui_x_res or ws.x_res
  local sh = ws.ui_y_res or ws.y_res
  if not sw or not sh then return false end
  local _, _, w, h = self:grid_bounds()
  if base_x < 0 or base_y < 0 or base_x + w > sw or base_y + h > sh then
    base_x = math.max(0, math.floor((sw - w) / 2))
    base_y = math.max(0, math.floor((sh - h) / 2))
    self:update_positions()
    return true
  end
  return false
end

function hotbar_sets:hit_test(x, y)
  local ds = dot_size()
  for i = 1, NODE_COUNT do
    local nx, ny = node_xy(i)
    if x >= nx and x <= nx + ds and y >= ny and y <= ny + ds then
      return i
    end
  end
  return nil
end

function hotbar_sets:point_in_grid(x, y)
  local bx, by, w, h = self:grid_bounds()
  return x >= bx and x <= bx + w and y >= by and y <= by + h
end

return hotbar_sets
