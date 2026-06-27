-- src/settings.lua
-- 訓練設定的存取與錄製槽備份/還原

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

  -- update old versions data
  if _training_settings.recordings then
    for _key, _value in pairs(_training_settings.recordings) do
      for _i, _slot in ipairs(_value) do
        if _value[_i].inputs == nil then
          _value[_i] = make_recording_slot()
        else
          _slot.delay = _slot.delay or 0
          _slot.random_deviation = _slot.random_deviation or 0
          _slot.weight = _slot.weight or 1
        end
      end
    end
  end

  for _key, _value in pairs(_training_settings) do
    training_settings[_key] = _value
  end

  restore_recordings()
end

function backup_recordings()
  -- Init base table
  if training_settings.recordings == nil then
    training_settings.recordings = {}
  end
  for _key, _value in ipairs(characters) do
    if training_settings.recordings[_value] == nil then
      training_settings.recordings[_value] = {}
      for _i = 1, #recording_slots do
        table.insert(training_settings.recordings[_value], make_recording_slot())
      end
    end
  end

  if dummy.char_str ~= "" then
    training_settings.recordings[dummy.char_str] = recording_slots
  end
end

function restore_recordings()
  local _char = player_objects[2].char_str
  if _char and _char ~= "" then
    local _recording_count = #recording_slots
    if training_settings.recordings then
      recording_slots = training_settings.recordings[_char] or {}
    end
    local _missing_slots = _recording_count - #recording_slots
    for _i = 1, _missing_slots do
      table.insert(recording_slots, make_recording_slot())
    end
  end
end
