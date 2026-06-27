require("src/startup")

-- v0.22

print("-----------------------------")
print("  3rd_training.lua - "..script_version.."")
print("  Training mode for "..game_name.."")
print("  Last tested Fightcade version: "..fc_version.."")
print("  project url: https://github.com/Juilin77/3rd_training_lua_peter")
print("  Original work by: Grouflon (https://github.com/Grouflon/3rd_training_lua)")
print("  Modified by: Peter")
print("  License: MIT")
print("-----------------------------")
print("")
print("Command List:")
print("- Enter training menu by pressing \"Start\" while in game")
print("- Enter/exit recording mode by double tapping \"Coin\"")
print("- In recording mode, press \"Coin\" again to start/stop recording")
print("- In normal mode, press \"Coin\" to start/stop replay")
print("- Lua Hotkey 1 (alt+1) to return to character select screen")
print("- Lua Hotkey 5 (alt+5) to start/stop mission recording")
print("")

-- Kudos to indirect contributors:
-- *esn3s* for his work on 3s frame data : http://baston.esn3s.com/
-- *dammit* for his work on 3s hitbox display script : https://dammit.typepad.com/blog/2011/10/improved-3rd-strike-hitboxes.html
-- *furitiem* for his prior work on 3s C# training program : https://www.youtube.com/watch?v=vE27xe0QM64
-- *crytal_cube99* for his prior work on 3s training & trial scripts : https://ameblo.jp/3fv/

-- Thanks to *speedmccool25* for recording all the 4rd strike frame data
-- Thanks to *ProfessorAnon* for the Charge and Hyakuretsu Kyaku special training mode
-- Thanks to *sammygutierrez* for the damage info display

-- FBA-RR Scripting reference:
-- http://tasvideos.org/EmulatorResources/VBA/LuaScriptingFunctions.html
-- https://github.com/TASVideos/mame-rr/wiki/Lua-scripting-functions

-- Resources
-- https://github.com/Jesuszilla/mame-rr-scripts/blob/master/framedata.lua
-- https://imgur.com/gallery/0Tsl7di

-- Stuff
-- As far of selective stages, this one is Elena's Stage, write this: 0x020154F5,0x08
-- It would be also nice to show "alt+1 reset char select" on the top left corner in the character select screen
-- optional speed up

--[[
would it be possible to add a "first, second, third" action when getting hit?  So for example i divekick on opponent, first time they throw, second time they standing hk, third time they do another thing.
This isn't really possible with weighting but it can be extremely important for figuring out options after hitting specific choices your opponent makes at awkward timings.  So like block 1 = recording 1, block 2 = recording 2, block 3 = recording 3.
it'd need its own menu for setup that would be used just like the "recording" reaction option, but with 1-5 layers.  Possibly adding "random recording" as an option for the replay instead of a specific one as well
So like you do your first choice and want opponent to throw, but second time you want them to either throw, or do option 2 or 3  etc etc
And also having throw as an option there as well so you have one less option to record if you don't want a button action
]]--

-- Includes
require("src/tools")
require("src/memory_adresses")
require("src/draw")
require("src/display")
require("src/menu_widgets")
require("src/framedata")
require("src/gamestate")
require("src/input_history")
require("src/attack_data")
require("src/frame_advantage")
require("src/frame_table")
require("src/character_select")
recording_slot_count = 8

require("src/ui/menu")
require("src/settings")
require("src/control/dummy_control")
require("src/control/recording")
require("src/control/missions")
require("src/control/pattern_replay")
require("src/ui/special_training/parry_training")
require("src/ui/special_training/charge_training")
require("src/ui/special_training/hyakuretsu_training")
require("src/ui/special_training/juggle_training")
require("src/ui/special_training/tech_throw_training")
require("src/ui/special_training/720_trainer")
require("src/data/simulation")
require("src/prediction")

