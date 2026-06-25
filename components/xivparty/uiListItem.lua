
local res     = require('resources')
local socket  = require('socket')
local packets = require('packets')

local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiJobIcon = require('components/xivparty/uijobicon')
local uiStatusBar = require('components/xivparty/uistatusbar')
local uiLeader= require('components/xivparty/uileader')
local uiRange = require('components/xivparty/uirange')
local uiBuffIcons = require('components/xivparty/uibufficons')
local uiText = require('components/xivparty/uitext')
local uiImage = require('components/xivparty/uiimage')
local uiCastBar = require('components/xivparty/uicastbar')
local const = require('components/xivparty/const')
local utils = require('components/xivparty/utils')

local uiListItem = classes.class(uiContainer)

local isDebug = false

local pet_target     = nil
local pet_saved      = 0
local pet_start_time = 0
local pet_next_tab   = 0
local pet_count      = 0
local pet_from       = {}
local pet_last       = -1
local pet_prerender  = nil

local function pet_cleanup(restore)
    if restore then
        if pet_saved > 0 then
            pcall(function()
                packets.inject(packets.new('outgoing', 0x016, {['Target Index'] = pet_saved}))
            end)
        else
            windower.send_command('setkey escape down; wait 0.02; setkey escape up')
        end
    end
    pet_target = nil; pet_saved = 0; pet_count = 0; pet_from = {}; pet_last = -1
end

local function pet_prerender_fn()
    if not pet_target then return end
    local now = socket.gettime()
    local cur = windower.ffxi.get_mob_by_target('t')
    local ci  = cur and cur.index or 0

    if ci == pet_target then
        pet_cleanup(false)
        return
    end
    local want = windower.ffxi.get_mob_by_index(pet_target)
    if not want or not want.hpp or want.hpp <= 0 then
        pet_cleanup(true)
        return
    end
    if now - pet_start_time > 5.0 then
        pet_cleanup(true)
        return
    end
    if now >= pet_next_tab and ci ~= pet_last then
        if pet_count > 0 and pet_from[ci] then
            pet_cleanup(true)
            return
        end
        pet_from[ci] = true
        pet_last = ci
        windower.send_command('setkey tab down; wait 0.02; setkey tab up')
        pet_next_tab = now + 0.15
        pet_count    = pet_count + 1
    end
end

local function fire_tab_to_mob(want_index, want_name)
    if not want_index or want_index == 0 then return end
    if not pet_prerender then
        pet_prerender = windower.register_event('prerender', pet_prerender_fn)
    end

    local prev = windower.ffxi.get_mob_by_target('t')

    pcall(function()
        packets.inject(packets.new('outgoing', 0x016, {['Target Index'] = want_index}))
    end)

    if want_name then
        windower.chat.input('/target ' .. want_name)
    end
    local now      = socket.gettime()
    pet_target     = want_index
    pet_saved      = prev and prev.index or 0
    pet_start_time = now
    pet_next_tab   = now + 0.1
    pet_count      = 0
    pet_from       = {}
    pet_last       = -1
end

