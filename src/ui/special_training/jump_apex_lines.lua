-- src/ui/special_training/jump_apex_lines.lua
-- Gouki's air down+MK ("Air Down K" in the UI; animation id 2aa0, framedata name "Air Down MK")
-- needs height (pos_y) >= 74 to come out; a normal (forward) jump peaks at 83. 74/83 measured by
-- Peter in-game (2026-11-12). The move has no input buffer/leniency: pressed before height 74, it
-- fails outright and the jump's special-move attempt is burned for the rest of that jump even if
-- a later, correctly-timed press follows (confirmed by Peter in-game, 2026-11-13) -- early miss
-- and success are mutually exclusive within one jump, never both. Input order: down must be held
-- before (or simultaneously with) MK -- pressing MK before down is not a valid input for this
-- move at all (confirmed by Peter, 2026-11-13).
--
-- Two independent pieces:
--
-- 1. Display tab toggle (`display_jump_apex_lines`): draws just the single 74 usable-threshold
--    reference line (Peter, 2026-11-13: dropped the normal/big apex lines, only wants this one)
--    -- plus a live position cross (origin point, i.e. the feet, not the head), using the same
--    draw_point() cross Display Distances already uses (src/display.lua). Works for any
--    character -- this is just a position reference, no Gouki-specific data needed to show it.
--
-- 2. Special Training mode ("Air Down K"): each jump's whole timeline bar is pre-drawn full
--    width the instant takeoff is detected (action/animation at takeoff tells normal vs big jump
--    apart -- see jump_apex_data below -- so total_frames/window_open_t/window_close_t are all
--    known up front; no live-growing-bar style left in this file at all, Peter explicitly doesn't
--    want that). A traveling pointer sweeps across it in real time, red outside the window / green
--    inside it. A green marker shows a down+MK press any time after first crossing 74 and still at
--    or above late_usable_floor -- that's then confirmed by the move's own animation (2aa0)
--    actually appearing -- ground truth, so it also catches input the game rejects for a reason
--    other than height (e.g. a diagonal down instead of pure down, found 2026-11-13) without
--    needing each such rule modeled separately. A red marker shows either a too-early attempt
--    (down+MK pressed before crossing 74, which always fails outright in-game, no animation check
--    needed, confirmed by Peter) or a too-late attempt (down+MK pressed after crossing 74 but
--    already below late_usable_floor -- 72 for normal jump, 77 for big jump, both the lowest
--    height Peter's confirmed the move still comes out at -- also always fails outright, same
--    certainty, confirmed by Peter 2026-11-14) -- never more than one outcome in the same jump; an
--    attempt between those two heights that never gets animation-confirmed just shows no new
--    outcome at all (no marker for it, since there's no confirmed cutoff to show one for in that
--    range). Both markers are POSITIONED at the INPUT frame, not whatever later frame confirms
--    success -- the animation visibly changing lags the true input frame by the game's own
--    internal processing (confirmed 2026-11-13). Beside the bar, a frozen +N/-N frame-count
--    readout, Parry's own sign convention (src/draw.lua:323-337): displayed value is -delta -- 0
--    is best, a late-but-successful press shows as a negative number with no prefix (no "+"), a
--    too-early miss shows as a positive number prefixed "Too Early", a too-late miss shows as a
--    negative number prefixed "Too Late". The whole result (bar + marker +
--    number) is cleared at the NEXT TAKEOFF, not at landing -- so it's still visible while
--    standing on the ground after a jump, but a fresh jump with no attempt at all shows a blank
--    gauge rather than an old, possibly mismatched result (Peter, 2026-11-13: reversed from an
--    earlier "persist until the next real attempt" design after finding a stale record from a
--    different jump_type could show mismatched tick positions next to the live timeline). Gouki-
--    only: the move animation and height constant are specific to this character.

jump_apex_lines_character_names = { "Gouki" }

