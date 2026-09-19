FRAME_TABLE_LENGTH = 90 -- ~1.5s at 60fps

frame_table_colors = {
  neutral    = 0x444444FF, -- idle / empty
  startup    = 0x00FF00FF, -- startup (windup before hitbox)
  movement   = 0x88AA55FF, -- dash/jump/landing — not idle yet, but not a real attack windup either
  active     = 0xFF4040FF, -- active (hitbox active)
  projectile = 0xCC7722FF, -- projectile active (hitbox on projectile object)
  recovery   = 0x4080FFFF, -- recovery (busy after active)
  hitstun    = 0xFFFF00FF, -- hitstun/knockdown/wakeup/thrown
  blocked    = 0x00E5FFFF, -- blockstun (attack was blocked, not parried)
  parry      = 0xCC33FFFF, -- parry validity window (input-acceptance opportunity), not just a successful parry
  invincible = 0xFFFFFFFF, -- invincible
  -- SA Only: all 3 validity-window types share one color — some SAs require
  -- alternating forward/down parries mid-sequence, and distinct per-type
  -- colors there just read as visual noise rather than useful information
  parry_forward = 0xCC33FFFF,
  parry_down    = 0xCC33FFFF,
  parry_air     = 0xCC33FFFF,
}

-- each player has its own independent capture: p1 and p2 arm/fill/freeze separately,
-- so a long sequence on one side doesn't restart the other side's display
frame_table_players = {
  p1 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil, prev_start_frame = nil },
  p2 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil, prev_start_frame = nil },
}
frame_table_stats = { p1 = nil, p2 = nil }
frame_table_has_been_active = { p1 = false, p2 = false }
frame_table_in_hitstun = { p1 = false, p2 = false }
-- absolute frame_number the fixed 16F parrier-side freeze suppression ends,
-- set from has_just_parried (see frame_table_classify) — a plain frame
-- countdown, not tied to remaining_freeze_frames (which is shared/global and
-- can chain seamlessly from hit to hit in a tight combo without ever actually
-- reaching 0, which would otherwise leave the suppression stuck on forever).
-- Regular and SA Only modes keep independent trackers so switching modes
-- mid-match can't leave one mode's countdown affecting the other.
frame_table_parry_freeze_until = { p1 = nil, p2 = nil }
frame_table_sa_parry_freeze_until = { p1 = nil, p2 = nil }
-- true only for the side whose OWN action (attack/parry) triggered the current
-- capture; the other side gets armed passively so its buffer has real neutral
-- frames leading up to the incoming attack. Without this, a passively-armed
-- defender that hasn't been hit/blocked/parried yet falls through classify()'s
-- final fallback and shows a false "startup" (green) blip right as the
-- attacker's super-freeze ends, before anything has actually reached them.
frame_table_own_trigger = { p1 = false, p2 = false }
-- Parry SA Only mode's own rising-edge tracker for superfreeze_decount, kept
-- separate from frame_table_prev_superfreeze (the parry-history reset tracker)
-- so the two independent checks don't consume each other's edge
frame_table_prev_superfreeze_strip = { p1 = 0, p2 = 0 }
-- regular mode only: rising-edge tracker for is_in_jump_startup, used to arm a
-- fresh capture on jump start the same way an attack does
frame_table_prev_jump_startup = { p1 = false, p2 = false }
-- regular mode only: rising-edge tracker for walk/dash (movement_type2 2/3/4
-- while movement_type==0), used to arm a fresh capture the same way an
-- attack does. Values confirmed empirically 2026-09-14: 2=walk forward,
-- 3=walk backward, 4=dash
frame_table_prev_ground_movement = { p1 = false, p2 = false }
-- true only when the row's current capture was armed by a movement trigger
-- (walk/dash/jump start) rather than an attack/parry — lets a later movement
-- trigger force a fresh re-arm over a stray movement capture (e.g. a 1-frame
-- walk blip) without ever cutting short a real attack capture in progress
frame_table_armed_by_movement = { p1 = false, p2 = false }
-- Parry SA Only: true from an SA's rising edge until both players have
-- genuinely settled back to neutral; gates continuation re-arming so a long
-- SA's buffer-boundary crossings don't get mistaken for the sequence ending
frame_table_sa_episode_active = false
-- once a failure (hurt/yellow-marker) event lands during an SA episode, both
-- sides freeze exactly where they are instead of continuing to fill with
-- mostly-neutral padding until the episode settles — there's little value in
-- continuing to capture after a miss, and it avoids the strip drifting into
-- a long stretch of dim/neutral columns. Cleared on the next SA's rising edge.
frame_table_sa_episode_frozen = false

