-- targetbar: target HP bar, buff/debuff strip, and skillchain display.
-- XivUI component. Maintainer: maybeLynd. Version: 2.0.0.
-- Based on "enemybar" v1.0.2 by mmckee. Incorporates "Debuffed" v3.0.0 by Xathe (Asura) and the skillchain display from "SkillChains" v2.20.08.25 by Ivaar.

local SELF_PATH         = windower.addon_path .. 'assets/components/targetbar/'
local BAR_DIR = SELF_PATH
if _G.XIVUI_THEME == 'ffxi' then
    local f = io.open(SELF_PATH .. 'themes/ffxi/bar_track.png', 'rb')
    if f then f:close(); BAR_DIR = SELF_PATH .. 'themes/ffxi/' end
end
local ICONS_PATH        = windower.addon_path .. 'assets/components/targetbar/buffs/'
local DEBUFF_ICONS_PATH = windower.addon_path .. 'assets/components/targetbar/debuff_icons/'
local DEBUFF_ICON_BG    = windower.addon_path .. 'assets/components/targetbar/debuff_icons/icon_bg.png'

local config     = require('config')
local res        = require('resources')
local socket     = require('socket')
local packets    = require('packets')
local ui_bounds  = require('lib/ui_bounds')
local targeting  = require('lib/targeting')
local tooltip_lib = require('lib/tooltip')
local cast_state = require('lib/cast_state')
local shadow_tracker = require('lib/shadow_tracker')
local skillchain = require('components/targetbar/skillchain')

local _priv = require('lib/priv_res')
local _priv_spells, _priv_ja = _priv.spells, _priv.job_abilities

if not _G.resources then _G.resources = res end

local BUFF_STATUS_DURATION = {}
local function _index_durations(tbl)
    for _, e in pairs(tbl) do
        if e.status and e.status > 0 and e.duration and e.duration > 0 then
            if not BUFF_STATUS_DURATION[e.status] then
                BUFF_STATUS_DURATION[e.status] = e.duration
            end
        end
    end
end
_index_durations(_priv_spells)
_index_durations(_priv_ja)
if res.spells        then _index_durations(res.spells)        end
if res.job_abilities then _index_durations(res.job_abilities) end

local STEP_DAZE_BASE = { [386] = true, [391] = true, [396] = true, [448] = true }
local STEP_DAZE_BASE_DUR = 60
local STEP_DAZE_STEP     = 30
local STEP_DAZE_CAP      = 120
for sid in pairs(STEP_DAZE_BASE) do BUFF_STATUS_DURATION[sid] = BUFF_STATUS_DURATION[sid] or STEP_DAZE_BASE_DUR end
for _, sid in ipairs({378, 379, 380}) do BUFF_STATUS_DURATION[sid] = BUFF_STATUS_DURATION[sid] or 90 end

local AILMENT_NAMES = { sleep=true, poison=true, paralysis=true, blindness=true,
    silence=true, petrification=true, disease=true, curse=true, stun=true, bind=true,
    weight=true, slow=true, doom=true, amnesia=true, addle=true, terror=true,
    plague=true, flash=true, dia=true, bio=true, requiem=true, elegy=true, ['inhibit tp']=true,
    gravity=true, burn=true, frost=true, choke=true, rasp=true, shock=true, drown=true,
    helix=true, kaustra=true, impairment=true, ['drain daze']=true, ['aspir daze']=true,
    ['haste daze']=true, bane=true, ['flash']=true }
local IS_DEBUFF = {}
for id, e in pairs(res.buffs) do
    local nm = (e.en or ''):lower()
    if nm:find('down$') or AILMENT_NAMES[nm] or nm:find('daze') then IS_DEBUFF[id] = true end
end

local function cap_words(s)
    if not s or s == '' then return s end
    return (s:gsub("(%a)([%w'%.]*)", function(a, b) return a:upper() .. b end))
end

local CANON_STATUS = {}
do
    local by_name = {}
    for id, e in pairs(res.buffs) do
        if e.en then
            local key = e.en:lower():gsub('%s+%d+$', '')
            if not by_name[key] or id < by_name[key] then by_name[key] = id end
        end
    end
    for id, e in pairs(res.buffs) do
        if e.en then CANON_STATUS[id] = by_name[e.en:lower():gsub('%s+%d+$', '')] end
    end
end

local LEARNED_PATH  = require('lib/cache').path('targetbar', 'learned_durations.lua')
local DEBUFF_MAX_AGE = 600
local learned_dur   = {}
local function load_learned()
    local f = loadfile(LEARNED_PATH)
    if f then local ok, t = pcall(f); if ok and type(t) == 'table' then learned_dur = t end end
end
local function save_learned()
    local f = io.open(LEARNED_PATH, 'w')
    if not f then return end
    f:write('-- Auto-cached debuff durations (status id -> seconds) learned from wear-offs.\n')
    f:write('return {\n')
    local keys = {}
    for k in pairs(learned_dur) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do f:write(('  [%d] = %.1f,\n'):format(k, learned_dur[k])) end
    f:write('}\n')
    f:close()
end

local B_TARGET_W, B_TARGET_H = 598, 8
local B_MOB_W,    B_MOB_H    = 160, 8
local B_BAR_PAD              = (_G.XIVUI_THEME == 'ffxi') and 1 or 2
local B_BUFF_ICON_SIZE       = 18
local B_BUFF_ICON_GAP        = 2
local B_BUFF_Y_OFFSET        = 4
local B_FONT_SIZE            = 10

local BUFF_MAX_SLOTS   = 32
local CAST_FLASH_SECS  = 1.5
local CLICK_PAD        = 10

local SCALE = 1
local TARGET_W, TARGET_H, TARGET_IW, TARGET_IH
local MOB_W, MOB_H, MOB_IW, MOB_IH
local BAR_PAD
local BUFF_ICON_SIZE, BUFF_ICON_GAP, BUFF_ICON_STRIDE, BUFF_Y_OFFSET
local CAST_BAR_W, CAST_BAR_H, CAST_IW, CAST_IH
local ARROW_W, ARROW_H, ARROW_GAP, TEXT_INSET, CAST_TOP_GAP

local function compute_geom(s)
    SCALE = math.max(0.5, math.min(2.5, tonumber(s) or 1))
    local function R(n) return math.floor(n * SCALE + 0.5) end
    TARGET_W, TARGET_H   = R(B_TARGET_W), R(B_TARGET_H)
    MOB_W, MOB_H         = R(B_MOB_W), R(B_MOB_H)
    BAR_PAD              = math.max(1, R(B_BAR_PAD))
    TARGET_IW, TARGET_IH = TARGET_W - 2 * BAR_PAD, TARGET_H - 2 * BAR_PAD
    MOB_IW, MOB_IH       = MOB_W - 2 * BAR_PAD, MOB_H - 2 * BAR_PAD
    BUFF_ICON_SIZE       = R(B_BUFF_ICON_SIZE)
    BUFF_ICON_GAP        = R(B_BUFF_ICON_GAP)
    BUFF_ICON_STRIDE     = BUFF_ICON_SIZE + BUFF_ICON_GAP
    BUFF_Y_OFFSET        = R(B_BUFF_Y_OFFSET)
    CAST_BAR_W           = math.floor(TARGET_W * 0.4)
    CAST_BAR_H           = TARGET_H
    CAST_IW, CAST_IH     = CAST_BAR_W - 2 * BAR_PAD, CAST_BAR_H - 2 * BAR_PAD
    ARROW_W, ARROW_H     = R(22), R(10)
    ARROW_GAP            = R(4)
    TEXT_INSET           = R(4)
    CAST_TOP_GAP         = R(10)
end
compute_geom(1)

local defaults = {
    font = 'Constantia',
    font_size = 10,
    scale = 1,
    pos = { x = -1, y = 50 },
    sc_visible = false,
    sc_offset = { x = 0, y = 0 },
}

local settings

local center_x

local tbg_body, tfg_body, tfgg_body, tbar_border, t_text
local mt_arrow, mtbg_body, mtfg_body, mtbar_border, mt_text
local cbg_body, cfg_body, cbar_border, c_text
local buff_slots = {}
local buff_tooltip
local buff_tip_visible = false

local visible = false
local hud_preview_on = false
local ready   = false

local cast_actor_id = nil
local cast = { hold = true }

local BUFF_MSGS   = {[166]=true, [186]=true, [194]=true, [205]=true, [230]=true, [266]=true, [280]=true, [319]=true}
local DEBUFF_MSGS = {[2]=true, [252]=true}
local RESIST_MSGS = {[236]=true, [237]=true, [268]=true, [271]=true}
local SAMBA_DAZE  = {[161]=378, [162]=379}
local SAMBA_BUFF_TO_DAZE = {[368]=378, [369]=379, [370]=380}
local HIT_MSGS = {[1]=true, [67]=true, [185]=true, [187]=true, [264]=true, [265]=true}
local STATUS_APPLY_MSGS = {[127]=true, [141]=true, [320]=true, [242]=true, [243]=true}
local NOLAND_MSGS = {[75]=true, [85]=true, [156]=true, [189]=true, [197]=true, [248]=true,
                     [282]=true, [283]=true, [284]=true, [323]=true, [355]=true, [408]=true,
                     [422]=true, [423]=true, [425]=true, [653]=true, [654]=true}
local DEBUFF_APPLY_MSGS = {[127]=true, [236]=true, [237]=true, [243]=true, [267]=true, [278]=true, [319]=true}
local DEATH_MSGS  = {[6]=true, [20]=true, [113]=true, [406]=true, [605]=true, [646]=true}
local REMOVE_MSGS = { [64]=true, [159]=true, [168]=true, [204]=true, [206]=true,
    [321]=true, [322]=true, [341]=true, [342]=true, [343]=true, [344]=true, [350]=true,
    [378]=true, [531]=true, [647]=true, [805]=true, [806]=true }
local LEARN_MSGS  = { [64]=true, [204]=true, [206]=true, [350]=true, [531]=true }
local DAMAGE_MSGS = {[1]=true, [2]=true, [67]=true, [110]=true, [185]=true, [252]=true}
local BREAK_ON_DAMAGE = {2, 19, 193}

