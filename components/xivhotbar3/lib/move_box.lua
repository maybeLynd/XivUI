icon_lib = require('components/xivhotbar3/lib/icon')

local move_boxes = {}
move_boxes.theme = {}
move_boxes.current_environment = 'battle'

local function effective_visible_count()
    local t = move_boxes.theme
    if move_boxes.current_environment == 'field' and t.field_visible_hotbar_count then
        return t.field_visible_hotbar_count
    end
    return t.visible_hotbar_count or t.rows
end

local box_config = {
  count = 0,
  rows = {},
  icons = {},
  sub_config = {}
}

local icon_height = 40
local scaled_icon_height = 0
local icon_width = 40
local scaled_icon_width = 0
local debug = false

local ROW_OVERLAY_ALPHA = 35
local SLOT_GRID_ALPHA = 95
local SLOT_DRAG_ALPHA = 220
local SLOT_DROP_ALPHA = 255
local CHOICE_INDICATOR_WIDTH = 170
local CHOICE_INDICATOR_HEIGHT = 28
local HANDLE_HIT_W = 13
local HANDLE_HIT_H = 16

local images_setup = {
  draggable = false,
  size = {
    width  = 10,
    height = 100
  },
  pos = {
    x = 100,
    y = 100
  },
  texture = {
    fit = false
  },
  visible = true,
}

local function compute_size(move_box, sub_conf, is_vertical)
  if (is_vertical == true) then
    local vsp = move_boxes.theme.vertical_slot_spacing or move_boxes.theme.slot_spacing
    local t_width   = 2 * (scaled_icon_width + vsp) - vsp
    local t_height  = (scaled_icon_height + vsp) * (move_boxes.theme.columns / 2) - vsp
    sub_conf.width  = t_width
    sub_conf.height = t_height
    move_box:size(t_width, t_height)
  else
    local t_height  = (scaled_icon_height + move_boxes.theme.slot_spacing) - move_boxes.theme.slot_spacing
    local t_width   = (scaled_icon_width + move_boxes.theme.slot_spacing) * move_boxes.theme.columns -
        move_boxes.theme.slot_spacing
    sub_conf.width  = t_width
    sub_conf.height = t_height
    move_box:size(t_width, t_height)
  end
end

local function point_inside_box(x, y, pos_x, pos_y, width, height)
  local off_x = width + pos_x
  local off_y = height + pos_y
  return ((pos_x <= x and x <= off_x) or (pos_x >= x and x >= off_x))
      and ((pos_y <= y and y <= off_y) or (pos_y >= y and y >= off_y))
end

local function reset_transient_flags(info)
  info.swapped_slots.active = false
  info.swapped_slots.source.row = 0
  info.swapped_slots.source.slot = 0
  info.swapped_slots.dest.row = 0
  info.swapped_slots.dest.slot = 0

  info.removed_slot.active = false
  info.removed_slot.source.row = 0
  info.removed_slot.source.slot = 0
  info.source_actual_slot = nil
end

local function get_slot_marker_path(theme)
  if theme ~= nil and theme.frame_theme ~= nil then
    return HTB_ART .. 'themes/' .. (theme.frame_theme:lower()) .. '/frame.png'
  end

  return HTB_ART .. 'other/move.png'
end

local function get_drag_x(x)
  return x - math.floor(scaled_icon_width / 2)
end

local function get_drag_y(y)
  return y - math.floor(scaled_icon_height / 2)
end

local function has_choice_row()
  return move_boxes.theme ~= nil and move_boxes.theme.choice_bar ~= nil
end

local function get_choice_row_index()
  return (move_boxes.theme.rows or 0) + 1
end

local function get_choice_indicator_row_index()
  return (move_boxes.theme.rows or 0) + 2
end

local function get_total_rows()
  if has_choice_row() then return get_choice_indicator_row_index() end
  return move_boxes.theme.rows
end

local function is_choice_row(row_index)
  return has_choice_row() and row_index == get_choice_row_index()
end

local function is_choice_indicator_row(row_index)
  return has_choice_row() and row_index == get_choice_indicator_row_index()
end

local function get_offset_for_row(row_index)
  if is_choice_row(row_index) then
    return { Vertical = false, OffsetX = move_boxes.theme.choice_bar.OffsetX or 675, OffsetY = move_boxes.theme.choice_bar.OffsetY or 740 }
  elseif is_choice_indicator_row(row_index) then
    local cb = move_boxes.theme.choice_bar or {}
    return { Vertical = false, OffsetX = (cb.OffsetX or 675) + (cb.IndicatorOffsetX or 0), OffsetY = (cb.OffsetY or 740) + (cb.IndicatorOffsetY or -52) }
  end
  return move_boxes.theme.offsets[tostring(row_index)]
