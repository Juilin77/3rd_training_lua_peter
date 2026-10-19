-- src/control/profiles.lua
-- training profiles: save/load Dummy + Rules settings bundled with recording slots, under a user-chosen name

local dummy_settings_keys = {
  "pose",
  "blocking_style",
  "blocking_mode",
  "blocking_guard_type",
  "frame_trap_hit_count",
  "frame_trap_after_mode",
  "red_parry_hit_count",
  "tech_throws_on",
  "counter_attack_stick",
  "counter_attack_button",
  "fast_wakeup_on",
}

local rules_settings_keys = {
  "infinite_time",
  "life_mode",
  "life_refill_delay",
  "stun_mode",
  "p1_stun_reset_value",
  "p2_stun_reset_value",
  "stun_reset_delay",
  "meter_mode",
  "p1_meter",
  "p2_meter",
  "meter_refill_delay",
  "infinite_sa_time",
  "fast_forward_intro",
}

function gather_profile_data()
  local _dummy_settings = {}
  for _i, _key in ipairs(dummy_settings_keys) do
    _dummy_settings[_key] = training_settings[_key]
  end

  local _rules_settings = {}
  for _i, _key in ipairs(rules_settings_keys) do
    _rules_settings[_key] = training_settings[_key]
  end

  return {
    character = player_objects[2].char_str,
    dummy_settings = _dummy_settings,
    rules_settings = _rules_settings,
    recording_slots = recording_slots,
  }
end

function apply_profile_data(_data)
  if _data.dummy_settings then
    for _key, _value in pairs(_data.dummy_settings) do
      training_settings[_key] = _value
    end
  end

  if _data.rules_settings then
    for _key, _value in pairs(_data.rules_settings) do
      training_settings[_key] = _value
    end
  end

  if _data.character == nil or _data.character == player_objects[2].char_str then
    recording_slots = _data.recording_slots or {}
    local _missing_slots = recording_slot_count - #recording_slots
    for _i = 1, _missing_slots do
      table.insert(recording_slots, make_recording_slot())
    end
    -- explicit user-selected import (Load/Manage Profiles), not an unresolved
    -- scratch table — mark it confirmed immediately so backup_recordings()'s
    -- pristine/retry/conflict guard (2026-10-19) doesn't mistake this
    -- freshly-imported, very likely non-pristine data for unconfirmed scratch
    -- and refuse to save it. Also clear any stale pending/warned state for
    -- this character — the user's explicit import takes priority over
    -- whatever was previously stashed or already warned about.
    local _loaded_char = player_objects[2].char_str
    recording_slots_char = _loaded_char
    recordings_session_cache[_loaded_char] = recording_slots
    recording_slots_pending[_loaded_char] = nil
    recording_slots_conflict_warned[_loaded_char] = nil
    recording_slots_skip_warned[_loaded_char] = nil
  else
    print(string.format("Profile was saved for \"%s\", current dummy is \"%s\" - recording slots not applied", _data.character, player_objects[2].char_str))
  end

  save_training_data()
end

function open_save_profile_popup()
  save_profile_popup.selected_index = 1
  menu_stack_push(save_profile_popup)
  -- "PROFILE_" prefix instead of mixed-case "Profile_" -- the filename editor
  -- widget's available_characters (menu_widgets.lua) is uppercase-only, and
  -- silently drops any character it doesn't recognize the instant the field
  -- is opened for editing, so a mixed-case prefill would get mangled on the
  -- first edit. Matches the existing uppercase-forcing already applied to
  -- the character part below.
  save_profile_name = "PROFILE_"..string.gsub(player_objects[2].char_str, "(.*)", string.upper).."_"
end

