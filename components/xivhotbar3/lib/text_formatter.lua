local text_formatter = {}
local white = '\\cs(255,255,255)'

local ja_levels = require('components/xivhotbar3/priv_res/job_abilities_levels')
local ws_levels = require('components/xivhotbar3/priv_res/weapon_skills_levels')
local action_radius = require('components/xivhotbar3/priv_res/action_radius')

local status_descs = require('lib/status_descs')
local function effect_subtext(status_id, status_name)
    if not status_id then return nil end
    local sd = status_descs.load()
    local b, db = sd.buffs, sd.debuffs
    local nm = status_name and tostring(status_name):lower()
    local d = b[tostring(status_id)]
           or (nm and db[nm]) or (nm and b[nm])
    if type(d) == 'string' and d ~= '' then return d end
    return nil
end

local function generate_sc_string(database, sc_name)
  if sc_name == nil then return nil end
  return string.format("%s%s%s", database:get_element_color_name(sc_name), sc_name, white)
end

local function split_string(input_str)
  local t = {}
  for str in string.gmatch(input_str, "([^ ]+)") do
    table.insert(t, str)
  end
  return t
end

local function format_description(desc)
  local temp_str = ""
  local formatted_desc = ""
  local teststr = split_string(desc)
  for k, v in pairs(teststr) do
    if (string.len(temp_str) > 30) then
      formatted_desc = formatted_desc .. " " .. temp_str .. "\n"
      temp_str = ""
    end
    temp_str = temp_str .. " " .. v
  end
  formatted_desc = formatted_desc .. " " .. temp_str .. "\n"
  return formatted_desc
end

function text_formatter.format_ws_info(database, action, action_target)
  local string_return = ""
  local ws = database.ws[(action):lower()]
  if ws ~= nil then
    local ws_info = {}
    ws_info[1] = string.format("\\cs(255,255,255)%s\\cr    \\cs(200,200,255)Target:<%s>\\cr\n", ws.name, action_target)

    local sc_info = {}
    local sc_a = generate_sc_string(database, ws.sc_a)
    local sc_b = generate_sc_string(database, ws.sc_b)
    local sc_c = generate_sc_string(database, ws.sc_c)
    if sc_a then table.insert(sc_info, sc_a) end
    if sc_b then table.insert(sc_info, sc_b) end
    if sc_c then table.insert(sc_info, sc_c) end

    ws_info[2] = format_description(ws.desc)
    local temp_ws_str = table.concat(sc_info, ", ")
    if temp_ws_str ~= "" then
      ws_info[3] = "SC: " .. temp_ws_str
    else
      ws_info[3] = "SC: None"
    end
    if (ws.range == 255) then
      ws_info[4] = "Range: \\cs(200,200,255)Self\\cr "
    else
      ws_info[4] = string.format("Range: \\cs(200,200,255)%.1fy\\cr", ws.range)
    end
    string_return = table.concat(ws_info, "\n")
  end
  return string_return
end

function text_formatter.format_ability_info(database, action, action_target)
  local string_return = ""
  local ability = database.ja[(action):lower()]
  if ability ~= nil then
    local ability_info = {}
    ability_info[1] = string.format("\\cs(255,255,255)%s\\cr    Target:\\cs(200,200,255)<%s>\\cr\n", ability.name,
      action_target)
    ability_info[2] = format_description(ability.desc)

    local sc_info = {}
    local sc_a = generate_sc_string(database, ability.sc_a)
    local sc_b = generate_sc_string(database, ability.sc_b)
    local sc_c = generate_sc_string(database, ability.sc_c)
    if sc_a then table.insert(sc_info, sc_a) end
    if sc_b then table.insert(sc_info, sc_b) end
    if sc_c then table.insert(sc_info, sc_c) end

    local temp_ws_str = table.concat(sc_info, ", ")
    if temp_ws_str ~= "" then
      ability_info[3] = "SC: " .. temp_ws_str
    end

    if (ability.range == 255) then
      table.insert(ability_info, "Range: \\cs(200,200,255)Self\\cr ")
    else
      table.insert(ability_info, string.format("Range: \\cs(200,200,255)%.1fy\\cr", ability.range))
    end
    string_return = table.concat(ability_info, " \n")
  end
  return string_return
end

function text_formatter.format_spell_info(database, action, action_target)
  local string_return = ""
  local spell = database.ma[(action):lower()]
  if spell ~= nil then
    local spell_info = {}
    spell_info[1] = string.format("\\cs(255,255,255)%s\\cr   Target:\\cs(200,200,255)<%s>\\cr\n",
      spell.name, action_target)
    local spell_target_cost = {}
    if (spell.range == 255) then
      spell_target_cost[1] = "Range: \\cs(200,200,255)Self\\cr "
    else
      spell_target_cost[1] = string.format("Range: \\cs(200,200,255)%.1fy\\cr", spell.range)
    end
    spell_info[2] = format_description(spell.desc)
    if (spell.mpcost ~= 0) then
      spell_target_cost[2] = string.format("MP Cost: \\cs(0,255,0)%sMP\\cr", spell.mpcost)
    end
    spell_info[3] = table.concat(spell_target_cost, "    ")
    string_return = table.concat(spell_info, "\n")
  end
  return string_return
end

function text_formatter.format_item_info(database, action, action_target)
  local string_return = ""
  local item = database.items[(action):lower()]
  if item ~= nil then
    local item_info = {}
    item_info[1] = string.format("\\cs(255,255,255)%s\\cr    \\cs(200,200,255)Target:<%s>\\cr\n", item.name,
      action_target)
    item_info[2] = format_description(item.desc:gsub("\n", " "))

    string_return = table.concat(item_info, "\n")
  end
  return string_return
