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
  if _meta.start_pos then
    memory.writeword(player_objects[1].base + 0x64, bit.band(_meta.start_pos.p1.x, 0xFFFF))
    memory.writeword(player_objects[1].base + 0x68, bit.band(_meta.start_pos.p1.y, 0xFFFF))
    memory.writeword(player_objects[2].base + 0x64, bit.band(_meta.start_pos.p2.x, 0xFFFF))
    memory.writeword(player_objects[2].base + 0x68, bit.band(_meta.start_pos.p2.y, 0xFFFF))
  end
  local _fs_path = _base .. ".fs"
  local _fs_check = io.open(_fs_path, "r")
  if _fs_check then
    _fs_check:close()
    direct_play_inputs  = _inputs
    direct_play_pending = true
    mission_replay_active = true
    savestate.load(savestate.create(_fs_path))
    print(string.format("[direct play] %s  char=%s  frames=%d  loading savestate...",
      _file, replay_import_char, #_inputs))
  else
    queue_input_sequence(player_objects[2], _inputs)
    pattern_defense_start()
    mission_replay_active = true
    print(string.format("[direct play] %s  char=%s  frames=%d  (no savestate, close menu to start)",
      _file, replay_import_char, #_inputs))
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
    if player_objects[2].pending_input_sequence == nil and not direct_play_pending then
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