end

function move_boxes:is_choice_row(row_index)
  return is_choice_row(row_index)
end

function move_boxes:is_choice_indicator_row(row_index)
  return is_choice_indicator_row(row_index)
end

local function get_slot_xy_from_row_pos(row_index, slot_index, row_x, row_y)
  local offset = get_offset_for_row(row_index)

  if offset ~= nil and offset.Vertical == true then
    local vsp = move_boxes.theme.vertical_slot_spacing or move_boxes.theme.slot_spacing
    if (slot_index < math.floor(move_boxes.theme.columns / 2) + 1) then
      return row_x, row_y + ((scaled_icon_height + vsp) * (slot_index - 1))
    else
      return row_x + (scaled_icon_width + vsp),
          row_y + ((scaled_icon_height + vsp) *
              (slot_index - math.floor(move_boxes.theme.columns / 2) - 1))
    end
  end

  return row_x + ((scaled_icon_width + move_boxes.theme.slot_spacing) * (slot_index - 1)), row_y
end

function move_boxes:init_slot(row_index, slot_index)
  local slot     = images.new(table.copy(images_setup, true))
  local offset   = get_offset_for_row(row_index)
  local x, y     = get_slot_xy_from_row_pos(row_index, slot_index, offset.OffsetX, offset.OffsetY)
  local t_width  = icon_lib:get_width()
  local t_height = icon_lib:get_height()

  slot:pos(x, y)
  slot:size(t_width, t_height)

  slot:path(get_slot_marker_path(self.theme))
  slot:hide()
  slot:alpha(SLOT_GRID_ALPHA)
  slot.init_x = x
  slot.init_y = y
  return slot
end

function move_boxes:update_row_slots(row_index, row_x, row_y)
  if is_choice_indicator_row(row_index) then return end
  for s = 1, self.theme.columns do
    local x, y = get_slot_xy_from_row_pos(row_index, s, row_x, row_y)
    box_config.icons[row_index].init_slot[s].x = x
    box_config.icons[row_index].init_slot[s].y = y

    if not (self.moved_box_info.slot_active == true
        and self.moved_box_info.box_index == row_index
        and self.moved_box_info.slot_index == s) then
      box_config.icons[row_index].slot[s]:pos(x, y)
    end
  end
end

function move_boxes:show_slot_grid()
  local visible_count = effective_visible_count()
  for i = 1, get_total_rows() do
    if not is_choice_indicator_row(i) and (i <= visible_count or is_choice_row(i)) then
      for j = 1, self.theme.columns do
        box_config.icons[i].slot[j]:path(get_slot_marker_path(self.theme))
        box_config.icons[i].slot[j]:alpha(SLOT_GRID_ALPHA)
        box_config.icons[i].slot[j]:show()
        box_config.icons[i].slot[j]:pos(box_config.icons[i].init_slot[j].x, box_config.icons[i].init_slot[j].y)
      end
    end
  end
end

function move_boxes:hide_slot_grid()
  for i = 1, get_total_rows() do
    for j = 1, self.theme.columns do
      box_config.icons[i].slot[j]:hide()
      box_config.icons[i].slot[j]:pos(box_config.icons[i].init_slot[j].x, box_config.icons[i].init_slot[j].y)
      box_config.icons[i].slot[j]:alpha(SLOT_GRID_ALPHA)
    end
  end
end

function move_boxes:reset_slot_grid_alpha()
  for i = 1, get_total_rows() do
    for j = 1, self.theme.columns do
      box_config.icons[i].slot[j]:alpha(SLOT_GRID_ALPHA)
    end
  end
end

function move_boxes:update_drop_highlight(x, y)
  self:reset_slot_grid_alpha()

  local found, dest_row, dest_slot = self:check_slot(x, y)
  if found == true and dest_row ~= 0 and dest_slot ~= 0 then
    box_config.icons[dest_row].slot[dest_slot]:alpha(SLOT_DROP_ALPHA)
  end

  local source_row = self.moved_box_info.box_index
  local source_slot = self.moved_box_info.slot_index
  if source_row ~= 0 and source_slot ~= 0 then
    box_config.icons[source_row].slot[source_slot]:alpha(SLOT_DRAG_ALPHA)
  end
end

