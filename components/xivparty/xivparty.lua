-- xivparty: party / alliance list.
-- XivUI component. Maintainer: maybeLynd. Version: 2.3.0.
-- Based on "XivParty" v2.2.0 by Tylas.

local socket  = require('socket')
local const   = require('components/xivparty/const')
local uiView  = require('components/xivparty/uiView')
local modelClass = require('components/xivparty/model')
local settingsClass = require('components/xivparty/settings')
local ui_bounds = require('lib/ui_bounds')
local cast_state = require('lib/cast_state')
local _ok_aggro, aggrolist_comp = pcall(require, 'components/aggrolist/aggrolist')
if not _ok_aggro then aggrolist_comp = nil end

local isInitialized     = false
local isZoning          = false
local waitingForZoneIn  = false
local lastFrameTimeMsec = 0

local view        = nil
local model       = nil
local setupModel  = nil
local isSetupEnabled = false
local hud_force_layout = 0

RefCountImage = 0
RefCountText  = 0

math.randomseed(os.time())

local PARTY_BOUND_ID = { [0] = 'xivparty_0', [1] = 'xivparty_1', [2] = 'xivparty_2', [3] = 'xivparty_3' }

local function isSolo(party)
    party = party or windower.ffxi.get_party()
    return party.party1_leader == nil
end

local function setSetupEnabled(enabled)
    isSetupEnabled = enabled
    if not setupModel then
        setupModel = modelClass.new()
        setupModel:createSetupData()
    end
    view:setModel(isSetupEnabled and setupModel or model)
    view:setUiLocked(not isSetupEnabled)
    if aggrolist_comp and aggrolist_comp.setSetupMode then
        aggrolist_comp.setSetupMode(enabled)
    end
end

local THEME_LAYOUT = { ffxi = 'ffxi', ffxiv10 = 'xiv', ffxiv = 'xiv' }
local function theme_layout()
    local ok, ts = pcall(require('config').load, 'data/theme/settings.xml', { Theme = 'ffxiv' })
    return THEME_LAYOUT[(ok and type(ts) == 'table' and ts.Theme) or 'ffxiv']
end

local xivparty = {}

local function findPetAsPrincipal(actorId)
    local partyData = windower.ffxi.get_party()
    for i = 0, 5 do
        local m = partyData['p' .. i]
        if m and m.mob and m.mob.id > 0 then
            local petIdx = m.mob.pet_index
            if petIdx and petIdx > 0 then
                local petMob = windower.ffxi.get_mob_by_index(petIdx)
                if petMob and petMob.id == actorId then return actorId end
            end
        end
    end
    return nil
end

local function findOwnerPetMobId(actorId)
    local partyData = windower.ffxi.get_party()
    for i = 0, 5 do
        local m = partyData['p' .. i]
        if m and m.mob and m.mob.id == actorId then
            local petIdx = m.mob.pet_index
            if petIdx and petIdx > 0 then
                local petMob = windower.ffxi.get_mob_by_index(petIdx)
                if petMob and petMob.id > 0 then return petMob.id end
            end
        end
    end
    return nil
end

function xivparty.init()
    if not isInitialized then
        model     = modelClass.new()
        Settings  = settingsClass.new(model)
        Settings:load()
        local lay = theme_layout()
        if lay and Settings.layout ~= lay then Settings.layout = lay; Settings:save() end
        view = uiView.new(model)
        isInitialized = true
    end
end

function xivparty.apply_theme(id)
    local lay = THEME_LAYOUT[id]
    if not lay or not Settings or Settings.layout == lay then return end
    Settings.layout = lay
    Settings:save()
    if view then view:reload() end
end

function xivparty.dispose()
    if isInitialized then
        if view then view:dispose() end
        view       = nil
        model      = nil
        setupModel = nil
        Settings   = nil
        isInitialized = false
        for i = 0, 3 do ui_bounds.clear(PARTY_BOUND_ID[i]) end
    end
end