-- jump_types keyed by the action id read at TAKEOFF only (that's the one
-- frame we've traced and confirmed distinguishes NORMAL vs BIG -- not
-- verified to hold for the rest of the jump, so nothing after takeoff reads
-- action again). Both measured by Peter in-game via a full per-frame height
-- trace, 2026-11-13: action 12/animation 8db0 is a normal jump (apex 83, 39
-- total frames); action 13/animation 8df0 is a big jump (apex 103, 44 total
-- frames). Action/animation do NOT distinguish DIRECTION, though -- Peter
-- confirmed via console trace, 2026-11-13, that neutral jump reads the
-- exact same action/animation as forward jump for both types -- so
-- jump_apex_gauge_update also gates on the held direction at takeoff to
-- stay forward-jump-only (大前跳/普通前跳). Lets the Special Training gauge
-- draw its whole timeline up front instead of growing live. Anything else
-- at takeoff -- an unrecognized action (any other jump not yet measured),
-- a non-forward-held jump (neutral/backward -- same action/animation as
-- forward, just no forward input), or a special move that leaves the
-- ground (e.g. a qcb+K command move) -- is NOT tracked at all
-- (jump_apex_gauge_update skips it entirely): this whole tool is Air Down
-- K-only, not a general jump/airborne detector (Peter, 2026-11-13).
local jump_apex_data = {
  gouki = {
    usable_from = 74,
    move_animation = "2aa0",
    -- window_open_t/window_close_t are also from that same trace (first
    -- frame pos_y>=74, first frame pos_y<74 after that) -- let the "[ ]"
    -- ticks show immediately alongside the pre-drawn track too (Peter,
    -- 2026-11-13), instead of waiting for live crossing detection. These
    -- are only ever used for the tick POSITIONS; the +/-N readout still
    -- comes from this specific jump's own real recorded crossed_frame,
    -- never from these generic per-type numbers.
    --
    -- Big jump's window_close_t corrected 2026-11-13 (35 -> 34): Peter's
    -- own retest found the big jump's real late boundary at "-20 y=77" (20
    -- frames after crossing 74, still above 74 at that point -- unlike the
    -- normal jump's late boundary, which is past its apex and already back
    -- below 74), 1 frame earlier than the originally-coded 35. Its own
    -- early boundary retested unchanged, "0 y=74".
    --
    -- late_usable_floor (added 2026-11-14): the lowest height Peter's
    -- confirmed the move still comes out at on the descent -- normal
    -- jump's retest found "-12 y=72" (the last successful frame before
    -- window-close); big jump's found "-20 y=77" (same). Peter: anything
    -- lower than this floor always fails outright, no animation check
    -- needed -- symmetric to the early side's usable_from cutoff, just
    -- measured from the single known-good floor rather than independently
    -- confirmed to fail below it (ship-and-observe, same as other unproven
    -- edges in this file).
    jump_types = {
      [12] = { apex = 83, apex_label = "Normal Jump Apex", total_frames = 39, window_open_t = 15, window_close_t = 27, late_usable_floor = 72 },
      [13] = { apex = 103, apex_label = "Big Jump Apex", total_frames = 44, window_open_t = 14, window_close_t = 34, late_usable_floor = 77 },
    },
  },
}

-- ---------------------------------------------------------------------------
-- Thing 1: Display tab -- 74 reference line + live position cross,
-- any character
-- ---------------------------------------------------------------------------

-- Just the usable_from (74) line -- Peter, 2026-11-13: dropped the normal/
-- big apex lines, only wants this one.
local function jump_apex_draw_band(_player)
  local _usable_from = jump_apex_data.gouki.usable_from

  local _y_from = game_to_screen_space_y(_usable_from)

  draw_horizontal_line(4, screen_width - 4, _y_from, 0x00AAFFFF, 1)
  gui.text(4, _y_from - 9, string.format("Usable From (%d)", _usable_from), 0x00AAFFFF, text_default_border_color)

  local _cross_x, _cross_y = game_to_screen_space(_player.pos_x, _player.pos_y)
  draw_point(_cross_x, _cross_y, 0xFFFF00FF)
end

-- ---------------------------------------------------------------------------
-- Thing 2: Special Training mode "Air Down K" -- live event-driven timeline
-- ---------------------------------------------------------------------------

