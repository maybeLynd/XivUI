-- priv_res skillchain data overrides Windower res for weaponskills / job abilities
-- (kept correct + complete here); res is the fallback for anything priv_res lacks.
local ok_priv_ws, priv_ws_sc = pcall(require, 'components/xivhotbar3/priv_res/weapon_skills')
if not ok_priv_ws then priv_ws_sc = {} end
local ok_priv_ja, priv_ja_sc = pcall(require, 'components/xivhotbar3/priv_res/job_abilities')
if not ok_priv_ja then priv_ja_sc = {} end

skillchains = {
  is_initialized = false,

  last_cleanup_check = os.time(),

  sc_properties = {},

  target_buffs = {},

  sc_combos = {
    ["Transfixion"] = {
      ["Compression"]   = { property = "Compression", level = 1 },
      ["Reverberation"] = { property = "Reverberation", level = 1 },
      ["Scission"]      = { property = "Distortion", level = 2 },
    },
    ["Compression"] = {
      ["Transfixion"] = { property = "Transfixion", level = 1 },
      ["Detonation"]  = { property = "Detonation", level = 1 },
    },
    ["Liquefaction"] = {
      ["Scission"]  = { property = "Scission", level = 1 },
      ["Impaction"] = { property = "Fusion", level = 2 },
    },
    ["Scission"] = {
      ["Liquefaction"]  = { property = "Liquefaction", level = 1 },
      ["Reverberation"] = { property = "Reverberation", level = 1 },
      ["Detonation"]    = { property = "Detonation", level = 1 },
    },
    ["Reverberation"] = {
      ["Induration"] = { property = "Induration", level = 1 },
      ["Impaction"]  = { property = "Impaction", level = 1 },
    },
    ["Detonation"] = {
      ["Scission"]    = { property = "Scission", level = 1 },
      ["Compression"] = { property = "Gravitation", level = 2 },
    },
    ["Induration"] = {
      ["Compression"]   = { property = "Compression", level = 1 },
      ["Impaction"]     = { property = "Impaction", level = 1 },
      ["Reverberation"] = { property = "Fragmentation", level = 2 },
    },
    ["Impaction"] = {
      ["Liquefaction"] = { property = "Liquefaction", level = 1 },
      ["Detonation"]   = { property = "Detonation", level = 1 },
    },
    ["Gravitation"] = {
      ["Distortion"]    = { property = "Darkness", level = 3 },
      ["Fragmentation"] = { property = "Fragmentation", level = 3 },
    },
    ["Distortion"] = {
      ["Gravitation"] = { property = "Darkness", level = 3 },
      ["Fusion"]      = { property = "Fusion", level = 3 },
    },
    ["Fusion"] = {
      ["Gravitation"]   = { property = "Gravitation", level = 3 },
      ["Fragmentation"] = { property = "Light", level = 3 },
    },
    ["Fragmentation"] = {
      ["Distortion"] = { property = "Distortion", level = 3 },
      ["Fusion"]     = { property = "Light", level = 3 },
    },
    ["Light"] = {
      ["Light"] = { property = "Double Light", level = 4 },
    },
    ["Darkness"] = {
      ["Darkness"] = { property = "Double Darkness", level = 4 },
    },
  },

  sc_alignments = {
    ["Transfixion"]     = { 6 },
    ["Compression"]     = { 7 },
    ["Liquefaction"]    = { 0 },
    ["Scission"]        = { 3 },
    ["Reverberation"]   = { 5 },
    ["Detonation"]      = { 2 },
    ["Induration"]      = { 1 },
    ["Impaction"]       = { 4 },
    ["Gravitation"]     = { 7, 3 },
    ["Distortion"]      = { 5, 1 },
    ["Fusion"]          = { 0, 6 },
    ["Fragmentation"]   = { 2, 4 },
    ["Light"]           = { 0, 2, 4, 6 },
    ["Darkness"]        = { 1, 3, 5, 7 },
    ["Double Light"]    = { 0, 2, 4, 6 },
    ["Double Darkness"] = { 1, 3, 5, 7 },
  },

  sc_base_levels = {
    Transfixion = 1, Compression = 1, Liquefaction = 1, Scission = 1,
    Reverberation = 1, Detonation = 1, Induration = 1, Impaction = 1,
    Gravitation = 2, Fragmentation = 2, Distortion = 2, Fusion = 2,
    Light = 3, Darkness = 3,
    ["Double Light"] = 4, ["Double Darkness"] = 4,
  },
}

