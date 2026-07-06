local action_manager = require('components/xivhotbar3/lib/action_manager')
local extdata = require('extdata')
local player = {}

local USE_EQUIP_WINDOWER_KEYS = {
  main='main', sub='sub', range='range', ammo='ammo',
  head='head', body='body', hands='hands', legs='legs', feet='feet',
  neck='neck', waist='waist', back='back',
  lear='left_ear', rear='right_ear',
  ring1='left_ring', ring2='right_ring',
}

player.name = ''
player.main_job = ''
player.sub_job = ''
player.server = ''
player.pet_name = ''
player.finishing_moves = 0

player.main_job_level = 0
player.sub_job_level = 0
player.vitals = {}
player.vitals.mp = 0
player.vitals.tp = 0
player.id = 0
player.current_weapon = 0
player.current_range_weapon = 0
player.buffs = {}
player.has_free_spell = false
player.has_shield = false
player.has_angon = false
player.has_jug      = false
player.has_animator = false
player.has_overload = false
player.pup_overload_chances = {}
player.utsusemi_shadows = 0
player.utsusemi_shadow_tier = 0
player.has_luopan = false
player.luopan_id = nil
player.luopan_geo_pending = false
player.scavenge_ammo_expended = 0
player.boost_expires = 0
player.autora_active = false
player.autora_pending_at = nil
player.autora_last_fire = nil
player.has_ranged_ammo = false
player.ranged_ammo_count = 0
player.ammo_skill = 0
player.has_penury = false
player.has_parsimony = false
player.has_apogee = false
player.has_trance = false
player.has_sekko = false
player.has_meikyo = false
player.has_tabula_rasa = false
player.has_astral_flow = false
player.has_spirit_surge = false
player.has_enlightenment = false
player.enlightenment_expires = 0
player.has_jug_pet = false
player.set_blue_magic = nil
player.items = {}

player.item_count = {}

function player:get_finishing_moves()
  return self.finishing_moves
end

function player:get_hotbar_info_without_vitals()
  local hotbar = action_manager.hotbar
  local active_environment = action_manager.hotbar_settings.active_environment
  return hotbar, active_environment
end

function player:get_hotbar_info()
  local hotbar = action_manager.hotbar
  local active_environment = action_manager.hotbar_settings.active_environment
  local windower_player = windower.ffxi.get_player()
  local vitals = windower_player and windower_player.vitals or self.vitals or {}
  return hotbar, active_environment, vitals
end

function player:initialize(windower_player, server, theme_options)
  self.name           = windower_player.name
  self.main_job_id    = windower_player.main_job_id
  self.sub_job_id     = windower_player.sub_job_id
  self.main_job       = windower_player.main_job
  self.sub_job        = windower_player.sub_job
  self.main_job_level = windower_player.main_job_level
  self.sub_job_level  = windower_player.sub_job_level
  self.server         = server
  self.buffs          = windower_player.buffs
  self.id             = windower_player.id
  self.vitals.mp      = windower_player.vitals.mp
  self.vitals.tp      = windower_player.vitals.tp
  self:update_costs()
  self:load_default_stance()
  action_manager:initialize(theme_options)
  action_manager:update_file_path(player.name, player.main_job)
end

function player:remove_action(remove_table)
  action_manager:remove_action(self, remove_table)
end

function player:update_job(main_id, main, sub_id, sub)
  self.main_job = main
  self.sub_job = sub
  self.main_job_id = main_id
  self.sub_job_id = sub_id
  action_manager:update_file_path(player.name, player.main_job)
end

function player:update_pet(name)
  self.pet_name = name
end

function player:update_finishing_moves(buff_id)
  if buff_id == 381 then
    self.finishing_moves = 1
  elseif buff_id == 382 then
    self.finishing_moves = 2
  elseif buff_id == 383 then
    self.finishing_moves = 3
  elseif buff_id == 384 then
    self.finishing_moves = 4
  elseif buff_id == 385 then
    self.finishing_moves = 5
  elseif buff_id == 588 then
    self.finishing_moves = 6
  end