local function compute_handle_pos(row_index)
  local offset = get_offset_for_row(row_index)
  if not offset then return 0, 0 end
  local sub = box_config.sub_config[row_index]
  if not sub then return 0, 0 end
  return offset.OffsetX + sub.width - 3, offset.OffsetY - 13
end

function move_boxes:update_handle_pos(row, row_x, row_y)
  if not box_config.handles[row] then return end
  local sub = box_config.sub_config[row] or {}
  box_config.handles[row]:pos(row_x + (sub.width or 0) - 3, row_y - 13)
end

function move_boxes:init(theme_options)
  local function teardown(img) if img then pcall(function() img:destroy() end) end end
  if box_config.handles then
    for _, h in pairs(box_config.handles) do teardown(h) end
  end
  if box_config.rows then
    for _, r in pairs(box_config.rows) do teardown(r) end
  end
  if box_config.icons then
    for _, ri in pairs(box_config.icons) do
      if ri and ri.slot then for _, s in pairs(ri.slot) do teardown(s) end end
    end
  end
  box_config.icons = {}
  box_config.rows = {}
  box_config.sub_config = {}
  box_config.handles = {}

  self.theme = theme_options
  icon_lib:init(self.theme)
  box_config.count = get_total_rows()
  scaled_icon_width = math.floor(icon_width * self.theme.slot_icon_scale)
  scaled_icon_height = math.floor(icon_height * self.theme.slot_icon_scale)

  for r = 1, get_total_rows() do
    box_config.rows[r] = images.new(table.copy(images_setup, true))
    local offset = get_offset_for_row(r)
    box_config.sub_config[r] = {}
    if is_choice_indicator_row(r) then
      box_config.sub_config[r].width = CHOICE_INDICATOR_WIDTH
      box_config.sub_config[r].height = CHOICE_INDICATOR_HEIGHT
      box_config.rows[r]:size(CHOICE_INDICATOR_WIDTH, CHOICE_INDICATOR_HEIGHT)
    else
      compute_size(box_config.rows[r], box_config.sub_config[r], offset.Vertical)
    end
    box_config.rows[r]:pos(offset.OffsetX, offset.OffsetY)

    local x, y = box_config.rows[r]:pos()
    box_config.sub_config[r].pos_x = x
    box_config.sub_config[r].pos_y = y
    box_config.rows[r]:path(HTB_ART .. 'other/black-square.png')
    box_config.rows[r]:alpha(ROW_OVERLAY_ALPHA)
    box_config.rows[r]:hide()

    if not is_choice_indicator_row(r) then
      local hx, hy = compute_handle_pos(r)
      local h = images.new(table.copy(images_setup, true))
      h:path(HTB_ART .. 'other/drag_handle.png')
      h:alpha(200)
      h:size(HANDLE_HIT_W, HANDLE_HIT_H)
      h:pos(hx, hy)
      h:hide()
      box_config.handles[r] = h
    end

    box_config.icons[r] = {}
    box_config.icons[r].slot = {}
    box_config.icons[r].init_slot = {}

    for s = 1, self.theme.columns do
      box_config.icons[r].slot[s] = self:init_slot(r, s)
      box_config.icons[r].init_slot[s] = {}
      box_config.icons[r].init_slot[s].x, box_config.icons[r].init_slot[s].y = box_config.icons[r].slot[s]:pos()
    end
  end
end

function move_boxes:enable()
  reset_transient_flags(self.moved_box_info)
  self.moved_box_info.box_index = 0
  self.moved_box_info.slot_index = 0
  self.moved_box_info.row_active = false
  self.moved_box_info.slot_active = false

  local visible_count = effective_visible_count()
  for i = 1, get_total_rows() do
    if i <= visible_count or is_choice_row(i) or is_choice_indicator_row(i) then
      local x, y = box_config.rows[i]:pos()
      self:update_row_slots(i, x, y)
      if box_config.handles[i] then
        self:update_handle_pos(i, x, y)
        box_config.handles[i]:show()
      elseif is_choice_indicator_row(i) then
        box_config.rows[i]:alpha(ROW_OVERLAY_ALPHA)
        box_config.rows[i]:show()
      end
    end
  end

  self:show_slot_grid()
end

function move_boxes:disable()
  reset_transient_flags(self.moved_box_info)
  self.moved_box_info.box_index = 0
  self.moved_box_info.slot_index = 0
  self.moved_box_info.row_active = false
  self.moved_box_info.slot_active = false

  for i = 1, get_total_rows() do
    box_config.rows[i]:hide()
    if box_config.handles[i] then box_config.handles[i]:hide() end
  end

  self:hide_slot_grid()
