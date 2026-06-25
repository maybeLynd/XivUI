local hotbar_tools = {}

local resources = require('resources')
local choice_groups = require('components/xivhotbar3/lib/choice_groups')

local ACTION_ICONS = require('components/xivhotbar3/lib/icon_registry')

local ok_ability_levels, ability_level_list = pcall(require, 'components/xivhotbar3/priv_res/job_abilities_levels')
if not ok_ability_levels then ability_level_list = {} end

local ok_priv_ja, priv_job_abilities = pcall(require, 'components/xivhotbar3/priv_res/job_abilities')
if not ok_priv_ja then priv_job_abilities = {} end

local ok_horizon_spells, horizon_spell_list = pcall(require, 'components/xivhotbar3/priv_res/horizon_spells')
if not ok_horizon_spells then horizon_spell_list = {} end

local WARNED = {}

local VALID_TYPES = {
  ma = true,
  ja = true,
  ws = true,
  input = true,
  macro = true,
  gs = true,
  ct = true,
  pet = true,
  bstpet = true,
  item = true,
  autoitem = true,
  choice = true,
}

local NORMAL_CATEGORY_ALIASES = {
  main = 'main',
  mainjob = 'main',
  main_job = 'main',
  job = 'main',
  abilities = 'main',
  ability = 'main',
  ja = 'main',

  sub = 'sub',
  subjob = 'sub',
  sub_job = 'sub',

  ws = 'ws',
  weapon = 'ws',
  weaponskill = 'ws',
  weaponskills = 'ws',
  weapon_skill = 'ws',
  weapon_skills = 'ws',

  item = 'item',
  items = 'item',
  autoitem = 'item',
}

local MAGIC_CATEGORY_ALIASES = {

  elemental = 'elemental_magic',
  elemental_magic = 'elemental_magic',
  black = 'elemental_magic',
  blackmagic = 'elemental_magic',
  black_magic = 'elemental_magic',
  blm = 'elemental_magic',

  dark = 'dark_magic',
  dark_magic = 'dark_magic',
  darkmagic = 'dark_magic',
  drk = 'dark_magic',

  healing = 'healing_magic',
  healing_magic = 'healing_magic',
  white = 'healing_magic',
  whitemagic = 'healing_magic',
  white_magic = 'healing_magic',
  whm = 'healing_magic',

  enhancing = 'enhancing_magic',
  enhancing_magic = 'enhancing_magic',

  enfeebling = 'enfeebling_magic',
  enfeebling_magic = 'enfeebling_magic',

  divine = 'divine_magic',
  divine_magic = 'divine_magic',

  blue = 'blue_magic',
  bluemagic = 'blue_magic',
  blue_magic = 'blue_magic',
  blu = 'blue_magic',

  unbridled = 'unbridled_magic',
  unbridled_magic = 'unbridled_magic',
  ul = 'unbridled_magic',
  uw = 'unbridled_magic',

  nin = 'ninjutsu',
  ninja = 'ninjutsu',
  ninjutsu = 'ninjutsu',

  song = 'songs',
  songs = 'songs',
  bard = 'songs',
  brd = 'songs',
  bardsong = 'songs',
  bard_song = 'songs',

  summoning = 'summoning_magic',
  summoning_magic = 'summoning_magic',
  summon = 'summoning_magic',
  smn = 'summoning_magic',

  geomancy = 'geomancy',
  geo = 'geo_geomancy',
  geo_geomancy = 'geo_geomancy',
  geomancy_magic = 'geomancy',
  indi = 'indi_geomancy',
  indi_geomancy = 'indi_geomancy',
  indi_geo = 'indi_geomancy',

  trust = 'trust',
  trusts = 'trust',

  scholar = 'scholar_magic',
  scholar_magic = 'scholar_magic',
  sch_magic = 'scholar_magic',
  scholarmagic = 'scholar_magic',
}

local MAGIC_CATEGORY_LABELS = {
  elemental_magic = 'elemental magic',
  dark_magic = 'dark magic',
  healing_magic = 'healing magic',
  enhancing_magic = 'enhancing magic',
  enfeebling_magic = 'enfeebling magic',
  divine_magic = 'divine magic',
  blue_magic = 'blue magic',
  unbridled_magic = 'unbridled magic',
  ninjutsu = 'ninjutsu',
  songs = 'songs',
  summoning_magic = 'summoning magic',
  geomancy = 'geomancy',
  indi_geomancy = 'indi- geomancy',
  geo_geomancy = 'geo- geomancy',
  trust = 'trust',
  scholar_magic = 'scholar magic',
}

local PET_SECTION_ALIASES = {
  bloodrage        = 'blood_rage',
  blood_rage       = 'blood_rage',
  bprage           = 'blood_rage',
  bp_rage          = 'blood_rage',
  rage             = 'blood_rage',

  bloodward        = 'blood_ward',
  blood_ward       = 'blood_ward',
  bpward           = 'blood_ward',
  bp_ward          = 'blood_ward',
  ward             = 'blood_ward',

  wyvern           = 'wyvern',
  drg_wyvern       = 'wyvern',
  drgwyvern        = 'wyvern',

  automaton        = 'automaton',
  pup_automaton    = 'automaton',
  pupautomaton     = 'automaton',

  beast            = 'beast',
  bst_beast        = 'beast',
  bstbeast         = 'beast',
}

local PET_SECTION_LABELS = {
  blood_rage = 'blood rage',
  blood_ward = 'blood ward',
  wyvern     = 'wyvern',
  automaton  = 'automaton',
  beast      = 'beast',
}

local AVATAR_BY_ICON_ID = {
  [340] = 'Carbuncle',
  [341] = 'Fenrir',
  [342] = 'Ifrit',
  [343] = 'Titan',
  [344] = 'Leviathan',
  [345] = 'Garuda',
  [346] = 'Shiva',
  [347] = 'Ramuh',
  [348] = 'Diabolos',
  [349] = 'Odin',
  [350] = 'Alexander',
  [351] = 'Cait Sith',
  [18]  = 'Siren',
}
local AVATAR_ICON_PATHS = {
  Carbuncle       = 'summons/carbuncle_GUI',
  Fenrir          = 'summons/fenrir_GUI',
  Ifrit           = 'summons/ifrit_GUI',
  Titan           = 'summons/titan_GUI',
  Leviathan       = 'summons/leviathan_GUI',
  Garuda          = 'summons/garuda_GUI',
  Shiva           = 'summons/shiva_GUI',
  Ramuh           = 'summons/ramuh_GUI',
  Diabolos        = 'summons/diabolos_GUI',
  Odin            = 'summons/odin_GUI',
  Alexander       = 'summons/alexander_GUI',
  ['Cait Sith']   = 'summons/cait_sith_GUI',
  Siren           = 'summons/siren_GUI',
}

local UNBRIDLED_SPELL_IDS = {
  [736]=true, [737]=true, [738]=true, [739]=true, [740]=true,
  [741]=true, [742]=true, [743]=true, [744]=true, [745]=true,
  [746]=true, [750]=true, [751]=true, [752]=true, [753]=true,
}

local BLU_UNBRIDLED_KEYS = {
  ['ma|thunderbolt']       = true,
  ['ma|harden shell']      = true,
  ['ma|absolute terror']   = true,
  ['ma|gates of hades']    = true,
  ['ma|tourbillion']       = true,
  ['ma|pyric bulwark']     = true,
  ['ma|bilgestorm']        = true,
  ['ma|bloodrake']         = true,
  ['ma|droning whirlwind'] = true,
  ['ma|carcharian verve']  = true,
  ['ma|blistering roar']   = true,
  ['ma|mighty guard']      = true,
  ['ma|cruel joke']        = true,
  ['ma|cesspool']          = true,
  ['ma|tearing gust']      = true,
}

local WEAPONSKILL_TYPES = require('components/xivhotbar3/lib/constants').WEAPONSKILL_TYPES

local WEAPONSKILL_TYPE_KEYS = {}

local DEFAULT_PREFS = {
  battle = {},
  field = {},
  magic = {},
  pet = {},
  sub_populated = {},
  overlay = false,
  excluded = {},
  order = {},
  bar_order = {},
}

local AUTOGEN_START = '-- XIVHOTBAR2_AUTOGEN_START'
local AUTOGEN_END = '-- XIVHOTBAR2_AUTOGEN_END'

local STYLE_PRESETS = {
  xiv = {
    label = 'XIV-like: tight framed slots, visible empty frames',
    HideActionName = true,
    HideActionCost = false,
    HideEmptySlots = false,
    SlotSpacing = 4,
    HotbarSpacing = 48,
    SlotAlpha = 200,
    ShowEmptySlotFrames = true,
    Frame = 'ffxiv',
    Slot = 'ffxiv',
  },
  compact = {
    label = 'Compact: tight slots, minimal text',
    HideActionName = true,
    HideActionCost = true,
    HideEmptySlots = false,
    SlotSpacing = 2,
    HotbarSpacing = 44,
    SlotAlpha = 220,
    ShowEmptySlotFrames = true,
    Frame = 'ffxiv',
    Slot = 'ffxiv',
  },
  classic = {
    label = 'Classic addon defaults',
    HideActionName = false,
    HideActionCost = false,
    HideEmptySlots = true,
    SlotSpacing = 14,
    HotbarSpacing = 56,
    SlotAlpha = 100,
    ShowEmptySlotFrames = false,
    Frame = 'ffxiv',
    Slot = 'ffxiv',
  },
  minimal = {
    label = 'Minimal: hides names, costs, and empty slots',
    HideActionName = true,
    HideActionCost = true,
    HideEmptySlots = true,
    SlotSpacing = 6,
    HotbarSpacing = 48,
    SlotAlpha = 160,
    ShowEmptySlotFrames = false,
    Frame = 'ffxiv',
    Slot = 'ffxiv',
  },
  transparent = {
    label = 'Transparent: visible grid but low opacity',
    HideActionName = true,
    HideActionCost = false,
    HideEmptySlots = false,
    SlotSpacing = 4,
    HotbarSpacing = 48,
    SlotAlpha = 80,
    ShowEmptySlotFrames = true,
    Frame = 'ffxiv',
    Slot = 'ffxiv',
  },
}

local chat_force = false

local function chat(msg)
  if not (chat_force or _G.XIVUI_DEBUG) then return end
  if windower and windower.add_to_chat then
    windower.add_to_chat(8, tostring(msg))
  else
    print(tostring(msg))
  end
end

local function normalize_key(value)
  value = tostring(value or ''):lower()
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  value = value:gsub('%s+', '_')
  value = value:gsub('%-', '_')
  return value
end

local function init_weapon_keys()
  if next(WEAPONSKILL_TYPE_KEYS) ~= nil then return end
  for skill_id, skill_name in pairs(WEAPONSKILL_TYPES) do
    WEAPONSKILL_TYPE_KEYS[normalize_key(skill_name)] = skill_id
    WEAPONSKILL_TYPE_KEYS[normalize_key(skill_name:gsub('%-', ' '))] = skill_id
  end
  WEAPONSKILL_TYPE_KEYS.h2h = 1
  WEAPONSKILL_TYPE_KEYS.handtohand = 1
  WEAPONSKILL_TYPE_KEYS.hand_to_hand = 1
  WEAPONSKILL_TYPE_KEYS.greatsword = 4
  WEAPONSKILL_TYPE_KEYS.great_sword = 4
  WEAPONSKILL_TYPE_KEYS.great_axe = 6
  WEAPONSKILL_TYPE_KEYS.greataxe = 6
  WEAPONSKILL_TYPE_KEYS.greatkatana = 10
  WEAPONSKILL_TYPE_KEYS.great_katana = 10
  WEAPONSKILL_TYPE_KEYS.marksmanship = 26
  WEAPONSKILL_TYPE_KEYS.marksman = 26
  WEAPONSKILL_TYPE_KEYS.ranged = 26
end

local function normalize_env(env)
  env = tostring(env or ''):lower()
  if env == 'b' or env == 'battle' then return 'battle' end
  if env == 'f' or env == 'field' then return 'field' end
  return nil
end

local function copy_table(t)
  local out = {}
  if type(t) ~= 'table' then return out end
  for k, v in pairs(t) do
    if type(v) == 'table' then
      out[k] = copy_table(v)
    else
      out[k] = v
    end
  end
  return out
end

local function file_exists(path)
  local f = io.open(path, 'rb')
  if f then f:close(); return true end
  return false
end

local function read_lines(path)
  local lines = {}
  local f = io.open(path, 'r')
  if not f then return lines end
  for line in f:lines() do table.insert(lines, line) end
  f:close()
  return lines
end

local function write_lines(path, lines)
  local f = io.open(path, 'w')
  if not f then return false end
  for _, line in ipairs(lines) do f:write(line .. '\n') end
  f:close()
  return true
end

local function parse_quoted_fields(line)
  local fields = {}
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "'" or c == '"' then
      local q = c
      local j = i + 1
      while j <= #line do
        local cj = line:sub(j, j)
        if cj == q and line:sub(j - 1, j - 1) ~= '\\' then
          break
        end
        j = j + 1
      end
      table.insert(fields, line:sub(i + 1, j - 1))
      i = j + 1
    else
      i = i + 1
    end
  end
  return fields
end

local function parse_slot(slot_text)
  if not slot_text then return nil end
  local env, row, slot = tostring(slot_text):match('^%s*(%S+)%s+(%d+)%s+(%d+)%s*$')
  env = normalize_env(env)
  row = tonumber(row)
  slot = tonumber(slot)
  if not env or not row or not slot then return nil end
  return env, row, slot
end

local function parse_action_line(line)
  if not line then return nil end
  if line:match('^%s*%-%-') then return nil end
  if not line:find('{', 1, true) then return nil end

  local fields = parse_quoted_fields(line)
  if #fields < 2 then return nil end

  local env, row, slot = parse_slot(fields[1])
  return {
    line = line,
    slot_text = fields[1],
    env = env,
    row = row,
    slot = slot,
    type = fields[2],
    action = fields[3],
    target = fields[4],
    alias = fields[5],
    icon = fields[6],
    field_count = #fields,
    has_valid_slot = env ~= nil and row ~= nil and slot ~= nil,
  }
end

local function get_paths(player)
  local base = HTB_PATH .. 'data/' .. player.name .. '/'
  return {
    base = base,
    job = base .. player.main_job .. '.lua',
    general = base .. 'General.lua',
    prefs = base .. 'autogen_settings_' .. player.main_job .. '.lua',
  }
end

local function quote_lua_string(value)
  value = value or ''
  return string.format('%q', tostring(value))
end

local function shorten_name(name)
  if _G.shorten_ability_name then
    return _G.shorten_ability_name(name)
  end
  name = tostring(name or '')
  local compact = name:gsub('[^%w]+', '')
  if #compact == 0 then return 'Action' end
  return compact:sub(1, 6)
end

local function normalize_action_name_for_key(action_name)
  local value = tostring(action_name or ''):lower()
  value = value:gsub('[’`]', "'")
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  value = value:gsub('%s+', ' ')
  return value
end

local function action_key(action_type, action_name)
  return tostring(action_type or ''):lower() .. '|' .. normalize_action_name_for_key(action_name)
end

