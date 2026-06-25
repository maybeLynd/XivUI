local defaults = {}

defaults.General                             = {}
defaults.General.HideEnvironment             = false
defaults.General.HideInventoryCount          = false
defaults.General.EnableWeaponSwitching       = true
defaults.General.HideHotbarNumbers           = true
defaults.General.PlayingHorizonXI            = false
defaults.General.AutoBattleMode              = true

defaults.HotbarSets                          = {}
defaults.HotbarSets.Visible                  = false
defaults.HotbarSets.Spacing                  = 34
defaults.HotbarSets.DotScale                 = 1.0
defaults.HotbarSets.Pos                      = {}
defaults.HotbarSets.Pos.X                    = 1380
defaults.HotbarSets.Pos.Y                    = 980

defaults.Hotbar                              = {}
defaults.Hotbar.StyleName                    = 'xiv'
defaults.Hotbar.ShowActionDescription        = true
defaults.Hotbar.HideEmptySlots               = false
defaults.Hotbar.HideActionName               = true
defaults.Hotbar.HideActionCost               = false
defaults.Hotbar.HighlightMagicBurst          = true
defaults.Hotbar.HighlightSkillchain          = true
defaults.Hotbar.UseAnimatedHighlights        = true
defaults.Hotbar.ConfirmSubtargetIfNecessary  = true

defaults.Hotbar.Offsets                      = {}
defaults.Hotbar.Offsets.First                = { Vertical = false, OffsetX = 675, OffsetY = 1010 }
defaults.Hotbar.Offsets.Second               = { Vertical = false, OffsetX = 675, OffsetY = 956 }
defaults.Hotbar.Offsets.Third                = { Vertical = false, OffsetX = 675, OffsetY = 902 }
defaults.Hotbar.Offsets.Fourth               = { Vertical = false, OffsetX = 675, OffsetY = 848 }
defaults.Hotbar.Offsets.Fifth                = { Vertical = true, OffsetX = 1380, OffsetY = 740 }
defaults.Hotbar.Offsets.Sixth                = { Vertical = true, OffsetX = 1490, OffsetY = 740 }

defaults.Hotbar.Theme                        = {}
defaults.Hotbar.Theme.Slot                   = 'ffxiv'
defaults.Hotbar.Theme.Frame                  = 'ffxiv'

defaults.Hotbar.Style                        = {}
defaults.Hotbar.Style.HotbarCount            = 6
defaults.Hotbar.Style.VisibleHotbarCount     = 6
defaults.Hotbar.Style.FieldVisibleHotbarCount = nil
defaults.Hotbar.Style.HotbarLength           = 12
defaults.Hotbar.Style.SlotIconScale          = 1
defaults.Hotbar.Style.SlotAlpha              = 200
defaults.Hotbar.Style.SlotSpacing            = 4
defaults.Hotbar.Style.VerticalSlotSpacing    = 4
defaults.Hotbar.Style.ShowEmptySlotFrames     = true
defaults.Hotbar.Style.HotbarSpacing          = 48
defaults.Hotbar.Style.OffsetX                = 0
defaults.Hotbar.Style.OffsetY                = 0

defaults.Hotbar.ChoiceBar                  = {}
defaults.Hotbar.ChoiceBar.OffsetX          = 675
defaults.Hotbar.ChoiceBar.OffsetY          = 740
defaults.Hotbar.ChoiceBar.SlotAlpha        = 185
defaults.Hotbar.ChoiceBar.IconAlpha        = 185
defaults.Hotbar.ChoiceBar.FrameAlpha       = 170
defaults.Hotbar.ChoiceBar.FrameRed         = 80
defaults.Hotbar.ChoiceBar.FrameGreen       = 190
defaults.Hotbar.ChoiceBar.FrameBlue        = 255
defaults.Hotbar.ChoiceBar.BackgroundAlpha  = 0
defaults.Hotbar.ChoiceBar.KeyRed           = 120
defaults.Hotbar.ChoiceBar.KeyGreen         = 220
defaults.Hotbar.ChoiceBar.KeyBlue          = 255
defaults.Hotbar.ChoiceBar.CloseOnExecute   = true
defaults.Hotbar.ChoiceBar.LabelOffsetX     = 0
defaults.Hotbar.ChoiceBar.LabelOffsetY     = -26
defaults.Hotbar.ChoiceBar.IndicatorOffsetX = 0
defaults.Hotbar.ChoiceBar.IndicatorOffsetY = -52
defaults.Hotbar.ChoiceBar.IndicatorText    = 'CHOICE MODE ON'
defaults.Hotbar.ChoiceBar.FieldOffsetX     = -99999
defaults.Hotbar.ChoiceBar.FieldOffsetY     = -99999
defaults.Hotbar.ChoiceBar.Scale            = 1
defaults.Hotbar.ChoiceBar.IndicatorScale   = 1
defaults.Hotbar.ChoiceBar.IndicatorBattleX = -99999
defaults.Hotbar.ChoiceBar.IndicatorBattleY = -99999
defaults.Hotbar.ChoiceBar.IndicatorFieldX  = -99999
defaults.Hotbar.ChoiceBar.IndicatorFieldY  = -99999

