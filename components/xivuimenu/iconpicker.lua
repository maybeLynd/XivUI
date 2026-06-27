-- iconpicker: The XivUI Menu icon picker.
-- Serves the folder grouped icon index and a persistent action icon override map that takes precedence over the hotbar's action_icons.lua.
-- Overrides are stored as a path relative to assets/components/hotbar/icons/custom/ (e.g. 'ffxiv/war/provoke'), keyed by "type|name".
-- XivUI Menu component lib. Maintainer: maybeLynd.

local M = {}

local INDEX_OK, INDEX = pcall(require, 'components/xivuimenu/icon_index')
if not INDEX_OK or type(INDEX) ~= 'table' then INDEX = {} end

local OVERRIDE_PATH = windower.addon_path .. 'data/xivuimenu/icon_overrides.lua'
local ICON_ROOT     = windower.addon_path .. 'assets/components/hotbar/icons/'

local AI_OK, ACTION_ICONS = pcall(require, 'components/xivhotbar3/lib/icon_registry')
if not AI_OK or type(ACTION_ICONS) ~= 'table' then ACTION_ICONS = {} end
local ACTION_ICONS_PATH = windower.addon_path .. 'components/xivhotbar3/data/action_icons.lua'

local function write_action_icon(key, av)
    local f = io.open(ACTION_ICONS_PATH, 'r')
    if not f then return false end
    local lines, found = {}, false
    for line in f:lines() do
        local raw = line:match('^%s*%[(.-)%]%s*=')
        local k = raw and raw:match('^["\'](.*)["\']$')
        if k == key then
            lines[#lines + 1] = string.format('  [%q] = %q,', key, av); found = true
        else
            lines[#lines + 1] = line
        end
    end
    f:close()
    if not found then
        for i = #lines, 1, -1 do
            if lines[i]:match('^%s*}%s*$') then table.insert(lines, i, string.format('  [%q] = %q,', key, av)); break end
        end
    end
    f = io.open(ACTION_ICONS_PATH, 'w')
    if not f then return false end
    for _, l in ipairs(lines) do f:write(l .. '\n') end
    f:close()
    return true
end

local _overrides

local function load_overrides()
    local f = loadfile(OVERRIDE_PATH)
    if f then
        local ok, t = pcall(f)
        if ok and type(t) == 'table' then return t end
    end
    return {}
end

local function save_overrides()
    local dir = windower.addon_path .. 'data/xivuimenu'
    if windower.create_dir then pcall(windower.create_dir, dir) end
    local f = io.open(OVERRIDE_PATH, 'w')
    if not f then return false end
    f:write('-- XivUI Menu per-action icon overrides (set via the icon picker). Auto-written.\nreturn {\n')
    local keys = {}
    for k in pairs(_overrides) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        f:write(string.format('  [%q] = %q,\n', k, _overrides[k]))
    end
    f:write('}\n')
    f:close()
    return true
end

function M.index() return INDEX end

function M.overrides()
    if not _overrides then _overrides = load_overrides() end
    return _overrides
end

function M.get(key)
    return M.overrides()[key]
end

local _path_exists = {}
function M.path(value)
    local p = ICON_ROOT .. tostring(value) .. '.png'
    local ok = _path_exists[p]
    if ok == nil then
        local f = io.open(p, 'rb')
        ok = f ~= nil
        if f then f:close() end
        _path_exists[p] = ok
    end
    if ok then return p end
    return nil
end

function M.set(key, value)
    local av = tostring(value or ''):gsub('^custom/', '')
    ACTION_ICONS[key] = (av ~= '' and av) or nil
    write_action_icon(key, av)
    M.overrides()
    if _overrides[key] ~= nil then _overrides[key] = nil; save_overrides() end
    windower.send_command('htb reload')
end

return M
