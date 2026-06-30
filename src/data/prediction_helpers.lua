-- src/data/prediction_helpers.lua
-- Prediction helpers used by both dummy_control and simulation.
-- Loaded before dummy_control and simulation to break the reverse dependency.

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