defaults.Hotbar.Recasts                    = {}
defaults.Hotbar.Recasts.BstReadyChargeSeconds = 30
defaults.Hotbar.Recasts.ScholarBaseRechargeSeconds = 240
defaults.Hotbar.Recasts.ScholarMaxChargesCap = 5

defaults.Hotbar.Behavior                   = {}
defaults.Hotbar.Behavior.ReduceFlicker     = true
defaults.Hotbar.Behavior.HideDuringZoning  = false
defaults.Hotbar.Behavior.RangedAutoPin     = false
defaults.Hotbar.Behavior.AutoEquipAmmo     = false
defaults.Hotbar.Behavior.AmmoSource        = 'any'
defaults.Hotbar.Behavior.RangedMode        = 'auto'
defaults.Hotbar.Behavior.CollapseGaps      = false
defaults.Hotbar.Behavior.AutoHideUnusable  = false
defaults.Hotbar.Behavior.ChoiceDragMerge   = false
defaults.Hotbar.Behavior.WeaponPollSeconds  = 2
defaults.Hotbar.Behavior.WeaponSkillPriority = 'auto'
defaults.Hotbar.Behavior.RecastCheckIntervalFrames = 10
defaults.Hotbar.Behavior.HoverCheckIntervalFrames  = 3

defaults.Hotbar.Misc                         = {}
defaults.Hotbar.Misc.Feedback                = {}
defaults.Hotbar.Misc.Feedback.Opacity        = 150
defaults.Hotbar.Misc.Feedback.Speed          = 30
defaults.Hotbar.Misc.Disabled                = {}
defaults.Hotbar.Misc.Disabled.Opacity        = 50

defaults.AutoRA                              = {}
defaults.AutoRA.HaltOnTp                     = true
defaults.AutoRA.Delay                        = 1.5
defaults.AutoRA.MeleeMode                    = 'distance'
defaults.AutoRA.MeleeRange                   = 5.0

defaults.Texts                               = {}

defaults.Texts.ActionName                    = {}
defaults.Texts.ActionName.Font               = 'Constantia'
defaults.Texts.ActionName.Size               = 10
defaults.Texts.ActionName.Pos                = {}
defaults.Texts.ActionName.Pos.OffsetX        = -1
defaults.Texts.ActionName.Pos.OffsetY        = 37
defaults.Texts.ActionName.Color              = {}
defaults.Texts.ActionName.Color.Alpha        = 255
defaults.Texts.ActionName.Color.Red          = 255
defaults.Texts.ActionName.Color.Green        = 255
defaults.Texts.ActionName.Color.Blue         = 255
defaults.Texts.ActionName.Stroke             = {}
defaults.Texts.ActionName.Stroke.Width       = 2
defaults.Texts.ActionName.Stroke.Alpha       = 200
defaults.Texts.ActionName.Stroke.Red         = 20
defaults.Texts.ActionName.Stroke.Green       = 20
defaults.Texts.ActionName.Stroke.Blue        = 20
defaults.Texts.ActionName.Background         = {}
defaults.Texts.ActionName.Background.Enable  = false
defaults.Texts.ActionName.Background.Opacity = 100

defaults.Texts.Keys                          = {}
defaults.Texts.Keys.Font                     = 'Calibri'
defaults.Texts.Keys.Size                     = 9
defaults.Texts.Keys.Pos                      = {}
defaults.Texts.Keys.Pos.OffsetX              = -1
defaults.Texts.Keys.Pos.OffsetY              = -4
defaults.Texts.Keys.Color                    = {}
defaults.Texts.Keys.Color.Alpha              = 255
defaults.Texts.Keys.Color.Red                = 255
defaults.Texts.Keys.Color.Green              = 255
defaults.Texts.Keys.Color.Blue               = 255
defaults.Texts.Keys.Stroke                   = {}
defaults.Texts.Keys.Stroke.Width             = 2
defaults.Texts.Keys.Stroke.Alpha             = 200
defaults.Texts.Keys.Stroke.Red               = 20
defaults.Texts.Keys.Stroke.Green             = 20
defaults.Texts.Keys.Stroke.Blue              = 20