function xivparty.push_bounds()
    if not isInitialized or not view then
        for i = 0, 3 do ui_bounds.clear(PARTY_BOUND_ID[i]) end
        return
    end
    for i = 0, 3 do
        local pl = view.partyLists and view.partyLists[i]
        if pl and pl.isEnabled then
            local ax, ay, w, h = pl:get_screen_bounds()
            if ax and w and w > 0 and h and h > 0 then
                ui_bounds.register(PARTY_BOUND_ID[i], ax, ay, w, h)
            else
                ui_bounds.clear(PARTY_BOUND_ID[i])
            end
        else
            ui_bounds.clear(PARTY_BOUND_ID[i])
        end
    end
end

function xivparty.show()
    if isInitialized and not isZoning then
        view:show(const.visZoning)
    end
end

function xivparty.hide()
    if isInitialized then
        view:hide(const.visZoning)
    end
    for i = 0, 3 do ui_bounds.clear(PARTY_BOUND_ID[i]) end
end

function xivparty.on_status_change(status)
    if isInitialized then
        view:visible(not Settings.hideCutscene or status ~= 4, const.visCutscene)
        if waitingForZoneIn and status ~= 4 then
            waitingForZoneIn = false
            view:show(const.visZoning)
        end
    end
end

function xivparty.on_prerender()
    if isZoning or not isInitialized then return end

    local timeMsec = socket.gettime() * 1000
    if timeMsec - lastFrameTimeMsec < Settings.updateIntervalMsec then return end
    lastFrameTimeMsec = timeMsec

    local party = windower.ffxi.get_party()
    local target = windower.ffxi.get_mob_by_target('t')
    local subtarget = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('stpt') or windower.ffxi.get_mob_by_target('stal')

    local P = _G.XIVUI_PERF
    if P and P.on then
        local pc = P.clock
        local t0 = pc(); Settings:update(); P.t['xp:settings'] = (P.t['xp:settings'] or 0) + (pc() - t0)
        t0 = pc(); model:updatePlayers(party, target, subtarget); model:updatePets(party, target); model:updateFellow()
        P.t['xp:model'] = (P.t['xp:model'] or 0) + (pc() - t0)
        t0 = pc()
        view:visible(isSetupEnabled or not Settings.hideSolo or not isSolo(party), const.visSolo)
        view:update()
        P.t['xp:view'] = (P.t['xp:view'] or 0) + (pc() - t0)
    else
        Settings:update()
        model:updatePlayers(party, target, subtarget)
        model:updatePets(party, target)
        model:updateFellow()
        view:visible(isSetupEnabled or not Settings.hideSolo or not isSolo(party), const.visSolo)
        view:update()
    end
    if hud_force_layout > 0 and isSetupEnabled then
        hud_force_layout = hud_force_layout - 1
        pcall(function()
            view:visible(false, const.visSolo)
            view:visible(true, const.visSolo)
        end)
        if view.layoutElement then pcall(function() view:layoutElement() end) end
    end
end

