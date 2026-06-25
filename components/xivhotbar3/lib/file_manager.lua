local file_manager = {}
files = require('files')

local current_job_file_path = ""
local current_general_file_path = ""

local function fill_table(file)
  file_content = {}
  for line in file:lines() do
    table.insert(file_content, line)
  end
  return file_content
end

local function find_in_file_remove(file_path, action, row, slot, environment)
  log(string.format("Removing row %d, slot %d", row, slot))
  local testAc = action.action:lower()
  local env_long  = (environment == 'b' and 'battle') or (environment == 'f' and 'field') or environment
  local env_short = (environment == 'battle' and 'b') or (environment == 'field' and 'f') or environment
  local rtf_long  = string.format('%s %d %d', env_long, row, slot)
  local rtf_short = string.format('%s %d %d', env_short, row, slot)
  local found_row = false
  local fileContent = {}
  local file = io.open(file_path, 'r')

  if (file ~= nil) then
    for line in file:lines() do
      table.insert(fileContent, line)
    end
    for key, val in pairs(fileContent) do
      if (val:contains(rtf_long) or val:contains(rtf_short)) then
        if (val:lower():gsub('\\(.)', '%1'):contains(testAc)) then
          found_row = true
          fileContent[key] = '0'
          break
        elseif (val:contains("'gs'")) then
          local stripped_row = val:lower()
          i, j = string.find(stripped_row, '%[.*%]')
          k, l = string.find(testAc, '%[.*%]')
          local sub_row = string.sub(stripped_row, i + 3, j - 3)
          local sub_ac = string.sub(testAc, k + 2, l - 2)
          if sub_row == sub_ac then
            found_row = true
            fileContent[key] = '0'
            break
          end
        end
      end
    end
    if (found_row == true) then
      file = io.open(file_path, 'w')
      for index, value in ipairs(fileContent) do
        if (value ~= '0') then
          file:write(value .. '\n')
        end
      end
      io.close(file)
    end
  end
  return found_row
end

local function write_swap(file_location, action, d_row, d_slot, s_row, s_slot, environment)
  local testAc = action.action:lower()
  local env_long = (environment == 'b') and 'battle' or (environment == 'f') and 'field' or environment
  local env_short = (environment == 'battle') and 'b' or (environment == 'field') and 'f' or environment

  local found_row = false
  local fileContent = {}
  local file = io.open(file_location, 'r')

  if file ~= nil then
    for line in file:lines() do
      table.insert(fileContent, line)
    end
    io.close(file)

    for key, val in pairs(fileContent) do
      local matched_env = nil
      if val:contains(string.format('%s %d %d', env_short, s_row, s_slot)) then
        matched_env = env_short
      elseif val:contains(string.format('%s %d %d', env_long, s_row, s_slot)) then
        matched_env = env_long
      end

      if matched_env ~= nil then
        local row_to_find = string.format('%s %d %d', matched_env, s_row, s_slot)
        local new_row = string.format('%s %d %d', matched_env, d_row, d_slot)

        if val:lower():gsub('\\(.)', '%1'):contains(testAc) then
          found_row = true
          fileContent[key] = string.gsub(val, row_to_find, new_row, 1)
          break
        elseif string.find(val, "'%f[%a]gs%f[%A]'") and string.find(val, 'equip') then
          local stripped_row = val:lower()
          local i, j = string.find(stripped_row, '%[.*%]')
          local k, l = string.find(testAc, '%[.*%]')
          local sub_row = string.sub(stripped_row, i + 3, j - 3)
          local sub_ac = string.sub(testAc, k + 2, l - 2)
          if sub_row == sub_ac then
            found_row = true
            fileContent[key] = string.gsub(val, row_to_find, new_row, 1)
            break
          end
        end
      end
    end

    if found_row == true then
      file = io.open(file_location, 'w')
      for index, value in ipairs(fileContent) do
        file:write(value .. '\n')
      end
      io.close(file)
    end
  end
  return found_row
end

