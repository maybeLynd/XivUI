local res    = require('resources')
local socket = require('socket')

local classes = require('components/xivparty/classes')
local player  = require('components/xivparty/player')
local utils   = require('components/xivparty/utils')
local const   = require('components/xivparty/const')

local _priv = require('lib/priv_res')

local ABILITY_FLASH_SECS = 1.5

local cast_state = require('lib/cast_state')

local function getCastProgressFromState(state)
    if not state then return nil end
    if state.castInterruptStart then
        local ph = cast_state.blink_phase(state.castInterruptStart)
        if ph == 'done' then
            state.castInterruptStart = nil
            state.castInterruptProg = nil
            return nil
        end
        if ph == 'on' then return state.castInterruptProg or 1 end
        return nil
    end
    if state.castFlashEnd then
        if socket.gettime() < state.castFlashEnd then return 1 end
        state.castFlashEnd  = nil
        state.castSpellName = nil
        return nil
    end
    if state.castClearTimeSec then
        if socket.gettime() - state.castClearTimeSec < 0.15 then return 1 end
        state.castClearTimeSec = nil
        return nil
    end
    if not state.castStartTimeSec or not state.castDuration or state.castDuration <= 0 then return nil end
    local elapsed = socket.gettime() - state.castStartTimeSec
    if elapsed >= state.castDuration then
        if elapsed < state.castDuration + 12 then
            return 0.99
        end
        state.castClearTimeSec  = socket.gettime()
        state.castStartTimeSec  = nil
        state.castDuration      = nil
        state.castSpellId       = nil
        return 1
    end
    return elapsed / state.castDuration
end

local model = classes.class()

local partyKeys = { 'p%i', 'a1%i', 'a2%i' }

local function createPetPlayer(petMob, ownerName, target, tpCache, hasMp, castState)
    local p = {}
    p.name = petMob.name or 'Pet'
    local hpp = petMob.hpp or 0
    p.hp = (petMob.hp and petMob.hp > 0) and petMob.hp or math.floor(hpp)
    p.hpp = hpp
    local mpp = petMob.mpp or 0
    p.mp = (petMob.mp and petMob.mp > 0) and petMob.mp or nil
    p.mpp = mpp
    local rawTp = (tpCache and tpCache[petMob.index]) or ((petMob.tp and petMob.tp > 0) and petMob.tp) or nil
    p.tp = rawTp
    p.tpp = rawTp and math.min(rawTp / 10, 100) or 0
    p.zone = windower.ffxi.get_info().zone
    p.isOutsideZone = false
    p.distance = nil
    p.isInCastingRange = true
    p.isInTargetingRange = true
    p.isTrust = false
    p.isSelected = target and (target.id == petMob.id) or false
    p.isSubTarget = false
    p.isMainPlayer = false
    p.isLeader = false
    p.isAllianceLeader = false
    p.isQuarterMaster = false
    p.job = nil
    p.jobLvl = nil
    p.subJob = nil
    p.subJobLvl = nil
    p.buffs = {}
    p.filteredBuffs = T{}
    p.ownerName = ownerName
    p.mobIndex  = petMob.index
    p.hasMp = hasMp
    local cs = castState
    p.getCastProgress = function() return getCastProgressFromState(cs) end
    p.isCastInterrupt = function() return cs and cs.castInterruptStart ~= nil end
    p.castSpellName   = cs and cs.castSpellName or nil
    return p
end

function model:init()

    self.allPlayers = T{}

    self.parties = T{}
    for i = 0, 2 do
        self.parties[i] = T{}
    end
    self.parties[3] = T{}
    self.petTpCache     = {}
    self.petHasMpCache  = {}
    self.petCastStates  = {}
end

function model:dispose()
    self:clear()
end

function model:clear()
    self.allPlayers:clear()

    for i = 0, 3 do
        self.parties[i]:clear()
    end

    self.petTpCache    = {}
    self.petHasMpCache = {}
    self.petCastStates = {}
end

function model:cachePetTp(petIndex, tp)
    self.petTpCache[petIndex] = tp
end

