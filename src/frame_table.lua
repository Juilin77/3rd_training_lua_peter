FRAME_TABLE_LENGTH = 90 -- ~1.5s at 60fps

frame_table_colors = {
  neutral    = 0x444444FF, -- idle / empty
  startup    = 0x00FF00FF, -- 出招 (windup before hitbox)
  active     = 0xFF4040FF, -- 發生攻擊 (hitbox active)
  recovery   = 0x4080FFFF, -- 動作收回 (recovery / busy after active)
  hitstun    = 0xFFFF00FF, -- 因傷害/防禦/倒地而無法行動 (hitstun/blockstun/knockdown/wakeup/thrown)
  parry      = 0xCC33FFFF, -- 格擋(parry)瞬間
  invincible = 0xFFFFFFFF, -- 無敵時間
}

-- each player has its own independent capture: p1 and p2 arm/fill/freeze separately,
-- so a long sequence on one side doesn't restart the other side's display
frame_table_players = {
  p1 = { buffer = {}, armed = false, count = 0, start_frame = 0 },
  p2 = { buffer = {}, armed = false, count = 0, start_frame = 0 },
}
frame_table_stats = nil
frame_table_has_been_active = { p1 = false, p2 = false }
frame_table_in_hitstun = { p1 = false, p2 = false }

local function has_hitbox(_player_obj)
  for _, _box in ipairs(_player_obj.boxes) do
    if _box.type == "attack" or _box.type == "throw" then
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

local function find_first(_buffer, _value, _from)
  for i = _from, #_buffer do
    if _buffer[i] == _value then
      return i
    end
  end
  return nil
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

  if not has_vulnerability_box(_player_obj) then
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
function frame_table_update_stats(_attacker_key)
  local _attacker = frame_table_players[_attacker_key]
  local _defender_key = (_attacker_key == "p1") and "p2" or "p1"
  local _defender = frame_table_players[_defender_key]

  local _active_start = find_first(_attacker.buffer, "active", 1)
  if not _active_start then
    return -- this capture wasn't an attack, leave existing stats alone
  end

  local _active_end = _active_start
  for i = _active_start, #_attacker.buffer do
    if _attacker.buffer[i] == "active" then
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
    end
  end

  frame_table_stats = {
    startup   = _active_start - 1,
    total     = _total,
    advantage = _advantage,
  }
end

function frame_table_update(_player1_obj, _player2_obj)
  local _states = {
    p1 = frame_table_classify(_player1_obj, "p1"),
    p2 = frame_table_classify(_player2_obj, "p2"),
  }

  for _, _key in ipairs({ "p1", "p2" }) do
    local _state = _states[_key]
    local _p = frame_table_players[_key]

    if not _p.armed then
      -- only start a new capture when a fresh attack is actually beginning
      -- (don't let a knocked-down player's wakeup/hitstun restart their own display either)
      if _state == "startup" or _state == "active" or _state == "hitstun" or _state == "parry" then
        _p.armed = true
        _p.count = 0
        _p.buffer = {}
        _p.start_frame = frame_number
      end
    end

    if _p.armed then
      table.insert(_p.buffer, _state)
      _p.count = _p.count + 1

      if _p.count >= FRAME_TABLE_LENGTH then
        _p.armed = false
        frame_table_update_stats(_key)
      end
    end
  end
end

function frame_table_reset()
  frame_table_players.p1 = { buffer = {}, armed = false, count = 0, start_frame = 0 }
  frame_table_players.p2 = { buffer = {}, armed = false, count = 0, start_frame = 0 }
  frame_table_stats = nil
  frame_table_has_been_active = { p1 = false, p2 = false }
  frame_table_in_hitstun = { p1 = false, p2 = false }
end

function frame_table_draw_row(_buffer, _x, _y)
  local _block_width  = 3
  local _block_height = 4
  for i = 1, FRAME_TABLE_LENGTH do
    local _state = _buffer[i] or "neutral"
    local _color = frame_table_colors[_state] or frame_table_colors.neutral
    local _bx = _x + (i - 1) * _block_width
    gui.box(_bx, _y, _bx + _block_width - 1, _y + _block_height, _color, 0x00000000)
  end
end

function frame_table_stats_text()
  if not frame_table_stats then
    return "Start --F / Total --F / Adv --F"
  end
  local _total_str = "--"
  if frame_table_stats.total then
    _total_str = string.format("%d", frame_table_stats.total)
  end
  local _adv_str = "--"
  if frame_table_stats.advantage then
    local _sign = frame_table_stats.advantage >= 0 and "+" or ""
    _adv_str = string.format("%s%d", _sign, frame_table_stats.advantage)
  end
  return string.format("Start %dF / Total %sF / Adv %sF", frame_table_stats.startup, _total_str, _adv_str)
end

frame_table_legend_order = { "neutral", "startup", "active", "recovery", "hitstun", "parry", "invincible" }
frame_table_legend_labels = {
  neutral    = "Neutral",
  startup    = "Startup",
  active     = "Active",
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
  local _block_width  = 3
  local _table_width  = FRAME_TABLE_LENGTH * _block_width
  local _x = (screen_width - _table_width) / 2

  local _y_text_top    = 170
  local _y_p1          = 179
  local _y_p2          = 184
  local _y_text_bottom = 190

  -- solid background panel behind the color blocks only (text area stays transparent)
  gui.box(_x - 4, _y_p1 - 2, _x + _table_width + 4, _y_p2 + 6, 0x000000FF, 0x00000000)

  local _text = frame_table_stats_text()

  gui.text(_x, _y_text_top, _text, text_default_color, text_default_border_color)
  frame_table_draw_row(frame_table_players.p1.buffer, _x, _y_p1)
  frame_table_draw_row(frame_table_players.p2.buffer, _x, _y_p2)
  gui.text(_x, _y_text_bottom, _text, text_default_color, text_default_border_color)
end
