-- src/ui/menu.lua
-- 選單定義：所有 tab widget 定義與 main_menu 建立

function create_main_menu()

  -- ── Popup 選單 ────────────────────────────────────────────
  save_file_name = ""
  save_recording_slot_popup = make_menu(71, 61, 312, 122, -- screen size 383,223
  {
    textfield_menu_item("File Name", _G, "save_file_name", ""),
    button_menu_item("Save", save_recording_slot_to_file),
    button_menu_item("Cancel", function() menu_stack_pop(save_recording_slot_popup) end),
  })

  load_file_list = {}
  load_file_index = 1
  load_recording_slot_popup = make_menu(71, 61, 312, 122, -- screen size 383,223
  {
    list_menu_item("File", _G, "load_file_index", load_file_list),
    button_menu_item("Load", load_recording_slot_from_file),
    button_menu_item("Cancel", function() menu_stack_pop(load_recording_slot_popup) end),
  })

  -- ── _replay_file_item ─────────────────────────────────────
  _replay_file_item = list_menu_item("Pattern (P2: ?)", replay_import_state, "file_index", replay_import_files)

  -- disable Pattern Replay Mode / Pattern Replay until Replay Import: Scan has found at least one pattern
  -- no_pattern_available() is defined in 3rd_training.lua (after replay_import_files init)

  -- gray out "Pattern" entry when nothing has been scanned yet
  -- (left/right are already no-ops on a single-element list, so this only changes the color)
  local _replay_file_item_orig_draw = _replay_file_item.draw
  function _replay_file_item:draw(_x, _y, _selected)
    if no_pattern_available() then
      gui.text(_x, _y, self.name.." : "..tostring(self.list[self.object[self.property_name]]), text_disabled_color, text_default_border_color)
      return
    end
    _replay_file_item_orig_draw(self, _x, _y, _selected)
  end

  -- ── Widget 物件定義 ────────────────────────────────────────
  life_refill_delay_item = integer_menu_item("Life refill delay", training_settings, "life_refill_delay", 1, 100, false, 20)
  life_refill_delay_item.is_disabled = function()
    return training_settings.life_mode ~= 2
  end

  p1_stun_reset_value_gauge_item = gauge_menu_item("P1 Stun reset value", training_settings, "p1_stun_reset_value", 64, 0xFF0000FF)
  p2_stun_reset_value_gauge_item = gauge_menu_item("P2 Stun reset value", training_settings, "p2_stun_reset_value", 64, 0xFF0000FF)
  p1_stun_reset_value_gauge_item.unit = 1
  p2_stun_reset_value_gauge_item.unit = 1
  stun_reset_delay_item = integer_menu_item("Stun reset delay", training_settings, "stun_reset_delay", 1, 100, false, 20)
  p1_stun_reset_value_gauge_item.is_disabled = function()
    return training_settings.stun_mode ~= 3
  end
  p2_stun_reset_value_gauge_item.is_disabled = p1_stun_reset_value_gauge_item.is_disabled
  stun_reset_delay_item.is_disabled = p1_stun_reset_value_gauge_item.is_disabled

  p1_meter_gauge_item = gauge_menu_item("P1 Meter", training_settings, "p1_meter", 2, 0x0000FFFF)
  p2_meter_gauge_item = gauge_menu_item("P2 Meter", training_settings, "p2_meter", 2, 0x0000FFFF)
  meter_refill_delay_item = integer_menu_item("Meter refill delay", training_settings, "meter_refill_delay", 1, 100, false, 20)

  p1_meter_gauge_item.is_disabled = function()
    return training_settings.meter_mode ~= 2
  end
  p2_meter_gauge_item.is_disabled = p1_meter_gauge_item.is_disabled
  meter_refill_delay_item.is_disabled = p1_meter_gauge_item.is_disabled

  slot_weight_item = integer_menu_item("Weight", nil, "weight", 0, 100, false, 1)
  counter_attack_delay_item = integer_menu_item("Counter-attack delay", nil, "delay", -40, 40, false, 0)
  counter_attack_random_deviation_item = integer_menu_item("Counter-attack max random deviation", nil, "random_deviation", -600, 600, false, 0, 1)

  parry_forward_on_item = checkbox_menu_item("Forward Parry Helper", training_settings, "special_training_parry_forward_on")
  parry_forward_on_item.is_disabled = function() return training_settings.special_training_current_mode ~= 2 end
  parry_down_on_item = checkbox_menu_item("Down Parry Helper", training_settings, "special_training_parry_down_on")
  parry_down_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_air_on_item = checkbox_menu_item("Air Parry Helper", training_settings, "special_training_parry_air_on")
  parry_air_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_antiair_on_item = checkbox_menu_item("Anti-Air Parry Helper", training_settings, "special_training_parry_antiair_on")
  parry_antiair_on_item.is_disabled = parry_forward_on_item.is_disabled

  charge_overcharge_on_item = checkbox_menu_item("Display Overcharge", training_settings, "special_training_charge_overcharge_on")
  charge_overcharge_on_item.is_disabled = function() return training_settings.special_training_current_mode ~= 3 end

  hits_before_red_parry_item = integer_menu_item("Hits before Red Parry", training_settings, "red_parry_hit_count", 1, 20, true)
  hits_before_red_parry_item.is_disabled = function()
    return training_settings.blocking_style ~= 4
  end
  hits_before_red_parry_item.indent = true

  display_p2_input_history_item = checkbox_menu_item("Display P2 Input History", training_settings, "display_p2_input_history")
  display_p2_input_history_item.is_disabled = function() return training_settings.display_p1_input_history_dynamic end

  replay_slot_item = list_menu_item("Replay Mission for Slot", training_settings, "current_replay_mission_slot", mission_recording_slots_names)

  -- disable Replay Mission / Play Side when no non-empty replay slot is selected
  function no_replay_slot_selected()
    if training_settings.current_replay_mission_slot == 1 then return true end
    local _slot = mission_slots[training_settings.current_replay_mission_slot - 1]
    return _slot == nil or _slot.name == "none"
  end

  pattern_replay_mode_item = list_menu_item("Pattern Replay Mode", training_settings, "pattern_replay_mode", pattern_replay_mode_options)
  pattern_replay_mode_item.is_disabled = no_pattern_available

  direct_play_item = checkbox_menu_item("Pattern Replay", training_settings, "pattern_replay_on", nil, {"Start", "Stop"})
  direct_play_item.is_disabled = no_pattern_available

  replay_mission_item = checkbox_menu_item("Replay Mission", training_settings, "mission_replay_on", nil, {"Start", "Stop"})
  replay_mission_item.is_disabled = function()
    if training_settings.recording_mission_mode then return true end
    return no_replay_slot_selected()
  end

  recording_mission_mode_item = checkbox_menu_item("Recording Mission Mode", training_settings, "recording_mission_mode", nil, {"On", "Off"})

  change_characters_item = button_menu_item("Select Characters", start_character_select_sequence)
  change_characters_item.is_disabled = function()
    -- not implemented for 4rd strike yet
    return rom_name ~= "sfiii3nr1"
  end

  p1_distances_reference_point_item = list_menu_item("P1 Distance Reference Point", training_settings, "p1_distances_reference_point", distance_display_reference_point)
  p1_distances_reference_point_item.is_disabled = function()
    return not training_settings.display_distances
  end

  p2_distances_reference_point_item = list_menu_item("P2 Distance Reference Point", training_settings, "p2_distances_reference_point", distance_display_reference_point)
  p2_distances_reference_point_item.is_disabled = function()
    return not training_settings.display_distances
  end
  mid_distance_height_item = integer_menu_item("Mid Distance Height", training_settings, "mid_distance_height", 0, 200, false, 10)
  mid_distance_height_item.is_disabled = function()
    return not training_settings.display_distances
  end

  -- ── Main Menu 建立 ─────────────────────────────────────────
  main_menu = make_multitab_menu(
    23, 15, 360, 195, -- screen size 383,223
    {
      {
        name = "Dummy",
        entries = {
          list_menu_item("Pose", training_settings, "pose", pose),
          list_menu_item("Blocking Style", training_settings, "blocking_style", blocking_style),
          hits_before_red_parry_item,
          list_menu_item("Tech Throws", training_settings, "tech_throws_mode", tech_throws_mode),
          list_menu_item("Counter-Attack Move", training_settings, "counter_attack_stick", stick_gesture),
          list_menu_item("Counter-Attack Action", training_settings, "counter_attack_button", button_gesture),
          list_menu_item("Fast Wake Up", training_settings, "fast_wakeup_mode", fast_wakeup_mode),
        }
      },
      {
        name = "Recording",
        entries = {
          checkbox_menu_item("Auto Crop First Frames", training_settings, "auto_crop_recording_start"),
          checkbox_menu_item("Auto Crop Last Frames", training_settings, "auto_crop_recording_end"),
          list_menu_item("Replay Mode", training_settings, "replay_mode", slot_replay_mode),
          list_menu_item("Slot", training_settings, "current_recording_slot", recording_slots_names),
          slot_weight_item,
          counter_attack_delay_item,
          counter_attack_random_deviation_item,
          button_menu_item("Clear Slot", clear_slot),
          button_menu_item("Clear All Slots", clear_all_slots),
          button_menu_item("Save Slot To File", open_save_popup),
          button_menu_item("Load Slot From File", open_load_popup),
        }
      },
      {
        name = "Missions",
        entries = {
          recording_mission_mode_item,
          list_menu_item("Record Mission in Slot", training_settings, "current_mission_slot", mission_slot_names),
          replay_slot_item,
          (function()
            local _item = list_menu_item("Play Side", training_settings, "mission_play_side", mission_play_side_names)
            _item.is_disabled = function()
              return training_settings.recording_mission_mode or no_replay_slot_selected()
            end
            return _item
          end)(),
          replay_mission_item,
          (function()
            local _item = list_menu_item("Clear Slot", training_settings, "current_clear_mission_slot", mission_recording_slots_names)
            _item.last_frame_validated = 0
            _item.validate = function(self)
              if training_settings.current_clear_mission_slot ~= 1 then
                clear_mission_slot()
                training_settings.current_clear_mission_slot = 1
                self.last_frame_validated = frame_number
              end
            end
            _item.legend = function() return "LP: Validate | MP: Reset to default" end
            local _orig_draw = _item.draw
            _item.draw = function(self, _x, _y, _selected)
              if _selected and self.last_frame_validated > 0 then
                if frame_number < self.last_frame_validated then self.last_frame_validated = 0 end
                if frame_number - self.last_frame_validated < 5 then
                  gui.text(_x, _y, "< Clear Slot : "..mission_recording_slots_names[training_settings.current_clear_mission_slot].." >", 0xFFFF00FF, text_default_border_color)
                  return
                end
              end
              _orig_draw(self, _x, _y, _selected)
            end
            return _item
          end)(),
          button_menu_item("Clear All Mission Slots", clear_all_mission_slots),
          button_menu_item("-- Replay Import: Scan --", scan_replay_files),
          _replay_file_item,
          pattern_replay_mode_item,
          direct_play_item,
        }
      },
      {
        name = "Display",
        entries = {
          checkbox_menu_item("Display Controllers", training_settings, "display_input"),
          checkbox_menu_item("Display Gauges Numbers", training_settings, "display_gauges"),
          checkbox_menu_item("Display P1 Input History", training_settings, "display_p1_input_history"),
          checkbox_menu_item("Dynamic P1 Input History", training_settings, "display_p1_input_history_dynamic"),
          display_p2_input_history_item,
          checkbox_menu_item("Display Damage Info", training_settings, "display_attack_data"),
          checkbox_menu_item("Display Frame Advantage", training_settings, "display_frame_advantage"),
          checkbox_menu_item("Display Frame Table", training_settings, "display_frame_table"),
          checkbox_menu_item("Display Hitboxes", training_settings, "display_hitboxes"),
          checkbox_menu_item("Display Distances", training_settings, "display_distances"),
          mid_distance_height_item,
          p1_distances_reference_point_item,
          p2_distances_reference_point_item,
        }
      },
      {
        name = "Rules",
        entries = {
          change_characters_item,
          checkbox_menu_item("Infinite Time", training_settings, "infinite_time"),
          list_menu_item("Life Refill Mode", training_settings, "life_mode", life_mode),
          life_refill_delay_item,
          list_menu_item("Stun Mode", training_settings, "stun_mode", stun_mode),
          p1_stun_reset_value_gauge_item,
          p2_stun_reset_value_gauge_item,
          stun_reset_delay_item,
          list_menu_item("Meter Refill Mode", training_settings, "meter_mode", meter_mode),
          p1_meter_gauge_item,
          p2_meter_gauge_item,
          meter_refill_delay_item,
          checkbox_menu_item("Infinite Super Art Time", training_settings, "infinite_sa_time"),
          integer_menu_item("Music Volume", training_settings, "music_volume", 0, 10, false, 10),
          checkbox_menu_item("Speed Up Game Intro", training_settings, "fast_forward_intro"),
        }
      },
      {
        name = "Special Training",
        entries = {
          list_menu_item("Mode", training_settings, "special_training_current_mode", special_training_mode),
          (function()
            local _item = checkbox_menu_item("Follow Character", training_settings, "special_training_follow_character")
            _item.is_disabled = function()
              local _m = training_settings.special_training_current_mode
              return _m == 1 or special_training_mode[_m] == "Juggle" or special_training_mode[_m] == "Tech Throw"
            end
            return _item
          end)(),
          parry_forward_on_item,
          parry_down_on_item,
          parry_air_on_item,
          parry_antiair_on_item,
          charge_overcharge_on_item
        }
      },
    },
    function ()
      save_training_data()
    end,
    function(_menu)
      -- recording slots special display
      if _menu.main_menu_selected_index == 2 and not training_settings.recording_mission_mode then
        local _t = string.format("%d frames", #recording_slots[training_settings.current_recording_slot].inputs)
        gui.text(_menu.left + 83, _menu.top + 23 + 3 * menu_y_interval, _t, text_disabled_color, text_default_border_color)
      end

      -- Special Training tab: mode descriptions
      if _menu.main_menu_selected_index == 6 and special_training_mode[training_settings.special_training_current_mode] == "Tech Throw" then
        local _dx = _menu.left + 160
        local _dy = _menu.top + 23
        local _c = text_disabled_color
        local _b = text_default_border_color
        gui.text(_dx, _dy,      "Green bar: 5F tech window (press LP+LK)", _c, _b)
        gui.text(_dx, _dy + 10, "Orange bar: fwd/down parry validity", _c, _b)
        gui.text(_dx, _dy + 20, "Parry active = can't tech throw", _c, _b)
      end

      if _menu.main_menu_selected_index == 6 and special_training_mode[training_settings.special_training_current_mode] == "Juggle" then
        local _dx = _menu.left + 160
        local _dy = _menu.top + 23
        local _c = text_disabled_color
        local _b = text_default_border_color
        gui.text(_dx, _dy,      "Gauge: remaining air hitstun", _c, _b)
        gui.text(_dx, _dy + 10, "Ticks: initial frames by juggle count", _c, _b)
        gui.text(_dx, _dy + 20, "1->121  2->101  3->81  4->61", _c, _b)
        gui.text(_dx, _dy + 30, "5->41   6->21   7->11  8->5", _c, _b)
        gui.text(_dx, _dy + 40, "9->2    10+->1", _c, _b)
      end

      -- Display tab: color legends in the right-side blank space, only while the
      -- corresponding entry is selected and its display is turned on
      if not _menu.is_main_menu_selected and _menu.main_menu_selected_index == 4 then
        local _legend_x = _menu.left + 160
        if _menu.sub_menu_selected_index == 8 and training_settings.display_frame_table then
          local _legend_y = _menu.top + 23 + (8 - 1) * menu_y_interval - 1
          frame_table_legend_display(_legend_x, _legend_y)
        elseif _menu.sub_menu_selected_index == 9 and training_settings.display_hitboxes then
          local _legend_y = _menu.top + 23 + (9 - 1) * menu_y_interval - 1
          hitbox_legend_display(_legend_x, _legend_y)
        end
      end
    end
  )

  -- ── 後處理：動態 disable 邏輯 ──────────────────────────────

  -- Gray out Dummy (1), Recording (2), Rules (5), Special Training (6) when recording_mission_mode is ON
  for _, _tab_index in ipairs({1, 2, 5, 6}) do
    for _, _entry in ipairs(main_menu.content[_tab_index].entries) do
      local _orig = _entry.is_disabled
      if _orig then
        _entry.is_disabled = function() return training_settings.recording_mission_mode or _orig() end
      else
        _entry.is_disabled = function() return training_settings.recording_mission_mode end
      end
    end
  end

  -- Gray out Dummy (1) when mission_replay_on is ON
  for _, _entry in ipairs(main_menu.content[1].entries) do
    local _orig = _entry.is_disabled
    if _orig then
      _entry.is_disabled = function() return training_settings.mission_replay_on or _orig() end
    else
      _entry.is_disabled = function() return training_settings.mission_replay_on end
    end
  end

  -- Gray out Replay Mission for Slot (3), Play Side (4), Replay Mission (5), Clear Mission Slot (6), Clear All Mission Slots (7) in Missions tab (3)
  for _entry_index = 3, 7 do
    local _entry = main_menu.content[3].entries[_entry_index]
    if _entry then
      local _orig = _entry.is_disabled
      if _orig then
        _entry.is_disabled = function() return training_settings.recording_mission_mode or _orig() end
      else
        _entry.is_disabled = function() return training_settings.recording_mission_mode end
      end
    end
  end

  -- ── Debug Tab（developer_mode 才加）────────────────────────
  debug_move_menu_item = map_menu_item("Debug Move", debug_settings, "debug_move", frame_data, nil)
  if developer_mode then
    local _debug_settings_menu = {
      name = "Debug",
      entries = {
        checkbox_menu_item("Show Predicted Hitboxes", debug_settings, "show_predicted_hitbox"),
        checkbox_menu_item("Record Frame Data", debug_settings, "record_framedata"),
        checkbox_menu_item("Record Idle Frame Data", debug_settings, "record_idle_framedata"),
        checkbox_menu_item("Record Wake-Up Data", debug_settings, "record_wakeupdata"),
        button_menu_item("Save Frame Data", save_frame_data),
        map_menu_item("Debug Character", debug_settings, "debug_character", _G, "frame_data"),
        debug_move_menu_item
      }
    }
    table.insert(main_menu.content, _debug_settings_menu)
  end

  return main_menu
end