end

local function trim_zeros(s)
  return (s:gsub('%.?0+$', ''))
end

local function fmt_num(n)
  if n == math.floor(n) then return string.format('%d', n) end
  return trim_zeros(string.format('%.2f', n))
end

local function fmt_time(s)
  s = tonumber(s)
  if not s then return nil end
  if s == 0 then return 'Instant' end
  if s < 60 then return fmt_num(s) .. 's' end
  if s < 3600 then
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return sec > 0 and string.format('%dm %ds', m, sec) or string.format('%dm', m)
  end
  local h = math.floor(s / 3600)
  local m = math.floor((s % 3600) / 60)
  return m > 0 and string.format('%dh %dm', h, m) or string.format('%dh', h)
end

local function pretty_type(t)
  if not t then return nil end
  return (tostring(t):gsub('(%l)(%u)', '%1 %2'))
end

local _all_jobs
local function all_jobs_count()
  if _all_jobs then return _all_jobs end
  local n = 0
  if res and res.jobs then
    for jid, jb in pairs(res.jobs) do
      if jb.ens and jb.ens ~= 'NON' and type(jid) == 'number' and jid >= 1 and jid <= 22 then n = n + 1 end
    end
  end
  _all_jobs = (n > 0) and n or 22
  return _all_jobs
end

local function jobs_and_level(levels)
  if type(levels) ~= 'table' then return nil, nil end
  local ok, jobs_str, minl = pcall(function()
    local list, mn = {}, 999
    for jid, lvl in pairs(levels) do
      local jb = res and res.jobs and res.jobs[jid]
      if jb and jb.ens and jb.ens ~= 'NON' then list[#list + 1] = { abbr = jb.ens, lvl = lvl } end
      if lvl < mn then mn = lvl end
    end
    if #list >= all_jobs_count() then return 'ALL', (mn < 999 and mn or nil) end
    table.sort(list, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.abbr < b.abbr end)
    local abbrs = {}
    for _, e in ipairs(list) do abbrs[#abbrs + 1] = e.abbr end
    return table.concat(abbrs, ' '), (mn < 999 and mn or nil)
  end)
  if ok then return jobs_str, minl end
  return nil, nil
end

local function range_str(r)
  if r == nil or r == 255 then return '0y' end
  if type(r) == 'number' then return fmt_num(r) .. 'y' end
  return nil
end

function text_formatter.build_action_info(database, action)
  if not action then return nil end
  local atype = tostring(action.type or ''):lower()
  local name_l = tostring(action.action or ''):lower()
  local info = {}

  local db, resentry
  if atype == 'ma' then
    db = database.ma[name_l]
    if db then resentry = res and res.spells and res.spells[tonumber(db.id)] end
    info.type = (resentry and pretty_type(resentry.type)) or 'Magic'
    info.cast = fmt_time(db and db.cast)
    info.recast = fmt_time(db and db.recast)
  elseif atype == 'ja' or atype == 'pet' or atype == 'bstpet' then
    db = database.ja[name_l]
    if db then resentry = res and res.job_abilities and res.job_abilities[tonumber(db.oid)] end
    info.type = 'Job Ability'
    info.cast = 'Instant'
    info.recast_id = db and tonumber(db.id)
  elseif atype == 'ws' then
    db = database.ws[name_l]
    if db then resentry = res and res.weapon_skills and res.weapon_skills[tonumber(db.id)] end
    info.type = 'Weaponskill'
    info.cast = 'Instant'
    info.no_recast = true
  elseif atype == 'item' then
    db = database.items[name_l]
    info.type = 'Item'
  end

  if not db then return nil end
  info.name = db.name
  info.desc = db.desc
  if atype ~= 'item' then
    info.range = range_str(db.range)
    info.radius = action_radius[db.name:lower()] and 'AOE' or 'ST'
  end

  if resentry then
    local sid = tonumber(resentry.status)
    if sid and sid > 0 then
      local buff = res and res.buffs and res.buffs[resentry.status]
      local nm   = buff and buff.en
      local sub  = effect_subtext(resentry.status, nm)
      local placeholder = (not nm) or nm == '' or tostring(nm):find('N/A', 1, true) or tostring(nm):find('None', 1, true)
      if not placeholder then
        info.add_effect = nm
        if sub and sub ~= '' then info.add_effect_desc = '(' .. sub .. ')' end
      elseif sub and sub ~= '' then
        info.add_effect = (tostring(sub):gsub('%.%s*$', ''))
      end
    end
    if resentry.duration and resentry.duration > 0 then info.duration = fmt_time(resentry.duration) end
  end

  if atype == 'ma' and resentry then
    local jobs, minl = jobs_and_level(resentry.levels)
    if minl then info.acquired = 'Lv. ' .. minl end
    if jobs and jobs ~= '' then info.affinity = jobs end
  elseif atype == 'ja' or atype == 'pet' or atype == 'bstpet' then
    local jl = ja_levels[tonumber(db.oid)]
    if jl and type(jl.levels) == 'table' and next(jl.levels) then
      local jobs, minl = jobs_and_level(jl.levels)
      if minl then info.acquired = 'Lv. ' .. minl end
      if jobs and jobs ~= '' then info.affinity = jobs end
    elseif jl then
      info.acquired = 'Merit'
    end
  elseif atype == 'ws' then
    local wl = ws_levels[tonumber(db.id)]
    if wl and wl.min_skill then info.acquired = 'Skill ' .. wl.min_skill end
  end

  return info
end

text_formatter.fmt_time = fmt_time

return text_formatter
