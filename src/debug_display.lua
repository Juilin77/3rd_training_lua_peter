-- src/debug_display.lua
-- debug hitbox visualization: predicted hitboxes + move-frame hitbox scrubbing

function debug_draw_hitboxes(_player)
  --  predicted hitboxes
  if debug_settings.show_predicted_hitbox then
    local _predicted_hit = predict_hitboxes(_player, 2)
    if _predicted_hit.frame_data then
      draw_hitboxes(_predicted_hit.pos_x, _predicted_hit.pos_y, _player.flip_x, _predicted_hit.frame_data.boxes)
    end
  end

  --  move hitboxes
  local _debug_frame_data = frame_data[debug_settings.debug_character]
  if _debug_frame_data then
    local _debug_move = _debug_frame_data[debug_settings.debug_move]
    if _debug_move and _debug_move.frames then
      local _move_frame = frame_number % #_debug_move.frames

      local _debug_pos_x = _player.pos_x
      local _debug_pos_y = _player.pos_y
      local _debug_flip_x = _player.flip_x

      local _sign = 1
      if _debug_flip_x ~= 0 then _sign = -1 end
      for i = 1, _move_frame + 1 do
        _debug_pos_x = _debug_pos_x + _debug_move.frames[i].movement[1] * _sign
        _debug_pos_y = _debug_pos_y + _debug_move.frames[i].movement[2]
      end

      draw_hitboxes(_debug_pos_x, _debug_pos_y, _debug_flip_x, _debug_move.frames[_move_frame + 1].boxes)
    end
  end
end
