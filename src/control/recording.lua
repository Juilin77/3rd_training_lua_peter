-- src/control/recording.lua
-- recording/playback system: input sequences, recording slots, state machine

-- players
function queue_input_sequence(_player_obj, _sequence, _offset)
  _offset = _offset or 0
  if _sequence == nil or #_sequence == 0 then
    return
  end

  if _player_obj.pending_input_sequence ~= nil then
    return
  end

  local _seq = {}
  _seq.sequence = copytable(_sequence)
  _seq.current_frame = 1 - _offset

  _player_obj.pending_input_sequence = _seq
end

function process_pending_input_sequence(_player_obj, _input)
  if _player_obj.pending_input_sequence == nil then
    return
  end
  if is_menu_open then
    return
  end
  if not is_in_match then
    return
  end

  -- Cancel all input
  _input[_player_obj.prefix.." Up"] = false
  _input[_player_obj.prefix.." Down"] = false
  _input[_player_obj.prefix.." Left"] = false
  _input[_player_obj.prefix.." Right"] = false
  _input[_player_obj.prefix.." Weak Punch"] = false
  _input[_player_obj.prefix.." Medium Punch"] = false
  _input[_player_obj.prefix.." Strong Punch"] = false
  _input[_player_obj.prefix.." Weak Kick"] = false
  _input[_player_obj.prefix.." Medium Kick"] = false
  _input[_player_obj.prefix.." Strong Kick"] = false

  -- Charge moves memory locations
  -- P1
  -- 0x020259D8 H/Urien V/Oro V/Chun H/Q V/Remy
  -- 0x020259F4 (+1C) V/Urien H/Q H/Remy
  -- 0x02025A10 (+38) H/Oro H/Remy
  -- 0x02025A2C (+54) V/Urien V/Alex
  -- 0x02025A48 (+70) H/Alex

  -- P2
  -- 0x02025FF8
  -- 0x02026014
  -- 0x02026030
  -- 0x0202604C
  -- 0x02026068
  local _gauges_base = 0
  if _player_obj.id == 1 then
    _gauges_base = 0x020259D8
  elseif _player_obj.id == 2 then
    _gauges_base = 0x02025FF8
  end
  local _gauges_offsets = { 0x0, 0x1C, 0x38, 0x54, 0x70 }

  if _player_obj.pending_input_sequence.current_frame >= 1 then
    local _s = ""
    local _current_frame_input = _player_obj.pending_input_sequence.sequence[_player_obj.pending_input_sequence.current_frame]
    for i = 1, #_current_frame_input do
      local _input_name = _player_obj.prefix.." "
      if _current_frame_input[i] == "forward" then
        if _player_obj.flip_input then _input_name = _input_name.."Right" else _input_name = _input_name.."Left" end
      elseif _current_frame_input[i] == "back" then
        if _player_obj.flip_input then _input_name = _input_name.."Left" else _input_name = _input_name.."Right" end
      elseif _current_frame_input[i] == "up" then
        _input_name = _input_name.."Up"
      elseif _current_frame_input[i] == "down" then
        _input_name = _input_name.."Down"
      elseif _current_frame_input[i] == "LP" then
        _input_name = _input_name.."Weak Punch"
      elseif _current_frame_input[i] == "MP" then
        _input_name = _input_name.."Medium Punch"
      elseif _current_frame_input[i] == "HP" then
        _input_name = _input_name.."Strong Punch"
      elseif _current_frame_input[i] == "LK" then
        _input_name = _input_name.."Weak Kick"
      elseif _current_frame_input[i] == "MK" then
        _input_name = _input_name.."Medium Kick"
      elseif _current_frame_input[i] == "HK" then
        _input_name = _input_name.."Strong Kick"
      elseif _current_frame_input[i] == "h_charge" then
        if _player_obj.char_str == "urien" then
          memory.writeword(_gauges_base + _gauges_offsets[1], 0xFFFF)
        elseif _player_obj.char_str == "oro" then
          memory.writeword(_gauges_base + _gauges_offsets[3], 0xFFFF)
        elseif _player_obj.char_str == "chunli" then
        elseif _player_obj.char_str == "q" then
          memory.writeword(_gauges_base + _gauges_offsets[1], 0xFFFF)
          memory.writeword(_gauges_base + _gauges_offsets[2], 0xFFFF)
        elseif _player_obj.char_str == "remy" then
          memory.writeword(_gauges_base + _gauges_offsets[2], 0xFFFF)
          memory.writeword(_gauges_base + _gauges_offsets[3], 0xFFFF)
        elseif _player_obj.char_str == "alex" then
          memory.writeword(_gauges_base + _gauges_offsets[5], 0xFFFF)
        end
      elseif _current_frame_input[i] == "v_charge" then
        if _player_obj.char_str == "urien" then
          memory.writeword(_gauges_base + _gauges_offsets[2], 0xFFFF)
          memory.writeword(_gauges_base + _gauges_offsets[4], 0xFFFF)
        elseif _player_obj.char_str == "oro" then
          memory.writeword(_gauges_base + _gauges_offsets[1], 0xFFFF)
        elseif _player_obj.char_str == "chunli" then
          memory.writeword(_gauges_base + _gauges_offsets[1], 0xFFFF)
        elseif _player_obj.char_str == "q" then
        elseif _player_obj.char_str == "remy" then
          memory.writeword(_gauges_base + _gauges_offsets[1], 0xFFFF)
        elseif _player_obj.char_str == "alex" then
          memory.writeword(_gauges_base + _gauges_offsets[4], 0xFFFF)
        end
      end
      _input[_input_name] = true
      _s = _s.._input_name
    end
  end
  --print(_s)

  _player_obj.pending_input_sequence.current_frame = _player_obj.pending_input_sequence.current_frame + 1
  if _player_obj.pending_input_sequence.current_frame > #_player_obj.pending_input_sequence.sequence then
    _player_obj.pending_input_sequence = nil
  end
