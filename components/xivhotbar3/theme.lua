local theme = {}

theme.apply = function(settings)
  local options                   = {}
  local function value_or_default(value, default)
    if value == nil then return default end
    return value
  end

  local sg                        = settings.General
  options.enable_weapon_switching = sg.EnableWeaponSwitching
  options.hide_hotbar_numbers     = sg.HideHotbarNumbers
  options.hide_env                = sg.HideEnvironment
  options.hide_inventory_count    = sg.HideInventoryCount
  options.playing_on_horizon      = sg.PlayingHorizonXI
  options.auto_battle_mode        = sg.AutoBattleMode
  if options.auto_battle_mode == nil then options.auto_battle_mode = true end

  local sh                               = settings.Hotbar
  options.show_description               = sh.ShowActionDescription
  options.hide_empty_slots               = sh.HideEmptySlots
  options.hide_action_names              = sh.HideActionName
  options.hide_action_cost               = sh.HideActionCost
  options.hide_recast_text               = sh.HideRecastText
  options.highlight_magic_burst          = sh.HighlightMagicBurst
  options.highlight_skill_chain          = sh.HighlightSkillchain
  options.use_animated_highlights        = sh.UseAnimatedHighlights
  options.confirm_subtarget_if_necessary = sh.ConfirmSubtargetIfNecessary
  options.slot_icon_scale                = sh.SlotIconScale
  options.offsets                        = {
    ['1'] = { Vertical = sh.Offsets.First.Vertical, OffsetX = sh.Offsets.First.OffsetX, OffsetY = sh.Offsets.First.OffsetY },
    ['2'] = { Vertical = sh.Offsets.Second.Vertical, OffsetX = sh.Offsets.Second.OffsetX, OffsetY = sh.Offsets.Second.OffsetY },
    ['3'] = { Vertical = sh.Offsets.Third.Vertical, OffsetX = sh.Offsets.Third.OffsetX, OffsetY = sh.Offsets.Third.OffsetY },
    ['4'] = { Vertical = sh.Offsets.Fourth.Vertical, OffsetX = sh.Offsets.Fourth.OffsetX, OffsetY = sh.Offsets.Fourth.OffsetY },
    ['5'] = { Vertical = sh.Offsets.Fifth.Vertical, OffsetX = sh.Offsets.Fifth.OffsetX, OffsetY = sh.Offsets.Fifth.OffsetY },
    ['6'] = { Vertical = sh.Offsets.Sixth.Vertical, OffsetX = sh.Offsets.Sixth.OffsetX, OffsetY = sh.Offsets.Sixth.OffsetY }
  }
  options.slot_theme                     = sh.Theme.Slot
  options.frame_theme                    = sh.Theme.Frame
  if _G.XIVUI_THEME == 'ffxi' then
    options.slot_theme, options.frame_theme = 'ffxi', 'ffxi'
  elseif _G.XIVUI_THEME == 'ffxiv' or _G.XIVUI_THEME == 'ffxiv10' then
    options.slot_theme, options.frame_theme = 'ffxiv', 'ffxiv'
  end
  options.hotbar_number                  = sh.Style.HotbarCount
  options.rows                           = sh.Style.HotbarCount
  options.visible_hotbar_count           = sh.Style.VisibleHotbarCount or sh.Style.HotbarCount
  options.field_visible_hotbar_count     = sh.Style.FieldVisibleHotbarCount or nil
  options.columns                        = sh.Style.HotbarLength
  options.slot_opacity                   = sh.Style.SlotAlpha
  options.slot_spacing                   = sh.Style.SlotSpacing
  options.vertical_slot_spacing          = sh.Style.VerticalSlotSpacing or sh.Style.SlotSpacing
  options.show_empty_slot_frames          = sh.Style.ShowEmptySlotFrames or false
  options.hotbar_spacing                 = sh.Style.HotbarSpacing
  options.offset_x                       = sh.Style.OffsetX
  options.offset_y                       = sh.Style.OffsetY
  options.slot_icon_scale                = sh.Style.SlotIconScale

  local choice_bar = sh.ChoiceBar or {}
  options.choice_bar = {}
  options.choice_bar.OffsetX = choice_bar.OffsetX or 675
  options.choice_bar.OffsetY = choice_bar.OffsetY or 740
  options.choice_bar.SlotAlpha = value_or_default(choice_bar.SlotAlpha, 220)
  options.choice_bar.IconAlpha = value_or_default(choice_bar.IconAlpha, value_or_default(options.choice_bar.SlotAlpha, 220))
  options.choice_bar.FrameAlpha = value_or_default(choice_bar.FrameAlpha, value_or_default(options.choice_bar.SlotAlpha, 220))
  options.choice_bar.FrameRed = value_or_default(choice_bar.FrameRed, 80)
  options.choice_bar.FrameGreen = value_or_default(choice_bar.FrameGreen, 190)
  options.choice_bar.FrameBlue = value_or_default(choice_bar.FrameBlue, 255)
  options.choice_bar.BackgroundAlpha = value_or_default(choice_bar.BackgroundAlpha, 145)
  options.choice_bar.KeyRed = value_or_default(choice_bar.KeyRed, 120)
  options.choice_bar.KeyGreen = value_or_default(choice_bar.KeyGreen, 220)
  options.choice_bar.KeyBlue = value_or_default(choice_bar.KeyBlue, 255)
  options.choice_bar.CloseOnExecute = choice_bar.CloseOnExecute
  if options.choice_bar.CloseOnExecute == nil then options.choice_bar.CloseOnExecute = true end
  options.choice_bar.LabelOffsetX = value_or_default(choice_bar.LabelOffsetX, 0)
  options.choice_bar.LabelOffsetY = value_or_default(choice_bar.LabelOffsetY, -26)
  options.choice_bar.IndicatorOffsetX = value_or_default(choice_bar.IndicatorOffsetX, 0)
  options.choice_bar.IndicatorOffsetY = value_or_default(choice_bar.IndicatorOffsetY, -52)
  options.choice_bar.IndicatorText = choice_bar.IndicatorText or 'CHOICE MODE ON'
  local function cbpos(v, fallback) v = tonumber(v); return (v and v > -9000) and v or fallback end
  options.choice_bar.FieldOffsetX = cbpos(choice_bar.FieldOffsetX, options.choice_bar.OffsetX)
  options.choice_bar.FieldOffsetY = cbpos(choice_bar.FieldOffsetY, options.choice_bar.OffsetY)
  options.choice_bar.Scale = value_or_default(choice_bar.Scale, 1)
  options.choice_bar.IndicatorScale = value_or_default(choice_bar.IndicatorScale, 1)
  options.choice_bar.IndicatorBattleX = cbpos(choice_bar.IndicatorBattleX, options.choice_bar.OffsetX + options.choice_bar.IndicatorOffsetX)
  options.choice_bar.IndicatorBattleY = cbpos(choice_bar.IndicatorBattleY, options.choice_bar.OffsetY + options.choice_bar.IndicatorOffsetY)
  options.choice_bar.IndicatorFieldX = cbpos(choice_bar.IndicatorFieldX, options.choice_bar.FieldOffsetX + options.choice_bar.IndicatorOffsetX)
  options.choice_bar.IndicatorFieldY = cbpos(choice_bar.IndicatorFieldY, options.choice_bar.FieldOffsetY + options.choice_bar.IndicatorOffsetY)

  local sr = sh.Recasts or {}
  options.bst_ready_charge_seconds = tonumber(sr.BstReadyChargeSeconds) or 30
  options.scholar_base_recharge_seconds = tonumber(sr.ScholarBaseRechargeSeconds) or 240
  options.scholar_max_charges_cap = tonumber(sr.ScholarMaxChargesCap) or 5

  local behavior = sh.Behavior or {}
  options.reduce_flicker = behavior.ReduceFlicker ~= false
  options.hide_during_zoning = behavior.HideDuringZoning == true
  options.weapon_poll_seconds = tonumber(behavior.WeaponPollSeconds) or 2
  options.weapon_skill_priority = tostring(behavior.WeaponSkillPriority or 'auto'):lower()
  options.ranged_mode = tostring(behavior.RangedMode or 'auto'):lower()
  options.ranged_autopin = behavior.RangedAutoPin ~= false
  options.auto_equip_ammo = behavior.AutoEquipAmmo == true
  options.ammo_source = tostring(behavior.AmmoSource or 'any'):lower()
  if options.ranged_mode == 'off' then options.ranged_autopin = false; options.ranged_mode = 'auto' end
  if options.ranged_mode == 'autora' then options.ranged_mode = 'auto' end
  options.collapse_gaps = behavior.CollapseGaps ~= false
  options.auto_hide_unusable = behavior.AutoHideUnusable == true
  options.choice_drag_merge = behavior.ChoiceDragMerge == true
  options.recast_check_interval_frames = tonumber(behavior.RecastCheckIntervalFrames) or 10
  if options.recast_check_interval_frames < 1 then options.recast_check_interval_frames = 1 end
  if options.recast_check_interval_frames > 120 then options.recast_check_interval_frames = 120 end
  options.hover_check_interval_frames = tonumber(behavior.HoverCheckIntervalFrames) or 3
  if options.hover_check_interval_frames < 1 then options.hover_check_interval_frames = 1 end
  if options.hover_check_interval_frames > 120 then options.hover_check_interval_frames = 120 end
  options.feedback_max_opacity           = sh.Misc.Feedback.Opacity
  options.feedback_speed                 = sh.Misc.Feedback.Speed
  options.disabled_slot_opacity          = sh.Misc.Disabled.Opacity

  local st                               = settings.Texts

  options.font_names                     = st.ActionName.Font
  options.font_size_names                = st.ActionName.Size
  options.font_alpha_names               = st.ActionName.Color.Alpha
  options.font_color_red_names           = st.ActionName.Color.Red
  options.font_color_green_names         = st.ActionName.Color.Green
  options.font_color_blue_names          = st.ActionName.Color.Blue
  options.font_stroke_width_names        = st.ActionName.Stroke.Width
  options.font_stroke_alpha_names        = st.ActionName.Stroke.Alpha
  options.font_stroke_color_red_names    = st.ActionName.Stroke.Red
  options.font_stroke_color_green_names  = st.ActionName.Stroke.Green
  options.font_stroke_color_blue_names   = st.ActionName.Stroke.Blue
  options.font_offset_x_names            = st.ActionName.Pos.OffsetX
  options.font_offset_y_names            = st.ActionName.Pos.OffsetY
  options.font_bg_enable_names           = st.ActionName.Background.Enable
  options.font_bg_opacity_names          = st.ActionName.Background.Opacity

  options.font_keys                       = st.Keys.Font
  options.font_size_keys                  = st.Keys.Size
  options.font_alpha_keys                 = st.Keys.Color.Alpha
  options.font_color_red_keys             = st.Keys.Color.Red
  options.font_color_green_keys           = st.Keys.Color.Green
  options.font_color_blue_keys            = st.Keys.Color.Blue
  options.font_stroke_width_keys          = st.Keys.Stroke.Width
  options.font_stroke_alpha_keys          = st.Keys.Stroke.Alpha
  options.font_stroke_color_red_keys      = st.Keys.Stroke.Red
  options.font_stroke_color_green_keys    = st.Keys.Stroke.Green
  options.font_stroke_color_blue_keys     = st.Keys.Stroke.Blue
  options.text_offset_x_keys              = st.Keys.Pos.OffsetX
  options.text_offset_y_keys              = st.Keys.Pos.OffsetY

  options.font_costs                      = st.Costs.Font
  options.font_size_costs                 = st.Costs.Size
  options.font_stroke_width_costs         = st.Costs.Stroke.Width
  options.font_stroke_alpha_costs         = st.Costs.Stroke.Alpha
  options.font_stroke_color_red_costs     = st.Costs.Stroke.Red
  options.font_stroke_color_green_costs   = st.Costs.Stroke.Green
  options.font_stroke_color_blue_costs    = st.Costs.Stroke.Blue
  options.text_offset_x_costs             = st.Costs.Pos.OffsetX
  options.text_offset_y_costs             = st.Costs.Pos.OffsetY
  options.font_alpha_costs_mp             = st.Costs.MP.Color.Alpha
  options.font_color_red_costs_mp         = st.Costs.MP.Color.Red
  options.font_color_green_costs_mp       = st.Costs.MP.Color.Green
  options.font_color_blue_costs_mp        = st.Costs.MP.Color.Blue
  options.font_alpha_costs_tp             = st.Costs.TP.Color.Alpha
  options.font_color_red_costs_tp         = st.Costs.TP.Color.Red
  options.font_color_green_costs_tp       = st.Costs.TP.Color.Green
  options.font_color_blue_costs_tp        = st.Costs.TP.Color.Blue

  options.font_recasts                    = st.ActionName.Font
  options.font_size_recasts               = st.Recasts.Size + 2
  options.font_alpha_recasts              = st.Recasts.Color.Alpha
  options.font_color_red_recasts          = st.Recasts.Color.Red
  options.font_color_green_recasts        = st.Recasts.Color.Green
  options.font_color_blue_recasts         = st.Recasts.Color.Blue
  options.font_stroke_width_recasts       = st.Recasts.Stroke.Width
  options.font_stroke_alpha_recasts       = st.Recasts.Stroke.Alpha
  options.font_stroke_color_red_recasts   = st.Recasts.Stroke.Red
  options.font_stroke_color_green_recasts = st.Recasts.Stroke.Green
  options.font_stroke_color_blue_recasts  = st.Recasts.Stroke.Blue
  options.text_offset_x_recasts           = st.Recasts.Pos.OffsetX
  options.text_offset_y_recasts           = st.Recasts.Pos.OffsetY

  options.font_hotbar_nums                    = st.HotbarNumbers.Font
  options.font_size_hotbar_nums               = st.HotbarNumbers.Size
  options.font_italics_hotbar_nums            = st.HotbarNumbers.Italics
  options.font_alpha_hotbar_nums              = st.HotbarNumbers.Color.Alpha
  options.font_color_red_hotbar_nums          = st.HotbarNumbers.Color.Red
  options.font_color_green_hotbar_nums        = st.HotbarNumbers.Color.Green
  options.font_color_blue_hotbar_nums         = st.HotbarNumbers.Color.Blue
  options.font_stroke_width_hotbar_nums       = st.HotbarNumbers.Stroke.Width
  options.font_stroke_alpha_hotbar_nums       = st.HotbarNumbers.Stroke.Alpha
  options.font_stroke_color_red_hotbar_nums   = st.HotbarNumbers.Stroke.Red
  options.font_stroke_color_green_hotbar_nums = st.HotbarNumbers.Stroke.Green
  options.font_stroke_color_blue_hotbar_nums  = st.HotbarNumbers.Stroke.Blue
  options.text_offset_x_hotbar_nums           = st.HotbarNumbers.Pos.OffsetX
  options.text_offset_y_hotbar_nums           = st.HotbarNumbers.Pos.OffsetY
  options.text_vert_offset_x_hotbar_nums      = st.HotbarNumbers.Pos.VertOffsetX
  options.text_vert_offset_y_hotbar_nums      = st.HotbarNumbers.Pos.VertOffsetY

  options.font_battle_text_env                = st.Environment.BattleText
  options.font_field_text_env                 = st.Environment.FieldText
  options.hook_onto_bar                       = st.Environment.Pos.HookOntoBar
  options.font_pos_x_env                      = st.Environment.Pos.PosX
  options.font_pos_y_env                      = st.Environment.Pos.PosY
  options.font_offset_x_env                   = st.Environment.Pos.OffsetX
  options.font_offset_y_env                   = st.Environment.Pos.OffsetY
  options.font_hook_offset_x_env              = st.Environment.Pos.HookOffsetX
  options.font_hook_offset_y_env              = st.Environment.Pos.HookOffsetY
  options.font_italics_env                    = st.Environment.Italics
  options.font_env                            = st.Environment.Font
  options.font_size_env                       = st.Environment.Size
  options.env_text_scale                      = tonumber(st.Environment.Scale) or 1
  options.font_alpha_env                      = st.Environment.Color.Alpha
  options.font_color_red_env                  = st.Environment.Color.Red
  options.font_color_green_env                = st.Environment.Color.Green
  options.font_color_blue_env                 = st.Environment.Color.Blue
  options.font_stroke_width_env               = st.Environment.Stroke.Width
  options.font_stroke_alpha_env               = st.Environment.Stroke.Alpha
  options.font_stroke_color_red_env           = st.Environment.Stroke.Red
  options.font_stroke_color_green_env         = st.Environment.Stroke.Green
  options.font_stroke_color_blue_env          = st.Environment.Stroke.Blue

  options.unlock_pos_inv              = st.Inventory.Pos.Unlock
  options.font_pos_x_inv              = st.Inventory.Pos.PosX
  options.font_pos_y_inv              = st.Inventory.Pos.PosY
  options.text_offset_x_inv           = st.Inventory.Pos.OffsetX
  options.text_offset_y_inv           = st.Inventory.Pos.OffsetY
  options.font_italics_inv            = st.Inventory.Italics
  options.font_inv                    = st.Inventory.Font
  options.font_size_inv               = st.Inventory.Size
  options.inv_text_scale              = tonumber(st.Inventory.Scale) or 1
  options.font_alpha_inv              = st.Inventory.Color.Alpha
  options.font_color_red_inv          = st.Inventory.Color.Red
  options.font_color_green_inv        = st.Inventory.Color.Green
  options.font_color_blue_inv         = st.Inventory.Color.Blue
  options.font_stroke_width_inv       = st.Inventory.Stroke.Width
  options.font_stroke_alpha_inv       = st.Inventory.Stroke.Alpha
  options.font_stroke_color_red_inv   = st.Inventory.Stroke.Red
  options.font_stroke_color_green_inv = st.Inventory.Stroke.Green
  options.font_stroke_color_blue_inv  = st.Inventory.Stroke.Blue
  options.font_bg_enable_inv          = st.Inventory.Background.Enable
  options.font_bg_opacity_inv         = st.Inventory.Background.Opacity

  local sadp                            = (st.ActionDescription.Pos or {})
  options.description_box_x            = sadp.OffsetX or 675
  options.description_box_y            = sadp.OffsetY or 688
  options.description_scale            = tonumber(st.ActionDescription.Scale) or 1
  options.font_italics_descr            = st.ActionDescription.Italics
  options.font_descr                    = st.ActionDescription.Font
  options.font_size_descr               = st.ActionDescription.Size
  options.font_alpha_descr              = st.ActionDescription.Color.Alpha
  options.font_color_red_descr          = st.ActionDescription.Color.Red
  options.font_color_green_descr        = st.ActionDescription.Color.Green
  options.font_color_blue_descr         = st.ActionDescription.Color.Blue
  options.font_stroke_width_descr       = st.ActionDescription.Stroke.Width
  options.font_stroke_alpha_descr       = st.ActionDescription.Stroke.Alpha
  options.font_stroke_color_red_descr   = st.ActionDescription.Stroke.Red
  options.font_stroke_color_green_descr = st.ActionDescription.Stroke.Green
  options.font_stroke_color_blue_descr  = st.ActionDescription.Stroke.Blue
  options.font_bg_enable_descr          = st.ActionDescription.Background.Enable
  options.font_bg_opacity_descr         = st.ActionDescription.Background.Opacity

  local so                              = settings.Overlays
  options.disable_scroll                = so.DisableScroll

  local sco = settings.Controls
  options.controls_battle_mode = sco.ToggleBattleMode
