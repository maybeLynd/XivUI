local res                  = require('resources')
local database             = {}

local ok_priv_spells_db, priv_spells_db = pcall(require, 'components/xivhotbar3/priv_res/spells')
if not ok_priv_spells_db then priv_spells_db = {} end

local ok_horizon_spells_db, horizon_spells_db = pcall(require, 'components/xivhotbar3/priv_res/horizon_spells')
if not ok_horizon_spells_db then horizon_spells_db = {} end
local ranges               = {
  [0] = 255,
  [2] = 3.40,
  [3] = 4.47,
  [4] = 5.76,
  [5] = 6.89,
  [6] = 7.80,
  [7] = 8.40,
  [8] = 10.40,
  [9] = 12.40,
  [10] = 14.50,
  [11] = 16.40,
  [12] = 20.40,
  [13] = 23.4
}

database.ma                = {}
database.ja                = {}
database.ws                = {}
database.bstpet            = {}
database.items             = {}

local wpn_img_ids          = {
  ['H2H']          = 0,
  ['Dagger']       = 1,
  ['Sword']        = 2,
  ['Great Sword']  = 3,
  ['Axe']          = 4,
  ['Great Axe']    = 5,
  ['Scythe']       = 6,
  ['Polearm']      = 7,
  ['Katana']       = 8,
  ['Great Katana'] = 9,
  ['Club']         = 10,
  ['Staff']        = 11,
  ['Bow']          = 12,
  ['Marksmanship'] = 13
}

local ability_descriptions = require('components/xivhotbar3/priv_res/ability_descriptions')
local spell_descriptions   = require('components/xivhotbar3/priv_res/spell_descriptions')

function database:import()
  self:parse_abilities_lua()
  self:parse_ws_lua()
  self:parse_spells_lua()
  self:parse_bstpets_lua()
  self:parse_items()

  return true
end

function database:destroy()
  self.ma     = {}
  self.ja     = {}
  self.ws     = {}
  self.items  = {}
  self.bstpet = {}
end

function database:map_ws(ws_id)
  image_id = 0
  if ws_id >= 1 and ws_id <= 15 then
    image_id = wpn_img_ids['H2H']
  elseif ws_id >= 16 and ws_id <= 31 then
    image_id = wpn_img_ids['Dagger']
  elseif ws_id >= 32 and ws_id <= 47 then
    image_id = wpn_img_ids['Sword']
  elseif ws_id >= 48 and ws_id <= 61 then
    image_id = wpn_img_ids['Great Sword']
  elseif ws_id >= 64 and ws_id <= 77 then
    image_id = wpn_img_ids['Axe']
  elseif ws_id >= 80 and ws_id <= 93 then
    image_id = wpn_img_ids['Great Axe']
  elseif ws_id >= 96 and ws_id <= 109 then
    image_id = wpn_img_ids['Scythe']
  elseif ws_id >= 112 and ws_id <= 125 then
    image_id = wpn_img_ids['Polearm']
  elseif ws_id >= 128 and ws_id <= 141 then
    image_id = wpn_img_ids['Katana']
  elseif ws_id >= 144 and ws_id <= 158 then
    image_id = wpn_img_ids['Great Katana']
  elseif ws_id >= 160 and ws_id <= 175 then
    image_id = wpn_img_ids['Club']
  elseif ws_id >= 176 and ws_id <= 191 then
    image_id = wpn_img_ids['Staff']
  elseif ws_id >= 192 and ws_id <= 203 then
    image_id = wpn_img_ids['Bow']
  elseif ws_id >= 208 and ws_id <= 221 then
    image_id = wpn_img_ids['Marksmanship']
  elseif ws_id == 224 then
    image_id = wpn_img_ids['Dagger']
  elseif ws_id > 224 and ws_id <= 255 then
    image_id = wpn_img_ids['Sword']
  end

  return image_id
end

function database:parse_ws_lua()
  local contents = res.weapon_skills

  for key, abil in pairs(contents) do
    local new_weapon_skill   = {}
    new_weapon_skill.id      = tostring(contents[key].id)
    new_weapon_skill.icon    = string.format("%02d", database:map_ws(contents[key].id))
    new_weapon_skill.desc    = ability_descriptions[contents[key].id].en
    new_weapon_skill.name    = contents[key].en
    new_weapon_skill.tpcost  = tostring(1000)
    new_weapon_skill.cast    = tostring(0)
    new_weapon_skill.recast  = new_weapon_skill.cast
    new_weapon_skill.element = tostring(contents[key].element)
    new_weapon_skill.range   = ranges[contents[key].range]

    local function change_sc_string(sc_info)
      if sc_info == "" then return nil else return sc_info end
    end

    new_weapon_skill.sc_a                    = change_sc_string(contents[key].skillchain_a)
    new_weapon_skill.sc_b                    = change_sc_string(contents[key].skillchain_b)
    new_weapon_skill.sc_c                    = change_sc_string(contents[key].skillchain_c)

    self.ws[(new_weapon_skill.name):lower()] = new_weapon_skill
  end
end

