-- src/control/dummy_control.lua
-- Dummy control logic: Pose, Blocking, Counter Attack, Tech Throw

function update_pose(_input, _player_obj, _pose)

if current_recording_state == 4 then -- Replaying
  return
end

if is_in_match and not is_menu_open and not is_playing_input_sequence(_player_obj) then
  local _on_ground = is_state_on_ground(_player_obj.standing_state, _player_obj)
  local _is_waking_up = _player_obj.is_wakingup and _player_obj.is_past_wakeup_frame

  if _pose == 2 and (_on_ground or _is_waking_up) then -- crouching
    _input[_player_obj.prefix..' Down'] = true
  elseif _pose == 3 and _on_ground then -- Forward Jump
    queue_input_sequence(_player_obj, {{"up", "forward"}, {"up", "forward"}, {"up", "forward"}})
  elseif _pose == 4 and _on_ground then -- Neutral Jump
    _input[_player_obj.prefix..' Up'] = true
  elseif _pose == 5 and _on_ground then -- Back Jump
    queue_input_sequence(_player_obj, {{"up", "back"}, {"up", "back"}, {"up", "back"}})
  elseif _pose == 6 and _on_ground then -- Super Fwd Jump
    queue_input_sequence(_player_obj, {{"down"}, {"up", "forward"}, {"up", "forward"}, {"up", "forward"}})
  elseif _pose == 7 and _on_ground then -- Super Jump
    queue_input_sequence(_player_obj, {{"down"}, {"up"}, {"up"}, {"up"}})
  elseif _pose == 8 and _on_ground then -- Super Back Jump
    queue_input_sequence(_player_obj, {{"down"}, {"up", "back"}, {"up", "back"}, {"up", "back"}})
  elseif _pose == 9 and _on_ground then -- Forward Dash
    queue_input_sequence(_player_obj, {{"forward"}, {}, {"forward"}})
  elseif _pose == 10 and _on_ground then -- Back Dash
    queue_input_sequence(_player_obj, {{"back"}, {}, {"back"}})
  end
end
end

-- BLOCKING

function find_move_frame_data(_char_str, _animation_id)
  if not frame_data[_char_str] then return nil end
  return frame_data[_char_str][_animation_id]
end