end

function player:load_default_stance()
  for _, v in ipairs(self.buffs) do
    if v == 358 then
      action_manager:update_stance(211)
    elseif v == 359 then
      action_manager:update_stance(212)
    elseif v == 401 then
      action_manager:update_stance(234)
    elseif v == 402 then
      action_manager:update_stance(235)
    end
  end
  for _, v in ipairs(self.buffs) do
    self:update_finishing_moves(v)
  end
end

function player:update_blue_magic(blue_spells)
  self.set_blue_magic = blue_spells
end

function player:update_costs()
  local has_free_spell = false
  local has_penury = false
  local has_parsimony = false
  local has_apogee = false
  local has_trance = false
  local has_sekko = false
  local has_meikyo = false
  local has_tabula_rasa = false
  local has_astral_flow = false
  local has_spirit_surge = false

  for _, v in ipairs(self.buffs) do
    if v == 47 or v == 229 then
      has_free_spell = true
    elseif v == 360 then
      has_penury = true
    elseif v == 361 then
      has_parsimony = true
    elseif v == 583 then
      has_apogee = true
    elseif v == 376 then
      has_trance = true
    elseif v == 408 then
      has_sekko = true
    elseif v == 54 then
      has_meikyo = true
    elseif v == 377 then
      has_tabula_rasa = true
    elseif v == 55 then
      has_astral_flow = true
    elseif v == 126 then
      has_spirit_surge = true
    end
  end

  self.has_free_spell = has_free_spell
  self.has_penury = has_penury
  self.has_parsimony = has_parsimony
  self.has_apogee = has_apogee
  self.has_trance = has_trance
  self.has_sekko = has_sekko
  self.has_meikyo = has_meikyo
  self.has_tabula_rasa = has_tabula_rasa
  self.has_astral_flow = has_astral_flow
  self.has_spirit_surge = has_spirit_surge
  if self.enlightenment_expires and self.enlightenment_expires > 0 and os.clock() > self.enlightenment_expires then
    self.has_enlightenment = false
    self.enlightenment_expires = 0
  end
end

function player:add_buff(buff_id)
  for _, v in ipairs(self.buffs) do
    if v == buff_id then
      buff_id = nil
      break
    end
  end
  if buff_id then
    table.insert(self.buffs, buff_id)
  end
  self:update_costs()
end

function player:remove_buff(buff_id)
  for i, v in ipairs(self.buffs) do
    if v == buff_id then
      table.remove(self.buffs, i)
      break
    end
  end
  self:update_costs()
end

function player:set_enlightenment_override(enabled, duration)
  self.has_enlightenment = enabled == true
  if self.has_enlightenment then
    self.enlightenment_expires = os.clock() + (tonumber(duration) or 60)
  else
    self.enlightenment_expires = 0
  end
end

function player:consume_enlightenment_override()
  if self.has_enlightenment then
    self.has_enlightenment = false
    self.enlightenment_expires = 0
    return true
  end
  return false
end

function player:reset_finishing_moves()
  self.finishing_moves = 0
end

function player:update_level(main_level, sub_level)
  self.main_job_level = main_level
  self.sub_job_level = sub_level
end

function player:get_main_job_level()
  return self.main_job_level
end

function player:load_hotbar()
  action_manager:reset_hotbar()
  action_manager:load(self)
end

function player:swap_actions(swap_table)
  action_manager:swap_actions(player, swap_table)
end

function player:update_weapon_type(skill_type)
  player.current_weapon = skill_type
end

function player:update_shield(equipped)
  player.has_shield = equipped == true
end

function player:update_angon(equipped)
  player.has_angon = equipped == true
end

function player:update_jug(equipped)
  player.has_jug = equipped == true
end

function player:update_animator(equipped)
  player.has_animator = equipped == true
end

function player:update_range_weapon_type(skill_type)
  player.current_range_weapon = skill_type
end

function player:update_ranged_ammo(equipped)
  player.has_ranged_ammo = equipped == true
