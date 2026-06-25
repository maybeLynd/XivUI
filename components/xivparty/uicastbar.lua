local classes     = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage     = require('components/xivparty/uiimage')
local utils       = require('components/xivparty/utils')

local uiCastBar = classes.class(uiContainer)

function uiCastBar:init(layout)
    if self.super:init(layout) then
        self.imgBg   = self:addChild(uiImage.new(layout.imgBg))
        self.imgFill = self:addChild(uiImage.new(layout.imgFill))

        local fillSize  = utils:coord(layout.imgFill.size)
        self.fillMaxX   = fillSize.x
        self.fillHeight = fillSize.y
        self.defaultColor = utils:colorFromHex(layout.imgFill.color)

        self.imgFill:size(0, self.fillHeight)
    end
end

function uiCastBar:setProgress(progress)
    if not self.isEnabled then return end
    progress = math.min(math.max(progress, 0), 1)
    self.imgFill:size(self.fillMaxX * progress, self.fillHeight)
end

function uiCastBar:setFillColor(color)
    if not self.isEnabled then return end
    self.imgFill:color(color or self.defaultColor)
end

function uiCastBar:update()
    if not self.isEnabled then return end
    self.super:update()
end

return uiCastBar