-- debug options
developer_mode = false -- Unlock frame data recording options. Touch at your own risk since you may use those options to fuck up some already recorded frame data
assert_enabled = developer_mode or assert_enabled
debug_wakeup = false
log_enabled = developer_mode or log_enabled
log_categories_display =
{
  input =                     { history = false, print = false },
  projectiles =               { history = false, print = false },
  fight =                     { history = false, print = false },
  animation =                 { history = false, print = false },
  parry_training_Forward =    { history = false, print = false },
  parry_training_Down =       { history = false, print = false },
  parry_training_Air =        { history = false, print = false },
  ["parry_training_Anti-Air"] = { history = false, print = false },
  blocking =                  { history = false, print = false },
  counter_attack =            { history = false, print = false },
  block_string =              { history = false, print = false },
  frame_advantage =           { history = false, print = false },
} or log_categories_display

saved_recordings_path = "saved/recordings/"
saved_missions_path = "saved/recording_missions/"
training_settings_file = "training_settings.json"

-- training settings
pose = {
  "Normal",
  "Crouching",
  "Forward Jump",
  "Neutral Jump",
  "Back Jump",
  "Super Fwd Jump",
  "Super Jump",
  "Super Back Jump",
  "Forward Dash",
  "Back Dash",
}

stick_gesture = {
  "none",
  "QCF",
  "QCB",
  "HCF",
  "HCB",
  "DPF",
  "DPB",
  "HCharge",
  "VCharge",
  "360",
  "DQCF",
  "720",
  "forward",
  "back",
  "down",
  "jump",
  "super jump",
  "forward jump",
  "forward super jump",
  "back jump",
  "back super jump",
  "back dash",
  "forward dash",
  "guard jump (See Readme)",
  --"guard back jump",
  --"guard forward jump",
  "Shun Goku Satsu", -- Gouki hidden SA1
  "Kongou Kokuretsu Zan", -- Gouki hidden SA2
}
if is_4rd_strike then
  table.insert(stick_gesture, "Demon Armageddon") -- Gouki SA3
end

button_gesture =
{
  "none",
  "recording",
  "LP",
  "MP",
  "HP",
  "EXP",
  "LK",
  "MK",
  "HK",
  "EXK",
  "LP+LK",
  "MP+MK",
  "HP+HK",
}

fast_wakeup_mode =
{
  "never",
  "always",
  "random",
}

blocking_style =
{
  "Off",
  "Block",
  "Parry",
  "Red Parry",
}

blocking_mode =
{
  "never",
  "always",
  "combo only",
  "random",
}

tech_throws_mode =
{
  "never",
  "always",
  "random",
}

hit_type =
{
  "normal",
  "low",
  "overhead",
}

life_mode =
{
  "no refill",
  "refill",
  "infinite"
}

meter_mode =
{
  "no refill",
  "refill",
  "infinite"
}

stun_mode =
{
  "normal",
  "no stun",
  "delayed reset"
}

standing_state =
{
  "knockeddown",
  "standing",
  "crouched",
  "airborne",
}

players = {
  "Player 1",
  "Player 2",
}

special_training_mode = {
  "None",
  "Parry",
  "Charge",
  "Hyakuretsu Kyaku (Chun Li)",
  "Juggle",
  "Tech Throw",
  "720",
}

juggle_disp = { jc = 0, air_time = 0, expired = false, was_airborne = false }
throw_tech_disp = {
  name = "TECH THROW",
  max_validity = 5,
  max_cooldown = 10,
  validity_time = 0,
  cooldown_time = 0,
  delta = nil,
  success = nil,
  armed = false,
  prev_being_thrown = false,
  grab_frame = 0,
  last_lplk_frame = -99,
  prev_lplk = false,
  pre_press_delta = nil,
  parry_at_grab = 0,
  frozen_x = nil,
  frozen_y = nil,
}

