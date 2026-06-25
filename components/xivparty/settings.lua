
local config = require('config')
require('strings')

local classes = require('components/xivparty/classes')
local defaults = require('components/xivparty/defaults')
local jobDefaults = require('components/xivparty/jobdefaults')
local utils = require('components/xivparty/utils')
local const = require('components/xivparty/const')

local settings = classes.class()

local resX = windower.get_windower_settings().ui_x_res
local resY = windower.get_windower_settings().ui_y_res

function settings:init(model)
    self.model = model

    self.globalSettings = nil
    self.jobSettings = nil
    self.currentJob = ''

    self.jobEnabled = false
    self.buffFilters = T{}
end

local function copySettings(from, to, schema, ignoreSchema)
    for key, val in pairs(schema) do
        if not ignoreSchema or ignoreSchema[key] == nil then
            if type(from[key]) == 'table' then
                to[key] = table.copy(from[key])
            else
                to[key] = from[key]
            end
        end
    end
end

function settings:load(create, enable)
    local wasJobEnabled = self.jobEnabled

    self.globalSettings = config.load('data/xivparty/settings.xml', defaults)
    self.jobSettings = nil
    self.jobEnabled = false

    copySettings(self.globalSettings, self, defaults)

    local job = windower.ffxi.get_player().main_job
    if job then
        local jobFilePath = const.dataDir .. string.lower(job) .. const.xmlExtension
        local fullJobFilePath = windower.addon_path .. jobFilePath

        local exists = windower.file_exists(fullJobFilePath)
        if create or exists then
            local js = config.load(jobFilePath, jobDefaults)

            if not js.jobEnabled and enable then
                js.jobEnabled = true
                js:save()
            end

            if js.jobEnabled then
                self.jobSettings = js
                self.jobEnabled = true
                self.currentJob = job

                if create and not exists then
                    copySettings(self, self.jobSettings, jobDefaults)
                    self.jobSettings:save()
                    log('Created job settings for ' .. job .. ' and copied global settings.')
                else
                    copySettings(self.jobSettings, self, jobDefaults)
                    log('Loaded job settings for ' .. job .. '.')
                end
            end
        end
    end

    if wasJobEnabled and not self.jobEnabled then
        log('Global settings applied.')
    end

    self:loadFilters()
end

function settings:save()
    self:saveFilters()

    if self.jobSettings then
        copySettings(self, self.jobSettings, jobDefaults)
        self.jobSettings:save()

        copySettings(self, self.globalSettings, defaults, jobDefaults)
        self.globalSettings:save()
    else
        copySettings(self, self.globalSettings, defaults)
        self.globalSettings:save()
    end
end

function settings:update()
    local player = windower.ffxi.get_player()
    if not player then return end

    if self.currentJob ~= player.main_job then
        self.currentJob = player.main_job

        self:load()
    end
end

function settings:loadFilters()
    self.buffFilters:clear()

    if self.buffs.filters ~= '' then
        for part in T(self.buffs.filters:split(';')):it() do
            local buffIdString = part:trim()
            if buffIdString ~= '' then
                self.buffFilters[tonumber(buffIdString)] = true
            end
        end
    end

    self.model:refreshFilteredBuffs()
end

function settings:saveFilters()
    self.buffs.filters = ''

    for buffId, doFilter in pairs(self.buffFilters) do

        self.buffs.filters = self.buffs.filters .. tostring(buffId) .. ';'
    end
end

function settings:getPartySettings(partyIndex)
    if partyIndex == 0 then return self.party end
    if partyIndex == 1 then return self.alliance1 end
    if partyIndex == 2 then return self.alliance2 end
    if partyIndex == 3 then return self.pets end
end

function settings:partyIndexToName(partyIndex)
    if partyIndex == 0 then return 'main party' end
    if partyIndex == 1 then return 'alliance 1' end
    if partyIndex == 2 then return 'alliance 2' end
    if partyIndex == 3 then return 'pets' end
end

function settings:getUiPosition(partyIndex)
    local partySettings = self:getPartySettings(partyIndex)

    local pos = utils:coord(partySettings.pos)
    return { x = utils:round(pos.x * resX), y = utils:round(pos.y * resY) }
end

function settings:setUiPosition(posX, posY, partyIndex)
    local partySettings = self:getPartySettings(partyIndex)

    partySettings.pos = L{ posX / resX, posY / resY }
end

function settings:getUiScale(partyIndex)
    local partySettings = self:getPartySettings(partyIndex)

    return utils:coord(partySettings.scale)
end

function settings:setUiScale(scaleX, scaleY, partyIndex)
    local partySettings = self:getPartySettings(partyIndex)

    partySettings.scale = L{ scaleX, scaleY }
end

return settings