local player_id    = 0
local eb_mob_targets  = {}
local pet_targets     = {}
local player_targets  = {}
local party_buffs     = {}
local enemy_buffs     = {}
local enemy_debuffs   = {}
local debuff_debug    = false
local self_buffs               = {}
local party_member_buff_expires = {}

local exact_hpp     = 100
local last_target_id = nil
local prev_visible  = false
local last_bar_x    = nil
local last_bar_y    = nil
local is_bar_dragging       = false
local bar_press_x           = nil
local bar_press_y           = nil
local current_is_enemy      = false
local mob_target_visible    = false
local mob_target_name       = nil
local mt_press_in_bar       = false
local mob_target_index      = nil
local mob_target_id         = nil

local last_buff_bx   = nil
local last_buff_by   = nil
local last_buff_time = 0
local cached_display = {}

local debuff_icons = {
    ['Blind']='blind',['Blind II']='blind',['Blindga']='blind',['Blinding Fulgor']='blind',
    ['Blank Gaze']='damage_down',['Flash']='blind',['blindness']='blind',
    ['Accuracy Down']='accuracy_down',['Distract']='accuracy_down',['Distract II']='accuracy_down',
    ['Distract III']='accuracy_down',['Sandspin']='accuracy_down',['Infrasonics']='accuracy_down',
    ['Slow']='slow',['Slow II']='slow',['Slowga']='slow',['Elegy']='slow',['Carnage Elegy']='slow',
    ['Geo-Slow']='slow',['Indi-Slow']='slow',['Geo-Torpor']='slow',['Indi-Torpor']='slow',['slow']='slow',
    ['Silence']='silence',['Silencega']='silence',['Chaotic Eye']='silence',['Sound Blast']='silence',
    ['silence']='silence',['mute']='silence',
    ['Paralyze']='paralyze',['Paralyze II']='paralyze',['Paralyzega']='paralyze',['paralysis']='paralyze',
    ['Poison']='poison',['Poison II']='poison',['Poisonga']='poison',['Poisonga II']='poison',
    ['Poison Breath']='poison',['Geo-Poison']='poison',['Indi-Poison']='poison',
    ['Requiem']='poison',['Foe Requiem']='poison',['Foe Requiem II']='poison',
    ['Foe Requiem III']='poison',['Foe Requiem IV']='poison',['Foe Requiem V']='poison',
    ['Foe Requiem VI']='poison',['Foe Requiem VII']='poison',['Foe Requiem VIII']='poison',['poison']='poison',
    ['Dia']='dia',['Dia II']='dia',['Dia III']='dia',['Diaga']='dia',['Diaga II']='dia',['Luminohelix']='dia',
    ['Bio']='miasma',['Bio II']='miasma',['Bio III']='miasma',['Bioga']='miasma',['Bioga II']='miasma',
    ['Plague']='miasma',['Noctohelix']='miasma',['plague']='miasma',['disease']='disease',
    ['Gravity']='heavy',['Gravity II']='heavy',['Geo-Gravity']='heavy',['Indi-Gravity']='heavy',
    ['Weight']='heavy',['Foul Waters']='heavy',['weight']='heavy',
    ['Bind']='bind',['Bindga']='bind',['Shadowbind']='bind',['Sub-zero Smash']='bind',
    ['Cold Wave']='bind',['bind']='bind',
    ['Sleep']='sleep',['Sleep II']='sleep',['Sleepga']='sleep',['Sleepga II']='sleep',
    ['Lullaby']='sleep',['Foe Lullaby']='sleep',['Foe Lullaby II']='sleep',
    ['Horde Lullaby']='sleep',['Horde Lullaby II']='sleep',['Sheep Song']='sleep',
    ['Soporific']='sleep',['Nightmare']='sleep',['sleep']='sleep',
    ['Break']='petrify',['Breakga']='petrify',['Petrify']='petrify',['Petro Eyes']='petrify',
    ['Petribreath']='petrify',['petrification']='petrify',['gradual petrification']='petrify',
    ['Stun']='stun',['Temporal Shift']='stun',['stun']='stun',
    ['Doom']='doom',['Curse']='doom',['Cursed Sphere']='doom',
    ['doom']='doom',['curse']='doom',['bane']='doom',
    ['Amnesia']='amnesia',['amnesia']='amnesia',
    ['Addle']='addle',['Addle II']='addle',['addle']='addle',
    ['Frazzle']='damage_down',['Frazzle II']='damage_down',['Frazzle III']='damage_down',
    ['Acrid Stream']='damage_down',
    ['Threnody']='mag_vuln',['Threnody II']='mag_vuln',
    ['Terror']='petrify',['Absolute Terror']='petrify',['Terror Touch']='petrify',['terror']='petrify',
    ['Charm']='hysteria',['Charm II']='hysteria',['charm']='hysteria',
    ['Burn']='burn',['Pyrohelix']='burn',['Pyrohelix II']='burn',
    ['Frost']='frostbite',['Cryohelix']='frostbite',['Cryohelix II']='frostbite',
    ['Choke']='windburn',['Anemohelix']='windburn',['Anemohelix II']='windburn',
    ['Rasp']='sludge',['Geohelix']='sludge',['Geohelix II']='sludge',
    ['Shock']='electrocution',['Ionohelix']='electrocution',['Ionohelix II']='electrocution',
    ['Drown']='dropsy',['Hydrohelix']='dropsy',['Hydrohelix II']='dropsy',

    ['Feint']='accuracy_down',['Quickstep']='accuracy_down',
    ['Box Step']='damage_down',['Stutter Step']='mag_vuln',
    ['Feather Step']='weakness',
    ['Tomahawk']='damage_down',['Angon']='damage_down',
    ['Dragon Breaker']='weakness',['Hamanoha']='weakness',
    ['Shadowbind']='bind',
    ['Gambit']='weakness',['Rayke']='mag_vuln',
    ['Requiescat']='weakness',

    ['Dark Threnody']='mag_vuln',['Dark Threnody II']='mag_vuln',
    ['Fire Threnody']='mag_vuln',['Fire Threnody II']='mag_vuln',
    ['Ice Threnody']='mag_vuln',['Ice Threnody II']='mag_vuln',
    ['Earth Threnody']='mag_vuln',['Earth Threnody II']='mag_vuln',
    ['Water Threnody']='mag_vuln',['Water Threnody II']='mag_vuln',
    ['Wind Threnody']='mag_vuln',['Wind Threnody II']='mag_vuln',
    ['Light Threnody']='mag_vuln',['Light Threnody II']='mag_vuln',
    ['Ltng. Threnody']='mag_vuln',['Ltng. Threnody II']='mag_vuln',

    ['Katon: Ichi']='burn',['Katon: Ni']='burn',['Katon: San']='burn',
    ['Huton: Ichi']='windburn',['Huton: Ni']='windburn',['Huton: San']='windburn',
    ['Hyoton: Ichi']='frostbite',['Hyoton: Ni']='frostbite',['Hyoton: San']='frostbite',
    ['Doton: Ichi']='sludge',['Doton: Ni']='sludge',['Doton: San']='sludge',
    ['Raiton: Ichi']='electrocution',['Raiton: Ni']='electrocution',['Raiton: San']='electrocution',
    ['Suiton: Ichi']='dropsy',['Suiton: Ni']='dropsy',['Suiton: San']='dropsy',
    ['Aisha: Ichi']='damage_down',['Dokumori: Ichi']='poison',
    ['Hojo: Ichi']='slow',['Hojo: Ni']='slow',
    ['Jubaku: Ichi']='paralyze',
    ['Kurayami: Ichi']='blind',['Kurayami: Ni']='blind',
    ['Myoshu: Ichi']='amnesia',['Yurin: Ichi']='amnesia',

    ['Geo-Frailty']='damage_down',['Indi-Frailty']='damage_down',
    ['Geo-Wilt']='damage_down',['Indi-Wilt']='damage_down',
    ['Geo-Malaise']='mag_vuln',['Indi-Malaise']='mag_vuln',
    ['Geo-Fade']='addle',['Indi-Fade']='addle',
    ['Geo-Vex']='addle',['Indi-Vex']='addle',
    ['Geo-Languor']='accuracy_down',['Indi-Languor']='accuracy_down',
    ['Geo-Paralysis']='paralyze',['Indi-Paralysis']='paralyze',
    ['Geo-Slip']='accuracy_down',['Indi-Slip']='accuracy_down',

    ['Absorb-ACC']='accuracy_down',['Absorb-DEX']='accuracy_down',['Absorb-AGI']='accuracy_down',
    ['Absorb-STR']='damage_down',['Absorb-VIT']='damage_down',
    ['Absorb-CHR']='damage_down',['Absorb-Attri']='damage_down',
    ['Absorb-INT']='addle',['Absorb-MND']='addle',
    ['Absorb-TP']='amnesia',

    ['Aspir']='poison',['Aspir II']='poison',['Aspir III']='poison',
    ['Drain']='poison',['Drain II']='poison',['Drain III']='poison',
    ['Aspir Daze']='poison',['Drain Daze']='poison',['Haste Daze']='slow',

    ['Attack Down']='damage_down',['Defense Down']='damage_down',
    ['Evasion Down']='accuracy_down',['Avoidance Down']='accuracy_down',
    ['Magic Attack Down']='addle',['Magic Defense Down']='mag_vuln',
    ['Magic Accuracy Down']='addle',['Magic Evasion Down']='accuracy_down',

    ['Battlefield Elegy']='slow',['Massacre Elegy']='slow',
    ['Pining Nocturne']='addle',["Maiden's Virelai"]='hysteria',

    ['Dream Flower']='sleep',['Repose']='sleep',

    ['Blade Bash']='stun',['Shield Bash']='stun',
    ['Violent Flourish']='stun',['Weapon Bash']='stun',

    ['Cruel Joke']='doom',['Mortal Ray']='doom',['Haunt']='doom',

    ['Weakness']='weakness',['Double Weakness']='weakness',

    ['Animated']='hysteria',

    ['Entomb']='petrify',['Jettatura']='petrify',

    ['Ice Break']='bind',

    ['Subduction']='heavy',

    ['Lowing']='disease',

    ['Silent Storm']='silence',['Water Bomb']='silence',['Auroral Drape']='silence',

    ['Actinic Burst']='blind',['Thermal Pulse']='blind',
    ['Light of Penance']='blind',['Radiant Breath']='blind',

    ['Taint']='poison',['Cesspool']='miasma',['Delta Thrust']='miasma',
    ['Venom Shell']='poison',['Kaustra']='miasma',
    ['Luminohelix II']='dia',['Noctohelix II']='miasma',

    ['Dispel']='damage_down',['Dispelga']='damage_down',['Magic Finale']='damage_down',

    ['Awful Eye']='damage_down',['Bad Breath']='miasma',['Bilgestorm']='damage_down',
    ['Cimicine Discharge']='slow',['Corrosive Ooze']='damage_down',
    ['Demoralizing Roar']='damage_down',['Embalming Earth']='slow',
    ['Enervation']='damage_down',['Filamented Hold']='slow',
    ['Frightful Roar']='damage_down',['Geist Wall']='damage_down',
    ['Impact']='damage_down',['Magnetite Cloud']='damage_down',
    ['Odyllic Subterfuge']='addle',['Sepulcher']='accuracy_down',
    ['Tearing Gust']='mag_vuln',['Tenebral Crush']='damage_down',
    ['Arcane Crest']='accuracy_down',
}

