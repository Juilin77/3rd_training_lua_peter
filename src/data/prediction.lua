-- src/data/prediction.lua
-- Ported from effie3rd's prediction.lua for Peter's global-variable architecture
-- effie3rd source: _reference/effie3rd/3rd_training_lua-main/src/data/prediction.lua

local prediction = {}

-- ── Stubs for missing effie3rd modules ──────────────────────────────────────

-- Peter uses global frame_data, frame_data_meta instead of fd module
local fd = {}
fd.get_first_hit_frame = function(_char_str, _anim)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata or not _fdata.hit_frames then return nil end
  return _fdata.hit_frames[1]
end
fd.get_last_hit_frame = function(_char_str, _anim)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata or not _fdata.hit_frames then return nil end
  return _fdata.hit_frames[#_fdata.hit_frames]
end
fd.find_frame_data_by_name = function() return nil end
fd.get_boxes = function(_char_str, _anim, _frame)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata then return nil end
  return _fdata.boxes and _fdata.boxes[_frame] or nil
end

-- move_data not needed for blocking prediction
local move_data = {}
move_data.get_move_inputs_by_name = function() return nil end

-- SF3 stage boundaries (approximate pixel units)
local stage_boundaries = { left = -27648, right = 27648 }

-- debug stub
local _debug_on = false

-- ── Peter's globals used directly ───────────────────────────────────────────
-- frame_data, frame_data_meta, character_specific, next_animation,
-- frame_number, screen_x, screen_y, tools, Pools, copytable are all global

-- ── frame_data_meta access helper ───────────────────────────────────────────
-- effie3rd: frame_data_meta[char][anim_id]
-- Peter:    frame_data_meta[char].moves[anim_id]
local function get_fdm(_char_str, _anim_id)
  return frame_data_meta[_char_str] and frame_data_meta[_char_str].moves and frame_data_meta[_char_str].moves[_anim_id]
end

-- ── Core prediction functions (filled in by Agent B) ─────────────────────────
-- ── Batch 1: constants, predict_frames_branching, predict_frames_before_landing ─

local next_anim_types = { "next_anim", "optional_anim" }

local animations = {
   NONE = 1,
   WALK_FORWARD = 2,
   WALK_BACK = 3,
   WALK_TRANSITION = 4,
   STANDING_BEGIN = 5,
   CROUCHING_BEGIN = 6,
   BLOCK_HIGH_PROXIMITY = 7,
   BLOCK_HIGH = 8,
   BLOCK_HIGH_AIR_PROXIMITY = 9,
   BLOCK_HIGH_AIR = 10,
   BLOCK_LOW = 11,
   BLOCK_LOW_PROXIMITY = 12,
   PARRY_HIGH = 13,
   PARRY_LOW = 14,
   PARRY_AIR = 15,
}

local function predict_frames_branching(_obj, _anim, _frame, _frames_prediction, _specify_frame, _result)
   local _results = {}
   _result = _result or {}
   _frame = _frame or _obj.animation_frame
   local _fdata
   if _obj.type == "player" then
      _anim = _anim or _obj.animation
      _fdata = find_move_frame_data(_obj.char_str, _anim)
   else
      _anim = _anim or _obj.projectile_type
      _fdata = find_move_frame_data("projectiles", _anim)
   end
   if not _fdata then
      return _results
   end
   local _max_frames = _fdata.frames and #_fdata.frames or 1
   local _frame_to_check = math.min(_frame + 1, _max_frames)
   local _delta = 0
   if #_result > 0 then
      _delta = _result[#_result].delta
   end

   if _specify_frame then
      _delta = _delta + 1
      _frames_prediction = _frames_prediction - 1
      _result[#_result + 1] = { animation = _anim, frame = math.min(_frame, _max_frames - 1), delta = _delta }
   end

   local _used_loop = false
   local _used_next_anim = false

   for i = 1, _frames_prediction do
      if _fdata and _frame_to_check <= #_fdata.frames and _fdata.frames[_frame_to_check] then
         _used_loop = false
         _used_next_anim = false
         _delta = _delta + 1
         if _fdata.frames[_frame_to_check].loop then
            _used_loop = true
            _frame_to_check = _fdata.frames[_frame_to_check].loop + 1
         else
            for _, na in pairs(next_anim_types) do
               if _fdata.frames[_frame_to_check][na] then
                  if na == "next_anim" then
                     _used_next_anim = true
                  end
                  for __, next_anim in pairs(_fdata.frames[_frame_to_check][na]) do
                     local current_res = copytable(_result)
                     local next_anim_anim = next_anim[1]
                     local next_anim_frame = next_anim[2]
                     if next_anim_anim == "idle" then
                        local pfd = frame_data[_obj.char_str] or {}
                        if _obj.posture == 32 then
                           next_anim_anim = pfd.crouching or _obj.animation
                           next_anim_frame = 0
                        else
                           next_anim_anim = pfd.standing or _obj.animation
                           next_anim_frame = 0
                        end
                     end
                     current_res[#current_res + 1] = {
                        animation = next_anim_anim,
                        frame = next_anim_frame,
                        delta = _delta,
                     }
                     local subres = predict_frames_branching(
                        _obj,
                        next_anim_anim,
                        next_anim_frame,
                        _frames_prediction - i,
                        false,
                        current_res
                     )
                     for ___, sr in pairs(subres) do
                        _results[#_results + 1] = sr
                     end
                  end
               end
            end
         end
         if _used_next_anim then
            break
         else
            if not _used_loop then
               _frame_to_check = _frame_to_check + 1
               if _frame_to_check > #_fdata.frames then
                  break
               end
            end
            _result[#_result + 1] = { animation = _anim, frame = _frame_to_check - 1, delta = _delta }
         end
      end
   end

   if not _used_next_anim then
      _results[#_results + 1] = _result
   end

   return _results
end

local function predict_frames_before_landing(_player)
   if not _player.is_airborne then
      return 0
   end
   local _frames_prediction = 20
   local _y = _player.pos_y
   local _velocity = _player.velocity_y
   for i = 1, _frames_prediction do
      _y = _y + _velocity
      _velocity = _velocity + _player.acceleration_y
      if _player.animation_frame_data and _player.animation_frame_data.landing_height then
         if _y < _player.animation_frame_data.landing_height then
            return i
         end
      elseif _y < 0 then
         return i
      end
   end
   return -1
end

-- ── Batch 2: get_frames_until_idle, get_frame_advantage, check_switch_sides ──

local function get_frames_until_idle(_obj, _anim, _frame, _frames_prediction, _result, _depth)
   if _obj.is_idle then
      return 0
   end
   if _obj.remaining_freeze_frames == 0 and not _obj.freeze_just_ended then
      local recovery_time = _obj.recovery_time + _obj.additional_recovery_time
      if recovery_time > 0 then
         return recovery_time + 1
      end
   end

   _depth = _depth or 0
   local _results = {}
   _result = _result or 0
   _anim = _anim or _obj.animation
   _frame = _frame or _obj.animation_frame
   local _fdata = find_move_frame_data(_obj.char_str, _anim)

   local _delta = 0
   if _result then
      _delta = _result
   end

   local _used_loop = false
   local _used_next_anim = false

   if not _fdata then
      if _result == 0 then
         return _frames_prediction
      end
      return _delta, false
   end
   local _max_frames = _fdata.frames and #_fdata.frames or 1
   local _frame_to_check = math.min(_frame + 1, _max_frames)

   if _obj.is_airborne and _fdata.landing_anim then
      local _frames_until_landing = predict_frames_before_landing(_obj)
      local _adjustment = 0
      if _fdata.name == "uoh" and _obj.animation_connection_count > 0 then
         _adjustment = -1
      end
      if _obj.is_in_air_reel then
         _adjustment = 20
      end
      return _obj.remaining_freeze_frames
         + _frames_until_landing
         + get_frames_until_idle(_obj, _fdata.landing_anim, 0, _frames_prediction)
         + _adjustment
   end

   if _fdata.idle_frames then
      local diff = _delta
      for _, idle_frame in ipairs(_fdata.idle_frames) do
         if _frame <= idle_frame[1] then
            diff = idle_frame[1] - _frame
            break
         end
      end
      return _delta + diff, true
   else
      if _fdata.loops then
         for i = 1, #_fdata.loops do
            if _frame_to_check >= _fdata.loops[i][1] + 1 and _frame_to_check <= _fdata.loops[i][2] + 1 then
               break
            end
         end
      end
      for i = 1, _frames_prediction do
         if _fdata and _frame_to_check <= #_fdata.frames and _fdata.frames[_frame_to_check] then
            _used_loop = false
            _used_next_anim = false
            _delta = _delta + 1
            if _fdata.frames[_frame_to_check].loop then
               _used_loop = true
               _frame_to_check = _fdata.frames[_frame_to_check].loop + 1
            else
               for _, na in pairs(next_anim_types) do
                  if _fdata.frames[_frame_to_check][na] then
                     if na == "next_anim" then
                        _used_next_anim = true
                     end
                     for __, next_anim in pairs(_fdata.frames[_frame_to_check][na]) do
                        local next_anim_anim = next_anim[1]
                        local next_anim_frame = next_anim[2]
                        if next_anim_anim == "idle" then
                           return _delta, true
                        end
                        local subres, found = get_frames_until_idle(
                           _obj,
                           next_anim_anim,
                           next_anim_frame,
                           _frames_prediction - i,
                           _delta,
                           _depth + 1
                        )
                        if found then
                           _results[#_results + 1] = subres
                        end
                     end
                  end
               end
            end
            if _used_next_anim then
               break
            else
               if not _used_loop then
                  _frame_to_check = _frame_to_check + 1
                  if _frame_to_check > #_fdata.frames then
                     break
                  end
               end
               _result = _delta
            end
         end
      end
      if #_results == 0 then
         return _frames_prediction, false
      end
      local res = math.min(unpack(_results))
      if _depth == 0 then
         res = res + _obj.remaining_freeze_frames
      end
      return res, true
   end
end

local function get_frame_advantage(_player)
   if
      _player.has_just_connected
      or _player.other.has_just_connected
      or (_player.character_state_byte == 1 and (_player.freeze_just_ended or _player.remaining_freeze_frames > 0))
      or (
         _player.other.character_state_byte == 1
         and (_player.other.freeze_just_ended or _player.other.remaining_freeze_frames > 0)
      )
   then
      return
   end
   local _recovery_times = { 0, 0 }
   for _, p in ipairs({ _player, _player.other }) do
      _recovery_times[p.id] = get_frames_until_idle(p, nil, nil, 80)
   end
   return _recovery_times[_player.other.id] - _recovery_times[_player.id]
end

local function check_switch_sides(_player)
   local _previous_dist = math.floor(_player.other.previous_pos_x) - math.floor(_player.previous_pos_x)
   local _dist = math.floor(_player.other.pos_x) - math.floor(_player.pos_x)
   if tools.sign(_previous_dist) ~= tools.sign(_dist) and _dist ~= 0 then
      return true
   end
   return false
end

-- ── Batch 3: init_motion_data, create_line, update_player_animation, predict_next_animation, get_next_animation ──

local function init_motion_data(_obj)
   local _data = {
      pos_x = _obj.pos_x,
      pos_y = _obj.pos_y,
      flip_x = _obj.flip_x,
      velocity_x = _obj.velocity_x,
      velocity_y = _obj.velocity_y,
      acceleration_x = _obj.acceleration_x,
      acceleration_y = _obj.acceleration_y,
   }
   if _obj.type == "player" then
      _data.standing_state = _obj.standing_state
      if _obj.is_in_pushback then
         _data.pushback_start_index = frame_number - _obj.pushback_start_frame
      end
   end
   return { [0] = _data }
end

local function init_motion_data_zero(_obj)
   local _data = {
      pos_x = _obj.pos_x,
      pos_y = _obj.pos_y,
      flip_x = _obj.flip_x,
      velocity_x = 0,
      velocity_y = 0,
      acceleration_x = 0,
      acceleration_y = 0,
   }
   if _obj.type == "player" then
      _data.standing_state = _obj.standing_state
      if _obj.is_in_pushback then
         _data.pushback_start_index = frame_number - _obj.pushback_start_frame
      end
   end
   return { [0] = _data }
end

local function create_line(_obj, _n)
   local _line = {}
   for i = 1, _n do
      _line[#_line + 1] = { animation = _obj.animation or _obj.projectile_type, frame = _obj.animation_frame + i, delta = i }
   end
   return _line
end

local function update_player_animation(_previous_input, _player)
   if _player.has_animation_just_changed then
      next_animation[_player.id] = animations.NONE
   end
   if _player.has_just_blocked then
      local pfd = frame_data[_player.char_str] or {}
      local cspec = character_specific[_player.char_str] or {}
      local height_min = cspec.height and cspec.height.standing and cspec.height.standing.min or 0
      if not tools.is_pressing_down(_player, _previous_input) then
         if
            not _player.received_connection_is_projectile
            and _player.other.pos_y >= height_min - 56
         then
            next_animation[_player.id] = animations.BLOCK_HIGH_AIR
         else
            next_animation[_player.id] = animations.BLOCK_HIGH
         end
      else
         next_animation[_player.id] = animations.BLOCK_LOW
      end
   elseif _player.has_just_parried then
      if _player.parry_forward.success or _player.parry_antiair.success then
         next_animation[_player.id] = animations.PARRY_HIGH
      elseif _player.parry_down.success then
         next_animation[_player.id] = animations.PARRY_LOW
      elseif _player.parry_air.success then
         next_animation[_player.id] = animations.PARRY_AIR
      end
   end
   local _pfd = frame_data[_player.char_str] or {}
   if _player.animation == _pfd.parry_low and not tools.is_pressing_down(_player, _previous_input) then
      if _player.animation_frame == #_player.animation_frame_data.frames - 1 then
         next_animation[_player.id] = animations.STANDING_BEGIN
      end
   elseif _player.animation == _pfd.parry_high and tools.is_pressing_down(_player, _previous_input) then
      if _player.animation_frame == #_player.animation_frame_data.frames - 1 then
         next_animation[_player.id] = animations.CROUCHING_BEGIN
      end
   end
end

local function predict_next_animation(_player, _input)
   local _pfd = frame_data[_player.char_str] or {}
   local _cspec = character_specific[_player.char_str] or {}
   local _height_min = _cspec.height and _cspec.height.standing and _cspec.height.standing.min or 0
   local _animation = animations.NONE
   if _player.is_standing then
      if tools.is_pressing_down(_player, _input) then
         if _player.is_idle then
            _animation = animations.CROUCHING_BEGIN
         end
      elseif tools.is_pressing_forward(_player, _input) then
         if _player.action == 0 or _player.action == 23 or _player.action == 29 or _player.action == 30 then
            _animation = animations.WALK_FORWARD
         elseif _player.action == 3 then
            _animation = animations.WALK_TRANSITION
         end
      elseif tools.is_pressing_back(_player, _input) then
         if _player.is_idle then
            if
               _player.blocking
               and _player.blocking.last_block
               and _player.blocking.last_block.blocking_type == "player"
               and _player.pos_y >= _height_min - 56
            then
               _animation = animations.BLOCK_HIGH_AIR_PROXIMITY
            else
               _animation = animations.BLOCK_HIGH_PROXIMITY
            end
         end
      end
   elseif _player.is_crouching then
      if not tools.is_pressing_down(_player, _input) then
         if _player.is_idle then
            _animation = animations.STANDING_BEGIN
         end
      elseif tools.is_pressing_back(_player, _input) then
         if _player.is_idle then
            _animation = animations.BLOCK_LOW_PROXIMITY
         end
      end
   end
   local _recovery_time = _player.recovery_time + _player.additional_recovery_time
   if _recovery_time > 0 and _recovery_time <= 1 then
      if _player.animation == _pfd.block_low and not tools.is_pressing_down(_player, _input) then
         _animation = animations.STANDING_BEGIN
      elseif
         (_player.animation == _pfd.block_high or _player.animation == _pfd.block_high_air)
         and tools.is_pressing_down(_player, _input)
      then
         _animation = animations.CROUCHING_BEGIN
      end
   end
   return _animation
end

local function get_next_animation(_player, _animation)
   local _pfd = frame_data[_player.char_str] or {}
   if _animation == animations.WALK_FORWARD then
      return _pfd.walk_forward
   elseif _animation == animations.WALK_BACK then
      return _pfd.walk_back
   elseif _animation == animations.WALK_TRANSITION then
      return _pfd.walk_transition
   elseif _animation == animations.STANDING_BEGIN then
      return _pfd.standing_begin
   elseif _animation == animations.CROUCHING_BEGIN then
      return _pfd.crouching_begin
   elseif _animation == animations.BLOCK_HIGH_PROXIMITY then
      return _pfd.block_high_proximity
   elseif _animation == animations.BLOCK_HIGH then
      return _pfd.block_high
   elseif _animation == animations.BLOCK_HIGH_AIR_PROXIMITY then
      return _pfd.block_high_air_proximity
   elseif _animation == animations.BLOCK_HIGH_AIR then
      return _pfd.block_high_air
   elseif _animation == animations.BLOCK_LOW_PROXIMITY then
      return _pfd.block_low_proximity
   elseif _animation == animations.BLOCK_LOW then
      return _pfd.block_low
   elseif _animation == animations.PARRY_HIGH then
      return _pfd.parry_high
   elseif _animation == animations.PARRY_LOW then
      return _pfd.parry_low
   elseif _animation == animations.PARRY_AIR then
      return _pfd.parry_air
   else
      return _player.animation
   end
end

-- ── Batch 4: insert_projectile, box overlap helpers, update_before/after, update_frame_data ──

local function insert_projectile(_gs, _player, _projectile_data)
   local _proj_fdata = find_move_frame_data("projectiles", _projectile_data.type)
   if _proj_fdata then
      local obj = { base = 0, projectile = 99 }
      obj.id = _projectile_data.type .. "_" .. _player.id .. tostring(_gs.frame_number)
      obj.emitter_id = _player.id
      obj.alive = true
      obj.projectile_type = _projectile_data.type
      obj.projectile_start_type = obj.projectile_type
      obj.animation = obj.projectile_type
      obj.pos_x = _player.pos_x + _projectile_data.offset[1] * tools.flip_to_sign(_player.flip_x)
      obj.pos_y = _player.pos_y + _projectile_data.offset[2]
      obj.velocity_x = 0
      obj.velocity_y = 0
      obj.acceleration_x = 0
      obj.acceleration_y = 0
      if _proj_fdata.frames[1].velocity then
         obj.velocity_x = _proj_fdata.frames[1].velocity[1]
         obj.velocity_y = _proj_fdata.frames[1].velocity[2]
      end
      if _proj_fdata.frames[1].acceleration then
         obj.acceleration_x = _proj_fdata.frames[1].acceleration[1]
         obj.acceleration_y = _proj_fdata.frames[1].acceleration[2]
      end
      obj.flip_x = _player.flip_x
      obj.boxes = {}
      obj.expired = false
      obj.previous_remaining_hits = 99
      obj.remaining_hits = 99
      obj.is_forced_one_hit = false
      obj.has_activated = false
      obj.animation_start_frame = _gs.frame_number
      obj.animation_frame = 0
      obj.animation_freeze_frames = 0
      obj.remaining_freeze_frames = 0
      obj.remaining_lifetime = 0
      obj.lifetime = 0
      obj.cooldown = 0
      obj.is_placeholder = true
      _gs.projectiles[obj.id] = obj
   end
end

local function get_horizontal_box_overlap(_a_box, _ax, _ay, _a_flip, _b_box, _bx, _by, _b_flip)
   local _a_l, _b_l
   if _a_flip == 0 then
      _a_l = _ax + _a_box.left
   else
      _a_l = _ax - _a_box.left - _a_box.width
   end
   local _a_r = _a_l + _a_box.width
   local _a_b = _ay + _a_box.bottom
   local _a_t = _a_b + _a_box.height

   if _b_flip == 0 then
      _b_l = _bx + _b_box.left
   else
      _b_l = _bx - _b_box.left - _b_box.width
   end
   local _b_r = _b_l + _b_box.width
   local _b_b = _by + _b_box.bottom
   local _b_t = _b_b + _b_box.height

   if (_a_r >= _b_l) and (_a_l <= _b_r) and (_a_t >= _b_b) and (_a_b <= _b_t) then
      return math.min(_a_r, _b_r) - math.max(_a_l, _b_l)
   end
   return 0
end

local function get_push_value(_dist_from_pb_center, _pushbox_overlap_range, _push_value_max)
   local _p = _dist_from_pb_center / _pushbox_overlap_range
   if _p < 0.7 then
      local range = math.floor(0.7 * _pushbox_overlap_range)
      return tools.round((range - _dist_from_pb_center) / range * (_push_value_max - 6) + 6)
   elseif _p < 0.76 then
      return 4
   elseif _p < 0.82 then
      return 3
   elseif _p < 0.86 then
      return 2
   elseif _p < 0.98 then
      return 1
   end
   return 0
end

local function update_before(_previous_input, _dummy)
   local _player = _dummy.other
   update_player_animation(_previous_input, _player)
   update_player_animation(_previous_input, _dummy)
end

local function update_after(_input, _dummy)
   local _player = _dummy.other
   next_animation[_player.id] = predict_next_animation(_player, _input)
   next_animation[_dummy.id] = predict_next_animation(_dummy, _input)
end

local function update_frame_data(_gs, _obj, _frame_data_entry)
   _obj.animation = _frame_data_entry.animation
   if _obj.type == "projectile" then
      _obj.projectile_type = _frame_data_entry.animation
   end
   _obj.animation_frame = _frame_data_entry.frame
   if _frame_data_entry.frame_data then
      _obj.animation_frame_data = _frame_data_entry.frame_data
   else
      local new_fdata
      if _obj.type == "player" then
         new_fdata = frame_data[_obj.char_str] and frame_data[_obj.char_str][_obj.animation]
      else
         new_fdata = frame_data["projectiles"] and frame_data["projectiles"][_obj.animation]
      end
      _obj.animation_frame_data = new_fdata or _obj.animation_frame_data
   end
   _obj.boxes = _obj.animation_frame_data
         and _obj.animation_frame_data.frames
         and _obj.animation_frame_data.frames[_obj.animation_frame + 1]
         and _obj.animation_frame_data.frames[_obj.animation_frame + 1].boxes
      or _obj.boxes
   _obj.has_animation_just_changed = false
   if _obj.type == "player" and _gs.previous_gamestate and _obj.animation ~= _gs.previous_gamestate[_obj.prefix].animation then
      _obj.has_animation_just_changed = true
      _obj.current_hit_id = 0
      _obj.animation_action_count = 0
      _obj.animation_miss_count = 0
      _obj.animation_connection_count = 0
   end
end

-- ── Batch 5: local stubs, update_variables, update_turn ──────────────────────

-- stub: Peter's version doesn't expose this; return 0 as safe default
local function get_additional_recovery_delay() return 0 end

-- stub: simple side determination used by update_sides
local function get_side_local(_pos_x, _other_pos_x)
   return (_pos_x < _other_pos_x) and 1 or 2
end

local function update_variables(_gs)
   local _previous_gs = _gs.previous_gamestate
   _gs.frame_number = _gs.frame_number + 1
   for _, player in ipairs(_gs.player_objects) do
      player.previous_pos_x = _previous_gs and _previous_gs[player.prefix].pos_x or player.previous_pos_x
      player.previous_pos_y = _previous_gs and _previous_gs[player.prefix].pos_y or player.previous_pos_y
      player.previous_remaining_freeze_frames = player.remaining_freeze_frames or 0
      player.remaining_freeze_frames = math.max(player.remaining_freeze_frames - 1, 0)
      if _previous_gs and _previous_gs[player.prefix].just_received_connection then
         player.remaining_freeze_frames = player.other.remaining_freeze_frames
      end
      if player.freeze_just_ended and player.character_state_byte == 1 and player.recovery_time == 0 then
         player.recovery_time = 10
         if player.is_blocking then
            player.additional_recovery_time = get_additional_recovery_delay(player.char_str, player.is_crouching)
         end
         player.is_in_recovery = true
         player.is_in_pushback = true
         player.pushback_start_frame = _gs.frame_number
      end
      player.freeze_just_began = false
      player.freeze_just_ended = false
      if player.remaining_freeze_frames == 0 and player.previous_remaining_freeze_frames > 0 then
         player.freeze_just_ended = true
      end
      if player.remaining_freeze_frames > 0 then
         if player.previous_remaining_freeze_frames == 0 then
            player.freeze_just_began = true
         end
         player.animation_freeze_frames = player.animation_freeze_frames + 1
      end
      if player.ends_recovery_next_frame then
         player.has_just_ended_recovery = true
         player.character_state_byte = 0
         player.ends_recovery_next_frame = false
      end
      player.previous_recovery_time = player.recovery_time
      if player.recovery_time > 0 then
         player.recovery_time = player.recovery_time - 1
      end
      if player.recovery_time == 0 and player.previous_recovery_time > 0 then
         player.ends_recovery_next_frame = true
      end
      if
         player.freeze_just_began
         or (player.is_in_pushback and not player.freeze_just_ended and player.recovery_time == 0)
      then
         player.is_in_pushback = false
      end
      if player.freeze_just_ended and player.movement_type == 1 then
         player.pushback_start_frame = gs.frame_number
         player.is_in_pushback = true
      end
      if player.remaining_freeze_frames == 0 and not player.freeze_just_ended then
         player.cooldown = math.max(player.cooldown - 1, 0)
      end
      player.just_received_connection = false
      player.has_just_landed = false
   end

   local to_remove = Pools.small:alloc()
   for _, projectile in pairs(gs.projectiles) do
      projectile.lifetime = projectile.lifetime + 1
      projectile.previous_remaining_freeze_frames = projectile.remaining_freeze_frames
      projectile.remaining_freeze_frames = math.max(projectile.remaining_freeze_frames - 1, 0)
      projectile.freeze_just_began = false
      projectile.freeze_just_ended = false
      if projectile.remaining_freeze_frames > 0 then
         if projectile.previous_remaining_freeze_frames == 0 then
            projectile.freeze_just_began = true
         end
         projectile.animation_freeze_frames = projectile.animation_freeze_frames + 1
      end
      if projectile.remaining_freeze_frames == 0 and projectile.previous_remaining_freeze_frames > 0 then
         projectile.freeze_just_ended = true
      end
      if
         projectile.cooldown > 0
         and (
            (projectile.remaining_freeze_frames == 0 or projectile.freeze_just_began)
            or projectile.projectile_type == "72"
         )
      then
         projectile.cooldown = projectile.cooldown - 1
      end
      if projectile.is_placeholder and gs.frame_number > projectile.animation_start_frame then
         to_remove[#to_remove + 1] = projectile.id
      end
   end
   for _, key in ipairs(to_remove) do
      gs.projectiles[key] = nil
   end
end

local function update_turn(gs)
   local previous_gs = gs.previous_gamestate
   for _, player in ipairs(gs.player_objects) do
      if player.should_turn then
         if player.remaining_freeze_frames + player.recovery_time + player.additional_recovery_time == 0 then
            local pfd = frame_data[player.char_str] or {}
            player.flip_x = bit.bxor(previous_gs[player.prefix].flip_x, 1)
            local anim = previous_gs[player.prefix].animation
            local target_anim = nil
            if
               anim == pfd.standing
               or anim == pfd.walk_back
               or anim == pfd.block_high
            then
               target_anim = pfd.standing_turn
            elseif anim == pfd.crouching then
               target_anim = pfd.crouching_turn
            else
               player.should_turn = nil
            end
            if target_anim then
               local ufd = Pools.small:alloc()
               ufd.animation = target_anim
               ufd.frame = 0
               ufd.frame_data = find_move_frame_data(player.char_str, target_anim)
               update_frame_data(gs, player, ufd)
               if target_anim.velocity then
                  player.velocity_x = target_anim.velocity[1]
                  player.velocity_y = target_anim.velocity[2]
               end
               player.should_turn = nil
            end
         end
      end
   end
end

-- ── Batch 6: move_players, move_projectiles ───────────────────────────────────

local function move_players(gs)
   local stage = { left = stage_boundaries.left, right = stage_boundaries.right }

   for _, player in ipairs(gs.player_objects) do
      if player.remaining_freeze_frames == 0 and not player.freeze_just_ended then
         local cspec = character_specific[player.char_str] or {}
         local corner_left = stage.left + (cspec.corner_offset_left or 0)
         local corner_right = stage.right - (cspec.corner_offset_right or 0)
         local sign = tools.flip_to_sign(player.flip_x)

         if player.is_in_pushback then
            local pb_frame = gs.frame_number - player.pushback_start_frame
            local anim = player.last_received_connection_animation
            local hit_id = player.last_received_connection_hit_id
            local other_pfd = frame_data[player.other.char_str] or {}
            if
               anim and hit_id
               and other_pfd[anim]
               and other_pfd[anim].pushback
               and other_pfd[anim].pushback[hit_id]
               and pb_frame <= #other_pfd[anim].pushback[hit_id]
            then
               local pb_value = other_pfd[anim].pushback[hit_id][pb_frame]
               if pb_value then
                  local new_pos = player.pos_x - sign * pb_value
                  local over_push = 0
                  if new_pos < corner_left then
                     over_push = corner_left - new_pos
                  elseif new_pos > corner_right then
                     over_push = new_pos - corner_right
                  end
                  if over_push > 0 then
                     player.other.pos_x = player.other.pos_x + over_push * sign
                  end
                  player.pos_x = player.pos_x - (pb_value - over_push) * sign
               end
            end
         end

         local should_apply_velocity = false
         local current_frame = player.animation_frame_data
            and player.animation_frame_data.frames[player.animation_frame + 1]
         local first_frame_of_air_attack = player.animation_frame == 0
            and player.animation_frame_data
            and player.animation_frame_data.air
         local should_ignore_motion = current_frame and current_frame.ignore_motion

         if first_frame_of_air_attack then
            should_ignore_motion = true
         else
            if (player.animation_frame_data and player.animation_frame_data.uses_velocity) or player.is_airborne then
               should_apply_velocity = true
            end
         end

         if current_frame then
            if current_frame.clear_motion then
               player.velocity_x = 0
               player.velocity_y = 0
               player.acceleration_x = 0
               player.acceleration_y = 0
               should_apply_velocity = false
            end
            if not should_ignore_motion and should_apply_velocity then
               player.pos_x = player.pos_x + player.velocity_x * sign
               player.pos_y = player.pos_y + player.velocity_y
            end
            if current_frame.set_acceleration then
               player.acceleration_x = current_frame.set_acceleration[1]
               player.acceleration_y = current_frame.set_acceleration[2]
            end
            if current_frame.set_velocity then
               player.velocity_x = current_frame.set_velocity[1]
               player.velocity_y = current_frame.set_velocity[2]
            end
         end

         if not should_ignore_motion then
            player.velocity_x = player.velocity_x + player.acceleration_x
            player.velocity_y = player.velocity_y + player.acceleration_y
            if current_frame then
               if current_frame.movement then
                  player.pos_x = player.pos_x + current_frame.movement[1] * sign
                  player.pos_y = player.pos_y + current_frame.movement[2]
               end
               if current_frame.velocity then
                  player.velocity_x = player.velocity_x + current_frame.velocity[1]
                  player.velocity_y = player.velocity_y + current_frame.velocity[2]
               end
               if current_frame.acceleration then
                  player.acceleration_x = player.acceleration_x + current_frame.acceleration[1]
                  player.acceleration_y = player.acceleration_y + current_frame.acceleration[2]
               end
            end
         end

         if player.pos_x > corner_right then
            local mantissa = player.pos_x - math.floor(player.pos_x)
            player.pos_x = corner_right + mantissa
         elseif player.pos_x < corner_left then
            local mantissa = player.pos_x - math.floor(player.pos_x)
            player.pos_x = corner_left + mantissa
         end

         if player.animation_frame_data and player.pos_y < player.previous_pos_y then
            local should_land = false
            if player.animation_frame_data.landing_height then
               if player.pos_y < player.animation_frame_data.landing_height then
                  should_land = true
               end
            elseif player.pos_y < 0 then
               should_land = true
            end
            if should_land then
               player.pos_y = 0
               player.standing_state = 1
               player.has_just_landed = true
               player.is_airborne = false
               player.is_in_air_recovery = false
               player.is_in_air_reel = false
               local pfd = frame_data[player.char_str] or {}
               local landing_animation = (player.animation_frame_data and player.animation_frame_data.landing_anim)
                  or pfd.jump_recovery
                  or player.animation
               local ufd = Pools.small:alloc()
               ufd.animation = landing_animation
               ufd.frame = 0
               ufd.frame_data = find_move_frame_data(player.char_str, landing_animation)
               update_frame_data(gs, player, ufd)
            end
         end
      end
   end
   -- don't allow side switches if grounded
   for _, player in ipairs(gs.player_objects) do
      if player.pos_y == 0 and player.other.pos_y == 0 then
         if
            tools.sign(player.previous_pos_x - player.other.previous_pos_x)
            ~= tools.sign(player.pos_x - player.other.pos_x)
         then
            local sign = tools.sign(player.previous_pos_x - player.other.previous_pos_x)
            player.pos_x = player.other.pos_x + sign
         end
      end
   end
end

local function move_projectiles(gs)
   for _, projectile in pairs(gs.projectiles) do
      if projectile.remaining_freeze_frames == 0 then
         local ignore_flip = projectile.projectile_type == "00_tenguishi"
         local sign = ignore_flip and 1 or tools.flip_to_sign(projectile.flip_x)
         projectile.pos_x = projectile.pos_x + projectile.velocity_x * sign
         projectile.pos_y = projectile.pos_y + projectile.velocity_y
         if projectile.animation_frame_data then
            local current_frame = projectile.animation_frame_data.frames[projectile.animation_frame + 1]
            if current_frame then
               if current_frame.movement then
                  projectile.pos_x = projectile.pos_x + current_frame.movement[1] * sign
                  projectile.pos_y = projectile.pos_y + current_frame.movement[2]
               end
               if current_frame.velocity then
                  projectile.velocity_x = projectile.velocity_x + projectile.acceleration_x + current_frame.velocity[1]
                  projectile.velocity_y = projectile.velocity_y + projectile.acceleration_y + current_frame.velocity[2]
               end
               if current_frame.acceleration then
                  projectile.acceleration_x = projectile.acceleration_x + current_frame.acceleration[1]
                  projectile.acceleration_y = projectile.acceleration_y + current_frame.acceleration[2]
               end
            end
         end
      end
   end
end

-- ── Batch 7: box_type_matches, check_collisions ───────────────────────────────

local box_type_match_attack = { { { "vulnerability", "ext_vulnerability" }, { "attack" } } }
local box_type_match_attack_and_throw =
   { { { "vulnerability", "ext_vulnerability" }, { "attack" } }, { { "throwable" }, { "throw" } } }
local box_type_match_tengu = { { { "vulnerability", "ext_vulnerability", "push" }, { "attack" } } }

-- EX Aegis and Ibuki SA1
local first_hit_frame_exceptions = {
   ["70"] = true, ["25"] = true, ["26"] = true, ["27"] = true, ["28"] = true,
   ["29"] = true, ["2A"] = true, ["2B"] = true, ["2C"] = true, ["2D"] = true,
   ["2E"] = true, ["2F"] = true, ["30"] = true, ["31"] = true, ["32"] = true,
   ["33"] = true, ["34"] = true, ["35"] = true, ["36"] = true,
}

local function check_collisions(gs)
   gs.collisions = Pools.small:alloc()
   for _, player in ipairs(gs.player_objects) do
      local fdata = player.animation_frame_data
      if fdata then
         local frames = fdata.frames
         local frame_to_check = player.animation_frame + 1
         if frames and frames[frame_to_check] then
            if frames[frame_to_check].projectile and player.remaining_freeze_frames == 0 then
               insert_projectile(gs, player, frames[frame_to_check].projectile)
            end

            if
               fdata.hit_frames
               and frames[frame_to_check].boxes
               and tools.has_boxes(frames[frame_to_check].boxes, tools.BOXES.ATTACK_AND_THROW)
            then
               local should_test = false
               local current_hit_id = player.current_hit_id

               for i, hit_frame in ipairs(fdata.hit_frames) do
                  if player.animation_frame >= hit_frame[1] and player.animation_frame <= hit_frame[2] then
                     current_hit_id = i
                     break
                  end
               end

               if fdata.infinite_loop then
                  current_hit_id = (player.animation_miss_count + player.animation_connection_count) % #fdata.hit_frames + 1
                  local next_hit_id = math.min(player.current_hit_id + 1, #fdata.hit_frames)
                  if #fdata.hit_frames == 1 or next_hit_id ~= current_hit_id then
                     should_test = true
                  end
                  if player.animation_connection_count + player.animation_miss_count >= fdata.max_hits then
                     should_test = false
                  end
               else
                  if current_hit_id > player.current_hit_id then
                     should_test = true
                  end
               end

               if player.cooldown > 0 then
                  should_test = false
               end

               if should_test then
                  local delta = gs.frame_number - frame_number
                  local defender = player.other
                  local defender_boxes = defender.boxes
                  if not defender_boxes or #defender_boxes == 0 then
                     defender_boxes = {}
                  end

                  local box_type_matches = box_type_match_attack
                  if
                     get_fdm(player.char_str, player.animation)
                     and get_fdm(player.char_str, player.animation).hit_throw
                  then
                     box_type_matches = box_type_match_attack_and_throw
                  end

                  if
                     tools.test_collision(
                        defender.pos_x, defender.pos_y, defender.flip_x, defender_boxes,
                        player.pos_x, player.pos_y, player.flip_x, player.boxes,
                        box_type_matches
                     )
                  then
                     if not (frames[player.animation_frame + 1].bypass_freeze and delta == 1) then
                        delta = delta + player.remaining_freeze_frames
                     end

                     local expected_hit = Pools.big:alloc()
                     expected_hit.id = player.id
                     expected_hit.owner_id = player.id
                     expected_hit.blocking_type = "player"
                     expected_hit.hit_id = current_hit_id
                     expected_hit.delta = delta
                     expected_hit.animation = player.animation
                     expected_hit.frame = player.animation_frame
                     expected_hit.flip_x = player.flip_x
                     expected_hit.side = player.side
                     gs.collisions[#gs.collisions + 1] = expected_hit
                  end
               end
            end
         end
      end
   end

   local has_tengu_stones = false
   local valid_projectiles = Pools.small:alloc()
   for _, projectile in pairs(gs.projectiles) do
      if projectile.projectile_type == "72" then
         valid_projectiles[#valid_projectiles + 1] = projectile
      elseif projectile.projectile_type == "00_tenguishi" then
         if projectile.remaining_freeze_frames + projectile.cooldown == 0 then
            valid_projectiles[#valid_projectiles + 1] = projectile
         end
      else
         if
            ((projectile.is_forced_one_hit and projectile.remaining_hits ~= 0xFF) or projectile.remaining_hits > 0)
            and projectile.alive
            and projectile.projectile_type ~= "00_seieienbu"
         then
            local defender = gs.player_objects[projectile.emitter_id].other
            if
               projectile.emitter_id ~= defender.id
               or (projectile.emitter_id == defender.id and projectile.is_converted)
            then
               local bypass_freeze = projectile.animation_frame_data
                  and projectile.animation_frame_data.frames
                  and projectile.animation_frame_data.frames[projectile.animation_frame + 1]
                  and projectile.animation_frame_data.frames[projectile.animation_frame + 1].bypass_freeze
               if
                  gs.frame_number >= projectile.animation_start_frame
                  and (projectile.remaining_freeze_frames + projectile.cooldown == 0 or bypass_freeze)
               then
                  valid_projectiles[#valid_projectiles + 1] = projectile
               end
            end
         end
      end
   end

   for _, projectile in pairs(valid_projectiles) do
      local box_type_matches = box_type_match_attack
      local delta = gs.frame_number - frame_number
      local is_first_hit_frame = false
      if projectile.projectile_type == "00_tenguishi" then
         has_tengu_stones = true
         box_type_matches = box_type_match_tengu
      elseif projectile.projectile_type == "seieienbu" then
         is_first_hit_frame = false
      else
         if
            projectile.animation_frame == fd.get_first_hit_frame("projectiles", projectile.projectile_type)
            and not first_hit_frame_exceptions[projectile.projectile_type]
         then
            is_first_hit_frame = true
         end
      end
      local owner_id = projectile.emitter_id
      if projectile.is_converted then
         owner_id = projectile.emitter_id == 1 and 2 or 1
      end
      local defender = gs.player_objects[owner_id].other
      local defender_boxes = defender.boxes
      if not defender_boxes or #defender_boxes == 0 then
         defender_boxes = {}
      end

      if #projectile.boxes > 0 and not is_first_hit_frame then
         if
            tools.test_collision(
               defender.pos_x, defender.pos_y, defender.flip_x, defender_boxes,
               projectile.pos_x, projectile.pos_y, projectile.flip_x, projectile.boxes,
               box_type_matches
            )
         then
            local side = gs.player_objects[owner_id].side
            local expected_hit = Pools.big:alloc()
            expected_hit.id = projectile.id
            expected_hit.owner_id = owner_id
            expected_hit.blocking_type = "projectile"
            expected_hit.hit_id = 1
            expected_hit.delta = delta
            expected_hit.animation = projectile.animation
            expected_hit.frame = projectile.animation_frame
            expected_hit.flip_x = projectile.flip_x
            expected_hit.side = side
            if projectile.projectile_type == "00_tenguishi" then
               expected_hit.tengu_order = projectile.tengu_order
               projectile.cooldown = 99
            elseif projectile.seiei_animation then
               expected_hit.hit_id = projectile.seiei_hit_id
               expected_hit.is_seieienbu = true
            end
            projectile.has_just_connected = true
            gs.collisions[#gs.collisions + 1] = expected_hit
         end
      end
   end

   if has_tengu_stones then
      local current_attack
      for _, attack in ipairs(gs.collisions) do
         if attack.blocking_type == "player" then
            current_attack = attack
            break
         elseif attack.tengu_order then
            if not current_attack or attack.tengu_order < current_attack.tengu_order then
               current_attack = attack
            end
         end
      end
      local i = 1
      while i <= #gs.collisions do
         local attack = gs.collisions[i]
         if attack.animation == "00_tenguishi" and attack ~= current_attack then
            table.remove(gs.collisions, i)
         else
            i = i + 1
         end
      end
   end
end

-- ── Batch 8: apply_pushback, update_sides, check_side_switch, new_gamestate ──

local function apply_pushback(gs)
   local stage = { left = stage_boundaries.left, right = stage_boundaries.right }

   local pushboxes = Pools.small:alloc()
   for _, player in ipairs(gs.player_objects) do
      if player.boxes then
         local boxes = tools.get_boxes(player.boxes, tools.BOXES.PUSH, nil, Pools.small:alloc())
         if #boxes > 0 then
            pushboxes[player.id] = boxes[1]
         end
      end
      if not pushboxes[player.id] then
         pushboxes[player.id] = tools.get_pushboxes(player)
      end
   end

   if pushboxes[1] and pushboxes[2] then
      pushboxes[1] = tools.format_box(pushboxes[1], nil, Pools.small:alloc())
      pushboxes[2] = tools.format_box(pushboxes[2], nil, Pools.small:alloc())

      local overlap = get_horizontal_box_overlap(
         pushboxes[1], math.floor(gs.P1.pos_x), math.floor(gs.P1.pos_y), gs.P1.flip_x,
         pushboxes[2], math.floor(gs.P2.pos_x), math.floor(gs.P2.pos_y), gs.P2.flip_x
      )

      if overlap > 1 then
         local cspec1 = character_specific[gs.P1.char_str] or {}
         local cspec2 = character_specific[gs.P2.char_str] or {}
         local push_value_max = math.ceil(((cspec1.push_value or 0) + (cspec2.push_value or 0)) / 2)
         local dist_from_pb_center = math.abs(gs.P1.pos_x - gs.P2.pos_x)
         local pushbox_overlap_range = (pushboxes[1].width + pushboxes[2].width) / 2
         local push_value = get_push_value(dist_from_pb_center, pushbox_overlap_range, push_value_max)

         local sign = (math.floor(gs.P2.pos_x) - math.floor(gs.P1.pos_x) >= 0 and -1)
            or (math.floor(gs.P2.pos_x) - math.floor(gs.P1.pos_x) < 0 and 1)
         gs.P1.pos_x = gs.P1.pos_x + push_value * sign
         gs.P2.pos_x = gs.P2.pos_x - push_value * sign

         for _, player in ipairs(gs.player_objects) do
            local cspec = character_specific[player.char_str] or {}
            local corner_left = stage.left + (cspec.corner_offset_left or 0)
            local corner_right = stage.right - (cspec.corner_offset_right or 0)
            if player.pos_x > corner_right then
               local mantissa = player.pos_x - math.floor(player.pos_x)
               player.pos_x = corner_right + mantissa
            elseif player.pos_x < corner_left then
               local mantissa = player.pos_x - math.floor(player.pos_x)
               player.pos_x = corner_left + mantissa
            end
         end
      end
   end

   if not gs.previous_gamestate then
      return
   end
   for _, player in ipairs(gs.player_objects) do
      if gs.previous_gamestate[player.other.prefix].is_in_air_recovery then
         local cspec = character_specific[player.other.char_str] or {}
         local corner_left = stage.left + (cspec.corner_offset_left or 0)
         local corner_right = stage.right - (cspec.corner_offset_right or 0)
         if
            (tools.trunc(player.other.pos_x) == corner_left or tools.trunc(player.other.pos_x) == corner_right)
            and math.abs(player.other.pos_x - player.pos_x) < 79
         then
            local sign = tools.sign(player.other.pos_x - player.pos_x)
            if sign == 1 then
               player.pos_x = math.max(player.pos_x - 4.5, player.other.pos_x - 79)
            else
               player.pos_x = math.min(player.pos_x + 4.5, player.other.pos_x + 79)
            end
         end
      end
   end
end

local function update_sides(gs)
   for _, player in ipairs(gs.player_objects) do
      player.side = get_side_local(player.pos_x, player.other.pos_x)
   end
end

local function check_side_switch(gs)
   for _, player in ipairs(gs.player_objects) do
      if player.character_state_byte ~= 4 then
         local previous_dist = math.floor(player.other.previous_pos_x) - math.floor(player.previous_pos_x)
         local dist = math.floor(player.other.pos_x) - math.floor(player.pos_x)
         if tools.sign(previous_dist) ~= tools.sign(dist) and dist ~= 0 then
            player.switched_sides = true
         end
         if (player.side == 1 and player.flip_x ~= 1) or (player.side == 2 and player.flip_x ~= 0) then
            player.should_turn = true
         end
      end
   end
end

local function new_gamestate(base_gs)
   local result = Pools.big:alloc()
   local player_objects = Pools.small:alloc()
   local projectiles = Pools.small:alloc()
   for i, player in ipairs(base_gs.player_objects) do
      player_objects[player.id] = Pools.big:alloc()
      local np = player_objects[player.id]
      np.id = player.id
      np.base = player.base
      np.prefix = player.prefix
      np.type = player.type
      np.input = player.input
      np.char_str = player.char_str
      np.side = player.side
      np.selected_sa = player.selected_sa
      np.flip_x = player.flip_x
      np.previous_pos_x = player.previous_pos_x
      np.previous_pos_y = player.previous_pos_y
      np.pos_x = player.pos_x
      np.pos_y = player.pos_y
      np.velocity_x = player.velocity_x
      np.velocity_y = player.velocity_y
      np.acceleration_x = player.acceleration_x
      np.acceleration_y = player.acceleration_y
      np.boxes = copytable(player.boxes)
      np.remaining_freeze_frames = player.remaining_freeze_frames
      np.freeze_just_began = player.freeze_just_began
      np.freeze_just_ended = player.freeze_just_ended
      np.movement_type = player.movement_type
      np.movement_type2 = player.movement_type2
      np.is_standing = player.is_standing
      np.is_crouching = player.is_crouching
      np.is_airborne = player.is_airborne
      np.is_being_thrown = player.is_being_thrown
      np.is_in_air_recovery = player.is_in_air_recovery
      np.is_in_air_reel = player.is_in_air_reel
      np.is_blocking = player.is_blocking
      np.throw_countdown = player.throw_countdown
      np.animation = player.animation
      np.animation_frame = player.animation_frame
      np.animation_frame_hash = player.animation_frame_hash
      np.animation_frame_data = player.animation_frame_data
      np.animation_freeze_frames = player.animation_freeze_frames
      np.has_animation_just_changed = player.has_animation_just_changed
      np.character_state_byte = player.character_state_byte
      np.posture = player.posture
      np.posture_ext = player.posture_ext
      np.standing_state = player.standing_state
      np.is_in_pushback = player.is_in_pushback
      np.pushback_start_frame = player.pushback_start_frame
      np.recovery_time = player.recovery_time
      np.previous_recovery_time = player.previous_recovery_time
      np.additional_recovery_time = player.additional_recovery_time
      np.ends_recovery_next_frame = player.ends_recovery_next_frame
      np.remaining_wakeup_time = player.remaining_wakeup_time
      np.current_hit_id = player.current_hit_id
      np.animation_miss_count = player.animation_miss_count
      np.animation_connection_count = player.animation_connection_count
      np.connected_action_count = player.connected_action_count
      np.action_count = player.action_count
      np.action = player.action
      np.cooldown = player.cooldown
      np.has_just_connected = player.has_just_connected
      np.last_received_connection_animation = player.last_received_connection_animation
      np.last_received_connection_hit_id = player.last_received_connection_hit_id
   end
   for key, projectile in pairs(base_gs.projectiles) do
      projectiles[key] = Pools.big:alloc()
      local np = projectiles[key]
      np.id = projectile.id
      np.base = projectile.base
      np.emitter_id = projectile.emitter_id
      np.projectile_type = projectile.projectile_type
      np.projectile_start_type = projectile.projectile_start_type
      np.flip_x = projectile.flip_x
      np.previous_pos_x = projectile.previous_pos_x
      np.previous_pos_y = projectile.previous_pos_y
      np.pos_x = projectile.pos_x
      np.pos_y = projectile.pos_y
      np.velocity_x = projectile.velocity_x
      np.velocity_y = projectile.velocity_y
      np.acceleration_x = projectile.acceleration_x
      np.acceleration_y = projectile.acceleration_y
      np.boxes = copytable(projectile.boxes)
      np.remaining_freeze_frames = projectile.remaining_freeze_frames
      np.freeze_just_began = projectile.freeze_just_began
      np.is_forced_one_hit = projectile.is_forced_one_hit
      np.lifetime = projectile.lifetime
      np.remaining_lifetime = projectile.remaining_lifetime
      np.has_activated = projectile.has_activated
      np.animation_start_frame = projectile.animation_start_frame
      np.animation_freeze_frames = projectile.animation_freeze_frames
      np.cooldown = projectile.cooldown
      np.tengu_order = projectile.tengu_order
      np.alive = projectile.alive
      np.is_placeholder = projectile.is_placeholder
      np.expired = projectile.expired
      np.is_converted = projectile.is_converted
      np.remaining_hits = projectile.remaining_hits
      np.animation = projectile.animation
      np.animation_frame = projectile.animation_frame
      np.animation_frame_data = projectile.animation_frame_data
   end
   result.P1 = player_objects[1]
   result.P2 = player_objects[2]
   result.player_objects = player_objects
   result.projectiles = projectiles
   result.stage = base_gs.stage
   result.frame_number = base_gs.frame_number
   result.screen_x = base_gs.screen_x
   result.screen_y = base_gs.screen_y
   return result
end

-- ── Batch 9: next_frames, copy_gamestate, next_gamestates ────────────────────

local function next_frames(obj, gs, animation_options)
   local results = Pools.small:alloc()
   local fdata
   if obj.type == "player" then
      fdata = find_move_frame_data(obj.char_str, obj.animation)
   else
      fdata = find_move_frame_data("projectiles", obj.animation)
   end
   if not fdata then
      local result = Pools.small:alloc()
      result[1] = Pools.small:alloc()
      result[1].animation = obj.animation
      result[1].frame = obj.animation_frame
      return result
   end
   local max_frames = fdata.frames and #fdata.frames or 1
   local frame_to_check = math.min(obj.animation_frame + 1, max_frames)
   local used_next_anim = false
   if fdata and frame_to_check <= #fdata.frames and fdata.frames[frame_to_check] then
      if fdata.frames[frame_to_check].loop then
         local result = Pools.small:alloc()
         result.animation = obj.animation
         result.frame = fdata.frames[frame_to_check].loop
         result.frame_data = fdata
         results[#results + 1] = result
      else
         if fdata.frames[frame_to_check].wakeup then
            local pfd = frame_data[obj.char_str] or {}
            local result = Pools.small:alloc()
            result.animation = pfd.standing or obj.animation
            result.frame = 0
            results[#results + 1] = result
         else
            for _, na in pairs(next_anim_types) do
               if fdata.frames[frame_to_check][na] then
                  local should_check = true
                  if na == "optional_anim" then
                     if
                        animation_options
                        and animation_options[obj.id]
                        and animation_options[obj.id].ignore_optional_anim
                     then
                        should_check = false
                     end
                  elseif na == "next_anim" then
                     used_next_anim = true
                  end
                  if should_check then
                     for __, next_anim in pairs(fdata.frames[frame_to_check][na]) do
                        local next_anim_anim = next_anim[1]
                        local next_anim_frame = next_anim[2]
                        if animation_options and animation_options[obj.id] and animation_options[obj.id].next_anim then
                           if animation_options[obj.id].next_anim[obj.animation] then
                              next_anim_anim = animation_options[obj.id].next_anim[obj.animation].animation
                              next_anim_frame = animation_options[obj.id].next_anim[obj.animation].frame
                           end
                        else
                           if next_anim_anim == "idle" then
                              local pfd = frame_data[obj.char_str] or {}
                              if obj.posture == 32 then
                                 next_anim_anim = pfd.crouching or obj.animation
                                 next_anim_frame = 0
                              else
                                 next_anim_anim = pfd.standing or obj.animation
                                 next_anim_frame = 0
                              end
                           end
                        end
                        local result = Pools.small:alloc()
                        result.animation = next_anim_anim
                        result.frame = next_anim_frame
                        results[#results + 1] = result
                     end
                  end
               end
            end
         end
      end
   end
   if not used_next_anim or #results == 0 then
      local result = Pools.small:alloc()
      result.animation = obj.animation
      result.frame = math.min(obj.animation_frame + 1, max_frames - 1)
      result.frame_data = fdata
      results[#results + 1] = result
   end
   return results
end

local player_copy_reference_keys = { "other", "animation_frame_data", "boxes", "input" }
local gs_copy_exclude_keys = { player_objects = true, projectiles = true, collisions = true, previous_gamestate = true }
local proj_copy_exclude_props = { animation_frame_data = true }

local function copy_gamestate(gs)
   local temp_players = Pools.small:alloc()
   temp_players.P1 = Pools.small:alloc()
   temp_players.P2 = Pools.small:alloc()
   for id, player in ipairs(gs.player_objects) do
      for _, key in ipairs(player_copy_reference_keys) do
         temp_players[player.prefix][key] = player[key]
         player[key] = nil
      end
   end

   local next_gs = tools.tempcopy(gs, Pools.big, gs_copy_exclude_keys)

   for prefix, data in pairs(temp_players) do
      for key, value in pairs(data) do
         gs[prefix][key] = value
         next_gs[prefix][key] = value
      end
   end

   next_gs.player_objects = Pools.small:alloc()
   next_gs.player_objects[1] = next_gs.P1
   next_gs.player_objects[2] = next_gs.P2
   next_gs.P1.other = next_gs.P2
   next_gs.P2.other = next_gs.P1
   next_gs.projectiles = tools.tempcopy(gs.projectiles, Pools.big, proj_copy_exclude_props)

   return next_gs
end

local function next_gamestates(gs, animation_options)
   local next_states = Pools.small:alloc()
   local next_frames_list = Pools.small:alloc()

   local start_gs = copy_gamestate(gs)
   start_gs.previous_gamestate = gs

   update_variables(start_gs)

   for id, player in ipairs(start_gs.player_objects) do
      if animation_options and animation_options[id] and animation_options[id].set then
         next_frames_list[id] = Pools.small:alloc()
         next_frames_list[id][1] = Pools.small:alloc()
         next_frames_list[id][1].animation = animation_options[id].set.animation
         next_frames_list[id][1].frame = animation_options[id].set.frame
      else
         local bypass_freeze = player.animation_frame_data
            and player.animation_frame_data.frames
            and player.animation_frame_data.frames[player.animation_frame + 1]
            and player.animation_frame_data.frames[player.animation_frame + 1].bypass_freeze
         if (player.remaining_freeze_frames == 0 and not player.freeze_just_ended) or bypass_freeze then
            next_frames_list[id] = next_frames(player, start_gs, animation_options)
         else
            next_frames_list[id] = Pools.small:alloc()
            next_frames_list[id][1] = Pools.small:alloc()
            next_frames_list[id][1].animation = player.animation
            next_frames_list[id][1].frame = player.animation_frame
            next_frames_list[id][1].frame_data = player.animation_frame_data
         end
      end
   end

   local next_projectiles = Pools.small:alloc()
   for id, projectile in pairs(start_gs.projectiles) do
      local animation_frame_data = projectile.animation_frame_data
      local next_proj = tools.tempcopy(projectile, Pools.big, proj_copy_exclude_props)
      next_proj.animation_frame_data = animation_frame_data
      if not (next_proj.projectile_type == "seieienbu" or next_proj.projectile_type == "00_tenguishi") then
         local bypass_freeze = next_proj.animation_frame_data
            and next_proj.animation_frame_data.frames
            and next_proj.animation_frame_data.frames[next_proj.animation_frame + 1]
            and next_proj.animation_frame_data.frames[next_proj.animation_frame + 1].bypass_freeze
         if next_proj.remaining_freeze_frames == 0 or bypass_freeze then
            local next_frame = next_frames(next_proj, start_gs)[1]
            update_frame_data(start_gs, next_proj, next_frame)
         end
      end
      next_projectiles[id] = next_proj
   end

   for i, p1_nf in ipairs(next_frames_list[1]) do
      for j, p2_nf in ipairs(next_frames_list[2]) do
         local next_gs = copy_gamestate(start_gs)
         next_gs.previous_gamestate = start_gs
         next_gs.projectiles = next_projectiles
         update_frame_data(next_gs, next_gs.P1, p1_nf)
         update_frame_data(next_gs, next_gs.P2, p2_nf)
         next_states[#next_states + 1] = next_gs
      end
   end

   for i, next_gs in ipairs(next_states) do
      update_turn(next_gs)
      move_players(next_gs)
      move_projectiles(next_gs)
      update_sides(next_gs)
      check_collisions(next_gs)
      apply_pushback(next_gs)
      check_side_switch(next_gs)
   end

   return next_states
end

-- ── Batch 10: simulate_gamestates, predict_hits, predict_gamestate ────────────

local function simulate_gamestates(gs, animation_options, frames_prediction)
   local start_states = next_gamestates(gs, animation_options)
   local predicted_states = Pools.small:alloc()
   predicted_states[1] = start_states
   if animation_options then
      if animation_options[1] and animation_options[1].set then
         animation_options[1].set = nil
      end
      if animation_options[2] and animation_options[2].set then
         animation_options[2].set = nil
      end
   end
   for i = 2, frames_prediction do
      predicted_states[i] = Pools.small:alloc()
      for j, state in ipairs(predicted_states[i - 1]) do
         local next_gs_list = next_gamestates(state, animation_options)
         for k, next_gs in ipairs(next_gs_list) do
            table.insert(predicted_states[i], next_gs)
         end
      end
   end
   return predicted_states
end

local function predict_hits(gs, animation_options, frames_prediction)
   local results = Pools.small:alloc()
   gs = gs or new_gamestate(gamestate)
   if frames_prediction == 0 then
      return results
   end
   if next_animation[1] ~= animations.NONE then
      if not animation_options or not (animation_options[1] and animation_options[1].set) then
         if not animation_options then animation_options = Pools.small:alloc() end
         if not animation_options[1] then animation_options[1] = Pools.small:alloc() end
         animation_options[1].set = Pools.small:alloc()
         animation_options[1].set.animation = get_next_animation(gs.P1, next_animation[1])
         animation_options[1].set.frame = 0
      end
   end
   if next_animation[2] ~= animations.NONE then
      if not animation_options or not (animation_options[2] and animation_options[2].set) then
         if not animation_options then animation_options = Pools.small:alloc() end
         if not animation_options[2] then animation_options[2] = Pools.small:alloc() end
         animation_options[2].set = Pools.small:alloc()
         animation_options[2].set.animation = get_next_animation(gs.P2, next_animation[2])
         animation_options[2].set.frame = 0
      end
   end
   local predicted_states = simulate_gamestates(gs, animation_options, frames_prediction)
   for i, state_list in ipairs(predicted_states) do
      for j, state in ipairs(state_list) do
         for _, hit in ipairs(state.collisions) do
            if not results[hit.delta] then
               results[hit.delta] = Pools.small:alloc()
            end
            table.insert(results[hit.delta], hit)
         end
      end
   end
   return results
end

local function predict_gamestate(gs, animation_options, frames_prediction)
   gs = gs or new_gamestate(gamestate)
   if frames_prediction == 0 then
      return gs
   end
   if next_animation[1] ~= animations.NONE then
      if not animation_options or not (animation_options[1] and animation_options[1].set) then
         if not animation_options then animation_options = Pools.small:alloc() end
         if not animation_options[1] then animation_options[1] = Pools.small:alloc() end
         animation_options[1].set = { animation = get_next_animation(gs.P1, next_animation[1]), frame = 0 }
      end
   end
   if next_animation[2] ~= animations.NONE then
      if not animation_options or not (animation_options[2] and animation_options[2].set) then
         if not animation_options then animation_options = Pools.small:alloc() end
         if not animation_options[2] then animation_options[2] = Pools.small:alloc() end
         animation_options[2].set = { animation = get_next_animation(gs.P2, next_animation[2]), frame = 0 }
      end
   end
   if not animation_options then animation_options = Pools.small:alloc() end
   if not animation_options[1] then animation_options[1] = Pools.small:alloc() end
   if not animation_options[2] then animation_options[2] = Pools.small:alloc() end
   animation_options[1].ignore_optional_anim = true
   animation_options[2].ignore_optional_anim = true

   local predicted_states = simulate_gamestates(gs, animation_options, frames_prediction)
   return predicted_states[#predicted_states][1]
end

-- ── Gamestate adapter ────────────────────────────────────────────────────────

local function make_player_gs(p)
  return {
    pos_x = p.pos_x,
    pos_y = p.pos_y,
    flip_x = p.flip_x,
    velocity_x = p.velocity_x or 0,
    velocity_y = p.velocity_y or 0,
    acceleration_x = p.acceleration_x or 0,
    acceleration_y = p.acceleration_y or 0,
    animation = p.animation,
    animation_frame = p.animation_frame,
    animation_frame_hash = p.animation_frame_hash,
    animation_frame_data = p.animation_frame_data,
    remaining_freeze_frames = p.remaining_freeze_frames or 0,
    freeze_just_began = false,
    freeze_just_ended = false,
    char_str = p.char_str,
    char_id = p.char_id,
    id = p.id,
    prefix = p.prefix,
    boxes = p.boxes,
    posture = p.posture,
    posture_ext = p.posture_ext,
    standing_state = p.standing_state,
    is_standing = (p.standing_state == 1),
    is_crouching = (p.standing_state == 2),
    is_airborne = (p.standing_state == 4),
    is_blocking = p.is_blocking or false,
    movement_type = p.movement_type,
    movement_type2 = p.movement_type2,
    action = p.action,
    action_count = p.action_count or 0,
    throw_countdown = p.throw_countdown or 0,
    is_being_thrown = p.is_being_thrown or false,
    remaining_wakeup_time = p.remaining_wakeup_time or 0,
    recovery_time = p.recovery_time or 0,
    selected_sa = p.selected_sa or 1,
    -- effie3rd-specific fields defaulted
    is_in_pushback = false,
    pushback_start_frame = 0,
    is_in_air_recovery = false,
    is_in_air_reel = false,
    current_hit_id = 0,
    connected_action_count = 0,
    has_just_connected = false,
    animation_connection_count = 0,
    has_animation_just_changed = p.has_animation_just_changed or false,
    additional_recovery_time = 0,
    ends_recovery_next_frame = false,
    previous_recovery_time = 0,
    cooldown = 0,
  }
end

local function make_gs(player1, player2)
  local gs = {}
  gs.frame_number = frame_number
  gs.screen_x = screen_x or 0
  gs.screen_y = screen_y or 0
  gs.projectiles = {}
  gs.stage = 1

  local p1 = make_player_gs(player1)
  local p2 = make_player_gs(player2)
  p1.id = 1
  p2.id = 2
  gs.player_objects = {p1, p2}
  gs.P1 = p1
  gs.P2 = p2
  if p1.prefix then gs[p1.prefix] = p1 end
  if p2.prefix then gs[p2.prefix] = p2 end

  return gs
end

-- ── Public API ───────────────────────────────────────────────────────────────

function prediction.predict_hits(_player1, _player2, _frames_prediction)
  local gs = make_gs(_player1, _player2)
  return predict_hits(gs, nil, _frames_prediction or 3)
end

function prediction.predict_gamestate(_player1, _player2, _frames_prediction)
  local gs = make_gs(_player1, _player2)
  return predict_gamestate(gs, nil, _frames_prediction or 3)
end

function prediction.get_frame_advantage(_player_obj)
  return get_frame_advantage(make_player_gs(_player_obj))
end

function prediction.predict_frames_before_landing(_player_obj)
  return predict_frames_before_landing(make_player_gs(_player_obj))
end

return prediction