options.controls_choice_modifier = sco.ChoiceModifier or 58
options.controls_choice_modifier_shift_required = sco.ChoiceModifierShiftRequired
if options.controls_choice_modifier_shift_required == nil then options.controls_choice_modifier_shift_required = false end
options.controls_choice_modifier_mode = tostring(sco.ChoiceModifierMode or 'toggle'):lower()
if options.controls_choice_modifier_mode == 'one-shot' or options.controls_choice_modifier_mode == 'tap' then
  options.controls_choice_modifier_mode = 'oneshot'
end
if options.controls_choice_modifier_mode ~= 'hold' and options.controls_choice_modifier_mode ~= 'oneshot' and options.controls_choice_modifier_mode ~= 'toggle' then
  options.controls_choice_modifier_mode = 'toggle'
end

  local sd         = settings.Dev
  options.dev_mode = sd.DevMode

  local ara = settings.AutoRA or {}
  options.autora_halt_on_tp = ara.HaltOnTp ~= false
  options.autora_delay = tonumber(ara.Delay) or 1.5
  options.autora_melee_range = tonumber(ara.MeleeRange) or 5.0
  options.autora_melee_mode = tostring(ara.MeleeMode or 'distance'):lower()

  options.count_color_red, options.count_color_green, options.count_color_blue = 255, 255, 255

  if _G.XIVUI_THEME == 'ffxi' then
    local function setc(p, r, g, b)
      options['font_color_red_' .. p] = r; options['font_color_green_' .. p] = g; options['font_color_blue_' .. p] = b
    end
    setc('names',        224, 230, 244)
    setc('keys',         168, 196, 236)
    setc('recasts',      204, 232, 236)
    setc('hotbar_nums',  150, 170, 206)
    setc('env',          190, 210, 232)
    setc('inv',          200, 206, 220)
    setc('descr',        206, 217, 240)
    setc('costs_mp',     150, 184, 246)
    setc('costs_tp',     140, 216, 222)
    options.count_color_red, options.count_color_green, options.count_color_blue = 184, 214, 222
  end

  return options
end

return theme
