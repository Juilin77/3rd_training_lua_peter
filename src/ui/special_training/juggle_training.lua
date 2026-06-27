-- src/ui/special_training/juggle_training.lua

function special_training_juggle_draw()
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Juggle" then
    local _target = dummy
    local _airborne = (_target.pos_y ~= 0)

    if _airborne and not juggle_disp.was_airborne then
      juggle_disp.jc = 0
      juggle_disp.air_time = 0
      juggle_disp.expired = false
    end

    if _airborne then
      local _jt = _target.juggle_time
      juggle_disp.jc = _target.juggle_count
      juggle_disp.expired = (_jt == 0xFF)
      juggle_disp.air_time = juggle_disp.expired and 0 or math.floor((_jt + 1) / 2)
    end

    juggle_disp.was_airborne = _airborne

    local _x = screen_width - 138 - get_text_width("Juggle: ")
    local _y = 82
    local _gauge_w = 121
    local _gauge_h = 4

    gui.text(_x + 1, _y, "Juggle", text_default_color, text_default_border_color)
    gui.text(_x + _gauge_w - 6, _y, "121", text_disabled_color, text_default_border_color)
    gui.box(_x, _y + 10, _x + _gauge_w, _y + 10 + _gauge_h, 0x00000000, 0x000000FF)
    if not juggle_disp.expired and juggle_disp.air_time > 0 then
      local _fill = math.min(juggle_disp.air_time, _gauge_w)
      gui.box(_x, _y + 10, _x + _fill, _y + 10 + _gauge_h, 0x00C080FF, 0x000000FF)
    end
    gui.text(_x + _gauge_w + 4, _y + 10, string.format("%dF", juggle_disp.air_time), text_default_color, text_default_border_color)
    for _, _tx in ipairs({1, 2, 5, 11, 21, 41, 61, 81, 101}) do
      gui.line(_x + _tx, _y + 10, _x + _tx, _y + 10 + _gauge_h, 0x000000FF)
    end
    for _, _tx in ipairs({21, 41, 61, 81, 101}) do
      gui.text(_x + _tx - 4, _y + 10 + _gauge_h + 2, tostring(_tx), text_disabled_color, text_default_border_color)
    end

  end
end
