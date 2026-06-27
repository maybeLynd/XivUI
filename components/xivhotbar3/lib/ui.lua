local database = require('components/xivhotbar3/priv_res/database')
local formatter = require('components/xivhotbar3/lib/text_formatter')
local keyboard = require('components/xivhotbar3/lib/keyboard_mapper')
local hotbar_tools = require('components/xivhotbar3/lib/hotbar_tools')
local choice_groups = require('components/xivhotbar3/lib/choice_groups')

local ACTION_ICONS = require('components/xivhotbar3/lib/icon_registry')
local action_tooltip = require('lib/action_tooltip')
local recast_cache = require('components/xivhotbar3/lib/recast_cache')

local ACTION_TYPE_FOLDER = { ['ma'] = 'spells', ['ja'] = 'abilities', ['ws'] = 'weaponskills' }

local count_color = { 255, 255, 255 }

local lower_cache = {}
local function lc(s)
  if s == nil then return nil end
  local v = lower_cache[s]
  if v == nil then v = tostring(s):lower(); lower_cache[s] = v end
  return v
end

local hotbar_key_cache, slot_key_cache = {}, {}
local function hb_key(n)
  local k = hotbar_key_cache[n]
  if not k then k = 'hotbar_' .. n; hotbar_key_cache[n] = k end
  return k
end
local function slot_key(n)
  local k = slot_key_cache[n]
  if not k then k = 'slot_' .. n; slot_key_cache[n] = k end
  return k
end

local CHAIN_PROP_OUTLINE = {
  ['Transfixion']     = 'transfixion',
  ['Compression']     = 'compression',
  ['Liquefaction']    = 'liquefaction',
  ['Scission']        = 'scission',
  ['Reverberation']   = 'reverberation',
  ['Detonation']      = 'detonation',
  ['Induration']      = 'induration',
  ['Impaction']       = 'impaction',
  ['Gravitation']     = 'gravitation',
  ['Distortion']      = 'distortion',
  ['Fusion']          = 'fusion',
  ['Fragmentation']   = 'fragmentation',
  ['Light']           = 'light',
  ['Double Light']    = 'light',
  ['Darkness']        = 'darkness',
  ['Double Darkness'] = 'darkness',
}

local ELEMENT_OUTLINE = {
  [6] = 'transfixion',
  [7] = 'compression',
  [0] = 'liquefaction',
  [3] = 'scission',
  [5] = 'reverberation',
  [2] = 'detonation',
  [1] = 'induration',
  [4] = 'impaction',
}

local ui = {}

local slot_xy_cache = {}

local RECAST_ACTION_TYPES = S { 'ma', 'ja', 'ws', 'pet' }
local RUNE_BUFF_IDS = {[523]=true,[524]=true,[525]=true,[526]=true,[527]=true,[528]=true,[529]=true,[530]=true}
local RUN_RUNE_REQ = { run_effusions = true, run_wards = true }
local DNC_FL_FM_MIN = { dnc_flourishes = 1, dnc_flourishes_1 = 1, dnc_flourishes_2 = 1, dnc_flourishes_3 = 1 }

local buffs = {}

local text_setup = {
  flags = {
    draggable = false
  }
}

ui.hover_icon = {
  row = nil,
  col = nil,
  prev_row = nil,
  prev_col = nil
}

local environment_text_setup = {
  flags = {
    draggable = false,
  }
}

local category_arrow_text_setup = {
  flags = {
    draggable = false,
    bold = true,
  }
}

local inventory_count_setup = {
  flags = {
    draggable = false
  }
}
local sack_count_setup = {
  flags = {
    draggable = false
  }
}

local right_text_setup = {
  flags = {
    right = true,
    draggable = false
  }
}

local playerinv = {}
local is_silenced = false
local is_amnesiad = false
local is_neutralized = false
local is_burst_affinity = false
local is_chain_affinity = false
local is_immanence = false
local can_ws = false
local can_pet_ws = false
local current_mp = 0
local current_pet_mp = 0
local current_tp = 0
local current_pet_tp_value = 0
local bst_charge_time = 30

local nin_tool_requirements = {
  ['monomi: ichi']='Sanjaku-Tenugui', ['aisha: ichi']='Soshi',
  ['katon: ichi']='Uchitake',   ['katon: ni']='Uchitake',   ['katon: san']='Uchitake',
  ['hyoton: ichi']='Tsurara',   ['hyoton: ni']='Tsurara',   ['hyoton: san']='Tsurara',
  ['huton: ichi']='Kawahori-Ogi', ['huton: ni']='Kawahori-Ogi', ['huton: san']='Kawahori-Ogi',
  ['doton: ichi']='Makibishi',  ['doton: ni']='Makibishi',  ['doton: san']='Makibishi',
  ['raiton: ichi']='Hiraishin', ['raiton: ni']='Hiraishin', ['raiton: san']='Hiraishin',
  ['suiton: ichi']='Mizu-Deppo', ['suiton: ni']='Mizu-Deppo', ['suiton: san']='Mizu-Deppo',
  ['utsusemi: ichi']='Shihei',  ['utsusemi: ni']='Shihei',  ['utsusemi: san']='Shihei',
  ['jubaku: ichi']='Jusatsu',   ['jubaku: ni']='Jusatsu',   ['jubaku: san']='Jusatsu',
  ['hojo: ichi']='Kaginawa',    ['hojo: ni']='Kaginawa',    ['hojo: san']='Kaginawa',
  ['kurayami: ichi']='Sairui-Ran', ['kurayami: ni']='Sairui-Ran', ['kurayami: san']='Sairui-Ran',
  ['dokumori: ichi']='Kodoku',  ['dokumori: ni']='Kodoku',  ['dokumori: san']='Kodoku',
  ['tonko: ichi']='Shinobi-Tabi', ['tonko: ni']='Shinobi-Tabi',
  ['gekka: ichi']='Ranka',      ['yain: ichi']='Furusumi',
  ['myoshu: ichi']='Kabenro',   ['yurin: ichi']='Jinko',
  ['kakka: ichi']='Ryuno',      ['migawari: ichi']='Mokujin',
}

local cor_card_display = {
  [125]='Fire Card', [126]='Ice Card', [127]='Wind Card', [128]='Earth Card',
  [129]='Thunder Card', [130]='Water Card', [131]='Light Card', [132]='Dark Card',
}

local ja_ammo_slot_display_ids = {
  [26]=true,
  [57]=true,
  [124]=true,
  [150]=true,
  [171]=true,
  [257]=true,
  [301]=true,
}

local pup_oil_ability_ids = { [137]=true, [322]=true }
local automaton_oil_ids = { [18731]=true, [18732]=true, [18733]=true, [19185]=true }

ui.hotbar_width = 0
ui.hotbar = {
  initialized = false,
  ready = false,
  hide_hotbars = false,
  in_battle = false
}
ui.hotbar_spacing = 0
ui.slot_spacing = 0
ui.vertical_slot_spacing = 0
ui.pos_x = 0
ui.pos_y = 0
ui.current_row = 0
ui.current_column = 0
ui.current_text_size = 0

ui.image_height = 40
ui.image_width = 40
ui.overlay_image_height = 24
ui.overlay_image_width = 24
ui.player = {}
ui.recasts = {}
ui.slot_max_recasts = {}
ui.sweep_active = {}

local outline_images_setup = {
  draggable = false,
  size = {
    width  = ui.image_width + 6,
    height = ui.image_height + 6
  },
  texture = {
    fit = false
  },
  visible = false
}

local images_setup = {
  draggable = false,
  size = {
    width  = ui.image_width,
    height = ui.image_height
  },
  texture = {
    fit = false
  },
  visible = false
}

local overlay_images_setup = {
  draggable = false,
  size = {
    overlay_width  = ui.overlay_image_width,
    overlay_height = ui.overlay_image_height
  },
  texture = {
    fit = true
  },
  visible = false
}

ui.feedback_icon = nil
ui.hotbars = {}

ui.theme = {}

ui.feedback = {}
ui.feedback.is_active = false
ui.feedback.current_opacity = 0
ui.feedback.max_opacity = 0
ui.feedback.speed = 0

ui.disabled_slots = {}
ui.disabled_slots.actions = {}
ui.disabled_slots.no_vitals = {}
ui.disabled_slots.on_cooldown = {}

ui.outlined_slots = {}

ui.is_setup = false
ui.disabled_icons = {}
ui.current_tick = 0

ui.current_target = nil

ui.slot_resolved_keys = {}

ui.default_image_paths = {
  ['default'] = HTB_ART .. 'icons/custom/gear3.png',
  ['macro'] = HTB_ART .. 'icons/custom/macro.png',
  ['gs'] = HTB_ART .. 'icons/custom/gearswap.png',
  ['item'] = HTB_ART .. 'icons/custom/item.png',
  ['choice'] = HTB_ART .. 'icons/custom/macro.png',
}

ui.choice_bar = {
  active = false,
  row = 0,
  source_hotbar = 0,
  group_id = '',
  label = '',
  actions = {},
  page_actions = {},
  page = 1,
  page_size = 10,
}

ui.choice_modifier_indicator = nil
ui.category_page_arrows = {}
ui.category_page_arrow_last_change = {}

local function update_buffs(id, data)
  if id == 0x063 then
    if data:byte(0x05) == 0x09 then
      local silenced = false
      local amnesiad = false
      local neutralized = false
      local burst_affinity = false
      local chain_affinity = false
      local immanence = false
      for i = 1, 32 do
        local buff_id = data:unpack('H', i * 2 + 7)
        if (buff_id == 2 or buff_id == 10 or buff_id == 19 or buff_id == 28 or buff_id == 193 or buff_id == 14 or buff_id == 17) then neutralized = true end
        if (neutralized) then break end
        if (buff_id == 6) then
          silenced = true
        end
        if (buff_id == 164) then chain_affinity = true end
        if (buff_id == 165) then burst_affinity = true end
        if (buff_id == 470) then immanence = true end
        if (buff_id == 16) then amnesiad = true end
        if (silenced and amnesiad) then break end
      end
      is_neutralized = neutralized
      is_silenced = silenced
      is_amnesiad = amnesiad
      is_burst_affinity = burst_affinity
      is_chain_affinity = chain_affinity
      is_immanence = immanence
    end
  end
end

function ui:bar_scale(h)
  if self.choice_bar and self.choice_bar.row and h == self.choice_bar.row then
    local cs = tonumber((self.theme.choice_bar or {}).Scale) or 1
    return (cs and cs > 0) and cs or 1
  end
  local off = self.theme and self.theme.offsets and self.theme.offsets[tostring(h)]
  local s = off and tonumber(off.Scale) or 1
  if not s or s <= 0 then s = 1 end
  return s
end
function ui:bar_image_width(h)  return math.floor(self.image_width  * self:bar_scale(h)) end
function ui:bar_image_height(h) return math.floor(self.image_height * self:bar_scale(h)) end

function ui:choice_base()
  local cb = self.theme.choice_bar or {}
  if self.loaded_environment == 'field' then
    return (cb.FieldOffsetX or cb.OffsetX or 675), (cb.FieldOffsetY or cb.OffsetY or 740)
  end
  return (cb.OffsetX or 675), (cb.OffsetY or 740)
end

function ui:get_slot_xy(h, i)
  local rx = self.reposition_offset_x or 0
  local ry = self.reposition_offset_y or 0

  if self.choice_bar ~= nil and h == self.choice_bar.row then
    local cbx, cby = self:choice_base()
    local biw = self:bar_image_width(h)
    local x = self.pos_x + cbx + ((biw + self.slot_spacing) * (i - 1))
    return x + rx, cby + ry
  end

  local cache_key = h * 100 + i
  local custom_off = self.slot_custom_offsets and self.slot_custom_offsets[h] and self.slot_custom_offsets[h][i]

  if not custom_off then
    local cached = slot_xy_cache[cache_key]
    if cached then return cached[1], cached[2] end
  end

  local x, y
  local biw = self:bar_image_width(h)
  if (self.theme.offsets[tostring(h)] ~= nil) then
    if (self.theme.offsets[tostring(h)].Vertical == true) then
      local vsp = self.vertical_slot_spacing
      if (i < math.floor(self.theme.columns / 2) + 1) then
        x = self.theme.offsets[tostring(h)].OffsetX
        y = self.theme.offsets[tostring(h)].OffsetY + ((biw + vsp) * (i - 1))
      else
        x = self.theme.offsets[tostring(h)].OffsetX + (biw + vsp)
        y = self.theme.offsets[tostring(h)].OffsetY +
            ((biw + vsp) * (i - math.floor(self.theme.columns / 2) - 1))
      end
    else
      x = self.pos_x + self.theme.offsets[tostring(h)].OffsetX + ((biw + self.slot_spacing) * (i - 1))
      y = self.theme.offsets[tostring(h)].OffsetY
    end
  else
    x = self.pos_x + ((biw + self.slot_spacing) * (i - 1))
    y = self.pos_y - (((h - 1) * (self.hotbar_spacing - 3)))
  end

  if custom_off then
    return x + (custom_off.dx or 0) + rx, y + (custom_off.dy or 0) + ry
  end
  slot_xy_cache[cache_key] = { x + rx, y + ry }
  return x + rx, y + ry
end

function ui:set_slot_custom_offset(row, slot, dx, dy)
  if not self.slot_custom_offsets then self.slot_custom_offsets = {} end
  if not self.slot_custom_offsets[row] then self.slot_custom_offsets[row] = {} end
  dx, dy = math.floor(dx or 0), math.floor(dy or 0)
  local cur = self.slot_custom_offsets[row][slot]
  local sc = cur and cur.scale
  if dx == 0 and dy == 0 and (not sc or sc == 1) then
    self.slot_custom_offsets[row][slot] = nil
  else
    self.slot_custom_offsets[row][slot] = { dx = dx, dy = dy, scale = (sc and sc ~= 1) and sc or nil }
  end
  slot_xy_cache[row * 100 + slot] = nil
end

function ui:set_slot_scale(row, slot, scale)
  scale = tonumber(scale) or 1
  if scale <= 0 then scale = 1 end
  if not self.slot_custom_offsets then self.slot_custom_offsets = {} end
  if not self.slot_custom_offsets[row] then self.slot_custom_offsets[row] = {} end
  local cur = self.slot_custom_offsets[row][slot]
  local dx = (cur and cur.dx) or 0
  local dy = (cur and cur.dy) or 0
  if dx == 0 and dy == 0 and scale == 1 then
    self.slot_custom_offsets[row][slot] = nil
  else
    self.slot_custom_offsets[row][slot] = { dx = dx, dy = dy, scale = (scale ~= 1) and scale or nil }
  end
end

function ui:slot_scale(row, slot)
  local o = self.slot_custom_offsets and self.slot_custom_offsets[row] and self.slot_custom_offsets[row][slot]
  return (o and tonumber(o.scale)) or 1
end

function ui:get_slot_custom_offset(row, slot)
  return self.slot_custom_offsets and self.slot_custom_offsets[row] and self.slot_custom_offsets[row][slot]
end

function ui:clear_slot_custom_offsets_for_row(row)
  if not self.slot_custom_offsets then return end
  self.slot_custom_offsets[row] = nil
  local cols = self.theme and self.theme.columns or 12
  for i = 1, cols do slot_xy_cache[row * 100 + i] = nil end
end

function ui:load_slot_custom_offsets(offsets_table)
  self.slot_custom_offsets = {}
  if not offsets_table then return end
  for row, slots in pairs(offsets_table) do
    row = tonumber(row)
    if row and type(slots) == 'table' then
      self.slot_custom_offsets[row] = {}
      for slot, off in pairs(slots) do
        slot = tonumber(slot)
        if slot and type(off) == 'table' then
          local dx, dy = math.floor(tonumber(off.dx) or 0), math.floor(tonumber(off.dy) or 0)
          local sc = tonumber(off.scale)
          if dx ~= 0 or dy ~= 0 or (sc and sc ~= 1) then
            self.slot_custom_offsets[row][slot] = { dx = dx, dy = dy, scale = (sc and sc ~= 1) and sc or nil }
          end
          slot_xy_cache[row * 100 + slot] = nil
        end
      end
    end
  end
end

function ui:reposition_slot(h, i)
  if not self.hotbars or not self.hotbars[h] then return end
  local t = self.theme
  local x, y = self:get_slot_xy(h, i)
  local hb = self.hotbars[h]
  if hb.slot_icons[i] then hb.slot_icons[i]:pos(x, y) end
  if hb.slot_frames[i] then hb.slot_frames[i]:pos(x, y) end
  if hb.slot_recasts[i] then hb.slot_recasts[i]:pos(x, y) end
  if hb.slot_backgrounds[i] then hb.slot_backgrounds[i]:pos(x, y) end
  if hb.slot_texts[i] then hb.slot_texts[i]:pos(x + (t.font_offset_x_names * t.slot_icon_scale), y + (t.font_offset_y_names * t.slot_icon_scale)) end
  if hb.slot_recast_texts[i] then hb.slot_recast_texts[i]:pos(x + (t.text_offset_x_recasts * t.slot_icon_scale), y + (t.text_offset_y_recasts * t.slot_icon_scale)) end
  if hb.slot_keys[i] then hb.slot_keys[i]:pos(x + (t.text_offset_x_keys * t.slot_icon_scale), y + (t.text_offset_y_keys * t.slot_icon_scale)) end
  if hb.slot_cost[i] then hb.slot_cost[i]:pos(x + (t.text_offset_x_costs * t.slot_icon_scale), y + (t.text_offset_y_costs * t.slot_icon_scale)) end
  if not t.disable_scroll and hb.slot_overlay[i] then hb.slot_overlay[i]:pos(x + (17 * t.slot_icon_scale), y - (2 * t.slot_icon_scale)) end
  if hb.slot_outline[i] then hb.slot_outline[i]:pos(x - 3, y - 3) end
end

function ui:resize_slot(h, i)
  if not (self.hotbars and self.hotbars[h]) then return end
  local t  = self.theme
  local hb = self.hotbars[h]
  local bs = self:bar_scale(h) * self:slot_scale(h, i)
  local biw, bih = math.floor(self.image_width * bs), math.floor(self.image_height * bs)
  local bow, boh = math.floor(self.overlay_image_width * bs), math.floor(self.overlay_image_height * bs)
  local fs = (t.slot_icon_scale or 1) * bs
  if hb.slot_backgrounds[i] then hb.slot_backgrounds[i]:size(biw, bih) end
  if hb.slot_icons[i] then hb.slot_icons[i]:size(biw, bih) end
  if hb.slot_frames[i] then hb.slot_frames[i]:size(biw, bih) end
  if hb.slot_recasts[i] then hb.slot_recasts[i]:size(biw, bih) end
  if not t.disable_scroll and hb.slot_overlay[i] then hb.slot_overlay[i]:size(bow, boh) end
  if hb.slot_outline[i] then hb.slot_outline[i]:size(biw + 6, bih + 6) end
  if hb.slot_texts[i] then hb.slot_texts[i]:size(t.font_size_names * fs) end
  if hb.slot_keys[i] then hb.slot_keys[i]:size(t.font_size_keys * fs) end
  if hb.slot_cost[i] then hb.slot_cost[i]:size(t.font_size_costs * fs) end
  if hb.slot_recast_texts[i] then hb.slot_recast_texts[i]:size(t.font_size_recasts * fs) end
  self:reposition_slot(h, i)
end

function ui:apply_slot_scales()
  if not (self.hotbars and self.slot_custom_offsets) then return end
  local cols = (self.theme and self.theme.columns) or 12
  for h = 1, #self.hotbars do
    if self.hotbars[h] then
      for i = 1, cols do
        if self:slot_scale(h, i) ~= 1 then self:resize_slot(h, i) end
      end
    end
  end
end

function ui:get_slot_x(h, i)
  local x, _ = self:get_slot_xy(h, i)
  return x
end

function ui:get_slot_y(h, i)
  local _, y = self:get_slot_xy(h, i)
  return y
end

function ui:toggle_slot_opacity(hotbar, slot, is_enabled)
  if is_enabled == false then
    opacity = self.theme.disabled_slot_opacity
  elseif is_enabled == true then
    opacity = 255
  end

  self.hotbars[hotbar].slot_cost[slot]:alpha(opacity)
  local sweep_row = self.sweep_active and self.sweep_active[hotbar]
  if sweep_row and sweep_row[slot] then
    self.hotbars[hotbar].slot_icons[slot]:alpha(255)
  else
    self.hotbars[hotbar].slot_icons[slot]:alpha(opacity)
  end
end

function ui:disable_slot(hotbar_index, index, action)
  if self.disabled_slots.actions[action.action] ~= nil then
    if self.disabled_slots.actions[action.action] == true then
      self:toggle_slot_opacity(hotbar_index, index, false)
    end
  end
  if self.disabled_slots.on_cooldown[action.action] ~= nil then
    if self.disabled_slots.on_cooldown[action.action] == true then
      self:toggle_slot_opacity(hotbar_index, index, false)
    end
  end
  if self.disabled_slots.no_vitals[action.action] ~= nil then
    if self.disabled_slots.no_vitals[action.action] == true then
      self:toggle_slot_opacity(hotbar_index, index, false)
    end
  end
end

function ui:enable_slot(hotbar_index, index, action)
  if self.disabled_slots.actions[action.action] ~= nil then
    if self.disabled_slots.actions[action.action] == false then
      self:toggle_slot_opacity(hotbar_index, index, true)
    end
  end
  if self.disabled_slots.on_cooldown[action.action] ~= nil then
    if self.disabled_slots.on_cooldown[action.action] == false then
      self:toggle_slot_opacity(hotbar_index, index, true)
    end
  end
  if self.disabled_slots.no_vitals[action.action] ~= nil then
    if self.disabled_slots.no_vitals[action.action] == false then
      self:toggle_slot_opacity(hotbar_index, index, true)
    end
  end
end

function ui:outline_path(hotbar_index, index, type)
  if type then
    self.hotbars[hotbar_index].slot_outline[index]:path(HTB_ART ..
      'themes/' .. (self.theme.frame_theme:lower()) .. '/outline_' .. type .. '.png')
  else
    self.hotbars[hotbar_index].slot_outline[index]:path(HTB_ART ..
      'themes/' .. (self.theme.frame_theme:lower()) .. '/outline.png')
  end
  self.hotbars[hotbar_index].slot_outline[index]:size(self:bar_image_width(hotbar_index) + 6, self:bar_image_height(hotbar_index) + 6)
  self.hotbars[hotbar_index].slot_outline[index]:fit(false)

  if self.theme.use_animated_highlights then
    local cycle = self.current_tick % 4
    if cycle == 0 then
      self.hotbars[hotbar_index].slot_outline[index]:repeat_xy(1, 1)
    elseif cycle == 1 then
      self.hotbars[hotbar_index].slot_outline[index]:repeat_xy(-1, 1)
    elseif cycle == 2 then
      self.hotbars[hotbar_index].slot_outline[index]:repeat_xy(-1, -1)
    else
      self.hotbars[hotbar_index].slot_outline[index]:repeat_xy(1, -1)
    end
  end
end

function ui:enable_outline(hotbar_index, index, action)
  if self.outlined_slots[action.action] ~= nil then
    if self.outlined_slots[action.action] == true then
      self.hotbars[hotbar_index].slot_outline[index]:show()
    end
  end
end

function ui:disable_outline(hotbar_index, index, action)
  if self.theme.highlight_magic_burst or self.theme.highlight_skill_chain then
    if self.outlined_slots[action.action] ~= nil then
      if self.outlined_slots[action.action] == false then
        self.hotbars[hotbar_index].slot_outline[index]:hide()
      end
    end
  end
end

