-- dps: real-time alliance DPS / damage parser with an ACT style overlay.
-- XivUI component. Maintainer: maybeLynd. Version: 1.0.
-- Based on the standalone "Scoreboard" parser by Suji. Magic-burst detection reuses the skillchain library v2.20.08.25 by Ivaar (via xivhotbar3/lib).

require('actions')
require('sets')
local res         = require('resources')
local packets     = require('packets')
local ui_bounds   = require('lib/ui_bounds')

local Player   = require('components/dps/lib/player')
local DPSClock = require('components/dps/lib/dpsclock')
local Display  = require('components/dps/lib/display')
local xpjobs   = require('components/xivparty/jobs')

local skillchains = (function() local ok, t = pcall(require, 'components/xivhotbar3/lib/skillchains') return ok and t or nil end)()

local dps = {}

local defaults = {
    numplayers = 12,
    visible = false,

    separatesc = false,
    separatemb = false,
    combinepets = false,

    trackhealing = true,
    trackmagicburst = true,

    autoreset = true,
    autoresetdelay = 9,

    pos = { x = 600, y = 200 },
    rowheight = 18,
    width = 500,
    scale = 1,
    font = 'Constantia',
    fontsize = 8,
    background = false,
    baralpha = 90,
    bgalpha = 150,

    role_overrides = {},
}

local settings
local db
local clock
local display
local collecting = false
local render_ok  = false

local job_by_name = {}

local pet_names = {}

local role_overrides = {}

local ally_ids = {}
local ally_ids_time = 0
local player_id = 0

local last_active = 0
local last_reset_check = 0
local last_party_job_refresh = 0
local last_disp = 0

local function new_db() return { players = {}, filter = T{} } end

local function get_player(name)
    local p = db.players[name]
    if not p then
        p = Player:new(name)
        p.job = job_by_name[name]
        db.players[name] = p
    end
    if pet_names[name] then p.is_pet = true end

    p.role_override = role_overrides[name:lower()]
    return p
end

local function filter_allows(mob_name)
    if db.filter:empty() then return true end
    for _, pat in ipairs(db.filter) do
        if mob_name:lower():find(pat:lower()) then return true end
    end
    return false
end

local function has_data() return next(db.players) ~= nil end

local function reset_all()
    db = new_db()
    pet_names = {}
    clock:reset()
    last_active = os.clock()
    if display then display:set_db(db, clock) end
end

local function rebuild_ally_ids()
    local ids = {}
    local party = windower.ffxi.get_party()
    for _, member in pairs(party) do
        if type(member) == 'table' and member.mob then
            ids[member.mob.id] = true
            local pi = member.mob.pet_index
            if pi and pi > 0 then
                local pet = windower.ffxi.get_mob_by_index(pi)
                if pet then ids[pet.id] = true end
            end
        end
    end
    local fellow = windower.ffxi.get_mob_by_target('ft')
    if fellow then ids[fellow.id] = true end
    ally_ids = ids
    ally_ids_time = os.clock()
end

local function mob_is_ally(id)
    if os.clock() - ally_ids_time > 1 then rebuild_ally_ids() end
    return ally_ids[id] == true
end

local function pet_owner_name(pet_id)
    local pet = windower.ffxi.get_mob_by_id(pet_id)
    if not pet then return nil, nil end
    local party = windower.ffxi.get_party()
    for _, member in pairs(party) do
        if type(member) == 'table' and member.mob
           and member.mob.pet_index and member.mob.pet_index > 0
           and pet.index == member.mob.pet_index then
            return member.mob.name, pet.name
        end
    end
    return nil, pet.name
end

local function actor_display_name(actor_id, actor_name)
    local owner, pet = pet_owner_name(actor_id)
    if owner and pet then
        if settings.combinepets then return owner end
        local n = owner .. ': ' .. pet
        pet_names[n] = true
        return n
    end
    return actor_name
end

local DEATH_MSGS = S{6, 20, 113, 406, 605, 646}

local PARRY_MSGS = S{70}

local function in_combat()
    local p = windower.ffxi.get_player()
    if not p then return false end
    if p.in_combat then return true end
    local pm = windower.ffxi.get_mob_by_id(p.id)
    if pm and pm.pet_index and pm.pet_index > 0 then
        local pet = windower.ffxi.get_mob_by_index(pm.pet_index)
        if pet and pet.status == 1 then return true end
    end
    return false
end