-- shared by Load, Clear Profile and Clear All Profiles so there's exactly one
-- directory-scan implementation. /a-d excludes directories; the *.json glob
-- is combined with a strict trailing-match check below (not just the old
-- unanchored string.find(name, ".json"), which also matched e.g.
-- "foo.json.bak" since "." is a Lua pattern wildcard and the match wasn't
-- anchored to the end) - this list now also drives deletion, not just
-- loading, so a loose match here is no longer just cosmetic.
-- Returns true/false; on failure the list is cleared rather than left stale,
-- so a caller can't act on data from a previous successful scan by mistake.
function refresh_profile_file_list()
  local _dir = string.gsub(saved_profiles_path, "/", "\\")
  local _cmd = "dir /b /a-d \"".._dir.."*.json\""
  local _f = io.popen(_cmd)
  if _f == nil then
    print(string.format("Error: Failed to execute command \"%s\"", _cmd))
    load_profile_file_list = {}
    load_profile_popup.content[1].list = load_profile_file_list
    return false
  end
  local _str = _f:read("*all")
  _f:close()
  if _str == nil then
    print(string.format("Error: Failed to read output of command \"%s\"", _cmd))
    load_profile_file_list = {}
    load_profile_popup.content[1].list = load_profile_file_list
    return false
  end
  load_profile_file_list = {}
  for _line in string.gmatch(_str, '([^\r\n]+)') do
    if _line:lower():match("%.json$") then
      table.insert(load_profile_file_list, _line)
    end
  end
  load_profile_popup.content[1].list = load_profile_file_list
  return true
end

function open_load_profile_popup()
  load_profile_popup.selected_index = 1
  menu_stack_push(load_profile_popup)

  load_profile_file_index = 1
  refresh_profile_file_list()
end

function save_profile_to_file()
  if save_profile_name == "" then
    print(string.format("Error: Can't save to empty file name"))
    return
  end

  local _path = string.format("%s%s.json",saved_profiles_path, save_profile_name)
  if not write_object_to_json_file(gather_profile_data(), _path) then
    print(string.format("Error: Failed to save profile to \"%s\"", _path))
  else
    print(string.format("Saved profile to \"%s\"", _path))
  end

  menu_stack_pop(save_profile_popup)
end

function load_profile_from_file()
  if #load_profile_file_list == 0 or load_profile_file_list[load_profile_file_index] == nil then
    print(string.format("Error: Can't load from empty file name"))
    return
  end

  local _path = string.format("%s%s",saved_profiles_path, load_profile_file_list[load_profile_file_index])
  local _profile = read_object_from_json_file(_path)
  if not _profile then
    print(string.format("Error: Failed to load profile from \"%s\"", _path))
  else
    apply_profile_data(_profile)
    print(string.format("Loaded \"%s\"", _path))
  end

  menu_stack_pop(load_profile_popup)
end

-- deletes only the selected .json inside saved_profiles_path -- load_profile_file_list
-- is itself built exclusively from a directory scan of that same folder (refresh_profile_file_list),
-- never user-typed, so there is no wildcard or path-traversal risk here. Does not touch
-- training_settings or recording_slots: deleting a stored file is a pure filesystem action,
-- separate from resetting anything currently loaded in the session.
function clear_profile_file()
  if #load_profile_file_list == 0 or load_profile_file_list[load_profile_file_index] == nil then
    print(string.format("Error: Can't clear an empty file name"))
    return
  end

  local _path = string.format("%s%s", saved_profiles_path, load_profile_file_list[load_profile_file_index])
  local _ok, _err = os.remove(_path)
  if not _ok then
    print(string.format("Error: Failed to delete profile \"%s\": %s", _path, tostring(_err)))
  else
    print(string.format("Deleted profile \"%s\"", _path))
  end

  load_profile_file_index = 1
  refresh_profile_file_list()
end

-- same file-safety guarantees as clear_profile_file() (only .json files found by
-- refresh_profile_file_list() inside saved_profiles_path, no settings/recording-slot
-- mutation). Resets clear_all_profiles_on to false itself -- unlike clear_all_slots()/
-- clear_all_mission_slots(), which leave their own arming checkbox at Yes after running
-- (confirmed by reading them) -- so this can't re-trigger just by pressing LP again, and
-- the menu-open reset in 3rd_training.lua covers the remaining case where Yes got
-- auto-saved to disk without ever being validated.
function clear_all_profiles()
  if not refresh_profile_file_list() then
    print(string.format("Error: Aborting Clear All Profiles - could not scan \"%s\"", saved_profiles_path))
    training_settings.clear_all_profiles_on = false
    return
  end
  for _, _file in ipairs(load_profile_file_list) do
    local _path = saved_profiles_path.._file
    local _ok, _err = os.remove(_path)
    if not _ok then
      print(string.format("Error: Failed to delete profile \"%s\": %s", _path, tostring(_err)))
    else
      print(string.format("Deleted profile \"%s\"", _path))
    end
  end
  load_profile_file_index = 1
  refresh_profile_file_list()
  training_settings.clear_all_profiles_on = false
end
