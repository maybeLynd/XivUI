return {
    UNUSABLE_REASON = {
        lvl         = 'Not high enough level',
        nosub       = 'Not available as sub-job',
        merit       = 'Merit not unlocked',
        unlearned   = 'Not learned',
        choice_only = 'Use a choice: place the individual options, or use a choice from the Choice panel',
    },

    MACRO_KINDS = { { k = 'ja', l = 'Ability' }, { k = 'ma', l = 'Spell' }, { k = 'ws', l = 'Wpn Skill' },
                    { k = 'item', l = 'Item' }, { k = 'use_equip', l = 'Use Gear' },
                    { k = 'input', l = 'Command' }, { k = 'macro', l = 'Macro' } },

    MACRO_TARGETS      = { 'me', 't', 'bt', 'st', 'stnpc', 'stpc', 'r' },
    MACRO_TARGETS_MORE = { 'pet', 'p0', 'p1', 'p2', 'p3', 'p4', 'p5',
                           'stpt', 'stal', 'lastst', 'ht', 'ft', 'scan', 'focust' },

    EQUIP_SLOTS = {
        { k = 'main', l = 'Main' },  { k = 'sub', l = 'Sub' },     { k = 'range', l = 'Range' }, { k = 'ammo', l = 'Ammo' },
        { k = 'head', l = 'Head' },  { k = 'neck', l = 'Neck' },   { k = 'lear', l = 'L.Ear' },  { k = 'rear', l = 'R.Ear' },
        { k = 'body', l = 'Body' },  { k = 'hands', l = 'Hands' }, { k = 'ring1', l = 'Ring1' }, { k = 'ring2', l = 'Ring2' },
        { k = 'back', l = 'Back' },  { k = 'waist', l = 'Waist' }, { k = 'legs', l = 'Legs' },   { k = 'feet', l = 'Feet' },
    },

    COMPONENT_INFO = {
        statusbar     = { l = 'Status Bar',    d = 'HP / MP / TP bars' },
        expbar        = { l = 'EXP Bar',       d = 'EXP & capacity bar' },
        targetbar     = { l = 'Target Bar',    d = 'Target HP, buffs & debuffs' },
        xivparty      = { l = 'Party List',    d = 'Party member window' },
        xivhotbar3    = { l = 'Hotbars',       d = 'Action hotbar palette' },
        aggrolist     = { l = 'Aggro List',    d = 'Enemy aggro tracker' },
        dps           = { l = 'DPS Parser',    d = 'Real-time damage parser' },
        requestwindow = { l = 'Requests',      d = 'Party invite & trade popups' },
        notification  = { l = 'Notifications', d = 'Loot toast messages' },
        castbar       = { l = 'Cast Bar',      d = 'Spell / ability cast bar' },
        enemyloot     = { l = 'Enemy Loot',    d = 'Target drops bag' },
        enemyweak     = { l = 'Enemy Weakness',d = 'Target weakness panel' },
    },

    CFG_DEFMOD = {
        ['data/statusbar/settings.xml'] = 'components/statusbar/defaults',
        ['data/castbar/settings.xml']   = 'components/castbar/defaults',
        ['data/xivparty/settings.xml']  = 'components/xivparty/defaults',
    },
}
