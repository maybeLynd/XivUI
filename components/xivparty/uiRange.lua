local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local uiText = require('components/xivparty/uitext')
local const = require('components/xivparty/const')

local uiRange = classes.class(uiContainer)

function uiRange:init(layout, player)
    if self.super:init(layout) then
        self.layout = layout
        self.player = player

        self.imgNear = self:addChild(uiImage.new(layout.imgNear))
        self.imgNear:hide(const.visFeature)

        self.imgFar = self:addChild(uiImage.new(layout.imgFar))
        self.imgFar:hide(const.visFeature)

        self.txtDistance = self:addChild(uiText.new(layout.txtDistance))
    end
end

function uiRange:setPlayer(player)
    self.player = player
end

function uiRange:update()
    if not self.isEnabled then return end

    self:updateIndicators()
    self:updateNumeric()

    self.super:update()
end

function uiRange:updateIndicators()
    local visibility = false
    local visibilityFar = false

    if not Settings.rangeNumeric and self.player.distance and not self.player.isOutsideZone then
        if Settings.rangeIndicator > 0 and self.player.distance <= Settings.rangeIndicator then
            visibility = true
            visibilityFar = false
        elseif Settings.rangeIndicatorFar > 0 and self.player.distance <= Settings.rangeIndicatorFar then
            visibility = false
            visibilityFar = true
        end
    end

    self.imgNear:visible(visibility, const.visFeature)
    self.imgFar:visible(visibilityFar, const.visFeature)
end

function uiRange:updateNumeric()
    local distanceString = ''

    if Settings.rangeNumeric and not self.player.isMainPlayer and not self.player.isOutsideZone then
        if self.player.distance then
            distanceString = string.format("%.2f", self.player.distance)
        else
            distanceString = '?'
        end
    end

    self.txtDistance:update(distanceString)
end

return uiRange
