local res = require('resources')
local socket = require('socket')

local _priv = require('lib/priv_res')

local ABILITY_FLASH_SECS = 1.5

local cast_state = require('lib/cast_state')
local shadow_tracker = require('lib/shadow_tracker')

local classes = require('components/xivparty/classes')
local jobs = require('components/xivparty/jobs')
local buffOrder = require('components/xivparty/bufforder')
local const= require('components/xivparty/const')
local utils = require('components/xivparty/utils')

local player = classes.class()

function player:init(name, id, model)
    if not name and not id then
        utils:log('player:init missing parameter name or id!', 4)
        return
    end

    local initText = ''
    if name then
        initText = initText .. '. Name = ' .. name
    end
    if id then
        initText = initText .. '. ID = ' .. tostring(id)
    end
    utils:log('Initializing player' .. initText, 2)

    self.name = name
    self.id = id
    self.model = model
end

function player:merge(other)
    utils:log('Merging player ' .. utils:toString(other.name) .. '(' .. utils:toString(other.id) .. ')' ..
              ' into ' .. utils:toString(self.name) .. '(' .. utils:toString(self.id) .. ')', 2)

    if other.name ~= nil then self.name = other.name end
    if other.id ~= nil and other.id > 0 then self.id = other.id end

    if other.hp ~= nil then self.hp = other.hp end
    if other.mp ~= nil then self.mp = other.mp end
    if other.tp ~= nil then self.tp = other.tp end
    if other.hpp ~= nil then self.hpp = other.hpp end
    if other.mpp ~= nil then self.mpp = other.mpp end
    if other.tpp ~= nil then self.tpp = other.tpp end

    if other.isSelected ~= nil then self.isSelected = other.isSelected end
    if other.isSubTarget ~= nil then self.isSubTarget = other.isSubTarget end
    if other.distance ~= nil then self.distance = other.distance end
    if other.zone ~= nil then self.zone = other.zone end
    if other.isOutsideZone ~= nil then self.isOutsideZone = other.isOutsideZone end
    if other.isInCastingRange ~= nil then self.isInCastingRange = other.isInCastingRange end
    if other.isInTargetingRange ~= nil then self.isInTargetingRange = other.isInTargetingRange end

    if other.isTrust ~= nil then self.isTrust = other.isTrust end

    if other.job ~= nil then self.job = other.job end
    if other.jobLvl ~= nil then self.jobLvl = other.jobLvl end
    if other.subJob ~= nil then self.subJob = other.subJob end
    if other.subJobLvl ~= nil then self.subJobLvl = other.subJobLvl end

    if other.buffs ~= nil then self.buffs = other.buffs end
    if other.filteredBuffs ~= nil then self.filteredBuffs = other.filteredBuffs end

    if other.isLeader ~= nil then self.isLeader = other.isLeader end
    if other.isAllianceLeader ~= nil then self.isAllianceLeader = other.isAllianceLeader end
    if other.isQuarterMaster ~= nil then self.isQuarterMaster = other.isQuarterMaster end

    return self
end