local function seed_file_if_missing(path, content)
  local existing = io.open(path, 'r')
  if existing ~= nil then
    io.close(existing)
    return
  end
  local file = io.open(path, 'w')
  if file ~= nil then
    file:write(content)
    io.close(file)
  end
end

local function build_default_job_file()
  local lines = { "xivhotbar_keybinds_job['Base'] = {", '}', '' }
  local ok, res = pcall(require, 'resources')
  if ok and res ~= nil and res.jobs ~= nil then
    local seen = {}
    for _, job in pairs(res.jobs) do
      local ens = job.ens
      if ens ~= nil and ens ~= '' and ens ~= 'NON' and not seen[ens] then
        seen[ens] = true
        table.insert(lines, "xivhotbar_keybinds_job['" .. ens .. "'] = {")
        table.insert(lines, '}')
        table.insert(lines, '')
      end
    end
  end
  table.insert(lines, 'return xivhotbar_keybinds_job')
  return table.concat(lines, '\n') .. '\n'
end

local DEFAULT_GENERAL_FILE =
    "xivhotbar_keybinds_general['Root'] = {\n}\n\nxivhotbar_general_list = {\n}\n\nreturn xivhotbar_keybinds_general\n"

function file_manager:update_file_path(player_name, player_job)
  local basepath = HTB_PATH .. 'data/' .. player_name .. '/'
  pcall(windower.create_dir, basepath)
  local job_name = player_job
  current_job_file_path = basepath .. job_name .. '.lua'
  current_general_file_path = basepath .. "General.lua"
  seed_file_if_missing(current_job_file_path, build_default_job_file())
  seed_file_if_missing(current_general_file_path, DEFAULT_GENERAL_FILE)
end

local function find_in_file(file_content, action, environment, pattern)
  local pattern_start = 0
  local pattern_end = 0
  local found_pattern_start = false
  local found_pattern_end = false
  local found_in_section = false

  if (type(file_content) == "table") then
    for key, val in pairs(file_content) do
      local i, j = string.find(val, pattern)
      if (i ~= nil and j ~= nil) then
        log("i ~= nil and j ~= nil")
        found_pattern_start = true
        pattern_start = key + 1
      end
      local k, l = string.find(val, '^}')
      if (k ~= nil and l ~= nil and found_pattern_start == true) then
        log("k ~= nil and l ~= nil and found_main_job_start == true")
        log(val)
        pattern_end = key - 1
        found_pattern_end = true
        break
      end
    end
    if (found_pattern_end == true) then
      log("found_pattern_end==true")
      for i = pattern_start, pattern_end do
        local k, j = string.find(file_content[i], '\'')
        if (k ~= nil and j ~= nil) then
          local found_row = string.match(file_content[i], environment)
          if (found_row ~= nil) then
            found_in_section = true
            break
          end
        end
      end
      if (found_in_section == false) then
        local icon_part = (action.icon and tostring(action.icon) ~= '')
            and (", " .. string.format('%q', tostring(action.icon))) or ""
        new_row = "\t{'" .. environment .. "', '" .. action.type .. "', "
            .. string.format('%q', tostring(action.action or '')) .. ", '" .. action.target .. "', "
            .. string.format('%q', tostring(action.alias or '')) .. icon_part .. "},"
        log(string.format("Writing new: %s", new_row))
        table.insert(file_content, pattern_end + 1, new_row)
      end
    end
  end
  return found_in_section
end

local function write_to_file(file_path, new_file_content)
  file = io.open(file_path, 'w')
  for index, value in ipairs(new_file_content) do
    file:write(value .. '\n')
  end
  io.close(file)
end

function file_manager:insert_action(action, prio, player_subjob, environment, row, slot)
  local row_to_find = string.format('%s %d %d', environment, row, slot)
  local fileContent = {}
  local found = false
  local file = {}
  local file_to_open = ""

  if (prio == 'g') then
    file_to_open = current_general_file_path
  else
    file_to_open = current_job_file_path
  end
  file = io.open(file_to_open, 'r')
  if (file ~= nil) then
    fileContent = fill_table(file)
    io.close(file)
    if (prio == 'm') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_job%[\'Base\'%]')
    elseif (prio == 's') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_job%[\'' .. player_subjob .. '\'%]')
    elseif (prio == 'g') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_general%[\'Root\'%]')
    end
    if (found == false) then
      log("found==false")
      write_to_file(file_to_open, fileContent)
    end
  end
