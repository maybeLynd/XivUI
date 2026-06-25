local M = {}
local _cache

local PATH = windower.addon_path .. 'components/targetbar/status_descriptions.json'

function M.load()
    if _cache then return _cache end
    local out = { buffs = {}, debuffs = {} }
    local f = io.open(PATH, 'r')
    if not f then return out end
    local section
    for line in f:lines() do
        if line:match('"buffs"%s*:%s*{') then
            section = 'buffs'
        elseif line:match('"debuffs"%s*:%s*{') then
            section = 'debuffs'
        elseif line:match('^%s*}%s*,?%s*$') then
            section = nil
        elseif section then
            local k, v = line:match('^%s*"([^"]+)"%s*:%s*"(.-)"%s*,?%s*$')
            if k and v and v ~= '' then out[section][k] = v end
        end
    end
    f:close()
    _cache = out
    return out
end

return M
