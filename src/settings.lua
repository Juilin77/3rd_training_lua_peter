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

-- holds a still-unconfirmed, non-pristine table for a character we've
-- switched AWAY from, so it survives a character switch instead of being
-- silently discarded (2026-10-19) — distinct from recordings_session_cache,
-- which means "confirmed against disk", not just "held in memory"
recording_slots_pending = recording_slots_pending or {}

-- tracks which characters already got the one-time conflict/skip prints
-- below, so they don't repeat on every single menu action the way the plain
-- "still unconfirmed" skip used to (2026-10-19, see both functions below)
recording_slots_conflict_warned = recording_slots_conflict_warned or {}
recording_slots_skip_warned = recording_slots_skip_warned or {}

-- true only if every slot still exactly matches make_recording_slot()'s
-- defaults — no recorded inputs AND no menu-edited delay/random_deviation/
-- weight. Used to tell a genuinely-still-blank scratch table (safe to
-- silently replace with a successful disk read) apart from one the user has
-- already started using while it was unconfirmed (never safe to silently
-- replace or overwrite either side of).
local function recording_slots_is_pristine(_slots)
  for _, _slot in ipairs(_slots) do
    if #_slot.inputs > 0 or _slot.delay ~= 0 or _slot.random_deviation ~= 0 or _slot.weight ~= 1 then
      return false
    end
  end
  return true
end

-- shared by restore_recordings()'s own successful load and backup_recordings()'s
-- retry below, so the slot-padding/caching logic exists exactly once
local function recording_slots_adopt_loaded(_char, _loaded)
  local _recording_count = #recording_slots
  recording_slots = _loaded
  local _missing_slots = _recording_count - #recording_slots
  for _i = 1, _missing_slots do
    table.insert(recording_slots, make_recording_slot())
  end
  recordings_session_cache[_char] = recording_slots
  recording_slots_char = _char
  recording_slots_conflict_warned[_char] = nil
  recording_slots_skip_warned[_char] = nil
end

function backup_recordings()
  if is_in_match and player_objects[2].char_str ~= "" then
    -- use recording_slots_char (who this table actually belongs to), not the
    -- current char_str directly — on_load_state() finalizes an in-progress
    -- recording (set_recording_state -> save_training_data -> here) BEFORE
    -- calling restore_recordings(), and by then gamestate_read() has already
    -- refreshed char_str to the POST-load character, which can differ from
    -- who was actually being recorded if the savestate swaps the dummy's
    -- character. Keying off recording_slots_char instead saves the finalized
    -- recording under its real owner regardless of what char_str has already
    -- moved on to. Falls back to char_str only if restore_recordings() has
    -- never run yet this session (recording_slots_char still nil).
    local _char = recording_slots_char or player_objects[2].char_str
    if not recordings_session_cache[_char] then
      -- recording_slots was never confirmed via a successful disk load this
      -- session for _char — it's either a genuinely-new-character scratch
      -- table or still-unresolved after a transient read failure (see
      -- restore_recordings() below), and the two are indistinguishable from
      -- the table alone. Try an opportunistic same-owner retry FIRST, before
      -- ever branching on pristine-ness — a confirmed-missing file (ENOENT)
      -- is safe to create regardless of whether the table is pristine, and
      -- checking pristine before this was a real bug: a brand-new
      -- character's very first recording would never save, forever,
      -- because it's non-pristine by the time anyone would notice.
      local _retry_loaded = read_object_from_json_file(saved_recordings_path.._char..".json")
      if _retry_loaded then
        if not recording_slots_is_pristine(recording_slots) then
          -- a real file exists on disk AND this session has real unsaved
          -- data for the same character — genuine conflict. Never silently
          -- pick a side: don't overwrite the file, don't discard the
          -- in-memory data either. This does NOT resolve itself by
          -- switching characters or reloading — switching away now stashes
          -- it (see the pending map above/restore_recordings() below), but
          -- a full script reload still loses anything not written to disk
          -- or a saved profile first.
          if not recording_slots_conflict_warned[_char] then
            print(string.format("[recordings] Conflict for \"%s\": this session has new recording data, and a different saved file was just found on disk. Keeping both as-is, not overwriting either — use Save Profile to snapshot this session's data to a separate file if you want to be sure it's not lost.", _char))
            recording_slots_conflict_warned[_char] = true
          end
          return
        end
        recording_slots_adopt_loaded(_char, _retry_loaded)
        print(string.format("[recordings] Recovered \"%s\" from disk (retried during backup).", _char))
        -- falls through to the normal cache+write below, now with real data
      else
        -- still unresolved — only permit creating _char's first-ever file
        -- when io.open itself confirms ENOENT (errno 2, "No such file or
        -- directory"); any other result (opened fine = a real file is
        -- already there, or a non-ENOENT failure = inconclusive/possibly
        -- transient) skips this backup rather than risk overwriting real
        -- saved data with an empty/unconfirmed table. This check does NOT
        -- depend on pristine-ness - a confirmed-missing file is always safe
        -- to create, pristine scratch or a real first recording alike.
        local _existing, _open_err, _open_code = io.open(saved_recordings_path.._char..".json", "r")
        if _existing then
          _existing:close()
          if not recording_slots_skip_warned[_char] then
            print(string.format("[recordings] Skipping backup for \"%s\": a file already exists and this table was never confirmed loaded this session.", _char))
            recording_slots_skip_warned[_char] = true
          end
          return
        elseif _open_code ~= 2 then
          if not recording_slots_skip_warned[_char] then
            print(string.format("[recordings] Skipping backup for \"%s\": could not confirm the file is missing (%s), not treating this as a new character.", _char, tostring(_open_err)))
            recording_slots_skip_warned[_char] = true
          end
          return
        end
        recording_slots_skip_warned[_char] = nil
      end
    end
    recordings_session_cache[_char] = recording_slots
    write_object_to_json_file(recording_slots, saved_recordings_path.._char..".json")
  end
