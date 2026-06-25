-- XIVHotbar3 — action hotbars.
-- XivUI component. Maintainer: maybeLynd. Version: 1.
-- Based on "XIVHotbar2" v0.3 by Sabarjp, Fethur, Edeon, Akirane, Technyze.

HTB_PATH = windower.addon_path .. 'components/xivhotbar3/'
HTB_ART  = windower.addon_path .. 'assets/components/hotbar/'

file = require('files')
require('luau')

local defaults = require('components/xivhotbar3/defaults')

local settings
local hud_current_style = nil
local theme
local theme_options

first_0x050 = false

htb_skillchains = require('components/xivhotbar3/lib/skillchains')
htb_bloodpacts = require('components/xivhotbar3/lib/bloodpacts')
htb_blue_spells = require('components/xivhotbar3/lib/blue_spells')

player = require('components/xivhotbar3/lib/player')
ui = require('components/xivhotbar3/lib/ui')

local keyboard = require('components/xivhotbar3/lib/keyboard_mapper')

local move_box = require('components/xivhotbar3/lib/move_box')
local recast_cache = require('components/xivhotbar3/lib/recast_cache')
local hotbar_tools = require('components/xivhotbar3/lib/hotbar_tools')
local choice_groups = require('components/xivhotbar3/lib/choice_groups')
local hotbar_sets = require('components/xivhotbar3/lib/hotbar_sets')
local ui_bounds = require('lib/ui_bounds')

local state = {
  ready = false,
  demo = false,
  inventory_ready = false,
  inventory_loading = false,
  ext_hidden = false
}

local custom_slot_mode = {
  active = false,
  hotbar = nil,
  drag = { active = false, slot = nil, start_mouse_x = 0, start_mouse_y = 0, start_dx = 0, start_dy = 0 }
}

local reposition_mode = {
  active = false,
  bargap_mode = nil,
  drag = { active = false, start_x = 0, start_y = 0 }
}

local sets_grid_drag = { active = false, start_mouse_x = 0, start_mouse_y = 0, start_x = 0, start_y = 0 }
local hotbar_sets_start_pos = nil

local loaded = windower.ffxi.get_info().logged_in
local zoning = false
local first_load_done = false
local choice_modifier_held = false
local choice_modifier_armed = false
local choice_modifier_key_down = false
local modifier_shift_held = false
local environment_text_start_pos = nil
local inventory_count_start_pos = nil
local description_box_start_pos = nil
local trust_setup_state = nil
local pending_reload    = nil
local pending_updategen = nil
local addon_mode = nil
local PET_JOB_NAMES = { SMN=true, DRG=true, PUP=true, BST=true }
local weapon_refresh_state = { active = false, attempts_left = 0, next_time = 0, interval = 1, reason = '' }
local last_weapon_poll = 0
local last_drg_pet_poll = 0
local hotbar_blocker = nil
local choice_blocker  = nil
local htb_mouse_handler_id = nil
local htb_bounds_cache    = nil
local choice_bounds_cache = nil
local rmbPressedInHotbar = false
local lmbPressedInHotbar = false

