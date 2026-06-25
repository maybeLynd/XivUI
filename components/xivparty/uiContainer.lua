
require('tables')

local classes = require('components/xivparty/classes')
local uiElement = require('components/xivparty/uielement')
local utils = require('components/xivparty/utils')

local uiContainer = classes.class(uiElement)

function uiContainer:init(layout)
    self.super:init(layout)

    self.children = T{}

    return self.isEnabled
end

function uiContainer:dispose()
    if not self.isEnabled then return end

    self:clearChildren(true)

    self.super:dispose()
end

function uiContainer:addChild(child)
    if not self.isEnabled then return end

    if not child:instanceOf(uiElement) then
        utils:log('Failed to add UI child. Class must derive from uiElement!', 4)
        return nil
    end

    self.children:append(child)
    child.parent = self

    child:layoutElement()
    if self.isCreated then
        child:createPrimitives()
    end

    return child
end

function uiContainer:removeChild(child)
    if not self.isEnabled then return end

    if not self.children:delete(child) then return end

    child.parent = nil
    child:layoutElement()
end

function uiContainer:clearChildren(dispose)
    if not self.isEnabled then return end

    for child in self.children:it() do
        child.parent = nil

        if dispose then
            child:dispose()
        else
            child:layoutElement()
        end
    end

    self.children:clear()
end

function uiContainer:createPrimitives()
    if not self.isEnabled then return end

    utils:insertionSort(self.children, function(a, b) return a.zOrder > b.zOrder end)

    for child in self.children:it() do
        child:createPrimitives()
    end

    self.super:createPrimitives()
end

function uiContainer:layoutElement()
    if not self.isEnabled then return end

    self.super:layoutElement()

    for child in self.children:it() do
        child:layoutElement()
    end
end

function uiContainer:update()
    if not self.isEnabled then return end

    self.super:update()

    for child in self.children:it() do
        child:update()
    end
end

return uiContainer
