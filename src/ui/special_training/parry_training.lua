-- src/ui/special_training/parry_training.lua

function special_training_parry_draw()
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Parry" then

    local _player = P1
    local _x = 235 --96
    local _y = 40
    local _flip_gauge = false
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

    local _y_offset = 0
    local _group_y_margin = 6

    local _parry_array = {
      {
        object = _player.parry_forward,
        enabled = training_settings.special_training_parry_forward_on
      },
      {
        object = _player.parry_down,
        enabled = training_settings.special_training_parry_down_on
      },
      {
        object = _player.parry_air,
        enabled = training_settings.special_training_parry_air_on
      },
      {
        object = _player.parry_antiair,
        enabled = training_settings.special_training_parry_antiair_on
      }
    }

    for _i, _parry in ipairs(_parry_array) do

      if _parry.enabled then
        _y_offset = _y_offset + _group_y_margin + draw_parry_gauge_group(_x, _y + _y_offset, _parry.object, _gauge_x_scale)
      end
    end
  end
end
