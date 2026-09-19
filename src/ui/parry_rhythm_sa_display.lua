-- src/ui/parry_rhythm_sa_display.lua
-- Pure input-timing rhythm trainer: tracks P1's raw forward taps directly
-- from input_history (no parry-gauge / game-judgment involvement at all, no
-- opponent action required), and shows a live, real-time counter of frames
-- elapsed since the last tap so the player can practice hitting a steady
-- interval by feel alone, plus a short history of past tap-to-tap gaps.
--
-- Named "- SA" because the +17F rhythm target is derived from the Super
-- Art's own freeze math (16F freeze + 1F resolution, from the SA's +0
-- additional-freeze bonus) -- a future light/medium/heavy variant would need
-- a different target gap (+4/+3/+2 additional freeze -> 20/19/18), hence the
-- explicit "SA" qualifier now rather than a generic name.

-- Keep the last 10 tap-to-tap gaps, which takes 11 recorded taps (each gap
-- needs the tap before it).
local PARRY_RHYTHM_SA_GAP_LIST_MAX = 10
local PARRY_RHYTHM_SA_HISTORY_MAX = PARRY_RHYTHM_SA_GAP_LIST_MAX + 1

-- Same orange as the cooldown bar of the Forward Parry Helper gauge
-- (_gauge_cooldown_fill_color, local to draw_parry_gauge_group in src/draw.lua)
local PARRY_RHYTHM_SA_BAR_COLOR = 0xFF7939FF

parry_rhythm_sa_history = { events = {}, last_recorded_frame = nil }

function update_parry_rhythm_sa_capture()
  if not training_settings.display_parry_rhythm_sa then return end
  if training_settings.special_training_current_mode ~= 2 then return end
  if not is_in_match then return end

  local _history = input_history[1]
  if not _history or #_history == 0 then return end

  -- input_history only appends a new entry on an actual state change, so the
  -- last entry being a pure forward direction (6=right, 4=left -- no
  -- diagonals, per Peter's requirement) and not yet recorded (by frame) means
  -- a fresh forward tap just happened
  local _last_entry = _history[#_history]
  if (_last_entry.direction == 6 or _last_entry.direction == 4)
      and parry_rhythm_sa_history.last_recorded_frame ~= _last_entry.frame then
    table.insert(parry_rhythm_sa_history.events, { frame = _last_entry.frame })
    while #parry_rhythm_sa_history.events > PARRY_RHYTHM_SA_HISTORY_MAX do
      table.remove(parry_rhythm_sa_history.events, 1)
    end
    parry_rhythm_sa_history.last_recorded_frame = _last_entry.frame
  end
end

local function parry_rhythm_sa_draw_bar(_x, _y)
  local _events = parry_rhythm_sa_history.events
  local _scale = 4 -- px per frame
  local _bar_w = FRAME_TABLE_SA_PARRY_TARGET_GAP * _scale -- exactly 17f wide, matching the SA freeze length -- the right edge IS the target

  -- always draw the label + empty bar frame as soon as this is on, even with
  -- zero taps yet, so turning the setting on gives immediate visual feedback
  gui.text(_x, _y - 10, "Parry Rhythm - SA", text_default_color, text_default_border_color)
  gui.box(_x, _y, _x + _bar_w, _y + 8, 0x00000000, 0xFFFFFF77)

  if #_events == 0 then return end

  -- live fill: grows every frame since the last recorded tap, resetting the
  -- instant a new tap is captured -- this is the part that "runs" in real
  -- time as the player waits to tap again, not just a static post-hoc mark.
  -- Once idle for too long past the visible range, go back to the same
  -- static/empty look as before any tap at all, instead of sitting there
  -- permanently maxed out and red -- but the history line below still shows
  -- regardless, since that's a settled record, not a live countdown.
  local _last_tap_frame = _events[#_events].frame
  local _elapsed = frame_number - _last_tap_frame
  if _elapsed <= _bar_w / _scale then
    local _fill_w = math.min(_elapsed * _scale, _bar_w)
    gui.box(_x, _y, _x + _fill_w, _y + 8, PARRY_RHYTHM_SA_BAR_COLOR, 0x000000FF)
    gui.text(_x, _y + 12, string.format("%df", _elapsed), text_default_color, text_default_border_color)
  end

  -- history list, same layout as input_history_draw(): newest gap on the top
  -- row, older gaps stacked below it in 10px steps (diff from the 17F target)
  local _step_y = 10
  local _list_y = _y + 24
  local _j = 0
  for i = #_events, 2, -1 do
    local _hist_diff = (_events[i].frame - _events[i - 1].frame) - FRAME_TABLE_SA_PARRY_TARGET_GAP
    local _hist_text = string.format("%+d", _hist_diff)
    local _hist_color = 0xd6e3efff
    if _hist_diff == 0 then
      _hist_text = "0"
      _hist_color = 0x10FB00FF -- same green as the "0" in the menu.lua legend
    end
    gui.text(_x, _list_y + _j * _step_y, _hist_text, _hist_color, 0x101000ff)
    _j = _j + 1
  end
end

-- default (non-follow) position for this bar, or above P1's head when Follow
-- Character is on -- same formula as the "Parry" Special Training gauge in
-- src/ui/special_training/parry_training.lua
local function parry_rhythm_sa_bar_position(_player, _default_x, _default_y)
  if not training_settings.special_training_follow_character then
    return _default_x, _default_y
  end
  local _px = _player.pos_x - screen_x + emu.screenwidth() / 2
  local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
  local _half_width = 23 * 4 * 0.5
  local _x = _px - _half_width
  _x = math.max(_x, 4)
  _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
  local _y = _py - 100
  return _x, _y
end

function parry_rhythm_sa_display()
  if not training_settings.display_parry_rhythm_sa then return end
  if training_settings.special_training_current_mode ~= 2 then return end
  if not is_in_match then return end

  local _x, _y = parry_rhythm_sa_bar_position(player_objects[1], 100, 60)
  parry_rhythm_sa_draw_bar(_x, _y)
end