function model:petStartCast(mobId, spellId)
    if not self.petCastStates[mobId] then self.petCastStates[mobId] = {} end
    local state = self.petCastStates[mobId]
    if state.castStartTimeSec then
        state.castStartTimeSec = nil; state.castDuration = nil; state.castSpellId = nil
        state.castSpellName = nil; state.castClearTimeSec = nil; state.castFlashEnd = nil
    end
    local spell = _priv.spell(spellId)
    state.castStartTimeSec = socket.gettime()
    state.castSpellId      = spellId
    state.castDuration     = (state.castTimeCalib and state.castTimeCalib[spellId]) or (spell and spell.cast_time or 3)
    state.castClearTimeSec = nil
    state.castFlashEnd     = nil
    state.castInterruptStart = nil
    state.castSpellName    = (spell and spell.en) or '...'
end

function model:petInterruptCast(mobId)
    local state = self.petCastStates[mobId]
    if not state then return end
    state.castInterruptProg  = math.max(0.06, getCastProgressFromState(state) or 1)
    state.castInterruptStart = socket.gettime()
    state.castStartTimeSec = nil; state.castDuration = nil; state.castSpellId = nil
    state.castClearTimeSec = nil; state.castFlashEnd = nil; state.castSpellName = nil
end

function model:petClearCast(mobId)
    local state = self.petCastStates[mobId]
    if not state then return end
    if state.castStartTimeSec and state.castSpellId then
        local actual   = socket.gettime() - state.castStartTimeSec
        local expected = state.castDuration or 3
        if actual >= 0.1 and actual <= expected * 2.5 then
            if not state.castTimeCalib then state.castTimeCalib = {} end
            local prev = state.castTimeCalib[state.castSpellId]
            state.castTimeCalib[state.castSpellId] = prev and (prev * 0.7 + actual * 0.3) or actual
        end
    end
    if state.castStartTimeSec then state.castClearTimeSec = socket.gettime() end
    state.castStartTimeSec = nil
    state.castDuration     = nil
    state.castSpellId      = nil
    state.castFlashEnd     = nil
end

function model:petCancelCast(mobId)
    local state = self.petCastStates[mobId]
    if not state then return end
    state.castStartTimeSec = nil; state.castDuration    = nil; state.castSpellId   = nil
    state.castSpellName    = nil; state.castClearTimeSec = nil; state.castFlashEnd = nil
    state.castInterruptStart = nil
end

function model:petFlashAbility(mobId, actionId, actionType)
    if not self.petCastStates[mobId] then self.petCastStates[mobId] = {} end
    local state = self.petCastStates[mobId]
    if state.castStartTimeSec then return end
    local entry
    if actionType == 'ws' then
        entry = _priv.weapon_skill(actionId)
    else
        entry = _priv.ability(actionId)
    end
    if not entry then return end
    state.castSpellName    = entry.en
    state.castFlashEnd     = socket.gettime() + ABILITY_FLASH_SECS
    state.castStartTimeSec = nil; state.castDuration    = nil
    state.castClearTimeSec = nil; state.castSpellId     = nil
end

function model:petFlashSpell(mobId, spellId)
    if not self.petCastStates[mobId] then self.petCastStates[mobId] = {} end
    local state = self.petCastStates[mobId]
    if state.castStartTimeSec then return end
    local spell = _priv.spell(spellId)
    if not spell then return end
    state.castSpellName    = spell.en
    state.castFlashEnd     = socket.gettime() + ABILITY_FLASH_SECS
    state.castStartTimeSec = nil; state.castDuration    = nil
    state.castClearTimeSec = nil; state.castSpellId     = nil
end

function model:petFlashMobAbility(mobId, actionId)
    if not self.petCastStates[mobId] then self.petCastStates[mobId] = {} end
    local state = self.petCastStates[mobId]
    if state.castStartTimeSec then return end
    local entry = res.monster_abilities and res.monster_abilities[actionId]
    state.castSpellName    = entry and entry.en or '...'
    state.castFlashEnd     = socket.gettime() + ABILITY_FLASH_SECS
    state.castStartTimeSec = nil; state.castDuration    = nil
    state.castClearTimeSec = nil; state.castSpellId     = nil