function xivparty.on_incoming_chunk(id, original)
    if id == 0x028 and isInitialized and model then
        local act = windower.packets.parse_action(original)
        if act and act.actor_id and act.actor_id > 0 then
            local cat = act.category
            if cat == 8 then
                local p = model:getPlayer(nil, act.actor_id, 'action', true)
                if p then

                    local t1a1 = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1]
                    local spellId = t1a1 and t1a1.param
                    p:startCast(spellId)
                end
            elseif cat == 4 then
                local p = model:getPlayer(nil, act.actor_id, 'action', true)
                if p then
                    local t1 = act.targets and act.targets[1]
                    local msg = t1 and t1.actions and t1.actions[1] and t1.actions[1].message

                    if cast_state.INTERRUPT_MSGS[msg] or msg == 28 then
                        p:interruptCast()
                    else
                        p:clearCast()
                    end
                end
            elseif cat == 3 then
                local p = model:getPlayer(nil, act.actor_id, 'action', true)
                if p then p:flashAbility(act.param, 'ws') end
            elseif cat == 6 then
                local p = model:getPlayer(nil, act.actor_id, 'action', true)
                if p then p:flashAbility(act.param, 'ja') end
            end

            local petMobId = findPetAsPrincipal(act.actor_id) or findOwnerPetMobId(act.actor_id)
            if petMobId then
                if cat == 8 then
                    local t1a1 = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1]
                    local spellId = t1a1 and t1a1.param
                    model:petStartCast(petMobId, spellId)
                elseif cat == 4 then
                    local t1  = act.targets and act.targets[1]
                    local msg = t1 and t1.actions and t1.actions[1] and t1.actions[1].message
                    local isInterrupted = cast_state.INTERRUPT_MSGS[msg] or msg == 28
                    local state = model.petCastStates[petMobId]
                    if state and state.castStartTimeSec then
                        if isInterrupted then
                            model:petInterruptCast(petMobId)
                        else
                            model:petClearCast(petMobId)
                        end
                    elseif not isInterrupted then

                        model:petFlashSpell(petMobId, act.param)
                    end
                elseif cat == 3 then
                    model:petFlashAbility(petMobId, act.param, 'ws')
                elseif cat == 6 then
                    model:petFlashAbility(petMobId, act.param, 'ja')
                elseif cat == 11 then
                    model:petFlashMobAbility(petMobId, act.param)
                end
            end
        end
    end

    if id == 0x029 and isInitialized and model then
        local message_id = original:unpack('H', 0x19) % 32768
        if cast_state.INTERRUPT_MSGS[message_id] then
            local actor_id = original:unpack('I', 0x05)
            if actor_id and actor_id > 0 then
                local p = model:getPlayer(nil, actor_id, 'interrupt', true)
                if p and p.castStartTimeSec then p:interruptCast() end
                local petMobId = findPetAsPrincipal(actor_id) or findOwnerPetMobId(actor_id)
                if petMobId then
                    local state = model.petCastStates and model.petCastStates[petMobId]
                    if state and state.castStartTimeSec then model:petInterruptCast(petMobId) end
                end
            end
        end
    end

    if id == 0xC8 then
        local packet = packets.parse('incoming', original)
        if packet then
            for i = 1, 18 do
                local playerId = packet['ID ' .. tostring(i)]
                local flags = packet['Flags ' .. tostring(i)]
                if flags and playerId and playerId > 0 then
                    local foundPlayer = model:getPlayer(nil, playerId, 'alliance')
                    foundPlayer:updateLeaderFromFlags(flags)
                end
            end
        end
    end

    if id == 0xDF then
        local packet = packets.parse('incoming', original)
        if packet then
            local playerId = packet['ID']
            if playerId and playerId > 0 then
                local foundPlayer = model:getPlayer(nil, playerId, 'char')
                foundPlayer:updateJobFromPacket(packet)
            end
        end
    end

    if id == 0xDD then
        local packet = packets.parse('incoming', original)
        if packet then
            local name = packet['Name']
            local playerId = packet['ID']
            if name and playerId and playerId > 0 then
                local foundPlayer = model:getPlayer(name, playerId, 'party')
                foundPlayer:updateJobFromPacket(packet)
            end
        end
    end

    if id == 0x067 or id == 0x068 then
        local packet = packets.parse('incoming', original)
        if packet then
            local msgType = packet['Message Type']
            local petIdx  = packet['Pet Index']
            local ownIdx  = packet['Owner Index']
            if msgType == 0x04 and id == 0x067 then
                petIdx, ownIdx = ownIdx, petIdx
            end
            if msgType == 0x04 and petIdx and petIdx > 0 then
                local tp = packet['Pet TP']
                if tp then model:cachePetTp(petIdx, tp) end
            end
        end
    end

    if id == 0x076 then
        for k = 0, 4 do
            local playerId = original:unpack('I', k*48+5)
            if playerId ~= 0 then
                local buffsList = {}
                for i = 1, const.maxBuffs do
                    local buff = original:byte(k*48+5+16+i-1) + 256*(math.floor(original:byte(k*48+5+8+math.floor((i-1)/4)) / 4^((i-1)%4))%4)
                    if buff == 255 then buff = nil end
                    buffsList[i] = buff
                end
                local foundPlayer = model:getPlayer(nil, playerId, 'buffs')
                foundPlayer:updateBuffs(buffsList)
            end
        end
    end

    if id == 0xB then
        isZoning = true
        if model then model:clear() end
        if isInitialized then view:hide(const.visZoning) end
    elseif id == 0xA and isZoning then
        isZoning = false
        if isInitialized then
            local player = windower.ffxi.get_player()
            if player and player.status ~= 4 then
                view:show(const.visZoning)
            else
                waitingForZoneIn = true
            end
        end
    end