end

function restore_recordings()
  local _char = player_objects[2].char_str
  if _char and _char ~= "" then
    if recording_slots_char and recording_slots_char ~= _char
       and not recordings_session_cache[recording_slots_char]
       and not recording_slots_is_pristine(recording_slots) then
      -- about to switch recording_slots away to a DIFFERENT character while
      -- the current one is still UNCONFIRMED (not in recordings_session_cache
      -- yet) and has real data in it - stash it instead of silently losing it
      -- to the fresh-table/cache-hit reassignment below. Resumed if the user
      -- switches back to recording_slots_char later (see the pending-map
      -- check next). The recordings_session_cache check matters: an already-
      -- confirmed character's normal, already-saved recordings are also
      -- "non-pristine" (that's just what real recordings look like) but
      -- they're already safe via the cache reference, so without this check
      -- every ordinary character switch would wrongly trigger this path.
      recording_slots_pending[recording_slots_char] = recording_slots
      print(string.format("[recordings] Holding unsaved recording data for \"%s\" in memory while switching to \"%s\" - resumes if you switch back. Does not survive a script reload.", recording_slots_char, _char))
    end

    if recording_slots_pending[_char] then
      -- resuming a table stashed above instead of re-reading disk, which
      -- would only show the OLD saved data, not this session's unsaved one
      recording_slots = recording_slots_pending[_char]
      recording_slots_pending[_char] = nil
      recording_slots_char = _char
      return
    end

    if recordings_session_cache[_char] then
      recording_slots = recordings_session_cache[_char]
      recording_slots_char = _char
      return
    end
    -- char_str isn't guaranteed settled the instant this runs (e.g. right
    -- after a savestate load, before read_player_vars() has definitely
    -- re-read it) — if it's transiently wrong, saved_recordings_path.._char
    -- points at a file that doesn't exist for this session, and previously
    -- this blanked the in-memory recording_slots outright even though the
    -- real character's file on disk was untouched and fine. recording_slots
    -- is now only left untouched (not replaced at all) when the read fails
    -- AND it's still the same not-yet-resolved character as last time
    -- (recording_slots_char already == _char, see below) — a read failure
    -- for a character recording_slots doesn't already claim to be DOES
    -- still replace it, just with a fresh/empty table rather than the real
    -- data, to avoid aliasing a different character's table (see below).
    local _loaded = read_object_from_json_file(saved_recordings_path.._char..".json")
    if _loaded then
      if recording_slots_char == _char and not recording_slots_is_pristine(recording_slots) then
        -- same conflict as backup_recordings() above, reached from a
        -- different path (e.g. a savestate load firing before a backup-side
        -- retry got the chance) — do not silently discard real in-memory
        -- data with this disk read either; defer and let whichever path
        -- resolves it first
        if not recording_slots_conflict_warned[_char] then
          print(string.format("[recordings] Conflict for \"%s\": this session has new recording data, and a different saved file was just found on disk. Keeping both as-is, not overwriting either — use Save Profile to snapshot this session's data to a separate file if you want to be sure it's not lost.", _char))
          recording_slots_conflict_warned[_char] = true
        end
        return
      end
      recording_slots_adopt_loaded(_char, _loaded)
    elseif recording_slots_char ~= _char then
      -- the read failed and recording_slots currently belongs to some OTHER
      -- character (or none yet this session, recording_slots_char == nil) —
      -- give this character its own fresh table instead of silently leaving
      -- recording_slots aliased to that other character's cached/on-disk
      -- table. Without this, any new recording made here mutates that other
      -- character's table in place (table assignment is by reference), and
      -- backup_recordings() then caches/saves the contaminated table under
      -- BOTH characters' names, corrupting both on disk. (The pending-map
      -- check above already protects the OLD character's dirty data before
      -- we get here, so this reassignment can't lose it anymore.)
      -- recording_slots_char is deliberately only updated here and on a
      -- successful load (never on the transient-glitch no-op path below) —
      -- this makes the fresh table "sticky" for this not-yet-resolved
      -- character: a one-frame char_str glitch still gets exactly one
      -- disposable scratch table, not a new one every retry, so anything
      -- recorded into it while still unresolved survives subsequent retries
      -- of the disk read (which keeps happening every call since nothing
      -- gets cached for _char here).
      recording_slots = {}
      for _i = 1, recording_slot_count do
        table.insert(recording_slots, make_recording_slot())
      end
      recording_slots_char = _char
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