end

function clear_input_sequence(_player_obj)
  _player_obj.pending_input_sequence = nil
end

function is_playing_input_sequence(_player_obj)
  return _player_obj.pending_input_sequence ~= nil and _player_obj.pending_input_sequence.current_frame >= 1
end

function make_input_empty(_input)
  if _input == nil then
    return
  end

  _input["P1 Up"] = false
  _input["P1 Down"] = false
  _input["P1 Left"] = false
  _input["P1 Right"] = false
  _input["P1 Weak Punch"] = false
  _input["P1 Medium Punch"] = false
  _input["P1 Strong Punch"] = false
  _input["P1 Weak Kick"] = false
  _input["P1 Medium Kick"] = false
  _input["P1 Strong Kick"] = false
  _input["P1 Start"] = false
  _input["P1 Coin"] = false
  _input["P2 Up"] = false
  _input["P2 Down"] = false
  _input["P2 Left"] = false
  _input["P2 Right"] = false
  _input["P2 Weak Punch"] = false
  _input["P2 Medium Punch"] = false
  _input["P2 Strong Punch"] = false
  _input["P2 Weak Kick"] = false
  _input["P2 Medium Kick"] = false
  _input["P2 Strong Kick"] = false
  _input["P2 Start"] = false
  _input["P2 Coin"] = false
end