function ui:setup(theme_options)
  database:import()
  self.slot_custom_offsets    = {}
  self.theme                  = theme_options
  self.theme.hide_action_cost = theme_options.hide_action_cost
  self.orig_image_width    = self.orig_image_width    or self.image_width
  self.orig_image_height   = self.orig_image_height   or self.image_height
  self.orig_overlay_width  = self.orig_overlay_width  or self.overlay_image_width
  self.orig_overlay_height = self.orig_overlay_height or self.overlay_image_height
  self.base_image_size        = self.orig_image_width
  self.base_overlay_size      = self.orig_overlay_width
  self.image_width            = math.floor(self.orig_image_width * self.theme.slot_icon_scale)
  self.image_height           = math.floor(self.orig_image_height * self.theme.slot_icon_scale)
  self.overlay_image_width    = math.floor(self.orig_overlay_width * self.theme.slot_icon_scale)
  self.overlay_image_height   = math.floor(self.orig_overlay_height * self.theme.slot_icon_scale)
  self.hover_icon             = images.new(table.copy(images_setup, true))
  self:setup_image(self.hover_icon,
    HTB_ART .. 'themes/' .. (theme_options.frame_theme:lower()) .. '/frame.png')
  self.hover_icon:hide()
  self.hover_icon:size(self.image_width + 2, self.image_height + 2)
  self.hover_icon.row = 0
  self.hover_icon.column = 0
  self.theme.mp_cost_color_red = theme_options.font_color_red_costs_mp
  self.theme.mp_cost_color_green = theme_options.font_color_green_costs_mp
  self.theme.mp_cost_color_blue = theme_options.font_color_blue_costs_mp
  self.theme.tp_cost_color_red = theme_options.font_color_red_costs_tp
  self.theme.tp_cost_color_green = theme_options.font_color_green_costs_tp
  self.theme.tp_cost_color_blue = theme_options.font_color_blue_costs_tp
  count_color[1] = theme_options.count_color_red or 255
  count_color[2] = theme_options.count_color_green or 255
  count_color[3] = theme_options.count_color_blue or 255
  bst_charge_time = tonumber(theme_options.bst_ready_charge_seconds) or 30
  self:setup_sizing()
  self:setup_environment()
  self:setup_choice_modifier_indicator()
  self:setup_category_page_arrows()
  self:setup_choice_page_arrows()
  self:setup_disabled_icons()
  self:init_all_hotbars_and_slots()
  self:setup_feedback()
  self.is_setup = true
end

function ui:set_player(player)
  self.player = player
end

function ui:empty_row_hidden(environment, row)
  local h = self.theme and self.theme.hide_empty_rows
  if not h then return false end
  local et = h[environment]
  return et ~= nil and et[row] == true
end

function ui:setup_sizing()
  self.playerinv = windower.ffxi.get_items() or { inventory = { count = 0, max = 0 } }
  self.active_environment = {}

  self.active_environment['battle'] = {}
  self.active_environment['field'] = {}

  self.active_environment['battle'] = texts.new(table.copy(environment_text_setup), true)
  self.active_environment['field'] = texts.new(table.copy(environment_text_setup), true)

  self:setup_env_text(self.active_environment['battle'], self.theme)
  self:setup_env_text(self.active_environment['field'], self.theme)

  self.hotbar_width = ((40 * self.theme.columns) + self.theme.slot_spacing * (self.theme.columns - 1))
  self.scaled_pos_x = windower.get_windower_settings().ui_x_res
  self.scaled_pos_y = windower.get_windower_settings().ui_y_res
  self.pos_x = 0
  self.pos_y = 0

  self.slot_spacing = self.theme.slot_spacing
  self.vertical_slot_spacing = self.theme.vertical_slot_spacing or self.theme.slot_spacing

  if self.theme.hide_action_names == true then
    self.theme.hotbar_spacing = self.theme.hotbar_spacing - 10
    self.pos_y = self.pos_y + 10
  end

  self.hotbar_spacing = self.theme.hotbar_spacing
end

function ui:setup_env_text(text, theme_options)
  text:bg_alpha(0)
  text:bg_visible(false)
  text:font(theme_options.font_env)
  text:size(theme_options.font_size_env * theme_options.slot_icon_scale)
  text:color(theme_options.font_color_red_env, theme_options.font_color_green_env, theme_options.font_color_blue_env)
  text:stroke_transparency(theme_options.font_stroke_alpha_env)
  text:stroke_color(theme_options.font_stroke_color_red_env, theme_options.font_stroke_color_green_env,
    theme_options.font_stroke_color_blue_env)
  text:stroke_width(theme_options.font_stroke_width_env)
  text:show()
end

function ui:setup_choice_modifier_indicator()
  self.choice_modifier_indicator = texts.new(table.copy(environment_text_setup), true)
  self:setup_env_text(self.choice_modifier_indicator, self.theme)
  self.choice_modifier_indicator:text(((self.theme.choice_bar or {}).IndicatorText) or 'CHOICE MODE ON')
  self.choice_modifier_indicator:bg_visible(false)
  self.choice_modifier_indicator:bg_alpha(0)
  self.choice_modifier_indicator:alpha(255)
  self.choice_modifier_indicator:color(((self.theme.choice_bar or {}).FrameRed) or 80,
      ((self.theme.choice_bar or {}).FrameGreen) or 190,
      ((self.theme.choice_bar or {}).FrameBlue) or 255)
  self:apply_choice_indicator_scale()
  self:update_choice_modifier_indicator_position()
  self.choice_modifier_indicator:hide()
end

function ui:choice_indicator_pos()
  local cb = self.theme.choice_bar or {}
  if self.loaded_environment == 'field' then
    return (cb.IndicatorFieldX or 675), (cb.IndicatorFieldY or 688)
  end
  return (cb.IndicatorBattleX or 675), (cb.IndicatorBattleY or 688)
end

function ui:choice_indicator_scale()
  return tonumber((self.theme.choice_bar or {}).IndicatorScale) or 1
end

function ui:apply_choice_indicator_scale()
  if self.choice_modifier_indicator == nil then return end
  local sz = (self.theme.font_size_env or 14) * (self.theme.slot_icon_scale or 1) * self:choice_indicator_scale()
  pcall(function() self.choice_modifier_indicator:size(sz) end)
end

function ui:update_choice_modifier_indicator_position()
  if self.choice_modifier_indicator == nil then return end
  local x, y = self:choice_indicator_pos()
  self.choice_modifier_indicator:pos(x, y)
end

function ui:get_choice_indicator_extents()
  if self.choice_modifier_indicator == nil then return nil, nil end
  local was_visible = self.choice_modifier_indicator:visible()
  if not was_visible then self.choice_modifier_indicator:show() end
  local w, h = self.choice_modifier_indicator:extents()
  if not was_visible then self.choice_modifier_indicator:hide() end
  if w and h and w > 0 and h > 0 then return w, h end
  return nil, nil
end

function ui:resize_choice_bar()
  if not (self.choice_bar and self.choice_bar.row and self.hotbars[self.choice_bar.row]) then return end
  local t  = self.theme
  local cr = self.choice_bar.row
  local hb = self.hotbars[cr]
  local bs = self:bar_scale(cr)
  local biw, bih = math.floor(self.image_width * bs), math.floor(self.image_height * bs)
  local bow, boh = math.floor(self.overlay_image_width * bs), math.floor(self.overlay_image_height * bs)
  local fs = (t.slot_icon_scale or 1) * bs
  for i = 1, t.columns do
    hb.slot_backgrounds[i]:size(biw, bih)
    hb.slot_icons[i]:size(biw, bih)
    hb.slot_frames[i]:size(biw, bih)
    hb.slot_recasts[i]:size(biw, bih); hb.slot_recasts[i]:fit(true)
    if not t.disable_scroll then hb.slot_overlay[i]:size(bow, boh) end
    hb.slot_outline[i]:size(biw + 6, bih + 6)
    hb.slot_texts[i]:size(t.font_size_names * fs)
    hb.slot_keys[i]:size(t.font_size_keys * fs)
    hb.slot_cost[i]:size(t.font_size_costs * fs)
    hb.slot_recast_texts[i]:size(t.font_size_recasts * fs)
  end
  if hb.number then hb.number:size(t.font_size_hotbar_nums * fs) end
end

function ui:choice_bar_rect()
  if not (self.choice_bar and self.choice_bar.row) then return nil end
  local h = self.choice_bar.row
  local cbx, cby = self:choice_base()
  local biw, bih = self:bar_image_width(h), self:bar_image_height(h)
  local cols = (self.theme and self.theme.columns) or 10
  local w = cols * biw + (cols - 1) * (self.slot_spacing or 0)
  return math.floor(self.pos_x + cbx), math.floor(cby), math.floor(w), math.floor(bih)
end

function ui:reposition_choice_slots()
  if not (self.choice_bar and self.choice_bar.row and self.hotbars[self.choice_bar.row]) then return end
  for i = 1, self.theme.columns do self:reposition_slot(self.choice_bar.row, i) end
end

function ui:set_choice_base(x, y)
  local cb = self.theme.choice_bar; if not cb then return end
  local nx = math.floor(x - (self.pos_x or 0))
  if self.loaded_environment == 'field' then cb.FieldOffsetX, cb.FieldOffsetY = nx, math.floor(y)
  else cb.OffsetX, cb.OffsetY = nx, math.floor(y) end
  self:reposition_choice_slots()
  if self.choice_bar.row and self.hotbars[self.choice_bar.row] and self.hotbars[self.choice_bar.row].number then
    local sx, sy = self:get_slot_xy(self.choice_bar.row, 1)
    self.hotbars[self.choice_bar.row].number:pos(sx + ((cb.LabelOffsetX or 0) * (self.theme.slot_icon_scale or 1)),
      sy + ((cb.LabelOffsetY or -26) * (self.theme.slot_icon_scale or 1)))
  end
end

function ui:get_choice_scale() return self:bar_scale(self.choice_bar and self.choice_bar.row or -1) end
function ui:set_choice_scale(s)
  local cb = self.theme.choice_bar; if not cb then return end
  cb.Scale = math.max(0.5, math.min(2.5, tonumber(s) or 1))
  self:resize_choice_bar()
  self:reposition_choice_slots()
end

function ui:set_choice_indicator_pos(x, y)
  local cb = self.theme.choice_bar; if not cb then return end
  if self.loaded_environment == 'field' then cb.IndicatorFieldX, cb.IndicatorFieldY = math.floor(x), math.floor(y)
  else cb.IndicatorBattleX, cb.IndicatorBattleY = math.floor(x), math.floor(y) end
  self:update_choice_modifier_indicator_position()
end
function ui:set_choice_indicator_scale(s)
  local cb = self.theme.choice_bar; if not cb then return end
  cb.IndicatorScale = math.max(0.5, math.min(2.5, tonumber(s) or 1))
  self:apply_choice_indicator_scale()
  self:update_choice_modifier_indicator_position()
end
function ui:choice_indicator_rect()
  if self.choice_modifier_indicator == nil then return nil end
  local x, y = self:choice_indicator_pos()
  local w, h = self:get_choice_indicator_extents()
  return math.floor(x), math.floor(y), math.floor(w or 120), math.floor(h or 18)
end

function ui:choice_hud_preview(on)
  if not (self.choice_bar and self.choice_bar.row and self.hotbars[self.choice_bar.row]) then return end
  local cr = self.choice_bar.row
  local hb = self.hotbars[cr]
  local cb = self.theme.choice_bar or {}
  if on then
    self._choice_preview = true
    self:resize_choice_bar()
    for i = 1, self.theme.columns do
      local x, y = self:get_slot_xy(cr, i)
      hb.slot_backgrounds[i]:pos(x, y); hb.slot_backgrounds[i]:alpha(cb.BackgroundAlpha or 0); hb.slot_backgrounds[i]:show()
      hb.slot_frames[i]:pos(x, y); hb.slot_frames[i]:alpha(cb.FrameAlpha or 170)
      hb.slot_frames[i]:color(cb.FrameRed or 80, cb.FrameGreen or 190, cb.FrameBlue or 255); hb.slot_frames[i]:show()
    end
    if self.choice_modifier_indicator then
      self:apply_choice_indicator_scale(); self:update_choice_modifier_indicator_position()
      self.choice_modifier_indicator:text(cb.IndicatorText or 'CHOICE MODE ON')
      self.choice_modifier_indicator:show()
    end
  elseif self._choice_preview then
    self._choice_preview = false
    if not self:is_choice_bar_active() then
      for i = 1, self.theme.columns do
        if hb.slot_backgrounds[i] then hb.slot_backgrounds[i]:hide() end
        if hb.slot_frames[i] then hb.slot_frames[i]:hide() end
      end
      if self.choice_modifier_indicator then self.choice_modifier_indicator:hide() end
    end
  end
end

function ui:set_choice_modifier_indicator(active)
  if self.choice_modifier_indicator == nil then return end
  self:update_choice_modifier_indicator_position()
  if active == true and not (self.hotbar and self.hotbar.hide_hotbars == true) then
    self.choice_modifier_indicator:text(((self.theme.choice_bar or {}).IndicatorText) or 'CHOICE MODE ON')
    self.choice_modifier_indicator:show()
  else
    self.choice_modifier_indicator:hide()
  end
end

function ui:get_category_page_arrow_xy(row, direction)
  local first_x, first_y = self:get_slot_xy(row, 1)
  local last_x, last_y = self:get_slot_xy(row, self.theme.columns)
  local scale = tonumber(self.theme.slot_icon_scale or 1) or 1

  local width = math.max(12, math.floor(16 * scale))
  local height = self.image_height

  if direction == 'prev' then
    return first_x - width, first_y, width, height
  elseif direction == 'next' then
    return last_x + self.image_width, last_y, width, height
  else
    return last_x + self.image_width, last_y, 0, 0
  end
end

function ui:setup_category_page_arrows()
  self.category_page_arrows = {}
  for row = 1, self.theme.rows, 1 do
    self.category_page_arrows[row] = {
      prev = texts.new(table.copy(category_arrow_text_setup), true),
      next = texts.new(table.copy(category_arrow_text_setup), true),
      label = texts.new(table.copy(category_arrow_text_setup), true),
    }

    for _, key in ipairs({ 'prev', 'next', 'label' }) do
      local t = self.category_page_arrows[row][key]
      t:bg_alpha(0)
      t:bg_visible(false)
      t:font(self.theme.font_hotbar_nums or self.theme.font_env)
      t:size((self.theme.font_size_hotbar_nums or self.theme.font_size_env or 10) * self.theme.slot_icon_scale)
      t:color(((self.theme.choice_bar or {}).FrameRed) or 80,
          ((self.theme.choice_bar or {}).FrameGreen) or 190,
          ((self.theme.choice_bar or {}).FrameBlue) or 255)
      t:stroke_transparency(self.theme.font_stroke_alpha_hotbar_nums or 180)
      t:stroke_color(self.theme.font_stroke_color_red_hotbar_nums or 0,
          self.theme.font_stroke_color_green_hotbar_nums or 0,
          self.theme.font_stroke_color_blue_hotbar_nums or 0)
      t:stroke_width(self.theme.font_stroke_width_hotbar_nums or 2)
      t:hide()
    end

    self.category_page_arrows[row].prev:text('<')
    self.category_page_arrows[row].next:text('>')
    self.category_page_arrows[row].label:text('')
  end
end

function ui:update_category_page_arrows(player_hotbar, environment)
  if self.category_page_arrows == nil then return end
  environment = environment or (self.player and self.player.get_hotbar_info_without_vitals and select(2, self.player:get_hotbar_info_without_vitals()))

  for row = 1, self.theme.rows, 1 do
    local arrows = self.category_page_arrows[row]
    if arrows ~= nil then
      local page, pages = 1, 1
      if self.player ~= nil and self.player.get_hotbar_page_info ~= nil and environment ~= nil then
        page, pages = self.player:get_hotbar_page_info(environment, row)
      end

      if tonumber(pages or 1) > 1 then
        local px, py = self:get_category_page_arrow_xy(row, 'prev')
        local nx, ny = self:get_category_page_arrow_xy(row, 'next')
        local text_y = math.floor(self.image_height / 5)
        arrows.prev:pos(px + 2, py + text_y)
        arrows.next:pos(nx + 2, ny + text_y)

        if tonumber(page or 1) > 1 then
          arrows.prev:show()
        else
          arrows.prev:hide()
        end

        if tonumber(page or 1) < tonumber(pages or 1) then
          arrows.next:show()
        else
          arrows.next:hide()
        end

        arrows.label:hide()
      else
        arrows.prev:hide()
        arrows.next:hide()
        arrows.label:hide()
      end
    end
  end
end

function ui:setup_choice_page_arrows()
  self.choice_page_arrows = {
    prev = texts.new(table.copy(category_arrow_text_setup), true),
    next = texts.new(table.copy(category_arrow_text_setup), true),
  }
  for _, key in ipairs({ 'prev', 'next' }) do
    local t = self.choice_page_arrows[key]
    t:bg_alpha(0)
    t:bg_visible(false)
    t:font(self.theme.font_hotbar_nums or self.theme.font_env)
    t:size((self.theme.font_size_hotbar_nums or self.theme.font_size_env or 10) * self.theme.slot_icon_scale)
    local cb = self.theme.choice_bar or {}
    t:color(cb.FrameRed or 80, cb.FrameGreen or 190, cb.FrameBlue or 255)
    t:stroke_transparency(self.theme.font_stroke_alpha_hotbar_nums or 180)
    t:stroke_color(self.theme.font_stroke_color_red_hotbar_nums or 0,
        self.theme.font_stroke_color_green_hotbar_nums or 0,
        self.theme.font_stroke_color_blue_hotbar_nums or 0)
    t:stroke_width(self.theme.font_stroke_width_hotbar_nums or 2)
    t:hide()
  end
  self.choice_page_arrows.prev:text('<')
  self.choice_page_arrows.next:text('>')
end

function ui:update_choice_page_arrows()
  if self.choice_page_arrows == nil or self.choice_bar == nil then return end
  if not self:is_choice_bar_active() then
    self.choice_page_arrows.prev:hide()
    self.choice_page_arrows.next:hide()
    return
  end
  local total = #(self.choice_bar.actions or {})
  local columns = self.theme.columns
  if total <= columns then
    self.choice_page_arrows.prev:hide()
    self.choice_page_arrows.next:hide()
    return
  end
  local page = self.choice_bar.page or 1
  local max_page = math.max(1, math.ceil(total / columns))
  local row = self.choice_bar.row
  local text_y = math.floor(self.image_height / 5)
  local px, py = self:get_category_page_arrow_xy(row, 'prev')
  local nx, ny = self:get_category_page_arrow_xy(row, 'next')
  self.choice_page_arrows.prev:pos(px + 2, py + text_y)
  self.choice_page_arrows.next:pos(nx + 2, ny + text_y)
  if page > 1 then self.choice_page_arrows.prev:show() else self.choice_page_arrows.prev:hide() end
  if page < max_page then self.choice_page_arrows.next:show() else self.choice_page_arrows.next:hide() end
end

function ui:hovered_choice_page_arrow(x, y)
  if self.choice_page_arrows == nil or not self:is_choice_bar_active() or self.choice_bar == nil then
    return nil
  end
  local total = #(self.choice_bar.actions or {})
  local columns = self.theme.columns
  if total <= columns then return nil end
  local page = self.choice_bar.page or 1
  local max_page = math.max(1, math.ceil(total / columns))
  local row = self.choice_bar.row
  local directions = {}
  if page > 1 then table.insert(directions, 'prev') end
  if page < max_page then table.insert(directions, 'next') end
  for _, direction in ipairs(directions) do
    local ax, ay, aw, ah = self:get_category_page_arrow_xy(row, direction)
    if x >= ax and x <= ax + aw and y >= ay and y <= ay + ah then
      return direction
    end
  end
  return nil
end

function ui:hide_category_page_arrows()
  if self.category_page_arrows == nil then return end
  for _, arrows in pairs(self.category_page_arrows) do
    if arrows.prev then arrows.prev:hide() end
    if arrows.next then arrows.next:hide() end
    if arrows.label then arrows.label:hide() end
  end
end

function ui:hovered_category_page_arrow(x, y)
  if self.category_page_arrows == nil then return nil, nil end
  local _, environment = nil, nil
  if self.player ~= nil and self.player.get_hotbar_info_without_vitals ~= nil then
    _, environment = self.player:get_hotbar_info_without_vitals()
  end

  for row = 1, self.theme.rows, 1 do
    local page, pages = 1, 1
    if self.player ~= nil and self.player.get_hotbar_page_info ~= nil and environment ~= nil then
      page, pages = self.player:get_hotbar_page_info(environment, row)
    end
    if tonumber(pages or 1) > 1 then
      local directions = {}
      if tonumber(page or 1) > 1 then table.insert(directions, 'prev') end
      if tonumber(page or 1) < tonumber(pages or 1) then table.insert(directions, 'next') end

      for _, direction in ipairs(directions) do
        local ax, ay, aw, ah = self:get_category_page_arrow_xy(row, direction)
        if x >= ax and x <= ax + aw and y >= ay and y <= ay + ah then
          return row, direction
        end
      end
    end
  end
  return nil, nil
end

function ui:change_category_page(row, direction)
  if self.player == nil or self.player.change_hotbar_page == nil then return false end
  local player_hotbar, environment, vitals = self.player:get_hotbar_info()
  if environment == nil then return false end
  local delta = direction == 'prev' and -1 or 1
  local old_page, old_pages = self.player:get_hotbar_page_info(environment, row)
  local new_page, pages = self.player:change_hotbar_page(environment, row, delta)
  if new_page ~= old_page then
    self:load_player_hotbar(player_hotbar, environment, vitals)
    return true
  end
  self:update_category_page_arrows(player_hotbar, environment)
  return false
end

function ui:maybe_page_category_arrow_hover(x, y)
  local row, direction = self:hovered_category_page_arrow(x, y)
  if row == nil then return false end
  local now = os.clock()
  local key = tostring(row) .. ':' .. tostring(direction)
  local last = tonumber(self.category_page_arrow_last_change[key] or 0) or 0
  if (now - last) >= 0.45 then
    self.category_page_arrow_last_change[key] = now
    return self:change_category_page(row, direction)
  end
  return true
end

function ui:setup_environment()
  local env_pos_x = self:get_slot_x(self.theme.hook_onto_bar, self.theme.columns + 1)
  local env_pos_y = self:get_slot_y(self.theme.hook_onto_bar, 0)

  if self.theme.hide_env == false then
    self.active_environment['battle']:text(self.theme.font_battle_text_env)
    self.active_environment['battle']:pos(env_pos_x + (self.theme.font_hook_offset_x_env * self.theme.slot_icon_scale),
      env_pos_y + (self.theme.font_hook_offset_y_env * self.theme.slot_icon_scale))
    self.active_environment['battle']:size(self.theme.font_size_env * self.theme.slot_icon_scale)
    self.active_environment['battle']:italic(self.theme.font_italics_env)
    self.active_environment['battle']:font(self.theme.font_env)
    self.active_environment['battle']:alpha(self.theme.font_alpha_env)
    self.active_environment['battle']:color(self.theme.font_color_red_env, self.theme.font_color_green_env,
      self.theme.font_color_blue_env)
    self.active_environment['battle']:stroke_transparency(self.theme.font_stroke_alpha_env)
    self.active_environment['battle']:stroke_color(self.theme.font_stroke_color_red_env, self.theme
      .font_stroke_color_green_env, self.theme.font_stroke_color_blue_env)
    self.active_environment['battle']:stroke_width(self.theme.font_stroke_width_env)
    self.active_environment['battle']:show()

    self.active_environment['field']:text(self.theme.font_field_text_env)
    self.active_environment['field']:pos(
      env_pos_x + ((self.theme.font_hook_offset_x_env + self.theme.font_offset_x_env) * self.theme.slot_icon_scale),
      env_pos_y + ((self.theme.font_hook_offset_y_env + self.theme.font_offset_y_env) * self.theme.slot_icon_scale))
    self.active_environment['field']:size(self.theme.font_size_env * self.theme.slot_icon_scale)
    self.active_environment['field']:italic(self.theme.font_italics_env)
    self.active_environment['field']:font(self.theme.font_env)
    self.active_environment['field']:alpha(self.theme.font_alpha_env)
    self.active_environment['field']:color(self.theme.font_color_red_env, self.theme.font_color_green_env,
      self.theme.font_color_blue_env)
    self.active_environment['field']:stroke_transparency(self.theme.font_stroke_alpha_env)
    self.active_environment['field']:stroke_color(self.theme.font_stroke_color_red_env,
      self.theme.font_stroke_color_green_env,
      self.theme.font_stroke_color_blue_env)
    self.active_environment['field']:stroke_width(self.theme.font_stroke_width_env)
    self.active_environment['field']:show()

    if self.theme.hook_onto_bar == 0 then
      self.active_environment['battle']:pos(self.theme.font_pos_x_env, self.theme.font_pos_y_env)
      self.active_environment['battle']:show()

      self.active_environment['field']:pos(self.theme.font_pos_x_env + self.theme.font_offset_x_env,
        self.theme.font_pos_y_env + self.theme.font_offset_y_env)
      self.active_environment['field']:show()
    end
  end

  self.inventory_count = texts.new(inventory_count_setup)
  self:setup_inv_text(self.inventory_count, self.theme)

  if self.theme.hide_inventory_count == false then
    if self.theme.unlock_pos_inv == true then
      self.inventory_count:pos(self.theme.font_pos_x_inv, self.theme.font_pos_y_inv)
      self:get_inventory_count(self.theme, self.inventory_count, self.playerinv.inventory)
      self.inventory_count:show()
    else
      self.inventory_count:pos(env_pos_x + (self.theme.text_offset_x_inv * self.theme.slot_icon_scale),
        env_pos_y + (self.theme.text_offset_y_inv * self.theme.slot_icon_scale))
      self:get_inventory_count(self.theme, self.inventory_count, self.playerinv.inventory)
      self.inventory_count:show()
    end
  end