rot720_disp = {
  history = {},      -- {dir, frame} entries
  window = 11,       -- 11 frame window (confirmed from 3s-decomp)
  success_flash = 0,
  fail_reason = nil, -- "incomplete" or "time" or "wrong_button"
  fail_timer = 0,    -- counts down from 180 (3 seconds), clears fail_reason
  sequence = {},     -- 最多7個方向記錄，用於顯示
  last_button = nil, -- "LP"/"MP"/"HP"/"LK"/"MK"/"HK"
}

slot_replay_mode = {
  "normal",
  "random",
  "ordered",
  "repeat",
  "repeat random",
  "repeat ordered",
}

pattern_replay_mode_options = {
  "normal",
  "random",
  "ordered",
  "repeat",
}

-- POSE (moved to src/control/dummy_control.lua)

-- BLOCKING (moved to src/control/dummy_control.lua)

-- RECORDING POPUPS (moved to src/control/recording.lua)

-- REPLAY IMPORT (moved to src/control/pattern_replay.lua)

-- MISSION RECORDING

mission_recording_active = false
mission_recording_inputs = {p1 = {}, p2 = {}}
mission_recording_start_frame = 0
mission_recording_savestate_path = nil
mission_replay_active = false
mission_replay_pending = false
mission_replay_trigger = false
pattern_replay_trigger = false
mission_dummy_id = 2



-- GUI DECLARATION

training_settings = {
  pose = 1,
  blocking_style = 1,
  blocking_mode = 2,
  tech_throws_mode = 1,
  red_parry_hit_count = 1,
  counter_attack_stick = 1,
  counter_attack_button = 1,
  fast_wakeup_mode = 1,
  infinite_time = true,
  life_mode = 1,
  meter_mode = 1,
  p1_meter = 0,
  p2_meter = 0,
  infinite_sa_time = false,
  stun_mode = 1,
  p1_stun_reset_value = 0,
  p2_stun_reset_value = 0,
  stun_reset_delay = 20,
  display_input = true,
  display_gauges = false,
  display_p1_input_history = false,
  display_p1_input_history_dynamic = false,
  display_p2_input_history = false,
  display_attack_data = false,
  display_frame_advantage = false,
  display_frame_table = false,
  display_hitboxes = false,
  display_distances = false,
  mid_distance_height = 70,
  p1_distances_reference_point = 1,
  p2_distances_reference_point = 2,
  auto_crop_recording_start = true,
  auto_crop_recording_end = true,
  current_recording_slot = 1,
  current_mission_slot = 1,
  current_clear_mission_slot = 1,
  current_replay_mission_slot = 1,
  replay_mode = 1,
  music_volume = 10,
  life_refill_delay = 20,
  meter_refill_delay = 20,
  fast_forward_intro = true,
  recording_mission_mode = false,
  mission_play_side = 1,
  mission_replay_on = false,
  pattern_replay_on = false,
  pattern_replay_mode = 1, -- normal

  -- special training
  special_training_current_mode = 1,
  special_training_follow_character = true,
  special_training_parry_forward_on = true,
  special_training_parry_down_on = true,
  special_training_parry_air_on = true,
  special_training_parry_antiair_on = true,
  special_training_charge_overcharge_on = false,
}

debug_settings = {
  show_predicted_hitbox = false,
  record_framedata = false,
  record_idle_framedata = false,
  record_wakeupdata = false,
  debug_character = "",
  debug_move = "",
}

create_main_menu()

-- RECORDING
swap_characters = false
-- 1: Default Mode, 2: Wait for recording, 3: Recording, 4: Replaying
current_recording_state = 1
last_ordered_recording_slot = 0
current_recording_last_idle_frame = -1
last_coin_input_frame = -1
-- RECORDING STATE MACHINE (moved to src/control/recording.lua)

-- PROGRAM

P1.debug_state_variables = false
P1.debug_freeze_frames = false
P1.debug_animation_frames = false
P1.debug_standing_state = false
P1.debug_wake_up = false

