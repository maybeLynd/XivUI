local file_manager = require('components/xivhotbar3/lib/file_manager')
local spell_list = require('components/xivhotbar3/priv_res/spells')
local horizon_spell_list = require('components/xivhotbar3/priv_res/horizon_spells')
local ws_list = require('components/xivhotbar3/priv_res/weapon_skills')
local ability_list = require('components/xivhotbar3/priv_res/job_abilities')
local ability_level_list = require('components/xivhotbar3/priv_res/job_abilities_levels')
local weaponskill_level_list = require('components/xivhotbar3/priv_res/weapon_skills_levels')

local _action_icons = require('components/xivhotbar3/lib/icon_registry')

local spells = {}
local abilities = {}
local weaponskills = {}

local action_manager = {}
local mainjob_actions = {}
local subjob_actions = {}
local petname_actions = {}
local general_actions = {}
local stance_actions = {}
local weaponskill_actions = {}
local current_stance = nil
local last_job_root = nil
local learned_spells_name = {}
local learned_ws_id = {}
local learned_abilities_id = {}
usable_pet_abilities_name = {}

not_learned_spells_row_slot = {}

local _req_check_player = nil

local MERIT_ABILITY_IDS = {
  [149]=true,[150]=true,[151]=true,[152]=true,[153]=true,[154]=true,
  [155]=true,[156]=true,[157]=true,[158]=true,[159]=true,[160]=true,
  [161]=true,[162]=true,[163]=true,[164]=true,[165]=true,[166]=true,
  [167]=true,[168]=true,[169]=true,[170]=true,[171]=true,
  [175]=true,[176]=true,[177]=true,[178]=true,[179]=true,[180]=true,
  [237]=true,[238]=true,[239]=true,
  [240]=true,[241]=true,[242]=true,[243]=true,[244]=true,
  [354]=true,[355]=true,[375]=true,[376]=true,
}

local SCH_TR_SPELL_IDS = {
  [478] = true,
  [502] = true,
}

local BLU_UNBRIDLED_SPELL_IDS = {
  [736]=true,
  [737]=true,
  [738]=true,
  [739]=true,
  [740]=true,
  [741]=true,
  [742]=true,
  [743]=true,
  [744]=true,
  [745]=true,
  [746]=true,
  [750]=true,
  [751]=true,
  [752]=true,
  [753]=true,
}

buff_table = {
  [211] = 'Light Arts',
  [212] = 'Dark Arts',
  [234] = 'Addendum: White',
  [235] = 'Addendum: Black',
  [485] = 'Unbridled Learning',
  [505] = 'Unbridled Wisdom',
  [1001] = 'Carbuncle',
  [1002] = 'Ifrit',
  [1003] = 'Shiva',
  [1004] = 'Leviathan',
  [1005] = 'Ramuh',
  [1006] = 'Fenrir',
  [1007] = 'Diabolos',
  [1008] = 'Alexander',
  [1009] = 'Cait Sith',
  [1010] = 'Garuda',
  [1011] = 'Odin',
  [1012] = 'Titan',
  [1013] = 'Atomos',

}

weaponskill_actions.xivhotbar_keybinds_job = {}
subjob_actions.xivhotbar_keybinds_job = {}
petname_actions.xivhotbar_keybinds_job = {}

action_manager.theme_options = {}
action_manager.hotbar = {}
action_manager.hotbar_settings = {}
action_manager.hotbar_settings.max = 1
action_manager.hotbar_settings.active_hotbar = 1
action_manager.hotbar_settings.active_environment = 'battle'
action_manager.hotbar_page_state = { battle = {}, field = {} }
action_manager.items = {}

_job_fileG = {}
_job_fileG.xivhotbar_keybinds_job = {}
_general_fileG = {}
_general_fileG.xivhotbar_keybinds_general = {}

local weaponskill_types = require('components/xivhotbar3/lib/constants').WEAPONSKILL_TYPES

local en_to_spell_id = {}
local en_to_ability_id = {}
local en_to_weaponskill_id = {}

for spell_id, spell_data in pairs(resources.spells) do
  en_to_spell_id[spell_data.en] = spell_id
end

for ability_id, ability_data in pairs(resources.job_abilities) do
  en_to_ability_id[ability_data.en] = ability_id
end

for weapon_skill_id, weapon_skill_data in pairs(resources.weapon_skills) do
  en_to_weaponskill_id[weapon_skill_data.en] = weapon_skill_id
end

local keybinds_job_table = {
  __index = function(g, k)
    local t = rawget(rawget(g, 'xivhotbar_keybinds_job'), k)
    if not t then
      t = {}
      rawset(rawget(g, 'xivhotbar_keybinds_job'), k, t)
    end
    return t
  end,
  __newindex = function(g, k, v)
    local t = rawget(rawget(g, 'xivhotbar_keybinds_job'), k)
    if t and type(v) == 'table' then
      for k, v in pairs(v) do
        t[k] = v
      end
    end
  end
}

local general_keybinds_table = {
  __index = function(g, k)
    local t = rawget(rawget(g, 'xivhotbar_keybinds_general'), k)
    if not t then
      t = {}
      rawset(rawget(g, 'xivhotbar_keybinds_general'), k, t)
    end
    return t
  end,
  __newindex = function(g, k, v)
    if k == 'xivhotbar_general_list' then
      rawset(g, k, v)
      return
    end
    local t = rawget(rawget(g, 'xivhotbar_keybinds_general'), k)
    if t and type(v) == 'table' then
      for k, v in pairs(v) do
        t[k] = v
      end
    end
  end
}

setmetatable(_job_fileG, keybinds_job_table)
setmetatable(_general_fileG, general_keybinds_table)
local CUSTOM_TYPE = 'ct'

local function init_action_table(actions_table)
  actions_table.environment = {}
  actions_table.hotbar = {}
  actions_table.slot = {}
  actions_table.type = {}
  actions_table.action = {}
  actions_table.target = {}
  actions_table.alias = {}
  actions_table.icon = {}
end

function action_manager:init_action_tables()
  init_action_table(mainjob_actions)
  init_action_table(subjob_actions)
  init_action_table(petname_actions)
  init_action_table(weaponskill_actions)
  init_action_table(general_actions)
  init_action_table(stance_actions)
end

function action_manager:build(type, action, target, alias, icon)
  local new_action  = {}

  new_action.type   = type
  new_action.action = action
  new_action.target = target

  if alias == nil then alias = ' ' end
  new_action.alias = alias

  if icon == '' then icon = nil end
  if icon ~= nil then
    new_action.icon = icon
  end

  return new_action
end

local roman_spell_tiers = {
  [''] = 0,
  ['I'] = 1,
  ['II'] = 2,
  ['III'] = 3,
  ['IV'] = 4,
  ['V'] = 5,
  ['VI'] = 6,
}

local ninjutsu_spell_tiers = {
  ['Ichi'] = 1,
  ['Ni'] = 2,
  ['San'] = 3,
}

local function normalize_spell_lookup_name(name)
  local n = tostring(name or ''):lower()
  n = n:gsub("^[%s\"']+", ''):gsub("[%s\"']+$", '')
  n = n:gsub('%s+', ' ')
  return n
end

local normalized_to_spell_name = {}
for _, spell_data in pairs(resources.spells) do
  if spell_data and spell_data.en then
    local nk = normalize_spell_lookup_name(spell_data.en)
    if not normalized_to_spell_name[nk] then
      normalized_to_spell_name[nk] = spell_data.en
    end
  end
end

local shortened_to_spell_name = nil

local function canonical_spell_name(name)
  name = tostring(name or '')
  if en_to_spell_id[name] ~= nil then
    return resources.spells[en_to_spell_id[name]].en or name
  end

  local lookup = normalize_spell_lookup_name(name)
  local found = normalized_to_spell_name[lookup]
  if found then return found end

  if _G.shorten_ability_name ~= nil then
    if shortened_to_spell_name == nil then
      shortened_to_spell_name = {}
      for _, sd in pairs(resources.spells) do
        if sd and sd.en then
          local sk = normalize_spell_lookup_name(_G.shorten_ability_name(sd.en))
          if not shortened_to_spell_name[sk] then
            shortened_to_spell_name[sk] = sd.en
          end
        end
      end
    end
    local sf = shortened_to_spell_name[lookup]
    if sf then return sf end
  end

  return name
end

local function get_spell_family_info(name)
  name = canonical_spell_name(name)
  name = tostring(name or '')
  local base, tier = name:match('^(.-)%s+([IV]+)$')
  if base and roman_spell_tiers[tier] ~= nil then
    return base, roman_spell_tiers[tier]
  end

  local n_base, n_tier = name:match('^(.-):%s*(Ichi)$')
  if n_base and n_tier then return n_base, ninjutsu_spell_tiers[n_tier] end
  n_base, n_tier = name:match('^(.-):%s*(Ni)$')
  if n_base and n_tier then return n_base, ninjutsu_spell_tiers[n_tier] end
  n_base, n_tier = name:match('^(.-):%s*(San)$')
  if n_base and n_tier then return n_base, ninjutsu_spell_tiers[n_tier] end

  return name, 0
end

local function get_spell_data(action)
  if not action or tostring(action.type or ''):lower() ~= 'ma' then return nil end
  local spell_name = canonical_spell_name(action.action or action.alias)
  local spell_id = en_to_spell_id[spell_name]
  if not spell_id then return nil end
  return resources.spells[spell_id]
end

local function get_ability_data(action)
  if not action or tostring(action.type or ''):lower() ~= 'ja' then return nil end
  local ability_id = en_to_ability_id[action.action]
  if not ability_id then return nil end
  return ability_list[ability_id] or resources.job_abilities[ability_id]
end

local function get_action_mp_cost(action, player)
  local action_type = tostring(action and action.type or ''):lower()
  local data = nil
  if action_type == 'ma' then
    data = get_spell_data(action)
  elseif action_type == 'ja' then
    data = get_ability_data(action)
  end

  if not data then return 0 end
  local cost = data.mpcost or data.mp_cost or data.mp or 0
  if cost == nil then cost = 0 end

  if action_type == 'ja' and not (data.type == 'BloodPactRage' or data.type == 'BloodPactWard') then
    return 0
  end

  if action_type == 'ma' then
    if player and player.has_free_spell == true then
      cost = 0
    elseif player and player.has_penury == true and data.type == 'WhiteMagic' then
      cost = math.ceil(cost * 0.5)
    elseif player and player.has_parsimony == true and data.type == 'BlackMagic' then
      cost = math.ceil(cost * 0.5)
    end
  elseif action_type == 'ja' then
    if player and player.has_apogee == true and (data.type == 'BloodPactRage' or data.type == 'BloodPactWard') then
      cost = math.ceil(cost * 1.5)
    end
  end

  return cost or 0
end

local function get_action_tp_cost(action, player)
  local action_type = tostring(action and action.type or ''):lower()
  if action_type == 'ws' then
    if player and player.has_meikyo == true then return 0 end
    return 1000
  elseif action_type == 'ja' then
    local data = get_ability_data(action)
    if not data then return 0 end
    local cost = data.tpcost or data.tp_cost or 0
    if player and player.has_trance == true and (data.type == 'Samba' or data.type == 'Step' or data.type == 'Waltz') then
      cost = 0
    end
    return cost or 0
  end
  return 0
end

local dedupe_choice_actions
local spell_family_candidates_cache = {}
local resource_resolution_cache = {}
local row_page_count_cache = {}

local function clear_resource_resolution_cache()
  resource_resolution_cache = {}
end