-- tracker for the most recent jump -- reset every takeoff (and on
-- jump_apex_reset_current_jump(), called from on_load_state in
-- sf33rd_training.lua), but NOT at landing, so it's also what the gauge
-- draws from once grounded: whatever this jump's own result was (outcome
-- or none) stays on screen until the NEXT takeoff clears it -- same
-- lifecycle as jump_apex_input_warning below, not "persist until the next
-- real attempt" (Peter, 2026-11-13, reversing the earlier persist-forever
-- design after finding it could show a stale result from several jumps
-- back, possibly even a different jump_type, with mismatched ticks -- a
-- plain jump with no attempt should show no marker/number at all, not an
-- old one).
local _current_jump = {
  active = false,
  jump_type = nil, -- nil | jump_apex_data.gouki.jump_types[action] entry
  is_in_window = false,
  has_started_descending = false,
  takeoff_frame = nil,
  crossed_frame = nil,
  early_candidate_frame = nil,
  early_candidate_pos_y = nil,
  pending_attempt_frame = nil,
  pending_attempt_pos_y = nil,
  outcome = nil, -- nil | "success" | "early_miss" | "too_late_miss"
  outcome_frame = nil,
  outcome_pos_y = nil,
  previous_pos_y = nil,
}

-- separate from the above -- a dedicated wrong-input warning (e.g. "3MK",
-- "1MK", "no2MK"), shown instead of the gauge while active (Peter: don't
-- keep showing the previous result underneath it). Same clear-at-next-
-- takeoff lifecycle as _current_jump's own result above.
jump_apex_input_warning = { active = false, text = nil }

-- which P1/P2 object _current_jump is currently tracking, if any -- lets
-- special_training_jump_apex_draw notice when that identity changes (mode
-- switched away and back, character/slot swap) and clear the tracker
-- instead of risking it splicing a stale jump from the previously-observed
-- player into a new one's events (win-codex POST review, 2026-11-13).
local _jump_apex_observed_player = nil

-- any of the 6 attack buttons having a pressed edge this frame is a
-- candidate wrong-input check -- not just MK (Peter, 2026-11-13: LP/MP/HP/
-- LK/HK with any direction, or MK with any direction other than 1/2/3,
-- should all show the warning, only pure down (2) + MK is valid).
local function jump_apex_any_attack_pressed(_player)
  return _player.input.pressed.LP or _player.input.pressed.MP or _player.input.pressed.HP
    or _player.input.pressed.LK or _player.input.pressed.MK or _player.input.pressed.HK
end

-- numpad notation is relative to facing: flip_x == 0 faces left (forward =
-- left), non-zero faces right (forward = right) -- documented convention,
-- CLAUDE.md / gamestate.lua. Returns the wrong-input label for any button
-- other than MK (regardless of direction), or for MK pressed with
-- anything other than pure down (2) held; nil only for pure down + MK,
-- where the normal candidate logic below should run instead.
local function jump_apex_wrong_input_label(_player)
  if not _player.input.pressed.MK then
    return "no2MK"
  end
  if not _player.input.down.down then
    return "no2MK"
  end
  local _facing_right = _player.flip_x ~= 0
  if _player.input.down.right then
    return _facing_right and "3MK" or "1MK"
  end
  if _player.input.down.left then
    return _facing_right and "1MK" or "3MK"
  end
  return nil
end

-- sets the warning and returns true if this press was a wrong-input case,
-- so callers can skip their own candidate-recording for the same press.
local function jump_apex_try_wrong_input_warning(_player)
  local _label = jump_apex_wrong_input_label(_player)
  if not _label then return false end
  jump_apex_input_warning.active = true
  jump_apex_input_warning.text = _label
  return true
end

-- full clear back to idle (NOT just "inactive") -- clears takeoff_frame
-- too, so jump_apex_draw_gauge falls through to the idle preview instead
-- of showing a frozen, possibly now-meaningless result. Used both for a
-- fresh takeoff (immediately followed by setting the new takeoff's own
-- fields right after calling this) and for the invalidation cases below,
-- where there's no new takeoff to follow up with -- savestate load
-- (on_load_state calling jump_apex_reset_current_jump), and mode/match/
-- player-identity changes (special_training_jump_apex_draw). Found
-- missing for both of those by win-codex's POST review, 2026-11-13: the
-- old reset only set active=false, leaving takeoff_frame/outcome/warning
-- all still pointing at the previous, now-unrelated jump, so a savestate
-- load to a different point in time (or switching this mode off mid-jump,
-- then back on after a different jump happened) could show a stale
-- marker/number/warning, or even worse, let a later animation confirmation
-- from a NEW jump get wrongly attributed to an OLD jump's still-pending
-- attempt.
local function jump_apex_clear_current_jump()
  _current_jump.active = false
  _current_jump.jump_type = nil
  _current_jump.is_in_window = false
  _current_jump.has_started_descending = false
  _current_jump.takeoff_frame = nil
  _current_jump.crossed_frame = nil
  _current_jump.early_candidate_frame = nil
  _current_jump.early_candidate_pos_y = nil
  _current_jump.pending_attempt_frame = nil
  _current_jump.pending_attempt_pos_y = nil
  _current_jump.outcome = nil
  _current_jump.outcome_frame = nil
  _current_jump.outcome_pos_y = nil
  _current_jump.previous_pos_y = nil
  jump_apex_input_warning.active = false
  jump_apex_input_warning.text = nil
