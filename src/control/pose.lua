-- src/control/pose.lua
-- Dummy pose control.

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
