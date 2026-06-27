local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local const = require('components/xivparty/const')
local utils = require('components/xivparty/utils')

local uiBar = classes.class(uiContainer)

function uiBar:init(layout, value)
    if self.super:init(layout) then
        self.layout = layout

        if not value then value = 0 end
        self.value = value
        self.exactValue = value
        self.currentValue = nil

        self.isDimmed = false
        self.animSpeed = self.layout.animSpeed
        if self.animSpeed <= 0 then
            self.animSpeed = 1
        end

        self.imgBg = self:addChild(uiImage.new(layout.imgBg))
        self.imgBar = self:addChild(uiImage.new(layout.imgBar))
        self.imgFg = self:addChild(uiImage.new(layout.imgFg))

        self.imgGlow = self:addChild(uiImage.new(layout.imgGlow))
        self.imgGlowLeft = self:addChild(uiImage.new(layout.imgGlowSides))
        self.imgGlowRight = self:addChild(uiImage.new(layout.imgGlowSides))

        self.imgGlow:hide(const.visFeature)
        self.imgGlowLeft:hide(const.visFeature)
        self.imgGlowRight:hide(const.visFeature)

        self.sizeBar = utils:coord(layout.imgBar.size)
        self.sizeGlow = utils:coord(layout.imgGlow.size)
        self.sizeGlowSides = utils:coord(layout.imgGlowSides.size)

        self.imgBarColor = utils:colorFromHex(layout.imgBar.color)

        self.imgGlowRight:size(-self.sizeGlowSides.x, self.sizeGlowSides.y)
    end
end

function uiBar:setValue(value)
    self.value = math.min(math.max(value, 0), 1)
end

function uiBar:setColor(color)
    if not self.isEnabled then return end

    if not color then color = self.imgBarColor end
    self.imgBar:color(color)
end

function uiBar:update()
    if not self.isEnabled then return end

    if self.currentValue ~= self.value then
        self.exactValue = self.exactValue + (self.value - self.exactValue) * self.animSpeed
        self.exactValue = math.min(math.max(self.exactValue, 0), 1)
        self.currentValue = utils:round(self.exactValue, 3)

        local multiplier
        if self.isDimmed or not self.imgGlow.isEnabled then
            multiplier = self.currentValue
        else
            multiplier = self.value
        end

        self.imgBar:size(self.sizeBar.x * multiplier, self.sizeBar.y)
    end
    self:updateGlow()

    self.super:update()
end

function uiBar:updateGlow()
    if not self.isDimmed and math.abs(self.value - self.currentValue) > 0.01 then
        local glowWidth = self.sizeBar.x * math.abs(self.value - self.currentValue)
        local glowPosX = self.imgBar.posX + self.sizeBar.x * math.min(self.value, self.currentValue)
        local glowLeftPosX = glowPosX - self.sizeGlowSides.x
        local glowRightPosX = glowPosX + glowWidth + self.sizeGlowSides.x

        self.imgGlow:show(const.visFeature)
        self.imgGlowLeft:show(const.visFeature)
        self.imgGlowRight:show(const.visFeature)

        self.imgGlow:size(glowWidth, self.sizeGlow.y)
        self.imgGlow:pos(glowPosX, self.imgGlow.posY)

        self.imgGlowLeft:pos(glowLeftPosX, self.imgGlowLeft.posY)
        self.imgGlowRight:pos(glowRightPosX, self.imgGlowRight.posY)
    else
        self.imgGlow:hide(const.visFeature)
        self.imgGlowLeft:hide(const.visFeature)
        self.imgGlowRight:hide(const.visFeature)
    end
end

function uiBar:opacity(o)
    if not self.isEnabled then return end

    self.isDimmed = o < 1
    self.imgBar:opacity(o)
end

return uiBar
