-- config_cats.lua: builds the Config tab's category data (cfg.cats).
local config = require('config')
local MD = require('components/xivuimenu/menudata')

return function(cfg, cfg_settings)
    if cfg.cats then return end
    local st = _G.XIVUI_STATE
    if not (st and st.components) then return end
    local function csettings(file)
        if cfg_settings[file] == nil then
            local def = {}
            local dm = MD.CFG_DEFMOD[file]
            if dm then local ok, d = pcall(require, dm); if ok and type(d) == 'table' then def = d end end
            local ok, s = pcall(config.load, file, def)
            cfg_settings[file] = (ok and type(s) == 'table') and s or {}
        end
        return cfg_settings[file]
    end
    local function getbool(file, path)
        local s = csettings(file)
        for i = 1, #path - 1 do s = s and s[path[i]] end
        local v = s and s[path[#path]]; return v == true or v == 'true'
    end
    local function getstr(file, path)
        local s = csettings(file)
        for i = 1, #path - 1 do s = s and s[path[i]] end
        return s and s[path[#path]]
    end
    local function setval(file, path, v)
        local s = csettings(file)
        for i = 1, #path - 1 do s[path[i]] = s[path[i]] or {}; s = s[path[i]] end
        s[path[#path]] = v
    end
    local function persist(file)
        local s = cfg_settings[file]
        if s then pcall(config.save, s) end
    end
    local function toggle(label, desc, file, path, cmd, words)
        words = words or { 'on', 'off' }
        return { kind = 'toggle', label = label, desc = desc or '',
            get = function() return getbool(file, path) end,
            set = function(v) setval(file, path, v); windower.send_command(cmd .. ' ' .. (v and words[1] or words[2])); persist(file) end }
    end
    local function choice(label, desc, file, path, cmd, options)
        return { kind = 'choice', label = label, desc = desc or '', options = options,
            get = function() return tostring(getstr(file, path) or options[1]) end,
            set = function(v) setval(file, path, v); windower.send_command(cmd .. ' ' .. v); persist(file) end }
    end
    local function choice_cmd(label, desc, cmd, options, default)
        local cur = default or options[1]
        return { kind = 'choice', label = label, desc = desc or '', options = options,
            get = function() return cur end,
            set = function(v) cur = v; windower.send_command(cmd .. ' ' .. v) end }
    end
    local function comp_toggle(cname, label, desc)
        local c
        for _, x in ipairs(st.components) do if x.name == cname then c = x; break end end
        return { kind = 'toggle', label = label, desc = desc or '',
            get = function() return c and c.enabled end,
            set = function(v) if c and st.set_enabled then st.set_enabled(cname, v) end end }
    end
    local comps = {}
    for _, c in ipairs(st.components) do
        if c.name ~= 'xivuimenu' and c.name ~= 'enemyweak' and c.name ~= 'enemyloot' then
            local info = MD.COMPONENT_INFO[c.name] or {}
            comps[#comps + 1] = { kind = 'toggle', label = info.l or c.name, desc = info.d or '',
                get = function() return c.enabled end,
                set = function(v)
                    if st.set_enabled then st.set_enabled(c.name, v) end
                    if c.name == 'dps' then windower.send_command('xui dps ' .. (v and 'show' or 'hide')) end
                end }
        end
    end
    local SB, TB, PT = 'data/statusbar/settings.xml', 'data/targetbar/settings.xml', 'data/xivparty/settings.xml'
    local DP, NT, CB = 'data/dps/settings.xml', 'data/notification/settings.xml', 'data/castbar/settings.xml'
    local EW = 'data/enemyweak/settings.xml'
    local TH = 'data/theme/settings.xml'
    local TF = { 'true', 'false' }
    local function button(label, desc, file, path, value, cmd)
        return { kind = 'button', label = label, desc = desc or '',
            active = function() return getstr(file, path) == value end,
            set = function() setval(file, path, value); windower.send_command(cmd); persist(file) end }
    end
    local hb_mod = require('components/xivhotbar3/xivhotbar3')
    local HB_STYLES = { 'xiv', 'compact', 'classic', 'minimal', 'transparent' }
    local hb_bars, hb_style, hb_behavior = {}, {}, {}
    local nbars = (hb_mod.hud_bar_count and hb_mod.hud_bar_count()) or 6
    for h = 1, nbars do
        local n = h
        hb_bars[#hb_bars + 1] = { kind = 'toggle', label = 'Bar ' .. n .. ' — Main', desc = 'Show in combat',
            get = function() return not (hb_mod.hud_bar_hidden and hb_mod.hud_bar_hidden('battle', n)) end,
            set = function(v) if hb_mod.hud_set_hidden then hb_mod.hud_set_hidden('battle', n, not v) end end }
    end
    for h = 1, nbars do
        local n = h
        hb_bars[#hb_bars + 1] = { kind = 'toggle', label = 'Bar ' .. n .. ' — Gen', desc = 'Out of combat',
            get = function() return not (hb_mod.hud_bar_hidden and hb_mod.hud_bar_hidden('field', n)) end,
            set = function(v) if hb_mod.hud_set_hidden then hb_mod.hud_set_hidden('field', n, not v) end end }
    end
    hb_style[#hb_style + 1] = { kind = 'choice', label = 'Style', desc = 'Slot look preset', options = HB_STYLES,
        get = function() return (hb_mod.hud_get_style and hb_mod.hud_get_style()) or HB_STYLES[1] end,
        set = function(v) if hb_mod.hud_set_style then hb_mod.hud_set_style(v) end end }
    hb_style[#hb_style + 1] = { kind = 'toggle', label = 'Show costs', desc = 'MP/TP, item & ammo counts',
        get = function() return hb_mod.hud_get_show_costs and hb_mod.hud_get_show_costs() end,
        set = function(v) if hb_mod.hud_set_show_costs then hb_mod.hud_set_show_costs(v) end end }
    hb_style[#hb_style + 1] = { kind = 'toggle', label = 'Empty slot frames', desc = 'Frame on empty slots',
        get = function() return hb_mod.hud_get_empty_frames and hb_mod.hud_get_empty_frames() end,
        set = function(v) if hb_mod.hud_set_empty_frames then hb_mod.hud_set_empty_frames(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Auto-pin ranged', desc = 'Show when ranged equipped',
        get = function() return hb_mod.hud_get_ranged_autopin and hb_mod.hud_get_ranged_autopin() end,
        set = function(v) if hb_mod.hud_set_ranged_autopin then hb_mod.hud_set_ranged_autopin(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Auto-equip ammo', desc = 'Re-equip when ammo runs out',
        get = function() return hb_mod.hud_get_auto_equip_ammo and hb_mod.hud_get_auto_equip_ammo() end,
        set = function(v) if hb_mod.hud_set_auto_equip_ammo then hb_mod.hud_set_auto_equip_ammo(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'choice', label = 'Ammo source', desc = 'Where to pull ammo from',
        options = { 'any', 'inventory', 'wardrobe1', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8' },
        get = function() return (hb_mod.hud_get_ammo_source and hb_mod.hud_get_ammo_source()) or 'any' end,
        set = function(v) if hb_mod.hud_set_ammo_source then hb_mod.hud_set_ammo_source(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'choice', label = 'Ranged type', desc = 'When auto-pinned', options = { 'auto', 'press' },
        get = function() return (hb_mod.hud_get_ranged_mode and hb_mod.hud_get_ranged_mode()) or 'auto' end,
        set = function(v) if hb_mod.hud_set_ranged_mode then hb_mod.hud_set_ranged_mode(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'choice', label = 'Auto-ranged in melee', desc = 'distance=out of range only, all=ranged after 1st melee, alternate=melee/ranged',
        options = { 'distance', 'all', 'alternate' },
        get = function() return (hb_mod.hud_get_autora_melee_mode and hb_mod.hud_get_autora_melee_mode()) or 'distance' end,
        set = function(v) if hb_mod.hud_set_autora_melee_mode then hb_mod.hud_set_autora_melee_mode(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Auto-collapse gaps', desc = 'Keep slots contiguous',
        get = function() return hb_mod.hud_get_collapse_gaps and hb_mod.hud_get_collapse_gaps() end,
        set = function(v) if hb_mod.hud_set_collapse_gaps then hb_mod.hud_set_collapse_gaps(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Autohide unusable', desc = 'Hide unlearned/low-level',
        get = function() return hb_mod.hud_get_autohide and hb_mod.hud_get_autohide() end,
        set = function(v) if hb_mod.hud_set_autohide then hb_mod.hud_set_autohide(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Auto switch to Gen', desc = 'When out of combat',
        get = function() return hb_mod.hud_auto_battle and hb_mod.hud_auto_battle() end,
        set = function(v) if hb_mod.hud_set_auto_battle then hb_mod.hud_set_auto_battle(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Job-specific positions', desc = 'Per-job layout',
        get = function() return hb_mod.hud_job_override and hb_mod.hud_job_override() end,
        set = function(v) if hb_mod.hud_set_job_override then hb_mod.hud_set_job_override(v) end end }
    hb_behavior[#hb_behavior + 1] = { kind = 'toggle', label = 'Sets grid', desc = '3x3 saved-set switcher',
        get = function() return hb_mod.hud_get_sets_visible and hb_mod.hud_get_sets_visible() end,
        set = function(v) if hb_mod.hud_set_sets_visible then hb_mod.hud_set_sets_visible(v) end end }

    local DIK_NAMES = {
        [1]='Esc', [2]='1', [3]='2', [4]='3', [5]='4', [6]='5', [7]='6', [8]='7', [9]='8', [10]='9', [11]='0',
        [12]='-', [13]='=', [14]='Backspace', [15]='Tab', [16]='Q', [17]='W', [18]='E', [19]='R', [20]='T',
        [21]='Y', [22]='U', [23]='I', [24]='O', [25]='P', [26]='[', [27]=']', [28]='Enter', [29]='LCtrl',
        [30]='A', [31]='S', [32]='D', [33]='F', [34]='G', [35]='H', [36]='J', [37]='K', [38]='L', [39]=';',
        [40]="'", [41]='`', [42]='LShift', [43]='\\', [44]='Z', [45]='X', [46]='C', [47]='V', [48]='B',
        [49]='N', [50]='M', [51]=',', [52]='.', [53]='/', [54]='RShift', [55]='Num*', [56]='LAlt', [57]='Space',
        [58]='CapsLock', [59]='F1', [60]='F2', [61]='F3', [62]='F4', [63]='F5', [64]='F6', [65]='F7', [66]='F8',
        [67]='F9', [68]='F10', [87]='F11', [88]='F12', [157]='RCtrl', [184]='RAlt',
    }
    local function key_label(dik, shift)
        return (shift and 'Shift+' or '') .. (DIK_NAMES[dik] or ('DIK ' .. tostring(dik)))
    end
    local controls = {
        { kind = 'keybind', label = 'Choice key', desc = 'Tap, then press a key',
            get = function()
                local dik = (hb_mod.hud_get_choice_key_dik and hb_mod.hud_get_choice_key_dik()) or 58
                return key_label(dik, hb_mod.hud_get_choice_key_shift and hb_mod.hud_get_choice_key_shift())
            end,
            set = function() cfg.capturing = true end },
        { kind = 'choice', label = 'Choice key mode', desc = 'How the key behaves', options = { 'toggle', 'hold', 'oneshot' },
            get = function() return (hb_mod.hud_get_choice_mode and hb_mod.hud_get_choice_mode()) or 'toggle' end,
            set = function(v) if hb_mod.hud_set_choice_mode then hb_mod.hud_set_choice_mode(v) end end },
    }

    local DPS_ROLES = { 'auto', 'tank', 'healer', 'support', 'dps' }
    local dps_roles = {}
    for s = 1, 6 do
        dps_roles[#dps_roles + 1] = choice_cmd('Slot ' .. s, 'Party member ' .. s, 'xui dps set ' .. s, DPS_ROLES)
    end

    cfg.cats = {
        { name = 'Components', desc = 'Show or hide each XivUI overlay. Click a switch to toggle it.', cols = 3, items = comps },
        { name = 'Theme', desc = 'Overall UI look: Pick a preset.', cols = 2, items = {
            button('FFXI', 'Classic FFXI look', TH, { 'Theme' }, 'ffxi', 'xui theme ffxi'),
            button('FFXIV', 'Modern FFXIV look', TH, { 'Theme' }, 'ffxiv', 'xui theme ffxiv') } },
        { name = 'Status Bar', desc = 'HP / MP / TP main bar.', items = {
            choice('Theme', 'Bar skin', SB, { 'Theme', 'Name' }, 'xui status theme', { 'ffxiv', 'ffxi', 'ffxiv-legacy' }),
            toggle('Compact bars', 'Smaller bar layout', SB, { 'Theme', 'Compact' }, 'xui status compact') } },
        { name = 'Target Bar', desc = 'Target HP bar + skillchain display.', items = {
            toggle('Skillchain display', 'Skillchain / magicburst readout', TB, { 'sc_visible' }, 'xui target sc') } },
        { name = 'Hotbar · Bars', desc = 'Which bars show, per job (Main = combat, Gen = out of combat).', items = hb_bars },
        { name = 'Hotbar · Style', desc = 'Slot look. Bar positions are dragged in HUD Layout.', items = hb_style },
        { name = 'Hotbar · Behavior', desc = 'Automation and slot behavior.', items = hb_behavior },
        { name = 'Controls', desc = 'Choice modifier key. Tap "Choice key", then press the key to bind.', items = controls },
        { name = 'Party List · Display', desc = 'Layout and interaction.', items = {
            choice_cmd('Layout', 'List layout preset', 'xui party layout', { 'xiv', 'xiv2', 'ffxi', 'ffxi2' }),
            choice_cmd('Alliance grid', 'Columns x rows for each alliance list (default = layout preset)', 'xui party alliancegrid', { 'default', '1x6', '2x3', '3x2', '2x4', '3x6' }),
            toggle('Click to target', 'Click a member to target them', PT, { 'mouseTargeting' }, 'xui party mousetargeting'),
            toggle('Wide single alliance', 'Use full width with one alliance', PT, { 'swapSingleAlliance' }, 'xui party swapsinglealliance'),
            toggle('Custom buff order', 'Sort buffs by bufforder.lua', PT, { 'customOrder' }, 'xui party customorder') } },
        { name = 'Party List · Hiding', desc = 'When the list hides itself.', items = {
            toggle('Hide when solo', 'Hide the list when not in a party', PT, { 'hideSolo' }, 'xui party hidesolo'),
            toggle('Hide alliance', 'Hide the other alliance parties', PT, { 'hideAlliance' }, 'xui party hidealliance'),
            toggle('Hide pets panel', 'Hide the pets subpanel', PT, { 'hidePets' }, 'xui party hidepets'),
            toggle('Hide in cutscene', 'Hide during cutscenes', PT, { 'hideCutscene' }, 'xui party hidecutscene') } },
        { name = 'DPS Parser · Display', desc = 'Panel look and extra rows.', items = {
            toggle('Background panel', 'Show the panel background', DP, { 'background' }, 'xui dps set background', TF),
            toggle('Separate skillchain', 'Skillchain damage on its own row', DP, { 'separatesc' }, 'xui dps set separatesc', TF),
            toggle('Separate magic burst', 'Magic burst damage on its own row', DP, { 'separatemb' }, 'xui dps set separatemb', TF) } },
        { name = 'DPS Parser · Tracking', desc = 'What gets counted.', items = {
            toggle('Auto reset', 'Reset the parse when a new fight starts', DP, { 'autoreset' }, 'xui dps set autoreset', TF),
            toggle('Track healing', 'Count cure / healing output', DP, { 'trackhealing' }, 'xui dps set trackhealing', TF),
            toggle('Track magic burst', 'Count magic burst damage', DP, { 'trackmagicburst' }, 'xui dps set trackmagicburst', TF),
            toggle('Combine pets', 'Add pet damage to its owner', DP, { 'combinepets' }, 'xui dps set combinepets', TF) } },
        { name = 'DPS Parser · Roles', desc = 'Bar color per party slot (auto = by job).', items = dps_roles },
        { name = 'Notifications', desc = 'Loot toast messages.', items = {
            toggle('Show party loot', 'Also show party members\' drops', NT, { 'show_party' }, 'xui notify party') } },
        { name = 'Cast Bar', desc = 'Spell cast + auto-attack bars.', items = {
            toggle('Cast bar', 'Spell cast bar', CB, { 'ShowCast' }, 'xui cast cast'),
            toggle('Swing timer', 'Melee auto-attack bar', CB, { 'ShowSwing' }, 'xui cast swing'),
            toggle('Swing/ranged text', 'Interval + multi-hit count on the auto-attack bars', CB, { 'ShowSwingText' }, 'xui cast swingtext'),
            toggle('Ranged timer', 'Ranged-attack bar', CB, { 'ShowRanged' }, 'xui cast ranged') } },
        { name = 'EXP Bar', desc = 'Experience bar readout.', items = {
            toggle('EXP/hr stats', 'Show EXP per hour', 'data/expbar/settings.xml', { 'Stats', 'Enable' }, 'xui exp stats') } },
        { name = 'Enemy Weakness', desc = '\\cs(232,170,90)[!] Community data; some entries could be incomplete or wrong. Toggle off to avoid bad info.\\cr', items = {
            comp_toggle('enemyweak', 'Weakness icons', 'Magnifier by enemy name'),
            toggle('Status ailments', 'Sleep/silence/etc. resist & immunity', EW, { 'show_status' }, 'xui weak status'),
            toggle('Always show', 'Keep expanded', EW, { 'always_show' }, 'xui weak always') } },
        { name = 'Enemy Drops', desc = '\\cs(232,170,90)[!] Community data; some entries could be incomplete or wrong; Caches your loot to fill gaps. Toggle off to avoid bad info.\\cr', items = {
            comp_toggle('enemyloot', 'Drop list', 'Bag below HP bar') } },
    }
end
