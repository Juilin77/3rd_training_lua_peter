-- src/ui/blocking_mode_display.lua

function blocking_mode_display()
  if is_in_match and not training_settings.recording_mission_mode and training_settings.blocking_style == 2 and training_settings.blocking_mode == 3 then
    local _x = screen_width - 138 - get_text_width("Juggle: ") + 100
    local _y = 82
    local _gauge_w = 20
    local _gauge_h = 4
    local _remaining = math.max(20 - (dummy.idle_time or 0), 0)

    gui.text(_x + 1, _y, "Meaty", text_default_color, text_default_border_color)
    gui.box(_x, _y + 10, _x + _gauge_w, _y + 10 + _gauge_h, 0x00000000, 0x000000FF)
    if _remaining > 0 then
      gui.box(_x, _y + 10, _x + _remaining, _y + 10 + _gauge_h, 0xFF7939FF, 0x000000FF)
    end
    gui.text(_x + _gauge_w + 4, _y + 10, string.format("%d", _remaining), text_default_color, text_default_border_color)
  end
end