end

function model:updatePlayers(members, target, subtarget)
    members = T(members or windower.ffxi.get_party())
    if target == nil then target = windower.ffxi.get_mob_by_target('t') end
    if subtarget == nil then
        subtarget = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('stpt') or windower.ffxi.get_mob_by_target('stal')
    end

    for i = 0, 17 do
        local idx = (i / 6):floor()
        local member = members[string.format(partyKeys[idx + 1], i % 6)]

        if member and member.name then
            local id
            if member.mob and member.mob.id > 0 then
                id = member.mob.id
            end

            local foundPlayer = self:getPlayer(member.name, id, 'member')
            if foundPlayer then
                foundPlayer:update(member, target, subtarget)
            end

            self.parties[idx][i % 6] = foundPlayer
        else
            self.parties[idx][i % 6] = nil
        end
    end
end

function model:getPlayer(name, id, debugTag, dontCreate)
    local foundPlayer
    local foundByName
    local foundById

    if not name and not id then
        utils:log('Attempted a player lookup without name and ID.', 4)
        return nil
    end

    for ap in self.allPlayers:it() do
        if name and ap.name == name then
            foundByName = ap
        end
        if id and ap.id == id then
            foundById = ap
        end
    end

    if foundByName and foundById and foundByName ~= foundById then

        if foundByName.id ~= nil and foundById.id ~= nil and foundByName.id > 0 and foundById.id > 0 and foundByName.id ~= foundById.id then
            utils:log('ID conflict finding player, returning player with higher ID.', 2)

            if foundByName.id > foundById.id then
                foundPlayer = foundByName
                self.allPlayers:delete(foundById)
            else
                foundPlayer = foundById
                self.allPlayers:delete(foundByName)
            end
        else
            foundPlayer = foundByName:merge(foundById)
            self.allPlayers:delete(foundById)
        end
    else
        if foundByName then
            foundPlayer = foundByName
        else
            foundPlayer = foundById
        end

        if not foundPlayer and not dontCreate then
            utils:log('Creating new player (' .. debugTag .. ')', 2)
            foundPlayer = player.new(name, id, self)
            self.allPlayers:append(foundPlayer)
        end
    end

    return foundPlayer
end

function model:findPlayer(name)
    return self:getPlayer(name, nil, 'findPlayer', true)
end

function model:findPartyLeader(partyIndex)
    if not partyIndex then partyIndex = 0 end

    for p in self.parties[partyIndex]:it() do
        if p.isLeader then
            return p
        end
    end

    return nil
end

function model:updatePets(partyData, target)
    self.parties[3] = T{}

    if target == nil then target = windower.ffxi.get_mob_by_target('t') end
    partyData = partyData or windower.ffxi.get_party()
    local slotIdx = 0

    for i = 0, 5 do
        local member = partyData[string.format(partyKeys[1], i)]
        if member and member.name and member.mob and member.mob.id > 0 then
            local petIdx = member.mob.pet_index
            if petIdx and petIdx > 0 then
                local petMob = windower.ffxi.get_mob_by_index(petIdx)
                if petMob and petMob.id > 0 and petMob.hpp > 0 then
                    if (petMob.mpp and petMob.mpp > 0) or (petMob.mp and petMob.mp > 0) then
                        self.petHasMpCache[petIdx] = true
                    elseif self.petHasMpCache[petIdx] == nil then
                        self.petHasMpCache[petIdx] = false
                    end
                    if not self.petCastStates[petMob.id] then self.petCastStates[petMob.id] = {} end
                    self.parties[3][slotIdx] = createPetPlayer(petMob, member.name, target, self.petTpCache, self.petHasMpCache[petIdx], self.petCastStates[petMob.id])
                    slotIdx = slotIdx + 1
                end
            end
        end
    end

end

