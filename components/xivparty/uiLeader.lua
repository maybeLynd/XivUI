
local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local const = require('components/xivparty/const')

local uiLeader = classes.class(uiContainer)

function uiLeader:init(layout, player)
    if self.super:init(layout) then
        self.player = player

        self.imgParty = self:addChild(uiImage.new(layout.imgParty))
        self.imgParty:hide(const.visFeature)

        self.imgAlliance = self:addChild(uiImage.new(layout.imgAlliance))
        self.imgAlliance:hide(const.visFeature)

        self.imgQuarterMaster = self:addChild(uiImage.new(layout.imgQuarterMaster))
        self.imgQuarterMaster:hide(const.visFeature)
    end
end

function uiLeader:setPlayer(player)
    self.player = player
end

function uiLeader:update()
    if not self.isEnabled then return end

    self.imgParty:visible(self.player.isLeader, const.visFeature)
    self.imgAlliance:visible(self.player.isAllianceLeader, const.visFeature)
    self.imgQuarterMaster:visible(self.player.isQuarterMaster, const.visFeature)

    self.super:update()
end

return uiLeader