function uiListItem:init(layout, player, isUiLocked, itemWidth, itemHeight, partyIndex, slotIndex)
    if self.super:init(layout) then
        self.layout = layout
        self.player = player
        self.isUiLocked = isUiLocked
        self.partyIndex = partyIndex or 0
        self.slotIndex = slotIndex or 0

        self.hover = self:addChild(uiImage.new(layout.hover))
        self.hover:hide(const.visFeature)

        self.cursor = self:addChild(uiImage.new(layout.cursor))
        self.cursor:opacity(0)

        self.hpBar = self:addChild(uiStatusBar.new(layout.hp, const.barTypeHp, player))
        self.mpBar = self:addChild(uiStatusBar.new(layout.mp, const.barTypeMp, player))
        self.tpBar = self:addChild(uiStatusBar.new(layout.tp, const.barTypeTp, player))
        self.tpBarDefaultX = layout.tp.pos[1]
        self.tpBarDefaultY = layout.tp.pos[2]
        self.mpBarDefaultX = layout.mp.pos[1]
        self.mpBarDefaultY = layout.mp.pos[2]
        self.nameDefaultX = layout.txtName.pos[1]
        self.nameDefaultY = layout.txtName.pos[2]
        self.nameDefaultMaxChars = layout.txtName.maxChars or 0
        self.namePetX = layout.hp.pos[1]

        self.jobIcon = self:addChild(uiJobIcon.new(layout.jobIcon, player))

        self.txtName = self:addChild(uiText.new(layout.txtName))
        self.txtZone = self:addChild(uiText.new(layout.txtZone))

        self.txtJob = self:addChild(uiText.new(layout.txtJob))
        self.txtSubJob = self:addChild(uiText.new(layout.txtSubJob))

        self.leader = self:addChild(uiLeader.new(layout.leader, player))

        self.range = self:addChild(uiRange.new(layout.range, player))
        self.buffIcons = self:addChild(uiBuffIcons.new(layout.buffIcons, player))

        self.castBar = self:addChild(uiCastBar.new(layout.castBar))
        if self.castBar then self.castBar:hide(const.visFeature) end

        self.txtCastSpell = self:addChild(uiText.new(layout.txtCastSpell))
        if self.txtCastSpell then self.txtCastSpell:hide(const.visFeature) end

        self.imgMouse = self:addChild(uiImage.create())
        self.imgMouse:size(math.max(0, itemWidth - 1), math.max(0, itemHeight - 1))
        self.imgMouse:alpha(isDebug and 32 or 0)

        self.mouseHandlerId = windower.register_event('mouse', function(type, x, y, delta, blocked)
            return self:handleWindowerMouse(type, x, y, delta, blocked)
        end)
    end
end

function uiListItem:dispose()
    if not self.isEnabled then return end

    if self.mouseHandlerId then
        windower.unregister_event(self.mouseHandlerId)
        self.mouseHandlerId = nil
    end

    if pet_prerender then
        windower.unregister_event(pet_prerender)
        pet_prerender = nil
    end
    pet_target = nil; pet_saved = 0; pet_count = 0; pet_from = {}; pet_last = -1

    self.super:dispose()
end

function uiListItem:setPlayer(player)
    if not self.isEnabled then return end
    if self.player == player then return end

    self.player = player

    self.hpBar:setPlayer(player)
    self.mpBar:setPlayer(player)
    self.tpBar:setPlayer(player)

    self.jobIcon:setPlayer(player)
    self.leader:setPlayer(player)
    self.range:setPlayer(player)
    self.buffIcons:setPlayer(player)
end

function uiListItem:setUiLocked(isUiLocked)
    if not self.isEnabled then return end

    self.isUiLocked = isUiLocked

    if not isUiLocked then
        self.hover:hide(const.visFeature)
    end
end

function uiListItem:update()
    if not self.isEnabled or not self.player then return end

    local displayName = self.player.name or '???'
    if self.player.ownerName then
        displayName = self.player.ownerName .. ': ' .. displayName
        self.txtName:pos(self.namePetX, self.nameDefaultY)
        self.txtName:setMaxChars(0)
    else
        self.txtName:pos(self.nameDefaultX, self.nameDefaultY)
        self.txtName:setMaxChars(self.nameDefaultMaxChars)
    end
    self.txtName:update(displayName)

    self:updateZone()
    self:updateJob()
    self:updateCursor()
    self:updateCastBar()

    local isForeignPet = self.player.ownerName ~= nil and
        (windower.ffxi.get_player() or {}).name ~= self.player.ownerName

    if self.player.hasMp == false then
        self.mpBar:hide(const.visFeature)
        self.tpBar:pos(self.mpBarDefaultX, self.mpBarDefaultY)
    else
        self.mpBar:show(const.visFeature)
        self.tpBar:pos(self.tpBarDefaultX, self.tpBarDefaultY)
    end

    if isForeignPet then
        self.tpBar:hide(const.visFeature)
    else
        self.tpBar:show(const.visFeature)
    end

    self.super:update()
