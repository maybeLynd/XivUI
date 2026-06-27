local const = require('components/xivparty/const')

local defaults = {
    layout = const.defaultLayout,

    hideKeyCode = 207,
    hideSolo = false,
    hideAlliance = false,
    hidePets = false,
    hideCutscene = true,
    mouseTargeting = true,
    swapSingleAlliance = false,
    allianceColumns = 0,
    allianceRows = 0,

    rangeNumeric = false,
    rangeIndicator = 0,
    rangeIndicatorFar = 0,

    updateIntervalMsec = 30,

    party = {
        pos = L{ 0.015625, 0.4791666 },
        scale = L{ 0, 0 },
        itemSpacing = 0,
        alignBottom = false,
        showEmptyRows = false
    },
    alliance1 = {
        pos = L{ 0.8671875, 0.5277777 },
        scale = L{ 0, 0 },
        itemSpacing = 0,
        alignBottom = false,
        showEmptyRows = false
    },
    alliance2 = {
        pos = L{ 0.8671875, 0.5972222 },
        scale = L{ 0, 0 },
        itemSpacing = 0,
        alignBottom = false,
        showEmptyRows = false
    },
    pets = {
        pos = L{ 0.015625, 0.670 },
        scale = L{ 0, 0 },
        itemSpacing = 0,
        alignBottom = false,
        showEmptyRows = false
    },

    buffs = {
        filters = '',
        filterMode = 'blacklist',
        customOrder = false
    }
}

return defaults
