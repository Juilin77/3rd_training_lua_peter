-- src/control/pattern_replay.lua
-- pattern replay system: scan and replay pattern files

replay_output_path = "../replay-pattern-trainer/patterns/"

replay_import_state = {
  file_index = 1,
}
replay_import_char = "(not scanned)"
replay_import_files = { "empty" }
direct_play_pending = false
direct_play_inputs  = nil
direct_play_superfreeze = nil

-- positioning state machine (non-savestate patterns): teleport both players to the
-- recorded relative distance every frame until they settle, then queue the inputs
positioning_state = nil
positioning_timeout = 15
corner_offset_tolerance = 40

pattern_defense_tracking   = false
pattern_defense_init_life  = 0
pattern_defense_hits       = 0
pattern_defense_blocks     = 0
pattern_defense_parries    = 0
pattern_defense_thrown     = false
pattern_defense_result     = nil
pattern_defense_result_timer = 0

function pattern_defense_start()
  pattern_defense_tracking  = true
  pattern_defense_init_life = player_objects[1].life
  pattern_defense_hits      = 0
  pattern_defense_blocks    = 0
  pattern_defense_parries   = 0
  pattern_defense_thrown    = false
end

function pattern_replay_on_load_state()
  if direct_play_pending then
    direct_play_pending = false
    if direct_play_inputs then
      queue_input_sequence(player_objects[2], direct_play_inputs)
      pattern_defense_start()
      direct_play_inputs = nil
    end
  end
end