end

function xivparty.on_keyboard(key, down)
    if Settings and Settings.hideKeyCode > 0 and key == Settings.hideKeyCode then
        view:visible(not down, const.visKeyboard)
        return true
    end
end

local function showHelp()
    log('Commands: //xui party or //xui party')
    log('filter - hides specified buffs in party list. Use command "buffs" to find out IDs.')
    log('   add <ID> - adds filter for a buff (e.g. //xui party filter add 123)')
    log('   remove <ID> - removes filter for a buff')
    log('   clear - removes all filters')
    log('   list - shows list of currently set filters')
    log('   mode - switches between blacklist and whitelist mode')
    log('buffs <name> - shows list of currently active buffs and their IDs for a party member')
    log('range - display party member distances as icons or numeric values')
    log('   <near> <far> - shows a marker for each party member closer than the set distances')
    log('   num - numeric display mode, disables near/far markers.')
    log('customOrder - toggles custom buff order (customize in bufforder.lua)')
    log('hideSolo - hides the UI while solo')
    log('hideAlliance - hides alliance party lists')
    log('hidePets - hides the pets panel')
    log('hideCutscene - hides the UI during cutscenes')
    log('mouseTargeting - toggles targeting party members using the mouse')
    log('swapSingleAlliance - shows single alliance in the 2nd alliance list')
    log('alliancegrid <cols>x<rows> - arrange each alliance list (e.g. 1x6, 2x4, 3x2; default = layout preset)')
    log('alignBottom - expands the party list from bottom to top')
    log('showEmptyRows - show empty rows in partially filled parties')
    log('job - toggles job specific settings for current job')
    log('pos [partyIndex] <x> <y> - set exact UI position (0 main, 1 alliance 1, 2 alliance 2, 3 pets); or use HUD Layout')
    log('layout <file> - loads a UI layout file')
end

local function handleCommand(currentValue, argsString, text, option1String, option1Value, option2String, option2Value, isNowText)
    isNowText = isNowText or 'is now'
    local setValue
    if argsString and string.lower(argsString) == option1String then
        setValue = option1Value
    elseif argsString and string.lower(argsString) == option2String then
        setValue = option2Value
    elseif not argsString or argsString == '' then
        setValue = (currentValue == option1Value) and option2Value or option1Value
    else
        error('Unknown parameter \'' .. argsString .. '\'.')
        return currentValue
    end
    local setString = (setValue == option2Value) and option2String or option1String
    log(text .. ' ' .. isNowText .. ' ' .. setString .. '.')
    return setValue
end

local function handleCommandOnOff(currentValue, argsString, text, plural)
    local isNowText = plural and 'are now' or nil
    return handleCommand(currentValue, argsString, text, 'on', true, 'off', false, isNowText)
end

local function handlePartySettingsOnOff(settingsName, argsString1, argsString2, text)
    local partyIndex = tonumber(argsString1)
    if partyIndex ~= nil then
        if partyIndex < 0 or partyIndex > 2 then
            error('Invalid party index \'' .. argsString1 .. '\'.')
        else
            local partySettings = Settings:getPartySettings(partyIndex)
            local ret = handleCommandOnOff(partySettings[settingsName], argsString2, text .. ' (' .. Settings:partyIndexToName(partyIndex) .. ')')
            partySettings[settingsName] = ret
            Settings:save()
        end
    else
        local ret = handleCommandOnOff(Settings.party[settingsName], argsString1, text)
        for i = 0, 2 do
            Settings:getPartySettings(i)[settingsName] = ret
        end
        Settings:save()
    end
end

local function checkBuff(buffId)
    if buffId and res.buffs[buffId] then return true
    elseif not buffId then error('Invalid buff ID.')
    else error('Buff with ID ' .. buffId .. ' not found.')
    end
    return false
end

local function getBuffText(buffId)
    local buffData = res.buffs[buffId]
    return buffData and (buffData.en .. ' (' .. buffData.id .. ')') or tostring(buffId)
end