end

function ui:set_environment_text_draggable(enabled)
  if self.active_environment == nil then return end
  for _, key in ipairs({ 'battle', 'field' }) do
    local text_obj = self.active_environment[key]
    if text_obj ~= nil and text_obj.draggable ~= nil then
      pcall(function() text_obj:draggable(enabled == true) end)
    end
  end
end

function ui:set_inventory_count_draggable(enabled)
  if self.inventory_count == nil then return end
  if self.inventory_count.draggable == nil then return end
  pcall(function() self.inventory_count:draggable(enabled == true) end)
end

function ui:get_inventory_count_position()
  if self.inventory_count == nil then return nil, nil end
  local x, y = self.inventory_count:pos()
  return x, y
end

function ui:get_environment_text_position()
  if self.active_environment == nil or self.active_environment['battle'] == nil then return nil end
  local battle_x, battle_y = self.active_environment['battle']:pos()
  local field_x, field_y = battle_x, battle_y
  if self.active_environment['field'] ~= nil then
    field_x, field_y = self.active_environment['field']:pos()
  end
  return battle_x, battle_y, (field_x - battle_x), (field_y - battle_y)
end

local function text_rect(t)
  if not t then return nil end
  local x, y = t:pos()
  if not x then return nil end
  local w, h = 0, 0
  pcall(function() w, h = t:extents() end)
  return x, y, tonumber(w) or 0, tonumber(h) or 0
end

function ui:get_environment_text_rect()
  local bx, by, bw, bh = text_rect(self.active_environment and self.active_environment['battle'])
  if not bx then return nil end
  local x1, y1, x2, y2 = bx, by, bx + bw, by + bh
  local fx, fy, fw, fh = text_rect(self.active_environment and self.active_environment['field'])
  if fx then
    x1 = math.min(x1, fx); y1 = math.min(y1, fy)
    x2 = math.max(x2, fx + fw); y2 = math.max(y2, fy + fh)
  end
  return x1, y1, (x2 - x1), (y2 - y1)
end

function ui:get_inventory_count_rect()
  return text_rect(self.inventory_count)
end

function ui:set_environment_text_position(x, y)
  if self.active_environment == nil then return end
  local _, _, dx, dy = self:get_environment_text_position()
  dx = dx or 0; dy = dy or 0
  if self.active_environment['battle'] then self.active_environment['battle']:pos(x, y) end
  if self.active_environment['field'] then self.active_environment['field']:pos(x + dx, y + dy) end
end

function ui:set_inventory_count_position(x, y)
  if self.inventory_count == nil then return end
  self.inventory_count:pos(x, y)
end

function ui:get_inventory_count(theme, text_box, bag)
  text_box:text(bag.count .. '/' .. bag.max)
  if (bag.max - bag.count <= 5) then
    text_box:color(240, 0, 0)
  elseif (bag.max - bag.count <= 10) then
    text_box:color(240, 240, 0)
  else
    text_box:color(theme.font_color_red_inv, theme.font_color_green_inv, theme.font_color_blue_inv)
  end
end

function ui:setup_inv_text(text, theme_options)
  text:bg_alpha(theme_options.font_bg_opacity_inv)
  text:bg_visible(theme_options.font_bg_enable_inv)
  text:size(ui.theme.font_size_inv * theme_options.slot_icon_scale)
  text:italic(ui.theme.font_italics_inv)
  text:font(ui.theme.font_inv)
  text:alpha(ui.theme.font_alpha_inv)
  text:stroke_transparency(ui.theme.font_stroke_alpha_inv)
  text:stroke_width(ui.theme.font_stroke_width_inv)
  text:stroke_color(ui.theme.font_stroke_color_red_inv, ui.theme.font_stroke_color_green_inv,
    ui.theme.font_stroke_color_blue_inv)
  text:bg_alpha(ui.theme.font_bg_opacity_inv)
  text:bg_visible(ui.theme.font_bg_enable_inv)
  text:show()
end

