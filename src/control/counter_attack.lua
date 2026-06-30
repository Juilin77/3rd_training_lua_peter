-- src/control/counter_attack.lua
-- Dummy counter-attack control.

function update_counter_attack(_input, _attacker, _defender, _stick, _button)

  local _debug = false

  if not is_in_match then return end
  if _stick == 1 and _button == 1 then return end
  if current_recording_state == 4 then return end

  local function handle_recording()
    if button_gesture[_button] == "recording" and dummy.id == 2 then
      local _slot_index = training_settings.current_recording_slot
      if training_settings.replay_mode == 2 or training_settings.replay_mode == 5 then
        _slot_index = find_random_recording_slot()
      elseif training_settings.replay_mode == 3 or training_settings.replay_mode == 6 then
        _slot_index = go_to_next_ordered_slot()
      end
      if _slot_index < 0 then
        return
      end

      _defender.counter.recording_slot = _slot_index

      local _delay = recording_slots[_defender.counter.recording_slot].delay or 0
      local _random_deviation = recording_slots[_defender.counter.recording_slot].random_deviation or 0
      if _random_deviation <= 0 then
        _random_deviation = math.ceil(math.random(_random_deviation - 1, 0))
      else
        _random_deviation = math.floor(math.random(0, _random_deviation + 1))
      end
      if _debug then
        print(string.format("frame offset: %d", _delay + _random_deviation))
      end
      _defender.counter.attack_frame = _defender.counter.attack_frame + _delay + _random_deviation
    end
  end

  if _defender.has_just_parried then
    if _debug then
      print(frame_number.." - init ca (parry)")
    end
    log(_defender.prefix, "counter_attack", "init ca (parry)")
    _defender.counter.attack_frame = frame_number + 15
    _defender.counter.sequence, _defender.counter.offset = make_input_sequence(stick_gesture[_stick], button_gesture[_button])
    _defender.counter.ref_time = -1
    handle_recording()

  elseif _defender.has_just_been_hit or _defender.has_just_blocked then
    if _debug then
      print(frame_number.." - init ca (hit/block)")
    end
    log(_defender.prefix, "counter_attack", "init ca (hit/block)")
    _defender.counter.ref_time = _defender.recovery_time
    clear_input_sequence(_defender)
    _defender.counter.attack_frame = -1
    _defender.counter.sequence = nil
    _defender.counter.recording_slot = -1
  elseif _defender.has_just_started_wake_up or _defender.has_just_started_fast_wake_up then
    if _defender.remaining_wakeup_time == 0 then
      return
    end
    if _debug then
      print(frame_number.." - init ca (wake up)")
    end
    log(_defender.prefix, "counter_attack", "init ca (wakeup)")
    _defender.counter.attack_frame = frame_number + _defender.remaining_wakeup_time + 1 -- the +1 here means that there is an error somehere but I don't know where. the remaining wakeup time seems ok
    _defender.counter.sequence, _defender.counter.offset = make_input_sequence(stick_gesture[_stick], button_gesture[_button])
    _defender.counter.ref_time = -1
    handle_recording()
  elseif _defender.has_just_entered_air_recovery then
    clear_input_sequence(_defender)
    _defender.counter.ref_time = -1
    _defender.counter.attack_frame = frame_number + 100
    _defender.counter.sequence, _defender.counter.offset = make_input_sequence(stick_gesture[_stick], button_gesture[_button])
    _defender.counter.air_recovery = true
    handle_recording()
    log(_defender.prefix, "counter_attack", "init ca (air)")
  end

  if not _defender.counter.sequence then
    if _defender.counter.ref_time ~= -1 and _defender.recovery_time ~= _defender.counter.ref_time then
      if _debug then
        print(frame_number.." - setup ca")
      end
      log(_defender.prefix, "counter_attack", "setup ca")
      _defender.counter.attack_frame = frame_number + _defender.recovery_time + 2

      -- special character cases
      if _defender.is_crouched then
        if (_defender.char_str == "q" or _defender.char_str == "ryu" or _defender.char_str == "chunli") then
          _defender.counter.attack_frame = _defender.counter.attack_frame + 2
        end
      else
        if _defender.char_str == "q" then
          _defender.counter.attack_frame = _defender.counter.attack_frame + 1
        end
      end

      _defender.counter.sequence, _defender.counter.offset = make_input_sequence(stick_gesture[_stick], button_gesture[_button])
      _defender.counter.ref_time = -1
      handle_recording()
    end
  end


  if _defender.counter.sequence then
    if _defender.counter.air_recovery then
      local _frames_before_landing = predict_frames_before_landing(_defender)
      if _frames_before_landing > 0 then
        _defender.counter.attack_frame = frame_number + _frames_before_landing + 2
      elseif _frames_before_landing == 0 then
        _defender.counter.attack_frame = frame_number
      end
    end
    local _frames_remaining = _defender.counter.attack_frame - frame_number
    if _debug then
      print(_frames_remaining)
    end
    if _frames_remaining <= (#_defender.counter.sequence + 1) then
      if _debug then
        print(frame_number.." - queue ca")
      end
      log(_defender.prefix, "counter_attack", string.format("queue ca %d", _frames_remaining))
      queue_input_sequence(_defender, _defender.counter.sequence, _defender.counter.offset)
      _defender.counter.sequence = nil
      _defender.counter.attack_frame = -1
      _defender.counter.air_recovery = false
    end
  elseif button_gesture[_button] == "recording" and _defender.counter.recording_slot > 0 then
    if _defender.counter.attack_frame <= (frame_number + 1) then
      if training_settings.replay_mode == 2 or training_settings.replay_mode == 3 or training_settings.replay_mode == 5 or training_settings.replay_mode == 6 then
        override_replay_slot = _defender.counter.recording_slot
      end
      if _debug then
        print(frame_number.." - queue recording")
      end
      log(_defender.prefix, "counter_attack", "queue recording")
      _defender.counter.attack_frame = -1
      _defender.counter.recording_slot = -1
      _defender.counter.air_recovery = false
      set_recording_state(_input, 1)
      set_recording_state(_input, 4)
      override_replay_slot = -1
    end
  end
end