function skillchains:initialize()
  self.is_initialized = true
end

function skillchains:destroy()
  self.is_initialized = false
  self.sc_properties = {}
  self.target_buffs = {}
end

function skillchains:handle_action(packet)
  local actor_id = packet.actor_id
  local actions = packet.targets[1].actions
  if not actions or #actions == 0 then return end

  local message_id = actions[1].message
  local target_id = packet.targets[1].id

  if message_id == 185
      or message_id == 186
      or message_id == 194
      or message_id == 187
  then
    local ability_id = packet.param
    local sc_props = self:load_skillchain_properties('WEAPONSKILL', ability_id)

    if sc_props and #sc_props > 0 then
      local ws = (ability_id < 256) and resources.weapon_skills[ability_id] or resources.monster_abilities[ability_id]
      self:attempt_skillchain(target_id, sc_props, ws and ws.en)
    end
  elseif message_id == 100
  then
    local ability_id = packet.param
    local buff_id = (resources.job_abilities[ability_id] and resources.job_abilities[ability_id].status) or packet.param

    if buff_id == 164
    then
      local duration = resources.job_abilities[ability_id].duration

      if not self.target_buffs[actor_id] then
        self.target_buffs[actor_id] = {}
      end

      self.target_buffs[actor_id][buff_id] = os.clock() + duration
    end
  elseif message_id == 2
  then
    local spell_id = packet.param

    if self.target_buffs[actor_id] then
      if self.target_buffs[actor_id][164] then
        if os.clock() < self.target_buffs[actor_id][164] then
          local spell = resources.spells[spell_id]
          if spell.type == "BlueMagic" then
            local sc_props = self:load_skillchain_properties('BLUEMAGIC', spell_id)
            if sc_props and #sc_props > 0 then
              self:attempt_skillchain(target_id, sc_props, spell and spell.en)
              self.target_buffs[actor_id][164] = nil
            end
          end
        end
      end
    end
  elseif message_id == 317
  then
    local ability_id = packet.param
    local ability = resources.job_abilities[ability_id]

    if ability then
      if ability.type == 'BloodPactRage' then
        local sc_props = self:load_skillchain_properties('JOBABILITY', ability_id)

        if sc_props and #sc_props > 0 then
          self:attempt_skillchain(target_id, sc_props, ability.en)
        end
      end
    end
  end
end