end

function move_boxes:rescale(theme_options)
  self.theme = theme_options
  scaled_icon_width = math.floor(icon_width * self.theme.slot_icon_scale)
  scaled_icon_height = math.floor(icon_height * self.theme.slot_icon_scale)

  for r = 1, get_total_rows() do
    if not is_choice_indicator_row(r) then
      local row_x, row_y = box_config.rows[r]:pos()
      local offset = get_offset_for_row(r)
      if offset then
        compute_size(box_config.rows[r], box_config.sub_config[r], offset.Vertical)
        self:update_row_slots(r, row_x, row_y)
        self:update_handle_pos(r, row_x, row_y)
        for s = 1, self.theme.columns do
          box_config.icons[r].slot[s]:size(scaled_icon_width, scaled_icon_height)
        end
      end
    end
  end
end

function move_boxes:set_indicator_size(w, h)
  local indicator_row = get_choice_indicator_row_index()
  if box_config.rows[indicator_row] == nil then return end
  local iw = w or CHOICE_INDICATOR_WIDTH
  local ih = h or CHOICE_INDICATOR_HEIGHT
  box_config.sub_config[indicator_row].width = iw
  box_config.sub_config[indicator_row].height = ih
  box_config.rows[indicator_row]:size(iw, ih)
end

move_boxes.moved_box_info = {
  pos_x = 0,
  pos_y = 0,
  drag_offset_x = 0,
  drag_offset_y = 0,
  box_index = 0,
  slot_index = 0,
  row_active = false,
  slot_active = false,
  swapped_slots = {
    active = false,
    source = { row = 0, slot = 0 },
    dest = { row = 0, slot = 0 },
  },
  removed_slot = {
    active = false,
    source = { row = 0, slot = 0 }
  },
  source_actual_slot = nil
}

function move_boxes:get_pos(row)
  return box_config.rows[row]:pos()
end

function move_boxes:get_move_box_info()
  return self.moved_box_info
end

function move_boxes:determine_box(x, y)
  for i = 1, get_total_rows(), 1 do
    if box_config.handles[i] and (i <= effective_visible_count() or is_choice_row(i)) then
      local hx, hy = box_config.handles[i]:pos()
      if point_inside_box(x, y, hx, hy, HANDLE_HIT_W, HANDLE_HIT_H) then
        return i, nil
      end
    end
  end

  for i = 1, get_total_rows(), 1 do
    if not is_choice_indicator_row(i) and (i <= effective_visible_count() or is_choice_row(i)) then
      for j = 1, self.theme.columns, 1 do
        local pos_x = box_config.icons[i].init_slot[j].x
        local pos_y = box_config.icons[i].init_slot[j].y
        local width, height = box_config.icons[i].slot[j]:size()

        if point_inside_box(x, y, pos_x, pos_y, width, height) then
          if is_choice_row(i) then
            return i, nil
          end
          return i, j
        end
      end
    end
  end

  for i = 1, get_total_rows(), 1 do
    if is_choice_indicator_row(i) then
      local pos_x, pos_y = box_config.rows[i]:pos()
      local width, height = box_config.rows[i]:size()
      if point_inside_box(x, y, pos_x, pos_y, width, height) then
        return i, nil
      end
    end
  end

  return nil, nil
end

function move_boxes:check_slot(x, y)
  local found = false
  local dest_row = 0
  local dest_col = 0

  for i = 1, self.theme.rows, 1 do
    if i <= effective_visible_count() then
      for j = 1, self.theme.columns, 1 do
        local pos_x = box_config.icons[i].init_slot[j].x
        local pos_y = box_config.icons[i].init_slot[j].y
        local width, height = box_config.icons[i].slot[j]:size()

        if point_inside_box(x, y, pos_x, pos_y, width, height) then
          dest_row = i
          dest_col = j
          found = true
          break
        end
      end
    end

    if found == true then
      break
    end
  end

  return found, dest_row, dest_col
end

function move_boxes:get_row_bounds(row)
  local r = box_config.rows[row]
  if not r then return nil end
  local x, y = r:pos()
  local w, h = r:size()
  return x, y - 14, w + HANDLE_HIT_W + 4, h + 14
end