local htb_events = {}
local event_ids  = {}
local function htb_register(...)
  htb_events[#htb_events + 1] = { n = select('#', ...), ... }
end
local function register_events()
  if #event_ids > 0 then return end
  for _, e in ipairs(htb_events) do
    event_ids[#event_ids + 1] = windower.register_event(unpack(e, 1, e.n))
  end
end
local function unregister_events()
  for i = #event_ids, 1, -1 do
    windower.unregister_event(event_ids[i])
    event_ids[i] = nil
  end
end

local function refresh_overload_state()
  local wp = windower.ffxi.get_player()
  if not wp or not wp.buffs then return end
  local found = false
  for _, bid in ipairs(wp.buffs) do
    local buff = resources and resources.buffs and resources.buffs[bid]
    if buff and buff.en and tostring(buff.en):lower():find('overload') then
      found = true
      break
    end
  end
  player.has_overload = found
end

local last_ammo_id, last_ammo_skill = nil, 0
local last_ammo_equip_at = 0
local AMMO_BAG_FIELD = {
  inventory = 'inventory',
  wardrobe1 = 'wardrobe',  wardrobe2 = 'wardrobe2', wardrobe3 = 'wardrobe3', wardrobe4 = 'wardrobe4',
  wardrobe5 = 'wardrobe5', wardrobe6 = 'wardrobe6', wardrobe7 = 'wardrobe7', wardrobe8 = 'wardrobe8',
}
local AMMO_ANY_BAGS = { 'inventory', 'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8' }

local function maybe_auto_equip_ammo(has_ammo)
  if has_ammo or not last_ammo_id then return end
  if not (theme_options and theme_options.auto_equip_ammo == true) then return end
  local now = os.clock()
  if now - last_ammo_equip_at < 3 then return end

  local items = windower.ffxi.get_items()
  local eqp = items and items.equipment
  if not eqp then return end
  local rw_skill = 0
  if eqp.range_bag and eqp.range and not (eqp.range_bag == 0 and eqp.range == 0) then
    local ritem = windower.ffxi.get_items(eqp.range_bag, eqp.range)
    local rres  = ritem and ritem.id and resources and resources.items and resources.items[ritem.id]
    rw_skill = (rres and rres.skill) or 0
  end
  local is_thrown = (last_ammo_skill or 0) == 27
  if rw_skill ~= 25 and rw_skill ~= 26 and not is_thrown then return end

  local src  = (theme_options and theme_options.ammo_source) or 'any'
  local bags = (src == 'any') and AMMO_ANY_BAGS or { AMMO_BAG_FIELD[src] or 'inventory' }
  local same_id_name, same_skill_name
  for _, field in ipairs(bags) do
    local bag = items[field]
    if type(bag) == 'table' then
      for i = 1, (bag.max or 80) do
        local it = bag[i]
        if type(it) == 'table' and it.id and it.id ~= 0 and (it.count or 0) > 0 then
          local res = resources and resources.items and resources.items[it.id]
          if res and res.slots and res.slots[3] then
            if it.id == last_ammo_id then same_id_name = res.en; break end
            if (last_ammo_skill or 0) > 0 and (res.skill or 0) == last_ammo_skill and not same_skill_name then
              same_skill_name = res.en
            end
          end
        end
      end
    end
    if same_id_name then break end
  end
  local name = same_id_name or same_skill_name
  if name then
    last_ammo_equip_at = now
    windower.send_command('input /equip ammo "' .. tostring(name) .. '"')
  end
end

local function refresh_weapon_types(reason)
  local items = windower.ffxi.get_items()
  if items == nil or items.equipment == nil then
    if ui and ui.theme and ui.theme.dev_mode then
      log('Weapon refresh skipped; items/equipment not ready yet. ' .. tostring(reason or ''))
    end
    return false
  end

  local changed = false

  if theme_options and theme_options.enable_weapon_switching == true then
    if items.equipment.main_bag ~= nil and items.equipment.main ~= nil then
      if not (items.equipment.main_bag == 0 and items.equipment.main == 0) then
        changed = set_weapon_type(false, items.equipment.main_bag, items.equipment.main) or changed
      else
        if player.current_weapon ~= 0 then
          player:update_weapon_type(0)
          changed = true
        end
      end
    end

    if items.equipment.range_bag ~= nil and items.equipment.range ~= nil then
      if not (items.equipment.range_bag == 0 and items.equipment.range == 0) then
        changed = set_weapon_type(true, items.equipment.range_bag, items.equipment.range) or changed
      else
        if player.current_range_weapon ~= 0 then
          player:update_range_weapon_type(0)
          changed = true
        end
      end
    end
  end

  if items.equipment.sub_bag ~= nil and items.equipment.sub ~= nil then
    local has_shield = false
    if not (items.equipment.sub_bag == 0 and items.equipment.sub == 0) then
      local sub_items = windower.ffxi.get_items(items.equipment.sub_bag, items.equipment.sub)
      if sub_items and sub_items.id then
        local sub_item = resources.items[sub_items.id]
        has_shield = sub_item ~= nil and (sub_item.shield_size or 0) > 0
      end
    end
    player:update_shield(has_shield)
  end

  if items.equipment.range_bag ~= nil and items.equipment.range ~= nil then
    local has_animator = false
    if not (items.equipment.range_bag == 0 and items.equipment.range == 0) then
      local range_items = windower.ffxi.get_items(items.equipment.range_bag, items.equipment.range)
      if range_items and range_items.id then
        local range_item = resources.items[range_items.id]
        has_animator = range_item ~= nil and range_item.en ~= nil and tostring(range_item.en):lower():find('animator') ~= nil
      end
    end
    player:update_animator(has_animator)
  end

  if items.equipment.ammo_bag ~= nil and items.equipment.ammo ~= nil then
    local has_angon = false
    local has_jug   = false
    local has_ranged_ammo = false
    local ranged_ammo_count = 0
    local ammo_skill = 0
    if not (items.equipment.ammo_bag == 0 and items.equipment.ammo == 0) then
      local ammo_items = windower.ffxi.get_items(items.equipment.ammo_bag, items.equipment.ammo)
      has_angon = ammo_items ~= nil and ammo_items.id == 18259
      if ammo_items and ammo_items.id and ammo_items.id ~= 0 then
        local ammo_res = resources and resources.items and resources.items[ammo_items.id]
        has_jug = ammo_res ~= nil
            and ammo_res.category == 'Weapon'
            and ammo_res.slots ~= nil and ammo_res.slots[3]
            and ammo_res.jobs ~= nil and ammo_res.jobs[9] and not ammo_res.jobs[1]
        ammo_skill = (ammo_res and ammo_res.skill) or 0
        last_ammo_id, last_ammo_skill = ammo_items.id, ammo_skill
      end
      has_ranged_ammo = true
      ranged_ammo_count = (ammo_items and ammo_items.count) or 0
    end
    player:update_angon(has_angon)
    player:update_jug(has_jug)
    player.ranged_ammo_count = ranged_ammo_count
    player.ammo_skill = ammo_skill
    player:update_ranged_ammo(has_ranged_ammo)
    maybe_auto_equip_ammo(has_ranged_ammo)
  end

  return changed
end

local function request_hotbar_reload(reason, delay_seconds, pet_name)
  pending_reload = {
    reason = reason or 'reload',
    pet_name = pet_name,
    due = os.clock() + (tonumber(delay_seconds) or 0),
  }
end

local function request_updategen(reason, delay_seconds, reload_first)
  pending_updategen = {
    reason       = reason or 'updategen',
    due          = os.clock() + (tonumber(delay_seconds) or 0),
    reload_first = reload_first or false,
  }
end

local function schedule_weapon_refresh(reason, attempts, interval)
  weapon_refresh_state.active = true
  weapon_refresh_state.attempts_left = attempts or 8
  weapon_refresh_state.interval = interval or 1
  weapon_refresh_state.next_time = os.clock() + 0.1
  weapon_refresh_state.reason = reason or 'scheduled'
end

local function autora_valid_target()
  local t = windower.ffxi.get_mob_by_target('t')
  return t ~= nil and t.id ~= nil and t.id > 0 and t.hpp ~= nil and t.hpp > 0 and t.is_npc == true and t.in_party ~= true
end

local function autora_has_weapon_and_ammo()
  local rw = player.current_range_weapon or 0
  local has_ammo = player.has_ranged_ammo == true
  local has_throwable_ammo = rw == 0 and has_ammo and (player.ammo_skill or 0) == 27
  local has_projectile_range_weapon = rw == 25 or rw == 26
  local has_throwing_range_weapon = rw == 27

  return has_throwing_range_weapon or has_throwable_ammo or (has_projectile_range_weapon and has_ammo)
end

local function autora_queue(delay)
  player.autora_pending_at = os.clock() + (tonumber(delay) or 0.1)
  player.autora_last_fire = nil
end

local function autora_in_melee_range(t)
  if not (t and t.distance) then return false end
  local mr = tonumber(theme_options and theme_options.autora_melee_range) or 5.0
  return t.distance <= mr * mr
end

local function autora_resync_ranged()
  local items = windower.ffxi.get_items()
  if not (items and items.equipment) then return end
  local rb, ri = items.equipment.range_bag, items.equipment.range
  local skill = 0
  if rb and ri and not (rb == 0 and ri == 0) then
    local it = windower.ffxi.get_items(rb, ri)
    if it and it.id and it.id ~= 0 and resources.items[it.id] then skill = resources.items[it.id].skill or 0 end
  end
  if player.current_range_weapon ~= skill and player.update_range_weapon_type then
    player:update_range_weapon_type(skill)
  end
  local ab, ai = items.equipment.ammo_bag, items.equipment.ammo
  player:update_ranged_ammo((ab and ai and not (ab == 0 and ai == 0)) == true)
end

local function autora_try_fire(now)
  now = now or os.clock()
  local wp = windower.ffxi.get_player()
  local engaged = (wp and wp.status == 1) or player.combat_status == 1
  if not engaged then
    player.autora_pending_at = nil
    player.autora_last_fire = nil
    return false
  end
  if not autora_has_weapon_and_ammo() then
    autora_resync_ranged()
    if not autora_has_weapon_and_ammo() then
      player.autora_pending_at = now + 2.0
      player.autora_last_fire = nil
      return false
    end
  end
  local t = windower.ffxi.get_mob_by_target('t')
  if not (t and t.id and t.id > 0 and t.hpp and t.hpp > 0 and t.is_npc == true and t.in_party ~= true) then
    player.autora_pending_at = now + 0.5
    player.autora_last_fire = nil
    return false
  end
  if autora_in_melee_range(t) then
    local mode = (theme_options and theme_options.autora_melee_mode) or 'distance'
    local hold = true
    if mode == 'all' then
      hold = not player.autora_melee_landed
    elseif mode == 'alternate' then
      hold = player.autora_last_hit ~= 'melee'
    end
    if hold then
      player.autora_pending_at = now + 0.5
      player.autora_last_fire = nil
      return false
    end
  end
  local halt_on_tp = theme_options and theme_options.autora_halt_on_tp ~= false
  local tp = player.vitals and player.vitals.tp or 0
  if halt_on_tp and tp >= 1000 then
    player.autora_pending_at = now + 2.0
    player.autora_last_fire = nil
    return false
  end
  player.autora_pending_at = nil
  player.autora_last_fire = now
  windower.chat.input('/ra <t>')
  return true
end

local function process_deferred_work()
  local now = os.clock()

  if weapon_refresh_state.active and now >= weapon_refresh_state.next_time then
    weapon_refresh_state.attempts_left = weapon_refresh_state.attempts_left - 1
    local changed = refresh_weapon_types(weapon_refresh_state.reason)
    if changed then
      request_hotbar_reload('weapon refresh: ' .. tostring(weapon_refresh_state.reason), 0.1)
      weapon_refresh_state.active = false
    elseif weapon_refresh_state.attempts_left <= 0 then
      weapon_refresh_state.active = false
    else
      weapon_refresh_state.next_time = now + weapon_refresh_state.interval
    end
  end

  if state.ready == true and theme_options ~= nil and theme_options.enable_weapon_switching == true then
    local poll_seconds = tonumber(theme_options.weapon_poll_seconds) or 0
    if poll_seconds > 0 and (now - last_weapon_poll) >= poll_seconds then
      last_weapon_poll = now
      if refresh_weapon_types('poll') then
        request_hotbar_reload('weapon poll', 0.1)
      end
    end
  end

  if state.ready == true and player.main_job == 'DRG' and (now - last_drg_pet_poll) >= 1.0 then
    last_drg_pet_poll = now
    local pet = windower.ffxi.get_mob_by_target('pet')
    local has_wyvern = pet ~= nil and pet.name ~= nil and pet.name ~= ''
    local had_wyvern = player.pet_name ~= nil and player.pet_name ~= ''
    if has_wyvern ~= had_wyvern and not pending_reload then
      request_hotbar_reload('drg wyvern poll', 0.1, has_wyvern and pet.name or '')
    end
  end

  if pending_reload and now >= pending_reload.due then
    local pet_name = pending_reload.pet_name
    pending_reload = nil
    reload_hotbar(pet_name)
  end

  if pending_updategen and now >= pending_updategen.due then
    local reason      = pending_updategen.reason
    local do_pre_reload = pending_updategen.reload_first
    pending_updategen = nil
    if addon_mode == 'gen' and state.ready then
      if ui.theme.dev_mode then log('Auto-updategen: ' .. reason) end
      if do_pre_reload then reload_hotbar() end
      if hotbar_tools:autogenerate(player, theme_options, true, nil) then
        reload_hotbar()
      end
    end
  end

  if state.ready == true and player.autora_active then
    local wp = windower.ffxi.get_player()
    local engaged = (wp and wp.status == 1) or player.combat_status == 1
    if not engaged then
      player.autora_pending_at = nil
      player.autora_last_fire = nil
    else
      if player.autora_pending_at == nil and player.autora_last_fire == nil then
        autora_queue(0.1)
      elseif player.autora_pending_at == nil and player.autora_last_fire ~= nil then
        local recover = (tonumber(theme_options and theme_options.autora_delay) or 1.5) + 2.0
        if now - player.autora_last_fire > recover then autora_queue(0.1) end
      end
      if player.autora_pending_at ~= nil and now >= player.autora_pending_at then
        autora_try_fire(now)
      end
    end
  end
end

local function get_mode_file_path()
  if not player or not player.name or player.name == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/mode.lua'
end

local function save_addon_mode(mode)
  local path = get_mode_file_path()
  if not path then return end
  local f = io.open(path, 'w')
  if f then
    f:write('return { mode = "' .. tostring(mode) .. '" }\n')
    f:close()
  end
end

local function load_addon_mode()
  local path = get_mode_file_path()
  if not path then return nil end
  local chunk = loadfile(path)
  if not chunk then return nil end
  local ok, result = pcall(chunk)
  if ok and type(result) == 'table' and (result.mode == 'gen' or result.mode == 'manual') then
    return result.mode
  end
  return nil
end

local function get_layout_path(job)
  if not player or not player.name or player.name == '' or not job or job == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/layout_' .. job .. '.lua'
end

local function load_job_layout(job)
  local path = get_layout_path(job)
  if not path then return nil end
  local chunk = loadfile(path)
  if not chunk then return nil end
  local ok, result = pcall(chunk)
  if ok and type(result) == 'table' then return result end
  return nil
end

local LAYOUT_ENVS = { 'battle', 'field' }

local function copy_offsets(src)
  local t = {}
  if src then
    for k, v in pairs(src) do
      if v then t[k] = { OffsetX = v.OffsetX, OffsetY = v.OffsetY, Vertical = v.Vertical, Scale = v.Scale } end
    end
  end
  return t
end

local function copy_slot_offsets(src)
  local t = {}
  if src then
    for row, slots in pairs(src) do
      if slots then
        local r = {}
        for slot, off in pairs(slots) do
          if off then r[slot] = { dx = off.dx, dy = off.dy, scale = off.scale } end
        end
        t[row] = r
      end
    end
  end
  return t
end

local function get_active_env()
  if not player or not player.get_hotbar_info_without_vitals then return 'battle' end
  local _, env = player:get_hotbar_info_without_vitals()
  return (env == 'field') and 'field' or 'battle'
end

local function current_visible_count()
  local max = theme_options.hotbar_number or 6
  if get_active_env() == 'field' and theme_options.field_visible_hotbar_count then
    return theme_options.field_visible_hotbar_count
  end
  return theme_options.visible_hotbar_count or max
end

local function refresh_move_boxes()
  move_box:init(theme_options)
  if ui.get_choice_indicator_extents and move_box.set_indicator_size then
    local iw, ih = ui:get_choice_indicator_extents()
    if iw and ih then move_box:set_indicator_size(iw, ih) end
  end
  move_box.current_environment = get_active_env()
  move_box:enable()
end

local function capture_environment_layout(env)
  theme_options.env_offsets = theme_options.env_offsets or {}
  theme_options.env_offsets[env] = copy_offsets(theme_options.offsets)
  theme_options.env_slot_offsets = theme_options.env_slot_offsets or {}
  theme_options.env_slot_offsets[env] = copy_slot_offsets(ui and ui.slot_custom_offsets)
end

local function global_layout_path()
  if not player or not player.name or player.name == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/hotbar_global.lua'
end
local _global_layout
local function load_global_layout()
  if _global_layout then return _global_layout end
  _global_layout = { offsets = { battle = {}, field = {} } }
  local p = global_layout_path()
  if p then
    local chunk = loadfile(p)
    if chunk then
      local ok, t = pcall(chunk)
      if ok and type(t) == 'table' and type(t.offsets) == 'table' then
        _global_layout.offsets.battle = t.offsets.battle or {}
        _global_layout.offsets.field  = t.offsets.field or {}
      end
    end
  end
  return _global_layout
end
local function save_global_layout()
  local p = global_layout_path(); if not p then return end
  local g = load_global_layout()
  local n = theme_options.hotbar_number or 6
  local lines = { 'return {', '  offsets = {' }
  for _, env in ipairs(LAYOUT_ENVS) do
    lines[#lines + 1] = '    ' .. env .. ' = {'
    local offs = g.offsets[env] or {}
    for i = 1, n do
      local off = offs[tostring(i)] or offs[i]
      if off then
        lines[#lines + 1] = '      ["' .. i .. '"] = { OffsetX=' .. tostring(off.OffsetX or 0) ..
          ', OffsetY=' .. tostring(off.OffsetY or 0) .. ', Vertical=' .. tostring(off.Vertical == true) ..
          ', Scale=' .. tostring(off.Scale or 1) .. ' },'
      end
    end
    lines[#lines + 1] = '    },'
  end
  lines[#lines + 1] = '  },'; lines[#lines + 1] = '}'
  local f = io.open(p, 'w'); if f then f:write(table.concat(lines, '\n')); f:close() end
end
local function ensure_hidden_bars()
  theme_options.hidden_bars = theme_options.hidden_bars or { battle = {}, field = {} }
  theme_options.hidden_bars.battle = theme_options.hidden_bars.battle or {}
  theme_options.hidden_bars.field  = theme_options.hidden_bars.field or {}
  return theme_options.hidden_bars
end

local function apply_environment_layout(env)
  if theme_options.env_offsets and theme_options.env_offsets[env] then
    for k, v in pairs(theme_options.env_offsets[env]) do
      if theme_options.offsets[k] then
        theme_options.offsets[k].OffsetX = v.OffsetX
        theme_options.offsets[k].OffsetY = v.OffsetY
        theme_options.offsets[k].Vertical = v.Vertical
        theme_options.offsets[k].Scale = v.Scale
      end
    end
  end
  if not theme_options.job_override then
    local g = load_global_layout()
    local goff = g.offsets and g.offsets[env]
    if goff then
      for k, v in pairs(goff) do
        theme_options.offsets[k] = theme_options.offsets[k] or { OffsetX = 0, OffsetY = 0, Vertical = false }
        theme_options.offsets[k].OffsetX = v.OffsetX
        theme_options.offsets[k].OffsetY = v.OffsetY
        theme_options.offsets[k].Vertical = v.Vertical
        theme_options.offsets[k].Scale = v.Scale
      end
    end
  end
  if theme_options.env_slot_offsets and ui.load_slot_custom_offsets then
    ui:load_slot_custom_offsets(theme_options.env_slot_offsets[env])
  end
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then
    ui:reposition_all_bars()
  end
  local hb = theme_options.hidden_bars and theme_options.hidden_bars[env]
  if hb and ui.hide_bar then
    for k, on in pairs(hb) do
      if on then ui:hide_bar(tonumber(k) or k) end
    end
  end
  if state.demo then
    refresh_move_boxes()
  end
end

local function save_job_layout()
  local job = player and player.main_job
  if not job or job == '' then return end
  local path = get_layout_path(job)
  if not path then return end

  capture_environment_layout(get_active_env())
  local n = theme_options.hotbar_number or 6
  local lines = { 'return {' }
  lines[#lines+1] = '  visible_bars = ' .. tostring(theme_options.visible_hotbar_count or n) .. ','
  lines[#lines+1] = '  job_override = ' .. tostring(theme_options.job_override == true) .. ','
  do
    local function set_str(env)
      local et = theme_options.hidden_bars and theme_options.hidden_bars[env]
      if not et then return nil end
      local parts = {}
      for bar, on in pairs(et) do if on then parts[#parts+1] = tonumber(bar) or bar end end
      if #parts == 0 then return nil end
      table.sort(parts)
      for i = 1, #parts do parts[i] = tostring(parts[i]) end
      return table.concat(parts, ',')
    end
    local b, f = set_str('battle'), set_str('field')
    if b or f then
      local segs = {}
      if b then segs[#segs+1] = 'battle = "' .. b .. '"' end
      if f then segs[#segs+1] = 'field = "' .. f .. '"' end
      lines[#lines+1] = '  hidden_bars = { ' .. table.concat(segs, ', ') .. ' },'
    end
  end
  if theme_options.field_visible_hotbar_count then
    lines[#lines+1] = '  field_visible_bars = ' .. tostring(theme_options.field_visible_hotbar_count) .. ','
  end
  if theme_options.job_scale_override then
    lines[#lines+1] = '  scale = ' .. tostring(theme_options.slot_icon_scale) .. ','
  end
  if theme_options.hide_empty_rows then
    local function rows_str(env)
      local et = theme_options.hide_empty_rows[env]
      if not et then return nil end
      local parts = {}
      for row, on in pairs(et) do if on then parts[#parts+1] = tostring(row) end end
      if #parts == 0 then return nil end
      table.sort(parts)
      return table.concat(parts, ',')
    end
    local b = rows_str('battle')
    local f = rows_str('field')
    if b or f then
      local segs = {}
      if b then segs[#segs+1] = 'battle = "' .. b .. '"' end
      if f then segs[#segs+1] = 'field = "' .. f .. '"' end
      lines[#lines+1] = '  hide_empty_rows = { ' .. table.concat(segs, ', ') .. ' },'
    end
  end
  local function env_off(env)
    return (theme_options.env_offsets and theme_options.env_offsets[env]) or theme_options.offsets
  end
  lines[#lines+1] = '  env_offsets = {'
  for _, env in ipairs(LAYOUT_ENVS) do
    lines[#lines+1] = '    ' .. env .. ' = {'
    local offs = env_off(env)
    for i = 1, n do
      local off = offs[tostring(i)]
      if off then
        lines[#lines+1] = '      [' .. i .. '] = { OffsetX=' .. tostring(off.OffsetX or 0) ..
          ', OffsetY=' .. tostring(off.OffsetY or 0) ..
          ', Vertical=' .. tostring(off.Vertical == true) ..
          ', Scale=' .. tostring(off.Scale or 1) .. ' },'
      end
    end
    lines[#lines+1] = '    },'
  end
  lines[#lines+1] = '  },'
  if theme_options.choice_bar then
    local cb = theme_options.choice_bar
    lines[#lines+1] = '  choice_bar = { OffsetX=' .. tostring(cb.OffsetX or 0) ..
      ', OffsetY=' .. tostring(cb.OffsetY or 0) ..
      ', FieldOffsetX=' .. tostring(cb.FieldOffsetX or cb.OffsetX or 0) ..
      ', FieldOffsetY=' .. tostring(cb.FieldOffsetY or cb.OffsetY or 0) ..
      ', Scale=' .. tostring(cb.Scale or 1) ..
      ', IndicatorScale=' .. tostring(cb.IndicatorScale or 1) ..
      ', IndicatorBattleX=' .. tostring(cb.IndicatorBattleX or 0) ..
      ', IndicatorBattleY=' .. tostring(cb.IndicatorBattleY or 0) ..
      ', IndicatorFieldX=' .. tostring(cb.IndicatorFieldX or 0) ..
      ', IndicatorFieldY=' .. tostring(cb.IndicatorFieldY or 0) ..
      ', IndicatorOffsetX=' .. tostring(cb.IndicatorOffsetX or 0) ..
      ', IndicatorOffsetY=' .. tostring(cb.IndicatorOffsetY or -52) .. ' },'
  end
  if theme_options.description_box_x ~= nil and theme_options.description_box_y ~= nil then
    lines[#lines+1] = '  description_box = { x=' .. tostring(math.floor(theme_options.description_box_x)) ..
      ', y=' .. tostring(math.floor(theme_options.description_box_y)) .. ' },'
  end
  local function env_slots(env)
    return (theme_options.env_slot_offsets and theme_options.env_slot_offsets[env])
      or (ui and ui.slot_custom_offsets) or {}
  end
  local any_slot = false
  for _, env in ipairs(LAYOUT_ENVS) do
    if next(env_slots(env)) ~= nil then any_slot = true end
  end
  if any_slot then
    lines[#lines+1] = '  env_slot_offsets = {'
    for _, env in ipairs(LAYOUT_ENVS) do
      lines[#lines+1] = '    ' .. env .. ' = {'
      for row, slots in pairs(env_slots(env)) do
        if slots and next(slots) ~= nil then
          lines[#lines+1] = '      [' .. tostring(row) .. '] = {'
          for slot, off in pairs(slots) do
            local sc = tonumber(off.scale)
            local sc_part = (sc and sc ~= 1) and (', scale=' .. tostring(sc)) or ''
            lines[#lines+1] = '        [' .. tostring(slot) .. '] = { dx=' .. tostring(off.dx or 0) .. ', dy=' .. tostring(off.dy or 0) .. sc_part .. ' },'
          end
          lines[#lines+1] = '      },'
        end
      end
      lines[#lines+1] = '    },'
    end
    lines[#lines+1] = '  },'
  end
  lines[#lines+1] = '}'
  local f = io.open(path, 'w')
  if f then
    f:write(table.concat(lines, '\n') .. '\n')
    f:close()
  end
end

local function apply_job_layout(layout)
  theme_options.job_override = false
  theme_options.hidden_bars = { battle = {}, field = {} }
  theme_options.visible_hotbar_count = theme_options.hotbar_number or 6
  theme_options.field_visible_hotbar_count = nil
  if ui.theme then ui.theme.visible_hotbar_count = theme_options.hotbar_number or 6; ui.theme.field_visible_hotbar_count = nil end
  if layout then
    theme_options.job_override = layout.job_override == true
    do
      local function parse_set(spec)
        local t = {}
        if spec ~= nil then for s in tostring(spec):gmatch('%d+') do t[tonumber(s)] = true end end
        return t
      end
      local hb = layout.hidden_bars
      if type(hb) == 'table' then
        theme_options.hidden_bars = { battle = parse_set(hb.battle), field = parse_set(hb.field) }
      end
    end
    if type(layout.hidden_bars) ~= 'table' then
      local nb = theme_options.hotbar_number or 6
      local vb = layout.visible_bars or nb
      local fb = layout.field_visible_bars or vb
      local mig = { battle = {}, field = {} }
      for i = vb + 1, nb do mig.battle[i] = true end
      for i = fb + 1, nb do mig.field[i] = true end
      theme_options.hidden_bars = mig
    end

    theme_options.env_offsets = { battle = copy_offsets(theme_options.offsets), field = copy_offsets(theme_options.offsets) }
    local function overlay_offsets(dest, src)
      if type(src) ~= 'table' then return end
      for i, off in pairs(src) do
        if off then dest[tostring(i)] = { OffsetX = off.OffsetX, OffsetY = off.OffsetY, Vertical = off.Vertical, Scale = off.Scale } end
      end
    end
    if type(layout.env_offsets) == 'table' then
      overlay_offsets(theme_options.env_offsets.battle, layout.env_offsets.battle)
      overlay_offsets(theme_options.env_offsets.field, layout.env_offsets.field)
    elseif type(layout.offsets) == 'table' then
      overlay_offsets(theme_options.env_offsets.battle, layout.offsets)
      overlay_offsets(theme_options.env_offsets.field, layout.offsets)
    end
    if layout.choice_bar and theme_options.choice_bar then
      local cb = layout.choice_bar
      theme_options.choice_bar.OffsetX = cb.OffsetX
      theme_options.choice_bar.OffsetY = cb.OffsetY
      if cb.FieldOffsetX ~= nil then theme_options.choice_bar.FieldOffsetX = cb.FieldOffsetX end
      if cb.FieldOffsetY ~= nil then theme_options.choice_bar.FieldOffsetY = cb.FieldOffsetY end
      if cb.Scale ~= nil then theme_options.choice_bar.Scale = cb.Scale end
      if cb.IndicatorScale ~= nil then theme_options.choice_bar.IndicatorScale = cb.IndicatorScale end
      if cb.IndicatorBattleX ~= nil then theme_options.choice_bar.IndicatorBattleX = cb.IndicatorBattleX end
      if cb.IndicatorBattleY ~= nil then theme_options.choice_bar.IndicatorBattleY = cb.IndicatorBattleY end
      if cb.IndicatorFieldX ~= nil then theme_options.choice_bar.IndicatorFieldX = cb.IndicatorFieldX end
      if cb.IndicatorFieldY ~= nil then theme_options.choice_bar.IndicatorFieldY = cb.IndicatorFieldY end
      if cb.IndicatorOffsetX ~= nil then theme_options.choice_bar.IndicatorOffsetX = cb.IndicatorOffsetX end
      if cb.IndicatorOffsetY ~= nil then theme_options.choice_bar.IndicatorOffsetY = cb.IndicatorOffsetY end
    end
    if layout.description_box then
      local db = layout.description_box
      if db.x ~= nil then theme_options.description_box_x = db.x end
      if db.y ~= nil then theme_options.description_box_y = db.y end
      if ui.action_description then
        ui.action_description:pos(theme_options.description_box_x, theme_options.description_box_y)
      end
    end
    if layout.hide_empty_rows ~= nil then
      local function parse_rows(spec)
        local t = {}
        if spec ~= nil then
          for row_str in tostring(spec):gmatch('%d+') do t[tonumber(row_str)] = true end
        end
        return t
      end
      local her = layout.hide_empty_rows
      local tbl
      if type(her) == 'table' then
        tbl = { battle = parse_rows(her.battle), field = parse_rows(her.field) }
      else

        tbl = { battle = parse_rows(her), field = parse_rows(her) }
      end
      theme_options.hide_empty_rows = tbl
      if ui.theme then ui.theme.hide_empty_rows = tbl end
    else
      theme_options.hide_empty_rows = nil
      if ui.theme then ui.theme.hide_empty_rows = nil end
    end

    theme_options.env_slot_offsets = { battle = {}, field = {} }
    if type(layout.env_slot_offsets) == 'table' then
      theme_options.env_slot_offsets.battle = copy_slot_offsets(layout.env_slot_offsets.battle)
      theme_options.env_slot_offsets.field = copy_slot_offsets(layout.env_slot_offsets.field)
    elseif type(layout.slot_offsets) == 'table' then
      theme_options.env_slot_offsets.battle = copy_slot_offsets(layout.slot_offsets)
      theme_options.env_slot_offsets.field = copy_slot_offsets(layout.slot_offsets)
    end
    if layout.scale then
      theme_options.slot_icon_scale = layout.scale
      theme_options.job_scale_override = true
    else
      theme_options.slot_icon_scale = settings.Hotbar.Style.SlotIconScale
      theme_options.job_scale_override = nil
    end
    apply_environment_layout(get_active_env())
  else
    theme_options.slot_icon_scale = settings.Hotbar.Style.SlotIconScale
    theme_options.job_scale_override = nil
    theme_options.env_offsets = { battle = copy_offsets(theme_options.offsets), field = copy_offsets(theme_options.offsets) }
    theme_options.env_slot_offsets = { battle = {}, field = {} }
    apply_environment_layout(get_active_env())
  end
  if ui.rescale and ui.hotbars and ui.hotbars[1] then
    ui:rescale(theme_options.slot_icon_scale or 1)
  end
  move_box:init(theme_options)
  if ui.hide_bars_beyond_visible then ui:hide_bars_beyond_visible() end
end

function initialize()
  keyboard:set_bindings(settings.Keybinds)
  keyboard:parse_keybinds()

  ui:setup(theme_options)
  ui:set_player(player)

  local windower_player = windower.ffxi.get_player()
  local windower_info = windower.ffxi.get_info()

  local server = resources.servers[windower_info.server]
      and resources.servers[windower_info.server].en
      or "PrivateServer_" .. tostring(windower_info.server)

  refresh_weapon_types('initialize')
  refresh_overload_state()

  local current_mp = windower_player.vitals.mp
  local current_tp = windower_player.vitals.tp

  ui:update_mp(current_mp)
  ui:update_tp(current_tp)

  local pet = windower.ffxi.get_mob_by_target('pet') or nil
  if pet ~= nil then
    player:update_pet(pet.name)
  end

  player:initialize(windower_player, server, theme_options)
  apply_job_layout(load_job_layout(player.main_job))
  player:load_hotbar()
  keyboard:bind_keys(theme_options.rows, theme_options.columns)
  skillchains:initialize()

  ui:load_player_hotbar(player:get_hotbar_info())
  ui.hotbar.ready = true
  ui.hotbar.initialized = true
  state.ready = true

  hotbar_sets:setup(theme_options)
  hotbar_sets:set_player(player)
  hotbar_sets:apply_settings(settings.HotbarSets)
  hotbar_sets:init_grid()
  if hotbar_sets:is_visible() and hotbar_sets:ensure_on_screen() then
    local gx, gy = hotbar_sets:get_pos()
    settings.HotbarSets.Pos.X = math.floor(gx)
    settings.HotbarSets.Pos.Y = math.floor(gy)
    config.save(settings)
  end
  hotbar_sets:refresh_visibility()
  if hotbar_blocker then hotbar_blocker:hide() end
  hotbar_blocker = images.new()
  hotbar_blocker:draggable(false)
  hotbar_blocker:fit(false)
  hotbar_blocker:alpha(0)
  hotbar_blocker:size(0, 0)
  hotbar_blocker:pos(0, 0)
  if choice_blocker then choice_blocker:hide() end
  choice_blocker = images.new()
  choice_blocker:draggable(false)
  choice_blocker:fit(false)
  choice_blocker:alpha(0)
  choice_blocker:size(0, 0)
  choice_blocker:pos(0, 0)
  schedule_weapon_refresh('initialize', 10, 1)
  local saved_mode = load_addon_mode()
  if saved_mode then
    addon_mode = saved_mode
  end
end

function on_world_load()
  if ui.theme.dev_mode then log("Zoning. Reloading Hotbar.") end

  player.scavenge_ammo_expended = 0
  player.has_luopan = false
  player.luopan_id = nil
  player.luopan_geo_pending = false
  player.autora_active = false
  player.autora_pending_at = nil
  player.autora_last_fire = nil
  player.combat_status = 0

  refresh_weapon_types('world load')
  refresh_overload_state()
  schedule_weapon_refresh('world load', 8, 1)

  local wp = windower.ffxi.get_player()
  if wp and wp.status == 4 then
    ui.hotbar.hide_hotbars = true
  elseif not state.ext_hidden then
    ui.hotbar.hide_hotbars = false
    ui:show(player:get_hotbar_info())
  end

  request_hotbar_reload('world load', 0.1)
end

local is_choice_modifier_active
local set_choice_modifier_state

local function trigger_choice_action(slot)
  local action = ui:get_choice_action(slot)
  if action == nil then return true end

  local action_type = tostring(action.type or ''):lower()
  if action_type == 'choice_page_next' then
    ui:choice_next_page()
    return true
  elseif action_type == 'choice_page_prev' then
    ui:choice_prev_page()
    return true
  end

  if ui.is_choice_action_disabled ~= nil then
    local disabled, reason = ui:is_choice_action_disabled(action)
    if disabled == true then
      ui:trigger_choice_feedback(slot)
      print('XIVHOTBAR2: ' .. tostring(action.alias or action.action or 'Choice') .. ' is not currently usable' .. (reason and (': ' .. reason) or '.'))
      return true
    end
  end

  ui:trigger_choice_feedback(slot)
  if ui.theme.choice_bar == nil or ui.theme.choice_bar.CloseOnExecute ~= false then
    ui:close_choice_bar()
    if is_choice_modifier_active() and ui.set_choice_modifier_indicator then
      ui:set_choice_modifier_indicator(true)
    end
  end
  player:execute_action_object(action, true)
  return true
end

is_choice_modifier_active = function()
  return choice_modifier_held == true or choice_modifier_armed == true
end

set_choice_modifier_state = function(active, announce)
  local mode = tostring((theme_options or {}).controls_choice_modifier_mode or 'toggle'):lower()
  if mode == 'hold' then
    choice_modifier_held = active == true
    choice_modifier_armed = false
  else
    choice_modifier_held = false
    choice_modifier_armed = active == true
  end

  if active ~= true and ui and ui.is_choice_bar_active and ui:is_choice_bar_active() then
    ui:close_choice_bar()
  end

  if ui and ui.set_choice_modifier_indicator then
    ui:set_choice_modifier_indicator(active == true)
  end
  if announce == true then
    if active == true then
      print('XIVHOTBAR2: choice modifier enabled. Press hotbar keys to open variants; press the modifier again to turn it off.')
    else
      print('XIVHOTBAR2: choice modifier disabled.')
    end
  end
end

local function hud_layout_open()
  local ok, hud = pcall(require, 'components/xivuimenu/hud')
  return ok and type(hud) == 'table' and hud.open == true
end

local function menu_covers(x, y)
  local ok, menu = pcall(require, 'components/xivuimenu/xivuimenu')
  return ok and type(menu) == 'table' and menu.covers ~= nil and menu.covers(x, y) == true
end

local function key_is_down(flags)
  return flags == true or flags == 1 or tostring(flags):lower() == 'true'
end

local function action_label(action, fallback)
  if action == nil then return fallback or 'slot' end
  return tostring(action.alias or action.action or fallback or 'slot')
end

local function open_slot_variants_for_active_hotbar(slot)
  local active_hotbar = player:get_active_hotbar()
  local raw_action = player:get_raw_action(slot)
  local visible_action = nil
  local action = raw_action

  if action == nil then
    visible_action = player:get_action(slot)
    action = visible_action
  end

  if action == nil then
    return false
  end

  local action_type = tostring(action.type or ''):lower()
  if action_type == 'choice' then
    if player.resolve_action_for_resources then
      local resolved = player:resolve_action_for_resources(action)
      if resolved ~= nil and tostring(resolved.type or ''):lower() ~= 'choice' then
        return false
      end
    end
    if ui.disabled_slots and (
        (ui.disabled_slots.on_cooldown and ui.disabled_slots.on_cooldown[action.action] == true) or
        (ui.disabled_slots.no_vitals and ui.disabled_slots.no_vitals[action.action] == true) or
        (ui.disabled_slots.actions and ui.disabled_slots.actions[action.action] == true)
      ) then
      return true
    end
    local choices, err = choice_groups:resolve(player, action.action)
    if choices ~= nil and #choices > 0 then
      ui:open_choice_bar(action.action, choice_groups:get_label(action.action, player), choices, active_hotbar)
      return true
    end
    if ui and ui.theme and ui.theme.dev_mode then
      log('XIVHOTBAR2: No choices for group ' .. tostring(action.action) .. (err and (': ' .. err) or '.'))
    end
    return false
  end

  local choices = nil
  if player.get_action_choices_for_action then
    choices = player:get_action_choices_for_action(raw_action)
  end
  if (choices == nil or #choices <= 1) and player.get_action_choices then
    choices = player:get_action_choices(slot)
  end
  if (choices == nil or #choices <= 1) then
    visible_action = visible_action or player:get_action(slot)
    if visible_action ~= raw_action and player.get_action_choices_for_action then
      choices = player:get_action_choices_for_action(visible_action)
    end
  end

  if choices ~= nil and #choices > 1 then
    local label_src = visible_action or raw_action
    local label = (choices[1] and choices[1]._family_base)
    if not label and label_src then
      local name = tostring(label_src.action or '')
      label = name:match('^(.-)%s+[IVX]+$') or name
    end
    label = label or 'Choices'
    ui:open_choice_bar('slot_variants_' .. tostring(active_hotbar) .. '_' .. tostring(slot), label, choices, active_hotbar)
    return true
  end

  if ui and ui.theme and ui.theme.dev_mode then
    visible_action = visible_action or player:get_action(slot)
    local raw_desc = raw_action and (tostring(raw_action.type or '') .. ':' .. tostring(raw_action.action or '')) or 'nil'
    log('XIVHOTBAR2: No variants for ' .. action_label(visible_action or raw_action, 'slot') .. ' raw=' .. raw_desc)
  end
  return false
end

function trigger_action(slot)
  if hud_layout_open() then return end

  local active_hotbar = player:get_active_hotbar()

  if ui:is_choice_bar_active() and ui:choice_matches_hotbar(active_hotbar) then
    trigger_choice_action(slot)
    return
  end

  if is_choice_modifier_active() then
    if open_slot_variants_for_active_hotbar(slot) then
      return
    end
  end

  local action = player:get_action(slot)
  if action ~= nil and tostring(action.type or ''):lower() == 'choice' then
    if ui.disabled_slots and (
        (ui.disabled_slots.on_cooldown and ui.disabled_slots.on_cooldown[action.action] == true) or
        (ui.disabled_slots.actions and ui.disabled_slots.actions[action.action] == true)
      ) then
      return
    end
    local choices, err = choice_groups:resolve(player, action.action)
    if choices ~= nil and #choices > 0 then
      ui:open_choice_bar(action.action, choice_groups:get_label(action.action, player), choices, active_hotbar)
    else
      print('XIVHOTBAR2: No available choices for ' .. tostring(action.action) .. (err and (': ' .. err) or '.'))
    end
    return
  end

  player:execute_action(slot)
  ui:trigger_feedback(active_hotbar, slot)
end

function toggle_environment()
  player:toggle_environment()
  apply_environment_layout(get_active_env())
  ui:load_player_hotbar(player:get_hotbar_info())
end

function set_battle_environment(in_battle)
  player:set_battle_environment(in_battle)
  apply_environment_layout(get_active_env())
  ui:load_player_hotbar(player:get_hotbar_info())
end

local function sync_key_bindings_for_hide_state()
  local max = theme_options.hotbar_number or 6
  local visible_count = current_visible_count()
  local columns = theme_options.columns or 12
  local _, active_env = player:get_hotbar_info_without_vitals()
  local env_hide = theme_options.hide_empty_rows and theme_options.hide_empty_rows[active_env]
  for r = 1, max do
    if r > visible_count then
      keyboard:unbind_row(r, columns)
    else
      local row_hide = env_hide and env_hide[r] == true
      if row_hide then
        for s = 1, columns do
          local action = player:get_visible_action(nil, r, s)
          if action == nil then
            keyboard:unbind_slot(r, s)
          else
            keyboard:bind_slot(r, s)
          end
        end
      else
        keyboard:bind_row(r, columns)
      end
    end
  end
end

function reload_hotbar(using_pet_name)
  if ui.theme.dev_mode then log("Reloading Hotbar.") end

  local pet_name
  if using_pet_name == nil then
    local pet = windower.ffxi.get_mob_by_target('pet')
    pet_name = (pet ~= nil and pet.name ~= nil and pet.name ~= '') and pet.name or ''
  else
    pet_name = using_pet_name
  end

  local windower_player = windower.ffxi.get_player()

  local cur_job = (resources.jobs[windower_player.main_job_id] or {}).ens or 'NON'
  if not PET_JOB_NAMES[cur_job] then
    pet_name = ''
  end

  if resources.jobs[windower_player.sub_job_id] == nil then
    ui:update_mp(windower_player.vitals.mp)
    ui:update_tp(windower_player.vitals.tp)
    player:update_job(windower_player.main_job_id, resources.jobs[windower_player.main_job_id].ens, 0, 'NON')
    player:update_level(windower_player.main_job_level, 0)
    player:update_pet(pet_name)
  else
    ui:update_mp(windower_player.vitals.mp)
    ui:update_tp(windower_player.vitals.tp)
    player:update_job(windower_player.main_job_id, resources.jobs[windower_player.main_job_id].ens,
      windower_player.sub_job_id, resources.jobs[windower_player.sub_job_id].ens)
    player:update_level(windower_player.main_job_level, windower_player.sub_job_level)
    player:update_pet(pet_name)
  end

  player.gen_mode = (addon_mode == 'gen')
  player:load_hotbar()
  choice_groups.invalidate_dynamic_cache()
  ui:load_player_hotbar(player:get_hotbar_info())
  sync_key_bindings_for_hide_state()

  hotbar_sets:set_player(player)
  hotbar_sets:refresh_colors()
end

function change_active_hotbar(new_hotbar)
  player:change_active_hotbar(new_hotbar)
end

function flush_old_keybinds()
  for i = 1, ui.hotbar.rows, 1 do
    for j = 1, ui.hotbar.columns, 1 do
      windower.send_command('htb delete f ' .. i .. ' ' .. j)
    end
  end
  for i = 1, ui.hotbar.rows, 1 do
    for j = 1, ui.hotbar.columns, 1 do
      windower.send_command('htb delete battle ' .. i .. ' ' .. j)
    end
  end
end

local function save_hotbar(hotbar, index)
  if index <= theme_options.rows then
    local x, y = move_box:get_pos(index)
    hotbar.OffsetX = x
    hotbar.OffsetY = y
  end
end

local function save_choice_bar()
  if theme_options.choice_bar ~= nil then
    if settings.Hotbar.ChoiceBar == nil then
      settings.Hotbar.ChoiceBar = {}
    end

    local choice_row = (theme_options.rows or 6) + 1
    local x, y = move_box:get_pos(choice_row)
    settings.Hotbar.ChoiceBar.OffsetX = x
    settings.Hotbar.ChoiceBar.OffsetY = y
    theme_options.choice_bar.OffsetX = x
    theme_options.choice_bar.OffsetY = y

    local indicator_row = (theme_options.rows or 6) + 2
    if move_box.get_pos ~= nil then
      local ix, iy = move_box:get_pos(indicator_row)
      if ix ~= nil and iy ~= nil then
        settings.Hotbar.ChoiceBar.IndicatorOffsetX = ix - x
        settings.Hotbar.ChoiceBar.IndicatorOffsetY = iy - y
        theme_options.choice_bar.IndicatorOffsetX = ix - x
        theme_options.choice_bar.IndicatorOffsetY = iy - y
      end
    end
  end
end

local function print_help()
  local log = _G.xivui_echo or log
  log("Commands:")
  log("move: Enables layout mode. Drag a skill onto another slot to swap them. To move the bar itself, click and drag the gap between slots. Run //htb move again to save. Bar/slot positions save per environment (Main vs General) - switch environments to set each.")
  log("reposition: Click and drag anywhere to move all hotbars together as a group. Release to save (to the current environment). Run //htb reposition again to exit.")
  log("reload: Reloads the hotbar, if you have made changes to the hotbar-file, this is faster for loading.")
  log("mount: either dismounts if mounted, or mounts the indicated mount")
  log("validate: Checks current job/general lua files for bad slots, typos, and missing icons.")
  log("whyhidden: Lists job-file entries the live checks are hiding right now (not learned / level / pet) and why.")
  if addon_mode ~= 'manual' then
    log("setbar <category> <1-6> [battle|field]: Sets autogen category bar. Examples: setbar main 1, setbar black magic 3.")
    log("unsetbar <magic category>: Disables generated magic for that category.")
    log("autogen [category|bar <n>|<n>]: Adds generated actions. Magic only generates for setbar-enabled magic categories.")
    log("updategen [category|bar <n>|<n>]: Adds only newly learned/generated actions.")
  end
  log("resetslot [battle|field] <row> <slot>: Removes a single action from a hotbar slot.")
  log("resetbar [battle|field] <1-6>: Removes all actions from that bar in job/general files.")
  log("resetall [battle|field]: Removes all actions from all bars in job/general files.")
  if addon_mode == 'manual' then
    log("set slot <row> <slot> <type> <action> [target] [alias]: Adds an action to a hotbar slot.")
    log("  Types: ma (magic), ws, ja, ct, item, macro, gs, input, choice. Targets: me, stpc, bt, stnpc, st (default: me).")
    log("  ma:     //htb set slot 1 1 ma Cure stpc")
    log("  ws:     //htb set slot 1 2 ws Savage Blade bt")
    log("  ja:     //htb set slot 1 3 ja Provoke bt Prov")
    log("  item:   //htb set slot 1 4 item Hi-Potion me")
    log("  choice: //htb set slot 1 5 choice elemental_magic bt Nukes  (variant popup)")
    log("    Use //htb choice list to see available group names.")
    log("  Stacking tiers (e.g. Fire I-IV): edit data/<CharName>/<JOB>.lua directly.")
    log("    List lowest tier first, highest last. The addon selects the highest you know.")
    log("resetslot [battle|field] <row> <slot>: Removes a single action. Example: //htb resetslot 1 1")
    log("set gen mode: Switch to gen mode to enable autogen commands.")
  else
    log("set gen mode | set manual mode: Switch the addon setup mode.")
  end
  log("style list|xiv|compact|classic|minimal|transparent|theme <slotTheme> [frameTheme]: Changes visual style/theme.")
  log("envpos <x> <y> / envhook <bar>: Moves or re-hooks the Main/General environment text.")
  log("choice [on|off|toggle|list|cancel|status]: Toggles choice mode, lists groups, checks status, or cancels an active popup.")
  log("choice <hotbar> <slot>: Opens the choice popup for a specific slot by position.")
  log("choiceindicator <xOffset> <yOffset>: Moves the CHOICE MODE ON indicator relative to the choice bar.")
  log("choicekey [DIK|capslock|grave|tilde]: Shows or sets the modifier key that opens variant choice bars. Default is CapsLock.")
  log("choicemode [toggle|hold|oneshot]: Toggle mode, hold mode, or one-shot mode. Default toggle.")
  log("collapse weaponskills <hotbar> <slot> [weapon]: Replaces a WS bar with one choice button. Example: //htb collapse weaponskills 3 1 sword")
  log("set up trust [battle|field]: Adds a Trust choice button to the first open slot, then walks you through filling the Trust choice bar.")
  log("bstcharge <seconds>: Sets BST Ready charge time for charge/recast display.")
  log("schchargebase <seconds>: Sets SCH stratagem base recharge time for charge/recast display.")
  log("weaponpriority [auto|main|range]: Controls whether main or ranged weapon WS tables win shared slots. 'melee' = main, 'ranged' = range.")
  log("petrefresh [name|clear]: Re-detects, manually sets, or clears the current pet name used for pet hotbars.")
  log("bars <1-6>: Sets visible bar count for both environments. 'bars main <n>' or 'bars gen <n>' sets each independently.")
  log("hideempty [main|gen] <1-6>: Toggles hiding of unused slots on a hotbar row. With no qualifier affects both environments; 'main'/'gen' target one. Persists per job.")
  log("move custom <1-6>: Enter free-position mode for a single hotbar row. Drag each slot independently. Run again to save. Saved per environment (Main vs General).")
  log("reset custom <1-6>: Resets all custom per-slot offsets on that hotbar back to the row grid.")
  log("set visible: Toggles the 3x3 hotbar set grid (save slots 1-9 per job). Drag it while in //htb move.")
  log("set save <1-9> [\"name\"]: Snapshots the current job's hotbar (slots + bar count, positions, custom slot offsets, hidden rows, scale) into a set node. Reuses the old name if omitted.")
  log("set load <1-9>: Loads a saved set for the current job and reloads the addon (also: click a green node). set clear <1-9> deletes one.")
  log("set list: Lists the saved sets and names for the current job.")
  log("set pos <x> <y>: Moves the set grid to exact coordinates (run with no args to print the current position).")
  log("execute <1-6> <slot>: Fires a specific hotbar slot programmatically. Useful in Windower aliases.")
  log("autora [start|stop|status]: Manually start or stop auto ranged attack, or check its current state.")
  log("perf [low|normal|high|custom <recastFrames> <hoverFrames> [weaponPollSeconds]]: Sets performance preset. Aliases: potato=low, smooth=high, balanced=normal. Saves and reloads.")
end

local xivhotbar3_component = {}

function xivhotbar3_component.handle_command(command, ...)
  local raw_command = command or 'help'
  local raw_args = { ... }
  command = command and command:lower() or 'help'
  local args = raw_args

  if trust_setup_state and trust_setup_state.active and command ~= 'execute' then
    if command == 'done' or command == 'finish' or command == 'end' then
      hotbar_tools:finish_trust_setup(player, trust_setup_state, false)
      trust_setup_state = nil
      return
    elseif command == 'cancel' then
      hotbar_tools:finish_trust_setup(player, trust_setup_state, true)
      trust_setup_state = nil
      return
    elseif command == 'trust' then
      local trust_name = table.concat(raw_args, ' ')
      local keep_going = hotbar_tools:add_trust_setup_choice(player, trust_setup_state, trust_name)
      if not keep_going then trust_setup_state = nil end
      return
    else
      local trust_name = tostring(raw_command or '')
      if #raw_args > 0 then trust_name = trust_name .. ' ' .. table.concat(raw_args, ' ') end
      local keep_going = hotbar_tools:add_trust_setup_choice(player, trust_setup_state, trust_name)
      if not keep_going then trust_setup_state = nil end
      return
    end
  end

  if command == 'reload' then
    if ui.theme.dev_mode then log('Reloading Hotbar.') end
    reload_hotbar()
  elseif command == 'help' then
    print_help()
  elseif command == 'mount' then
    local player_mount = windower.ffxi.get_player()
    if not player_mount then return end
    for k = 1, 32 do
      if player_mount.buffs[k] == 252 then
        windower.chat.input('/dismount')
        return
      end
    end
    if args[1] == nil then
      windower.chat.input('/mount raptor <me>')
    else
      windower.chat.input('/mount ' .. args[1] .. ' <me>')
    end
  elseif command == 'execute' then
    local hotbar_num = tonumber(args[1])
    local slot_num = tonumber(args[2])
    local visible_count = current_visible_count()
    if hotbar_num and slot_num and hotbar_num <= visible_count then
      change_active_hotbar(hotbar_num)
      if slot_num <= theme_options.columns then
        trigger_action(slot_num)
      end
    end
  elseif command == 'move' and args[1] and tostring(args[1]):lower() == 'custom' then
    local hotbar_num = tonumber(args[2])
    if not hotbar_num then
      print('XIVHOTBAR2: Usage: //htb move custom <hotbar number>')
    elseif custom_slot_mode.active and custom_slot_mode.hotbar == hotbar_num then
      custom_slot_mode.active = false
      custom_slot_mode.drag.active = false
      save_job_layout()
      print('XIVHOTBAR2: Custom slot mode saved for hotbar ' .. hotbar_num .. '.')
    else
      if state.demo then
        state.demo = false
        move_box:disable()
      end
      custom_slot_mode.active = true
      custom_slot_mode.hotbar = hotbar_num
      custom_slot_mode.drag.active = false
      log('Custom slot mode enabled for hotbar ' .. hotbar_num .. '.')
      log('Drag individual slots to reposition them freely.')
      log('Run //htb move custom ' .. hotbar_num .. ' again to save and exit.')
      print('XIVHOTBAR2: Custom slot mode enabled for hotbar ' .. hotbar_num .. '.')
    end
  elseif command == 'reset' and args[1] and tostring(args[1]):lower() == 'custom' then
    local hotbar_num = tonumber(args[2])
    if not hotbar_num then
      print('XIVHOTBAR2: Usage: //htb reset custom <hotbar number>')
    else
      if ui.clear_slot_custom_offsets_for_row then
        ui:clear_slot_custom_offsets_for_row(hotbar_num)
        ui:reposition_all_bars()
        save_job_layout()
        print('XIVHOTBAR2: Reset custom slot positions for hotbar ' .. hotbar_num .. '.')
      end
    end
  elseif command == 'reposition' then
    local sub = args[1] and tostring(args[1]):lower() or nil
    local sub2 = args[2] and tostring(args[2]):lower() or nil
    local mode_key = nil
    local mode_label = nil
    local exit_cmd = nil
    if sub == 'hotbargaps' then
      mode_key = 'hotbar'
      mode_label = 'Hotbar row gap (horizontal bars)'
      exit_cmd = '//htb reposition hotbargaps'
    elseif sub == 'icongaps' and sub2 == 'vertical' then
      mode_key = 'icon_v'
      mode_label = 'Icon gap (vertical bars)'
      exit_cmd = '//htb reposition icongaps vertical'
    elseif sub == 'icongaps' then
      mode_key = 'icon_h'
      mode_label = 'Icon gap (horizontal bars)'
      exit_cmd = '//htb reposition icongaps'
    elseif sub == 'descsize' then
      mode_key = 'descsize'
      mode_label = 'Description tooltip size'
      exit_cmd = '//htb reposition descsize'
    end
    if mode_key then
      if reposition_mode.active and reposition_mode.bargap_mode == mode_key then
        reposition_mode.active = false
        reposition_mode.bargap_mode = nil
        reposition_mode.drag.active = false
        print('XIVHOTBAR2: ' .. mode_label .. ' mode disabled.')
      else
        if state.demo then state.demo = false; move_box:disable() end
        if custom_slot_mode.active then custom_slot_mode.active = false; custom_slot_mode.drag.active = false end
        reposition_mode.active = true
        reposition_mode.bargap_mode = mode_key
        reposition_mode.drag.active = false
        print('XIVHOTBAR2: ' .. mode_label .. ' mode enabled. Scroll to adjust. Run ' .. exit_cmd .. ' again to exit.')
      end
    else
      reposition_mode.bargap_mode = nil
      reposition_mode.active = not reposition_mode.active
      if reposition_mode.active then
        if state.demo then
          state.demo = false
          move_box:disable()
        end
        if custom_slot_mode.active then
          custom_slot_mode.active = false
          custom_slot_mode.drag.active = false
        end
        print('XIVHOTBAR2: Reposition mode enabled. Click and drag anywhere to move all hotbars together. Run //htb reposition again to exit.')
      else
        reposition_mode.drag.active = false
        ui.reposition_offset_x = 0
        ui.reposition_offset_y = 0
        ui:reposition_all_bars()
        print('XIVHOTBAR2: Reposition mode disabled.')
      end
    end
  elseif command == 'move' then
    if custom_slot_mode.active then
      custom_slot_mode.active = false
      custom_slot_mode.drag.active = false
    end
    state.demo = not state.demo
    if state.demo then
      log("Layout mode enabled!")
      log("Click, then drag an action onto another slot to change its location.")
      log("Click between the rows, then drag to move the hotbars.")
      log("To save the changes, type '//htb move' then hit enter.")
      log("You can also drag the Main/General environment text while layout mode is enabled.")
      print('XIVHOTBAR2: Layout mode enabled')

      refresh_move_boxes()
      if ui.get_environment_text_position then
        local ex, ey = ui:get_environment_text_position()
        environment_text_start_pos = { x = ex, y = ey }
      end
      if ui.set_environment_text_draggable then ui:set_environment_text_draggable(true) end
      if ui.get_inventory_count_position then
        local ix, iy = ui:get_inventory_count_position()
        inventory_count_start_pos = ix and iy and { x = ix, y = iy } or nil
      end
      if ui.set_inventory_count_draggable then ui:set_inventory_count_draggable(true) end
      if ui.get_description_position then
        local dx, dy = ui:get_description_position()
        description_box_start_pos = dx and dy and { x = dx, y = dy } or nil
      end
      if ui.set_description_draggable then ui:set_description_draggable(true) end
      do
        local gx, gy = hotbar_sets:get_pos()
        hotbar_sets_start_pos = { x = gx, y = gy }
      end
      hotbar_sets:set_force_shown(true)
      log("Drag the Hotbar Sets grid to reposition it.")
    else
      save_hotbar(settings.Hotbar.Offsets.First, 1)
      save_hotbar(settings.Hotbar.Offsets.Second, 2)
      save_hotbar(settings.Hotbar.Offsets.Third, 3)
      save_hotbar(settings.Hotbar.Offsets.Fourth, 4)
      save_hotbar(settings.Hotbar.Offsets.Fifth, 5)
      save_hotbar(settings.Hotbar.Offsets.Sixth, 6)
      save_choice_bar()
      if ui.get_environment_text_position then
        local env_x, env_y, env_dx, env_dy = ui:get_environment_text_position()
        local moved_env = false
        if environment_text_start_pos and env_x and env_y then
          moved_env = math.abs(env_x - (environment_text_start_pos.x or env_x)) > 1
              or math.abs(env_y - (environment_text_start_pos.y or env_y)) > 1
        end
        if moved_env and settings.Texts and settings.Texts.Environment and settings.Texts.Environment.Pos then
          settings.Texts.Environment.Pos.HookOntoBar = 0
          settings.Texts.Environment.Pos.PosX = math.floor(env_x)
          settings.Texts.Environment.Pos.PosY = math.floor(env_y)
          if env_dx ~= nil then settings.Texts.Environment.Pos.OffsetX = math.floor(env_dx) end
          if env_dy ~= nil then settings.Texts.Environment.Pos.OffsetY = math.floor(env_dy) end
          theme_options.hook_onto_bar = 0
          theme_options.font_pos_x_env = math.floor(env_x)
          theme_options.font_pos_y_env = math.floor(env_y)
          if ui.theme then
            ui.theme.hook_onto_bar = 0
            ui.theme.font_pos_x_env = theme_options.font_pos_x_env
            ui.theme.font_pos_y_env = theme_options.font_pos_y_env
          end
          print('XIVHOTBAR2: saved Main/General environment text position.')
        end
        environment_text_start_pos = nil
      end

      if ui.get_inventory_count_position then
        local inv_x, inv_y = ui:get_inventory_count_position()
        local moved_inv = false
        if inventory_count_start_pos and inv_x and inv_y then
          moved_inv = math.abs(inv_x - (inventory_count_start_pos.x or inv_x)) > 1
              or math.abs(inv_y - (inventory_count_start_pos.y or inv_y)) > 1
        end
        if moved_inv and settings.Texts and settings.Texts.Inventory and settings.Texts.Inventory.Pos then
          settings.Texts.Inventory.Pos.Unlock = true
          settings.Texts.Inventory.Pos.PosX = math.floor(inv_x)
          settings.Texts.Inventory.Pos.PosY = math.floor(inv_y)
          theme_options.unlock_pos_inv = true
          theme_options.font_pos_x_inv = math.floor(inv_x)
          theme_options.font_pos_y_inv = math.floor(inv_y)
          if ui.theme then
            ui.theme.unlock_pos_inv = true
            ui.theme.font_pos_x_inv = theme_options.font_pos_x_inv
            ui.theme.font_pos_y_inv = theme_options.font_pos_y_inv
          end
          print('XIVHOTBAR2: saved inventory count position.')
        end
        inventory_count_start_pos = nil
      end

      if ui.get_description_position then
        local desc_x, desc_y = ui:get_description_position()
        local moved_desc = false
        if description_box_start_pos and desc_x and desc_y then
          moved_desc = math.abs(desc_x - (description_box_start_pos.x or desc_x)) > 1
              or math.abs(desc_y - (description_box_start_pos.y or desc_y)) > 1
        end
        if moved_desc and settings.Texts and settings.Texts.ActionDescription and settings.Texts.ActionDescription.Pos then
          settings.Texts.ActionDescription.Pos.OffsetX = math.floor(desc_x)
          settings.Texts.ActionDescription.Pos.OffsetY = math.floor(desc_y)
          theme_options.description_box_x = math.floor(desc_x)
          theme_options.description_box_y = math.floor(desc_y)
          print('XIVHOTBAR2: saved description box position.')
        end
        description_box_start_pos = nil
      end
      if ui.set_description_draggable then ui:set_description_draggable(false) end

      do
        local gx, gy = hotbar_sets:get_pos()
        local moved_grid = false
        if hotbar_sets_start_pos then
          moved_grid = math.abs(gx - (hotbar_sets_start_pos.x or gx)) > 1
              or math.abs(gy - (hotbar_sets_start_pos.y or gy)) > 1
        end
        if moved_grid and settings.HotbarSets and settings.HotbarSets.Pos then
          settings.HotbarSets.Pos.X = math.floor(gx)
          settings.HotbarSets.Pos.Y = math.floor(gy)
          print('XIVHOTBAR2: saved hotbar set grid position.')
        end
        hotbar_sets_start_pos = nil
      end
      hotbar_sets:set_force_shown(false)

      config.save(settings)
      save_job_layout()
      print('XIVHOTBAR2: Layout mode disabled, writing new positions to settings.xml.')
      move_box:disable()
      if ui.set_environment_text_draggable then ui:set_environment_text_draggable(false) end
      if ui.set_inventory_count_draggable then ui:set_inventory_count_draggable(false) end
    end
  elseif command == 'validate' then
    hotbar_tools:set_chat_forced(true)
    hotbar_tools:validate_current(player, theme_options)
    hotbar_tools:set_chat_forced(false)
  elseif command == 'whyhidden' or command == 'why' then
    local am = require('components/xivhotbar3/lib/action_manager')
    if am.report_req_checks then am:report_req_checks() end
  elseif command == 'setbar' then
    if addon_mode ~= 'gen' then
      print('XIVHOTBAR2: setbar is only available in gen mode. Use //htb set gen mode to enable it.')
      return
    end
    local joined_args = table.concat(args, ' '):lower()
    if joined_args == 'general list' or joined_args == 'gen list' then
      local list = action_manager:get_general_list()
      if not list or #list == 0 then
        print('XIVHOTBAR2: xivhotbar_general_list is empty. Add entries to your General.lua then //htb reload.')
      else
        print('XIVHOTBAR2: xivhotbar_general_list (' .. #list .. ' entries):')
        for i, entry in ipairs(list) do
          print('  ' .. i .. '. ' .. tostring(entry))
        end
      end
    elseif args[1] == nil then
      hotbar_tools:print_preferences(player)
      print('Usage: //htb setbar <category> <1-6> [b|g|battle|field]')
    else
      local category, bar, env = hotbar_tools:parse_setbar_args(args)
      if category == nil or bar == nil then
        hotbar_tools:print_preferences(player)
        print('Usage: //htb setbar <category> <1-6> [b|g|battle|field]')
      else
        if hotbar_tools:set_category_bar(player, category, bar, env or 'battle') then
          print('XIVHOTBAR2: Run //htb autogen to populate the hotbar with your current abilities.')
        end
      end
    end
  elseif command == 'unsetbar' then
    if addon_mode ~= 'gen' then
      print('XIVHOTBAR2: unsetbar is only available in gen mode. Use //htb set gen mode to enable it.')
      return
    end
    if args[1] == nil then
      print('Usage: //htb unsetbar <dark magic|elemental magic|healing magic|enhancing magic|enfeebling magic|divine magic|blue magic|ninjutsu|songs|summoning|geomancy|trust>')
    else
      hotbar_tools:unset_category_bar(player, table.concat(args, ' '))
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'gen'
      and args[2] and tostring(args[2]):lower() == 'mode' then
    addon_mode = 'gen'
    save_addon_mode('gen')
    print('XIVHOTBAR2: Gen mode enabled. First, assign a category to each hotbar you want populated.')
    print('XIVHOTBAR2: Example: //htb setbar main 1  (main job abilities on hotbar 1)')
    print('XIVHOTBAR2: Example: //htb setbar sub 2, //htb setbar elemental magic 3, //htb setbar ws 4')
    print('XIVHOTBAR2: Use //htb help for a full command reference.')
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'manual'
      and args[2] and tostring(args[2]):lower() == 'mode' then
    addon_mode = 'manual'
    save_addon_mode('manual')
    print('XIVHOTBAR2: Manual mode enabled. Use //htb set slot to place actions on your hotbars.')
    print('XIVHOTBAR2: Syntax: //htb set slot <row> <slot> <type> <action> [target] [alias]')
    print('XIVHOTBAR2: Magic:   //htb set slot 1 1 ma Cure stpc')
    print('XIVHOTBAR2: WS:      //htb set slot 1 2 ws Savage Blade bt')
    print('XIVHOTBAR2: Ability: //htb set slot 1 3 ja Provoke bt')
    print('XIVHOTBAR2: Item:    //htb set slot 1 4 item Hi-Potion me')
    print('XIVHOTBAR2: Choice:  //htb set slot 1 5 choice elemental_magic bt Nukes')
    print('XIVHOTBAR2:   Choice opens a variant popup bar. Use //htb choice list to see all group names.')
    print('XIVHOTBAR2: Stacking tiers (e.g. Fire I-IV) requires editing the Lua file directly.')
    print("XIVHOTBAR2:   Add lowest tier first, highest last in data/<CharName>/<JOB>.lua:")
    print("XIVHOTBAR2:   {'battle 1 6', 'ma', 'Fire', 'bt', 'Fire'},")
    print("XIVHOTBAR2:   {'battle 1 6', 'ma', 'Fire IV', 'bt', 'Fire'},")
    print('XIVHOTBAR2:   The addon auto-selects the highest tier you know and can afford.')
    print('XIVHOTBAR2: Use //htb help for a full command reference.')
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'slot' then
    local VALID_TARGETS = { me=true, stpc=true, stnpc=true, bt=true, st=true, t=true, self=true }
    local row = tonumber(args[2])
    local slot_num = tonumber(args[3])
    local action_type = args[4] and tostring(args[4]):lower()
    if not row or not slot_num or not action_type or not args[5] then
      print('Usage: //htb set slot <row> <slot> <type> <action> [target] [alias]')
      print('Types: ma (magic), ws, ja, ct, item, macro')
      print('Targets: me, stpc, stnpc, bt, st (default: me)')
      print('Example: //htb set slot 1 1 ma Cure stpc')
      print('Example: //htb set slot 1 2 ws Savage Blade bt')
      print('Example: //htb set slot 1 3 ja Provoke bt Prov')
      print('Example: //htb set slot 1 4 item Hi-Potion me')
      return
    end
    local rest = {}
    for i = 5, #args do table.insert(rest, args[i]) end
    local n = #rest
    local last = rest[n] and rest[n]:lower()
    local second_last = n >= 2 and rest[n - 1] and rest[n - 1]:lower()
    local action_name, target, alias
    if n == 1 then
      action_name = rest[1]
      target = 'me'
    elseif VALID_TARGETS[last] then
      action_name = table.concat(rest, ' ', 1, n - 1)
      target = rest[n]
    elseif second_last and VALID_TARGETS[second_last] then
      action_name = table.concat(rest, ' ', 1, n - 2)
      target = rest[n - 1]
      alias = rest[n]
    else
      action_name = table.concat(rest, ' ')
      target = 'me'
    end
    if not alias then alias = action_name end
    player:insert_action({ 'm', tostring(row), tostring(slot_num), action_type, action_name, target, alias })
    print(string.format('XIVHOTBAR2: Slot %d-%d set to %s "%s". Reloading.', row, slot_num, action_type, action_name))
    reload_hotbar()
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'save' then
    local n = tonumber(args[2])
    if not n or n < 1 or n > 9 then
      print('XIVHOTBAR2: Usage: //htb set save <1-9> ["name"]')
    else
      hotbar_sets:set_player(player)

      save_job_layout()
      local name = nil
      if args[3] then
        name = table.concat(args, ' ', 3):gsub('^"(.*)"$', '%1'):gsub("^'(.*)'$", '%1')
      end
      local ok, stored = hotbar_sets:save_set(n, name)
      if ok then
        print('XIVHOTBAR2: Saved set ' .. n .. ' as "' .. tostring(stored) .. '".')
      else
        print('XIVHOTBAR2: Failed to save set ' .. n .. ' (no job file?).')
      end
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'pos' then
    local px = tonumber(args[2])
    local py = tonumber(args[3])
    if not px or not py then
      local gx, gy = hotbar_sets:get_pos()
      print('XIVHOTBAR2: Hotbar set grid is at ' .. gx .. ', ' .. gy .. '. Usage: //htb set pos <x> <y>')
    else
      hotbar_sets:move_to(px, py)
      settings.HotbarSets.Pos.X = math.floor(px)
      settings.HotbarSets.Pos.Y = math.floor(py)
      config.save(settings)
      print('XIVHOTBAR2: Hotbar set grid moved to ' .. math.floor(px) .. ', ' .. math.floor(py) .. '.')
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'load' then
    local n = tonumber(args[2])
    if not n or n < 1 or n > 9 then
      print('XIVHOTBAR2: Usage: //htb set load <1-9>')
    elseif not hotbar_sets:has_set(n) then
      print('XIVHOTBAR2: Set ' .. n .. ' is empty.')
    elseif hotbar_sets:load_set(n) then
      print('XIVHOTBAR2: Loaded set ' .. n .. ' (' .. (hotbar_sets:get_name(n) or '') .. '). Reloading.')
      windower.send_command('lua reload xivui')
    else
      print('XIVHOTBAR2: Failed to load set ' .. n .. '.')
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'clear' then
    local n = tonumber(args[2])
    if not n or n < 1 or n > 9 then
      print('XIVHOTBAR2: Usage: //htb set clear <1-9>')
    else
      hotbar_sets:clear_set(n)
      print('XIVHOTBAR2: Cleared set ' .. n .. '.')
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'list' then
    hotbar_sets:set_player(player)
    local names = hotbar_sets:get_names()
    print('XIVHOTBAR2: Hotbar sets for ' .. (player.main_job or '?') .. ':')
    for i = 1, 9 do
      if hotbar_sets:has_set(i) then
        print(string.format('  %d. %s', i, names[i] or ('Set ' .. i)))
      else
        print(string.format('  %d. (empty)', i))
      end
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'visible' then
    local now = hotbar_sets:toggle_visible()
    settings.HotbarSets.Visible = now
    if now and hotbar_sets:ensure_on_screen() then
      local gx, gy = hotbar_sets:get_pos()
      settings.HotbarSets.Pos.X = math.floor(gx)
      settings.HotbarSets.Pos.Y = math.floor(gy)
      print('XIVHOTBAR2: Grid was off-screen; recentered to ' .. math.floor(gx) .. ', ' .. math.floor(gy) .. '.')
    end
    config.save(settings)
    if now then
      local gx, gy = hotbar_sets:get_pos()
      print('XIVHOTBAR2: Hotbar set grid shown at ' .. gx .. ', ' .. gy .. '. Use //htb move or //htb set pos <x> <y> to reposition.')
    else
      print('XIVHOTBAR2: Hotbar set grid hidden.')
    end
  elseif command == 'set' and args[1] and tostring(args[1]):lower() == 'up'
      and args[2] and tostring(args[2]):lower() == 'trust' then
    local setup_args = {}
    for i = 3, #args do table.insert(setup_args, args[i]) end
    trust_setup_state = hotbar_tools:start_trust_setup(player, theme_options, setup_args)
    if trust_setup_state then reload_hotbar() end
  elseif command == 'trust' and args[1] and tostring(args[1]):lower() == 'setup' then
    local setup_args = {}
    for i = 2, #args do table.insert(setup_args, args[i]) end
    trust_setup_state = hotbar_tools:start_trust_setup(player, theme_options, setup_args)
    if trust_setup_state then reload_hotbar() end
  elseif command == 'autogen' or command == 'generate' then
    if addon_mode ~= 'gen' then
      print('XIVHOTBAR2: autogen is only available in gen mode. Use //htb set gen mode to enable it.')
      return
    end
    local filter = hotbar_tools:parse_autogen_filter(args)
    if hotbar_tools:autogenerate(player, theme_options, false, filter) then
      reload_hotbar()
    end
  elseif command == 'updategen' then
    if addon_mode ~= 'gen' then
      print('XIVHOTBAR2: updategen is only available in gen mode. Use //htb set gen mode to enable it.')
      return
    end
    local filter = hotbar_tools:parse_autogen_filter(args)
    if hotbar_tools:autogenerate(player, theme_options, true, filter) then
      reload_hotbar()
    end
  elseif command == 'resetbar' then
    local env = nil
    local bar = nil
    if args[1] and tostring(args[1]):lower() == 'all' then
      if hotbar_tools:reset_all(player, args[2]) then
        reload_hotbar()
      end
    else
      if args[1] and tonumber(args[1]) then
        local _, active_env = player:get_hotbar_info_without_vitals()
        env = active_env or 'battle'
        bar = tonumber(args[1])
      else
        env = args[1] or 'battle'
        bar = tonumber(args[2])
      end
      if hotbar_tools:reset_bar(player, env, bar) then
        reload_hotbar()
      end
    end
  elseif command == 'resetslot' then
    local env, row, slot
    if args[1] and tonumber(args[1]) then
      local _, active_env = player:get_hotbar_info_without_vitals()
      env = active_env or 'battle'
      row = tonumber(args[1])
      slot = tonumber(args[2])
    else
      env = args[1] or 'battle'
      row = tonumber(args[2])
      slot = tonumber(args[3])
    end
    if not row or not slot then
      print('Usage: //htb resetslot <row> <slot> or //htb resetslot [battle|field] <row> <slot>')
    elseif hotbar_tools:reset_slot(player, env, row, slot) then
      reload_hotbar()
    end
  elseif command == 'resetall' then
    if hotbar_tools:reset_all(player, args[1]) then
      reload_hotbar()
    end
  elseif command == 'style' then
    if hotbar_tools:apply_style(settings, args) then
      hud_current_style = tostring(args[1] or ''):lower()
      if settings.Hotbar then settings.Hotbar.StyleName = hud_current_style end
      config.save(settings)
      print('XIVHOTBAR2: style changed.')
      xivhotbar3_component.apply_style_relayout()
    end
  elseif command == 'jobscale' then
    local arg = args[1] and tostring(args[1]):lower() or nil
    if arg == 'reset' or arg == 'clear' then
      theme_options.job_scale_override = nil
      theme_options.slot_icon_scale = settings.Hotbar.Style.SlotIconScale
      ui:rescale(theme_options.slot_icon_scale or 1)
      move_box:rescale(theme_options)
      save_job_layout()
      print('XIVHOTBAR2: Job scale cleared. Using global scale: ' .. tostring(theme_options.slot_icon_scale))
    elseif tonumber(arg) then
      local new_scale = math.max(0.25, math.min(4.0, tonumber(arg)))
      new_scale = math.floor(new_scale * 100 + 0.5) / 100
      theme_options.slot_icon_scale = new_scale
      theme_options.job_scale_override = true
      ui:rescale(new_scale)
      move_box:rescale(theme_options)
      save_job_layout()
      print('XIVHOTBAR2: Job scale set to ' .. new_scale)
    else
      local global_scale = settings.Hotbar.Style.SlotIconScale or 1
      if theme_options.job_scale_override then
        print('XIVHOTBAR2: Job scale: ' .. tostring(theme_options.slot_icon_scale) .. ' (global: ' .. tostring(global_scale) .. ')')
      else
        print('XIVHOTBAR2: No job scale override. Global scale: ' .. tostring(global_scale))
      end
    end
  elseif command == 'envpos' or command == 'environmentpos' then
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    if not x or not y then
      print('Usage: //htb envpos <x> <y>. This places the Main/General text at a fixed screen position.')
    else
      settings.Texts.Environment.Pos.HookOntoBar = 0
      settings.Texts.Environment.Pos.PosX = math.floor(x)
      settings.Texts.Environment.Pos.PosY = math.floor(y)
      config.save(settings)
      print('XIVHOTBAR2: environment text position saved. Reloading addon.')
      windower.send_command('lua reload xivui')
    end
  elseif command == 'envhook' or command == 'environmenthook' then
    local bar = tonumber(args[1])
    if not bar or bar < 0 or bar > theme_options.rows then
      print('Usage: //htb envhook <0-6>. 0 = fixed PosX/PosY, 1-6 = hook next to that hotbar.')
    else
      settings.Texts.Environment.Pos.HookOntoBar = bar
      config.save(settings)
      print('XIVHOTBAR2: environment text hook saved. Reloading addon.')
      windower.send_command('lua reload xivui')
    end
  elseif command == 'collapse' then
    if args[1] and (tostring(args[1]):lower() == 'weaponskills' or tostring(args[1]):lower() == 'weaponskill' or tostring(args[1]):lower() == 'ws') then
      if hotbar_tools:collapse_weaponskills(player, theme_options, args) then
        reload_hotbar()
      end
    else
      print('Usage: //htb collapse weaponskills <hotbar 1-6> <slot 1-12> [battle|field] [current|main|range|sword|...]')
    end
  elseif command == 'hotbar' then
    if args[1] and tostring(args[1]):lower() == 'slot'
        and args[2] and tostring(args[2]):lower() == 'collapse'
        and args[3] and (tostring(args[3]):lower() == 'weaponskills' or tostring(args[3]):lower() == 'weaponskill' or tostring(args[3]):lower() == 'ws') then
      if hotbar_tools:collapse_weaponskills(player, theme_options, args) then
        reload_hotbar()
      end
    else
      print('Usage: //htb hotbar slot collapse weaponskills <hotbar 1-6> <slot 1-12> [weapon]')
    end
  elseif command == 'choice' or command == 'variants' or command == 'variant' then
    local sub = args[1] and tostring(args[1]):lower() or 'toggle'
    if sub == 'list' then
      choice_groups:print_groups()
    elseif sub == 'cancel' or sub == 'off' or sub == 'clear' then
      set_choice_modifier_state(false, true)
      if ui:is_choice_bar_active() then ui:close_choice_bar() end
    elseif sub == 'status' then
      print('XIVHOTBAR2: choice modifier is ' .. (is_choice_modifier_active() and 'enabled' or 'disabled') .. '. Mode: ' .. tostring(theme_options.controls_choice_modifier_mode or 'toggle') .. '.')
    elseif tonumber(args[1]) and tonumber(args[2]) then
      local row = tonumber(args[1])
      local slot = tonumber(args[2])
      player:change_active_hotbar(row)
      open_slot_variants_for_active_hotbar(slot)
    elseif sub == 'arm' or sub == 'on' or sub == 'next' then
      set_choice_modifier_state(true, true)
    elseif sub == 'toggle' then
      set_choice_modifier_state(not is_choice_modifier_active(), true)
    else
      print('Usage: //htb choice [on|off|toggle|list|cancel|status] or //htb choice <hotbar> <slot>')
    end
  elseif command == 'choiceindicator' or command == 'choiceind' then
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    if x == nil or y == nil then
      print('Usage: //htb choiceindicator <xOffset> <yOffset>')
    else
      if settings.Hotbar.ChoiceBar == nil then settings.Hotbar.ChoiceBar = {} end
      settings.Hotbar.ChoiceBar.IndicatorOffsetX = x
      settings.Hotbar.ChoiceBar.IndicatorOffsetY = y
      if theme_options.choice_bar == nil then theme_options.choice_bar = {} end
      theme_options.choice_bar.IndicatorOffsetX = x
      theme_options.choice_bar.IndicatorOffsetY = y
      ui.theme.choice_bar = theme_options.choice_bar
      if ui.update_choice_modifier_indicator_position then ui:update_choice_modifier_indicator_position() end
      config.save(settings)
      print('XIVHOTBAR2: choice mode indicator offset set to ' .. tostring(x) .. ', ' .. tostring(y) .. '.')
    end

  elseif command == 'choicekey' or command == 'modifier' then
    if args[1] == nil then
      local shift_text = theme_options.controls_choice_modifier_shift_required and ' + Shift required' or ''
      print('XIVHOTBAR2: Current choice modifier DIK is ' .. tostring(theme_options.controls_choice_modifier or 58) .. shift_text .. '. Mode: ' .. tostring(theme_options.controls_choice_modifier_mode or 'toggle') .. '. Examples: //htb choicekey capslock, //htb choicekey 58')
    else
      local key_arg = tostring(args[1] or ''):lower()
      if key_arg == 'fn' then
        print('XIVHOTBAR2: Fn cannot be used as a Windower/DIK modifier on normal keyboards because it usually never reaches Windows or DirectInput. Use a real DIK key instead, like CapsLock.')
        return
      end

      local dik = tonumber(args[1])
      local shift_required = false
      if key_arg == 'tilde' or key_arg == '~' then
        dik = 41
        shift_required = true
      elseif key_arg == 'grave' or key_arg == 'backtick' or key_arg == '`' then
        dik = 41
        shift_required = false
      elseif key_arg == 'caps' or key_arg == 'capslock' or key_arg == 'caps_lock' then
        dik = 58
        shift_required = false
      end

      if dik == nil then
        print('Usage: //htb choicekey <DIK number|capslock|grave|tilde>. Fn is not available as a DIK key on normal keyboards.')
      else
        settings.Controls.ChoiceModifier = dik
        settings.Controls.ChoiceModifierShiftRequired = shift_required
        config.save(settings)
        local label = shift_required and ('Shift+DIK ' .. tostring(dik)) or ('DIK ' .. tostring(dik))
        print('XIVHOTBAR2: Choice modifier set to ' .. label .. '. Reloading addon.')
        windower.send_command('lua reload xivui')
      end
    end
  elseif command == 'choicemode' or command == 'modifiermode' then
    if args[1] == nil then
      print('XIVHOTBAR2: Current choice modifier mode is ' .. tostring(theme_options.controls_choice_modifier_mode or 'toggle') .. '. Use //htb choicemode toggle, hold, or oneshot.')
    else
      local mode = tostring(args[1] or ''):lower()
      if mode == 'one-shot' or mode == 'tap' then mode = 'oneshot' end
      if mode ~= 'hold' and mode ~= 'oneshot' and mode ~= 'toggle' then
        print('Usage: //htb choicemode toggle|hold|oneshot')
      else
        settings.Controls.ChoiceModifierMode = mode
        config.save(settings)
        print('XIVHOTBAR2: Choice modifier mode set to ' .. mode .. '. Reloading addon.')
        windower.send_command('lua reload xivui')
      end
    end
  elseif command == 'perf' or command == 'performance' then
    local mode = tostring(args[1] or 'status'):lower()
    settings.Hotbar.Behavior = settings.Hotbar.Behavior or {}

    local function apply_perf(label, recast_frames, hover_frames, weapon_poll, animated_highlights)
      settings.Hotbar.Behavior.RecastCheckIntervalFrames = recast_frames
      settings.Hotbar.Behavior.HoverCheckIntervalFrames = hover_frames
      settings.Hotbar.Behavior.WeaponPollSeconds = weapon_poll
      if animated_highlights ~= nil then
        settings.Hotbar.UseAnimatedHighlights = animated_highlights
      end
      config.save(settings)
      print('XIVHOTBAR2: performance preset "' .. label .. '" saved. Reloading addon.')
      windower.send_command('lua reload xivui')
    end

    if mode == 'low' or mode == 'potato' then
      apply_perf('low', 20, 5, 5, false)
    elseif mode == 'normal' or mode == 'balanced' or mode == 'default' then
      apply_perf('normal', 10, 3, 2, true)
    elseif mode == 'high' or mode == 'smooth' then
      apply_perf('high', 3, 1, 2, true)
    elseif mode == 'custom' then
      local recast_frames = tonumber(args[2])
      local hover_frames = tonumber(args[3])
      if recast_frames == nil or hover_frames == nil or recast_frames < 1 or hover_frames < 1 then
        print('Usage: //htb perf custom <recastIntervalFrames> <hoverIntervalFrames> [weaponPollSeconds]')
      else
        settings.Hotbar.Behavior.RecastCheckIntervalFrames = math.floor(recast_frames)
        settings.Hotbar.Behavior.HoverCheckIntervalFrames = math.floor(hover_frames)
        if tonumber(args[4]) then settings.Hotbar.Behavior.WeaponPollSeconds = tonumber(args[4]) end
        config.save(settings)
        print('XIVHOTBAR2: custom performance settings saved. Reloading addon.')
        windower.send_command('lua reload xivui')
      end
    else
      print('XIVHOTBAR2 performance: recast every ' .. tostring(theme_options.recast_check_interval_frames or 10) .. ' frame(s), hover every ' .. tostring(theme_options.hover_check_interval_frames or 3) .. ' frame(s), weapon poll every ' .. tostring(theme_options.weapon_poll_seconds or 2) .. 's.')
      print('Usage: //htb perf low | normal | high | custom <recastFrames> <hoverFrames> [weaponPollSeconds]')
    end

  elseif command == 'bstcharge' then
    local seconds = tonumber(args[1])
    if seconds == nil or seconds < 1 then
      print('XIVHOTBAR2: Current BST Ready charge seconds: ' .. tostring(theme_options.bst_ready_charge_seconds or 30) .. '. Usage: //htb bstcharge <seconds>')
    else
      settings.Hotbar.Recasts = settings.Hotbar.Recasts or {}
      settings.Hotbar.Recasts.BstReadyChargeSeconds = seconds
      config.save(settings)
      print('XIVHOTBAR2: BST Ready charge time set to ' .. tostring(seconds) .. ' seconds. Reloading addon.')
      windower.send_command('lua reload xivui')
    end
  elseif command == 'schchargebase' then
    local seconds = tonumber(args[1])
    if seconds == nil or seconds < 1 then
      print('XIVHOTBAR2: Current SCH stratagem base recharge seconds: ' .. tostring(theme_options.scholar_base_recharge_seconds or 240) .. '. Usage: //htb schchargebase <seconds>')
    else
      settings.Hotbar.Recasts = settings.Hotbar.Recasts or {}
      settings.Hotbar.Recasts.ScholarBaseRechargeSeconds = seconds
      config.save(settings)
      print('XIVHOTBAR2: SCH stratagem base recharge set to ' .. tostring(seconds) .. ' seconds. Reloading addon.')
      windower.send_command('lua reload xivui')
    end
  elseif command == 'weaponpriority' then
    local mode = tostring(args[1] or ''):lower()
    if mode == '' then
      print('XIVHOTBAR2: Current weapon priority is ' .. tostring(theme_options.weapon_skill_priority or 'auto') .. '. Usage: //htb weaponpriority auto|main|range')
    elseif mode == 'auto' or mode == 'main' or mode == 'melee' or mode == 'range' or mode == 'ranged' then
      if mode == 'melee' then mode = 'main' end
      if mode == 'ranged' then mode = 'range' end
      settings.Hotbar.Behavior = settings.Hotbar.Behavior or {}
      settings.Hotbar.Behavior.WeaponSkillPriority = mode
      config.save(settings)
      print('XIVHOTBAR2: Weapon skill priority set to ' .. mode .. '. Reloading addon.')
      windower.send_command('lua reload xivui')
    else
      print('Usage: //htb weaponpriority auto|main|range')
    end
  elseif command == 'petrefresh' or command == 'petset' then
    local arg = table.concat(args, ' ')
    if arg == nil or arg == '' then
      local pet = windower.ffxi.get_mob_by_target('pet') or nil
      if pet ~= nil and pet.name ~= nil and pet.name ~= '' then
        player:update_pet(pet.name)
        request_hotbar_reload('manual pet refresh', 0.1, pet.name)
        print('XIVHOTBAR2: Pet refreshed as ' .. pet.name .. '.')
      else
        print('XIVHOTBAR2: No visible pet target found. Current cached pet is "' .. tostring(player.pet_name or '') .. '". Use //htb petrefresh <name> or //htb petrefresh clear.')
      end
    elseif arg:lower() == 'clear' or arg:lower() == 'none' then
      player:update_pet('')
      request_hotbar_reload('manual pet clear', 0.1, '')
      print('XIVHOTBAR2: Pet cache cleared.')
    else
      player:update_pet(arg)
      request_hotbar_reload('manual pet set', 0.1, arg)
      print('XIVHOTBAR2: Pet manually set to ' .. arg .. '.')
    end
  elseif command == 'bars' then
    local max = theme_options.hotbar_number or 6
    local sub = args[1] and args[1]:lower() or ''
    local is_main = sub == 'main'
    local is_gen  = sub == 'gen' or sub == 'field'
    local n = tonumber(is_main and args[2] or is_gen and args[2] or args[1])
    if not n or n < 1 or n > max then
      local main_cur = theme_options.visible_hotbar_count or max
      local gen_cur  = theme_options.field_visible_hotbar_count or main_cur
      print('XIVHOTBAR2: Main bars: ' .. tostring(main_cur) .. ', General bars: ' .. tostring(gen_cur) .. ' (max ' .. tostring(max) .. ')')
      print('XIVHOTBAR2: Usage: //htb bars <n>  |  //htb bars main <n>  |  //htb bars gen <n>')
    elseif is_gen then
      theme_options.field_visible_hotbar_count = n
      ui.theme.field_visible_hotbar_count = n
      save_job_layout()
      reload_hotbar()
      print('XIVHOTBAR2: General bars set to ' .. n .. '.')
    else
      theme_options.visible_hotbar_count = n
      ui.theme.visible_hotbar_count = n
      move_box.theme.visible_hotbar_count = n
      if not is_main then
        theme_options.field_visible_hotbar_count = nil
        ui.theme.field_visible_hotbar_count = nil
      end
      save_job_layout()
      reload_hotbar()
      print('XIVHOTBAR2: Main bars set to ' .. n .. (is_main and '.' or ' (general bars follow main).'))
    end
  elseif command == 'autora' then
    local sub = args[1] and tostring(args[1]):lower() or 'status'
    if sub == 'stop' or sub == 'off' then
      player.autora_active = false
      player.autora_pending_at = nil
      player.autora_last_fire = nil
      print('XIVHOTBAR2: Auto ranged attack stopped.')
    elseif sub == 'start' or sub == 'on' then
      if autora_has_weapon_and_ammo() then
        player.autora_active = true
        autora_queue(0.1)
        print('XIVHOTBAR2: Auto ranged attack started.')
      else
        print('XIVHOTBAR2: No ranged weapon or ammo equipped.')
      end
    else
      print('XIVHOTBAR2: autora is ' .. (player.autora_active and 'active' or 'stopped') .. '. Use //htb autora stop or the hotbar button to toggle.')
    end
  elseif command == 'hideempty' then
    local env_arg = args[1] and tostring(args[1]):lower()
    local envs, row, label
    if env_arg == 'main' or env_arg == 'battle' then
      envs = { 'battle' }; row = tonumber(args[2]); label = 'Main'
    elseif env_arg == 'gen' or env_arg == 'general' or env_arg == 'field' then
      envs = { 'field' }; row = tonumber(args[2]); label = 'General'
    else
      envs = { 'battle', 'field' }; row = tonumber(args[1]); label = 'Main+General'
    end
    local max = theme_options.hotbar_number or 6
    if not row or row < 1 or row > max then
      print('XIVHOTBAR2: Usage: //htb hideempty [main|gen] <1-' .. tostring(max) .. '>')
    else
      theme_options.hide_empty_rows = theme_options.hide_empty_rows or {}
      theme_options.hide_empty_rows.battle = theme_options.hide_empty_rows.battle or {}
      theme_options.hide_empty_rows.field = theme_options.hide_empty_rows.field or {}
      if ui.theme then ui.theme.hide_empty_rows = theme_options.hide_empty_rows end

      local new_state = not (theme_options.hide_empty_rows[envs[1]][row] == true)
      for _, e in ipairs(envs) do
        theme_options.hide_empty_rows[e][row] = new_state or nil
      end
      print('XIVHOTBAR2: Hotbar ' .. row .. ' unused slots are now ' ..
        (new_state and 'hidden' or 'visible') .. ' (' .. label .. ').')
      save_job_layout()
      reload_hotbar()
    end
  elseif command == 'sc' then
    local target = windower.ffxi.get_mob_by_target('t')
    if target then
      local combos = skillchains:get_potential_skillchains(target.id)
      local mb_elements = skillchains:get_magic_burst_elements(target.id)

      if combos then
        windower.add_to_chat(8, '--------COMBOS-------')
        for key, _ in pairs(combos) do
          windower.add_to_chat(8, tostring(key))
        end
      end

      if mb_elements then
        windower.add_to_chat(8, '--------MB-------')
        for key, _ in pairs(mb_elements) do
          windower.add_to_chat(8, tostring(key))
        end
      end

      windower.add_to_chat(8, '--------POT-------')
      local potential = skillchains:get_potential_skillchains(target.id)
      printTable(potential)

      if args[1] then
        local props = {}
        for i, value in ipairs(args) do
          table.insert(props, args[i])
        end
        skillchains:attempt_skillchain(target.id, props)
      end
    end
  end
end

htb_register('keyboard', function(dik, flags, blocked)
  if ui.hotbar.ready == false or windower.ffxi.get_info().chat_open then
    return
  end

  if ui.hotbar.hide_hotbars then
    return
  end

  local pressed = key_is_down(flags)

  if dik == 42 or dik == 54 then
    modifier_shift_held = pressed
    if not modifier_shift_held and theme_options.controls_choice_modifier_shift_required == true then
      choice_modifier_held = false
    end
  end

  if dik == theme_options.controls_choice_modifier then
    local shift_ok = true
    if theme_options.controls_choice_modifier_shift_required == true then
      shift_ok = modifier_shift_held == true
    end

    if shift_ok then
      local mode = tostring(theme_options.controls_choice_modifier_mode or 'toggle'):lower()
      if mode == 'hold' then
        set_choice_modifier_state(pressed, false)
        if not pressed then
          choice_modifier_key_down = false
        end
      else
        if pressed and choice_modifier_key_down == false then
          choice_modifier_key_down = true
          if is_choice_modifier_active() then
            set_choice_modifier_state(false, true)
          else
            set_choice_modifier_state(true, mode == 'toggle')
            if mode == 'oneshot' then
              print('XIVHOTBAR2: one-shot choice mode armed. Press a hotbar key to open variants. Press the modifier again to cancel.')
            end
          end
        elseif not pressed then
          choice_modifier_key_down = false
        end
      end
      return
    elseif not pressed then
      choice_modifier_key_down = false
      set_choice_modifier_state(false, false)
    end
  end

  if pressed and ui:is_choice_bar_active() and (dik == 1 or dik == 14) then
    ui:close_choice_bar()
    return
  end

  if dik == theme_options.controls_battle_mode and pressed then
    toggle_environment()
  end
end)

local current_hotbar = -1
local current_action = -1

local slot_drag = { pressed = false, dragging = false, h = 0, i = 0, sx = 0, sy = 0,
                    icon_path = nil, ghost = nil, ghost_cur = nil }
local SLOT_DRAG_THRESHOLD = 6

local function slotdrag_ghost()
    if not slot_drag.ghost then
        slot_drag.ghost = images.new({ pos = { x = 0, y = 0 }, visible = false,
            color = { alpha = 255, red = 255, green = 255, blue = 255 }, size = { width = 32, height = 32 },
            texture = { path = '', fit = true }, repeatable = { x = 1, y = 1 }, draggable = false })
        pcall(function() slot_drag.ghost:draggable(false); slot_drag.ghost:fit(true); slot_drag.ghost:hide() end)
    end
    return slot_drag.ghost
end

local function slotdrag_reset()
    if slot_drag.ghost then pcall(function() slot_drag.ghost:hide() end) end
    slot_drag.pressed, slot_drag.dragging, slot_drag.h, slot_drag.i = false, false, 0, 0
end

local function slotdrag_press(h, i, x, y)
    slot_drag.pressed, slot_drag.dragging = true, false
    slot_drag.h, slot_drag.i, slot_drag.sx, slot_drag.sy = h, i, x, y
    local hb = ui.hotbars and ui.hotbars[h]
    local ic = hb and hb.slot_icons and hb.slot_icons[i]
    local ok, p = pcall(function() return ic and ic:path() end)
    slot_drag.icon_path = (ok and p) or nil
end

local function slotdrag_move(x, y)
    if not slot_drag.pressed then return false end
    if not slot_drag.dragging then
        if math.abs(x - slot_drag.sx) + math.abs(y - slot_drag.sy) < SLOT_DRAG_THRESHOLD then return false end
        slot_drag.dragging = true
    end
    local hb = ui.hotbars and ui.hotbars[slot_drag.h]
    local ic = hb and hb.slot_icons and hb.slot_icons[slot_drag.i]
    if ic then pcall(ic.hide, ic) end
    local g = slotdrag_ghost()
    if slot_drag.icon_path and slot_drag.icon_path ~= '' and slot_drag.ghost_cur ~= slot_drag.icon_path then
        pcall(function() g:path(slot_drag.icon_path); g:fit(true) end); slot_drag.ghost_cur = slot_drag.icon_path
    end
    local sz = ui.image_width or 32
    local r, c, bx, by, bw, bh = xivhotbar3_component.slot_box_at(x, y)
    if r and bx then g:size(bw, bh); g:pos(bx, by)
    else g:size(sz, sz); g:pos(x - math.floor(sz / 2), y - math.floor(sz / 2)) end
    pcall(function() g:alpha(255); g:show() end)
    return true
end

local SLOTDRAG_MERGE_TYPES = { ma = true, ja = true, ws = true, item = true }

local function slotdrag_merge_entry(a)
    return { type = tostring(a.type or ''):lower(), action = a.action,
             target = (a.target and a.target ~= '' and a.target) or 'me',
             alias = a.alias or a.action, icon = a.icon }
end

local function merge_decline(reason)
    local say = _G.xivui_echo or print
    say('XIVHOTBAR2: drag merge fell back to swap (' .. reason .. ').')
    return false
end

local function merge_entry_into_slot(dst, dest_h, dest_i, environment, src_entry)
    local pl = windower.ffxi.get_player()
    local dt = tostring(dst.type or ''):lower()
    if dt == 'choice' then
        if not choice_groups:is_user_group(dst.action) then
            return merge_decline('"' .. tostring(dst.action) .. '" is a built-in choice; only your custom choices accept merges')
        end
        local g = choice_groups:get_user_group(pl, dst.action)
        if not g then return merge_decline('choice group not found') end
        local entries = {}
        for _, e in ipairs(g.entries or {}) do entries[#entries + 1] = e end
        entries[#entries + 1] = src_entry
        choice_groups:save_user_group(pl, { id = g._user_id, label = g.label, alias = g.alias,
            icon = g.icon, jobs = g.jobs, autogen = g.autogen, entries = entries })
        print(string.format('XIVHOTBAR2: "%s" added to choice "%s".', tostring(src_entry.action), tostring(g.label)))
        return true
    end
    if not SLOTDRAG_MERGE_TYPES[dt] then
        return merge_decline('target slot is a ' .. tostring(dst.type) .. ', not a mergeable action')
    end
    local label = tostring(dst.alias or dst.action)
    local id = choice_groups:new_user_group_id(pl, label)
    choice_groups:save_user_group(pl, { id = id, label = label, icon = dst.icon,
        entries = { slotdrag_merge_entry(dst), src_entry } })
    local dest_slot = player:get_visible_slot_index(dest_h, dest_i, environment) or dest_i
    local prio = (environment == 'field') and 'g' or 'm'
    hotbar_tools:reset_slot(player, environment, dest_h, dest_slot)
    player:insert_action({ prio, tostring(dest_h), tostring(dest_slot), 'choice', id, '', label, dst.icon })
    print(string.format('XIVHOTBAR2: Merged "%s" + "%s" into choice "%s".',
        tostring(dst.action), tostring(src_entry.action), label))
    return true
end

local function slotdrag_merge(h, i, actual, dest_h, dest_i, environment)
    if not (theme_options and theme_options.choice_drag_merge) then return false end
    local src = player:get_visible_action(environment, h, i)
    local dst = player:get_visible_action(environment, dest_h, dest_i)
    if not src or not dst then return false end
    if src.is_dynamic or dst.is_dynamic then return merge_decline('auto-ranged slots cannot merge') end
    if not SLOTDRAG_MERGE_TYPES[tostring(src.type or ''):lower()] then
        return merge_decline('dragged slot is a ' .. tostring(src.type) .. ', not a mergeable action')
    end
    if not merge_entry_into_slot(dst, dest_h, dest_i, environment, slotdrag_merge_entry(src)) then
        return false
    end
    player:remove_action({ source = { row = h, slot = i, actual_slot = actual } })
    return true
end

local function slotdrag_drop(x, y)
    if not slot_drag.dragging then slot_drag.pressed = false; return false end
    local h, i = slot_drag.h, slot_drag.i
    slotdrag_reset()
    local _, environment = player:get_hotbar_info_without_vitals()
    environment = environment or 'battle'
    local actual = player:get_visible_slot_index(h, i, environment)
    local dest_h, dest_i = ui:hovered(x, y)
    if not dest_h or not dest_i or dest_i == 100 then
        local r, c = xivhotbar3_component.slot_box_at(x, y)
        dest_h, dest_i = r, c
    end
    if hotbar_tools:overlay_owns_bar(player, environment, h)
            or (dest_h and hotbar_tools:overlay_owns_bar(player, environment, dest_h)) then
        local say = _G.xivui_echo or print
        say('XIVHOTBAR2: that bar is auto-generated — reorder or exclude its actions in the AUTOGEN panel.')
        reload_hotbar()
        return true
    end
    if dest_h and dest_i and not (dest_h == h and dest_i == i) then
        if not slotdrag_merge(h, i, actual, dest_h, dest_i, environment or 'battle') then
            player:swap_actions({ source = { row = h, slot = i, actual_slot = actual }, dest = { row = dest_h, slot = dest_i } })
        end
        reload_hotbar()
    elseif not (dest_h and dest_i) then
        player:remove_action({ source = { row = h, slot = i, actual_slot = actual } })
        reload_hotbar()
    else
        reload_hotbar()
    end
    return true
end

local function mouse_hotbars(type, x, y, delta, blocked)
  return_value = false

  if not ui.hotbar.hide_hotbars then
    if type == 0 and rmbPressedInHotbar then return true end
    if type == 1 then
      local choice_arrow_dir = ui.hovered_choice_page_arrow and ui:hovered_choice_page_arrow(x, y)
      if choice_arrow_dir ~= nil then
        current_hotbar = -4
        current_action = choice_arrow_dir
        return true
      end

      local arrow_row, arrow_dir = ui:hovered_category_page_arrow(x, y)
      if arrow_row ~= nil then
        current_hotbar = -3
        current_action = { row = arrow_row, direction = arrow_dir }
        return true
      end

      local choice_slot = ui:hovered_choice(x, y)
      if choice_slot ~= nil then
        current_hotbar = -2
        current_action = choice_slot
        return true
      end

      local hotbar, action = ui:hovered(x, y)
      if (action ~= nil) then
        current_hotbar = hotbar
        current_action = action
        if action ~= 100 then slotdrag_press(hotbar, action, x, y) end
        return_value = true
      else
        local _b = htb_bounds_cache
        local _cb = choice_bounds_cache
        if (_b and x >= _b.x and x <= _b.x + _b.w and y >= _b.y and y <= _b.y + _b.h)
        or (_cb and x >= _cb.x and x <= _cb.x + _cb.w and y >= _cb.y and y <= _cb.y + _cb.h) then
          lmbPressedInHotbar = true
          return true
        end
        return_value = false
      end
    elseif type == 2 then
      if slotdrag_drop(x, y) then current_hotbar = -1; current_action = -1; return true end
      if current_hotbar == -4 then
        local choice_arrow_dir = ui.hovered_choice_page_arrow and ui:hovered_choice_page_arrow(x, y)
        if choice_arrow_dir ~= nil and choice_arrow_dir == current_action then
          if choice_arrow_dir == 'prev' then ui:choice_prev_page()
          else ui:choice_next_page() end
        end
        current_hotbar = -1
        current_action = -1
        return true
      elseif current_hotbar == -3 then
        local arrow_row, arrow_dir = ui:hovered_category_page_arrow(x, y)
        if arrow_row ~= nil and current_action ~= nil and arrow_row == current_action.row and arrow_dir == current_action.direction then
          ui:change_category_page(arrow_row, arrow_dir)
        end
        current_hotbar = -1
        current_action = -1
        return true
      elseif current_hotbar == -2 then
        local choice_slot = ui:hovered_choice(x, y)
        if choice_slot ~= nil and choice_slot == current_action then
          trigger_choice_action(choice_slot)
        end
        current_hotbar = -1
        current_action = -1
        return true
      elseif (current_action ~= -1) then
        local hotbar, action = ui:hovered(x, y)
        if (action ~= nil) then
          if (action == 100) then
            if ui:is_choice_bar_active() then ui:close_choice_bar() end
            toggle_environment()
          elseif (hotbar == current_hotbar and action == current_action) then
            player:change_active_hotbar(hotbar)
            trigger_action(action)
          end
        end
        current_hotbar = -1
        current_action = -1
        return_value = true
      else
        if lmbPressedInHotbar then
          lmbPressedInHotbar = false
          return true
        end
        return_value = false
      end
    elseif type == 3 or type == 4 then
      if ui:is_choice_bar_active() then
        ui:close_choice_bar()
        current_hotbar = -1
        current_action = -1
        rmbPressedInHotbar = false
        return true
      end

      local hotbar, action = ui:hovered(x, y)
      if action ~= nil and hotbar ~= nil and action ~= 100 then
        player:change_active_hotbar(hotbar)
        open_slot_variants_for_active_hotbar(action)
        if type == 3 then rmbPressedInHotbar = true end
        return true
      end

      local _b = htb_bounds_cache
      local _cb = choice_bounds_cache
      local _inBounds = (_b and x >= _b.x and x <= _b.x + _b.w and y >= _b.y and y <= _b.y + _b.h)
                     or (_cb and x >= _cb.x and x <= _cb.x + _cb.w and y >= _cb.y and y <= _cb.y + _cb.h)
      if type == 3 then
        rmbPressedInHotbar = _inBounds == true
        if _inBounds then return true end
      elseif type == 4 then
        if rmbPressedInHotbar then
          rmbPressedInHotbar = false
          return true
        end
      end
      return false
    elseif type == 0 then
      if slotdrag_move(x, y) then ui:hide_hover(); return true end
      if ui.hovered_choice_page_arrow and ui:hovered_choice_page_arrow(x, y) then
        ui:hide_hover()
        return true
      end

      local arrow_row, arrow_dir = ui:hovered_category_page_arrow(x, y)
      if arrow_row ~= nil then
        ui:hide_hover()
        return true
      end

      local choice_slot = ui:hovered_choice(x, y)
      if choice_slot ~= nil then
        ui:light_up_choice_action(x, y, choice_slot)
        return true
      end

      local hotbar, action = ui:hovered(x, y)
      if (action ~= nil and hotbar ~= nil) then
        ui:light_up_action(x, y, hotbar, action)
        return_value = true
      else
        ui:hide_hover()
        return_value = false
      end
    end
  else
    rmbPressedInHotbar = false
    lmbPressedInHotbar = false
  end

  return return_value
end

local external_drag_active = false

htb_register('mouse', function(type, x, y, delta, blocked)
  return_value = nil
  if external_drag_active then return false end
  if hud_layout_open() then return false end
  if menu_covers(x, y) then return false end
  if state.ready == true and blocked == false then
    if reposition_mode.active then
      if type == 1 then
        reposition_mode.drag.active = true
        reposition_mode.drag.start_x = x
        reposition_mode.drag.start_y = y
        return true
      elseif type == 0 then
        if reposition_mode.drag.active then
          ui.reposition_offset_x = x - reposition_mode.drag.start_x
          ui.reposition_offset_y = y - reposition_mode.drag.start_y
          ui:reposition_all_bars()
        end
        return true
      elseif type == 10 then
        if reposition_mode.bargap_mode == 'hotbar' then
          local step = delta > 0 and 1 or -1
          local new_val = math.max(0, math.min(400, theme_options.hotbar_spacing + step))
          theme_options.hotbar_spacing = new_val
          ui.hotbar_spacing = new_val
          local save_val = new_val + (theme_options.hide_action_names and 10 or 0)
          settings.Hotbar.Style.HotbarSpacing = save_val
          config.save(settings)
          ui:reposition_all_bars()
          print('XIVHOTBAR2: Hotbar row spacing: ' .. new_val)
        elseif reposition_mode.bargap_mode == 'icon_h' then
          local step = delta > 0 and 1 or -1
          local new_val = math.max(0, math.min(200, theme_options.slot_spacing + step))
          theme_options.slot_spacing = new_val
          ui.slot_spacing = new_val
          settings.Hotbar.Style.SlotSpacing = new_val
          config.save(settings)
          move_box:rescale(theme_options)
          ui:reposition_all_bars()
          print('XIVHOTBAR2: Horizontal icon spacing: ' .. new_val)
        elseif reposition_mode.bargap_mode == 'icon_v' then
          local step = delta > 0 and 1 or -1
          local new_val = math.max(0, math.min(200, theme_options.vertical_slot_spacing + step))
          theme_options.vertical_slot_spacing = new_val
          ui.vertical_slot_spacing = new_val
          settings.Hotbar.Style.VerticalSlotSpacing = new_val
          config.save(settings)
          move_box:rescale(theme_options)
          ui:reposition_all_bars()
          print('XIVHOTBAR2: Vertical icon spacing: ' .. new_val)
        elseif reposition_mode.bargap_mode == 'descsize' then
          local step = delta > 0 and 1 or -1
          local new_val = math.max(4, math.min(72, theme_options.font_size_descr + step))
          theme_options.font_size_descr = new_val
          settings.Texts.ActionDescription.Size = new_val
          config.save(settings)
          if ui.action_description then ui.action_description:size(new_val + 5) end
          print('XIVHOTBAR2: Description tooltip size: ' .. new_val)
        else
          local current = theme_options.slot_icon_scale or 1
          local new_scale = math.max(0.25, math.min(4.0, current + delta / 20))
          new_scale = math.floor(new_scale * 100 + 0.5) / 100
          ui:rescale(new_scale)
          move_box:rescale(theme_options)
          settings.Hotbar.Style.SlotIconScale = new_scale
          config.save(settings)
          print('XIVHOTBAR2: Scale set to ' .. new_scale)
        end
        return true
      elseif type == 2 then
        if reposition_mode.drag.active then
          reposition_mode.drag.active = false
          local dx = math.floor(x - reposition_mode.drag.start_x)
          local dy = math.floor(y - reposition_mode.drag.start_y)
          if dx ~= 0 or dy ~= 0 then
            local offset_names = { 'First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth' }
            for _, name in ipairs(offset_names) do
              if settings.Hotbar.Offsets[name] then
                settings.Hotbar.Offsets[name].OffsetX = settings.Hotbar.Offsets[name].OffsetX + dx
                settings.Hotbar.Offsets[name].OffsetY = settings.Hotbar.Offsets[name].OffsetY + dy
              end
            end
            if settings.Hotbar.ChoiceBar then
              settings.Hotbar.ChoiceBar.OffsetX = (settings.Hotbar.ChoiceBar.OffsetX or 675) + dx
              settings.Hotbar.ChoiceBar.OffsetY = (settings.Hotbar.ChoiceBar.OffsetY or 740) + dy
            end
            for h = 1, (theme_options.rows or 6) do
              local key = tostring(h)
              if theme_options.offsets and theme_options.offsets[key] then
                theme_options.offsets[key].OffsetX = theme_options.offsets[key].OffsetX + dx
                theme_options.offsets[key].OffsetY = theme_options.offsets[key].OffsetY + dy
              end
            end
            if theme_options.choice_bar then
              theme_options.choice_bar.OffsetX = (theme_options.choice_bar.OffsetX or 675) + dx
              theme_options.choice_bar.OffsetY = (theme_options.choice_bar.OffsetY or 740) + dy
            end
            ui.reposition_offset_x = 0
            ui.reposition_offset_y = 0
            ui:reposition_all_bars()
            config.save(settings)
            save_job_layout()
            print('XIVHOTBAR2: Hotbar position saved.')
          else
            ui.reposition_offset_x = 0
            ui.reposition_offset_y = 0
          end
        end
        return true
      end
    end
    if custom_slot_mode.active then
      if type == 1 then
        local hotbar, slot = ui:hovered(x, y)
        if hotbar == custom_slot_mode.hotbar and slot and slot ~= 100 then
          local cur = ui:get_slot_custom_offset(hotbar, slot)
          custom_slot_mode.drag.active = true
          custom_slot_mode.drag.slot = slot
          custom_slot_mode.drag.start_mouse_x = x
          custom_slot_mode.drag.start_mouse_y = y
          custom_slot_mode.drag.start_dx = cur and cur.dx or 0
          custom_slot_mode.drag.start_dy = cur and cur.dy or 0
          return true
        end
      elseif type == 0 then
        if custom_slot_mode.drag.active then
          local new_dx = custom_slot_mode.drag.start_dx + (x - custom_slot_mode.drag.start_mouse_x)
          local new_dy = custom_slot_mode.drag.start_dy + (y - custom_slot_mode.drag.start_mouse_y)
          ui:set_slot_custom_offset(custom_slot_mode.hotbar, custom_slot_mode.drag.slot, new_dx, new_dy)
          ui:reposition_slot(custom_slot_mode.hotbar, custom_slot_mode.drag.slot)
          return true
        end
      elseif type == 2 then
        if custom_slot_mode.drag.active then
          custom_slot_mode.drag.active = false
          return true
        end
        return false
      end
    end
    if state.demo == true then

      if type == 1 and hotbar_sets:point_in_grid(x, y) then
        sets_grid_drag.active = true
        sets_grid_drag.start_mouse_x = x
        sets_grid_drag.start_mouse_y = y
        sets_grid_drag.start_x, sets_grid_drag.start_y = hotbar_sets:get_pos()
        return true
      elseif type == 0 and sets_grid_drag.active then
        hotbar_sets:move_to(sets_grid_drag.start_x + (x - sets_grid_drag.start_mouse_x),
          sets_grid_drag.start_y + (y - sets_grid_drag.start_mouse_y))
        return true
      elseif type == 2 and sets_grid_drag.active then
        sets_grid_drag.active = false
        return true
      end

      if is_choice_modifier_active() then
        if type == 1 then
          local hotbar, action_slot = ui:hovered(x, y)
          if action_slot and action_slot ~= 100 and hotbar then
            local env = select(2, player:get_hotbar_info_without_vitals())
            local action = player:get_visible_action(env, hotbar, action_slot)
            if action and tostring(action.type or ''):lower() == 'choice' then
              local is_disabled = ui.disabled_slots and (
                (ui.disabled_slots.on_cooldown and ui.disabled_slots.on_cooldown[action.action] == true) or
                (ui.disabled_slots.actions and ui.disabled_slots.actions[action.action] == true)
              )
              if not is_disabled then
                player:change_active_hotbar(hotbar)
                local choices, _ = choice_groups:resolve(player, action.action)
                if choices and #choices > 0 then
                  ui:open_choice_bar(action.action, choice_groups:get_label(action.action, player), choices, hotbar)
                end
              end
              return true
            end
          end
        end
      end

      return_value = move_box:move_hotbars(type, x, y, delta, blocked)
      if not return_value and (type == 1 or type == 2) then
        local htb, slot = ui:hovered(x, y)
        if htb ~= nil or slot ~= nil then return_value = true end
      end
      local moved_info = move_box:get_move_box_info()
      if moved_info ~= nil and type == 1 and moved_info.slot_active == true then
        moved_info.source_actual_slot = player:get_visible_slot_index(moved_info.box_index, moved_info.slot_index)
      elseif moved_info ~= nil and type == 0 and moved_info.slot_active == true then
        ui:maybe_page_category_arrow_hover(x, y)
      end
    else
      if hotbar_sets:is_visible() and not (ui.hotbar and ui.hotbar.hide_hotbars) then
        local node = hotbar_sets:hit_test(x, y)
        if type == 0 then hotbar_sets:set_hover(node) end
        if type == 1 and node then
          hotbar_sets:begin_hold(node)
          return true
        elseif type == 0 and hotbar_sets:hold_node() and hotbar_sets:hold_node() ~= node then
          hotbar_sets:end_hold()
        elseif type == 2 and hotbar_sets:hold_node() then
          local hn = hotbar_sets:hold_node()
          local was_saved = hotbar_sets:hold_saved()
          hotbar_sets:end_hold()
          if not was_saved and hotbar_sets:has_set(hn) and hotbar_sets:load_set(hn) then
            print('XIVHOTBAR2: Loaded set ' .. hn .. ' (' .. (hotbar_sets:get_name(hn) or '') .. ').')
            windower.send_command('lua reload xivui')
          end
          return true
        end
      end
      return_value = mouse_hotbars(type, x, y, delta, blocked)
    end
  end

  return return_value
end)

local frame_counter = 0
htb_register('prerender', function()
  frame_counter = frame_counter + 1

  if ui.hotbar.ready == false then
    return
  end

  if hotbar_sets:hold_node() and not hotbar_sets:hold_saved() then
    local p = hotbar_sets:tick_hold()
    if (p or 0) >= 1 then
      local hn = hotbar_sets:hold_node()
      hotbar_sets:set_player(player)
      save_job_layout()
      local ok, stored = hotbar_sets:save_set(hn)
      hotbar_sets:mark_hold_saved()
      if ok then
        hotbar_sets:set_saved_title(hn)
        print('XIVHOTBAR2: Saved set ' .. hn .. ' as "' .. tostring(stored) .. '".')
      else print('XIVHOTBAR2: Failed to save set ' .. hn .. ' (' .. tostring(stored) .. ').') end
    end
  end

  if slot_drag.dragging then
    local hb = ui.hotbars and ui.hotbars[slot_drag.h]
    local ic = hb and hb.slot_icons and hb.slot_icons[slot_drag.i]
    if ic then pcall(ic.hide, ic) end
  end

  process_deferred_work()

  if frame_counter % 6 == 0 then
    recast_cache.observe_live(windower.ffxi.get_ability_recasts())
  end

  if ui.feedback.is_active then
    ui:show_feedback()
  end

  if ui.is_setup and ui.hotbar.hide_hotbars == false then
    moved_row_info = move_box:get_move_box_info()
    if (moved_row_info.swapped_slots.active == true) then
      moved_row_info.swapped_slots.active = false
      if moved_row_info.source_actual_slot ~= nil then
        moved_row_info.swapped_slots.source.actual_slot = moved_row_info.source_actual_slot
      end
      moved_row_info.source_actual_slot = nil
      local st = moved_row_info.swapped_slots
      local _, menv = player:get_hotbar_info_without_vitals()
      if slotdrag_merge(st.source.row, st.source.slot, st.source.actual_slot, st.dest.row, st.dest.slot, menv or 'battle') then
        reload_hotbar()
      else
        player:swap_actions(st)
        ui:swap_icons(st)
        ui:load_player_hotbar(player:get_hotbar_info())
      end
    elseif (moved_row_info.row_active == true) then
      if moved_row_info.box_index and moved_row_info.box_index == (theme_options.rows + 1) then
        ui:move_choice_bar(moved_row_info, ui.theme)
      elseif moved_row_info.box_index and moved_row_info.box_index == (theme_options.rows + 2) then
        ui:move_choice_indicator(moved_row_info, ui.theme)
      else
        ui:move_icons(moved_row_info, ui.theme)
      end
    elseif (moved_row_info.removed_slot.active == true) then
      if moved_row_info.source_actual_slot ~= nil then
        moved_row_info.removed_slot.source.actual_slot = moved_row_info.source_actual_slot
      end
      player:remove_action(moved_row_info.removed_slot)
      moved_row_info.removed_slot.active = false
      moved_row_info.source_actual_slot = nil
      ui:load_player_hotbar(player:get_hotbar_info())
    end

    local recast_interval = tonumber(theme_options.recast_check_interval_frames) or 10
    if recast_interval < 1 then recast_interval = 1 end
    if frame_counter % recast_interval == 0 then
      ui:check_recasts(player:get_hotbar_info())
    end

    local hover_interval = tonumber(theme_options.hover_check_interval_frames) or 3
    if hover_interval < 1 then hover_interval = 1 end
    if hover_interval == 1 or frame_counter % hover_interval == 0 then
      ui:check_hover()
    end

    if ui.update_hover_tooltip then ui:update_hover_tooltip() end
  end

  if slot_drag.dragging then
    local hb = ui.hotbars and ui.hotbars[slot_drag.h]
    local ic = hb and hb.slot_icons and hb.slot_icons[slot_drag.i]
    if ic then pcall(ic.hide, ic) end
  end
end)

htb_register('mp change', function(new, old)
  player.vitals.mp = new
  ui:update_mp(new)
end)

htb_register('tp change', function(new, old)
  player.vitals.tp = new
  ui:update_tp(new)
end)

htb_register('status change', function(new_status_id, old_status_id)
  if ui.hotbar.hide_hotbars == false and new_status_id == 4 then
    ui.hotbar.hide_hotbars = true
    ui:hide()
  elseif ui.hotbar.hide_hotbars and new_status_id ~= 4 and not zoning and not state.ext_hidden then
    ui.hotbar.hide_hotbars = false
    ui:show(player:get_hotbar_info())
  end

  if theme_options and theme_options.auto_battle_mode == true then
    if new_status_id == 1 then
      set_battle_environment(true)
    elseif old_status_id == 1 and new_status_id ~= 1 then
      set_battle_environment(false)
    end
  end

  player.combat_status = new_status_id

  if new_status_id == 1 then
    player.autora_melee_landed = false
    player.autora_last_hit = nil
    if player.autora_active then autora_queue(0.1) end
  elseif old_status_id == 1 and new_status_id ~= 1 then
    player.autora_pending_at = nil
    player.autora_last_fire = nil
    player.autora_melee_landed = false
    player.autora_last_hit = nil
  end
end)

htb_register('incoming chunk', function(id, original)
  if id ~= 0x028 then return end
  local ok, act = pcall(windower.packets.parse_action, original)
  if not ok or not act then return end
  if state.ready == true then
    if act.actor_id == player.id and act.category == 0x01 then
      player.autora_melee_landed = true
      player.autora_last_hit = 'melee'
    end
    if act.actor_id == player.id and act.category == 0x02 then
      player.autora_last_hit = 'ranged'
      local unlimited_shot_active = false
      if player.buffs then
        for _, bid in ipairs(player.buffs) do
          if tonumber(bid) == 115 then unlimited_shot_active = true; break end
        end
      end
      if not unlimited_shot_active then
        local ammo_consumed = 0
        if act.targets and #act.targets > 0 then
          local first_target = act.targets[1]
          if first_target and first_target.actions then
            for _, ar in ipairs(first_target.actions) do
              if (ar.add_effect_message or 0) ~= 322 then
                ammo_consumed = ammo_consumed + 1
              end
            end
          end
        end
        if ammo_consumed == 0 then ammo_consumed = 1 end
        player.scavenge_ammo_expended = player.scavenge_ammo_expended + ammo_consumed
        player.ranged_ammo_count = math.max(0, player.ranged_ammo_count - ammo_consumed)
      end
      if player.autora_active then
        local delay = tonumber(theme_options and theme_options.autora_delay) or 1.5
        player.autora_pending_at = os.clock() + delay
      end
    end

    if act.actor_id == player.id and act.category == 0x04 then
      if act.param == 338 and player.utsusemi_shadow_tier <= 1 then
        player.utsusemi_shadows = 1
        player.utsusemi_shadow_tier = 1
      elseif act.param == 339 and player.utsusemi_shadow_tier <= 2 then
        player.utsusemi_shadows = 3
        player.utsusemi_shadow_tier = 2
      elseif act.param == 340 then
        player.utsusemi_shadows = 5
        player.utsusemi_shadow_tier = 3
      end

      if act.param >= 798 and act.param <= 827 then
        player.has_luopan = true
        player.luopan_geo_pending = true
        request_hotbar_reload('luopan placed', 0.1)
      end

      if player:consume_enlightenment_override() then
        request_hotbar_reload('Enlightenment consumed', 0.1)
      end
    end

    if player.utsusemi_shadows > 0 and act.targets then
      for _, target in ipairs(act.targets) do
        if target.id == player.id and target.actions then
          for _, action_result in ipairs(target.actions) do
            if action_result.message == 31 then
              player.utsusemi_shadows = math.max(0, player.utsusemi_shadows - 1)
            end
          end
        end
      end
    end
  end

  if state.ready == true and act.actor_id == player.id and act.category == 0x06 then
    if (act.param == 211 or act.param == 212 or act.param == 234 or act.param == 235) then
      player:load_job_ability_actions(act.param)
      ui:load_player_hotbar(player:get_hotbar_info())
      return
    end

    local ability = resources.job_abilities and resources.job_abilities[act.param] or nil
    if ability and ability.en == 'Enlightenment' then
      player:set_enlightenment_override(true, ability.duration or 60)
      request_hotbar_reload('Enlightenment', 0.1)
    end

    if act.param == 345 then
      player.has_luopan = false
      player.luopan_id = nil
      player.luopan_geo_pending = false
      request_hotbar_reload('luopan dismissed', 0.1)
    end

    if act.param == 56 then
      player.scavenge_ammo_expended = 0
    end

    if act.param == 39 then
      if player.boost_expires == 0 or os.clock() >= player.boost_expires then
        player.boost_expires = os.clock() + 13
      end
    end

    if player.main_job == 'BST' then
      if act.param == 85 or act.param == 387 then
        player.has_jug_pet = true
      elseif act.param == 52 then
        player.has_jug_pet = false
      end
    end
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  local seq = original:unpack('H', 3)

  if (next_sequence and seq >= next_sequence) and loaded then
    next_sequence = nil
    first_load_done = true
    on_world_load()
  end

  if id == 0x00B then
    loaded = false
    ui.hotbar.hide_hotbars = true
    ui:hide()
  elseif id == 0x00A then
    loaded = false
    zoning = true
    ui.hotbar.hide_hotbars = true
    ui:hide()
  elseif id == 0x01D and not loaded then
    loaded = true
    zoning = false

    if first_load_done == false then
      next_sequence = (seq + 18) % 0x10000
    else
      on_world_load()
    end
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x050 then
    local packet = packets.parse('incoming', original)
    local slot = packet['Equipment Slot']

    if slot == 3 then
      local evt_inv_index = packet['Inventory Index']
      local evt_bag_index = packet['Inventory Bag']
      local has_angon = false
      local has_jug   = false
      local ammo_skill = 0
      local ammo_count = 0
      if evt_inv_index ~= 0 then
        local ammo_item = windower.ffxi.get_items(evt_bag_index, evt_inv_index)
        has_angon = ammo_item ~= nil and ammo_item.id == 18259
        if ammo_item and ammo_item.id and ammo_item.id ~= 0 then
          local ammo_res = resources and resources.items and resources.items[ammo_item.id]
          has_jug = ammo_res ~= nil
              and ammo_res.category == 'Weapon'
              and ammo_res.slots ~= nil and ammo_res.slots[3]
              and ammo_res.jobs ~= nil and ammo_res.jobs[9] and not ammo_res.jobs[1]
          ammo_skill = (ammo_res and ammo_res.skill) or 0
        end
        ammo_count = (ammo_item and ammo_item.count) or 0
      end
      player:update_angon(has_angon)
      player:update_jug(has_jug)
      player.ranged_ammo_count = ammo_count
      player.ammo_skill = ammo_skill
      player:update_ranged_ammo(evt_inv_index ~= 0)
      if player.current_range_weapon == 0 then
        request_hotbar_reload('ammo change', 0.1)
      end
      ui:update_tp_costs(player:get_hotbar_info())
      return
    end

    if slot == 1 then
      local evt_inv_index = packet['Inventory Index']
      local evt_bag_index = packet['Inventory Bag']
      local has_shield = false
      if evt_inv_index ~= 0 then
        local sub_items = windower.ffxi.get_items(evt_bag_index, evt_inv_index)
        if sub_items and sub_items.id then
          local sub_item = resources.items[sub_items.id]
          has_shield = sub_item ~= nil and (sub_item.shield_size or 0) > 0
        end
      end
      player:update_shield(has_shield)
      return
    end

    if slot == 0 or slot == 2 then
      local evt_inv_index = packet['Inventory Index']
      local evt_bag_index = packet['Inventory Bag']

      if evt_inv_index ~= 0 then
        if slot == 2 then
          local range_items = windower.ffxi.get_items(evt_bag_index, evt_inv_index)
          local has_animator = false
          if range_items and range_items.id then
            local range_item = resources.items[range_items.id]
            has_animator = range_item ~= nil and range_item.en ~= nil and tostring(range_item.en):lower():find('animator') ~= nil
          end
          player:update_animator(has_animator)
        end

        local weapon_changed = false
        local items = windower.ffxi.get_items()
        if items and items.equipment then
          if slot == 0 then
            weapon_changed = set_weapon_type(false, evt_bag_index, items.equipment.main)
          elseif slot == 2 then
            weapon_changed = set_weapon_type(true, evt_bag_index, items.equipment.range)
          end
        else
          schedule_weapon_refresh('equip packet', 5, 0.5)
        end

        if not zoning and weapon_changed then
          if ui.theme.dev_mode then log("Weapon Changed. Reloading Hotbar.") end
          request_hotbar_reload('weapon changed', 0.1)
        end

        return
      else
        if slot == 2 then
          player:update_animator(false)
        end

        local weapon_changed = false
        if slot == 0 then
          if player.current_weapon ~= 0 then
            player:update_weapon_type(0)
            weapon_changed = true
          end
        elseif slot == 2 then
          if player.current_range_weapon ~= 0 then
            player:update_range_weapon_type(0)
            weapon_changed = true
          end
        end

        if not zoning and weapon_changed then
          if ui.theme.dev_mode then log("Weapon Unequipped. Reloading Hotbar.") end
          request_hotbar_reload('weapon unequipped', 0.1)
        end

        return
      end
    end
  end
end)

function set_weapon_type(is_ranged, bag, index)
  local bag_items = windower.ffxi.get_items(bag, index)
  if bag_items == nil or bag_items.id == nil then
    return false
  end

  local item = resources.items[bag_items.id]
  local new_skill_type = item and item.skill or 0

  if theme_options.enable_weapon_switching == true then
    if is_ranged then
      if player.current_range_weapon ~= new_skill_type then
        player:update_range_weapon_type(new_skill_type)
        return true
      end
    else
      if player.current_weapon ~= new_skill_type then
        player:update_weapon_type(new_skill_type)
        return true
      end
    end
  end

  return false
end

htb_register('add item', 'remove item', function(id, bag, index, count)
  if state.ready == true then
    ui:update_inventory_count()
    player:update_inventory_items()
    ui:update_tp_costs(player:get_hotbar_info())
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    if id == 0x0AC and changing_job == true then
      changing_job = false
      local prev_main = player.main_job_id
      local prev_sub  = player.sub_job_id
      if prev_main ~= new_main or prev_sub ~= new_sub then
        if prev_main ~= new_main then
          player:update_pet('')
        end
        local main_job = resources.jobs[new_main] and resources.jobs[new_main].ens or 'NON'
        local sub_job = resources.jobs[new_sub] and resources.jobs[new_sub].ens or 'NON'
        player:update_job(new_main, main_job, new_sub or 0, sub_job)
        if ui.theme.dev_mode then log("Changing Job (Moogle)") end
        apply_job_layout(load_job_layout(main_job))
        choice_groups.invalidate_dynamic_cache()
        request_hotbar_reload('job changed', 0.5)
        if prev_sub ~= new_sub and addon_mode == 'gen' then
          coroutine.sleep(1.0)
          local wp = windower.ffxi.get_player()
          if wp and wp.sub_job_id == new_sub then
            player:update_level(wp.main_job_level, wp.sub_job_level)
            if hotbar_tools:auto_populate_sub_bar(player, theme_options) then
              request_hotbar_reload('sub bar auto-populated', 0.1)
            end
          end
        end
      end
    elseif id == 0x01B then
      local windower_player = windower.ffxi.get_player()
      old_main = windower_player.main_job_id
      old_sub = windower_player.sub_job_id
      local packet = packets.parse('incoming', original)
      new_main = packet['Main Job']
      new_sub = packet['Sub Job']

      changing_job = true
    end
  end
end)

htb_register('outgoing chunk', function(id, original, modified, injected, blocked)
  if id == 0x102 then
    if player.main_job_id == 16 or player.sub_job_id == 16 then
      if ui.theme.dev_mode then log("Set blue magic. Reloading Hotbar.") end
      choice_groups.invalidate_dynamic_cache()
      request_hotbar_reload('blue magic set changed', 1.5)
    end
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x044 then
    if player.main_job_id == 16 or player.sub_job_id == 16 then
      local packet = packets.parse('incoming', original)
      if packet['Job'] == 16 then
        local binary_dump = {}
        local set_blu_spells = {}

        for i = 9, 28 do
          local byte = string.byte(original, i)
          if byte ~= 0x0 then
            table.insert(set_blu_spells, string.byte(original, i) + 512)
          end
          if i % 4 == 0 then
            table.insert(binary_dump, "\n")
          end
        end
        player:update_blue_magic(set_blu_spells)
        choice_groups.invalidate_dynamic_cache()
        request_hotbar_reload('blu spell set changed', 0.5)
      end
    end
  end
end)

htb_register('incoming chunk', function(id, original)
  if id ~= 0x029 then return end
  local ok, p = pcall(packets.parse, 'incoming', original)
  if not ok or not p or p['Actor'] ~= player.id then return end
  local message_id = (p['Message'] or 0) % 0x8000
  if message_id == 45 then
    if ui.theme.dev_mode then log("Learned Weaponskill. Scheduling Hotbar reload.") end
    request_hotbar_reload('learned weaponskill', 0.75)
  elseif message_id == 23 then
    if ui.theme.dev_mode then log("Learned Spell. Scheduling Hotbar reload.") end
    choice_groups.invalidate_dynamic_cache()
    request_hotbar_reload('learned spell', 0.75)
  end
end)

htb_register('gain buff', function(id)
  if id == 143 or id == 269 then
    if ui.theme.dev_mode then log("Level Capped/Sync'd. Reloading Hotbar.") end
    reload_hotbar()
  elseif id == 55 then
    player:add_buff(id)
    reload_hotbar()
  elseif (id >= 523 and id <= 530) then
    player:add_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  elseif id == 377 then
    player:add_buff(id)
    request_hotbar_reload('Tabula Rasa gained', 0.1)
  elseif id == 359 or id == 402 or id == 358 or id == 401 then
    player:add_buff(id)
    reload_hotbar()
  elseif (id >= 381 and id <= 385) or id == 588 then
    player:update_finishing_moves(id)
    ui:update_tp_costs(player:get_hotbar_info())
  elseif id == 47 or id == 360 or id == 361 or id == 229 or id == 583 then
    player:add_buff(id)
    ui:update_mp_costs(player:get_hotbar_info())
  elseif id == 376 or id == 408 or id == 54 then
    player:add_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  end
end)

htb_register('lose buff', function(id)
  if id == 45 then
    player.boost_expires = 0
  elseif id == 66 then
    player.utsusemi_shadows = 0
    player.utsusemi_shadow_tier = 0
  elseif id == 269 then
    log("Leve Sync'd Removed. Reloading Hotbar.")
    reload_hotbar()
  elseif id == 55 then
    player:remove_buff(id)
    reload_hotbar()
  elseif (id >= 523 and id <= 530) then
    player:remove_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  elseif id == 377 then
    player:remove_buff(id)
    request_hotbar_reload('Tabula Rasa lost', 0.1)
  elseif id == 359 or id == 402 or id == 358 or id == 401 then
    player:remove_buff(id)
    reload_hotbar()
  elseif (id >= 381 and id <= 385) or id == 588 then
    player:reset_finishing_moves()
    ui:update_tp_costs(player:get_hotbar_info())
  elseif id == 47 or id == 360 or id == 361 or id == 229 or id == 583 then
    player:remove_buff(id)
    ui:update_mp_costs(player:get_hotbar_info())
  elseif id == 376 or id == 408 or id == 54 then
    player:remove_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x02D then
    mob_killed = true
    old_level = player.main_job_level
  elseif mob_killed and id == 0x061 then
    local packet = packets.parse('incoming', original)
    new_level = packet['Main Job Level']

    S { 'ws' }:contains('ws')
    if new_level ~= old_level then
      if ui.theme.dev_mode then log("Leveled up! Scheduling Hotbar reload.") end
      choice_groups.invalidate_dynamic_cache()
      request_hotbar_reload('level changed', 0.5)
    end

    mob_killed = false
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  local packet = packets.parse('incoming', original)
  if id == 0x068 then
    if packet['Owner ID'] == player.id then
      if packet['Pet Index'] == 0 then
        if ui.theme.dev_mode then log("Pet Died or was Released. Reloading Hotbar.") end
        player.has_jug_pet = false
        if player.has_luopan then
          player.has_luopan = false
          player.luopan_id = nil
          player.luopan_geo_pending = false
        end
        request_hotbar_reload('pet removed', 2.5, '')
      end
    end
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    local packet = packets.parse('incoming', original)
    if id == 0x068 then
      local wp = windower.ffxi.get_player()
      if wp and packet['Owner ID'] == wp.id then
        if packet['Pet Index'] ~= 0 then
          local pet_name_for_reload = packet['Pet Name']
          if (pet_name_for_reload == nil or pet_name_for_reload == '') and player.main_job == 'DRG' then
            local mob = windower.ffxi.get_mob_by_target('pet')
            pet_name_for_reload = (mob ~= nil and mob.name ~= nil and mob.name ~= '') and mob.name or ''
          end
          if player.pet_name ~= pet_name_for_reload and pet_name_for_reload ~= '' then
            if ui.theme.dev_mode then log("Pet Summoned/Changed " .. tostring(pet_name_for_reload) .. ". Scheduling Hotbar reload.") end
            request_hotbar_reload('pet changed', 0.3, pet_name_for_reload)
          end
          local pet_name = tostring(packet['Pet Name'] or '')
          if pet_name:sub(1, 4) == 'Geo-' then
            player.has_luopan = true
            player.luopan_geo_pending = false
          end
        end
      end
    end
  end
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    local packet = packets.parse('incoming', original)
    if id == 0x068 then
      local wp = windower.ffxi.get_player()
      if wp and packet['Owner ID'] == wp.id then
        ui:update_pet_tp(packet['Pet TP'])
        ui:update_pet_mp(packet['Current MP%'])
      end
    end
  end
end)

htb_register('incoming text', function(text)
  local pname = windower.ffxi.get_player().name
  if string.find(text, pname) and string.find(text, ' learns a new spell') then
    if ui.theme.dev_mode then log('Learned a new spell. Scheduling updategen.') end
    request_hotbar_reload('learned spell text', 0.75)
    request_updategen('learned spell', 0.75, false)
  elseif string.find(text, pname) and string.find(text, 'learns.*weapon.skill') then
    if ui.theme.dev_mode then log('Learned a weapon skill. Scheduling updategen.') end
    request_updategen('learned weapon skill', 0.75, false)
  end
end)

htb_register('level up', function()
  if addon_mode ~= 'gen' or not state.ready then return end
  if ui.theme.dev_mode then log('Level up. Scheduling updategen.') end
  request_updategen('level up', 1.5, true)
end)

htb_register('incoming chunk', function(id, original, modified, injected, blocked)
  if ui.theme.dev_mode then
    if id == 0x0AC and gm_command == true then
      if ui.theme.dev_mode then log("GM Command. Reloading Hotbar.", count) end
      gm_command = false
      request_hotbar_reload('GM command', 0.5)
    end
  end
end)

htb_register('incoming text', function(text)
  if ui.theme.dev_mode then
    if string.find(text, "!changejob") or string.find(text, "!changesjob") then
      gm_command = true
    end
  end

  if text then
    local element_word, pct_str = text:match("'s (%a+) Maneuver overload chance is (%d+)%%")
    if element_word and pct_str then
      local key = element_word:lower() .. ' maneuver'
      player.pup_overload_chances[key] = { pct = tonumber(pct_str) or 0, time = os.clock() }
      if ui and ui.theme and ui.theme.dev_mode then
        log('PUP overload: ' .. key .. ' = ' .. tostring(pct_str) .. '%')
      end
    end

    local overload_name = player.name ~= '' and player.name or nil
    if overload_name then
      if text:find(overload_name .. ' is overloaded!', 1, true) then
        player.has_overload = true
      elseif text:find(overload_name .. ' is no longer overloaded.', 1, true) then
        player.has_overload = false
      end
    end
  end
end)

htb_register('mob spawned', function(mob)
  if state.ready == true and player.luopan_geo_pending and mob and mob.owner_id == player.id then
    player.luopan_id = mob.id
    player.luopan_geo_pending = false
  end
end)

htb_register('mob despawned', function(id)
  if state.ready == true and player.luopan_id and id == player.luopan_id then
    player.luopan_id = nil
    if not player.luopan_geo_pending then
      player.has_luopan = false
      request_hotbar_reload('luopan despawned', 0.1)
    end
  end
end)

function printTable(tbl, indent)
  indent = indent or 0
  local indentString = string.rep("  ", indent)

  for key, value in pairs(tbl) do
    if type(value) == "table" then
      windower.add_to_chat(8, indentString .. tostring(key) .. ":")
      printTable(value, indent + 1)
    else
      windower.add_to_chat(8, indentString .. tostring(key) .. ": " .. tostring(value))
    end
  end
end

function shorten_ability_name(name)
  local function shortenWord(word)
    local result = ""
    local vowelPreserved = false

    for char in word:gmatch(".") do
      if #result < 3 then
        if char:match("[aeiouAEIOU]") then
          if not vowelPreserved then
            result = result .. char
            vowelPreserved = true
          end
        else
          result = result .. char
        end
      else
        break
      end
    end

    return result
  end

  local shortenedName = name:gsub("(%a)([%a]*)", function(firstLetter, restOfWord)
    return firstLetter:upper() .. shortenWord(restOfWord)
  end):gsub("%s+", "")

  return shortenedName:sub(1, 6)
end

function xivhotbar3_component.init()
  recast_cache.load()
  local windower_player = windower.ffxi.get_player()
  if windower_player ~= nil and not state.ready then
    defaults = require('components/xivhotbar3/defaults')
    defaults.Keybinds = keyboard.default_keybinds
    settings = config.load('data/xivhotbar3/settings.xml', defaults)
    keyboard:cast_all_to_strings(settings)
    config.save(settings)
    theme = require('components/xivhotbar3/theme')
    theme_options = theme.apply(settings)
    player.id = windower_player.id
    initialize()
    register_events()
    if htb_mouse_handler_id then
      windower.unregister_event(htb_mouse_handler_id)
      htb_mouse_handler_id = nil
    end
    htb_mouse_handler_id = windower.register_event('mouse', function(type, x, y, delta, blocked)
      if not state.ready then return end
      if hud_layout_open() then return false end
      if type ~= 0 and type ~= 1 and type ~= 2 and type ~= 3 and type ~= 4 then return end
      if (hotbar_blocker and hotbar_blocker:hover(x, y))
      or (choice_blocker  and choice_blocker:hover(x, y)) then
        return true
      end
    end)
    require('components/xivhotbar3/lib/action_manager').post_load_overlay = function(am)
      if not (player and theme_options) then return end
      local okp, prefs = pcall(hotbar_tools.load_preferences, hotbar_tools, player)
      if not okp or type(prefs) ~= 'table' or prefs.overlay ~= true then return end
      local okb, placements, bars = pcall(hotbar_tools.build_overlay_placements, hotbar_tools, player, theme_options, am.hotbar)
      if okb and placements then am:apply_overlay(placements, bars) end
    end
    schedule_weapon_refresh('post-init delayed', 10, 1)
  end
end

function xivhotbar3_component.dispose()
  if not state.ready then return end
  player.autora_active = false
  player.autora_pending_at = nil
  player.autora_last_fire = nil
  settings = nil
  theme = nil
  theme_options = nil
  state = { ready = false, demo = false, inventory_ready = false, inventory_loading = false }
  loaded = false
  first_load_done = false
  skillchains:destroy()
  ui:destroy()
  hotbar_sets:destroy()
  ui_bounds.clear('xivhotbar3')
  ui_bounds.clear('xivhotbar3_sets')
  if hotbar_blocker then hotbar_blocker:hide() end
  hotbar_blocker = nil
  if choice_blocker  then choice_blocker:hide()  end
  choice_blocker = nil
  if htb_mouse_handler_id then
    windower.unregister_event(htb_mouse_handler_id)
    htb_mouse_handler_id = nil
  end
  unregister_events()
  rmbPressedInHotbar = false
  lmbPressedInHotbar = false
end

function xivhotbar3_component.show()
  state.ext_hidden = false
  if state.ready and ui then
    ui.hotbar.hide_hotbars = false
    ui:show(player:get_hotbar_info())
    if is_choice_modifier_active and is_choice_modifier_active() and ui.set_choice_modifier_indicator then
      ui:set_choice_modifier_indicator(true)
    end
    hotbar_sets:show()
  end
end

function xivhotbar3_component.hide()
  state.ext_hidden = true
  if ui then
    ui.hotbar.hide_hotbars = true
    ui:hide()
  end
  hotbar_sets:hide()
  ui_bounds.clear('xivhotbar3')
  ui_bounds.clear('xivhotbar3_sets')
  if hotbar_blocker then hotbar_blocker:hide() end
  if choice_blocker  then choice_blocker:hide()  end
  rmbPressedInHotbar = false
  lmbPressedInHotbar = false
end

local function push_sets_grid_bounds()
    if state.ready and hotbar_sets:is_visible() and not (ui.hotbar and ui.hotbar.hide_hotbars) then
        local gx, gy, gw, gh = hotbar_sets:grid_bounds()
        ui_bounds.register('xivhotbar3_sets', gx, gy, gw, gh)
    else
        ui_bounds.clear('xivhotbar3_sets')
    end
end

local function push_hotbar_bounds()
    push_sets_grid_bounds()
    if not state.ready or not ui.hotbars or not ui.theme
       or (ui.hotbar and ui.hotbar.hide_hotbars) then
        ui_bounds.clear('xivhotbar3')
        ui_bounds.clear('xivhotbar3_choice')
        if hotbar_blocker then hotbar_blocker:hide() end
        if choice_blocker  then choice_blocker:hide()  end
        return
    end
    local t = ui.theme
    local scale   = tonumber(t.slot_icon_scale or 1) or 1
    local arrow_w = math.max(12, math.floor(16 * scale))
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for h = 1, t.hotbar_number do
        local hb = ui.hotbars[h]
        if hb then
            for i = 1, t.columns do
                local frame = hb.slot_frames and hb.slot_frames[i]
                if frame and frame:visible() then
                    local sx, sy = ui:get_slot_xy(h, i)
                    local biw = ui.bar_image_width and ui:bar_image_width(h) or ui.image_width
                    local bih = ui.bar_image_height and ui:bar_image_height(h) or ui.image_height
                    min_x = math.min(min_x, sx)
                    min_y = math.min(min_y, sy)
                    max_x = math.max(max_x, sx + biw)
                    max_y = math.max(max_y, sy + bih)
                end
            end
        end
    end
    if min_x < math.huge then
        local right_ext = arrow_w
        local inv_x = ui.get_inventory_count_position and select(1, ui:get_inventory_count_position())
        if inv_x and inv_x > max_x then right_ext = math.max(right_ext, inv_x - max_x + 60) end
        local bx = min_x - arrow_w
        local by = min_y
        local bw = (max_x - min_x) + arrow_w + right_ext
        local bh = max_y - min_y
        ui_bounds.register('xivhotbar3', bx, by, bw, bh)
        htb_bounds_cache = { x=bx, y=by, w=bw, h=bh }
        if hotbar_blocker then
            hotbar_blocker:pos(bx, by)
            hotbar_blocker:size(bw, bh)
            hotbar_blocker:show()
        end
    else
        ui_bounds.clear('xivhotbar3')
        htb_bounds_cache = nil
        if hotbar_blocker then hotbar_blocker:hide() end
    end

    if state.demo then
        local cr = (theme_options.rows or 6) + 1
        local ir = (theme_options.rows or 6) + 2
        local function reg(id, rownum)
            local bx, by, bw, bh = move_box.get_row_bounds and move_box:get_row_bounds(rownum)
            if bx and bw and bw > 0 and bh and bh > 0 then
                ui_bounds.register(id, bx, by, bw, bh)
            else
                ui_bounds.clear(id)
            end
        end
        reg('xivhotbar3_choice', cr)
        reg('xivhotbar3_choiceind', ir)
        choice_bounds_cache = nil
        if choice_blocker then choice_blocker:hide() end
    elseif ui.choice_bar and ui.choice_bar.active and ui.hotbars and ui.hotbars[ui.choice_bar.row] then
        local row = ui.choice_bar.row
        local cb_min_x, cb_min_y = math.huge, math.huge
        local cb_max_x, cb_max_y = -math.huge, -math.huge
        local cbiw = ui.bar_image_width and ui:bar_image_width(row) or ui.image_width
        local cbih = ui.bar_image_height and ui:bar_image_height(row) or ui.image_height
        for i = 1, t.columns do
            local sx, sy = ui:get_slot_xy(row, i)
            cb_min_x = math.min(cb_min_x, sx)
            cb_min_y = math.min(cb_min_y, sy)
            cb_max_x = math.max(cb_max_x, sx + cbiw)
            cb_max_y = math.max(cb_max_y, sy + cbih)
        end
        if cb_min_x < math.huge then

            local indicator_above = 60
            local cbx = cb_min_x - arrow_w
            local cby = cb_min_y - indicator_above
            local cbw = (cb_max_x - cb_min_x) + arrow_w * 2
            local cbh = (cb_max_y - cb_min_y) + indicator_above
            ui_bounds.register('xivhotbar3_choice', cbx, cby, cbw, cbh)
            choice_bounds_cache = { x=cbx, y=cby, w=cbw, h=cbh }
            if choice_blocker then
                choice_blocker:pos(cbx, cby)
                choice_blocker:size(cbw, cbh)
                choice_blocker:show()
            end
        else
            ui_bounds.clear('xivhotbar3_choice')
            choice_bounds_cache = nil
            if choice_blocker then choice_blocker:hide() end
        end
        ui_bounds.clear('xivhotbar3_choiceind')
    else
        ui_bounds.clear('xivhotbar3_choice')
        ui_bounds.clear('xivhotbar3_choiceind')
        choice_bounds_cache = nil
        if choice_blocker then choice_blocker:hide() end
    end
end

function xivhotbar3_component.push_bounds()
    push_hotbar_bounds()
end

function xivhotbar3_component.set_drag_block(v)
    external_drag_active = v and true or false
end

function xivhotbar3_component.slot_box_at(x, y)
    if not state.ready or not ui or not ui.hotbars or not ui.theme then return nil end
    if ui.hotbar and ui.hotbar.hide_hotbars then return nil end
    local t = ui.theme
    for h = 1, t.hotbar_number do
        local hb = ui.hotbars[h]
        if hb then
            for i = 1, t.columns do
                local frame = hb.slot_frames and hb.slot_frames[i]
                if frame and frame:visible() then
                    local sx, sy = ui:get_slot_xy(h, i)
                    if x >= sx and x <= sx + ui.image_width and y >= sy and y <= sy + ui.image_height then
                        return h, i, sx, sy, ui.image_width, ui.image_height
                    end
                end
            end
        end
    end
    return nil
end

function xivhotbar3_component.assign_action(x, y, entry)
    if not entry or not entry.type or not entry.action or entry.action == '' then return false end
    local row, col = xivhotbar3_component.slot_box_at(x, y)
    if not row then return false end

    local _, environment = player:get_hotbar_info_without_vitals()
    environment = environment or 'battle'
    if hotbar_tools:overlay_owns_bar(player, environment, row) then
        local say = _G.xivui_echo or print
        say('XIVHOTBAR2: that bar is auto-generated — add or reorder actions in the AUTOGEN panel.')
        return false
    end
    local vis_slot = player:get_visible_slot_index(row, col, environment) or col
    local am = require('components/xivhotbar3/lib/action_manager')
    local slot   = (am.visible_to_file_slot and am:visible_to_file_slot(row, vis_slot, environment)) or vis_slot
    local prio   = (environment == 'field') and 'g' or 'm'
    local target = entry.target or 'me'
    local alias  = entry.alias or entry.action

    local existing = player.get_visible_action and player:get_visible_action(environment, row, col)
    if existing and theme_options and theme_options.choice_drag_merge
            and not existing.is_dynamic
            and SLOTDRAG_MERGE_TYPES[tostring(entry.type or ''):lower()] then
        if merge_entry_into_slot(existing, row, col, environment,
                { type = tostring(entry.type):lower(), action = entry.action,
                  target = target, alias = alias, icon = entry.icon }) then
            reload_hotbar()
            return true, row, slot
        end
    end
    if existing then
        hotbar_tools:reset_slot(player, environment, row, slot)
    end
    player:insert_action({ prio, tostring(row), tostring(slot), entry.type, entry.action, target, alias, entry.icon })
    local am = require('components/xivhotbar3/lib/action_manager')
    local hidden_reason = am.req_check_reason
        and am:req_check_reason({ environment .. ' ' .. row .. ' ' .. slot, entry.type, entry.action })
    if hidden_reason then
        local say = _G.xivui_echo or print
        say(string.format('XIVHOTBAR2: "%s" saved to %s slot %d-%d, but it will stay HIDDEN for now: %s.',
            tostring(entry.action), environment, row, slot, hidden_reason))
    else
        print(string.format('XIVHOTBAR2: %s "%s" pinned to %s slot %d-%d.',
            tostring(entry.type), tostring(entry.action), environment, row, slot))
    end
    reload_hotbar()
    return true, row, slot
end

function xivhotbar3_component.hud_env() return get_active_env() end
function xivhotbar3_component.hud_bar_count() return theme_options.hotbar_number or 6 end

function xivhotbar3_component.hud_bars()
  local env = get_active_env()
  local hb  = (theme_options.hidden_bars and theme_options.hidden_bars[env]) or {}
  local out, n = {}, theme_options.hotbar_number or 6
  for h = 1, n do
    if ui.get_bar_rect then
      local x, y, w, hh = ui:get_bar_rect(h)
      if x then out[#out + 1] = { index = h, x = x, y = y, w = w, h = hh, hidden = hb[h] == true,
        scale = xivhotbar3_component.hud_get_bar_scale(h) } end
    end
  end
  return out
end

function xivhotbar3_component.hud_move_bar_live(h, x, y)
  local key = tostring(h)
  local existing = theme_options.offsets[key]
  local vertical = existing and existing.Vertical == true
  local ox = math.floor(x - (ui.pos_x or 0))
  local oy = math.floor(y)
  theme_options.offsets[key] = { OffsetX = ox, OffsetY = oy, Vertical = vertical }
  if ui.hotbars and ui.hotbars[1] then
    if ui.reposition_bar then ui:reposition_bar(h)
    elseif ui.reposition_all_bars then ui:reposition_all_bars() end
  end
  return ox, oy, vertical
end

function xivhotbar3_component.hud_move_bar(h, x, y)
  local key = tostring(h)
  local ox, oy, vertical = xivhotbar3_component.hud_move_bar_live(h, x, y)
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then ui:reposition_all_bars() end
  local env = get_active_env()
  if theme_options.job_override then
    capture_environment_layout(env); save_job_layout()
  else
    local g = load_global_layout()
    g.offsets[env] = g.offsets[env] or {}
    g.offsets[env][key] = { OffsetX = ox, OffsetY = oy, Vertical = vertical }
    save_global_layout()
  end
end

function xivhotbar3_component.hud_bar_hidden(env, h)
  return theme_options and theme_options.hidden_bars and theme_options.hidden_bars[env] and theme_options.hidden_bars[env][h] == true
end

function xivhotbar3_component.hud_set_hidden(env, h, val)
  ensure_hidden_bars()
  theme_options.hidden_bars[env][h] = val and true or nil
  save_job_layout()
  if env == get_active_env() and player and player.get_hotbar_info and ui.load_player_hotbar then
    ui:load_player_hotbar(player:get_hotbar_info())
  end
end

function xivhotbar3_component.hud_get_scale() return theme_options.slot_icon_scale or 1 end
function xivhotbar3_component.hud_set_scale_live(f)
  f = math.max(0.5, math.min(2.5, tonumber(f) or 1))
  theme_options.slot_icon_scale = f
  if ui.rescale and ui.hotbars and ui.hotbars[1] then ui:rescale(f) end
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then ui:reposition_all_bars() end
  if move_box and move_box.rescale then pcall(function() move_box:rescale(theme_options) end) end
end
function xivhotbar3_component.hud_set_scale(f)
  f = math.max(0.5, math.min(2.5, tonumber(f) or 1))
  theme_options.slot_icon_scale = f
  if ui.rescale and ui.hotbars and ui.hotbars[1] then ui:rescale(f) end
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then ui:reposition_all_bars() end
  if move_box and move_box.rescale then pcall(function() move_box:rescale(theme_options) end) end
  if settings and settings.Hotbar and settings.Hotbar.Style then
    settings.Hotbar.Style.SlotIconScale = f
    config.save(settings)
  end
end

function xivhotbar3_component.hud_action_tip_rect()
  local x = (theme_options and theme_options.description_box_x) or 675
  local y = (theme_options and theme_options.description_box_y) or 688
  local s = (theme_options and theme_options.description_scale) or 1
  return { x = math.floor(x), y = math.floor(y), w = math.floor(360 * s), h = math.floor(200 * s) }
end
function xivhotbar3_component.hud_move_action_tip(x, y)
  x = math.floor(tonumber(x) or 0); y = math.floor(tonumber(y) or 0)
  if theme_options then theme_options.description_box_x = x; theme_options.description_box_y = y end
  if ui.action_description then ui.action_description:pos(x, y) end
  if settings and settings.Texts and settings.Texts.ActionDescription then
    settings.Texts.ActionDescription.Pos = settings.Texts.ActionDescription.Pos or {}
    settings.Texts.ActionDescription.Pos.OffsetX = x
    settings.Texts.ActionDescription.Pos.OffsetY = y
    config.save(settings)
  end
end
function xivhotbar3_component.hud_get_action_tip_scale() return (theme_options and theme_options.description_scale) or 1 end
function xivhotbar3_component.hud_set_action_tip_scale(s)
  s = math.max(0.5, math.min(2.5, tonumber(s) or 1))
  if theme_options then theme_options.description_scale = s end
  if settings and settings.Texts and settings.Texts.ActionDescription then
    settings.Texts.ActionDescription.Scale = s
    config.save(settings)
  end
end

function xivhotbar3_component.hud_get_bar_scale(h)
  local off = theme_options and theme_options.offsets and theme_options.offsets[tostring(h)]
  local s = off and tonumber(off.Scale) or 1
  if not s or s <= 0 then s = 1 end
  return s
end
function xivhotbar3_component.hud_set_bar_scale(h, scale)
  scale = math.max(0.5, math.min(2.5, tonumber(scale) or 1))
  local key = tostring(h)
  theme_options.offsets = theme_options.offsets or {}
  local cur = theme_options.offsets[key] or { OffsetX = 0, OffsetY = 0, Vertical = false }
  cur.Scale = scale
  theme_options.offsets[key] = cur
  if ui.rescale and ui.hotbars and ui.hotbars[1] then ui:rescale(theme_options.slot_icon_scale or 1) end
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then ui:reposition_all_bars() end
  local env = get_active_env()
  if theme_options.job_override then
    capture_environment_layout(env); save_job_layout()
  else
    local g = load_global_layout()
    g.offsets[env] = g.offsets[env] or {}
    g.offsets[env][key] = g.offsets[env][key] or {}
    g.offsets[env][key].OffsetX  = cur.OffsetX
    g.offsets[env][key].OffsetY  = cur.OffsetY
    g.offsets[env][key].Vertical = cur.Vertical
    g.offsets[env][key].Scale    = scale
    save_global_layout()
  end
end

function xivhotbar3_component.hud_preview(on)
  if ui.theme then ui.theme.hud_show_all_bars = false end
  if not on and player and player.get_hotbar_info and ui.load_player_hotbar then
    ui:load_player_hotbar(player:get_hotbar_info())
  end
  hotbar_sets:set_force_shown(on == true)
  if ui.choice_hud_preview then pcall(function() ui:choice_hud_preview(on == true) end) end
end

local function save_choice_bar()
  if not (ui.theme and ui.theme.choice_bar) then return end
  if theme_options and theme_options.choice_bar and theme_options.choice_bar ~= ui.theme.choice_bar then
    local c = ui.theme.choice_bar
    for _, k in ipairs({ 'OffsetX', 'OffsetY', 'FieldOffsetX', 'FieldOffsetY', 'Scale', 'IndicatorScale',
        'IndicatorBattleX', 'IndicatorBattleY', 'IndicatorFieldX', 'IndicatorFieldY' }) do
      theme_options.choice_bar[k] = c[k]
    end
  end
  pcall(save_job_layout)
end

function xivhotbar3_component.hud_choice_rect()
  if not ui.choice_bar_rect then return nil end
  local x, y, w, h = ui:choice_bar_rect()
  if not x then return nil end
  return { x = x, y = y, w = w, h = h, scale = (ui.get_choice_scale and ui:get_choice_scale()) or 1, visible = true }
end
function xivhotbar3_component.hud_move_choice_live(x, y) if ui.set_choice_base then ui:set_choice_base(x, y) end end
function xivhotbar3_component.hud_move_choice(x, y) if ui.set_choice_base then ui:set_choice_base(x, y); save_choice_bar() end end
function xivhotbar3_component.hud_get_choice_scale() return (ui.get_choice_scale and ui:get_choice_scale()) or 1 end
function xivhotbar3_component.hud_set_choice_scale(s) if ui.set_choice_scale then ui:set_choice_scale(s); save_choice_bar() end end

function xivhotbar3_component.hud_choice_ind_rect()
  if not ui.choice_indicator_rect then return nil end
  local x, y, w, h = ui:choice_indicator_rect()
  if not x then return nil end
  return { x = x, y = y, w = w, h = h, scale = (ui.choice_indicator_scale and ui:choice_indicator_scale()) or 1, visible = true }
end
function xivhotbar3_component.hud_move_choice_ind_live(x, y) if ui.set_choice_indicator_pos then ui:set_choice_indicator_pos(x, y) end end
function xivhotbar3_component.hud_move_choice_ind(x, y) if ui.set_choice_indicator_pos then ui:set_choice_indicator_pos(x, y); save_choice_bar() end end
function xivhotbar3_component.hud_get_choice_ind_scale() return (ui.choice_indicator_scale and ui:choice_indicator_scale()) or 1 end
function xivhotbar3_component.hud_set_choice_ind_scale(s) if ui.set_choice_indicator_scale then ui:set_choice_indicator_scale(s); save_choice_bar() end end

function xivhotbar3_component.hud_env_text()
  if not ui.get_environment_text_rect then return nil end
  local x, y, w, h = ui:get_environment_text_rect()
  if not x then return nil end
  local s = (theme_options and theme_options.env_text_scale) or 1
  return { x = math.floor(x), y = math.floor(y), w = math.max(8, math.floor(w)), h = math.max(8, math.floor(h)), scale = s }
end

function xivhotbar3_component.hud_get_env_text_scale() return (theme_options and theme_options.env_text_scale) or 1 end

function xivhotbar3_component.hud_set_env_text_scale_live(s)
  s = tonumber(s) or 1; if s <= 0 then s = 1 end
  if theme_options then theme_options.env_text_scale = s end
  if ui.theme then ui.theme.env_text_scale = s end
  if ui.rescale and ui.theme then ui:rescale(ui.theme.slot_icon_scale or 1) end
end

function xivhotbar3_component.hud_set_env_text_scale(s)
  xivhotbar3_component.hud_set_env_text_scale_live(s)
  if settings and settings.Texts and settings.Texts.Environment then
    settings.Texts.Environment.Scale = (theme_options and theme_options.env_text_scale) or 1
    config.save(settings)
  end
end

function xivhotbar3_component.hud_move_env_text_live(x, y)
  if ui.set_environment_text_position then ui:set_environment_text_position(x, y) end
end

function xivhotbar3_component.hud_move_env_text(x, y)
  if ui.set_environment_text_position then ui:set_environment_text_position(x, y) end
  local _, _, dx, dy = ui:get_environment_text_position()
  if settings and settings.Texts and settings.Texts.Environment and settings.Texts.Environment.Pos then
    settings.Texts.Environment.Pos.HookOntoBar = 0
    settings.Texts.Environment.Pos.PosX = math.floor(x)
    settings.Texts.Environment.Pos.PosY = math.floor(y)
    if dx then settings.Texts.Environment.Pos.OffsetX = math.floor(dx) end
    if dy then settings.Texts.Environment.Pos.OffsetY = math.floor(dy) end
  end
  theme_options.hook_onto_bar = 0
  theme_options.font_pos_x_env = math.floor(x); theme_options.font_pos_y_env = math.floor(y)
  if ui.theme then ui.theme.hook_onto_bar = 0; ui.theme.font_pos_x_env = theme_options.font_pos_x_env; ui.theme.font_pos_y_env = theme_options.font_pos_y_env end
  config.save(settings)
end

function xivhotbar3_component.hud_inv_text()
  if not ui.get_inventory_count_rect then return nil end
  local x, y, w, h = ui:get_inventory_count_rect()
  if not x then return nil end
  local s = (theme_options and theme_options.inv_text_scale) or 1
  return { x = math.floor(x), y = math.floor(y), w = math.max(8, math.floor(w)), h = math.max(8, math.floor(h)), scale = s }
end

function xivhotbar3_component.hud_get_inv_text_scale() return (theme_options and theme_options.inv_text_scale) or 1 end

function xivhotbar3_component.hud_set_inv_text_scale_live(s)
  s = tonumber(s) or 1; if s <= 0 then s = 1 end
  if theme_options then theme_options.inv_text_scale = s end
  if ui.theme then ui.theme.inv_text_scale = s end
  if ui.rescale and ui.theme then ui:rescale(ui.theme.slot_icon_scale or 1) end
end

function xivhotbar3_component.hud_set_inv_text_scale(s)
  xivhotbar3_component.hud_set_inv_text_scale_live(s)
  if settings and settings.Texts and settings.Texts.Inventory then
    settings.Texts.Inventory.Scale = (theme_options and theme_options.inv_text_scale) or 1
    config.save(settings)
  end
end

function xivhotbar3_component.hud_move_inv_text_live(x, y)
  if ui.set_inventory_count_position then ui:set_inventory_count_position(x, y) end
end

function xivhotbar3_component.hud_move_inv_text(x, y)
  if ui.set_inventory_count_position then ui:set_inventory_count_position(x, y) end
  if settings and settings.Texts and settings.Texts.Inventory and settings.Texts.Inventory.Pos then
    settings.Texts.Inventory.Pos.Unlock = true
    settings.Texts.Inventory.Pos.PosX = math.floor(x); settings.Texts.Inventory.Pos.PosY = math.floor(y)
  end
  theme_options.unlock_pos_inv = true
  theme_options.font_pos_x_inv = math.floor(x); theme_options.font_pos_y_inv = math.floor(y)
  if ui.theme then ui.theme.unlock_pos_inv = true; ui.theme.font_pos_x_inv = theme_options.font_pos_x_inv; ui.theme.font_pos_y_inv = theme_options.font_pos_y_inv end
  config.save(settings)
end

function xivhotbar3_component.hud_auto_battle() return theme_options.auto_battle_mode == true end
function xivhotbar3_component.hud_set_auto_battle(val)
  theme_options.auto_battle_mode = val and true or false
  if settings and settings.General then settings.General.AutoBattleMode = theme_options.auto_battle_mode; config.save(settings) end
end

local function hud_apply_slot_text()
  if ui.theme then
    ui.theme.hide_action_cost = theme_options.hide_action_cost
    ui.theme.hide_action_names = theme_options.hide_action_names
  end
  if player and player.get_hotbar_info and ui.show then ui:show(player:get_hotbar_info()) end
end
function xivhotbar3_component.hud_get_show_costs() return theme_options.hide_action_cost ~= true end
function xivhotbar3_component.hud_set_show_costs(val)
  theme_options.hide_action_cost = not val
  if settings and settings.Hotbar then settings.Hotbar.HideActionCost = not val; config.save(settings) end
  hud_apply_slot_text()
end
function xivhotbar3_component.hud_get_show_names() return theme_options.hide_action_names ~= true end
function xivhotbar3_component.hud_set_show_names(val)
  theme_options.hide_action_names = not val
  if settings and settings.Hotbar then settings.Hotbar.HideActionName = not val; config.save(settings) end
  hud_apply_slot_text()
end

function xivhotbar3_component.hud_get_empty_frames()
  return theme_options.hide_empty_slots ~= true or theme_options.show_empty_slot_frames == true
end
function xivhotbar3_component.hud_set_empty_frames(val)
  val = val and true or false
  theme_options.hide_empty_slots = not val
  theme_options.show_empty_slot_frames = val
  if ui.theme then ui.theme.hide_empty_slots = not val; ui.theme.show_empty_slot_frames = val end
  if settings and settings.Hotbar then
    settings.Hotbar.HideEmptySlots = not val
    settings.Hotbar.Style = settings.Hotbar.Style or {}
    settings.Hotbar.Style.ShowEmptySlotFrames = val
    config.save(settings)
  end
  if xivhotbar3_component.apply_style_relayout then xivhotbar3_component.apply_style_relayout() end
end

local function hb_behavior_settings()
  if not (settings and settings.Hotbar) then return nil end
  settings.Hotbar.Behavior = settings.Hotbar.Behavior or {}
  return settings.Hotbar.Behavior
end
function xivhotbar3_component.hud_get_ranged_mode()
  local m = theme_options and theme_options.ranged_mode
  if not m then local b = settings and settings.Hotbar and settings.Hotbar.Behavior; m = b and b.RangedMode end
  if m == 'autora' or not m then m = 'auto' end
  return m
end
function xivhotbar3_component.hud_set_ranged_mode(mode)
  mode = tostring(mode or 'auto'):lower()
  if mode ~= 'auto' and mode ~= 'press' then mode = 'auto' end
  if theme_options then theme_options.ranged_mode = mode end
  local b = hb_behavior_settings(); if b then b.RangedMode = mode; config.save(settings) end
  if reload_hotbar then reload_hotbar() end
end

function xivhotbar3_component.hud_get_autora_melee_mode()
  local m = theme_options and theme_options.autora_melee_mode
  if not m then local a = settings and settings.AutoRA; m = a and a.MeleeMode end
  m = tostring(m or 'distance'):lower()
  if m ~= 'all' and m ~= 'alternate' then m = 'distance' end
  return m
end
function xivhotbar3_component.hud_set_autora_melee_mode(mode)
  mode = tostring(mode or 'distance'):lower()
  if mode ~= 'all' and mode ~= 'alternate' then mode = 'distance' end
  if theme_options then theme_options.autora_melee_mode = mode end
  if settings then
    settings.AutoRA = settings.AutoRA or {}
    settings.AutoRA.MeleeMode = mode
    config.save(settings)
  end
end

function xivhotbar3_component.hud_get_ranged_autopin() return not (theme_options and theme_options.ranged_autopin == false) end
function xivhotbar3_component.hud_set_ranged_autopin(val)
  if theme_options then theme_options.ranged_autopin = val and true or false end
  local b = hb_behavior_settings(); if b then b.RangedAutoPin = val and true or false; config.save(settings) end
  if reload_hotbar then reload_hotbar() end
end

function xivhotbar3_component.hud_get_auto_equip_ammo() return theme_options and theme_options.auto_equip_ammo == true end
function xivhotbar3_component.hud_set_auto_equip_ammo(val)
  if theme_options then theme_options.auto_equip_ammo = val and true or false end
  local b = hb_behavior_settings(); if b then b.AutoEquipAmmo = val and true or false; config.save(settings) end
end

function xivhotbar3_component.hud_get_ammo_source() return (theme_options and theme_options.ammo_source) or 'any' end
function xivhotbar3_component.hud_set_ammo_source(val)
  val = tostring(val or 'any'):lower()
  if theme_options then theme_options.ammo_source = val end
  local b = hb_behavior_settings(); if b then b.AmmoSource = val; config.save(settings) end
end

function xivhotbar3_component.hud_get_collapse_gaps() return not (theme_options and theme_options.collapse_gaps == false) end
function xivhotbar3_component.hud_set_collapse_gaps(val)
  if theme_options then theme_options.collapse_gaps = val and true or false end
  local b = hb_behavior_settings(); if b then b.CollapseGaps = val and true or false; config.save(settings) end
  if reload_hotbar then reload_hotbar() end
end

function xivhotbar3_component.hud_get_autohide() return theme_options and theme_options.auto_hide_unusable == true end
function xivhotbar3_component.hud_set_autohide(val)
  if theme_options then theme_options.auto_hide_unusable = val and true or false end
  local b = hb_behavior_settings(); if b then b.AutoHideUnusable = val and true or false; config.save(settings) end
  if reload_hotbar then reload_hotbar() end
end

function xivhotbar3_component.choice_autogen_list()
  if not player then return {} end
  local cg = require('components/xivhotbar3/lib/choice_groups')
  local ok, raw = pcall(function() return cg:get_smart_choices(player) end)
  if not ok or type(raw) ~= 'table' then return {} end
  local out = {}
  for _, e in ipairs(raw) do
    local rt, ra
    local ok2, acts = pcall(function() return (select(1, cg:resolve(player, e.action))) end)
    if ok2 and type(acts) == 'table' and acts[1] then rt, ra = acts[1].type, acts[1].action end
    out[#out + 1] = { action = e.action, label = cg:get_label(e.action, player) or e.alias or e.action,
                      alias = e.alias, icon = e.icon, rep_type = rt, rep_action = ra }
  end
  return out
end

function xivhotbar3_component.choice_preview(group_id)
  if not player then return {} end
  local cg = require('components/xivhotbar3/lib/choice_groups')
  local ok, list = pcall(function() return (select(1, cg:resolve(player, group_id))) end)
  if not ok or type(list) ~= 'table' then return {} end
  local out = {}
  for _, a in ipairs(list) do
    out[#out + 1] = { type = a.type, action = a.action, alias = a.alias or a.action, icon = a.icon }
  end
  return out
end

local GENERIC_PET_SECTIONS = { SMN = 'Avatar', DRG = 'Wyvern', PUP = 'Automaton', BST = 'Beast' }

local expand_section_exclusions = nil
local function get_expand_exclusions()
  if expand_section_exclusions then return expand_section_exclusions end
  local res = require('resources')
  local constants = require('components/xivhotbar3/lib/constants')
  local exclude = { base = true }
  for _, j in pairs(res.jobs or {}) do
    if j.ens then exclude[tostring(j.ens):lower()] = true end
    if j.en then exclude[tostring(j.en):lower()] = true end
  end
  for _, wn in pairs(constants.WEAPONSKILL_TYPES or {}) do exclude[tostring(wn):lower()] = true end
  for _, b in pairs(res.buffs or {}) do if b.en then exclude[tostring(b.en):lower()] = true end end
  expand_section_exclusions = exclude
  return exclude
end

function xivhotbar3_component.expand_triggers()
  if not player then return {} end
  local am = require('components/xivhotbar3/lib/action_manager')
  local exclude = get_expand_exclusions()

  local seen, out = {}, {}
  local function add(name, note)
    name = tostring(name or '')
    if name == '' or seen[name:lower()] then return end
    seen[name:lower()] = true
    out[#out + 1] = { section = name, note = note }
  end
  local generic = GENERIC_PET_SECTIONS[tostring(player.main_job or ''):upper()]
  if generic then add(generic, 'any pet') end
  if player.pet_name and player.pet_name ~= '' then add(player.pet_name, 'current pet') end
  local sections = (am.get_job_sections and am:get_job_sections()) or {}
  local keys = {}
  for k, v in pairs(sections) do
    if type(k) == 'string' and type(v) == 'table' and #v > 0 then keys[#keys + 1] = k end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    if not exclude[k:lower()] then add(k) end
  end
  return out
end

function xivhotbar3_component.expand_section_entries(section)
  local am = require('components/xivhotbar3/lib/action_manager')
  local sections = (am.get_job_sections and am:get_job_sections()) or {}
  local sec = sections[tostring(section or '')]
  if type(sec) ~= 'table' then return {} end
  local out = {}
  for _, e in ipairs(sec) do
    if type(e) == 'table' and e[1] then
      local env, row, slot = tostring(e[1]):match('^(%a+)%s+(%d+)%s+(%d+)')
      if env then
        out[#out + 1] = { env = env, row = tonumber(row), slot = tonumber(slot),
          type = e[2], action = e[3], target = e[4], alias = e[5], icon = e[6] }
      end
    end
  end
  return out
end

function xivhotbar3_component.assign_expand_action(x, y, section, entry)
  if not entry or not entry.type or not entry.action or entry.action == '' then return false end
  section = tostring(section or '')
  if section == '' then return false end
  local row, col = xivhotbar3_component.slot_box_at(x, y)
  if not row then return false end
  local _, environment = player:get_hotbar_info_without_vitals()
  environment = environment or 'battle'
  local vis_slot = player:get_visible_slot_index(row, col, environment) or col
  local am = require('components/xivhotbar3/lib/action_manager')
  local slot = (am.visible_to_file_slot and am:visible_to_file_slot(row, vis_slot, environment)) or vis_slot
  local fm = require('components/xivhotbar3/lib/file_manager')
  fm:remove_from_section(section, environment, row, slot)
  fm:insert_action_in_section({ type = entry.type, action = entry.action,
      target = entry.target or 'me', alias = entry.alias or entry.action, icon = entry.icon },
    section, environment, row, slot)
  print(string.format('XIVHOTBAR2: %s "%s" added to the %s bar at slot %d-%d.',
    tostring(entry.type), tostring(entry.action), section, row, slot))
  reload_hotbar()
  return true, row, slot
end

function xivhotbar3_component.remove_expand_action(section, e)
  if not e then return false end
  local fm = require('components/xivhotbar3/lib/file_manager')
  local ok = fm:remove_from_section(tostring(section or ''), tostring(e.env or 'battle'),
    tonumber(e.row) or 0, tonumber(e.slot) or 0, e.action)
  if ok then reload_hotbar() end
  return ok
end

function xivhotbar3_component.remove_choice_slots(group_id)
  if not player or not player.name or player.name == '' then return 0 end
  if not group_id or tostring(group_id) == '' then return 0 end
  local res = require('resources')
  local fm = require('components/xivhotbar3/lib/file_manager')
  local base = HTB_PATH .. 'data/' .. player.name .. '/'
  local paths = { base .. 'General.lua' }
  for _, j in pairs(res.jobs or {}) do
    if j.ens then paths[#paths + 1] = base .. tostring(j.ens) .. '.lua' end
  end
  local removed = 0
  for _, p in ipairs(paths) do
    removed = removed + fm:remove_choice_references_in(p, group_id)
  end
  if removed > 0 then
    print(string.format('XIVHOTBAR2: removed %d hotbar slot%s using deleted choice "%s".',
      removed, removed == 1 and '' or 's', tostring(group_id)))
    reload_hotbar()
  end
  return removed
end

local CHOICE_MOD_KEYS = { capslock = 58, tab = 15, grave = 41, tilde = 41, lalt = 56, lctrl = 29 }

function xivhotbar3_component.hud_get_choice_key()
  local dik = (theme_options and theme_options.controls_choice_modifier) or 58
  local shift = theme_options and theme_options.controls_choice_modifier_shift_required == true
  if dik == 41 then return shift and 'tilde' or 'grave' end
  for name, d in pairs(CHOICE_MOD_KEYS) do
    if d == dik and name ~= 'tilde' and name ~= 'grave' then return name end
  end
  return 'dik' .. tostring(dik)
end

function xivhotbar3_component.hud_set_choice_key_dik(dik, shift_required)
  dik = tonumber(dik)
  if not dik or not (settings and settings.Controls) then return end
  settings.Controls.ChoiceModifier = dik
  settings.Controls.ChoiceModifierShiftRequired = shift_required == true
  config.save(settings)
  if theme_options then
    theme_options.controls_choice_modifier = dik
    theme_options.controls_choice_modifier_shift_required = shift_required == true
  end
end

function xivhotbar3_component.hud_set_choice_key(name)
  name = tostring(name or ''):lower()
  local dik = CHOICE_MOD_KEYS[name]
  if not dik then return end
  xivhotbar3_component.hud_set_choice_key_dik(dik, name == 'tilde')
end

function xivhotbar3_component.hud_get_choice_key_dik()
  return (theme_options and theme_options.controls_choice_modifier) or 58
end

function xivhotbar3_component.hud_get_choice_key_shift()
  return theme_options and theme_options.controls_choice_modifier_shift_required == true
end

function xivhotbar3_component.hud_get_choice_mode()
  return tostring((theme_options and theme_options.controls_choice_modifier_mode) or 'toggle')
end

function xivhotbar3_component.hud_set_choice_mode(mode)
  mode = tostring(mode or ''):lower()
  if mode ~= 'toggle' and mode ~= 'hold' and mode ~= 'oneshot' then return end
  if not (settings and settings.Controls) then return end
  settings.Controls.ChoiceModifierMode = mode
  config.save(settings)
  if theme_options then theme_options.controls_choice_modifier_mode = mode end
end

function xivhotbar3_component.hud_slot_rects(h)
  if not (ui and ui.hotbars and ui.hotbars[h]) then return nil end
  local out = {}
  local cols = (ui.theme and ui.theme.columns) or 12
  local bs = (ui.bar_scale and ui:bar_scale(h)) or 1
  if bs <= 0 then bs = 1 end
  for i = 1, cols do
    local x, y = ui:get_slot_xy(h, i)
    local ss = (ui.slot_scale and ui:slot_scale(h, i)) or 1
    local w = math.floor((ui.image_width or 32) * bs * ss)
    local hh = math.floor((ui.image_height or 32) * bs * ss)
    out[#out + 1] = { i = i, x = x, y = y, w = w, h = hh, scale = bs * ss }
  end
  return out
end

function xivhotbar3_component.hud_reset_slot(h, i)
  h, i = tonumber(h), tonumber(i)
  if not (h and i and ui and ui.slot_custom_offsets) then return false end
  if ui.slot_custom_offsets[h] then ui.slot_custom_offsets[h][i] = nil end
  if ui.set_slot_scale then ui:set_slot_scale(h, i, 1) end
  if ui.rescale and ui.theme then ui:rescale(ui.theme.slot_icon_scale or 1) end
  if ui.reposition_slot then ui:reposition_slot(h, i) end
  capture_environment_layout(get_active_env())
  save_job_layout()
  return true
end

function xivhotbar3_component.hud_reset_slots(h)
  h = tonumber(h)
  if not h or not (ui and ui.clear_slot_custom_offsets_for_row) then return false end
  ui:clear_slot_custom_offsets_for_row(h)
  if ui.rescale and ui.theme then ui:rescale(ui.theme.slot_icon_scale or 1) end
  if ui.reposition_all_bars then ui:reposition_all_bars() end
  capture_environment_layout(get_active_env())
  save_job_layout()
  return true
end

function xivhotbar3_component.hud_set_slot_scale_live(h, i, scale)
  h, i = tonumber(h), tonumber(i)
  if not (h and i and ui and ui.set_slot_scale) then return end
  local bs = (ui.bar_scale and ui:bar_scale(h)) or 1
  if bs <= 0 then bs = 1 end
  ui:set_slot_scale(h, i, (tonumber(scale) or bs) / bs)
  if ui.resize_slot then ui:resize_slot(h, i) end
end

function xivhotbar3_component.hud_set_slot_scale(h, i, scale)
  xivhotbar3_component.hud_set_slot_scale_live(h, i, scale)
  capture_environment_layout(get_active_env())
  save_job_layout()
end

function xivhotbar3_component.hud_move_slot_live(h, i, x, y)
  if not (ui and ui.get_slot_xy) then return end
  local cur = ui.get_slot_custom_offset and ui:get_slot_custom_offset(h, i)
  local cx, cy = ui:get_slot_xy(h, i)
  local bx = cx - ((cur and cur.dx) or 0)
  local by = cy - ((cur and cur.dy) or 0)
  ui:set_slot_custom_offset(h, i, math.floor(x - bx), math.floor(y - by))
  if ui.reposition_slot then ui:reposition_slot(h, i) end
end

function xivhotbar3_component.hud_move_slot(h, i, x, y)
  xivhotbar3_component.hud_move_slot_live(h, i, x, y)
  capture_environment_layout(get_active_env())
  save_job_layout()
end

function xivhotbar3_component.hud_get_sets_visible() return hotbar_sets:is_visible() end

function xivhotbar3_component.hud_set_sets_visible(v)
  hotbar_sets:set_visible(v and true or false)
  if settings and settings.HotbarSets then
    settings.HotbarSets.Visible = hotbar_sets:is_visible()
    config.save(settings)
  end
end

function xivhotbar3_component.hud_sets_rect()
  local x, y, w, h = hotbar_sets:grid_bounds()
  if not x then return nil end
  return { x = x, y = y, w = w, h = h, scale = hotbar_sets:get_dot_scale(), visible = hotbar_sets:is_visible() }
end

function xivhotbar3_component.hud_set_sets_scale_live(f)
  hotbar_sets:set_dot_scale(f)
end

function xivhotbar3_component.hud_set_sets_scale(f)
  hotbar_sets:set_dot_scale(f)
  if settings and settings.HotbarSets then
    settings.HotbarSets.DotScale = tonumber(f) or settings.HotbarSets.DotScale
    config.save(settings)
  end
end

function xivhotbar3_component.hud_move_sets_live(x, y)
  hotbar_sets:move_to(x, y)
end

function xivhotbar3_component.hud_move_sets(x, y)
  hotbar_sets:move_to(x, y)
  if settings and settings.HotbarSets and settings.HotbarSets.Pos then
    settings.HotbarSets.Pos.X = math.floor(x)
    settings.HotbarSets.Pos.Y = math.floor(y)
    config.save(settings)
  end
end

function xivhotbar3_component.autogen_panel()
  if not (player and theme_options) then return nil end
  local ok, entries, prefs = pcall(hotbar_tools.collect_preview_entries, hotbar_tools, player, theme_options)
  if not ok or type(entries) ~= 'table' then return nil end
  local excluded = (prefs and prefs.excluded) or {}
  local seen, cats = {}, {}
  local function bar_for(cat)
    if prefs.battle and prefs.battle[cat] then return tonumber(prefs.battle[cat]) end
    local m = prefs.magic and prefs.magic[cat]
    if type(m) == 'table' then return tonumber(m.bar) end
    return nil
  end
  for _, e in ipairs(entries) do
    e.key = tostring(e.type or ''):lower() .. '|' .. tostring(e.action or ''):lower()
    e.excluded = excluded[e.key] == true
    local c = tostring(e.category or '')
    if c ~= '' and not seen[c] then
      seen[c] = true
      cats[#cats + 1] = { key = c, label = hotbar_tools:category_label(c), bar = bar_for(c) }
    end
  end
  return { entries = entries, cats = cats, overlay = (prefs and prefs.overlay) == true,
           job = tostring(player.main_job or '?') }
end

function xivhotbar3_component.autogen_set_enabled(v)
  if not player then return end
  local prefs = hotbar_tools:load_preferences(player)
  prefs.overlay = v and true or false
  hotbar_tools:save_preferences(player, prefs)
  reload_hotbar()
end

function xivhotbar3_component.autogen_set_bar(category, bar)
  if not player then return end
  bar = tonumber(bar)
  if bar and bar >= 1 and bar <= 6 then
    hotbar_tools:set_category_bar(player, category, bar, 'battle')
  else
    local resolved = hotbar_tools:resolve_category(category) or category
    local prefs = hotbar_tools:load_preferences(player)
    if prefs.magic and prefs.magic[resolved] then prefs.magic[resolved] = nil
    elseif prefs.pet and prefs.pet[resolved] then prefs.pet[resolved] = nil
    else
      prefs.battle[resolved] = nil
      prefs.field[resolved] = nil
    end
    if type(prefs.bar_order) == 'table' then
      local out = {}
      for _, k in ipairs(prefs.bar_order) do if k ~= resolved then out[#out + 1] = k end end
      prefs.bar_order = out
    end
    hotbar_tools:save_preferences(player, prefs)
  end
  reload_hotbar()
end

function xivhotbar3_component.autogen_set_order(category, keys)
  if not player or not category then return end
  local prefs = hotbar_tools:load_preferences(player)
  prefs.order = prefs.order or {}
  if type(keys) == 'table' and #keys > 0 then
    prefs.order[tostring(category)] = keys
  else
    prefs.order[tostring(category)] = nil
  end
  hotbar_tools:save_preferences(player, prefs)
  reload_hotbar()
end

function xivhotbar3_component.autogen_toggle_exclude(key)
  if not player or not key or key == '' then return end
  local prefs = hotbar_tools:load_preferences(player)
  prefs.excluded = prefs.excluded or {}
  if prefs.excluded[key] then prefs.excluded[key] = nil else prefs.excluded[key] = true end
  hotbar_tools:save_preferences(player, prefs)
  reload_hotbar()
end

function xivhotbar3_component.get_choice_drag_merge()
  return theme_options ~= nil and theme_options.choice_drag_merge == true
end

function xivhotbar3_component.set_choice_drag_merge(val)
  if not theme_options then return end
  theme_options.choice_drag_merge = val and true or false
  if settings and settings.Hotbar then
    settings.Hotbar.Behavior = settings.Hotbar.Behavior or {}
    settings.Hotbar.Behavior.ChoiceDragMerge = theme_options.choice_drag_merge
    config.save(settings)
  end
end

function xivhotbar3_component.apply_style_relayout()
  if not (theme and settings and theme_options and ui) then return end
  local nt = theme.apply(settings)
  for _, k in ipairs({ 'hide_empty_slots', 'hide_action_names', 'hide_action_cost', 'slot_opacity',
      'slot_spacing', 'vertical_slot_spacing', 'show_empty_slot_frames', 'hotbar_spacing' }) do
    theme_options[k] = nt[k]
    if ui.theme then ui.theme[k] = nt[k] end
  end
  ui.slot_spacing = theme_options.slot_spacing or ui.slot_spacing
  ui.hotbar_spacing = theme_options.hotbar_spacing or ui.hotbar_spacing
  ui.vertical_slot_spacing = theme_options.vertical_slot_spacing or ui.vertical_slot_spacing
  if ui.reposition_all_bars and ui.hotbars and ui.hotbars[1] then ui:reposition_all_bars() end
  if player and player.get_hotbar_info then
    if ui.load_player_hotbar then ui:load_player_hotbar(player:get_hotbar_info()) end
    if ui.show then ui:show(player:get_hotbar_info()) end
  end
end

function xivhotbar3_component.apply_theme(id)
  if not (theme and settings and theme_options and ui) then return end
  local nt = theme.apply(settings)
  for k, v in pairs(nt) do
    if type(v) ~= 'table' then theme_options[k] = v end
  end
  if reload_hotbar then reload_hotbar() end
end

function xivhotbar3_component.hud_get_style()
  return hud_current_style or (settings and settings.Hotbar and settings.Hotbar.StyleName) or 'xiv'
end
function xivhotbar3_component.hud_set_style(name)
  if not (settings and hotbar_tools and hotbar_tools.apply_style) then return end
  if hotbar_tools:apply_style(settings, { name }) then
    if settings.Hotbar then settings.Hotbar.StyleName = name end
    config.save(settings)
    hud_current_style = name
    xivhotbar3_component.apply_style_relayout()
  end
end

function xivhotbar3_component.hud_job_override() return theme_options.job_override == true end

function xivhotbar3_component.hud_set_job_override(val)
  theme_options.job_override = val and true or false
  save_job_layout()
  apply_environment_layout(get_active_env())
end

return xivhotbar3_component