defaults.Texts.Costs                         = {}

defaults.Texts.Costs.Font                    = 'Calibri'
defaults.Texts.Costs.Size                    = 10
defaults.Texts.Costs.Pos                     = {}
defaults.Texts.Costs.Pos.OffsetX             = 1
defaults.Texts.Costs.Pos.OffsetY             = 24
defaults.Texts.Costs.Stroke                  = {}
defaults.Texts.Costs.Stroke.Width            = 2
defaults.Texts.Costs.Stroke.Alpha            = 200
defaults.Texts.Costs.Stroke.Red              = 20
defaults.Texts.Costs.Stroke.Green            = 20
defaults.Texts.Costs.Stroke.Blue             = 20

defaults.Texts.Costs.MP                      = {}
defaults.Texts.Costs.MP.Color                = {}
defaults.Texts.Costs.MP.Color.Alpha          = 255
defaults.Texts.Costs.MP.Color.Red            = 0
defaults.Texts.Costs.MP.Color.Green          = 240
defaults.Texts.Costs.MP.Color.Blue           = 120
defaults.Texts.Costs.TP                      = {}
defaults.Texts.Costs.TP.Color                = {}
defaults.Texts.Costs.TP.Color.Alpha          = 255
defaults.Texts.Costs.TP.Color.Red            = 240
defaults.Texts.Costs.TP.Color.Green          = 120
defaults.Texts.Costs.TP.Color.Blue           = 120

defaults.Texts.Recasts                       = {}
defaults.Texts.Recasts.Font                  = 'Arial'
defaults.Texts.Recasts.Size                  = 10
defaults.Texts.Recasts.Pos                   = {}
defaults.Texts.Recasts.Pos.OffsetX           = 11
defaults.Texts.Recasts.Pos.OffsetY           = 12
defaults.Texts.Recasts.Color                 = {}
defaults.Texts.Recasts.Color.Alpha           = 255
defaults.Texts.Recasts.Color.Red             = 255
defaults.Texts.Recasts.Color.Green           = 255
defaults.Texts.Recasts.Color.Blue            = 255
defaults.Texts.Recasts.Stroke                = {}
defaults.Texts.Recasts.Stroke.Width          = 1
defaults.Texts.Recasts.Stroke.Alpha          = 220
defaults.Texts.Recasts.Stroke.Red            = 0
defaults.Texts.Recasts.Stroke.Green          = 0
defaults.Texts.Recasts.Stroke.Blue           = 0

defaults.Texts.HotbarNumbers = {}
defaults.Texts.HotbarNumbers.Font = 'Calibri'
defaults.Texts.HotbarNumbers.Size = 13
defaults.Texts.HotbarNumbers.Italics = true
defaults.Texts.HotbarNumbers.Pos = {}
defaults.Texts.HotbarNumbers.Pos.OffsetX = -20
defaults.Texts.HotbarNumbers.Pos.OffsetY = 9
defaults.Texts.HotbarNumbers.Pos.VertOffsetX = 42
defaults.Texts.HotbarNumbers.Pos.VertOffsetY = -30
defaults.Texts.HotbarNumbers.Color = {}
defaults.Texts.HotbarNumbers.Color.Alpha = 255
defaults.Texts.HotbarNumbers.Color.Red = 200
defaults.Texts.HotbarNumbers.Color.Green = 200
defaults.Texts.HotbarNumbers.Color.Blue = 200
defaults.Texts.HotbarNumbers.Stroke = {}
defaults.Texts.HotbarNumbers.Stroke.Width = 2
defaults.Texts.HotbarNumbers.Stroke.Alpha = 200
defaults.Texts.HotbarNumbers.Stroke.Red = 20
defaults.Texts.HotbarNumbers.Stroke.Green = 20
defaults.Texts.HotbarNumbers.Stroke.Blue = 20

