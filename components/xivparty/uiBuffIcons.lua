
local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiImage = require('components/xivparty/uiimage')
local const = require('components/xivparty/const')
local utils = require('components/xivparty/utils')

local uiBuffIcons = classes.class(uiContainer)

function uiBuffIcons:init(layout, player)
    if self.super:init(layout) then
        self.layout = layout
        self.player = player

        self.spacing = utils:coord(layout.spacing)
        self.size = utils:coord(layout.size)

        self.currentBuffs = {}
        self.buffImages = {}

        if not self:validateLayout(self.layout) then
            self.isEnabled = false
            return
        end

        self.maxBuffCount = self:getMaxBuffCount()

        for i = 1, self.maxBuffCount do

            local row = self:getRow(i)
            if not row then break end

            local column = self:getColumn(i, row)
            local iconOffset = tonumber(layout.offsetByRow[row]) * (self.size.x + self.spacing.x)

            local posX = iconOffset + (column - 1) * (self.size.x + self.spacing.x)
            if self.layout.alignRight then
                posX = posX - self.maxBuffCount * (self.size.x + self.spacing.x)
            end

            local posY = (row - 1) * self.size.y + (row - 1) * self.spacing.y
            local size = utils:coord(layout.size)
            local color = utils:colorFromHex(layout.color)

            self.buffImages[i] = self:addChild(uiImage.create('', size.x, size.y, posX, posY))
            self.buffImages[i]:color(color)
            self.buffImages[i]:hide(const.visFeature)
        end
    end
end

function uiBuffIcons:setPlayer(player)
    self.player = player
end

function uiBuffIcons:validateLayout(layout)

    local singleEntry = false
    if type(layout.numIconsByRow) == 'number' then
        layout.numIconsByRow = L{ layout.numIconsByRow }
        singleEntry = true
    end
    if type(layout.offsetByRow) == 'number' then
        layout.offsetByRow = L{ layout.offsetByRow }
        singleEntry = true
    end
    if singleEntry then
        warning('To prevent the addon load warning when using a single buff icon row, add an empty row at the end. Example: 32,0')
    end

    if layout.numIconsByRow:length() ~= layout.offsetByRow:length() then
        error('Layout invalid! Lists numIconsByRow and offsetByRow must have the same number of entries!')
        return false
    end

    return true
end

function uiBuffIcons:getRow(iconIndex)
    for row = 1, self.layout.numIconsByRow:length() do
        local numIcons = tonumber(self.layout.numIconsByRow[row])

        if iconIndex <= numIcons then return row end
        iconIndex = iconIndex - numIcons
    end

    return nil
end

function uiBuffIcons:getColumn(iconIndex, row)
    if not row then return nil end

    local column = iconIndex - self:getSumOfPreviousRows(row)
    return column
end

function uiBuffIcons:getSumOfPreviousRows(row)
    local sum = 0
    if row > 1 then
        for r = 1, row - 1 do
            sum = sum + tonumber(self.layout.numIconsByRow[r])
        end
    end

    return sum
end

function uiBuffIcons:getMaxBuffCount()
    local count = 0
    for row = 1, self.layout.numIconsByRow:length() do
        local numIcons = tonumber(self.layout.numIconsByRow[row])
        count = count + numIcons
    end

    return math.min(const.maxBuffs, count)
end

function uiBuffIcons:update()
    if not self.isEnabled then return end

    local buffs = self.player.filteredBuffs
    if not buffs or self.player.isOutsideZone then
        buffs = T{}
    end

    if not table.equals(buffs, self.currentBuffs) then
        self.currentBuffs = table.copy(buffs)

        for i = 1, self.maxBuffCount do
            local buff
            local image = self.buffImages[i]

            if self.layout.alignRight then
                local row = self:getRow(i)
                if not row then break end

                local numIcons = self.layout.numIconsByRow[row]
                local sumPreviousRows = self:getSumOfPreviousRows(row)

                local totalBuffCount = math.min(buffs:length(), self.maxBuffCount)
                local buffCountInRow = math.min(totalBuffCount - sumPreviousRows, numIcons)

                local indexOffset = buffCountInRow - numIcons
                local index = i + indexOffset

                if index - sumPreviousRows > 0 then
                    buff = buffs[index]
                else
                    buff = nil
                end
            else
                buff = buffs[i]
            end

            if buff then
                image:path(self.layout.path .. tostring(buff) .. '.png')
                image:show(const.visFeature)
            else
                image:path('')
                image:hide(const.visFeature)
            end
        end
    end

    self.super:update()
end

return uiBuffIcons