local function encounter_active()
    if in_combat() then return true end
    local party = windower.ffxi.get_party()
    for _, m in pairs(party) do
        if type(m) == 'table' and m.mob and m.mob.status == 1 then return true end
    end
    for _, mob in pairs(windower.ffxi.get_mob_array()) do
        if mob and mob.valid_target and (mob.hpp or 0) > 0
           and mob.claim_id and mob.claim_id ~= 0 and mob_is_ally(mob.claim_id) then
            return true
        end
    end
    return false
end

local function sc_entry_name(closer_name)
    if settings.separatesc then return closer_name end
    return 'Skillchain'
end

local function mb_entry_name(caster_name)
    if settings.separatemb then return caster_name end
    return 'Magic Burst'
end

local function spell_element(spell_id)
    local s = spell_id and res.spells[spell_id]
    return s and s.element
end

local SC_ADD_MSGS = S{196,223,288,289,290,291,292,293,294,295,296,297,298,299,300,
                      301,302,385,386,387,388,389,390,391,392,393,394,395,396,397,
                      398,732,767,768,769,770}

local function handle_action(raw)
    if not collecting then return end
    local ok, ap = pcall(ActionPacket.new, raw)
    if not ok or not ap then return end

    local category = ap:get_category_string()
    local actor_id = ap:get_id()
    if not actor_id then return end
    if not in_combat() then return end

    local spell_id = ap.raw and ap.raw.param
    local element  = (category == 'spell_finish') and spell_element(spell_id) or nil

    for target in ap:get_targets() do
        local target_id = target.raw and target.raw.id
        if target_id then
            local tname = target:get_name()
            for sub in target:get_actions() do
                local main  = sub:get_basic_info()
                local add   = sub:get_add_effect()
                local spike = sub:get_spike_effect()

                if mob_is_ally(actor_id) and not mob_is_ally(target_id) and filter_allows(tname) then

                    local actor_name = actor_display_name(actor_id, ap:get_actor_name())
                    local mid = main.message_id

                    if mid == 1 then
                        get_player(actor_name):add_m_hit(main.param)
                    elseif mid == 67 then
                        get_player(actor_name):add_m_crit(main.param)
                    elseif mid == 15 or mid == 63 then
                        get_player(actor_name):incr_m_misses()
                    elseif mid == 353 then
                        get_player(actor_name):add_r_crit(main.param)
                    elseif T{157, 352, 576, 577}:contains(mid) then
                        get_player(actor_name):add_r_hit(main.param)
                    elseif mid == 354 then
                        get_player(actor_name):incr_r_misses()
                    elseif mid == 188 then
                        get_player(actor_name):incr_ws_misses()
                    elseif main.resource == 'weapon_skills' and main.conclusion then
                        get_player(actor_name):add_ws_damage(main.param)
                    elseif mid == 802 then
                        get_player(actor_name):add_damage(main.param)
                    elseif main.conclusion and main.conclusion.subject == 'target'
                           and T(main.conclusion.objects):contains('HP') and main.param ~= 0 then
                        local signed = (main.conclusion.verb == 'gains' and -1 or 1) * main.param
                        if signed > 0 then
                            local routed = false
                            if settings.trackmagicburst and category == 'spell_finish'
                               and element and skillchains then
                                local mbset = skillchains:get_magic_burst_elements(target_id)
                                if mbset and mbset[element] then
                                    get_player(mb_entry_name(actor_name)):add_mb(signed)
                                    routed = true
                                end
                            end
                            if not routed then get_player(actor_name):add_damage(signed) end
                        end
                    end

                    if add and add.conclusion and SC_ADD_MSGS:contains(add.message_id)
                       and add.conclusion.subject == 'target'
                       and T(add.conclusion.objects):contains('HP') and add.param ~= 0 then
                        local signed = (add.conclusion.verb == 'gains' and -1 or 1) * add.param
                        if signed > 0 then get_player(sc_entry_name(actor_name)):add_damage(signed) end
                    end

                    if spike and spike.conclusion and spike.conclusion.subject == 'target'
                       and T(spike.conclusion.objects):contains('HP') and spike.param ~= 0 then
                        local sp = (spike.conclusion.verb == 'gains' and -1 or 1) * spike.param
                        if sp > 0 then get_player(actor_name):add_damage(sp) end
                    end

                elseif mob_is_ally(actor_id) and mob_is_ally(target_id) then

                    if settings.trackhealing and main.conclusion
                       and main.conclusion.subject == 'target'
                       and T(main.conclusion.objects):contains('HP')
                       and main.conclusion.verb == 'gains' and main.param > 0 then
                        local actor_name = actor_display_name(actor_id, ap:get_actor_name())
                        get_player(actor_name):add_heal(main.param)
                    end

                elseif not mob_is_ally(actor_id) and mob_is_ally(target_id) then

                    local victim = actor_display_name(target_id, tname)
                    local mid = main.message_id
                    local reaction = sub.raw and sub.raw.reaction

                    if mid == 15 or mid == 63 then
                        get_player(victim):incr_evade()
                    elseif PARRY_MSGS:contains(mid) then
                        get_player(victim):incr_parry()
                    elseif reaction == 12 then
                        get_player(victim):incr_block()
                    elseif reaction == 10 then
                        get_player(victim):incr_guard()
                    elseif mid == 1 or mid == 67 then
                        get_player(victim):incr_melee_taken()
                    end
                    if DEATH_MSGS:contains(mid) then
                        get_player(victim):incr_death()
                    end
                end
            end
        end
    end