end

-- called from on_load_state() -- a savestate load mid-jump would otherwise
-- leave stale frame numbers (and a stale displayed result) from before the
-- load. See jump_apex_clear_current_jump's comment above.
function jump_apex_reset_current_jump()
  jump_apex_clear_current_jump()
end

local function jump_apex_gauge_update(_player, _data)
  local _was_grounded = is_state_on_ground(_player.previous_standing_state, _player)
  local _is_grounded = is_state_on_ground(_player.standing_state, _player)

  if _was_grounded and not _is_grounded and _data.jump_types[_player.action] then
    -- action/animation alone do NOT distinguish jump direction -- confirmed
    -- 2026-11-13 by Peter via [JUMP_APEX_DBG] console trace: neutral jump
    -- reads the exact same action=12/animation=8db0 as forward jump, and
    -- neutral big jump the exact same action=13/animation=8df0 as forward
    -- big jump. So this tool, which is forward-jump-only (大前跳/普通前跳,
    -- Peter 2026-11-13), also gates on the held direction AT TAKEOFF,
    -- same facing-relative left/right check jump_apex_wrong_input_label
    -- below uses for 1MK/3MK.
    local _facing_right = _player.flip_x ~= 0
    local _is_forward_held = (_facing_right and _player.input.down.right) or (not _facing_right and _player.input.down.left)

    if _is_forward_held then
      -- fresh takeoff into a RECOGNIZED forward jump (action 12 or 13) only
      -- -- clear the tracker, then set this new jump's own starting fields,
      -- which is what clears the previous jump's result/warning off screen
      -- (see the _current_jump/jump_apex_input_warning comments above). Any
      -- other grounded->airborne transition -- neutral/backward jump (same
      -- action/animation, just no forward held), or a special move that
      -- leaves the ground entirely (e.g. a qcb+K command move) -- is
      -- ignored entirely here -- no clear, no new tracker -- so it doesn't
      -- touch whatever jump result was already on screen. Previously fell
      -- back to the normal-jump entry for any unrecognized action instead
      -- of skipping it, which is exactly what let a non-jump airborne move
      -- start the gauge running (found by Peter, 2026-11-13); the
      -- direction check above is what's needed on top of that to also
      -- exclude neutral/backward jump, which share the SAME action/
      -- animation as forward jump.
      jump_apex_clear_current_jump()
      _current_jump.active = true
      _current_jump.jump_type = _data.jump_types[_player.action]
      _current_jump.takeoff_frame = frame_number
    end
  end

  if not _current_jump.active then return end

  if not _is_grounded then
    -- descending-phase flag -- sticky once true. Needed because the SAME
    -- height can occur twice in one jump: once rising past usable_from/74
    -- (always a valid success zone) and once falling back through
    -- late_usable_floor's range on the way down (big jump's floor, 77, is
    -- actually ABOVE usable_from 74 -- so right after crossing 74 while
    -- still rising, pos_y sits between 74 and 77, which is < 77 but is NOT
    -- a too-late case at all; found 2026-11-14 as a real bug, "大跳 0 y=74
    -- 是紅字" -- a perfect-timing crossing-frame press was wrongly getting
    -- flagged too_late_miss because the too-late check only looked at
    -- height, not direction). previous_pos_y is guarded since it's nil on
    -- the very first airborne frame. Computed BEFORE is_in_window below so
    -- the pointer's own red/green uses the same up-to-date phase.
    if _current_jump.previous_pos_y and _player.pos_y < _current_jump.previous_pos_y then
      _current_jump.has_started_descending = true
    end

    -- live, real-time "am I in the window right now" flag -- drives the
    -- gauge's traveling pointer (red/green/red) independent of whether an
    -- attempt has happened yet. Uses usable_from while still rising, but
    -- switches to this jump_type's own late_usable_floor once descending --
    -- a single usable_from-only check disagreed with the actual outcome
    -- logic on both jump types (win-codex POST review, 2026-11-14): big
    -- jump's FALLING 74-77 band would wrongly show green even though a
    -- press there is already a too_late_miss; normal jump's falling 72-73
    -- band would wrongly show red even though a press there still
    -- succeeds.
    local _in_window_floor = _current_jump.has_started_descending and _current_jump.jump_type.late_usable_floor or _data.usable_from
    _current_jump.is_in_window = _player.pos_y >= _in_window_floor

    -- early candidate: pure down+MK edge while pos_y is still actually
    -- below usable_from THIS frame, no outcome locked in yet, and we
    -- haven't crossed 74 yet at all this jump (`not crossed_frame` --
    -- without this, a press during the DESCENT after the window has
    -- already closed, pos_y back below 74 again, would also match "pos_y
    -- < usable_from" and get wrongly recorded here as an "early" candidate
    -- even though it's actually late -- found 2026-11-13: this is why a
    -- genuinely late real press was producing no new outcome at all,
    -- leaving an old stale result on screen that looked unrelated to what
    -- Peter had just done. See the late-candidate check below instead).
    -- Overwritten on every eligible press, so the latest one before
    -- crossing is the one that counts (closest miss). A wrong-input press
    -- (diagonal, or MK with no down at all) short-circuits this via
    -- jump_apex_try_wrong_input_warning -- same height range, same
    -- priority, just a different outcome than a candidate attempt.
    if not _current_jump.crossed_frame and _player.pos_y < _data.usable_from and not _current_jump.outcome
      and jump_apex_any_attack_pressed(_player)
      and not jump_apex_try_wrong_input_warning(_player) then
      _current_jump.early_candidate_frame = frame_number
      _current_jump.early_candidate_pos_y = _player.pos_y
    end

    -- first upward crossing of usable_from (74)
    if not _current_jump.crossed_frame and _player.pos_y >= _data.usable_from then
      _current_jump.crossed_frame = frame_number
      -- a pending early candidate becomes this jump's final outcome the
      -- instant the window opens -- the move can never come out after an
      -- early miss, confirmed by Peter in-game, so no success check can
      -- ever override this once set
      if _current_jump.early_candidate_frame then
        _current_jump.outcome = "early_miss"
        _current_jump.outcome_frame = _current_jump.early_candidate_frame
        _current_jump.outcome_pos_y = _current_jump.early_candidate_pos_y
      end
    end

    -- too-late candidate: pure down+MK edge after crossing usable_from AND
    -- after the jump has started descending (see has_started_descending
    -- above -- required so a rising press between 74 and late_usable_floor,
    -- which only happens for big jump since its floor 77 is above 74,
    -- doesn't get misread as too-late), at a height already below this
    -- jump_type's late_usable_floor (the lowest height Peter's confirmed
    -- the move still comes out at -- see jump_apex_data comment above) --
    -- always fails outright, no animation check needed, same certainty as
    -- early_miss (Peter, 2026-11-14: "最後能成功的高度是 -12 y=72，所以-13
    -- 開始都是y<72都應該是too late"). Checked BEFORE the pending-attempt
    -- candidate below so a below-the-floor press never gets treated as an
    -- unconfirmed attempt waiting on ground truth -- it's already a known
    -- fail. Overwritten on every eligible press while unconfirmed... except
    -- once outcome is set here it can't be overwritten (not
    -- _current_jump.outcome guards both this and the pending-attempt check
    -- below), same "first locked in wins" rule early_miss already has once
    -- crossed_frame is set.
    if _current_jump.crossed_frame and not _current_jump.outcome
      and _current_jump.has_started_descending
      and _player.pos_y < _current_jump.jump_type.late_usable_floor
      and jump_apex_any_attack_pressed(_player)
      and not jump_apex_try_wrong_input_warning(_player) then
      _current_jump.outcome = "too_late_miss"
      _current_jump.outcome_frame = frame_number
      _current_jump.outcome_pos_y = _player.pos_y
    end

    -- attempt candidate: pure down+MK edge any time after first crossing
    -- usable_from AND still at/above late_usable_floor, no outcome locked
    -- in yet -- covers both still-above-74 and already-descended-but-
    -- still-above-the-floor presses with the same check. Recorded
    -- frame/height are what gets displayed (the INPUT moment), not
    -- whatever frame confirms it below -- the move's own animation (2aa0)
    -- visibly changing lags the true input frame by the game's own
    -- internal processing (confirmed 2026-11-13: Peter reported "0 y=74"
    -- before a prior bugfix and "-1 y=74" after it, for what was otherwise
    -- the same timing -- that 1-frame gap was this animation-onset lag, not
    -- a bug in the crossing-detection fix. This check runs AFTER the
    -- crossing-detection above so a press on the exact frame height first
    -- reaches 74 still sees crossed_frame as already set this same frame --
    -- moving this check earlier than crossing-detection reintroduced the
    -- "0 y=74" bug once, 2026-11-13, fixed by restoring this position).
    -- Overwritten on every eligible press while unconfirmed, same "latest
    -- wins" approach as the early candidate above. Same wrong-input
    -- short-circuit as the early candidate check.
    --
    -- Flagged, untested risk (win-codex POST review, 2026-11-13): if the
    -- move's own input gets buffered by the game (a correct press, then
    -- extra mashed MK presses before the animation visibly changes), a
    -- later mash press could overwrite pending_attempt_frame/pos_y on the
    -- SAME frame has_animation_just_changed finally confirms, attributing
    -- the success to the mash instead of the real triggering press. Not
    -- fixed here -- needs frame-step verification of whether this can
    -- actually happen before guessing at a fix (ship with it as a known
    -- limitation, same as the already-documented MK-ordering caveat).
    --
    -- Related, flagged (win-codex POST review, 2026-11-14): the too-late
    -- check above runs every frame too, so a later mash press that's
    -- already below late_usable_floor could lock in too_late_miss on top
    -- of an earlier, still-unconfirmed VALID pending attempt, before that
    -- earlier press's own animation confirmation ever gets a chance to
    -- land -- same root cause (mashing during an unconfirmed attempt), just
    -- the failure side of the same risk. Also not fixed -- needs frame-step
    -- verification (a last-valid press followed by another MK edge while
    -- the animation is still pending).
    if _current_jump.crossed_frame and not _current_jump.outcome
      and jump_apex_any_attack_pressed(_player)
      and not jump_apex_try_wrong_input_warning(_player) then
      _current_jump.pending_attempt_frame = frame_number
      _current_jump.pending_attempt_pos_y = _player.pos_y
    end

    -- confirm success once the move's own animation actually appears --
    -- ground truth, so it also catches any input-validity rule we haven't
    -- found yet, not just the diagonal-down case. If it never arrives, this
    -- jump's outcome just stays nil (no marker/number shown for it at all)
    -- -- the too-late case above is the only "confirmed-failed-without-
    -- animation" outcome this file knows about; any other unconfirmed
    -- attempt (above the floor) still just shows nothing rather than
    -- guessing at a fail state for it.
    if _current_jump.pending_attempt_frame and not _current_jump.outcome
      and _player.has_animation_just_changed and _player.animation == _data.move_animation then
      _current_jump.outcome = "success"
      _current_jump.outcome_frame = _current_jump.pending_attempt_frame
      _current_jump.outcome_pos_y = _current_jump.pending_attempt_pos_y
    end

    _current_jump.previous_pos_y = _player.pos_y
  end

  if _is_grounded then
    _current_jump.active = false
  end
