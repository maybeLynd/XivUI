
require('tables')

local classes = require('components/xivparty/classes')
local utils = require('components/xivparty/utils')
local const = require('components/xivparty/const')

local uiElement = classes.class()

local private = {}

function uiElement:init(layout)
    private[self] = {}
    private[self].visibility = {}
    private[self].visibility[const.visDefault] = true
    self.absoluteVisibility = true

    self.parent = nil
    self.isCreated = false

    self.isEnabled = true
    if layout and layout.enabled ~= nil then
        self.isEnabled = layout.enabled
    end

    self.posX = 0
    self.posY = 0
    if layout and layout.pos then
        local pos = utils:coord(layout.pos)
        self.posX = pos.x
        self.posY = pos.y
    end

    self.scaleX = 1
    self.scaleY = 1
    if layout and layout.scale then
        local scale = utils:coord(layout.scale)
        self.scaleX = scale.x
        self.scaleY = scale.y
    end

    self.absolutePos = { x = 0, y = 0 }
    self.absoluteScale = { x = 1, y = 1 }

    self.zOrder = 0
    if layout and layout.zOrder then
        self.zOrder = layout.zOrder
    end

    self.snapToRaster = false
    if layout and layout.snapToRaster ~= nil then
        self.snapToRaster = layout.snapToRaster
    end

    return self.isEnabled
end

function uiElement:dispose()
    self.isEnabled = false
    self.isCreated = false

    private[self] = nil
end

function uiElement:createPrimitives()
    self.isCreated = true
    self:applyLayout()
end

function uiElement:layoutElement()
    if not self.isEnabled then return end

    self:updateLayout()
    self:applyLayout()
end

function uiElement:updateLayout()
    if not self.isEnabled then return end

    if self.parent then
        self.absolutePos.x = self.parent.absolutePos.x + self.posX * self.parent.absoluteScale.x
        self.absolutePos.y = self.parent.absolutePos.y + self.posY * self.parent.absoluteScale.y
        self.absoluteScale.x = self.parent.absoluteScale.x * self.scaleX
        self.absoluteScale.y = self.parent.absoluteScale.y * self.scaleY

        self.absoluteVisibility = self.parent.absoluteVisibility and self:getVisibility()
    else
        self.absolutePos.x = self.posX
        self.absolutePos.y = self.posY
        self.absoluteScale.x = self.scaleX
        self.absoluteScale.y = self.scaleY

        self.absoluteVisibility = self:getVisibility()
    end

    if self.snapToRaster then
        self.absolutePos.x = math.floor(self.absolutePos.x)
        self.absolutePos.y = math.floor(self.absolutePos.y)
    end
end

function uiElement:applyLayout()

end

function uiElement:update()

end

function uiElement:pos(x, y)
    if not self.isEnabled then return end

    if self.posX ~= x or self.posY ~= y then
        self.posX = x
        self.posY = y

        self:layoutElement()
    end
end

function uiElement:scale(x, y)
    if not self.isEnabled then return end

    if self.scaleX ~= x or self.scaleY ~= y then
        self.scaleX = x
        self.scaleY = y

        self:layoutElement()
    end
end

function uiElement:show(flagId)
    self:visible(true, flagId)
end

function uiElement:hide(flagId)
    self:visible(false, flagId)
end

function uiElement:visible(isVisible, flagId)
    if not self.isEnabled then return end
    if not isVisible then isVisible = false end
    if not flagId then flagId = const.visDefault end

    if private[self].visibility[flagId] ~= isVisible then
        private[self].visibility[flagId] = isVisible

        self:layoutElement()
    end
end

function uiElement:getVisibility()
    return utils:all(private[self].visibility)
end

return uiElement