function skillchains:attempt_skillchain(target_id, incoming_properties, source_name)
  local now = os.time()

  if not self.sc_properties[target_id] then
    self.sc_properties[target_id] = {
      props = {},
      last_update = 0,
      chain_formed_time = 0,
      formed = false,
      source_name = nil,
    }
  end

  local data = self.sc_properties[target_id]
  local time_diff = now - data.last_update

  if time_diff >= 10 then
    data.props = {}
    data.chain_formed_time = 0
  end

  local can_chain = (time_diff >= 3 and time_diff <= 10 and #data.props > 0)
  if can_chain then
    local sc_formed = false
    local new_chain_property = nil

    for _, incprop in ipairs(incoming_properties) do
      for _, oldprop in ipairs(data.props) do
        local combo = self.sc_combos[oldprop] and self.sc_combos[oldprop][incprop]
        if combo then
          sc_formed = true
          new_chain_property = combo.property
          break
        end
      end
      if sc_formed then break end
    end

    if sc_formed and new_chain_property then

      data.props = { new_chain_property }
      data.chain_formed_time = now
      data.formed = true
      data.source_name = source_name
    else

      data.props = incoming_properties
      data.formed = false
      data.source_name = source_name
    end
  else
    data.props = incoming_properties
    data.formed = false
    data.source_name = source_name
  end

  data.last_update = now
end

function skillchains:get_potential_skillchains(target_id)
  local info = {}
  local data = self.sc_properties[target_id]
  if not data or #data.props == 0 then
    return info
  end

  local now = os.time()
  local time_diff = now - data.last_update

  if time_diff < 3 or time_diff > 10 then
    if time_diff > 10 then
      self.sc_properties[target_id] = nil
    end
    return info
  end

  for _, oldprop in ipairs(data.props) do
    local combos_for_old = self.sc_combos[oldprop]
    if combos_for_old then
      for incprop, combo_result in pairs(combos_for_old) do
        if not info[incprop] then info[incprop] = combo_result end
      end
    end
  end

  return info
end

function skillchains:get_magic_burst_elements(target_id)
  local data = self.sc_properties[target_id]
  if not data or #data.props == 0 then
    return nil
  end

  local now = os.time()
  if (now - data.chain_formed_time) > 10 then
    return nil
  end

  local sc_property = data.props[1]
  local alignments = self.sc_alignments[sc_property]
  if alignments then
    local result_set = {}
    for _, element in ipairs(alignments) do
      result_set[element] = true
    end
    return result_set
  end
  return nil
end

function skillchains:get_chain_display(target_id)
  local data = self.sc_properties[target_id]
  if not data or #data.props == 0 then return nil end

  local now = os.time()
  if (now - data.last_update) > 10 then
    self.sc_properties[target_id] = nil
    return nil
  end

  local current_level = 0
  for _, prop in ipairs(data.props) do
    local lvl = self.sc_base_levels[prop] or 0
    if lvl > current_level then current_level = lvl end
  end

  local options = {}
  for _, oldprop in ipairs(data.props) do
    local combos = self.sc_combos[oldprop]
    if combos then
      for incprop, result in pairs(combos) do
        if not options[incprop] then
          options[incprop] = { property = result.property, level = self.sc_base_levels[result.property] or result.level }
        end
      end
    end
  end

  return {
    props = data.props,
    current_level = current_level,
    options = options,
    formed = data.formed == true,
    source_name = data.source_name,
  }
end

local function add_valid_property(properties, value)

  if value and value ~= 'None' and value ~= '' then
    table.insert(properties, value)
  end
end

function skillchains:load_skillchain_properties(type, ability_id)
  local properties = {}

  if type == 'WEAPONSKILL' then
    local ws = nil
    if ability_id < 256 then
      local pw = priv_ws_sc[ability_id]
      ws = (pw and (pw.skillchain_a or "") ~= "" and pw) or resources.weapon_skills[ability_id]
    else
      ws = resources.monster_abilities[ability_id]
    end

    if ws then
      add_valid_property(properties, ws.skillchain_a)
      add_valid_property(properties, ws.skillchain_b)
      add_valid_property(properties, ws.skillchain_c)
    end
  elseif type == 'BLUEMAGIC' then
    local blu_data = htb_blue_spells[ability_id]
    if blu_data then
      add_valid_property(properties, blu_data.skillchain_a)
      add_valid_property(properties, blu_data.skillchain_b)
      add_valid_property(properties, blu_data.skillchain_c)
    end
  elseif type == 'JOBABILITY' then
    local pj = priv_ja_sc[ability_id]
    local ja = (pj and (pj.skillchain_a or "") ~= "" and pj) or resources.job_abilities[ability_id]
    if ja then
      add_valid_property(properties, ja.skillchain_a)
      add_valid_property(properties, ja.skillchain_b)
      add_valid_property(properties, ja.skillchain_c)
    end
  end

  return properties
end

function skillchains:add_skillchain_property(target_id, sc_property)
  if not self.sc_properties[target_id] then
    self.sc_properties[target_id] = {
      props = {},
      last_update = 0,
      chain_formed_time = 0,
    }
  end
  table.insert(self.sc_properties[target_id].props, sc_property)
  self.sc_properties[target_id].last_update = os.time()
end

function skillchains:cleanup_old_data()
  local now = os.time()
  local cutoff = 10

  for target_id, data in pairs(self.sc_properties) do
    if (now - data.last_update) >= cutoff then
      self.sc_properties[target_id] = nil
    end
  end
end

windower.register_event('incoming chunk', function(id, data)
  if skillchains.is_initialized and id == 0x028 then
    local packet = windower.packets.parse_action(data)
    skillchains:handle_action(packet)
  end
end)

windower.register_event('prerender', function()
  if skillchains.is_initialized then
    local now = os.time()
    local THIRTY_MINUTES = 30 * 60

    if (now - skillchains.last_cleanup_check) >= THIRTY_MINUTES then
      skillchains:cleanup_old_data()
      skillchains.last_cleanup_check = now
    end
  end
end)

return skillchains