P2.debug_state_variables = false
P2.debug_freeze_frames = false
P2.debug_animation_frames = false
P2.debug_standing_state = false
P2.debug_wake_up = false

function on_load_state()
  local _saved_inputs = {}
  for i = 1, 2 do
    if player_objects[i] then
      _saved_inputs[i] = { down = player_objects[i].input.down, state_time = player_objects[i].input.state_time }
    end
  end
  reset_player_objects()
  for i = 1, 2 do
    if _saved_inputs[i] then
      player_objects[i].input.down = _saved_inputs[i].down
      player_objects[i].input.state_time = _saved_inputs[i].state_time
    end
  end
  attack_data_reset()
  frame_advantage_reset()

  gamestate_read()

  restore_recordings()

  if mission_replay_pending then
    mission_replay_pending = false
    mission_replay_queue_inputs()
  end

  if direct_play_pending then
    direct_play_pending = false
    if direct_play_inputs then
      queue_input_sequence(player_objects[2], direct_play_inputs)
      pattern_defense_start()
      direct_play_inputs = nil
    end
  end

  -- reset recording states in a useful way
  if current_recording_state == 3 then
    set_recording_state({}, 2)
  elseif current_recording_state == 4 and (training_settings.replay_mode == 4 or training_settings.replay_mode == 5 or training_settings.replay_mode == 6) then
    set_recording_state({}, 1)
    set_recording_state({}, 4)
  end

  clear_input_history()
  clear_printed_geometry()
  emu.speedmode("normal")
end

function on_start()
  load_training_data()
  load_frame_data()
  load_missions_from_files()
  emu.speedmode("normal")

  if not developer_mode and not training_settings.recording_mission_mode then
    start_character_select_sequence()
  end
end

function hotkey1()
  set_recording_state({}, 1)
  start_character_select_sequence()
end

function hotkey2()
  if character_select_sequence_state ~= 0 then
    select_gill()
  end
end

function hotkey3()
  if character_select_sequence_state ~= 0 then
    select_shingouki()
  end
end

function hotkey5()
  if not mission_recording_active then
    mission_recording_active = true
    mission_recording_inputs = {p1 = {}, p2 = {}}
    mission_recording_start_frame = frame_number
    local _slot_index = training_settings.current_mission_slot
    mission_recording_savestate_path = string.format("%smission_slot_%d.fs", saved_missions_path, _slot_index)
    savestate.save(savestate.create(mission_recording_savestate_path))
  else
    mission_recording_active = false
    local _end_frame = frame_number
    local _name = string.format("mission_%d-%d", mission_recording_start_frame, _end_frame)
    local _slot_index = training_settings.current_mission_slot
    mission_slots[_slot_index].name = _name
    mission_slots[_slot_index].inputs = mission_recording_inputs
    mission_slots[_slot_index].savestate_path = mission_recording_savestate_path
    save_mission_to_file(_slot_index)
    refresh_mission_recording_slots_names()
    for _i = 1, mission_slot_count do
      local _next = (_slot_index - 1 + _i) % mission_slot_count + 1
      if mission_slots[_next].name == "none" then
        training_settings.current_mission_slot = _next
        break
      end
    end
  end
end

input.registerhotkey(1, hotkey1)
if rom_name == "sfiii3nr1" then
  input.registerhotkey(2, hotkey2)
  input.registerhotkey(3, hotkey3)
end
input.registerhotkey(5, hotkey5)

