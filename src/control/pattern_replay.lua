-- src/control/pattern_replay.lua
-- Pattern Replay 系統：掃描、回放 replay pattern 檔案

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
