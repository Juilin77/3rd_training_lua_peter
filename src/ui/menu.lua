-- src/ui/menu.lua
-- menu definitions: all tab widget definitions and main_menu construction

function create_main_menu()

  -- ── popup menu ────────────────────────────────────────────
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

  save_profile_name = ""
  save_profile_popup = make_menu(71, 61, 312, 122, -- screen size 383,223
  {
    -- max_length 28 instead of the default 16: the "PROFILE_" prefix plus the
    -- longest character name ("CHUNLI"/"MAKOTO", 6 chars) plus "_" already
    -- takes 15, which would leave almost no room for an actual purpose suffix
    -- at the default length. Still comfortably fits this popup's 241px width
    -- at 4px/char. Only this field is extended, not the shared textfield default.
    textfield_menu_item("Profile Name", _G, "save_profile_name", "", 28),
    button_menu_item("Save", save_profile_to_file),
    button_menu_item("Cancel", function() menu_stack_pop(save_profile_popup) end),
  })

  load_profile_file_list = {}
  load_profile_file_index = 1
  load_profile_popup = make_menu(71, 61, 312, 122, -- screen size 383,223
  {
    list_menu_item("File", _G, "load_profile_file_index", load_profile_file_list),
    button_menu_item("Load", load_profile_from_file),
    button_menu_item("Clear", clear_profile_file),
    button_menu_item("Cancel", function() menu_stack_pop(load_profile_popup) end),
  })

  -- ── _replay_file_item ─────────────────────────────────────
  _replay_file_item = list_menu_item("Pattern (P2: ?)", replay_import_state, "file_index", replay_import_files)
  _replay_file_item.is_disabled = pattern_import_disabled
  _replay_file_item.indent = true

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

  -- ── widget definitions ────────────────────────────────────────
  life_refill_delay_item = integer_menu_item("Life Refill Delay", training_settings, "life_refill_delay", 1, 100, false, 20)
  life_refill_delay_item.is_disabled = function()
    return training_settings.life_mode ~= 2
  end
  life_refill_delay_item.indent = true

  p1_stun_reset_value_gauge_item = gauge_menu_item("P1 Stun Reset Value", training_settings, "p1_stun_reset_value", 64, 0xFF0000FF)
  p2_stun_reset_value_gauge_item = gauge_menu_item("P2 Stun Reset Value", training_settings, "p2_stun_reset_value", 64, 0xFF0000FF)
  p1_stun_reset_value_gauge_item.unit = 1
  p2_stun_reset_value_gauge_item.unit = 1
  stun_reset_delay_item = integer_menu_item("Stun Reset Delay", training_settings, "stun_reset_delay", 1, 100, false, 20)
  p1_stun_reset_value_gauge_item.is_disabled = function()
    return training_settings.stun_mode ~= 3
  end
  p2_stun_reset_value_gauge_item.is_disabled = p1_stun_reset_value_gauge_item.is_disabled
  stun_reset_delay_item.is_disabled = p1_stun_reset_value_gauge_item.is_disabled
  p1_stun_reset_value_gauge_item.indent = true
  p2_stun_reset_value_gauge_item.indent = true
  stun_reset_delay_item.indent = true

  p1_meter_gauge_item = gauge_menu_item("P1 Meter", training_settings, "p1_meter", 2, 0x0000FFFF)
  p2_meter_gauge_item = gauge_menu_item("P2 Meter", training_settings, "p2_meter", 2, 0x0000FFFF)
  meter_refill_delay_item = integer_menu_item("Meter Refill Delay", training_settings, "meter_refill_delay", 1, 100, false, 20)

  p1_meter_gauge_item.is_disabled = function()
    return training_settings.meter_mode ~= 2
  end
  p2_meter_gauge_item.is_disabled = p1_meter_gauge_item.is_disabled
  meter_refill_delay_item.is_disabled = p1_meter_gauge_item.is_disabled
  p1_meter_gauge_item.indent = true
  p2_meter_gauge_item.indent = true
  meter_refill_delay_item.indent = true

  slot_weight_item = integer_menu_item("Weight", nil, "weight", 0, 100, false, 1)
  counter_attack_delay_item = integer_menu_item("Counter-attack delay", nil, "delay", -40, 40, false, 0)
  counter_attack_random_deviation_item = integer_menu_item("Counter-attack max random deviation", nil, "random_deviation", -600, 600, false, 0, 1)

  parry_forward_on_item = checkbox_menu_item("Forward Parry Helper", training_settings, "special_training_parry_forward_on")
  parry_forward_on_item.is_disabled = function() return training_settings.special_training_current_mode ~= 2 end
  parry_forward_on_item.indent = true
  parry_down_on_item = checkbox_menu_item("Down Parry Helper", training_settings, "special_training_parry_down_on")
  parry_down_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_down_on_item.indent = true
  parry_air_on_item = checkbox_menu_item("Air Parry Helper", training_settings, "special_training_parry_air_on")
  parry_air_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_air_on_item.indent = true
  parry_antiair_on_item = checkbox_menu_item("Anti-Air Parry Helper", training_settings, "special_training_parry_antiair_on")
  parry_antiair_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_antiair_on_item.indent = true

  parry_rhythm_sa_on_item = checkbox_menu_item("Parry Rhythm - SA", training_settings, "display_parry_rhythm_sa")
  parry_rhythm_sa_on_item.is_disabled = parry_forward_on_item.is_disabled
  parry_rhythm_sa_on_item.indent = true

  -- Parry Rhythm - SA is mutually exclusive with the 4 Parry Helpers as a
  -- group (the helpers aren't exclusive with each other): whichever one was
  -- JUST toggled on turns the other side off. Each wrapper checks its OWN
  -- item's new value (self.object[self.property_name]) rather than the other
  -- side's current state, since that state is stale at the moment this runs
  -- (e.g. if Parry Rhythm - SA was already on and a helper just got turned
  -- on, display_parry_rhythm_sa is still true here — checking it first would
  -- wrongly re-disable the helper that was just turned on instead of
  -- disabling Parry Rhythm - SA).
  local function parry_rhythm_sa_disable_helpers()
    training_settings.special_training_parry_forward_on = false
    training_settings.special_training_parry_down_on = false
    training_settings.special_training_parry_air_on = false
    training_settings.special_training_parry_antiair_on = false
    training_settings.special_training_follow_character = true
  end
  local parry_rhythm_sa_orig_left = parry_rhythm_sa_on_item.left
  local parry_rhythm_sa_orig_right = parry_rhythm_sa_on_item.right
  parry_rhythm_sa_on_item.left = function(self) parry_rhythm_sa_orig_left(self) if training_settings.display_parry_rhythm_sa then parry_rhythm_sa_disable_helpers() end end
  parry_rhythm_sa_on_item.right = function(self) parry_rhythm_sa_orig_right(self) if training_settings.display_parry_rhythm_sa then parry_rhythm_sa_disable_helpers() end end

  for _, _item in ipairs({ parry_forward_on_item, parry_down_on_item, parry_air_on_item, parry_antiair_on_item }) do
    local _orig_left = _item.left
    local _orig_right = _item.right
    _item.left = function(self) _orig_left(self) if self.object[self.property_name] then training_settings.display_parry_rhythm_sa = false end end
    _item.right = function(self) _orig_right(self) if self.object[self.property_name] then training_settings.display_parry_rhythm_sa = false end end
  end

  charge_overcharge_on_item = checkbox_menu_item("Display Overcharge", training_settings, "special_training_charge_overcharge_on")
  charge_overcharge_on_item.is_disabled = function() return training_settings.special_training_current_mode ~= 3 end
  charge_overcharge_on_item.indent = true

  hits_before_red_parry_item = integer_menu_item("Hits before Red Parry", training_settings, "red_parry_hit_count", 1, 20, true)
  hits_before_red_parry_item.is_disabled = function()
    return training_settings.blocking_style ~= 4
  end
  hits_before_red_parry_item.indent = true

  blocking_mode_item = list_menu_item("Blocking Mode", training_settings, "blocking_mode", blocking_mode)
  blocking_mode_item.is_disabled = function()
    return training_settings.blocking_style ~= 2
  end
  blocking_mode_item.indent = true

  blocking_guard_type_item = list_menu_item("Guard Type", training_settings, "blocking_guard_type", blocking_guard_type)
  blocking_guard_type_item.is_disabled = function()
    -- must match blocking_mode_item's own is_disabled (blocking_style ~= 2) too, same
    -- orphan-avoidance reasoning as frame_trap_hit_count_item below, just for mode==1
    -- ("Always") instead of ==4
    return training_settings.blocking_style ~= 2 or training_settings.blocking_mode ~= 1
  end
  blocking_guard_type_item.indent = true

  frame_trap_hit_count_item = integer_menu_item("Frame Trap Hits", training_settings, "frame_trap_hit_count", 1, 5, true)
  frame_trap_hit_count_item.is_disabled = function()
    -- must match blocking_mode_item's own is_disabled (blocking_style ~= 2) too, or this
    -- stays visible as an "orphan" once blocking_mode was left at 4 ("Frame Trap") from a
    -- previous Block-style session and the style gets switched away (2026-10-11 Peter)
    return training_settings.blocking_style ~= 2 or training_settings.blocking_mode ~= 4
  end
  frame_trap_hit_count_item.indent = true

  frame_trap_after_mode_item = list_menu_item("After N Hits", training_settings, "frame_trap_after_mode", frame_trap_after_mode)
  frame_trap_after_mode_item.is_disabled = function()
    return training_settings.blocking_style ~= 2 or training_settings.blocking_mode ~= 4
  end
  frame_trap_after_mode_item.indent = true

  display_p2_input_history_item = checkbox_menu_item("Display P2 Input History", training_settings, "display_p2_input_history")
  display_p2_input_history_item.is_disabled = function() return training_settings.display_p1_input_history_dynamic end

  replay_slot_item = list_menu_item("Raw Mission Slot", training_settings, "current_replay_mission_slot", mission_recording_slots_names)
  replay_slot_item.is_disabled = function()
    return not training_settings.replay_raw_mission_menu_on
  end
  replay_slot_item.indent = true

  -- disable Replay Mission / Play Side when no non-empty replay slot is selected
  local function no_replay_slot_selected()
    if training_settings.current_replay_mission_slot == 1 then return true end
    local _slot = mission_slots[training_settings.current_replay_mission_slot - 1]
    return _slot == nil or _slot.name == "none"
  end

  -- Generate Bookmark Savestates reads the slot picked by "Analyze Raw Mission Slot"
  -- (2026-10-11 Peter: was wrongly gated on "Raw Mission Slot" above, a separate and
  -- unrelated selector tied to Replay Raw Mission for Slot)
  local function no_analyze_slot_selected()
    if training_settings.current_analyze_raw_slot == 1 then return true end
    local _slot = mission_slots[training_settings.current_analyze_raw_slot - 1]
    return _slot == nil or _slot.name == "none"
  end

  pattern_replay_mode_item = list_menu_item("Pattern Replay Mode", training_settings, "pattern_replay_mode", pattern_replay_mode_options)
  pattern_replay_mode_item.is_disabled = pattern_import_disabled
  pattern_replay_mode_item.indent = true

  direct_play_item = checkbox_menu_item("Pattern Replay", training_settings, "pattern_replay_on", nil, {"Start", "Stop"})
  direct_play_item.is_disabled = pattern_import_disabled
  direct_play_item.indent = true

  replay_raw_mission_gate_item = checkbox_menu_item("Replay Raw Mission for Slot", training_settings, "replay_raw_mission_menu_on", nil, {"On", "Off"})
  replay_raw_mission_gate_item.is_disabled = function()
    return training_settings.recording_mission_mode
  end

  replay_mission_item = checkbox_menu_item("Replay Raw Mission", training_settings, "mission_replay_on", nil, {"Start", "Stop"})
  replay_mission_item.is_disabled = function()
    return training_settings.recording_mission_mode or not training_settings.replay_raw_mission_menu_on
  end
  replay_mission_item.indent = true

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
  p1_distances_reference_point_item.indent = true

  p2_distances_reference_point_item = list_menu_item("P2 Distance Reference Point", training_settings, "p2_distances_reference_point", distance_display_reference_point)
  p2_distances_reference_point_item.is_disabled = function()
    return not training_settings.display_distances
  end
  p2_distances_reference_point_item.indent = true
  mid_distance_height_item = integer_menu_item("Mid Distance Height", training_settings, "mid_distance_height", 0, 200, false, 10)
  mid_distance_height_item.is_disabled = function()
    return not training_settings.display_distances
  end
  mid_distance_height_item.indent = true

  -- ── main menu construction ─────────────────────────────────────
  main_menu = make_multitab_menu(
    23, 15, 360, 195, -- screen size 383,223
    {
      {
        name = "Dummy",
        entries = {
          list_menu_item("Pose", training_settings, "pose", pose),
          list_menu_item("Blocking Style", training_settings, "blocking_style", blocking_style),
          blocking_mode_item,
          blocking_guard_type_item,
          frame_trap_hit_count_item,
          frame_trap_after_mode_item,
          hits_before_red_parry_item,
          checkbox_menu_item("Tech Throws", training_settings, "tech_throws_on", nil, {"On", "Off"}),
          list_menu_item("Counter-Attack Move", training_settings, "counter_attack_stick", stick_gesture_display),
          list_menu_item("Counter-Attack Action", training_settings, "counter_attack_button", button_gesture_display),
          checkbox_menu_item("Fast Wake Up", training_settings, "fast_wakeup_on", nil, {"On", "Off"}),
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
          (function()
            local _item = list_menu_item("Clear Slot", training_settings, "current_clear_recording_slot", recording_slots_names_with_none)
            _item.last_frame_validated = 0
            _item.validate = function(self)
              if training_settings.current_clear_recording_slot ~= 1 then
                clear_slot()
                self.last_frame_validated = frame_number
              end
            end
            _item.legend = function() return "LP: Validate" end
            local _orig_draw = _item.draw
            _item.draw = function(self, _x, _y, _selected)
              if _selected and self.last_frame_validated > 0 then
                if frame_number < self.last_frame_validated then self.last_frame_validated = 0 end
                if frame_number - self.last_frame_validated < 5 then
                  gui.text(_x, _y, "< Clear Slot : deleted >", 0xFFFF00FF, text_default_border_color)
                  return
                end
              end
              _orig_draw(self, _x, _y, _selected)
            end
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Clear All Slots", training_settings, "clear_all_recording_slots_on", nil, {"On", "Off"})
            _item.validate = function(self)
              if training_settings.clear_all_recording_slots_on then
                clear_all_slots()
              end
            end
            _item.legend = function() return "LP: Clear All" end
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Save Slot To File", training_settings, "save_slot_to_file_on", nil, {"On", "Off"})
            _item.validate = function(self)
              if training_settings.save_slot_to_file_on then
                open_save_popup()
              end
            end
            _item.legend = function() return "LP: Open" end
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Load Slot From File", training_settings, "load_slot_from_file_on", nil, {"On", "Off"})
            _item.validate = function(self)
              if training_settings.load_slot_from_file_on then
                open_load_popup()
              end
            end
            _item.legend = function() return "LP: Open" end
            return _item
          end)(),
        }
      },
      {
        name = "Missions",
        entries = {
          recording_mission_mode_item,
          (function()
            local _item = list_menu_item("Record Raw Mission in Slot", training_settings, "current_mission_slot", mission_slot_names)
            _item.is_disabled = function()
              return not training_settings.recording_mission_mode
            end
            _item.indent = true
            return _item
          end)(),
          replay_raw_mission_gate_item,
          replay_slot_item,
          (function()
            local _item = list_menu_item("Play Side", training_settings, "mission_play_side", mission_play_side_names)
            _item.is_disabled = function()
              return training_settings.recording_mission_mode or not training_settings.replay_raw_mission_menu_on or no_replay_slot_selected()
            end
            _item.indent = true
            return _item
          end)(),
          replay_mission_item,
          (function()
            local _item = checkbox_menu_item("Analyze Raw Mission for Bookmarks", training_settings, "analyze_raw_mission_on", nil, {"On", "Off"})
            -- refresh the shared character/file cache on turning this on, same as the
            -- Clear Bookmark Slot gate below -- otherwise Pattern Character stays stuck
            -- on "none" until something else happens to trigger a scan first (2026-10-11
            -- Peter: public users with only the hand-placed patterns/ken/ examples, no
            -- private scan tool, would otherwise have no way to ever populate this list)
            local _orig_left, _orig_right = _item.left, _item.right
            _item.left = function(self)
              _orig_left(self)
              if training_settings.analyze_raw_mission_on then refresh_bookmark_clear_chars() end
            end
            _item.right = function(self)
              _orig_right(self)
              if training_settings.analyze_raw_mission_on then refresh_bookmark_clear_chars() end
            end
            return _item
          end)(),
          (function()
            local _item = list_menu_item("Analyze Raw Mission Slot", training_settings, "current_analyze_raw_slot", mission_recording_slots_names)
            _item.is_disabled = function()
              return not training_settings.analyze_raw_mission_on
            end
            _item.indent = true
            return _item
          end)(),
          (function()
            -- scan_pattern_analyzer_mode_names only exists if the private
            -- ../replay-pattern-trainer/lua/bookmark_scan.lua loaded (pcall'd
            -- dofile in 3rd_training.lua, silently a no-op without it) — on a
            -- public-only install the global stays nil, and list_menu_item's
            -- draw() indexes it unconditionally with no nil guard, crashing
            -- the whole menu as soon as this item becomes enabled (Analyze
            -- Raw Mission on). Same fallback-default idiom already used for
            -- bookmark_clear_char_names (pattern_replay.lua:16, public) so
            -- the widget always gets a real list regardless of which build
            -- this is; the actual scan trigger below already has its own
            -- run_scan_pattern_analyzer guard, so this is purely a display
            -- fallback, not a functional one.
            scan_pattern_analyzer_mode_names = scan_pattern_analyzer_mode_names or {"N/A (private scan tool not installed)"}
            local _item = list_menu_item("Scan Pattern for Character", training_settings, "scan_pattern_analyzer_mode", scan_pattern_analyzer_mode_names)
            _item.is_disabled = function()
              return not training_settings.analyze_raw_mission_on
            end
            _item.validate = function(self)
              if run_scan_pattern_analyzer then run_scan_pattern_analyzer() end
            end
            _item.legend = function() return "LP: Run" end
            _item.indent = true
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Generate Bookmark Savestates", training_settings, "generate_bookmark_savestates_on", nil, {"On", "Off"})
            -- 2026-10-11 Peter: hidden until the resimulation path is sorted out -- round
            -- timer freeze during resimulation is fixed, but it also spuriously triggers
            -- pattern_defense_result's "HIT"/"THROWN" banner (root cause not yet found).
            -- Revert to `return no_analyze_slot_selected()` once that's resolved.
            _item.is_disabled = function()
              return true
            end
            _item.validate = function(self)
              if training_settings.generate_bookmark_savestates_on and generate_bookmark_savestates then
                generate_bookmark_savestates()
              end
            end
            _item.legend = function() return "LP: Generate" end
            return _item
          end)(),
          (function()
            -- Pattern Character (2026-10-11 Peter): picks which character's folder the
            -- "Pattern (P2: ...)" list below browses. Switching is a cache lookup only
            -- (bookmark_clear_file_cache, built by Scan Pattern / refresh_bookmark_clear_chars),
            -- no disk re-scan per switch.
            local _item = list_menu_item("Pattern Character", pattern_browse_char_state, "char_index", bookmark_clear_char_names)
            _item.is_disabled = function()
              return not training_settings.analyze_raw_mission_on or #bookmark_clear_char_names <= 1
            end
            local _orig_left, _orig_right = _item.left, _item.right
            _item.left = function(self)
              _orig_left(self)
              load_pattern_browse_files()
            end
            _item.right = function(self)
              _orig_right(self)
              load_pattern_browse_files()
            end
            _item.indent = true
            return _item
          end)(),
          _replay_file_item,
          pattern_replay_mode_item,
          direct_play_item,
          -- Clear Raw/Bookmark Slot items moved to the bottom, parent level (no indent,
          -- per Peter 2026-10-11): they're standalone cleanup actions, not sub-options
          -- tied to any one step above, so they read better grouped and un-nested.
          (function()
            local _item = list_menu_item("Clear Raw Slot", training_settings, "current_clear_mission_slot", mission_recording_slots_names)
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
                  gui.text(_x, _y, "< Clear Raw Slot : "..mission_recording_slots_names[training_settings.current_clear_mission_slot].." >", 0xFFFF00FF, text_default_border_color)
                  return
                end
              end
              _orig_draw(self, _x, _y, _selected)
            end
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Clear All Raw Slots", training_settings, "clear_all_raw_slots_on", nil, {"On", "Off"})
            _item.validate = function(self)
              if training_settings.clear_all_raw_slots_on then
                clear_all_mission_slots()
              end
            end
            _item.legend = function() return "LP: Clear All" end
            return _item
          end)(),
          -- Clear Bookmark Slot (2026-10-11 Peter): a gate checkbox + two sub-lists,
          -- instead of one list tied to the Pattern Replay import scan -- that old design
          -- always showed "none" unless "Scan Pattern for Character" had already run,
          -- which is impossible once the raw mission that produced it has been cleared.
          -- This scans replay_output_path directly so it works independently of any raw
          -- mission slot or scan, for any character, at any time.
          (function()
            local _item = checkbox_menu_item("Clear Bookmark Slot", training_settings, "clear_bookmark_mode_on", nil, {"On", "Off"})
            local _orig_left, _orig_right = _item.left, _item.right
            _item.left = function(self)
              _orig_left(self)
              if training_settings.clear_bookmark_mode_on then refresh_bookmark_clear_chars() end
            end
            _item.right = function(self)
              _orig_right(self)
              if training_settings.clear_bookmark_mode_on then refresh_bookmark_clear_chars() end
            end
            return _item
          end)(),
          (function()
            local _item = list_menu_item("Character", bookmark_clear_char_state, "char_index", bookmark_clear_char_names)
            _item.is_disabled = function() return not training_settings.clear_bookmark_mode_on end
            _item.indent = true
            local _orig_left, _orig_right = _item.left, _item.right
            _item.left = function(self)
              _orig_left(self)
              refresh_bookmark_clear_files()
            end
            _item.right = function(self)
              _orig_right(self)
              refresh_bookmark_clear_files()
            end
            return _item
          end)(),
          (function()
            local _item = list_menu_item("Bookmark Slot", bookmark_clear_state, "file_index", bookmark_clear_names)
            _item.is_disabled = function()
              return not training_settings.clear_bookmark_mode_on
                or bookmark_clear_char_names[bookmark_clear_char_state.char_index] == "none"
            end
            _item.indent = true
            _item.last_frame_validated = 0
            _item.validate = function(self)
              if bookmark_clear_state.file_index ~= 1 then
                clear_bookmark_pattern()
                self.last_frame_validated = frame_number
              end
            end
            _item.legend = function() return "LP: Validate" end
            local _orig_draw = _item.draw
            _item.draw = function(self, _x, _y, _selected)
              if _selected and self.last_frame_validated > 0 then
                if frame_number < self.last_frame_validated then self.last_frame_validated = 0 end
                if frame_number - self.last_frame_validated < 5 then
                  gui.text(_x, _y, "< Bookmark Slot : deleted >", 0xFFFF00FF, text_default_border_color)
                  return
                end
              end
              _orig_draw(self, _x, _y, _selected)
            end
            return _item
          end)(),
          (function()
            local _item = checkbox_menu_item("Clear Chara All Bookmark Slot", training_settings, "clear_chara_all_bookmark_slot_on", nil, {"On", "Off"})
            _item.is_disabled = function()
              return not training_settings.clear_bookmark_mode_on
                or bookmark_clear_char_names[bookmark_clear_char_state.char_index] == "none"
            end
            _item.indent = true
            _item.validate = function(self)
              if training_settings.clear_chara_all_bookmark_slot_on then
                clear_chara_all_bookmark_patterns()
              end
            end
            _item.legend = function() return "LP: Clear Chara All" end
            return _item
          end)(),
          -- global, not scoped to the selected Character AND not gated behind the Clear
          -- Bookmark Slot On/Off toggle -- mirrors Clear All Raw Slots exactly (always
          -- visible, 2026-10-11 Peter: this deletes every character's bookmarks in one
          -- shot, so it must stay visible even while Clear Bookmark Slot itself is Off)
          (function()
            local _item = checkbox_menu_item("Clear All Bookmark Slot", training_settings, "clear_all_bookmark_slot_on", nil, {"On", "Off"})
            _item.validate = function(self)
              if training_settings.clear_all_bookmark_slot_on then
                clear_all_bookmark_patterns_global()
              end
            end
            _item.legend = function() return "LP: Clear All" end
            return _item
          end)(),
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
          (function()
            local _item = checkbox_menu_item("Parry SA Only", training_settings, "frame_table_sa_only")
            _item.is_disabled = function() return not training_settings.display_frame_table end
            _item.indent = true
            return _item
          end)(),
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
          list_menu_item("Ping Delay", training_settings, "ping_delay", ping_delay_names),
          (function()
            local _item = button_menu_item("Save Profile", open_save_profile_popup)
            _item.legend = function() return "LP: Validate | Saves Dummy+Rules settings and this character's recording slots" end
            return _item
          end)(),
          (function()
            -- single entry point for the popup below, which already offers
            -- both Load and Clear on the same file list (2026-10-19 Peter:
            -- a separate top-level "Clear Profile" button opening the exact
            -- same popup was redundant once that popup had its own Clear)
            local _item = button_menu_item("Manage Profiles", open_load_profile_popup)
            _item.legend = function() return "LP: Validate | Load or clear the selected saved profile" end
            return _item
          end)(),
          (function()
            -- Yes/No is checkbox_menu_item's own default labels (no override
            -- needed); validate only runs on LP (not on toggling Yes/No with
            -- left/right), matching Clear All Slots/Raw Slots/Bookmark Slot's
            -- existing arm-then-execute split
            local _item = checkbox_menu_item("Clear All Profiles", training_settings, "clear_all_profiles_on")
            _item.validate = function(self)
              if training_settings.clear_all_profiles_on then
                clear_all_profiles()
              end
            end
            _item.legend = function() return "LP: Clear All" end
            return _item
          end)(),
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
            _item.indent = true
            return _item
          end)(),
          parry_forward_on_item,
          parry_down_on_item,
          parry_air_on_item,
          parry_antiair_on_item,
          parry_rhythm_sa_on_item,
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

      if _menu.main_menu_selected_index == 6 and special_training_mode[training_settings.special_training_current_mode] == "Parry" then
        local _dx = _menu.left + 160
        local _dy = _menu.top + 23
        local _c = text_disabled_color
        local _b = text_default_border_color
        local _miss_c = 0xE70000FF
        local _success_c = 0x10FB00FF

        if training_settings.display_parry_rhythm_sa then
          -- Parry Rhythm - SA is on: replace the Parry Helper legend with the rhythm one
          gui.text(_dx, _dy, "Goal: 17F between two forward taps", _c, _b)

          gui.text(_dx, _dy + 10, "+N", _miss_c, _b)
          gui.text(_dx + get_text_width("+N"), _dy + 10, ": Gap N frames too long, be faster", _c, _b)

          gui.text(_dx, _dy + 20, "-N", _miss_c, _b)
          gui.text(_dx + get_text_width("-N"), _dy + 20, ": Gap N frames too short, be slower", _c, _b)

          gui.text(_dx, _dy + 30, "0", _success_c, _b)
          gui.text(_dx + get_text_width("0"), _dy + 30, ": Perfect", _c, _b)
        else
          gui.text(_dx, _dy, "+N", _miss_c, _b)
          gui.text(_dx + get_text_width("+N"), _dy, ": Pressed N frames late, need to be faster", _c, _b)

          gui.text(_dx, _dy + 10, "-N", _miss_c, _b)
          gui.text(_dx + get_text_width("-N"), _dy + 10, ": Pressed N frames early, need to be slower", _c, _b)

          gui.text(_dx, _dy + 20, "Success ", _c, _b)
          gui.text(_dx + get_text_width("Success "), _dy + 20, "-#", _success_c, _b)
          gui.text(_dx + get_text_width("Success -#"), _dy + 20, ": frames into window", _c, _b)
          gui.text(_dx, _dy + 30, "(closer to 0 is better)", _c, _b)
        end
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

      -- Dummy tab: Blocking Mode explanation in the right-side blank space,
      -- only while the Blocking Mode entry (index 3) is selected
      if not _menu.is_main_menu_selected and _menu.main_menu_selected_index == 1 and _menu.sub_menu_selected_index == 3 then
        local _dx = _menu.left + 160
        local _dy = _menu.top + 23 + (3 - 1) * menu_y_interval - 1
        local _c = text_disabled_color
        local _b = text_default_border_color
        if training_settings.blocking_mode == 2 then
          gui.text(_dx, _dy,      "Combo Only: lets the first hit", _c, _b)
          gui.text(_dx, _dy + 10, "of each fresh engagement through", _c, _b)
          gui.text(_dx, _dy + 20, "unblocked. True combos still land", _c, _b)
          gui.text(_dx, _dy + 30, "(hitstun); gaps get blocked.", _c, _b)
        elseif training_settings.blocking_mode == 4 then
          gui.text(_dx, _dy,      "Frame Trap: first N hits of each", _c, _b)
          gui.text(_dx, _dy + 10, "fresh engagement always connect,", _c, _b)
          gui.text(_dx, _dy + 20, "gap or not. After that: Block", _c, _b)
          gui.text(_dx, _dy + 30, "always blocks, Random is 50/50.", _c, _b)
        end
      end

      -- Missions tab: Pattern Character explanation in the right-side blank space,
      -- only while the Pattern Character entry (index 11) is selected (2026-10-11 Peter)
      if not _menu.is_main_menu_selected and _menu.main_menu_selected_index == 3 and _menu.sub_menu_selected_index == 11 then
        local _dx = _menu.left + 160
        local _dy = _menu.top + 23 + (11 - 1) * menu_y_interval - 1
        local _c = text_disabled_color
        local _b = text_default_border_color
        gui.text(_dx, _dy,      "Pattern Character: picks which", _c, _b)
        gui.text(_dx, _dy + 10, "folder the list below reads.", _c, _b)
        gui.text(_dx, _dy + 20, "Only shows entries if your live", _c, _b)
        gui.text(_dx, _dy + 30, "P2 char + SA match this pick.", _c, _b)
      end

      -- Display tab: color legends in the right-side blank space, only while the
      -- corresponding entry is selected and its display is turned on
      if not _menu.is_main_menu_selected and _menu.main_menu_selected_index == 4 then
        local _legend_x = _menu.left + 160
        if (_menu.sub_menu_selected_index == 8 or _menu.sub_menu_selected_index == 9) and training_settings.display_frame_table then
          -- anchored to the "Display Frame Table" row (8) even while "Parry SA Only" (9)
          -- is selected, so the legend doesn't jump position between the two
          local _legend_y = _menu.top + 23 + (8 - 1) * menu_y_interval - 1
          frame_table_legend_display(_legend_x, _legend_y)
        elseif _menu.sub_menu_selected_index == 10 and training_settings.display_hitboxes then
          local _legend_y = _menu.top + 23 + (10 - 1) * menu_y_interval - 1
          hitbox_legend_display(_legend_x, _legend_y)
        end
      end
    end
  )

  -- ── post-processing: dynamic disable logic ──────────────────────────────

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

  -- Gray out everything below Record Raw Mission in Slot EXCEPT Clear Raw Slot (14) and
  -- Clear All Raw Slots (15), which should stay usable even while armed to record: (3) Replay
  -- Raw Mission for Slot, (4) Raw Mission Slot, (5) Play Side, (6) Replay Raw Mission,
  -- (7) Analyze Raw Mission for Bookmarks, (8) Analyze Raw Mission Slot, (9) Scan Pattern
  -- for Character, (10) Generate Bookmark Savestates, (11) Pattern, (12) Pattern Replay Mode,
  -- (13) Pattern Replay, (16) Clear Bookmark Slot, (17) Character, (18) Bookmark Slot,
  -- (19) Clear Chara All Bookmark Slot, (20) Clear All Bookmark Slot, in Missions tab (3)
  -- (2026-10-11: Clear Raw/Bookmark Slot items moved to the bottom of the entries list, and
  -- Clear Bookmark Slot gained "Character"/"Clear Chara All Bookmark Slot" sub-items --
  -- indices shifted accordingly. Clear Raw Slot/All Raw Slots stay exempt by their NEW position.)
  for _, _entry_index in ipairs({3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18, 19, 20}) do
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

  -- ── debug tab (added only when developer_mode is enabled) ────────────────────────
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
