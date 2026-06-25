local choice_groups = {}
local resources = require('resources')

local dynamic_group_cache = {}

local ok_ability_levels, ability_level_list = pcall(require, 'components/xivhotbar3/priv_res/job_abilities_levels')
if not ok_ability_levels then ability_level_list = {} end

local ok_priv_ja, priv_job_abilities = pcall(require, 'components/xivhotbar3/priv_res/job_abilities')
if not ok_priv_ja then priv_job_abilities = {} end

local ok_priv_spells, priv_spells = pcall(require, 'components/xivhotbar3/priv_res/spells')
if not ok_priv_spells then priv_spells = {} end

local ok_horizon_spells, horizon_priv_spells = pcall(require, 'components/xivhotbar3/priv_res/horizon_spells')
if not ok_horizon_spells then horizon_priv_spells = {} end

local function effective_priv_spells()
  if theme_options and theme_options.playing_on_horizon == true then
    return horizon_priv_spells
  end
  return priv_spells
end

local BLOOD_PACT_BY_TYPE = { BloodPactRage = {}, BloodPactWard = {} }
for _, ability in pairs(priv_job_abilities) do
  if type(ability) == 'table' and ability.en and ability.en ~= '' then
    local t = tostring(ability.type or '')
    if t == 'BloodPactRage' or t == 'BloodPactWard' then
      table.insert(BLOOD_PACT_BY_TYPE[t], ability)
    end
  end
end

local WEAPONSKILL_TYPES = require('components/xivhotbar3/lib/constants').WEAPONSKILL_TYPES

local WEAPONSKILL_TYPE_KEYS = {}
local function normalize_key(value)
  value = tostring(value or ''):lower()
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  value = value:gsub('%s+', '_')
  value = value:gsub('%-', '_')
  return value
end

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

local function ja(name, target, alias, icon)
  return { type = 'ja', action = name, target = target or 'me', alias = alias or name, icon = icon }
end

local function ma(name, target, alias, icon)
  return { type = 'ma', action = name, target = target or 'me', alias = alias or name, icon = icon }
end

local function input(command, alias, icon)
  return { type = 'input', action = command, target = '', alias = alias or command, icon = icon }
end

local function fam(alias, choices, icon)
  return { alias = alias, icon = icon, choices = choices }
end

local function is_user_trust_group(group_id)
  local key = normalize_key(group_id)
  return key == 'trust_custom' or key == 'custom_trusts' or key == 'user_trusts' or key == 'trusts_custom'
end

local function get_user_trust_path(player)
  if not player or not player.name or player.name == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/trust_choices.lua'
end

local function load_user_trusts(player)
  local path = get_user_trust_path(player)
  if not path then return {} end

  local loader = loadfile(path)
  if not loader then return {} end

  local ok, data = pcall(loader)
  if not ok or type(data) ~= 'table' then return {} end
  return data
end

local function build_user_trust_actions(player)
  local data = load_user_trusts(player)
  local actions = {}

  for _, entry in ipairs(data) do
    local name = nil
    local alias = nil
    local icon = nil

    if type(entry) == 'table' then
      name = entry.name or entry.action or entry[1]
      alias = entry.alias or entry[2]
      icon = entry.icon or entry[3]
    else
      name = entry
    end

    if name ~= nil and tostring(name) ~= '' then
      table.insert(actions, ma(tostring(name), 'me', alias or tostring(name), icon))
    end
  end

  return actions
end

