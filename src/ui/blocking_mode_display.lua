-- src/ui/blocking_mode_display.lua

function blocking_mode_display()
  if not is_in_match or training_settings.recording_mission_mode or training_settings.blocking_style ~= 2 then return end
  local _blocking_mode = training_settings.blocking_mode
  -- Frame Trap's per-gap gauge hidden for now (2026-10-11 Peter: visual still isn't
  -- right despite the underlying data checking out correct in testing) -- the tracking
  -- in blocking.lua (frame_trap_gap_frozen/frame_trap_last_hit_frame) is untouched and
  -- still runs, only this display is parked pending a redesign. Revert to
  -- `if _blocking_mode ~= 2 and _blocking_mode ~= 4 then return end` once reworked.
  if _blocking_mode ~= 2 then return end

  local _y = 82
  local _seg_w = 20
  local _seg_h = 4

  if _blocking_mode == 2 then
    -- Combo Only: single "Fresh" gauge -- counts down until the dummy is idle long
    -- enough to treat the next hit as a fresh engagement (first-hit pass-through)
    local _x = screen_width - 138 - get_text_width("Juggle: ") + 100
    local _remaining = math.max(20 - (dummy.idle_time or 0), 0)

    gui.text(_x + 1, _y, "Fresh", text_default_color, text_default_border_color)
    gui.box(_x, _y + 10, _x + _seg_w, _y + 10 + _seg_h, 0x00000000, 0x000000FF)
    if _remaining > 0 then
      gui.box(_x, _y + 10, _x + _remaining, _y + 10 + _seg_h, 0xFF7939FF, 0x000000FF)
    end
    gui.text(_x + _seg_w + 4, _y + 10, string.format("%d", _remaining), text_default_color, text_default_border_color)
    return
  end

  -- Frame Trap: one segment per gap between consecutive force-passed hits (N hits ->
  -- N-1 gaps). Each segment freezes, the instant the next hit connects, at whatever the
  -- 20f arming countdown still read -- green if time was left (tight gap, a real
  -- opponent likely couldn't have punished it either), red if it hit 0 (the gap was wide
  -- enough that Frame Trap's force-pass is the only reason it wasn't blocked normally).
  -- (2026-10-11 Peter: wants per-gap feedback instead of one combined "Reset" timer)
  local _n = training_settings.frame_trap_hit_count or 1
  local _gap_count = math.max(_n - 1, 0)
  if _gap_count == 0 then return end -- N=1 has no gaps between hits to show

  local _through = dummy.blocking.frame_trap_hits_blocked_through or 0
  local _frozen = dummy.blocking.frame_trap_gap_frozen or {}
  -- same frame-delta measurement as the freeze in blocking.lua, not idle_time (see the
  -- comment there for why idle_time doesn't reliably track the gap between two hits)
  local _live_remaining = 0
  if _through > 0 and dummy.blocking.frame_trap_last_hit_frame then
    local _gap_frames = frame_number - dummy.blocking.frame_trap_last_hit_frame
    _live_remaining = math.max(20 - _gap_frames, 0)
  end

  -- one continuous bar with tick marks dividing it into _gap_count slices, same visual
  -- style as the Juggle air-timer gauge (src/ui/special_training/juggle_training.lua) --
  -- not separate boxed segments with gaps between them (2026-10-11 Peter)
  local _total_w = _gap_count * _seg_w
  local _right_edge = screen_width - 138 - get_text_width("Juggle: ") + 100 + _seg_w
  local _x = _right_edge - _total_w

  gui.text(_x + 1, _y, "Reset", text_default_color, text_default_border_color)
  gui.box(_x, _y + 10, _x + _total_w, _y + 10 + _seg_h, 0x00000000, 0x000000FF)

  for _i = 1, _gap_count do
    -- gap 1 (the first to count down) sits at the RIGHT end of the bar, later gaps sit
    -- further left -- the whole bar starts 100% full and empties right-to-left, gap by
    -- gap, instead of filling up left-to-right (2026-10-11 Peter)
    local _slot = _gap_count - _i -- 0 = rightmost slot
    local _sx = _x + _slot * _seg_w

    local _frozen_value = _frozen[_i]
    if _frozen_value ~= nil then
      -- resolved: green fill sized to the frozen remainder, or a full red slice if it hit 0.
      -- NOTE: gui.box color args are RRGGBBAA, but gui.text color args are AARRGGBB (this
      -- API uses two different byte orders) -- box_color/text_color must NOT be the same
      -- value, unlike every other color used elsewhere in this file by coincidence
      local _box_color = _frozen_value > 0 and 0x44FF44FF or 0xFF4444FF
      local _text_color = _frozen_value > 0 and 0xFF44FF44 or 0xFFFF4444
      local _fill_w = _frozen_value > 0 and _frozen_value or _seg_w
      gui.box(_sx, _y + 10, _sx + _fill_w, _y + 10 + _seg_h, _box_color, 0x00000000)
      gui.text(_sx + 1, _y + 10 + _seg_h + 2, string.format("%d", _frozen_value), _text_color, text_default_border_color)
    elseif _i == _through then
      -- active: still counting down toward the next hit
      if _live_remaining > 0 then
        gui.box(_sx, _y + 10, _sx + _live_remaining, _y + 10 + _seg_h, 0xFF7939FF, 0x00000000)
      end
      gui.text(_sx + 1, _y + 10 + _seg_h + 2, string.format("%d", _live_remaining), text_default_color, text_default_border_color)
    else
      -- not reached yet: starts out fully filled, same as a countdown that hasn't
      -- started ticking down yet -- not empty
      gui.box(_sx, _y + 10, _sx + _seg_w, _y + 10 + _seg_h, 0xFF7939FF, 0x00000000)
    end
  end

  -- divider tick between each slice (not drawn at the very start or very end)
  for _i = 1, _gap_count - 1 do
    local _tx = _x + _i * _seg_w
    gui.line(_tx, _y + 10, _tx, _y + 10 + _seg_h, 0x000000FF)
  end
end