local AUTOGEN_SUPPRESSED_ACTION_KEYS = {
  ['ja|samba'] = true,
  ['ja|sambas'] = true,
  ['ja|waltz'] = true,
  ['ja|waltzes'] = true,
  ['ja|step'] = true,
  ['ja|steps'] = true,
  ['ja|jig'] = true,
  ['ja|jigs'] = true,
  ['ja|flourish'] = true,
  ['ja|flourishes'] = true,
  ['ja|flourish i'] = true,
  ['ja|flourish ii'] = true,
  ['ja|flourish iii'] = true,
  ['ja|flourish 1'] = true,
  ['ja|flourish 2'] = true,
  ['ja|flourish 3'] = true,
  ['ja|flourishes i'] = true,
  ['ja|flourishes ii'] = true,
  ['ja|flourishes iii'] = true,
  ['ja|flourishes 1'] = true,
  ['ja|flourishes 2'] = true,
  ['ja|flourishes 3'] = true,
  ['ja|flourishes 1-3'] = true,
  ['ja|flourishes i-iii'] = true,
  ['ja|flourishes i - iii'] = true,
  ['ja|flourishes 1 - 3'] = true,

  ['ja|blood pact: rage'] = true,
  ['ja|blood pact: ward'] = true,
  ['ja|release'] = true,

  ['ja|deactivate'] = true,

  ['ja|phantom roll'] = true,
  ['ja|phantom rolls'] = true,
  ['ja|quick draw'] = true,
  ['ja|quick draws'] = true,
  ['ja|corsair shot'] = true,
  ['ja|corsair shots'] = true,
  ['ja|rune'] = true,
  ['ja|runes'] = true,
  ['ja|rune enchantment'] = true,
  ['ja|ward'] = true,
  ['ja|wards'] = true,
  ['ja|effusion'] = true,
  ['ja|effusions'] = true,
  ['ja|pet command'] = true,
  ['ja|pet commands'] = true,
  ['ja|monster'] = true,

  ['ja|addendum: white'] = true,
  ['ja|addendum: black'] = true,

  ['ja|fight'] = true,
  ['ja|heel'] = true,
  ['ja|stay'] = true,
  ['ja|sic'] = true,
  ['ja|ready'] = true,
  ['ja|leave'] = true,
  ['ja|snarl'] = true,
  ['ja|spur'] = true,
  ['ja|run wild'] = true,
  ['ja|reward'] = true,
  ['ja|feral howl'] = true,
  ['ja|killer instinct'] = true,
  ['ja|unleash'] = true,
}

local function is_autogen_suppressed_action(action_type, action_name)
  local key = action_key(action_type, action_name)
  if AUTOGEN_SUPPRESSED_ACTION_KEYS[key] then return true end

  if tostring(action_type or ''):lower() ~= 'ja' then return false end

  local name = normalize_action_name_for_key(action_name)
  if name:match('^sambas?$') then return true end
  if name:match('^waltzes?$') then return true end
  if name:match('^steps?$') then return true end
  if name:match('^jigs?$') then return true end
  if name:match('^flourishes?$') then return true end
  if name:match('^flourishes?%s+[ivx]+$') then return true end
  if name:match('^flourishes?%s+%d+$') then return true end
  if name:match('^flourishes?%s+[ivx]+%s*%-%s*[ivx]+$') then return true end
  if name:match('^flourishes?%s+%d+%s*%-%s*%d+$') then return true end

  if name:match('^phantom rolls?$') then return true end
  if name:match('^quick draws?$') then return true end
  if name:match('^corsair shots?$') then return true end
  if name:match('^runes?$') then return true end
  if name:match('^rune enchantment$') then return true end
  if name:match('^wards?$') then return true end
  if name:match('^effusions?$') then return true end
  if name:match('^pet commands?$') then return true end
  if name:match('^monster$') then return true end

  return false
end

local function first_existing_resource(res_table, id)
  if not res_table then return nil end
  local direct = res_table[id]
  if direct then return direct end
  for _, value in pairs(res_table) do
    if type(value) == 'table' and tonumber(value.id) == tonumber(id) then
      return value
    end
  end
  return nil
end

local function build_lower_lookup(res_table)
  local out = {}
  if type(res_table) ~= 'table' then return out end
  for _, value in pairs(res_table) do
    if type(value) == 'table' and value.en then
      out[tostring(value.en):lower()] = value
    end
  end
  return out
end

local TARGET_OVERRIDES = {
  ['ja|provoke'] = 'stnpc',
  ['ja|animated flourish'] = 'stnpc',
  ['ja|violent flourish'] = 'stnpc',
  ['ja|quickstep'] = 't',
  ['ja|box step'] = 't',
  ['ja|stutter step'] = 't',
  ['ja|feather step'] = 't',
  ['ja|assault'] = 't',
}

local function target_flag(targets, key)
  if type(targets) ~= 'table' then return false end
  if targets[key] or targets[key:lower()] then return true end
  for k, v in pairs(targets) do
    if v and tostring(k):lower() == tostring(key):lower() then return true end
  end
  return false
end

local function get_default_target(action_type, data)
  action_type = tostring(action_type or ''):lower()
  local action_name = data and (data.en or data.name) or ''
  local override = TARGET_OVERRIDES[action_type .. '|' .. tostring(action_name or ''):lower()]
  if override then return override end

  if action_type == 'ws' then return 't' end
  if not data or type(data.targets) ~= 'table' then return 'me' end

  local targets = data.targets
  local self_target = target_flag(targets, 'Self')
  local player_target = target_flag(targets, 'Player') or target_flag(targets, 'PC')
  local party_target = target_flag(targets, 'Party') or target_flag(targets, 'Ally')
  local enemy_target = target_flag(targets, 'Enemy')
  local npc_target = target_flag(targets, 'NPC')
  local object_target = target_flag(targets, 'Object')
  local corpse_target = target_flag(targets, 'Corpse')

  local friendly_target = player_target or party_target
  local hostile_target = enemy_target or npc_target

  if self_target and not friendly_target and not hostile_target and not object_target and not corpse_target then
    return 'me'
  end

  local skill = tostring(data.skill or data.type or ''):lower()
  if self_target and (skill:find('summoning') or skill:find('trust')) then
    return 'me'
  end

  if friendly_target then
    return 'stpc'
  end

  if hostile_target then
    if action_type == 'ja' and (tostring(action_name):lower():find('step') or tostring(action_name):lower():find('shot')) then
      return 't'
    end
    return 'stnpc'
  end

  if object_target or corpse_target then
    return 'st'
  end

  return 'me'
end

local function find_base_section(lines)
  local start_i = nil
  local end_i = nil

  for i, line in ipairs(lines) do
    if line:find("xivhotbar_keybinds_job%[['\"]Base['\"]%]%s*=%s*{") then
      start_i = i
      break
    end
  end

  if start_i then
    for i = start_i + 1, #lines do
      if lines[i]:match('^%s*}%s*,?%s*$') then
        end_i = i
        break
      end
    end
  end

  return start_i, end_i
end

local function find_named_section(lines, name)
  local pattern = "xivhotbar_keybinds_job%[[\'\"]" .. name .. "[\'\"]%]%s*=%s*{"
  local start_i = nil
  for i, line in ipairs(lines) do
    if line:find(pattern) then
      start_i = i
      break
    end
  end
  if not start_i then return nil, nil end
  local end_i = nil
  for i = start_i + 1, #lines do
    if lines[i]:match('^%s*}%s*,?%s*$') then
      end_i = i
      break
    end
  end
  return start_i, end_i
end

local function ensure_named_section(lines, name)
  local start_i, end_i = find_named_section(lines, name)
  if start_i then return lines end
  local insert_pos = #lines + 1
  for i = #lines, 1, -1 do
    if lines[i]:match('^%s*return%s') then
      insert_pos = i
      break
    end
  end
  table.insert(lines, insert_pos, '}')
  table.insert(lines, insert_pos, "xivhotbar_keybinds_job['" .. name .. "'] = {")
  table.insert(lines, insert_pos, '')
  return lines
end

local function remove_autogen_blocks(lines)
  local out = {}
  local skipping = false
  for _, line in ipairs(lines) do
    if line:find(AUTOGEN_START, 1, true) then
      skipping = true
    elseif line:find(AUTOGEN_END, 1, true) then
      skipping = false
    elseif not skipping then
      table.insert(out, line)
    end
  end
  return out
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

local function safe_level_for_ability(ability_id, job_id)
  local data = ability_level_list[ability_id]
  if data and data.levels then return data.levels[job_id] end
  return nil
end

local function category_for_ability(player, ability_id)
  local main_level = safe_level_for_ability(ability_id, player.main_job_id)
  local sub_level = safe_level_for_ability(ability_id, player.sub_job_id)
  local effective_sub_level = effective_subjob_level(player.main_job_level, player.sub_job_level)

  if main_level and player.main_job_level and player.main_job_level >= main_level then
    return 'main', main_level
  end

  if sub_level and effective_sub_level and effective_sub_level >= sub_level then
    return 'sub', sub_level
  end

  return nil, 999
end

local function spell_access_level(player, spell)
  if not spell then return nil end
  if type(spell.levels) ~= 'table' then return 0 end
  local main_level = spell.levels[player.main_job_id]
  local sub_level = spell.levels[player.sub_job_id]
  local effective_sub_level = effective_subjob_level(player.main_job_level, player.sub_job_level)

  local best = nil
  if main_level and player.main_job_level >= main_level then best = main_level end
  if sub_level and effective_sub_level >= sub_level then
    if not best or sub_level < best then best = sub_level end
  end
  return best
end

local function detect_magic_category(spell)
  if not spell then return nil end
  local t = normalize_key(spell.type or '')
  local skill_id  = tonumber(spell.skill) or 0
  local skill_str = type(spell.skill) == 'string' and normalize_key(spell.skill)
                    or normalize_key(spell.skill_name or '')

  if type(spell.levels) == 'table' and spell.levels[20] ~= nil then
    local job_count = 0
    for _ in pairs(spell.levels) do job_count = job_count + 1 end
    if job_count == 1 then return 'scholar_magic' end
  end

  if t:find('blue', 1, true) or skill_str:find('blue', 1, true) then return 'blue_magic' end
  if t:find('ninjutsu', 1, true) or skill_str:find('ninjutsu', 1, true) then return 'ninjutsu' end
  if t:find('bard', 1, true) or t:find('song', 1, true) or skill_str:find('singing', 1, true) or skill_str:find('string', 1, true) or skill_str:find('wind_instrument', 1, true) then return 'songs' end
  if t:find('summon', 1, true) or t:find('avatar', 1, true) or skill_str:find('summon', 1, true) then return 'summoning_magic' end
  if t:find('geomancy', 1, true) or t == 'geo' or skill_str:find('geomancy', 1, true) or skill_str:find('handbell', 1, true) then
    local spell_en = tostring(spell.en or '')
    if spell_en:find('^Indi%-', 1) then return 'indi_geomancy' end
    if spell_en:find('^Geo%-',  1) then return 'geo_geomancy'  end
    return 'geomancy'
  end
  if t:find('trust', 1, true) then return 'trust' end
  if t:find('black', 1, true) then
    if skill_id == 37 or skill_str:find('dark', 1, true)         then return 'dark_magic'      end
    if skill_id == 34 or skill_str:find('enhancing', 1, true)    then return 'enhancing_magic'  end
    return 'elemental_magic'
  end
  if t:find('white', 1, true) then
    if skill_id == 32 or skill_str:find('divine', 1, true)      then return 'divine_magic'     end
    if skill_id == 34 or skill_str:find('enhancing', 1, true)   then return 'enhancing_magic'  end
    if skill_id == 35 or skill_str:find('enfeebling', 1, true)  then return 'enfeebling_magic' end
    return 'healing_magic'
  end
  if skill_str:find('elemental', 1, true) then return 'elemental_magic' end
  if skill_str:find('dark', 1, true)      then return 'dark_magic'      end
  if skill_str:find('healing', 1, true)   then return 'healing_magic'   end
  if skill_str:find('enhancing', 1, true) then return 'enhancing_magic' end
  if skill_str:find('enfeebling', 1, true)then return 'enfeebling_magic'end
  if skill_str:find('divine', 1, true)    then return 'divine_magic'    end

  return 'all_magic'
end

local function spell_family_key(name)
  local n = tostring(name or ''):lower()
  n = n:gsub('["\']', '')
  n = n:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')

  n = n:gsub('%s+[ivx]+$', '')
  n = n:gsub('%s+%d+$', '')

  n = n:gsub(':%s*ichi$', '')
  n = n:gsub(':%s*ni$', '')
  n = n:gsub(':%s*san$', '')

  n = n:gsub('%s+%+$', '')
  return n
end

local function spell_sort_level(a, b)
  if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
  return tostring(a.action) < tostring(b.action)
end

local function sort_generated(a, b)
  local ao = a.sort_order or math.huge
  local bo = b.sort_order or math.huge
  if ao ~= bo then return ao < bo end
  if a.category ~= b.category then return a.category < b.category end
  if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
  return tostring(a.action) < tostring(b.action)
end

local JOB_PRIORITY = {
  SMN = {
    ['choice|smn_avatars']           = 1,
    ['ja|assault']                   = 2,
    ['ja|retreat']                   = 3,
    ['choice|ja_type_bloodpactrage'] = 4,
    ['choice|ja_type_bloodpactward'] = 5,
    ["ja|avatar's favor"]            = 6,
  },
  BLU = {
    ['ja|azure lore']          = 1,
    ['ja|burst affinity']      = 2,
    ['ja|chain affinity']      = 3,
    ['ja|efflux']              = 4,
    ['ja|convergence']         = 5,
    ['ja|diffusion']           = 6,
    ['ja|unbridled learning']  = 7,
    ['ja|unbridled wisdom']    = 8,
  },
  DRG = {
    ['ja|call wyvern']    = 1,
    ['ja|spirit surge']   = 2,
    ['ja|spirit link']    = 3,
    ['ja|spirit bond']    = 4,
    ['ja|jump']           = 5,
    ['ja|high jump']      = 6,
    ['ja|super jump']     = 7,
    ['ja|spirit jump']    = 8,
    ['ja|soul jump']      = 9,
    ['ja|fly high']       = 10,
    ['ja|angon']          = 11,
    ['ja|dragon breaker'] = 12,
    ['ja|ancient circle'] = 13,
  },
  PUP = {
    ['ja|activate']          = 1,
    ['ja|deploy']            = 2,
    ['ja|retrieve']          = 3,
    ['choice|pup_maneuvers'] = 4,
  },
  SCH = {
    ['ja|tabula rasa']        = 1,
    ['choice|sch_stratagems'] = 2,
    ['ja|dark arts']          = 3,
    ['ja|light arts']         = 4,
    ['ja|sublimation']        = 5,
  },
  BST = {
    ['ja|gauge']           = 1,
    ['ja|tame']            = 2,
    ['ja|charm']           = 3,
    ['ja|call beast']      = 4,
    ['ja|bestial loyalty'] = 5,
    ['ja|familiar']        = 6,
  },
  DNC = {
    ['choice|dnc_sambas']       = 1,
    ['choice|dnc_waltzes']      = 2,
    ['choice|dnc_steps']        = 3,
    ['choice|dnc_flourishes_1'] = 4,
    ['choice|dnc_flourishes_2'] = 5,
    ['choice|dnc_flourishes_3'] = 6,
    ['choice|dnc_jigs']         = 7,
    ['ja|trance']               = 8,
    ['ja|contradance']          = 9,
    ['ja|saber dance']          = 10,
    ['ja|fan dance']            = 11,
    ['ja|no foot rise']         = 12,
    ['ja|presto']               = 13,
    ['ja|grand pas']            = 14,
  },
}