end

function player:load_job_ability_actions(buff_id)
  action_manager:update_stance(buff_id)
  action_manager:reset_hotbar()
  action_manager:load(self)
end

function player:toggle_environment()
  action_manager:toggle_environment()
end

function player:set_battle_environment(in_battle)
  local environment = 'field'
  if in_battle then environment = 'battle' end

  action_manager.hotbar_settings.active_environment = environment
end

function player:change_active_hotbar(new_hotbar)
  action_manager:change_active_hotbar(new_hotbar)
end

function player:insert_action(args)
  action_manager:insert_action(player.sub_job, args)
end

function player:determine_summoner_id(pet_name)
  for buff_id, buff_name in pairs(buff_table) do
    if buff_name == pet_name then
      return buff_id
    end
  end
  return 0
end

function player:get_active_hotbar()
  return action_manager.hotbar_settings.active_hotbar
end

function player:get_raw_action(slot)
  return action_manager:get_raw_action(slot)
end

function player:get_visible_slot_index(row, slot, environment)
  if action_manager.get_visible_slot_index then
    return action_manager:get_visible_slot_index(row, slot, environment)
  end
  return slot
end

function player:get_visible_action(environment, row, slot)
  if action_manager.get_visible_action then
    return action_manager:get_visible_action(row, slot, environment)
  end
  local hotbar = action_manager.hotbar[environment] and action_manager.hotbar[environment]['hotbar_' .. row]
  return hotbar and hotbar['slot_' .. slot] or nil
end

function player:get_hotbar_page_info(environment, row)
  if action_manager.get_hotbar_page and action_manager.get_row_page_count then
    return action_manager:get_hotbar_page(environment, row), action_manager:get_row_page_count(environment, row)
  end
  return 1, 1
end

function player:change_hotbar_page(environment, row, delta)
  if action_manager.change_hotbar_page then
    return action_manager:change_hotbar_page(environment, row, delta)
  end
  return 1, 1
end

function player:get_action(slot)
  return action_manager:get_action(slot, self)
end

function player:get_action_choices(slot)
  return action_manager:get_action_choices(slot, self)
end

function player:get_action_choices_for_action(action)
  if action_manager.get_action_choices_for_action then
    return action_manager:get_action_choices_for_action(action, self)
  end
  return nil
end

function player:resolve_action_for_resources(action)
  return action_manager:resolve_action_for_resources(action, self)
end

function player:clear_resource_resolution_cache()
  if action_manager.clear_resource_resolution_cache then
    action_manager:clear_resource_resolution_cache()
  end
end

