-- catalog: builds the Action Panel's action list for the current job: the main job and sub job spells and job abilities, with unlock level, learned flag and icon path.
-- Trusts get their own category. Spells appear if the main/sub job casts them.
-- Spell levels come from the resources; ability levels from the hotbar's level table.
-- XivUI component lib. Maintainer: maybeLynd.

local res = require('resources')
local ACTION_ICONS = require('components/xivhotbar3/lib/icon_registry')
local iconpicker   = require('components/xivuimenu/iconpicker')
local choice_groups = require('components/xivhotbar3/lib/choice_groups')
local _ok, JA_LEVELS = pcall(require, 'components/xivhotbar3/priv_res/job_abilities_levels')
if not _ok or type(JA_LEVELS) ~= 'table' then JA_LEVELS = {} end
local _wsl_ok, WS_LEVELS = pcall(require, 'components/xivhotbar3/priv_res/weapon_skills_levels')
if not _wsl_ok or type(WS_LEVELS) ~= 'table' then WS_LEVELS = {} end
local _wsu_ok, WS_UNLOCK = pcall(require, 'components/xivhotbar3/priv_res/weapon_skill_unlocks')
if not _wsu_ok or type(WS_UNLOCK) ~= 'table' then WS_UNLOCK = {} end
local WS_REASON = {
    relic     = 'Requires a Relic weapon equipped',
    empyrean  = 'Requires an Empyrean weapon equipped',
    aeonic    = 'Requires an Aeonic weapon equipped',
    mythic    = 'Requires a Mythic / Ergon weapon equipped',
    prime     = 'Requires a Prime weapon equipped',
    ambuscade = 'Requires a specific Ambuscade weapon equipped',
    su2       = 'Requires a specific Superior (iLv.2) weapon equipped',
}
local function ws_usable_by_job(main, sub, info)
    if not info or (not info.ms and not info.mo) then return true end
    local function has(list, job)
        return job and list and (' ' .. list .. ' '):find(' ' .. job .. ' ', 1, true) ~= nil
    end
    if has(info.ms, main) or has(info.mo, main) then return true end
    if has(info.ms, sub) then return true end
    return false
end

local ICONS = windower.addon_path .. 'assets/components/hotbar/icons/'

local SKILL_RENAME = { Singing = 'Songs', ['Summoning Magic'] = 'Summoning' }
local AVATAR_BY_ICON = { [340]='Carbuncle',[341]='Fenrir',[342]='Ifrit',[343]='Titan',
    [344]='Leviathan',[345]='Garuda',[346]='Shiva',[347]='Ramuh',[348]='Diabolos',
    [349]='Odin',[350]='Alexander',[351]='Cait Sith',[18]='Siren' }
local AVATAR_ORDER = { 'Carbuncle','Fenrir','Ifrit','Titan','Leviathan','Garuda','Shiva',
    'Ramuh','Diabolos','Cait Sith','Siren','Alexander','Odin' }

local TYPE_CATEGORY = {
    CorsairRoll = 'Phantom Roll',
    CorsairShot = 'Quick Draw',
    Scholar     = 'Stratagems',
    Rune        = 'Runes',
    Ward        = 'Wards',
    Effusion    = 'Effusions',
    Samba       = 'Sambas',
    Waltz       = 'Waltzes',
    Step        = 'Steps',
    Jig         = 'Jigs',
    Flourish1   = 'Flourishes', Flourish2 = 'Flourishes', Flourish3 = 'Flourishes',
}

local SUB_UNUSABLE = {}
for _, n in ipairs({
    'Mighty Strikes', 'Hundred Fists', 'Benediction', 'Afflatus Solace', 'Afflatus Misery',
    'Manafont', 'Chainspell', 'Composure', 'Perfect Dodge', 'Invincible', 'Blood Weapon',
    'Familiar', 'Ready', 'Snarl', 'Soul Voice', 'Pianissimo', 'Eagle Eye Shot', 'Velocity Shot',
    'Meikyo Shisui', 'Mijin Gakure', 'Yonin', 'Innin', 'Spirit Surge', 'Call Wyvern',
    'Astral Flow', 'Azure Lore', 'Wild Card', 'Overdrive', 'Deus Ex Automata', 'Maintenance',
    'Trance', 'Tabula Rasa', 'Bolster', 'Full Circle', 'Lasting Emanation', 'Ecliptic Attrition',
    'Elemental Sforzo',
}) do SUB_UNUSABLE[n:lower()] = true end

