-- src/control/missions.lua
-- Mission 系統：mission slots、錄製、回放

mission_slot_count = 10

mission_recording_slots_names = {"none"}
for _i = 1, mission_slot_count do
  table.insert(mission_recording_slots_names, "slot ".._i)
end

mission_play_side_names = { "1P", "2P" }

function make_mission_slot()
  return { name = "none", inputs = {p1 = {}, p2 = {}}, savestate_path = nil }
end

mission_slots = {}
for _i = 1, mission_slot_count do
  table.insert(mission_slots, make_mission_slot())
end

mission_slot_names = {}
for _i = 1, mission_slot_count do
  table.insert(mission_slot_names, "slot ".._i)
end

-- builds "slot N (content name / empty)" labels for Record/Replay/Clear Slot menus
function refresh_mission_recording_slots_names()
  for _i = 1, mission_slot_count do
    local _content = mission_slots[_i].name == "none" and "empty" or mission_slots[_i].name
    local _label = string.format("slot %d (%s)", _i, _content)
    mission_slot_names[_i] = _label
    mission_recording_slots_names[_i + 1] = _label
  end
end
refresh_mission_recording_slots_names()

function get_mission_slot_paths(_slot_index)
  return {
    meta   = string.format("%smission_slot_%d.json",        saved_missions_path, _slot_index),
    inputs = string.format("%smission_slot_%d.inputs.json", saved_missions_path, _slot_index),
    fs     = string.format("%smission_slot_%d.fs",          saved_missions_path, _slot_index),
  }
end

function save_mission_to_file(_slot_index)
  local _slot = mission_slots[_slot_index]
  if _slot.name == "none" then return end
  local _paths = get_mission_slot_paths(_slot_index)
  local _meta = { name = _slot.name, savestate_path = _slot.savestate_path, dummy_id = _slot.dummy_id }
  if not write_object_to_json_file(_meta, _paths.meta) then
    print(string.format("Error: Failed to save mission metadata to \"%s\"", _paths.meta))
  end
  if not write_object_to_json_file(_slot.inputs, _paths.inputs) then
    print(string.format("Error: Failed to save mission inputs to \"%s\"", _paths.inputs))
  else
    print(string.format("Saved mission slot %d", _slot_index))
  end
end

function load_missions_from_files()
  for _i = 1, mission_slot_count do
    mission_slots[_i] = make_mission_slot()
    local _paths = get_mission_slot_paths(_i)
    local _meta = read_object_from_json_file(_paths.meta)
    if _meta then
      mission_slots[_i].name = _meta.name or "none"
      mission_slots[_i].savestate_path = _meta.savestate_path
      mission_slots[_i].dummy_id = _meta.dummy_id or 2
    end
  end
  refresh_mission_recording_slots_names()
end

function delete_mission_slot_files(_slot_index)
  local _paths = get_mission_slot_paths(_slot_index)
  os.remove(_paths.meta)
  os.remove(_paths.inputs)
  os.remove(_paths.fs)
end

function clear_mission_slot()
  local _slot_index = training_settings.current_clear_mission_slot - 1
  if _slot_index < 1 then return end
  delete_mission_slot_files(_slot_index)
  mission_slots[_slot_index] = make_mission_slot()
  refresh_mission_recording_slots_names()
end

function clear_all_mission_slots()
  for _i = 1, #mission_slots do
    delete_mission_slot_files(_i)
    mission_slots[_i] = make_mission_slot()
  end
  refresh_mission_recording_slots_names()
end

function mission_replay_queue_inputs()
  local _slot_index = training_settings.current_replay_mission_slot - 1
  local _slot = mission_slots[_slot_index]
  if not _slot then return end
  mission_dummy_id = 3 - training_settings.mission_play_side
  local _side = mission_dummy_id == 1 and "p1" or "p2"
  local _inputs = _slot.inputs[_side]
  if not _inputs or #_inputs == 0 then return end
  queue_input_sequence(player_objects[mission_dummy_id], _inputs)
end

function replay_current_mission()
  local _slot_index = training_settings.current_replay_mission_slot - 1
  if _slot_index < 1 then return end
  local _slot = mission_slots[_slot_index]
  if _slot.name == "none" then return end
  mission_dummy_id = 3 - training_settings.mission_play_side
  local _side = mission_dummy_id == 1 and "p1" or "p2"
  if not _slot.inputs[_side] or #_slot.inputs[_side] == 0 then
    local _paths = get_mission_slot_paths(_slot_index)
    local _inputs = read_object_from_json_file(_paths.inputs)
    if _inputs then _slot.inputs = _inputs end
  end
  local _dummy_inputs = _slot.inputs[_side]
  if not _dummy_inputs or #_dummy_inputs == 0 then return end
  if _slot.savestate_path then
    mission_replay_pending = true
    mission_replay_active = true
    savestate.load(savestate.create(_slot.savestate_path))
  else
    queue_input_sequence(player_objects[mission_dummy_id], _dummy_inputs)
    mission_replay_active = true
  end
end

function update_mission_recording(_input)
  if not is_in_match or is_menu_open then return end
  if not mission_recording_active then return end

  for _, _player_obj in ipairs(player_objects) do
    local _frame = {}
    for _key, _value in pairs(_input) do
      local _prefix = _key:sub(1, #_player_obj.prefix)
      if _prefix == _player_obj.prefix then
        local _input_name = _key:sub(1 + #_player_obj.prefix + 1)
        if _input_name ~= "Coin" and _input_name ~= "Start" then
          if _value then
            table.insert(_frame, stick_input_to_sequence_input(_player_obj, _input_name))
          end
        end
      end
    end
    local _side = _player_obj.id == 1 and "p1" or "p2"
    table.insert(mission_recording_inputs[_side], _frame)
  end
end
