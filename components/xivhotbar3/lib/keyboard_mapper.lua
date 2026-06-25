local keyboard = {}

keyboard.default_keybinds = require('components/xivhotbar3/data/default_keybinds')

keyboard.hotbar_rows = {}

keyboard.parsed_keybinds = {}

function keyboard:set_bindings(bindings)
  keyboard.hotbar_rows = {}
  for r = 1, 6 do
    local row = {}
    local rb = bindings['R' .. r]
    for c = 1, 12 do
      table.insert(row, rb[string.format('C%02d', c)])
    end
    table.insert(keyboard.hotbar_rows, row)
  end
end

function keyboard:cast_all_to_strings(settings)
  for r = 1, 6 do
    local rb = settings.Keybinds['R' .. r]
    for c = 1, 12 do
      local ck = string.format('C%02d', c)
      rb[ck] = tostring(rb[ck])
    end
  end
end

function keyboard:parse_keybinds()
  for row_key, row_value in pairs(keyboard.hotbar_rows) do
    for col_key, col_value in pairs(row_value) do
      col_value = string.lower(col_value)
      col_value = string.gsub(col_value, " ", "")
      local col_list = string.split(col_value, "+")
      if #col_list ~= 1 then
        for string_value in ipairs(col_list) do
          if (col_list[string_value] ~= "number") then
            if (col_list[string_value]:contains("ctrl")) then
              col_list[string_value] = "^"
            elseif (col_list[string_value]:contains("shift")) then
              col_list[string_value] = "%~"
            elseif (col_list[string_value]:contains("alt")) then
              col_list[string_value] = "!"
            end
          end
        end
        col_value = table.concat((col_list), "")
      else
        if type(col_list[1]) == "number" then
          col_value = "%" .. tostring(col_list[1])
        else
          col_value = "%" .. col_value
        end
      end
      if col_value then
        col_value = col_value:gsub('eq', '=')
        col_value = col_value:gsub('#', '')
      end
      row_value[col_key] = col_value
    end
    keyboard.hotbar_rows[row_key] = row_value
  end
end

function keyboard:bind_keys(rows, columns)
  for r = 1, rows do
    for s = 1, columns do
      if (self.hotbar_rows[r] ~= nil and self.hotbar_rows[r][s] ~= nil) then
        windower.send_command('bind ' .. keyboard.hotbar_rows[r][s] .. ' htb execute ' .. r .. ' ' .. s)
      end
    end
  end
end

function keyboard:unbind_keys(rows, columns)
  for r = 1, rows do
    for s = 1, columns do
      if (keyboard.hotbar_rows[r] ~= nil and keyboard.hotbar_rows[r][s] ~= nil) then
        windower.send_command('unbind ' .. keyboard.hotbar_rows[r][s])
      end
    end
  end
end

function keyboard:bind_row(row, columns)
  if self.hotbar_rows[row] == nil then return end
  for s = 1, columns do
    if self.hotbar_rows[row][s] ~= nil then
      windower.send_command('bind ' .. self.hotbar_rows[row][s] .. ' htb execute ' .. row .. ' ' .. s)
    end
  end
end

function keyboard:unbind_row(row, columns)
  if self.hotbar_rows[row] == nil then return end
  for s = 1, columns do
    if self.hotbar_rows[row][s] ~= nil then
      windower.send_command('unbind ' .. self.hotbar_rows[row][s])
    end
  end
end

function keyboard:bind_slot(row, slot)
  if self.hotbar_rows[row] and self.hotbar_rows[row][slot] ~= nil then
    windower.send_command('bind ' .. self.hotbar_rows[row][slot] .. ' htb execute ' .. row .. ' ' .. slot)
  end
end

function keyboard:unbind_slot(row, slot)
  if self.hotbar_rows[row] and self.hotbar_rows[row][slot] ~= nil then
    windower.send_command('unbind ' .. self.hotbar_rows[row][slot])
  end
end

return keyboard