local M = { CATEGORY_ORDER = {
    'Main Job Abilities', 'Sub Job Abilities',
    'Hand-to-Hand', 'Dagger', 'Sword', 'Great Sword', 'Axe', 'Great Axe', 'Scythe', 'Polearm',
    'Katana', 'Great Katana', 'Club', 'Staff', 'Archery', 'Marksmanship', 'Throwing',
    'Pet Commands',
    'Phantom Roll', 'Quick Draw', 'Stratagems', 'Runes', 'Wards', 'Effusions',
    'Sambas', 'Waltzes', 'Steps', 'Jigs', 'Flourishes',
    'Healing Magic', 'Enhancing Magic', 'Enfeebling Magic', 'Elemental Magic',
    'Dark Magic', 'Divine Magic', 'Ninjutsu', 'Songs', 'Blue Magic', 'Geomancy', 'Summoning',
} }
for _, a in ipairs(AVATAR_ORDER) do M.CATEGORY_ORDER[#M.CATEGORY_ORDER + 1] = a end
M.LAST_CATEGORY = 'Trusts'

M.DEFAULT_COLLAPSED = { Trusts = true }
for _, a in ipairs(AVATAR_ORDER) do M.DEFAULT_COLLAPSED[a] = true end

local function exists(path)
    local f = io.open(path, 'r')
    if f then f:close(); return true end
    return false
end

local function icon_for(type_key, name, icon_id, folder, fmt)
    local key = type_key .. '|' .. tostring(name):lower()
    local ov = iconpicker.get(key)
    if ov and ov ~= '' then
        local p = ICONS .. ov .. '.png'
        if exists(p) then return p end
    end
    local custom = ACTION_ICONS[key]
    if custom and custom ~= '' then
        local p = ICONS .. 'custom/' .. custom .. '.png'
        if exists(p) then return p end
        local p2 = ICONS .. custom .. '.png'
        if exists(p2) then return p2 end
    end
    if icon_id then
        local p = ICONS .. folder .. '/' .. string.format(fmt, icon_id) .. '.png'
        if exists(p) then return p end
    end
    return nil
end

local NAME_RES = {
    ma   = { res.spells,        'spells',    '%05d' },
    ja   = { res.job_abilities,  'abilities', '%05d' },
    ws   = { res.weapon_skills,  'weapons',   '%05d' },
    item = { res.items,          'items',     '%05d' },
}
local NAME_IDX = {}
local function name_to_icon_id(type_key, name)
    local idx = NAME_IDX[type_key]
    if not idx then
        idx = {}
        local spec = NAME_RES[type_key]
        if spec and spec[1] then
            for _, entry in pairs(spec[1]) do
                if type(entry) == 'table' and entry.en and entry.icon_id and idx[entry.en] == nil then
                    idx[entry.en] = entry.icon_id
                end
            end
        end
        NAME_IDX[type_key] = idx
    end
    return idx[name]
end
function M.icon_for_action(type_key, name)
    if not type_key or not name or name == '' then return nil end
    type_key = tostring(type_key):lower()
    local spec = NAME_RES[type_key]
    if not spec or not spec[1] then return nil end
    return icon_for(type_key, name, name_to_icon_id(type_key, name), spec[2], spec[3])
end

local function eff_sub_level(mlvl, slvl)
    if slvl <= 0 then return 0 end
    local cap = math.floor(mlvl / 2)
    if mlvl >= 99 and cap < 49 then cap = 49 end
    if cap <= 0 then return slvl end
    return math.min(slvl, cap)
end

function M.build()
    local p = windower.ffxi.get_player()
    if not p or not p.main_job_id then return {} end
    local mjob, sjob = p.main_job_id, p.sub_job_id
    local mlvl = p.main_job_level or 0
    local sub_eff = p.sub_job_level or 0
    local eff_sub = eff_sub_level(mlvl, p.sub_job_level or 0)
    local known = windower.ffxi.get_spells() or {}
    local list = {}

    local merit_names = {}
    if res.merit_points then
        for _, m in pairs(res.merit_points) do
            if m.en then merit_names[tostring(m.en):lower()] = true end
        end
    end

    local avatar_learned = {}
    if res.spells then
        for id, e in pairs(res.spells) do
            if tostring(e.type or '') == 'SummonerPact' and known[id] then
                local a = AVATAR_BY_ICON[e.icon_id]
                if a then avatar_learned[a] = true end
            end
        end
    end

    if res.spells then
        for id, e in pairs(res.spells) do
            if e.en and type(e.levels) == 'table' and not e.unlearnable then
                local ml = e.levels[mjob]
                local sl = sjob and e.levels[sjob]
                if ml or sl then
                    local category
                    if e.type == 'Trust' then
                        category = 'Trusts'
                    else
                        local skn = e.skill and res.skills and res.skills[e.skill] and res.skills[e.skill].en
                        category = (skn and (SKILL_RENAME[skn] or skn)) or 'Magic'
                    end
                    local slearned = known[id] == true
                    local sstatus
                    if slearned then sstatus = 'ok'
                    elseif ml and merit_names[tostring(e.en):lower()] then sstatus = 'merit'
                    elseif (ml and mlvl >= ml) or (sl and eff_sub >= sl) then sstatus = 'unlearned'
                    else sstatus = 'lvl' end
                    local torder = 0
                    if category == 'Trusts' then
                        if e.en == 'Cornelia' or e.en == 'Matsui-P' then torder = 2
                        elseif tostring(e.en):find('(UC)', 1, true) then torder = 1 end
                    end
                    list[#list + 1] = {
                        type = 'ma', id = id, name = e.en, level = ml or sl,
                        learned = slearned, status = sstatus,
                        category = category, torder = torder,
                        icon = icon_for('ma', e.en, e.icon_id, 'spells', '%05d'),
                    }
                end
            end
        end
    end

    if res.job_abilities then
        local abils = windower.ffxi.get_abilities() or {}
        local usable, have_list = {}, false
        for _, aid in pairs(abils.job_abilities or {}) do usable[tonumber(aid) or aid] = true; have_list = true end
        for id, e in pairs(res.job_abilities) do
            local etype = tostring(e.type or '')
            local ld = JA_LEVELS[id]
            local ml = (ld and ld.levels) and ld.levels[mjob] or nil
            local sl = (ld and ld.levels) and sjob and ld.levels[sjob] or nil
            local in_usable = have_list and usable[id] == true
            if e.en and (ml or sl or in_usable)
                and etype ~= 'BloodPactRage' and etype ~= 'BloodPactWard' then
                local name_l = tostring(e.en):lower()
                local is_petcmd = etype == 'PetCommand'
                local category = is_petcmd and 'Pet Commands'
                    or TYPE_CATEGORY[etype]
                    or (sl and not ml and 'Sub Job Abilities')
                    or 'Main Job Abilities'

                local is_usable
                if in_usable then is_usable = true
                elseif is_petcmd then is_usable = (ml and mlvl >= ml) or (sl and sub_eff >= sl) or false
                elseif have_list then is_usable = usable[id] == true
                else is_usable = (ml and mlvl >= ml) or (sl and eff_sub >= sl) or false end

                local status
                if choice_groups:is_parent_ability(e.en) then status = 'choice_only'
                elseif (not ml) and (not in_usable) and SUB_UNUSABLE[name_l] then status = 'nosub'
                elseif is_usable then status = 'ok'
                elseif ml and merit_names[name_l] then status = 'merit'
                elseif (ml and mlvl >= ml) or (sl and eff_sub >= sl) then status = 'unlearned'
                else status = 'lvl' end
                list[#list + 1] = {
                    type = 'ja', id = id, name = e.en, level = ml or sl or 0,
                    learned = (status == 'ok'), status = status, category = category,
                    icon = icon_for('ja', e.en, e.icon_id, 'abilities', '%05d'),
                }
            end
        end

        if res.jobs and res.jobs[mjob] and tostring(res.jobs[mjob].ens or '') == 'SMN' then
            for id, e in pairs(res.job_abilities) do
                local t = tostring(e.type or '')
                if (t == 'BloodPactRage' or t == 'BloodPactWard') and e.en then
                    local avatar = AVATAR_BY_ICON[e.icon_id]
                    if avatar then
                        local st
                        if not avatar_learned[avatar] then st = 'unlearned'
                        elseif have_list and usable[id] then st = 'ok'
                        else st = 'lvl' end
                        list[#list + 1] = {
                            type = 'ja', id = id, name = e.en, level = 0,
                            learned = (st == 'ok'), status = st, category = avatar,
                            icon = icon_for('ja', e.en, e.icon_id, 'abilities', '%05d'),
                        }
                    end
                end
            end
        end
    end

    if res.weapon_skills and res.items then
        local items = windower.ffxi.get_items()
        local eq = items and items.equipment
        local function equipped_skill(slot)
            if not eq then return nil end
            local idx = eq[slot]
            if not idx or idx == 0 then return nil end
            local it = windower.ffxi.get_items(eq[slot .. '_bag'] or 0, idx)
            local rid = it and it.id and it.id ~= 0 and res.items[it.id]
            return rid and tonumber(rid.skill) or nil
        end
        local abils = windower.ffxi.get_abilities() or {}
        local usable_ws = {}
        for _, id in pairs(abils.weapon_skills or {}) do usable_ws[tonumber(id) or id] = true end
        local function add_ws(skill_type)
            if not skill_type or skill_type == 0 then return end
            local category = (res.skills and res.skills[skill_type] and res.skills[skill_type].en) or 'Weapon Skills'
            for id, e in pairs(res.weapon_skills) do
                if e.en and tonumber(e.skill) == skill_type then
                    local usable = usable_ws[id] == true
                    local lvl = WS_LEVELS[id]
                    local info = WS_UNLOCK[e.en] or {}
                    local kind = info.kind
                    local status, reason, sort_level
                    if usable then
                        status = 'ok'; sort_level = (lvl and lvl.min_skill) or 0
                    elseif not ws_usable_by_job(p.main_job, p.sub_job, info) then
                        status = 'wsnotjob'; reason = 'Not usable by your current job'; sort_level = 200000
                    elseif kind == 'quest' then
                        status = 'wsquest'; reason = 'Unlocked from a level 71+ Weapon Skill quest'
                        sort_level = 100000 + ((lvl and lvl.min_level) or 90)
                    elseif kind then
                        status = 'wsweapon'; reason = WS_REASON[kind] or 'Requires a special weapon equipped'
                        sort_level = 100000 + ((lvl and lvl.min_level) or 99)
                    else
                        status = 'lvl'; reason = 'Combat skill not high enough'
                        sort_level = (lvl and lvl.min_skill) or 0
                    end
                    list[#list + 1] = {
                        type = 'ws', id = id, name = e.en, level = 0, sort_level = sort_level,
                        learned = usable, status = status, reason = reason, category = category,
                        icon = icon_for('ws', e.en, e.icon_id, 'weapons', '%05d'),
                    }
                end
            end
        end
        add_ws(equipped_skill('main'))
        add_ws(equipped_skill('range'))
    end

    table.sort(list, function(a, b)
        local la, lb = a.sort_level or a.level, b.sort_level or b.level
        if la ~= lb then return la < lb end
        if (a.torder or 0) ~= (b.torder or 0) then return (a.torder or 0) < (b.torder or 0) end
        return a.name < b.name
    end)
    return list
end

function M.weapon_skills()
    local out = {}
    if not res.weapon_skills then return out end
    local ab = windower.ffxi.get_abilities() or {}
    local usable = {}
    for _, id in pairs(ab.weapon_skills or {}) do usable[tonumber(id) or id] = true end
    for id, e in pairs(res.weapon_skills) do
        if e.en and usable[id] then
            out[#out + 1] = { type = 'ws', id = id, name = e.en, level = 0, learned = true, status = 'ok',
                icon = icon_for('ws', e.en, e.icon_id, 'weapons', '%05d') }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function has_flag(flags, name, bit)
    if type(flags) == 'table' then return (flags[name] or (bit and flags[bit])) and true or false end
    if type(flags) == 'number' and bit then return math.floor(flags / (2 ^ bit)) % 2 >= 1 end
    return false
end

function M.usable_items()
    if not res.items then return {} end
    local items = windower.ffxi.get_items()
    if not items then return {} end
    local out, seen = {}, {}
    for _, bag in pairs(items) do
        if type(bag) == 'table' then
            for k, it in pairs(bag) do
                if type(k) == 'number' and type(it) == 'table' and it.id and (it.count or 0) > 0 and not seen[it.id] then
                    local rid = res.items[it.id]
                    if rid and rid.category == 'Usable' and (rid.cast_time or 0) > 0
                       and has_flag(rid.flags, 'Usable', 9) and not has_flag(rid.flags, 'Scroll', 7) then
                        seen[it.id] = true
                        out[#out + 1] = { type = 'item', id = it.id, name = rid.en, level = 0, learned = true,
                            status = 'ok', icon = icon_for('item', rid.en, it.id, 'items', '%05d') }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return #out > 0 and { { category = 'Usable Items', entries = out } } or {}
end

local SLOT_BIT = { main = 0, sub = 1, range = 2, ammo = 3, head = 4, body = 5, hands = 6,
    legs = 7, feet = 8, neck = 9, waist = 10, lear = 11, rear = 12, ring1 = 13, ring2 = 14, back = 15 }

function M.enchanted_gear(slot)
    if not res.items then return {} end
    local items = windower.ffxi.get_items()
    if not items then return {} end
    local bit = SLOT_BIT[slot]
    local out, seen = {}, {}
    for _, bag in pairs(items) do
        if type(bag) == 'table' then
            for k, it in pairs(bag) do
                if type(k) == 'number' and type(it) == 'table' and it.id and (it.count or 0) > 0 and not seen[it.id] then
                    local rid = res.items[it.id]
                    if rid and (rid.category == 'Armor' or rid.category == 'Weapon') and (rid.cast_time or 0) > 0 then
                        local fits = true
                        if bit then
                            if type(rid.slots) == 'table' then fits = rid.slots[bit] and true or false
                            elseif type(rid.slots) == 'number' then fits = math.floor(rid.slots / (2 ^ bit)) % 2 >= 1
                            else fits = false end
                        end
                        if fits then
                            seen[it.id] = true
                            out[#out + 1] = { type = 'use_equip', id = it.id, name = rid.en, level = 0,
                                learned = true, status = 'ok', icon = icon_for('item', rid.en, it.id, 'items', '%05d') }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return #out > 0 and { { category = 'Enchanted Gear', entries = out } } or {}
end

function M.group(list)
    local by = {}
    for _, e in ipairs(list) do
        by[e.category] = by[e.category] or {}
        table.insert(by[e.category], e)
    end
    local groups, seen = {}, {}
    for _, c in ipairs(M.CATEGORY_ORDER) do
        if by[c] then groups[#groups + 1] = { category = c, entries = by[c] }; seen[c] = true end
    end
    seen[M.LAST_CATEGORY] = true
    for c, entries in pairs(by) do
        if not seen[c] then groups[#groups + 1] = { category = c, entries = entries } end
    end
    if by[M.LAST_CATEGORY] then
        groups[#groups + 1] = { category = M.LAST_CATEGORY, entries = by[M.LAST_CATEGORY] }
    end
    return groups
end

return M