function player:update(member, target, subtarget)
    self.name = member.name

    self.hp = member.hp
    self.mp = member.mp
    self.tp = member.tp
    self.hpp = member.hpp
    self.mpp = member.mpp
    self.tpp = math.min(member.tp / 10, 100)

    self.zone = member.zone
    self.isOutsideZone = self.zone and self.zone ~= windower.ffxi.get_info().zone

    self.distance = nil

    if member.mob then
        self.id = member.mob.id
        self.isTrust = member.mob.is_npc

        if member.mob.distance then
            self.distance = member.mob.distance:sqrt()
        end

        if self.isTrust and (self.job == nil or self.jobLvl == nil or self.jobLvl == 0) then
            local trustInfo = jobs:getTrustInfo(self.name, member.mob.models[1])
            if trustInfo then
                self.job = trustInfo.job
                self.subJob = trustInfo.subJob

                if self.model then
                    local partyLeader = self.model:findPartyLeader()
                    if partyLeader and partyLeader.jobLvl then
                        self.jobLvl = partyLeader.jobLvl
                        self.subJobLvl = math.max(1, math.floor(partyLeader.jobLvl / 2))
                    end
                end
            end
        end
    end

    self.isSelected = target and target.id == self.id
    self.isSubTarget = subtarget and subtarget.id == self.id

    self.isInCastingRange = self.distance and self.distance < const.castRange
    self.isInTargetingRange = self.distance and self.distance < const.targetRange
    if self.isTrust and not self.isInTargetingRange then
        self.isInTargetingRange = true
    end

    local mainPlayer = windower.ffxi.get_player()
    self.isMainPlayer = self.name == mainPlayer.name

    if self.isMainPlayer then
        self:updateBuffs(mainPlayer.buffs)
        self.job = res.jobs[mainPlayer.main_job_id].ens
        self.jobLvl = mainPlayer.main_job_level

        if mainPlayer.sub_job_id then
            self.subJob = res.jobs[mainPlayer.sub_job_id].ens
            self.subJobLvl = mainPlayer.sub_job_level
        end
    end
end

local function buffOrderCompare(a, b)
    local orderA = buffOrder[a]
    local orderB = buffOrder[b]

    if not orderA then
        return false
    elseif not orderB then
        return true
    end

    return buffOrder[a] < buffOrder[b]
end

function player:updateBuffs(buffs)
    self.buffs = buffs
    self.filteredBuffs = T{}

    if not buffs then return end

    local shadows_gone = self.id and shadow_tracker.is_depleted(self.id)
    for i = 1, const.maxBuffs do
        local buff = buffs[i]

        if (Settings.buffs.filterMode == 'blacklist' and Settings.buffFilters[buff]) or
           (Settings.buffs.filterMode == 'whitelist' and not Settings.buffFilters[buff]) then
            buff = nil
        end

        if buff and shadows_gone and shadow_tracker.is_shadow(buff) then
            buff = nil
        end

        if buff then
            self.filteredBuffs:append(buff)
        end
    end

    if Settings.buffs.customOrder then
        self.filteredBuffs:sort(buffOrderCompare)
    else
        self.filteredBuffs:sort()
    end
end

function player:refreshFilteredBuffs()
    self:updateBuffs(self.buffs)
end

function player:startCast(spellId)
    if self.castStartTimeSec then

        self:cancelCast()
    end
    local spell = _priv.spell(spellId)
    local baseTime = spell and spell.cast_time or 3
    self.castStartTimeSec = socket.gettime()
    self.castSpellId = spellId
    self.castDuration = (self.castTimeCalib and self.castTimeCalib[spellId]) or baseTime
    self.castClearTimeSec = nil
    self.castFlashEnd = nil
    self.castInterruptStart = nil
    self.castSpellName = (spell and spell.en) or ('...')
end

function player:interruptCast()
    local prog = self:getCastProgress() or 1
    self.castInterruptStart = socket.gettime()
    self.castInterruptProg = math.max(0.06, prog)
    self.castStartTimeSec = nil
    self.castDuration = nil
    self.castSpellId = nil
    self.castClearTimeSec = nil
    self.castFlashEnd = nil
    self.castSpellName = nil
end

function player:clearCast()

    if self.castStartTimeSec and self.castSpellId then
        local actual   = socket.gettime() - self.castStartTimeSec
        local expected = self.castDuration or 3
        if actual >= 0.1 and actual <= expected * 2.5 then
            if not self.castTimeCalib then self.castTimeCalib = {} end
            local prev = self.castTimeCalib[self.castSpellId]
            self.castTimeCalib[self.castSpellId] = prev and (prev * 0.7 + actual * 0.3) or actual
        end
    end
    if self.castStartTimeSec then
        self.castClearTimeSec = socket.gettime()
    end
    self.castStartTimeSec = nil
    self.castDuration = nil
    self.castSpellId = nil
    self.castFlashEnd = nil
end