function predict_object_position(_object, _frames_prediction, _movement_cycle, _lifetime)
  local _result = {
    _object.pos_x,
    _object.pos_y,
  }

  if _frames_prediction == 0 then
    return _result
  end

  -- case of supplied movement pattern
  _lifetime = _lifetime or 0
  if _movement_cycle ~= nil then
    local _sign = 1
    if _object.flip_x ~= 0 then _sign = -1 end
    local _cycle_length = #_movement_cycle
    for _i = _lifetime, _lifetime + _frames_prediction - 1 do
      local _movement_index = (_i % _cycle_length) + 1
      _result[1] = _result[1] + _movement_cycle[_movement_index][1] * _sign
      _result[2] = _result[2] + _movement_cycle[_movement_index][2]
    end
    return _result
  end

  local _last_velocity_sample = _object.velocity_samples[#_object.velocity_samples]
  local _velocity_x = _last_velocity_sample.x + _object.acc.x * _frames_prediction
  local _velocity_y = _last_velocity_sample.y + _object.acc.y * _frames_prediction

  _result[1] = _result[1] + _velocity_x * _frames_prediction
  _result[2] = _result[2] + _velocity_y * _frames_prediction
  return _result
end

function predict_frames_before_landing(_player_obj, _max_lookahead_frames)
  _max_lookahead_frames = _max_lookahead_frames or 15
  if _player_obj.pos_y == 0 then
    return 0
  end

  local _result = -1
  for _i = 1, _max_lookahead_frames do
    local _pos = predict_object_position(_player_obj, _i)
    if _pos[2] <= 3 then
      _result = _i
      break
    end
  end
  return _result
end

function predict_hitboxes(_player_obj, _frames_prediction)
  local _debug = false
  local _result = {
    frame = 0,
    frame_data = nil,
    hit_id = 0,
    pos_x = 0,
    pos_y = 0,
  }

  local _frame_data = find_move_frame_data(_player_obj.char_str, _player_obj.relevant_animation)
  if not _frame_data then return _result end

  local _frame_data_meta = frame_data_meta[_player_obj.char_str] and frame_data_meta[_player_obj.char_str].moves[_player_obj.relevant_animation] or nil

  local _frame = _player_obj.relevant_animation_frame
  local _frame_to_check = _frame + _frames_prediction
  local _current_animation_pos = {_player_obj.pos_x, _player_obj.pos_y}
  local _frame_delta = _frame_to_check - _frame

  --print(string.format("update blocking frame %d (freeze: %d)", _frame, _player_obj.current_animation_freeze_frames - 1))

  local _next_hit_id = 1
  for i = 1, #_frame_data.hit_frames do
    if _frame_data.hit_frames[i] ~= nil then
      if type(_frame_data.hit_frames[i]) == "number" then
        if _frame_to_check >= _frame_data.hit_frames[i] then
          _next_hit_id = i
        end
      else
        --print(string.format("%d/%d", _frame_to_check, _frame_data.hit_frames[i].max))
        if _frame_to_check > _frame_data.hit_frames[i].max then
          _next_hit_id = i + 1
        end
      end
    end
  end

  if _next_hit_id > #_frame_data.hit_frames then return _result end

  if _frame_to_check < #_frame_data.frames then
    local _next_frame = _frame_data.frames[_frame_to_check + 1]
    local _sign = 1
    if _player_obj.flip_x ~= 0 then _sign = -1 end
    local _next_attacker_pos = copytable(_current_animation_pos)
    local _movement_type = 1
    if _frame_data_meta and _frame_data_meta.movement_type then
      _movement_type = _frame_data_meta.movement_type
    end
    if _movement_type == 1 then -- animation base movement
      for i = _frame + 1, _frame_to_check do
        if i >= 0 then
          _next_attacker_pos[1] = _next_attacker_pos[1] + _frame_data.frames[i+1].movement[1] * _sign
          _next_attacker_pos[2] = _next_attacker_pos[2] + _frame_data.frames[i+1].movement[2]
        end
      end
    else -- velocity based movement
      _next_attacker_pos = predict_object_position(_player_obj, _frame_delta)
    end

    _result.frame = _frame_to_check
    _result.frame_data = _next_frame
    _result.hit_id = _next_hit_id
    _result.pos_x = _next_attacker_pos[1]
    _result.pos_y = _next_attacker_pos[2]

    if _debug then
      print(string.format(" predicted frame %d: %d hitboxes, hit %d, at %d:%d", _result.frame, #_result.frame_data.boxes, _result.hit_id, _result.pos_x, _result.pos_y))
    end
  end
  return _result
end

function predict_hurtboxes(_player_obj, _frames_prediction)
  -- There don't seem to be a need for exact idle animation hurtboxes prediction, so let's return the current hurtboxes for the general case
  local _result = _player_obj.boxes

  -- If we wake up, we need to foresee the position of the hurtboxes in the frame data so we can block frame 1
  if _player_obj.is_wakingup and frame_data[_player_obj.char_str] then
    local _idle_startup_frame_data = frame_data[_player_obj.char_str].wakeup_to_idle
    local _idle_frame_data = frame_data[_player_obj.char_str].idle
    if _idle_startup_frame_data ~= nil and _idle_frame_data ~= nil then
      local _wakeup_frame = _frames_prediction - _player_obj.remaining_wakeup_time
      if _wakeup_frame >= 0 then
        if _wakeup_frame <= #_idle_startup_frame_data.frames then
          _result = _idle_startup_frame_data.frames[_wakeup_frame + 1].boxes
        else
          local _frame_index = ((_wakeup_frame - #_idle_startup_frame_data.frames) % #_idle_frame_data.frames) + 1
          _result = _idle_frame_data.frames[_frame_index].boxes
        end
      end
    end
  end
  return _result
end

local function _hurtbox_dist(_attacker, _defender)
  local _near_x = nil
  for _, _box in ipairs(_defender.boxes) do
    if _box.type == "vulnerability" or _box.type == "ext. vulnerability" then
      local _edge
      if _defender.flip_x ~= 0 then
        -- facing left: left_edge = pos_x - left - width, right_edge = pos_x - left
        _edge = (_attacker.pos_x < _defender.pos_x)
                and (_defender.pos_x - _box.left - _box.width)
                or  (_defender.pos_x - _box.left)
      else
        -- facing right: left_edge = pos_x + left, right_edge = pos_x + left + width
        _edge = (_attacker.pos_x < _defender.pos_x)
                and (_defender.pos_x + _box.left)
                or  (_defender.pos_x + _box.left + _box.width)
      end
      if _near_x == nil
         or (_attacker.pos_x < _defender.pos_x and _edge < _near_x)
         or (_attacker.pos_x >= _defender.pos_x and _edge > _near_x) then
        _near_x = _edge
      end
    end
  end
  return _near_x ~= nil and math.abs(_attacker.pos_x - _near_x)
                         or math.abs(_attacker.pos_x - _defender.pos_x)
end

function update_blocking(_input, _player, _dummy, _mode, _style, _red_parry_hit_count)

  local _debug = false

  -- ensure variables
  _dummy.blocking.blocked_hit_count = _dummy.blocking.blocked_hit_count or 0
  _dummy.blocking.expected_attack_animation_hit_frame = _dummy.blocking.expected_attack_animation_hit_frame or 0
  _dummy.blocking.expected_attack_hit_id = _dummy.blocking.expected_attack_hit_id or 0
  _dummy.blocking.last_attack_hit_id = _dummy.blocking.last_attack_hit_id or 0
  _dummy.blocking.is_bypassing_freeze_frames = _dummy.blocking.is_bypassing_freeze_frames or false
  _dummy.blocking.bypassed_freeze_frames = _dummy.blocking.bypassed_freeze_frames or 0
  _dummy.blocking.sa_preblock = _dummy.blocking.sa_preblock or false
  _dummy.blocking.sa_preblock_anim = _dummy.blocking.sa_preblock_anim or nil
  _dummy.blocking.sa_preblock_expire = _dummy.blocking.sa_preblock_expire or nil
  _dummy.blocking.sa_preblock_triggered = _dummy.blocking.sa_preblock_triggered or nil
  _dummy.blocking.carry_hold_remaining = _dummy.blocking.carry_hold_remaining or 0
  _dummy.blocking.carry_global_expected = _dummy.blocking.carry_global_expected or nil
  _dummy.blocking.carry_offset_fired = _dummy.blocking.carry_offset_fired or false
  _dummy.blocking.sa_p2_frame = _dummy.blocking.sa_p2_frame or nil

  function stop_listening_hits(_player_obj)
    _dummy.blocking.listening = false
    _dummy.blocking.should_block = false
  end

  function stop_listening_projectiles(_player_obj)
    if _dummy.blocking.listening_projectiles then
      log(_dummy.prefix, "blocking", "listening proj 0")
    end
    if _dummy.blocking.should_block_projectile then
      log(_dummy.prefix, "blocking", "block proj 0")
    end
    _dummy.blocking.listening_projectiles = false
    _dummy.blocking.should_block_projectile = false
    _dummy.blocking.expected_projectile = nil
  end

  function reset_parry_cooldowns(_player_obj)
    memory.writebyte(_player_obj.parry_forward_cooldown_time_addr, 0)
    memory.writebyte(_player_obj.parry_down_cooldown_time_addr, 0)
    memory.writebyte(_player_obj.parry_air_cooldown_time_addr, 0)
    memory.writebyte(_player_obj.parry_antiair_cooldown_time_addr, 0)
  end

  if not is_in_match then
    return
  end

  -- exit if playing recording
  if current_recording_state == 4 then
    stop_listening_hits(_dummy)
    stop_listening_projectiles(_dummy)
    return
  end

  if _dummy.is_idle then
    _dummy.blocking.blocked_hit_count = 0
  end

  local _pre_block_string = _dummy.blocking.block_string  -- snapshot block_string before it may be cleared

  -- blockstring detection
  if ((_dummy.blocking.should_block and not _dummy.blocking.randomized_out) or (_dummy.blocking.should_block_projectile and not _dummy.blocking.projectile_randomized_out)) and _dummy.blocking.wait_for_block_string then
    _dummy.blocking.block_string = true
    _dummy.blocking.wait_for_block_string = false
    log(_dummy.prefix, "block_string", string.format("blockstring 1"))
  end
  if _dummy.blocking.block_string then
    if _dummy.has_just_parried or _dummy.has_just_been_hit or (_dummy.remaining_freeze_frames == 0 and _dummy.recovery_time == 0 and _dummy.previous_recovery_time == 1 and not _dummy.blocking.should_block) then
      _dummy.blocking.block_string = false
      log(_dummy.prefix, "block_string", string.format("blockstring 0 (%d, %d, %d, %d, %d)", to_bit(_dummy.has_just_parried), to_bit(_dummy.has_just_been_hit), _dummy.blocking.last_attack_hit_id, _dummy.blocking.expected_attack_hit_id, _dummy.recovery_time))
    end
  elseif not _dummy.blocking.wait_for_block_string then
    if (
        _dummy.has_just_parried or
        ((_dummy.blocking.expected_attack_hit_id == _dummy.blocking.last_attack_hit_id or not _dummy.blocking.listening) and _dummy.is_idle and _dummy.idle_time > 20)
       ) then
      _dummy.blocking.wait_for_block_string = true
      log(_dummy.prefix, "block_string", string.format("wait blockstring (%d, %d, %d)",  _dummy.blocking.expected_attack_hit_id, _dummy.blocking.last_attack_hit_id, _dummy.idle_time))
    end
  end

  if _dummy.blocking.is_bypassing_freeze_frames then
    _dummy.blocking.bypassed_freeze_frames = _dummy.blocking.bypassed_freeze_frames + 1
  end
  local _player_relevant_animation_frame = _player.relevant_animation_frame + _dummy.blocking.bypassed_freeze_frames

  -- new animation
  if _player.has_relevant_animation_just_changed then
    if (
      (frame_data[_player.char_str] and frame_data[_player.char_str][_player.relevant_animation])
      or (frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation])
    ) then
      -- known animation, start listening
      _dummy.blocking.listening = true
      _dummy.blocking.expected_attack_animation_hit_frame = 0
      _dummy.blocking.expected_attack_hit_id = 0
      _dummy.blocking.last_attack_hit_id = 0
      if _dummy.blocking.is_bypassing_freeze_frames then
        log(_dummy.prefix, "blocking", string.format("bypassing end&reset"))
      end
      _dummy.blocking.is_bypassing_freeze_frames = false
      _dummy.blocking.bypassed_freeze_frames = 0
      -- if mid-combo (block_string=true or within carry window) and new anim is a meta-only attack, continue blocking immediately
      local _in_carry_window = _dummy.blocking.last_carry_frame and (frame_number - _dummy.blocking.last_carry_frame <= 5)
      local _new_meta = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
      -- on force_recording SA anim switch (e.g. SA2 894c→8be4), preserve should_block across the animation boundary
      -- otherwise Phase 2's should_block=true gets cleared on the switch frame and the first hit goes unblocked
      local _preserve_should_block = _pre_block_string and _new_meta and _new_meta.force_recording and _new_meta.hits
      if not _preserve_should_block then
        _dummy.blocking.should_block = false
      end
      if _pre_block_string or _in_carry_window then
        if _new_meta and _new_meta.force_recording and _new_meta.hits then
          _dummy.blocking.block_string = true  -- carry still active, keep block_string so subsequent chain is unbroken
          _dummy.blocking.last_carry_frame = frame_number
          if _new_meta.first_hit_offset and not _dummy.blocking.carry_global_expected then
            _dummy.blocking.carry_global_expected = frame_number + _new_meta.first_hit_offset
            _dummy.blocking.carry_offset_fired = false
          end
        end
      end
      reset_parry_cooldowns(_dummy)

      log(_dummy.prefix, "blocking", string.format("listening %s", _player.relevant_animation))
      if _debug then
        print(string.format("%d - %s listening for attack animation \"%s\" (starts at frame %d)", frame_number, _dummy.prefix, _player.relevant_animation, _player.relevant_animation_start_frame))
      end
    else
      -- unknown animation, stop listening
      if _dummy.blocking.listening then
        log(_dummy.prefix, "blocking", string.format("stopped listening"))
        if _debug then
          print(string.format("%d - %s stopped listening for attack animation", frame_number, _dummy.prefix))
        end
        stop_listening_hits(_dummy)
      end
    end
  end

  if _mode == 1 or _dummy.throw.listening == true then
    stop_listening_hits(_dummy)
    stop_listening_projectiles(_dummy)
    return
  end

  function get_meta_hit(_character_str, _move_id, _hit_id)
    local _character_meta = frame_data_meta[_character_str]
    if _character_meta == nil then return nil end
    if _character_meta.moves == nil then return nil end
    local _move_meta = _character_meta.moves[_player.relevant_animation]
    if _move_meta == nil then return nil end
    if _move_meta.hits == nil then return nil end
    if _move_meta.hits[_hit_id] == nil then return nil end
    return _move_meta.hits[_hit_id]
  end

  -- update blocked hit count
  if _dummy.has_just_blocked or _dummy.has_just_parried then
    _dummy.blocking.blocked_hit_count = _dummy.blocking.blocked_hit_count + 1
  end


  -- check if the hit we are expecting has expired or not
  local _hit_expired = false
  if _dummy.blocking.expected_attack_hit_id > 0 then
    local _frame_data = find_move_frame_data(_player.char_str, _player.relevant_animation)
    if _frame_data then
      local _hit_frame = _frame_data.hit_frames[_dummy.blocking.expected_attack_hit_id]
      local _last_hit_frame = 0
      if _hit_frame ~= nil then
        if type(_hit_frame) == "number" then
          _last_hit_frame = _hit_frame
        else
          _last_hit_frame = _hit_frame.max
        end
      else
        t_assert(false, string.format("unknown hit id, what is happening ? (anim:%s, hit:%d)", _player.relevant_animation, _dummy.blocking.expected_attack_hit_id))
      end
      local _frame = frame_number - _player.current_animation_start_frame - _player.current_animation_freeze_frames
      _hit_expired = _frame > _last_hit_frame
    end
  end
  if _dummy.blocking.should_block_projectile and _dummy.blocking.projectile_hit_frame < frame_number then
    _hit_expired = true
  end

  -- increment hit id
  if _dummy.has_just_blocked or _dummy.has_just_parried or _dummy.has_just_been_hit or _hit_expired then
    log(_dummy.prefix, "blocking", string.format("next hit %d>%d %d", _dummy.blocking.last_attack_hit_id, _dummy.blocking.expected_attack_hit_id, to_bit(_hit_expired)))
    _dummy.blocking.last_attack_hit_id = _dummy.blocking.expected_attack_hit_id
    _dummy.blocking.expected_attack_hit_id = 0
    _dummy.blocking.should_block = false
    _dummy.blocking.should_block_projectile = false
    _dummy.blocking.expected_projectile = nil
    local _relevant_hit = get_meta_hit(_player.char_str, _player.relevant_animation, _player.last_attack_hit_id)
    if _relevant_hit and _player.remaining_freeze_frames > 0 and _relevant_hit.bypass_freeze then
      _dummy.blocking.is_bypassing_freeze_frames = true
      log(_dummy.prefix, "blocking", string.format("bypassing start"))
    elseif _dummy.blocking.is_bypassing_freeze_frames then
      _dummy.blocking.is_bypassing_freeze_frames = false
      log(_dummy.prefix, "blocking", string.format("bypassing end"))
    end
    -- force_recording carry chain (e.g. SA2): uses global frame_number for timing, unaffected by animation loop resets
    -- carry_offset = frames until next hit from now (SA2 = 45); omit to use carry_hold_remaining as short fallback
    do
      local _cur_meta = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
      if _cur_meta and _cur_meta.force_recording and _cur_meta.hits then
        -- Phase 2 not triggered but SA hit close up (has_just_been_hit): start carry from the hit frame
        if _dummy.has_just_been_hit then
          _dummy.blocking.block_string = true
        end
        if _dummy.blocking.block_string then
          _dummy.blocking.should_block = true
          -- carry_hold_short: after first carry_offset fires, use short hold so hits 3+ are segmented via fallback
          local _hold_val = (_cur_meta.carry_hold_short and _dummy.blocking.carry_offset_fired) and _cur_meta.carry_hold_short or 15
          _dummy.blocking.carry_hold_remaining = _hold_val
          -- SA2 segmented block: carry_hold set at carry fire time, not at hit event
          if _dummy.blocking.sa_p2_frame then
            _dummy.blocking.carry_hold_remaining = 0
          end
          if _cur_meta.carry_offset and not _dummy.blocking.carry_offset_fired then
            _dummy.blocking.carry_global_expected = frame_number + _cur_meta.carry_offset
          end
          -- in short carry mode: reset animation hit frame to prevent stale negative delta causing continuous blocking
          -- also reset expected_attack_hit_id so sub-frame fallback can re-detect subsequent hits
          -- (SA2 8be4 returns hit_id=0 for all hits, so last_attack_hit_id+1 would stay at 1 forever)
          if _dummy.blocking.carry_offset_fired then
            _dummy.blocking.expected_attack_animation_hit_frame = _player.relevant_animation_frame + 999
            _dummy.blocking.expected_attack_hit_id = 0
            -- segmented carry sequence: use p2_frame + offset to predict each chip hit timing
            -- hit2 is at P2+107 (60f after hit1); hits3+ every 7f → short_carry_offset=5
            if _dummy.blocking.sa_p2_frame and _cur_meta.p2_hit2_offset
               and (frame_number - _dummy.blocking.sa_p2_frame) < 80 then
              -- after hit1 block: set carry for hit2
              _dummy.blocking.carry_global_expected = _dummy.blocking.sa_p2_frame + _cur_meta.p2_hit2_offset
            elseif _cur_meta.short_carry_offset then
              -- after hit2+ block: use short interval (hits every 7f)
              _dummy.blocking.carry_global_expected = frame_number + _cur_meta.short_carry_offset
            end
          end
        end
      end
    end
  elseif _dummy.blocking.last_attack_hit_id < _player.next_hit_id - 1 then
    local _next_hit = _player.next_hit_id - 1
    log(_dummy.prefix, "blocking", string.format("missed hit %d>%d", _dummy.blocking.last_attack_hit_id, _next_hit))
    _dummy.blocking.last_attack_hit_id = _next_hit
    _dummy.blocking.expected_attack_hit_id = 0
    _dummy.blocking.should_block = false
    reset_parry_cooldowns(_dummy)
  end

  -- force_recording exit: SA anim ends (switches to non-force_recording) → clear block_string, stop carry
  -- prevents dummy from continuing to hold back after SA2 ends
  do
    local _cur_fdm  = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
    local _prev_fdm = _dummy.blocking.last_player_anim and frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_dummy.blocking.last_player_anim]
    if _dummy.blocking.block_string and _prev_fdm and _prev_fdm.force_recording and not (_cur_fdm and _cur_fdm.force_recording) then
      _dummy.blocking.block_string = false
      _dummy.blocking.should_block = false
      _dummy.blocking.carry_global_expected = nil
      _dummy.blocking.carry_offset_fired = false
    end
    _dummy.blocking.last_player_anim = _player.relevant_animation
  end

  -- Super Freeze Pre-Block Phase 1 (TODO 1.33): prime sa_preblock during freeze
  -- does not set should_block; dummy stays neutral; Phase 2 forces block only after all predictions fail
  -- sa_preblock_triggered (cleared only on anim end) ensures Phase 2 fires at most once per SA anim
  if _player.superfreeze_decount > 0 and not _dummy.blocking.sa_preblock_triggered then
    _dummy.blocking.sa_preblock = true
    _dummy.blocking.sa_preblock_anim = _dummy.blocking.sa_preblock_anim or _player.relevant_animation
  end

  if _dummy.blocking.listening then
    log(_player.prefix, "blocking", string.format("frame %d", _player_relevant_animation_frame))

    -- move has probably changed, therefore we reset hit id
    if _player.highest_hit_id == 0 and _dummy.blocking.last_attack_hit_id > 0 and _player.remaining_freeze_frames == 0 then
      log(_dummy.prefix, "blocking", string.format("reset hits"))
      if _debug then
        print(string.format("%d - reset last hit (%d, %d)", frame_number, _player.highest_hit_id, _dummy.blocking.last_attack_hit_id))
      end
      _dummy.blocking.last_attack_hit_id = 0
      _dummy.blocking.expected_attack_hit_id = 0
      if _dummy.blocking.is_bypassing_freeze_frames then
        log(_dummy.prefix, "blocking", string.format("bypassing end&reset"))
      end
      _dummy.blocking.is_bypassing_freeze_frames = false
      _dummy.blocking.bypassed_freeze_frames = 0
      _dummy.blocking.should_block = false
      reset_parry_cooldowns(_dummy)
    end

    --if (_dummy.blocking.expected_attack_animation_hit_frame < frame_number or _dummy.blocking.last_attack_hit_id == _dummy.blocking.expected_attack_hit_id) then
    if (_dummy.blocking.expected_attack_hit_id == 0 and not _dummy.blocking.should_block) then
      local _max_prediction_frames = 3
      for i = 1, _max_prediction_frames do
        local predicted_frame_id = i + _dummy.blocking.bypassed_freeze_frames
        local _predicted_hit = predict_hitboxes(_player, predicted_frame_id)
        if _predicted_hit.frame_data then
          local _frame_delta = _predicted_hit.frame - _player_relevant_animation_frame
          local _next_defender_pos = predict_object_position(_dummy, _frame_delta)

          --log(_dummy.prefix, "blocking", string.format("%d,%d", _predicted_hit.frame, _predicted_hit.hit_id))

          local _box_type_matches = {{{"vulnerability", "ext. vulnerability"}, {"attack"}}}
          if frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation] and frame_data_meta[_player.char_str].moves[_player.relevant_animation].hit_throw then
            table.insert(_box_type_matches, {{"throwable"}, {"throw"}})
          end

          -- Add dilation to attacker hit box
          local _meta_hit = get_meta_hit(_player.char_str, _player.relevant_animation, _predicted_hit.hit_id)
          local _attacker_box_dilation = 0
          if _meta_hit and _meta_hit.dilation then
            _attacker_box_dilation = _meta_hit.dilation
          end

          local _defender_boxes = predict_hurtboxes(_dummy, _frame_delta)

          if _predicted_hit.hit_id > _dummy.blocking.last_attack_hit_id and test_collision(
            _next_defender_pos[1], _next_defender_pos[2], _dummy.flip_x, _defender_boxes, -- defender
            _predicted_hit.pos_x, _predicted_hit.pos_y, _player.flip_x, _predicted_hit.frame_data.boxes, -- attacker
            _box_type_matches,
            0, -- defender hitbox dilation x
            4, -- defender hitbox dilation y
            _attacker_box_dilation, -- x
            _attacker_box_dilation -- y
          ) then
            _dummy.blocking.expected_attack_animation_hit_frame = _predicted_hit.frame
            _dummy.blocking.expected_attack_hit_id = _predicted_hit.hit_id
            _dummy.blocking.should_block = true
            _dummy.blocking.randomized_out = false
            _dummy.blocking.has_pre_parried = false
            _dummy.blocking.is_precise_timing = false
            log(_dummy.prefix, "blocking", string.format("block in %d", _dummy.blocking.expected_attack_animation_hit_frame - _player_relevant_animation_frame))

            if _mode == 3 then -- combo only
              if not _dummy.blocking.block_string and not _dummy.blocking.wait_for_block_string then
                _dummy.blocking.should_block = false
              end
            elseif _mode == 4 then -- random
              if not _dummy.blocking.block_string then
                local _r = math.random()
                if _r > 0.5 then
                  _dummy.blocking.randomized_out = true
                  if _debug then
                    print(string.format(" %d: next hit randomized out", frame_number))
                  end
                end
              end
            end

            if _debug then
              print(string.format(" %d: next hit %d at frame %d (%d), last hit %d", frame_number, _dummy.blocking.expected_attack_hit_id, _predicted_hit.frame, _dummy.blocking.expected_attack_animation_hit_frame, _dummy.blocking.last_attack_hit_id))
            end

            break
          end
        end
        -- proxy_hits: SA sub-frame 距離型預測（sa_preblock primed + framedata_meta 有 proxy_hits 才生效）
        if not _dummy.blocking.should_block and _dummy.blocking.sa_preblock then
          local _proxy_fdm = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
          if _proxy_fdm and _proxy_fdm.proxy_hits and _proxy_fdm.proxy_hits[predicted_frame_id] then
            local _proxy = _proxy_fdm.proxy_hits[predicted_frame_id]
            local _next_defender_pos = predict_object_position(_dummy, 1)
            local _defender_boxes = predict_hurtboxes(_dummy, 1)
            local _box_type_matches = {{{"vulnerability", "ext. vulnerability"}, {"attack"}}}
            if test_collision(
              _next_defender_pos[1], _next_defender_pos[2], _dummy.flip_x, _defender_boxes,
              _player.pos_x, _player.pos_y, _player.flip_x, _proxy.boxes,
              _box_type_matches, 0, 4, 0, 0
            ) then
              _dummy.blocking.expected_attack_animation_hit_frame = predicted_frame_id
              _dummy.blocking.expected_attack_hit_id = _dummy.blocking.last_attack_hit_id + 1
              _dummy.blocking.should_block = true
              _dummy.blocking.randomized_out = false
              _dummy.blocking.has_pre_parried = false
              _dummy.blocking.is_precise_timing = false
              _dummy.blocking.sa_preblock = false
              log(_dummy.prefix, "blocking", string.format("proxy_hit f:%d dist:%d", predicted_frame_id, math.abs(_player.pos_x - _dummy.pos_x)))
              break
            end
          end
        end
      end

      -- Sub-frame fallback: all frame data lookups failed (animation is sub-frame, invisible to Lua)
      -- use physics simulation to collision-test against attacker's current RAM boxes
      if not _dummy.blocking.should_block and _dummy.blocking.listening then
        local _sim_hits = predict_hits_simulation(_player, _dummy, _max_prediction_frames, _dummy.blocking.last_attack_hit_id)
        local _sh = nil
        for _d = 1, _max_prediction_frames do if _sim_hits[_d] then _sh = _sim_hits[_d]; break end end
        if _sh then
          _dummy.blocking.expected_attack_animation_hit_frame = _sh.frame
          _dummy.blocking.expected_attack_hit_id = (_sh.hit_id or 0) > 0 and _sh.hit_id or (_dummy.blocking.last_attack_hit_id + 1)
          _dummy.blocking.should_block = true
          _dummy.blocking.randomized_out = false
          _dummy.blocking.has_pre_parried = false
          _dummy.blocking.is_precise_timing = false
          log(_dummy.prefix, "blocking", string.format("sim block in %d (sub-frame fallback)", _sh.delta or 1))

          if _mode == 3 then -- combo only
            if not _dummy.blocking.block_string and not _dummy.blocking.wait_for_block_string then
              _dummy.blocking.should_block = false
            end
          elseif _mode == 4 then -- random
            if not _dummy.blocking.block_string then
              local _r = math.random()
              if _r > 0.5 then
                _dummy.blocking.randomized_out = true
              end
            end
          end
        end
      end
    end
  end

  -- pre_block_frame: start blocking only when startup animation reaches the specified frame (prevents holding back too early)
  -- yields to proxy_hits when present: distance-based prediction takes priority, pre_block_frame is fallback only
  if _dummy.blocking.listening and not _dummy.blocking.should_block then
    local _pre_meta = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
    if _pre_meta and _pre_meta.pre_block_frame and _player.relevant_animation_frame >= _pre_meta.pre_block_frame then
      if not _pre_meta.proxy_hits then
        _dummy.blocking.should_block = true
        _dummy.blocking.block_string = true
        _dummy.blocking.last_carry_frame = frame_number
        log(_dummy.prefix, "blocking", string.format("pre_block %s f:%d", _player.relevant_animation, _player.relevant_animation_frame))
      end
    end
  end

  -- carry window continuous update: refresh every frame during block_string to prevent long landing anims from expiring carry
  if _dummy.blocking.should_block and _dummy.blocking.block_string then
    _dummy.blocking.last_carry_frame = frame_number
  end

  -- No-frame-data fallback：animation 不在 frame_data，但 attacker 有 RAM attack boxes
  if not _dummy.blocking.should_block and not _dummy.blocking.listening and sim_has_attack_boxes(_player.boxes) then
    local _sim_hits = predict_hits_simulation(_player, _dummy, 3, _dummy.blocking.last_attack_hit_id)
    local _sh = nil
    for _d = 1, 3 do if _sim_hits[_d] then _sh = _sim_hits[_d]; break end end
    if _sh then
      _dummy.blocking.expected_attack_animation_hit_frame = _sh.frame
      _dummy.blocking.expected_attack_hit_id = (_sh.hit_id or 0) > 0 and _sh.hit_id or (_dummy.blocking.last_attack_hit_id + 1)
      _dummy.blocking.should_block = true
      _dummy.blocking.randomized_out = false
      _dummy.blocking.has_pre_parried = false
      _dummy.blocking.is_precise_timing = false
      log(_dummy.prefix, "blocking", string.format("sim block in %d (no-framedata fallback)", _sh.delta or 1))
    end
  end

  -- projectiles
  local _valid_projectiles = {}
  for _id, _projectile_obj in pairs(projectiles) do
    if (_projectile_obj.is_forced_one_hit and _projectile_obj.remaining_hits ~= 0xFF) or _projectile_obj.remaining_hits > 0 then
      if (not _projectile_obj.has_activated or #_projectile_obj.boxes > 0) and (_projectile_obj.emitter_id ~= _dummy.id or (_projectile_obj.emitter_id == _dummy.id and _projectile_obj.is_converted)) then
        table.insert(_valid_projectiles, _projectile_obj)
      end
    end
  end
  if #_valid_projectiles > 0 then
    if not _dummy.blocking.listening_projectiles then
      log(_dummy.prefix, "blocking", "listening proj 1")
    end
    _dummy.blocking.listening_projectiles = true
  else
    stop_listening_projectiles(_dummy)
  end

  if _dummy.blocking.listening_projectiles and not _dummy.blocking.should_block_projectile then
    local _max_prediction_frames = 3
    local _box_type_matches = {{{"vulnerability", "ext. vulnerability"}, {"attack"}}}
    for _i = 1, _max_prediction_frames do
      for _j, _projectile_obj in ipairs(_valid_projectiles) do
        local _frame_delta = _i - _projectile_obj.remaining_freeze_frames
        if _frame_delta >= 0 then
          local _next_defender_pos = predict_object_position(_dummy, _frame_delta)

          local _movement = nil
          local _lifetime = _projectile_obj.lifetime
          local _projectile_meta_data = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].projectiles and frame_data_meta[_player.char_str].projectiles[_projectile_obj.projectile_start_type] or nil
          if _projectile_meta_data ~= nil then
            _movement = _projectile_meta_data.movement
          end
          local _next_projectile_pos = predict_object_position(_projectile_obj, _frame_delta, _movement, _lifetime)

          local _projectile_boxes = _projectile_obj.boxes
          -- Look into the frame data for the first frame hitboxes
          local _projectile_frame_data = frame_data[_player.char_str][_projectile_obj.projectile_start_type]
          if _projectile_frame_data ~= nil and _projectile_obj.lifetime < _projectile_frame_data.start_lifetime then
            if (_projectile_obj.lifetime + _frame_delta) >= _projectile_frame_data.start_lifetime then
              _projectile_boxes = _projectile_frame_data.boxes
            end
          end

          local _defender_boxes = predict_hurtboxes(_dummy, _frame_delta)

          if test_collision(_next_defender_pos[1], _next_defender_pos[2], _dummy.flip_x, _defender_boxes,
          _next_projectile_pos[1] , _next_projectile_pos[2], _projectile_obj.flip_x, _projectile_boxes,
          _box_type_matches,
          0, -- defender hitbox dilation
          0, -- defender hitbox dilation
          0,
          0) then
            _dummy.blocking.should_block_projectile = true
            _dummy.blocking.projectile_randomized_out = false
            _dummy.blocking.has_pre_parried = false
            _dummy.blocking.projectile_hit_frame = frame_number + _i
            _dummy.blocking.expected_projectile = _projectile_obj
            _dummy.blocking.is_precise_timing = _movement ~= nil
            log(_dummy.prefix, "blocking", string.format("block proj %s in %d", _projectile_obj.id, _i))

            if _mode == 3 then -- combo only
              if not _dummy.blocking.block_string and not _dummy.blocking.wait_for_block_string then
                _dummy.blocking.should_block_projectile = false
              end
            elseif _mode == 4 then -- random
              if not _dummy.blocking.block_string then
                local _r = math.random()
                if _r > 0.5 then
                  _dummy.blocking.projectile_randomized_out = true
                  if _debug then
                    print(string.format(" %d: next hit randomized out", frame_number))
                  end
                end
              end
            end

            break
          end
        end
      end
      if _dummy.blocking.should_block_projectile then
        break
      end
    end
  end

  -- Super Freeze Pre-Block: clear on SA anim end (independent of sa_preblock state, can run after expire)
  -- only this block clears sa_preblock_triggered, ensuring the next SA can trigger Phase 2 normally
  if _dummy.blocking.sa_preblock_anim
     and _player.relevant_animation ~= _dummy.blocking.sa_preblock_anim
     and _player.superfreeze_decount == 0 then
    -- if transitioning to a force_recording attack animation (freeze → attack), preserve blocking state
    -- this happens when the SA attack anim starts one frame after freeze ends (e.g. 8be4 vs 894c)
    local _new_fdm = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
    if _new_fdm and _new_fdm.force_recording then
      _dummy.blocking.sa_preblock_anim = _player.relevant_animation
    else
      _dummy.blocking.sa_preblock = false
      _dummy.blocking.should_block = false
      _dummy.blocking.block_string = false
      _dummy.blocking.sa_preblock_anim = nil
      _dummy.blocking.sa_preblock_expire = nil
      _dummy.blocking.sa_preblock_triggered = nil
      _dummy.blocking.carry_global_expected = nil
      _dummy.blocking.sa_p2_frame = nil
    end
  end

  -- Super Freeze Pre-Block Phase 2 (TODO 1.33): last resort after all predictions have run
  -- triggers only after SA freeze, when normal prediction fully fails (sub-frame or no-entry SA)
  -- projectile SAs like Ken SA1 are handled by should_block_projectile; this block does not intervene
  if _dummy.blocking.sa_preblock then
    if _dummy.has_just_blocked or _dummy.has_just_parried or _dummy.has_just_been_hit then
      -- blocked/hit: clear only the sa_preblock mechanism itself; leave should_block and block_string untouched
      -- should_block is already cleared at L365-371; if force_recording carry is active, L380-386 restores it before Branch 1
      -- do not clear here to avoid overwriting carry state, which would leave a gap before the second hit of a multi-hit SA
      _dummy.blocking.sa_preblock = false
      _dummy.blocking.sa_preblock_expire = nil
    elseif _dummy.blocking.sa_preblock_expire and frame_number >= _dummy.blocking.sa_preblock_expire then
      -- timeout (whiff): clear sa_preblock mechanism; block_string is left for normal logic to clear (resets when dummy returns to idle)
      _dummy.blocking.sa_preblock = false
      _dummy.blocking.should_block = false
      _dummy.blocking.sa_preblock_expire = nil
      _dummy.blocking.carry_global_expected = nil
    elseif _player.superfreeze_decount <= 1
       and not _dummy.blocking.should_block
       and not _dummy.blocking.should_block_projectile
       and not _dummy.blocking.sa_preblock_triggered then
      -- when proxy_max_dist is set, do a simple distance check: only trigger should_block if distance <= threshold (whiff at long range skips naturally)
      -- without proxy_max_dist, trigger unconditionally (SA that hits regardless of distance)
      local _ph_fdm = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
      local _dist = _hurtbox_dist(_player, _dummy)
      local _p2_trigger
      if _ph_fdm and _ph_fdm.proxy_max_dist then
        _p2_trigger = _dist <= _ph_fdm.proxy_max_dist
      else
        _p2_trigger = true  -- no distance data → trigger unconditionally
      end
      -- whether triggered or skipped, lock triggered+anim to prevent Phase 2 from re-running every frame after decount=0
      _dummy.blocking.sa_preblock_triggered = true
      _dummy.blocking.sa_preblock_anim      = _player.relevant_animation
      if _p2_trigger then
        _dummy.blocking.should_block          = true
        _dummy.blocking.sa_p2_frame           = frame_number
        _dummy.blocking.block_string          = true
        _dummy.blocking.last_carry_frame      = frame_number
        _dummy.blocking.expected_attack_hit_id = _dummy.blocking.last_attack_hit_id + 1
        -- first_hit_window: only needs to cover wait time for first hit (carry takes over after, Phase 2 is no longer needed)
        local _expire_window = (_ph_fdm and _ph_fdm.first_hit_window) or 55
        _dummy.blocking.sa_preblock_expire    = frame_number + _expire_window
        -- first_hit_offset: frames from Phase 2 to first hit → set carry_global_expected directly
        -- dummy only starts holding back 2f before the first hit, reducing whiff retreat from 55f to ~8f
        if _ph_fdm and _ph_fdm.first_hit_offset then
          _dummy.blocking.carry_global_expected = frame_number + _ph_fdm.first_hit_offset
          _dummy.blocking.carry_offset_fired = true
        end
      else
        -- out of range: clear sa_preblock so Phase 2's outer if does not re-enter on the next frame
        _dummy.blocking.sa_preblock = false
      end
    end
  end

  if (_dummy.blocking.should_block and not _dummy.blocking.randomized_out) or (_dummy.blocking.should_block_projectile and not _dummy.blocking.projectile_randomized_out) then
    local _hit_type = 1
    local _blocking_style = _style -- 2 is block, 3 is parry

    if _blocking_style == 4 then -- red parry
      if _dummy.blocking.blocked_hit_count ~= _red_parry_hit_count then
        _blocking_style = 2
      else
        _blocking_style = 3
      end
    end

    if _dummy.blocking.should_block then
      local _frame_data_meta = frame_data_meta[_player.char_str].moves[_player.relevant_animation]
      if _frame_data_meta and _frame_data_meta.hits and _frame_data_meta.hits[_dummy.blocking.expected_attack_hit_id] then
        _hit_type = _frame_data_meta.hits[_dummy.blocking.expected_attack_hit_id].type
      end
    elseif _dummy.blocking.should_block_projectile then
      local _frame_data_meta = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].projectiles and frame_data_meta[_player.char_str].projectiles[_dummy.blocking.expected_projectile.projectile_type] or nil
      if _frame_data_meta then
        _hit_type = _frame_data_meta.type
      end
    end

    local _animation_frame_delta = 0
    if _dummy.blocking.should_block_projectile then
      _animation_frame_delta = _dummy.blocking.projectile_hit_frame - frame_number
    elseif _dummy.blocking.carry_global_expected then
      -- carry uses global frame timing, unaffected by animation loop resets
      _animation_frame_delta = _dummy.blocking.carry_global_expected - frame_number
      -- when carry fires (delta <= 0), switch to short carry mode so subsequent hits are segmented
      if _animation_frame_delta <= 0 then
        _dummy.blocking.carry_global_expected = nil
        _animation_frame_delta = 99
        _dummy.blocking.should_block = true  -- ensure same-frame clear check does not clear should_block when carry fires
        if not _dummy.blocking.carry_offset_fired then
          -- Phase 2 carry expired; reset so sub-frame fallback can detect actual first hit
          _dummy.blocking.carry_offset_fired = true
          _dummy.blocking.expected_attack_hit_id = 0
        end
        -- SA2 segmented block: set carry_hold at fire time so neutral gap exists between hits
        if _dummy.blocking.sa_p2_frame then
          local _fm = frame_data_meta[_player.char_str] and frame_data_meta[_player.char_str].moves and frame_data_meta[_player.char_str].moves[_player.relevant_animation]
          if _fm and _fm.carry_hold_short then
            _dummy.blocking.carry_hold_remaining = _fm.carry_hold_short
          end
        end
      end
    else
      _animation_frame_delta = _dummy.blocking.expected_attack_animation_hit_frame - _player_relevant_animation_frame
    end

    if _blocking_style == 2 then
      local _blocking_delta_threshold = 2
      if _dummy.blocking.is_precise_timing then
        _blocking_delta_threshold = 1
      end
      local _carry_hold = _dummy.blocking.carry_hold_remaining and _dummy.blocking.carry_hold_remaining > 0
      if _carry_hold then
        _dummy.blocking.carry_hold_remaining = _dummy.blocking.carry_hold_remaining - 1
      end
      -- short carry mode: when carry expires, clear should_block so fallback can re-detect next hit
      -- sa_preblock still active = waiting for first SA hit; don't clear or the hit lands unblocked
      -- expected_attack_hit_id > 0 = sub-frame already found a target; don't clear or we lose blocking mid-hit
      if not _carry_hold and _dummy.blocking.carry_offset_fired and not _dummy.blocking.carry_global_expected and _dummy.blocking.block_string and not _dummy.blocking.sa_preblock and _dummy.blocking.expected_attack_hit_id == 0 then
        _dummy.blocking.should_block = false
      end
      if _animation_frame_delta <= _blocking_delta_threshold or _carry_hold then
        log(_dummy.prefix, "blocking", string.format("dummy block %d %d %d", _dummy.blocking.expected_attack_hit_id, to_bit(_dummy.blocking.should_block_projectile), _animation_frame_delta))
        if _debug then
          print(string.format("%d - %s blocking", frame_number, _dummy.prefix))
        end

        if not _dummy.flip_input then
          _input[_dummy.prefix..' Right'] = true
          _input[_dummy.prefix..' Left'] = false
        else
          _input[_dummy.prefix..' Right'] = false
          _input[_dummy.prefix..' Left'] = true
        end

        if _hit_type == 2 then
          _input[_dummy.prefix..' Down'] = true
        elseif _hit_type == 3 then
          _input[_dummy.prefix..' Down'] = false
        end
      end
    elseif _blocking_style == 3 then
      _input[_dummy.prefix..' Right'] = false
      _input[_dummy.prefix..' Left'] = false
      _input[_dummy.prefix..' Down'] = false

      local _parry_low = _hit_type == 2

      if not _dummy.blocking.is_bypassing_freeze_frames then
        _animation_frame_delta = _animation_frame_delta + _player.remaining_freeze_frames
      end
      if (_animation_frame_delta == 1) or (_animation_frame_delta == 2 and _dummy.blocking.has_pre_parried) then
        log(_dummy.prefix, "blocking", string.format("parry %d", _dummy.blocking.expected_attack_hit_id))
        if _debug then
          print(string.format("%d - %s parrying", frame_number, _dummy.prefix))
        end

        if _parry_low then
          _input[_dummy.prefix..' Down'] = true
        else
          _input[_dummy.prefix..' Right'] = _dummy.flip_input
          _input[_dummy.prefix..' Left'] = not _dummy.flip_input
        end
      else
        _dummy.blocking.has_pre_parried = true
        log(_dummy.prefix, "blocking", string.format("pre parry %d", _dummy.blocking.expected_attack_hit_id))
      end
    end
  end
end

function update_fast_wake_up(_input, _player, _dummy, _mode)
  if is_in_match and _mode ~= 1 and current_recording_state ~= 4 then
    local _should_tap_down = _dummy.previous_can_fast_wakeup == 0 and _dummy.can_fast_wakeup == 1

    if _should_tap_down then
      local _r = math.random()
      if _mode ~= 3 or _r > 0.5 then
        _input[dummy.prefix..' Down'] = true
      end
    end
  end
end

function update_counter_attack(_input, _attacker, _defender, _stick, _button)

  local _debug = false

  if not is_in_match then return end
  if _stick == 1 and _button == 1 then return end
  if current_recording_state == 4 then return end

  function handle_recording()
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

function update_tech_throws(_input, _attacker, _defender, _mode)
  local _debug = false

  if not is_in_match or _mode == 1 then
    _defender.throw.listening = false
    if _debug and _attacker.previous_throw_countdown > 0 then
      print(string.format("%d - %s stopped listening for throws", frame_number, _defender.prefix))
    end
    return
  end

  if _attacker.throw_countdown > _attacker.previous_throw_countdown then
    _defender.throw.listening = true
    if _debug then
      print(string.format("%d - %s listening for throws", frame_number, _defender.prefix))
    end
  end

  if _attacker.throw_countdown == 0 then
    _defender.throw.listening = false
    if _debug and _attacker.previous_throw_countdown > 0  then
      print(string.format("%d - %s stopped listening for throws", frame_number, _defender.prefix))
    end
  end

  if _defender.throw.listening then

    if test_collision(
      _defender.pos_x, _defender.pos_y, _defender.flip_x, _defender.boxes, -- defender
      _attacker.pos_x, _attacker.pos_y, _attacker.flip_x, _attacker.boxes, -- attacker
      {{{"throwable"},{"throw"}}},
      0, -- defender hitbox dilation
      0
    ) then
      _defender.throw.listening = false
      if _debug then
        print(string.format("%d - %s teching throw", frame_number, _defender.prefix))
      end
      local _r = math.random()
      if _mode ~= 3 or _r > 0.5 then
        _input[_defender.prefix..' Weak Punch'] = true
        _input[_defender.prefix..' Weak Kick'] = true
      end
    end
  end
end