end

ActionPacket.open_listener(handle_action)

local function set_job_from_id(name, job_id)
    if not name or not job_id then return end
    local j = res.jobs[job_id]
    if j and j.ens then
        job_by_name[name] = j.ens:lower()
        if db and db.players[name] then db.players[name].job = job_by_name[name] end
    end
end

local function refresh_self_job()
    local p = windower.ffxi.get_player()
    if p and p.name and p.main_job then
        job_by_name[p.name] = p.main_job:lower()
        if db and db.players[p.name] then db.players[p.name].job = job_by_name[p.name] end
    end
end

local function set_job_name(name, job)
    if not name or not job or job == '' then return end
    local job_l = tostring(job):lower()
    job_by_name[name] = job_l
    if db and db.players[name] then db.players[name].job = job_l end
end

local function refresh_party_jobs()
    local party = windower.ffxi.get_party()
    if not party then return end
    for _, member in pairs(party) do
        if type(member) == 'table' then
            local name = member.name or (member.mob and member.mob.name)
            if name and member.mob and member.mob.is_npc then
                local model = member.mob.models and member.mob.models[1] or nil
                local trust = xpjobs:getTrustInfo(name, model)
                if trust and trust.job then set_job_name(name, trust.job) end
            elseif name and member.main_job then
                set_job_name(name, member.main_job)
            end
        end
    end
end

local function ensure_settings()
    if not settings then settings = config.load('data/dps/settings.xml', defaults) end
    return settings
end

function dps.init()
    ensure_settings()
    db = new_db()
    clock = DPSClock:new()
    job_by_name = {}
    pet_names = {}
    role_overrides = settings.role_overrides or {}
    local pl = windower.ffxi.get_player()
    player_id = pl and pl.id or 0
    refresh_self_job()
    refresh_party_jobs()
    if skillchains and not skillchains.is_initialized then skillchains:initialize() end
    display = Display.new(settings, db, clock, job_by_name)
    collecting = true
    render_ok = false
end

function dps.dispose()
    collecting = false
    render_ok = false
    if display then display:destroy() end
    display = nil
    db = new_db()
    if clock then clock:reset() end
    ui_bounds.clear('dps')
end

function dps.apply_theme(id)
    Display.set_theme(id)
    if display then display:recolor() end
end

function dps.show()
    render_ok = true
end

function dps.hide()
    render_ok = false
    if display then display:hide_all() end
    ui_bounds.clear('dps')
end

function dps.on_login()
    refresh_self_job()
end

function dps.on_prerender()
    if not collecting or not display then return end

    local now = os.clock()
    if now - last_party_job_refresh > 1.0 then
        last_party_job_refresh = now
        refresh_party_jobs()
    end

    if in_combat() then clock:advance() else clock:pause() end

    if settings.autoreset and now - last_reset_check > 1 then
        last_reset_check = now
        if encounter_active() then
            last_active = now
        elseif has_data() and (now - last_active) >= (settings.autoresetdelay or 9) then
            reset_all()
        end
    end

    if render_ok and settings.visible then
        if now - last_disp >= 0.1 then
            last_disp = now
            display:update()
        end
    else
        display:hide_all()
    end
end

function dps.on_incoming_chunk(id, original)
    if id == 0x0DD or id == 0x0DF then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if ok and p and p['Name'] and p['Main job'] and (p['Main job level'] or 0) > 0 then
            set_job_from_id(p['Name'], p['Main job'])
        end
    end
end

function dps.push_bounds()
    if display and settings.visible then display:push_bounds() else ui_bounds.clear('dps') end
end

local BOOL_FLAGS = S{'separatesc','separatemb','combinepets',
                     'trackhealing','trackmagicburst','autoreset','background'}
local ROLE_NAMES = S{'tank','healer','support','dps','pet','other'}