local function apply_job_priorities(player, entries)
  if not player then return end
  for _, job in ipairs({ player.main_job, player.sub_job }) do
    local pri = job and JOB_PRIORITY[job]
    if pri then
      for _, entry in ipairs(entries) do
        if entry.category == 'main' or entry.category == 'sub' then
          local key = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
          local order = pri[key]
          if order then entry.sort_order = order end
        end
      end
    end
  end
end

local function apply_order_overrides(prefs, entries)
  local order = prefs and prefs.order
  if type(order) ~= 'table' or not next(order) then return end
  local rank = {}
  for cat, list in pairs(order) do
    rank[cat] = {}
    for i, k in ipairs(list) do rank[cat][k] = i end
  end
  for _, entry in ipairs(entries) do
    local r = rank[tostring(entry.category or '')]
    if r then
      local key = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      if r[key] then
        entry.sort_order = r[key]
      else
        entry.sort_order = 1000 + (entry.sort_order or 500)
      end
    end
  end
end

local function append_bar_order(prefs, category)
  if not category then return end
  prefs.bar_order = prefs.bar_order or {}
  for _, k in ipairs(prefs.bar_order) do if k == category then return end end
  prefs.bar_order[#prefs.bar_order + 1] = category
end

local function remove_bar_order(prefs, category)
  if not category or type(prefs.bar_order) ~= 'table' then return end
  local out = {}
  for _, k in ipairs(prefs.bar_order) do if k ~= category then out[#out + 1] = k end end
  prefs.bar_order = out
end

local function make_action_line(entry, env, row, slot)
  local slot_text = env .. ' ' .. tostring(row) .. ' ' .. tostring(slot)
  local line = "  { '" .. slot_text .. "', '" .. entry.type .. "', " .. quote_lua_string(entry.action) .. ", '" ..
      (entry.target or 'me') .. "', " .. quote_lua_string(entry.alias or shorten_name(entry.action))

  if entry.icon and entry.icon ~= '' then
    line = line .. ', ' .. quote_lua_string(entry.icon)
  end

  return line .. ' }, -- XIVHOTBAR2 autogen: ' .. entry.category
end

local function get_magic_pref(prefs, category)
  if type(prefs.magic) ~= 'table' then return nil end
  return prefs.magic[category]
end

local function is_magic_category_key(category)
  return MAGIC_CATEGORY_LABELS[tostring(category or '')] ~= nil
end

local function collect_existing(paths, include_autogen)
  local used_slots = { battle = {}, field = {} }
  local actions = {}
  local magic_family_slots = {}
  local spell_lookup = build_lower_lookup(resources.spells)

  local function ensure(env, row)
    used_slots[env] = used_slots[env] or {}
    used_slots[env][row] = used_slots[env][row] or {}
  end

  local function scan(path)
    local in_autogen = false
    for _, line in ipairs(read_lines(path)) do
      if line:find(AUTOGEN_START, 1, true) then in_autogen = true end
      if line:find(AUTOGEN_END, 1, true) then in_autogen = false end
      if include_autogen or not in_autogen then
        local a = parse_action_line(line)
        if a and a.has_valid_slot then
          ensure(a.env, a.row)
          used_slots[a.env][a.row][a.slot] = true
          if a.type and a.action then
            actions[action_key(a.type, a.action)] = true
          end

          if tostring(a.type or ''):lower() == 'ma' and a.action then
            local spell = spell_lookup[tostring(a.action):lower()]
            if spell then
              local cat = detect_magic_category(spell)
              local family = spell_family_key(a.action)
              magic_family_slots[cat] = magic_family_slots[cat] or {}
              if not magic_family_slots[cat][family] then
                magic_family_slots[cat][family] = { env = a.env, row = a.row, slot = a.slot }
              end
              magic_family_slots.all_magic = magic_family_slots.all_magic or {}
              if not magic_family_slots.all_magic[family] then
                magic_family_slots.all_magic[family] = { env = a.env, row = a.row, slot = a.slot }
              end
            end
          end
        end
      end
    end
  end

  scan(paths.job)
  scan(paths.general)
  return used_slots, actions, magic_family_slots
end

local function collect_autogen_pinned_slots(paths)
  local pinned = {}
  local magic_families = {}
  local spell_lookup = build_lower_lookup(resources.spells)

  local function scan(path)
    local in_autogen = false
    for _, line in ipairs(read_lines(path)) do
      local is_start = line:find(AUTOGEN_START, 1, true) ~= nil
      local is_end   = line:find(AUTOGEN_END,   1, true) ~= nil
      if is_start then in_autogen = true end
      if is_end   then in_autogen = false end
      if in_autogen and not is_start then
        local a = parse_action_line(line)
        if a and a.has_valid_slot and a.type and a.action then
          local key = action_key(a.type, a.action)
          if not pinned[key] then
            pinned[key] = { env = a.env, row = a.row, slot = a.slot }
          end
          if tostring(a.type):lower() == 'ma' then
            local spell = spell_lookup[tostring(a.action):lower()]
            if spell then
              local cat    = detect_magic_category(spell)
              local family = spell_family_key(a.action)
              magic_families[cat] = magic_families[cat] or {}
              if not magic_families[cat][family] then
                magic_families[cat][family] = { env = a.env, row = a.row, slot = a.slot }
              end
              magic_families.all_magic = magic_families.all_magic or {}
              if not magic_families.all_magic[family] then
                magic_families.all_magic[family] = { env = a.env, row = a.row, slot = a.slot }
              end
            end
          end
        end
      end
    end
  end

  scan(paths.job)
  return pinned, magic_families
end

local function collect_existing_choice_group_ids(paths)
  local ids = {}

  local function scan(path)
    for _, line in ipairs(read_lines(path)) do
      local a = parse_action_line(line)
      if a and tostring(a.type or ''):lower() == 'choice' and a.action and a.action ~= '' then
        ids[tostring(a.action)] = true
      end
    end
  end

  scan(paths.job)
  scan(paths.general)
  return ids
end

local function merge_action_keys(dest, src)
  if type(src) ~= 'table' then return end
  for key, value in pairs(src) do
    if value then dest[key] = true end
  end
end

local function remove_autogen_lines_matching_actions(lines, covered_action_keys)
  if type(covered_action_keys) ~= 'table' or next(covered_action_keys) == nil then return lines, 0 end

  local out = {}
  local removed = 0
  for _, line in ipairs(lines) do
    local a = parse_action_line(line)
    local is_autogen_line = line:find('XIVHOTBAR2 autogen:', 1, true) ~= nil
    local key = nil
    if a and a.type and a.action then key = action_key(a.type, a.action) end

    if is_autogen_line and key and tostring(a.type or ''):lower() ~= 'choice'
        and (covered_action_keys[key] or is_autogen_suppressed_action(a.type, a.action)) then
      removed = removed + 1
    else
      table.insert(out, line)
    end
  end
  return out, removed
end

local function category_matches_filter(category, filter)
  if not filter or not filter.categories then return true end
  if filter.categories[category] then return true end
  return false
end

local function target_matches_filter(env, row, filter)
  if not filter then return true end
  if filter.env and filter.env ~= env then return false end
  if filter.bars and not filter.bars[row] then return false end
  return true
end

local function find_empty_slot(used_slots, env, row, columns)
  used_slots[env] = used_slots[env] or {}
  used_slots[env][row] = used_slots[env][row] or {}
  for slot = 1, columns do
    if not used_slots[env][row][slot] then
      used_slots[env][row][slot] = true
      return slot
    end
  end
  return nil
end

local function find_empty_virtual_slot(used_slots, env, row, columns)
  used_slots[env] = used_slots[env] or {}
  used_slots[env][row] = used_slots[env][row] or {}
  local max_slot = (columns or 12) * 5
  local slot = 1
  while used_slots[env][row][slot] and slot <= max_slot do
    slot = slot + 1
  end
  if slot > max_slot then return nil end
  used_slots[env][row][slot] = true
  return slot
end

local capture_placements = nil

local function add_slot_line(generated_lines, existing_actions, entry, env, row, slot)
  if not existing_actions[action_key(entry.type, entry.action)] then
    existing_actions[action_key(entry.type, entry.action)] = true
    table.insert(generated_lines, make_action_line(entry, env, row, slot))
    if capture_placements then
      table.insert(capture_placements, { entry = entry, env = env, row = row, slot = slot })
    end
    return true
  end
  return false
end

local function place_entries(entries, prefs, theme_options, existing_slots, existing_actions, magic_family_slots, filter, pinned_slots, pinned_magic_families)
  local columns = tonumber(theme_options.columns or 12) or 12
  local generated_lines = {}
  local overflow = {}

  local grouped = { main = {}, sub = {}, ws = {}, item = {} }
  local magic_grouped = {}
  local magic_choice_grouped = {}

  for _, entry in ipairs(entries) do
    if entry.type == 'ma' then
      local cat = entry.category
      local magic_pref = get_magic_pref(prefs, cat)
      if not magic_pref and (cat == 'indi_geomancy' or cat == 'geo_geomancy') then
        magic_pref = get_magic_pref(prefs, 'geomancy')
        if magic_pref then cat = 'geomancy' end
      end
      if magic_pref then
        magic_grouped[cat] = magic_grouped[cat] or {}
        magic_grouped[cat][entry.family] = magic_grouped[cat][entry.family] or {}
        table.insert(magic_grouped[cat][entry.family], entry)
      end
    elseif entry.type == 'choice' and is_magic_category_key(entry.category) then
      local magic_pref = get_magic_pref(prefs, entry.category)
      if magic_pref then
        magic_choice_grouped[entry.category] = magic_choice_grouped[entry.category] or {}
        table.insert(magic_choice_grouped[entry.category], entry)
      end
    elseif grouped[entry.category] then
      table.insert(grouped[entry.category], entry)
    end
  end

  if prefs.leading then
    for _, entry in ipairs(prefs.leading) do
      local env = entry.env or 'battle'
      local row = tonumber(entry.row)
      local slot = tonumber(entry.slot)
      if env and row and slot then
        existing_slots[env] = existing_slots[env] or {}
        existing_slots[env][row] = existing_slots[env][row] or {}
        existing_slots[env][row][slot] = true
        local key = action_key(entry.type, entry.action)
        if not existing_actions[key] then
          existing_actions[key] = true
          table.insert(generated_lines, make_action_line({
            type = entry.type,
            action = entry.action,
            target = entry.target or '',
            alias = entry.alias or entry.action,
            icon = entry.icon or '',
            category = 'leading',
          }, env, row, slot))
        end
      end
    end
  end

  local LEGACY_RANK = { main = 1, sub = 2, ws = 3, item = 4 }
  local bar_seq = {}
  if type(prefs.bar_order) == 'table' then
    for i, k in ipairs(prefs.bar_order) do bar_seq[k] = i end
  end
  local function bar_rank(category)
    return bar_seq[category] or (1000 + (LEGACY_RANK[category] or 500))
  end

  local function place_normal(category)
    if not category_matches_filter(category, filter) then return end
    local row = prefs.battle[category]
    if not row then return end
    table.sort(grouped[category], sort_generated)
    local env = 'battle'
    if not target_matches_filter(env, row, filter) then return end
    for _, entry in ipairs(grouped[category]) do
      if not existing_actions[action_key(entry.type, entry.action)] then
        local key = action_key(entry.type, entry.action)
        local slot = nil
        if pinned_slots then
          local p = pinned_slots[key]
          if p and p.env == env and p.row == row then
            existing_slots[env] = existing_slots[env] or {}
            existing_slots[env][row] = existing_slots[env][row] or {}
            if not existing_slots[env][row][p.slot] then
              existing_slots[env][row][p.slot] = true
              slot = p.slot
            end
          end
        end
        if not slot then slot = find_empty_virtual_slot(existing_slots, env, row, columns) end
        if slot then
          add_slot_line(generated_lines, existing_actions, entry, env, row, slot)
        else
          table.insert(overflow, entry)
        end
      end
    end
  end

  local function place_magic_choice(category)
    if not category_matches_filter(category, filter) then return end
    local choice_entries = magic_choice_grouped[category]
    local pref = get_magic_pref(prefs, category)
    if not (choice_entries and pref) then return end
    local env = pref.env or 'battle'
    local row = tonumber(pref.bar or pref.row or 4) or 4
    if not target_matches_filter(env, row, filter) then return end
    table.sort(choice_entries, sort_generated)
    for _, entry in ipairs(choice_entries) do
      if not existing_actions[action_key(entry.type, entry.action)] then
        local key = action_key(entry.type, entry.action)
        local slot = nil
        if pinned_slots then
          local p = pinned_slots[key]
          if p and p.env == env and p.row == row then
            existing_slots[env] = existing_slots[env] or {}
            existing_slots[env][row] = existing_slots[env][row] or {}
            if not existing_slots[env][row][p.slot] then
              existing_slots[env][row][p.slot] = true
              slot = p.slot
            end
          end
        end
        if not slot then slot = find_empty_virtual_slot(existing_slots, env, row, columns) end
        if slot then
          add_slot_line(generated_lines, existing_actions, entry, env, row, slot)
        else
          table.insert(overflow, entry)
        end
      end
    end
  end

  local function place_magic(category)
    if not category_matches_filter(category, filter) then return end
    local families = magic_grouped[category]
    local pref = get_magic_pref(prefs, category)
    if not (families and pref) then return end
    local env = pref.env or 'battle'
    local row = tonumber(pref.bar or pref.row or 4) or 4
    if not target_matches_filter(env, row, filter) then return end

    local family_keys = {}
    for family, _ in pairs(families) do table.insert(family_keys, family) end
    table.sort(family_keys, function(a, b)
      local a_min, b_min = math.huge, math.huge
      for _, s in ipairs(families[a]) do if (s.level or 0) < a_min then a_min = s.level or 0 end end
      for _, s in ipairs(families[b]) do if (s.level or 0) < b_min then b_min = s.level or 0 end end
      if a_min ~= b_min then return a_min < b_min end
      return a < b
    end)

    for _, family in ipairs(family_keys) do
      local spells = families[family]
      table.sort(spells, spell_sort_level)

      local existing_family_slot = nil
      if magic_family_slots[category] and magic_family_slots[category][family] then
        existing_family_slot = magic_family_slots[category][family]
      elseif magic_family_slots.all_magic and magic_family_slots.all_magic[family] then
        existing_family_slot = magic_family_slots.all_magic[family]
      end
      if not existing_family_slot and pinned_magic_families then
        local pf = pinned_magic_families[category]
        local pm = pinned_magic_families.all_magic
        local p = (pf and pf[family]) or (pm and pm[family])
        if p and p.env == env and p.row == row then
          existing_family_slot = p
        end
      end

      local target_env = env
      local target_row = row
      local target_slot = nil

      if existing_family_slot then
        target_env = existing_family_slot.env
        target_row = existing_family_slot.row
        target_slot = existing_family_slot.slot
        existing_slots[target_env] = existing_slots[target_env] or {}
        existing_slots[target_env][target_row] = existing_slots[target_env][target_row] or {}
        existing_slots[target_env][target_row][target_slot] = true
      else
        target_slot = find_empty_virtual_slot(existing_slots, target_env, target_row, columns)
      end

      if target_slot then
        for _, spell in ipairs(spells) do
          add_slot_line(generated_lines, existing_actions, spell, target_env, target_row, target_slot)
        end
      else
        table.insert(overflow, { action = family .. ' spell family', category = category })
      end
    end
  end

  if pinned_magic_families then
    for category, families in pairs(magic_grouped) do
      if category_matches_filter(category, filter) then
        local pref = get_magic_pref(prefs, category)
        if pref then
          local env = pref.env or 'battle'
          local row = tonumber(pref.bar or pref.row or 4) or 4
          if target_matches_filter(env, row, filter) then
            for family, _ in pairs(families) do
              local pf = pinned_magic_families[category]
              local pm = pinned_magic_families.all_magic
              local p = (pf and pf[family]) or (pm and pm[family])
              if p and p.env == env and p.row == row then
                existing_slots[p.env] = existing_slots[p.env] or {}
                existing_slots[p.env][p.row] = existing_slots[p.env][p.row] or {}
                existing_slots[p.env][p.row][p.slot] = true
              end
            end
          end
        end
      end
    end
  end

  local tasks = {}
  for _, category in ipairs({ 'main', 'sub', 'ws', 'item' }) do
    if grouped[category] and #grouped[category] > 0 then
      tasks[#tasks + 1] = { cat = category, ord = 0, fn = place_normal }
    end
  end
  for category in pairs(magic_choice_grouped) do
    tasks[#tasks + 1] = { cat = category, ord = 1, fn = place_magic_choice }
  end
  for category in pairs(magic_grouped) do
    tasks[#tasks + 1] = { cat = category, ord = 2, fn = place_magic }
  end
  table.sort(tasks, function(a, b)
    local ra, rb = bar_rank(a.cat), bar_rank(b.cat)
    if ra ~= rb then return ra < rb end
    if a.cat ~= b.cat then return tostring(a.cat) < tostring(b.cat) end
    return a.ord < b.ord
  end)
  for _, t in ipairs(tasks) do t.fn(t.cat) end

  return generated_lines, overflow
end

local function current_weapon_has_learned_ws(player)
  if not player then return false end
  local skill_lookup = {}
  if tonumber(player.current_weapon or 0) and tonumber(player.current_weapon or 0) ~= 0 then
    skill_lookup[tonumber(player.current_weapon)] = true
  end
  if tonumber(player.current_range_weapon or 0) and tonumber(player.current_range_weapon or 0) ~= 0 then
    skill_lookup[tonumber(player.current_range_weapon)] = true
  end
  if next(skill_lookup) == nil then return false end

  local abilities = windower.ffxi.get_abilities() or {}
  for _, ws_id in pairs(abilities.weapon_skills or {}) do
    local ws = resources.weapon_skills[ws_id]
    if ws and skill_lookup[tonumber(ws.skill)] then return true end
  end
  return false
end

local function choice_group_for_weapon_name(player, weapon_name)
  init_weapon_keys()
  local key = normalize_key(weapon_name or '')
  if key == '' or key == 'current' or key == 'weapon' or key == 'weaponskills' or key == 'weapon_skills' or key == 'ws' then
    return 'ws_current', 'WS'
  end
  if key == 'main' then return 'ws_main', 'MainWS' end
  if key == 'range' or key == 'ranged' then return 'ws_range', 'RngWS' end
  if WEAPONSKILL_TYPE_KEYS[key] then
    local skill_id = WEAPONSKILL_TYPE_KEYS[key]
    local label = WEAPONSKILL_TYPES[skill_id] or weapon_name
    return 'ws_' .. key, shorten_name(label .. ' WS')
  end
  return 'ws_' .. key, 'WS'
end

local function remove_ws_lines_for_bar(lines, env, row, slot)
  local out = {}
  local removed = 0
  for _, line in ipairs(lines) do
    local a = parse_action_line(line)
    if a and a.has_valid_slot and a.env == env and a.row == row then
      local action_type = tostring(a.type or ''):lower()
      if action_type == 'ws' or (a.slot == slot and action_type == 'choice') then
        removed = removed + 1
      else
        table.insert(out, line)
      end
    else
      table.insert(out, line)
    end
  end
  return out, removed
end

function hotbar_tools:set_chat_forced(v)
  chat_force = v == true
end

function hotbar_tools:reset_warnings()
  WARNED = {}
end

function hotbar_tools:warn_once(key, msg)
  key = tostring(key or msg or 'warning')
  if WARNED[key] then return end
  WARNED[key] = true
  chat(msg)
end

function hotbar_tools:file_exists(path)
  return file_exists(path)
end

function hotbar_tools:resolve_category(category)
  local key = normalize_key(category)
  return NORMAL_CATEGORY_ALIASES[key] or MAGIC_CATEGORY_ALIASES[key] or PET_SECTION_ALIASES[key]
end

function hotbar_tools:is_magic_category(category)
  local key = normalize_key(category)
  local resolved = MAGIC_CATEGORY_ALIASES[key] or category
  return MAGIC_CATEGORY_LABELS[resolved] ~= nil
end

function hotbar_tools:get_paths(player)
  return get_paths(player)
end

function hotbar_tools:load_preferences(player)
  local paths = get_paths(player)
  local prefs = copy_table(DEFAULT_PREFS)

  local f = loadfile(paths.prefs)
  if f then
    local ok, loaded = pcall(f)
    if ok and type(loaded) == 'table' then
      if type(loaded.battle) == 'table' then
        for k, v in pairs(loaded.battle) do prefs.battle[k] = tonumber(v) or prefs.battle[k] end
      end
      if type(loaded.field) == 'table' then
        for k, v in pairs(loaded.field) do prefs.field[k] = tonumber(v) or prefs.field[k] end
      end
      if type(loaded.magic) == 'table' then
        prefs.magic = {}
        for k, v in pairs(loaded.magic) do
          local cat = MAGIC_CATEGORY_ALIASES[normalize_key(k)] or k
          if cat ~= 'all_magic' and MAGIC_CATEGORY_LABELS[cat] ~= nil then
            if type(v) == 'table' then
              prefs.magic[cat] = { env = normalize_env(v.env or v.environment or 'battle') or 'battle', bar = tonumber(v.bar or v.row) or 4 }
            elseif tonumber(v) then
              prefs.magic[cat] = { env = 'battle', bar = tonumber(v) }
            end
          end
        end
      end
      if type(loaded.pet) == 'table' then
        prefs.pet = {}
        for k, v in pairs(loaded.pet) do
          local cat = PET_SECTION_ALIASES[normalize_key(k)] or k
          if PET_SECTION_LABELS[cat] ~= nil then
            if type(v) == 'table' then
              prefs.pet[cat] = { env = normalize_env(v.env or v.environment or 'battle') or 'battle', bar = tonumber(v.bar or v.row) or 1 }
            elseif tonumber(v) then
              prefs.pet[cat] = { env = 'battle', bar = tonumber(v) }
            end
          end
        end
      end
      if type(loaded.sub_populated) == 'table' then
        prefs.sub_populated = {}
        for k, _ in pairs(loaded.sub_populated) do
          prefs.sub_populated[tostring(k)] = true
        end
      end
      if type(loaded.leading) == 'table' then
        prefs.leading = loaded.leading
      end
      prefs.overlay = loaded.overlay == true
      if type(loaded.excluded) == 'table' then
        prefs.excluded = {}
        for k, _ in pairs(loaded.excluded) do prefs.excluded[tostring(k)] = true end
      end
      if type(loaded.order) == 'table' then
        prefs.order = {}
        for cat, list in pairs(loaded.order) do
          if type(list) == 'table' then
            local keys = {}
            for _, k in ipairs(list) do keys[#keys + 1] = tostring(k) end
            if #keys > 0 then prefs.order[tostring(cat)] = keys end
          end
        end
      end
      if type(loaded.bar_order) == 'table' then
        prefs.bar_order = {}
        local seen = {}
        for _, k in ipairs(loaded.bar_order) do
          local key = tostring(k)
          if not seen[key] then seen[key] = true; prefs.bar_order[#prefs.bar_order + 1] = key end
        end
      end
    end
  end

  return prefs
end

function hotbar_tools:save_preferences(player, prefs)
  local paths = get_paths(player)
  local magic_keys = {}
  if type(prefs.magic) == 'table' then
    for k, _ in pairs(prefs.magic) do table.insert(magic_keys, k) end
  end
  table.sort(magic_keys)

  local normal_cats = { 'main', 'sub', 'ws', 'item' }
  local lines = { 'return {', '  battle = {' }
  for _, cat in ipairs(normal_cats) do
    if prefs.battle[cat] then
      table.insert(lines, '    ' .. cat .. ' = ' .. tostring(prefs.battle[cat]) .. ',')
    end
  end
  table.insert(lines, '  },')
  table.insert(lines, '  field = {')
  for _, cat in ipairs(normal_cats) do
    if prefs.field[cat] then
      table.insert(lines, '    ' .. cat .. ' = ' .. tostring(prefs.field[cat]) .. ',')
    end
  end
  table.insert(lines, '  },')
  table.insert(lines, '  magic = {')

  for _, k in ipairs(magic_keys) do
    local v = prefs.magic[k]
    if type(v) == 'table' then
      table.insert(lines, "    ['" .. k .. "'] = { env = '" .. (v.env or 'battle') .. "', bar = " .. tostring(v.bar) .. ' },')
    end
  end

  table.insert(lines, '  },')
  if type(prefs.pet) == 'table' and next(prefs.pet) then
    local pet_keys = {}
    for k, _ in pairs(prefs.pet) do table.insert(pet_keys, k) end
    table.sort(pet_keys)
    table.insert(lines, '  pet = {')
    for _, k in ipairs(pet_keys) do
      local v = prefs.pet[k]
      if type(v) == 'table' then
        table.insert(lines, "    ['" .. k .. "'] = { env = '" .. (v.env or 'battle') .. "', bar = " .. tostring(v.bar) .. ' },')
      end
    end
    table.insert(lines, '  },')
  end
  if type(prefs.sub_populated) == 'table' and next(prefs.sub_populated) then
    local sub_keys = {}
    for k, _ in pairs(prefs.sub_populated) do table.insert(sub_keys, k) end
    table.sort(sub_keys)
    table.insert(lines, '  sub_populated = {')
    for _, k in ipairs(sub_keys) do
      table.insert(lines, '    [' .. quote_lua_string(k) .. '] = true,')
    end
    table.insert(lines, '  },')
  end
  if prefs.overlay == true then
    table.insert(lines, '  overlay = true,')
  end
  if type(prefs.excluded) == 'table' and next(prefs.excluded) then
    local ex_keys = {}
    for k, _ in pairs(prefs.excluded) do table.insert(ex_keys, k) end
    table.sort(ex_keys)
    table.insert(lines, '  excluded = {')
    for _, k in ipairs(ex_keys) do
      table.insert(lines, '    [' .. quote_lua_string(k) .. '] = true,')
    end
    table.insert(lines, '  },')
  end
  if type(prefs.order) == 'table' and next(prefs.order) then
    local cat_keys = {}
    for k, _ in pairs(prefs.order) do table.insert(cat_keys, k) end
    table.sort(cat_keys)
    table.insert(lines, '  order = {')
    for _, cat in ipairs(cat_keys) do
      local parts = {}
      for _, k in ipairs(prefs.order[cat]) do parts[#parts + 1] = quote_lua_string(k) end
      table.insert(lines, '    [' .. quote_lua_string(cat) .. '] = { ' .. table.concat(parts, ', ') .. ' },')
    end
    table.insert(lines, '  },')
  end
  if type(prefs.bar_order) == 'table' and #prefs.bar_order > 0 then
    local parts = {}
    for _, k in ipairs(prefs.bar_order) do parts[#parts + 1] = quote_lua_string(k) end
    table.insert(lines, '  bar_order = { ' .. table.concat(parts, ', ') .. ' },')
  end
  table.insert(lines, '}')
  return write_lines(paths.prefs, lines)
end

function hotbar_tools:parse_setbar_args(args)
  local bar_index = nil
  for i = 1, #args do
    if tonumber(args[i]) then
      bar_index = i
      break
    end
  end

  if not bar_index then return nil, nil, nil end

  local category_parts = {}
  for i = 1, bar_index - 1 do table.insert(category_parts, args[i]) end
  local category = table.concat(category_parts, ' ')
  local bar = tonumber(args[bar_index])
  local env = args[bar_index + 1] or 'battle'

  return category, bar, env
end

function hotbar_tools:set_category_bar(player, category, bar, env)
  local resolved = self:resolve_category(category)
  bar = tonumber(bar)
  env = normalize_env(env or 'battle') or 'battle'

  if not resolved then
    chat('XIVHOTBAR2: Unknown category. Use main, sub, ws, item, dark magic, elemental magic, healing magic, enhancing magic, enfeebling magic, divine magic, blue magic, ninjutsu, songs, summoning, geomancy, indi geomancy, geo geomancy, trust, blood rage, blood ward, wyvern, automaton, or beast.')
    return false
  end

  if not bar or bar < 1 or bar > 6 then
    chat('XIVHOTBAR2: Invalid hotbar number. Use 1-6.')
    return false
  end

  local prefs = self:load_preferences(player)
  append_bar_order(prefs, resolved)
  if MAGIC_CATEGORY_LABELS[resolved] then
    prefs.magic[resolved] = { env = env, bar = bar }
    chat(string.format('XIVHOTBAR2: Auto-generate category "%s" will use %s hotbar %d.', MAGIC_CATEGORY_LABELS[resolved], env, bar))
  elseif PET_SECTION_LABELS[resolved] then
    prefs.pet = prefs.pet or {}
    prefs.pet[resolved] = { env = env, bar = bar }
    chat(string.format('XIVHOTBAR2: Auto-generate pet section "%s" will use %s hotbar %d.', PET_SECTION_LABELS[resolved], env, bar))
  else
    prefs[env][resolved] = bar
    chat(string.format('XIVHOTBAR2: Auto-generate category "%s" will use %s hotbar %d.', resolved, env, bar))
  end
  self:save_preferences(player, prefs)
  return true
end

function hotbar_tools:unset_category_bar(player, category)
  local resolved = self:resolve_category(category)
  if not resolved or (not MAGIC_CATEGORY_LABELS[resolved] and not PET_SECTION_LABELS[resolved]) then
    chat('XIVHOTBAR2: unsetbar disables magic categories or pet sections, e.g. //htb unsetbar black magic, //htb unsetbar beast')
    return false
  end

  local prefs = self:load_preferences(player)
  remove_bar_order(prefs, resolved)
  if MAGIC_CATEGORY_LABELS[resolved] then
    prefs.magic[resolved] = nil
    chat('XIVHOTBAR2: disabled autogenerated ' .. MAGIC_CATEGORY_LABELS[resolved] .. '.')
  else
    prefs.pet = prefs.pet or {}
    prefs.pet[resolved] = nil
    chat('XIVHOTBAR2: disabled autogenerated pet section ' .. PET_SECTION_LABELS[resolved] .. '.')
  end
  self:save_preferences(player, prefs)
  return true
end

function hotbar_tools:print_preferences(player)
  local prefs = self:load_preferences(player)
  chat('XIVHOTBAR2 autogen bars:')
  chat(string.format('  battle: main=%s sub=%s ws=%s item=%s', prefs.battle.main, prefs.battle.sub, prefs.battle.ws, prefs.battle.item))
  chat(string.format('  field:  main=%s sub=%s ws=%s item=%s', prefs.field.main, prefs.field.sub, prefs.field.ws, prefs.field.item))
  chat('  magic categories enabled:')

  local keys = {}
  for k, _ in pairs(prefs.magic or {}) do table.insert(keys, k) end
  table.sort(keys)
  if #keys == 0 then
    chat('    none. Use //htb setbar black magic 3 to enable one.')
  else
    for _, k in ipairs(keys) do
      local v = prefs.magic[k]
      chat(string.format('    %s = %s hotbar %s', MAGIC_CATEGORY_LABELS[k] or k, v.env or 'battle', tostring(v.bar or '?')))
    end
  end
  chat('  pet sections enabled:')
  local pet_keys = {}
  for k, _ in pairs(prefs.pet or {}) do table.insert(pet_keys, k) end
  table.sort(pet_keys)
  if #pet_keys == 0 then
    chat('    none. Use //htb setbar beast 2 to enable one.')
  else
    for _, k in ipairs(pet_keys) do
      local v = prefs.pet[k]
      chat(string.format('    %s = %s hotbar %s', PET_SECTION_LABELS[k] or k, v.env or 'battle', tostring(v.bar or '?')))
    end
  end
end

function hotbar_tools:validate_current(player, theme_options)
  local paths = get_paths(player)
  local max_rows = tonumber(theme_options.rows or theme_options.hotbar_number or 6) or 6
  local max_slots = tonumber(theme_options.columns or 12) or 12
  local spell_lookup = build_lower_lookup(resources.spells)
  local ability_lookup = build_lower_lookup(resources.job_abilities)
  local ws_lookup = build_lower_lookup(resources.weapon_skills)
  local warning_count = 0

  local function warn(path, line_no, msg)
    warning_count = warning_count + 1
    chat(string.format('XIVHOTBAR2 validate: %s:%d: %s', path:match('[^/\\]+$') or path, line_no, msg))
  end

  local function validate_file(path)
    local lines = read_lines(path)
    if #lines == 0 then
      warn(path, 1, 'file could not be opened or is empty')
      return
    end

    for line_no, line in ipairs(lines) do
      if line:find('{', 1, true) and not line:match('^%s*%-%-') then
        local a = parse_action_line(line)
        if a then
          if not a.has_valid_slot then
            warn(path, line_no, 'invalid slot designation. Expected "battle 1 1" or "field 1 1"')
          else
            if a.row < 1 or a.row > max_rows then warn(path, line_no, 'hotbar row is outside configured range') end
            if a.slot < 1 or a.slot > 999 then warn(path, line_no, 'slot is outside configured range') end
          end

          local action_type = tostring(a.type or ''):lower()
          if not VALID_TYPES[action_type] then
            warn(path, line_no, 'unknown action type "' .. tostring(a.type) .. '"')
          end

          if action_type == 'choice' and a.action and not choice_groups:exists(a.action) then
            warn(path, line_no, 'unknown choice group "' .. a.action .. '"')
          end

          if (action_type == 'ma' or action_type == 'ja' or action_type == 'ws') and (not a.action or a.action == '') then
            warn(path, line_no, 'missing action name')
          elseif action_type == 'ma' and a.action and not spell_lookup[a.action:lower()] then
            warn(path, line_no, 'unknown spell "' .. a.action .. '"')
          elseif action_type == 'ja' and a.action and not ability_lookup[a.action:lower()] then
            warn(path, line_no, 'unknown job ability "' .. a.action .. '"')
          elseif action_type == 'ws' and a.action and not ws_lookup[a.action:lower()] then
            warn(path, line_no, 'unknown weaponskill "' .. a.action .. '"')
          end

          if a.icon and a.icon ~= '' then
            local icon_path = HTB_ART .. 'icons/custom/' .. a.icon .. '.png'
            if not file_exists(icon_path) then
              warn(path, line_no, 'missing custom icon images/icons/custom/' .. a.icon .. '.png')
            end
          end
        end
      end
    end
  end

  validate_file(paths.job)
  validate_file(paths.general)

  if warning_count == 0 then
    chat('XIVHOTBAR2 validate: no problems found.')
  else
    chat('XIVHOTBAR2 validate: ' .. tostring(warning_count) .. ' warning(s).')
  end
end

function hotbar_tools:reset_bar(player, env, bar)
  env = normalize_env(env or 'battle') or 'battle'
  bar = tonumber(bar)
  if not bar or bar < 1 or bar > 6 then
    chat('XIVHOTBAR2: resetbar needs a hotbar number 1-6.')
    return false
  end

  local paths = get_paths(player)
  local removed = 0

  local function reset_file(path)
    local lines = read_lines(path)
    if #lines == 0 then return end
    local out = {}
    for _, line in ipairs(lines) do
      local a = parse_action_line(line)
      if a and a.has_valid_slot and a.env == env and a.row == bar then
        removed = removed + 1
      else
        table.insert(out, line)
      end
    end
    write_lines(path, out)
  end

  if env == 'field' then
    reset_file(paths.general)
  else
    reset_file(paths.job)
  end
  chat(string.format('XIVHOTBAR2: reset %s hotbar %d to empty state. Removed %d action line(s).', env, bar, removed))
  return true
end

function hotbar_tools:reset_slot(player, env, row, slot)
  env = normalize_env(env or 'battle') or 'battle'
  row = tonumber(row)
  slot = tonumber(slot)
  if not row or row < 1 or not slot or slot < 1 then
    chat('XIVHOTBAR2: resetslot needs a hotbar row and slot number.')
    return false
  end

  local paths = get_paths(player)
  local removed = 0

  local function reset_file(path)
    local lines = read_lines(path)
    if #lines == 0 then return end
    local out = {}
    for _, line in ipairs(lines) do
      local a = parse_action_line(line)
      if a and a.has_valid_slot and a.env == env and a.row == row and a.slot == slot then
        removed = removed + 1
      else
        table.insert(out, line)
      end
    end
    write_lines(path, out)
  end

  if env == 'field' then
    reset_file(paths.general)
  else
    reset_file(paths.job)
  end

  if removed > 0 then
    chat(string.format('XIVHOTBAR2: cleared %s hotbar slot %d-%d (%d line(s) removed).', env, row, slot, removed))
    return true
  else
    chat(string.format('XIVHOTBAR2: no action found in %s hotbar slot %d-%d.', env, row, slot))
    return false
  end
end

function hotbar_tools:reset_all(player, env)
  env = normalize_env(env)
  local paths = get_paths(player)
  local removed = 0

  local function reset_file(path)
    local lines = read_lines(path)
    if #lines == 0 then return end
    local out = {}
    for _, line in ipairs(lines) do
      local a = parse_action_line(line)
      if a and a.has_valid_slot and (not env or a.env == env) then
        removed = removed + 1
      else
        table.insert(out, line)
      end
    end
    write_lines(path, out)
  end

  if env == 'field' then
    reset_file(paths.general)
  elseif env == 'battle' then
    reset_file(paths.job)
  else
    reset_file(paths.job)
    reset_file(paths.general)
  end

  local empty_prefs = { battle = {}, field = {}, magic = {}, pet = {} }
  self:save_preferences(player, empty_prefs)

  if env then
    chat(string.format('XIVHOTBAR2: reset all %s hotbars and setbar config to empty state. Removed %d action line(s).', env, removed))
  else
    chat(string.format('XIVHOTBAR2: reset all hotbars and setbar config to empty state. Removed %d action line(s).', removed))
  end
  return true
end

function hotbar_tools:collect_generated_entries(player, theme_options, prefs)
  local entries = {}
  local abilities = windower.ffxi.get_abilities() or {}
  local player_spells = windower.ffxi.get_spells() or {}
  local paths = get_paths(player)
  local covered_action_keys = {}
  merge_action_keys(covered_action_keys, AUTOGEN_SUPPRESSED_ACTION_KEYS)
  local choice_entries = choice_groups:get_autogen_entries(player)

  local has_indi_pref = prefs and type(prefs.magic) == 'table' and prefs.magic['indi_geomancy'] ~= nil
  local has_geo_pref  = prefs and type(prefs.magic) == 'table' and prefs.magic['geo_geomancy']  ~= nil

  for group_id, _ in pairs(collect_existing_choice_group_ids(paths)) do
    if not (group_id == 'geomancy_indi' and has_indi_pref) and
       not (group_id == 'geomancy_geo'  and has_geo_pref) then
      merge_action_keys(covered_action_keys, choice_groups:get_group_action_keys(group_id, player))
    end
  end

  for _, entry in ipairs(choice_entries) do
    if (entry.action == 'geomancy_indi' and has_indi_pref) or
       (entry.action == 'geomancy_geo'  and has_geo_pref) then

    else
      table.insert(entries, entry)
      merge_action_keys(covered_action_keys, choice_groups:get_group_action_keys(entry.action, player))
    end
  end

  local function add_ja_entry(ability_id)
    local ability = first_existing_resource(resources.job_abilities, ability_id)
              or priv_job_abilities[tonumber(ability_id) or ability_id]
    if ability and ability.en and ability.en ~= ''
        and not is_autogen_suppressed_action('ja', ability.en)
        and not covered_action_keys[action_key('ja', ability.en)] then
      local category, level = category_for_ability(player, tonumber(ability.id or ability_id) or ability_id)
      if category then
        covered_action_keys[action_key('ja', ability.en)] = true
        table.insert(entries, {
          category = category,
          type = 'ja',
          action = ability.en,
          target = get_default_target('ja', ability),
          alias = shorten_name(ability.en),
          level = level,
        })
      end
    end
  end

  local ja_list = abilities.job_abilities or {}
  local has_ja = false
  for _ in pairs(ja_list) do has_ja = true; break end
  if has_ja then
    for _, ability_id in pairs(ja_list) do
      add_ja_entry(ability_id)
    end
  elseif player.main_job_id and player.main_job_id > 0 then
    local eff_sub = effective_subjob_level(player.main_job_level, player.sub_job_level)
    for ab_id, data in pairs(ability_level_list) do
      if type(data) == 'table' and type(data.levels) == 'table' then
        local main_req = data.levels[player.main_job_id]
        local sub_req = player.sub_job_id and data.levels[player.sub_job_id]
        if (main_req and (player.main_job_level or 0) >= main_req)
            or (sub_req and eff_sub >= sub_req) then
          add_ja_entry(ab_id)
        end
      end
    end
  end
  for priv_ab_id, priv_ab in pairs(priv_job_abilities) do
    if type(priv_ab) == 'table' and tostring(priv_ab.type or '') == 'PetCommand' then
      local num_id = tonumber(priv_ab_id) or 0
      local level_data = ability_level_list[num_id]
      if level_data and type(level_data.levels) == 'table' then
        local main_level = level_data.levels[player.main_job_id]
        local sub_level = level_data.levels[player.sub_job_id]
        local eff_sub = effective_subjob_level(player.main_job_level, player.sub_job_level)
        if (main_level and player.main_job_level >= main_level)
            or (sub_level and eff_sub >= sub_level) then
          add_ja_entry(num_id)
        end
      end
    end
  end

  local include_unlearned = not (theme_options and theme_options.auto_hide_unusable == true)
  if include_unlearned then
    for ab_id, data in pairs(ability_level_list) do
      if type(data) == 'table' and type(data.levels) == 'table' and data.levels[player.main_job_id] then
        local ability = first_existing_resource(resources.job_abilities, ab_id) or priv_job_abilities[tonumber(ab_id) or ab_id]
        if ability and ability.en and ability.en ~= ''
            and not is_autogen_suppressed_action('ja', ability.en)
            and not covered_action_keys[action_key('ja', ability.en)] then
          covered_action_keys[action_key('ja', ability.en)] = true
          table.insert(entries, {
            category = 'main', type = 'ja', action = ability.en,
            target = get_default_target('ja', ability), alias = shorten_name(ability.en),
            level = data.levels[player.main_job_id],
          })
        end
      end
    end
  end

  if current_weapon_has_learned_ws(player) then
    table.insert(entries, {
      category = 'ws',
      type = 'choice',
      action = 'ws_current',
      target = '',
      alias = 'WS',
      level = 0,
    })
  end

  local spell_lookup_by_id = resources.spells or {}
  if theme_options and theme_options.playing_on_horizon == true and type(horizon_spell_list) == 'table' and next(horizon_spell_list) then
    spell_lookup_by_id = horizon_spell_list
  end
  local is_blu = player and player.main_job == 'BLU'
  local blu_set_ids = {}
  if is_blu and player.set_blue_magic then
    for _, sid in pairs(player.set_blue_magic) do
      blu_set_ids[tonumber(sid)] = true
    end
  end

  for spell_id, known in pairs(player_spells) do
    if known == true then
      local spell = first_existing_resource(spell_lookup_by_id, spell_id)
      if spell and spell.en and spell.en ~= '' and not covered_action_keys[action_key('ma', spell.en)] then
        local level = spell_access_level(player, spell)
        if level ~= nil then
          local skip = false
          if is_blu and spell.type == 'BlueMagic' then
            local sid = tonumber(spell_id)
            if not UNBRIDLED_SPELL_IDS[sid] and not blu_set_ids[sid] then
              skip = true
            end
          end
          if not skip then
            local category = detect_magic_category(spell)
            table.insert(entries, {
              category = category,
              family = spell_family_key(spell.en),
              type = 'ma',
              action = spell.en,
              target = get_default_target('ma', spell),
              alias = shorten_name(spell.en),
              level = level or 0,
            })
          end
        end
      end
    end
  end

  if include_unlearned then
    for spell_id, spell in pairs(spell_lookup_by_id) do
      if spell and spell.en and spell.en ~= '' and type(spell.levels) == 'table'
          and spell.levels[player.main_job_id]
          and not covered_action_keys[action_key('ma', spell.en)] then
        local skip = false
        if is_blu and spell.type == 'BlueMagic' then
          local sid = tonumber(spell_id)
          if not UNBRIDLED_SPELL_IDS[sid] and not blu_set_ids[sid] then skip = true end
        end
        local mcat = detect_magic_category(spell)
        if not skip and mcat and mcat ~= 'trust' then
          covered_action_keys[action_key('ma', spell.en)] = true
          table.insert(entries, {
            category = mcat, family = spell_family_key(spell.en), type = 'ma', action = spell.en,
            target = get_default_target('ma', spell), alias = shorten_name(spell.en),
            level = spell.levels[player.main_job_id],
          })
        end
      end
    end
  end

  apply_job_priorities(player, entries)
  apply_order_overrides(prefs, entries)

  for _, entry in ipairs(entries) do
    if not entry.icon or entry.icon == '' then
      local key = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      local icon = ACTION_ICONS[key]
      if icon then entry.icon = icon end
    end
  end

  return entries
end

local NORMAL_CATEGORY_LABELS = { main = 'Job Abilities', sub = 'Subjob', ws = 'Weapon Skills', item = 'Items' }

function hotbar_tools:category_label(category)
  return NORMAL_CATEGORY_LABELS[category] or MAGIC_CATEGORY_LABELS[category] or tostring(category or '?')
end

function hotbar_tools:collect_preview_entries(player, theme_options)
  local prefs = self:load_preferences(player)
  local entries, covered = {}, {}
  merge_action_keys(covered, AUTOGEN_SUPPRESSED_ACTION_KEYS)

  for _, entry in ipairs(choice_groups:get_autogen_entries(player)) do
    if entry.category ~= 'trust' and tostring(entry.action or '') ~= 'trust_custom' then
      entry.known, entry.accessible = true, true
      table.insert(entries, entry)
      merge_action_keys(covered, choice_groups:get_group_action_keys(entry.action, player))
    end
  end

  local known_ja = {}
  local ab_lists = windower.ffxi.get_abilities() or {}
  for _, id in pairs(ab_lists.job_abilities or {}) do known_ja[tonumber(id) or id] = true end
  for _, id in pairs(ab_lists.pet_commands or {}) do known_ja[tonumber(id) or id] = true end

  for ab_id, data in pairs(ability_level_list) do
    if type(data) == 'table' and type(data.levels) == 'table' then
      local lvl, cat = data.levels[player.main_job_id], nil
      if lvl then cat = 'main'
      elseif player.sub_job_id and data.levels[player.sub_job_id] then
        lvl, cat = data.levels[player.sub_job_id], 'sub'
      end
      if cat then
        local ability = first_existing_resource(resources.job_abilities, ab_id)
                  or priv_job_abilities[tonumber(ab_id) or ab_id]
        if ability and ability.en and ability.en ~= ''
            and not is_autogen_suppressed_action('ja', ability.en)
            and not covered[action_key('ja', ability.en)] then
          covered[action_key('ja', ability.en)] = true
          local acc = (category_for_ability(player, tonumber(ab_id) or ab_id)) ~= nil
          table.insert(entries, {
            category = cat, type = 'ja', action = ability.en,
            target = get_default_target('ja', ability), alias = shorten_name(ability.en),
            level = lvl, accessible = acc, known = acc or known_ja[tonumber(ab_id) or ab_id] == true,
          })
        end
      end
    end
  end

  table.insert(entries, { category = 'ws', type = 'choice', action = 'ws_current',
    target = '', alias = 'WS', level = 0, known = true, accessible = true })

  local player_spells = windower.ffxi.get_spells() or {}
  local spell_lookup = resources.spells or {}
  if theme_options and theme_options.playing_on_horizon == true
      and type(horizon_spell_list) == 'table' and next(horizon_spell_list) then
    spell_lookup = horizon_spell_list
  end
  for spell_id, spell in pairs(spell_lookup) do
    if spell and spell.en and spell.en ~= '' and type(spell.levels) == 'table'
        and not covered[action_key('ma', spell.en)] then
      local lvl = spell.levels[player.main_job_id]
      if not lvl and player.sub_job_id then lvl = spell.levels[player.sub_job_id] end
      local mcat = lvl and lvl >= 1 and detect_magic_category(spell) or nil
      if mcat and mcat ~= 'trust' then
        covered[action_key('ma', spell.en)] = true
        table.insert(entries, {
          category = mcat, family = spell_family_key(spell.en),
          type = 'ma', action = spell.en, target = get_default_target('ma', spell),
          alias = shorten_name(spell.en), level = lvl,
          accessible = spell_access_level(player, spell) ~= nil,
          known = player_spells[spell_id] == true,
        })
      end
    end
  end

  apply_job_priorities(player, entries)
  apply_order_overrides(prefs, entries)
  table.sort(entries, sort_generated)

  for _, entry in ipairs(entries) do
    if not entry.icon or entry.icon == '' then
      local icon = ACTION_ICONS[action_key(entry.type, entry.action)]
      if icon then entry.icon = icon end
    end
  end
  return entries, prefs
end

function hotbar_tools:build_overlay_placements(player, theme_options, live_hotbar)
  local prefs = self:load_preferences(player)
  local entries = self:collect_generated_entries(player, theme_options, prefs)
  local excluded = prefs.excluded or {}
  local kept = {}
  for _, e in ipairs(entries) do
    if not excluded[action_key(e.type, e.action)]
        and e.category ~= 'trust' and tostring(e.action or '') ~= 'trust_custom' then
      table.insert(kept, e)
    end
  end

  local existing_slots = { battle = {}, field = {} }
  if type(live_hotbar) == 'table' then
    for _, env in ipairs({ 'battle', 'field' }) do
      local et = live_hotbar[env]
      if type(et) == 'table' then
        for rk, row in pairs(et) do
          local r = tonumber(tostring(rk):match('hotbar_(%d+)'))
          if r and type(row) == 'table' then
            for sk, a in pairs(row) do
              local s = tonumber(tostring(sk):match('slot_(%d+)'))
              if s and type(a) == 'table' and a.is_dynamic == true then
                existing_slots[env][r] = existing_slots[env][r] or {}
                existing_slots[env][r][s] = true
              end
            end
          end
        end
      end
    end
  end

  capture_placements = {}
  place_entries(kept, prefs, theme_options, existing_slots, {}, {}, nil)
  local placements = capture_placements
  capture_placements = nil

  local bars = { battle = {}, field = {} }
  for _, cat in ipairs({ 'main', 'sub', 'ws', 'item' }) do
    if prefs.battle[cat] then bars.battle[tonumber(prefs.battle[cat])] = true end
    if prefs.field[cat] then bars.field[tonumber(prefs.field[cat])] = true end
  end
  for _, v in pairs(prefs.magic or {}) do
    if type(v) == 'table' and tonumber(v.bar) then
      local env = v.env or 'battle'
      bars[env] = bars[env] or {}
      bars[env][tonumber(v.bar)] = true
    end
  end
  for _, v in pairs(prefs.pet or {}) do
    if type(v) == 'table' and tonumber(v.bar) then
      local env = v.env or 'battle'
      bars[env] = bars[env] or {}
      bars[env][tonumber(v.bar)] = true
    end
  end
  return placements, bars, prefs
end

function hotbar_tools:overlay_owns_bar(player, env, row)
  if not player then return false end
  local prefs = self:load_preferences(player)
  if prefs.overlay ~= true then return false end
  env = (env == 'b' and 'battle') or (env == 'f' and 'field') or env or 'battle'
  row = tonumber(row)
  if not row then return false end
  for _, cat in ipairs({ 'main', 'sub', 'ws', 'item' }) do
    if prefs[env] and tonumber(prefs[env][cat]) == row then return true end
  end
  for _, store in ipairs({ prefs.magic or {}, prefs.pet or {} }) do
    for _, v in pairs(store) do
      if type(v) == 'table' and tonumber(v.bar) == row and (v.env or 'battle') == env then return true end
    end
  end
  return false
end

function hotbar_tools:parse_autogen_filter(args)
  local filter = { bars = nil, categories = nil, env = nil }
  args = args or {}

  local joined = table.concat(args, ' ')
  if joined == '' then return nil end

  local function add_bar(n)
    n = tonumber(n)
    if n then
      filter.bars = filter.bars or {}
      filter.bars[n] = true
    end
  end

  local function add_category(name)
    local cat = self:resolve_category(name)
    if cat then
      filter.categories = filter.categories or {}
      filter.categories[cat] = true
      return true
    end
    return false
  end

  if add_category(joined) then return filter end

  local i = 1
  while i <= #args do
    local arg = tostring(args[i] or ''):lower()
    local env = normalize_env(arg)
    if env then
      filter.env = env
      i = i + 1
    elseif arg == 'bar' or arg == 'bars' or arg == 'hotbar' or arg == 'hotbars' then
      i = i + 1
      while i <= #args and tonumber(args[i]) do
        add_bar(args[i])
        i = i + 1
      end
    elseif tonumber(arg) then
      add_bar(arg)
      i = i + 1
    else
      if i < #args and add_category(arg .. ' ' .. tostring(args[i + 1])) then
        i = i + 2
      else
        add_category(arg)
        i = i + 1
      end
    end
  end

  if not filter.bars and not filter.categories and not filter.env then return nil end
  return filter
end

function hotbar_tools:autogenerate(player, theme_options, update_only, filter)
  local paths = get_paths(player)
  local prefs = self:load_preferences(player)
  local lines = read_lines(paths.job)

  if #lines == 0 then
    chat('XIVHOTBAR2: could not open current job file: ' .. paths.job)
    return false
  end

  local refresh_all = (not update_only and filter == nil)
  local pinned_slots, pinned_magic_families = {}, {}
  if refresh_all then
    pinned_slots, pinned_magic_families = collect_autogen_pinned_slots(paths)
    lines = remove_autogen_blocks(lines)
  end

  local entries = self:collect_generated_entries(player, theme_options, prefs)

  local SMN_AVATAR_SECTION_KEYS = {
    ['choice|ja_type_bloodpactrage'] = true,
    ['choice|ja_type_bloodpactward'] = true,
    ['ja|assault'] = true,
    ['ja|retreat'] = true,
    ["ja|avatar's favor"] = true,
    ['ja|astral flow'] = true,
    ['ja|elemental siphon'] = true,
    ['ja|mana cede'] = true,
  }
  local avatar_entries = {}
  if player and player.main_job_id == 15 then
    local base_entries = {}
    for _, entry in ipairs(entries) do
      local ekey = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      if SMN_AVATAR_SECTION_KEYS[ekey] then
        table.insert(avatar_entries, entry)
      else
        table.insert(base_entries, entry)
      end
    end
    entries = base_entries
  end

  local DRG_WYVERN_KEYS = {
    ['ja|smiting breath']   = true,
    ['ja|restoring breath'] = true,
    ['ja|steady wing']      = true,
    ['ja|spirit surge']     = true,
    ['ja|spirit link']      = true,
    ['ja|spirit bond']      = true,
  }
  local wyvern_entries = {}
  if player and player.main_job_id == 14 then
    local base_entries = {}
    for _, entry in ipairs(entries) do
      local ekey = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      if DRG_WYVERN_KEYS[ekey] then
        table.insert(wyvern_entries, entry)
      elseif ekey ~= 'ja|dismiss' then
        table.insert(base_entries, entry)
      end
    end
    entries = base_entries
  end

  local PUP_AUTOMATON_KEYS = {
    ['ja|deploy']            = true,
    ['ja|retrieve']          = true,
    ['choice|pup_maneuvers'] = true,
  }
  local automaton_entries = {}
  if player and player.main_job_id == 18 then
    local base_entries = {}
    for _, entry in ipairs(entries) do
      local ekey = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      if PUP_AUTOMATON_KEYS[ekey] then
        table.insert(automaton_entries, entry)
      else
        table.insert(base_entries, entry)
      end
    end
    entries = base_entries
  end

  local blu_unbridled_entries = {}
  if player and player.main_job == 'BLU' then
    local base_entries = {}
    for _, entry in ipairs(entries) do
      local ekey = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      if BLU_UNBRIDLED_KEYS[ekey] then
        table.insert(blu_unbridled_entries, entry)
      else
        table.insert(base_entries, entry)
      end
    end
    entries = base_entries
  end

  local covered_action_keys = {}
  merge_action_keys(covered_action_keys, AUTOGEN_SUPPRESSED_ACTION_KEYS)
  for _, entry in ipairs(entries) do
    if tostring(entry.type or ''):lower() == 'choice' then
      merge_action_keys(covered_action_keys, choice_groups:get_group_action_keys(entry.action, player))
    end
  end
  for group_id, _ in pairs(collect_existing_choice_group_ids(paths)) do
    merge_action_keys(covered_action_keys, choice_groups:get_group_action_keys(group_id, player))
  end

  local pruned = 0
  lines, pruned = remove_autogen_lines_matching_actions(lines, covered_action_keys)
  if pruned > 0 then
    write_lines(paths.job, lines)
    chat('XIVHOTBAR2: removed ' .. tostring(pruned) .. ' old autogenerated individual action line(s) now covered by choice buttons.')
  end

  local existing_slots, existing_actions, magic_family_slots = collect_existing(paths, true)
  if refresh_all then
    existing_slots, existing_actions, magic_family_slots = collect_existing(paths, false)
  end

  local generated_lines, overflow = place_entries(entries, prefs, theme_options, existing_slots, existing_actions, magic_family_slots, filter, pinned_slots, pinned_magic_families)
  local added_count = #generated_lines

  local start_i, end_i = find_base_section(lines)
  if not start_i or not end_i then
    chat('XIVHOTBAR2: current job file has no xivhotbar_keybinds_job[\'Base\'] section to insert into.')
    return false
  end

  if #generated_lines > 0 then
    local block = {}
    table.insert(block, '  ' .. AUTOGEN_START)
    table.insert(block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
    table.insert(block, '  -- Magic categories only generate after //htb setbar <magic category> <bar>.')
    table.insert(block, '  -- Delete these lines or use //htb resetbar <bar> / //htb resetall to clear.')
    for _, line in ipairs(generated_lines) do table.insert(block, line) end
    table.insert(block, '  ' .. AUTOGEN_END)

    for i = #block, 1, -1 do
      table.insert(lines, end_i, block[i])
    end
  end

  if #avatar_entries > 0 then
    lines = ensure_named_section(lines, 'Avatar')
    local _, av_end = find_named_section(lines, 'Avatar')
    local av_existing_slots, av_existing_actions = collect_existing(paths, not refresh_all)
    for _, genline in ipairs(generated_lines) do
      local a = parse_action_line(genline)
      if a and a.has_valid_slot then
        av_existing_slots[a.env] = av_existing_slots[a.env] or {}
        av_existing_slots[a.env][a.row] = av_existing_slots[a.env][a.row] or {}
        av_existing_slots[a.env][a.row][a.slot] = true
        if a.type and a.action then av_existing_actions[action_key(a.type, a.action)] = true end
      end
    end

    local function make_pet_prefs(section_key)
      local pet_pref = prefs.pet and prefs.pet[section_key]
      if not pet_pref then return prefs end
      local p = copy_table(prefs)
      p.battle.main = pet_pref.bar
      return p
    end

    local has_bp_bars = prefs.pet and (prefs.pet.blood_rage or prefs.pet.blood_ward)

    local other_av_entries = {}
    for _, entry in ipairs(avatar_entries) do
      local ekey = tostring(entry.type or ''):lower() .. '|' .. tostring(entry.action or ''):lower()
      local is_bp_choice = ekey == 'choice|ja_type_bloodpactrage' or ekey == 'choice|ja_type_bloodpactward'
      if not is_bp_choice or not has_bp_bars then
        table.insert(other_av_entries, entry)
      end
    end

    local all_av_lines = {}
    if #other_av_entries > 0 then
      local glines, gov = place_entries(other_av_entries, prefs, theme_options,
        av_existing_slots, av_existing_actions, {}, filter)
      for _, l in ipairs(glines) do table.insert(all_av_lines, l) end
      for _, ov in ipairs(gov) do table.insert(overflow, ov) end
    end

    added_count = added_count + #all_av_lines
    if #all_av_lines > 0 then
      local av_block = {}
      table.insert(av_block, '  ' .. AUTOGEN_START)
      table.insert(av_block, '  -- SMN Avatar section: appears on bar only when an avatar is summoned.')
      table.insert(av_block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
      for _, line in ipairs(all_av_lines) do table.insert(av_block, line) end
      table.insert(av_block, '  ' .. AUTOGEN_END)
      for i = #av_block, 1, -1 do
        table.insert(lines, av_end, av_block[i])
      end
    end

    local avatar_pacts_by_name = {}
    if has_bp_bars then
    for ab_id, ability in pairs(priv_job_abilities) do
      if type(ability) == 'table' then
        local av_name = AVATAR_BY_ICON_ID[tonumber(ability.icon_id or 0) or 0]
        local ab_type = tostring(ability.type or '')
        if av_name and (ab_type == 'BloodPactRage' or ab_type == 'BloodPactWard') then
          local category = category_for_ability(player, tonumber(ab_id) or 0)
          if category == nil and player and player.main_job_id == 15 then category = 'main' end
          if category then
            avatar_pacts_by_name[av_name] = avatar_pacts_by_name[av_name] or { rage = {}, ward = {} }
            local bucket = ab_type == 'BloodPactRage' and 'rage' or 'ward'
            table.insert(avatar_pacts_by_name[av_name][bucket], {
              category = category,
              type = 'ja',
              action = ability.en,
              target = get_default_target('ja', ability),
              alias = shorten_name(ability.en),
              icon = AVATAR_ICON_PATHS[av_name],
              level = 0,
            })
          end
        end
      end
    end

    local avatar_order = {
      'Carbuncle', 'Ifrit', 'Titan', 'Leviathan', 'Garuda',
      'Shiva', 'Ramuh', 'Fenrir', 'Diabolos', 'Cait Sith',
      'Siren', 'Alexander', 'Odin',
    }
    for _, av_name in ipairs(avatar_order) do
      local pacts = avatar_pacts_by_name[av_name]
      if pacts and (#pacts.rage > 0 or #pacts.ward > 0) then
        lines = ensure_named_section(lines, av_name)
        local _, av_sec_end = find_named_section(lines, av_name)
        local av_sec_slots, av_sec_actions = collect_existing(paths, not refresh_all)
        for _, genline in ipairs(generated_lines) do
          local a = parse_action_line(genline)
          if a and a.has_valid_slot then
            av_sec_slots[a.env] = av_sec_slots[a.env] or {}
            av_sec_slots[a.env][a.row] = av_sec_slots[a.env][a.row] or {}
            av_sec_slots[a.env][a.row][a.slot] = true
            if a.type and a.action then av_sec_actions[action_key(a.type, a.action)] = true end
          end
        end

        local rage_prefs = make_pet_prefs('blood_rage')
        local ward_prefs = make_pet_prefs('blood_ward')
        local av_lines = {}
        if #pacts.rage > 0 then
          local rl, ro = place_entries(pacts.rage, rage_prefs, theme_options, av_sec_slots, av_sec_actions, {}, filter)
          for _, l in ipairs(rl) do table.insert(av_lines, l) end
          for _, ov in ipairs(ro) do table.insert(overflow, ov) end
        end
        if #pacts.ward > 0 then
          local wl, wo = place_entries(pacts.ward, ward_prefs, theme_options, av_sec_slots, av_sec_actions, {}, filter)
          for _, l in ipairs(wl) do table.insert(av_lines, l) end
          for _, wo_entry in ipairs(wo) do table.insert(overflow, wo_entry) end
        end

        added_count = added_count + #av_lines
        if #av_lines > 0 then
          local av_sec_block = {}
          table.insert(av_sec_block, '  ' .. AUTOGEN_START)
          table.insert(av_sec_block, '  -- SMN ' .. av_name .. ' section: individual blood pacts for this avatar.')
          table.insert(av_sec_block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
          for _, line in ipairs(av_lines) do table.insert(av_sec_block, line) end
          table.insert(av_sec_block, '  ' .. AUTOGEN_END)
          for i = #av_sec_block, 1, -1 do
            table.insert(lines, av_sec_end, av_sec_block[i])
          end
        end
      end
    end
    end
  end

  if #wyvern_entries > 0 then
    lines = ensure_named_section(lines, 'Wyvern')
    local _, wy_end = find_named_section(lines, 'Wyvern')
    local wy_existing_slots, wy_existing_actions = collect_existing(paths, not refresh_all)
    for _, genline in ipairs(generated_lines) do
      local a = parse_action_line(genline)
      if a and a.has_valid_slot then
        wy_existing_slots[a.env] = wy_existing_slots[a.env] or {}
        wy_existing_slots[a.env][a.row] = wy_existing_slots[a.env][a.row] or {}
        wy_existing_slots[a.env][a.row][a.slot] = true
        if a.type and a.action then wy_existing_actions[action_key(a.type, a.action)] = true end
      end
    end
    local wy_prefs = prefs
    if prefs.pet and prefs.pet.wyvern then
      wy_prefs = copy_table(prefs)
      wy_prefs.battle.main = prefs.pet.wyvern.bar
    end
    local wy_lines, wy_overflow = place_entries(wyvern_entries, wy_prefs, theme_options,
      wy_existing_slots, wy_existing_actions, {}, filter)
    added_count = added_count + #wy_lines
    if #wy_lines > 0 then
      local wy_block = {}
      table.insert(wy_block, '  ' .. AUTOGEN_START)
      table.insert(wy_block, '  -- DRG Wyvern section: appears on bar only when the wyvern is summoned.')
      table.insert(wy_block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
      for _, line in ipairs(wy_lines) do table.insert(wy_block, line) end
      table.insert(wy_block, '  ' .. AUTOGEN_END)
      for i = #wy_block, 1, -1 do
        table.insert(lines, wy_end, wy_block[i])
      end
    end
    for _, ov in ipairs(wy_overflow) do table.insert(overflow, ov) end
  end

  if #automaton_entries > 0 then
    lines = ensure_named_section(lines, 'Automaton')
    local _, auto_end = find_named_section(lines, 'Automaton')
    local auto_existing_slots, auto_existing_actions = collect_existing(paths, not refresh_all)
    for _, genline in ipairs(generated_lines) do
      local a = parse_action_line(genline)
      if a and a.has_valid_slot then
        auto_existing_slots[a.env] = auto_existing_slots[a.env] or {}
        auto_existing_slots[a.env][a.row] = auto_existing_slots[a.env][a.row] or {}
        auto_existing_slots[a.env][a.row][a.slot] = true
        if a.type and a.action then auto_existing_actions[action_key(a.type, a.action)] = true end
      end
    end
    local auto_prefs        = prefs
    local auto_to_place     = automaton_entries
    if prefs.pet and prefs.pet.automaton then
      auto_prefs = copy_table(prefs)
      auto_prefs.battle.main = prefs.pet.automaton.bar
      local expanded = {}
      for _, entry in ipairs(automaton_entries) do
        if tostring(entry.type or ''):lower() == 'choice'
            and tostring(entry.action or ''):lower() == 'pup_maneuvers' then
          local maneuver_list = (choice_groups.groups.pup_maneuvers or {}).entries or {}
          for _, mv in ipairs(maneuver_list) do
            table.insert(expanded, {
              category = 'main',
              type     = mv.type or 'ja',
              action   = mv.action,
              target   = mv.target or 'me',
              alias    = mv.alias or mv.action,
              icon     = mv.icon,
              level    = entry.level or 0,
            })
          end
        else
          table.insert(expanded, entry)
        end
      end
      auto_to_place = expanded
    end
    local auto_lines, auto_overflow = place_entries(auto_to_place, auto_prefs, theme_options,
      auto_existing_slots, auto_existing_actions, {}, filter)
    added_count = added_count + #auto_lines
    if #auto_lines > 0 then
      local auto_block = {}
      table.insert(auto_block, '  ' .. AUTOGEN_START)
      table.insert(auto_block, '  -- PUP Automaton section: appears on bar only when the automaton is active.')
      table.insert(auto_block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
      for _, line in ipairs(auto_lines) do table.insert(auto_block, line) end
      table.insert(auto_block, '  ' .. AUTOGEN_END)
      for i = #auto_block, 1, -1 do
        table.insert(lines, auto_end, auto_block[i])
      end
    end
    for _, ov in ipairs(auto_overflow) do table.insert(overflow, ov) end
  end

  if refresh_all and player and player.main_job == 'SCH' then
    local sch_stance_sections = {
      { name = 'Light Arts',  lines = {
          "  { 'battle 1 6', 'ja', 'Addendum: White', 'me', 'Add.Wht', 'classes/sch' }, -- XIVHOTBAR2 autogen: stance",
        }},
      { name = 'Dark Arts',   lines = {
          "  { 'battle 1 6', 'ja', 'Addendum: Black', 'me', 'Add.Blk', 'classes/sch' }, -- XIVHOTBAR2 autogen: stance",
        }},
      { name = 'Tabula Rasa', lines = {
          "  { 'battle 1 6', 'ja', 'Addendum: White', 'me', 'Add.Wht', 'classes/sch' }, -- XIVHOTBAR2 autogen: stance",
          "  { 'battle 1 7', 'ja', 'Addendum: Black', 'me', 'Add.Blk', 'classes/sch' }, -- XIVHOTBAR2 autogen: stance",
        }},
    }
    for _, sec in ipairs(sch_stance_sections) do
      lines = ensure_named_section(lines, sec.name)
      local _, sec_end = find_named_section(lines, sec.name)
      if sec_end then
        local block = {}
        table.insert(block, '  ' .. AUTOGEN_START)
        table.insert(block, '  -- SCH ' .. sec.name .. ': generated by //htb autogen')
        for _, line in ipairs(sec.lines) do table.insert(block, line) end
        table.insert(block, '  ' .. AUTOGEN_END)
        for i = #block, 1, -1 do
          table.insert(lines, sec_end, block[i])
        end
        added_count = added_count + #sec.lines
      end
    end
  end

  if #blu_unbridled_entries > 0 then
    table.sort(blu_unbridled_entries, function(a, b)
      return (a.level or 0) < (b.level or 0)
    end)

    local blu_magic_pref = prefs.magic and prefs.magic['blue_magic']
    local unb_bar = (blu_magic_pref and tonumber(blu_magic_pref.bar)) or 2
    local prefs_unb = { battle = prefs.battle, field = prefs.field, magic = { blue_magic = { env = 'battle', bar = unb_bar } } }

    local function make_unbridled_lines()
      local unb_slots   = { battle = {}, field = {} }
      local unb_actions = {}
      local sec_lines, _ = place_entries(blu_unbridled_entries, prefs_unb, theme_options, unb_slots, unb_actions, {}, filter)
      return sec_lines
    end

    for _, sec_name in ipairs({ 'Unbridled Wisdom', 'Unbridled Learning' }) do
      lines = ensure_named_section(lines, sec_name)
      local _, sec_end = find_named_section(lines, sec_name)
      if sec_end then
        local sec_lines = make_unbridled_lines()
        added_count = added_count + #sec_lines
        if #sec_lines > 0 then
          local block = {}
          table.insert(block, '  ' .. AUTOGEN_START)
          table.insert(block, '  -- BLU ' .. sec_name .. ': generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
          for _, l in ipairs(sec_lines) do table.insert(block, l) end
          table.insert(block, '  ' .. AUTOGEN_END)
          for i = #block, 1, -1 do
            table.insert(lines, sec_end, block[i])
          end
        end
      end
    end
  end

  if refresh_all and player and player.main_job_id == 9 then
    lines = ensure_named_section(lines, 'Beast')
    local _, beast_end = find_named_section(lines, 'Beast')
    if beast_end then
      local function bst_ja_ok(name)
        for id, ab in pairs(priv_job_abilities) do
          if type(ab) == 'table' and ab.en == name then
            local level_data = ability_level_list[tonumber(id)]
            if level_data and type(level_data.levels) == 'table' then
              local req = level_data.levels[player.main_job_id]
              return req ~= nil and (player.main_job_level or 0) >= req
            end
            return false
          end
        end
        for id, ab in pairs(resources.job_abilities or {}) do
          if ab and ab.en == name then
            local level_data = ability_level_list[tonumber(id)]
            if level_data and type(level_data.levels) == 'table' then
              local req = level_data.levels[player.main_job_id]
              return req ~= nil and (player.main_job_level or 0) >= req
            end
            return false
          end
        end
        return false
      end

      local BEAST_LAYOUT = {
        { type = 'ja',     action = 'Fight',            target = 't',  alias = 'Fight' },
        { type = 'ja',     action = 'Heel',             target = 'me', alias = 'Heel' },
        { type = 'ja',     action = 'Sic',              target = 'me', alias = 'Sic' },
        { type = 'choice', action = 'bst_ready',        target = '',   alias = 'Ready',  icon = 'classes/bst' },
        { type = 'ja',     action = 'Gauge',            target = 'me', alias = 'Gauge' },
        { type = 'ja',     action = 'Tame',             target = 'me', alias = 'Tame' },
        { type = 'ja',     action = 'Leave',            target = 'me', alias = 'Leave' },
        { type = 'choice', action = 'bst_pet_commands', target = '',   alias = 'PetCmd', icon = 'classes/bst' },
        { type = 'ja',     action = 'Familiar',         target = 'me', alias = 'Famil' },
        { type = 'ja',     action = 'Feral Howl',       target = 'me', alias = 'FrlHwl' },
        { type = 'ja',     action = 'Killer Instinct',  target = 'me', alias = 'KilIns' },
        { type = 'ja',     action = 'Unleash',          target = 'me', alias = 'Unlsh' },
        { type = 'ja',     action = 'Reward',           target = 'me', alias = 'Rewrd' },
      }

      local beast_pref     = prefs.pet and prefs.pet.beast
      local beast_ch_env   = (beast_pref and beast_pref.env) or 'battle'
      local beast_ch_bar   = beast_pref and beast_pref.bar

      local beast_block = {}
      table.insert(beast_block, '  ' .. AUTOGEN_START)
      table.insert(beast_block, '  -- BST Beast section: appears on bar only when a beast is active.')
      table.insert(beast_block, '  -- Generated by //htb ' .. (update_only and 'updategen' or 'autogen'))
      local beast_ja_slot = 1
      local beast_ch_slot = 1
      local beast_count   = 0
      for _, entry in ipairs(BEAST_LAYOUT) do
        local include = true
        if entry.type == 'ja' then include = bst_ja_ok(entry.action) end
        if include then
          local icon_part = (entry.icon and entry.icon ~= '') and (", '" .. entry.icon .. "'") or ''
          if beast_ch_bar and entry.action == 'bst_pet_commands' then
            local cmd_list = (choice_groups.groups.bst_pet_commands or {}).entries or {}
            for _, cmd in ipairs(cmd_list) do
              local cmd_icon = (cmd.icon and cmd.icon ~= '') and (", '" .. cmd.icon .. "'") or ''
              table.insert(beast_block,
                "  { '" .. beast_ch_env .. ' ' .. beast_ch_bar .. ' ' .. beast_ch_slot .. "', 'ja', '"
                .. cmd.action .. "', '" .. (cmd.target or 'me') .. "', '"
                .. (cmd.alias or cmd.action) .. "'" .. cmd_icon
                .. " }, -- XIVHOTBAR2 autogen: beast")
              beast_ch_slot = beast_ch_slot + 1
              beast_count   = beast_count + 1
            end
          elseif beast_ch_bar and entry.action == 'bst_ready' then
            table.insert(beast_block,
              "  { '" .. beast_ch_env .. ' ' .. beast_ch_bar .. ' ' .. beast_ch_slot .. "', 'choice', 'bst_ready', '', 'Ready', 'classes/bst' }, -- XIVHOTBAR2 autogen: beast")
            beast_ch_slot = beast_ch_slot + 1
            beast_count   = beast_count + 1
          elseif beast_ch_bar and entry.action == 'Sic' then
            table.insert(beast_block,
              "  { '" .. beast_ch_env .. ' ' .. beast_ch_bar .. ' ' .. beast_ch_slot .. "', 'ja', 'Sic', '"
              .. (entry.target or 'me') .. "', 'Sic'" .. icon_part
              .. " }, -- XIVHOTBAR2 autogen: beast")
            beast_ch_slot = beast_ch_slot + 1
            beast_count   = beast_count + 1
          else
            table.insert(beast_block,
              "  { 'battle 1 " .. beast_ja_slot .. "', '" .. entry.type .. "', '"
              .. entry.action .. "', '" .. (entry.target or '') .. "', '"
              .. (entry.alias or entry.action) .. "'" .. icon_part
              .. " }, -- XIVHOTBAR2 autogen: beast")
            beast_ja_slot = beast_ja_slot + 1
            beast_count   = beast_count + 1
          end
        end
      end
      table.insert(beast_block, '  ' .. AUTOGEN_END)

      if beast_count > 0 then
        for i = #beast_block, 1, -1 do
          table.insert(lines, beast_end, beast_block[i])
        end
        added_count = added_count + beast_count
      end
    end
  end

  if added_count == 0 then
    local has_normal_bars = prefs.battle.main or prefs.battle.sub or prefs.battle.ws or prefs.battle.item
    local has_magic_bars = prefs.magic and next(prefs.magic)
    if has_normal_bars or has_magic_bars then
      chat('XIVHOTBAR2: no new actions to add (all bars already current). If abilities seem missing, try //htb autogen again after fully loading.')
    else
      chat('XIVHOTBAR2: no new generated actions to add.')
    end
    return false
  end

  write_lines(paths.job, lines)
  chat(string.format('XIVHOTBAR2: added %d generated action line(s) to %s.', added_count, paths.job:match('[^/\\]+$') or paths.job))

  if #overflow > 0 then
    chat(string.format('XIVHOTBAR2: %d action(s) did not fit on non-paged bars.', #overflow))
    for i = 1, math.min(#overflow, 10) do
      chat('  overflow: ' .. tostring(overflow[i].action))
    end
  end

  return true
end

function hotbar_tools:collapse_weaponskills(player, theme_options, args)
  args = args or {}
  init_weapon_keys()

  local env = nil
  local row = nil
  local slot = nil
  local number_positions = {}

  for i = 1, #args do
    local e = normalize_env(args[i])
    if e then env = e end
    if tonumber(args[i]) then table.insert(number_positions, i) end
  end

  if #number_positions >= 2 then
    row = tonumber(args[number_positions[1]])
    slot = tonumber(args[number_positions[2]])
  end

  if not env then
    local _, active_env = player:get_hotbar_info_without_vitals()
    env = active_env or 'battle'
  end

  if not row or not slot or row < 1 or row > 6 or slot < 1 or slot > (theme_options.columns or 12) then
    chat('Usage: //htb collapse weaponskills <hotbar 1-6> <slot 1-12> [battle|field] [current|main|range|sword|dagger|...]')
    chat('Also accepted: //htb hotbar slot collapse weaponskills <hotbar> <slot>')
    return false
  end

  local ignored = {
    collapse = true, collapsed = true, hotbar = true, bar = true, slot = true,
    weaponskill = true, weaponskills = true, weapon_skill = true, weapon_skills = true,
    ws = true, weapon = true, skills = true, skill = true, into = true, to = true,
    battle = true, b = true, field = true, f = true,
  }

  local weapon_parts = {}
  for i = 1, #args do
    if not tonumber(args[i]) then
      local key = normalize_key(args[i])
      if not ignored[key] then table.insert(weapon_parts, args[i]) end
    end
  end

  local weapon_name = table.concat(weapon_parts, ' ')
  local group_id, alias = choice_group_for_weapon_name(player, weapon_name)
  if weapon_name == '' then weapon_name = 'current' end

  if not choice_groups:exists(group_id) then
    chat('XIVHOTBAR2: could not create weaponskill choice group for ' .. tostring(weapon_name) .. '.')
    return false
  end

  local paths = get_paths(player)
  local total_removed = 0

  local lines = read_lines(paths.job)
  if #lines == 0 then
    chat('XIVHOTBAR2: could not open current job file: ' .. paths.job)
    return false
  end

  lines, total_removed = remove_ws_lines_for_bar(lines, env, row, slot)

  local choice_line = "  { '" .. env .. ' ' .. tostring(row) .. ' ' .. tostring(slot) .. "', 'choice', " .. quote_lua_string(group_id) .. ", '', " .. quote_lua_string(alias) .. " },"
  local start_i, end_i = find_base_section(lines)
  if not start_i or not end_i then
    chat("XIVHOTBAR2: current job file has no xivhotbar_keybinds_job['Base'] section to insert into.")
    return false
  end

  table.insert(lines, end_i, choice_line)
  write_lines(paths.job, lines)

  local general_lines = read_lines(paths.general)
  if #general_lines > 0 then
    local cleaned_general, removed_general = remove_ws_lines_for_bar(general_lines, env, row, slot)
    total_removed = total_removed + removed_general
    write_lines(paths.general, cleaned_general)
  end

  chat(string.format('XIVHOTBAR2: collapsed %s hotbar %d weaponskills into slot %d using group %s. Removed %d old WS line(s).', env, row, slot, group_id, total_removed))
  return true
end

local function get_trust_choices_path(player)
  local paths = get_paths(player)
  return paths.base .. 'trust_choices.lua'
end

local function write_trust_choices_file(player, trusts)
  local path = get_trust_choices_path(player)
  local lines = {
    '-- Generated by XIVHotbar2 //htb set up trust',
    '-- Re-run //htb set up trust to rebuild this list.',
    'return {',
  }

  for _, name in ipairs(trusts or {}) do
    if name and tostring(name) ~= '' then
      table.insert(lines, '  ' .. quote_lua_string(name) .. ',')
    end
  end

  table.insert(lines, '}')
  return write_lines(path, lines)
end

local function find_existing_choice_button(paths, group_id)
  group_id = tostring(group_id or ''):lower()
  local function scan(path)
    for _, line in ipairs(read_lines(path)) do
      local a = parse_action_line(line)
      if a and a.has_valid_slot and tostring(a.type or ''):lower() == 'choice'
          and tostring(a.action or ''):lower() == group_id then
        return { env = a.env, row = a.row, slot = a.slot, path = path }
      end
    end
    return nil
  end

  return scan(paths.job) or scan(paths.general)
end

local function insert_choice_button_into_job(player, theme_options, env, group_id, alias, icon)
  local paths = get_paths(player)
  local existing = find_existing_choice_button(paths, group_id)
  if existing then
    return true, existing, false
  end

  local lines = read_lines(paths.job)
  if #lines == 0 then
    chat('XIVHOTBAR2: could not open current job file: ' .. paths.job)
    return false, nil, false
  end

  local existing_slots = collect_existing(paths, true)
  local rows = tonumber(theme_options.rows or theme_options.hotbar_number or 6) or 6
  local columns = tonumber(theme_options.columns or 12) or 12
  local row = nil
  local slot = nil

  for r = 1, rows do
    local candidate = find_empty_slot(existing_slots, env, r, columns)
    if candidate then
      row = r
      slot = candidate
      break
    end
  end

  if not row or not slot then
    chat('XIVHOTBAR2: no empty ' .. tostring(env) .. ' slot was found for the Trust choice button. Clear a slot or use //htb resetbar first.')
    return false, nil, false
  end

  local start_i, end_i = find_base_section(lines)
  if not start_i or not end_i then
    chat("XIVHOTBAR2: current job file has no xivhotbar_keybinds_job['Base'] section to insert into.")
    return false, nil, false
  end

  local choice_line = "  { '" .. env .. ' ' .. tostring(row) .. ' ' .. tostring(slot) .. "', 'choice', " ..
      quote_lua_string(group_id) .. ", '', " .. quote_lua_string(alias or 'Trust')
  if icon and icon ~= '' then
    choice_line = choice_line .. ', ' .. quote_lua_string(icon)
  end
  choice_line = choice_line .. ' }, -- XIVHOTBAR2 trust setup'

  table.insert(lines, end_i, choice_line)
  write_lines(paths.job, lines)

  return true, { env = env, row = row, slot = slot, path = paths.job }, true
end

function hotbar_tools:start_trust_setup(player, theme_options, args)
  args = args or {}
  local env = nil

  for _, arg in ipairs(args) do
    local maybe_env = normalize_env(arg)
    if maybe_env then env = maybe_env end
  end

  if not env then
    local _, active_env = player:get_hotbar_info_without_vitals()
    env = active_env or 'field'
  end

  local ok, placed, inserted = insert_choice_button_into_job(player, theme_options, env, 'trust_custom', 'Trust', 'scroll')
  if not ok then return nil end

  write_trust_choices_file(player, {})

  if inserted then
    chat(string.format('XIVHOTBAR2: added Trust choice button to %s hotbar %d slot %d.', placed.env, placed.row, placed.slot))
  else
    chat(string.format('XIVHOTBAR2: Trust choice button already exists on %s hotbar %d slot %d.', placed.env, placed.row, placed.slot))
  end

  chat('XIVHOTBAR2 Trust setup started. Enter Trust names with //htb <trust name> or //htb trust <trust name>.')
  chat('XIVHOTBAR2: Enter Trust for choice slot 1, or //htb done to finish, //htb cancel to cancel.')

  return {
    active = true,
    index = 1,
    max = tonumber(theme_options.columns or 12) or 12,
    trusts = {},
    button = placed,
  }
end

function hotbar_tools:add_trust_setup_choice(player, setup, name)
  if not setup or not setup.active then return false end
  name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')

  if name == '' then
    chat('XIVHOTBAR2: Trust name was blank. Enter a name, //htb done, or //htb cancel.')
    return true
  end

  if setup.index > setup.max then
    chat('XIVHOTBAR2: Trust choice bar is already full. Use //htb done to finish.')
    return true
  end

  table.insert(setup.trusts, name)
  write_trust_choices_file(player, setup.trusts)
  chat(string.format('XIVHOTBAR2: Trust slot %d set to %s.', setup.index, name))

  setup.index = setup.index + 1
  if setup.index > setup.max then
    chat('XIVHOTBAR2: Trust choice bar is full. Setup finished.')
    setup.active = false
    return false
  end

  chat(string.format('XIVHOTBAR2: Enter Trust for choice slot %d, or //htb done to finish.', setup.index))
  return true
end

function hotbar_tools:finish_trust_setup(player, setup, cancelled)
  if not setup then return end

  if cancelled then
    write_trust_choices_file(player, {})
    chat('XIVHOTBAR2: Trust setup cancelled. Trust choice list was cleared. The Trust button remains so you can set it up again or move/remove it.')
  else
    write_trust_choices_file(player, setup.trusts or {})
    chat(string.format('XIVHOTBAR2: Trust setup finished with %d Trust(s).', #(setup.trusts or {})))
  end
end

function hotbar_tools:list_styles()
  chat('XIVHOTBAR2 style presets:')
  local keys = {}
  for k, _ in pairs(STYLE_PRESETS) do table.insert(keys, k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    chat('  ' .. k .. ' - ' .. STYLE_PRESETS[k].label)
  end
  chat('Theme folders can also be used directly: //htb style theme <slotTheme> [frameTheme]')
  chat('Example: //htb style ffxiv OR //htb style theme ffxiv')
end

function hotbar_tools:apply_style(settings, args)
  args = args or {}
  local first = tostring(args[1] or ''):lower()

  if first == '' or first == 'list' or first == 'help' then
    self:list_styles()
    return false
  end

  if first == 'theme' then
    local slot_theme = args[2]
    local frame_theme = args[3] or args[2]
    if not slot_theme then
      chat('Usage: //htb style theme <slotTheme> [frameTheme]')
      return false
    end
    settings.Hotbar.Theme.Slot = slot_theme
    settings.Hotbar.Theme.Frame = frame_theme
    chat('XIVHOTBAR2: set slot theme to ' .. slot_theme .. ' and frame theme to ' .. frame_theme .. '.')
    return true
  end

  local preset = STYLE_PRESETS[first]
  if preset then
    settings.Hotbar.HideActionName = preset.HideActionName
    settings.Hotbar.HideActionCost = preset.HideActionCost
    settings.Hotbar.HideEmptySlots = preset.HideEmptySlots
    settings.Hotbar.Style.SlotSpacing = preset.SlotSpacing
    settings.Hotbar.Style.HotbarSpacing = preset.HotbarSpacing
    settings.Hotbar.Style.SlotAlpha = preset.SlotAlpha
    settings.Hotbar.Style.ShowEmptySlotFrames = preset.ShowEmptySlotFrames
    settings.Hotbar.Theme.Frame = preset.Frame
    settings.Hotbar.Theme.Slot = preset.Slot
    chat('XIVHOTBAR2: applied style preset ' .. first .. '.')
    return true
  end

  settings.Hotbar.Theme.Slot = args[1]
  settings.Hotbar.Theme.Frame = args[2] or args[1]
  chat('XIVHOTBAR2: set custom theme to ' .. tostring(args[1]) .. '.')
  return true
end

function hotbar_tools:auto_populate_sub_bar(player, theme_options)
  local paths = get_paths(player)
  if not file_exists(paths.job) then return false end

  local prefs = self:load_preferences(player)
  local sub_bar = prefs.battle and tonumber(prefs.battle.sub)
  if not sub_bar then return false end

  local sub_key = tostring(player.sub_job or 'NON')
  if sub_key == 'NON' or sub_key == '' then return false end

  self:reset_bar(player, 'battle', sub_bar)
  local ok = self:autogenerate(player, theme_options, false, {categories = {sub = true}})
  if ok then
    prefs.sub_populated = prefs.sub_populated or {}
    prefs.sub_populated[sub_key] = true
    self:save_preferences(player, prefs)
  end
  return ok
end

hotbar_tools.action_icons = ACTION_ICONS

return hotbar_tools
