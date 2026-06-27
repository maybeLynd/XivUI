local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local utils = require('components/xivparty/utils')

local uiBackground = classes.class(uiContainer)

local isDebug = false

function uiBackground:init(layout, contentHeight)
    if self.super:init(layout) then
        self.layout = layout

        if not contentHeight then contentHeight = 0 end
        self.contentHeight = contentHeight

        self.imgTop = self:addChild(uiImage.new(layout.imgTop))
        self.imgMid = self:addChild(uiImage.new(layout.imgMid))
        self.imgBottom = self:addChild(uiImage.new(layout.imgBottom))

        self.sizeMid = utils:coord(layout.imgMid.size)

        if isDebug then
            self.imgTop:path('')
            self.imgMid:path('')
            self.imgBottom:path('')

            self.imgTop:color(255,0,0)
            self.imgMid:color(0,255,0)
            self.imgBottom:color(0,0,255)

            self.imgTop:alpha(32)
            self.imgMid:alpha(32)
            self.imgBottom:alpha(32)
        end
    end
end

function uiBackground:setContentHeight(contentHeight)
    self.contentHeight = contentHeight
end

function uiBackground:update()
    if not self.isEnabled then return end

    local contentHeight = self.contentHeight / self.scaleY

    self.imgMid:size(self.sizeMid.x, contentHeight)
    self.imgMid:repeat_xy(1, math.floor(contentHeight / self.sizeMid.y))
    self.imgBottom:pos(self.imgBottom.posX, self.imgMid.posY + contentHeight)

    self.super:update()
end

return uiBackground