function ui:setup_disabled_icons()
  for h = 1, self.theme.rows, 1 do
    self.disabled_icons[#self.disabled_icons + 1] = {}
    for i = 1, self.theme.columns, 1 do
      ui.disabled_icons[h][#self.disabled_icons[h] + 1] = 0
    end
  end
end

function ui:init_all_hotbars_and_slots()
  for h = 1, self.theme.hotbar_number, 1 do
    self.hotbars[h] = self:init_hotbar(self.theme, h)
    for i = 1, self.theme.columns, 1 do
      self:init_slot(h, i, self.theme)
    end
  end

  self.choice_bar.row = self.theme.hotbar_number + 1
  self.hotbars[self.choice_bar.row] = self:init_hotbar(self.theme, self.choice_bar.row)
  for i = 1, self.theme.columns, 1 do
    self:init_slot(self.choice_bar.row, i, self.theme)
  end
  self:hide_choice_bar_visuals()

  self.action_description = texts.new()
  self:setup_action_description_text(self.action_description, self.theme)
  self.description_setup = false
  self:hide_bars_beyond_visible()
end

function ui:hide_bars_beyond_visible()
  local visible_count = self.theme.visible_hotbar_count or self.theme.hotbar_number
  for h = visible_count + 1, self.theme.hotbar_number do
    if self.hotbars[h] then
      if self.hotbars[h].number then self.hotbars[h].number:hide() end
      for i = 1, self.theme.columns do
        self.hotbars[h].slot_backgrounds[i]:hide()
        self.hotbars[h].slot_icons[i]:hide()
        self.hotbars[h].slot_overlay[i]:hide()
        self.hotbars[h].slot_outline[i]:hide()
        self.hotbars[h].slot_frames[i]:hide()
        self.hotbars[h].slot_recasts[i]:hide()
        self.hotbars[h].slot_texts[i]:hide()
        self.hotbars[h].slot_cost[i]:hide()
        self.hotbars[h].slot_recast_texts[i]:hide()
        self.hotbars[h].slot_keys[i]:hide()
      end
    end
  end
end

function ui:get_bar_rect(h)
  if not self.hotbars or not self.hotbars[h] then return nil end
  local cols = self.theme.columns
  local x1, y1 = self:get_slot_xy(h, 1)
  local biw, bih = self:bar_image_width(h), self:bar_image_height(h)
  local off = self.theme.offsets[tostring(h)]
  if off and off.Vertical == true then
    local vsp = self.vertical_slot_spacing or 0
    local rows = math.ceil(cols / 2)
    return x1, y1, biw * 2 + vsp, bih * rows + vsp * (rows - 1)
  end
  local xc = self:get_slot_xy(h, cols)
  return x1, y1, (xc - x1) + biw, bih
end

local BAR_SLOT_PARTS = { 'slot_backgrounds', 'slot_icons', 'slot_overlay', 'slot_outline',
  'slot_frames', 'slot_recasts', 'slot_texts', 'slot_cost', 'slot_recast_texts', 'slot_keys' }
function ui:hide_bar(h)
  local hb = self.hotbars and self.hotbars[h]
  if not hb then return end
  if hb.number then hb.number:hide() end
  for i = 1, self.theme.columns do
    for _, part in ipairs(BAR_SLOT_PARTS) do
      local obj = hb[part] and hb[part][i]
      if obj then obj:hide() end
    end
  end
end

function ui:reposition_bar(h)
  local t = self.theme
  local esc = t.slot_icon_scale * self:bar_scale(h)
  for i = 1, t.columns do slot_xy_cache[h * 100 + i] = nil end
  if not self.hotbars[h] then return end
  for i = 1, t.columns do
    local x, y = self:get_slot_xy(h, i)
    self.hotbars[h].slot_icons[i]:pos(x, y)
    self.hotbars[h].slot_frames[i]:pos(x, y)
    self.hotbars[h].slot_recasts[i]:pos(x, y)
    self.hotbars[h].slot_backgrounds[i]:pos(x, y)
    self.hotbars[h].slot_texts[i]:pos(
      x + (t.font_offset_x_names * esc),
      y + (t.font_offset_y_names * esc))
    self.hotbars[h].slot_recast_texts[i]:pos(
      x + (t.text_offset_x_recasts * esc),
      y + (t.text_offset_y_recasts * esc))
    self.hotbars[h].slot_keys[i]:pos(
      x + (t.text_offset_x_keys * esc),
      y + (t.text_offset_y_keys * esc))
    self.hotbars[h].slot_cost[i]:pos(
      x + (t.text_offset_x_costs * esc),
      y + (t.text_offset_y_costs * esc))
    if not t.disable_scroll then
      self.hotbars[h].slot_overlay[i]:pos(
        x + (17 * esc), y - (2 * esc))
    end
    self.hotbars[h].slot_outline[i]:pos(x - 3, y - 3)
  end
  if self.hotbars[h].number then
    local sx, sy = self:get_slot_xy(h, 1)
    if t.offsets[tostring(h)] and t.offsets[tostring(h)].Vertical == true then
      self.hotbars[h].number:pos(
        sx + (t.text_vert_offset_x_hotbar_nums * esc),
        sy + (t.text_vert_offset_y_hotbar_nums * esc))
    else
      self.hotbars[h].number:pos(
        sx + (t.text_offset_x_hotbar_nums * esc),
        sy + (t.text_offset_y_hotbar_nums * esc))
    end
  end
end

function ui:reposition_all_bars()
  local t = self.theme
  if self.choice_bar then
    for i = 1, t.columns do slot_xy_cache[self.choice_bar.row * 100 + i] = nil end
  end
  for h = 1, t.hotbar_number do
    self:reposition_bar(h)
  end
  if self.choice_bar and self.hotbars[self.choice_bar.row] then
    local cb = t.choice_bar or {}
    local cr = self.choice_bar.row
    for i = 1, t.columns do
      local x, y = self:get_slot_xy(cr, i)
      self.hotbars[cr].slot_icons[i]:pos(x, y)
      self.hotbars[cr].slot_frames[i]:pos(x, y)
      self.hotbars[cr].slot_recasts[i]:pos(x, y)
      self.hotbars[cr].slot_backgrounds[i]:pos(x, y)
      self.hotbars[cr].slot_texts[i]:pos(
        x + (t.font_offset_x_names * t.slot_icon_scale),
        y + (t.font_offset_y_names * t.slot_icon_scale))
      self.hotbars[cr].slot_recast_texts[i]:pos(
        x + (t.text_offset_x_recasts * t.slot_icon_scale),
        y + (t.text_offset_y_recasts * t.slot_icon_scale))
      self.hotbars[cr].slot_keys[i]:pos(
        x + (t.text_offset_x_keys * t.slot_icon_scale),
        y + (t.text_offset_y_keys * t.slot_icon_scale))
      self.hotbars[cr].slot_cost[i]:pos(
        x + (t.text_offset_x_costs * t.slot_icon_scale),
        y + (t.text_offset_y_costs * t.slot_icon_scale))
      if not t.disable_scroll then
        self.hotbars[cr].slot_overlay[i]:pos(
          x + (17 * t.slot_icon_scale), y - (2 * t.slot_icon_scale))
      end
      self.hotbars[cr].slot_outline[i]:pos(x - 3, y - 3)
    end
    if self.hotbars[cr].number then
      local sx, sy = self:get_slot_xy(cr, 1)
      self.hotbars[cr].number:pos(
        sx + ((cb.LabelOffsetX or 0) * t.slot_icon_scale),
        sy + ((cb.LabelOffsetY or -26) * t.slot_icon_scale))
    end
  end
  if self.active_environment then
    if t.hook_onto_bar ~= 0 then
      local epx = self:get_slot_x(t.hook_onto_bar, t.columns + 1)
      local epy = self:get_slot_y(t.hook_onto_bar, 0)
      if self.active_environment['battle'] then
        self.active_environment['battle']:pos(
          epx + (t.font_hook_offset_x_env * t.slot_icon_scale),
          epy + (t.font_hook_offset_y_env * t.slot_icon_scale))
      end
      if self.active_environment['field'] then
        self.active_environment['field']:pos(
          epx + ((t.font_hook_offset_x_env + t.font_offset_x_env) * t.slot_icon_scale),
          epy + ((t.font_hook_offset_y_env + t.font_offset_y_env) * t.slot_icon_scale))
      end
      if self.inventory_count and not t.unlock_pos_inv then
        self.inventory_count:pos(
          epx + (t.text_offset_x_inv * t.slot_icon_scale),
          epy + (t.text_offset_y_inv * t.slot_icon_scale))
      end
    else
      if self.active_environment['battle'] then
        self.active_environment['battle']:pos(t.font_pos_x_env, t.font_pos_y_env)
      end
      if self.active_environment['field'] then
        self.active_environment['field']:pos(
          t.font_pos_x_env + t.font_offset_x_env,
          t.font_pos_y_env + t.font_offset_y_env)
      end
    end
  end
  if self.inventory_count and t.unlock_pos_inv then
    self.inventory_count:pos(t.font_pos_x_inv, t.font_pos_y_inv)
  end
  self:update_choice_modifier_indicator_position()
  self:update_category_page_arrows()
end

function ui:rescale(new_scale)
  local t = self.theme
  t.slot_icon_scale = new_scale

  self.image_width          = math.floor(self.base_image_size * new_scale)
  self.image_height         = math.floor(self.base_image_size * new_scale)
  self.overlay_image_width  = math.floor(self.base_overlay_size * new_scale)
  self.overlay_image_height = math.floor(self.base_overlay_size * new_scale)

  for h = 1, t.hotbar_number do
    local hb = self.hotbars[h]
    if hb then
      local bs = self:bar_scale(h)
      local biw, bih = math.floor(self.image_width * bs), math.floor(self.image_height * bs)
      local bow, boh = math.floor(self.overlay_image_width * bs), math.floor(self.overlay_image_height * bs)
      local fs = new_scale * bs
      for i = 1, t.columns do
        hb.slot_backgrounds[i]:size(biw, bih)
        hb.slot_icons[i]:size(biw, bih)
        hb.slot_frames[i]:size(biw, bih)
        hb.slot_recasts[i]:size(biw, bih)
        if not t.disable_scroll then hb.slot_overlay[i]:size(bow, boh) end
        hb.slot_outline[i]:size(biw + 6, bih + 6)
        hb.slot_texts[i]:size(t.font_size_names * fs)
        hb.slot_keys[i]:size(t.font_size_keys * fs)
        hb.slot_cost[i]:size(t.font_size_costs * fs)
        hb.slot_recast_texts[i]:size(t.font_size_recasts * fs)
      end
      if hb.number then hb.number:size(t.font_size_hotbar_nums * fs) end
    end
  end

  if self.choice_bar and self.choice_bar.row and self.hotbars[self.choice_bar.row] then
    local cr = self.choice_bar.row
    local hb = self.hotbars[cr]
    local bs = self:bar_scale(cr)
    local biw, bih = math.floor(self.image_width * bs), math.floor(self.image_height * bs)
    local bow, boh = math.floor(self.overlay_image_width * bs), math.floor(self.overlay_image_height * bs)
    local fs = new_scale * bs
    for i = 1, t.columns do
      hb.slot_backgrounds[i]:size(biw, bih)
      hb.slot_icons[i]:size(biw, bih)
      hb.slot_frames[i]:size(biw, bih)
      hb.slot_recasts[i]:size(biw, bih)
      hb.slot_recasts[i]:fit(true)
      if not t.disable_scroll then hb.slot_overlay[i]:size(bow, boh) end
      hb.slot_outline[i]:size(biw + 6, bih + 6)
      hb.slot_texts[i]:size(t.font_size_names * fs)
      hb.slot_keys[i]:size(t.font_size_keys * fs)
      hb.slot_cost[i]:size(t.font_size_costs * fs)
      hb.slot_recast_texts[i]:size(t.font_size_recasts * fs)
    end
    if hb.number then hb.number:size(t.font_size_hotbar_nums * fs) end
  end

  if self.feedback_icon then self.feedback_icon:size(self.image_width, self.image_height) end

  self.hover_icon:size(self.image_width + 2, self.image_height + 2)

  for _, key in ipairs({'battle', 'field'}) do
    if self.active_environment and self.active_environment[key] then
      self.active_environment[key]:size(t.font_size_env * new_scale * (t.env_text_scale or 1))
    end
  end
  if self.inventory_count then self.inventory_count:size(t.font_size_inv * new_scale * (t.inv_text_scale or 1)) end
  if self.choice_modifier_indicator then self.choice_modifier_indicator:size(t.font_size_env * new_scale * self:choice_indicator_scale()) end

  local arrow_size = (t.font_size_hotbar_nums or t.font_size_env or 10) * new_scale
  if self.category_page_arrows then
    for row = 1, t.rows do
      local arrows = self.category_page_arrows[row]
      if arrows then
        if arrows.prev then arrows.prev:size(arrow_size) end
        if arrows.next then arrows.next:size(arrow_size) end
        if arrows.label then arrows.label:size(arrow_size) end
      end
    end
  end
  if self.choice_page_arrows then
    if self.choice_page_arrows.prev then self.choice_page_arrows.prev:size(arrow_size) end
    if self.choice_page_arrows.next then self.choice_page_arrows.next:size(arrow_size) end
  end

  self:reposition_all_bars()
  self:apply_slot_scales()
  self:update_choice_page_arrows()
end

function ui:init_hotbar(theme_options, number)
  local hotbar             = {}
  hotbar.slot_backgrounds  = {}
  hotbar.slot_icons        = {}
  hotbar.slot_recasts      = {}
  hotbar.slot_frames       = {}
  hotbar.slot_texts        = {}
  hotbar.slot_cost         = {}
  hotbar.slot_recast_texts = {}
  hotbar.slot_keys         = {}
  hotbar.slot_overlay      = {}
  hotbar.slot_outline      = {}
  hotbar.number            = texts.new(table.copy(text_setup), true)

  if self.theme.hide_hotbar_numbers == false or (self.choice_bar ~= nil and number == self.choice_bar.row) then
    self:setup_hotbar_numbers_text(hotbar.number, theme_options)
    hotbar.number:text(tostring(number))
  end

  local slot_x, slot_y = self:get_slot_xy(number, 1)

  if self.choice_bar ~= nil and number == self.choice_bar.row then
    local cb = theme_options.choice_bar or {}
    hotbar.number:pos(
      slot_x + ((cb.LabelOffsetX or 0) * theme_options.slot_icon_scale),
      slot_y + ((cb.LabelOffsetY or -26) * theme_options.slot_icon_scale))
    hotbar.number:text('Choice')
  elseif (theme_options.offsets[tostring(number)].Vertical == true) then
    hotbar.number:pos(
      slot_x + (theme_options.text_vert_offset_x_hotbar_nums * theme_options.slot_icon_scale),
      slot_y + (theme_options.text_vert_offset_y_hotbar_nums * theme_options.slot_icon_scale))
  else
    hotbar.number:pos(
      slot_x + (theme_options.text_offset_x_hotbar_nums * theme_options.slot_icon_scale),
      slot_y + (theme_options.text_offset_y_hotbar_nums * theme_options.slot_icon_scale))
  end
  return hotbar
end

function ui:setup_hotbar_numbers_text(text, theme_options)
  text:bg_alpha(0)
  text:bg_visible(false)
  text:italic(theme_options.font_italics_hotbar_nums)
  text:font(theme_options.font_hotbar_nums)
  text:size(theme_options.font_size_hotbar_nums * theme_options.slot_icon_scale)
  text:color(theme_options.font_color_red_hotbar_nums, theme_options.font_color_green_hotbar_nums,
    theme_options.font_color_blue_hotbar_nums)
  text:stroke_transparency(theme_options.font_stroke_alpha_hotbar_nums)
  text:stroke_color(theme_options.font_stroke_color_red_hotbar_nums, theme_options.font_stroke_color_green_hotbar_nums,
    theme_options.font_stroke_color_blue_hotbar_nums)
  text:stroke_width(theme_options.font_stroke_width_hotbar_nums)
  text:show()
end

function ui:init_slot(row, column, theme_options)
  local slot_pos_x, slot_pos_y                = self:get_slot_xy(row, column)

  self.hotbars[row].slot_backgrounds[column]  = images.new(table.copy(images_setup, true))
  self.hotbars[row].slot_icons[column]        = images.new(table.copy(images_setup, true))
  self.hotbars[row].slot_overlay[column]      = images.new(table.copy(overlay_images_setup, true))
  self.hotbars[row].slot_recasts[column]      = images.new(table.copy(images_setup, true))
  self.hotbars[row].slot_frames[column]       = images.new(table.copy(images_setup, true))

  self.hotbars[row].slot_texts[column]        = texts.new(table.copy(text_setup), true)
  self.hotbars[row].slot_cost[column]         = texts.new(table.copy(text_setup), true)
  self.hotbars[row].slot_recast_texts[column] = texts.new(table.copy(text_setup), true)
  self.hotbars[row].slot_keys[column]         = texts.new(table.copy(text_setup), true)
  self.hotbars[row].slot_outline[column]      = images.new(table.copy(outline_images_setup, true))

  self:setup_image(self.hotbars[row].slot_backgrounds[column],
    HTB_ART .. 'themes/' .. (theme_options.slot_theme:lower()) .. '/slot.png')
  self:setup_image(self.hotbars[row].slot_icons[column], HTB_ART .. 'other/blank.png')
  self:setup_image(self.hotbars[row].slot_frames[column],
    HTB_ART .. 'themes/' .. (theme_options.frame_theme:lower()) .. '/frame.png')
  self:setup_overlay_image(self.hotbars[row].slot_overlay[column],
    HTB_ART .. 'icons/custom/scroll.png')
  self:setup_outline_image(self.hotbars[row].slot_outline[column],
    HTB_ART .. 'other/blank.png')

  self:setup_names_text(self.hotbars[row].slot_texts[column], theme_options, slot_pos_x, slot_pos_y)

  self:setup_keys_text(self.hotbars[row].slot_keys[column], theme_options, slot_pos_x, slot_pos_y)

  self:setup_costs_text(self.hotbars[row].slot_cost[column], theme_options, slot_pos_x, slot_pos_y)

  self:setup_recasts_text(self.hotbars[row].slot_recast_texts[column], theme_options, slot_pos_x, slot_pos_y)

  self.hotbars[row].slot_backgrounds[column]:alpha(theme_options.slot_opacity)
  self.hotbars[row].slot_backgrounds[column]:pos(slot_pos_x, slot_pos_y)

  self.hotbars[row].slot_recasts[column]:size(self.image_width, self.image_height)
  self.hotbars[row].slot_recasts[column]:fit(false)
  self.hotbars[row].slot_recasts[column]:pos(slot_pos_x, slot_pos_y)
  self.hotbars[row].slot_recasts[column]:alpha(5)

  self.hotbars[row].slot_frames[column]:pos(slot_pos_x, slot_pos_y)

  self.hotbars[row].slot_icons[column]:pos(slot_pos_x, slot_pos_y)

  if theme_options.disable_scroll == false then
    self.hotbars[row].slot_overlay[column]:pos(slot_pos_x + (17 * theme_options.slot_icon_scale),
      slot_pos_y - (2 * theme_options.slot_icon_scale))
  end

  self.hotbars[row].slot_outline[column]:pos(slot_pos_x - 3, slot_pos_y - 3)

  if keyboard.hotbar_rows[row] == nil or keyboard.hotbar_rows[row][column] == nil then
    self.hotbars[row].slot_keys[column]:text("")
  else
    self.hotbars[row].slot_keys[column]:text(self:convert_modifier_string(keyboard.hotbar_rows[row][column]))
  end
end

function ui:convert_modifier_string(text)
  local msg = ''
  for i = 1, #text do
    local v = text:sub(i, i)
    if v == '^' then
      msg = msg .. 'C-'
    elseif v == '%' then
      msg = msg .. ''
    elseif v == '!' then
      msg = msg .. 'A-'
    elseif v == '@' then
      msg = msg .. 'Win-'
    elseif v == '~' then
      msg = msg .. 'S-'
    else
      msg = msg .. string.upper(v)
    end
  end
  return msg
end

function ui:setup_image(image, path)
  image:path(path)
  image:repeat_xy(1, 1)
  image:draggable(false)
  image:fit(false)
  image:alpha(255)
  image:size(ui.image_width, ui.image_height)
  image:show()
end

function ui:setup_overlay_image(image, path)
  image:path(path)
  image:repeat_xy(1, 1)
  image:draggable(false)
  image:fit(false)
  image:alpha(255)
  image:size(ui.overlay_image_width, ui.overlay_image_height)
end

function ui:setup_outline_image(image, path)
  image:path(path)
  image:repeat_xy(1, 1)
  image:draggable(false)
  image:fit(true)
  image:alpha(255)
  image:size(self.image_width + 6, self.image_height + 6)
  image:show()
end

function ui:setup_action_description_text(text, theme_options)
  text:bg_alpha(theme_options.font_bg_opacity_descr)
  text:bg_visible(theme_options.font_bg_enable_descr)
  text:italic(theme_options.font_italics_descr)
  text:font(theme_options.font_descr)
  text:size(theme_options.font_size_descr + 5)
  text:alpha(theme_options.font_alpha_descr)
  text:color(theme_options.font_color_red_descr, theme_options.font_color_green_descr,
    theme_options.font_color_blue_descr)
  text:stroke_transparency(theme_options.font_stroke_alpha_descr)
  text:stroke_color(theme_options.font_stroke_color_red_descr, theme_options.font_stroke_color_green_descr,
    theme_options.font_stroke_color_blue_descr)
  text:stroke_width(theme_options.font_stroke_width_descr)
  text:draggable(false)
  text:pos(theme_options.description_box_x or 675, theme_options.description_box_y or 688)
  text:hide()
end

function ui:get_description_position()
  if self.action_description == nil then return nil, nil end
  return self.action_description:pos()
end

function ui:build_tip_info(action, icon_path, row, col)
  if not action then return nil end
  local atype = tostring(action.type or ''):lower()
  if atype == 'choice' then
    local info = { is_choice = true, icon_path = icon_path }
    info.name = (action.alias and action.alias ~= '' and action.alias) or tostring(action.action or 'Choice')
    local names = {}
    local ok, members = pcall(function() return choice_groups:resolve(self.player, action.action) end)
    if ok and type(members) == 'table' then
      for _, m in ipairs(members) do
        local nm = (type(m) == 'table' and (m.action or m.alias)) or m
        if nm and tostring(nm) ~= '' then names[#names + 1] = tostring(nm) end
      end
    end
    info.members = table.concat(names, ', ')
    return info
  end

  local info = formatter.build_action_info(database, action)
  if not info then
    info = { icon_path = icon_path }
    info.name = (action.alias and action.alias ~= '' and action.alias) or tostring(action.action or 'Action')
    local act = tostring(action.action or '')
    local labels = { item = 'Item', autoitem = 'Item', autora = 'Ranged Attack', macro = 'Macro',
                     gs = 'GearSwap', input = 'Command', key = 'Key', ct = 'Phantom Roll',
                     pet = 'Pet Command', bstpet = 'Pet Command' }
    info.type = labels[atype] or (atype ~= '' and (atype:sub(1, 1):upper() .. atype:sub(2))) or 'Action'
    if atype == 'item' or atype == 'autoitem' then info.desc = act ~= '' and ('Uses ' .. act .. '.') or 'Uses an item.'
    elseif atype == 'autora' then info.desc = 'Initiates an automatic ranged attack.'
    elseif atype == 'macro' then info.desc = act ~= '' and ('Runs macro: ' .. act) or 'Runs a macro.'
    elseif atype == 'gs' then info.desc = 'GearSwap: ' .. act
    elseif atype == 'input' then info.desc = act
    elseif atype == 'key' then info.desc = 'Sends key: ' .. act
    else info.desc = act end
    return info
  end

  info.icon_path = icon_path
  if info.recast_id and not info.recast then
    local cached = recast_cache.get(info.recast_id)
    info.recast = (cached and formatter.fmt_time(cached)) or '?'
  end
  return info
end

function ui:show_action_panel(info)
  if self.description_setup or not info then return end
  if not self.action_tip then self.action_tip = action_tooltip.new() end
  self.tip_visible = true
  local bx, by = self.action_description:pos()
  self.action_description:hide()
  if self.action_tip.set_scale then self.action_tip:set_scale(self.theme.description_scale or 1) end
  self.action_tip:show(info, bx or 675, by or 688)
end

function ui:hide_action_panel()
  if self.action_tip then self.action_tip:hide() end
  if self.action_description then self.action_description:hide() end
  self.tip_visible = false
end

function ui:set_description_draggable(enabled)
  if self.action_description == nil then return end
  self.description_setup = (enabled == true)
  pcall(function() self.action_description:draggable(enabled == true) end)
  if enabled then
    self:hide_hover()
    if self.action_tip then self.action_tip:hide() end
    self.action_description:text('Skill Description Box\n(drag to reposition)')
    self.action_description:show()
  else
    self.action_description:hide()
  end
end

function ui:setup_feedback()
  self.feedback_icon = images.new(table.copy(images_setup, true))
  self:setup_image(self.feedback_icon, HTB_ART .. 'other/feedback.png')
  self.feedback.max_opacity = self.theme.feedback_max_opacity
  self.feedback.speed = self.theme.feedback_speed
  self.feedback.current_opacity = self.feedback.max_opacity
  self.feedback_icon:hide()
end

function ui:setup_names_text(text, theme_options, pos_x, pos_y)
  text:bg_alpha(theme_options.font_bg_opacity_names)
  text:bg_visible(theme_options.font_bg_enable_names)
  text:font(theme_options.font_names)
  text:size(theme_options.font_size_names * theme_options.slot_icon_scale)
  text:pos(pos_x + (theme_options.font_offset_x_names * theme_options.slot_icon_scale),
    pos_y + (theme_options.font_offset_y_names * theme_options.slot_icon_scale))
  text:alpha(255)
  text:color(theme_options.font_color_red_names, theme_options.font_color_green_names,
    theme_options.font_color_blue_names)
  text:stroke_transparency(theme_options.font_stroke_alpha_names)
  text:stroke_color(theme_options.font_stroke_color_red_names, theme_options.font_stroke_color_green_names,
    theme_options.font_stroke_color_blue_names)
  text:stroke_width(theme_options.font_stroke_width_names)
  text:show()
end

function ui:setup_keys_text(text, theme_options, pos_x, pos_y)
  text:bg_alpha(0)
  text:bg_visible(false)
  text:font(theme_options.font_keys)
  text:size(theme_options.font_size_keys * theme_options.slot_icon_scale)
  text:pos(pos_x + (theme_options.text_offset_x_keys * theme_options.slot_icon_scale),
    pos_y + (theme_options.text_offset_y_keys * theme_options.slot_icon_scale))
  text:color(theme_options.font_color_red_keys, theme_options.font_color_green_keys, theme_options.font_color_blue_keys)
  text:stroke_transparency(theme_options.font_stroke_alpha_keys)
  text:stroke_color(theme_options.font_stroke_color_red_keys, theme_options.font_stroke_color_green_keys,
    theme_options.font_stroke_color_blue_keys)
  text:stroke_width(theme_options.font_stroke_width_keys)
  text:show()
end

function ui:setup_costs_text(text, theme_options, pos_x, pos_y)
  text:alpha(255)
  text:pos(pos_x + (theme_options.text_offset_x_costs * theme_options.slot_icon_scale),
    pos_y + (theme_options.text_offset_y_costs * theme_options.slot_icon_scale))
  text:bg_alpha(0)
  text:bg_visible(false)
  text:font(theme_options.font_costs)
  text:size(theme_options.font_size_costs * theme_options.slot_icon_scale)
  text:color(theme_options.font_color_red_costs, theme_options.font_color_green_costs,
    theme_options.font_color_blue_costs)
  text:stroke_transparency(theme_options.font_stroke_alpha_costs)
  text:stroke_color(theme_options.font_stroke_color_red_costs, theme_options.font_stroke_color_green_costs,
    theme_options.font_stroke_color_blue_costs)
  text:stroke_width(theme_options.font_stroke_width_costs)
  text:show()
end

function ui:setup_recasts_text(text, theme_options, pos_x, pos_y)
  text:alpha(255)
  text:pos(pos_x + (theme_options.text_offset_x_recasts * theme_options.slot_icon_scale),
    pos_y + (theme_options.text_offset_y_recasts * theme_options.slot_icon_scale))
  text:bg_alpha(0)
  text:bg_visible(false)
  text:bold(true)
  text:font(theme_options.font_recasts)
  text:size(theme_options.font_size_recasts * theme_options.slot_icon_scale)
  text:color(theme_options.font_color_red_recasts, theme_options.font_color_green_recasts,
    theme_options.font_color_blue_recasts)
  text:stroke_transparency(theme_options.font_stroke_alpha_recasts)
  text:stroke_color(theme_options.font_stroke_color_red_recasts, theme_options.font_stroke_color_green_recasts,
    theme_options.font_stroke_color_blue_recasts)
  text:stroke_width(theme_options.font_stroke_width_recasts)
  text:show()
end

function ui:destroy()
  database:destroy()

  local function kill(o) if o then pcall(function() o:destroy() end) end end
  local function kill_all(t) if type(t) == 'table' then for _, o in pairs(t) do kill(o) end end end
  if self.hotbars then
    for _, hb in pairs(self.hotbars) do
      if type(hb) == 'table' then
        kill_all(hb.slot_backgrounds); kill_all(hb.slot_icons); kill_all(hb.slot_overlay)
        kill_all(hb.slot_outline); kill_all(hb.slot_frames); kill_all(hb.slot_recasts)
        kill_all(hb.slot_texts); kill_all(hb.slot_cost); kill_all(hb.slot_recast_texts); kill_all(hb.slot_keys)
        kill(hb.number)
      end
    end
  end
  kill(self.hover_icon); kill(self.inventory_count); kill(self.action_description)
  kill(self.feedback_icon); kill(self.choice_modifier_indicator)
  if self.action_tip then pcall(self.action_tip.dispose, self.action_tip); self.action_tip = nil end
  self.tip_visible = false
  if self.active_environment then kill(self.active_environment.battle); kill(self.active_environment.field) end
  if self.choice_page_arrows then kill(self.choice_page_arrows.prev); kill(self.choice_page_arrows.next); self.choice_page_arrows = nil end
  if self.category_page_arrows then
    for _, a in pairs(self.category_page_arrows) do
      if type(a) == 'table' then kill(a.prev); kill(a.next); kill(a.label) end
    end
  end

  self.hotbar = {
    initialized = false,
    ready = false,
    hide_hotbars = false,
    in_battle = false
  }

  self.hover_icon = {
    row = nil,
    col = nil,
    prev_row = nil,
    prev_col = nil
  }

  self.player = {}
  self.recasts = {}
  self.feedback_icon = nil
  self.hotbars = {}
  self.theme = {}
  self.feedback = {}
  self.feedback.is_active = false
  self.feedback.current_opacity = 0
  self.feedback.max_opacity = 0
  self.feedback.speed = 0
  self.disabled_slots = {}
  self.disabled_slots.actions = {}
  self.disabled_slots.no_vitals = {}
  self.disabled_slots.on_cooldown = {}
  self.outlined_slots = {}
  self.slot_max_recasts = {}
  self.sweep_active = {}
  self.is_setup = false
  self.disabled_icons = {}
  self.current_tick = 0
  self.current_target = nil
  self.choice_bar = { active = false, row = 0, source_hotbar = 0, group_id = '', label = '', actions = {}, page_actions = {}, page = 1, page_size = 10 }
  self.category_page_arrows = {}
  self.category_page_arrow_last_change = {}
end

function ui:swap_icons(swap_table)
  local source_row     = swap_table.source.row
  local source_slot    = swap_table.source.slot
  local dest_row       = swap_table.dest.row
  local dest_slot      = swap_table.dest.slot
  local tempPathSource = self.hotbars[source_row].slot_icons[source_slot]:path()
  local tempTextSource = self.hotbars[source_row].slot_texts[source_slot]:text()
  local tempPathDest   = self.hotbars[dest_row].slot_icons[dest_slot]:path()
  local tempTextDest   = self.hotbars[dest_row].slot_texts[dest_slot]:text()

  self.hotbars[dest_row].slot_texts[dest_slot]:text(tempTextSource or '')
  self.hotbars[source_row].slot_texts[source_slot]:text(tempTextDest or '')
  if tempPathSource and tempPathSource ~= '' then
    self.hotbars[dest_row].slot_icons[dest_slot]:path(tempPathSource)
  end
  if tempPathDest and tempPathDest ~= '' then
    self.hotbars[source_row].slot_icons[source_slot]:path(tempPathDest)
  end
end

function ui:move_icons(moved_row_info, theme_options)
  local off_x = moved_row_info.pos_x
  local off_y = moved_row_info.pos_y
  local r = moved_row_info.box_index
  self.theme.offsets[tostring(r)].OffsetX = off_x
  self.theme.offsets[tostring(r)].OffsetY = off_y
  for i = 1, self.theme.columns, 1 do
    slot_xy_cache[r * 100 + i] = nil
    local x, y = self:get_slot_xy(r, i)
    self.hotbars[r].slot_icons[i]:pos(x, y)
    self.hotbars[r].slot_frames[i]:pos(x, y)
    self.hotbars[r].slot_recasts[i]:pos(x, y)
    self.hotbars[r].slot_backgrounds[i]:pos(x, y)
    self.hotbars[r].slot_texts[i]:pos(x + (theme_options.font_offset_x_names * theme_options.slot_icon_scale),
      y + (theme_options.font_offset_y_names * theme_options.slot_icon_scale))
    self.hotbars[r].slot_recast_texts[i]:pos(x + (theme_options.text_offset_x_recasts * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_recasts * theme_options.slot_icon_scale))
    self.hotbars[r].slot_keys[i]:pos(x + (theme_options.text_offset_x_keys * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_keys * theme_options.slot_icon_scale))
    self.hotbars[r].slot_cost[i]:pos(x + (theme_options.text_offset_x_costs * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_costs * theme_options.slot_icon_scale))
  end
  local slot_x, slot_y = self:get_slot_xy(r, 1)
  if (self.theme.offsets[tostring(r)].Vertical == true) then
    self.hotbars[r].number:pos(
      slot_x + (theme_options.text_vert_offset_x_hotbar_nums * theme_options.slot_icon_scale),
      slot_y + (theme_options.text_vert_offset_y_hotbar_nums * theme_options.slot_icon_scale))
  else
    self.hotbars[r].number:pos(
      slot_x + (theme_options.text_offset_x_hotbar_nums * theme_options.slot_icon_scale),
      slot_y + (theme_options.text_offset_y_hotbar_nums * theme_options.slot_icon_scale))
  end
  self:update_category_page_arrows()

  if (r == self.theme.hook_onto_bar) then
    local env_pos_x = self:get_slot_x(self.theme.hook_onto_bar, self.theme.columns + 1)
    local env_pos_y = self:get_slot_y(self.theme.hook_onto_bar, 0)

    self.active_environment['battle']:pos(
      env_pos_x + (theme_options.font_hook_offset_x_env * theme_options.slot_icon_scale),
      env_pos_y + (theme_options.font_hook_offset_y_env * theme_options.slot_icon_scale))
    self.active_environment['field']:pos(
      env_pos_x +
      ((theme_options.font_hook_offset_x_env + theme_options.font_offset_x_env) * theme_options.slot_icon_scale),
      env_pos_y +
      ((theme_options.font_hook_offset_y_env + theme_options.font_offset_y_env) * theme_options.slot_icon_scale))
    if not theme_options.unlock_pos_inv then
      self.inventory_count:pos(env_pos_x + (theme_options.font_hook_offset_x_env * theme_options.slot_icon_scale),
        env_pos_y + (theme_options.font_hook_offset_y_env * theme_options.slot_icon_scale) +
        (35 * theme_options.slot_icon_scale))
    end
  end
end

function ui:hide_choice_bar_visuals()
  if self.choice_bar == nil or self.choice_bar.row == 0 or self.hotbars[self.choice_bar.row] == nil then return end
  local row = self.choice_bar.row
  self.hotbars[row].number:hide()
  for i = 1, self.theme.columns, 1 do
    self.hotbars[row].slot_backgrounds[i]:hide()
    self.hotbars[row].slot_icons[i]:hide()
    self.hotbars[row].slot_overlay[i]:hide()
    self.hotbars[row].slot_outline[i]:hide()
    self.hotbars[row].slot_frames[i]:hide()
    self.hotbars[row].slot_recasts[i]:hide()
    self.hotbars[row].slot_texts[i]:hide()
    self.hotbars[row].slot_cost[i]:hide()
    self.hotbars[row].slot_recast_texts[i]:hide()
    self.hotbars[row].slot_keys[i]:hide()
  end
end

function ui:is_choice_bar_active()
  return self.choice_bar ~= nil and self.choice_bar.active == true
end

function ui:choice_matches_hotbar(hotbar)
  return self:is_choice_bar_active() and tonumber(self.choice_bar.source_hotbar) == tonumber(hotbar)
end

function ui:build_choice_page_actions()
  self.choice_bar.page_actions = {}
  local total = #self.choice_bar.actions
  local columns = self.theme.columns
  local page_size = columns
  self.choice_bar.page_size = page_size

  local max_page = math.max(1, math.ceil(total / page_size))
  if self.choice_bar.page < 1 then self.choice_bar.page = 1 end
  if self.choice_bar.page > max_page then self.choice_bar.page = max_page end

  local start_index = ((self.choice_bar.page - 1) * page_size) + 1
  for i = start_index, math.min(total, start_index + page_size - 1) do
    self.choice_bar.page_actions[i - start_index + 1] = self.choice_bar.actions[i]
  end
end

local function value_or_default(value, default)
  if value == nil then return default end
  return value
end

local function safe_text_color(text_obj, r, g, b)
  if text_obj and text_obj.color then text_obj:color(r, g, b) end
end

function ui:style_choice_slot(slot)
  if self.choice_bar == nil or self.choice_bar.row == 0 then return end
  local row_index = self.choice_bar.row
  local row = self.hotbars[row_index]
  if row == nil or row.slot_backgrounds[slot] == nil then return end

  local cb = self.theme.choice_bar or {}
  local frame_r = cb.FrameRed or 80
  local frame_g = cb.FrameGreen or 190
  local frame_b = cb.FrameBlue or 255
  local key_r = cb.KeyRed or 120
  local key_g = cb.KeyGreen or 220
  local key_b = cb.KeyBlue or 255

  local bg_alpha = value_or_default(cb.BackgroundAlpha, 145)
  local frame_alpha = value_or_default(cb.FrameAlpha, value_or_default(cb.SlotAlpha, 220))
  row.slot_backgrounds[slot]:alpha(bg_alpha)
  if row.slot_frames[slot] then row.slot_frames[slot]:alpha(frame_alpha) end
  if row.slot_backgrounds[slot].color then row.slot_backgrounds[slot]:color(35, 55, 70) end
  if row.slot_frames[slot].color then row.slot_frames[slot]:color(frame_r, frame_g, frame_b) end
  safe_text_color(row.slot_keys[slot], key_r, key_g, key_b)
  safe_text_color(row.slot_texts[slot], frame_r, frame_g, frame_b)
  row.slot_keys[slot]:show()
  row.slot_frames[slot]:show()
  row.slot_backgrounds[slot]:show()
end

function ui:is_choice_action_disabled(action)
  if action == nil then return true, 'empty choice slot' end
  local action_type = tostring(action.type or ''):lower()

  if action._choice_unlearned == true then
    return true, action._choice_disabled_reason or 'not learned'
  elseif action._choice_inaccessible == true then
    return true, action._choice_disabled_reason or 'not available to current job/level'
  end

  if is_neutralized == true and action_type ~= 'input' and action_type ~= 'key' and action_type ~= 'macro' and action_type ~= 'gs' and action_type ~= 'ct' and action_type ~= 'autora' then
    return true, 'player cannot act right now'
  end

  if action_type == 'ma' then
    if is_spell_learned(action.action) ~= true then
      return true, 'not learned'
    elseif is_silenced == true then
      return true, 'silenced'
    elseif is_spell_usable(action.action, self.player) ~= true then
      return true, 'not available to current job/level'
    end

    local skill = database.ma and database.ma[tostring(action.action or ''):lower()] or nil
    local mp = current_mp
    if skill and mp < self:get_true_mp_cost(skill) then
      return true, 'not enough MP'
    end

    local on_cooldown, recast_time = self:get_action_cooldown_info(action)
    if on_cooldown == true then
      return true, 'on cooldown' .. (recast_time and (' (' .. self:calc_recast_time(recast_time, action_type) .. ')') or '')
    end
  elseif action_type == 'ja' then
    if is_amnesiad == true then
      return true, 'amnesiad'
    elseif is_job_ability_usable(action.action, self.player) ~= true then
      return true, 'not available to current job/level'
    end

    local skill = database.ja and database.ja[tostring(action.action or ''):lower()] or nil
    local mp = current_mp
    local tp = current_tp
    if skill and skill.type ~= 'Monster' and mp < self:get_true_mp_cost(skill) then
      return true, 'not enough MP'
    elseif skill and skill.tpcost ~= nil and skill.tpcost ~= 0 and skill.prefix ~= '/pet' and tp < self:get_true_tp_cost(skill) then
      return true, 'not enough TP'
    end

    local on_cooldown, recast_time = self:get_action_cooldown_info(action)
    if on_cooldown == true then
      return true, 'on cooldown' .. (recast_time and (' (' .. self:calc_recast_time(recast_time, action_type) .. ')') or '')
    end
  elseif action_type == 'ws' then
    if is_amnesiad == true then
      return true, 'amnesiad'
    elseif can_ws == false then
      return true, 'not enough TP'
    end
  elseif action_type == 'pet' then
    if is_amnesiad == true then
      return true, 'amnesiad'
    end
  end

  return false, nil
end

function ui:apply_choice_action_state(slot, action)
  if self.choice_bar == nil or self.choice_bar.row == 0 then return end
  local row_index = self.choice_bar.row
  local row = self.hotbars[row_index]
  if row == nil or row.slot_icons[slot] == nil then return end

  self.disabled_icons[row_index] = self.disabled_icons[row_index] or {}
  local disabled, reason = self:is_choice_action_disabled(action)
  local cb = self.theme.choice_bar or {}
  local enabled_opacity = value_or_default(cb.IconAlpha, value_or_default(cb.SlotAlpha, 220))
  local frame_enabled = value_or_default(cb.FrameAlpha, value_or_default(cb.SlotAlpha, enabled_opacity))
  local disabled_opacity = math.min(self.theme.disabled_slot_opacity or 50, enabled_opacity)
  local text_enabled = 255
  local text_disabled = math.max(80, disabled_opacity)

  if disabled == true then
    row.slot_icons[slot]:alpha(disabled_opacity)
    row.slot_frames[slot]:alpha(math.min(text_disabled, frame_enabled))
    row.slot_texts[slot]:alpha(text_disabled)
    row.slot_cost[slot]:alpha(text_disabled)
    self.disabled_icons[row_index][slot] = 1

    if action and action._choice_unlearned == true then
      row.slot_overlay[slot]:path(HTB_ART .. 'icons/custom/scroll.png')
      row.slot_overlay[slot]:show()
    elseif action and action._choice_inaccessible == true then
      row.slot_overlay[slot]:path(HTB_ART .. 'icons/custom/upgrade.png')
      row.slot_overlay[slot]:show()
    end
  else
    row.slot_icons[slot]:alpha(enabled_opacity)
    row.slot_frames[slot]:alpha(frame_enabled)
    row.slot_texts[slot]:alpha(text_enabled)
    row.slot_cost[slot]:alpha(text_enabled)
    if row.slot_overlay[slot] then row.slot_overlay[slot]:hide() end
    self.disabled_icons[row_index][slot] = 0
  end

  if action ~= nil then
    action._choice_disabled = disabled
    action._choice_disabled_reason = reason
  end
end

function ui:apply_overload_pct_display(row, slot, action_name_lower)
  if self.theme.hide_action_cost == true then return end
  if self.player == nil then return end
  local chances = self.player.pup_overload_chances
  if not chances then return end
  local entry = chances[action_name_lower]
  if entry == nil then return end
  local hb = self.hotbars[row]
  if not (hb and hb.slot_cost and hb.slot_cost[slot]) then return end
  local pct
  if type(entry) == 'table' then
    pct = math.max(0, entry.pct - math.floor((os.clock() - (entry.time or 0)) / 3))
  else
    pct = math.max(0, tonumber(entry) or 0)
  end
  local r, g, b = 150, 150, 150
  if pct >= 75 then r, g, b = 255, 60, 60
  elseif pct >= 50 then r, g, b = 255, 140, 0
  elseif pct >= 25 then r, g, b = 255, 220, 50
  elseif pct > 0 then r, g, b = 255, 255, 255
  end
  hb.slot_cost[slot]:color(r, g, b)
  hb.slot_cost[slot]:text(pct .. '%')
  hb.slot_cost[slot]:show()
end

function ui:load_choice_page()
  if self.choice_bar == nil or self.choice_bar.row == 0 then return end
  self:build_choice_page_actions()
  for i = 1, self.theme.columns, 1 do
    self:load_action(self.choice_bar.row, i, 'choice', self.choice_bar.page_actions[i], self.player and self.player.vitals)
    if self.choice_bar.page_actions[i] == nil then
      self.hotbars[self.choice_bar.row].slot_keys[i]:show()
      self.hotbars[self.choice_bar.row].slot_frames[i]:show()
      self.hotbars[self.choice_bar.row].slot_backgrounds[i]:show()
    end
    self:style_choice_slot(i)
    self:apply_choice_action_state(i, self.choice_bar.page_actions[i])
    local pa = self.choice_bar.page_actions[i]
    if pa and tostring(pa.type or '') == 'ja' then
      self:apply_overload_pct_display(self.choice_bar.row, i, tostring(pa.action or ''):lower())
    end
    if pa and (pa.type == 'ja' or pa.type == 'ma') then
      local on_cd, rt = self:get_action_cooldown_info(pa)
      if on_cd and rt and rt > 0 then
        self:show_recast(self.choice_bar.row, i, self:calc_recast_time(rt, pa.type), rt)
      end
    end
  end
  self:reposition_choice_slots()
  local cb = self.theme.choice_bar or {}
  local slot_x, slot_y = self:get_slot_xy(self.choice_bar.row, 1)
  self.hotbars[self.choice_bar.row].number:pos(slot_x + ((cb.LabelOffsetX or 0) * self.theme.slot_icon_scale), slot_y + ((cb.LabelOffsetY or -26) * self.theme.slot_icon_scale))
  self.hotbars[self.choice_bar.row].number:text('CHOICE: ' .. tostring(self.choice_bar.label or 'Choice'))
  self.hotbars[self.choice_bar.row].number:color(cb.FrameRed or 80, cb.FrameGreen or 190, cb.FrameBlue or 255)
  self.hotbars[self.choice_bar.row].number:show()
  self:update_choice_page_arrows()
end

function ui:open_choice_bar(group_id, label, actions, source_hotbar)
  self.choice_bar.active = true
  self.choice_bar.group_id = group_id or ''
  self.choice_bar.label = label or group_id or 'Choice'
  if self.theme and self.theme.auto_hide_unusable == true and type(actions) == 'table' then
    local filtered = {}
    for _, a in ipairs(actions) do
      if not (a and (a._choice_unlearned == true or a._choice_inaccessible == true)) then
        filtered[#filtered + 1] = a
      end
    end
    actions = filtered
  end
  self.choice_bar.actions = actions or {}
  self.choice_bar.page_actions = {}
  self.choice_bar.page = 1
  self.choice_bar.source_hotbar = tonumber(source_hotbar) or 0
  if self.choice_bar.row and self.choice_bar.row > 0 then
    self.slot_max_recasts[self.choice_bar.row] = {}
    self.sweep_active[self.choice_bar.row] = {}
  end
  self:load_choice_page()
end

function ui:close_choice_bar()
  if self.choice_bar == nil then return end
  self.choice_bar.active = false
  self.choice_bar.group_id = ''
  self.choice_bar.label = ''
  self.choice_bar.actions = {}
  self.choice_bar.page_actions = {}
  self.choice_bar.page = 1
  self.choice_bar.source_hotbar = 0
  self:hide_choice_bar_visuals()
  self:hide_hover()
  local crow = self.choice_bar.row
  if crow and crow > 0 and self.hotbars[crow] and self.hotbars[crow].number then
    self.hotbars[crow].number:text('')
    self.hotbars[crow].number:hide()
  end
  if self.choice_page_arrows ~= nil then
    self.choice_page_arrows.prev:hide()
    self.choice_page_arrows.next:hide()
  end
end

function ui:get_choice_action(slot)
  if not self:is_choice_bar_active() then return nil end
  return self.choice_bar.page_actions[tonumber(slot) or 0]
end

function ui:choice_next_page()
  if not self:is_choice_bar_active() then return end
  self.choice_bar.page = self.choice_bar.page + 1
  self:load_choice_page()
end

function ui:choice_prev_page()
  if not self:is_choice_bar_active() then return end
  self.choice_bar.page = self.choice_bar.page - 1
  self:load_choice_page()
end

function ui:hovered_choice(x, y)
  if not self:is_choice_bar_active() then return nil end
  local row = self.choice_bar.row
  for i = 1, self.theme.columns do
    local pos_x, pos_y = self:get_slot_xy(row, i)
    local off_x, off_y = pos_x + self.image_width, pos_y + self.image_height
    if x >= pos_x and x <= off_x and y >= pos_y and y <= off_y then
      return i
    end
  end
  return nil
end

local count_lines
local fallback_action_description
local format_action_description

function ui:trigger_choice_feedback(slot)
  if self.choice_bar == nil or self.choice_bar.row == 0 then return end
  local crow = self.choice_bar.row
  self.feedback_icon:size(self:bar_image_width(crow), self:bar_image_height(crow))
  self.feedback_icon:pos(self:get_slot_xy(crow, slot))
  self.feedback.current_opacity = self.feedback.max_opacity
  self.feedback.is_active = true
end

function ui:move_choice_indicator(moved_row_info, theme_options)
  local cb = self.theme.choice_bar or {}
  cb.IndicatorOffsetX = moved_row_info.pos_x - (cb.OffsetX or 0)
  cb.IndicatorOffsetY = moved_row_info.pos_y - (cb.OffsetY or 0)
  self.theme.choice_bar = cb
  self:update_choice_modifier_indicator_position()
end

function ui:move_choice_bar(moved_row_info, theme_options)
  local cb = self.theme.choice_bar or {}
  cb.OffsetX = moved_row_info.pos_x
  cb.OffsetY = moved_row_info.pos_y
  self.theme.choice_bar = cb
  for i = 1, self.theme.columns, 1 do
    local x, y = self:get_slot_xy(self.choice_bar.row, i)
    self.hotbars[self.choice_bar.row].slot_icons[i]:pos(x, y)
    self.hotbars[self.choice_bar.row].slot_frames[i]:pos(x, y)
    self.hotbars[self.choice_bar.row].slot_recasts[i]:pos(x, y)
    self.hotbars[self.choice_bar.row].slot_backgrounds[i]:pos(x, y)
    self.hotbars[self.choice_bar.row].slot_overlay[i]:pos(x + (17 * theme_options.slot_icon_scale),
      y - (2 * theme_options.slot_icon_scale))
    self.hotbars[self.choice_bar.row].slot_outline[i]:pos(x - 3, y - 3)
    self.hotbars[self.choice_bar.row].slot_texts[i]:pos(x + (theme_options.font_offset_x_names * theme_options.slot_icon_scale),
      y + (theme_options.font_offset_y_names * theme_options.slot_icon_scale))
    self.hotbars[self.choice_bar.row].slot_recast_texts[i]:pos(x + (theme_options.text_offset_x_recasts * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_recasts * theme_options.slot_icon_scale))
    self.hotbars[self.choice_bar.row].slot_keys[i]:pos(x + (theme_options.text_offset_x_keys * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_keys * theme_options.slot_icon_scale))
    self.hotbars[self.choice_bar.row].slot_cost[i]:pos(x + (theme_options.text_offset_x_costs * theme_options.slot_icon_scale),
      y + (theme_options.text_offset_y_costs * theme_options.slot_icon_scale))
  end
  local slot_x, slot_y = self:get_slot_xy(self.choice_bar.row, 1)
  self.hotbars[self.choice_bar.row].number:pos(
    slot_x + ((cb.LabelOffsetX or 0) * theme_options.slot_icon_scale),
    slot_y + ((cb.LabelOffsetY or -26) * theme_options.slot_icon_scale))
  self:update_choice_modifier_indicator_position()
end

function ui:hide()
  self:close_choice_bar()
  self:hide_hover()
  self.feedback_icon:hide()
  self.inventory_count:hide()
  if self.choice_modifier_indicator then self.choice_modifier_indicator:hide() end
  self:hide_category_page_arrows()
  if (self.active_environment ~= nil) then
    self.active_environment['battle']:hide()
    self.active_environment['field']:hide()
  end
  for h = 1, self.theme.hotbar_number, 1 do
    self.hotbars[h].number:hide()
    for i = 1, self.theme.columns, 1 do
      self.hotbars[h].slot_backgrounds[i]:hide()
      self.hotbars[h].slot_icons[i]:hide()
      self.hotbars[h].slot_overlay[i]:hide()
      self.hotbars[h].slot_outline[i]:hide()
      self.hotbars[h].slot_frames[i]:hide()
      self.hotbars[h].slot_recasts[i]:hide()
      self.hotbars[h].slot_texts[i]:hide()
      self.hotbars[h].slot_cost[i]:hide()
      self.hotbars[h].slot_recast_texts[i]:hide()
      self.hotbars[h].slot_keys[i]:hide()
    end
  end
end

function ui:hide_hover()
  self.hover_icon:hide()
  self.action_description:hide()
  if self.action_tip then self.action_tip:hide() end
  self.tip_visible = false
  self.current_row, self.current_column, self.current_choice = nil, nil, nil
  self.pending_row, self.pending_col, self.pending_choice = nil, nil, nil
  self.current_action_name = nil
end

function ui:show(player_hotbar, environment)
  if (self.active_environment ~= nil) then
    self.active_environment['battle']:show()
    self.active_environment['field']:show()
  end

  self.inventory_count:show()

  local env_table = player_hotbar and environment and player_hotbar[environment] or nil

  local visible_count = self.theme.visible_hotbar_count or self.theme.rows
  local henv = (environment == 'field') and 'field' or 'battle'
  local hidden_set = (self.theme.hidden_bars and self.theme.hidden_bars[henv]) or {}
  for h = 1, self.theme.rows, 1 do
    if h > visible_count or (hidden_set[h] and not self.theme.hud_show_all_bars) then
      if self.hotbars[h] and self.hotbars[h].number then self.hotbars[h].number:hide() end
      for i = 1, self.theme.columns, 1 do
        self.hotbars[h].slot_backgrounds[i]:hide()
        self.hotbars[h].slot_icons[i]:hide()
        self.hotbars[h].slot_overlay[i]:hide()
        self.hotbars[h].slot_outline[i]:hide()
        self.hotbars[h].slot_frames[i]:hide()
        self.hotbars[h].slot_recasts[i]:hide()
        self.hotbars[h].slot_texts[i]:hide()
        self.hotbars[h].slot_cost[i]:hide()
        self.hotbars[h].slot_recast_texts[i]:hide()
        self.hotbars[h].slot_keys[i]:hide()
      end
    else
      for i = 1, self.theme.columns, 1 do
        local row_table = env_table and env_table['hotbar_' .. h] or nil
        local action = (self.player ~= nil and self.player.get_visible_action ~= nil) and self.player:get_visible_action(environment, h, i) or (row_table and row_table['slot_' .. i] or nil)

        if self.hotbars[h] and self.hotbars[h].number then
          self.hotbars[h].number:show()
        end

        if action ~= nil then
          self.hotbars[h].slot_icons[i]:show()
          self.hotbars[h].slot_frames[i]:show()
          self.hotbars[h].slot_backgrounds[i]:show()
          if self.theme.hide_action_names == false then self.hotbars[h].slot_texts[i]:show() end
          if self.theme.hide_action_cost == false then self.hotbars[h].slot_cost[i]:show() else self.hotbars[h].slot_cost[i]:hide() end
          if self.theme.hide_recast_text == false then self.hotbars[h].slot_recast_texts[i]:show() end
          self.hotbars[h].slot_keys[i]:show()
        else
          self.hotbars[h].slot_icons[i]:path(HTB_ART .. 'other/blank.png')
          self.hotbars[h].slot_icons[i]:hide()
          self.hotbars[h].slot_overlay[i]:hide()
          self.hotbars[h].slot_outline[i]:hide()
          self.hotbars[h].slot_recasts[i]:hide()
          self.hotbars[h].slot_texts[i]:hide()
          self.hotbars[h].slot_cost[i]:hide()
          self.hotbars[h].slot_recast_texts[i]:hide()

          local row_hide = self:empty_row_hidden(environment, h)
          if not row_hide and (self.theme.hide_empty_slots == false or self.theme.show_empty_slot_frames == true) then
            self.hotbars[h].slot_backgrounds[i]:show()
            self.hotbars[h].slot_frames[i]:show()
            self.hotbars[h].slot_keys[i]:show()
          else
            self.hotbars[h].slot_backgrounds[i]:hide()
            self.hotbars[h].slot_frames[i]:hide()
            self.hotbars[h].slot_keys[i]:hide()
          end
        end
      end
    end
  end
  self:update_category_page_arrows(player_hotbar, environment)
end

local function action_draw_key(action)
  if action == nil then return 'nil' end
  return tostring(action.type or '') .. '|' ..
         tostring(action.action or '') .. '|' ..
         tostring(action.target or '') .. '|' ..
         tostring(action.alias or '') .. '|' ..
         tostring(action.icon or '')
end

function ui:set_slot_resolved_key(row, slot, action)
  self.slot_resolved_keys[row] = self.slot_resolved_keys[row] or {}
  self.slot_resolved_keys[row][slot] = action_draw_key(action)
end

function ui:get_slot_resolved_key(row, slot)
  return self.slot_resolved_keys[row] and self.slot_resolved_keys[row][slot] or nil
end

function ui:refresh_resource_dependent_slots()
  if self.is_setup ~= true or self.player == nil or self.player.get_hotbar_info == nil then return end

  if self.player.clear_resource_resolution_cache ~= nil then
    self.player:clear_resource_resolution_cache()
  end

  local player_hotbar, environment, vitals = self.player:get_hotbar_info()
  local env_table = player_hotbar and environment and player_hotbar[environment] or nil
  if env_table == nil then return end

  local visible_count = (environment == 'field' and self.theme.field_visible_hotbar_count) or self.theme.visible_hotbar_count or self.theme.hotbar_number
  local henv = (environment == 'field') and 'field' or 'battle'
  local hidden_set = (self.theme.hidden_bars and self.theme.hidden_bars[henv]) or {}
  for h = 1, self.theme.hotbar_number, 1 do
    if h > visible_count then break end
    local row_table = (not hidden_set[h] or self.theme.hud_show_all_bars) and env_table['hotbar_' .. h] or nil
    if row_table ~= nil then
      for i = 1, self.theme.columns, 1 do
        local raw_action = nil
        if self.player ~= nil and self.player.get_visible_action ~= nil then
          raw_action = self.player:get_visible_action(environment, h, i)
        else
          raw_action = row_table['slot_' .. i]
        end
        local resolved_action = raw_action
        if raw_action ~= nil and self.player.resolve_action_for_resources ~= nil then
          resolved_action = self.player:resolve_action_for_resources(raw_action)
        end

        local new_key = action_draw_key(resolved_action)
        if new_key ~= self:get_slot_resolved_key(h, i) then
          self:load_action(h, i, environment, raw_action, vitals)
        else
          self:update_mp_cost(h, i, resolved_action)
          self:update_tp_cost(h, i, resolved_action)
        end
      end
    end
  end

  if self:is_choice_bar_active() and self.choice_bar.row and self.choice_bar.row > 0
      and self.hotbars[self.choice_bar.row] then
    local cr = self.choice_bar.row
    for i = 1, self.theme.columns, 1 do
      local pa = self.choice_bar.page_actions and self.choice_bar.page_actions[i]
      if pa ~= nil then
        self:update_mp_cost(cr, i, pa)
        self:update_tp_cost(cr, i, pa)
        self:apply_choice_action_state(i, pa)
      end
    end
  end
end

function ui:load_player_hotbar(player_hotbar, environment, player_vitals)
  self.loaded_environment = (environment == 'field') and 'field' or 'battle'
  local _ffxi_env = (_G.XIVUI_THEME == 'ffxi')
  local function env_color(active)
    if _ffxi_env then
      local r, g, b = self.theme.font_color_red_env, self.theme.font_color_green_env, self.theme.font_color_blue_env
      if active then return r, g, b end
      return math.floor(r * 0.42), math.floor(g * 0.42), math.floor(b * 0.42)
    end
    if active then return 255, 255, 255 end
    return 100, 100, 100
  end
  if environment == 'field' then
    self.active_environment['field']:color(env_color(true))
    self.active_environment['battle']:color(env_color(false))
  else
    self.active_environment['field']:color(env_color(false))
    self.active_environment['battle']:color(env_color(true))
  end

  self.disabled_slots.actions = {}
  self.disabled_slots.no_vitals = {}
  self.disabled_slots.on_cooldown = {}
  self.outlined_slots = {}
  self.slot_resolved_keys = {}
  self.slot_max_recasts = {}
  self.sweep_active = {}
  if self.player ~= nil and self.player.clear_resource_resolution_cache ~= nil then
    self.player:clear_resource_resolution_cache()
  end

  local env_table = player_hotbar and environment and player_hotbar[environment] or nil

  local visible_count = (environment == 'field' and self.theme.field_visible_hotbar_count) or self.theme.visible_hotbar_count or self.theme.hotbar_number
  local henv = (environment == 'field') and 'field' or 'battle'
  local hidden_set = (self.theme.hidden_bars and self.theme.hidden_bars[henv]) or {}
  for h = 1, self.theme.hotbar_number, 1 do
    if h > visible_count or (hidden_set[h] and not self.theme.hud_show_all_bars) then
      if self.hotbars[h] and self.hotbars[h].number then self.hotbars[h].number:hide() end
      for i = 1, self.theme.columns, 1 do
        self.hotbars[h].slot_backgrounds[i]:hide()
        self.hotbars[h].slot_icons[i]:hide()
        self.hotbars[h].slot_overlay[i]:hide()
        self.hotbars[h].slot_outline[i]:hide()
        self.hotbars[h].slot_frames[i]:hide()
        self.hotbars[h].slot_recasts[i]:hide()
        self.hotbars[h].slot_texts[i]:hide()
        self.hotbars[h].slot_cost[i]:hide()
        self.hotbars[h].slot_recast_texts[i]:hide()
        self.hotbars[h].slot_keys[i]:hide()
      end
    else
      for i = 1, self.theme.columns, 1 do
        local row_table = env_table and env_table['hotbar_' .. h] or nil
        local action = nil
        if self.player ~= nil and self.player.get_visible_action ~= nil then
          action = self.player:get_visible_action(environment, h, i)
        else
          action = row_table and row_table['slot_' .. i] or nil
        end
        self:load_action(h, i, environment, action, player_vitals)
      end
    end
  end
  self:update_category_page_arrows(player_hotbar, environment)
end

function ui:load_action(row, slot, environment, action, player_vitals)

  self:clear_slot(row, slot)
  self.hotbars[row].slot_overlay[slot]:path(HTB_ART .. 'icons/custom/blank.png')
  self.hotbars[row].slot_overlay[slot]:hide()
  self.hotbars[row].slot_outline[slot]:hide()

  if environment ~= 'choice' and action ~= nil and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
    action = self.player:resolve_action_for_resources(action)
  end
  self:set_slot_resolved_key(row, slot, action)

  if action == nil then
    self.hotbars[row].slot_icons[slot]:path(HTB_ART .. 'other/blank.png')
    self.hotbars[row].slot_icons[slot]:hide()
    self.hotbars[row].slot_overlay[slot]:hide()
    self.hotbars[row].slot_outline[slot]:hide()
    self.hotbars[row].slot_recasts[slot]:hide()
    self.hotbars[row].slot_texts[slot]:hide()
    self.hotbars[row].slot_cost[slot]:hide()
    self.hotbars[row].slot_recast_texts[slot]:hide()

    local row_hide = self:empty_row_hidden(environment, row)
    if (self.theme.hide_empty_slots == true or row_hide) and (self.theme.show_empty_slot_frames ~= true or row_hide) then
      self.hotbars[row].slot_backgrounds[slot]:hide()
      self.hotbars[row].slot_frames[slot]:hide()
      self.hotbars[row].slot_keys[slot]:hide()
    else
      self.hotbars[row].slot_backgrounds[slot]:show()
      self.hotbars[row].slot_frames[slot]:show()
      self.hotbars[row].slot_keys[slot]:show()
    end
    return
  end

  self.hotbars[row].slot_cost[slot]:text('')

  local action_type = tostring(action.type or ''):lower()
  local action_name = tostring(action.action or '')
  local action_lookup = action_name:lower()
  local learnable_spell_name = not_learned_spells_row_slot[environment .. ' ' .. row .. ' ' .. slot]

  if learnable_spell_name then
    if learnable_spell_name == action.action then
      self.hotbars[row].slot_overlay[slot]:path(HTB_ART .. 'icons/custom/scroll.png')
    else
      self.hotbars[row].slot_overlay[slot]:path(HTB_ART .. 'icons/custom/upgrade.png')
    end
    self.hotbars[row].slot_overlay[slot]:show()
  end

  self.hotbars[row].slot_backgrounds[slot]:show()

  if S { 'ma', 'ja' }:contains(action_type) then
    self.hotbars[row].slot_backgrounds[slot]:alpha(200)
    local skill = nil

    if database[action_type] ~= nil then
      skill = database[action_type][action_lookup]
    end

    if skill ~= nil then
      self:setup_slot_icons('/images/icons/' .. (string.format('%s/%05d', ACTION_TYPE_FOLDER[action_type], skill.icon)) .. '.png', row, slot, 'default')

      if skill.mpcost ~= nil and skill.mpcost ~= 0 then
        if not (action_type == 'ja' and (skill.type == 'Scholar' or skill.type == 'Rune' or skill.type == 'CorsairShot')) then
          self.hotbars[row].slot_cost[slot]:color(self.theme.mp_cost_color_red, self.theme.mp_cost_color_green,
            self.theme.mp_cost_color_blue)
          self.hotbars[row].slot_cost[slot]:text(tostring(skill.mpcost))
        end
      end

      if skill.tpcost ~= nil and skill.tpcost ~= 0 then
        local tp_cost = self:get_true_tp_cost(skill)
        self:set_tp_cost_text_color(row, slot, tp_cost)
        self.hotbars[row].slot_cost[slot]:text(tostring(tp_cost))
      end
    else
      hotbar_tools:warn_once('unknown-' .. action_type .. '-' .. action_lookup,
        'XIVHOTBAR2: Unknown ' .. action_type .. ' action "' .. action_name .. '". Using fallback icon.')
      self:setup_default_slot_icons('default', row, slot)
    end

    self.hotbars[row].slot_icons[slot]:show()
  elseif action_type == 'ws' then
    local ws = nil
    if database[action_type] ~= nil then
      ws = database[action_type][action_lookup]
    end

    if ws ~= nil and ws.icon ~= nil then
      self:setup_slot_icons('/images/icons/weapons/' .. string.format('%02d', ws.icon) .. '.png', row, slot, 'default')
    else
      hotbar_tools:warn_once('unknown-ws-' .. action_lookup,
        'XIVHOTBAR2: Unknown weaponskill "' .. action_name .. '". Using fallback icon.')
      self:setup_default_slot_icons('default', row, slot)
    end

    self:set_tp_cost_text_color(row, slot, 1000)
    if player_vitals and player_vitals.tp then
      self.hotbars[row].slot_cost[slot]:text(tostring(math.max(1000, player_vitals.tp)))
    else
      self.hotbars[row].slot_cost[slot]:text('1000')
    end
  elseif action_type == 'choice' then
    self:setup_default_slot_icons('choice', row, slot)
  elseif action_type == 'choice_page_next' or action_type == 'choice_page_prev' then
    self:setup_default_slot_icons('macro', row, slot)
  elseif S { 'gs', 'macro' }:contains(action_type) then
    self:setup_default_slot_icons(action_type, row, slot)
  elseif action_type == 'item' then
    local itemCount = player.item_count and player.item_count[action.action] or 0
    if self.theme.hide_action_cost ~= true then
      if itemCount == 0 then
        self.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
      else
        self.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
      end
      self.hotbars[row].slot_cost[slot]:text(tostring(itemCount))
    end
    self:toggle_slot_opacity(row, slot, itemCount > 0)
    self:setup_item_slot_icons(action.action, row, slot)
  elseif action_type == 'use_equip' then
    local available = (player.item_count and (player.item_count[action.action] or 0) > 0)
                   or (player.equipped_item_names and player.equipped_item_names[action.action] == true)
    self:toggle_slot_opacity(row, slot, available)
    self:setup_item_slot_icons(action.action, row, slot)
  else
    self:setup_default_slot_icons('default', row, slot)
  end

  local effective_icon = action.icon
  if (effective_icon == nil or effective_icon == '') then
    effective_icon = ACTION_ICONS[action_type .. '|' .. action_lookup]
  end
  if effective_icon ~= nil and effective_icon ~= '' then
    self:setup_custom_slot_icons(effective_icon, row, slot)
  end

  self.hotbars[row].slot_outline[slot]:path(HTB_ART ..
    'themes/' .. (self.theme.frame_theme:lower()) .. '/outline.png')

  self.hotbars[row].slot_frames[slot]:show()
  if action.alias and #action.alias > 0 then
    self.hotbars[row].slot_texts[slot]:text(action.alias)
  end
  self.hotbars[row].slot_keys[slot]:show()

  if self.theme.hide_action_names == true then
    self.hotbars[row].slot_texts[slot]:hide()
  else
    self.hotbars[row].slot_texts[slot]:show()
  end

  if self.theme.hide_action_cost == true then
    self.hotbars[row].slot_cost[slot]:hide()
  else
    self.hotbars[row].slot_cost[slot]:show()
  end

  self:update_mp_cost(row, slot, action)
  self:update_tp_cost(row, slot, action)
end

function ui:clear_slot(hotbar, slot)
  if not self.hotbars[hotbar] then return end
  local row = self.hotbars[hotbar]
  if not row.slot_backgrounds or not row.slot_backgrounds[slot] then return end

  row.slot_backgrounds[slot]:alpha(self.theme.slot_opacity)
  row.slot_icons[slot]:alpha(255)
  row.slot_icons[slot]:color(255, 255, 255)
  if row.slot_frames[slot].color then row.slot_frames[slot]:color(255, 255, 255) end
  if row.slot_backgrounds[slot].color then row.slot_backgrounds[slot]:color(255, 255, 255) end
  row.slot_overlay[slot]:hide()
  row.slot_outline[slot]:hide()
  row.slot_recasts[slot]:hide()
  row.slot_texts[slot]:text('')
  row.slot_cost[slot]:alpha(255)
  row.slot_cost[slot]:text('')
  row.slot_recast_texts[slot]:text('')

  if self.theme.reduce_flicker == false then
    row.slot_frames[slot]:hide()
    row.slot_icons[slot]:path(HTB_ART .. 'other/blank.png')
    row.slot_icons[slot]:hide()
  end
end

function ui:setup_slot_icons(img_path, row, slot, fallback_type)
  local full_path = HTB_ART .. (img_path:gsub('^/?images/', ''))
  self.hotbars[row].slot_icons[slot]:pos(self:get_slot_xy(row, slot))

  if hotbar_tools:file_exists(full_path) then
    self.hotbars[row].slot_icons[slot]:path(full_path)
  else
    hotbar_tools:warn_once('missing-icon-' .. img_path, 'XIVHOTBAR2: Missing icon ' .. img_path .. '. Using fallback icon.')
    self.hotbars[row].slot_icons[slot]:path(self.default_image_paths[fallback_type or 'default'] or self.default_image_paths['default'])
  end

  self.hotbars[row].slot_icons[slot]:show()
end

function ui:setup_custom_slot_icons(icon, row, slot)
  local custom = '/images/icons/custom/' .. icon .. '.png'
  if hotbar_tools:file_exists(HTB_ART .. (custom:gsub('^/?images/', ''))) then
    self:setup_slot_icons(custom, row, slot, 'default')
  else
    self:setup_slot_icons('/images/icons/' .. icon .. '.png', row, slot, 'default')
  end
end

function ui:setup_default_slot_icons(type, row, slot)
  self.hotbars[row].slot_icons[slot]:pos(self:get_slot_xy(row, slot))
  self.hotbars[row].slot_icons[slot]:path(self.default_image_paths[type] or self.default_image_paths['default'])
  self.hotbars[row].slot_icons[slot]:show()
end

function ui:setup_item_slot_icons(name, row, slot)
  local img_path = '/images/icons/custom/item.png'
  name = tostring(name or ''):lower()

  if database.items and database.items[name] ~= nil then
    local id = database.items[name].id

    if id then
      local temp_path = '/images/icons/items/' .. id .. '.bmp'
      if hotbar_tools:file_exists(HTB_ART .. (temp_path:gsub('^/?images/', ''))) then
        img_path = temp_path
      end
    end
  end

  self:setup_slot_icons(img_path, row, slot, 'item')
end

function ui:update_mp_costs(player_hotbar, environment)
  if player_hotbar ~= nil and environment ~= nil and player_hotbar[environment] ~= nil then
    for h = 1, self.theme.hotbar_number, 1 do
      local row_table = player_hotbar[environment]['hotbar_' .. h]
      if row_table ~= nil then
        for i = 1, self.theme.columns, 1 do
          self:update_mp_cost(h, i, (self.player ~= nil and self.player.get_visible_action ~= nil) and self.player:get_visible_action(environment, h, i) or row_table['slot_' .. i])
        end
      end
    end
  end
end

function ui:update_tp_costs(player_hotbar, environment)
  local meikyo_active = self.player and self.player.has_meikyo == true
  if current_tp < 1000 and not meikyo_active then can_ws = false else can_ws = true end
  if player_hotbar ~= nil and environment ~= nil and player_hotbar[environment] ~= nil then
    for h = 1, self.theme.hotbar_number, 1 do
      local row_table = player_hotbar[environment]['hotbar_' .. h]
      if row_table ~= nil then
        for i = 1, self.theme.columns, 1 do
          self:update_tp_cost(h, i, (self.player ~= nil and self.player.get_visible_action ~= nil) and self.player:get_visible_action(environment, h, i) or row_table['slot_' .. i])
        end
      end
    end
  end
end

function ui:update_mp(new_mp)
  current_mp = new_mp or 0
  if self.player and self.player.vitals then
    self.player.vitals.mp = current_mp
  end

  self:refresh_resource_dependent_slots()
end

function ui:update_tp(new_tp)
  current_tp = new_tp or 0
  if self.player and self.player.vitals then
    self.player.vitals.tp = current_tp
  end

  local meikyo_active = self.player and self.player.has_meikyo == true
  if current_tp < 1000 and not meikyo_active then can_ws = false else can_ws = true end

  self:refresh_resource_dependent_slots()
end

function ui:update_pet_tp(current_pet_tp)
  current_pet_tp_value = tonumber(current_pet_tp) or 0
  can_pet_ws = current_pet_tp_value >= 1000
  self:refresh_resource_dependent_slots()
end

function ui:get_current_pet_tp()
  return current_pet_tp_value
end

function ui:update_pet_mp(new_pet_mp)
  current_pet_mp = new_pet_mp
end

local function skill_has_real_mp_cost(skill)
  if skill == nil then return false end
  local prefix = tostring(skill.prefix or '')
  local skill_type = tostring(skill.type or '')
  if prefix == '/magic' then return true end
  if skill_type == 'BloodPactRage' or skill_type == 'BloodPactWard' then return true end
  if prefix == '/pet' and skill_type == 'Monster' then return true end
  return false
end

function ui:get_true_mp_cost(skill)
  if skill ~= nil then
    if not skill_has_real_mp_cost(skill) then return 0 end
    if not (skill.type == 'Monster' and skill.prefix == '/pet') then
      local mp_cost = skill.mpcost or 0

      if self.player.has_free_spell == true then
        mp_cost = 0
      elseif self.player.has_penury == true and skill.type == 'WhiteMagic' then
        mp_cost = math.ceil(mp_cost * 0.5)
      elseif self.player.has_parsimony == true and skill.type == 'BlackMagic' then
        mp_cost = math.ceil(mp_cost * 0.5)
      end

      if self.player.has_apogee == true and (skill.type == 'BloodPactRage' or skill.type == 'BloodPactWard') then
        mp_cost = math.ceil(mp_cost * 1.5)
      end

      return mp_cost
    else
      return skill.mpcost
    end
  else
    return -1
  end
end

function ui:get_true_tp_cost(skill)
  if skill ~= nil then
    if skill.tpcost ~= nil and skill.tpcost ~= 0 and skill.prefix ~= '/pet' then
      local tp_cost = tonumber(skill.tpcost) or 0

      if self.player.has_trance == true then
        if skill.type == 'Samba' or skill.type == 'Step' or skill.type == 'Waltz' then
          tp_cost = 0
        end
      end

      return tp_cost
    end
    return 0
  else
    return 0
  end
end

function ui:get_current_tp()
  return current_tp
end

function ui:get_current_mp()
  return current_mp
end

function ui:get_rune_count()
  local wp = windower.ffxi.get_player()
  if not wp or not wp.buffs then return 0 end
  local count = 0
  for _, bid in ipairs(wp.buffs) do
    if RUNE_BUFF_IDS[bid] then count = count + 1 end
  end
  return count
end

local function spell_recasts_seconds()
  local out = {}
  for id, v in pairs(windower.ffxi.get_spell_recasts() or {}) do out[id] = (tonumber(v) or 0) / 60 end
  return out
end

function ui:get_action_cooldown_info(action, recast_tables)
  if action == nil then return false, 0, nil end

  local action_type = lc(action.type or '')
  if action_type ~= 'ja' and action_type ~= 'ma' then
    return false, 0, nil
  end

  local skill = database[action_type] and database[action_type][lc(action.action or '')] or nil
  if skill == nil then return false, 0, nil end

  local recasts = recast_tables or self.recasts or {}
  local action_recasts = recasts[action_type]
  if action_recasts == nil then
    if action_type == 'ja' then
      action_recasts = windower.ffxi.get_ability_recasts() or {}
    else
      action_recasts = spell_recasts_seconds()
    end
  end

  if skill.prefix == '/pet' and skill.type == 'Monster' then
    local ability_recasts = recasts.ja or windower.ffxi.get_ability_recasts() or {}
    local ready_cooldown = tonumber(ability_recasts[102]) or 0
    local charge_seconds = tonumber(self.theme.bst_ready_charge_seconds) or bst_charge_time or 30
    local max_charge_time = charge_seconds * 3
    local charges = math.floor((max_charge_time - ready_cooldown) / charge_seconds)
    if charges < 0 then charges = 0 end
    if charges > 3 then charges = 3 end

    local required = math.max(1, tonumber(skill.mpcost) or 1)
    if charges >= required then
      return false, 0, 'bst_ready_charges'
    end

    local missing = required - charges
    local remainder = ready_cooldown % charge_seconds
    if remainder == 0 then remainder = charge_seconds end
    return true, ((missing - 1) * charge_seconds) + remainder, 'bst_ready_charges'
  end

  if self:is_scholar_stratagem(skill) then
    local raw_recast = tonumber(action_recasts[tonumber(skill.icon)] or 0) or 0
    local charge_info = self:get_scholar_charge_info(raw_recast)
    if charge_info.charges > 0 then
      return false, 0, 'scholar_charges'
    end
    return true, charge_info.next_recast or raw_recast, 'scholar_charges'
  end

  local recast_id = tonumber(skill.icon)
  local recast_time = tonumber(action_recasts[recast_id] or 0) or 0
  if recast_time > 0 then
    return true, recast_time, 'recast'
  end

  return false, 0, 'recast'
end

function ui:set_tp_cost_text_color(row, slot, required_tp)
  local tp_cost = tonumber(required_tp) or 0
  local have_tp = self:get_current_tp()

  if tp_cost > 0 and have_tp < tp_cost then
    ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
  else
    ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
  end
end

function ui:set_count_cost_text(row, slot, count)
  count = tonumber(count) or 0
  if count == 0 then
    ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
  else
    ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
  end
  ui.hotbars[row].slot_cost[slot]:text(tostring(count))
end

function ui:update_mp_cost(row, slot, action)
  if action == nil then return end

  if not (self.choice_bar ~= nil and tonumber(row) == tonumber(self.choice_bar.row))
      and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
    action = self.player:resolve_action_for_resources(action)
  end

  local action_type = tostring(action.type or ''):lower()
  if action_type == 'ma' or action_type == 'ja' then
    local skill = database[action_type] and database[action_type][tostring(action.action or ''):lower()] or nil
    if skill then
      if skill.type == 'BloodPactRage' and self.player and self.player.has_astral_flow then
        local cur_mp = self:get_current_mp()
        local min_mp = (self.player.main_job_level or 1) * 2
        if cur_mp < min_mp then
          ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        ui.hotbars[row].slot_cost[slot]:text(tostring(cur_mp))
        return
      end

      if skill.type == 'CorsairShot' then
        local card_name = cor_card_display[tonumber(skill.oid)]
        if card_name then
          local card_count = self.player and self.player.item_count and (self.player.item_count[card_name] or 0) or 0
          if card_count == 0 then
            ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
          else
            ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          end
          ui.hotbars[row].slot_cost[slot]:text(tostring(card_count))
        end
      elseif skill.mpcost ~= nil and skill.mpcost ~= 0 then
        local mp_cost = self:get_true_mp_cost(skill)
        if mp_cost ~= nil and mp_cost > 0 then
          local have_mp = self:get_current_mp()
          if have_mp < mp_cost then
            ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
          else
            ui.hotbars[row].slot_cost[slot]:color(self.theme.mp_cost_color_red, self.theme.mp_cost_color_green, self.theme.mp_cost_color_blue)
          end
          ui.hotbars[row].slot_cost[slot]:text(tostring(mp_cost))
        end
      end
    end
  elseif action_type == 'choice' and tostring(action.action or ''):lower() == 'ja_type_bloodpactrage'
      and self.player and self.player.has_astral_flow then
    local cur_mp = self:get_current_mp()
    local min_mp = (self.player.main_job_level or 1) * 2
    if cur_mp < min_mp then
      ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
    else
      ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
    end
    ui.hotbars[row].slot_cost[slot]:text(tostring(cur_mp))
  end
end

function ui:get_charge_cost_text(skill)
  if skill == nil then return nil end

  if skill.prefix == '/pet' and skill.type == 'Monster' and skill.mpcost ~= nil and tonumber(skill.mpcost) and tonumber(skill.mpcost) > 0 then
    return tostring(skill.mpcost) .. 'C'
  end

  if skill.type == 'Flourish1' or skill.type == 'Flourish2' or skill.type == 'Flourish3' then
    local oid = tonumber(skill.oid)
    if oid == 209 or oid == 313 then
      return '2'
    elseif oid == 314 then
      return '3'
    elseif oid == 264 then
      return '1'
    else
      return nil
    end
  end

  return nil
end

function ui:update_tp_cost(row, slot, action)
  if action == nil then return end

  if not (self.choice_bar ~= nil and tonumber(row) == tonumber(self.choice_bar.row))
      and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
    action = self.player:resolve_action_for_resources(action)
  end

  local action_type = tostring(action.type or ''):lower()
  if action_type == 'ws' then
    if self.player.has_meikyo == true then
      ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
      ui.hotbars[row].slot_cost[slot]:text(tostring(current_tp))
    else
      self:set_tp_cost_text_color(row, slot, 1000)
      ui.hotbars[row].slot_cost[slot]:text(tostring(math.max(1000, current_tp)))
    end
  elseif action_type == 'ja' then
    local skill = database[action_type] and database[action_type][tostring(action.action or ''):lower()] or nil
    if skill then
      local charge_text = self:get_charge_cost_text(skill)
      if charge_text then
        local is_flourish = skill.type == 'Flourish1' or skill.type == 'Flourish2' or skill.type == 'Flourish3'
        if is_flourish then
          local fm_required = tonumber(charge_text) or 1
          local current_fm = self.player and self.player:get_finishing_moves() or 0
          if current_fm >= fm_required then
            ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          else
            ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
          end
        else
          ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        ui.hotbars[row].slot_cost[slot]:text(charge_text)
      elseif tonumber(skill.oid) == 389 then
        local dmg = math.floor(self:get_current_mp() / 10)
        ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        ui.hotbars[row].slot_cost[slot]:text(tostring(dmg))
      elseif tonumber(skill.oid) == 388 then
        local dmg = math.floor(self:get_current_tp() / 10)
        ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        ui.hotbars[row].slot_cost[slot]:text(tostring(dmg))
      elseif tonumber(skill.oid) == 78 then
        local food_count = 0
        local eq = windower.ffxi.get_items()
        if eq and eq.equipment and eq.equipment.ammo_bag and eq.equipment.ammo
            and not (eq.equipment.ammo_bag == 0 and eq.equipment.ammo == 0) then
          local ammo_item = windower.ffxi.get_items(eq.equipment.ammo_bag, eq.equipment.ammo)
          if ammo_item and ammo_item.id >= 17016 and ammo_item.id <= 17023 then
            food_count = ammo_item.count or 1
          end
        end
        if food_count == 0 then
          ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        ui.hotbars[row].slot_cost[slot]:text(tostring(food_count))
      elseif tonumber(skill.oid) == 85 or tonumber(skill.oid) == 387 then
        local jug_count = 0
        local eq = windower.ffxi.get_items()
        if eq and eq.equipment and eq.equipment.ammo_bag and eq.equipment.ammo
            and not (eq.equipment.ammo_bag == 0 and eq.equipment.ammo == 0) then
          local ammo_item = windower.ffxi.get_items(eq.equipment.ammo_bag, eq.equipment.ammo)
          if ammo_item and ammo_item.id and ammo_item.id ~= 0 then
            local ammo_res = resources and resources.items and resources.items[ammo_item.id]
            if ammo_res and ammo_res.category == 'Weapon'
                and ammo_res.slots ~= nil and ammo_res.slots[3]
                and ammo_res.jobs ~= nil and ammo_res.jobs[9] and not ammo_res.jobs[1] then
              jug_count = ammo_item.count or 1
            end
          end
        end
        if jug_count == 0 then
          ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        ui.hotbars[row].slot_cost[slot]:text(tostring(jug_count))
      elseif skill.tpcost ~= nil and skill.tpcost ~= 0 and skill.prefix ~= '/pet' then
        local tp_cost = self:get_true_tp_cost(skill)
        self:set_tp_cost_text_color(row, slot, tp_cost)
        ui.hotbars[row].slot_cost[slot]:text(tostring(tp_cost))
      elseif skill.prefix == '/pet' and skill.type == 'PetCommand'
          and tostring(action.action or ''):lower() == 'sic'
          and self.player and self.player.pet_name and self.player.pet_name ~= '' then
        local pet_tp = self:get_current_pet_tp()
        if pet_tp < 1000 then
          ui.hotbars[row].slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        ui.hotbars[row].slot_cost[slot]:text(tostring(pet_tp))
      end
    end
  elseif action_type == 'choice' and tostring(action.action or ''):lower() == 'bst_ready' then
    local ability_recasts_ready = windower.ffxi.get_ability_recasts() or {}
    local ready_cooldown = tonumber(ability_recasts_ready[102]) or 0
    local ready_charge_sec = tonumber(self.theme.bst_ready_charge_seconds) or bst_charge_time or 30
    local ready_charges = math.max(0, math.min(3, math.floor(((ready_charge_sec * 3) - ready_cooldown) / ready_charge_sec)))
    ui.hotbars[row].slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
    ui.hotbars[row].slot_cost[slot]:text(tostring(ready_charges))
  elseif action_type == 'item' or action_type == 'autoitem' then
    local cnt = (self.player and self.player.item_count and self.player.item_count[action.action]) or 0
    self:set_count_cost_text(row, slot, cnt)
    self:toggle_slot_opacity(row, slot, cnt > 0)
  end
end

function ui:update_inventory_count()
  if self.is_setup == true then
    if self.theme.hide_inventory_count == false then
      self.playerinv = windower.ffxi.get_items() or { inventory = { count = 0, max = 0 } }
      self:get_inventory_count(self.theme, self.inventory_count, self.playerinv.inventory)
    end
  end
end

function ui:check_and_set_disable(action, already_resolved, player_vitals)
  local vitals
  if player_vitals then
    vitals = player_vitals
  else
    local windower_player = windower.ffxi.get_player()
    vitals = (windower_player and windower_player.vitals) or (self.player and self.player.vitals) or {}
  end
  local mp = vitals.mp or current_mp or 0
  local tp = vitals.tp or current_tp or 0

  if already_resolved ~= true and action ~= nil and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
    action = self.player:resolve_action_for_resources(action)
  end

  if action ~= nil and is_neutralized == true then
    self.disabled_slots.actions[action.action] = true
    return true
  elseif action ~= nil then
    local action_type = lc(action.type or '')
    local action_key = lc(action.action or '')

    if action_type == 'ma' then
      if is_spell_learned(action.action) ~= true then
        self.disabled_slots.actions[action.action] = true
        return true
      elseif is_silenced == true then
        self.disabled_slots.actions[action.action] = true
        return true
      elseif is_spell_usable(action.action, self.player) ~= true then
        self.disabled_slots.actions[action.action] = true
        return true
      else
        local skill = database[action_type] and database[action_type][action_key] or nil
        if skill and mp < self:get_true_mp_cost(skill) then
          self.disabled_slots.no_vitals[action.action] = true
          return true
        end
        local nin_tool = nin_tool_requirements[action_key]
        if nin_tool then
          local tool_count = self.player and self.player.item_count and (self.player.item_count[nin_tool] or 0) or 0
          if tool_count < 1 then
            self.disabled_slots.no_vitals[action.action] = true
            return true
          end
        end
        self.disabled_slots.actions[action.action] = false
        self.disabled_slots.no_vitals[action.action] = false
        return false
      end
    end

    if action_type == 'ws' or action_type == 'ja' or action_type == 'pet' then
      if is_amnesiad == true then
        self.disabled_slots.actions[action.action] = true
        return true
      elseif action_type == 'ws' and can_ws == false then
        self.disabled_slots.actions[action.action] = true
        return true
      elseif action_type == 'ja' and is_job_ability_usable(action.action, self.player) ~= true then
        self.disabled_slots.actions[action.action] = true
        return true
      else
        local skill = database[action_type] and database[action_type][action_key] or nil
        local true_mp_cost = skill and self:get_true_mp_cost(skill) or 0
        if action_type == 'ja' and skill and skill.type ~= 'Monster' and true_mp_cost > 0 and mp < true_mp_cost then
          self.disabled_slots.no_vitals[action.action] = true
          return true
        elseif action_type == 'ja' and skill and skill.tpcost ~= nil and skill.tpcost ~= 0 and skill.prefix ~= '/pet' and tp < self:get_true_tp_cost(skill) then
          self.disabled_slots.no_vitals[action.action] = true
          return true
        elseif skill and tostring(skill.oid or '') == '72' and not can_pet_ws then
          self.disabled_slots.actions[action.action] = true
          return true
        end

        if action_type == 'ja' and skill and tonumber(skill.oid) == 296 and mp < 100 then
          self.disabled_slots.no_vitals[action.action] = true
          return true
        end

        if action_type == 'ja' and skill and skill.type == 'BloodPactRage'
            and self.player and self.player.has_astral_flow then
          local min_mp = (self.player.main_job_level or 1) * 2
          if mp < min_mp then
            self.disabled_slots.no_vitals[action.action] = true
            return true
          end
        end

        if skill and (tonumber(skill.oid) == 85 or tonumber(skill.oid) == 387) then
          if not (self.player and self.player.has_jug == true) then
            self.disabled_slots.no_vitals[action.action] = true
            return true
          end
        end

        if skill and pup_oil_ability_ids[tonumber(skill.oid)] then
          local eq = windower.ffxi.get_items()
          local oil_count = 0
          if eq and eq.equipment and eq.equipment.ammo_bag and eq.equipment.ammo
              and not (eq.equipment.ammo_bag == 0 and eq.equipment.ammo == 0) then
            local ammo_item = windower.ffxi.get_items(eq.equipment.ammo_bag, eq.equipment.ammo)
            if ammo_item and automaton_oil_ids[ammo_item.id] then
              oil_count = ammo_item.count or 1
            end
          end
          if oil_count < 1 then
            self.disabled_slots.no_vitals[action.action] = true
            return true
          end
        end

        self.disabled_slots.actions[action.action] = false
        self.disabled_slots.no_vitals[action.action] = false
        return false
      end
    elseif action_type == 'choice' and action_key == 'pup_maneuvers' then
      if not (self.player and self.player.has_animator == true)
          or (self.player and self.player.has_overload == true) then
        self.disabled_slots.actions[action.action] = true
        return true
      end
      self.disabled_slots.no_vitals[action.action] = false
      self.disabled_slots.actions[action.action] = false
      return false
    elseif action_type == 'choice' and action_key == 'bst_ready' then
      self.disabled_slots.no_vitals[action.action] = false
      self.disabled_slots.actions[action.action] = false
      return false
    elseif action_type == 'choice' and action_key == 'ja_type_bloodpactrage'
        and self.player and self.player.has_astral_flow then
      local min_mp = (self.player.main_job_level or 1) * 2
      if mp < min_mp then
        self.disabled_slots.no_vitals[action.action] = true
        return true
      end
      self.disabled_slots.no_vitals[action.action] = false
      self.disabled_slots.actions[action.action] = false
      return false
    else
      self.disabled_slots.actions[action.action] = false
      return false
    end
  end

  return false
end

function ui:check_if_burstable(action)
  if not action or not self.theme.highlight_magic_burst then
    return false
  end

  local action_key = action.action and lc(action.action) or nil
  if not action_key or not database[action.type] then
    return false
  end

  if action.type == 'ma' then
    local skill = database[action.type][action_key]
    local mb_elements = nil

    if skill and (skill.type ~= "BlueMagic" or (skill.type == "BlueMagic" and is_burst_affinity)) then
      if not skill.targets['Enemy'] then
        return false
      end

      if self.current_target then
        mb_elements = skillchains:get_magic_burst_elements(self.current_target.id)
        return (mb_elements and mb_elements[skill.element]), skill.element
      else
        return false
      end
    end
  elseif action.type == 'ja' then
    local skill = database[action.type][action_key]
    local mb_elements = nil

    if not skill then
      return false
    end

    if skill.prefix == '/pet' and skill.type == 'BloodPactRage' then
      local bloodpact = htb_bloodpacts[tonumber(skill.oid)]
      if bloodpact and bloodpact.damage == 'magic' then
        if self.current_target then
          mb_elements = skillchains:get_magic_burst_elements(self.current_target.id)
          return (mb_elements and mb_elements[tonumber(skill.element)]), skill.element
        else
          return false
        end
      end
    end
  end

  return false
end

function ui:check_if_chainable(action)
  if not action or not self.theme.highlight_skill_chain then
    return false
  end

  local action_key = action.action and lc(action.action) or nil
  if not action_key or not database[action.type] then
    return false
  end

  if action.type == 'ja' or action.type == 'ws' then
    local skill = database[action.type][action_key]

    if not skill then
      return false
    end

    if skill.prefix == '/pet' and skill.type == 'Monster' then
      if not database['bstpet'] then
        return false
      end

      skill = database['bstpet'][action_key]

      if not skill then
        return false
      end
    end

    local potentials = nil

    if skill.sc_a or skill.sc_b or skill.sc_c then
      if self.current_target then
        potentials = skillchains:get_potential_skillchains(self.current_target.id)
      else
        return false
      end
    end

    if potentials and next(potentials) ~= nil then
      if skill.sc_a and potentials[skill.sc_a] then
        return true, potentials[skill.sc_a]
      elseif skill.sc_b and potentials[skill.sc_b] then
        return true, potentials[skill.sc_b]
      elseif skill.sc_c and potentials[skill.sc_c] then
        return true, potentials[skill.sc_c]
      end
    end
  elseif action.type == "ma" then
    local skill = database[action.type][action_key]

    if skill then
      if skill.type == "BlueMagic" and is_chain_affinity then
        if not skill.targets['Enemy'] then
          return false
        end

        local blue_sc_data = htb_blue_spells[tonumber(skill.id)]

        if blue_sc_data then
          local potentials = nil
          if blue_sc_data.skillchain_a or blue_sc_data.skillchain_b or blue_sc_data.skillchain_c then
            if self.current_target then
              potentials = skillchains:get_potential_skillchains(self.current_target.id)
            else
              return false
            end
          end

          if potentials and next(potentials) ~= nil then
            if blue_sc_data.skillchain_a and potentials[blue_sc_data.skillchain_a] then
              return true, potentials[blue_sc_data.skillchain_a]
            elseif blue_sc_data.skillchain_b and potentials[blue_sc_data.skillchain_b] then
              return true, potentials[blue_sc_data.skillchain_b]
            elseif blue_sc_data.skillchain_c and potentials[blue_sc_data.skillchain_c] then
              return true, potentials[blue_sc_data.skillchain_c]
            end
          end
        end
      elseif is_immanence and skill.type == "BlackMagic" and skill.targets["Enemy"] then
        local potentials = nil

        if self.current_target then
          potentials = skillchains:get_potential_skillchains(self.current_target.id)

          local property = nil

          if skill.element == 0 then
            property = "Liquefaction"
          elseif skill.element == 1 then
            property = "Induration"
          elseif skill.element == 2 then
            property = "Detonation"
          elseif skill.element == 3 then
            property = "Scission"
          elseif skill.element == 4 then
            property = "Impaction"
          elseif skill.element == 5 then
            property = "Reverberation"
          elseif skill.element == 6 then
            property = "Transfixion"
          elseif skill.element == 7 then
            property = "Compression"
          end

          if potentials and next(potentials) ~= nil then
            if property and potentials[property] then
              return true, potentials[property]
            end
          end
        else
          return false
        end
      end
    end
  end

  return false
end

local scholar_stratagem_names = {
  ['Penury'] = true, ['Celerity'] = true, ['Rapture'] = true, ['Accession'] = true,
  ['Parsimony'] = true, ['Alacrity'] = true, ['Ebullience'] = true, ['Manifestation'] = true,
  ['Perpetuance'] = true, ['Immanence'] = true,
}

function ui:is_scholar_stratagem(skill)
  if skill == nil then return false end
  if skill.type == 'Scholar' then return true end
  if skill.name and scholar_stratagem_names[skill.name] then return true end
  if skill.en and scholar_stratagem_names[skill.en] then return true end
  return false
end

function ui:get_scholar_max_charges()
  local main_level = self.player and self.player.main_job_id == 20 and self.player.main_job_level or 0
  local sub_level = self.player and self.player.sub_job_id == 20 and self.player.sub_job_level or 0
  local level = math.max(main_level or 0, sub_level or 0)
  local charges = 0
  if level >= 90 then charges = 5
  elseif level >= 70 then charges = 4
  elseif level >= 50 then charges = 3
  elseif level >= 30 then charges = 2
  elseif level >= 10 then charges = 1
  end
  local cap = tonumber(self.theme.scholar_max_charges_cap) or 5
  if charges > cap then charges = cap end
  if charges < 1 then charges = 1 end
  return charges
end

function ui:get_scholar_charge_info(recast_seconds)
  recast_seconds = tonumber(recast_seconds) or 0
  local max_charges = self:get_scholar_max_charges()
  local base = tonumber(self.theme.scholar_base_recharge_seconds) or 240
  local charge_time = math.max(1, math.floor(base / max_charges))

  if recast_seconds <= 0 then
    return { charges = max_charges, max_charges = max_charges, next_recast = 0, charge_time = charge_time }
  end

  local charges = max_charges - math.ceil(recast_seconds / charge_time)
  if charges < 0 then charges = 0 end
  if charges > max_charges then charges = max_charges end

  local next_recast = 0
  if charges <= 0 then
    next_recast = recast_seconds - ((max_charges - 1) * charge_time)
    if next_recast < 1 then next_recast = charge_time end
  end

  return { charges = charges, max_charges = max_charges, next_recast = next_recast, charge_time = charge_time }
end

function ui:check_all_choice_entries_blocked(group_id)
  local flat = choice_groups:get_flat_leaf_entries(group_id)
  if flat == nil or #flat == 0 then return false, 0 end

  local recast_tables = self.recasts
  local checked = 0
  local longest = 0
  local current_tp = self:get_current_tp()
  local fm = self.player and self.player:get_finishing_moves() or 0

  for _, entry in ipairs(flat) do
    local at = tostring(entry.type or ''):lower()
    if at == 'ja' or at == 'ma' then
      checked = checked + 1
      local on_cd, rt = self:get_action_cooldown_info(entry, recast_tables)
      if not on_cd then
        local skill = database[at] and database[at][tostring(entry.action or ''):lower()] or nil
        local tp_blocked = false
        local fm_blocked = false
        if skill then
          local tp_cost = self:get_true_tp_cost(skill)
          if tp_cost > 0 and current_tp < tp_cost then tp_blocked = true end
          local oid = tonumber(skill.oid)
          local fm_cost = 0
          if oid == 209 or oid == 313 then fm_cost = 2
          elseif oid == 314 then fm_cost = 3
          elseif oid == 264 then fm_cost = 1
          end
          if fm_cost > 0 and fm < fm_cost then fm_blocked = true end
        end
        if not tp_blocked and not fm_blocked then return false, 0 end
      end
      local t = tonumber(rt) or 0
      if t > longest then longest = t end
    elseif at == 'ws' then
      checked = checked + 1
      if not is_amnesiad and can_ws then return false, 0 end
    end
  end

  if checked > 0 then return true, longest end
  return false, 0
end

function ui:inner_check_recasts(player_hotbar, environment, player_vitals, row, slot)
  local env_table = player_hotbar and environment and player_hotbar[environment] or nil
  local row_table = env_table and env_table[hb_key(row)] or nil
  if row_table == nil then return end
  local action = nil
  if self.player ~= nil and self.player.get_visible_action ~= nil then
    action = self.player:get_visible_action(environment, row, slot)
  else
    action = row_table[slot_key(slot)]
  end
  if action ~= nil and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
    action = self.player:resolve_action_for_resources(action)
  end
  local is_disabled = self:check_and_set_disable(action, true, player_vitals)
  local is_magic_burstable, element = self:check_if_burstable(action)
  local is_skill_chainable, chain_prop = self:check_if_chainable(action)

  if action == nil then
    self:clear_recast(row, slot)
    if self.theme.hide_empty_slots == true or self:empty_row_hidden(environment, row) then
      self:hide_recast(row, slot)
    end
    return
  elseif RECAST_ACTION_TYPES:contains(action.type) and action ~= nil then
    local skill = nil
    local action_recasts = nil
    local in_cooldown = false
    local is_outlined = true
    local is_in_seconds = false
    local recast_time = 0

    if (action.type == 'ja' or action.type == 'ma') then
      skill = database[action.type] and database[action.type][lc(action.action or '')] or nil
      action_recasts = self.recasts[action.type] or {}
    end

    local ammo_item = nil
    if action.type == 'ja' and skill and self.theme.hide_action_cost ~= true then
      local oid = tonumber(skill.oid)
      if oid == 170 or ja_ammo_slot_display_ids[oid] or pup_oil_ability_ids[oid] then
        local eq = windower.ffxi.get_items()
        if eq and eq.equipment and eq.equipment.ammo_bag and eq.equipment.ammo
            and not (eq.equipment.ammo_bag == 0 and eq.equipment.ammo == 0) then
          ammo_item = windower.ffxi.get_items(eq.equipment.ammo_bag, eq.equipment.ammo)
        end
      end
    end

    in_cooldown, recast_time = self:get_action_cooldown_info(action, self.recasts)
    if action ~= nil and action.action ~= nil then
      self.disabled_slots.on_cooldown[action.action] = in_cooldown == true
    end

    if (self.theme.highlight_magic_burst and is_magic_burstable) or (self.theme.highlight_skill_chain and is_skill_chainable) then
      self.outlined_slots[action.action] = true
      is_outlined = true
    else
      self.outlined_slots[action.action] = false
      is_outlined = false
    end

    if in_cooldown == true then
      local raw_time = recast_time
      local recast_display = self:calc_recast_time(recast_time, action.type)
      self:show_recast(row, slot, recast_display, raw_time)
      self:disable_slot(row, slot, action)
      self:disable_outline(row, slot, action)
    elseif is_disabled == true then
      self:clear_recast(row, slot)
      self:disable_slot(row, slot, action)
      self:disable_outline(row, slot, action)
    else
      self:clear_recast(row, slot)
      self:enable_slot(row, slot, action)

      if is_outlined then
        self:enable_outline(row, slot, action)

        if self.theme.highlight_skill_chain and is_skill_chainable and chain_prop then
          local outline = CHAIN_PROP_OUTLINE[chain_prop.property]
          if outline then self:outline_path(row, slot, outline) end
        elseif self.theme.highlight_magic_burst and is_magic_burstable and element then
          local outline = ELEMENT_OUTLINE[element]
          if outline then self:outline_path(row, slot, outline) end
        end
      else
        self:disable_outline(row, slot, action)
      end
    end

    if action.type == 'ja' and skill and tonumber(skill.oid) == 170
        and self.theme.hide_action_cost ~= true then
      local angon_count = 0
      if ammo_item and ammo_item.id == 18259 then
        angon_count = ammo_item.count or 1
      end
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if angon_count == 0 then
          row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        row_data.slot_cost[slot]:text(tostring(angon_count))
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ja' and skill and tonumber(skill.oid) == 335
        and self.theme.hide_action_cost ~= true then
      local shadows = self.player and self.player.utsusemi_shadows or 0
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if shadows > 0 then
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          row_data.slot_cost[slot]:text(tostring(shadows))
          row_data.slot_cost[slot]:show()
        else
          row_data.slot_cost[slot]:text('')
        end
      end
    end

    if action.type == 'ja' and skill and tonumber(skill.oid) == 296
        and self.theme.hide_action_cost ~= true then
      local current_mp = self:get_current_mp()
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if current_mp < 100 then
          row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          row_data.slot_cost[slot]:color(self.theme.mp_cost_color_red, self.theme.mp_cost_color_green, self.theme.mp_cost_color_blue)
        end
        row_data.slot_cost[slot]:text('100')
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ja' and skill and ja_ammo_slot_display_ids[tonumber(skill.oid)]
        and self.theme.hide_action_cost ~= true then
      local ammo_count = 0
      if ammo_item and ammo_item.id and ammo_item.id ~= 0 then
        ammo_count = ammo_item.count or 1
      end
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if ammo_count == 0 then
          row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        row_data.slot_cost[slot]:text(tostring(ammo_count))
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ja' and skill and pup_oil_ability_ids[tonumber(skill.oid)]
        and self.theme.hide_action_cost ~= true then
      local oil_count = 0
      if ammo_item and automaton_oil_ids[ammo_item.id] then
        oil_count = ammo_item.count or 1
      end
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if oil_count == 0 then
          row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        row_data.slot_cost[slot]:text(tostring(oil_count))
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ja' and skill and cor_card_display[tonumber(skill.oid)]
        and self.theme.hide_action_cost ~= true then
      local card_name = cor_card_display[tonumber(skill.oid)]
      local card_count = self.player and self.player.item_count and (self.player.item_count[card_name] or 0) or 0
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        if card_count == 0 then
          row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        row_data.slot_cost[slot]:text(tostring(card_count))
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ja' and skill and tonumber(skill.oid) == 56
        and self.theme.hide_action_cost ~= true then
      local expended = self.player and self.player.scavenge_ammo_expended or 0
      local rng_level = 0
      if self.player then
        if self.player.main_job == 'RNG' then
          rng_level = self.player.main_job_level or 0
        else
          rng_level = self.player.sub_job_level or 0
        end
      end
      local row_data = self.hotbars[row]
      if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
        local recovered = expended > 0 and math.floor(expended * (rng_level / 200)) or 0
        local display = expended > 0 and (tostring(recovered) .. '~') or '0'
        row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        row_data.slot_cost[slot]:text(display)
        row_data.slot_cost[slot]:show()
      end
    end

    if action.type == 'ma' and self.theme.hide_action_cost ~= true then
      local action_key_lower = tostring(action.action or ''):lower()
      local nin_tool = nin_tool_requirements[action_key_lower]
      if nin_tool then
        local tool_count = self.player and self.player.item_count and (self.player.item_count[nin_tool] or 0) or 0
        local row_data = self.hotbars[row]
        if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
          if tool_count < 1 then
            row_data.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
          else
            row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          end
          row_data.slot_cost[slot]:text(tostring(tool_count))
          row_data.slot_cost[slot]:show()
        end
      end
    end
    if action.type == 'ja' then
      self:apply_overload_pct_display(row, slot, tostring(action.action or ''):lower())
    end

  elseif action.type == 'autora' then
    self:clear_recast(row, slot)
    local p = self.player
    local rw = p and (p.current_range_weapon or 0) or 0
    local needs_ammo = rw == 25 or rw == 26
    local has_ammo = p and p.has_ranged_ammo == true
    local ammo_skill = p and (p.ammo_skill or 0) or 0
    local has_throwable_ammo = rw == 0 and has_ammo and ammo_skill == 27
    local has_range_weapon = rw == 25 or rw == 26 or rw == 27

    if not has_range_weapon and not has_throwable_ammo then
      self.hotbars[row].slot_icons[slot]:alpha(0)
      self.hotbars[row].slot_texts[slot]:hide()
      self.hotbars[row].slot_cost[slot]:text('')
      self.hotbars[row].slot_cost[slot]:hide()
      self.hotbars[row].slot_outline[slot]:hide()
      return
    end

    local show_count = needs_ammo or has_throwable_ammo
    self:toggle_slot_opacity(row, slot, not (needs_ammo and not has_ammo))

    if show_count and p and self.theme.hide_action_cost ~= true then
      local count = p.ranged_ammo_count or 0
      local hb = self.hotbars[row]
      if hb and hb.slot_cost and hb.slot_cost[slot] then
        if count == 0 then
          hb.slot_cost[slot]:color(self.theme.tp_cost_color_red, self.theme.tp_cost_color_green, self.theme.tp_cost_color_blue)
        else
          hb.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
        end
        hb.slot_cost[slot]:text(tostring(count))
        hb.slot_cost[slot]:show()
      end
    end

    if p and p.autora_active then
      local frame_idx = (self.current_tick * 4) % 60
      local frame_path = HTB_ART .. 'icons/autora/frame_' .. string.format('%02d', frame_idx) .. '.png'
      self.hotbars[row].slot_outline[slot]:path(frame_path)
      self.hotbars[row].slot_outline[slot]:size(self:bar_image_width(row) + 6, self:bar_image_height(row) + 6)
      self.hotbars[row].slot_outline[slot]:fit(false)
      self.hotbars[row].slot_outline[slot]:color(255, 255, 255)
      self.hotbars[row].slot_outline[slot]:alpha(255)
      self.hotbars[row].slot_outline[slot]:show()
    else
      self.hotbars[row].slot_outline[slot]:path(HTB_ART .. 'other/blank.png')
      self.hotbars[row].slot_outline[slot]:color(255, 255, 255)
      self.hotbars[row].slot_outline[slot]:hide()
    end
  elseif action.type == 'choice' then
    local recast_id = choice_groups:get_group_shared_recast_id(action.action)
    if recast_id then
      local ability_recasts = (self.recasts and self.recasts.ja) or windower.ffxi.get_ability_recasts() or {}
      local recast_time = tonumber(ability_recasts[recast_id] or 0) or 0
      if recast_time > 0 then
        self.disabled_slots.on_cooldown[action.action] = true
        self:show_recast(row, slot, self:calc_recast_time(recast_time, 'ja'), recast_time)
        self:disable_slot(row, slot, action)
      else
        self.disabled_slots.on_cooldown[action.action] = false
        self:clear_recast(row, slot)
        self:enable_slot(row, slot, action)
      end
    elseif action.action == 'sch_stratagems' then
      local ability_recasts = (self.recasts and self.recasts.ja) or windower.ffxi.get_ability_recasts() or {}
      local penury_skill = database.ja and database.ja['penury'] or nil
      local charge_info = { charges = 0, max_charges = 0, next_recast = 0 }
      if penury_skill then
        local raw_recast = tonumber(ability_recasts[tonumber(penury_skill.icon)] or 0) or 0
        charge_info = self:get_scholar_charge_info(raw_recast)
      end

      local no_arts     = choice_groups:is_empty(self.player, action.action)
      local no_charges  = charge_info.charges <= 0

      if no_arts or no_charges then
        self.disabled_slots.on_cooldown[action.action] = true
        self:disable_slot(row, slot, action)
        if not no_arts and charge_info.next_recast and charge_info.next_recast > 0 then
          self:show_recast(row, slot, self:calc_recast_time(charge_info.next_recast, 'ja'), charge_info.next_recast)
        else
          self:clear_recast(row, slot)
        end
      else
        self.disabled_slots.on_cooldown[action.action] = false
        self:clear_recast(row, slot)
        self:enable_slot(row, slot, action)
      end

      if self.theme.hide_action_cost ~= true then
        local row_data = self.hotbars[row]
        if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
          row_data.slot_cost[slot]:text(tostring(charge_info.charges))
          row_data.slot_cost[slot]:show()
        end
      end
    elseif action.action == 'bst_ready' then
      local bst_ability_recasts = (self.recasts and self.recasts.ja) or windower.ffxi.get_ability_recasts() or {}
      local bst_cooldown = tonumber(bst_ability_recasts[102]) or 0
      local bst_charge_sec = tonumber(self.theme.bst_ready_charge_seconds) or bst_charge_time or 30
      local bst_charges = math.max(0, math.min(3, math.floor(((bst_charge_sec * 3) - bst_cooldown) / bst_charge_sec)))

      if bst_charges <= 0 then
        self.disabled_slots.on_cooldown[action.action] = true
        self:disable_slot(row, slot, action)
        local next_recast = bst_cooldown % bst_charge_sec
        if next_recast == 0 then next_recast = bst_charge_sec end
        self:show_recast(row, slot, self:calc_recast_time(next_recast, 'ja'), next_recast)
      else
        self.disabled_slots.on_cooldown[action.action] = false
        self:clear_recast(row, slot)
        self:enable_slot(row, slot, action)
      end

      if self.theme.hide_action_cost ~= true then
        local row_data = self.hotbars[row]
        if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          row_data.slot_cost[slot]:text(tostring(bst_charges))
          row_data.slot_cost[slot]:show()
        end
      end
    elseif choice_groups:is_ws_group(action.action) then
      if is_amnesiad or not can_ws then
        self.disabled_slots.on_cooldown[action.action] = true
        self:disable_slot(row, slot, action)
        self:clear_recast(row, slot)
        self.outlined_slots[action.action] = false
        self:disable_outline(row, slot, action)
      else
        self.disabled_slots.on_cooldown[action.action] = false
        self:clear_recast(row, slot)
        self:enable_slot(row, slot, action)
        if self.theme.highlight_skill_chain then
          local any_chainable = false
          local first_chain_prop = nil
          local group_actions = choice_groups:resolve(self.player, action.action)
          for _, ws_action in ipairs(group_actions or {}) do
            if ws_action and ws_action.type == 'ws' then
              local chainable, chain_prop = self:check_if_chainable(ws_action)
              if chainable then
                any_chainable = true
                if not first_chain_prop then first_chain_prop = chain_prop end
              end
            end
          end
          if any_chainable then
            self.outlined_slots[action.action] = true
            self:enable_outline(row, slot, action)
            if first_chain_prop then
              local outline = CHAIN_PROP_OUTLINE[first_chain_prop.property]
              if outline then self:outline_path(row, slot, outline) end
            end
          else
            self.outlined_slots[action.action] = false
            self:disable_outline(row, slot, action)
          end
        else
          self.outlined_slots[action.action] = false
          self:disable_outline(row, slot, action)
        end
      end
    else
      local rune_forced_off = false
      if RUN_RUNE_REQ[tostring(action.action or '')] then
        if self:get_rune_count() == 0 then
          rune_forced_off = true
          self.disabled_slots.on_cooldown[action.action] = true
          self:disable_slot(row, slot, action)
          self:clear_recast(row, slot)
        end
      end

      local cor_quick_draw_forced_off = false
      if tostring(action.action or '') == 'cor_quick_draw' then
        local has_any_card = false
        for _, card_name in pairs(cor_card_display) do
          if self.player and self.player.item_count and (self.player.item_count[card_name] or 0) > 0 then
            has_any_card = true
            break
          end
        end
        if not has_any_card then
          cor_quick_draw_forced_off = true
          self.disabled_slots.no_vitals[action.action] = true
          self:disable_slot(row, slot, action)
          self:clear_recast(row, slot)
        else
          self.disabled_slots.no_vitals[action.action] = false
        end
      end

      local dnc_fl_forced_off = false
      local dnc_fl_fm_req = DNC_FL_FM_MIN[tostring(action.action or '')]
      if dnc_fl_fm_req then
        local current_fm = self.player and self.player:get_finishing_moves() or 0
        if current_fm < dnc_fl_fm_req then
          dnc_fl_forced_off = true
          self.disabled_slots.no_vitals[action.action] = true
          self:disable_slot(row, slot, action)
          self:clear_recast(row, slot)
        else
          self.disabled_slots.no_vitals[action.action] = false
        end
      end

      local pup_maneuver_forced_off = false
      if tostring(action.action or '') == 'pup_maneuvers' then
        if not (self.player and self.player.has_animator == true)
            or (self.player and self.player.has_overload == true) then
          pup_maneuver_forced_off = true
          self.disabled_slots.actions[action.action] = true
          self:disable_slot(row, slot, action)
          self:clear_recast(row, slot)
        else
          self.disabled_slots.actions[action.action] = false
        end
      end

      if not rune_forced_off and not cor_quick_draw_forced_off and not dnc_fl_forced_off and not pup_maneuver_forced_off then
        local all_blocked, longest_recast = self:check_all_choice_entries_blocked(action.action)
        if all_blocked then
          self.disabled_slots.on_cooldown[action.action] = true
          self:disable_slot(row, slot, action)
          if longest_recast > 0 then
            self:show_recast(row, slot, self:calc_recast_time(longest_recast, 'ja'), longest_recast)
          else
            self:clear_recast(row, slot)
          end
        else
          self.disabled_slots.on_cooldown[action.action] = false
          self:clear_recast(row, slot)
          self:enable_slot(row, slot, action)
        end
      end

      if self.theme.hide_action_cost ~= true and DNC_FL_FM_MIN[tostring(action.action or '')] then
        local fm = self.player and self.player:get_finishing_moves() or 0
        local row_data = self.hotbars[row]
        if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          row_data.slot_cost[slot]:text(tostring(fm))
          row_data.slot_cost[slot]:show()
        end
      end

      if self.theme.hide_action_cost ~= true and tostring(action.action or '') == 'run_runes' then
        local rc = self:get_rune_count()
        local row_data = self.hotbars[row]
        if row_data and row_data.slot_cost and row_data.slot_cost[slot] then
          row_data.slot_cost[slot]:color(count_color[1], count_color[2], count_color[3])
          row_data.slot_cost[slot]:text(tostring(rc))
          row_data.slot_cost[slot]:show()
        end
      end

      if self.theme.highlight_magic_burst and choice_groups:is_magic_group(action.action) then
        local any_burstable = false
        local first_element = nil
        local group_actions = choice_groups:resolve(self.player, action.action)
        for _, ma_action in ipairs(group_actions or {}) do
          if ma_action and ma_action.type == 'ma' then
            local burstable, element = self:check_if_burstable(ma_action)
            if burstable then
              any_burstable = true
              if not first_element then first_element = element end
            end
          end
        end
        if any_burstable then
          self.outlined_slots[action.action] = true
          self:enable_outline(row, slot, action)
          if first_element then
            local outline = ELEMENT_OUTLINE[first_element]
            if outline then self:outline_path(row, slot, outline) end
          end
        else
          self.outlined_slots[action.action] = false
          self:disable_outline(row, slot, action)
        end
      end

    end
  end
end

function ui:clear_recast(r, s)
  if not (self.hotbars[r] and self.hotbars[r].slot_recasts and self.hotbars[r].slot_recasts[s]) then return end
  self.hotbars[r].slot_recasts[s]:hide()
  self.hotbars[r].slot_keys[s]:show()
  self.hotbars[r].slot_recast_texts[s]:text('')
  if self.sweep_active[r] then self.sweep_active[r][s] = nil end
  if self.slot_max_recasts[r] then self.slot_max_recasts[r][s] = nil end
end

function ui:hide_recast(r, s)
  if not (self.hotbars[r] and self.hotbars[r].slot_recasts and self.hotbars[r].slot_recasts[s]) then return end
  self.hotbars[r].slot_recasts[s]:hide()
  self.hotbars[r].slot_keys[s]:hide()
  self.hotbars[r].slot_recast_texts[s]:text('')
  if self.sweep_active[r] then self.sweep_active[r][s] = nil end
  if self.slot_max_recasts[r] then self.slot_max_recasts[r][s] = nil end
end

function ui:show_recast(r, s, recast_display, raw_recast_time)
  if not (self.hotbars[r] and self.hotbars[r].slot_recasts and self.hotbars[r].slot_recasts[s]) then return end

  if raw_recast_time ~= nil then
    self.slot_max_recasts[r] = self.slot_max_recasts[r] or {}
    local stored_max = self.slot_max_recasts[r][s] or 0
    if raw_recast_time > stored_max then
      self.slot_max_recasts[r][s] = raw_recast_time
    end
    local max_recast = self.slot_max_recasts[r][s] or raw_recast_time
    if max_recast > 0 then
      local remaining_fraction = math.min(1.0, raw_recast_time / max_recast)
      local progress = 1.0 - remaining_fraction
      local frame_idx = math.max(0, math.min(59, math.floor(progress * 59)))
      local frame_path = HTB_ART .. 'icons/sweep/frame_' .. string.format('%02d', frame_idx) .. '.png'
      self.hotbars[r].slot_recasts[s]:path(frame_path)
      self.hotbars[r].slot_recasts[s]:size(self:bar_image_width(r), self:bar_image_height(r))
      self.hotbars[r].slot_recasts[s]:fit(false)
      self.hotbars[r].slot_recasts[s]:alpha(210)
      self.sweep_active[r] = self.sweep_active[r] or {}
      self.sweep_active[r][s] = true
    end
  end

  self.hotbars[r].slot_recasts[s]:show()

  local display_str = tostring(recast_display or '')
  local t = self.theme
  local text_obj = self.hotbars[r].slot_recast_texts[s]
  self.recast_cache = self.recast_cache or {}
  self.recast_cache[r] = self.recast_cache[r] or {}
  self.recast_w_cache = self.recast_w_cache or {}
  local rc = self.recast_cache[r][s]
  local icon_x = self.hotbars[r].slot_recasts[s]:pos_x()
  local icon_y = self.hotbars[r].slot_recasts[s]:pos_y()
  text_obj:text(display_str)
  text_obj:show()
  local biw, bih = self:bar_image_width(r), self:bar_image_height(r)
  local size  = math.floor((t.font_size_recasts or 11) * (t.slot_icon_scale or 1) * self:bar_scale(r) + 0.5)
  local shape = display_str:gsub('%d', '0') .. '@' .. size
  local cw = self.recast_w_cache[shape]
  if cw then
    text_obj:size(cw.font)
    text_obj:pos(icon_x + math.floor((biw - cw.w) / 2 + 0.5), icon_y + math.floor((bih - cw.h) / 2 + 0.5))
  elseif rc and rc.str == display_str and #display_str > 0 then
    local text_w, text_h = text_obj:extents()
    text_w, text_h = text_w or 0, text_h or 0
    if text_w > 0 then
      local avail_w = biw - math.floor(biw * 0.14)
      local avail_h = bih - math.floor(bih * 0.12)
      local fit = 1
      if text_w > avail_w then fit = avail_w / text_w end
      if text_h > 0 and text_h * fit > avail_h then fit = math.min(fit, avail_h / text_h) end
      local font = math.max(6, math.floor(size * fit + 0.5))
      local w, h = math.floor(text_w * fit + 0.5), math.floor(text_h * fit + 0.5)
      self.recast_w_cache[shape] = { w = w, h = h, font = font }
      text_obj:size(font)
      text_obj:pos(icon_x + math.floor((biw - w) / 2 + 0.5), icon_y + math.floor((bih - h) / 2 + 0.5))
    else
      text_obj:pos(-9999, -9999)
    end
  else
    text_obj:size(size)
    self.recast_cache[r][s] = { str = display_str }
    text_obj:pos(-9999, -9999)
  end
  self.hotbars[r].slot_keys[s]:hide()
end

function ui:calc_recast_time(time, type)
  time = math.max(0, math.ceil(tonumber(time) or 0))
  if time >= 60 then
    return string.format('%dm', math.ceil(time / 60))
  end
  return tostring(time)
end

function ui:check_recasts(player_hotbar, environment, player_vitals)
  self.current_tick = self.current_tick + 1

  ui.recasts['ja'] = windower.ffxi.get_ability_recasts() or {}
  ui.recasts['ma'] = spell_recasts_seconds()
  ui.current_target = windower.ffxi.get_mob_by_target('t')

  local visible_count = (environment == 'field' and self.theme.field_visible_hotbar_count) or self.theme.visible_hotbar_count or self.theme.rows
  local henv = (environment == 'field') and 'field' or 'battle'
  local hidden_set = (self.theme.hidden_bars and self.theme.hidden_bars[henv]) or {}
  for h = 1, self.theme.rows, 1 do
    if h <= visible_count and (not hidden_set[h] or self.theme.hud_show_all_bars) then
      for i = 1, self.theme.columns, 1 do
        self:inner_check_recasts(player_hotbar, environment, player_vitals, h, i)
      end
    end
  end

  if self:is_choice_bar_active() and self.choice_bar.row > 0 then
    local cb_row = self.choice_bar.row
    for i = 1, self.theme.columns do
      local action = self.choice_bar.page_actions[i]
      if action == nil then
        self:clear_recast(cb_row, i)
      elseif action.type == 'ja' or action.type == 'ma' then
        local on_cooldown, recast_time = self:get_action_cooldown_info(action, self.recasts)
        self:update_mp_cost(cb_row, i, action)
        local should_disable = on_cooldown
        if not should_disable and action.type == 'ja' and self.player and self.player.has_astral_flow then
          local skill = database['ja'] and database['ja'][tostring(action.action or ''):lower()] or nil
          if skill and skill.type == 'BloodPactRage' then
            local cur_mp = self:get_current_mp()
            local min_mp = (self.player.main_job_level or 1) * 2
            should_disable = cur_mp < min_mp
          end
        end
        if on_cooldown then
          self:show_recast(cb_row, i, self:calc_recast_time(recast_time, action.type), recast_time)
        else
          self:clear_recast(cb_row, i)
        end
        if should_disable then
          self:disable_slot(cb_row, i, action)
        else
          self:enable_slot(cb_row, i, action)
        end

        if action.type == 'ja' then
          self:apply_overload_pct_display(cb_row, i, tostring(action.action or ''):lower())
        elseif action.type == 'ma' and self.theme.highlight_magic_burst then
          if not should_disable then
            local burstable, element = self:check_if_burstable(action)
            if burstable then
              self.outlined_slots[action.action] = true
              self:enable_outline(cb_row, i, action)
              if element then
                local outline = ELEMENT_OUTLINE[element]
                if outline then self:outline_path(cb_row, i, outline) end
              end
            else
              self.outlined_slots[action.action] = false
              self:disable_outline(cb_row, i, action)
            end
          else
            self.hotbars[cb_row].slot_outline[i]:hide()
          end
        end
      elseif action.type == 'ws' then
        self:clear_recast(cb_row, i)
        if is_amnesiad or not can_ws then
          self:disable_slot(cb_row, i, action)
          self.hotbars[cb_row].slot_outline[i]:hide()
        else
          self:enable_slot(cb_row, i, action)
          if self.theme.highlight_skill_chain then
            local chainable, chain_prop = self:check_if_chainable(action)
            if chainable then
              self.outlined_slots[action.action] = true
              self:enable_outline(cb_row, i, action)
              if chain_prop then
                local outline = CHAIN_PROP_OUTLINE[chain_prop.property]
                if outline then self:outline_path(cb_row, i, outline) end
              end
            else
              self.outlined_slots[action.action] = false
              self:disable_outline(cb_row, i, action)
            end
          else
            self.hotbars[cb_row].slot_outline[i]:hide()
          end
        end
      end
    end
  elseif self.choice_bar and self.choice_bar.row and self.choice_bar.row > 0 then
    local crow = self.choice_bar.row
    if self.hotbars[crow] and self.hotbars[crow].number and self.hotbars[crow].number:visible() then
      self.hotbars[crow].number:hide()
    end
    if self.choice_page_arrows then
      if self.choice_page_arrows.prev and self.choice_page_arrows.prev:visible() then self.choice_page_arrows.prev:hide() end
      if self.choice_page_arrows.next and self.choice_page_arrows.next:visible() then self.choice_page_arrows.next:hide() end
    end
  end
end

function ui:check_hover()
  local disabled_opacity = self.theme.disabled_slot_opacity
  local enabled_opacity = 200
  local row = self.hover_icon and self.hover_icon.row or nil
  local col = self.hover_icon and self.hover_icon.col or nil
  local prev_row = self.prev_row
  local prev_col = self.prev_col

  if prev_row and prev_col
      and self.disabled_icons[prev_row]
      and self.hotbars[prev_row]
      and self.hotbars[prev_row].slot_icons
      and self.hotbars[prev_row].slot_icons[prev_col]
  then
    local opacity = self.disabled_icons[prev_row][prev_col] == 1 and disabled_opacity or enabled_opacity
    self.hotbars[prev_row].slot_icons[prev_col]:alpha(opacity)
  end

  if row and col
      and self.disabled_icons[row]
      and self.hotbars[row]
      and self.hotbars[row].slot_icons
      and self.hotbars[row].slot_icons[col]
  then
    if self.disabled_icons[row][col] == 0 then
      self.hotbars[row].slot_icons[col]:alpha(disabled_opacity)
      prev_row, prev_col = row, col
    end
  else
    prev_row, prev_col = nil, nil
  end

  self.prev_row = prev_row
  self.prev_col = prev_col
  if self.hover_icon then
    self.hover_icon.row = row
    self.hover_icon.col = col
  end
end

function ui:trigger_feedback(row, slot)
  if not self.feedback_icon or not row or not slot or not self.hotbars[row] or not self.hotbars[row].slot_icons or not self.hotbars[row].slot_icons[slot] then
    self.feedback.is_active = false
    return
  end
  self.feedback_icon:size(self:bar_image_width(row), self:bar_image_height(row))
  self.feedback_icon:pos(self:get_slot_xy(row, slot))
  self.feedback.current_opacity = self.feedback.max_opacity or 0
  self.feedback.is_active = true
end

function ui:show_feedback()
  if not self.feedback_icon then
    self.feedback.is_active = false
    return
  end

  if self.feedback.is_active and self.feedback.current_opacity and self.feedback.current_opacity > 0 then
    self.feedback.current_opacity = self.feedback.current_opacity - (self.feedback.speed or 0)
    self.feedback_icon:alpha(self.feedback.current_opacity)
    self.feedback_icon:show()
  else
    self.feedback_icon:hide()
    self.feedback.is_active = false
  end
end

function ui:hovered(x, y)
  local row, slot = nil, nil

  if self.active_environment and self.active_environment['battle'] then
    local pos_x = self.active_environment['battle']:pos_x()
    local pos_y = self.active_environment['battle']:pos_y() - 60
    local off_x, off_y = pos_x + 60, pos_y + 100

    if x >= pos_x and x <= off_x and y >= pos_y and y <= off_y then
      return nil, 100
    end
  end

  local player_hotbar, environment = player:get_hotbar_info_without_vitals()
  if not player_hotbar or not environment or not player_hotbar[environment] then
    return row, slot
  end

  for h = 1, self.theme.rows do
    local hotbar_table = player_hotbar[environment]['hotbar_' .. h]
    if hotbar_table then
      for i = 1, self.theme.columns do
        local action = nil
        if self.player ~= nil and self.player.get_visible_action ~= nil then
          action = self.player:get_visible_action(environment, h, i)
        else
          action = hotbar_table['slot_' .. i]
        end
        if action ~= nil then
          local pos_x, pos_y = self:get_slot_xy(h, i)
          local off_x, off_y = pos_x + self.image_width, pos_y + self.image_height

          if x >= pos_x and x <= off_x and y >= pos_y and y <= off_y then
            return h, i
          end
        end
      end
    end
  end

  return row, slot
end

count_lines = function(text)
  text = tostring(text or '')
  if text == '' then return 1 end
  local _, count = text:gsub('\n', '\n')
  return count + 1
end

fallback_action_description = function(action)
  if not action then return '' end
  local action_type = tostring(action.type or ''):lower()
  local name = tostring(action.action or '')
  local alias = tostring(action.alias or '')
  local target = tostring(action.target or '')
  local lines = {}

  local display = alias ~= '' and alias or name
  if display == '' then display = 'Hotbar Action' end
  table.insert(lines, string.format('\\cs(255,255,255)%s\\cr', display))

  if name ~= '' and name ~= display then
    table.insert(lines, 'Action: ' .. name)
  end
  if action_type ~= '' then
    table.insert(lines, 'Type: ' .. action_type)
  end
  if target ~= '' then
    table.insert(lines, 'Target: <' .. target .. '>')
  end

  if action_type == 'choice' then
    table.insert(lines, 'Opens choice group: ' .. name)
  elseif action_type == 'input' then
    table.insert(lines, 'Input: ' .. name)
  elseif action_type == 'key' then
    table.insert(lines, 'Key: ' .. name)
  elseif action_type == 'autora' then
    table.insert(lines, 'Auto Ranged Attack')
  elseif action_type == 'macro' then
    table.insert(lines, 'Macro: ' .. name)
  elseif action_type == 'gs' then
    table.insert(lines, 'GearSwap: ' .. name)
  elseif action_type == 'autoitem' then
    table.insert(lines, 'Auto item filter: ' .. name)
  end

  return table.concat(lines, '\n')
end

format_action_description = function(database, action)
  if not action then return '' end
  local action_type = tostring(action.type or ''):lower()
  local action_name = tostring(action.action or '')
  local action_target = tostring(action.target or '')
  local text_msg = ''

  if action_type == 'ma' then
    text_msg = formatter.format_spell_info(database, action_name, action_target)
  elseif action_type == 'ja' or action_type == 'pet' or action_type == 'bstpet' then
    text_msg = formatter.format_ability_info(database, action_name, action_target)
  elseif action_type == 'ws' then
    text_msg = formatter.format_ws_info(database, action_name, action_target)
  elseif action_type == 'item' then
    text_msg = formatter.format_item_info(database, action_name, action_target)
  end

  if text_msg == nil or text_msg == '' then
    text_msg = fallback_action_description(action)
  end

  return text_msg or ''
end

local HOVER_TIP_DELAY = 0.12

function ui:light_up_action(x, y, row, column)
  if not row or not column then return end
  local icon_x, icon_y = self:get_slot_xy(row, column)
  if self.hover_icon then
    self.hover_icon:size(self:bar_image_width(row) + 2, self:bar_image_height(row) + 2)
    self.hover_icon:pos(icon_x - 1, icon_y - 1)
    self.hover_icon:alpha(255)
    self.hover_icon:show()
    self.hover_icon.row = row
    self.hover_icon.col = column
  end

  if self.tip_visible and not self.current_choice and row == self.current_row and column == self.current_column then return end

  if self.tip_visible then self:hide_action_panel() end
  if self.pending_row ~= row or self.pending_col ~= column or self.pending_choice then
    self.pending_row, self.pending_col, self.pending_choice = row, column, false
    self.pending_time = os.clock()
  end
end

function ui:light_up_choice_action(x, y, slot)
  local crow = self.choice_bar.row
  local icon_x, icon_y = self:get_slot_xy(crow, slot)
  if self.hover_icon then
    self.hover_icon:size(self:bar_image_width(crow) + 2, self:bar_image_height(crow) + 2)
    self.hover_icon:pos(icon_x - 1, icon_y - 1)
    self.hover_icon:alpha(255)
    self.hover_icon:show()
    self.hover_icon.row = crow
    self.hover_icon.col = slot
  end

  if self.tip_visible and self.current_choice and crow == self.current_row and slot == self.current_column then return end
  if self.tip_visible then self:hide_action_panel() end
  if self.pending_row ~= crow or self.pending_col ~= slot or not self.pending_choice then
    self.pending_row, self.pending_col, self.pending_choice = crow, slot, true
    self.pending_time = os.clock()
  end
end

function ui:update_hover_tooltip()
  if self.tip_visible or self.description_setup then return end
  local row, column = self.pending_row, self.pending_col
  if not row or not column then return end
  if (os.clock() - (self.pending_time or 0)) < HOVER_TIP_DELAY then return end
  local is_choice = self.pending_choice
  self.pending_row, self.pending_col, self.pending_choice = nil, nil, nil
  if self.theme.show_description == false then return end

  local action = nil
  if is_choice then
    action = self:get_choice_action(column)
  else
    local player_hotbar, environment = player:get_hotbar_info_without_vitals()
    if self.player ~= nil and self.player.get_visible_action ~= nil then
      action = self.player:get_visible_action(environment, row, column)
    else
      local env_table = player_hotbar and environment and player_hotbar[environment]
      local row_table = env_table and env_table['hotbar_' .. row]
      action = row_table and row_table['slot_' .. column] or nil
    end
    if action ~= nil and self.player ~= nil and self.player.resolve_action_for_resources ~= nil then
      action = self.player:resolve_action_for_resources(action)
    end
  end
  if action == nil then return end

  local icon_path = self.hotbars[row] and self.hotbars[row].slot_icons[column]
                    and self.hotbars[row].slot_icons[column]:path()
  local info = self:build_tip_info(action, icon_path, row, column)
  if info then
    self.current_row = row
    self.current_column = column
    self.current_choice = is_choice
    self.current_action_name = tostring(action.type or '') .. ':' .. tostring(action.action or '')
    self:show_action_panel(info)
  end

  if self.hover_icon then
    self.hover_icon.row = row
    self.hover_icon.col = column
  end
end

windower.register_event('incoming chunk', update_buffs)

return ui