end

function uiListItem:updateZone()
    local zoneString = ''

    if self.player.zone and self.player.isOutsideZone then
        if self.layout.txtZone.short then
            zoneString = '('..res.zones[self.player.zone]['search']..')'
        else
            zoneString = '('..res.zones[self.player.zone].name..')'
        end
    end

    self.txtZone:update(zoneString)
end

function uiListItem:updateJob()
    local jobString = ''
    local subJobString = ''

    if not self.player.isOutsideZone then
        if self.player.job then
            jobString = self.player.job
            if self.player.jobLvl then
                jobString = jobString .. ' ' .. tostring(self.player.jobLvl)
            end
        end

        if self.player.subJob and self.player.subJob ~= 'MON' then
            subJobString = self.player.subJob
            if self.player.subJobLvl then
                subJobString = subJobString .. ' ' .. tostring(self.player.subJobLvl)
            end
        end
    end

    self.txtJob:update(jobString)
    self.txtSubJob:update(subJobString)
end

function uiListItem:updateCursor()
    local opacity = 0

    if not self.player.isOutsideZone then
        if self.player.isSelected then
            opacity = 1
        elseif self.player.isSubTarget then
            opacity = 0.5
        end
    end

    self.cursor:opacity(opacity)
end

function uiListItem:updateCastBar()
    if not self.castBar or not self.castBar.isEnabled then return end
    local progress = self.player and self.player:getCastProgress()
    if progress then
        local interrupted = self.player.isCastInterrupt and self.player:isCastInterrupt()
        self.castBar:setFillColor(interrupted and { r = 224, g = 64, b = 64, a = 255 } or nil)
        self.castBar:setProgress(progress)
        self.castBar:show(const.visFeature)
        if self.txtCastSpell and self.txtCastSpell.isEnabled then
            if interrupted then
                self.txtCastSpell:update('Interrupted')
                self.txtCastSpell:color(224, 64, 64)
            else
                self.txtCastSpell:update(self.player.castSpellName or '')
                self.txtCastSpell:color(240, 255, 255)
            end
            self.txtCastSpell:show(const.visFeature)
        end
    else
        self.castBar:hide(const.visFeature)
        if self.txtCastSpell then self.txtCastSpell:hide(const.visFeature) end
    end
end

function uiListItem:handleWindowerMouse(type, x, y, delta, blocked)
    if self.isUiLocked and Settings.mouseTargeting then
        if self.imgMouse:hover(x, y) and not self.player.isOutsideZone and self.player.isInTargetingRange then

            if type == 0 then
                self.hover:show(const.visFeature)

            elseif type == 1 then
                return true

            elseif type == 2 then
                if self.player.isFellow then
                    windower.chat.input('/ta <ft>')
                elseif self.player.ownerName then
                    if self.player.name and self.player.name:find('^Geo%-') then
                        return true
                    end
                    local mainPlayer = windower.ffxi.get_player()
                    if mainPlayer and mainPlayer.name == self.player.ownerName then
                        windower.send_command('setkey f10 down; wait 0.05; setkey f10 up')
                    else
                        fire_tab_to_mob(self.player.mobIndex, self.player.name)
                    end
                elseif self.partyIndex == 0 then
                    local fkey = 'f' .. (self.slotIndex + 1)
                    windower.send_command('setkey ' .. fkey .. ' down; wait 0.05; setkey ' .. fkey .. ' up')
                else
                    windower.chat.input('/ta ' .. self.player.name)
                end
                return true
            end
        else
            self.hover:hide(const.visFeature)
        end
    else
        self.hover:hide(const.visFeature)
    end

    return false
end

return uiListItem
