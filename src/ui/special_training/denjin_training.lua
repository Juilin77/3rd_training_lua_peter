-- src/ui/special_training/denjin_training.lua
-- Ryu SA3 Denjin Hadoken charge display: two stacked gauges.
-- Level/timer mapping ported from effie3rd src/ui/hud.lua (denjin_display):
-- denjin_level jumps 3 -> 9 -> 14 -> 19 (I/II/III/IV), each with its own countdown
-- window (denjin_time counts down to 0 within the level); reaching 0 at level 19
-- (IV) means max charge (V).
-- Top gauge = cumulative charge since the start of the whole charge (I -> V),
-- never resets per level, read from denjin_level/denjin_time RAM. Freezes at
-- its last value after release (denjin_disp.charge_frozen_ratio/_text) instead
-- of vanishing, and clears back to 0 the instant the NEXT SA3 activation's
-- superfreeze flash starts (superfreeze_decount rising edge) -- earlier than
-- the charging animation itself, which only begins once the flash ends. This
-- matters because denjin_level/denjin_time can still hold the PREVIOUS
-- charge's stale values during the flash and for one more frame after
-- charging starts (before the game updates them), so resetting any later
-- would let the old frozen reading bleed into/through the flash.
-- Bottom gauge = a plain frame-counter stopwatch (denjin_disp.elapsed_frames)
-- measuring pure charge duration, start to release -- same width/scale as the
-- top gauge for a direct visual comparison, but its own ratio denominator
-- (denjin_timer_max_frames) since Peter measured this in-game at ~162 frames,
-- slightly above the RAM-derived 160 total used by the top gauge.
local denjin_level_data = {
  [3]  = { level_number = 1, max_timer = 8,  cumulative_start = 0 },
  [9]  = { level_number = 2, max_timer = 24, cumulative_start = 8 },
  [14] = { level_number = 3, max_timer = 48, cumulative_start = 32 },
  [19] = { level_number = 4, max_timer = 80, cumulative_start = 80 },
}
local denjin_total_frames = 160 -- full charge I -> V (8 + 24 + 48 + 80), RAM-derived
local denjin_timer_max_frames = 162 -- pure charge duration, measured in-game by Peter
local denjin_gauge_scale = 0.5 -- px per frame, keeps the bar in line with other HUD gauge widths

-- same check frame_table.lua's has_active_projectile() uses (that one is
-- local to frame_table.lua, so it isn't reachable from here) -- needed
-- because animation stays 774c/90b4 for a bit after release too, through the
-- fireball's own travel time, which must not count as charging either
local function denjin_has_active_projectile(_player_obj)
  for _, _proj in pairs(projectiles) do
    if _proj.emitter_id == _player_obj.id and _proj.has_activated then
      return true
    end
  end
  return false
end

-- savestate load can jump RAM frame_number backwards or land mid-charge
-- without a fresh superfreeze rising edge, so without this reset:
-- `released` could stay latched from a charge that already finished before
-- the save, blocking the bottom timer forever, and `prev_is_charging` could
-- stay true, skipping the charge_start_frame reset and reading negative
-- elapsed frames (win-codex re-review, 2026-11-06)
function denjin_disp_reset()
  denjin_disp = { prev_is_charging = false, prev_superfreeze_decount = 0, charge_start_frame = 0, elapsed_frames = 0, level_label = "-", charge_frozen_ratio = 0, charge_frozen_text = "", released = false }
end