local function party_slot_name(slot)
    local party = windower.ffxi.get_party()
    local key
    if slot >= 1 and slot <= 6 then key = 'p' .. (slot - 1)
    elseif slot >= 7 and slot <= 12 then key = 'a1' .. (slot - 7)
    elseif slot >= 13 and slot <= 18 then key = 'a2' .. (slot - 13) end
    local m = key and party[key]
    return (type(m) == 'table' and m.name) and m.name or nil
end

function dps.handle_command(args)
    ensure_settings()
    local cmd = (args[1] or 'help'):lower()
    if cmd == 'visible' or cmd == 'show' or cmd == 'hide' then
        if cmd == 'visible' then settings.visible = not settings.visible
        else settings.visible = (cmd == 'show') end
        config.save(settings)
        if not settings.visible and display then display:hide_all() end
        log('dps: ' .. (settings.visible and 'shown' or 'hidden'))
    elseif cmd == 'reset' then
        reset_all()
        log('dps: reset')
    elseif cmd == 'move' or cmd == 'reposition' then
        (_G.xivui_echo or log)('dps: use the HUD Layout editor (XivUI Menu) to move/scale the DPS panel.')
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            settings.pos.x, settings.pos.y = x, y
            config.save(settings)
            if display then display:set_position(x, y) end
            log('dps: moved to ' .. x .. ', ' .. y)
        end
    elseif cmd == 'scale' then
        local f = tonumber(args[2])
        if f then settings.scale = math.max(0.5, math.min(2.5, f)); config.save(settings)
            log('dps: scale ' .. settings.scale .. '.')
        else log('Usage: //xui dps scale <factor>') end
    elseif cmd == 'set' then
        local flag = args[2] and args[2]:lower()
        local val  = args[3] and args[3]:lower()
        local slot = tonumber(args[2])
        if slot and val then

            local name = party_slot_name(slot)
            local key = name and name:lower()
            if not name then
                log('dps: no member in slot ' .. slot .. ' (1-6 party, 7-18 alliance)')
            elseif val == 'auto' or val == 'clear' then
                role_overrides[key] = nil
                if db.players[name] then db.players[name].role_override = nil end
                settings.role_overrides = role_overrides; config.save(settings)
                log('dps: ' .. name .. ' role -> auto (by job)')
            elseif ROLE_NAMES:contains(val) then
                role_overrides[key] = val
                if db.players[name] then db.players[name].role_override = val end
                settings.role_overrides = role_overrides; config.save(settings)
                log('dps: ' .. name .. ' role -> ' .. val)
            else
                log('dps: role must be ' .. ROLE_NAMES:concat('|') .. ' or auto')
            end
        elseif (flag == 'numplayers' or flag == 'autoresetdelay') and tonumber(args[3]) then
            settings[flag] = tonumber(args[3]); config.save(settings)
            log('dps: ' .. flag .. ' = ' .. settings[flag])
        elseif BOOL_FLAGS:contains(flag) then
            local b
            if val == nil then b = not settings[flag]
            elseif val == 'true'  or val == 'on'  or val == '1' or val == 'yes' then b = true
            elseif val == 'false' or val == 'off' or val == '0' or val == 'no'  then b = false
            end
            if b == nil then
                log('dps: ' .. flag .. ' <on|off> (or omit to toggle)')
            else
                settings[flag] = b; config.save(settings)
                log('dps: ' .. flag .. ' = ' .. tostring(settings[flag]))
            end
        else
            log('dps: numplayers <n>, autoresetdelay <s>, or <flag> [on|off]: ' .. BOOL_FLAGS:concat(', '))
        end
    elseif cmd == 'filter' then
        local sub = args[2] and args[2]:lower()
        if sub == 'add' then
            for i = 3, #args do db.filter:append(args[i]) end
        elseif sub == 'clear' then
            db.filter = T{}
        elseif sub == 'show' then
            log('dps filters: ' .. (db.filter:empty() and 'None (all mobs)' or db.filter:concat(', ')))
        end
    elseif cmd == 'roles' then
        log('dps roles: tank(blue) healer(green) support(lavender) dps(red) pet(brown)')
        if next(role_overrides) then
            for name, role in pairs(role_overrides) do log('  ' .. name .. ' -> ' .. role) end
        else
            log('  no manual overrides (all by job); set with: set <slot> <role>')
        end
    else
        log('dps (//xui dps): visible | show | hide | reset | pos <x> <y> | scale <0.5-2.5> | set <flag> <val> | set <slot> <role> | filter <add|clear|show> | roles')
        log('  flags: numplayers, autoresetdelay, background, separatesc, separatemb, combinepets, trackhealing, trackmagicburst, autoreset')
        log('  roles: ' .. ROLE_NAMES:concat(', ') .. ' (or auto to clear); slot 1-6 party, 7-18 alliance')
    end
end

return dps
