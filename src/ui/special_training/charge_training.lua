-- src/ui/special_training/charge_training.lua

function draw_charge_gauge_group(_x, _y, _charge_object)
  local _gauge_height = 3
  local _gauge_background_color = 0xD6E7EF77
  local _gauge_valid_fill_color = 0x52AAE7FF
  local _gauge_cooldown_fill_color = 0xFF9939FF
  local _success_color = 0x10FB00FF
  local _miss_color = 0xE70000FF
  local _gauge_x_scale = 1

  local _charge_gauge_width = _charge_object.max_charge * _gauge_x_scale
  local _reset_gauge_width = _charge_object.max_reset * _gauge_x_scale
  local _charge_gauge_left = math.floor(_x + (_reset_gauge_width - _charge_gauge_width) * 0.5)
  local _charge_gauge_right = _charge_gauge_left + _charge_gauge_width + 1
  local _reset_gauge_left = _x
  local _reset_gauge_right = _reset_gauge_left + _reset_gauge_width + 1
  local _charge_time_text = string.format("%d", _charge_object.charge_time)
  local _reset_time_text = string.format("%d", _charge_object.reset_time)
  local _charge_text_color = text_default_color
  local _charge_outline_color = text_default_border_color
  if _charge_object.max_charge - _charge_object.charge_time == _charge_object.max_charge then
    _charge_text_color = _success_color
    _charge_outline_color = 0x00A200FF
  else
    _charge_text_color = _miss_color
    _charge_outline_color = 0x840000FF
  end

  _charge_time_text = string.format("%d", _charge_object.max_charge - _charge_object.charge_time)
  _overcharge_time_text = string.format("[%d]", _charge_object.overcharge)
  _last_overcharge_time_text = string.format("[%d]", _charge_object.last_overcharge)
  _reset_time_text = string.format("%d", _charge_object.reset_time)


  gui.text(_x + 1, _y, _charge_object.name, text_default_color, text_default_border_color)
  gui.box(_reset_gauge_left + 1, _y + 11, _charge_gauge_left, _y + 11, 0x00000000, 0xFFFFFF77)
  gui.box(_reset_gauge_left, _y + 10, _reset_gauge_left, _y + 12, 0x00000000, 0xFFFFFF77)
  gui.box(_charge_gauge_right, _y + 11, _reset_gauge_right - 1, _y + 11, 0x00000000, 0xFFFFFF77)
  gui.box(_reset_gauge_right, _y + 10, _reset_gauge_right, _y + 12, 0x00000000, 0xFFFFFF77)
  draw_gauge(_charge_gauge_left, _y + 8, _charge_gauge_width, _gauge_height + 1, _charge_object.charge_time / _charge_object.max_charge, _gauge_valid_fill_color, _gauge_background_color, nil, true)
  draw_gauge(_reset_gauge_left, _y + 8 + _gauge_height + 2, _reset_gauge_width, _gauge_height, _charge_object.reset_time / _charge_object.max_reset, _gauge_cooldown_fill_color, _gauge_background_color, nil, true)
  if training_settings.special_training_charge_overcharge_on and _charge_object.overcharge ~=0 and _charge_object.overcharge < 42 then
    draw_gauge(_charge_gauge_left, _y + 8, _charge_gauge_width, _gauge_height + 1, _charge_object.overcharge / _charge_object.max_charge, 0x08FF0044, _gauge_background_color, nil, true)
    gui.text(_reset_gauge_right + 16, _y + 7, _overcharge_time_text, _success_color, text_default_border_color)
  end
  if training_settings.special_training_charge_overcharge_on and _charge_object.overcharge == 0 and _charge_object.last_overcharge > 0 and _charge_object.last_overcharge < 42 then
    gui.text(_reset_gauge_right + 16, _y + 7, _last_overcharge_time_text, _success_color, text_default_border_color)
  end


  gui.text(_reset_gauge_right + 4, _y + 7, _charge_time_text, _charge_text_color, text_default_border_color)
  gui.text(_reset_gauge_right + 4, _y + 13, _reset_time_text, text_default_color, text_default_border_color)

  return 8 + 5 + (_gauge_height * 2)
end

function special_training_charge_draw()
  -- Charge Meter Drawing
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Charge" then

    local _player = P1
    local _x = 276 --96
    local _y = 40
    local _flip_gauge = false
    local _gauge_x_scale = 1

    if training_settings.special_training_follow_character then
      local _px = _player.pos_x - screen_x + emu.screenwidth()/2
      local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
      local _half_width = 23 * _gauge_x_scale * 0.5
      _x = _px - _half_width
      _x = math.max(_x, 4)
      _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
      _y = _py - 100
    end

    local _y_offset = 0
    local _x_offset = 0
    local _group_y_margin = 6
    local _group_x_margin = 12

    local _charge_array = {
      {
        object = _player.charge_1,
        enabled = _player.charge_1.enabled
      },
      {
        object = _player.charge_2,
        enabled = _player.charge_2.enabled
      },
      {
        object = _player.charge_3,
        enabled = _player.charge_3.enabled
      }
    }

    for _i, _charge in ipairs(_charge_array) do
      if _charge.enabled then
        _y_offset = _y_offset + _group_y_margin + draw_charge_gauge_group(_x, _y + _y_offset, _charge.object)
      end
    end
  end
end