defaults.Texts.Environment = {}
defaults.Texts.Environment.BattleText = 'Main'
defaults.Texts.Environment.FieldText = 'General'
defaults.Texts.Environment.Pos = {}
defaults.Texts.Environment.Pos.HookOntoBar = 1
defaults.Texts.Environment.Pos.PosX = 0
defaults.Texts.Environment.Pos.PosY = 0
defaults.Texts.Environment.Pos.OffsetX = 0
defaults.Texts.Environment.Pos.OffsetY = 17
defaults.Texts.Environment.Pos.HookOffsetX = -8
defaults.Texts.Environment.Pos.HookOffsetY = 0
defaults.Texts.Environment.Italics = true
defaults.Texts.Environment.Font = 'Constantia'
defaults.Texts.Environment.Size = 12
defaults.Texts.Environment.Scale = 1
defaults.Texts.Environment.Color = {}
defaults.Texts.Environment.Color.Alpha = 255
defaults.Texts.Environment.Color.Red = 255
defaults.Texts.Environment.Color.Green = 255
defaults.Texts.Environment.Color.Blue = 255
defaults.Texts.Environment.Stroke = {}
defaults.Texts.Environment.Stroke.Width = 2
defaults.Texts.Environment.Stroke.Alpha = 200
defaults.Texts.Environment.Stroke.Red = 20
defaults.Texts.Environment.Stroke.Green = 20
defaults.Texts.Environment.Stroke.Blue = 20

defaults.Texts.Inventory = {}
defaults.Texts.Inventory.Pos = {}
defaults.Texts.Inventory.Pos.Unlock = false
defaults.Texts.Inventory.Pos.PosX = 1135
defaults.Texts.Inventory.Pos.PosY = 820
defaults.Texts.Inventory.Pos.OffsetX = -8
defaults.Texts.Inventory.Pos.OffsetY = 36
defaults.Texts.Inventory.Italics = true
defaults.Texts.Inventory.Font = 'Constantia'
defaults.Texts.Inventory.Size = 11
defaults.Texts.Inventory.Scale = 1
defaults.Texts.Inventory.Color = {}
defaults.Texts.Inventory.Color.Alpha = 255
defaults.Texts.Inventory.Color.Red = 255
defaults.Texts.Inventory.Color.Green = 255
defaults.Texts.Inventory.Color.Blue = 255
defaults.Texts.Inventory.Stroke = {}
defaults.Texts.Inventory.Stroke.Width = 2
defaults.Texts.Inventory.Stroke.Alpha = 200
defaults.Texts.Inventory.Stroke.Red = 20
defaults.Texts.Inventory.Stroke.Green = 20
defaults.Texts.Inventory.Stroke.Blue = 20
defaults.Texts.Inventory.Background = {}
defaults.Texts.Inventory.Background.Enable = false
defaults.Texts.Inventory.Background.Opacity = 100

defaults.Texts.ActionDescription = {}
defaults.Texts.ActionDescription.Pos = {}
defaults.Texts.ActionDescription.Pos.OffsetX = 675
defaults.Texts.ActionDescription.Pos.OffsetY = 688
defaults.Texts.ActionDescription.Italics = true
defaults.Texts.ActionDescription.Font = 'Constantia'
defaults.Texts.ActionDescription.Size = 9
defaults.Texts.ActionDescription.Scale = 1
defaults.Texts.ActionDescription.Color = {}
defaults.Texts.ActionDescription.Color.Alpha = 255
defaults.Texts.ActionDescription.Color.Red = 255
defaults.Texts.ActionDescription.Color.Green = 255
defaults.Texts.ActionDescription.Color.Blue = 255
defaults.Texts.ActionDescription.Stroke = {}
defaults.Texts.ActionDescription.Stroke.Width = 3
defaults.Texts.ActionDescription.Stroke.Alpha = 200
defaults.Texts.ActionDescription.Stroke.Red = 20
defaults.Texts.ActionDescription.Stroke.Green = 20
defaults.Texts.ActionDescription.Stroke.Blue = 20
defaults.Texts.ActionDescription.Background = {}
defaults.Texts.ActionDescription.Background.Enable = true
defaults.Texts.ActionDescription.Background.Opacity = 180

defaults.Overlays = {}
defaults.Overlays.DisableScroll = false

defaults.Controls = {}
defaults.Controls.ToggleBattleMode = 43
defaults.Controls.ChoiceModifier = 58
defaults.Controls.ChoiceModifierShiftRequired = false
defaults.Controls.ChoiceModifierMode = 'toggle'

defaults.Dev = {}
defaults.Dev.DevMode = false
defaults.Keybinds = {}

return defaults
