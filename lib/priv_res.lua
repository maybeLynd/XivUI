local res = require('resources')

local function load(name)
    local ok, t = pcall(require, 'components/xivhotbar3/priv_res/' .. name)
    return ok and t or {}
end

local M = {
    spells        = load('spells'),
    weapon_skills = load('weapon_skills'),
    job_abilities = load('job_abilities'),
}

function M.spell(id)        return id and ((res.spells and res.spells[id]) or M.spells[id]) or nil end
function M.ability(id)      return id and ((res.job_abilities and res.job_abilities[id]) or M.job_abilities[id]) or nil end
function M.weapon_skill(id) return id and ((res.weapon_skills and res.weapon_skills[id]) or M.weapon_skills[id]) or nil end

return M
