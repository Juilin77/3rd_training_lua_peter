-- src/settings.lua
-- training settings: load/save and recording slot backup/restore

function save_training_data()
  backup_recordings()
  if not write_object_to_json_file(training_settings, saved_path..training_settings_file) then
    print(string.format("Error: Failed to save training settings to \"%s\"", training_settings_file))
  end
end

function load_training_data()
  local _training_settings = read_object_from_json_file(saved_path..training_settings_file)
  if _training_settings == nil then
    _training_settings = {}
  end

  for _key, _value in pairs(_training_settings) do
    training_settings[_key] = _value
  end

  restore_recordings()
end

-- per-character recordings are cached in memory for the life of this script
-- session, keyed by char_str. restore_recordings() only hits disk the FIRST
-- time a character is seen this session; every later switch back to a
-- character already loaded just reuses the cached table instead of reading
-- again. This sidesteps an observed intermittent disk-read failure
-- (io.open returning nil for a file that demonstrably exists and is
-- correct — likely a transient working-directory issue during a savestate
-- load, not a corrupt/missing file) that otherwise silently masked a
-- correct recording every time a character switch happened to land on a
-- bad read, even with the read-failure guard below in place.
recordings_session_cache = recordings_session_cache or {}

function backup_recordings()
  if is_in_match and player_objects[2].char_str ~= "" then
    local _char = player_objects[2].char_str
    recordings_session_cache[_char] = recording_slots
    write_object_to_json_file(recording_slots, saved_recordings_path.._char..".json")
  end
end

function restore_recordings()
  local _char = player_objects[2].char_str
  if _char and _char ~= "" then
    if recordings_session_cache[_char] then
      recording_slots = recordings_session_cache[_char]
      return
    end
    -- char_str isn't guaranteed settled the instant this runs (e.g. right
    -- after a savestate load, before read_player_vars() has definitely
    -- re-read it) — if it's transiently wrong, saved_recordings_path.._char
    -- points at a file that doesn't exist for this session, and previously
    -- this blanked the in-memory recording_slots outright even though the
    -- real character's file on disk was untouched and fine. Only replace
    -- recording_slots when the read actually succeeds, so a bad/stale
    -- char_str just leaves the current data alone instead of wiping it.
    local _loaded = read_object_from_json_file(saved_recordings_path.._char..".json")
    if _loaded then
      local _recording_count = #recording_slots
      recording_slots = _loaded
      local _missing_slots = _recording_count - #recording_slots
      for _i = 1, _missing_slots do
        table.insert(recording_slots, make_recording_slot())
      end
      recordings_session_cache[_char] = recording_slots
    end
  end
end

function clamp_gauge_settings()
  if is_in_match then
    training_settings.p1_meter = math.min(training_settings.p1_meter, player_objects[1].max_meter_count * player_objects[1].max_meter_gauge)
    training_settings.p2_meter = math.min(training_settings.p2_meter, player_objects[2].max_meter_count * player_objects[2].max_meter_gauge)
    p1_meter_gauge_item.gauge_max = player_objects[1].max_meter_gauge * player_objects[1].max_meter_count
    p1_meter_gauge_item.subdivision_count = player_objects[1].max_meter_count
    p2_meter_gauge_item.gauge_max = player_objects[2].max_meter_gauge * player_objects[2].max_meter_count
    p2_meter_gauge_item.subdivision_count = player_objects[2].max_meter_count
    training_settings.p1_stun_reset_value = math.min(training_settings.p1_stun_reset_value, player_objects[1].stun_max)
    training_settings.p2_stun_reset_value = math.min(training_settings.p2_stun_reset_value, player_objects[2].stun_max)
    p1_stun_reset_value_gauge_item.gauge_max = player_objects[1].stun_max
    p2_stun_reset_value_gauge_item.gauge_max = player_objects[2].stun_max
  end
end