local json              = require('json')
local _descs            = require('lib/status_descs').load()
local debuff_buff_descs = _descs.debuffs or {}

local _ok_manual, _manual = pcall(require, 'components/targetbar/manual_debuffs')
if not _ok_manual or type(_manual) ~= 'table' then _manual = {} end
local MANUAL_WS         = _manual.ws or {}
local MANUAL_JA         = _manual.ja or {}
local MANUAL_SP         = _manual.sp or {}
local _debuff_applied   = false

local _ok_ow, STATUS_OVERWRITE = pcall(require, 'components/targetbar/status_overwrite')
if not _ok_ow or type(STATUS_OVERWRITE) ~= 'table' then STATUS_OVERWRITE = {} end

local _ok_md, _mdur = pcall(require, 'components/targetbar/manual_durations')
if not _ok_md or type(_mdur) ~= 'table' then _mdur = {} end
local MANUAL_DUR_WS = _mdur.ws or {}
local MANUAL_DUR_JA = _mdur.ja or {}
local MANUAL_DUR_SP = _mdur.sp or {}

local function debuff_icon_path(name)
    local file = debuff_icons[name]
    return file and (DEBUFF_ICONS_PATH .. file .. '.png') or DEBUFF_ICON_BG
end

local function fmt_timer(remains)
    if remains >= 3600 then
        return math.floor(remains / 3600) .. 'h'
    elseif remains > 60 then
        return math.floor(remains / 60) .. 'm'
    else
        return tostring(math.floor(remains))
    end
end

local allied_ids         = {}
local allied_indices     = {}
local allied_cache_time  = 0
local ALLIED_KEY_FMTS    = { 'p%i', 'a1%i', 'a2%i' }

local function refresh_allied_cache()
    local now = socket.gettime()
    if now - allied_cache_time < 1.0 then return end
    allied_cache_time = now
    allied_ids      = {}
    allied_indices  = {}
    local party = windower.ffxi.get_party()
    for _, fmt in ipairs(ALLIED_KEY_FMTS) do
        for i = 0, 5 do
            local m = party[string.format(fmt, i)]
            if m and m.id and m.id > 0 then
                allied_ids[m.id] = true
                if m.mob and m.mob.id and m.mob.id > 0 then
                    allied_ids[m.mob.id] = true
                end
                local pi = m.mob and m.mob.pet_index
                if not pi or pi == 0 then
                    local mm = windower.ffxi.get_mob_by_id(m.id)
                    pi = mm and mm.pet_index
                end
                if pi and pi > 0 then
                    allied_indices[pi] = true
                end
            end
        end
    end
end

local function is_allied_mob(mob_id, mob_index)
    refresh_allied_cache()
    return (mob_id and allied_ids[mob_id] == true)
        or (mob_index and allied_indices[mob_index] == true)
end

local function actor_is_friendly(actor_id)
    if not actor_id or actor_id == 0 then return false end
    if actor_id == player_id then return true end
    local m = windower.ffxi.get_mob_by_id(actor_id)
    if m and (m.in_party or m.in_alliance) then return true end
    return is_allied_mob(actor_id, m and m.index)
end

local function timer_color(actor)
    if actor == player_id then return 255, 255, 255 end
    if actor then
        local mob = windower.ffxi.get_mob_by_id(actor)
        if mob and mob.is_npc and not mob.in_party and not is_allied_mob(mob.id, mob.index) then
            return 255, 200, 80
        end
    end
    return 180, 220, 255
end

local PALETTE = {
    enemy  = { bg = {80, 15, 15},  fg = {255, 186, 183}, fgg = {160, 70, 70},   border = {255, 140, 140}, text = {255, 186, 183} },
    pc     = { bg = {8, 45, 82},   fg = {226, 255, 255}, fgg = {40, 130, 160},  border = {80, 180, 250},  text = {226, 255, 255} },
    npc    = { bg = {70, 52, 10},  fg = {255, 238, 170}, fgg = {150, 118, 38},  border = {250, 208, 90},  text = {255, 238, 170} },
    object = { bg = {42, 42, 46},  fg = {214, 214, 220}, fgg = {108, 108, 114}, border = {172, 172, 180}, text = {214, 214, 220} },
}
if _G.XIVUI_THEME == 'ffxi' then
    PALETTE.enemy  = { bg = {255, 255, 255}, fg = {250, 132, 130}, fgg = {150, 56, 58},   border = {255, 255, 255}, text = {250, 158, 158} }
    PALETTE.pc     = { bg = {255, 255, 255}, fg = {140, 172, 238}, fgg = {54, 92, 152},   border = {255, 255, 255}, text = {160, 188, 242} }
    PALETTE.npc    = { bg = {255, 255, 255}, fg = {202, 204, 132}, fgg = {120, 118, 56},  border = {255, 255, 255}, text = {210, 210, 152} }
    PALETTE.object = { bg = {255, 255, 255}, fg = {200, 208, 222}, fgg = {100, 104, 116}, border = {255, 255, 255}, text = {204, 210, 224} }
end

local DEFAULT_OBJECTS = {
    'home point', 'survival guide', 'field manual', 'conflux', 'waypoint',
    'runic portal', 'cavernous maw', 'treasure casket', 'treasure coffer',
    'treasure chest', 'hunt registry', 'planar rift', 'enigmatic footprints',
    'goblin footprints', 'voidstone', 'waystone', 'geomagnetron',
    'mining point', 'logging point', 'harvesting point', 'excavation point', '???',
}
local object_patterns = DEFAULT_OBJECTS