end

-- shared by the live/landed jump display and the idle default preview
-- below -- same shape (takeoff_frame, outcome, outcome_frame,
-- outcome_pos_y, crossed_frame -- used only for the +/- readout math, not
-- for tick positions). _tail_frame/_open_t/_close_t are this jump_type's
-- own precomputed total_frames/window_open_t/window_close_t either way
-- (fixed, so it's identical whether still airborne, already landed, or
-- the idle preview's normal-jump default) -- both callers always pass
-- them now, so the "[ ]" ticks show immediately alongside the pre-drawn
-- track rather than ever waiting on live crossing detection.
local function jump_apex_draw_gauge_body(_record, _tail_frame, _open_t, _close_t)
  local _x = screen_width - 138 - get_text_width("Juggle: ")
  local _y = 106
  local _label = "Air Down K: "
  local _scale = 2
  local _track_height = 4
  local _track_color = 0xD6E7EFFF
  local _success_color = 0x10FB00FF
  local _miss_color = 0xE70000FF

  local _track_width = math.max((_tail_frame - _record.takeoff_frame) * _scale, 1)

  gui.text(_x + 1, _y, _label, text_default_color, text_default_border_color)
  gui.box(_x, _y + 8, _x + _track_width, _y + 8 + _track_height, _track_color, 0x00000000)

  -- window-open tick ("[")
  draw_vertical_line(_x + _open_t * _scale, _y + 7, _y + 9 + _track_height, 0xFFFFFFFF)

  -- window-close tick ("]")
  draw_vertical_line(_x + _close_t * _scale, _y + 7, _y + 9 + _track_height, 0xFFFFFFFF)

  -- outcome marker + readout: green/success or red/miss, only once this
  -- jump (live or frozen) actually has an outcome
  if _record.outcome then
    local _marker_color = _record.outcome == "success" and _success_color or _miss_color
    local _marker_x = _x + (_record.outcome_frame - _record.takeoff_frame) * _scale
    gui.box(_marker_x, _y + 6, _marker_x + 2, _y + 10 + _track_height, _marker_color, _marker_color)

    -- +/- readout, Parry's own sign convention (src/draw.lua:323-337):
    -- displayed value is -delta. 0 = best. Late-but-successful shows
    -- negative (no "+"); too-early miss shows positive (with "+"). Fixed
    -- position right after the label, not tied to any bar position -- the
    -- track itself is already pre-drawn full width from takeoff (no live
    -- growth to track), but the readout still only appears once the
    -- outcome is actually known, same as the marker above. crossed_frame
    -- is guarded since an early_miss on a jump that never actually reaches
    -- 74 would leave it nil.
    --
    -- "Too Early"/"Too Late" text prefix (Peter, 2026-11-13/14): early_miss
    -- -> "Too Early" (always positive, pressed before crossing 74,
    -- confirmed in-game, no exceptions); too_late_miss -> "Too Late"
    -- (below late_usable_floor, see jump_apex_data/pending_attempt comments
    -- above). A successful-but-late press (negative value, still above
    -- late_usable_floor) gets NO prefix -- "Too Late" means a confirmed
    -- fail now, not just "later than 0", so a late success that still
    -- worked just shows its plain -N y=xx. Zero (the best case) also gets
    -- no prefix.
    if _record.crossed_frame then
      local _display_value = -(_record.outcome_frame - _record.crossed_frame)
      local _delta_text = _display_value > 0 and string.format("+%d", _display_value) or string.format("%d", _display_value)
      local _timing_label = ""
      if _record.outcome == "early_miss" then
        _timing_label = "Too Early "
      elseif _record.outcome == "too_late_miss" then
        _timing_label = "Too Late "
      end
      local _result_text = string.format("%s%s y=%d", _timing_label, _delta_text, _record.outcome_pos_y)
      gui.text(_x + 1 + get_text_width(_label), _y, _result_text, _marker_color, text_default_border_color)
    end
  end
end

-- traveling timing pointer, drawn only over a jump whose total length is
-- already known (a measured jump_type) -- the whole track is pre-drawn
-- full width for these (see jump_apex_draw_gauge below), so a pointer
-- sweeping across it at the real elapsed-frame position gives live
-- red/green/red timing feedback even before any attempt is made. Red
-- before/after the window, green while _current_jump.is_in_window (set
-- live off real pos_y, not off the precomputed total_frames, so it's
-- accurate even if the actual window timing ever drifts from the
-- originally-measured sample).
local function jump_apex_draw_pointer()
  local _x = screen_width - 138 - get_text_width("Juggle: ")
  local _y = 106
  local _scale = 2
  local _track_height = 4
  local _success_color = 0x10FB00FF
  local _miss_color = 0xE70000FF

  local _t = math.min(frame_number - _current_jump.takeoff_frame, _current_jump.jump_type.total_frames)
  local _pointer_x = _x + _t * _scale
  local _pointer_color = _current_jump.is_in_window and _success_color or _miss_color
  draw_vertical_line(_pointer_x, _y + 5, _y + 11 + _track_height, _pointer_color)
end

local function jump_apex_draw_gauge()
  -- wrong-input warning overrides the gauge entirely -- Peter: don't keep
  -- showing the previous (possibly now-stale) result underneath it.
  if jump_apex_input_warning.active then
    local _x = screen_width - 138 - get_text_width("Juggle: ")
    local _y = 106
    gui.text(_x + 1, _y, "Air Down K: " .. jump_apex_input_warning.text, 0xE70000FF, text_default_border_color)
    return
  end

  -- draw straight from the most recent jump's own tracker -- live while
  -- still airborne, or just sitting there landed -- this is what makes
  -- the bar visibly open the instant you take off (Peter, 2026-11-13) AND
  -- what makes a plain jump with no attempt show no marker/number once
  -- landed instead of some earlier jump's stale, possibly mismatched
  -- result (Peter, 2026-11-13: it only ever shows THIS jump's own real
  -- data, clearing at the next takeoff -- see _current_jump comment
  -- above). takeoff_frame (and jump_type) is only ever set for a
  -- recognized jump (see jump_apex_gauge_update), so the whole timeline is
  -- always pre-drawn full width right away for those, instead of growing
  -- frame by frame -- Peter explicitly doesn't want the growing style at
  -- all. The traveling pointer only sweeps while still actually airborne.
  if _current_jump.takeoff_frame then
    local _jt = _current_jump.jump_type
    jump_apex_draw_gauge_body(_current_jump, _current_jump.takeoff_frame + _jt.total_frames, _jt.window_open_t, _jt.window_close_t)
    if _current_jump.active then
      jump_apex_draw_pointer()
    end
    return
  end

  -- idle: mode is selected but no jump has happened yet at all -- default
  -- to showing the normal jump's own static timeline (ticks included) as
  -- a preview (Peter, 2026-11-13), not just a bare label, so the gauge is
  -- visibly "open" at its real eventual width the instant the mode is
  -- selected.
  local _default_type = jump_apex_data.gouki.jump_types[12]
  jump_apex_draw_gauge_body({ takeoff_frame = 0 }, _default_type.total_frames, _default_type.window_open_t, _default_type.window_close_t)
end

-- ---------------------------------------------------------------------------

function special_training_jump_apex_draw()
  if not (is_in_match and not training_settings.recording_mission_mode) then
    -- leaving the match (or entering mission-recording mode) skips the rest
    -- of this function entirely, including the mode/player invalidation
    -- below -- without this, a tracker/result from the match just left
    -- could still be sitting there the next time a match starts and the
    -- same P1/P2 object gets observed again (win-codex POST review round
    -- 2, 2026-11-13: this exact early return bypassed the fix below).
    if _jump_apex_observed_player then
      jump_apex_clear_current_jump()
      _jump_apex_observed_player = nil
    end
    return
  end

  if training_settings.display_jump_apex_lines then
    jump_apex_draw_band(P1)
  end

  local _is_observing = false

  if special_training_mode[training_settings.special_training_current_mode] == "Air Down K" then
    local _selected_character = jump_apex_lines_character_names[training_settings.jump_apex_lines_character]
    local _char_str = _selected_character:lower()
    -- Gouki can be in either slot -- check both rather than assuming P1.
    -- Hardcoding P1 made facing/direction detection read the WRONG
    -- player's flip_x/input when Gouki was actually P2, showing wrong
    -- 1MK/3MK labels on that side (Peter, 2026-11-13).
    local _player = (P1.char_str == _char_str and P1) or (P2.char_str == _char_str and P2)
    if _player then
      local _data = jump_apex_data[_char_str]
      if _data then
        _is_observing = true
        if _jump_apex_observed_player ~= _player then
          -- switched which player object we're tracking (character/slot
          -- changed while this mode stayed selected) -- clear rather than
          -- risk a stale jump from the PREVIOUSLY observed player getting
          -- spliced into this one's events.
          jump_apex_clear_current_jump()
        end
        _jump_apex_observed_player = _player
        jump_apex_gauge_update(_player, _data)
        jump_apex_draw_gauge()
      end
    end
    if not _is_observing then
      -- same wrong-character hint pattern as 720_trainer.lua's "720 Trainer:
      -- Hugo Only" -- same gauge position, same colors
      local _x = screen_width - 138 - get_text_width("Juggle: ")
      local _y = 106
      gui.text(_x, _y, string.format("Air Down K: %s Only", _selected_character), 0xFFFFFFFF, 0x00000080)
    end
  end

  if not _is_observing and _jump_apex_observed_player then
    -- mode switched away, or the selected character is no longer present
    -- (match restarted differently, etc.) while a jump was still being
    -- tracked -- clear now so the next time this mode becomes active again
    -- it starts clean on the next real takeoff, instead of resuming a
    -- stale tracker that could splice two different jumps' events together
    -- (win-codex POST review, 2026-11-13).
    jump_apex_clear_current_jump()
    _jump_apex_observed_player = nil
  end
end
