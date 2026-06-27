local config = require('config')

local classes = require('components/xivparty/classes')
local uiContainer = require('components/xivparty/uicontainer')
local uiPartyList = require('components/xivparty/uipartylist')
local layoutDefaults = require('components/xivparty/layout')
local const = require('components/xivparty/const')

local uiView = classes.class(uiContainer)

local function getLayoutFileNames(layoutName)
    local layoutFile = const.layoutDir .. layoutName .. const.xmlExtension
    local layoutAllianceFile = const.layoutDir .. layoutName .. const.layoutAllianceSuffix .. const.xmlExtension

    return layoutFile, layoutAllianceFile
end

local function checkLayout(layoutName)
    local layoutFile = getLayoutFileNames(layoutName)

    if not windower.file_exists(windower.addon_path .. layoutFile) then
        log('Layout \'' .. layoutName .. '\' not found. Reverting to default \'' .. const.defaultLayout .. '\'.')

        Settings.layout = const.defaultLayout
        Settings:save()
    end
end

local function loadLayout(layoutName)
    local layoutFile, layoutAllianceFile = getLayoutFileNames(layoutName)

    local layout = config.load(layoutFile, layoutDefaults)
    local layoutAlliance

    local hasAllianceFile = windower.file_exists(windower.addon_path .. layoutAllianceFile)
    if hasAllianceFile then
        layoutAlliance = config.load(layoutAllianceFile, layoutDefaults)
    else
        layoutAlliance = layout
    end

    local oc, orow = tonumber(Settings.allianceColumns) or 0, tonumber(Settings.allianceRows) or 0
    if hasAllianceFile and (oc > 0 or orow > 0) and layoutAlliance.partyList then
        if oc > 0 then layoutAlliance.partyList.columns = oc end
        if orow > 0 then layoutAlliance.partyList.rows = orow end
    end

    return layout, layoutAlliance
end

function uiView:init(model, isUiLocked)
    if isUiLocked == nil then isUiLocked = true end

    if self.super:init() then
        self.model = model
        self.isUiLocked = isUiLocked

        self.partyLists = T{}

        self:reload()
    end
end

function uiView:reload()
    self:clearChildren(true)

    self.lastPartyIndex = 2
    if Settings.hideAlliance then
        self.lastPartyIndex = 0
    end

    checkLayout(Settings.layout)
    self.layout, self.layoutAlliance = loadLayout(Settings.layout)

    for i = 0, self.lastPartyIndex do
        self.partyLists[i] = self:addChild(uiPartyList.new(
            i == 0 and self.layout.partyList or self.layoutAlliance.partyList,
            i,
            self.model,
            self.isUiLocked))
    end

    if not Settings.hidePets then
        self.partyLists[3] = self:addChild(uiPartyList.new(
            self.layout.partyList,
            3,
            self.model,
            self.isUiLocked))
    else
        self.partyLists[3] = nil
    end

    self:layoutElement()
    self:createPrimitives()
end

function uiView:setModel(model)
    if not self.isEnabled then return end

    self.model = model

    for i = 0, self.lastPartyIndex do
        self.partyLists[i]:setModel(model)
    end

    if self.partyLists[3] then
        self.partyLists[3]:setModel(model)
    end
end

function uiView:setUiLocked(isUiLocked)
    if not self.isEnabled then return end

    self.isUiLocked = isUiLocked

    for i = 0, self.lastPartyIndex do
        self.partyLists[i]:setUiLocked(isUiLocked)
    end

    if self.partyLists[3] then
        self.partyLists[3]:setUiLocked(isUiLocked)
    end
end

function uiView:debugSaveLayout()
    if not self.isEnabled then return end

    self.layout:save()
    self.layoutAlliance:save();

    log('Layout saved.')
end

return uiView