function before_frame()

  is_fightcade_replay = emu.isreplay and emu.isreplay() or false

  -- update debug menu
  if debug_settings.debug_character ~= debug_move_menu_item.map_property then
    debug_move_menu_item.map_object = frame_data
    debug_move_menu_item.map_property = debug_settings.debug_character
    debug_settings.debug_move = ""
  end

  slot_weight_item.object = recording_slots[training_settings.current_recording_slot]
  counter_attack_delay_item.object = recording_slots[training_settings.current_recording_slot]
  counter_attack_random_deviation_item.object = recording_slots[training_settings.current_recording_slot]

  draw_read()

  -- gamestate
  local _previous_dummy_char_str = player_objects[2].char_str or ""
  gamestate_read()

  -- load recordings according to P2 character
  if _previous_dummy_char_str ~= player_objects[2].char_str then
    restore_recordings()
    -- invalidate stale Pattern scan (cheap string reset, no io.popen)
    if replay_import_char ~= "(not scanned)" and replay_import_char ~= player_objects[2].char_str then
      replay_import_char = "(not scanned)"
      for i = #replay_import_files, 1, -1 do table.remove(replay_import_files, i) end
      table.insert(replay_import_files, "empty")
      replay_import_state.file_index = 1
      _replay_file_item.name = "Pattern (P2: ?)"
    end
  end

  -- cap training settings
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

  local _write_game_vars_settings =
  {
    freeze = is_menu_open,
    infinite_time = not training_settings.recording_mission_mode and training_settings.infinite_time,
    music_volume = training_settings.music_volume,
  }
  write_game_vars(_write_game_vars_settings)

  if not training_settings.recording_mission_mode then
    write_player_vars(player_objects[1])
    write_player_vars(player_objects[2])
  end

  -- input
  local _input = joypad.get()
  local _mission_swap = training_settings.mission_replay_on and training_settings.mission_play_side == 2
  if is_in_match and not is_menu_open and (swap_characters or _mission_swap) then
    swap_inputs(_input)
  end

  if not swap_characters then
    player = player_objects[1]
    dummy = player_objects[2]
  else
    player = player_objects[2]
    dummy = player_objects[1]
  end

  -- attack data
  attack_data_update(player, dummy)

  -- frame advantage
  frame_advantage_update(player, dummy)

  -- frame table
  frame_table_update(player_objects[1], player_objects[2])

  if replay_mission_item.is_disabled() then training_settings.mission_replay_on = false end
  if direct_play_item.is_disabled() then training_settings.pattern_replay_on = false end

  if not training_settings.recording_mission_mode and not training_settings.mission_replay_on then
    -- pose
    update_pose(_input, dummy, training_settings.pose)

    -- blocking
    update_blocking(_input, player, dummy, training_settings.blocking_mode, training_settings.blocking_style, training_settings.red_parry_hit_count)

    -- fast wake-up
    update_fast_wake_up(_input, player, dummy, training_settings.fast_wakeup_mode)

    -- tech throws
    update_tech_throws(_input, player, dummy, training_settings.tech_throws_mode)

    -- counter attack
    update_counter_attack(_input, player, dummy, training_settings.counter_attack_stick, training_settings.counter_attack_button)
  end

  -- recording
  update_recording(_input)
  update_mission_recording(_input)

  process_pending_input_sequence(player_objects[1], _input)
  process_pending_input_sequence(player_objects[2], _input)

  if mission_replay_trigger then
    mission_replay_trigger = false
    replay_current_mission()
  end

  if mission_replay_active and not mission_replay_pending and training_settings.mission_replay_on and not training_settings.recording_mission_mode and not is_menu_open and is_in_match then
    if player_objects[mission_dummy_id].pending_input_sequence == nil then
      replay_current_mission()
    end
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

  if is_in_match then
    input_history_update(input_history[1], "P1", _input)
    input_history_update(input_history[2], "P2", _input)
  else
    clear_input_history()
    attack_data_reset()
    frame_advantage_reset()
    frame_table_reset()
  end

  -- character select
  if not training_settings.recording_mission_mode then
    update_character_select(_input, training_settings.fast_forward_intro)
  end

  -- Log input
  if previous_input then
    function log_input(_player_object, _name, _short_name)
      _short_name = _short_name or _name
      local _full_name = _player_object.prefix.." ".._name
      if not previous_input[_full_name] and _input[_full_name] then
        log(_player_object.prefix, "input", _short_name.." 1")
      elseif previous_input[_full_name] and not _input[_full_name] then
        log(_player_object.prefix, "input", _short_name.." 0")
      end
    end

    for _i, _o in ipairs(player_objects) do
      log_input(_o, "Left")
      log_input(_o, "Right")
      log_input(_o, "Up")
      log_input(_o, "Down")
      log_input(_o, "Weak Punch", "LP")
      log_input(_o, "Medium Punch", "MP")
      log_input(_o, "Strong Punch", "HP")
      log_input(_o, "Weak Kick", "LK")
      log_input(_o, "Medium Kick", "MK")
      log_input(_o, "Strong Kick", "HK")
    end
  end
  previous_input = _input

  if not is_fightcade_replay then
    joypad.set(_input)
  end

  update_framedata_recording(player_objects[1], projectiles)
  update_idle_framedata_recording(player_objects[2])
  update_projectiles_recording(projectiles)
  update_wakeupdata_recording(player, dummy)

  local _debug_position_prediction = false
  if _debug_position_prediction and player.pos_y > 0 then
    local _px, _py = game_to_screen_space(player.pos_x, player.pos_y)
    print_point(_px, _py, 0x00FFFFFF)
    local _prediction = predict_object_position(player, 2)
    _px, _py = game_to_screen_space(_prediction[1], _prediction[2])
    print_point(_px, _py, 0xFF0000FF)
  end

  if _debug_position_prediction then
    for _id, _obj in pairs(projectiles) do
      if #_obj.pos_samples > 1 then
        local _x = _obj.pos_samples[#_obj.pos_samples].x - _obj.pos_samples[#_obj.pos_samples - 1].x
        local _y = _obj.pos_samples[#_obj.pos_samples].y - _obj.pos_samples[#_obj.pos_samples - 1].y
        print(string.format("x: %d, y: %d", _x, _y))
      end

      local _px, _py = game_to_screen_space(_obj.pos_x, _obj.pos_y)
      print_point(_px, _py, 0x00FFFFFF)

      local _movement = nil
      local _lifetime = _obj.lifetime
      local _emitter = player_objects[_obj.emitter_id]
      local _projectile_meta_data = _emitter and frame_data_meta[_emitter.char_str] and frame_data_meta[_emitter.char_str].projectiles and frame_data_meta[_emitter.char_str].projectiles[_obj.projectile_type] or nil
      if _projectile_meta_data ~= nil then
        _movement = _projectile_meta_data.movement
      end
      local _prediction = predict_object_position(_obj, 4, _movement, _lifetime)
      _px, _py = game_to_screen_space(_prediction[1], _prediction[2])
      print_point(_px, _py, 0xFF0000FF)
    end
  end

  log_update()
end

is_menu_open = false

function on_gui()

  if P1.input.pressed.start then
    clear_printed_geometry()
  end

  draw_character_select()

  if is_in_match then

    --[[
    -- Code to test frame advantage correctness by measuring the frame count between both players jump
    if (player_objects[1].last_jump_startup_frame ~= nil and player_objects[2].last_jump_startup_frame ~= nil) then
      gui.text(5, 5, string.format("jump difference: %d (startups: %d/%d)", player_objects[2].last_jump_startup_frame - player_objects[1].last_jump_startup_frame, player_objects[1].last_jump_startup_duration, player_objects[2].last_jump_startup_duration), text_default_color, text_default_border_color)
    end
    ]]

    display_draw_printed_geometry()

    if training_settings.display_gauges then
      display_draw_life(player_objects[1])
      display_draw_life(player_objects[2])
      display_draw_life_loss(player_objects[1])
      display_draw_life_loss(player_objects[2])

      display_draw_meter(player_objects[1])
      display_draw_meter(player_objects[2])

      display_draw_stun_gauge(player_objects[1])
      display_draw_stun_gauge(player_objects[2])

      display_draw_bonuses(player_objects[1])
      display_draw_bonuses(player_objects[2])
    end

    -- hitboxes
    if training_settings.display_hitboxes then
      display_draw_hitboxes()
    end

    -- distances
    if training_settings.display_distances then
      display_draw_distances(player_objects[1], player_objects[2], training_settings.mid_distance_height, training_settings.p1_distances_reference_point, training_settings.p2_distances_reference_point)
    end

    -- input history
    if training_settings.display_p1_input_history_dynamic and training_settings.display_p1_input_history then
      if player_objects[1].pos_x < 320 then
        input_history_draw(input_history[1], screen_width - 4, 49, true)
      else
        input_history_draw(input_history[1], 4, 49, false)
      end
    else
      if training_settings.display_p1_input_history then input_history_draw(input_history[1], 4, 49, false) end
      if training_settings.display_p2_input_history then input_history_draw(input_history[2], screen_width - 4, 49, true) end
    end

    -- controllers
    if training_settings.display_input then
      local _i = joypad.get()
      local _p1 = make_input_history_entry("P1", _i)
      local _p2 = make_input_history_entry("P2", _i)
      draw_controller_big(_p1, 44, 34)
      draw_controller_big(_p2, 310, 34)
    end

    -- attack data
    -- do not show if special training not following character is on, otherwise it will overlap
    -- exception: juggle and tech throw have fixed-position gauges at y=82, no overlap with damage info at y=49
    local _st_mode = special_training_mode[training_settings.special_training_current_mode]
    if training_settings.display_attack_data and (training_settings.special_training_current_mode == 1 or training_settings.special_training_follow_character or _st_mode == "Juggle" or _st_mode == "Tech Throw" or _st_mode == "720") then
      attack_data_display()
    end

    -- move advantage
    if training_settings.display_frame_advantage then
      frame_advantage_display()
    end

    -- frame table
    if training_settings.display_frame_table then
      frame_table_display()
    end

    -- debug
    --  predicted hitboxes
    if debug_settings.show_predicted_hitbox then
      local _predicted_hit = predict_hitboxes(player, 2)
      if _predicted_hit.frame_data then
        draw_hitboxes(_predicted_hit.pos_x, _predicted_hit.pos_y, player.flip_x, _predicted_hit.frame_data.boxes)
      end
    end

    --  move hitboxes
    local _debug_frame_data = frame_data[debug_settings.debug_character]
    if _debug_frame_data then
      local _debug_move = _debug_frame_data[debug_settings.debug_move]
      if _debug_move and _debug_move.frames then
        local _move_frame = frame_number % #_debug_move.frames

        local _debug_pos_x = player.pos_x
        local _debug_pos_y = player.pos_y
        local _debug_flip_x = player.flip_x

        local _sign = 1
        if _debug_flip_x ~= 0 then _sign = -1 end
        for i = 1, _move_frame + 1 do
          _debug_pos_x = _debug_pos_x + _debug_move.frames[i].movement[1] * _sign
          _debug_pos_y = _debug_pos_y + _debug_move.frames[i].movement[2]
        end

        draw_hitboxes(_debug_pos_x, _debug_pos_y, _debug_flip_x, _debug_move.frames[_move_frame + 1].boxes)
      end
    end
  end

  special_training_parry_draw()
  special_training_charge_draw()
  special_training_hyakuretsu_draw()
  special_training_juggle_draw()
  special_training_tech_throw_draw()
  special_training_720_draw()

  if is_in_match and current_recording_state ~= 1 then
    local _y = 5
    local _current_recording_size = 0
    if (recording_slots[training_settings.current_recording_slot].inputs) then
      _current_recording_size = #recording_slots[training_settings.current_recording_slot].inputs
    end

    if current_recording_state == 2 then
      local _text = string.format("%s: Wait for recording (%d)", recording_slots_names[training_settings.current_recording_slot], _current_recording_size)
      gui.text(250, _y, _text, text_default_color, text_default_border_color)
    elseif current_recording_state == 3 then
      local _text = string.format("%s: Recording... (%d)", recording_slots_names[training_settings.current_recording_slot], _current_recording_size)
      gui.text(274, _y, _text, text_default_color, text_default_border_color)
    elseif current_recording_state == 4 and dummy.pending_input_sequence and dummy.pending_input_sequence.sequence then
      local _text = ""
      local _x = 0
      if training_settings.replay_mode == 1 or training_settings.replay_mode == 4 then
        _x = 308
        _text = string.format("Playing (%d/%d)", dummy.pending_input_sequence.current_frame, #dummy.pending_input_sequence.sequence)
      else
        _x = 338
        _text = "Playing..."
      end
      gui.text(_x, _y, _text, text_default_color, text_default_border_color)
    end
  end

  if mission_recording_active then
    local _frame_count = #mission_recording_inputs.p1
    local _slot_index = training_settings.current_mission_slot
    local _text = string.format("Mission REC [slot %d] (%d)", _slot_index, _frame_count)
    gui.text(306, 8, _text, 0xFF4444FF, text_default_border_color)
  end

  if mission_replay_active then
    local _dummy = player_objects[mission_dummy_id]
    if _dummy and _dummy.pending_input_sequence then
      local _seq = _dummy.pending_input_sequence
      local _text = string.format("Replay (%d/%d)", _seq.current_frame, #_seq.sequence)
      gui.text(306, 8, _text, 0xFF44FF44, text_default_border_color)
    end
  end

  if pattern_defense_result and pattern_defense_result_timer > 0 then
    pattern_defense_result_timer = pattern_defense_result_timer - 1
    local _color = 0xFF44FF44
    if string.find(pattern_defense_result, "HIT") or string.find(pattern_defense_result, "THROWN") then
      _color = 0xFFFF4444
    end
    local _w = get_text_width(pattern_defense_result)
    gui.text(math.floor((383 - _w) / 2), 30, pattern_defense_result, _color, text_default_border_color)
  end

  if log_enabled then
    log_draw()
  end

  if is_in_match then
    local _should_toggle = P1.input.pressed.start
    if log_enabled then
      _should_toggle = P1.input.released.start
    end
    _should_toggle = not log_start_locked and _should_toggle

    if _should_toggle then
      is_menu_open = (not is_menu_open)
      if is_menu_open then
        menu_stack_push(main_menu)
        mission_replay_active = false
      else
        menu_stack_clear()
        if not training_settings.recording_mission_mode and training_settings.mission_replay_on then
          mission_replay_trigger = true
        end
        if training_settings.pattern_replay_on then
          pattern_replay_trigger = true
        end
      end
    end
  else
    is_menu_open = false
    menu_stack_clear()
  end

  if is_menu_open then
    local _horizontal_autofire_rate = 4
    local _vertical_autofire_rate = 4

    local _current_entry = menu_stack_top():current_entry()
    if _current_entry ~= nil and _current_entry.autofire_rate ~= nil then
      _horizontal_autofire_rate = _current_entry.autofire_rate
    end

    local _input =
    {
      down = check_input_down_autofire(player_objects[1], "down", _vertical_autofire_rate),
      up = check_input_down_autofire(player_objects[1], "up", _vertical_autofire_rate),
      left = check_input_down_autofire(player_objects[1], "left", _horizontal_autofire_rate),
      right = check_input_down_autofire(player_objects[1], "right", _horizontal_autofire_rate),
      validate = P1.input.pressed.LP,
      reset = P1.input.pressed.MP,
      cancel = P1.input.pressed.LK,
    }

    menu_stack_update(_input)

    menu_stack_draw()
  end

  gui.box(0,0,0,0,0,0) -- if we don't draw something, what we drawed from last frame won't be cleared
end

-- registers
emu.registerstart(on_start)
emu.registerbefore(before_frame)
gui.register(on_gui)
savestate.registerload(on_load_state)
