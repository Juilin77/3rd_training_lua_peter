-- src/settings.lua
-- training settings: load/save and recording slot backup/restore

function save_training_data()
  backup_recordings()
  if not write_object_to_json_file(training_settings, saved_path..training_settings_file) then
    print(string.format("Error: Failed to save training settings to \"%s\"", training_settings_file))
  end
end

function load_training_data()
  local _training_settings = read_object_from_json_file(saved_path..training_settings_file)
  if _training_settings == nil then
    _training_settings = {}
  end

  for _key, _value in pairs(_training_settings) do
    training_settings[_key] = _value
  end

  restore_recordings()
end

function backup_recordings()
  if is_in_match and player_objects[2].char_str ~= "" then
    write_object_to_json_file(recording_slots, saved_recordings_path..player_objects[2].char_str..".json")
  end
end

function restore_recordings()
  local _char = player_objects[2].char_str
  if _char and _char ~= "" then
    local _recording_count = #recording_slots
    recording_slots = read_object_from_json_file(saved_recordings_path.._char..".json") or {}
    local _missing_slots = _recording_count - #recording_slots
    for _i = 1, _missing_slots do
      table.insert(recording_slots, make_recording_slot())
    end
  end
end