function scan_replay_files()
  local _char = player_objects[2].char_str or "unknown"
  replay_import_char = _char
  for i = #replay_import_files, 1, -1 do table.remove(replay_import_files, i) end
  local _win = string.gsub(replay_output_path .. _char .. "/", "/", "\\")
  local _f = io.popen('dir /b "' .. _win .. '*.json"')
  if _f then
    local _str = _f:read("*all")
    _f:close()
    for _line in string.gmatch(_str, "([^\r\n]+)") do
      if _line ~= "" and not string.find(_line, "%.inputs%.json$") then
        table.insert(replay_import_files, _line)
      end
    end
  end
  if #replay_import_files == 0 then table.insert(replay_import_files, "empty") end
  replay_import_state.file_index = 1
  _replay_file_item.name = string.format("Pattern (P2: %s)", string.upper(_char))
  print(string.format("[import] P2=%s  found %d patterns", _char, #replay_import_files))
end

function direct_play_pattern()
  local _file = replay_import_files[replay_import_state.file_index]
  if not _file or _file == "empty" then
    print("[direct play] no pattern selected") return
  end
  local _base = replay_output_path .. replay_import_char .. "/" .. string.gsub(_file, "%.json$", "")
  local _meta        = read_object_from_json_file(_base .. ".json")
  local _inputs_data = read_object_from_json_file(_base .. ".inputs.json")
  if not _meta or not _inputs_data then
    print("[direct play] failed to read " .. _base) return
  end
  local _owner_side = _meta.owner or "p2"
  local _inputs = _inputs_data[_owner_side]
  if not _inputs or #_inputs == 0 then
    print("[direct play] no inputs in pattern") return
  end
  direct_play_superfreeze = _meta.superfreeze
  local _fs_path = _base .. ".fs"
  local _fs_check = io.open(_fs_path, "r")
  if _fs_check then
    -- savestate path: positions come from the savestate, no positioning
    _fs_check:close()
    if _meta.start_pos then
      memory.writeword(player_objects[1].base + 0x64, bit.band(_meta.start_pos.p1.x, 0xFFFF))
      memory.writeword(player_objects[1].base + 0x68, bit.band(_meta.start_pos.p1.y, 0xFFFF))
      memory.writeword(player_objects[2].base + 0x64, bit.band(_meta.start_pos.p2.x, 0xFFFF))
      memory.writeword(player_objects[2].base + 0x68, bit.band(_meta.start_pos.p2.y, 0xFFFF))
    end
    direct_play_inputs  = _inputs
    direct_play_pending = true
    mission_replay_active = true
    savestate.load(savestate.create(_fs_path))
    print(string.format("[direct play] %s  char=%s  frames=%d  loading savestate...",
      _file, replay_import_char, #_inputs))
  else
    local _def_target_x, _atk_target_x = compute_positioning_targets(_meta)
    if _def_target_x then
      positioning_state = {
        def_target_x = _def_target_x,
        atk_target_x = _atk_target_x,
        time = 0,
        screen_x = memory.readwordsigned(adresses.global.screen_pos_x),
        screen_y = memory.readwordsigned(adresses.global.screen_pos_y),
        inputs = _inputs,
      }
      mission_replay_active = true
      print(string.format("[direct play] %s  char=%s  frames=%d  positioning P1=%d P2=%d",
        _file, replay_import_char, #_inputs, _def_target_x, _atk_target_x))
    else
      -- no start_pos in metadata: play in place
      queue_input_sequence(player_objects[2], _inputs)
      pattern_defense_start()
      mission_replay_active = true
      print(string.format("[direct play] %s  char=%s  frames=%d  (no savestate, close menu to start)",
        _file, replay_import_char, #_inputs))
    end
  end
end

-- compute target pos_x for both players from pattern metadata
-- the attack pattern is always replayed on P2 (attacker), P1 is the defender,
-- whichever side (_meta.owner) the attacker was on in the original match
function compute_positioning_targets(_meta)
  if not _meta.start_pos then return nil end
  local _def_obj = player_objects[1]
  local _atk_obj = player_objects[2]
  local _owner = _meta.owner or "p2"
  local _other = _owner == "p1" and "p2" or "p1"

  -- horizontal gap, attacker minus defender (rel_pos when present, else derived from absolute start_pos)
  local _gap_x
  if _meta.rel_pos then
    _gap_x = _meta.rel_pos.gap_x
  else
    _gap_x = _meta.start_pos[_owner].x - _meta.start_pos[_other].x
  end

  -- sign: +1 means attacker is on the right of the defender
  local _sign
  if _gap_x > 0 then
    _sign = 1
  elseif _gap_x < 0 then
    _sign = -1
  elseif _meta.rel_pos and _meta.rel_pos.atk_side then
    _sign = _meta.rel_pos.atk_side == 1 and -1 or 1
  else
    _sign = _atk_obj.pos_x >= _def_obj.pos_x and 1 or -1
  end

  -- gap beyond contact distance (0 when characters were pushbox to pushbox)
  local _contact_dist = get_contact_distance(_atk_obj.char_str, _def_obj.char_str)
  local _dummy_offset = math.abs(_gap_x) - _contact_dist
  if _dummy_offset < 0 then _dummy_offset = 0 end

  local _def_left, _def_right = get_stage_limits(current_stage, _def_obj.char_str)
  local _atk_left, _atk_right = get_stage_limits(current_stage, _atk_obj.char_str)

  local _def_target_x = math.min(math.max(_meta.start_pos[_other].x, _def_left), _def_right)
  local _atk_target_x = _def_target_x + _sign * (_contact_dist + _dummy_offset)

  -- corner overflow: clamp attacker to stage, drag defender along if the overflow is small
  local _diff = 0
  if _atk_target_x < _atk_left then
    _diff = _atk_left - _atk_target_x
    _atk_target_x = _atk_left
  elseif _atk_target_x > _atk_right then
    _diff = _atk_right - _atk_target_x
    _atk_target_x = _atk_right
  end
  if _diff ~= 0 and math.abs(_diff) <= corner_offset_tolerance then
    _def_target_x = _def_target_x + _diff
  end

  return _def_target_x, _atk_target_x
end

-- advance positioning: rewrite both positions and freeze the camera every frame,
-- queue the pattern inputs once both players have settled or timeout is reached
function update_pattern_positioning()
  if not positioning_state then return end
  if not is_in_match then
    positioning_state = nil
    return
  end
  local _s = positioning_state
  local _def = player_objects[1]
  local _atk = player_objects[2]

  -- freeze camera while teleporting
  memory.writeword(adresses.global.screen_pos_x, _s.screen_x)
  memory.writeword(adresses.global.screen_pos_y, _s.screen_y)

  -- defender is human controlled: exact match when grounded, velocity tolerance otherwise
  local _def_positioned = false
  if _def.posture == 0 or _def.posture == 0x20 then
    _def_positioned = _def.pos_x == math.floor(_s.def_target_x)
  else
    _def_positioned = math.abs(_s.def_target_x - _def.pos_x) <= math.abs(_def.velocity_x or 0) + 1
  end
  local _atk_positioned = _atk.pos_x == math.floor(_s.atk_target_x)
  local _has_moved = math.abs(_def.previous_pos_x - _def.pos_x) >= 3
    or math.abs(_atk.previous_pos_x - _atk.pos_x) >= 3

  write_pos_x(_def, _s.def_target_x)
  write_pos_x(_atk, _s.atk_target_x)

  if not _has_moved then
    _s.time = _s.time + 1
  end

  -- absolute cap: when targets overlap pushboxes (or a player holds a direction),
  -- physics moves someone every frame and the no-movement timeout alone never fires
  _s.total = (_s.total or 0) + 1

  if (_def_positioned and _atk_positioned) or _s.time >= positioning_timeout or _s.total >= 60 then
    queue_input_sequence(_atk, _s.inputs)
    pattern_defense_start()
    positioning_state = nil
  end
end

-- superfreeze sync: compensate input sequence timing when actual freeze length differs from recorded one
-- metadata offset is 0-based (relative to ctx_start), current_frame is 1-based, so offset k maps to current_frame k+1
function update_superfreeze_sync()
  local _obj = player_objects[2]  -- pattern input is always fed to P2
  if not direct_play_superfreeze or #direct_play_superfreeze == 0 then return end
  if _obj.pending_input_sequence == nil then return end
  if _obj.superfreeze_decount == nil or _obj.superfreeze_decount == 0 then return end
  local _expected_freeze = 0
  for _, _ev in ipairs(direct_play_superfreeze) do
    if _obj.pending_input_sequence.current_frame >= _ev.offset + 1 then
      _expected_freeze = _ev.remaining - (_obj.pending_input_sequence.current_frame - (_ev.offset + 1))
    end
  end
  if _expected_freeze > 0 then
    local _diff = _obj.remaining_freeze_frames - _expected_freeze
    if _diff ~= 0 then
      _obj.pending_input_sequence.current_frame = _obj.pending_input_sequence.current_frame - _diff
    end
  end
end

-- disable Pattern Replay Mode / Pattern Replay until Replay Import: Scan has found at least one pattern
function no_pattern_available()
  return replay_import_files[1] == "empty"
end

last_ordered_pattern_index = 0

function pick_random_pattern_index()
  if no_pattern_available() then return false end
  replay_import_state.file_index = math.random(#replay_import_files)
  return true
end

function pick_next_ordered_pattern_index()
  if no_pattern_available() then return false end
  last_ordered_pattern_index = (last_ordered_pattern_index % #replay_import_files) + 1
  replay_import_state.file_index = last_ordered_pattern_index
  return true
end

function update_pattern_replay_before_frame()
  update_pattern_positioning()

  if direct_play_superfreeze and player_objects[2].pending_input_sequence == nil and not direct_play_pending and not positioning_state then
    direct_play_superfreeze = nil
  end

  if pattern_defense_tracking then
    local _p1 = player_objects[1]
    if _p1.has_just_been_hit  then pattern_defense_hits    = pattern_defense_hits    + 1 end
    if _p1.has_just_blocked   then pattern_defense_blocks  = pattern_defense_blocks  + 1 end
    if _p1.has_just_parried   then pattern_defense_parries = pattern_defense_parries + 1 end
    if _p1.is_being_thrown    then pattern_defense_thrown  = true end
  end

  if pattern_replay_trigger then
    pattern_replay_trigger = false
    direct_play_pattern()
  end

  if training_settings.pattern_replay_on and not is_menu_open and is_in_match then
    if player_objects[2].pending_input_sequence == nil and not direct_play_pending and not positioning_state then
      if pattern_defense_tracking then
        pattern_defense_tracking = false
        local _dmg = pattern_defense_init_life - player_objects[1].life
        local _parts = {}
        if _dmg == 0 and not pattern_defense_thrown then
          if pattern_defense_parries > 0 then
            table.insert(_parts, string.format("PERFECT PARRY  Parried %d", pattern_defense_parries))
          elseif pattern_defense_blocks > 0 then
            table.insert(_parts, string.format("PERFECT BLOCK  Blocked %d", pattern_defense_blocks))
          else
            table.insert(_parts, "PERFECT BLOCK")
          end
        else
          if _dmg > 0 then table.insert(_parts, string.format("HIT  -%d HP", _dmg)) end
          if pattern_defense_thrown then table.insert(_parts, "THROWN") end
          if pattern_defense_parries > 0 then table.insert(_parts, string.format("Parried %d", pattern_defense_parries)) end
          if pattern_defense_blocks > 0 then table.insert(_parts, string.format("Blocked %d", pattern_defense_blocks)) end
        end
        pattern_defense_result = table.concat(_parts, "  ")
        pattern_defense_result_timer = 180
      end
      local _mode = training_settings.pattern_replay_mode
      if _mode == 1 then -- normal: play once then stop
        training_settings.pattern_replay_on = false
      elseif _mode == 2 then -- random
        if pick_random_pattern_index() then direct_play_pattern() else training_settings.pattern_replay_on = false end
      elseif _mode == 3 then -- ordered
        if pick_next_ordered_pattern_index() then direct_play_pattern() else training_settings.pattern_replay_on = false end
      else -- repeat
        direct_play_pattern()
      end
    end
  end
end

function pattern_defense_result_draw()
  if pattern_defense_result and pattern_defense_result_timer > 0 then
    pattern_defense_result_timer = pattern_defense_result_timer - 1
    local _color = 0xFF44FF44
    if string.find(pattern_defense_result, "HIT") or string.find(pattern_defense_result, "THROWN") then
      _color = 0xFFFF4444
    end
    local _w = get_text_width(pattern_defense_result)
    gui.text(math.floor((383 - _w) / 2), 30, pattern_defense_result, _color, text_default_border_color)
  end
end

function pattern_replay_invalidate_scan(_char_str)
  -- invalidate stale Pattern scan (cheap string reset, no io.popen)
  if replay_import_char ~= "(not scanned)" and replay_import_char ~= _char_str then
    replay_import_char = "(not scanned)"
    for i = #replay_import_files, 1, -1 do table.remove(replay_import_files, i) end
    table.insert(replay_import_files, "empty")
    replay_import_state.file_index = 1
    _replay_file_item.name = "Pattern (P2: ?)"
  end
end