local _family_index
local function build_family_index()
  local idx = {}
  for _, spell_data in pairs(resources.spells) do
    if spell_data ~= nil and spell_data.en ~= nil then
      local candidate_name = canonical_spell_name(spell_data.en)
      local candidate_base, candidate_tier = get_spell_family_info(candidate_name)
      if candidate_base ~= nil then
        local list = idx[candidate_base]
        if not list then list = {}; idx[candidate_base] = list end
        list[#list + 1] = { name = candidate_name, tier = candidate_tier, type = spell_data.type }
      end
    end
  end
  for _, list in pairs(idx) do
    table.sort(list, function(a, b)
      if (a.tier or 0) == (b.tier or 0) then return tostring(a.name) < tostring(b.name) end
      return (a.tier or 0) < (b.tier or 0)
    end)
  end
  return idx
end

local function get_spell_family_candidates(family_base, source_spell_type)
  local cache_key = tostring(family_base or '') .. '|' .. tostring(source_spell_type or '')
  if spell_family_candidates_cache[cache_key] ~= nil then
    return spell_family_candidates_cache[cache_key]
  end

  _family_index = _family_index or build_family_index()
  local family = _family_index[family_base]
  local candidates = {}
  if family then
    for _, c in ipairs(family) do
      if source_spell_type == nil or source_spell_type == '' or c.type == source_spell_type then
        candidates[#candidates + 1] = c
      end
    end
  end

  spell_family_candidates_cache[cache_key] = candidates
  return candidates
end

local function effective_subjob_level(main_level, sub_level)
  local main = tonumber(main_level) or 0
  local sub = tonumber(sub_level) or 0
  if sub <= 0 then return 0 end

  local cap = math.floor(main / 2)
  if main >= 99 and cap < 49 then cap = 49 end
  if cap <= 0 then return sub end
  return math.min(sub, cap)
end

local function action_meets_current_access(action, player)
  if action == nil then return false end
  local action_type = tostring(action.type or ''):lower()

  if action_type == 'ma' then
    local spell_name = canonical_spell_name(action.action or action.alias)
    local spell_id = en_to_spell_id[spell_name]
    if not spell_id then return true end
    local spell = resources.spells[spell_id]
    if not spell then return true end

    if player ~= nil and _G.is_spell_usable_by_a_job ~= nil then
      return _G.is_spell_usable_by_a_job(spell, player) and (_G.is_blu_spell_set == nil or _G.is_blu_spell_set(spell, player))
    end

    return meets_spell_level_req(spell_name)
  elseif action_type == 'ja' then
    return meets_ability_level_req(action.action)
  elseif action_type == 'ws' then
    return meets_weaponskill_level_req(action.action)
  end

  return true
end

local function action_is_known(action)
  if action == nil then return false end
  local action_type = tostring(action.type or ''):lower()

  if action_type == 'ma' then
    local spell_name = canonical_spell_name(action.action or action.alias)
    local spell_id = en_to_spell_id[spell_name]
    if not spell_id then return true end
    return is_spell_learned(spell_name)
  elseif action_type == 'ja' then
    local ability_id = en_to_ability_id[action.action]
    if not ability_id then return true end
    return is_job_ability_learned(action.action)
  elseif action_type == 'ws' then
    local ws_id = en_to_weaponskill_id[action.action]
    if not ws_id then return true end
    return is_weaponskill_learned(action.action)
  elseif action_type == 'ct' then
    return is_job_ability_learned(action.action)
  end

  return true
end

local function action_is_affordable(action, player)
  if not action or not player then return true end
  local vitals = player.vitals or {}
  local mp = vitals.mp or 0
  local tp = vitals.tp or 0
  local mp_cost = get_action_mp_cost(action, player)
  local tp_cost = get_action_tp_cost(action, player)
  if mp_cost > 0 and mp < mp_cost then return false end
  if tp_cost > 0 and tp < tp_cost then return false end
  return true
end

local function copy_action_for_family(source_action, spell_name)
  local base, tier = get_spell_family_info(spell_name)
  local action = action_manager:build('ma', spell_name, source_action.target, shorten_ability_name(spell_name), nil)
  action._family_base = base
  action._family_tier = tier
  return action
end

local function mark_choice_status(action, player)
  if action == nil then return nil end

  local known = action_is_known(action)
  local accessible = action_meets_current_access(action, player)
  local affordable = action_is_affordable(action, player)

  action._choice_known = known
  action._choice_accessible = accessible
  action._choice_affordable = affordable
  action._choice_unlearned = not known
  action._choice_inaccessible = not accessible
  action._choice_unaffordable = accessible and known and not affordable
  action._choice_disabled = not (known and accessible and affordable)

  if not known then
    action._choice_disabled_reason = 'not learned'
  elseif not accessible then
    action._choice_disabled_reason = 'not available to current job/level'
  elseif not affordable then
    action._choice_disabled_reason = 'not enough MP/TP'
  else
    action._choice_disabled_reason = nil
  end

  return action
end

local function copy_action_table(source)
  if source == nil then return nil end
  local copy = {}
  for k, v in pairs(source) do
    if type(k) == 'string' then
      if string.sub(k, 1, 1) ~= '_' then
        copy[k] = v
      end
    else
      copy[k] = v
    end
  end
  return copy
end

local function copy_action_payload(source)
  return copy_action_table(source)
end

local function build_spell_family_static_choices(source_action)
  if not source_action or tostring(source_action.type or ''):lower() ~= 'ma' then return nil end

  local source_name = canonical_spell_name(source_action.action or source_action.alias)
  local source_spell = get_spell_data({ type = 'ma', action = source_name })
  local family_base = get_spell_family_info(source_name)
  local choices = {}
  local seen = {}

  local candidates = get_spell_family_candidates(family_base, source_spell and source_spell.type or nil)
  for _, candidate in ipairs(candidates) do
    local candidate_name = candidate.name
    if candidate_name ~= nil and not seen[candidate_name] then
      local action = copy_action_for_family(source_action, candidate_name)
      action._family_tier = candidate.tier
      table.insert(choices, action)
      seen[candidate_name] = true
    end
  end

  if #choices <= 1 then return nil end
  return dedupe_choice_actions(choices)
end

local function ensure_spell_family_shared_actions(action)
  if action == nil then return nil end
  if action._family_static_checked == true then
    return action._shared_actions
  end

  action._family_static_checked = true

  if action._shared_actions ~= nil and #action._shared_actions > 1 then
    action._shared_actions = dedupe_choice_actions(action._shared_actions)
    return action._shared_actions
  end

  if tostring(action.type or ''):lower() ~= 'ma' then
    return action._shared_actions
  end

  local family_actions = build_spell_family_static_choices(action)
  if family_actions ~= nil and #family_actions > 1 then
    action._shared_actions = family_actions
    return family_actions
  end

  return action._shared_actions
end

local function mark_and_dedupe_choice_payloads(static_choices, player)
  if static_choices == nil or #static_choices <= 1 then return nil end

  local choices = dedupe_choice_actions(static_choices)
  if choices == nil or #choices <= 1 then return nil end

  for _, entry in ipairs(choices) do
    mark_choice_status(entry, player)
  end

  return choices
end

local function build_spell_family_choices_stateless(source_action, player)
  if not source_action or tostring(source_action.type or ''):lower() ~= 'ma' then return nil end
  local static_choices = build_spell_family_static_choices(source_action)
  return mark_and_dedupe_choice_payloads(static_choices, player)
end

local function choice_action_key(action)
  if action == nil then return '' end
  local action_type = tostring(action.type or ''):lower()
  local action_name = tostring(action.action or '')
  if action_type == 'ma' then
    action_name = canonical_spell_name(action_name)
  end
  return action_type .. '|' .. normalize_spell_lookup_name(action_name) .. '|' .. tostring(action.target or '')
end

dedupe_choice_actions = function(actions)
  if actions == nil then return nil end

  local clean = {}
  local seen = {}
  for _, action in ipairs(actions) do
    local key = choice_action_key(action)
    if key ~= '' and not seen[key] then
      table.insert(clean, copy_action_table(action))
      seen[key] = true
    end
  end

  table.sort(clean, function(a, b)
    if tostring(a.type or ''):lower() == 'ma' and tostring(b.type or ''):lower() == 'ma' then
      local a_base, a_tier = get_spell_family_info(a.action)
      local b_base, b_tier = get_spell_family_info(b.action)
      if a_base == b_base and a_tier ~= b_tier then
        return a_tier < b_tier
      end
    end
    return tostring(a.action or '') < tostring(b.action or '')
  end)

  return clean
end

local function get_row_table(am, env, row)
  if env == 'b' then env = 'battle' elseif env == 'f' then env = 'field' end
  row = tonumber(row)
  if env == nil or row == nil then return nil end
  return am.hotbar[env] and am.hotbar[env]['hotbar_' .. row] or nil
end

local function get_row_max_slot(am, env, row)
  local row_table = get_row_table(am, env, row)
  local max_slot = 0
  if row_table == nil then return 0 end
  for key, value in pairs(row_table) do
    if value ~= nil then
      local slot = tostring(key):match('^slot_(%d+)$')
      slot = tonumber(slot)
      if slot ~= nil and slot > max_slot then max_slot = slot end
    end
  end
  return max_slot
end

local function get_row_page_count_internal(am, env, row)
  local cache_key = (env or '') .. '|' .. tostring(row or '')
  if row_page_count_cache[cache_key] then
    return row_page_count_cache[cache_key]
  end
  local columns = tonumber(am.theme_options and am.theme_options.columns or 12) or 12
  if columns < 1 then columns = 12 end
  local max_slot = get_row_max_slot(am, env, row)
  local result
  if max_slot <= columns then result = 1
  else result = math.min(5, math.max(1, math.ceil(max_slot / columns))) end
  row_page_count_cache[cache_key] = result
  return result
end

local function clamp_row_page(am, env, row)
  if env == 'b' then env = 'battle' elseif env == 'f' then env = 'field' end
  row = tonumber(row)
  if env == nil or row == nil then return 1 end
  am.hotbar_page_state[env] = am.hotbar_page_state[env] or {}
  local page_count = get_row_page_count_internal(am, env, row)
  local page = tonumber(am.hotbar_page_state[env][row] or 1) or 1
  if page < 1 then page = 1 end
  if page > page_count then page = page_count end
  am.hotbar_page_state[env][row] = page
  return page
end

local function add_action(am, action, environment, hotbar, slot)
  local status = true
  if environment == 'b' then environment = 'battle' elseif environment == 'f' then environment = 'field' end

  hotbar = tonumber(hotbar)
  slot = tonumber(slot)

  if am.hotbar[environment] == nil then
    windower.console.write('XIVHOTBAR: invalid hotbar (environment)')
    status = false
  end

  if hotbar == nil or hotbar > am.hotbar_rows or hotbar < 1 then
    status = false
  elseif am.hotbar[environment]['hotbar_' .. hotbar] == nil then
    windower.console.write('XIVHOTBAR: invalid hotbar (hotbar number)')
    status = false
  end

  if slot == nil or slot < 1 or slot > 999 then
    status = false
  end

  if status == true then
    local slot_key = 'slot_' .. slot
    local row = am.hotbar[environment]['hotbar_' .. hotbar]

    if action.type == 'autoitem' then
      local filter = action.action or ""
      local item = player:get_item_from_filter(filter)

      if item then
        action = {
          alias = shorten_ability_name(item.name),
          type = 'item',
          target = item.target,
          icon = action.icon,
          action = item.name
        }
      else
        row[slot_key] = nil
        return
      end
    end

    local stored = copy_action_payload(action)
    stored._file_slot = tonumber(slot)
    local existing = row[slot_key]
    if existing ~= nil then
      local prev_variants = existing._shared_actions
      if prev_variants == nil then
        prev_variants = { copy_action_payload(existing) }
      end
      table.insert(prev_variants, copy_action_payload(action))
      stored._shared_actions = prev_variants
    end
    row[slot_key] = stored
    row_page_count_cache[environment .. '|' .. tostring(hotbar)] = nil
  end
end

local function reindex_action_table(actions_table)
  local function reindex_table(original_table)
    local sequential_table = {}
    for _, value in pairs(original_table) do
      table.insert(sequential_table, value)
    end
    return sequential_table
  end

  actions_table.environment = reindex_table(actions_table.environment)
  actions_table.hotbar = reindex_table(actions_table.hotbar)
  actions_table.slot = reindex_table(actions_table.slot)
  actions_table.type = reindex_table(actions_table.type)
  actions_table.action = reindex_table(actions_table.action)
  actions_table.target = reindex_table(actions_table.target)
  actions_table.alias = reindex_table(actions_table.alias)
  actions_table.icon = reindex_table(actions_table.icon)
end

local AUTOGEN_START_MARKER = '-- XIVHOTBAR2_AUTOGEN_START'
local AUTOGEN_END_MARKER   = '-- XIVHOTBAR2_AUTOGEN_END'

local function read_manual_slots(filepath)
  local t = { environment = {}, hotbar = {}, slot = {} }
  local f = io.open(filepath, 'r')
  if not f then return t end
  local in_autogen = false
  local idx = 0
  for line in f:lines() do
    if     line:find(AUTOGEN_START_MARKER, 1, true) then in_autogen = true
    elseif line:find(AUTOGEN_END_MARKER,   1, true) then in_autogen = false
    elseif not in_autogen and not line:match('^%s*%-%-') then
      local slot_str = line:match("['\"]([^'\"]+)['\"]")
      if slot_str then
        local parts = {}
        for p in slot_str:gmatch('%S+') do parts[#parts + 1] = p end
        if #parts >= 3 then
          local e, r, s = parts[1], tonumber(parts[2]), tonumber(parts[3])
          if (e == 'battle' or e == 'b' or e == 'field' or e == 'f') and r and s then
            idx = idx + 1
            t.environment[idx] = e
            t.hotbar[idx]      = tostring(r)
            t.slot[idx]        = tostring(s)
          end
        end
      end
    end
  end
  f:close()
  return t
end

local function displace_into(base_t, incoming_t)
  if not base_t.environment or not incoming_t.environment then return end
  local inc_slots = {}
  local bar_max = {}
  for i = 1, #incoming_t.environment do
    local bk = incoming_t.environment[i] .. '\0' .. tostring(incoming_t.hotbar[i])
    local s = tonumber(incoming_t.slot[i]) or 0
    inc_slots[bk] = inc_slots[bk] or {}
    inc_slots[bk][s] = true
    if not bar_max[bk] or s > bar_max[bk] then bar_max[bk] = s end
  end
  for i = 1, #base_t.environment do
    local bk = base_t.environment[i] .. '\0' .. tostring(base_t.hotbar[i])
    if inc_slots[bk] then
      local s = tonumber(base_t.slot[i]) or 0
      if not bar_max[bk] or s > bar_max[bk] then bar_max[bk] = s end
    end
  end
  local displaced = {}
  for i = 1, #base_t.environment do
    local bk = base_t.environment[i] .. '\0' .. tostring(base_t.hotbar[i])
    if inc_slots[bk] then
      local s = tonumber(base_t.slot[i]) or 0
      if inc_slots[bk][s] then
        local gk = bk .. '\0' .. s
        if not displaced[gk] then
          bar_max[bk] = bar_max[bk] + 1
          displaced[gk] = bar_max[bk]
        end
        base_t.slot[i] = tostring(displaced[gk])
      end
    end
  end
end

local function fill_action_table(file_table, file_key, actions_table)
  if not file_table or not file_table[1] then return end
  local slot_key = T(tostring(file_table[1]):split(' '))

  if (file_table[2] == "bstpet") then
    local ability_name = usable_pet_abilities_name[tonumber(file_table[3]) or -1]
    if ability_name == nil then return end
    file_table[2] = "ja"
    file_table[3] = ability_name
    file_table[5] = shorten_ability_name(ability_name)
  end

  actions_table.environment[file_key] = slot_key[1]
  actions_table.hotbar[file_key]      = slot_key[2]
  actions_table.slot[file_key]        = slot_key[3]
  actions_table.type[file_key]        = file_table[2]
  actions_table.action[file_key]      = file_table[3]
  actions_table.target[file_key]      = file_table[4]
  actions_table.alias[file_key]       = file_table[5]

  local stored_icon = file_table[6]
  if stored_icon ~= nil and stored_icon ~= '' then
    actions_table.icon[file_key] = stored_icon
  else
    local ikey = tostring(file_table[2] or ''):lower() .. '|' .. tostring(file_table[3] or ''):lower()
    local dyn_icon = _action_icons[ikey]
    actions_table.icon[file_key] = (dyn_icon ~= nil and dyn_icon ~= '') and dyn_icon or ''
  end
end

function action_manager:update_stance(buff_id)
  current_stance = buff_id
end

function action_manager:get_stance()
  return current_stance or ""
end

local _slot_first_learned = nil

local function pre_process_spell_tiers(entries)
  if entries == nil then return {} end
  local slot_has_learned = {}
  for _, entry in ipairs(entries) do
    if entry[1] ~= nil and entry[2] ~= nil and entry[3] ~= nil then
      local slot = entry[1]
      local atype = tostring(entry[2]):lower()
      if atype == 'ma' then
        local name = entry[3]
        if meets_spell_level_req(name) and is_spell_learned(name) then
          local blu_ok = true
          if _G.is_blu_spell_set ~= nil and _req_check_player ~= nil then
            local sid = en_to_spell_id[name]
            local sp = sid and resources.spells[sid]
            if sp and not _G.is_blu_spell_set(sp, _req_check_player) then
              blu_ok = false
            end
          end
          if blu_ok then slot_has_learned[slot] = true end
        else
          not_learned_spells_row_slot[slot] = name
        end
      end
    end
  end
  return slot_has_learned
end

local function parse_general_binds(hotbar)
  if hotbar == nil or hotbar['Root'] == nil then return end
  _slot_first_learned = pre_process_spell_tiers(hotbar['Root'])
  for key, val in ipairs(hotbar['Root']) do
    if action_req_check(hotbar['Root'][key]) == true then
      fill_action_table(hotbar['Root'][key], key, general_actions)
      reindex_action_table(general_actions)
    end
  end
end

local GENERAL_LIST_TYPES = {
  item    = { type = 'item',  target = 'me'    },
  use     = { type = 'item',  target = 'me'    },
  gs      = { type = 'gs',    target = ''      },
  ma      = { type = 'ma',    target = 'stpc'  },
  ja      = { type = 'ja',    target = 'me'    },
  ws      = { type = 'ws',    target = 't'     },
  macro   = { type = 'macro', target = ''      },
  input   = { type = 'input', target = ''      },
}

local USE_EQUIP_SLOT_CMD = {
  [4]='head', [5]='body',  [6]='hands', [7]='legs',  [8]='feet',
  [9]='neck',  [10]='waist', [11]='lear', [12]='rear',
  [13]='ring1', [14]='ring2', [15]='back',
}

local function find_equip_use_slot(name)
  if not resources or not resources.items then return nil end
  local name_lower = name:lower()
  for _, item in pairs(resources.items) do
    if item.en and item.en:lower() == name_lower then
      if item.category == 'Armor' and item.slots and (item.cast_time or item.recast_delay or item.max_charges) then
        for bit_idx = 4, 15 do
          if item.slots[bit_idx] and USE_EQUIP_SLOT_CMD[bit_idx] then
            return USE_EQUIP_SLOT_CMD[bit_idx]
          end
        end
      end
      return nil
    end
  end
  return nil
end

local function parse_general_list(list, columns)
  if not list or type(list) ~= 'table' then return end
  columns = tonumber(columns) or 12

  local occupied = {}
  for i = 1, #general_actions.environment do
    local env = general_actions.environment[i]
    if env == 'field' or env == 'f' then
      occupied[tostring(general_actions.hotbar[i]) .. '\0' .. tostring(general_actions.slot[i])] = true
    end
  end

  local row, slot = 1, 1
  local function advance()
    occupied[tostring(row) .. '\0' .. tostring(slot)] = true
    slot = slot + 1
    if slot > columns then slot = 1; row = row + 1 end
  end
  local function skip_occupied()
    while occupied[tostring(row) .. '\0' .. tostring(slot)] do
      slot = slot + 1
      if slot > columns then slot = 1; row = row + 1 end
    end
  end

  for _, entry in ipairs(list) do
    if type(entry) == 'string' and entry ~= '' then
      local sh_type, name = entry:match('^(%S+)%s+(.-)%s*$')
      if sh_type and name and name ~= '' then
        local def = GENERAL_LIST_TYPES[sh_type:lower()]
        if def then
          local action_type   = def.type
          local action_name   = name
          local action_target = def.target

          if sh_type:lower() == 'use' then
            local equip_slot = find_equip_use_slot(name)
            if equip_slot then
              action_type   = 'use_equip'
              action_name   = name
              action_target = equip_slot
            end
          end

          skip_occupied()
          local idx = #general_actions.environment + 1
          general_actions.environment[idx] = 'field'
          general_actions.hotbar[idx]      = tostring(row)
          general_actions.slot[idx]        = tostring(slot)
          general_actions.type[idx]        = action_type
          general_actions.action[idx]      = action_name
          general_actions.target[idx]      = action_target
          general_actions.alias[idx]       = shorten_ability_name(name)
          general_actions.icon[idx]        = _action_icons[action_type .. '|' .. name:lower()] or ''
          advance()
        end
      end
    end
  end
end

local GEO_LUOPAN_ABILITY_NAMES = {
  ['Full Circle']      = true, ['Lasting Emanation'] = true,
  ['Ecliptic Attrition']=true, ['Life Cycle']        = true,
  ['Blaze of Glory']   = true, ['Dematerialize']     = true,
  ['Concentric Pulse'] = true, ['Mending Halation']  = true,
  ['Radial Arcana']    = true, ['Widened Compass']   = true,
}

local DRG_WYVERN_ABILITY_NAMES = {
  ['Spirit Link']  = true,
  ['Spirit Bond']  = true,
  ['Spirit Surge'] = true,
  ['Dismiss']      = true,
}

function action_req_check(action_array)
  if action_array == nil or action_array[1] == nil or action_array[2] == nil or action_array[3] == nil then return false end
  local action_type = tostring(action_array[2]):lower()
  local action_name = action_array[3]
  local slot = action_array[1]

  if action_type == 'ma' then
    if not meets_spell_level_req(action_name) then
      return false
    end

    if is_spell_learned(action_name) then
      if _G.is_blu_spell_set ~= nil and _req_check_player ~= nil then
        local spell_id = en_to_spell_id[action_name]
        local spell = spell_id and resources.spells[spell_id]
        if spell and not _G.is_blu_spell_set(spell, _req_check_player) then
          return false
        end
      end
      return true
    else
      if _slot_first_learned and _slot_first_learned[slot] then
        return false
      else
        return true
      end
    end
  elseif action_type == 'ja' then
    if not meets_ability_level_req(action_name) then
      return false
    end

    return is_job_ability_learned(action_name)
  elseif action_type == 'bstpet' then
    return is_pet_ability_usable(action_name)
  elseif action_type == 'ws' then
    if not meets_weaponskill_level_req(action_name) then
      return false
    end

    return is_weaponskill_learned(action_name)
  elseif action_type == 'ct' or action_type == 'pet' or action_type == 'input' or action_type == 'key' or action_type == 'macro' or action_type == 'gs' or action_type == 'autoitem' or action_type == 'choice' or action_type == 'autora' then
    return true
  else
    return false
  end
end

function meets_spell_level_req(spell_name_en)
  if not spell_name_en then return false end

  local windower_player = _req_check_player or windower.ffxi.get_player()
  if windower_player == nil then return false end

  local spell_id = en_to_spell_id[spell_name_en]
  if not spell_id then
    return true
  end

  local spell_data = resources.spells[spell_id]
  if not spell_data then
    return true
  end

  local main_job_id = windower_player.main_job_id
  local main_job_level = windower_player.main_job_level
  local main_job_spell_level = spell_data.levels[main_job_id]

  if not main_job_spell_level then
    local sub_job_id = windower_player.sub_job_id
    local sub_job_level = effective_subjob_level(windower_player.main_job_level, windower_player.sub_job_level)

    if not sub_job_id or not sub_job_level then
      return false
    end

    local sub_job_spell_level = spell_data.levels[sub_job_id]
    if not sub_job_spell_level then
      return false
    end

    return sub_job_level >= sub_job_spell_level
  else
    if main_job_level >= main_job_spell_level then return true end
    if main_job_spell_level > 99 and is_spell_learned(spell_name_en) then return true end
    return false
  end
end

function meets_ability_level_req(ability_name_en)
  if not ability_name_en then return false end

  local windower_player = _req_check_player or windower.ffxi.get_player()
  if windower_player == nil then return false end

  local ability_id = en_to_ability_id[ability_name_en]
  if not ability_id then
    return true
  end

  local ability_data = ability_level_list[ability_id]
  if not ability_data or type(ability_data.levels) ~= 'table' then
    local ab = ability_list[ability_id]
    local ab_type = ab and tostring(ab.type or '') or ''
    if ab_type == 'BloodPactRage' or ab_type == 'BloodPactWard' then
      return true
    end
    if ab_type == 'Monster' and ab and tostring(ab.prefix or '') == '/pet' then
      return true
    end
    if ab_type == 'CorsairShot' then
      return true
    end
    return false
  end

  local main_job_id = windower_player.main_job_id
  local main_job_level = windower_player.main_job_level
  local main_job_ability_level = ability_data.levels[main_job_id]

  if not main_job_ability_level then
    local sub_job_id = windower_player.sub_job_id
    local sub_job_level = effective_subjob_level(windower_player.main_job_level, windower_player.sub_job_level)

    if not sub_job_id or not sub_job_level then
      return false
    end

    local sub_job_ability_level = ability_data.levels[sub_job_id]
    if not sub_job_ability_level then
      return false
    end

    return sub_job_level >= sub_job_ability_level
  else
    if main_job_level >= main_job_ability_level then return true end
    if main_job_ability_level > 99 and learned_abilities_id[ability_id] == true then return true end
    return false
  end
end

local underscored_to_known_skill_map = {
  hand_to_hand = "Hand-to-Hand",
  dagger = "Dagger",
  sword = "Sword",
  great_sword = "Great Sword",
  axe = "Axe",
  great_axe = "Great Axe",
  scythe = "Scythe",
  polearm = "Polearm",
  katana = "Katana",
  great_katana = "Great Katana",
  club = "Club",
  staff = "Staff",
  automaton_melee = "Automaton Melee",
  automaton_archery = "Automaton Archery",
  automaton_magic = "Automaton Magic",
  archery = "Archery",
  marksmanship = "Marksmanship",
  throwing = "Throwing",
  guard = "Guard",
  evasion = "Evasion",
  shield = "Shield",
  parrying = "Parrying",
}

function meets_weaponskill_level_req(weaponskill_name_en)
  if not weaponskill_name_en then return false end
  local weaponskill_id = en_to_weaponskill_id[weaponskill_name_en]

  local windower_player = _req_check_player or windower.ffxi.get_player()
  if windower_player == nil then return false end
  local skills = windower_player.skills
  if type(skills) ~= 'table' then
    local wp = windower.ffxi.get_player()
    skills = (wp and wp.skills) or {}
  end
  local main_job_level = windower_player.main_job_level

  local skill_data = weaponskill_level_list[weaponskill_id]
  if not skill_data then
    return true
  end

  local min_level = skill_data.min_level
  local min_skill = skill_data.min_skill

  if min_level and main_job_level < min_level then
    return false
  end

  local skill_name = nil
  for underscored_name, readable_name in pairs(underscored_to_known_skill_map) do
    if resources.skills[skill_data.skill] and readable_name == resources.skills[skill_data.skill].en then
      skill_name = underscored_name
      break
    end
  end

  if not skill_name then
    return false
  end

  local player_skill = skills[skill_name] or 0

  if min_skill and player_skill < min_skill then
    if not (weaponskill_id and learned_ws_id[weaponskill_id] == true) then
      return false
    end
  end

  return true
end

function is_spell_learned(spell_name_en)
  return learned_spells_name[spell_name_en] == true
end

function is_spell_usable(spell_name_en, player)
  local spell_id = en_to_spell_id[spell_name_en]
  if not spell_id then
    return true
  end

  local spell = resources.spells[spell_id]
  if not spell then
    return true
  end

  local usable_by_job = is_spell_usable_by_a_job(spell, player)
  local usable_by_blu = is_blu_spell_set(spell, player)

  return usable_by_job and usable_by_blu
end

function is_blu_spell_set(spell, player)
  local spell_id = tonumber(spell['id'])

  if SCH_TR_SPELL_IDS[spell_id] then
    return player and player.has_tabula_rasa == true
  end

  if spell['type'] ~= 'BlueMagic' then return true end

  if BLU_UNBRIDLED_SPELL_IDS[spell_id] then
    if player and player.buffs then
      for _, buff_id in ipairs(player.buffs) do
        buff_id = tonumber(buff_id)
        if buff_id == 485 or buff_id == 505 then
          return true
        end
      end
    end
    return false
  end

  if player.set_blue_magic == nil then
    return true
  end
  for _, v in pairs(player.set_blue_magic) do
    if v == spell_id then return true end
  end
  return false
end

function is_spell_usable_by_a_job(spell, player)
  local main_job_id = player.main_job_id
  local main_job_level = player.main_job_level
  local sub_job_id = player.sub_job_id
  local sub_job_level = effective_subjob_level(player.main_job_level, player.sub_job_level)

  local function can_cast(job_id, job_level)
    local spell_level = spell['levels'][job_id]
    local post99_learned = spell_level ~= nil and spell_level > 99 and job_level >= 99 and is_spell_learned(spell['en'])
    if spell_level and (job_level >= spell_level or post99_learned) then
      if job_id ~= 20 then
        return true
      else
        if player and player.has_tabula_rasa == true then
          return true
        end
        local req = spell['requirements'] or 0
        local needs_addendum    = (req % 8) >= 4
        local needs_tabula_rasa = math.floor(req / 8) % 2 == 1
        if needs_tabula_rasa then
          return false
        elseif needs_addendum then
          if player and player.has_enlightenment == true then
            return true
          end
          if current_stance == 234 and spell['type'] == 'WhiteMagic' then
            return true
          end
          if current_stance == 235 and spell['type'] == 'BlackMagic' then
            return true
          end
        else
          return true
        end
      end
    end
    return false
  end

  return can_cast(main_job_id, main_job_level) or can_cast(sub_job_id, sub_job_level)
end

function is_job_ability_learned(ability_name_en)
  local ability_id = en_to_ability_id[ability_name_en]
  if not ability_id then
    return true
  end
  if learned_abilities_id[ability_id] == true then
    return true
  end
  if MERIT_ABILITY_IDS[ability_id] then
    return false
  end
  if next(learned_abilities_id) ~= nil then
    return false
  end
  return meets_ability_level_req(ability_name_en) == true
end

local function get_ammo_slot_info()
  local eq = windower.ffxi.get_items()
  if not eq or not eq.equipment then return nil end
  local ammo_bag = eq.equipment.ammo_bag
  local ammo_slot = eq.equipment.ammo
  if not ammo_bag or not ammo_slot then return nil end
  if ammo_bag == 0 and ammo_slot == 0 then return nil end
  local item = windower.ffxi.get_items(ammo_bag, ammo_slot)
  if not item or not item.id or item.id == 0 then return nil end
  return item
end

local cor_card_by_ability_id = {
  [125]='Fire Card', [126]='Ice Card', [127]='Wind Card', [128]='Earth Card',
  [129]='Thunder Card', [130]='Water Card', [131]='Light Card', [132]='Dark Card',
}
local cor_cards_all = {'Fire Card','Ice Card','Wind Card','Earth Card','Thunder Card','Water Card','Light Card','Dark Card'}
local GEO_LUOPAN_IDS = {
  [345]=true, [346]=true, [347]=true, [349]=true, [350]=true,
  [351]=true, [353]=true, [354]=true, [355]=true, [377]=true,
}

local JUG_ONLY_ABILITIES = { Snarl = true, ['Run Wild'] = true }
local TWOHANDER_WEAPON_TYPES = { [4]=true, [6]=true, [7]=true, [8]=true, [10]=true, [12]=true }

function is_job_ability_usable(ability_name_en, player)
  if meets_ability_level_req(ability_name_en) ~= true then
    return false
  end

  if DRG_WYVERN_ABILITY_NAMES[ability_name_en] then
    if not _req_check_player or not _req_check_player.pet_name or _req_check_player.pet_name == '' then
      return false
    end
  end
  if GEO_LUOPAN_ABILITY_NAMES[ability_name_en] then
    if not _req_check_player or not _req_check_player.has_luopan then
      return false
    end
  end

  local key = en_to_ability_id[ability_name_en]
  if key == nil then return true end
  local ab = ability_list[key]
  if ab == nil then return true end

  local current_tp = (player and player.vitals and player.vitals.tp) or 0
  local ab_id = ab['id']
  local ab_type = ab['type']

  local tp_cost = ab['tp_cost'] or ab['tpcost'] or 0
  if player ~= nil and player.has_trance == true and
      (ab_type == 'Samba' or ab_type == 'Step' or ab_type == 'Waltz') then
    tp_cost = 0
  end
  if tp_cost > 0 and current_tp < tp_cost then
    return false
  end

  if ab_id == 61 and player ~= nil and player.has_spirit_surge == true then
    return false
  end

  if ab_id == 209 or ab_id == 313 then
    if player == nil or player:get_finishing_moves() < 2 then return false end
  elseif ab_id == 314 then
    if player == nil or player:get_finishing_moves() < 3 then return false end
  elseif ab_type == 'Flourish1' or ab_type == 'Flourish2' or ab_type == 'Flourish3' then
    if player == nil or player:get_finishing_moves() < 1 then return false end
  end

  if ab_id == 46 or ab_id == 278 or ab_id == 329 then
    if player == nil or player.has_shield ~= true then return false end
  end

  if ab_id >= 141 and ab_id <= 148 then
    if player == nil or player.has_animator ~= true then return false end
  end

  if ab_id == 170 then
    if player == nil or player.has_angon ~= true then return false end
  end

  if ab_id == 29 or ab_id == 80 or ab_id == 393 then
    if not _req_check_player or not _req_check_player.pet_name or _req_check_player.pet_name == '' then
      return false
    end
  end

  if ab_id == 168 then
    if player == nil or not TWOHANDER_WEAPON_TYPES[tonumber(player.current_weapon or 0)] then
      return false
    end
  end

  if ab_id == 150 then
    local ammo = get_ammo_slot_info()
    if not ammo or ammo.id ~= 18258 then return false end
  end

  if ab_id == 78 then
    if not _req_check_player or not _req_check_player.pet_name or _req_check_player.pet_name == '' then
      return false
    end
    local ammo = get_ammo_slot_info()
    if not ammo or ammo.id < 17016 or ammo.id > 17023 then return false end
  end

  if ab_id == 24 then
    if not _req_check_player or not _req_check_player.pet_name or _req_check_player.pet_name == '' then
      return false
    end
  end

  if ab_id == 30 or ab_id == 232 or ab_id == 296 then
    if not _req_check_player or not _req_check_player.pet_name or _req_check_player.pet_name == '' then
      return false
    end
  end

  if ab_id == 26 or ab_id == 57 then
    if not (_req_check_player and _req_check_player.current_range_weapon
        and _req_check_player.current_range_weapon ~= 0) then return false end
    if not get_ammo_slot_info() then return false end
  end

  if ab_id == 257 then
    if not (_req_check_player and _req_check_player.current_range_weapon
        and _req_check_player.current_range_weapon ~= 0) then return false end
    local ammo = get_ammo_slot_info()
    if not ammo or (ammo.count or 1) < 2 then return false end
  end

  if ab_id == 301 then
    local ammo = get_ammo_slot_info()
    if not ammo or (ammo.count or 1) < 3 then return false end
  end

  if ab_id == 124 then
    local ammo = get_ammo_slot_info()
    if not ammo then return false end
    local has_card = false
    if player and player.item_count then
      for _, cn in ipairs(cor_cards_all) do
        if (player.item_count[cn] or 0) >= 1 then has_card = true; break end
      end
    end
    if not has_card then return false end
  end

  local cor_card = cor_card_by_ability_id[ab_id]
  if cor_card then
    local ammo = get_ammo_slot_info()
    if not ammo then return false end
    if not player or not player.item_count or (player.item_count[cor_card] or 0) < 1 then
      return false
    end
  end

  if GEO_LUOPAN_IDS[ab_id] then
    if player == nil or player.has_luopan ~= true then return false end
  end

  if ab_id == 171 then
    local ammo = get_ammo_slot_info()
    if not ammo then return false end
    local ammo_res = resources and resources.items and resources.items[ammo.id]
    if not ammo_res or (ammo_res.skill or 0) ~= 27 then return false end
  end

  if ab_type == 'PetCommand' then
    local pet = windower.ffxi.get_mob_by_target('pet')
    if not pet or not pet.name or pet.name == '' then return false end
    if JUG_ONLY_ABILITIES[ab['en']] then
      if player == nil or player.has_jug_pet ~= true then return false end
    end
  end

  return true
end

function is_pet_ability_usable(ability_index)
  local ndx = tonumber(ability_index)
  if ndx ~= nil and ndx >= 1 and ndx <= #usable_pet_abilities_name then
    return true
  end
  return false
end

function is_weaponskill_learned(ws_name_en)
  local ws_key = en_to_weaponskill_id[ws_name_en]
  if ws_key == nil then return false end
  return learned_ws_id[ws_key] == true
end

local function parse_binds(theme_options, player, job_root)
  learned_abilities_id = {}
  learned_spells_name = {}
  learned_ws_id = {}
  missing_actions = {}
  usable_pet_abilities_name = {}
  not_learned_spells_row_slot = {}

  if theme_options.playing_on_horizon == true then
    spells = horizon_spell_list
    local known_spells = windower.ffxi.get_spells() or {}
    for key, val in pairs(horizon_spell_list) do
      if known_spells[spells[key]['id']] == true then
        learned_spells_name[spells[key]['en']] = true
      end
    end
  elseif theme_options.playing_on_horizon == false then
    spells = spell_list
    local known_spells = windower.ffxi.get_spells() or {}
    for key, val in pairs(spell_list) do
      if known_spells[spells[key]['id']] == true then
        learned_spells_name[spells[key]['en']] = true
      end
    end
  end

  abilities = ability_list
  pet_abilities = ability_list
  weaponskills = ws_list
  local windower_abilities = windower.ffxi.get_abilities() or { job_abilities = {}, weapon_skills = {} }

  for _, val in pairs(windower_abilities.job_abilities or {}) do
    local ab = ability_list[val]
    if ab then
      learned_abilities_id[ab.id] = true
      if ab.prefix == '/pet' and ab.type ~= 'PetCommand' then
        table.insert(usable_pet_abilities_name, ab.en)
      end
    end
  end

  for _, val in pairs(windower_abilities.weapon_skills or {}) do
    if weaponskills[val] then
      learned_ws_id[val] = true
    end
  end

  if job_root['Base'] ~= nil then
    _slot_first_learned = pre_process_spell_tiers(job_root['Base'])
    for key, val in ipairs(job_root['Base']) do
    if action_req_check(job_root['Base'][key]) == true then
      fill_action_table(job_root['Base'][key], key, mainjob_actions)
      reindex_action_table(mainjob_actions)
    end
    end
  end

  if (job_root[player.sub_job] ~= nil) then
    _slot_first_learned = pre_process_spell_tiers(job_root[player.sub_job])
    for key, val in ipairs(job_root[player.sub_job]) do
      if action_req_check(job_root[player.sub_job][key]) == true then
        fill_action_table(job_root[player.sub_job][key], key, subjob_actions)
        reindex_action_table(subjob_actions)
      end
    end
  else
    init_action_table(subjob_actions)
  end

  if player.main_job == 'SMN' and player.pet_name ~= nil and player.pet_name ~= '' then
    if (job_root['Avatar'] ~= nil) then
      _slot_first_learned = pre_process_spell_tiers(job_root['Avatar'])
      for key, val in ipairs(job_root['Avatar']) do
        if action_req_check(job_root['Avatar'][key]) == true then
          fill_action_table(job_root['Avatar'][key], key, petname_actions)
          reindex_action_table(petname_actions)
        end
      end
    end
  end

  if (job_root[player.pet_name] ~= nil) then
    _slot_first_learned = pre_process_spell_tiers(job_root[player.pet_name])
    local key_offset = petname_actions.environment and #petname_actions.environment or 0
    for key, val in ipairs(job_root[player.pet_name]) do
      if action_req_check(job_root[player.pet_name][key]) == true then
        fill_action_table(job_root[player.pet_name][key], key + key_offset, petname_actions)
        reindex_action_table(petname_actions)
      end
    end
  else
    init_action_table(petname_actions)
  end

  if player.main_job == 'DRG' and player.pet_name ~= nil and player.pet_name ~= '' then
    if job_root['Wyvern'] ~= nil then
      _slot_first_learned = pre_process_spell_tiers(job_root['Wyvern'])
      for key, val in ipairs(job_root['Wyvern']) do
        if action_req_check(job_root['Wyvern'][key]) == true then
          fill_action_table(job_root['Wyvern'][key], key, petname_actions)
          reindex_action_table(petname_actions)
        end
      end
    end
  end

  if player.main_job == 'PUP' and player.pet_name ~= nil and player.pet_name ~= '' then
    if job_root['Automaton'] ~= nil then
      _slot_first_learned = pre_process_spell_tiers(job_root['Automaton'])
      for key, val in ipairs(job_root['Automaton']) do
        if action_req_check(job_root['Automaton'][key]) == true then
          fill_action_table(job_root['Automaton'][key], key, petname_actions)
          reindex_action_table(petname_actions)
        end
      end
    end
  end

  if player.main_job == 'BST' and player.pet_name ~= nil and player.pet_name ~= '' then
    player.has_jug_pet = (#usable_pet_abilities_name > 0)

    local BST_JUG_ONLY_KEYS  = { ['choice|bst_ready'] = true, ['ja|snarl'] = true, ['ja|run wild'] = true }
    local BST_CHARM_ONLY_KEYS = { ['ja|sic'] = true }
    local BST_BASE_ONLY_KEYS  = { ['ja|tame'] = true }
    if job_root['Beast'] ~= nil then
      _slot_first_learned = pre_process_spell_tiers(job_root['Beast'])
      local per_bar = {}
      local bar_seq = {}
      for _, entry in ipairs(job_root['Beast']) do
        local ekey = tostring(entry[2] or ''):lower() .. '|' .. tostring(entry[3] or ''):lower()
        local skip_jug_only   = BST_JUG_ONLY_KEYS[ekey]  and not player.has_jug_pet
        local skip_charm_only = BST_CHARM_ONLY_KEYS[ekey] and player.has_jug_pet
        local skip_base_only  = BST_BASE_ONLY_KEYS[ekey]
        if not skip_jug_only and not skip_charm_only and not skip_base_only and action_req_check(entry) == true then
          local env, bar = tostring(entry[1]):match('^(%S+)%s+(%S+)')
          env = env or 'battle'
          bar = bar or '1'
          local bk = env .. '\0' .. bar
          if per_bar[bk] == nil then
            per_bar[bk] = { env = env, bar = bar, items = {} }
            table.insert(bar_seq, bk)
          end
          table.insert(per_bar[bk].items, entry)
        end
      end
      local fill_key = 1
      for _, bk in ipairs(bar_seq) do
        local g = per_bar[bk]
        for sn, entry in ipairs(g.items) do
          local adj = { g.env .. ' ' .. g.bar .. ' ' .. sn, entry[2], entry[3], entry[4], entry[5], entry[6] }
          fill_action_table(adj, fill_key, petname_actions)
          reindex_action_table(petname_actions)
          fill_key = fill_key + 1
        end
      end
    end
  end

  local stances = {}
  table.insert(stances, current_stance)

  if (current_stance == 234) then
    table.insert(stances, 211)
  elseif (current_stance == 235) then
    table.insert(stances, 212)
  end

  local stance_ndx = 1
  for k, s in ipairs(stances) do
    if (job_root[buff_table[s]] ~= nil) then
      local stance_table = job_root[buff_table[s]]
      _slot_first_learned = pre_process_spell_tiers(stance_table)
      for key, val in ipairs(stance_table) do
        if action_req_check(stance_table[key]) == true then
          fill_action_table(stance_table[key], stance_ndx, stance_actions)
          stance_ndx = stance_ndx + 1
        end
      end
    end
  end

  local weapons = {}
  local function append_weapon(skill_type)
    if skill_type ~= nil and skill_type ~= 0 then
      table.insert(weapons, skill_type)
    end
  end

  local priority = tostring(theme_options.weapon_skill_priority or 'auto'):lower()
  if priority == 'range' or priority == 'ranged' then
    append_weapon(player.current_weapon)
    append_weapon(player.current_range_weapon)
  elseif priority == 'main' or priority == 'melee' then
    append_weapon(player.current_range_weapon)
    append_weapon(player.current_weapon)
  else
    local main_job = tostring(player.main_job or ''):upper()
    local prefers_range = (main_job == 'RNG' or main_job == 'COR')
    if prefers_range then
      append_weapon(player.current_weapon)
      append_weapon(player.current_range_weapon)
    else
      append_weapon(player.current_range_weapon)
      append_weapon(player.current_weapon)
    end
  end

  if (theme_options.enable_weapon_switching == true) then
    local weaponskill_ndx = 1
    for k, w in ipairs(weapons) do
      if (weaponskill_types[w] ~= nil) then
        if (job_root[weaponskill_types[w]] ~= nil) then
          _slot_first_learned = pre_process_spell_tiers(job_root[weaponskill_types[w]])
          for key, val in ipairs(job_root[weaponskill_types[w]]) do
            if action_req_check(job_root[weaponskill_types[w]][key]) == true then
              fill_action_table(job_root[weaponskill_types[w]][key], weaponskill_ndx, weaponskill_actions)
              weaponskill_ndx = weaponskill_ndx + 1
            end
          end
        end
      end
    end
  end

  local PET_ANCHOR = {
    SMN = { atype = 'choice', action = 'smn_avatars' },
    DRG = { atype = 'ja',     action = 'call wyvern' },
    PUP = { atype = 'ja',     action = 'activate' },
  }
  local main_job_upper = tostring(player.main_job or ''):upper()
  local anchor_cfg = PET_ANCHOR[main_job_upper]
  if anchor_cfg and player.pet_name ~= nil and player.pet_name ~= ''
      and petname_actions.environment ~= nil then
    local av_env, av_row, av_slot
    for k, _ in ipairs(mainjob_actions.environment) do
      if tostring(mainjob_actions.type[k] or ''):lower() == anchor_cfg.atype
          and tostring(mainjob_actions.action[k] or ''):lower() == anchor_cfg.action then
        av_env  = tostring(mainjob_actions.environment[k] or '')
        av_row  = tonumber(mainjob_actions.hotbar[k])
        av_slot = tonumber(mainjob_actions.slot[k])
        break
      end
    end

    if av_env and av_row and av_slot then
      local pet_keys = {}
      for k, _ in ipairs(petname_actions.environment) do
        if tostring(petname_actions.environment[k] or '') == av_env
            and tonumber(petname_actions.hotbar[k]) == av_row then
          table.insert(pet_keys, { k = k, slot = tonumber(petname_actions.slot[k]) or 0 })
        end
      end
      table.sort(pet_keys, function(a, b) return a.slot < b.slot end)

      local pet_count = #pet_keys
      if pet_count > 0 then
        for i, entry in ipairs(pet_keys) do
          petname_actions.slot[entry.k] = tostring(av_slot + i)
        end
        for k, _ in ipairs(mainjob_actions.environment) do
          if tostring(mainjob_actions.environment[k] or '') == av_env
              and tonumber(mainjob_actions.hotbar[k]) == av_row then
            local s = tonumber(mainjob_actions.slot[k]) or 0
            if s > av_slot then
              mainjob_actions.slot[k] = tostring(s + pet_count)
            end
          end
        end
      end
    end
  end

  if main_job_upper == 'BLU' and stance_actions.environment ~= nil then
    local blu_unbridled_active = false
    for _, b in ipairs(player.buffs or {}) do
      if b == 485 or b == 505 then blu_unbridled_active = true; break end
    end

    if blu_unbridled_active then
      local unb_by_bar = {}
      for k, _ in ipairs(stance_actions.environment) do
        local env = tostring(stance_actions.environment[k] or '')
        local bar = tonumber(stance_actions.hotbar[k])
        if env ~= '' and bar then
          local sid = en_to_spell_id[tostring(stance_actions.action[k] or '')]
          if sid and BLU_UNBRIDLED_SPELL_IDS[sid] then
            unb_by_bar[env] = unb_by_bar[env] or {}
            unb_by_bar[env][bar] = unb_by_bar[env][bar] or {}
            table.insert(unb_by_bar[env][bar], {k = k, slot = tonumber(stance_actions.slot[k]) or 0})
          end
        end
      end

      for env, bars in pairs(unb_by_bar) do
        for bar, unb_list in pairs(bars) do
          table.sort(unb_list, function(a, b) return a.slot < b.slot end)
          local unb_count = #unb_list
          for k, _ in ipairs(mainjob_actions.environment) do
            if tostring(mainjob_actions.environment[k] or '') == env
                and tonumber(mainjob_actions.hotbar[k]) == bar
                and tostring(mainjob_actions.type[k] or ''):lower() == 'ma' then
              local s = tonumber(mainjob_actions.slot[k]) or 0
              mainjob_actions.slot[k] = tostring(s + unb_count)
            end
          end
          for i, entry in ipairs(unb_list) do
            stance_actions.slot[entry.k] = tostring(i)
          end
        end
      end
    end
  end

  if main_job_upper == 'SCH' and player.has_tabula_rasa then
    local tr_by_bar = {}
    for k, _ in ipairs(mainjob_actions.environment) do
      if tostring(mainjob_actions.type[k] or ''):lower() == 'ma' then
        local env = tostring(mainjob_actions.environment[k] or '')
        local bar = tonumber(mainjob_actions.hotbar[k])
        if env ~= '' and bar then
          local sid = en_to_spell_id[tostring(mainjob_actions.action[k] or '')]
          if sid and SCH_TR_SPELL_IDS[sid] then
            tr_by_bar[env] = tr_by_bar[env] or {}
            tr_by_bar[env][bar] = tr_by_bar[env][bar] or {}
            table.insert(tr_by_bar[env][bar], {k = k, slot = tonumber(mainjob_actions.slot[k]) or 0})
          end
        end
      end
    end

    for env, bars in pairs(tr_by_bar) do
      for bar, tr_list in pairs(bars) do
        table.sort(tr_list, function(a, b) return a.slot < b.slot end)
        local tr_count = #tr_list
        for k, _ in ipairs(mainjob_actions.environment) do
          if tostring(mainjob_actions.environment[k] or '') == env
              and tonumber(mainjob_actions.hotbar[k]) == bar
              and tostring(mainjob_actions.type[k] or ''):lower() == 'ma' then
            local sid = en_to_spell_id[tostring(mainjob_actions.action[k] or '')]
            if not (sid and SCH_TR_SPELL_IDS[sid]) then
              local s = tonumber(mainjob_actions.slot[k]) or 0
              mainjob_actions.slot[k] = tostring(s + tr_count)
            end
          end
        end
        for i, entry in ipairs(tr_list) do
          mainjob_actions.slot[entry.k] = tostring(i)
        end
      end
    end
  end
end

function action_manager:initialize(theme_options)
  self.theme_options       = theme_options
  self.hotbar_settings.max = theme_options.hotbar_number
  self.hotbar_rows         = theme_options.rows
end

function action_manager:reset_hotbar()
  self.hotbar = {
    ['battle'] = {},
    ['field'] = {}
  }

  for h = 1, self.hotbar_settings.max, 1 do
    self.hotbar.field['hotbar_' .. h] = {}
    self.hotbar.battle['hotbar_' .. h] = {}
  end

  self.hotbar_settings.active_hotbar = 1
  self.hotbar_page_state = self.hotbar_page_state or { battle = {}, field = {} }
  self.hotbar_page_state.battle = self.hotbar_page_state.battle or {}
  self.hotbar_page_state.field  = self.hotbar_page_state.field  or {}
  row_page_count_cache = {}
end

function action_manager:build_custom(action, alias, icon)
  return self:build(CUSTOM_TYPE, action, nil, alias, icon)
end

local function collect_file_write_actions(action)
  local writes = {}
  if action == nil then return writes end

  table.insert(writes, copy_action_payload(action))
  return writes
end

local function write_action_move_list(actions, d_row, d_slot, s_row, s_slot, file_env)
  if actions == nil then return end
  for _, entry in ipairs(actions) do
    if entry ~= nil and entry.action ~= nil then
      file_manager:write_changes(entry, d_row, d_slot, s_row, s_slot, file_env)
    end
  end
end

function action_manager:swap_actions(player, swap_table)
  local s_row  = swap_table.source.row
  local d_row  = swap_table.dest.row
  local env = self.hotbar_settings.active_environment
  local file_env = env == 'battle' and 'b' or 'f'
  local s_slot = tonumber(swap_table.source.actual_slot) or self:get_visible_slot_index(s_row, swap_table.source.slot, env)
  local d_slot = tonumber(swap_table.dest.actual_slot) or self:get_visible_slot_index(d_row, swap_table.dest.slot, env)
  local env_table = self.hotbar[env]

  local function to_file_slot(row, slot) return self:visible_to_file_slot(row, slot, env) end

  if env_table and env_table['hotbar_' .. s_row] and env_table['hotbar_' .. d_row] then
    local source_before = env_table['hotbar_' .. s_row]['slot_' .. s_slot]
    local dest_before = env_table['hotbar_' .. d_row]['slot_' .. d_slot]

    if source_before ~= nil then
      local source_writes = source_before.is_dynamic and {} or collect_file_write_actions(source_before)
      local dest_writes = (dest_before and dest_before.is_dynamic) and {} or collect_file_write_actions(dest_before)

      local fs_s = source_before._file_slot or to_file_slot(s_row, s_slot)
      local fs_d = (dest_before and dest_before._file_slot) or to_file_slot(d_row, d_slot)

      if dest_before == nil then
        env_table['hotbar_' .. d_row]['slot_' .. d_slot] = copy_action_payload(source_before)
        env_table['hotbar_' .. s_row]['slot_' .. s_slot] = nil

        write_action_move_list(source_writes, d_row, fs_d, s_row, fs_s, file_env)
      else
        env_table['hotbar_' .. s_row]['slot_' .. s_slot] = copy_action_payload(dest_before)
        env_table['hotbar_' .. d_row]['slot_' .. d_slot] = copy_action_payload(source_before)

        write_action_move_list(dest_writes, s_row, fs_s, d_row, fs_d, file_env)
        write_action_move_list(source_writes, d_row, fs_d, s_row, fs_s, file_env)
      end
    else
      print("XIVHOTBAR2: Cannot swap icons if the dragged icon is empty!")
    end
  end
end

function action_manager:remove_action(player, remove_table)
  local row = remove_table.source.row
  local env = self.hotbar_settings.active_environment
  local file_env = env == 'battle' and 'b' or 'f'
  local slot = tonumber(remove_table.source.actual_slot) or self:get_visible_slot_index(row, remove_table.source.slot, env)
  local row_table = self.hotbar[env] and self.hotbar[env]['hotbar_' .. row]

  if row_table and row_table['slot_' .. slot] ~= nil then
    local action = row_table['slot_' .. slot]
    if not action.is_dynamic then
      local file_slot = action._file_slot or self:visible_to_file_slot(row, slot, env)
      local writes = collect_file_write_actions(action)
      for _, entry in ipairs(writes) do
        file_manager:write_remove(entry, row, file_slot, file_env)
      end
    end
    row_table['slot_' .. slot] = nil
  end
end

function action_manager:insert_action(player_subjob, args)
  if not args[6] then
    print(
      'XIVHOTBAR2: Invalid arguments: set <mode> <hotbar> <slot> <action_type> <action> <target (optional)> <alias (optional)> <icon (optional)>')
    return
  end
  local prio = args[1]:lower()
  local row = tonumber(args[2]) or 0
  local slot = tonumber(args[3]) or 0
  local action_type = args[4]:lower()
  local action = args[5]
  local target = args[6] or nil
  local alias = args[7] or nil
  local icon = args[8] or nil
  if target ~= nil then target = target:lower() end
  local environment_to_send = function()
    if self.hotbar_settings.active_environment == 'field' then return 'field' else return 'battle' end
  end

  local new_action = action_manager:build(action_type, action, target, alias, icon)

  file_manager:insert_action(new_action, prio, player_subjob, environment_to_send(), row, slot)
end

function action_manager:update_file_path(player_name, player_job)
  file_manager:update_file_path(player_name, player_job)
end

function action_manager:get_job_sections()
  return last_job_root or {}
end

function action_manager:req_check_reason(entry)
  if type(entry) ~= 'table' or not entry[1] or not entry[2] or not entry[3] then return 'malformed entry' end
  if action_req_check(entry) == true then return nil end
  local t = tostring(entry[2] or '?'):lower()
  local name = entry[3]
  if t == 'ja' then
    if not meets_ability_level_req(name) then return 'job/level requirement not met' end
    return 'ability not learned'
  elseif t == 'ws' then
    if not meets_weaponskill_level_req(name) then return 'weapon skill level requirement not met' end
    return 'weapon skill not learned'
  elseif t == 'ma' then
    if not meets_spell_level_req(name) then return 'job/level requirement not met' end
    return 'spell not learned'
  elseif t == 'bstpet' then
    return 'pet ability not usable now'
  end
  return 'unsupported type "' .. t .. '"'
end

function action_manager:report_req_checks()
  local root = last_job_root or {}
  local keys = {}
  for k, v in pairs(root) do
    if type(k) == 'string' and type(v) == 'table' and #v > 0 then keys[#keys + 1] = k end
  end
  table.sort(keys)
  local hidden, total = 0, 0
  for _, k in ipairs(keys) do
    for _, entry in ipairs(root[k]) do
      if type(entry) == 'table' and entry[1] then
        total = total + 1
        local reason = self:req_check_reason(entry)
        if reason then
          hidden = hidden + 1
          windower.add_to_chat(8, string.format('  HIDDEN [%s] %s %s "%s": %s',
            k, tostring(entry[1]), tostring(entry[2]), tostring(entry[3]), reason))
        end
      end
    end
  end
  windower.add_to_chat(8, string.format(
    'XIVHOTBAR2 whyhidden: %d of %d job-file entries hidden by live checks (the rest are loadable).',
    hidden, total))
end

function action_manager:get_general_list()
  return rawget(_general_fileG, 'xivhotbar_general_list')
end

function action_manager:add_actions(action_table)
  for key, _ in ipairs(action_table.environment) do
    add_action(self,
      action_manager:build(
        action_table.type[key],
        action_table.action[key],
        action_table.target[key],
        action_table.alias[key],
        action_table.icon[key]
      ),
      action_table.environment[key],
      action_table.hotbar[key],
      action_table.slot[key]
    )
  end
end

function action_manager:toggle_environment()
  if self.hotbar_settings.active_environment == 'battle' then
    self.hotbar_settings.active_environment = 'field'
  else
    self.hotbar_settings.active_environment = 'battle'
  end
end

function action_manager:get_row_page_count(env, row)
  return get_row_page_count_internal(self, env or self.hotbar_settings.active_environment, row)
end

function action_manager:get_hotbar_page(env, row)
  return clamp_row_page(self, env or self.hotbar_settings.active_environment, row)
end

function action_manager:set_hotbar_page(env, row, page)
  env = env or self.hotbar_settings.active_environment
  if env == 'b' then env = 'battle' elseif env == 'f' then env = 'field' end
  row = tonumber(row)
  page = tonumber(page) or 1
  if env == nil or row == nil then return 1, 1 end
  self.hotbar_page_state[env] = self.hotbar_page_state[env] or {}
  local page_count = self:get_row_page_count(env, row)
  if page < 1 then page = 1 end
  if page > page_count then page = page_count end
  self.hotbar_page_state[env][row] = page
  return page, page_count
end

function action_manager:change_hotbar_page(env, row, delta)
  env = env or self.hotbar_settings.active_environment
  row = tonumber(row)
  if env == nil or row == nil then return 1, 1 end
  local current = self:get_hotbar_page(env, row)
  return self:set_hotbar_page(env, row, current + (tonumber(delta) or 0))
end

function action_manager:get_visible_slot_index(row, slot, env)
  env = env or self.hotbar_settings.active_environment
  local columns = tonumber(self.theme_options and self.theme_options.columns or 12) or 12
  if columns < 1 then columns = 12 end
  local page = self:get_hotbar_page(env, row)
  return ((page - 1) * columns) + (tonumber(slot) or 0)
end

function action_manager:visible_to_file_slot(row, slot, env)
  return tonumber(slot) or 0
end

function action_manager:get_visible_action(row, slot, env)
  env = env or self.hotbar_settings.active_environment
  local row_table = get_row_table(self, env, row)
  if row_table == nil then return nil end
  local actual_slot = self:get_visible_slot_index(row, slot, env)
  return row_table['slot_' .. tostring(actual_slot)]
end

function action_manager:get_raw_action(slot)
  return self:get_visible_action(self.hotbar_settings.active_hotbar, slot, self.hotbar_settings.active_environment)
end

function action_manager:get_action_choices_for_action(action, player)
  if action == nil then return nil end

  if tostring(action.type or ''):lower() == 'ma' then
    local family_choices = build_spell_family_choices_stateless(action, player)
    if family_choices ~= nil and #family_choices > 1 then
      return family_choices
    end
  end

  if action._shared_actions ~= nil and #action._shared_actions > 1 then
    local choices = mark_and_dedupe_choice_payloads(action._shared_actions, player)
    if choices ~= nil and #choices > 1 then
      return choices
    end
  end

  return nil
end

function action_manager:get_action_choices(slot, player)
  local raw_action = self:get_raw_action(slot)
  return self:get_action_choices_for_action(raw_action, player)
end

function action_manager:clear_resource_resolution_cache()
  clear_resource_resolution_cache()
end

function action_manager:resolve_action_for_resources(action, player)
  if action == nil then return action end

  local action_type = tostring(action.type or ''):lower()
  local action_action_lower = tostring(action.action or ''):lower()

  if action_type == 'autora' then
    return action
  end

  if action_type == 'choice'
      and action_action_lower == 'smn_avatars'
      and player and player.pet_name and player.pet_name ~= '' then
    return { type = 'ja', action = 'Release', target = 'me', alias = 'Release', icon = 'ffxiv/pet/steady' }
  end

  if action_type == 'ja'
      and action_action_lower == 'call wyvern'
      and player and player.main_job == 'DRG'
      and player.pet_name and player.pet_name ~= '' then
    return { type = 'ja', action = 'Dismiss', target = 'me', alias = 'Dismiss', icon = 'ffxiv/pet/steady' }
  end

  if action_type == 'ja'
      and action_action_lower == 'activate'
      and player and player.main_job == 'PUP'
      and player.pet_name and player.pet_name ~= '' then
    return { type = 'ja', action = 'Deactivate', target = 'me', alias = 'Deactvte', icon = 'ffxiv/mch/hot_shot' }
  end

  if action_type == 'ja'
      and action_action_lower == 'call beast'
      and player and player.main_job == 'BST'
      and player.pet_name and player.pet_name ~= '' then
    return nil
  end

  if action_type == 'ja'
      and action_action_lower == 'sic'
      and player and player.main_job == 'BST' then
    local a = copy_action_table(action)
    a.exec_prefix = 'pet'
    a.target = 'me'
    return a
  end

  if action_type == 'ma' then
    ensure_spell_family_shared_actions(action)
  end

  local variants = action._shared_actions
  if variants == nil or #variants == 0 then return action end
  local best = nil
  for _, candidate in ipairs(variants) do
    if action_is_known(candidate)
        and action_meets_current_access(candidate, player)
        and action_is_affordable(candidate, player) then
      best = candidate
    end
  end
  return best or action
end

function action_manager:get_action(slot, player)
  return self:resolve_action_for_resources(self:get_raw_action(slot), player)
end

function action_manager:change_active_hotbar(new_hotbar)
  self.hotbar_settings.active_hotbar = new_hotbar

  if self.hotbar_settings.active_hotbar > self.hotbar_settings.max then
    self.hotbar_settings.active_hotbar = 1
  end
end

local _pinned_rows = {}

local function row_is_pinned(env, row_key)
  local n = tonumber(tostring(row_key):match('hotbar_(%d+)'))
  return n ~= nil and _pinned_rows[env .. '\0' .. n] == true
end

local function compact_blu_magic_rows(am, player)
  local set_blue_magic = player and player.set_blue_magic or nil

  local function spell_in_set(spell_id)
    if set_blue_magic == nil then return true end
    for _, id in pairs(set_blue_magic) do
      if id == spell_id then return true end
    end
    return false
  end

  for _, env in ipairs({'battle', 'field'}) do
    local env_hotbar = am.hotbar[env]
    if env_hotbar then
      for _, row in pairs(env_hotbar) do
        local filled = {}
        local all_blu = true
        for slot_key, action in pairs(row) do
          if slot_key:match('^slot_') then
            local spell_id = action.type == 'ma' and en_to_spell_id[tostring(action.action or '')]
            local spell = spell_id and resources.spells[spell_id]
            if spell and spell.type == 'BlueMagic' and not action._shared_actions then
              if spell_in_set(spell_id) then
                local num = tonumber(slot_key:match('^slot_(%d+)$'))
                table.insert(filled, {num = num, action = action})
              end
            else
              all_blu = false
              break
            end
          end
        end

        if all_blu then
          table.sort(filled, function(a, b) return a.num < b.num end)
          local to_clear = {}
          for slot_key in pairs(row) do
            if slot_key:match('^slot_') then table.insert(to_clear, slot_key) end
          end
          for _, slot_key in ipairs(to_clear) do row[slot_key] = nil end
          for i, entry in ipairs(filled) do row['slot_' .. i] = entry.action end
        end
      end
    end
  end
end

local function compact_inaccessible_magic_rows(am)
  for _, env in ipairs({'battle', 'field'}) do
    local env_hotbar = am.hotbar[env]
    if env_hotbar then
      for row_key, row in pairs(env_hotbar) do
       if not row_is_pinned(env, row_key) then
        local magic_slots    = {}
        local max_nonmagic   = 0
        local has_blu        = false

        for slot_key, action in pairs(row) do
          if slot_key:match('^slot_') then
            local num = tonumber(slot_key:match('^slot_(%d+)$'))
            if num then
              if action.type == 'ma' then
                local spell_id = en_to_spell_id[tostring(action.action or '')]
                local spell    = spell_id and resources.spells[spell_id]
                if spell and spell.type == 'BlueMagic' then
                  has_blu = true
                else
                  table.insert(magic_slots, {num = num, key = slot_key, action = action})
                end
              else
                if num > max_nonmagic then max_nonmagic = num end
              end
            end
          end
        end

        if #magic_slots > 0 and not has_blu then
          table.sort(magic_slots, function(a, b) return a.num < b.num end)

          local has_gaps = false
          for i, e in ipairs(magic_slots) do
            if e.num ~= max_nonmagic + i then
              has_gaps = true
              break
            end
          end

          if has_gaps then
            for _, e in ipairs(magic_slots) do row[e.key] = nil end
            for i, e in ipairs(magic_slots) do
              row['slot_' .. (max_nonmagic + i)] = e.action
            end
          end
        end
       end
      end
    end
  end
end

local function compact_inaccessible_ja_rows(am)
  for _, env in ipairs({'battle', 'field'}) do
    local env_hotbar = am.hotbar[env]
    if env_hotbar then
      for row_key, row in pairs(env_hotbar) do
       if not row_is_pinned(env, row_key) then
        local ja_slots  = {}
        local has_nonja = false

        for slot_key, action in pairs(row) do
          if slot_key:match('^slot_') then
            local num = tonumber(slot_key:match('^slot_(%d+)$'))
            if num then
              if action.type == 'ja' then
                table.insert(ja_slots, {num = num, key = slot_key, action = action})
              else
                has_nonja = true
              end
            end
          end
        end

        if #ja_slots > 1 and not has_nonja then
          table.sort(ja_slots, function(a, b) return a.num < b.num end)

          local has_gaps = false
          for i = 2, #ja_slots do
            if ja_slots[i].num ~= ja_slots[i-1].num + 1 then
              has_gaps = true
              break
            end
          end

          if has_gaps then
            local start = ja_slots[1].num
            for _, e in ipairs(ja_slots) do row[e.key] = nil end
            for i, e in ipairs(ja_slots) do
              row['slot_' .. (start + i - 1)] = e.action
            end
          end
        end
       end
      end
    end
  end
end

local function compact_all_gaps(am)
  if not am.hotbar then return end
  for _, env in ipairs({ 'battle', 'field' }) do
    local env_hotbar = am.hotbar[env]
    if env_hotbar then
      for _, row in pairs(env_hotbar) do
        local slots = {}
        for slot_key, action in pairs(row) do
          local num = slot_key:match('^slot_(%d+)$')
          if num and type(action) == 'table' then slots[#slots + 1] = { num = tonumber(num), action = action } end
        end
        if #slots > 0 then
          table.sort(slots, function(a, b) return a.num < b.num end)
          local contiguous = true
          for i, e in ipairs(slots) do if e.num ~= i then contiguous = false break end end
          if not contiguous then
            for _, e in ipairs(slots) do row['slot_' .. e.num] = nil end
            for i, e in ipairs(slots) do row['slot_' .. i] = e.action end
          end
        end
      end
    end
  end
end

local function action_is_unusable_now(action, player)
  local t = tostring(action.type or ''):lower()
  if t == 'ma' then
    return (not action_is_known(action)) or (not action_meets_current_access(action, player))
  end
  if t == 'ja' or t == 'ws' or t == 'ct' then
    return not action_is_known(action)
  end
  return false
end

local function autohide_unusable_actions(am, player)
  for _, env in ipairs({ 'battle', 'field' }) do
    local env_hotbar = am.hotbar[env]
    if env_hotbar then
      for row_key, row in pairs(env_hotbar) do
        if not row_is_pinned(env, row_key) then
          for slot_key, action in pairs(row) do
            if slot_key:match('^slot_%d+$') and type(action) == 'table'
                and action_is_unusable_now(action, player) then
              row[slot_key] = nil
            end
          end
        end
      end
    end
  end
end

local PET_ROW_JOBS = { SMN = true, DRG = true, PUP = true, BST = true }
local PET_ROW_TYPES = {
  pet = true, bstpet = true, bloodpactrage = true, bloodpactward = true,
  petcommand = true,
}
local PET_ROW_ACTIONS = {
  ['smn_avatars'] = true, ['bst_ready'] = true,
  ['call wyvern'] = true, ['dismiss'] = true, ['spirit link'] = true, ['spirit bond'] = true,
  ['activate'] = true, ['deactivate'] = true,
  ['call beast'] = true, ['sic'] = true, ['snarl'] = true, ['run wild'] = true,
  ['assault'] = true, ['retreat'] = true, ['release'] = true,
}

local function is_pet_row_action(action)
  if action == nil then return false end
  local at = tostring(action.type or ''):lower()
  local aa = tostring(action.action or ''):lower()
  if PET_ROW_TYPES[at] or PET_ROW_ACTIONS[aa] then return true end
  if at == 'choice' and (aa:find('smn', 1, true) or aa:find('bst', 1, true) or aa:find('pet', 1, true)) then return true end
  return false
end

local function compact_pet_rows(am, player)
  local mj = tostring(player and player.main_job or ''):upper()
  if not PET_ROW_JOBS[mj] or not am.hotbar then return end
  for _, env in ipairs({'battle', 'field'}) do
    local env_table = am.hotbar[env]
    if env_table then
      for h = 1, am.hotbar_rows do
        local row = env_table['hotbar_' .. h]
        if row then
          local slot_nums = {}
          local has_pet_related = false
          for k, action in pairs(row) do
            local n = tonumber(tostring(k):match('^slot_(%d+)$'))
            if n then
              table.insert(slot_nums, n)
              if is_pet_row_action(action) then has_pet_related = true end
            end
          end
          if has_pet_related and #slot_nums > 1 then
            table.sort(slot_nums)
            local compacted = {}
            for _, n in ipairs(slot_nums) do
              local action = row['slot_' .. n]
              if action ~= nil then table.insert(compacted, action) end
              row['slot_' .. n] = nil
            end
            for i, action in ipairs(compacted) do
              row['slot_' .. i] = action
            end
            row_page_count_cache[env .. '|' .. tostring(h)] = nil
          end
        end
      end
    end
  end
end

local function compact_dynamic_gaps(am, player)
  if not (player and player.gen_mode) then return end
  if not am.hotbar or not am.hotbar_rows then return end
  for _, env in ipairs({'battle', 'field'}) do
    local env_table = am.hotbar[env]
    if env_table then
      for h = 1, am.hotbar_rows do
        local row = env_table['hotbar_' .. h]
        if row and not _pinned_rows[env .. '\0' .. h] then
          local nums = {}
          for k in pairs(row) do
            local n = tonumber(tostring(k):match('^slot_(%d+)$'))
            if n then nums[#nums + 1] = n end
          end
          if #nums > 0 then
            table.sort(nums)
            if nums[#nums] ~= #nums then
              local actions = {}
              for _, n in ipairs(nums) do actions[#actions + 1] = row['slot_' .. n] end
              for _, n in ipairs(nums) do row['slot_' .. n] = nil end
              for i, a in ipairs(actions) do row['slot_' .. i] = a end
              row_page_count_cache[env .. '|' .. tostring(h)] = nil
            end
          end
        end
      end
    end
  end
end

function action_manager:load(player)
  _req_check_player = player
  player:update_inventory_items()

  action_manager:init_action_tables()

  local basepath = HTB_PATH .. 'data/' .. player.name .. '/'
  local job_file, job_err = loadfile(basepath .. player.main_job .. '.lua')
  local general_file, general_err = loadfile(basepath .. 'General.lua')
  if job_file == nil then
    print(string.format("XIVHOTBAR2: Couldn't load job file %s.lua: %s", player.main_job, tostring(job_err or 'file not found')))
  else
    setfenv(job_file, _job_fileG)

    local ok, job_root = pcall(job_file)
    if not ok then
      print('XIVHOTBAR2: Error while running job file: ' .. tostring(job_root))
      _job_fileG.xivhotbar_keybinds_job = {}
      _job_fileG._binds = {}
      return
    end

    if not job_root then
      _job_fileG.xivhotbar_keybinds_job = {}
      _job_fileG._binds = {}
      return
    end
    _job_fileG.xivhotbar_keybinds_job = {}
    _job_fileG.xivhotbar_keybinds_job[job_root] = _job_fileG.xivhotbar_keybinds_job[job_root] or 'Root'
    last_job_root = job_root

    parse_binds(self.theme_options, player, job_root)

    if player.main_job == 'BST' and petname_actions.environment ~= nil then
      local beast_bars = {}
      for i = 1, #petname_actions.environment do
        beast_bars[petname_actions.environment[i] .. '\0' .. tostring(petname_actions.hotbar[i])] = true
      end
      local ke, kh, ks, kt, ka, kr, kl, ki = {}, {}, {}, {}, {}, {}, {}, {}
      for i = 1, #mainjob_actions.environment do
        if not beast_bars[mainjob_actions.environment[i] .. '\0' .. tostring(mainjob_actions.hotbar[i])] then
          table.insert(ke, mainjob_actions.environment[i])
          table.insert(kh, mainjob_actions.hotbar[i])
          table.insert(ks, mainjob_actions.slot[i])
          table.insert(kt, mainjob_actions.type[i])
          table.insert(ka, mainjob_actions.action[i])
          table.insert(kr, mainjob_actions.target[i])
          table.insert(kl, mainjob_actions.alias[i])
          table.insert(ki, mainjob_actions.icon[i])
        end
      end
      mainjob_actions.environment = ke
      mainjob_actions.hotbar = kh
      mainjob_actions.slot = ks
      mainjob_actions.type = kt
      mainjob_actions.action = ka
      mainjob_actions.target = kr
      mainjob_actions.alias = kl
      mainjob_actions.icon = ki
    end

    if subjob_actions.environment ~= nil then
      displace_into(mainjob_actions, subjob_actions)
    end
    if stance_actions.environment ~= nil then
      displace_into(mainjob_actions, stance_actions)
    end
    if weaponskill_actions.environment ~= nil then
      displace_into(mainjob_actions, weaponskill_actions)
    end

    if petname_actions.environment ~= nil then
      local manual = read_manual_slots(basepath .. player.main_job .. '.lua')
      if #manual.environment > 0 then
        displace_into(petname_actions, manual)
      end
    end

    action_manager:add_actions(mainjob_actions)
    if (subjob_actions.environment ~= nil) then
      action_manager:add_actions(subjob_actions)
    end
    if (petname_actions.environment ~= nil) then
      action_manager:add_actions(petname_actions)
    end

    if (stance_actions.environment ~= nil) then
      action_manager:add_actions(stance_actions)
    end
    action_manager:add_actions(weaponskill_actions)
  end

  if general_file == nil then
    print("XIVHOTBAR2: Couldn't load General.lua: " .. tostring(general_err or 'file not found'))
  else
    setfenv(general_file, _general_fileG)
    local ok_general, general_root = pcall(general_file)
    if not ok_general then
      print('XIVHOTBAR2: Error while running General.lua: ' .. tostring(general_root))
      _general_fileG.xivhotbar_keybinds_general = {}
      _general_fileG.binds = {}
      return
    end
    if not general_root then
      _general_fileG.xivhotbar_keybinds_general = {}
      _general_fileG.binds = {}
      return
    end
    _general_fileG.xivhotbar_keybinds_general = {}
    _general_fileG.xivhotbar_keybinds_general[general_root] = _general_fileG.xivhotbar_keybinds_general[general_root] or
        'Root'
    parse_general_binds(general_root)
    parse_general_list(_general_fileG.xivhotbar_general_list, self.theme_options and self.theme_options.columns)

    action_manager:add_actions(general_actions)
  end

  _pinned_rows = {}
  do
    local mp = read_manual_slots(basepath .. player.main_job .. '.lua')
    for i = 1, #mp.environment do
      local e = mp.environment[i]
      e = (e == 'b' and 'battle') or (e == 'f' and 'field') or e
      local r = tonumber(mp.hotbar[i])
      if r then _pinned_rows[e .. '\0' .. r] = true end
    end
  end

  if self.theme_options and self.theme_options.auto_hide_unusable == true then
    autohide_unusable_actions(self, player)
  end
  compact_blu_magic_rows(self, player)
  local collapse_gaps = not (self.theme_options and self.theme_options.collapse_gaps == false)
  if collapse_gaps then
    compact_inaccessible_magic_rows(self)
    compact_inaccessible_ja_rows(self)
  end
  compact_pet_rows(self, player)
  if collapse_gaps then
    compact_dynamic_gaps(self, player)
    compact_all_gaps(self)
  end

  local ranged_mode = (self.theme_options and self.theme_options.ranged_mode) or 'auto'
  local ranged_autopin = not (self.theme_options and self.theme_options.ranged_autopin == false)
  local rw = player.current_range_weapon or 0
  local ok_eq, eq = pcall(windower.ffxi.get_items)
  if ok_eq and eq and type(eq.equipment) == 'table' then
    local rb, ri = eq.equipment.range_bag, eq.equipment.range
    if rb and ri and not (rb == 0 and ri == 0) then
      local ritem = windower.ffxi.get_items(rb, ri)
      local rid   = ritem and ritem.id
      if rid and rid ~= 0 and resources and resources.items and resources.items[rid] then
        rw = resources.items[rid].skill or rw
      end
    else
      rw = 0
    end
  end
  local has_throwable_ammo = rw == 0 and player.has_ranged_ammo == true and (player.ammo_skill or 0) == 27
  local has_ranged_weapon = rw == 25 or rw == 26 or rw == 27
  local battle_row1 = self.hotbar['battle'] and self.hotbar['battle']['hotbar_1']
  if battle_row1 then
    local function is_ranged_dynamic(a)
      if not (a and a.is_dynamic == true) then return false end
      local t = tostring(a.type or ''):lower()
      return t == 'autora' or (t == 'input' and tostring(a.alias or '') == 'Ranged')
    end
    for k, v in pairs(battle_row1) do
      if k:match('^slot_%d+$') and is_ranged_dynamic(v) then battle_row1[k] = nil end
    end
    if ranged_autopin and ranged_mode ~= 'off' and (has_ranged_weapon or has_throwable_ammo) then
      local want = (ranged_mode == 'press')
        and { type = 'input', action = '/range <t>', target = '', alias = 'Ranged', icon = 'ffxiv/brd/apex_arrow', is_dynamic = true }
        or  { type = 'autora', action = 'toggle', target = '', alias = 'AutoRA', icon = 'ffxiv/brd/apex_arrow', is_dynamic = true }
      local columns = tonumber(self.theme_options and self.theme_options.columns or 12) or 12
      for i = 1, columns do
        if battle_row1['slot_' .. i] == nil then battle_row1['slot_' .. i] = want; break end
      end
    end
  end

  if type(self.post_load_overlay) == 'function' then
    pcall(self.post_load_overlay, self)
  end
end

function action_manager:apply_overlay(placements, bars)
  for env, rows in pairs(bars or {}) do
    local et = self.hotbar[env]
    if et then
      for row in pairs(rows) do
        local rt = et['hotbar_' .. row]
        if rt then
          for sk, a in pairs(rt) do
            if not (type(a) == 'table' and a.is_dynamic == true) then rt[sk] = nil end
          end
        end
      end
    end
  end
  local t = { environment = {}, hotbar = {}, slot = {}, type = {}, action = {}, target = {}, alias = {}, icon = {} }
  local n = 0
  for _, p in ipairs(placements or {}) do
    local et = self.hotbar[p.env]
    local row = et and et['hotbar_' .. p.row]
    if not (row and row['slot_' .. p.slot] ~= nil) then
      n = n + 1
      t.environment[n] = p.env
      t.hotbar[n]      = tostring(p.row)
      t.slot[n]        = tostring(p.slot)
      t.type[n]        = p.entry.type
      t.action[n]      = p.entry.action
      t.target[n]      = p.entry.target or 'me'
      t.alias[n]       = p.entry.alias or p.entry.action
      t.icon[n]        = p.entry.icon or ''
    end
  end
  self:add_actions(t)
end

return action_manager