function model:updateFellow()
    for i = 0, 5 do
        if self.parties[0][i] and self.parties[0][i].isFellow then
            self.parties[0][i] = nil
        end
    end

    local fellow = windower.ffxi.get_mob_by_target('ft')
    if not fellow or fellow.id == 0 or fellow.hpp == 0 then return end

    for i = 0, 5 do
        local p = self.parties[0][i]
        if p and p.id and p.id == fellow.id then return end
    end

    local target = windower.ffxi.get_mob_by_target('t')
    local fellowHasMp = (fellow.mpp and fellow.mpp > 0) or (fellow.mp and fellow.mp > 0)
    local mainPlayer = windower.ffxi.get_player()
    local ownerName = mainPlayer and mainPlayer.name or nil

    local fellowPlayer = createPetPlayer(fellow, ownerName, target, self.petTpCache, fellowHasMp)
    fellowPlayer.isFellow = true

    for i = 0, 5 do
        if not self.parties[0][i] then
            self.parties[0][i] = fellowPlayer
            return
        end
    end
end

function model:refreshFilteredBuffs()
    for p in self.parties[0]:it() do
        p:refreshFilteredBuffs()
    end
end

function model:hasAlliance2Members()
    return self.parties[2]:length() > 0
end

function model:createSetupData()
    local petNames = { 'Carbuncle', 'Fenrir', 'Wyvern', 'Harlequin', 'Falcorr' }
    local ownerNames = { 'Player1', 'Player2', 'Player3', 'Player4', 'Player5' }
    self.parties[3] = T{}
    for i = 0, 2 do
        local p = createPetPlayer({ name = petNames[i + 1] or 'Pet', id = i + 1, hp = nil, hpp = math.random(20, 100), mp = nil, mpp = math.random(0, 100) }, ownerNames[i + 1] or 'Owner', nil)
        self.parties[3][i] = p
    end

    for partyIndex = 0, 2 do
        for i = 0, 5 do
            local j = res.jobs[math.random(1,22)].ens
            local sj = res.jobs[math.random(1,22)].ens

            local setupPlayer = player.new('Player' .. tostring(i + 1), (i + 1), nil)
            setupPlayer:createSetupData(j, sj, partyIndex == 0)
            self.parties[partyIndex][i] = setupPlayer
        end

        self.parties[partyIndex][0].isLeader = true
        self.parties[partyIndex][0].isAllianceLeader = true
        self.parties[partyIndex][0].isQuarterMaster = true

        self.parties[partyIndex][math.random(0,2)].isSelected = true

        local zone = windower.ffxi.get_info().zone
        if zone == 0 then
            zone = zone + 1
        else
            zone = zone - 1
        end
        local outsideZonePlayer = self.parties[partyIndex][math.random(3,5)]
        outsideZonePlayer.zone = zone
        outsideZonePlayer.isOutsideZone = true
    end
end

function model:debugSetBarValue(type, value, partyIndex, playerIndex)
    if value == nil then value = 0 end
    if partyIndex == nil then partyIndex = 0 end
    if playerIndex == nil then playerIndex = 0 end

    if type == 'tpp' then
        self.parties[partyIndex][playerIndex].tpp = value
    elseif type == 'mpp' then
        self.parties[partyIndex][playerIndex].mpp = value
    else
        self.parties[partyIndex][playerIndex].hpp = value
    end
end

function model:debugAddSetupPlayer(partyIndex)
    if not partyIndex then partyIndex = 0 end

    local setupParty = self.parties[partyIndex]
    local i = setupParty:length()

    if i > 5 then error('Cannot add setup player, party full!') return end

    local j = res.jobs[math.random(1,22)].ens
    local sj = res.jobs[math.random(1,22)].ens

    local setupPlayer = player.new('Player' .. tostring(i + 1), (i + 1), nil)
    setupPlayer:createSetupData(j, sj, partyIndex == 0)
    setupParty[i] = setupPlayer
end

function model:debugTestBuffs()
    for p = 0, 5 do
        local setupParty = self.parties[0]

        local cutoff = math.random(1, 32)
        for i = 1, 32 do
            local buff = nil
            if i < cutoff then
                buff = math.random(1, 631)
            end
            setupParty[p].buffs[i] = buff
        end
    end
end

return model