local function getRange(arg)
    if not arg then return nil end
    local range = string.lower(arg)
    if range == 'off' then range = 0 else range = tonumber(range) end
    if not range then error('Invalid range \'' .. arg .. '\'.') end
    return range
end

function xivparty.handle_command(args)
    if not Settings then (_G.xivui_echo or log)('xivparty: not loaded — log in / enable it first.'); return end
    local command = args[1] and string.lower(args[1]) or nil

    if command == 'setup' or command == 'move' or command == 'reposition' then
        (_G.xivui_echo or log)('xivparty: use the HUD Layout editor (XivUI Menu) to move the party panels.')
    elseif command == 'pos' then
        local partyIndex, x, y
        if tonumber(args[2]) and tonumber(args[3]) and tonumber(args[4]) then
            partyIndex = tonumber(args[2])
            x = tonumber(args[3])
            y = tonumber(args[4])
        elseif tonumber(args[2]) and tonumber(args[3]) then
            partyIndex = 0
            x = tonumber(args[2])
            y = tonumber(args[3])
        end
        if partyIndex and x and y and partyIndex >= 0 and partyIndex <= 3 then
            Settings:setUiPosition(x, y, partyIndex)
            Settings:save()
            if view and view.partyLists and view.partyLists[partyIndex] then
                view.partyLists[partyIndex]:pos(x, y)
            end
            log(Settings:partyIndexToName(partyIndex) .. ' position: ' .. tostring(math.floor(x)) .. ', ' .. tostring(math.floor(y)))
        else
            log('Usage: //xui party pos [partyIndex] <x> <y>  (partyIndex: 0 main, 1 alliance 1, 2 alliance 2, 3 pets)')
        end
    elseif command == 'hidesolo' then
        local ret = handleCommandOnOff(Settings.hideSolo, args[2], 'Party list hiding while solo')
        Settings.hideSolo = ret
        Settings:save()
    elseif command == 'hidealliance' then
        local ret = handleCommandOnOff(Settings.hideAlliance, args[2], 'Alliance list hiding')
        Settings.hideAlliance = ret
        Settings:save()
        view:reload()
    elseif command == 'hidepets' then
        local ret = handleCommandOnOff(Settings.hidePets, args[2], 'Pets panel hiding')
        Settings.hidePets = ret
        Settings:save()
        view:reload()
    elseif command == 'hidecutscene' then
        local ret = handleCommandOnOff(Settings.hideCutscene, args[2], 'Party list hiding during cutscenes')
        Settings.hideCutscene = ret
        Settings:save()
    elseif command == 'mousetargeting' then
        local ret = handleCommandOnOff(Settings.mouseTargeting, args[2], 'Targeting party members using the mouse')
        Settings.mouseTargeting = ret
        Settings:save()
    elseif command == 'swapsinglealliance' then
        local ret = handleCommandOnOff(Settings.swapSingleAlliance, args[2], 'Swapping UI for single alliance')
        Settings.swapSingleAlliance = ret
        Settings:save()
    elseif command == 'alignbottom' then
        handlePartySettingsOnOff('alignBottom', args[2], args[3], 'Bottom alignment')
    elseif command == 'showemptyrows' then
        handlePartySettingsOnOff('showEmptyRows', args[2], args[3], 'Display of empty rows')
    elseif command == 'customorder' then
        local ret = handleCommandOnOff(Settings.buffs.customOrder, args[2], 'Custom buff order')
        Settings.buffs.customOrder = ret
        Settings:save()
        if setupModel then setupModel:refreshFilteredBuffs() end
        model:refreshFilteredBuffs()
    elseif command == 'range' then
        if args[2] then
            if args[2] == 'num' or args[2] == 'numeric' then
                Settings.rangeNumeric = true
                Settings.rangeIndicator = 0
                Settings.rangeIndicatorFar = 0
                Settings:save()
                log('Range numeric display mode enabled.')
            else
                local range1 = getRange(args[2])
                local range2 = getRange(args[3])
                if range1 then
                    Settings.rangeNumeric = false
                    Settings.rangeIndicator = range1
                    if range2 then
                        Settings.rangeIndicatorFar = range2
                        if Settings.rangeIndicator > Settings.rangeIndicatorFar then
                            Settings.rangeIndicator = range2
                            Settings.rangeIndicatorFar = range1
                        end
                        log('Range indicators set to near ' .. tostring(Settings.rangeIndicator) .. ', far ' .. tostring(Settings.rangeIndicatorFar) .. '.')
                    else
                        Settings.rangeIndicatorFar = 0
                        if range1 > 0 then
                            log('Range indicator set to ' .. tostring(Settings.rangeIndicator) .. '.')
                        else
                            log('Range indicator disabled.')
                        end
                    end
                    Settings:save()
                end
            end
        else
            showHelp()
        end
    elseif command == 'filter' or command == 'filters' then
        local subCommand = args[2] and string.lower(args[2]) or ''
        if subCommand == 'add' then
            local buffId = tonumber(args[3])
            if checkBuff(buffId) then
                Settings.buffFilters[buffId] = true
                Settings:save()
                if setupModel then setupModel:refreshFilteredBuffs() end
                model:refreshFilteredBuffs()
                log('Added buff filter for ' .. getBuffText(buffId))
            end
        elseif subCommand == 'remove' then
            local buffId = tonumber(args[3])
            if checkBuff(buffId) then
                Settings.buffFilters[buffId] = nil
                Settings:save()
                if setupModel then setupModel:refreshFilteredBuffs() end
                model:refreshFilteredBuffs()
                log('Removed buff filter for ' .. getBuffText(buffId))
            end
        elseif subCommand == 'clear' then
            Settings.buffFilters = T{}
            Settings:save()
            if setupModel then setupModel:refreshFilteredBuffs() end
            model:refreshFilteredBuffs()
            log('All buff filters cleared.')
        elseif subCommand == 'list' then
            log('Currently active buff filters (' .. Settings.buffs.filterMode .. '):')
            for buffId, doFilter in pairs(Settings.buffFilters) do
                if doFilter then log(getBuffText(buffId)) end
            end
        elseif subCommand == 'mode' then
            local ret = handleCommand(Settings.buffs.filterMode, args[3], 'Filter mode', 'blacklist', 'blacklist', 'whitelist', 'whitelist')
            Settings.buffs.filterMode = ret
            Settings:save()
            if setupModel then setupModel:refreshFilteredBuffs() end
            model:refreshFilteredBuffs()
        else
            showHelp()
        end
    elseif command == 'buffs' then
        local playerName = args[2]
        local buffs
        if playerName then
            playerName = playerName:ucfirst()
            local foundPlayer = model:findPlayer(playerName)
            if foundPlayer then
                buffs = foundPlayer.buffs
                log(playerName .. '\'s active buffs:')
            else
                error('Player ' .. playerName .. ' not found.')
                return
            end
        else
            buffs = windower.ffxi.get_player().buffs
            log('Your active buffs:')
        end
        for i = 1, const.maxBuffs do
            if buffs[i] then log(getBuffText(buffs[i])) end
        end
    elseif command == 'layout' then
        if args[2] then
            local layoutName = args[2]
            if layoutName:endswith(const.xmlExtension) then
                layoutName = layoutName:slice(1, #layoutName - #const.xmlExtension)
            end
            local filename = const.layoutDir .. layoutName .. const.xmlExtension
            if windower.file_exists(windower.addon_path .. filename) then
                log('Loading layout \'' .. layoutName .. '\'.')
                Settings.layout = layoutName
                Settings:save()
                view:reload()
            else
                error('The layout file \'' .. filename .. '\' does not exist!')
            end
        else
            showHelp()
        end
    elseif command == 'alliancegrid' then
        if args[2] then
            local arg = tostring(args[2]):lower()
            if arg == 'default' or arg == '0x0' or arg == '0' then
                Settings.allianceColumns = 0
                Settings.allianceRows = 0
                Settings:save()
                log('Alliance grid reset to the layout default.')
                if view then view:reload() end
            else
                local c, r = arg:match('^(%d+)[x%*](%d+)$')
                c, r = tonumber(c), tonumber(r)
                if c and r and c >= 1 and c <= 6 and r >= 1 and r <= 12 then
                    Settings.allianceColumns = c
                    Settings.allianceRows = r
                    Settings:save()
                    log('Alliance grid set to ' .. c .. 'x' .. r .. ' (default to reset).')
                    if view then view:reload() end
                else
                    log('Usage: //xui party alliancegrid <cols>x<rows>  (e.g. 1x6, 2x4, 3x2; or default to reset)')
                end
            end
        else
            showHelp()
        end
    elseif command == 'job' then
        local job = windower.ffxi.get_player().main_job
        local ret = handleCommandOnOff(Settings.jobEnabled, args[2], 'Job specific settings for ' .. job, true)
        if ret then
            if not Settings.jobEnabled then
                Settings:load(true, true)
                log('Settings changes to range and buffs will now only affect this job.')
            end
        elseif Settings.jobEnabled then
            Settings.jobEnabled = false
            Settings:save()
            Settings:load()
            log('Global settings applied.')
        end
    elseif command == 'debug' then
        local subCommand = string.lower(args[2])
        if subCommand == 'savelayout' then
            view:debugSaveLayout()
        elseif subCommand == 'refcount' then
            log('Images: ' .. RefCountImage .. ', Texts: ' .. RefCountText)
        elseif subCommand == 'setbar' and args[3] ~= nil and setupModel then
            setupModel:debugSetBarValue(args[3], tonumber(args[4]), tonumber(args[5]), tonumber(args[6]))
        elseif subCommand == 'addplayer' and setupModel then
            setupModel:debugAddSetupPlayer(tonumber(args[3]))
        elseif subCommand == 'testbuffs' then
            setupModel:debugTestBuffs()
            setupModel:refreshFilteredBuffs()
        end
    else
        showHelp()
    end
end

function xivparty.hud_panels()
    local out = {}
    if not Settings then return out end
    local labels = { [0] = 'Main Party', [1] = 'Alliance 1', [2] = 'Alliance 2', [3] = 'Pets' }
    local sizes  = { [0] = { 240, 180 }, [1] = { 200, 110 }, [2] = { 200, 110 }, [3] = { 180, 90 } }
    for idx = 0, 3 do
        local ok, pos = pcall(function() return Settings:getUiPosition(idx) end)
        if ok and pos then
            local pl = view and view.partyLists and view.partyLists[idx]
            local live = pl ~= nil
            local sc = (pl and pl.scaleX) or 1
            if sc <= 0 then sc = 1 end
            local x, y, w, h = pos.x, pos.y, nil, nil
            if pl and pl.get_screen_bounds then
                local bx, by, bw, bh = pl:get_screen_bounds()
                if bx and bw and bw > 0 and bh and bh > 0 then
                    x, y, w, h = bx, by, bw / sc, bh / sc
                end
            end
            if not w then local sz = sizes[idx]; w, h = sz[1], sz[2] end
            out[#out + 1] = { index = idx, label = labels[idx], x = x, y = y, w = w, h = h, visible = live, scale = sc }
        end
    end
    return out
end

local function panel_align_offset_y(pl)
    if pl and pl.boundsAlignY then
        return pl.boundsAlignY * ((pl.absoluteScale and pl.absoluteScale.y) or 1)
    end
    return 0
end

function xivparty.hud_move_panel(idx, x, y)
    if not Settings then return end
    local pl = view and view.partyLists and view.partyLists[idx]
    local px, py = x, y - panel_align_offset_y(pl)
    Settings:setUiPosition(px, py, idx)
    if Settings.save then Settings:save() end
    if pl then pl:pos(px, py) end
end

function xivparty.hud_get_panel_scale(idx)
    if view and view.partyLists and view.partyLists[idx] then return view.partyLists[idx].scaleX or 1 end
    return 1
end

function xivparty.hud_set_panel_scale(idx, f)
    if not (view and view.partyLists and view.partyLists[idx]) then return end
    f = math.max(0.25, math.min(3.0, tonumber(f) or 1))
    view.partyLists[idx]:scale(f, f)
    if Settings then
        Settings:setUiScale(f, f, idx)
        if Settings.save then Settings:save() end
    end
end

function xivparty.hud_preview(on)
    setSetupEnabled(on and true or false)
    if on and view then pcall(function() view:setUiLocked(true) end) end
    hud_force_layout = on and 4 or 0
end

return xivparty
