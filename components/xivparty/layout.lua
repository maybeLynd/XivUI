require('tables')

local XIV   = 'assets/components/xivparty/'
local JOBS  = 'assets/components/xivparty/jobs/'
local BUFFS = 'assets/components/targetbar/buffs/'

local function element(values)
    local ret = {
        enabled = false,
        pos = L{ 0, 0 },
        scale = L{ 1, 1 },
        zOrder = 0,
        snapToRaster = false
    }

    if values ~= nil then
        table.update(ret, values)
    end

    return ret
end

local function image(values)
    local ret = table.update(element(), {
        path = '',
        size = L{ 0, 0 },
        color = '#FFFFFFFF'
    })

    if values ~= nil then
        table.update(ret, values)
    end

    return ret
end

local function text(values)
    local ret = table.update(element(), {
        font = 'Constantia',
        size = 12,
        color = '#FFFFFFFF',
        stroke = '#000000FF',
        strokeWidth = 1,
        alignRight = false,
        maxChars = 0
    })

    if values ~= nil then
        table.update(ret, values)
    end

    return ret
end

local layout = {
    partyList = {
        rows = 6,
        columns = 1,
        rowHeight = 46,
        columnWidth = 410,

        background = element({
            pos = L{ 0, -21 },
            imgTop = image({
                pos = L{ 0, 0 },
                path = XIV .. 'BgTop.png',
                size = L{ 377, 21 },
                color = '#FFFFFFDD'
            }),
            imgMid = image({
                pos = L{ 0, 21 },
                path = XIV .. 'BgMid.png',
                size = L{ 377, 12 },
                color = '#FFFFFFDD'
            }),
            imgBottom = image({
                pos = L{ 0, 0 },
                path = XIV .. 'BgBottom.png',
                size = L{ 377, 21 },
                color = '#FFFFFFDD'
            })
        }),

        listItem = element({
            pos = L{ 0, 0 },

            hp = element({
                pos = L{ 19, -7 },
                hideOutsideZone = false,
                hpYellowColor = '#F3F37CFF',
                hpOrangeColor = '#F8BA80FF',
                hpRedColor = '#FC8182FF',
                hpYellowBarColor = '',
                hpOrangeBarColor = '',
                hpRedBarColor = '',
                snapToRaster = true,
                zOrder = 2,

                txtValue = text({
                    pos = L{ 120, 35 },
                    font = 'Grammara',
                    size = 11,
                    color = '#F0FFFFFF',
                    stroke = '#062D54C8',
                    strokeWidth = 2,
                    alignRight = true,
                    snapToRaster = true
                }),

                bar = element({
                    pos = L{ 0, 0 },
                    animSpeed = 0.1,

                    imgBg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarBG.png',
                        size = L{ 128, 64 }
                    }),
                    imgBar = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'Bar.png',
                        size = L{ 102, 64 }
                    }),
                    imgFg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarFG.png',
                        size = L{ 128, 64 }
                    }),
                    imgGlow = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'BarGlow.png',
                        size = L{ 6, 64 }
                    }),
                    imgGlowSides = image({
                        pos = L{ 11, 0 },
                        path = XIV .. 'BarGlowSides.png',
                        size = L{ 2, 64 }
                    })
                })
            }),

            mp = element({
                pos = L{ 150, -7 },
                hideOutsideZone = false,
                snapToRaster = true,
                zOrder = 3,

                txtValue = text({
                    pos = L{ 120, 35 },
                    font = 'Grammara',
                    size = 11,
                    color = '#F0FFFFFF',
                    stroke = '#062D54C8',
                    strokeWidth = 2,
                    alignRight = true,
                    snapToRaster = true
                }),

                bar = element({
                    pos = L{ 0, 0 },
                    animSpeed = 0.1,

                    imgBg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarBG.png',
                        size = L{ 128, 64 }
                    }),
                    imgBar = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'Bar.png',
                        size = L{ 102, 64 }
                    }),
                    imgFg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarFG.png',
                        size = L{ 128, 64 }
                    }),
                    imgGlow = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'BarGlow.png',
                        size = L{ 6, 64 }
                    }),
                    imgGlowSides = image({
                        pos = L{ 11, 0 },
                        path = XIV .. 'BarGlowSides.png',
                        size = L{ 2, 64 }
                    })
                })
            }),

            tp = element({
                pos = L{ 281, -7 },
                tpFullColor = '#50B4FAFF',
                tpFullBarColor = '',
                hideOutsideZone = false,
                snapToRaster = true,
                zOrder = 4,

                txtValue = text({
                    pos = L{ 120, 35 },
                    font = 'Grammara',
                    size = 11,
                    color = '#F0FFFFFF',
                    stroke = '#062D54C8',
                    strokeWidth = 2,
                    alignRight = true,
                    snapToRaster = true
                }),

                bar = element({
                    pos = L{ 0, 0 },
                    animSpeed = 0.1,

                    imgBg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarBG.png',
                        size = L{ 128, 64 }
                    }),
                    imgBar = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'Bar.png',
                        size = L{ 102, 64 }
                    }),
                    imgFg = image({
                        pos = L{ 0, 0 },
                        path = XIV .. 'BarFG.png',
                        size = L{ 128, 64 }
                    }),
                    imgGlow = image({
                        pos = L{ 13, 0 },
                        path = XIV .. 'BarGlow.png',
                        size = L{ 6, 64 }
                    }),
                    imgGlowSides = image({
                        pos = L{ 11, 0 },
                        path = XIV .. 'BarGlowSides.png',
                        size = L{ 2, 64 }
                    })
                })
            }),

            jobIcon = element({
                pos = L{ -11, -2 },
                path = JOBS .. '',
                snapToRaster = true,
                zOrder = 5,

                colors = {
                    dd = '#663535FF',
                    tank = '#364597FF',
                    healer = '#3B6529FF',
                    support = '#DAB200FF',
                    special = '#FF9700FF'
                },

                imgFrame = image({
                    pos = L{ 0, 0 },
                    path = JOBS .. 'frame.png',
                    size = L{ 36, 36 }
                }),
                imgIcon = image({
                    pos = L{ 0, 0 },
                    path = '',
                    size = L{ 36, 36 }
                }),
                imgGradient = image({
                    pos = L{ 0, 0 },
                    path = JOBS .. 'gradient.png',
                    size = L{ 36, 36 }
                }),
                imgBg = image({
                    pos = L{ 0, 0 },
                    path = JOBS .. 'bg.png',
                    size = L{ 36, 36 },
                    color = '#FFFFFFFF'
                }),
                imgHighlight = image({
                    pos = L{ -13, -13 },
                    path = JOBS .. 'highlight.png',
                    size = L{ 62, 62 }
                })
            }),

            leader = element({
                pos = L{ -23, -6 },
                zOrder = 10,

                imgParty = image({
                    pos = L{ 0, 0 },
                    path = XIV .. 'Leader.png',
                    size = L{ 22, 22 }
                }),
                imgAlliance = image({
                    pos = L{ 0, 11 },
                    path = XIV .. 'AllianceLeader.png',
                    size = L{ 22, 22 }
                }),
                imgQuarterMaster = image({
                    pos = L{ 0, 22 },
                    path = XIV .. 'QuarterMaster.png',
                    size = L{ 22, 22 }
                })
            }),

            range = element({
                pos = L{ 30, 28.5 },
                zOrder = 11,

                imgNear = image({
                    pos = L { 0, 0 },
                    path = XIV .. 'Range.png',
                    size = L{ 14, 12 }
                }),
                imgFar = image({
                    pos = L { 0, 0 },
                    path = XIV .. 'RangeFar.png',
                    size = L{ 14, 12 }
                }),
                txtDistance = text({
                    pos = L{ 0, 1.5 },
                    font = 'Grammara',
                    size = 6,
                    color = '#F0FFFFFF',
                    stroke = '#062D54C8',
                    strokeWidth = 1,
                    snapToRaster = true
                })
            }),

            hover = image({
                pos = L{ 20, -8 },
                path = XIV .. 'Hover.png',
                size = L{ 390, 60 },
                color = '#FFFFFFAA',
                zOrder = 0
            }),

            cursor = image({
                pos = L{ 20, -8 },
                path = XIV .. 'Cursor.png',
                size = L{ 390, 60 },
                zOrder = 1
            }),

            buffIcons = element({
                pos = L{ 293, 0 },
                path = BUFFS .. '',
                size = L{ 20, 20 },
                color = '#FFFFFFFF',
                spacing = L{ 0, 1 },
                numIconsByRow = L{ 19, 13 },
                offsetByRow = L{ 0, 6 },
                alignRight = false,
                zOrder = 12
            }),
            castBar = element({
                enabled = true,
                pos = L{ -11, 26 },
                zOrder = 13,
                snapToRaster = true,

                imgBg = image({
                    enabled = true,
                    pos = L{ 0, 0 },
                    path = XIV .. 'BarBG.png',
                    size = L{ 40, 20 },
                    color = '#000000AA'
                }),
                imgFill = image({
                    enabled = true,
                    pos = L{ 1, 1 },
                    path = XIV .. 'Bar.png',
                    size = L{ 38, 18 },
                    color = '#A0D0FFFF'
                })
            }),
            txtCastSpell = text({
                enabled = true,
                pos = L{ -12, 30 },
                font = 'Constantia',
                size = 11,
                color = '#F0FFFFFF',
                stroke = '#062D54C8',
                strokeWidth = 2,
                snapToRaster = true,
                zOrder = 14
            }),

            txtName = text({
                pos = L{ 95, 1 },
                font = 'Constantia',
                size = 15,
                color = '#F0FFFFFF',
                stroke = '#062D54C8',
                strokeWidth = 2,
                maxChars = 17,
                snapToRaster = true,
                zOrder = 6
            }),
            txtZone = text({
                pos = L{ 292, 1 },
                font = 'Constantia',
                size = 13,
                color = '#F0FFFFFF',
                stroke = '#062D54C8',
                strokeWidth = 2,
                short = false,
                alignRight = false,
                snapToRaster = true,
                zOrder = 7
            }),
            txtJob = text({
                pos = L{ 30, 0 },
                font = 'Constantia',
                size = 8,
                color = '#F0FFFFFF',
                stroke = '#062D54C8',
                strokeWidth = 1,
                snapToRaster = true,
                zOrder = 8
            }),
            txtSubJob = text({
                pos = L{ 39, 9 },
                font = 'Constantia',
                size = 8,
                color = '#F0FFFFFF',
                stroke = '#062D54C8',
                strokeWidth = 1,
                snapToRaster = true,
                zOrder = 9
            })
        })
    }
}

return layout
