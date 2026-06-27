local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local jobs = require('components/xivparty/jobs')
local const = require('components/xivparty/const')

local uiJobIcon = classes.class(uiContainer)

function uiJobIcon:init(layout, player)
    if self.super:init(layout) then
        self.layout = layout
        self.player = player

        self.jobHighlight = self:addChild(uiImage.new(layout.imgHighlight))
        self.jobHighlight:hide(const.visFeature)

        self.jobBg = self:addChild(uiImage.new(layout.imgBg))
        self.jobBg:hide(const.visFeature)

        self.jobGradient = self:addChild(uiImage.new(layout.imgGradient))
        self.jobGradient:hide(const.visFeature)

        self.jobIcon = self:addChild(uiImage.new(layout.imgIcon))
        self.jobIcon:hide(const.visFeature)

        self.jobFrame = self:addChild(uiImage.new(layout.imgFrame))
        self.jobFrame:hide(const.visFeature)
    end
end

function uiJobIcon:setPlayer(player)
    self.player = player
end

function uiJobIcon:update()
    if not self.isEnabled then return end

    local visibility = false
    local highlightVisibility = false

    if not self.player.isOutsideZone and self.player.job then
        self.jobIcon:path(self.layout.path .. self.player.job .. '.png')
        self.jobBg:color(jobs:getRoleColor(self.player.job, self.layout.colors))
        visibility = true

        if self.player.isSelected then
            highlightVisibility = true
        end
    end

    self.jobHighlight:visible(highlightVisibility, const.visFeature)
    self.jobBg:visible(visibility, const.visFeature)
    self.jobGradient:visible(visibility, const.visFeature)
    self.jobIcon:visible(visibility, const.visFeature)
    self.jobFrame:visible(visibility, const.visFeature)

    self.super:update()
end

return uiJobIcon
