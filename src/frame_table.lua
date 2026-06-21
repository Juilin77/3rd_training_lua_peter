FRAME_TABLE_LENGTH = 90 -- ~1.5s at 60fps

frame_table_colors = {
  neutral    = 0x444444FF, -- idle / empty
  startup    = 0x00FF00FF, -- startup (windup before hitbox)
  active     = 0xFF4040FF, -- active (hitbox active)
  projectile = 0xCC7722FF, -- projectile active (hitbox on projectile object)
  recovery   = 0x4080FFFF, -- recovery (busy after active)
  hitstun    = 0xFFFF00FF, -- hitstun/blockstun/knockdown/wakeup/thrown
  parry      = 0xCC33FFFF, -- parry success
  invincible = 0xFFFFFFFF, -- invincible
}

-- each player has its own independent capture: p1 and p2 arm/fill/freeze separately,
-- so a long sequence on one side doesn't restart the other side's display
frame_table_players = {
  p1 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil },
  p2 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil },
}
frame_table_stats = { p1 = nil, p2 = nil }
frame_table_has_been_active = { p1 = false, p2 = false }
frame_table_in_hitstun = { p1 = false, p2 = false }

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
  if _player_obj.has_just_parried then
    return "parry"
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

  if _player_obj.is_idle then
    frame_table_has_been_active[_player_key] = false
    frame_table_in_hitstun[_player_key] = false
    return "neutral"
  end

  -- unable to act due to damage / blockstun / knockdown / getting up / being thrown
  -- sticky for the whole knockdown/hitstun sequence, not just the trigger frame
  -- (also covers hitstop freeze frames right after being hit, before has_just_been_hit/is_wakingup fire)
  local _is_hitstun_event = _player_obj.is_blocking or _player_obj.has_just_been_hit or _player_obj.is_being_thrown or _player_obj.is_wakingup or _player_obj.is_fast_wakingup
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
  else
    _p.prev_buffer = nil
    _p.prev_run_lengths = nil
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
  for _, _key in ipairs({ "p1", "p2" }) do
    local _state = _states[_key]
    local _p = frame_table_players[_key]

    if not _p.armed then
      local _fresh_trigger = _state == "parry" or has_just_attacked(_objs[_key])
      local _continuation_trigger = _state == "startup" or _state == "active" or _state == "projectile" or _state == "hitstun"
      -- a true continuation means the just-frozen buffer's last slot was already
      -- in this same state (the action carried straight through frame 90);
      -- otherwise this is a brand-new action (e.g. a jump starting right after
      -- an unrelated capture froze) and shouldn't inherit its dimmed overlay
      local _is_true_continuation = _continuation_trigger and _p.buffer[FRAME_TABLE_LENGTH] == _state

      if _fresh_trigger or _continuation_trigger then
        frame_table_arm(_key, _is_true_continuation and not _fresh_trigger, _fresh_trigger and _objs[_key].has_animation_just_changed)

        if _fresh_trigger then
          local _other_key = (_key == "p1") and "p2" or "p1"
          if not frame_table_players[_other_key].armed then
            frame_table_arm(_other_key, false, false)
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
      end
    else
      frame_table_just_cancelled[_key] = false
    end
  end
end

function frame_table_reset()
  frame_table_players.p1 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil }
  frame_table_players.p2 = { buffer = {}, run_lengths = {}, armed = false, count = 0, start_frame = 0, prev_buffer = nil, prev_run_lengths = nil }
  frame_table_stats = { p1 = nil, p2 = nil }
  frame_table_has_been_active = { p1 = false, p2 = false }
  frame_table_in_hitstun = { p1 = false, p2 = false }
  frame_table_run_length = { p1 = 0, p2 = 0 }
  frame_table_prev_state = { p1 = nil, p2 = nil }
  frame_table_pending_adv = { p1 = nil, p2 = nil }
  frame_table_pending_stats = { p1 = nil, p2 = nil }
  frame_table_prev_animation = { p1 = nil, p2 = nil }
  frame_table_prev_action = { p1 = nil, p2 = nil }
  frame_table_just_cancelled = { p1 = false, p2 = false }
end

-- label the end of each non-neutral run within [_from, _to] with its (true,
-- possibly pre-capture) consecutive frame count from _run_lengths,
-- right-aligned to the last block of the run
local function frame_table_draw_run_labels(_buffer, _run_lengths, _from, _to, _x, _y, _text_color)
  local _block_width = 4
  local i = _from
  while i <= _to do
    local _state = _buffer[i] or "neutral"
    if _state == "neutral" then
      i = i + 1
    else
      local _end = i
      while _end + 1 <= _to and (_buffer[_end + 1] or "neutral") == _state do
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

function frame_table_draw_row(_buffer, _run_lengths, _prev_buffer, _prev_run_lengths, _x, _y)
  local _block_width  = 4
  local _block_height = 8
  for i = 1, FRAME_TABLE_LENGTH do
    local _state = _buffer[i]
    local _color
    if _state then
      _color = frame_table_colors[_state] or frame_table_colors.neutral
    elseif _prev_buffer and _prev_buffer[i] then
      _color = frame_table_dim_color(frame_table_colors[_prev_buffer[i]] or frame_table_colors.neutral)
    else
      _color = frame_table_colors.neutral
    end
    local _bx = _x + (i - 1) * _block_width
    gui.box(_bx, _y, _bx + _block_width - 1, _y + _block_height, _color, 0x00000000)
  end

  frame_table_draw_run_labels(_buffer, _run_lengths, 1, FRAME_TABLE_LENGTH, _x, _y, text_default_color)

  if _prev_buffer then
    frame_table_draw_run_labels(_prev_buffer, _prev_run_lengths, #_buffer + 1, FRAME_TABLE_LENGTH, _x, _y, text_disabled_color)
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

frame_table_legend_order = { "neutral", "startup", "active", "recovery", "hitstun", "projectile", "parry", "invincible" }
frame_table_legend_labels = {
  neutral    = "Neutral",
  startup    = "Startup",
  active     = "Active",
  projectile = "Projectile",
  recovery   = "Recovery",
  hitstun    = "Hitstun",
  parry      = "Parry",
  invincible = "Invincible",
}

function frame_table_legend_display(_x, _y)
  local _box_size = 6
  local _col_width = 50
  local _row_height = 10
  local _per_row = 3
  for i, _key in ipairs(frame_table_legend_order) do
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

  local _p1_prefix, _p1_adv_str, _p1_adv_color = frame_table_stats_parts("p1")
  gui.text(_x, _y_text_top, _p1_prefix, text_default_color, text_default_border_color)
  gui.text(_x + get_text_width(_p1_prefix), _y_text_top, _p1_adv_str, _p1_adv_color, text_default_border_color)

  frame_table_draw_row(frame_table_players.p1.buffer, frame_table_players.p1.run_lengths,
    frame_table_players.p1.prev_buffer, frame_table_players.p1.prev_run_lengths, _x, _y_p1)
  frame_table_draw_row(frame_table_players.p2.buffer, frame_table_players.p2.run_lengths,
    frame_table_players.p2.prev_buffer, frame_table_players.p2.prev_run_lengths, _x, _y_p2)

  local _p2_prefix, _p2_adv_str, _p2_adv_color = frame_table_stats_parts("p2")
  gui.text(_x, _y_text_bottom, _p2_prefix, text_default_color, text_default_border_color)
  gui.text(_x + get_text_width(_p2_prefix), _y_text_bottom, _p2_adv_str, _p2_adv_color, text_default_border_color)
end
