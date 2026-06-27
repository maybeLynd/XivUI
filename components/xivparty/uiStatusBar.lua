local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiBar = require('components/xivparty/uibar')
local uiText = require('components/xivparty/uitext')
local const = require('components/xivparty/const')
local utils = require('components/xivparty/utils')

local uiStatusBar = classes.class(uiContainer)

function uiStatusBar:init(layout, barType, player)
    if self.super:init(layout) then
        self.layout = layout
        self.barType = barType
        self.player = player

        self.bar = self:addChild(uiBar.new(layout.bar))
        self.txtValue = self:addChild(uiText.new(layout.txtValue))

        if self.barType == const.barTypeHp then
            self.hpYellowColor = utils:colorFromHex(layout.hpYellowColor)
            self.hpOrangeColor = utils:colorFromHex(layout.hpOrangeColor)
            self.hpRedColor = utils:colorFromHex(layout.hpRedColor)

            self.hpYellowBarColor = utils:colorFromHex(layout.hpYellowBarColor)
            self.hpOrangeBarColor = utils:colorFromHex(layout.hpOrangeBarColor)
            self.hpRedBarColor = utils:colorFromHex(layout.hpRedBarColor)
        elseif self.barType == const.barTypeTp then
            self.tpFullColor = utils:colorFromHex(layout.tpFullColor)
            self.tpFullBarColor = utils:colorFromHex(layout.tpFullBarColor)
        end

        self.textColor = utils:colorFromHex(layout.txtValue.color)
    end
end

function uiStatusBar:setPlayer(player)
    self.player = player
end

function uiStatusBar:update()
    if not self.isEnabled then return end

    local val = nil
    local valPercent = nil

    if not self.player.isOutsideZone then
        if self.barType == const.barTypeHp then
            val = self.player.hp
            valPercent = self.player.hpp
        elseif self.barType == const.barTypeMp then
            val = self.player.mp
            valPercent = self.player.mpp
        elseif self.barType == const.barTypeTp then
            val = self.player.tp
            valPercent = self.player.tpp
        end

        self:show(const.visOutsideZone)
    elseif self.layout.hideOutsideZone then
        self:hide(const.visOutsideZone)
    end

    if not val then val = -1 end
    if not valPercent then valPercent = 0 end

    self.bar:setValue(valPercent / 100)

    if val < 0 then
        self.txtValue:update('?')
    else
        self.txtValue:update(tostring(val))
    end

    local color = self.textColor
    local barColor = nil
    if self.barType == const.barTypeHp then
        if val >= 0 then
            if valPercent < 25 then
                color = self.hpRedColor
                barColor = self.hpRedBarColor
            elseif valPercent < 50 then
                color = self.hpOrangeColor
                barColor = self.hpOrangeBarColor
            elseif valPercent < 75 then
                color = self.hpYellowColor
                barColor = self.hpYellowBarColor
            end
        end
    elseif self.barType == const.barTypeTp then
        if val >= 1000 then
            color = self.tpFullColor
            barColor = self.tpFullBarColor
        end
    end

    self.txtValue:color(color)
    self.bar:setColor(barColor)

    if self.player.isInCastingRange then
        self.bar:opacity(1)
    elseif self.player.isInTargetingRange then
        self.bar:opacity(0.5)
    else
        self.bar:opacity(0.25)
    end

    self.super:update()
end

return uiStatusBar