local colors = {}
colors.Light = '\\cs(255,255,255)'
colors.Dark = '\\cs(120,120,180)'
colors.Ice = '\\cs(0,255,255)'
colors.Water = '\\cs(100,100,255)'
colors.Earth = '\\cs(221,161,62)'
colors.Wind = '\\cs(102,255,102)'
colors.Fire = '\\cs(255,0,0)'
colors.Lightning = '\\cs(255,0,255)'
colors.Gravitation = '\\cs(102,51,0)'
colors.Fragmentation = '\\cs(250,156,247)'
colors.Fusion = '\\cs(255,102,102)'
colors.Distortion = '\\cs(51,153,255)'
colors.Darkness = colors.Dark
colors.Umbra = colors.Dark
colors.Compression = colors.Dark
colors.Radiance = colors.Light
colors.Transfixion = colors.Light
colors.Induration = colors.Ice
colors.Reverberation = colors.Water
colors.Scission = colors.Earth
colors.Detonation = colors.Wind
colors.Liquefaction = colors.Fire
colors.Impaction = colors.Lightning
colors[6] = colors.Light
colors[7] = colors.Dark
colors[1] = colors.Ice
colors[5] = colors.Water
colors[3] = colors.Earth
colors[2] = colors.Wind
colors[0] = colors.Fire
colors[4] = colors.Lightning

function database:parse_abilities_lua()
  local contents = res.job_abilities

  for key, abil in pairs(contents) do
    local new_abil   = {}
    new_abil.oid     = tostring(contents[key].id)
    new_abil.id      = tostring(contents[key].recast_id)
    new_abil.icon    = new_abil.id
    new_abil.name    = contents[key].en
    new_abil.mpcost  = tonumber(contents[key].mp_cost)
    new_abil.tpcost  = tonumber(contents[key].tp_cost)
    new_abil.range   = ranges[contents[key].range]
    new_abil.desc    = ability_descriptions[contents[key].id + 512].en
    new_abil.cast    = tostring(0)
    new_abil.recast  = tostring(0)
    new_abil.element = tostring(contents[key].element)
    new_abil.prefix  = contents[key].prefix
    new_abil.type    = contents[key].type

    local function change_sc_string(sc_info)
      if sc_info == "" then return nil else return sc_info end
    end

    new_abil.sc_a                    = change_sc_string(contents[key].skillchain_a or "")
    new_abil.sc_b                    = change_sc_string(contents[key].skillchain_b or "")
    new_abil.sc_c                    = change_sc_string(contents[key].skillchain_c or "")

    self.ja[(new_abil.name):lower()] = new_abil
  end
end

function database:get_element_color_name(element_name)
  return colors[element_name]
end

function database:get_element_color(element_id)
  return colors[element_id]
end

function database:get_element_name(element_id)
  return res.elements[element_id].en
end

function database:parse_spells_lua()
  local contents = res.spells

  for key, spell in pairs(contents) do
    local new_spell                   = {}
    new_spell.id                      = tostring(contents[key].id)
    new_spell.icon                    = new_spell.id
    new_spell.name                    = contents[key].en
    new_spell.mpcost                  = contents[key].mp_cost
    new_spell.cast                    = contents[key].cast_time
    new_spell.element                 = contents[key].element
    new_spell.recast                  = contents[key].recast
    new_spell.range                   = ranges[contents[key].range]
    new_spell.desc                    = spell_descriptions[contents[key].id].en
    new_spell.prefix                  = contents[key].prefix
    new_spell.type                    = contents[key].type
    new_spell.targets                 = contents[key].targets

    self.ma[(new_spell.name):lower()] = new_spell
  end

  local function supplement(priv_table)
    for _, spell in pairs(priv_table or {}) do
      if type(spell) == 'table' and spell.en and spell.en ~= ''
          and not self.ma[spell.en:lower()] then
        local new_spell     = {}
        new_spell.id        = tostring(spell.id)
        new_spell.icon      = new_spell.id
        new_spell.name      = spell.en
        new_spell.mpcost    = spell.mp_cost
        new_spell.cast      = spell.cast_time
        new_spell.element   = spell.element
        new_spell.recast    = spell.recast
        new_spell.range     = ranges[spell.range]
        new_spell.desc      = spell_descriptions[spell.id] and spell_descriptions[spell.id].en or ''
        new_spell.prefix    = spell.prefix
        new_spell.type      = spell.type
        new_spell.targets   = spell.targets
        self.ma[spell.en:lower()] = new_spell
      end
    end
  end

  supplement(priv_spells_db)
  supplement(horizon_spells_db)
end

function database:parse_bstpets_lua()
  local contents = res.monster_abilities

  for key, _ in pairs(contents) do
    if key > 3839 and key < 3963 then
      local new_ability = {}
      new_ability.id    = tostring(contents[key].id)
      new_ability.name  = contents[key].en

      local function change_sc_string(sc_info)
        if sc_info == "" then return nil else return sc_info end
      end

      new_ability.sc_a                        = change_sc_string(contents[key].skillchain_a or "")
      new_ability.sc_b                        = change_sc_string(contents[key].skillchain_b or "")
      new_ability.sc_c                        = change_sc_string(contents[key].skillchain_c or "")

      self.bstpet[(new_ability.name):lower()] = new_ability
    end
  end
end

function database:parse_items()
  local items = res.items
  local item_desc = res.item_descriptions

  for key, _ in pairs(items) do
    local new_item                      = {}
    new_item.id                         = tostring(items[key].id)
    new_item.name                       = items[key].en
    new_item.desc                       = (item_desc[key] and item_desc[key].en) or ""

    self.items[(new_item.name):lower()] = new_item
  end
end

return database