function draw_denjin_gauge_group(_x, _y, _player)
  local _gauge_width = denjin_total_frames * denjin_gauge_scale
  local _gauge_height = 3
  local _gauge_background_color = 0xD6E7EF77
  local _charge_fill_color = 0xFFAA00FF
  local _timer_fill_color = 0x66CCFFFF
  local _tick_color = 0xFF0000FF

  -- Top bar's RAM-valid window: matches effie3rd's own gating (animation +
  -- superfreeze_decount == 0). Do not add the projectile check here -- it
  -- cut this window one frame short at full charge (showed 159 instead of
  -- 160), because has_activated can already be true for a frame before the
  -- fireball is actually considered "released" by the rest of the game.
  local _is_charging = (_player.animation == "774c" or _player.animation == "90b4")
    and _player.superfreeze_decount == 0

  -- Bottom bar's stricter "pure charge time" window: same as above, but also
  -- excludes the fireball's own flight time after release (animation doesn't
  -- change immediately on release), matching how Frame Table's own
  -- classification treats "projectile" as separate from "startup" (green).
  -- "released" latches true the instant a projectile ever appears and stays
  -- true until the next superfreeze -- without it, once the projectile
  -- expires (removed from the projectiles table) while animation still
  -- hasn't left 774c/90b4 yet, _is_pure_charging would flip true again and
  -- get misread as a brand new charge starting, popping up a bogus small
  -- number (e.g. "15") right after the whole move has already finished.
  local _projectile_active = denjin_has_active_projectile(_player)
  if _projectile_active then
    denjin_disp.released = true
  end
  local _is_pure_charging = _is_charging and not _projectile_active and not denjin_disp.released
  local _just_started = _is_pure_charging and not denjin_disp.prev_is_charging
  denjin_disp.prev_is_charging = _is_pure_charging
  if _just_started then
    denjin_disp.charge_start_frame = frame_number
  end

  local _superfreeze_now = _player.superfreeze_decount
  local _superfreeze_rising = _superfreeze_now > 0 and (denjin_disp.prev_superfreeze_decount or 0) == 0
  denjin_disp.prev_superfreeze_decount = _superfreeze_now
  if _superfreeze_rising then
    -- SA3 activation flash just started: clear BOTH bars' frozen readings
    -- right away, instead of waiting for the charging animation to begin
    -- once the flash ends -- otherwise the new charge's bars would keep
    -- showing the previous charge's final numbers until charging resumes
    denjin_disp.level_label = "-"
    denjin_disp.charge_frozen_ratio = 0
    denjin_disp.charge_frozen_text = ""
    denjin_disp.elapsed_frames = 0
    denjin_disp.released = false
  end

  gui.text(_x, _y, "Denjin", text_default_color, text_default_border_color)

  if _is_charging and not _just_started then
    -- skip RAM read on the very first charging frame: denjin_level/denjin_time
    -- can still hold the previous charge's stale values for one frame
    local _level_data = denjin_level_data[_player.denjin_level]
    if _level_data then
      local _level_number = _level_data.level_number
      local _elapsed_in_level = _level_data.max_timer - _player.denjin_time
      if _level_number == 4 and _player.denjin_time == 0 then
        _level_number = 5 -- max charge
      end
      denjin_disp.level_label = tostring(_level_number)

      local _cumulative_elapsed = _level_data.cumulative_start + _elapsed_in_level
      denjin_disp.charge_frozen_ratio = _cumulative_elapsed / denjin_total_frames
      denjin_disp.charge_frozen_text = string.format("%d", _cumulative_elapsed)
    end
  end

  if _is_pure_charging then
    -- plain frame-counter stopwatch, independent of the RAM values above;
    -- holds its last value (frozen) once charging stops, until the next
    -- charge. +1 so the very first charging frame reads "1", matching Frame
    -- Table's own 1-indexed count of green (startup) frames -- a 0-indexed
    -- count here was reading one frame behind it.
    denjin_disp.elapsed_frames = frame_number - denjin_disp.charge_start_frame + 1
  end
  local _timer_ratio = denjin_disp.elapsed_frames / denjin_timer_max_frames
  local _timer_text = string.format("%d", denjin_disp.elapsed_frames)

  gui.text(_x - get_text_width(denjin_disp.level_label) - 4, _y + 7, denjin_disp.level_label, text_default_color, text_default_border_color)
  draw_gauge(_x, _y + 8, _gauge_width, _gauge_height + 1, denjin_disp.charge_frozen_ratio, _charge_fill_color, _gauge_background_color, nil, false)
  for _level_byte, _level_data in pairs(denjin_level_data) do
    if _level_data.cumulative_start > 0 then
      local _tick_x = _x + _level_data.cumulative_start * denjin_gauge_scale
      gui.box(_tick_x, _y + 8, _tick_x, _y + 8 + _gauge_height + 2, 0x00000000, _tick_color)
    end
  end
  gui.text(_x + _gauge_width + 4, _y + 7, denjin_disp.charge_frozen_text, text_default_color, text_default_border_color)

  draw_gauge(_x, _y + 16, _gauge_width, _gauge_height + 1, _timer_ratio, _timer_fill_color, _gauge_background_color, nil, false)
  gui.text(_x + _gauge_width + 4, _y + 15, _timer_text, text_default_color, text_default_border_color)

  return 16 + _gauge_height + 4
end

function special_training_denjin_draw()
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Denjin Hadoken (Ryu)" then

    local _player = P1
    local _x = 230
    local _y = 49

    if training_settings.special_training_follow_character then
      local _px = _player.pos_x - screen_x + emu.screenwidth()/2
      local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
      local _half_width = 40
      _x = math.max(_px - _half_width, 4)
      _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
      _y = _py - 100
    end

    if _player.char_str == "ryu" and _player.selected_sa == 3 then
      draw_denjin_gauge_group(_x, _y, _player)
    else
      gui.text(_x - 8, _y, "Denjin Hadoken not enabled \nfor this character")
    end
  end
end