function player:cancelCast()

    self.castStartTimeSec = nil
    self.castDuration = nil
    self.castSpellId = nil
    self.castSpellName = nil
    self.castClearTimeSec = nil
    self.castFlashEnd = nil
    self.castInterruptStart = nil
end

function player:isCastInterrupt()
    return self.castInterruptStart ~= nil
end

function player:getCastProgress()
    if self.castInterruptStart then
        local ph = cast_state.blink_phase(self.castInterruptStart)
        if ph == 'done' then
            self.castInterruptStart = nil
            self.castInterruptProg = nil
            return nil
        end
        if ph == 'on' then return self.castInterruptProg or 1 end
        return nil
    end
    if self.castFlashEnd then
        if socket.gettime() < self.castFlashEnd then
            return 1
        end
        self.castFlashEnd = nil
        self.castSpellName = nil
        return nil
    end
    if self.castClearTimeSec then
        if socket.gettime() - self.castClearTimeSec < 0.15 then
            return 1
        end
        self.castClearTimeSec = nil
        return nil
    end
    if not self.castStartTimeSec or not self.castDuration or self.castDuration <= 0 then
        return nil
    end
    local elapsed = socket.gettime() - self.castStartTimeSec
    if elapsed >= self.castDuration then
        if elapsed < self.castDuration + 12 then
            return 0.99
        end
        self.castClearTimeSec = socket.gettime()
        self.castStartTimeSec = nil
        self.castDuration = nil
        self.castSpellId = nil
        return 1
    end
    return elapsed / self.castDuration
end

function player:flashAbility(actionId, actionType)
    if self.castStartTimeSec then return end
    local entry
    if actionType == 'ws' then
        entry = _priv.weapon_skill(actionId)
    else
        entry = _priv.ability(actionId)
    end
    if not entry then return end
    self.castSpellName = entry.en
    self.castFlashEnd = socket.gettime() + ABILITY_FLASH_SECS
    self.castStartTimeSec = nil
    self.castDuration = nil
    self.castClearTimeSec = nil
    self.castSpellId = nil
end

function player:updateLeaderFromFlags(flags)
    self.isLeader = utils:bitAnd(flags, 4) > 0
    self.isAllianceLeader = utils:bitAnd(flags, 8) > 0
    self.isQuarterMaster = utils:bitAnd(flags, 16) > 0
end

function player:updateJobFromPacket(packet)

    local mJob = packet['Main job']
    local mJobLvl = packet['Main job level']
    local sJob =  packet['Sub job']
    local sJobLvl = packet['Sub job level']

    if (mJob and mJobLvl and sJob and sJobLvl and mJobLvl > 0) then
        self.job = res.jobs[mJob].ens
        self.jobLvl = mJobLvl
        self.subJob = res.jobs[sJob].ens
        self.subJobLvl = sJobLvl

        utils:log('Set job info: '.. self.job ..tostring(mJobLvl)..'/'.. self.subJob ..tostring(sJobLvl), 0)
    else
        utils:log('Unusable job info. Dropping.', 0)
    end
end

function player:createSetupData(job, subJob, isMainParty)
    self.hp = math.random(500,2500)
    self.mp = math.random(500,1500)
    self.tp = math.random(0,3000)
    self.hpp = self.hp / 2500 * 100
    self.mpp = math.random(50, 100)
    self.tpp = math.min(self.tp / 1000 * 100, 100)

    self.zone = windower.ffxi.get_info().zone

    self.isSelected = false
    self.isSubTarget = false
    self.distance = math.random(0, 25)
    self.isInCastingRange = self.distance < const.castRange
    self.isInTargetingRange = self.distance < const.targetRange
    self.isTrust = false

    self.job = job
    self.jobLvl = 99
    self.subJob = subJob
    self.subJobLvl = 49

    self.buffs = {}

    if isMainParty then
        for i = 1, const.maxBuffs do
            self.buffs[i] = math.random(1, 631)
        end
    end

    self:updateBuffs(self.buffs)
end

return player