function player:execute_action_object(action, exact_action)
  if action == nil then return false end

  if exact_action ~= true then
    action = action_manager:resolve_action_for_resources(action, self)
  end
  if action == nil then return false end

  local action_type = tostring(action.type or ''):lower()

  if action_type == 'choice' or action_type == 'choice_page_next' or action_type == 'choice_page_prev' then
    return false
  end

  do
    local ok, cg = pcall(require, 'components/xivhotbar3/lib/choice_groups')
    if ok and cg and cg.is_parent_ability and cg:is_parent_ability(action.action) then
      (_G.xivui_echo or print)('XIVHOTBAR2: "' .. tostring(action.action)
        .. '" can\'t be used directly — place the individual options, or use a choice from the Choice panel.')
      return false
    end
  end

  if action_type == 'ct' then
    local command = '/' .. action.action

    if action.target ~= nil and action.target ~= "" then
      command = command .. ' <' .. action.target .. '>'
    end

    windower.chat.input(command)
    return true
  elseif action_type == 'macro' then
    windower.chat.input('//' .. action.action)
  elseif action_type == 'gs' then
    windower.chat.input('//gs ' .. action.action)
  elseif action_type == 's' then
    windower.chat.input('//send ' .. action.action)
  elseif action_type == 'input' then
    local body = tostring(action.action or '')
    if body:find(';;') or body:find('[\r\n]') then
      local norm = body:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub(';;', '\n')
      local delay = 0
      for line in (norm .. '\n'):gmatch('([^\n]*)\n') do
        local slash_wait = line:match('^%s*/wait%s+([%d%.]+)%s*$')
        local inline_wait = line:match('<wait%s+([%d%.]+)%s*>')
        local cmd = slash_wait and '' or line:gsub('<wait%s+[%d%.]+%s*>', '')
        cmd = cmd:gsub('^%s+', ''):gsub('%s+$', '')
        if cmd ~= '' then
          local d, c = delay, cmd
          coroutine.schedule(function() windower.chat.input(c) end, d)
          delay = delay + 0.1
        end
        local add = tonumber(slash_wait or inline_wait)
        if add then delay = delay + add end
      end
    else
      windower.chat.input('//input ' .. body)
    end
  elseif action_type == 'key' then
    local parts = {}
    for part in tostring(action.action):lower():gmatch('[^+]+') do
      local k = part:gsub('^ctrl$', 'lctrl'):gsub('^shift$', 'lshift'):gsub('^alt$', 'lalt')
      parts[#parts+1] = k
    end
    local main = parts[#parts]
    if main then
      local cmds = {}
      for i = 1, #parts - 1 do cmds[#cmds+1] = 'setkey ' .. parts[i] .. ' down' end
      cmds[#cmds+1] = 'setkey ' .. main .. ' down'
      cmds[#cmds+1] = 'wait 0.05'
      cmds[#cmds+1] = 'setkey ' .. main .. ' up'
      for i = #parts - 1, 1, -1 do cmds[#cmds+1] = 'setkey ' .. parts[i] .. ' up' end
      windower.send_command(table.concat(cmds, '; '))
    end
  elseif action_type == 'use_equip' then
    local slot_cmd  = tostring(action.target or '')
    local item_name = tostring(action.action or '')
    if slot_cmd ~= '' and item_name ~= '' then
      local original_name = nil
      local windower_key  = USE_EQUIP_WINDOWER_KEYS[slot_cmd]
      if windower_key then
        local all_items = windower.ffxi.get_items()
        if all_items and all_items.equipment then
          local bag = all_items.equipment[windower_key .. '_bag']
          local idx = all_items.equipment[windower_key]
          if bag and idx and idx ~= 0 then
            local equipped = windower.ffxi.get_items(bag, idx)
            if equipped and equipped.id and equipped.id ~= 0 and resources.items[equipped.id] then
              original_name = resources.items[equipped.id].en
            end
          end
        end
      end
      local restore = (original_name and original_name:lower() ~= item_name:lower()) and original_name or nil
      coroutine.schedule(function()
        windower.chat.input('/equip ' .. slot_cmd .. ' "' .. item_name .. '"')
        coroutine.sleep(0.5)
        local equip_bag, equip_idx
        if windower_key then
          local all_items_post = windower.ffxi.get_items()
          if all_items_post and all_items_post.equipment then
            equip_bag = all_items_post.equipment[windower_key .. '_bag']
            equip_idx = all_items_post.equipment[windower_key]
          end
        end
        local cast_time = 1
        local tries = 0
        repeat
          coroutine.sleep(0.5)
          tries = tries + 1
          local ready = false
          if equip_bag and equip_idx then
            local item_obj = windower.ffxi.get_items(equip_bag, equip_idx)
            if item_obj and item_obj.id and item_obj.id ~= 0 then
              local res_item = resources.items[item_obj.id]
              if res_item then cast_time = res_item.cast_time or 1 end
              if item_obj.extdata then
                local ok, ext = pcall(extdata.decode, item_obj)
                if ok and ext and ext.usable ~= nil then
                  ready = ext.usable
                else
                  ready = true
                end
              else
                ready = true
              end
            else
              ready = true
            end
          else
            ready = true
          end
          if ready then break end
        until tries >= 20
        windower.chat.input('/item "' .. item_name .. '" <me>')
        if restore then
          coroutine.sleep(cast_time + 0.5)
          windower.chat.input('/equip ' .. slot_cmd .. ' "' .. restore .. '"')
        end
      end, 0)
    end
  elseif action_type == 'autora' then
    self.autora_active = not self.autora_active
    if self.autora_active then
      self.autora_pending_at = os.clock() + 0.1
      self.autora_last_fire = nil
    else
      self.autora_pending_at = nil
      self.autora_last_fire = nil
    end
  else
    local confirmed_st = false
    if action_manager.theme_options.confirm_subtarget_if_necessary then
      local st = windower.ffxi.get_mob_by_target('st')
      if st then
        windower.send_command('setkey enter down; wait 0.1; setkey enter up')
        confirmed_st = true
      end
    end
    if not confirmed_st then
      local cmd_prefix = action.exec_prefix or action_type
      windower.chat.input('/' .. cmd_prefix .. ' "' .. action.action .. '" <' .. action.target .. '>')
    end
  end

  return true
end

function player:execute_action(slot)
  local action = action_manager:get_action(slot, self)
  return self:execute_action_object(action)
end

local WARDROBE_BAG_IDS = {8, 10, 11, 12, 13, 14, 15, 16}
local EQUIPMENT_SLOT_KEYS = {
  'main','sub','range','ammo','head','body','hands','legs','feet',
  'neck','waist','back','left_ear','right_ear','left_ring','right_ring',
}

function player:update_inventory_items()
  self.items = {}
  self.item_count = {}
  self.equipped_item_names = {}

  local function add_from_bag(bag)
    if bag == nil then return end
    for _, item in ipairs(bag) do
      if item.id and item.id ~= 0 then
        local res_item = resources.items[item.id]

        if res_item and res_item.en then
          local cnt = item.count or 1
          if self.item_count[res_item.en] then
            self.item_count[res_item.en] = self.item_count[res_item.en] + cnt
          else
            self.item_count[res_item.en] = cnt
          end

          if res_item.targets and next(res_item.targets) then
            local target = ''

            if res_item.targets['Self'] and not (res_item.targets['Player'] or res_item.targets['Party'] or res_item.targets['Ally'] or res_item.targets['Enemy'] or res_item.targets['Object'] or res_item.targets['Corpse']) then
              target = 'me'

            elseif (res_item.targets['Player'] or res_item.targets['Party'] or res_item.targets['Ally']) and not (res_item.targets['Enemy'] or res_item.targets['Object'] or res_item.targets['Corpse']) then
              target = 'stpc'

            elseif (res_item.targets['Enemy'] or res_item.targets['NPC']) and not (res_item.targets['Object'] or res_item.targets['Corpse']) then
              target = 'stnpc'

            else
              target = 'st'
            end

            table.insert(self.items, {
              name = res_item.en,
              target = target
            })
          end
        end
      end
    end
  end

  add_from_bag(windower.ffxi.get_items(3))
  add_from_bag(windower.ffxi.get_items(0))
  for _, bag_id in ipairs(WARDROBE_BAG_IDS) do
    add_from_bag(windower.ffxi.get_items(bag_id))
  end

  local all_items = windower.ffxi.get_items()
  if all_items and all_items.equipment then
    local eq = all_items.equipment
    for _, key in ipairs(EQUIPMENT_SLOT_KEYS) do
      local bag = eq[key .. '_bag']
      local idx = eq[key]
      if bag and idx and idx ~= 0 then
        local equipped = windower.ffxi.get_items(bag, idx)
        if equipped and equipped.id and equipped.id ~= 0 and resources.items[equipped.id] then
          self.equipped_item_names[resources.items[equipped.id].en] = true
        end
      end
    end
  end
end

function player:get_item_from_filter(filter)
  if filter then
    if tonumber(filter) then
      local matched_item = self.items[tonumber(filter)]
      if matched_item then
        return matched_item
      end
    else
      local matched_item

      for _, item in ipairs(self.items) do
        if string.find(item.name, filter) then
          matched_item = item
          break
        end
      end
      return matched_item
    end
  end
end

return player
