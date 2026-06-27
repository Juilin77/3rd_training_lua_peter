-- src/ui/special_training/hyakuretsu_training.lua

function draw_legs_gauge_group(_x, _y, _legs_object)
  local _gauge_height = 4
  local _gauge_background_color = 0xD6E7EF77
  local _gauge_valid_fill_color = 0x08CF00FF
  local _margin = 2
  local _x_offset = _margin

  gui.text(_x -8, _y, "LK", text_default_color, text_default_border_color)
  for _i=1,_legs_object.l_legs_count,1 do
    gui.image(_x + _x_offset, _y, img_LK_button_small)
    _x_offset = _x_offset + 8
  end
  _x_offset = _margin
  gui.text(_x -8, _y+8, "MK", text_default_color, text_default_border_color)
  for _i=1,_legs_object.m_legs_count,1 do
    gui.image(_x + _x_offset, _y+8, img_MK_button_small)
    _x_offset = _x_offset + 8
  end
  _x_offset = _margin
  gui.text(_x -8, _y+16, "HK", text_default_color, text_default_border_color)
  for _i=1,_legs_object.h_legs_count,1 do
    gui.image(_x + _x_offset, _y+16, img_HK_button_small)
    _x_offset = _x_offset + 8
  end
  _x_offset = _margin
  local _reset_text = "Reset"
  gui.text(_x - get_text_width(_reset_text), _y+24, _reset_text, text_default_color, text_default_border_color)
  if _legs_object.active ~= 0xFF then
    draw_gauge(_x + _margin, _y + 24, 99, _gauge_height + 1, _legs_object.reset_time / 99, _gauge_valid_fill_color, _gauge_background_color, nil, true)
    gui.text(_x + _margin + 99 + 4, _y + 24, string.format("%dF", _legs_object.reset_time), text_default_color, text_default_border_color)
  end

  return 8 + 5 + (_gauge_height * 2)
end

function special_training_hyakuretsu_draw()
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Hyakuretsu Kyaku (Chun Li)" then

    local _player = P1
    local _x = 235 --96
    local _y = 49
    local _gauge_x_scale = 4

    if training_settings.special_training_follow_character then
      local _px = _player.pos_x - screen_x + emu.screenwidth()/2
      local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
      local _half_width = 23 * _gauge_x_scale * 0.5
      _x = _px - _half_width
      _x = math.max(_x, 4)
      _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
      _y = _py - 100
    end

    local _margin = 2
    local _x_offset = _margin
    local _y_offset = 0
    local _group_y_margin = 6

    if _player.legs_state.enabled then
      draw_legs_gauge_group(_x, _y + _y_offset, _player.legs_state)
    else
      gui.text(_x -8, _y, "Hyakuretsu Kyaku not enabled \nfor this character")
    end
  end
end