function move_boxes:move_hotbars(type, x, y, delta, blocked)
  local offset = 1
  local return_value = false

  if type == 1 then
    reset_transient_flags(self.moved_box_info)

    local row_clicked, slot_clicked = self:determine_box(x, y)

    if (slot_clicked ~= nil) then
      self.moved_box_info.box_index = row_clicked
      self.moved_box_info.slot_index = slot_clicked

      local pos_x, pos_y = box_config.rows[self.moved_box_info.box_index]:pos()
      self.moved_box_info.pos_y = pos_y
      self.moved_box_info.pos_x = pos_x
      self.moved_box_info.row_active = false
      self.moved_box_info.slot_active = true

      box_config.icons[row_clicked].slot[slot_clicked]:show()
      box_config.icons[row_clicked].slot[slot_clicked]:alpha(SLOT_DRAG_ALPHA)
      box_config.icons[row_clicked].slot[slot_clicked]:pos(get_drag_x(x), get_drag_y(y))
      self:update_drop_highlight(x, y)
      return_value = true
    elseif (row_clicked ~= nil) then
      self.moved_box_info.box_index = row_clicked
      local pos_x, pos_y = box_config.rows[self.moved_box_info.box_index]:pos()
      self.moved_box_info.pos_y = pos_y
      self.moved_box_info.pos_x = pos_x
      self.moved_box_info.drag_offset_x = x - pos_x
      self.moved_box_info.drag_offset_y = y - pos_y
      self.moved_box_info.row_active = true
      self.moved_box_info.slot_active = false
      return_value = true
    end
  elseif type == 2 then
    if (self.moved_box_info.slot_active == true) then
      local row = self.moved_box_info.box_index
      local col = self.moved_box_info.slot_index

      if row ~= 0 and col ~= 0 then
        local init_x = box_config.icons[row].init_slot[col].x
        local init_y = box_config.icons[row].init_slot[col].y
        box_config.icons[row].slot[col]:pos(init_x, init_y)
        box_config.icons[row].slot[col]:alpha(SLOT_GRID_ALPHA)
        box_config.icons[row].slot[col]:show()

        local found, dest_row, dest_slot = self:check_slot(x, y)

        if (found == true) then
          self.moved_box_info.swapped_slots.source.row = row
          self.moved_box_info.swapped_slots.source.slot = col
          self.moved_box_info.swapped_slots.dest.row = dest_row
          self.moved_box_info.swapped_slots.dest.slot = dest_slot
          self.moved_box_info.swapped_slots.active = true
        else
          self.moved_box_info.removed_slot.source.row = row
          self.moved_box_info.removed_slot.source.slot = col
          self.moved_box_info.removed_slot.active = true
        end
      end

      self.moved_box_info.slot_index = 0
      self.moved_box_info.box_index = 0
      self.moved_box_info.slot_active = false
      self.moved_box_info.row_active = false
      self:reset_slot_grid_alpha()
      return_value = true
    elseif (self.moved_box_info.row_active == true) then
      self.moved_box_info.box_index = 0
      self.moved_box_info.row_active = false
      self:reset_slot_grid_alpha()
      return_value = true
    end
  elseif type == 0 then
    if (self.moved_box_info.slot_active == true) then
      local row = self.moved_box_info.box_index
      local col = self.moved_box_info.slot_index

      if row ~= 0 and col ~= 0 then
        box_config.icons[row].slot[col]:pos_x(get_drag_x(x))
        box_config.icons[row].slot[col]:pos_y(get_drag_y(y))
        self:update_drop_highlight(x, y)
      end
    elseif (self.moved_box_info.row_active == true) then
      local row = self.moved_box_info.box_index
      local new_x = math.floor((x - self.moved_box_info.drag_offset_x) / offset) * offset
      local new_y = math.floor((y - self.moved_box_info.drag_offset_y) / offset) * offset

      box_config.rows[row]:pos_x(new_x)
      box_config.rows[row]:pos_y(new_y)
      if is_choice_row(row) then
        self.theme.choice_bar.OffsetX = new_x
        self.theme.choice_bar.OffsetY = new_y
      elseif is_choice_indicator_row(row) then
        local cb = self.theme.choice_bar or {}
        cb.IndicatorOffsetX = new_x - (cb.OffsetX or 0)
        cb.IndicatorOffsetY = new_y - (cb.OffsetY or 0)
        self.theme.choice_bar = cb
      end
      self:update_row_slots(row, new_x, new_y)
      self:update_handle_pos(row, new_x, new_y)
      self.moved_box_info.pos_y = new_y
      self.moved_box_info.pos_x = new_x
    end
  end

  return return_value
end

return move_boxes