choice_groups.groups = {
  dnc_sambas = {
    label = 'Sambas', jobs = { 'DNC' }, icon = 'ffxiv/dnc/pirouette', alias = 'Samba',
    suppress = { 'Samba', 'Sambas' },
    entries = {
      fam('Haste', { ja('Haste Samba', 'me', 'Haste', 'ffxiv/dnc/pirouette') }, 'ffxiv/dnc/pirouette'),
      fam('Drain', { ja('Drain Samba', 'me', 'Drain', 'ffxiv/dnc/emboite'), ja('Drain Samba II', 'me', 'Drain2', 'ffxiv/dnc/emboite'), ja('Drain Samba III', 'me', 'Drain3', 'ffxiv/dnc/emboite') }, 'ffxiv/dnc/emboite'),
      fam('Aspir', { ja('Aspir Samba', 'me', 'Aspir', 'ffxiv/dnc/jete'), ja('Aspir Samba II', 'me', 'Aspir2', 'ffxiv/dnc/jete') }, 'ffxiv/dnc/jete'),
    }
  },

  dnc_waltzes = {
    label = 'Waltzes', jobs = { 'DNC' }, icon = 'ffxiv/dnc/curing_waltz', alias = 'Waltz',
    suppress = { 'Waltz', 'Waltzes' },
    entries = {
      fam('Curing', { ja('Curing Waltz', 'stpc', 'CurW', 'ffxiv/dnc/curing_waltz'), ja('Curing Waltz II', 'stpc', 'CurW2', 'ffxiv/dnc/curing_waltz'), ja('Curing Waltz III', 'stpc', 'CurW3', 'ffxiv/dnc/curing_waltz'), ja('Curing Waltz IV', 'stpc', 'CurW4', 'ffxiv/dnc/curing_waltz'), ja('Curing Waltz V', 'stpc', 'CurW5', 'ffxiv/dnc/curing_waltz') }, 'ffxiv/dnc/curing_waltz'),
      fam('Divine', { ja('Divine Waltz', 'stpc', 'Divine', 'ffxiv/dnc/improvised_finish'), ja('Divine Waltz II', 'stpc', 'Divine2', 'ffxiv/dnc/improvised_finish') }, 'ffxiv/dnc/improvised_finish'),
      fam('Healing', { ja('Healing Waltz', 'stpc', 'Healing', 'ffxiv/dnc/shield_samba') }, 'ffxiv/dnc/shield_samba'),
    }
  },

  dnc_steps = {
    label = 'Steps', jobs = { 'DNC' }, icon = 'ffxiv/dnc/en_avant', alias = 'Steps',
    suppress = { 'Step', 'Steps' },
    entries = {
      fam('Quick', { ja('Quickstep', 't', 'Quick', 'ffxiv/dnc/en_avant') }, 'ffxiv/dnc/en_avant'),
      fam('Box', { ja('Box Step', 't', 'Box', 'ffxiv/dnc/bladeshower') }, 'ffxiv/dnc/bladeshower'),
      fam('Stutter', { ja('Stutter Step', 't', 'Stutter', 'ffxiv/dnc/fountainfall') }, 'ffxiv/dnc/fountainfall'),
      fam('Feather', { ja('Feather Step', 't', 'Feather', 'ffxiv/dnc/fountain') }, 'ffxiv/dnc/fountain'),
    }
  },

  dnc_flourishes = {
    autogen = false,
    label = 'Flourishes', jobs = { 'DNC' }, icon = 'ffxiv/dnc/flourish', alias = 'Flour',
    suppress = { 'Flourish', 'Flourishes', 'Flourish I', 'Flourish II', 'Flourish III', 'Flourish 1', 'Flourish 2', 'Flourish 3', 'Flourishes I', 'Flourishes II', 'Flourishes III', 'Flourishes 1', 'Flourishes 2', 'Flourishes 3', 'Flourishes 1-3', 'Flourishes I-III', 'Flourishes I - III', 'Flourishes 1 - 3' },
    entries = {
      fam('Animated', { ja('Animated Flourish', 'stnpc', 'Voke', 'ffxiv/dnc/closed_position') }, 'ffxiv/dnc/closed_position'),
      fam('Desperate', { ja('Desperate Flourish', 't', 'Despr', 'ffxiv/dnc/devilment') }, 'ffxiv/dnc/devilment'),
      fam('Violent', { ja('Violent Flourish', 'stnpc', 'Stun', 'ffxiv/dnc/starfall_dance') }, 'ffxiv/dnc/starfall_dance'),
      fam('Reverse', { ja('Reverse Flourish', 'me', 'Reverse', 'ffxiv/dnc/reverse_cascade') }, 'ffxiv/dnc/reverse_cascade'),
      fam('Building', { ja('Building Flourish', 'me', 'Build', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Wild', { ja('Wild Flourish', 'me', 'Wild', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Climactic', { ja('Climactic Flourish', 'me', 'Clim', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Striking', { ja('Striking Flourish', 'me', 'Strike', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Ternary', { ja('Ternary Flourish', 'me', 'Tern', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
    }
  },

  dnc_flourishes_1 = {
    label = 'Flourish I', jobs = { 'DNC' }, icon = 'ffxiv/dnc/closed_position', alias = 'Flour1',
    suppress = { 'Flourish I', 'Flourish 1', 'Flourishes I', 'Flourishes 1' },
    entries = {
      fam('Animated', { ja('Animated Flourish', 'stnpc', 'Voke', 'ffxiv/dnc/closed_position') }, 'ffxiv/dnc/closed_position'),
      fam('Desperate', { ja('Desperate Flourish', 't', 'Despr', 'ffxiv/dnc/devilment') }, 'ffxiv/dnc/devilment'),
      fam('Violent', { ja('Violent Flourish', 'stnpc', 'Stun', 'ffxiv/dnc/starfall_dance') }, 'ffxiv/dnc/starfall_dance'),
    }
  },

  dnc_flourishes_2 = {
    label = 'Flourish II', jobs = { 'DNC' }, icon = 'ffxiv/dnc/reverse_cascade', alias = 'Flour2',
    suppress = { 'Flourish II', 'Flourish 2', 'Flourishes II', 'Flourishes 2' },
    entries = {
      fam('Reverse', { ja('Reverse Flourish', 'me', 'Reverse', 'ffxiv/dnc/reverse_cascade') }, 'ffxiv/dnc/reverse_cascade'),
      fam('Building', { ja('Building Flourish', 'me', 'Build', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Wild', { ja('Wild Flourish', 'me', 'Wild', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
    }
  },

  dnc_flourishes_3 = {
    label = 'Flourish III', jobs = { 'DNC' }, icon = 'ffxiv/dnc/flourish', alias = 'Flour3',
    suppress = { 'Flourish III', 'Flourish 3', 'Flourishes III', 'Flourishes 3' },
    entries = {
      fam('Climactic', { ja('Climactic Flourish', 'me', 'Clim', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Striking', { ja('Striking Flourish', 'me', 'Strike', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
      fam('Ternary', { ja('Ternary Flourish', 'me', 'Tern', 'ffxiv/dnc/flourish') }, 'ffxiv/dnc/flourish'),
    }
  },

  dnc_jigs = {
    label = 'Jigs', jobs = { 'DNC' }, icon = 'ffxiv/dnc/fan_dance_IV', alias = 'Jigs',
    suppress = { 'Jig', 'Jigs' },
    entries = {
      fam('Spectral', { ja('Spectral Jig', 'me', 'Spectral', 'ffxiv/dnc/fan_dance_IV') }, 'ffxiv/dnc/fan_dance_IV'),
      fam('Chocobo', { ja('Chocobo Jig', 'me', 'Chocobo', 'ffxiv/dnc/entrechat'), ja('Chocobo Jig II', 'me', 'Choco2', 'ffxiv/dnc/entrechat') }, 'ffxiv/dnc/entrechat'),
    }
  },

  cor_rolls = {
    label = 'Rolls', jobs = { 'COR' }, icon = 'ffxiv/ast/play', alias = 'Rolls',
    suppress = { 'Phantom Roll', 'Rolls' },
    entries = {
      fam('COR', { ja("Corsair's Roll", 'me', 'COR', 'classes/ast') }, 'classes/ast'),
      fam('NIN', { ja('Ninja Roll', 'me', 'NIN', 'classes/nin') }, 'classes/nin'),
      fam('HUN', { ja("Hunter's Roll", 'me', 'HUN', 'classes/acr') }, 'classes/acr'),
      fam('CHS', { ja('Chaos Roll', 'me', 'CHS', 'classes/rpr') }, 'classes/rpr'),
      fam('MGS', { ja("Magus's Roll", 'me', 'MGS', 'classes/whm') }, 'classes/whm'),
      fam('HLR', { ja("Healer's Roll", 'me', 'HLR', 'classes/hlr') }, 'classes/hlr'),
      fam('DRC', { ja('Drachen Roll', 'me', 'DRC', 'classes/lnc') }, 'classes/lnc'),
      fam('CRL', { ja('Choral Roll', 'me', 'CRL', 'classes/brd') }, 'classes/brd'),
      fam('MNK', { ja("Monk's Roll", 'me', 'MNK', 'classes/mnk') }, 'classes/mnk'),
      fam('BST', { ja('Beast Roll', 'me', 'BST', 'classes/war') }, 'classes/war'),
      fam('SAM', { ja('Samurai Roll', 'me', 'SAM', 'classes/sam') }, 'classes/sam'),
      fam('EVO', { ja("Evoker's Roll", 'me', 'EVO', 'classes/smn') }, 'classes/smn'),
      fam('RGE', { ja("Rogue's Roll", 'me', 'RGE', 'classes/rge') }, 'classes/rge'),
      fam('WLK', { ja("Warlock's Roll", 'me', 'WLK', 'classes/thm') }, 'classes/thm'),
      fam('FTR', { ja("Fighter's Roll", 'me', 'FTR', 'classes/mar') }, 'classes/mar'),
      fam('PUP', { ja('Puppet Roll', 'me', 'PUP', 'classes/pug') }, 'classes/pug'),
      fam('GAL', { ja("Gallant's Roll", 'me', 'GAL', 'classes/pld') }, 'classes/pld'),
      fam('WIZ', { ja("Wizard's Roll", 'me', 'WIZ', 'classes/blm') }, 'classes/blm'),
      fam('DNC', { ja("Dancer's Roll", 'me', 'DNC', 'classes/dnc') }, 'classes/dnc'),
      fam('SCH', { ja("Scholar's Roll", 'me', 'SCH', 'classes/sch') }, 'classes/sch'),
      fam('BLT', { ja("Bolter's Roll", 'me', 'BLT', 'classes/mag_rng') }, 'classes/mag_rng'),
      fam('CST', { ja("Caster's Roll", 'me', 'CST', 'classes/blm') }, 'classes/blm'),
      fam('CRS', { ja("Courser's Roll", 'me', 'CRS', 'classes/acr') }, 'classes/acr'),
      fam('BLZ', { ja("Blitzer's Roll", 'me', 'BLZ', 'classes/mnk') }, 'classes/mnk'),
      fam('TAC', { ja("Tactician's Roll", 'me', 'TAC', 'classes/sam') }, 'classes/sam'),
      fam('ALY', { ja("Allies' Roll", 'me', 'ALY', 'classes/gnb') }, 'classes/gnb'),
      fam('MSR', { ja("Miser's Roll", 'me', 'MSR', 'classes/thf') }, 'classes/thf'),
      fam('CMP', { ja("Companion's Roll", 'me', 'CMP', 'classes/smn') }, 'classes/smn'),
      fam('AVG', { ja("Avenger's Roll", 'me', 'AVG', 'classes/drk') }, 'classes/drk'),
      fam('NAT', { ja("Naturalist's Roll", 'me', 'NAT', 'classes/sch') }, 'classes/sch'),
      fam('RUN', { ja("Runeist's Roll", 'me', 'RUN', 'classes/run') }, 'classes/run'),
    }
  },

  cor_quick_draw = {
    label = 'Quick Draw', jobs = { 'COR' }, icon = 'ffxiv/ast/003110', alias = 'QDraw',
    suppress = { 'Quick Draw' },
    entries = {
      fam('Fire', { ja('Fire Shot', 't', 'Fire', 'ffxiv/ast/003110') }, 'ffxiv/ast/003110'),
      fam('Ice', { ja('Ice Shot', 't', 'Ice', 'ffxiv/ast/003113') }, 'ffxiv/ast/003113'),
      fam('Wind', { ja('Wind Shot', 't', 'Wind', 'ffxiv/ast/003111') }, 'ffxiv/ast/003111'),
      fam('Earth', { ja('Earth Shot', 't', 'Earth', 'ffxiv/ast/003115') }, 'ffxiv/ast/003115'),
      fam('Thunder', { ja('Thunder Shot', 't', 'Thunder', 'ffxiv/ast/003112') }, 'ffxiv/ast/003112'),
      fam('Water', { ja('Water Shot', 't', 'Water', 'ffxiv/ast/003114') }, 'ffxiv/ast/003114'),
      fam('Light', { ja('Light Shot', 't', 'Light', 'ffxiv/ast/003146') }, 'ffxiv/ast/003146'),
      fam('Dark', { ja('Dark Shot', 't', 'Dark', 'ffxiv/ast/003147') }, 'ffxiv/ast/003147'),
    }
  },

  run_runes = {
    label = 'Runes', jobs = { 'RUN' }, icon = 'classes/run', alias = 'Runes',
    suppress = { 'Runes', 'Rune Enchantment' },
    entries = {
      fam('Ignis', { ja('Ignis', 'me', 'Ignis') }), fam('Gelus', { ja('Gelus', 'me', 'Gelus') }),
      fam('Flabra', { ja('Flabra', 'me', 'Flabra') }), fam('Tellus', { ja('Tellus', 'me', 'Tellus') }),
      fam('Sulpor', { ja('Sulpor', 'me', 'Sulpor') }), fam('Unda', { ja('Unda', 'me', 'Unda') }),
      fam('Lux', { ja('Lux', 'me', 'Lux') }), fam('Tenebrae', { ja('Tenebrae', 'me', 'Teneb') }),
    }
  },

  run_wards = {
    label = 'Wards', jobs = { 'RUN' }, icon = 'classes/run', alias = 'Wards',
    suppress = { 'Ward', 'Wards' },
    entries = {
      fam('Vallation', { ja('Vallation', 'me', 'Valla') }),
      fam('Pflug', { ja('Pflug', 'me', 'Pflug') }),
      fam('Valiance', { ja('Valiance', 'me', 'Valia') }),
      fam('Liement', { ja('Liement', 'me', 'Liement') }),
      fam('Battuta', { ja('Battuta', 'me', 'Battuta') }),
    }
  },

  run_effusions = {
    label = 'Effusions', jobs = { 'RUN' }, icon = 'classes/run', alias = 'Effuse',
    suppress = { 'Effusion', 'Effusions' },
    entries = {
      fam('Swipe', { ja('Swipe', 't', 'Swipe') }),
      fam('Lunge', { ja('Lunge', 't', 'Lunge') }),
      fam('Gambit', { ja('Gambit', 't', 'Gambit') }),
      fam('Rayke', { ja('Rayke', 't', 'Rayke') }),
    }
  },

  nin_elemental = {
    autogen = false,
    label = 'Ninjutsu', jobs = { 'NIN' }, icon = 'ffxiv/nin/katon', alias = 'Nukes',
    entries = {
      fam('Katon', { ma('Katon: Ichi', 'stnpc', 'Katon', 'ffxiv/nin/katon'), ma('Katon: Ni', 'stnpc', 'Katon2', 'ffxiv/nin/katon'), ma('Katon: San', 'stnpc', 'Katon3', 'ffxiv/nin/katon') }, 'ffxiv/nin/katon'),
      fam('Hyoton', { ma('Hyoton: Ichi', 'stnpc', 'Hyoton', 'ffxiv/nin/hyoton'), ma('Hyoton: Ni', 'stnpc', 'Hyoton2', 'ffxiv/nin/hyoton'), ma('Hyoton: San', 'stnpc', 'Hyoton3', 'ffxiv/nin/hyoton') }, 'ffxiv/nin/hyoton'),
      fam('Huton', { ma('Huton: Ichi', 'stnpc', 'Huton', 'ffxiv/nin/huton'), ma('Huton: Ni', 'stnpc', 'Huton2', 'ffxiv/nin/huton'), ma('Huton: San', 'stnpc', 'Huton3', 'ffxiv/nin/huton') }, 'ffxiv/nin/huton'),
      fam('Doton', { ma('Doton: Ichi', 'stnpc', 'Doton', 'ffxiv/nin/doton'), ma('Doton: Ni', 'stnpc', 'Doton2', 'ffxiv/nin/doton'), ma('Doton: San', 'stnpc', 'Doton3', 'ffxiv/nin/doton') }, 'ffxiv/nin/doton'),
      fam('Raiton', { ma('Raiton: Ichi', 'stnpc', 'Raiton', 'ffxiv/nin/raiton'), ma('Raiton: Ni', 'stnpc', 'Raiton2', 'ffxiv/nin/raiton'), ma('Raiton: San', 'stnpc', 'Raiton3', 'ffxiv/nin/raiton') }, 'ffxiv/nin/raiton'),
      fam('Suiton', { ma('Suiton: Ichi', 'stnpc', 'Suiton', 'ffxiv/nin/suiton'), ma('Suiton: Ni', 'stnpc', 'Suiton2', 'ffxiv/nin/suiton'), ma('Suiton: San', 'stnpc', 'Suiton3', 'ffxiv/nin/suiton') }, 'ffxiv/nin/suiton'),
    }
  },

  nin_utility = {
    autogen = false,
    label = 'Nin Utility', jobs = { 'NIN' }, icon = 'ffxiv/nin/phantom_kamaitachi', alias = 'NinUtil',
    entries = {
      fam('Utsu', { ma('Utsusemi: Ichi', 'me', 'Utsu1', 'ffxiv/nin/dream_within_a_dream'), ma('Utsusemi: Ni', 'me', 'Utsu2', 'ffxiv/nin/phantom_kamaitachi'), ma('Utsusemi: San', 'me', 'Utsu3', 'ffxiv/nin/phantom_kamaitachi') }, 'ffxiv/nin/phantom_kamaitachi'),
      fam('Tonko', { ma('Tonko: Ichi', 'me', 'Tonko1'), ma('Tonko: Ni', 'me', 'Tonko2') }),
      fam('Monomi', { ma('Monomi: Ichi', 'me', 'Monomi') }),
      fam('Hojo', { ma('Hojo: Ichi', 'stnpc', 'Hojo1'), ma('Hojo: Ni', 'stnpc', 'Hojo2') }),
      fam('Kurayami', { ma('Kurayami: Ichi', 'stnpc', 'Kura1'), ma('Kurayami: Ni', 'stnpc', 'Kura2') }),
      fam('Jubaku', { ma('Jubaku: Ichi', 'stnpc', 'Jubaku') }),
      fam('Dokumori', { ma('Dokumori: Ichi', 'stnpc', 'Doku') }),
    }
  },

  smn_avatars = {
    label = 'Summons', jobs = { 'SMN' }, icon = 'classes/smn', alias = 'Summon',
    entries = {
      fam('Carby',     { ma('Carbuncle',     'me', 'Carby',    'summons/carbuncle_GUI') }),
      fam('Ifrit',     { ma('Ifrit',         'me', 'Ifrit',    'summons/ifrit_GUI') }),
      fam('Shiva',     { ma('Shiva',         'me', 'Shiva',    'summons/shiva_GUI') }),
      fam('Garuda',    { ma('Garuda',        'me', 'Garuda',   'summons/garuda_GUI') }),
      fam('Titan',     { ma('Titan',         'me', 'Titan',    'summons/titan_GUI') }),
      fam('Ramuh',     { ma('Ramuh',         'me', 'Ramuh',    'summons/ramuh_GUI') }),
      fam('Levi',      { ma('Leviathan',     'me', 'Levi',     'summons/leviathan_GUI') }),
      fam('Fenrir',    { ma('Fenrir',        'me', 'Fenrir',   'summons/fenrir_GUI') }),
      fam('Diabolos',  { ma('Diabolos',      'me', 'Diab',     'summons/diabolos_GUI') }),
      fam('Cait Sith', { ma('Cait Sith',     'me', 'Cait',     'summons/cait_sith_GUI') }),
      fam('Siren',     { ma('Siren',         'me', 'Siren',    'summons/siren_GUI') }),
      fam('Atomos',    { ma('Atomos',        'me', 'Atomos',   'summons/atomos_GUI') }),
      fam('Odin',      { ma('Odin',          'me', 'Odin',     'summons/odin_GUI') }),
      fam('Alexander', { ma('Alexander',     'me', 'Alex',     'summons/alexander_GUI') }),
      fam('Earth',     { ma('Earth Spirit',  'me', 'Earth',    'summons/earthspirit') }),
      fam('Water',     { ma('Water Spirit',  'me', 'Water',    'summons/waterspirit') }),
      fam('Air',       { ma('Air Spirit',    'me', 'Wind',     'summons/windspirit') }),
      fam('Fire',      { ma('Fire Spirit',   'me', 'Fire',     'summons/firespirit') }),
      fam('Ice',       { ma('Ice Spirit',    'me', 'Ice',      'summons/icespirit') }),
      fam('Thunder',   { ma('Thunder Spirit','me', 'Thunder',  'summons/thunderspirit') }),
      fam('Light',     { ma('Light Spirit',  'me', 'Light',    'summons/lightspirit') }),
      fam('Dark',      { ma('Dark Spirit',   'me', 'Dark',     'summons/darkspirit') }),
    }
  },

  pup_maneuvers = {
    label = 'Maneuvers', jobs = { 'PUP' }, icon = 'ffxiv/mch/rook_overload', alias = 'Maneuver',
    entries = {
      ja('Fire Maneuver',    'me', 'FireMan', 'ffxiv/pic/fire_in_red'),
      ja('Ice Maneuver',     'me', 'IceMan',  'ffxiv/pic/blizzard_in_cyan'),
      ja('Wind Maneuver',    'me', 'WndMan',  'ffxiv/pic/aero_in_green'),
      ja('Earth Maneuver',   'me', 'EthMan',  'ffxiv/pic/stone_in_yellow'),
      ja('Thunder Maneuver', 'me', 'ThrMan',  'ffxiv/pic/thunder_in_magenta'),
      ja('Water Maneuver',   'me', 'WtrMan',  'ffxiv/pic/water_in_blue'),
      ja('Light Maneuver',   'me', 'LghMan',  'ffxiv/pic/holy_in_white'),
      ja('Dark Maneuver',    'me', 'DrkMan',  'ffxiv/pic/comet_in_black'),
    },
  },

  sch_stratagems = {
    label = 'Stratagems', jobs = { 'SCH' }, icon = 'classes/sch', alias = 'Stratgm', autogen_always = true,
    entries = {
      ja('Penury',        'me', 'Penury'),
      ja('Celerity',      'me', 'Celer'),
      ja('Accession',     'me', 'Access'),
      ja('Rapture',       'me', 'Raptur'),
      ja('Altruism',      'me', 'Altru'),
      ja('Tranquility',   'me', 'Tranq'),
      ja('Perpetuance',   'me', 'Perp'),
      ja('Parsimony',     'me', 'Parsim'),
      ja('Alacrity',      'me', 'Alacr'),
      ja('Manifestation', 'me', 'Manif'),
      ja('Ebullience',    'me', 'Ebull'),
      ja('Focalization',  'me', 'Focus'),
      ja('Equanimity',    'me', 'Equan'),
      ja('Immanence',     'me', 'Imman'),
    },
  },

  bst_pet_commands = {
    autogen = false,
    label = 'Pet Commands', jobs = { 'BST' }, icon = 'classes/bst', alias = 'PetCmd',
    entries = {
      ja('Stay',     'me', 'Stay'),
      ja('Snarl',    'me', 'Snarl'),
      ja('Spur',     'me', 'Spur'),
      ja('Run Wild', 'me', 'RunWld'),
    },
  },

  bst_ready = {
    autogen = false,
    label = 'Ready', jobs = { 'BST' }, icon = 'classes/bst', alias = 'Ready',
    entries = {},
  },

  brd_core_songs = {
    label = 'Songs', jobs = { 'BRD' }, icon = 'classes/brd', alias = 'Songs',
    autogen = false,
    entries = {
      fam('March', { ma('Advancing March', 'me', 'March1'), ma('Victory March', 'me', 'March2'), ma('Honor March', 'me', 'Honor') }),
      fam('Minuet', { ma("Valor Minuet", 'me', 'Minuet1'), ma('Valor Minuet II', 'me', 'Minuet2'), ma('Valor Minuet III', 'me', 'Minuet3'), ma('Valor Minuet IV', 'me', 'Minuet4'), ma('Valor Minuet V', 'me', 'Minuet5') }),
      fam('Madrigal', { ma('Sword Madrigal', 'me', 'Madr1'), ma('Blade Madrigal', 'me', 'Madr2') }),
      fam('Ballad', { ma("Mage's Ballad", 'me', 'Ballad1'), ma("Mage's Ballad II", 'me', 'Ballad2'), ma("Mage's Ballad III", 'me', 'Ballad3') }),
      fam('Minne', { ma('Knight\'s Minne', 'me', 'Minne1'), ma('Knight\'s Minne II', 'me', 'Minne2'), ma('Knight\'s Minne III', 'me', 'Minne3'), ma('Knight\'s Minne IV', 'me', 'Minne4'), ma('Knight\'s Minne V', 'me', 'Minne5') }),
      fam('Paeon', { ma("Army's Paeon", 'me', 'Paeon1'), ma("Army's Paeon II", 'me', 'Paeon2'), ma("Army's Paeon III", 'me', 'Paeon3'), ma("Army's Paeon IV", 'me', 'Paeon4'), ma("Army's Paeon V", 'me', 'Paeon5'), ma("Army's Paeon VI", 'me', 'Paeon6') }),
      fam('Mazurka', { ma('Raptor Mazurka', 'me', 'Raptor'), ma('Chocobo Mazurka', 'me', 'Chocobo') }),
      fam('Mambo', { ma('Sheepfoe Mambo', 'me', 'Mambo1'), ma('Dragonfoe Mambo', 'me', 'Mambo2') }),
      fam('Lullaby', { ma('Foe Lullaby', 'stnpc', 'Lullaby'), ma('Foe Lullaby II', 'stnpc', 'Lullaby2'), ma('Horde Lullaby', 'stnpc', 'HLull'), ma('Horde Lullaby II', 'stnpc', 'HLull2') }),
      fam('Elegy', { ma('Battlefield Elegy', 'stnpc', 'Elegy1'), ma('Carnage Elegy', 'stnpc', 'Elegy2') }),
    }
  },
}

local function lower(s)
  return tostring(s or ''):lower()
end

local function table_contains(list, value)
  if not list then return false end
  for _, v in ipairs(list) do
    if tostring(v):upper() == tostring(value):upper() then return true end
  end
  return false
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

local SUPPRESSED_DYNAMIC_JA_TYPES = {
  PetCommand = true,
  Monster = true,
  CorsairShot = true,
  Scholar = true,
}

local function is_suppressed_dynamic_ja_type(type_name)
  return SUPPRESSED_DYNAMIC_JA_TYPES[tostring(type_name or '')] == true
end

local _learned_cache, _learned_at
local function build_learned_names()
  local now = os.clock()
  if _learned_cache and (now - (_learned_at or 0)) < 1.0 then return _learned_cache end

  local learned = { ja = {}, ma = {}, ws = {} }
  local abilities = windower.ffxi.get_abilities() or {}
  local spells = windower.ffxi.get_spells() or {}

  for _, id in pairs(abilities.job_abilities or {}) do
    local ability = resources.job_abilities[id]
    if ability and ability.en then learned.ja[lower(ability.en)] = true end
  end
  for _, id in pairs(abilities.pet_commands or {}) do
    local ability = resources.job_abilities[id] or priv_job_abilities[id]
    if ability and ability.en then learned.ja[lower(ability.en)] = true end
  end

  for _, id in pairs(abilities.weapon_skills or {}) do
    local ws = resources.weapon_skills[id]
    if ws and ws.en then learned.ws[lower(ws.en)] = true end
  end

  local priv = effective_priv_spells()
  for id, known in pairs(spells) do
    if known == true then
      local spell = resources.spells[id] or priv[id]
      if spell and spell.en then learned.ma[lower(spell.en)] = true end
    end
  end

  _learned_cache, _learned_at = learned, now
  return learned
end

local _spell_by_name, _ja_by_name
local function spell_by_name(name)
  if not _spell_by_name then
    local idx = {}
    for _, data in pairs(resources.spells) do
      if data.en then idx[lower(data.en)] = data end
    end
    _spell_by_name = idx
  end
  local n = lower(name)
  local s = _spell_by_name[n]
  if s then return s end
  for _, data in pairs(effective_priv_spells()) do
    if data.en and lower(data.en) == n then return data end
  end
  return nil
end
local function ja_by_name(name)
  if not _ja_by_name then
    local idx = {}
    for id, res in pairs(resources.job_abilities) do
      if res.en then idx[lower(res.en)] = { id = id, type = tostring(res.type or 'JobAbility') } end
    end
    _ja_by_name = idx
  end
  return _ja_by_name[lower(name)]
end

local function job_level_ok(player, action)
  if action.type == 'input' or action.type == 'key' or action.type == 'macro' or action.type == 'gs' or action.type == 'ct' or action.type == 'autora' then return true end

  if action.type == 'ma' then
    local spell = spell_by_name(action.action)
    if not spell or type(spell.levels) ~= 'table' then return true end
    local main_level = spell.levels[player.main_job_id]
    local sub_level = spell.levels[player.sub_job_id]
    local effective_sub = effective_subjob_level(player.main_job_level, player.sub_job_level)
    if main_level and player.main_job_level >= main_level then return true end
    if sub_level and effective_sub >= sub_level then return true end
    return false
  elseif action.type == 'ja' then
    local found = ja_by_name(action.action)
    local ability_id = found and found.id
    local ability_type = (found and found.type) or 'JobAbility'
    if not ability_id then return true end
    local level_data = ability_level_list[ability_id]
    if not level_data or type(level_data.levels) ~= 'table' then
      if ability_type == 'JobAbility' then
        local priv = priv_job_abilities[ability_id]
        if priv and priv.type and priv.type ~= 'JobAbility' then
          return true
        end
      end
      return ability_type ~= 'JobAbility'
    end
    local main_level = level_data.levels[player.main_job_id]
    local sub_level = level_data.levels[player.sub_job_id]
    local effective_sub = effective_subjob_level(player.main_job_level, player.sub_job_level)
    if main_level and player.main_job_level >= main_level then return true end
    if sub_level and effective_sub >= sub_level then return true end
    return false
  end

  return true
end

local function action_available(player, action, learned)
  if not action then return false end
  local action_type = lower(action.type)
  if action_type == 'input' or action_type == 'key' or action_type == 'macro' or action_type == 'gs' or action_type == 'ct' or action_type == 'autora' then return true end

  local accessible = job_level_ok(player, action)

  if action_type == 'ja' then
    return accessible
  end

  if learned[action_type] and learned[action_type][lower(action.action)] then return true end
  return accessible
end

local function mark_choice_status(player, action, learned)
  if not action then return nil end
  local action_type = lower(action.type)
  local known = true
  local accessible = true
  local available = true

  if learned[action_type] ~= nil then
    accessible = job_level_ok(player, action)
    known = learned[action_type][lower(action.action)] == true

    if action_type == 'ja' and accessible == true and next(learned.ja or {}) == nil then
      known = true
    end

    available = action_available(player, action, learned)
  end

  action._choice_known = known
  action._choice_accessible = accessible
  action._choice_unlearned = not known
  action._choice_inaccessible = not accessible
  action._choice_disabled = not available

  if not known then
    action._choice_disabled_reason = 'not learned'
  elseif not accessible then
    action._choice_disabled_reason = 'not available to current job/level'
  else
    action._choice_disabled_reason = nil
  end

  return action
end

local function copy_action(action, alias, icon)
  local out = {}
  for k, v in pairs(action) do out[k] = v end
  if alias and (out.alias == nil or out.alias == '' or out.alias == out.action) then out.alias = alias end
  if icon and (out.icon == nil or out.icon == '') then out.icon = icon end
  return out
end

local function shorten_choice_name(name)
  name = tostring(name or '')
  if _G.shorten_ability_name then
    return _G.shorten_ability_name(name)
  end
  local compact = name:gsub('[^%w]+', '')
  if compact == '' then return 'WS' end
  return compact:sub(1, 6)
end

local function is_dynamic_ws_group(group_id)
  local key = normalize_key(group_id)
  if key == 'ws_current' or key == 'weaponskills_current' or key == 'weapon_skills_current' then return true end
  if key == 'ws_main' or key == 'weaponskills_main' or key == 'weapon_skills_main' then return true end
  if key == 'ws_range' or key == 'ws_ranged' or key == 'weaponskills_range' or key == 'weapon_skills_range' then return true end
  if key:sub(1, 3) == 'ws_' and WEAPONSKILL_TYPE_KEYS[key:sub(4)] ~= nil then return true end
  if key:sub(1, 14) == 'weaponskills_' and WEAPONSKILL_TYPE_KEYS[key:sub(15)] ~= nil then return true end
  if key:sub(1, 14) == 'weapon_skills_' and WEAPONSKILL_TYPE_KEYS[key:sub(15)] ~= nil then return true end
  return false
end

local function dynamic_ws_skill_ids(player, group_id)
  local key = normalize_key(group_id)
  local ids = {}
  local seen = {}

  local function add_id(id)
    id = tonumber(id)
    if id and id ~= 0 and WEAPONSKILL_TYPES[id] and not seen[id] then
      table.insert(ids, id)
      seen[id] = true
    end
  end

  if key == 'ws_current' or key == 'weaponskills_current' or key == 'weapon_skills_current' then
    if player then
      add_id(player.current_weapon)
      add_id(player.current_range_weapon)
    end
  elseif key == 'ws_main' or key == 'weaponskills_main' or key == 'weapon_skills_main' then
    if player then add_id(player.current_weapon) end
  elseif key == 'ws_range' or key == 'ws_ranged' or key == 'weaponskills_range' or key == 'weapon_skills_range' then
    if player then add_id(player.current_range_weapon) end
  else
    local weapon_key = key
    weapon_key = weapon_key:gsub('^ws_', '')
    weapon_key = weapon_key:gsub('^weaponskills_', '')
    weapon_key = weapon_key:gsub('^weapon_skills_', '')
    add_id(WEAPONSKILL_TYPE_KEYS[weapon_key])
  end

  return ids
end

local function dynamic_ws_label(player, group_id)
  local key = normalize_key(group_id)
  if key == 'ws_current' or key == 'weaponskills_current' or key == 'weapon_skills_current' then
    return 'Weapon Skills'
  elseif key == 'ws_main' or key == 'weaponskills_main' or key == 'weapon_skills_main' then
    local name = player and WEAPONSKILL_TYPES[tonumber(player.current_weapon or 0)] or nil
    return (name or 'Main') .. ' WS'
  elseif key == 'ws_range' or key == 'ws_ranged' or key == 'weaponskills_range' or key == 'weapon_skills_range' then
    local name = player and WEAPONSKILL_TYPES[tonumber(player.current_range_weapon or 0)] or nil
    return (name or 'Range') .. ' WS'
  end

  local ids = dynamic_ws_skill_ids(player, group_id)
  if ids[1] and WEAPONSKILL_TYPES[ids[1]] then
    return WEAPONSKILL_TYPES[ids[1]] .. ' WS'
  end
  return 'Weapon Skills'
end

local function resolve_dynamic_ws_group(player, group_id)
  local skill_ids = dynamic_ws_skill_ids(player, group_id)
  if #skill_ids == 0 then return {}, 'no current weapon skill type found' end

  local skill_lookup = {}
  for _, id in ipairs(skill_ids) do skill_lookup[id] = true end

  local abilities = windower.ffxi.get_abilities() or {}
  local actions = {}

  for _, ws_id in pairs(abilities.weapon_skills or {}) do
    local ws = resources.weapon_skills[ws_id]
    if ws and ws.en and skill_lookup[tonumber(ws.skill)] then
      table.insert(actions, {
        type = 'ws',
        action = ws.en,
        target = 't',
        alias = shorten_choice_name(ws.en),
      })
    end
  end

  table.sort(actions, function(a, b)
    return tostring(a.action or '') < tostring(b.action or '')
  end)

  if #actions == 0 then return {}, 'no learned weapon skills for this weapon type' end
  return actions, nil
end

local function normalize_action_name_for_key(action_name)
  local value = tostring(action_name or ''):lower()
  value = value:gsub('[’`]', "'")
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  value = value:gsub('%s+', ' ')
  return value
end

local function add_action_key(keys, action_type, action_name)
  if action_type and action_name and tostring(action_name) ~= '' then
    keys[tostring(action_type or ''):lower() .. '|' .. normalize_action_name_for_key(action_name)] = true
  end
end

local function collect_group_action_keys(group)
  local keys = {}
  if not group then return keys end

  for _, action in ipairs(group.suppress or {}) do
    if type(action) == 'table' then
      add_action_key(keys, action.type or 'ja', action.action or action.name)
    else
      add_action_key(keys, 'ja', action)
    end
  end

  for _, entry in ipairs(group.entries or {}) do
    local choices = entry.choices or { entry }
    for _, action in ipairs(choices) do
      if action and action.type and action.action then
        add_action_key(keys, action.type, action.action)
      end
    end
  end
  return keys
end

local MAGIC_CATEGORY_ALIASES = {
  magic = 'all_magic', spell = 'all_magic', spells = 'all_magic', ma = 'all_magic', allmagic = 'all_magic', all_magic = 'all_magic',
  black = 'black_magic', blackmagic = 'black_magic', black_magic = 'black_magic', blm = 'black_magic',
  elemental = 'elemental_magic', elemental_magic = 'elemental_magic',
  dark = 'dark_magic', dark_magic = 'dark_magic', darkmagic = 'dark_magic', drk = 'dark_magic',
  white = 'white_magic', whitemagic = 'white_magic', white_magic = 'white_magic', whm = 'white_magic',
  healing = 'healing_magic', healing_magic = 'healing_magic', cures = 'healing_magic',
  divine = 'divine_magic', divine_magic = 'divine_magic', banish = 'divine_magic',
  enfeebling = 'enfeebling_magic', enfeebling_magic = 'enfeebling_magic', debuffs = 'enfeebling_magic',
  enhancing = 'enhancing_magic', enhancing_magic = 'enhancing_magic', buffs = 'enhancing_magic',
  blue = 'blue_magic', bluemagic = 'blue_magic', blue_magic = 'blue_magic', blu = 'blue_magic',
  nin = 'ninjutsu', ninja = 'ninjutsu', ninjutsu = 'ninjutsu',
  song = 'songs', songs = 'songs', bard = 'songs', brd = 'songs', bardsong = 'songs', bard_song = 'songs',
  summoning = 'summoning_magic', summoning_magic = 'summoning_magic', summon = 'summoning_magic', smn = 'summoning_magic', avatars = 'summoning_magic', avatar = 'summoning_magic',
  geomancy = 'geomancy', geo = 'geomancy', geomancy_magic = 'geomancy',
  geo_indi = 'geomancy_indi', geomancy_indi = 'geomancy_indi', indi = 'geomancy_indi', indi_spells = 'geomancy_indi',
  geo_luopan = 'geomancy_geo', geomancy_geo = 'geomancy_geo', geo_geo = 'geomancy_geo', luopan = 'geomancy_geo', geo_buff = 'geomancy_geo', geo_debuff = 'geomancy_geo',
  trust = 'trust', trusts = 'trust',
  scholar = 'scholar_magic', scholar_magic = 'scholar_magic', sch_magic = 'scholar_magic', scholarmagic = 'scholar_magic',
}

local MAGIC_SUPER_CATEGORIES = {
  black_magic = { elemental_magic = true, dark_magic = true },
  white_magic  = { healing_magic = true, divine_magic = true, enhancing_magic = true, enfeebling_magic = true },
}

local MAGIC_CATEGORY_LABELS = {
  black_magic = 'Black Magic', white_magic = 'White Magic', blue_magic = 'Blue Magic',
  elemental_magic = 'Elemental', dark_magic = 'Dark Magic',
  healing_magic = 'Healing', divine_magic = 'Divine', enhancing_magic = 'Enhancing', enfeebling_magic = 'Enfeebling',
  ninjutsu = 'Ninjutsu', songs = 'Songs', summoning_magic = 'Summoning', geomancy = 'Geomancy', trust = 'Trusts',
  geomancy_indi = 'Indi-', geomancy_geo = 'Geo-',
  scholar_magic = 'Scholar Magic',
}

local MAGIC_CATEGORY_ICONS = {
  black_magic = 'classes/blm', white_magic = 'classes/whm', blue_magic = 'classes/blu',
  elemental_magic = 'classes/blm', dark_magic = 'classes/drk',
  healing_magic = 'classes/whm', divine_magic = 'classes/whm', enhancing_magic = 'classes/whm', enfeebling_magic = 'classes/rdm',
  ninjutsu = 'classes/nin', songs = 'classes/brd', summoning_magic = 'classes/smn', geomancy = 'classes/geo', trust = 'ffxiv/general/party',
  geomancy_indi = 'classes/geo', geomancy_geo = 'classes/geo',
  scholar_magic = 'classes/sch',
}

local function has_bit(value, bit_value)
  value = tonumber(value) or 0
  bit_value = tonumber(bit_value) or 0
  if bit_value <= 0 then return false end
  return math.floor(value / bit_value) % 2 >= 1
end

local function action_default_target(action_type, data)
  action_type = tostring(action_type or ''):lower()
  if action_type == 'ws' then return 't' end
  if not data then return 'me' end

  local targets = data.targets
  local self_target = false
  local friendly_target = false
  local hostile_target = false
  local object_target = false
  local corpse_target = false

  if type(targets) == 'number' then
    self_target = has_bit(targets, 1)
    friendly_target = has_bit(targets, 2) or has_bit(targets, 4) or has_bit(targets, 8) or has_bit(targets, 16)
    hostile_target = has_bit(targets, 32) or has_bit(targets, 64)
    object_target = has_bit(targets, 128)
    corpse_target = has_bit(targets, 256)
  elseif type(targets) == 'table' then
    local function target_flag(key)
      if targets[key] or targets[tostring(key):lower()] then return true end
      for k, v in pairs(targets) do
        if v and tostring(k):lower() == tostring(key):lower() then return true end
      end
      return false
    end
    self_target = target_flag('Self')
    friendly_target = target_flag('Player') or target_flag('PC') or target_flag('Party') or target_flag('Ally')
    hostile_target = target_flag('Enemy') or target_flag('NPC')
    object_target = target_flag('Object')
    corpse_target = target_flag('Corpse')
  end

  local data_type = tostring(data.type or data.skill or ''):lower()
  if self_target and not friendly_target and not hostile_target and not object_target and not corpse_target then return 'me' end
  if action_type == 'ma' and (data_type:find('summon', 1, true) or data_type:find('trust', 1, true)) then return 'me' end
  if friendly_target then return 'stpc' end
  if hostile_target then
    local action_name = tostring(data.en or data.name or ''):lower()
    if action_type == 'ja' and (action_name:find('step', 1, true) or action_name:find('shot', 1, true)) then return 't' end
    return 'stnpc'
  end
  if object_target or corpse_target then return 'st' end
  return 'me'
end

local function detect_magic_category(spell)
  if not spell then return nil end
  local t = normalize_key(spell.type or '')
  local skill = tonumber(spell.skill or 0) or 0
  if type(spell.levels) == 'table' and spell.levels[20] ~= nil then
    local job_count = 0
    for _ in pairs(spell.levels) do job_count = job_count + 1 end
    if job_count == 1 then return 'scholar_magic' end
  end
  if t:find('blue', 1, true) then return 'blue_magic' end
  if t:find('ninjutsu', 1, true) then return 'ninjutsu' end
  if t:find('bard', 1, true) or t:find('song', 1, true) then return 'songs' end
  if t:find('summon', 1, true) or t:find('avatar', 1, true) then return 'summoning_magic' end
  if t:find('geomancy', 1, true) or t == 'geo' then return 'geomancy' end
  if t:find('trust', 1, true) then return 'trust' end
  if t:find('black', 1, true) then
    if skill == 37 then return 'dark_magic' end
    return 'elemental_magic'
  end
  if t:find('white', 1, true) then
    if skill == 32 then return 'divine_magic' end
    if skill == 33 then return 'healing_magic' end
    if skill == 34 then return 'enfeebling_magic' end
    if skill == 35 then return 'enhancing_magic' end
    return 'white_magic'
  end
  return 'all_magic'
end

local function magic_category_from_group_id(group_id)
  local key = normalize_key(group_id)
  key = key:gsub('^choice_', '')
  if MAGIC_CATEGORY_ALIASES[key] then return MAGIC_CATEGORY_ALIASES[key] end
  if key:sub(1, 3) == 'ma_' then key = key:sub(4) end
  if MAGIC_CATEGORY_ALIASES[key] then return MAGIC_CATEGORY_ALIASES[key] end
  if key:sub(1, 6) == 'magic_' then key = key:sub(7) end
  if MAGIC_CATEGORY_ALIASES[key] then return MAGIC_CATEGORY_ALIASES[key] end
  if key:sub(1, 7) == 'spells_' then key = key:sub(8) end
  if MAGIC_CATEGORY_ALIASES[key] then return MAGIC_CATEGORY_ALIASES[key] end
  return nil
end

local function is_dynamic_magic_group(group_id)
  return magic_category_from_group_id(group_id) ~= nil
end

local function dynamic_magic_label(group_id)
  local category = magic_category_from_group_id(group_id)
  return MAGIC_CATEGORY_LABELS[category] or 'Magic'
end

local function spell_action_from_data(spell)
  return ma(spell.en, action_default_target('ma', spell), shorten_choice_name(spell.en), MAGIC_CATEGORY_ICONS[detect_magic_category(spell)])
end

local function resolve_dynamic_magic_group(player, group_id)
  local cached = dynamic_group_cache[group_id]
  if cached then return cached, nil end

  local category = magic_category_from_group_id(group_id)
  if not category then return {}, 'unknown magic category' end

  local geo_prefix = nil
  if category == 'geomancy_indi' then
    geo_prefix = 'Indi-'
    category = 'geomancy'
  elseif category == 'geomancy_geo' then
    geo_prefix = 'Geo-'
    category = 'geomancy'
  end

  local learned = build_learned_names()
  local subcats = MAGIC_SUPER_CATEGORIES[category]
  local actions = {}

  local is_blu = player and player.main_job == 'BLU'
  local blu_set_ids = {}
  if is_blu and player.set_blue_magic then
    for _, sid in pairs(player.set_blue_magic) do blu_set_ids[tonumber(sid)] = true end
  end

  local function passes_filter(action, spell, spell_id)
    if geo_prefix ~= nil then
      return learned.ma and learned.ma[lower(action.action or '')] == true
    end
    if action_available(player, action, learned) then return true end
    if spell and type(spell.levels) == 'table' and player and player.main_job_id and spell.levels[player.main_job_id] then
      if is_blu and tostring(spell.type or ''):find('blue', 1, true) then
        return blu_set_ids[tonumber(spell_id)] == true
      end
      return true
    end
    return false
  end

  local seen_spell_ids = {}
  for id, spell in pairs(resources.spells or {}) do
    seen_spell_ids[id] = true
    if spell and spell.en and spell.en ~= '' then
      local spell_category = detect_magic_category(spell)
      local prefix_ok = (geo_prefix == nil) or (spell.en:sub(1, #geo_prefix) == geo_prefix)
      local cat_ok = category == 'all_magic' or spell_category == category or (subcats and subcats[spell_category])
      if prefix_ok and cat_ok then
        local action = spell_action_from_data(spell)
        if passes_filter(action, spell, id) then
          mark_choice_status(player, action, learned)
          table.insert(actions, action)
        end
      end
    end
  end
  for id, spell in pairs(effective_priv_spells()) do
    if not seen_spell_ids[id] and spell and spell.en and spell.en ~= '' then
      local spell_category = detect_magic_category(spell)
      local prefix_ok = (geo_prefix == nil) or (spell.en:sub(1, #geo_prefix) == geo_prefix)
      local cat_ok = category == 'all_magic' or spell_category == category or (subcats and subcats[spell_category])
      if prefix_ok and cat_ok then
        local action = spell_action_from_data(spell)
        if passes_filter(action, spell, id) then
          mark_choice_status(player, action, learned)
          table.insert(actions, action)
        end
      end
    end
  end

  table.sort(actions, function(a, b)
    return tostring(a.action or '') < tostring(b.action or '')
  end)

  if #actions == 0 then return {}, 'no available ' .. tostring(dynamic_magic_label(group_id)) end
  dynamic_group_cache[group_id] = actions
  return actions, nil
end

local function dynamic_ja_type_from_group_id(group_id)
  local key = normalize_key(group_id)
  key = key:gsub('^choice_', '')
  if key == 'ja_current' or key == 'job_abilities_current' or key == 'abilities_current' then return '__current__' end
  key = key:gsub('^ja_type_', '')
  key = key:gsub('^job_ability_type_', '')
  key = key:gsub('^job_abilities_type_', '')
  key = key:gsub('^ability_type_', '')
  key = key:gsub('^abilities_type_', '')
  key = key:gsub('^ja_', '')

  for _, ability in pairs(resources.job_abilities or {}) do
    if ability and ability.type and normalize_key(ability.type) == key then
      return ability.type
    end
  end
  for _, ability in pairs(priv_job_abilities) do
    if type(ability) == 'table' and ability.type and normalize_key(ability.type) == key then
      return ability.type
    end
  end
  return nil
end

local function format_dynamic_type_label(type_name)
  if type_name == '__current__' then return 'Abilities' end
  local text = tostring(type_name or 'Abilities')
  text = text:gsub('([a-z])([A-Z])', '%1 %2')
  text = text:gsub('(%a)(%d)', '%1 %2')
  text = text:gsub('(%d)(%a)', '%1 %2')
  return text
end

local function dynamic_ja_group_id(type_name)
  return 'ja_type_' .. normalize_key(type_name)
end

local function is_dynamic_ja_group(group_id)
  return dynamic_ja_type_from_group_id(group_id) ~= nil
end

local function dynamic_ja_label(group_id)
  return format_dynamic_type_label(dynamic_ja_type_from_group_id(group_id))
end

local function ability_action_from_data(ability)
  return ja(ability.en, action_default_target('ja', ability), shorten_choice_name(ability.en))
end

local function resolve_dynamic_ja_group(player, group_id)
  local cached = dynamic_group_cache[group_id]
  if cached then return cached, nil end

  local wanted_type = dynamic_ja_type_from_group_id(group_id)
  if not wanted_type then return {}, 'unknown job ability category' end

  if BLOOD_PACT_BY_TYPE[wanted_type] then
    local learned = build_learned_names()
    local actions = {}
    for _, ability in ipairs(BLOOD_PACT_BY_TYPE[wanted_type]) do
      if learned.ja[lower(ability.en)] then
        local action = ability_action_from_data(ability)
        action._choice_known = true
        action._choice_accessible = true
        action._choice_unlearned = false
        action._choice_inaccessible = false
        action._choice_disabled = false
        action._choice_disabled_reason = nil
        table.insert(actions, action)
      end
    end
    table.sort(actions, function(a, b) return (a.action or '') < (b.action or '') end)
    if #actions == 0 then return {}, 'no available ' .. tostring(dynamic_ja_label(group_id)) end
    return actions, nil
  end

  local learned = build_learned_names()
  local actions = {}
  local seen_en = {}

  local function ja_passes(action, ability_id)
    if action_available(player, action, learned) then return true end
    local ld = ability_level_list[tonumber(ability_id) or ability_id]
    if ld and type(ld.levels) == 'table' and player and player.main_job_id and ld.levels[player.main_job_id] then
      return true
    end
    return false
  end

  for ability_id, ability in pairs(resources.job_abilities or {}) do
    if ability and ability.en and ability.en ~= '' then
      local ability_type = tostring(ability.type or 'JobAbility')
      if wanted_type == '__current__' or ability_type == wanted_type then
        local action = ability_action_from_data(ability)
        if ja_passes(action, ability_id) then
          mark_choice_status(player, action, learned)
          table.insert(actions, action)
          seen_en[lower(ability.en)] = true
        end
      end
    end
  end
  for ability_id, ability in pairs(priv_job_abilities) do
    if type(ability) == 'table' and ability.en and ability.en ~= ''
        and not seen_en[lower(ability.en)] then
      local ability_type = tostring(ability.type or 'JobAbility')
      if ability_type ~= 'JobAbility' and (wanted_type == '__current__' or ability_type == wanted_type) then
        local action = ability_action_from_data(ability)
        if action_available(player, action, learned) then
          mark_choice_status(player, action, learned)
          table.insert(actions, action)
        end
      end
    end
  end

  table.sort(actions, function(a, b)
    return tostring(a.action or '') < tostring(b.action or '')
  end)

  if #actions == 0 then return {}, 'no available ' .. tostring(dynamic_ja_label(group_id)) end
  dynamic_group_cache[group_id] = actions
  return actions, nil
end

local function merge_keys(dest, src)
  for key, value in pairs(src or {}) do if value then dest[key] = true end end
end

local function action_key_for_group(action)
  if not action or not action.type or not action.action then return nil end
  return tostring(action.type or ''):lower() .. '|' .. normalize_action_name_for_key(action.action)
end

local function ability_autogen_category(player, ability)
  if not player or not ability then return 'main' end
  local ability_id = tonumber(ability.id or 0) or 0
  local level_data = ability_level_list[ability_id]
  if not level_data or type(level_data.levels) ~= 'table' then return nil end

  local main_level = level_data.levels[player.main_job_id]
  local sub_level = level_data.levels[player.sub_job_id]
  local effective_sub = effective_subjob_level(player.main_job_level, player.sub_job_level)
  if main_level and player.main_job_level and player.main_job_level >= main_level then return 'main' end
  if sub_level and effective_sub and effective_sub >= sub_level then return 'sub' end
  return nil
end

local function dynamic_ja_autogen_entries(player, covered_keys)
  local entries = {}
  local type_counts = {}
  local type_uncovered = {}
  local type_category = {}
  local learned = build_learned_names()

  local abilities_rt = windower.ffxi.get_abilities() or {}
  local accessible_ids = {}
  for _, id in pairs(abilities_rt.job_abilities or {}) do accessible_ids[id] = true end
  for _, id in pairs(abilities_rt.pet_commands or {}) do accessible_ids[id] = true end

  for ability_id, ability in pairs(resources.job_abilities or {}) do
    if ability and ability.en and ability.en ~= '' then
      local ability_type = tostring(ability.type or 'JobAbility')
      local action = ability_action_from_data(ability)
      if not is_suppressed_dynamic_ja_type(ability_type) and action_available(player, action, learned) then
        type_counts[ability_type] = (type_counts[ability_type] or 0) + 1
        local ability_category = ability_autogen_category(player, ability)
        if ability_category == nil and ability_type ~= 'JobAbility' and accessible_ids[ability_id] then
          ability_category = 'main'
        end
        if type_category[ability_type] ~= 'main' then type_category[ability_type] = ability_category end
        local key = action_key_for_group(action)
        if key and not covered_keys[key] then
          type_uncovered[ability_type] = (type_uncovered[ability_type] or 0) + 1
        end
      end
    end
  end
  for bp_type, abilities in pairs(BLOOD_PACT_BY_TYPE) do
    if not is_suppressed_dynamic_ja_type(bp_type) then
      for _, ability in ipairs(abilities) do
        local action = ability_action_from_data(ability)
        if action_available(player, action, learned) then
          local ability_category = ability_autogen_category(player, ability)
          if ability_category == nil and player and player.main_job_id == 15 then
            ability_category = 'main'
          end
          if ability_category ~= nil then
            type_counts[bp_type] = (type_counts[bp_type] or 0) + 1
            if type_category[bp_type] ~= 'main' then
              type_category[bp_type] = ability_category
            end
            local key = action_key_for_group(action)
            if key and not covered_keys[key] then
              type_uncovered[bp_type] = (type_uncovered[bp_type] or 0) + 1
            end
          end
        end
      end
    end
  end

  for ability_type, count in pairs(type_counts) do
    if ability_type ~= 'JobAbility' and not is_suppressed_dynamic_ja_type(ability_type)
        and count > 1 and (type_uncovered[ability_type] or 0) > 0 and type_category[ability_type] ~= nil then
      table.insert(entries, {
        category = type_category[ability_type] or 'main',
        type = 'choice',
        action = dynamic_ja_group_id(ability_type),
        target = '',
        alias = format_dynamic_type_label(ability_type),
        icon = nil,
        level = 0,
      })
    end
  end

  return entries
end

local _parent_ability_set
function choice_groups:parent_ability_set()
  if _parent_ability_set then return _parent_ability_set end
  _parent_ability_set = {}
  for _, g in pairs(self.groups or {}) do
    for _, name in ipairs(g.suppress or {}) do
      _parent_ability_set[tostring(name):lower()] = true
    end
  end
  return _parent_ability_set
end

function choice_groups:is_parent_ability(name)
  if not name or name == '' then return false end
  return self:parent_ability_set()[tostring(name):lower()] == true
end

function choice_groups:exists(group_id)
  if self.groups[tostring(group_id or '')] ~= nil then return true end
  if is_dynamic_ws_group(group_id) then return true end
  if is_dynamic_magic_group(group_id) then return true end
  if is_dynamic_ja_group(group_id) then return true end
  if is_user_trust_group(group_id) then return true end
  return false
end

function choice_groups:is_empty(player, group_id)
  local entries, _ = self:resolve(player, group_id)
  return entries == nil or #entries == 0
end

local function strip_tier_suffix(name)
  if not name then return name end
  local base = tostring(name):match('^(.-)%s+[IVX]+$')
  return base or name
end

function choice_groups:get_label(group_id, player)
  local group = self.groups[tostring(group_id or '')]
  if group then return strip_tier_suffix(group.label or group_id) end
  if is_dynamic_ws_group(group_id) then return dynamic_ws_label(player, group_id) end
  if is_dynamic_magic_group(group_id) then return strip_tier_suffix(dynamic_magic_label(group_id)) end
  if is_dynamic_ja_group(group_id) then return strip_tier_suffix(dynamic_ja_label(group_id)) end
  if is_user_trust_group(group_id) then return 'Trusts' end
  return strip_tier_suffix(group_id)
end

local SCH_LA_STRATAGEMS = {
  ja('Penury',        'me', 'Penury',  'classes/sch'),
  ja('Celerity',      'me', 'Celer',   'classes/sch'),
  ja('Accession',     'me', 'Access',  'classes/sch'),
  ja('Rapture',       'me', 'Raptur',  'classes/sch'),
  ja('Altruism',      'me', 'Altru',   'classes/sch'),
  ja('Tranquility',   'me', 'Tranq',   'classes/sch'),
  ja('Perpetuance',   'me', 'Perp',    'classes/sch'),
}

local SCH_DA_STRATAGEMS = {
  ja('Parsimony',     'me', 'Parsim',  'classes/sch'),
  ja('Alacrity',      'me', 'Alacr',   'classes/sch'),
  ja('Manifestation', 'me', 'Manif',   'classes/sch'),
  ja('Ebullience',    'me', 'Ebull',   'classes/sch'),
  ja('Focalization',  'me', 'Focus',   'classes/sch'),
  ja('Equanimity',    'me', 'Equan',   'classes/sch'),
  ja('Immanence',     'me', 'Imman',   'classes/sch'),
}

local function resolve_bst_pet_commands(player)
  local learned = build_learned_names()
  local actions = {}
  local has_jug = player and player.has_jug_pet == true
  for _, entry in ipairs(choice_groups.groups['bst_pet_commands'].entries or {}) do
    local name = tostring(entry.action or '')
    local jug_only = (name == 'Snarl' or name == 'Run Wild')
    if not jug_only or has_jug then
      local resolved = copy_action(entry)
      mark_choice_status(player, resolved, learned)
      table.insert(actions, resolved)
    end
  end
  return actions, nil
end

local function resolve_bst_ready(player)
  local abilities = _G.usable_pet_abilities_name
  if not abilities or #abilities == 0 then
    return {}, nil
  end
  local learned = build_learned_names()
  local actions = {}
  for _, name in ipairs(abilities) do
    local action = ja(name, 'me', shorten_choice_name(name))
    action.exec_prefix = 'pet'
    mark_choice_status(player, action, learned)
    table.insert(actions, action)
  end
  return actions, nil
end

local function resolve_sch_stratagems(player)
  local show_la = false
  local show_da = false

  if player and player.buffs then
    for _, id in ipairs(player.buffs) do
      id = tonumber(id)
      if id == 358 or id == 401 then show_la = true end
      if id == 359 or id == 402 then show_da = true end
    end
  end

  if not show_la and not show_da then
    return {}, nil
  end

  local learned = build_learned_names()
  local actions = {}
  local function add_stratagems(list)
    for _, entry in ipairs(list) do
      local resolved = copy_action(entry)
      mark_choice_status(player, resolved, learned)
      table.insert(actions, resolved)
    end
  end

  if show_la then add_stratagems(SCH_LA_STRATAGEMS) end
  if show_da then add_stratagems(SCH_DA_STRATAGEMS) end
  return actions, nil
end

function choice_groups:resolve(player, group_id)
  self:ensure_user_groups(player)
  local group = self.groups[tostring(group_id or '')]
  if not group then
    if is_dynamic_ws_group(group_id) then
      return resolve_dynamic_ws_group(player, group_id)
    end
    if is_dynamic_magic_group(group_id) then
      return resolve_dynamic_magic_group(player, group_id)
    end
    if is_dynamic_ja_group(group_id) then
      return resolve_dynamic_ja_group(player, group_id)
    end
    if is_user_trust_group(group_id) then
      local actions = build_user_trust_actions(player)
      if #actions == 0 then return {}, 'no trusts configured; use //htb set up trust' end
      return actions, nil
    end
    return {}, 'unknown choice group'
  end

  if group_id == 'sch_stratagems' then
    return resolve_sch_stratagems(player)
  end
  if group_id == 'bst_ready' then
    return resolve_bst_ready(player)
  end
  if group_id == 'bst_pet_commands' then
    return resolve_bst_pet_commands(player)
  end

  local learned = build_learned_names()
  local actions = {}

  for _, entry in ipairs(group.entries or {}) do
    if entry.choices then
      for _, candidate in ipairs(entry.choices) do
        local resolved = copy_action(candidate, nil, entry.icon)
        mark_choice_status(player, resolved, learned)
        table.insert(actions, resolved)
      end
    else
      local resolved = copy_action(entry)
      mark_choice_status(player, resolved, learned)
      table.insert(actions, resolved)
    end
  end

  return actions, nil
end

function choice_groups:get_group_action_keys(group_id, player)
  local key = tostring(group_id or '')
  local group = self.groups[key]
  if group then
    return collect_group_action_keys(group)
  end

  local keys = {}
  if is_dynamic_ws_group(group_id) or is_dynamic_magic_group(group_id) or is_dynamic_ja_group(group_id) or is_user_trust_group(group_id) then
    local actions = self:resolve(player, group_id)
    for _, action in ipairs(actions or {}) do
      if action and action.type and action.action then
        add_action_key(keys, action.type, action.action)
      end
    end
  end
  return keys
end

function choice_groups:get_grouped_action_keys(player)
  local keys = {}
  for group_id, _ in pairs(self.groups) do
    local group_keys = self:get_group_action_keys(group_id, player)
    for action_key, _ in pairs(group_keys) do keys[action_key] = true end
  end
  return keys
end

function choice_groups:get_grouped_action_names()
  local names = {}
  for _, group in pairs(self.groups) do
    for _, entry in ipairs(group.entries or {}) do
      local choices = entry.choices or { entry }
      for _, action in ipairs(choices) do
        if action.action then names[lower(action.action)] = true end
      end
    end
  end
  return names
end

function choice_groups:get_autogen_entries(player)
  self:ensure_user_groups(player)
  local entries = {}
  local covered_keys = {}

  for group_id, group in pairs(self.groups) do
    local category = nil
    if group.autogen == false then
      category = nil
    elseif table_contains(group.jobs, player.main_job) then
      category = 'main'
    elseif table_contains(group.jobs, player.sub_job) then
      category = 'sub'
    end

    if category then
      local choices = self:resolve(player, group_id)
      if (choices and #choices > 0) or group.autogen_always then
        table.insert(entries, {
          category = category,
          type = 'choice',
          action = group_id,
          target = '',
          alias = group.alias or group.label or group_id,
          icon = group.icon,
          level = 0,
        })
        merge_keys(covered_keys, self:get_group_action_keys(group_id, player))
      end
    end
  end

  for _, entry in ipairs(dynamic_ja_autogen_entries(player, covered_keys)) do
    table.insert(entries, entry)
    merge_keys(covered_keys, self:get_group_action_keys(entry.action, player))
  end

  if player and (player.main_job == 'GEO' or player.sub_job == 'GEO') then
    local geo_defs = {
      { id = 'geomancy_indi', alias = 'Indi', sort_order = 1 },
      { id = 'geomancy_geo',  alias = 'Geo',  sort_order = 2 },
    }
    for _, g in ipairs(geo_defs) do
      local actions = self:resolve(player, g.id)
      if actions and #actions > 0 then
        table.insert(entries, {
          category = 'geomancy',
          type = 'choice',
          action = g.id,
          target = '',
          alias = g.alias,
          icon = 'classes/geo',
          level = 0,
          sort_order = g.sort_order,
        })
        merge_keys(covered_keys, self:get_group_action_keys(g.id, player))
      end
    end
  end

  table.sort(entries, function(a, b) return tostring(a.action) < tostring(b.action) end)
  return entries
end

local function group_is_ja(group)
  for _, entry in ipairs(group.entries or {}) do
    local first = (entry.choices and entry.choices[1]) or entry
    if first and first.type then return tostring(first.type):lower() == 'ja' end
  end
  return false
end

function choice_groups:get_smart_choices(player)
  local entries = self:get_autogen_entries(player)
  local covered_keys = {}
  local present = {}
  for _, e in ipairs(entries) do
    present[e.action] = true
    merge_keys(covered_keys, self:get_group_action_keys(e.action, player))
  end

  for group_id, group in pairs(self.groups) do
    if not present[group_id] and not group.user and group.autogen ~= false and group_is_ja(group)
        and (table_contains(group.jobs, player.main_job) or table_contains(group.jobs, player.sub_job)) then
      table.insert(entries, { category = 'main', type = 'choice', action = group_id, target = '',
        alias = group.alias or group.label or group_id, icon = group.icon, level = 0 })
      present[group_id] = true
      merge_keys(covered_keys, self:get_group_action_keys(group_id, player))
    end
  end

  for _, ws_group in ipairs({ 'ws_main', 'ws_range' }) do
    local ws_actions = self:resolve(player, ws_group)
    if ws_actions and #ws_actions > 0 then
      table.insert(entries, { category = 'main', type = 'choice', action = ws_group,
        target = '', alias = nil, icon = nil, level = 0 })
      merge_keys(covered_keys, self:get_group_action_keys(ws_group, player))
    end
  end

  local cat_counts, cat_uncovered = {}, {}
  for _, spell in pairs(resources.spells or {}) do
    if spell and spell.en and spell.en ~= '' then
      local action = spell_action_from_data(spell)
      if job_level_ok(player, action) then
        local category = detect_magic_category(spell)
        if category and category ~= 'trust' and category ~= 'all_magic' then
          cat_counts[category] = (cat_counts[category] or 0) + 1
          local key = action_key_for_group(action)
          if key and not covered_keys[key] then
            cat_uncovered[category] = (cat_uncovered[category] or 0) + 1
          end
        end
      end
    end
  end
  for category, count in pairs(cat_counts) do
    if count > 1 and (cat_uncovered[category] or 0) > 0 then
      table.insert(entries, { category = 'main', type = 'choice', action = category, target = '',
        alias = MAGIC_CATEGORY_LABELS[category] or category, icon = MAGIC_CATEGORY_ICONS[category], level = 0 })
    end
  end

  return entries
end

function choice_groups:get_group_shared_recast_id(group_id)
  local wanted_type = dynamic_ja_type_from_group_id(group_id)
  if not wanted_type then return nil end
  local list = BLOOD_PACT_BY_TYPE[wanted_type]
  if not list or not list[1] then return nil end
  return tonumber(list[1].recast_id) or nil
end

function choice_groups:get_flat_leaf_entries(group_id)
  local group = self.groups[tostring(group_id or '')]
  if not group then return nil end

  local entries = {}

  local function collect(entry)
    if type(entry) ~= 'table' then return end
    if entry.choices then
      for _, sub in ipairs(entry.choices) do collect(sub) end
    elseif entry.type == 'ja' or entry.type == 'ma' then
      table.insert(entries, entry)
    end
  end

  for _, entry in ipairs(group.entries or {}) do
    collect(entry)
  end

  return entries
end

function choice_groups:is_ws_group(group_id)
  return is_dynamic_ws_group(group_id)
end

function choice_groups:is_magic_group(group_id)
  return is_dynamic_magic_group(group_id)
end

function choice_groups:print_groups()
  windower.add_to_chat(8, 'XIVHOTBAR2 choice groups:')
  local keys = {}
  for key, _ in pairs(self.groups) do table.insert(keys, key) end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local group = self.groups[key]
    windower.add_to_chat(8, string.format('  %s - %s', key, group.label or key))
  end
  windower.add_to_chat(8, '  ws_current - current equipped weapon skill choices')
  windower.add_to_chat(8, '  ws_sword / ws_dagger / ws_marksmanship / etc. - specific weapon choices')
  windower.add_to_chat(8, '  black_magic / white_magic / blue_magic / ninjutsu / songs / summoning_magic / geomancy / geo_indi / geo_luopan / trust - dynamic magic categories')
  windower.add_to_chat(8, '  ja_type_<category> - dynamic job ability categories, e.g. ja_type_waltz, ja_type_corsairroll, ja_type_bloodpactrage')
  windower.add_to_chat(8, '  trust_custom - your configured Trust magic choices from //htb set up trust')
end

local user_loaded_name = nil
local injected_user_ids = {}
local builtin_backup = {}

local function user_groups_path(player)
  if not player or not player.name or player.name == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/choice_groups.lua'
end

local function clear_injected_user_groups()
  for id in pairs(injected_user_ids) do
    if builtin_backup[id] ~= nil then
      choice_groups.groups[id] = builtin_backup[id]
    elseif choice_groups.groups[id] and choice_groups.groups[id].user then
      choice_groups.groups[id] = nil
    end
  end
  injected_user_ids = {}
  builtin_backup = {}
end

local function sanitize_user_entry(entry)
  if type(entry) ~= 'table' then return nil end
  local action_type = tostring(entry.type or ''):lower()
  local action_name = entry.action or entry.name
  if action_type == '' or not action_name or tostring(action_name) == '' then return nil end
  return {
    type = action_type,
    action = tostring(action_name),
    target = (entry.target and tostring(entry.target) ~= '' and tostring(entry.target)) or 'me',
    alias = entry.alias and tostring(entry.alias) or nil,
    icon = entry.icon and tostring(entry.icon) or nil,
  }
end

local function inject_user_group(def)
  local id = tostring(def.id or '')
  if id == '' then return nil end
  local entries = {}
  for _, entry in ipairs(def.entries or {}) do
    local clean = sanitize_user_entry(entry)
    if clean then entries[#entries + 1] = clean end
  end
  if choice_groups.groups[id] and not choice_groups.groups[id].user and builtin_backup[id] == nil then
    builtin_backup[id] = choice_groups.groups[id]
  end
  choice_groups.groups[id] = {
    user = true,
    _user_id = id,
    label = def.label and tostring(def.label) or id,
    alias = def.alias and tostring(def.alias) or (def.label and tostring(def.label)) or id,
    icon = def.icon and tostring(def.icon) or nil,
    jobs = def.jobs,
    autogen = def.autogen == true and true or false,
    suppress = def.suppress,
    entries = entries,
  }
  injected_user_ids[id] = true
  return choice_groups.groups[id]
end

local function load_user_group_defs(player)
  local path = user_groups_path(player)
  if not path then return {} end
  local chunk = loadfile(path)
  if not chunk then return {} end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= 'table' then return {} end
  return data
end

local function quote(value)
  return string.format('%q', tostring(value))
end

local function serialize_jobs(jobs)
  if type(jobs) ~= 'table' or #jobs == 0 then return nil end
  local parts = {}
  for _, j in ipairs(jobs) do parts[#parts + 1] = quote(j) end
  return '{ ' .. table.concat(parts, ', ') .. ' }'
end

local function write_user_groups(player)
  local path = user_groups_path(player)
  if not path then return false end
  local lines = { '-- XivUI user choice groups (generated by the XivUI Menu)', 'return {' }
  for id in pairs(injected_user_ids) do
    local g = choice_groups.groups[id]
    if g and g.user then
      lines[#lines + 1] = '  {'
      lines[#lines + 1] = '    id = ' .. quote(g._user_id) .. ','
      lines[#lines + 1] = '    label = ' .. quote(g.label) .. ','
      lines[#lines + 1] = '    alias = ' .. quote(g.alias or g.label) .. ','
      if g.icon then lines[#lines + 1] = '    icon = ' .. quote(g.icon) .. ',' end
      local jobs = serialize_jobs(g.jobs)
      if jobs then lines[#lines + 1] = '    jobs = ' .. jobs .. ',' end
      if g.autogen == true then lines[#lines + 1] = '    autogen = true,' end
      lines[#lines + 1] = '    entries = {'
      for _, e in ipairs(g.entries or {}) do
        local parts = { 'type=' .. quote(e.type), 'action=' .. quote(e.action),
                        'target=' .. quote(e.target or 'me') }
        if e.alias then parts[#parts + 1] = 'alias=' .. quote(e.alias) end
        if e.icon then parts[#parts + 1] = 'icon=' .. quote(e.icon) end
        lines[#lines + 1] = '      { ' .. table.concat(parts, ', ') .. ' },'
      end
      lines[#lines + 1] = '    },'
      lines[#lines + 1] = '  },'
    end
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = ''
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(table.concat(lines, '\n'))
  f:close()
  return true
end

function choice_groups:reload_user_groups(player)
  clear_injected_user_groups()
  for _, def in ipairs(load_user_group_defs(player)) do
    if type(def) == 'table' then inject_user_group(def) end
  end
  user_loaded_name = player and player.name or nil
  dynamic_group_cache = {}
end

function choice_groups:ensure_user_groups(player)
  local name = player and player.name or nil
  if not name or name == '' then return end
  if user_loaded_name == name then return end
  self:reload_user_groups(player)
end

function choice_groups:is_user_group(group_id)
  local g = choice_groups.groups[tostring(group_id or '')]
  return g ~= nil and g.user == true
end

function choice_groups:user_groups_list(player)
  self:ensure_user_groups(player)
  local out = {}
  for id in pairs(injected_user_ids) do
    local g = choice_groups.groups[id]
    if g and g.user then
      out[#out + 1] = { id = g._user_id, label = g.label, alias = g.alias,
                        icon = g.icon, jobs = g.jobs, entries = g.entries }
    end
  end
  table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
  return out
end

function choice_groups:get_user_group(player, group_id)
  self:ensure_user_groups(player)
  local g = choice_groups.groups[tostring(group_id or '')]
  if g and g.user then return g end
  return nil
end

function choice_groups:new_user_group_id(player, label)
  self:ensure_user_groups(player)
  local base = 'user_' .. normalize_key(label or 'choice')
  if base == 'user_' then base = 'user_choice' end
  local id = base
  local n = 1
  while choice_groups.groups[id] ~= nil do
    n = n + 1
    id = base .. '_' .. n
  end
  return id
end

function choice_groups:save_user_group(player, def)
  self:ensure_user_groups(player)
  if not def or not def.id or tostring(def.id) == '' then return false, 'no id' end
  inject_user_group(def)
  dynamic_group_cache = {}
  return write_user_groups(player)
end

function choice_groups:delete_user_group(player, group_id)
  self:ensure_user_groups(player)
  group_id = tostring(group_id or '')
  local g = choice_groups.groups[group_id]
  if not g or not g.user then return false end
  if builtin_backup[group_id] ~= nil then
    choice_groups.groups[group_id] = builtin_backup[group_id]
    builtin_backup[group_id] = nil
  else
    choice_groups.groups[group_id] = nil
  end
  injected_user_ids[group_id] = nil
  dynamic_group_cache = {}
  return write_user_groups(player)
end

local icon_overrides = {}
local icon_overrides_name = nil

local function icon_overrides_path(player)
  if not player or not player.name or player.name == '' then return nil end
  return HTB_PATH .. 'data/' .. player.name .. '/choice_icons.lua'
end

local function ensure_icon_overrides(player)
  local name = player and player.name or nil
  if not name or name == '' then return end
  if icon_overrides_name == name then return end
  icon_overrides = {}
  local path = icon_overrides_path(player)
  local chunk = path and loadfile(path)
  if chunk then
    local ok, data = pcall(chunk)
    if ok and type(data) == 'table' then icon_overrides = data end
  end
  icon_overrides_name = name
end

function choice_groups:get_icon_override(player, group_id)
  ensure_icon_overrides(player)
  return icon_overrides[tostring(group_id or '')]
end

function choice_groups:set_icon_override(player, group_id, icon)
  ensure_icon_overrides(player)
  local id = tostring(group_id or '')
  if id == '' then return false end
  if icon == nil or tostring(icon) == '' then icon_overrides[id] = nil else icon_overrides[id] = tostring(icon) end
  local path = icon_overrides_path(player)
  if not path then return false end
  local lines = { '-- XivUI choice icon overrides (generated by the XivUI Menu)', 'return {' }
  for k, v in pairs(icon_overrides) do
    lines[#lines + 1] = '  [' .. string.format('%q', k) .. '] = ' .. string.format('%q', v) .. ','
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = ''
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(table.concat(lines, '\n'))
  f:close()
  return true
end

function choice_groups.invalidate_dynamic_cache()
  dynamic_group_cache = {}
  _learned_cache = nil
end

return choice_groups