local function load_object_patterns()
    local path = windower.addon_path .. 'data/targetbar/objects.txt'
    local f = io.open(path, 'r')
    if f then
        local list = {}
        for line in f:lines() do
            local p = line:gsub('#.*$', ''):gsub('^%s+', ''):gsub('%s+$', ''):lower()
            if p ~= '' then list[#list + 1] = p end
        end
        f:close()
        if #list > 0 then object_patterns = list end
        return
    end
    f = io.open(path, 'w')
    if f then
        f:write('# Targetbar: names that should read as objects (gray bar).\n')
        f:write('# One case-insensitive substring per line; # starts a comment.\n')
        f:write('# A targeted spawn_type-2 entity whose name contains one of these is an\n')
        f:write('# object; everything else with spawn_type 2 is treated as an NPC (yellow).\n')
        for _, p in ipairs(DEFAULT_OBJECTS) do f:write(p .. '\n') end
        f:close()
    end
end

local function is_object_name(name)
    if not name then return false end
    local n = name:lower()
    for _, p in ipairs(object_patterns) do
        if n:find(p, 1, true) then return true end
    end
    return false
end

local function visual_kind(target, is_enemy)
    if not target.is_npc then return 'pc' end
    if not is_enemy then return 'pc' end
    local st = target.spawn_type
    if st == 16 then return 'enemy' end
    if st ~= 2  then return 'object' end
    return is_object_name(target.name) and 'object' or 'npc'
end

local buff_descs = (function()
    local t = {}
    for k, v in pairs(_descs.buffs or {}) do t[tonumber(k)] = v end
    return t
end)()

local function make_image(cfg)
    local img = images.new(cfg)
    img:size(cfg.size.width, cfg.size.height)
    img:color(cfg.color.red, cfg.color.green, cfg.color.blue)
    img:alpha(cfg.color.alpha)
    img:path(cfg.texture.path)
    img:fit(cfg.texture.fit)
    img:draggable(cfg.draggable or false)
    img:hide()
    return img
end

local function make_fill(w, h, r, g, b, a, path)
    return make_image({
        pos = { x = 0, y = 0 }, visible = false,
        color = { alpha = a, red = r, green = g, blue = b },
        size = { width = w, height = h },
        texture = { path = path, fit = true },
        repeatable = { x = 1, y = 1 }, draggable = false,
    })
end

local function cast_start(actor_id, spell_id)
    local spell = _priv.spell(spell_id)
    cast_actor_id = actor_id
    cast_state.start(cast, spell and spell.cast_time or 3, spell and spell.en or '...', spell_id)
end

local function cast_cancel()
    cast_actor_id = nil
    cast_state.cancel(cast)
end

local function cast_interrupt() cast_state.interrupt(cast) end

local function cast_complete() cast_state.complete(cast) end

local function cast_flash(actor_id, action_id, action_type)
    if cast.start_time and cast_actor_id == actor_id then return end
    local entry
    if action_type == 'ws' then
        entry = _priv.weapon_skill(action_id)
    elseif action_type == 'ja' then
        entry = _priv.ability(action_id)
    elseif action_type == 'mob' then
        entry = res.monster_abilities and res.monster_abilities[action_id]
    end
    if not entry then return end
    cast_actor_id = actor_id
    cast_state.flash(cast, entry.en, CAST_FLASH_SECS)
end

local function scaled_font()
    return math.max(6, math.floor(((settings and settings.font_size) or B_FONT_SIZE) * SCALE + 0.5))
end

local function apply_position(nx, ny)
    local fs = scaled_font()
    t_text:pos(nx + TEXT_INSET, ny - (fs + TEXT_INSET))
    tbg_body:pos(nx, ny)
    tfg_body:pos(nx + BAR_PAD, ny + BAR_PAD)
    tfgg_body:pos(nx + BAR_PAD, ny + BAR_PAD)
    tbar_border:pos(nx, ny)

    local arrow_x = nx + TARGET_W + ARROW_GAP
    local mtx = arrow_x + ARROW_W + ARROW_GAP
    mt_arrow:pos(arrow_x, ny - 1)
    mtbg_body:pos(mtx, ny)
    mtfg_body:pos(mtx + BAR_PAD, ny + BAR_PAD)
    mtbar_border:pos(mtx, ny)
    mt_text:pos(mtx, ny - (fs + TEXT_INSET))

    local cx = nx + TARGET_W - CAST_BAR_W
    local cy = ny - CAST_BAR_H - CAST_TOP_GAP
    cbg_body:pos(cx, cy)
    cfg_body:pos(cx + BAR_PAD, cy + BAR_PAD)
    cbar_border:pos(cx, cy)
    local ui_x_res = windower.get_windower_settings().ui_x_res
    c_text:pos(cx + CAST_BAR_W - 2 - ui_x_res, cy + CAST_BAR_H - fs)

    last_bar_x = nx
    last_bar_y = ny
end

local function apply_scale(s)
    compute_geom(s)
    if _G.XIVUI_TARGET then _G.XIVUI_TARGET.scale = SCALE end
    if not ready then return end
    local function rs(o, w, h) if o then pcall(function() o:size(w, h) end) end end
    rs(tbg_body, TARGET_W, TARGET_H); rs(tfg_body, TARGET_IW, TARGET_IH); rs(tfgg_body, 0, TARGET_IH)
    rs(tbar_border, TARGET_W, TARGET_H)
    rs(mt_arrow, ARROW_W, ARROW_H)
    rs(mtbg_body, MOB_W, MOB_H); rs(mtfg_body, MOB_IW, MOB_IH); rs(mtbar_border, MOB_W, MOB_H)
    rs(cbg_body, CAST_BAR_W, CAST_BAR_H); rs(cfg_body, 0, CAST_IH); rs(cbar_border, CAST_BAR_W, CAST_BAR_H)
    local fs = scaled_font()
    local function tz(o, sz) if o then pcall(function() o:size(sz) end) end end
    tz(t_text, fs); tz(mt_text, fs); tz(c_text, fs)
    local tsz = math.max(6, math.floor(7 * SCALE + 0.5))
    for i = 1, BUFF_MAX_SLOTS do
        local b = buff_slots[i]
        if b then rs(b.icon, BUFF_ICON_SIZE, BUFF_ICON_SIZE); tz(b.timer_t, tsz) end
    end
    if skillchain and skillchain.apply_scale then pcall(skillchain.apply_scale) end
    apply_position(last_bar_x or center_x or 0, last_bar_y or (settings and settings.pos and settings.pos.y) or 50)
end

local function move_to(nx, ny)
    nx = math.floor(tonumber(nx) or last_bar_x or center_x or 0)
    ny = math.floor(tonumber(ny) or last_bar_y or (settings and settings.pos and settings.pos.y) or 50)
    settings.pos.x = nx
    settings.pos.y = ny
    center_x = nx
    apply_position(nx, ny, settings.font_size or 10)
end

local function actor_samba_daze(actor_id)
    local now = os.clock()
    local function active(tbl)
        if not tbl then return nil end
        for buff_id, daze_id in pairs(SAMBA_BUFF_TO_DAZE) do
            local e = tbl[buff_id]
            if e and (e.expires == nil or now <= e.expires) then return daze_id end
        end
    end
    if actor_id == player_id then return active(self_buffs) end
    return active(party_member_buff_expires[actor_id])
end

local function apply_overwrite(target_id, status_id)
    local sup = STATUS_OVERWRITE[status_id]
    if not sup then return end
    local ed, eb = enemy_debuffs[target_id], enemy_buffs[target_id]
    for _, rid in ipairs(sup) do
        local cid = CANON_STATUS[rid] or rid
        if ed then ed[rid] = nil; ed[cid] = nil end
        if eb then eb[rid] = nil; eb[cid] = nil end
    end
end

local function apply_enemy_debuff(target_id, effect_id, spell_id, actor_id, category, name_override)
    if not effect_id or effect_id <= 0 then return end
    effect_id = CANON_STATUS[effect_id] or effect_id
    if not enemy_debuffs[target_id] then enemy_debuffs[target_id] = {} end
    apply_overwrite(target_id, effect_id)

    local spell
    if category == 4 then
        spell = _priv.spell(spell_id)
    elseif category == 6 or category == 14 then
        spell = _priv.ability(spell_id)
    elseif category == 3 then
        spell = _priv.weapon_skill(spell_id)
    end

    if category == 4 and spell then
        local overwrites = spell.overwrites or {}
        for eff_id, existing in pairs(enemy_debuffs[target_id]) do
            if existing.spell_id then

                local old_entry = res.spells and res.spells[existing.spell_id]
                local old_ow = (old_entry and old_entry.overwrites) or {}
                for _, v in ipairs(old_ow) do
                    if spell_id == v then return end
                end
            end

            for _, v in ipairs(overwrites) do
                if existing.spell_id == v then
                    enemy_debuffs[target_id][eff_id] = nil
                end
            end
        end
    end

    local status_info  = res.buffs and res.buffs[effect_id]
    local display_name = name_override
    if not display_name and status_info and status_info.en then
        display_name = (status_info.en:gsub('%s+%d+$', ''))
    end
    if not display_name then
        if category == 4 and spell and spell.name then
            display_name = spell.name
        elseif category == 6 and spell and spell.en then
            display_name = spell.en
        else
            display_name = 'Status #' .. tostring(effect_id)
        end
    end
    display_name = cap_words(display_name)

    local icon_path
    if status_info then
        icon_path = ICONS_PATH .. tostring(effect_id) .. '.png'
    else
        icon_path = debuff_icon_path(display_name)
    end
    local desc = buff_descs[effect_id] or debuff_buff_descs[display_name] or ''

    local seed_dur
    if spell_id then
        if category == 3 then seed_dur = MANUAL_DUR_WS[spell_id]
        elseif category == 6 or category == 14 then seed_dur = MANUAL_DUR_JA[spell_id]
        elseif category == 4 then seed_dur = MANUAL_DUR_SP[spell_id] end
    end
    local known_dur = (spell and spell.duration) or BUFF_STATUS_DURATION[effect_id]
    local dur       = known_dur or learned_dur[effect_id] or seed_dur
    local now       = os.clock()

    local daze_total
    if STEP_DAZE_BASE[effect_id] then
        local existing = enemy_debuffs[target_id][effect_id]
        if existing and existing.daze_total then
            if (now - (existing.applied_at or 0)) < 1 then
                daze_total = existing.daze_total
            else
                daze_total = math.min(existing.daze_total + STEP_DAZE_STEP, STEP_DAZE_CAP)
            end
        else
            daze_total = STEP_DAZE_BASE_DUR
        end
        dur = daze_total
    end
    local has_timer = dur and dur > 0

    enemy_debuffs[target_id][effect_id] = {
        name       = display_name,
        icon_path  = icon_path,
        desc       = desc,
        timer      = has_timer and (now + dur) or nil,
        has_timer  = has_timer or false,
        actor      = actor_id,
        spell_id   = spell_id,
        applied_at = now,
        learn      = (known_dur == nil and daze_total == nil),
        daze_total = daze_total,
    }
    _debuff_applied = true
end

local function remove_enemy_status(target_id, status_id, learn_full)
    local cid = CANON_STATUS[status_id] or status_id
    local ed, eb = enemy_debuffs[target_id], enemy_buffs[target_id]
    if ed then
        local e = ed[cid] or ed[status_id]
        if learn_full and e and e.learn and e.applied_at then
            local elapsed = os.clock() - e.applied_at
            if elapsed >= 1 and elapsed <= DEBUFF_MAX_AGE then
                local prev = learned_dur[cid]
                learned_dur[cid] = prev and (prev * 0.6 + elapsed * 0.4) or elapsed
                save_learned()
            end
        end
        ed[cid] = nil; ed[status_id] = nil
    end
    if eb then eb[cid] = nil; eb[status_id] = nil end
end

local function buff_strip_hide()
    for i = 1, BUFF_MAX_SLOTS do
        local s = buff_slots[i]
        if s.current_path then
            s.icon:hide()
            if s.timer_t then s.timer_t:hide() end
            s.current_path = nil
            s.display_name = nil
            s.display_desc = nil
        end
    end
    if buff_tooltip then buff_tooltip:hide() end
    last_buff_bx = nil
    last_buff_by = nil
    last_buff_time = 0
    cached_display = {}
end

local function buff_strip_update(bx, by)
    local now = os.clock()
    local pos_changed  = (bx ~= last_buff_bx or by ~= last_buff_by)
    local time_elapsed = (now - last_buff_time) >= 0.5
    if not pos_changed and not time_elapsed then return end

    last_buff_bx = bx
    last_buff_by = by

    if time_elapsed then
        last_buff_time = now
        local target = windower.ffxi.get_mob_by_target('t')
        cached_display = {}

        if target and target.is_npc and not target.in_party and not is_allied_mob(target.id, target.index) then
            local tracked_debuffs = enemy_debuffs[target.id]
            if tracked_debuffs then
                local debuff_list = {}
                for effect_id, data in pairs(tracked_debuffs) do
                    local remaining = data.timer and (data.timer - now) or nil
                    local stale = remaining == nil and data.applied_at and (now - data.applied_at > DEBUFF_MAX_AGE)
                    if (remaining == nil or remaining > 0) and not stale then
                        debuff_list[#debuff_list + 1] = { effect_id = effect_id, data = data, remaining = remaining or math.huge }
                    else
                        tracked_debuffs[effect_id] = nil
                    end
                end
                table.sort(debuff_list, function(a, b) return a.remaining > b.remaining end)
                for _, entry in ipairs(debuff_list) do
                    cached_display[#cached_display + 1] = {
                        path         = entry.data.icon_path or DEBUFF_ICON_BG,
                        display_name = entry.data.name or ('Status #' .. tostring(entry.effect_id)),
                        display_desc = entry.data.desc or '',
                        timer        = entry.data.timer,
                        has_timer    = entry.data.has_timer,
                        is_debuff    = true,
                        actor        = entry.data.actor,
                    }
                end
            end

            local tracked_buffs = enemy_buffs[target.id]
            if tracked_buffs then
                for status_id, data in pairs(tracked_buffs) do
                    if shadow_tracker.is_shadow(status_id) and shadow_tracker.is_depleted(target.id) then
                        tracked_buffs[status_id] = nil
                    elseif data.expires == nil or now <= data.expires then
                        local buff_info = res.buffs and res.buffs[status_id]
                        cached_display[#cached_display + 1] = {
                            path         = ICONS_PATH .. tostring(status_id) .. '.png',
                            display_name = cap_words(buff_info and buff_info.en or ('Buff ' .. tostring(status_id))),
                            display_desc = buff_descs[status_id] or '',
                            timer        = data.expires,
                            has_timer    = true,
                            is_debuff    = false,
                            actor        = data.actor,
                        }
                    else
                        tracked_buffs[status_id] = nil
                    end
                end
            end
        elseif target and target.in_party and not target.is_npc then
            local p = windower.ffxi.get_player()
            local is_self = p and target.id == p.id
            local raw_buffs = is_self and (p.buffs or {}) or (party_buffs[target.id] or {})
            for i = 1, 32 do
                local bid = raw_buffs[i]
                if bid and bid ~= 255 and bid ~= 0
                   and not (shadow_tracker.is_shadow(bid) and shadow_tracker.is_depleted(target.id)) then
                    local info = res.buffs and res.buffs[bid]
                    local sb = is_self and self_buffs[bid]
                        or (party_member_buff_expires[target.id] and party_member_buff_expires[target.id][bid])
                        or nil
                    local expires = sb and sb.expires or nil
                    cached_display[#cached_display + 1] = {
                        path         = ICONS_PATH .. tostring(bid) .. '.png',
                        display_name = cap_words(info and info.en or ('Buff ' .. tostring(bid))),
                        display_desc = buff_descs[bid] or '',
                        timer        = expires,
                        has_timer    = expires ~= nil,
                        is_debuff    = false,
                        actor        = sb and sb.actor or nil,
                    }
                end
            end
        end
    end

    local icon_y = by + TARGET_H + BUFF_Y_OFFSET
    for slot_i = 1, BUFF_MAX_SLOTS do
        local entry = cached_display[slot_i]
        local s = buff_slots[slot_i]
        if entry then
            if s.current_path ~= entry.path then
                s.icon:path(entry.path)
                s.current_path = entry.path
            end
            s.icon:pos(bx + (slot_i - 1) * BUFF_ICON_STRIDE, icon_y)
            s.icon:show()
            s.display_name = entry.display_name
            s.display_desc = entry.display_desc
            if s.timer_t then
                local timer_str
                if entry.is_debuff then
                    if entry.has_timer and entry.timer then
                        local remains = entry.timer - now
                        timer_str = remains > 0 and fmt_timer(remains) or '0'
                    else
                        timer_str = nil
                    end
                elseif entry.has_timer and entry.timer then
                    local remains = entry.timer - now
                    timer_str = remains > 0 and fmt_timer(remains) or nil
                end
                if timer_str then
                    s.timer_t.v = timer_str
                    s.timer_t:color(timer_color(entry.actor))
                    local ix = bx + (slot_i - 1) * BUFF_ICON_STRIDE
                    s.timer_t:pos(ix + math.floor(BUFF_ICON_SIZE / 2) - math.floor(#timer_str * 3), icon_y + BUFF_ICON_SIZE - 2)
                    s.timer_t:show()
                else
                    s.timer_t.v = ''
                    s.timer_t:hide()
                end
            end
        else
            if s.current_path then
                s.icon:hide()
                if s.timer_t then s.timer_t:hide() end
                s.current_path = nil
                s.display_name = nil
                s.display_desc = nil
            end
        end
    end
end

local fill_path  = BAR_DIR .. 'fill_white.png'

local function render_target()
    local te = XIVUI_TARGET
    if visible ~= prev_visible then
        if visible then last_target_id = nil end
        prev_visible = visible
    end

    if not visible then
        tbg_body:hide()
        tfg_body:hide()
        tfgg_body:size(0, TARGET_H)
        tfgg_body:hide()
        tbar_border:hide()
        t_text:hide()
        buff_strip_hide()
        mt_arrow:hide()
        mtbg_body:hide()
        mtfg_body:hide()
        mtbar_border:hide()
        mt_text:hide()
        cbg_body:hide()
        cfg_body:hide()
        cbar_border:hide()
        c_text:hide()
        skillchain.hide()
        te.visible = false; te.sc_active = false
        return
    end

    local bx = tbg_body:pos_x()
    local by = tbg_body:pos_y()
    if bx ~= last_bar_x or by ~= last_bar_y then
        apply_position(bx, by, settings.font_size or 10)
    end

    tbg_body:show()
    tfg_body:show()
    tbar_border:show()
    t_text:show()

    if hud_preview_on then
        tbg_body:size(TARGET_W, TARGET_H)
        tfg_body:size(TARGET_IW, TARGET_IH)
        tbar_border:size(TARGET_W, TARGET_H)
        t_text.name = 'Target'
        local icon_y = by + TARGET_H + BUFF_Y_OFFSET
        for i = 1, BUFF_MAX_SLOTS do
            local s = buff_slots[i]
            if s and s.icon then
                if i <= 5 then
                    if s.current_path ~= DEBUFF_ICON_BG then s.icon:path(DEBUFF_ICON_BG); s.current_path = DEBUFF_ICON_BG end
                    s.icon:size(BUFF_ICON_SIZE, BUFF_ICON_SIZE); s.icon:pos(bx + (i - 1) * BUFF_ICON_STRIDE, icon_y); s.icon:show()
                else
                    s.icon:hide()
                end
                if s.timer_t then s.timer_t:hide() end
            end
        end
        mt_arrow:show()
        mtbg_body:size(MOB_W, MOB_H); mtbg_body:show()
        mtfg_body:size(MOB_IW, MOB_IH); mtfg_body:show()
        mtbar_border:size(MOB_W, MOB_H); mtbar_border:show()
        mt_text.name = 'Sub-Target'; mt_text:show()
        cbg_body:hide(); cfg_body:hide(); cbar_border:hide(); c_text:hide(); skillchain.hide()
        te.visible = false; te.sc_active = false
        return
    end

    local target = XIVUI_TMOB
    if not target or target.id == 0 then
        tbg_body:hide(); tfg_body:hide(); tfgg_body:hide(); tbar_border:hide(); t_text:hide()
        mt_arrow:hide(); mtbg_body:hide(); mtfg_body:hide(); mtbar_border:hide(); mt_text:hide()
        buff_strip_hide(); cbg_body:hide(); cfg_body:hide(); cbar_border:hide(); c_text:hide()
        te.visible = false; te.sc_active = false
        return
    end

    local is_enemy = target.is_npc == true and target.in_party ~= true and not is_allied_mob(target.id, target.index)
    current_is_enemy = is_enemy

    if target.id ~= last_target_id then
        exact_hpp = target.hpp
        last_target_id = target.id
        local p = PALETTE[visual_kind(target, is_enemy)]
        tbg_body:color(p.bg[1], p.bg[2], p.bg[3])
        tfg_body:color(p.fg[1], p.fg[2], p.fg[3])
        tfgg_body:color(p.fgg[1], p.fgg[2], p.fgg[3])
        tbar_border:color(p.border[1], p.border[2], p.border[3])
    end

    local hpp = target.hpp
    exact_hpp = exact_hpp + (hpp - exact_hpp) * 0.1
    tfg_body:size(math.floor(TARGET_IW * hpp / 100), TARGET_IH)
    tbg_body:size(TARGET_W, TARGET_H)

    local hp_diff = math.abs(hpp - exact_hpp)
    if hp_diff > 0.5 then
        local lo = math.min(hpp, exact_hpp) / 100
        local hi = math.max(hpp, exact_hpp) / 100
        tfgg_body:pos(bx + BAR_PAD + math.floor(TARGET_IW * lo), by + BAR_PAD)
        tfgg_body:size(math.max(1, math.floor(TARGET_IW * (hi - lo))), TARGET_IH)
        tfgg_body:show()
    else
        tfgg_body:size(0, TARGET_IH)
        tfgg_body:hide()
    end

    t_text.name = target.name
    t_text.hpp  = target.hpp

    te.visible = true
    te.enemy   = is_enemy
    te.monster = is_enemy and target.spawn_type == 16
    te.x, te.y = bx, by
    te.w, te.h = TARGET_W, TARGET_H
    te.name = target.name
    te.font = (settings.font_size or 10) * (te.scale or 1)
    te.fontname = settings.font or 'Constantia'
    if te._ext_name ~= target.name then
        te._ext_name = target.name
        te._ext_w = math.ceil((#tostring(target.name) + 6) * (te.font or 10) * 0.55)
        te._ext_exact = false
    end
    local nw = t_text:extents()
    if nw and nw > 0 then te._ext_w = nw; te._ext_exact = true end
    te.name_right = bx + 4 + (te._ext_w or 0)
    te.name_right_exact = te._ext_exact and true or false

    if target.hpp == 0 then
        t_text:color(155, 155, 155)
    else
        local p = PALETTE[visual_kind(target, is_enemy)]
        t_text:color(p.text[1], p.text[2], p.text[3])
    end

    if is_enemy or (target.in_party and not target.is_npc) then
        buff_strip_update(bx, by)
    else
        buff_strip_hide()
    end

    local prog = (cast_actor_id == target.id) and cast_state.progress(cast) or nil
    if prog then
        local w = math.max(1, math.floor(CAST_IW * prog))
        if cast_state.is_interrupt(cast) then
            cfg_body:color(232, 64, 64); c_text:color(232, 64, 64); c_text.v = 'Interrupted'
        else
            cfg_body:color(255, 255, 200); c_text:color(255, 255, 200); c_text.v = cast.name or ''
        end
        cbg_body:size(CAST_BAR_W, CAST_BAR_H)
        cfg_body:size(w, CAST_IH)
        cbar_border:size(CAST_BAR_W, CAST_BAR_H)
        cbg_body:show()
        cfg_body:show()
        cbar_border:show()
        c_text:show()
    else
        cbg_body:hide()
        cfg_body:hide()
        cbar_border:hide()
        c_text:hide()
    end

    skillchain.update(target, is_enemy, hpp, bx, by, TARGET_W, TARGET_H)
    te.sc_active = skillchain.bounds() ~= nil

    local mob_target = nil
    if hpp > 0 then
        if is_enemy then
            local t_idx = target.target_index
            if t_idx and t_idx > 0 then
                local mt = windower.ffxi.get_mob_by_index(t_idx)
                if mt and mt.id > 0 and mt.hpp > 0 then mob_target = mt end
            end
            if not mob_target then
                local tracked = eb_mob_targets[target.id]
                if tracked then
                    local mt = windower.ffxi.get_mob_by_id(tracked)
                    if mt and mt.id > 0 and mt.hpp > 0 then mob_target = mt end
                end
            end
        elseif target.is_npc then

            local t_idx = target.target_index
            if t_idx and t_idx > 0 then
                local mt = windower.ffxi.get_mob_by_index(t_idx)
                if mt and mt.id > 0 then mob_target = mt end
            end
            if not mob_target then
                local tracked_id = pet_targets[target.id]
                if tracked_id then
                    local mt = windower.ffxi.get_mob_by_id(tracked_id)
                    if mt and mt.id > 0 and mt.hpp > 0 then mob_target = mt end
                end
            end
            if not mob_target then
                local tracked = eb_mob_targets[target.id]
                if tracked then
                    local mt = windower.ffxi.get_mob_by_id(tracked)
                    if mt and mt.id > 0 and mt.hpp > 0 then mob_target = mt end
                end
            end
        else
            local pt_idx
            if target.id == player_id then
                local pd = windower.ffxi.get_player()
                if pd then pt_idx = pd['target_index'] end
            else
                pt_idx = player_targets[target.index]
                if not pt_idx or pt_idx == 0 then
                    local tm = windower.ffxi.get_mob_by_index(target.index)
                    if tm then pt_idx = tm.target_index end
                end
            end
            if pt_idx and pt_idx > 0 then
                local mt = windower.ffxi.get_mob_by_index(pt_idx)
                if mt and mt.id > 0 then mob_target = mt end
            end
        end
    end

    if mob_target then
        local mt_fill = math.floor(MOB_IW * (mob_target.hpp / 100))
        mtbg_body:size(MOB_W, MOB_H); mtfg_body:size(mt_fill, MOB_IH); mtbar_border:size(MOB_W, MOB_H)
        mt_text.name = mob_target.name
        local mt_enemy = mob_target.is_npc == true and mob_target.in_party ~= true and not is_allied_mob(mob_target.id, mob_target.index)
        local mp = PALETTE[visual_kind(mob_target, mt_enemy)]
        do
            mtbg_body:color(mp.bg[1], mp.bg[2], mp.bg[3])
            mtfg_body:color(mp.fg[1], mp.fg[2], mp.fg[3])
            mtbar_border:color(mp.border[1], mp.border[2], mp.border[3])
            mt_text:color(mp.text[1], mp.text[2], mp.text[3])
        end
        mob_target_visible = true
        mob_target_name    = mob_target.name
        mob_target_index   = mob_target.index
        mob_target_id      = mob_target.id
        mt_arrow:show(); mtbg_body:show(); mtfg_body:show(); mtbar_border:show(); mt_text:show()
    else
        mob_target_visible = false
        mob_target_name    = nil
        mob_target_index   = nil
        mob_target_id      = nil
        mt_arrow:hide(); mtbg_body:hide(); mtfg_body:hide(); mtbar_border:hide(); mt_text:hide()
    end
end

local targetbar = {}

function targetbar.init()
    settings = config.load('data/targetbar/settings.xml', defaults)
    compute_geom(settings.scale or 1)
    _G.XIVUI_TARGET = { visible = false, enemy = false, monster = false, x = 0, y = 0, w = 0, h = 0,
                        name = '', font = 10, fontname = 'Constantia', name_right_exact = false, scale = SCALE }
    load_object_patterns()
    load_learned()
    local p = windower.ffxi.get_player()
    player_id = p and p.id or 0

    center_x = settings.pos.x >= 0 and settings.pos.x
               or (((windower.get_windower_settings() or {}).ui_x_res or 1920) / 2 - TARGET_W / 2)
    local ny = settings.pos.y

    local text_cfg = {
        pos   = { x = center_x + TEXT_INSET, y = ny - (scaled_font() + TEXT_INSET) },
        text  = { size = scaled_font(), font = settings.font, fonts = {settings.font},
                  stroke = { width = 2, alpha = 200, red = 0, green = 0, blue = 0 } },
        flags = { bold = true, draggable = false },
        bg    = { visible = false },
    }

    tbg_body    = make_fill(TARGET_W, TARGET_H,  8,  45,  82, 255, BAR_DIR .. 'bar_track.png')
    tfg_body    = make_fill(TARGET_IW, TARGET_IH, 226, 255, 255, 255, fill_path)
    tfgg_body   = make_fill(0,        TARGET_IH, 160,  70,  70, 200, fill_path)
    tbar_border = make_fill(TARGET_W, TARGET_H, 255, 255, 255, 255, BAR_DIR .. 'bar_frame.png')
    t_text      = texts.new(' ${hpp|(100)}%  ${name|(Name)}', text_cfg)

    tbg_body:draggable(false)
    tbar_border:size(TARGET_W, TARGET_H)

    local arrow_x = center_x + TARGET_W + 4
    local mtx = arrow_x + 22 + 4
    mt_arrow    = make_fill(ARROW_W, ARROW_H, 255, 255, 255, 255, BAR_DIR .. 'mob_arrow.png')
    mtbg_body   = make_fill(MOB_W, MOB_H,  8,  45,  82, 255, BAR_DIR .. 'bar_track.png')
    mtfg_body   = make_fill(MOB_IW, MOB_IH, 226, 255, 255, 255, fill_path)
    mtbar_border = make_fill(MOB_W, MOB_H, 255, 255, 255, 255, BAR_DIR .. 'bar_frame.png')
    mt_text     = texts.new('${name|(---)}', text_cfg)

    cbg_body    = make_fill(CAST_BAR_W, CAST_BAR_H, 20, 15, 0, 210, BAR_DIR .. 'bar_track.png')
    cfg_body    = make_fill(0, CAST_IH, 255, 255, 200, 255, fill_path)
    cbar_border = make_fill(CAST_BAR_W, CAST_BAR_H, 150, 110, 10, 255, BAR_DIR .. 'bar_frame.png')
    local cast_text_cfg = {
        pos   = { x = -300, y = -300 },
        text  = { size = scaled_font(), font = settings.font, fonts = {settings.font},
                  stroke = { width = 2, alpha = 200, red = 0, green = 0, blue = 0 } },
        flags = { bold = false, draggable = false, right = true },
        bg    = { visible = false },
    }
    c_text = texts.new('${v}', cast_text_cfg)
    c_text:color(255, 255, 200)
    c_text.v = ''
    c_text:hide()

    skillchain.init(settings)

    local function icon_cfg() return {
        pos = { x = -300, y = -300 }, visible = false,
        color = { alpha = 255, red = 255, green = 255, blue = 255 },
        size = { width = BUFF_ICON_SIZE, height = BUFF_ICON_SIZE },
        texture = { path = ICONS_PATH .. '0.png', fit = false },
        repeatable = { x = 1, y = 1 }, draggable = false,
    } end
    local tooltip_cfg = {
        pos = { x = -300, y = -300 },
        text = { size = 9, font = 'Constantia', stroke = { width = 2, alpha = 220, red = 0, green = 0, blue = 0 } },
        flags = { bold = false, draggable = false },
        bg = { visible = true, alpha = 210, red = 18, green = 8, blue = 28 },
        padding = 4,
    }
    local timer_text_cfg = {
        pos   = { x = -300, y = -300 },
        text  = { size = math.max(6, math.floor(7 * SCALE + 0.5)), font = 'Constantia', stroke = { width = 1, alpha = 200, red = 0, green = 0, blue = 0 } },
        flags = { bold = true, draggable = false },
        bg    = { visible = false },
    }
    buff_slots = {}
    for i = 1, BUFF_MAX_SLOTS do
        local icon = images.new(icon_cfg())
        icon:size(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
        icon:color(255, 255, 255)
        icon:hide()
        local timer_t = texts.new('${v}', timer_text_cfg)
        timer_t.v = ''
        timer_t:hide()
        buff_slots[i] = { icon = icon, timer_t = timer_t, current_path = nil, display_name = nil, display_desc = nil }
    end

    apply_position(center_x, ny, settings.font_size)

    eb_mob_targets = {}
    pet_targets    = {}
    player_targets = {}
    visible = false
    ready   = true
end

function targetbar.dispose()
    visible = false
    ready   = false
    if buff_tooltip then buff_tooltip:hide() end
    eb_mob_targets              = {}
    pet_targets                 = {}
    player_targets              = {}
    party_buffs                 = {}
    enemy_buffs                 = {}
    enemy_debuffs               = {}
    self_buffs                  = {}
    party_member_buff_expires   = {}
end

function targetbar.show()
    ready = true
end

function targetbar.hide()
    if not tbg_body then return end
    visible = false
    tbg_body:hide(); tfg_body:hide(); tfgg_body:hide(); tbar_border:hide(); t_text:hide()
    mt_arrow:hide(); mtbg_body:hide(); mtfg_body:hide(); mtbar_border:hide(); mt_text:hide()
    if cbg_body then cbg_body:hide() end
    if cfg_body then cfg_body:hide() end
    if cbar_border then cbar_border:hide() end
    if c_text then c_text:hide() end
    skillchain.hide()
    buff_strip_hide()
    ready = false
    ui_bounds.clear('targetbar')
    ui_bounds.clear('targetbar_sc')
end

function targetbar.push_bounds()
    if ready and visible and last_bar_x and last_bar_y then
        local x = last_bar_x
        local y = last_bar_y
        local w = TARGET_W + ARROW_GAP + ARROW_W + ARROW_GAP + MOB_W
        local h = TARGET_H + BUFF_Y_OFFSET + BUFF_ICON_SIZE + math.floor(12 * SCALE + 0.5)
        ui_bounds.register('targetbar', x, y, w, h)
    else
        ui_bounds.clear('targetbar')
    end
    local scx, scy, scw, sch = skillchain.bounds()
    if ready and scx then
        ui_bounds.register('targetbar_sc', scx, scy, scw, sch)
    else
        ui_bounds.clear('targetbar_sc')
    end
end

function targetbar.hud_preview(on)
    hud_preview_on = on and true or false
    if hud_preview_on then
        visible = true
    else
        visible = false
        last_target_id = nil
        local function h(o) if o then pcall(function() o:hide() end) end end
        h(tbg_body); h(tfg_body); h(tfgg_body); h(tbar_border); h(t_text)
        h(mt_arrow); h(mtbg_body); h(mtfg_body); h(mtbar_border); h(mt_text)
        h(cbg_body); h(cfg_body); h(cbar_border); h(c_text)
        pcall(buff_strip_hide)
        if skillchain and skillchain.hide then pcall(function() skillchain.hide() end) end
    end
end

function targetbar.on_prerender()
    if not ready then return end
    hud_preview_on = (_G.XIVUI_HUD_PREVIEW == true)
    _G.XIVUI_HUD_PREVIEW = false
    if hud_preview_on then visible = true end
    render_target()
end

function targetbar.on_target_change(index)
    visible = (index ~= 0)
    cast_cancel()
end

function targetbar.on_incoming_chunk(id, original)
    if id == 0x00D then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if ok and p then
            local idx   = p['Index']
            local t_idx = p['Target Index']
            if idx and t_idx then player_targets[idx] = t_idx end
        end
    elseif id == 0x028 then
        local ok, act = pcall(windower.packets.parse_action, original)
        if not ok or not act then return end
        local cat = act.category

        local first_t = act.targets and act.targets[1]
        if act.actor_id and first_t and first_t.id and first_t.id > 0 then
            eb_mob_targets[act.actor_id] = first_t.id
        end

        if act.targets then
            local spell_entry = _priv.spell(act.param)
            local ja_entry    = _priv.ability(act.param)
            local ws_entry    = _priv.weapon_skill(act.param)
            local act_entry   = (cat == 4 and spell_entry)
                             or ((cat == 6 or cat == 14) and ja_entry)
                             or (cat == 3 and ws_entry) or nil
            local act_friendly = actor_is_friendly(act.actor_id)

            for _, target_entry in ipairs(act.targets) do
                if target_entry.id and target_entry.actions and target_entry.actions[1] then
                    local msg    = target_entry.actions[1].message
                    local eparam = target_entry.actions[1].param
                    _debuff_applied = false

                    for _, sa in ipairs(target_entry.actions) do
                        if sa.message and shadow_tracker.ABSORB_MSGS[sa.message] then
                            shadow_tracker.on_absorb(target_entry.id)
                            break
                        end
                    end

                    if debuff_debug then
                        local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                        if tm and tm.is_npc and not tm.in_party then
                            local nm = (ja_entry and ja_entry.en) or (ws_entry and ws_entry.en)
                                       or (spell_entry and (spell_entry.en or spell_entry.name)) or '?'
                            for ai, ta in ipairs(target_entry.actions) do
                                log(('ddebug: cat=%s param=%s(%s) act#%d msg=%s prm=%s | add=%s ae_msg=%s ae_prm=%s')
                                    :format(tostring(cat), tostring(act.param), tostring(nm), ai,
                                            tostring(ta.message), tostring(ta.param),
                                            tostring(ta.has_add_effect), tostring(ta.add_effect_message), tostring(ta.add_effect_param)))
                            end
                        end
                    end

                    if act_friendly and act_entry and act_entry.status and act_entry.status > 0
                       and IS_DEBUFF[act_entry.status] and not NOLAND_MSGS[msg] then
                        local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                        if tm and tm.is_npc and not tm.in_party and not is_allied_mob(tm.id, tm.index) then
                            apply_enemy_debuff(target_entry.id, act_entry.status, act.param, act.actor_id, cat)
                        end
                    end

                    if cat == 6 and ja_entry and ja_entry.status and ja_entry.status > 0 then
                        local dur = ja_entry.duration or BUFF_STATUS_DURATION[ja_entry.status]
                        local expires = dur and dur > 0 and (os.clock() + dur) or nil
                        local status_id = ja_entry.status
                        if target_entry.id == player_id then
                            self_buffs[status_id] = { expires = expires, actor = act.actor_id }
                        else
                            local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                            if tm and tm.in_party and not tm.is_npc then
                                if not party_member_buff_expires[target_entry.id] then party_member_buff_expires[target_entry.id] = {} end
                                party_member_buff_expires[target_entry.id][status_id] = { expires = expires, actor = act.actor_id }
                            end
                        end
                    end

                    for _, tact in ipairs(target_entry.actions) do
                        local tmsg    = tact.message
                        local teparam = tact.param
                        if tmsg and BUFF_MSGS[tmsg] and teparam and teparam > 0 then
                            local dur = cat == 4 and (spell_entry and spell_entry.duration) or nil
                            if not dur then dur = BUFF_STATUS_DURATION[teparam] end
                            local expires = dur and dur > 0 and (os.clock() + dur) or nil
                            if shadow_tracker.is_shadow(teparam) then shadow_tracker.on_gain(target_entry.id, teparam) end

                            if target_entry.id == player_id then
                                self_buffs[teparam] = { expires = expires, actor = act.actor_id }
                            else
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm then
                                    if tm.is_npc and not tm.in_party then
                                        if not enemy_buffs[target_entry.id] then enemy_buffs[target_entry.id] = {} end
                                        apply_overwrite(target_entry.id, teparam)
                                        enemy_buffs[target_entry.id][teparam] = { expires = expires, actor = act.actor_id }
                                    elseif tm.in_party then
                                        if not party_member_buff_expires[target_entry.id] then party_member_buff_expires[target_entry.id] = {} end
                                        party_member_buff_expires[target_entry.id][teparam] = { expires = expires, actor = act.actor_id }
                                    end
                                end
                            end
                            break
                        end
                    end

                    if msg then

                        if cat == 4 and spell_entry then
                            if DEBUFF_MSGS[msg] and spell_entry.status and spell_entry.status > 0 then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party then
                                    apply_enemy_debuff(target_entry.id, spell_entry.status, act.param, act.actor_id, 4)
                                end
                            elseif RESIST_MSGS[msg] and spell_entry.status and spell_entry.status > 0 and spell_entry.status == eparam then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party then
                                    apply_enemy_debuff(target_entry.id, eparam, act.param, act.actor_id, 4)
                                end
                            end
                        elseif cat == 6 then
                            if DEBUFF_MSGS[msg] and ja_entry and ja_entry.status and ja_entry.status > 0 then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party then
                                    apply_enemy_debuff(target_entry.id, ja_entry.status, act.param, act.actor_id, 6)
                                end
                            elseif RESIST_MSGS[msg] and eparam and eparam > 0 then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party then
                                    apply_enemy_debuff(target_entry.id, eparam, act.param, act.actor_id, 6, ja_entry and ja_entry.en or nil)
                                end
                            end
                        else

                            if (RESIST_MSGS[msg] or DEBUFF_MSGS[msg]) and eparam and eparam > 0 then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party then
                                    apply_enemy_debuff(target_entry.id, eparam, act.param, act.actor_id, cat)
                                end
                            end
                        end

                        local a1    = target_entry.actions[1]
                        local aemsg = a1 and (a1.add_effect_message or (a1.add_effect and a1.add_effect.message))
                        local aeprm = a1 and (a1.add_effect_param   or (a1.add_effect and a1.add_effect.param))
                        local dbf
                        if STATUS_APPLY_MSGS[msg] and eparam and eparam > 0 then dbf = eparam
                        elseif (aemsg == 160 or aemsg == 164) and aeprm and aeprm > 0 then dbf = aeprm
                        elseif aemsg and SAMBA_DAZE[aemsg] then dbf = SAMBA_DAZE[aemsg] end
                        if dbf then
                            local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                            if tm and tm.is_npc and not tm.in_party then
                                apply_enemy_debuff(target_entry.id, dbf, act.param, act.actor_id, cat)
                            end
                        end

                        if (cat == 1 or cat == 3) and act_friendly and HIT_MSGS[msg] then
                            local sdaze = actor_samba_daze(act.actor_id)
                            if sdaze then
                                local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                                if tm and tm.is_npc and not tm.in_party and not is_allied_mob(tm.id, tm.index) then
                                    apply_enemy_debuff(target_entry.id, sdaze, act.param, act.actor_id, cat)
                                end
                            end
                        end
                    end

                    if not _debuff_applied and act_friendly and act.param and not NOLAND_MSGS[msg] then
                        local mm = (cat == 3 and MANUAL_WS) or ((cat == 6 or cat == 14) and MANUAL_JA)
                                or (cat == 4 and MANUAL_SP) or nil
                        local list = mm and mm[act.param]
                        if list then
                            local tm = windower.ffxi.get_mob_by_id(target_entry.id)
                            if tm and tm.is_npc and not tm.in_party and not is_allied_mob(tm.id, tm.index) then
                                for _, st_id in ipairs(list) do
                                    apply_enemy_debuff(target_entry.id, st_id, act.param, act.actor_id, cat)
                                end
                            end
                        end
                    end

                    if REMOVE_MSGS[msg] and eparam and eparam > 0 then
                        remove_enemy_status(target_entry.id, eparam, LEARN_MSGS[msg])
                    elseif DAMAGE_MSGS[msg] then
                        for _, sd in ipairs(BREAK_ON_DAMAGE) do remove_enemy_status(target_entry.id, sd) end
                    end
                end
            end
        end

        local target = windower.ffxi.get_mob_by_target('t')
        if not target or target.id == 0 then return end
        if act.actor_id ~= target.id then return end
        if cat == 8 then
            local t1a1 = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1]
            cast_start(act.actor_id, t1a1 and t1a1.param)
        elseif cat == 4 then
            cast_complete()
        elseif cat == 3 then
            cast_flash(act.actor_id, act.param, 'ws')
        elseif cat == 6 then
            cast_flash(act.actor_id, act.param, 'ja')
        elseif cat == 11 then
            cast_flash(act.actor_id, act.param, 'mob')
        end
    elseif id == 0x076 then
        for k = 0, 4 do
            local pid = original:unpack('I', k*48+5)
            if pid ~= 0 then
                local buffs = {}
                for i = 1, 32 do
                    local lo = original:byte(k*48+5+16+i-1)
                    local hi = math.floor(original:byte(k*48+5+8+math.floor((i-1)/4)) / (4^((i-1)%4))) % 4
                    local buff = lo + 256 * hi
                    if buff ~= 255 then buffs[i] = buff end
                end
                party_buffs[pid] = buffs
            end
        end
    elseif id == 0x068 then
        local ok, p = pcall(packets.parse, 'incoming', original)
        if ok and p then
            local pet_idx   = p['Pet Index']
            local target_id = p['Target ID']
            if pet_idx and pet_idx > 0 and target_id and target_id > 0 then
                local pet_mob = windower.ffxi.get_mob_by_index(pet_idx)
                if pet_mob and pet_mob.id and pet_mob.id > 0 then
                    pet_targets[pet_mob.id] = target_id
                end
            end
        end
    elseif id == 0x029 then
        local actor_id   = original:unpack('I', 0x05)
        local target_id  = original:unpack('I', 0x09)
        local param_1    = original:unpack('I', 0x0D)
        local message_id = original:unpack('H', 0x19) % 32768
        if cast_state.INTERRUPT_MSGS[message_id] and actor_id == cast_actor_id and cast.start_time then
            cast_interrupt()
        end
        if shadow_tracker.ABSORB_MSGS[message_id] then
            shadow_tracker.on_absorb(target_id)
        end
        if DEATH_MSGS[message_id] then
            enemy_debuffs[target_id] = nil
            enemy_buffs[target_id]   = nil
            shadow_tracker.clear(target_id)
        elseif REMOVE_MSGS[message_id] and param_1 and param_1 > 0 then
            remove_enemy_status(target_id, param_1, LEARN_MSGS[message_id])
        end
    end
end

function targetbar.on_zone_change()
    eb_mob_targets              = {}
    pet_targets                 = {}
    player_targets              = {}
    party_buffs                 = {}
    enemy_buffs                 = {}
    enemy_debuffs               = {}
    party_member_buff_expires   = {}
    allied_ids        = {}
    allied_indices    = {}
    allied_cache_time = 0
    cast_cancel()
end

function targetbar.on_login()
    local p = windower.ffxi.get_player()
    player_id = p and p.id or 0
    self_buffs        = {}
    allied_ids        = {}
    allied_indices    = {}
    allied_cache_time = 0
end

function targetbar.on_mouse(type, x, y, delta, blocked)
    if not ready then return false end
    local ux, uy = ui_bounds.to_ui(x, y)

    local wr = XIVUI_WEAK_RECT
    if wr and wr.active and ux >= wr.x and ux <= wr.x + wr.w and uy >= wr.y and uy <= wr.y + wr.h then
        return false
    end

    if type == 0 then
        if last_buff_bx then
            local icon_y = last_buff_by + TARGET_H + BUFF_Y_OFFSET
            for i = 1, BUFF_MAX_SLOTS do
                local s = buff_slots[i]
                if s.current_path then
                    local ix = last_buff_bx + (i - 1) * BUFF_ICON_STRIDE
                    if ux >= ix and ux <= ix + BUFF_ICON_SIZE and uy >= icon_y and uy <= icon_y + BUFF_ICON_SIZE then
                        local name = s.display_name or 'Unknown'
                        local desc = s.display_desc or ''
                        local txt = '\\cs(255,255,0)' .. name .. '\\cr'
                        if desc ~= '' then txt = txt .. '\n\\cs(228,228,228)' .. desc .. '\\cr' end
                        if not buff_tip_visible then
                            if buff_tooltip then buff_tooltip:dispose() end
                            buff_tooltip = tooltip_lib.new({ size = 8, pad = 5 })
                            buff_tip_visible = true
                        end
                        buff_tooltip:show(nil, txt, ux + 14, uy + 16)
                        return true
                    end
                end
            end
            if buff_tooltip then buff_tooltip:hide() end; buff_tip_visible = false
        end
        if is_bar_dragging then
            return true
        end
        if visible then
            local bx = tbg_body:pos_x()
            local by = tbg_body:pos_y()
            if ux >= bx and ux <= bx + TARGET_W and uy >= by - CLICK_PAD and uy <= by + TARGET_H + CLICK_PAD then
                return true
            end
            if mob_target_visible then
                local mtx = mtbg_body:pos_x()
                local mty = mtbg_body:pos_y()
                local font_sz = settings and settings.font_size or 10
                if ux >= (mtx - 30) and ux <= mtx + MOB_W and uy >= mty - (font_sz + 4) - CLICK_PAD and uy <= mty + MOB_H + CLICK_PAD then
                    return true
                end
            end
        end
    elseif type == 1 then
        local bx = tbg_body:pos_x()
        local by = tbg_body:pos_y()
        if ux >= bx and ux <= bx + TARGET_W and uy >= by - CLICK_PAD and uy <= by + TARGET_H + CLICK_PAD then
            is_bar_dragging = true
            bar_press_x = bx
            bar_press_y = by
            return true
        end
        if mob_target_visible then
            local mtx = mtbg_body:pos_x()
            local mty = mtbg_body:pos_y()
            local font_sz = settings and settings.font_size or 10
            if ux >= (mtx - 30) and ux <= mtx + MOB_W and uy >= mty - (font_sz + 4) - CLICK_PAD and uy <= mty + MOB_H + CLICK_PAD then
                mt_press_in_bar = true
                return true
            end
        end
    elseif type == 2 then
        if buff_tooltip then buff_tooltip:hide() end; buff_tip_visible = false
        if mt_press_in_bar then
            mt_press_in_bar = false
            if mob_target_visible then
                if not current_is_enemy then
                    windower.chat.input('/assist <t>')
                    if mob_target_index and mob_target_index > 0 then
                        targeting.target_index(mob_target_index, mob_target_name)
                    end
                elseif mob_target_name then
                    windower.chat.input('/target ' .. mob_target_name)
                    if mob_target_index and mob_target_index > 0 then
                        targeting.target_index(mob_target_index, mob_target_name)
                    elseif mob_target_id and mob_target_id > 0 then
                        targeting.target_id(mob_target_id, mob_target_name)
                    end
                elseif mob_target_index and mob_target_index > 0 then
                    targeting.target_index(mob_target_index, mob_target_name)
                elseif mob_target_id and mob_target_id > 0 then
                    targeting.target_id(mob_target_id, mob_target_name)
                end
                return true
            end
        end
        if is_bar_dragging then
            local bx = tbg_body:pos_x()
            local by = tbg_body:pos_y()
            local dragged = bar_press_x and (math.abs(bx - bar_press_x) > 3 or math.abs(by - bar_press_y) > 3)
            is_bar_dragging = false
            bar_press_x = nil
            bar_press_y = nil
            if not dragged then
                local target = windower.ffxi.get_mob_by_target('t')
                if target and target.index and target.index > 0 then
                    targeting.target_index(target.index, target.name)
                end
            end
            return true
        end
    end
    return false
end

function targetbar.handle_sc_command(args)
    if not settings then log('targetbar: not loaded — log in / enable it first.'); return end
    local a = args and args[1] and tostring(args[1]):lower() or 'toggle'
    if a == 'on' or a == 'show' then
        settings.sc_visible = true
    elseif a == 'off' or a == 'hide' then
        settings.sc_visible = false
    else
        settings.sc_visible = not settings.sc_visible
    end
    skillchain.on_toggle()
    config.save(settings)
    log('targetbar: skillchain display ' .. (settings.sc_visible and 'ON' or 'OFF'))
end

function targetbar.handle_command(args)
    if not settings then log('targetbar: not loaded — log in / enable it first.'); return end
    local cmd = args and args[1] and tostring(args[1]):lower() or ''
    if cmd == 'sc' then
        return targetbar.handle_sc_command({ table.unpack(args, 2) })
    elseif cmd == 'move' or cmd == 'reposition' then
        (_G.xivui_echo or log)('targetbar: use the HUD Layout editor (XivUI Menu) to move the target bar.')
    elseif cmd == 'pos' then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            move_to(x, y)
            config.save(settings)
            log('targetbar: moved to ' .. tostring(settings.pos.x) .. ', ' .. tostring(settings.pos.y) .. '.')
        else
            log('Usage: //xui target pos <x> <y>')
        end
    elseif cmd == 'scale' then
        local s = tonumber(args[2])
        if s then
            settings.scale = math.max(0.5, math.min(2.5, s))
            apply_scale(settings.scale)
            config.save(settings)
            log('targetbar: scale ' .. string.format('%.2f', settings.scale))
        else
            log('Usage: //xui target scale <0.5-2.5>  (or use the HUD Layout editor)')
        end
    elseif cmd == 'ddebug' then
        debuff_debug = not debuff_debug
        log('targetbar: debuff debug ' .. (debuff_debug and 'on — use a WS/JA/step/samba on an enemy and read the ddebug lines.' or 'off.'))
    elseif cmd == 'debug' then
        local t = windower.ffxi.get_mob_by_target('t')
        if not t or t.id == 0 then
            log('targetbar debug: no target. Target something and run again.')
        else
            local enemy = t.is_npc == true and t.in_party ~= true and not is_allied_mob(t.id, t.index)
            log(('targetbar debug: %s  -> %s'):format(tostring(t.name), visual_kind(t, enemy)))
            local keys = {}
            for k, v in pairs(t) do
                local tv = type(v)
                if tv ~= 'table' and tv ~= 'function' then keys[#keys + 1] = k end
            end
            table.sort(keys)
            local line = ''
            for _, k in ipairs(keys) do
                local piece = k .. '=' .. tostring(t[k]) .. '  '
                if #line + #piece > 110 then log('  ' .. line); line = '' end
                line = line .. piece
            end
            if line ~= '' then log('  ' .. line) end
        end
    else
        log('targetbar commands:')
        log('  sc [on|off] — toggle the skillchain display')
        log('  pos <x> <y> — set exact target bar position (or use HUD Layout)')
        log('  scale <0.5-2.5> — set target bar scale (or use HUD Layout)')
        log('  debug — print the current target\'s spawn_type / class (for color tuning)')
    end
end

return targetbar