function make_input_sequence(_stick, _button)

  if _button == "recording" then
    return nil
  end

  local _sequence = {}
  local _offset = 0
  if      _stick == "none"    then _sequence = { { } }
  elseif  _stick == "forward" then _sequence = { { "forward" } }
  elseif  _stick == "back"    then _sequence = { { "back" } }
  elseif  _stick == "down"    then _sequence = { { "down" } }
  elseif  _stick == "jump"    then _sequence = { { "up" } }
  elseif  _stick == "super jump" then _sequence = { { "down" }, { "up" } }
  elseif  _stick == "forward jump" then
    _sequence = { { "forward", "up" }, { "forward", "up" }, { "forward", "up" } }
    _offset = 2
  elseif  _stick == "forward super jump" then
    _sequence = { { "down" }, { "forward", "up" }, { "forward", "up" } }
    _offset = 2
  elseif  _stick == "back jump" then
    _sequence = { { "back", "up" }, { "back", "up" } }
    _offset = 2
  elseif  _stick == "back super jump" then
    _sequence = { { "down" }, { "back", "up" }, { "back", "up" } }
    _offset = 2
  elseif  _stick == "guard jump" then
    _sequence = {
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "up" }, { "up" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" }
    }
    _offset = 13
  elseif  _stick == "guard forward jump" then
    _sequence = {
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "forward", "up" },
      { "forward", "up" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" }
    }
    _offset = 13
  elseif  _stick == "guard back jump" then
    _sequence = {
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "back", "up" },
      { "back", "up" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" },
      { "down", "back" }
    }
    _offset = 13
  elseif  _stick == "QCF"     then _sequence = { { "down" }, {"down", "forward"}, {"forward"} }
  elseif  _stick == "QCB"     then _sequence = { { "down" }, {"down", "back"}, {"back"} }
  elseif  _stick == "HCF"     then _sequence = { { "back" }, {"down", "back"}, {"down"}, {"down", "forward"}, {"forward"} }
  elseif  _stick == "HCB"     then _sequence = { { "forward" }, {"down", "forward"}, {"down"}, {"down", "back"}, {"back"} }
  elseif  _stick == "DPF"     then _sequence = { { "forward" }, {"down"}, {"down", "forward"} }
  elseif  _stick == "DPB"     then _sequence = { { "back" }, {"down"}, {"down", "back"} }
  elseif  _stick == "HCharge" then _sequence = { { "back", "h_charge" }, {"forward"} }
  elseif  _stick == "VCharge" then _sequence = { { "down", "v_charge" }, {"up"} }
  elseif  _stick == "360"     then _sequence = { { "forward" }, { "forward", "down" }, {"down"}, { "back", "down" }, { "back" }, { "up" } }
  elseif  _stick == "DQCF"    then _sequence = { { "down" }, {"down", "forward"}, {"forward"}, { "down" }, {"down", "forward"}, {"forward"} }
  elseif  _stick == "720"     then _sequence = { { "forward" }, { "forward", "down" }, {"down"}, { "back", "down" }, { "back" }, { "up" }, { "forward" }, { "forward", "down" }, {"down"}, { "back", "down" }, { "back" } }
  -- full moves special cases
  elseif  _stick == "back dash" then _sequence = { { "back" }, {}, { "back" } }
    return _sequence
  elseif  _stick == "forward dash" then _sequence = { { "forward" }, {}, { "forward" } }
    return _sequence
  elseif  _stick == "Shun Goku Satsu" then _sequence = { { "LP" }, {}, {}, { "LP" }, { "forward" }, {"LK"}, {}, { "HP" } }
    return _sequence
  elseif  _stick == "Kongou Kokuretsu Zan" then _sequence = { { "down" }, {}, { "down" }, {}, { "down", "LP", "MP", "HP" } }
    return _sequence
  elseif  _stick == "Demon Armageddon" then _sequence = { { "up" }, {}, { "up" }, {}, { "up", "LK", "MK" } }
    return _sequence
  end

  if     _button == "none" then
  elseif _button == "EXP"  then
    table.insert(_sequence[#_sequence], "MP")
    table.insert(_sequence[#_sequence], "HP")
  elseif _button == "EXK"  then
    table.insert(_sequence[#_sequence], "MK")
    table.insert(_sequence[#_sequence], "HK")
  elseif _button == "LP+LK" then
    table.insert(_sequence[#_sequence], "LP")
    table.insert(_sequence[#_sequence], "LK")
  elseif _button == "MP+MK" then
    table.insert(_sequence[#_sequence], "MP")
    table.insert(_sequence[#_sequence], "MK")
  elseif _button == "HP+HK" then
    table.insert(_sequence[#_sequence], "HP")
    table.insert(_sequence[#_sequence], "HK")
  else
    table.insert(_sequence[#_sequence], _button)
  end

  return _sequence, _offset
end

function make_recording_slot()
  return {
    inputs = {},
    delay = 0,
    random_deviation = 0,
    weight = 1,
  }
end
recording_slots = {}
for _i = 1, recording_slot_count do
  table.insert(recording_slots, make_recording_slot())
end

recording_slots_names = {}
for _i = 1, #recording_slots do
  table.insert(recording_slots_names, "slot ".._i)
end

-- swap inputs
function swap_inputs(_out_input_table)
  local function swap(_input)
    local carry = _out_input_table["P1 ".._input]
    _out_input_table["P1 ".._input] = _out_input_table["P2 ".._input]
    _out_input_table["P2 ".._input] = carry
  end

  swap("Up")
  swap("Down")
  swap("Left")
  swap("Right")
  swap("Weak Punch")
  swap("Medium Punch")
  swap("Strong Punch")
  swap("Weak Kick")
  swap("Medium Kick")
  swap("Strong Kick")
end

function clear_slot()
  recording_slots[training_settings.current_recording_slot] = make_recording_slot()
  save_training_data()
end

function clear_all_slots()
  for _i = 1, recording_slot_count do
    recording_slots[_i] = make_recording_slot()
  end
  training_settings.current_recording_slot = 1
  save_training_data()
end

function open_save_popup()
  save_recording_slot_popup.selected_index = 1
  menu_stack_push(save_recording_slot_popup)
  save_file_name = string.gsub(dummy.char_str, "(.*)", string.upper).."_"
end

function open_load_popup()
  load_recording_slot_popup.selected_index = 1
  menu_stack_push(load_recording_slot_popup)

  load_file_index = 1

  local _cmd = "dir /b "..string.gsub(saved_recordings_path, "/", "\\")
  local _f = io.popen(_cmd)
  if _f == nil then
    print(string.format("Error: Failed to execute command \"%s\"", _cmd))
    return
  end
  local _str = _f:read("*all")
  load_file_list = {}
  for _line in string.gmatch(_str, '([^\r\n]+)') do -- Split all lines that have ".json" in them
    if string.find(_line, ".json") ~= nil then
      local _file = _line
      table.insert(load_file_list, _file)
    end
  end
  load_recording_slot_popup.content[1].list = load_file_list
end

function save_recording_slot_to_file()
  if save_file_name == "" then
    print(string.format("Error: Can't save to empty file name"))
    return
  end

  local _path = string.format("%s%s.json",saved_recordings_path, save_file_name)
  if not write_object_to_json_file(recording_slots[training_settings.current_recording_slot].inputs, _path) then
    print(string.format("Error: Failed to save recording to \"%s\"", _path))
  else
    print(string.format("Saved slot %d to \"%s\"", training_settings.current_recording_slot, _path))
  end

  menu_stack_pop(save_recording_slot_popup)
end

function load_recording_slot_from_file()
  if #load_file_list == 0 or load_file_list[load_file_index] == nil then
    print(string.format("Error: Can't load from empty file name"))
    return
  end

  local _path = string.format("%s%s",saved_recordings_path, load_file_list[load_file_index])
  local _recording = read_object_from_json_file(_path)
  if not _recording then
    print(string.format("Error: Failed to load recording from \"%s\"", _path))
  else
    recording_slots[training_settings.current_recording_slot].inputs = _recording
    print(string.format("Loaded \"%s\" to slot %d", _path, training_settings.current_recording_slot))
  end
  save_training_data()

  menu_stack_pop(load_recording_slot_popup)
end

override_replay_slot = -1
recording_states =
{
  "none",
  "waiting",
  "recording",
  "playing",
}

function stick_input_to_sequence_input(_player_obj, _input)
  if _input == "Up" then return "up" end
  if _input == "Down" then return "down" end
  if _input == "Weak Punch" then return "LP" end
  if _input == "Medium Punch" then return "MP" end
  if _input == "Strong Punch" then return "HP" end
  if _input == "Weak Kick" then return "LK" end
  if _input == "Medium Kick" then return "MK" end
  if _input == "Strong Kick" then return "HK" end

  if _input == "Left" then
    if _player_obj.flip_input then
      return "back"
    else
      return "forward"
    end
  end

  if _input == "Right" then
    if _player_obj.flip_input then
      return "forward"
    else
      return "back"
    end
  end
  return ""
end

function can_play_recording()
  if training_settings.replay_mode == 2 or training_settings.replay_mode == 3 or training_settings.replay_mode == 5 or training_settings.replay_mode == 6 then
    for _i, _value in ipairs(recording_slots) do
      if #_value.inputs > 0 then
        return true
      end
    end
  else
    return recording_slots[training_settings.current_recording_slot].inputs ~= nil and #recording_slots[training_settings.current_recording_slot].inputs > 0
  end
  return false
end

function find_random_recording_slot()
  -- random slot selection
  local _recorded_slots = {}
  for _i, _value in ipairs(recording_slots) do
    if _value.inputs and #_value.inputs > 0 then
      table.insert(_recorded_slots, _i)
    end
  end

  if #_recorded_slots > 0 then
    local _total_weight = 0
    for _i, _value in pairs(_recorded_slots) do
      _total_weight = _total_weight + recording_slots[_value].weight
    end

    local _random_slot_weight = 0
    if _total_weight > 0 then
      _random_slot_weight = math.ceil(math.random(_total_weight))
    end
    local _random_slot = 1
    local _weight_i = 0
    for _i, _value in ipairs(_recorded_slots) do
      if _weight_i <= _random_slot_weight and _weight_i + recording_slots[_value].weight >= _random_slot_weight then
        _random_slot = _i
        break
      end
      _weight_i = _weight_i + recording_slots[_value].weight
    end
    return _recorded_slots[_random_slot]
  end
  return -1
end

function go_to_next_ordered_slot()
  local _slot = -1
  for _i = 1, recording_slot_count do
    local _slot_index = ((last_ordered_recording_slot - 1 + _i) % recording_slot_count) + 1
    --print(_slot_index)
    if recording_slots[_slot_index].inputs ~= nil and #recording_slots[_slot_index].inputs > 0 then
      _slot = _slot_index
      last_ordered_recording_slot = _slot
      break
    end
  end
  return _slot
end

function set_recording_state(_input, _state)
  if (_state == current_recording_state) then
    return
  end

  -- exit states
  if current_recording_state == 1 then
  elseif current_recording_state == 2 then
    swap_characters = false
  elseif current_recording_state == 3 then
    local _first_input = 1
    local _last_input = 1
    for _i, _value in ipairs(recording_slots[training_settings.current_recording_slot].inputs) do
      if #_value > 0 then
        _last_input = _i
      elseif _first_input == _i then
        _first_input = _first_input + 1
      end
    end

    _last_input = math.max(current_recording_last_idle_frame, _last_input)

    if not training_settings.auto_crop_recording_start then
      _first_input = 1
    end

    if not training_settings.auto_crop_recording_end or _last_input ~= current_recording_last_idle_frame then
      _last_input = #recording_slots[training_settings.current_recording_slot].inputs
    end

    local _cropped_sequence = {}
    for _i = _first_input, _last_input do
      table.insert(_cropped_sequence, recording_slots[training_settings.current_recording_slot].inputs[_i])
    end
    recording_slots[training_settings.current_recording_slot].inputs = _cropped_sequence

    save_training_data()

    swap_characters = false
  elseif current_recording_state == 4 then
    clear_input_sequence(dummy)
  end

  current_recording_state = _state

  -- enter states
  if current_recording_state == 1 then
  elseif current_recording_state == 2 then
    swap_characters = true
    make_input_empty(_input)
  elseif current_recording_state == 3 then
    current_recording_last_idle_frame = -1
    swap_characters = true
    make_input_empty(_input)
    recording_slots[training_settings.current_recording_slot].inputs = {}
  elseif current_recording_state == 4 then
    local _replay_slot = -1
    if override_replay_slot > 0 then
      _replay_slot = override_replay_slot
    else
      if training_settings.replay_mode == 2 or training_settings.replay_mode == 5 then
        _replay_slot = find_random_recording_slot()
      elseif training_settings.replay_mode == 3 or training_settings.replay_mode == 6 then
        _replay_slot = go_to_next_ordered_slot()
      else
        _replay_slot = training_settings.current_recording_slot
      end
    end

    if _replay_slot > 0 then
      queue_input_sequence(dummy, recording_slots[_replay_slot].inputs)
    end
  end
end

function update_recording(_input)

  local _input_buffer_length = 11
  if is_in_match and not is_menu_open then

    -- manage input
    local _input_pressed = (not swap_characters and player.input.pressed.coin) or (swap_characters and dummy.input.pressed.coin)
    if _input_pressed then
      if frame_number < (last_coin_input_frame + _input_buffer_length) then
        last_coin_input_frame = -1

        -- double tap
        if current_recording_state == 2 or current_recording_state == 3 then
          set_recording_state(_input, 1)
        else
          set_recording_state(_input, 2)
        end

      else
        last_coin_input_frame = frame_number
      end
    end

    if last_coin_input_frame > 0 and frame_number >= last_coin_input_frame + _input_buffer_length then
      last_coin_input_frame = -1

      -- single tap
      if current_recording_state == 1 then
        if can_play_recording() then
          set_recording_state(_input, 4)
        end
      elseif current_recording_state == 2 then
        set_recording_state(_input, 3)
      elseif current_recording_state == 3 then
        set_recording_state(_input, 1)
      elseif current_recording_state == 4 then
        set_recording_state(_input, 1)
      end

    end

    -- tick states
    if current_recording_state == 1 then
    elseif current_recording_state == 2 then
    elseif current_recording_state == 3 then
      local _frame = {}

      for _key, _value in pairs(_input) do
        local _prefix = _key:sub(1, #player.prefix)
        if (_prefix == player.prefix) then
          local _input_name = _key:sub(1 + #player.prefix + 1)
          if (_input_name ~= "Coin" and _input_name ~= "Start") then
            if (_value) then
              local _sequence_input_name = stick_input_to_sequence_input(player, _input_name)
              --print(_input_name.." ".._sequence_input_name)
              table.insert(_frame, _sequence_input_name)
            end
          end
        end
      end

      table.insert(recording_slots[training_settings.current_recording_slot].inputs, _frame)

      if player.idle_time == 1 then
        current_recording_last_idle_frame = #recording_slots[training_settings.current_recording_slot].inputs - 1
      end

    elseif current_recording_state == 4 then
      if dummy.pending_input_sequence == nil then
        set_recording_state(_input, 1)
        if can_play_recording() and (training_settings.replay_mode == 4 or training_settings.replay_mode == 5 or training_settings.replay_mode == 6) then
          set_recording_state(_input, 4)
        end
      end
    end
  end

  previous_recording_state = current_recording_state
end