-- tracks how many consecutive frames each player has been in the current
-- classify() state, independent of buffer/capture resets, so the per-segment
-- frame count stays correct across a re-arm in the middle of a long run
-- (e.g. a combo's "active"/"hitstun" run lasting longer than FRAME_TABLE_LENGTH)
frame_table_run_length = { p1 = 0, p2 = 0 }
frame_table_prev_state = { p1 = nil, p2 = nil }
frame_table_pending_adv = { p1 = nil, p2 = nil }
-- each entry: { attacker_neutral_abs = N, expires = frame_N } or nil
frame_table_pending_stats = { p1 = nil, p2 = nil }
-- each entry: { startup=N, attacker_start_frame=N, active_end_abs=N, defender_key="p1"/"p2", defender_start_frame=N, expires=N } or nil
frame_table_prev_animation = { p1 = nil, p2 = nil }
frame_table_prev_action = { p1 = nil, p2 = nil }
frame_table_just_cancelled = { p1 = false, p2 = false }

local function has_hitbox(_player_obj)
  if not _player_obj.boxes then return false end
  for _, _box in ipairs(_player_obj.boxes) do
    if _box.type == "attack" or _box.type == "throw" then
      return true
    end
  end
  return false
end

local function has_active_projectile(_player_obj)
  for _, _proj in pairs(projectiles) do
    if _proj.emitter_id == _player_obj.id and _proj.has_activated then
      return true
    end
  end
  return false
end

local function has_vulnerability_box(_player_obj)
  if not _player_obj.boxes then return false end
  for _, _box in ipairs(_player_obj.boxes) do
    if _box.type == "vulnerability" or _box.type == "ext. vulnerability" then
      return true
    end
  end
  return false
end

-- halves each RGB channel (keeps alpha) for the dimmed "previous capture"
-- overlay; avoids Lua 5.1 bitwise operators (not available in FBNeo's Lua)
local function frame_table_dim_color(_color)
  local _a = _color % 256
  local _b = math.floor(_color / 256) % 256
  local _g = math.floor(_color / 65536) % 256
  local _r = math.floor(_color / 16777216) % 256
  return math.floor(_r / 2) * 16777216 + math.floor(_g / 2) * 65536 + math.floor(_b / 2) * 256 + _a
end

local function find_first(_buffer, _value, _from)
  for i = _from, #_buffer do
    if _buffer[i] == _value then
      return i
    end
  end
  return nil
end

-- same "move just started" trigger as frame_advantage.lua, used to arm the
-- capture earlier than classify() would (which can miss the first startup
-- frames while is_idle is still true)
local function has_just_attacked(_player_obj)
  return _player_obj.has_just_attacked or _player_obj.has_just_thrown
end

function frame_table_classify(_player_obj, _player_key)
  -- parry and hitbox-active can land on the same frame as is_idle == true,
  -- so check them before the early-out neutral return
  if training_settings.frame_table_sa_only then
    -- SA Only: purple-family states represent the active parry VALIDITY WINDOW
    -- (the input-acceptance opportunity), not the post-hit freeze — the freeze
    -- length varies by attack type (see _reference/sf33_System_clean.md), so
    -- it isn't a reliable fixed-width training reference the way the per-type
    -- validity window (10F forward/down, 7F air) is. Anti-Air Parry excluded,
    -- consistent with the rest of this file's SA-only parry-history feature.
    if _player_obj.has_just_parried then
      frame_table_sa_parry_freeze_until[_player_key] = frame_number + 16
    end
    if _player_obj.parry_forward and _player_obj.parry_forward.validity_time > 0 then
      return "parry_forward"
    end
    if _player_obj.parry_down and _player_obj.parry_down.validity_time > 0 then
      return "parry_down"
    end
    if _player_obj.parry_air and _player_obj.parry_air.validity_time > 0 then
      return "parry_air"
    end

    -- the window already closed this frame (or earlier) — if we're still
    -- inside the resulting post-parry freeze, that's a consequence of a
    -- successful parry, not genuine hitstun; suppress the hitstun catch-all
    -- below (which would otherwise misclassify the freeze tail as "hitstun"
    -- now that this branch no longer returns "parry" for it) and show blank
    -- neutral instead until the freeze actually ends. Uses a fixed 16-frame
    -- countdown from the parry frame (the parrier's own documented constant),
    -- NOT remaining_freeze_frames — that value is shared/global and can chain
    -- seamlessly across consecutive hits in a tight combo without ever truly
    -- reaching 0, which would otherwise leave this suppressed forever.
    if frame_table_sa_parry_freeze_until[_player_key]
      and frame_number < frame_table_sa_parry_freeze_until[_player_key] then
      return "neutral"
    end
  else
    -- regular mode mirrors SA Only's approach: purple represents the active
    -- parry VALIDITY WINDOW (the input-acceptance opportunity), not the
    -- post-hit freeze — the freeze length varies by attack type, so it isn't
    -- a reliable fixed-width training reference the way the per-type
    -- validity window (10F forward/down, 7F air, 5F anti-air) is. Anti-Air
    -- Parry is included here (unlike SA Only, which deliberately excludes it
    -- for its own parry-history feature) since this is the general-purpose
    -- frame viewer.
    -- forward/back walking taps the exact same input as a forward/down parry
    -- attempt (SF3 has no dedicated parry button), so the engine opens a
    -- validity window on every plain directional tap regardless of whether
    -- anything is actually incoming — gate on the opponent genuinely having
    -- an active hitbox/projectile right now, or this fires constantly during
    -- normal movement and drowns out real parry opportunities
    if _player_obj.has_just_parried then
      frame_table_parry_freeze_until[_player_key] = frame_number + 16
    end
    local _opponent_obj = player_objects[(_player_key == "p1") and 2 or 1]
    local _opponent_attacking = _opponent_obj
      and (has_hitbox(_opponent_obj) or has_active_projectile(_opponent_obj))
    if _opponent_attacking then
      if _player_obj.parry_forward and _player_obj.parry_forward.validity_time > 0 then
        return "parry"
      end
      if _player_obj.parry_down and _player_obj.parry_down.validity_time > 0 then
        return "parry"
      end
      if _player_obj.parry_air and _player_obj.parry_air.validity_time > 0 then
        return "parry"
      end
      if _player_obj.parry_antiair and _player_obj.parry_antiair.validity_time > 0 then
        return "parry"
      end
    end

    -- the window already closed this frame (or earlier) — if we're still
    -- inside the resulting post-parry freeze, that's a consequence of a
    -- successful parry, not genuine hitstun; suppress the hitstun catch-all
    -- below and show blank neutral instead until the freeze actually ends.
    -- Uses a fixed 16-frame countdown from the parry frame (the parrier's own
    -- documented constant), NOT remaining_freeze_frames — that value is
    -- shared/global and can chain seamlessly across consecutive hits in a
    -- tight combo without ever truly reaching 0, which would otherwise leave
    -- this suppressed forever.
    if frame_table_parry_freeze_until[_player_key]
      and frame_number < frame_table_parry_freeze_until[_player_key] then
      return "neutral"
    end
  end

  -- the game clears the attack hitbox from memory on the connect frame (and for the
  -- remaining active frames once it has hit), so also treat the connect frame and
  -- the following hitstop as active
  if has_active_projectile(_player_obj) then
    frame_table_has_been_active[_player_key] = true
    return "projectile"
  end

  if has_hitbox(_player_obj) or _player_obj.has_just_hit or _player_obj.has_just_been_blocked
    or (frame_table_has_been_active[_player_key] and _player_obj.remaining_freeze_frames > 0) then
    frame_table_has_been_active[_player_key] = true
    return "active"
  end

  -- dash/big-jump/plain-airborne don't set busy_flag/is_attacking/etc, so
  -- is_idle stays true throughout them (confirmed via [FT_MOVE_DBG],
  -- 2026-09-14) — without this check they'd fall straight into the is_idle
  -- branch below and always read as neutral instead of movement.
  -- movement_type2 is only this "basic engine movement" sub-state while
  -- movement_type==0 (same mode is_in_jump_startup already relies on) —
  -- during an actual move/hitstun movement_type becomes 1 and movement_type2
  -- turns into a move-specific ID, so gating on movement_type==0 keeps this
  -- from colliding with those.
  -- 4=forward dash, 5=back dash, 13=big jump startup, 14/15/16=airborne
  -- normal jump (forward/neutral/back), 20/21/22=airborne big jump
  -- (forward/neutral/back). plain walk (2=forward, 3=backward) deliberately
  -- excluded: dash is executed as a quick double-tap, so its own trigger is
  -- always preceded by a sliver of walk state — coloring that sliver made
  -- every dash look like it wiped out and restarted a preceding walk capture
  -- instead of just starting cleanly. the plain jump-startup phase itself is
  -- 12, already handled by is_in_jump_startup reaching the not-on-ground
  -- fallback further down once is_idle is bypassed
  if not training_settings.frame_table_sa_only and _player_obj.movement_type == 0
    and (_player_obj.movement_type2 == 4 or _player_obj.movement_type2 == 5
      or _player_obj.movement_type2 == 13
      or _player_obj.movement_type2 == 14 or _player_obj.movement_type2 == 15
      or _player_obj.movement_type2 == 16
      or _player_obj.movement_type2 == 20 or _player_obj.movement_type2 == 21
      or _player_obj.movement_type2 == 22) then
    return "movement"
  end

  if _player_obj.is_idle then
    frame_table_has_been_active[_player_key] = false
    frame_table_in_hitstun[_player_key] = false
    return "neutral"
  end

  -- opponent's super-flash freeze pauses this player before anything has
  -- actually happened to them yet (no hit/block/parry event fired) — without
  -- this, the shared freeze alone would fall into the hitstun catch-all below
  local _in_superfreeze = (player_objects[1] and player_objects[1].superfreeze_decount > 0)
    or (player_objects[2] and player_objects[2].superfreeze_decount > 0)
  if _in_superfreeze and _player_obj.remaining_freeze_frames > 0
    and not frame_table_has_been_active[_player_key] and not frame_table_in_hitstun[_player_key] then
    return "neutral"
  end

  -- blockstun is its own distinct outcome (didn't parry, but chip-blocked rather
  -- than eating a raw hit) — check before the hitstun catch-all so it isn't
  -- lumped in with genuine hitstun
  if _player_obj.is_blocking then
    frame_table_in_hitstun[_player_key] = false
    return "blocked"
  end

  -- unable to act due to damage / knockdown / getting up / being thrown
  -- sticky for the whole knockdown/hitstun sequence, not just the trigger frame
  -- (also covers hitstop freeze frames right after being hit, before has_just_been_hit/is_wakingup fire)
  local _is_hitstun_event = _player_obj.has_just_been_hit or _player_obj.is_being_thrown or _player_obj.is_wakingup or _player_obj.is_fast_wakingup
    or (_player_obj.remaining_freeze_frames > 0 and not frame_table_has_been_active[_player_key])
  if _is_hitstun_event or frame_table_in_hitstun[_player_key] then
    frame_table_in_hitstun[_player_key] = true
    return "hitstun"
  end

  if not has_vulnerability_box(_player_obj) and not frame_table_has_been_active[_player_key] then
    return "invincible"
  end

  if frame_table_has_been_active[_player_key] then
    return "recovery"
  end

  -- passively-armed side (opponent's action triggered the capture, not this
  -- player's own) with nothing classifiable yet: waiting, not starting up
  if not frame_table_own_trigger[_player_key] then
    return "neutral"
  end

  -- an attack already committed to (is_attacking true) but with no hitbox
  -- yet keeps showing "startup" even while airborne — many jumping specials
  -- (and jump-in normals) leave the ground as part of their own windup, and
  -- without this check they'd otherwise hit the "not on ground" movement
  -- branch below and misreport as plain movement instead of attack startup
  if _player_obj.is_attacking then
    return "startup"
  end

  -- regular mode only: not simply standing/crouching still (dash, jump, walk,
  -- landing recovery), no hitbox yet — could be genuine attack startup, or
  -- could just be movement that never produces a hitbox at all. Can't tell
  -- which in advance, so treat anything that isn't plain grounded stillness
  -- as movement rather than defaulting it to startup; has_just_landed is
  -- checked separately since a player can already read as "on the ground"
  -- for standing_state purposes during the single-frame landing-recovery
  -- blip is_idle catches, which is_state_on_ground alone would miss.
  if not training_settings.frame_table_sa_only
    and (not is_state_on_ground(_player_obj.standing_state, _player_obj) or _player_obj.has_just_landed) then
    return "movement"
  end

  return "startup"
end

-- update Start/Total/Adv stats using the just-finished capture of _attacker_key
-- (only if that capture actually contains an attack; cross-references the other
-- player's independently-running buffer via absolute frame numbers)
local function find_first_active(_buffer, _from)
  for i = _from, #_buffer do
    if _buffer[i] == "active" or _buffer[i] == "projectile" then
      return i
    end
  end
  return nil
end

function frame_table_update_stats(_attacker_key)
  local _attacker = frame_table_players[_attacker_key]
  local _defender_key = (_attacker_key == "p1") and "p2" or "p1"
  local _defender = frame_table_players[_defender_key]

  local _active_start = find_first_active(_attacker.buffer, 1)
  if not _active_start then
    return -- this capture wasn't an attack, leave existing stats alone
  end

  local _active_end = _active_start
  for i = _active_start, #_attacker.buffer do
    if _attacker.buffer[i] == "active" or _attacker.buffer[i] == "projectile" then
      _active_end = i
    else
      break
    end
  end

  local _attacker_neutral_idx = find_first(_attacker.buffer, "neutral", _active_end + 1)
  local _total = nil
  local _advantage = nil

  if _attacker_neutral_idx then
    _total = _attacker_neutral_idx - 1

    local _attacker_neutral_abs = _attacker.start_frame + _attacker_neutral_idx - 1
    local _search_from_abs = _attacker.start_frame + _active_end
    local _from_idx = _search_from_abs - _defender.start_frame + 1
    if _from_idx < 1 then _from_idx = 1 end

    local _defender_neutral_idx = find_first(_defender.buffer, "neutral", _from_idx)
    if _defender_neutral_idx then
      local _defender_neutral_abs = _defender.start_frame + _defender_neutral_idx - 1
      _advantage = _defender_neutral_abs - _attacker_neutral_abs
    else
      frame_table_pending_adv[_attacker_key] = {
        attacker_neutral_abs = _attacker_neutral_abs,
        expires = frame_number + 90,
      }
    end
  else
    frame_table_pending_stats[_attacker_key] = {
      startup              = _active_start - 1,
      attacker_start_frame = _attacker.start_frame,
      active_end_abs       = _attacker.start_frame + _active_end - 1,
      defender_key         = _defender_key,
      defender_start_frame = _defender.start_frame,
      expires              = frame_number + 150,
    }
  end

  frame_table_stats[_attacker_key] = {
    startup   = _active_start - 1,
    total     = _total,
    advantage = _advantage,
  }
end

local function frame_table_arm(_key, _preserve_as_dimmed, _clear_stats)
  local _p = frame_table_players[_key]
  -- if this is a continuation re-arm (the previous capture filled the whole
  -- table while the action was still going), keep it as a dimmed overlay for
  -- the columns the new capture hasn't reached yet (1.17). a fresh-action
  -- re-arm discards it, since the dimmed data wouldn't relate to the new action.
  if _preserve_as_dimmed and _p.count >= FRAME_TABLE_LENGTH then
    _p.prev_buffer = _p.buffer
    _p.prev_run_lengths = _p.run_lengths
    _p.prev_start_frame = _p.start_frame
  else
    _p.prev_buffer = nil
    _p.prev_run_lengths = nil
    _p.prev_start_frame = nil
  end
  _p.armed = true
  _p.count = 0
  _p.buffer = {}
  _p.run_lengths = {}
  _p.start_frame = frame_number
  if _clear_stats ~= false then
    frame_table_stats[_key] = nil
    frame_table_pending_adv[_key] = nil
    frame_table_pending_stats[_key] = nil
  end
end

function frame_table_update(_player1_obj, _player2_obj)
  if not _player1_obj.boxes or not _player2_obj.boxes then return end
  local _objs = { p1 = _player1_obj, p2 = _player2_obj }

  -- reset has_been_active only when animation AND action both change (new move started):
  -- same-move phase changes (e.g. active→recovery of a special) keep action constant,
  -- so they no longer incorrectly clear has_been_active and show green.
  -- when a cancel is confirmed, also retroactively fix any gap recovery frame to startup.
  for _, _key in ipairs({ "p1", "p2" }) do
    if _objs[_key].animation ~= (frame_table_prev_animation[_key] or "")
       and frame_table_has_been_active[_key]
       and frame_table_prev_action[_key] ~= nil
       and _objs[_key].action ~= frame_table_prev_action[_key] then
      frame_table_has_been_active[_key] = false
      frame_table_just_cancelled[_key] = true
    end
    frame_table_prev_animation[_key] = _objs[_key].animation
    frame_table_prev_action[_key] = _objs[_key].action
  end

  local _states = {
    p1 = frame_table_classify(_player1_obj, "p1"),
    p2 = frame_table_classify(_player2_obj, "p2"),
  }

  -- regular mode only: walk-start, dash-start (movement_type2 rising edge
  -- into 4/5 while movement_type==0, walk excluded — see the classify()
  -- comment on why) and jump-start (is_in_jump_startup rising edge) each arm
  -- a fresh capture the same way an attack does, so these movement-only
  -- actions get their own frame-table entry instead of only ever showing up
  -- incidentally during an attack-triggered capture
  local _just_moved = { p1 = false, p2 = false }
  if not training_settings.frame_table_sa_only then
    for _, _key in ipairs({ "p1", "p2" }) do
      local _obj = _objs[_key]
      local _is_ground_movement = _obj.movement_type == 0
        and (_obj.movement_type2 == 4 or _obj.movement_type2 == 5)
      -- big jump's startup is movement_type2==13 rather than the plain
      -- jump's 12 (is_in_jump_startup), but is otherwise the same rising-edge
      -- shape — treat both as "jump started" for arming purposes
      local _is_jump_startup = _obj.is_in_jump_startup
        or (_obj.movement_type == 0 and _obj.movement_type2 == 13)
      local _just_jumped = _is_jump_startup and not frame_table_prev_jump_startup[_key]
      _just_moved[_key] = _just_jumped or (_is_ground_movement and not frame_table_prev_ground_movement[_key])
      frame_table_prev_ground_movement[_key] = _is_ground_movement
      frame_table_prev_jump_startup[_key] = _is_jump_startup
    end

    -- a genuine movement trigger forces a fresh re-arm even when the row is
    -- already armed and mid-fill, but only when that in-progress capture was
    -- ITSELF movement-triggered (e.g. a stray 1-frame walk blip between reps)
    -- — otherwise the real action (e.g. a big jump right after the blip)
    -- silently gets folded into the earlier, unrelated capture instead of
    -- starting its own, since the normal "if not armed" re-arm path below
    -- never runs while the row is still armed. Never overrides an
    -- attack/parry-triggered capture in progress, which would cut short real
    -- frame data.
    for _, _key in ipairs({ "p1", "p2" }) do
      local _p = frame_table_players[_key]
      if _just_moved[_key] and _p.armed and frame_table_armed_by_movement[_key] then
        frame_table_arm(_key, false, false)
        frame_table_own_trigger[_key] = true
        local _other_key = (_key == "p1") and "p2" or "p1"
        if not frame_table_players[_other_key].armed then
          frame_table_arm(_other_key, false, false)
          frame_table_own_trigger[_other_key] = false
          frame_table_armed_by_movement[_other_key] = false
        end
      end
    end
  end


  -- run-length tracking, independent of arming
  for _, _key in ipairs({ "p1", "p2" }) do
    local _state = _states[_key]
    if _state == frame_table_prev_state[_key] then
      frame_table_run_length[_key] = frame_table_run_length[_key] + 1
    else
      frame_table_run_length[_key] = 1
    end
    frame_table_prev_state[_key] = _state
  end

  -- deferred total/adv: when attacker animation lasts >90F (e.g. Ken LP+LK, command grabs),
  -- keep watching until attacker goes neutral or the search window expires
  for _, _key in ipairs({ "p1", "p2" }) do
    local _ps = frame_table_pending_stats[_key]
    if _ps then
      if frame_number > _ps.expires then
        frame_table_pending_stats[_key] = nil
      elseif _states[_key] == "neutral" then
        local _total = frame_number - _ps.attacker_start_frame
        local _attacker_neutral_abs = frame_number

        local _defender = frame_table_players[_ps.defender_key]
        local _from_idx = _ps.active_end_abs - _ps.defender_start_frame + 1
        if _from_idx < 1 then _from_idx = 1 end

        local _defender_neutral_idx = find_first(_defender.buffer, "neutral", _from_idx)
        local _advantage = nil
        if _defender_neutral_idx then
          local _defender_neutral_abs = _ps.defender_start_frame + _defender_neutral_idx - 1
          _advantage = _defender_neutral_abs - _attacker_neutral_abs
        else
          frame_table_pending_adv[_key] = {
            attacker_neutral_abs = _attacker_neutral_abs,
            expires = frame_number + 90,
          }
        end

        if frame_table_stats[_key] then
          frame_table_stats[_key].total     = _total
          frame_table_stats[_key].advantage = _advantage
        end
        frame_table_pending_stats[_key] = nil
      end
    end
  end

  -- deferred advantage: when buffer filled before defender reached neutral (e.g. throws),
  -- keep watching until defender goes neutral or the search window expires
  for _, _key in ipairs({ "p1", "p2" }) do
    local _pending = frame_table_pending_adv[_key]
    if _pending then
      if frame_number > _pending.expires then
        frame_table_pending_adv[_key] = nil
      else
        local _other_key = (_key == "p1") and "p2" or "p1"
        if _states[_other_key] == "neutral" then
          local _advantage = frame_number - _pending.attacker_neutral_abs
          if frame_table_stats[_key] then
            frame_table_stats[_key].advantage = _advantage
          end
          frame_table_pending_adv[_key] = nil
        end
      end
    end
  end

  -- a fresh attack/parry on one side also arms the other side (if it isn't
  -- already capturing its own thing), with the same start_frame, so the
  -- defender's buffer starts with real neutral frames before the action lands.
  -- continuation re-arms (state still active/hitstun/startup after a previous
  -- capture filled up) only re-arm the player it belongs to, so they don't
  -- reset the other player's already-frozen display.
  -- Parry SA Only: a Super Art activation (this player's own superfreeze_decount
  -- rising edge) forces a fresh capture on BOTH sides, overriding whatever
  -- unrelated normal-move capture might already be mid-cycle (armed) — without
  -- this override, an SA that happens to start while the attacker is still
  -- armed from an earlier jab silently swallows the rising edge, since the
  -- normal per-key re-arm logic below only runs when a row is NOT already armed
  if training_settings.frame_table_sa_only then
    for _, _key in ipairs({ "p1", "p2" }) do
      local _freeze_now = _objs[_key].superfreeze_decount
      -- arm on the FALLING edge (freeze just ended), not the rising edge —
      -- the color strip should only start counting once the SA's freeze/flash
      -- screen is over and the real attack sequence begins, not during the
      -- frozen pause itself
      if frame_table_prev_superfreeze_strip[_key] > 0 and _freeze_now == 0 then
        frame_table_sa_episode_active = true
        frame_table_sa_episode_frozen = false
        frame_table_arm(_key, false, false)
        frame_table_own_trigger[_key] = true
        local _other_key = (_key == "p1") and "p2" or "p1"
        frame_table_arm(_other_key, false, false)
        frame_table_own_trigger[_other_key] = false
      end
      frame_table_prev_superfreeze_strip[_key] = _freeze_now
    end

    -- the episode stays "live" (continuation allowed across 90-frame buffer
    -- boundaries regardless of the exact per-frame state, e.g. a brief neutral
    -- gap between two parries) until both sides have genuinely settled back
    -- to neutral, not just whichever single frame happens to land on the boundary
    if frame_table_sa_episode_active then
      local _p1_settled = _objs.p1.is_idle and (_objs.p1.idle_time or 0) > 20
      local _p2_settled = _objs.p2.is_idle and (_objs.p2.idle_time or 0) > 20
      if _p1_settled and _p2_settled then
        frame_table_sa_episode_active = false
        -- freeze both rows exactly where they are the instant the episode
        -- settles, instead of letting them keep filling with neutral padding
        -- until they happen to hit the 90-frame boundary on their own — that
        -- natural boundary can land AFTER all the real content (parries,
        -- blocks) has already scrolled out of the current generation and into
        -- prev_buffer, and a further re-arm from there would start a new,
        -- empty current generation with nothing left to show
        frame_table_players.p1.armed = false
        frame_table_players.p2.armed = false
      end
    end
  end

  for _, _key in ipairs({ "p1", "p2" }) do
    local _state = _states[_key]
    local _p = frame_table_players[_key]

    if not _p.armed then
      local _fresh_trigger
      local _attack_fresh_trigger = _state == "parry" or has_just_attacked(_objs[_key])
      if training_settings.frame_table_sa_only then
        -- fresh triggers in this mode only come from the SA-activation override above;
        -- ordinary attacks/parries here only extend an already-armed (SA) capture via continuation
        _fresh_trigger = false
      else
        _fresh_trigger = _attack_fresh_trigger or _just_moved[_key]
      end
      local _continuation_trigger = _state == "startup" or _state == "active" or _state == "projectile" or _state == "hitstun"
      -- a true continuation means the just-frozen buffer's last slot was already
      -- in this same state (the action carried straight through frame 90);
      -- otherwise this is a brand-new action (e.g. a jump starting right after
      -- an unrelated capture froze) and shouldn't inherit its dimmed overlay
      local _is_true_continuation = _continuation_trigger and _p.buffer[FRAME_TABLE_LENGTH] == _state

      if training_settings.frame_table_sa_only then
        -- gate continuation on still being within the current SA episode (see
        -- above), not a coincidental per-frame state match — a normal jab's own
        -- "startup" frame must never arm a brand-new capture in this mode, and a
        -- long SA's brief neutral gap between parries must not cut it short.
        -- also gate on not being frozen from a failure — once a miss lands,
        -- stop re-arming entirely until the next SA's rising edge clears it
        _continuation_trigger = frame_table_sa_episode_active and not frame_table_sa_episode_frozen
        -- same episode-based gating for the dimmed-overlay decision: a long SA
        -- crossing the 90-frame boundary must keep its previous capture visible
        -- even if the buffer's last slot doesn't literally match the current state
        _is_true_continuation = _continuation_trigger
      end

      if _fresh_trigger or _continuation_trigger then
        frame_table_arm(_key, _is_true_continuation and not _fresh_trigger, _fresh_trigger and _objs[_key].has_animation_just_changed)
        -- only a pure movement trigger (no attack/parry involved) marks this
        -- capture as movement-owned — lets a later movement trigger force a
        -- fresh re-arm over it without ever doing that to an attack capture
        frame_table_armed_by_movement[_key] = _fresh_trigger and not _attack_fresh_trigger

        if _fresh_trigger then
          frame_table_own_trigger[_key] = true
          local _other_key = (_key == "p1") and "p2" or "p1"
          if not frame_table_players[_other_key].armed then
            frame_table_arm(_other_key, false, false)
            frame_table_own_trigger[_other_key] = false
            frame_table_armed_by_movement[_other_key] = false
          end
        end
      end
    end
  end

  for _, _key in ipairs({ "p1", "p2" }) do
    local _state = _states[_key]
    local _p = frame_table_players[_key]

    if _p.armed then
      table.insert(_p.buffer, _state)
      table.insert(_p.run_lengths, frame_table_run_length[_key])
      _p.count = _p.count + 1

      -- retroactive cancel gap fix: the 1-frame gap between hitbox disappearing and
      -- animation updating shows as recovery; relabel only that single frame to startup
      if frame_table_just_cancelled[_key] and _state == "startup" then
        local prev = #_p.buffer - 1
        if prev >= 1 and _p.buffer[prev] == "recovery" then
          _p.buffer[prev] = "startup"
        end
      end
      frame_table_just_cancelled[_key] = false

      if _p.count >= FRAME_TABLE_LENGTH then
        _p.armed = false
        frame_table_update_stats(_key)
        -- SA Only: hitting the natural 90-frame cap while both sides already
        -- happen to be idle (regardless of how long — this is a one-time check
        -- right at the cap, not a general shortcut for the 20-frame settle
        -- threshold elsewhere) almost certainly means the exchange is over, not
        -- a brief mid-SA gap. Without this, the 90-frame cap can keep winning
        -- the race against the 20-frame settle check by a handful of frames
        -- every time, re-arming into an empty generation and burying the real
        -- content that just got captured.
        if training_settings.frame_table_sa_only and frame_table_sa_episode_active
          and _objs.p1.is_idle and _objs.p2.is_idle then
          frame_table_sa_episode_active = false
          frame_table_players.p1.armed = false
          frame_table_players.p2.armed = false
        end
      end
    else
      frame_table_just_cancelled[_key] = false
    end
  end
end

function frame_table_reset()
  frame_table_players.p1 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil, prev_start_frame = nil }
  frame_table_players.p2 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil, prev_start_frame = nil }
  frame_table_stats = { p1 = nil, p2 = nil }
  frame_table_has_been_active = { p1 = false, p2 = false }
  frame_table_in_hitstun = { p1 = false, p2 = false }
  frame_table_parry_freeze_until = { p1 = nil, p2 = nil }
  frame_table_sa_parry_freeze_until = { p1 = nil, p2 = nil }
  frame_table_own_trigger = { p1 = false, p2 = false }
  frame_table_prev_superfreeze_strip = { p1 = 0, p2 = 0 }
  frame_table_prev_jump_startup = { p1 = false, p2 = false }
  frame_table_prev_ground_movement = { p1 = false, p2 = false }
  frame_table_armed_by_movement = { p1 = false, p2 = false }
  frame_table_sa_episode_active = false
  frame_table_sa_episode_frozen = false
  frame_table_run_length = { p1 = 0, p2 = 0 }
  frame_table_prev_state = { p1 = nil, p2 = nil }
  frame_table_pending_adv = { p1 = nil, p2 = nil }
  frame_table_pending_stats = { p1 = nil, p2 = nil }
  frame_table_prev_animation = { p1 = nil, p2 = nil }
  frame_table_prev_action = { p1 = nil, p2 = nil }
  frame_table_just_cancelled = { p1 = false, p2 = false }
end

-- SA Only: a real SA hit's hitstun run can be very long (full launch/juggle),
-- and treating it as opaque (block color + run-length label) would bury the
-- dimmed reference layer underneath for most of the strip — the failure is
-- already marked precisely by the yellow border, so hitstun defers to the
-- dimmed layer the same way "neutral" already does. Regular (non-SA-only)
-- mode is unaffected — there, hitstun length is itself the frame-data being
-- analyzed. Shared by both frame_table_draw_row and frame_table_draw_run_labels
-- so the block color and its run-length label always agree on what's "empty".
local function frame_table_is_transparent_state(_s)
  return _s == "neutral" or (training_settings.frame_table_sa_only and _s == "hitstun")
end

-- label the end of each non-neutral run within [_from, _to] with its (true,
-- possibly pre-capture) consecutive frame count from _run_lengths,
-- right-aligned to the last block of the run
local function frame_table_draw_run_labels(_buffer, _run_lengths, _from, _to, _x, _y, _text_color, _mask_buffer)
  local _block_width = 4
  local function _is_masked(idx)
    local _m = _mask_buffer and _mask_buffer[idx]
    return _m and not frame_table_is_transparent_state(_m)
  end
  local i = _from
  while i <= _to do
    local _state = _buffer[i] or "neutral"
    if frame_table_is_transparent_state(_state) or _is_masked(i) then
      i = i + 1
    else
      local _end = i
      while _end + 1 <= _to and (_buffer[_end + 1] or "neutral") == _state and not _is_masked(_end + 1) do
        _end = _end + 1
      end
      local _length = _run_lengths[_end] or (_end - i + 1)
      local _digits = string.format("%d", _length)
      local _num_width = get_text_width(_digits)
      local _right_edge = _x + _end * _block_width
      gui.text(_right_edge - _num_width, _y, _digits, _text_color, text_default_border_color)
      i = _end + 1
    end
  end
end

function frame_table_draw_row(_buffer, _run_lengths, _prev_buffer, _prev_run_lengths, _x, _y, _predicted_cols)
  local _block_width  = 4
  local _block_height = 8
  for i = 1, FRAME_TABLE_LENGTH do
    local _state = _buffer[i]
    local _mark = _predicted_cols and _predicted_cols[i]
    local _color
    if _mark and _mark.fill then
      -- a solid-fill marker (success resolution frame, or a miss) always wins
      -- over the real per-frame state color, since that column's own frame is
      -- almost always already classified by the time it's marked (e.g. delta=0
      -- lands on the very frame the row arms, which fills buffer[1] in the same
      -- update call) — requiring an empty cell made the marker nearly invisible
      _color = _mark.fill
    elseif _state and not frame_table_is_transparent_state(_state) then
      _color = frame_table_colors[_state] or frame_table_colors.neutral
    elseif _prev_buffer and _prev_buffer[i] and not frame_table_is_transparent_state(_prev_buffer[i]) then
      -- same transparency rule applies once this generation's data has scrolled
      -- into the dimmed prev_buffer layer — otherwise a hitstun run that was
      -- correctly transparent as the current layer would reappear solid yellow
      -- the moment a re-arm pushes it into the dimmed layer. (SA Only freezes
      -- both rows the instant the episode settles — see frame_table_update — so
      -- this doesn't need its own episode-liveness gate any more: once frozen,
      -- there's no further re-arm to scroll real data into a suppressed echo.)
      _color = frame_table_dim_color(frame_table_colors[_prev_buffer[i]] or frame_table_colors.neutral)
    else
      _color = frame_table_colors.neutral
    end
    -- a hollow marker (no .fill, e.g. the held-input frames leading up to a
    -- success) lets the real underlying state color show through as the fill,
    -- and only overlays its own border color on top
    local _border = (_mark and _mark.border) or 0x00000000
    local _bx = _x + (i - 1) * _block_width
    gui.box(_bx, _y, _bx + _block_width - 1, _y + _block_height, _color, _border)
  end

  frame_table_draw_run_labels(_buffer, _run_lengths, 1, FRAME_TABLE_LENGTH, _x, _y, text_default_color)

  if _prev_buffer then
    frame_table_draw_run_labels(_prev_buffer, _prev_run_lengths, 1, FRAME_TABLE_LENGTH, _x, _y, text_disabled_color, _buffer)
  end
end

-- same convention as frame_advantage.lua: green when ahead, red when behind
frame_table_advantage_colors = {
  positive = 0x10FB00FF,
  negative = 0xE70000FF,
  zero     = 0xFFFB63FF,
}

-- returns the "Start/Total" prefix (default color), and the "Adv" value
-- with its own color (green/red/yellow depending on sign), drawn separately
-- so the Adv number can stand out from the rest of the line
function frame_table_stats_parts(_key)
  local _label = (_key == "p1") and "P1" or "P2"
  local _stats = frame_table_stats[_key]
  if not _stats then
    return string.format("%s: Start --F / Total --F / Adv ", _label), "--F", text_default_color
  end
  local _total_str = "--"
  if _stats.total then
    _total_str = string.format("%d", _stats.total)
  end
  local _prefix = string.format("%s: Start %dF / Total %sF / Adv ", _label, _stats.startup, _total_str)

  local _adv_str = "--F"
  local _adv_color = text_default_color
  if _stats.advantage then
    local _sign = _stats.advantage >= 0 and "+" or ""
    _adv_str = string.format("%s%dF", _sign, _stats.advantage)
    if _stats.advantage > 0 then
      _adv_color = frame_table_advantage_colors.positive
    elseif _stats.advantage < 0 then
      _adv_color = frame_table_advantage_colors.negative
    else
      _adv_color = frame_table_advantage_colors.zero
    end
  end

  return _prefix, _adv_str, _adv_color
end

local FRAME_TABLE_PARRY_HISTORY_MAX = 12
local frame_table_parry_field_map = { FP = "parry_forward", DP = "parry_down", AP = "parry_air" }
local frame_table_parry_types = { "FP", "DP", "AP" }

frame_table_parry_history = {
  p1 = { events = {}, prev_window = {}, prev_active = {} },
  p2 = { events = {}, prev_window = {}, prev_active = {} },
}
frame_table_prev_superfreeze = { [1] = 0, [2] = 0 }

function frame_table_update_parry_history()
  if not is_in_match then return end
  if not training_settings.display_frame_table then return end

  if training_settings.frame_table_sa_only then
    for _i = 1, 2 do
      local _p = player_objects[_i]
      if _p then
        local _freeze_now = _p.superfreeze_decount
        if frame_table_prev_superfreeze[_i] == 0 and _freeze_now > 0 then
          frame_table_parry_history.p1.events = {}
          frame_table_parry_history.p2.events = {}
        end
        frame_table_prev_superfreeze[_i] = _freeze_now
      end
    end
  end

  for _, _key in ipairs({ "p1", "p2" }) do
    local _idx = (_key == "p1") and 1 or 2
    local _d = player_objects[_idx]
    if _d then
      if not training_settings.frame_table_sa_only and _d.is_idle and (_d.idle_time or 0) > 20 then
        frame_table_parry_history[_key].events = {}
      end

      -- capture once per resolved window, keyed on last_validity_start_frame
      -- (not on delta's nil -> non-nil edge): when a parry lands with exactly
      -- 0-frame precision, read_parry_state's window-open reset (delta -> nil)
      -- and its success resolution (delta -> the resolved value) happen in the
      -- same frame, so a nil/non-nil poll once per frame never observes the
      -- transient nil and silently drops the event. last_validity_start_frame
      -- changes on every new window regardless of how fast it resolves, so
      -- comparing it against the last-captured window is the precise signal
      -- for "this type just resolved a new window."
      for _, _label in ipairs(frame_table_parry_types) do
        local _po = _d[frame_table_parry_field_map[_label]]
        if _po then
          if _po.delta ~= nil and _po.last_validity_start_frame ~= frame_table_parry_history[_key].prev_window[_label] then
            table.insert(frame_table_parry_history[_key].events, { label = _label, delta = _po.delta, success = _po.success, frame = frame_number, window_start_frame = _po.last_validity_start_frame })
            while #frame_table_parry_history[_key].events > FRAME_TABLE_PARRY_HISTORY_MAX do
              table.remove(frame_table_parry_history[_key].events, 1)
            end
            frame_table_parry_history[_key].prev_window[_label] = _po.last_validity_start_frame
            -- a miss freezes both sides where they are (see frame_table_sa_episode_frozen)
            -- instead of continuing to fill with mostly-neutral padding until the
            -- episode settles on its own
            if training_settings.frame_table_sa_only and not _po.success then
              frame_table_sa_episode_frozen = true
              frame_table_players.p1.armed = false
              frame_table_players.p2.armed = false
            end
          end

          -- track the true close of this type's validity window (purple box end)
          -- separately from delta resolution: the window may stay active several
          -- frames after delta/success is already known, so this patches the
          -- real close frame onto the matching event once it actually happens
          local _active_now = _po.validity_time > 0
          if frame_table_parry_history[_key].prev_active[_label] and not _active_now then
            local _events = frame_table_parry_history[_key].events
            for i = #_events, 1, -1 do
              if _events[i].label == _label and _events[i].window_end_frame == nil then
                _events[i].window_end_frame = frame_number
                break
              end
            end
          end
          frame_table_parry_history[_key].prev_active[_label] = _active_now

        end
      end

    end
  end
end

-- searches an input_history array backward for the closest entry at or before
-- _before_or_at_frame whose direction matches one of _target_directions;
-- deliberately keeps scanning past non-matching entries (e.g. a neutral entry
-- sitting between the real tap and the resolution frame) instead of stopping
-- at the first one, so it can find a tap that already ended before the
-- resolution frame
local function find_recent_direction_entry(_history, _target_directions, _before_or_at_frame)
  for i = #_history, 1, -1 do
    if _history[i].frame <= _before_or_at_frame then
      for _, _dv in ipairs(_target_directions) do
        if _history[i].direction == _dv then
          return i
        end
      end
    end
  end
  return nil
end

-- one white-bordered column per resolved parry-gauge event (success), or a
-- yellow-bordered one for a miss — purely a record of what actually happened,
-- no predictive/forward-looking marker.
-- each candidate absolute frame is mapped against the CURRENT generation's
-- start_frame first; if it no longer fits there (it's already scrolled into
-- the dimmed prev-generation layer after a continuation re-arm), it's mapped
-- against prev_start_frame instead — otherwise a marker drawn while its event
-- was still "current" would just vanish the instant a re-arm happens, since
-- the dimmed layer was never checked for it at all
local function frame_table_predicted_columns(_key, _p)
  local _cols = {}
  local _events = frame_table_parry_history[_key].events
  local _n = #_events
  local _idx = (_key == "p1") and 1 or 2

  local function _mark(_frame, _color)
    local _col = _frame - _p.start_frame + 1
    if _col >= 1 and _col <= FRAME_TABLE_LENGTH then
      _cols[_col] = _color
      return
    end
    if _p.prev_start_frame then
      local _prev_col = _frame - _p.prev_start_frame + 1
      if _prev_col >= 1 and _prev_col <= FRAME_TABLE_LENGTH then
        _cols[_prev_col] = _color
      end
    end
  end

  for i = 1, _n do
    local _e = _events[i]
    if _e.success then
      local _target_directions = (_e.label == "DP") and { 2 } or { 6, 4 }
      local _history = input_history[_idx]
      local _found = _history and find_recent_direction_entry(_history, _target_directions, _e.frame)
      if _found then
        local _start = _history[_found].frame
        local _end = (_found < #_history) and (_history[_found + 1].frame - 1) or frame_number
        for _f = _start, _end do
          if _f ~= _e.frame then
            _mark(_f, { border = 0xFFFFFFFF })
          end
        end
      end
      -- always mark the resolution frame itself solid, regardless of whether a
      -- matching hold span was found or where it landed — the hollow span is
      -- bonus context, never a precondition for the guaranteed solid marker
      _mark(_e.frame, { fill = 0xFFFFFFFF, border = 0xFFFFFFFF })
    else
      _mark(_e.frame, { fill = frame_table_colors.hitstun, border = frame_table_colors.hitstun })
    end
  end
  if next(_cols) == nil then return nil end
  return _cols
end

-- draws a hollow "rhythm target zone" for every consecutive event pair where
-- the earlier event was a success: after a successful parry, the game's fixed
-- 16F hitstop freeze means the next successful parry's resolution frame can
-- never land less than 17 frames later, so [prev.frame+1, prev.frame+17] is
-- exactly where the next success is expected to land if the player repeats
-- the same rhythm. Drawn unconditionally (not just when the actual next
-- event lands inside it) so Peter can visually compare actual vs expected.
frame_table_rhythm_target_color = 0xFF8800FF -- bright orange, distinct from projectile's muted 0xCC7722FF and every other frame_table_colors entry

-- base parry freeze (16F) + 1F resolution = the minimum possible gap between
-- two consecutive successful parries. This constant is only correct for
-- Super Art hits (+0 additional freeze). TODO: light/medium/heavy normals add
-- +4/+3/+2 more (so 20/19/18 instead of 17) — not implemented yet, would need
-- each event to also record the attacking move's strength, which isn't
-- tracked today. Deliberately named/extracted here instead of left as an
-- inline "17" so that future light/medium/heavy support has one place to key
-- the lookup off, per event, instead of hunting down every hardcoded use.
FRAME_TABLE_SA_PARRY_TARGET_GAP = 17

function frame_table_draw_rhythm_target(_key, _p, _x, _y)
  local _events = frame_table_parry_history[_key].events
  local _block_width = 4
  for i = 2, #_events do
    if _events[i - 1].success then
      local _target_start_frame = _events[i - 1].frame + 1
      local _target_end_frame = _events[i - 1].frame + FRAME_TABLE_SA_PARRY_TARGET_GAP
      local _col_start = _target_start_frame - _p.start_frame + 1
      local _col_end = _target_end_frame - _p.start_frame + 1
      if (_col_end < 1 or _col_start > FRAME_TABLE_LENGTH) and _p.prev_start_frame then
        -- doesn't overlap the current generation at all anymore (scrolled into
        -- the dimmed prev-generation layer after a continuation re-arm) — retry
        -- against prev_start_frame, same dual-layer fallback _mark() uses for
        -- single-frame markers
        _col_start = _target_start_frame - _p.prev_start_frame + 1
        _col_end = _target_end_frame - _p.prev_start_frame + 1
      end
      _col_start = math.max(_col_start, 1)
      _col_end = math.min(_col_end, FRAME_TABLE_LENGTH)
      if _col_start <= _col_end then
        local _bx1 = _x + (_col_start - 1) * _block_width
        local _bx2 = _x + _col_end * _block_width - 1
        gui.box(_bx1, _y - 1, _bx2, _y + 9, 0x00000000, frame_table_rhythm_target_color)
      end
    end
  end
end

function frame_table_draw_parry_history(_key, _x, _y)
  local _events = frame_table_parry_history[_key].events
  local _cx = _x
  local _last_label = nil
  local _last_end_frame = nil
  for _, _e in ipairs(_events) do
    if _last_end_frame then
      local _gap_token = tostring(_e.window_start_frame - _last_end_frame) .. " "
      gui.text(_cx, _y, _gap_token, frame_table_colors.neutral, text_default_border_color)
      _cx = _cx + get_text_width(_gap_token)
    end
    _last_end_frame = _e.window_end_frame or _e.frame

    local _sign_str = (_e.delta >= 0) and string.format("%d", -_e.delta) or string.format("+%d", -_e.delta)
    local _color = _e.success and frame_table_colors.parry or 0xE70000FF
    if _e.label ~= _last_label then
      local _label_token = _e.label .. " "
      gui.text(_cx, _y, _label_token, text_default_color, text_default_border_color)
      _cx = _cx + get_text_width(_label_token)
      _last_label = _e.label
    end
    local _num_token = _sign_str .. " "
    gui.text(_cx, _y, _num_token, _color, text_default_border_color)
    _cx = _cx + get_text_width(_num_token)
  end
end

frame_table_legend_order = { "neutral", "startup", "movement", "active", "recovery", "hitstun", "blocked", "projectile", "parry", "invincible" }
-- only one entry needed here even though classify() still tracks 3 distinct
-- parry_forward/down/air states internally — they all share one color now.
-- startup/active/recovery/projectile restored (2026-09-15) so melee-type SAs
-- (which show as those states, not just projectile-type SAs) aren't missing
-- from the legend
frame_table_legend_order_sa_only = { "neutral", "parry_forward", "startup", "active", "recovery", "projectile", "blocked", "hitstun" }
frame_table_legend_labels = {
  neutral    = "Neutral",
  startup    = "Startup",
  movement   = "Movement",
  active     = "Active",
  projectile = "Projectile",
  recovery   = "Recovery",
  hitstun    = "Hitstun",
  blocked    = "Blocked",
  parry      = "Parry",
  invincible = "Invincible",
  parry_forward = "Parry",
}

function frame_table_legend_display(_x, _y)
  local _order = training_settings.frame_table_sa_only and frame_table_legend_order_sa_only or frame_table_legend_order
  local _box_size = 6
  local _col_width = 50
  local _row_height = 10
  local _per_row = 3
  for i, _key in ipairs(_order) do
    local _col = (i - 1) % _per_row
    local _row = math.floor((i - 1) / _per_row)
    local _cx = _x + _col * _col_width
    local _cy = _y + _row * _row_height
    gui.box(_cx, _cy, _cx + _box_size, _cy + _box_size, frame_table_colors[_key], 0x00000000)
    gui.text(_cx + _box_size + 2, _cy - 1, frame_table_legend_labels[_key], text_disabled_color, text_default_border_color)
  end
end

function frame_table_display()
  local _block_width  = 4
  local _block_height = 8
  local _table_width  = FRAME_TABLE_LENGTH * _block_width
  local _x = 6

  local _y_text_top    = 163
  local _y_p1          = 172
  local _y_p2          = 182
  local _y_text_bottom = 192

  -- solid background panel behind the color blocks only (text area stays transparent)
  gui.box(_x - 4, _y_p1 - 2, _x + _table_width + 4, _y_p2 + _block_height + 2, 0x000000FF, 0x00000000)

  if training_settings.frame_table_sa_only then
    gui.text(_x, _y_text_top, "P1: ", text_default_color, text_default_border_color)
    frame_table_draw_parry_history("p1", _x + get_text_width("P1: "), _y_text_top)
  else
    local _p1_prefix, _p1_adv_str, _p1_adv_color = frame_table_stats_parts("p1")
    gui.text(_x, _y_text_top, _p1_prefix, text_default_color, text_default_border_color)
    gui.text(_x + get_text_width(_p1_prefix), _y_text_top, _p1_adv_str, _p1_adv_color, text_default_border_color)
  end

  local _p1_predicted_cols, _p2_predicted_cols = nil, nil
  if training_settings.frame_table_sa_only then
    _p1_predicted_cols = frame_table_predicted_columns("p1", frame_table_players.p1)
    _p2_predicted_cols = frame_table_predicted_columns("p2", frame_table_players.p2)
  end

  frame_table_draw_row(frame_table_players.p1.buffer, frame_table_players.p1.run_lengths,
    frame_table_players.p1.prev_buffer, frame_table_players.p1.prev_run_lengths, _x, _y_p1, _p1_predicted_cols)
  frame_table_draw_row(frame_table_players.p2.buffer, frame_table_players.p2.run_lengths,
    frame_table_players.p2.prev_buffer, frame_table_players.p2.prev_run_lengths, _x, _y_p2, _p2_predicted_cols)
  if training_settings.frame_table_sa_only then
    frame_table_draw_rhythm_target("p1", frame_table_players.p1, _x, _y_p1)
    frame_table_draw_rhythm_target("p2", frame_table_players.p2, _x, _y_p2)
  end

  if training_settings.frame_table_sa_only then
    gui.text(_x, _y_text_bottom, "P2: ", text_default_color, text_default_border_color)
    frame_table_draw_parry_history("p2", _x + get_text_width("P2: "), _y_text_bottom)
  else
    local _p2_prefix, _p2_adv_str, _p2_adv_color = frame_table_stats_parts("p2")
    gui.text(_x, _y_text_bottom, _p2_prefix, text_default_color, text_default_border_color)
    gui.text(_x + get_text_width(_p2_prefix), _y_text_bottom, _p2_adv_str, _p2_adv_color, text_default_border_color)
  end
end
