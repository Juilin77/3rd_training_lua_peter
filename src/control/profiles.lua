-- src/control/profiles.lua
-- training profiles: save/load Dummy + Rules settings bundled with recording slots, under a user-chosen name

local dummy_settings_keys = {
  "pose",
  "blocking_style",
  "blocking_mode",
  "red_parry_hit_count",
  "tech_throws_mode",
  "counter_attack_stick",
  "counter_attack_button",
  "fast_wakeup_mode",
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
  else
    print(string.format("Profile was saved for \"%s\", current dummy is \"%s\" - recording slots not applied", _data.character, player_objects[2].char_str))
  end

  save_training_data()
end

function open_save_profile_popup()
  save_profile_popup.selected_index = 1
  menu_stack_push(save_profile_popup)
  save_profile_name = string.gsub(player_objects[2].char_str, "(.*)", string.upper).."_"
end

function open_load_profile_popup()
  load_profile_popup.selected_index = 1
  menu_stack_push(load_profile_popup)

  load_profile_file_index = 1

  local _cmd = "dir /b "..string.gsub(saved_profiles_path, "/", "\\")
  local _f = io.popen(_cmd)
  if _f == nil then
    print(string.format("Error: Failed to execute command \"%s\"", _cmd))
    return
  end
  local _str = _f:read("*all")
  load_profile_file_list = {}
  for _line in string.gmatch(_str, '([^\r\n]+)') do -- Split all lines that have ".json" in them
    if string.find(_line, ".json") ~= nil then
      local _file = _line
      table.insert(load_profile_file_list, _file)
    end
  end
  load_profile_popup.content[1].list = load_profile_file_list
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