end

local function escape_lua_pattern(s)
  return tostring(s):gsub('(%W)', '%%%1')
end

function file_manager:insert_action_in_section(action, section_key, environment, row, slot)
  local file = io.open(current_job_file_path, 'r')
  if file == nil then return false end
  local fileContent = fill_table(file)
  io.close(file)

  local pattern = 'xivhotbar_keybinds_job%[\'' .. escape_lua_pattern(section_key) .. '\'%]'
  local present = false
  for _, line in ipairs(fileContent) do
    if string.find(line, pattern) then present = true; break end
  end
  if not present then
    local insert_at = #fileContent + 1
    for key, line in ipairs(fileContent) do
      if string.find(line, '^%s*return%s') then insert_at = key; break end
    end
    table.insert(fileContent, insert_at,     '')
    table.insert(fileContent, insert_at + 1, "xivhotbar_keybinds_job['" .. section_key .. "'] = {")
    table.insert(fileContent, insert_at + 2, '}')
  end

  local row_to_find = string.format('%s %d %d', environment, row, slot)
  local found = find_in_file(fileContent, action, row_to_find, pattern)
  if found == false then
    write_to_file(current_job_file_path, fileContent)
  end
  return found == false
end

function file_manager:remove_from_section(section_key, environment, row, slot, action_name)
  local file = io.open(current_job_file_path, 'r')
  if file == nil then return false end
  local fileContent = fill_table(file)
  io.close(file)

  local pattern = 'xivhotbar_keybinds_job%[\'' .. escape_lua_pattern(section_key) .. '\'%]'
  local env_long  = (environment == 'b' and 'battle') or (environment == 'f' and 'field') or environment
  local env_short = (environment == 'battle' and 'b') or (environment == 'field' and 'f') or environment
  local rtf_long  = string.format('%s %d %d', env_long, row, slot)
  local rtf_short = string.format('%s %d %d', env_short, row, slot)
  local in_section, removed = false, false
  for key, val in ipairs(fileContent) do
    if string.find(val, pattern) then
      in_section = true
    elseif in_section and string.find(val, '^}') then
      break
    elseif in_section and (val:contains(rtf_long) or val:contains(rtf_short)) then
      if action_name == nil
          or val:lower():gsub('\\(.)', '%1'):contains(tostring(action_name):lower()) then
        table.remove(fileContent, key)
        removed = true
        break
      end
    end
  end
  if removed then
    write_to_file(current_job_file_path, fileContent)
  end
  return removed
end

function file_manager:remove_choice_references_in(file_path, group_id)
  local file = io.open(file_path, 'r')
  if file == nil then return 0 end
  local fileContent = fill_table(file)
  io.close(file)
  local gid = tostring(group_id or ''):lower()
  if gid == '' then return 0 end
  local kept, removed = {}, 0
  for _, line in ipairs(fileContent) do
    local l = line:lower()
    local is_ref = (l:find("'choice'", 1, true) or l:find('"choice"', 1, true))
      and (l:find("'" .. gid .. "'", 1, true) or l:find('"' .. gid .. '"', 1, true))
    if is_ref then removed = removed + 1 else kept[#kept + 1] = line end
  end
  if removed > 0 then write_to_file(file_path, kept) end
  return removed
end

function file_manager:write_changes(action, d_row, d_slot, s_row, s_slot, environment)
  local found_row = write_swap(current_job_file_path, action, d_row, d_slot, s_row, s_slot, environment)

  if (found_row == false) then
    write_swap(current_general_file_path, action, d_row, d_slot, s_row, s_slot, environment)
  end
end

function file_manager:write_remove(action, row, slot, environment)
  local found_row = find_in_file_remove(current_job_file_path, action, row, slot, environment)

  if (found_row == false) then
    find_in_file_remove(current_general_file_path, action, row, slot, environment)
  end
end

return file_manager
