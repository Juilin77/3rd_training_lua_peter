-- src/data/prediction.lua
-- Ported from effie3rd's prediction.lua for Peter's global-variable architecture
-- effie3rd source: _reference/effie3rd/3rd_training_lua-main/src/data/prediction.lua

local prediction = {}

-- ── Stubs for missing effie3rd modules ──────────────────────────────────────

-- Peter uses global frame_data, frame_data_meta instead of fd module
local _fd = {}
_fd.get_first_hit_frame = function(_char_str, _anim)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata or not _fdata.hit_frames then return nil end
  return _fdata.hit_frames[1]
end
_fd.get_last_hit_frame = function(_char_str, _anim)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata or not _fdata.hit_frames then return nil end
  return _fdata.hit_frames[#_fdata.hit_frames]
end
_fd.find_frame_data_by_name = function() return nil end
_fd.get_boxes = function(_char_str, _anim, _frame)
  local _fdata = find_move_frame_data(_char_str, _anim)
  if not _fdata then return nil end
  return _fdata.boxes and _fdata.boxes[_frame] or nil
end

-- move_data not needed for blocking prediction
local _move_data = {}
_move_data.get_move_inputs_by_name = function() return nil end

-- SF3 stage boundaries (approximate pixel units)
local _stage_boundaries = { left = -27648, right = 27648 }

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

local _next_anim_types = { "next_anim", "optional_anim" }

local _animations = {
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
      _delta = _result[#_result]._delta
   end

   if _specify_frame then
      _delta = _delta + 1
      _frames_prediction = _frames_prediction - 1
      _result[#_result + 1] = { animation = _anim, frame = math.min(_frame, _max_frames - 1), _delta = _delta }
   end

   local _used_loop = false
   local _used_next_anim = false

   for _i = 1, _frames_prediction do
      if _fdata and _frame_to_check <= #_fdata.frames and _fdata.frames[_frame_to_check] then
         _used_loop = false
         _used_next_anim = false
         _delta = _delta + 1
         if _fdata.frames[_frame_to_check].loop then
            _used_loop = true
            _frame_to_check = _fdata.frames[_frame_to_check].loop + 1
         else
            for _, _na in pairs(_next_anim_types) do
               if _fdata.frames[_frame_to_check][_na] then
                  if _na == "next_anim" then
                     _used_next_anim = true
                  end
                  for __, _next_anim in pairs(_fdata.frames[_frame_to_check][_na]) do
                     local _current_res = copytable(_result)
                     local _next_anim_anim = _next_anim[1]
                     local _next_anim_frame = _next_anim[2]
                     if _next_anim_anim == "idle" then
                        local _pfd = frame_data[_obj.char_str] or {}
                        if _obj.posture == 32 then
                           _next_anim_anim = _pfd.crouching or _obj.animation
                           _next_anim_frame = 0
                        else
                           _next_anim_anim = _pfd.standing or _obj.animation
                           _next_anim_frame = 0
                        end
                     end
                     _current_res[#_current_res + 1] = {
                        animation = _next_anim_anim,
                        frame = _next_anim_frame,
                        _delta = _delta,
                     }
                     local subres = predict_frames_branching(
                        _obj,
                        _next_anim_anim,
                        _next_anim_frame,
                        _frames_prediction - _i,
                        false,
                        _current_res
                     )
                     for ___, _sr in pairs(subres) do
                        _results[#_results + 1] = _sr
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
            _result[#_result + 1] = { animation = _anim, frame = _frame_to_check - 1, _delta = _delta }
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
   for _i = 1, _frames_prediction do
      _y = _y + _velocity
      _velocity = _velocity + _player.acceleration_y
      if _player._animation_frame_data and _player._animation_frame_data.landing_height then
         if _y < _player._animation_frame_data.landing_height then
            return _i
         end
      elseif _y < 0 then
         return _i
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
      local _recovery_time = _obj._recovery_time + _obj.additional_recovery_time
      if _recovery_time > 0 then
         return _recovery_time + 1
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
      for _, _idle_frame in ipairs(_fdata.idle_frames) do
         if _frame <= _idle_frame[1] then
            diff = _idle_frame[1] - _frame
            break
         end
      end
      return _delta + diff, true
   else
      if _fdata.loops then
         for _i = 1, #_fdata.loops do
            if _frame_to_check >= _fdata.loops[_i][1] + 1 and _frame_to_check <= _fdata.loops[_i][2] + 1 then
               break
            end
         end
      end
      for _i = 1, _frames_prediction do
         if _fdata and _frame_to_check <= #_fdata.frames and _fdata.frames[_frame_to_check] then
            _used_loop = false
            _used_next_anim = false
            _delta = _delta + 1
            if _fdata.frames[_frame_to_check].loop then
               _used_loop = true
               _frame_to_check = _fdata.frames[_frame_to_check].loop + 1
            else
               for _, _na in pairs(_next_anim_types) do
                  if _fdata.frames[_frame_to_check][_na] then
                     if _na == "next_anim" then
                        _used_next_anim = true
                     end
                     for __, _next_anim in pairs(_fdata.frames[_frame_to_check][_na]) do
                        local _next_anim_anim = _next_anim[1]
                        local _next_anim_frame = _next_anim[2]
                        if _next_anim_anim == "idle" then
                           return _delta, true
                        end
                        local subres, found = get_frames_until_idle(
                           _obj,
                           _next_anim_anim,
                           _next_anim_frame,
                           _frames_prediction - _i,
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
   for _, _p in ipairs({ _player, _player.other }) do
      _recovery_times[_p._id] = get_frames_until_idle(_p, nil, nil, 80)
   end
   return _recovery_times[_player.other._id] - _recovery_times[_player._id]
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
   for _i = 1, _n do
      _line[#_line + 1] = { animation = _obj.animation or _obj.projectile_type, frame = _obj.animation_frame + _i, _delta = _i }
   end
   return _line
end

local function update_player_animation(_previous_input, _player)
   if _player.has_animation_just_changed then
      next_animation[_player._id] = _animations.NONE
   end
   if _player.has_just_blocked then
      local _pfd = frame_data[_player.char_str] or {}
      local _cspec = character_specific[_player.char_str] or {}
      local _height_min = _cspec.height and _cspec.height.standing and _cspec.height.standing.min or 0
      if not tools.is_pressing_down(_player, _previous_input) then
         if
            not _player.received_connection_is_projectile
            and _player.other.pos_y >= _height_min - 56
         then
            next_animation[_player._id] = _animations.BLOCK_HIGH_AIR
         else
            next_animation[_player._id] = _animations.BLOCK_HIGH
         end
      else
         next_animation[_player._id] = _animations.BLOCK_LOW
      end
   elseif _player.has_just_parried then
      if _player.parry_forward.success or _player.parry_antiair.success then
         next_animation[_player._id] = _animations.PARRY_HIGH
      elseif _player.parry_down.success then
         next_animation[_player._id] = _animations.PARRY_LOW
      elseif _player.parry_air.success then
         next_animation[_player._id] = _animations.PARRY_AIR
      end
   end
   local _pfd = frame_data[_player.char_str] or {}
   if _player.animation == _pfd.parry_low and not tools.is_pressing_down(_player, _previous_input) then
      if _player.animation_frame == #_player._animation_frame_data.frames - 1 then
         next_animation[_player._id] = _animations.STANDING_BEGIN
      end
   elseif _player.animation == _pfd.parry_high and tools.is_pressing_down(_player, _previous_input) then
      if _player.animation_frame == #_player._animation_frame_data.frames - 1 then
         next_animation[_player._id] = _animations.CROUCHING_BEGIN
      end
   end
end

local function predict_next_animation(_player, _input)
   local _pfd = frame_data[_player.char_str] or {}
   local _cspec = character_specific[_player.char_str] or {}
   local _height_min = _cspec.height and _cspec.height.standing and _cspec.height.standing.min or 0
   local _animation = _animations.NONE
   if _player.is_standing then
      if tools.is_pressing_down(_player, _input) then
         if _player.is_idle then
            _animation = _animations.CROUCHING_BEGIN
         end
      elseif tools.is_pressing_forward(_player, _input) then
         if _player.action == 0 or _player.action == 23 or _player.action == 29 or _player.action == 30 then
            _animation = _animations.WALK_FORWARD
         elseif _player.action == 3 then
            _animation = _animations.WALK_TRANSITION
         end
      elseif tools.is_pressing_back(_player, _input) then
         if _player.is_idle then
            if
               _player.blocking
               and _player.blocking.last_block
               and _player.blocking.last_block.blocking_type == "player"
               and _player.pos_y >= _height_min - 56
            then
               _animation = _animations.BLOCK_HIGH_AIR_PROXIMITY
            else
               _animation = _animations.BLOCK_HIGH_PROXIMITY
            end
         end
      end
   elseif _player.is_crouching then
      if not tools.is_pressing_down(_player, _input) then
         if _player.is_idle then
            _animation = _animations.STANDING_BEGIN
         end
      elseif tools.is_pressing_back(_player, _input) then
         if _player.is_idle then
            _animation = _animations.BLOCK_LOW_PROXIMITY
         end
      end
   end
   local _recovery_time = _player._recovery_time + _player.additional_recovery_time
   if _recovery_time > 0 and _recovery_time <= 1 then
      if _player.animation == _pfd.block_low and not tools.is_pressing_down(_player, _input) then
         _animation = _animations.STANDING_BEGIN
      elseif
         (_player.animation == _pfd.block_high or _player.animation == _pfd.block_high_air)
         and tools.is_pressing_down(_player, _input)
      then
         _animation = _animations.CROUCHING_BEGIN
      end
   end
   return _animation
end

local function get_next_animation(_player, _animation)
   local _pfd = frame_data[_player.char_str] or {}
   if _animation == _animations.WALK_FORWARD then
      return _pfd.walk_forward
   elseif _animation == _animations.WALK_BACK then
      return _pfd.walk_back
   elseif _animation == _animations.WALK_TRANSITION then
      return _pfd.walk_transition
   elseif _animation == _animations.STANDING_BEGIN then
      return _pfd.standing_begin
   elseif _animation == _animations.CROUCHING_BEGIN then
      return _pfd.crouching_begin
   elseif _animation == _animations.BLOCK_HIGH_PROXIMITY then
      return _pfd.block_high_proximity
   elseif _animation == _animations.BLOCK_HIGH then
      return _pfd.block_high
   elseif _animation == _animations.BLOCK_HIGH_AIR_PROXIMITY then
      return _pfd.block_high_air_proximity
   elseif _animation == _animations.BLOCK_HIGH_AIR then
      return _pfd.block_high_air
   elseif _animation == _animations.BLOCK_LOW_PROXIMITY then
      return _pfd.block_low_proximity
   elseif _animation == _animations.BLOCK_LOW then
      return _pfd.block_low
   elseif _animation == _animations.PARRY_HIGH then
      return _pfd.parry_high
   elseif _animation == _animations.PARRY_LOW then
      return _pfd.parry_low
   elseif _animation == _animations.PARRY_AIR then
      return _pfd.parry_air
   else
      return _player.animation
   end
end

-- ── Batch 4: insert_projectile, box overlap helpers, update_before/after, update_frame_data ──

local function insert_projectile(_gs, _player, _projectile_data)
   local _proj_fdata = find_move_frame_data("projectiles", _projectile_data.type)
   if _proj_fdata then
      local _obj = { base = 0, _projectile = 99 }
      _obj._id = _projectile_data.type .. "_" .. _player._id .. tostring(_gs.frame_number)
      _obj.emitter_id = _player._id
      _obj.alive = true
      _obj.projectile_type = _projectile_data.type
      _obj.projectile_start_type = _obj.projectile_type
      _obj.animation = _obj.projectile_type
      _obj.pos_x = _player.pos_x + _projectile_data.offset[1] * tools.flip_to_sign(_player.flip_x)
      _obj.pos_y = _player.pos_y + _projectile_data.offset[2]
      _obj.velocity_x = 0
      _obj.velocity_y = 0
      _obj.acceleration_x = 0
      _obj.acceleration_y = 0
      if _proj_fdata.frames[1].velocity then
         _obj.velocity_x = _proj_fdata.frames[1].velocity[1]
         _obj.velocity_y = _proj_fdata.frames[1].velocity[2]
      end
      if _proj_fdata.frames[1].acceleration then
         _obj.acceleration_x = _proj_fdata.frames[1].acceleration[1]
         _obj.acceleration_y = _proj_fdata.frames[1].acceleration[2]
      end
      _obj.flip_x = _player.flip_x
      _obj._boxes = {}
      _obj.expired = false
      _obj.previous_remaining_hits = 99
      _obj.remaining_hits = 99
      _obj.is_forced_one_hit = false
      _obj.has_activated = false
      _obj.animation_start_frame = _gs.frame_number
      _obj.animation_frame = 0
      _obj.animation_freeze_frames = 0
      _obj.remaining_freeze_frames = 0
      _obj.remaining_lifetime = 0
      _obj.lifetime = 0
      _obj.cooldown = 0
      _obj.is_placeholder = true
      _gs.projectiles[_obj._id] = _obj
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
      local _range = math.floor(0.7 * _pushbox_overlap_range)
      return tools.round((_range - _dist_from_pb_center) / _range * (_push_value_max - 6) + 6)
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
   next_animation[_player._id] = predict_next_animation(_player, _input)
   next_animation[_dummy._id] = predict_next_animation(_dummy, _input)
end

local function update_frame_data(_gs, _obj, _frame_data_entry)
   _obj.animation = _frame_data_entry.animation
   if _obj.type == "projectile" then
      _obj.projectile_type = _frame_data_entry.animation
   end
   _obj.animation_frame = _frame_data_entry.frame
   if _frame_data_entry.frame_data then
      _obj._animation_frame_data = _frame_data_entry.frame_data
   else
      local _new_fdata
      if _obj.type == "player" then
         _new_fdata = frame_data[_obj.char_str] and frame_data[_obj.char_str][_obj.animation]
      else
         _new_fdata = frame_data["projectiles"] and frame_data["projectiles"][_obj.animation]
      end
      _obj._animation_frame_data = _new_fdata or _obj._animation_frame_data
   end
   _obj._boxes = _obj._animation_frame_data
         and _obj._animation_frame_data.frames
         and _obj._animation_frame_data.frames[_obj.animation_frame + 1]
         and _obj._animation_frame_data.frames[_obj.animation_frame + 1].boxes
      or _obj._boxes
   _obj.has_animation_just_changed = false
   if _obj.type == "player" and _gs.previous_gamestate and _obj.animation ~= _gs.previous_gamestate[_obj._prefix].animation then
      _obj.has_animation_just_changed = true
      _obj._current_hit_id = 0
      _obj.animation_action_count = 0
      _obj.animation_miss_count = 0
      _obj.animation_connection_count = 0
   end
end

-- ── Batch 5: local stubs, update_variables, update_turn ──────────────────────

-- stub: Peter's version doesn't expose this; return 0 as safe default
local function get_additional_recovery_delay() return 0 end

-- stub: simple _side determination used by update_sides
local function get_side_local(_pos_x, _other_pos_x)
   return (_pos_x < _other_pos_x) and 1 or 2
end

local function update_variables(_gs)
   local _previous_gs = _gs.previous_gamestate
   _gs.frame_number = _gs.frame_number + 1
   for _, _player in ipairs(_gs.player_objects) do
      _player.previous_pos_x = _previous_gs and _previous_gs[_player._prefix].pos_x or _player.previous_pos_x
      _player.previous_pos_y = _previous_gs and _previous_gs[_player._prefix].pos_y or _player.previous_pos_y
      _player.previous_remaining_freeze_frames = _player.remaining_freeze_frames or 0
      _player.remaining_freeze_frames = math.max(_player.remaining_freeze_frames - 1, 0)
      if _previous_gs and _previous_gs[_player._prefix].just_received_connection then
         _player.remaining_freeze_frames = _player.other.remaining_freeze_frames
      end
      if _player.freeze_just_ended and _player.character_state_byte == 1 and _player._recovery_time == 0 then
         _player._recovery_time = 10
         if _player.is_blocking then
            _player.additional_recovery_time = get_additional_recovery_delay(_player.char_str, _player.is_crouching)
         end
         _player.is_in_recovery = true
         _player.is_in_pushback = true
         _player.pushback_start_frame = _gs.frame_number
      end
      _player.freeze_just_began = false
      _player.freeze_just_ended = false
      if _player.remaining_freeze_frames == 0 and _player.previous_remaining_freeze_frames > 0 then
         _player.freeze_just_ended = true
      end
      if _player.remaining_freeze_frames > 0 then
         if _player.previous_remaining_freeze_frames == 0 then
            _player.freeze_just_began = true
         end
         _player.animation_freeze_frames = _player.animation_freeze_frames + 1
      end
      if _player.ends_recovery_next_frame then
         _player.has_just_ended_recovery = true
         _player.character_state_byte = 0
         _player.ends_recovery_next_frame = false
      end
      _player.previous_recovery_time = _player._recovery_time
      if _player._recovery_time > 0 then
         _player._recovery_time = _player._recovery_time - 1
      end
      if _player._recovery_time == 0 and _player.previous_recovery_time > 0 then
         _player.ends_recovery_next_frame = true
      end
      if
         _player.freeze_just_began
         or (_player.is_in_pushback and not _player.freeze_just_ended and _player._recovery_time == 0)
      then
         _player.is_in_pushback = false
      end
      if _player.freeze_just_ended and _player.movement_type == 1 then
         _player.pushback_start_frame = _gs.frame_number
         _player.is_in_pushback = true
      end
      if _player.remaining_freeze_frames == 0 and not _player.freeze_just_ended then
         _player.cooldown = math.max(_player.cooldown - 1, 0)
      end
      _player.just_received_connection = false
      _player.has_just_landed = false
   end

   local _to_remove = Pools.small:alloc()
   for _, _projectile in pairs(_gs.projectiles) do
      _projectile.lifetime = _projectile.lifetime + 1
      _projectile.previous_remaining_freeze_frames = _projectile.remaining_freeze_frames
      _projectile.remaining_freeze_frames = math.max(_projectile.remaining_freeze_frames - 1, 0)
      _projectile.freeze_just_began = false
      _projectile.freeze_just_ended = false
      if _projectile.remaining_freeze_frames > 0 then
         if _projectile.previous_remaining_freeze_frames == 0 then
            _projectile.freeze_just_began = true
         end
         _projectile.animation_freeze_frames = _projectile.animation_freeze_frames + 1
      end
      if _projectile.remaining_freeze_frames == 0 and _projectile.previous_remaining_freeze_frames > 0 then
         _projectile.freeze_just_ended = true
      end
      if
         _projectile.cooldown > 0
         and (
            (_projectile.remaining_freeze_frames == 0 or _projectile.freeze_just_began)
            or _projectile.projectile_type == "72"
         )
      then
         _projectile.cooldown = _projectile.cooldown - 1
      end
      if _projectile.is_placeholder and _gs.frame_number > _projectile.animation_start_frame then
         _to_remove[#_to_remove + 1] = _projectile._id
      end
   end
   for _, _key in ipairs(_to_remove) do
      _gs.projectiles[_key] = nil
   end
end

local function update_turn(_gs)
   local _previous_gs = _gs.previous_gamestate
   for _, _player in ipairs(_gs.player_objects) do
      if _player.should_turn then
         if _player.remaining_freeze_frames + _player._recovery_time + _player.additional_recovery_time == 0 then
            local _pfd = frame_data[_player.char_str] or {}
            _player.flip_x = bit.bxor(_previous_gs[_player._prefix].flip_x, 1)
            local _anim = _previous_gs[_player._prefix].animation
            local _target_anim = nil
            if
               _anim == _pfd.standing
               or _anim == _pfd.walk_back
               or _anim == _pfd.block_high
            then
               _target_anim = _pfd.standing_turn
            elseif _anim == _pfd.crouching then
               _target_anim = _pfd.crouching_turn
            else
               _player.should_turn = nil
            end
            if _target_anim then
               local _ufd = Pools.small:alloc()
               _ufd.animation = _target_anim
               _ufd.frame = 0
               _ufd.frame_data = find_move_frame_data(_player.char_str, _target_anim)
               update_frame_data(_gs, _player, _ufd)
               if _target_anim.velocity then
                  _player.velocity_x = _target_anim.velocity[1]
                  _player.velocity_y = _target_anim.velocity[2]
               end
               _player.should_turn = nil
            end
         end
      end
   end
end

-- ── Batch 6: move_players, move_projectiles ───────────────────────────────────

local function move_players(_gs)
   local _stage = { left = _stage_boundaries.left, right = _stage_boundaries.right }

   for _, _player in ipairs(_gs.player_objects) do
      if _player.remaining_freeze_frames == 0 and not _player.freeze_just_ended then
         local _cspec = character_specific[_player.char_str] or {}
         local _corner_left = _stage.left + (_cspec.corner_offset_left or 0)
         local _corner_right = _stage.right - (_cspec.corner_offset_right or 0)
         local _sign = tools.flip_to_sign(_player.flip_x)

         if _player.is_in_pushback then
            local _pb_frame = _gs.frame_number - _player.pushback_start_frame
            local _anim = _player.last_received_connection_animation
            local _hit_id = _player.last_received_connection_hit_id
            local _other_pfd = frame_data[_player.other.char_str] or {}
            if
               _anim and _hit_id
               and _other_pfd[_anim]
               and _other_pfd[_anim].pushback
               and _other_pfd[_anim].pushback[_hit_id]
               and _pb_frame <= #_other_pfd[_anim].pushback[_hit_id]
            then
               local _pb_value = _other_pfd[_anim].pushback[_hit_id][_pb_frame]
               if _pb_value then
                  local _new_pos = _player.pos_x - _sign * _pb_value
                  local _over_push = 0
                  if _new_pos < _corner_left then
                     _over_push = _corner_left - _new_pos
                  elseif _new_pos > _corner_right then
                     _over_push = _new_pos - _corner_right
                  end
                  if _over_push > 0 then
                     _player.other.pos_x = _player.other.pos_x + _over_push * _sign
                  end
                  _player.pos_x = _player.pos_x - (_pb_value - _over_push) * _sign
               end
            end
         end

         local _should_apply_velocity = false
         local _current_frame = _player._animation_frame_data
            and _player._animation_frame_data.frames[_player.animation_frame + 1]
         local _first_frame_of_air_attack = _player.animation_frame == 0
            and _player._animation_frame_data
            and _player._animation_frame_data.air
         local _should_ignore_motion = _current_frame and _current_frame.ignore_motion

         if _first_frame_of_air_attack then
            _should_ignore_motion = true
         else
            if (_player._animation_frame_data and _player._animation_frame_data.uses_velocity) or _player.is_airborne then
               _should_apply_velocity = true
            end
         end

         if _current_frame then
            if _current_frame.clear_motion then
               _player.velocity_x = 0
               _player.velocity_y = 0
               _player.acceleration_x = 0
               _player.acceleration_y = 0
               _should_apply_velocity = false
            end
            if not _should_ignore_motion and _should_apply_velocity then
               _player.pos_x = _player.pos_x + _player.velocity_x * _sign
               _player.pos_y = _player.pos_y + _player.velocity_y
            end
            if _current_frame.set_acceleration then
               _player.acceleration_x = _current_frame.set_acceleration[1]
               _player.acceleration_y = _current_frame.set_acceleration[2]
            end
            if _current_frame.set_velocity then
               _player.velocity_x = _current_frame.set_velocity[1]
               _player.velocity_y = _current_frame.set_velocity[2]
            end
         end

         if not _should_ignore_motion then
            _player.velocity_x = _player.velocity_x + _player.acceleration_x
            _player.velocity_y = _player.velocity_y + _player.acceleration_y
            if _current_frame then
               if _current_frame.movement then
                  _player.pos_x = _player.pos_x + _current_frame.movement[1] * _sign
                  _player.pos_y = _player.pos_y + _current_frame.movement[2]
               end
               if _current_frame.velocity then
                  _player.velocity_x = _player.velocity_x + _current_frame.velocity[1]
                  _player.velocity_y = _player.velocity_y + _current_frame.velocity[2]
               end
               if _current_frame.acceleration then
                  _player.acceleration_x = _player.acceleration_x + _current_frame.acceleration[1]
                  _player.acceleration_y = _player.acceleration_y + _current_frame.acceleration[2]
               end
            end
         end

         if _player.pos_x > _corner_right then
            local _mantissa = _player.pos_x - math.floor(_player.pos_x)
            _player.pos_x = _corner_right + _mantissa
         elseif _player.pos_x < _corner_left then
            local _mantissa = _player.pos_x - math.floor(_player.pos_x)
            _player.pos_x = _corner_left + _mantissa
         end

         if _player._animation_frame_data and _player.pos_y < _player.previous_pos_y then
            local should_land = false
            if _player._animation_frame_data.landing_height then
               if _player.pos_y < _player._animation_frame_data.landing_height then
                  should_land = true
               end
            elseif _player.pos_y < 0 then
               should_land = true
            end
            if should_land then
               _player.pos_y = 0
               _player.standing_state = 1
               _player.has_just_landed = true
               _player.is_airborne = false
               _player.is_in_air_recovery = false
               _player.is_in_air_reel = false
               local _pfd = frame_data[_player.char_str] or {}
               local _landing_animation = (_player._animation_frame_data and _player._animation_frame_data.landing_anim)
                  or _pfd.jump_recovery
                  or _player.animation
               local _ufd = Pools.small:alloc()
               _ufd.animation = _landing_animation
               _ufd.frame = 0
               _ufd.frame_data = find_move_frame_data(_player.char_str, _landing_animation)
               update_frame_data(_gs, _player, _ufd)
            end
         end
      end
   end
   -- don't allow _side switches if grounded
   for _, _player in ipairs(_gs.player_objects) do
      if _player.pos_y == 0 and _player.other.pos_y == 0 then
         if
            tools.sign(_player.previous_pos_x - _player.other.previous_pos_x)
            ~= tools.sign(_player.pos_x - _player.other.pos_x)
         then
            local _sign = tools.sign(_player.previous_pos_x - _player.other.previous_pos_x)
            _player.pos_x = _player.other.pos_x + _sign
         end
      end
   end
end

local function move_projectiles(_gs)
   for _, _projectile in pairs(_gs.projectiles) do
      if _projectile.remaining_freeze_frames == 0 then
         local _ignore_flip = _projectile.projectile_type == "00_tenguishi"
         local _sign = _ignore_flip and 1 or tools.flip_to_sign(_projectile.flip_x)
         _projectile.pos_x = _projectile.pos_x + _projectile.velocity_x * _sign
         _projectile.pos_y = _projectile.pos_y + _projectile.velocity_y
         if _projectile._animation_frame_data then
            local _current_frame = _projectile._animation_frame_data.frames[_projectile.animation_frame + 1]
            if _current_frame then
               if _current_frame.movement then
                  _projectile.pos_x = _projectile.pos_x + _current_frame.movement[1] * _sign
                  _projectile.pos_y = _projectile.pos_y + _current_frame.movement[2]
               end
               if _current_frame.velocity then
                  _projectile.velocity_x = _projectile.velocity_x + _projectile.acceleration_x + _current_frame.velocity[1]
                  _projectile.velocity_y = _projectile.velocity_y + _projectile.acceleration_y + _current_frame.velocity[2]
               end
               if _current_frame.acceleration then
                  _projectile.acceleration_x = _projectile.acceleration_x + _current_frame.acceleration[1]
                  _projectile.acceleration_y = _projectile.acceleration_y + _current_frame.acceleration[2]
               end
            end
         end
      end
   end
end

-- ── Batch 7: _box_type_matches, check_collisions ───────────────────────────────

local _box_type_match_attack = { { { "vulnerability", "ext_vulnerability" }, { "attack" } } }
local _box_type_match_attack_and_throw =
   { { { "vulnerability", "ext_vulnerability" }, { "attack" } }, { { "throwable" }, { "throw" } } }
local _box_type_match_tengu = { { { "vulnerability", "ext_vulnerability", "push" }, { "attack" } } }

-- EX Aegis and Ibuki SA1
local _first_hit_frame_exceptions = {
   ["70"] = true, ["25"] = true, ["26"] = true, ["27"] = true, ["28"] = true,
   ["29"] = true, ["2A"] = true, ["2B"] = true, ["2C"] = true, ["2D"] = true,
   ["2E"] = true, ["2F"] = true, ["30"] = true, ["31"] = true, ["32"] = true,
   ["33"] = true, ["34"] = true, ["35"] = true, ["36"] = true,
}

local function check_collisions(_gs)
   _gs.collisions = Pools.small:alloc()
   for _, _player in ipairs(_gs.player_objects) do
      local _fdata = _player._animation_frame_data
      if _fdata then
         local _frames = _fdata.frames
         local _frame_to_check = _player.animation_frame + 1
         if _frames and _frames[_frame_to_check] then
            if _frames[_frame_to_check].projectile and _player.remaining_freeze_frames == 0 then
               insert_projectile(_gs, _player, _frames[_frame_to_check].projectile)
            end

            if
               _fdata.hit_frames
               and _frames[_frame_to_check].boxes
               and tools.has_boxes(_frames[_frame_to_check].boxes, tools.BOXES.ATTACK_AND_THROW)
            then
               local _should_test = false
               local _current_hit_id = _player._current_hit_id

               for _i, hit_frame in ipairs(_fdata.hit_frames) do
                  if _player.animation_frame >= hit_frame[1] and _player.animation_frame <= hit_frame[2] then
                     _current_hit_id = _i
                     break
                  end
               end

               if _fdata.infinite_loop then
                  _current_hit_id = (_player.animation_miss_count + _player.animation_connection_count) % #_fdata.hit_frames + 1
                  local _next_hit_id = math.min(_player._current_hit_id + 1, #_fdata.hit_frames)
                  if #_fdata.hit_frames == 1 or _next_hit_id ~= _current_hit_id then
                     _should_test = true
                  end
                  if _player.animation_connection_count + _player.animation_miss_count >= _fdata.max_hits then
                     _should_test = false
                  end
               else
                  if _current_hit_id > _player._current_hit_id then
                     _should_test = true
                  end
               end

               if _player.cooldown > 0 then
                  _should_test = false
               end

               if _should_test then
                  local _delta = _gs.frame_number - frame_number
                  local _defender = _player.other
                  local _defender_boxes = _defender._boxes
                  if not _defender_boxes or #_defender_boxes == 0 then
                     _defender_boxes = {}
                  end

                  local _box_type_matches = _box_type_match_attack
                  if
                     get_fdm(_player.char_str, _player.animation)
                     and get_fdm(_player.char_str, _player.animation).hit_throw
                  then
                     _box_type_matches = _box_type_match_attack_and_throw
                  end

                  if
                     tools.test_collision(
                        _defender.pos_x, _defender.pos_y, _defender.flip_x, _defender_boxes,
                        _player.pos_x, _player.pos_y, _player.flip_x, _player._boxes,
                        _box_type_matches
                     )
                  then
                     if not (_frames[_player.animation_frame + 1].bypass_freeze and _delta == 1) then
                        _delta = _delta + _player.remaining_freeze_frames
                     end

                     local _expected_hit = Pools.big:alloc()
                     _expected_hit._id = _player._id
                     _expected_hit._owner_id = _player._id
                     _expected_hit.blocking_type = "player"
                     _expected_hit.hit_id = _current_hit_id
                     _expected_hit._delta = _delta
                     _expected_hit.animation = _player.animation
                     _expected_hit.frame = _player.animation_frame
                     _expected_hit.flip_x = _player.flip_x
                     _expected_hit._side = _player._side
                     _gs.collisions[#_gs.collisions + 1] = _expected_hit
                  end
               end
            end
         end
      end
   end

   local _has_tengu_stones = false
   local _valid_projectiles = Pools.small:alloc()
   for _, _projectile in pairs(_gs.projectiles) do
      if _projectile.projectile_type == "72" then
         _valid_projectiles[#_valid_projectiles + 1] = _projectile
      elseif _projectile.projectile_type == "00_tenguishi" then
         if _projectile.remaining_freeze_frames + _projectile.cooldown == 0 then
            _valid_projectiles[#_valid_projectiles + 1] = _projectile
         end
      else
         if
            ((_projectile.is_forced_one_hit and _projectile.remaining_hits ~= 0xFF) or _projectile.remaining_hits > 0)
            and _projectile.alive
            and _projectile.projectile_type ~= "00_seieienbu"
         then
            local _defender = _gs.player_objects[_projectile.emitter_id].other
            if
               _projectile.emitter_id ~= _defender._id
               or (_projectile.emitter_id == _defender._id and _projectile.is_converted)
            then
               local _bypass_freeze = _projectile._animation_frame_data
                  and _projectile._animation_frame_data.frames
                  and _projectile._animation_frame_data.frames[_projectile.animation_frame + 1]
                  and _projectile._animation_frame_data.frames[_projectile.animation_frame + 1].bypass_freeze
               if
                  _gs.frame_number >= _projectile.animation_start_frame
                  and (_projectile.remaining_freeze_frames + _projectile.cooldown == 0 or _bypass_freeze)
               then
                  _valid_projectiles[#_valid_projectiles + 1] = _projectile
               end
            end
         end
      end
   end

   for _, _projectile in pairs(_valid_projectiles) do
      local _box_type_matches = _box_type_match_attack
      local _delta = _gs.frame_number - frame_number
      local _is_first_hit_frame = false
      if _projectile.projectile_type == "00_tenguishi" then
         _has_tengu_stones = true
         _box_type_matches = _box_type_match_tengu
      elseif _projectile.projectile_type == "seieienbu" then
         _is_first_hit_frame = false
      else
         if
            _projectile.animation_frame == _fd.get_first_hit_frame("projectiles", _projectile.projectile_type)
            and not _first_hit_frame_exceptions[_projectile.projectile_type]
         then
            _is_first_hit_frame = true
         end
      end
      local _owner_id = _projectile.emitter_id
      if _projectile.is_converted then
         _owner_id = _projectile.emitter_id == 1 and 2 or 1
      end
      local _defender = _gs.player_objects[_owner_id].other
      local _defender_boxes = _defender._boxes
      if not _defender_boxes or #_defender_boxes == 0 then
         _defender_boxes = {}
      end

      if #_projectile._boxes > 0 and not _is_first_hit_frame then
         if
            tools.test_collision(
               _defender.pos_x, _defender.pos_y, _defender.flip_x, _defender_boxes,
               _projectile.pos_x, _projectile.pos_y, _projectile.flip_x, _projectile._boxes,
               _box_type_matches
            )
         then
            local _side = _gs.player_objects[_owner_id]._side
            local _expected_hit = Pools.big:alloc()
            _expected_hit._id = _projectile._id
            _expected_hit._owner_id = _owner_id
            _expected_hit.blocking_type = "projectile"
            _expected_hit.hit_id = 1
            _expected_hit._delta = _delta
            _expected_hit.animation = _projectile.animation
            _expected_hit.frame = _projectile.animation_frame
            _expected_hit.flip_x = _projectile.flip_x
            _expected_hit._side = _side
            if _projectile.projectile_type == "00_tenguishi" then
               _expected_hit.tengu_order = _projectile.tengu_order
               _projectile.cooldown = 99
            elseif _projectile.seiei_animation then
               _expected_hit.hit_id = _projectile.seiei_hit_id
               _expected_hit.is_seieienbu = true
            end
            _projectile.has_just_connected = true
            _gs.collisions[#_gs.collisions + 1] = _expected_hit
         end
      end
   end

   if _has_tengu_stones then
      local _current_attack
      for _, attack in ipairs(_gs.collisions) do
         if attack.blocking_type == "player" then
            _current_attack = attack
            break
         elseif attack.tengu_order then
            if not _current_attack or attack.tengu_order < _current_attack.tengu_order then
               _current_attack = attack
            end
         end
      end
      local _i = 1
      while _i <= #_gs.collisions do
         local attack = _gs.collisions[_i]
         if attack.animation == "00_tenguishi" and attack ~= _current_attack then
            table.remove(_gs.collisions, _i)
         else
            _i = _i + 1
         end
      end
   end
end

-- ── Batch 8: apply_pushback, update_sides, check_side_switch, new_gamestate ──

local function apply_pushback(_gs)
   local _stage = { left = _stage_boundaries.left, right = _stage_boundaries.right }

   local _pushboxes = Pools.small:alloc()
   for _, _player in ipairs(_gs.player_objects) do
      if _player._boxes then
         local _boxes = tools.get_boxes(_player._boxes, tools.BOXES.PUSH, nil, Pools.small:alloc())
         if #_boxes > 0 then
            _pushboxes[_player._id] = _boxes[1]
         end
      end
      if not _pushboxes[_player._id] then
         _pushboxes[_player._id] = tools.get_pushboxes(_player)
      end
   end

   if _pushboxes[1] and _pushboxes[2] then
      _pushboxes[1] = tools.format_box(_pushboxes[1], nil, Pools.small:alloc())
      _pushboxes[2] = tools.format_box(_pushboxes[2], nil, Pools.small:alloc())

      local _overlap = get_horizontal_box_overlap(
         _pushboxes[1], math.floor(_gs.P1.pos_x), math.floor(_gs.P1.pos_y), _gs.P1.flip_x,
         _pushboxes[2], math.floor(_gs.P2.pos_x), math.floor(_gs.P2.pos_y), _gs.P2.flip_x
      )

      if _overlap > 1 then
         local _cspec1 = character_specific[_gs.P1.char_str] or {}
         local _cspec2 = character_specific[_gs.P2.char_str] or {}
         local _push_value_max = math.ceil(((_cspec1.push_value or 0) + (_cspec2.push_value or 0)) / 2)
         local _dist_from_pb_center = math.abs(_gs.P1.pos_x - _gs.P2.pos_x)
         local _pushbox_overlap_range = (_pushboxes[1].width + _pushboxes[2].width) / 2
         local _push_value = get_push_value(_dist_from_pb_center, _pushbox_overlap_range, _push_value_max)

         local _sign = (math.floor(_gs.P2.pos_x) - math.floor(_gs.P1.pos_x) >= 0 and -1)
            or (math.floor(_gs.P2.pos_x) - math.floor(_gs.P1.pos_x) < 0 and 1)
         _gs.P1.pos_x = _gs.P1.pos_x + _push_value * _sign
         _gs.P2.pos_x = _gs.P2.pos_x - _push_value * _sign

         for _, _player in ipairs(_gs.player_objects) do
            local _cspec = character_specific[_player.char_str] or {}
            local _corner_left = _stage.left + (_cspec.corner_offset_left or 0)
            local _corner_right = _stage.right - (_cspec.corner_offset_right or 0)
            if _player.pos_x > _corner_right then
               local _mantissa = _player.pos_x - math.floor(_player.pos_x)
               _player.pos_x = _corner_right + _mantissa
            elseif _player.pos_x < _corner_left then
               local _mantissa = _player.pos_x - math.floor(_player.pos_x)
               _player.pos_x = _corner_left + _mantissa
            end
         end
      end
   end

   if not _gs.previous_gamestate then
      return
   end
   for _, _player in ipairs(_gs.player_objects) do
      if _gs.previous_gamestate[_player.other._prefix].is_in_air_recovery then
         local _cspec = character_specific[_player.other.char_str] or {}
         local _corner_left = _stage.left + (_cspec.corner_offset_left or 0)
         local _corner_right = _stage.right - (_cspec.corner_offset_right or 0)
         if
            (tools.trunc(_player.other.pos_x) == _corner_left or tools.trunc(_player.other.pos_x) == _corner_right)
            and math.abs(_player.other.pos_x - _player.pos_x) < 79
         then
            local _sign = tools.sign(_player.other.pos_x - _player.pos_x)
            if _sign == 1 then
               _player.pos_x = math.max(_player.pos_x - 4.5, _player.other.pos_x - 79)
            else
               _player.pos_x = math.min(_player.pos_x + 4.5, _player.other.pos_x + 79)
            end
         end
      end
   end
end

local function update_sides(_gs)
   for _, _player in ipairs(_gs.player_objects) do
      _player._side = get_side_local(_player.pos_x, _player.other.pos_x)
   end
end

local function check_side_switch(_gs)
   for _, _player in ipairs(_gs.player_objects) do
      if _player.character_state_byte ~= 4 then
         local _previous_dist = math.floor(_player.other.previous_pos_x) - math.floor(_player.previous_pos_x)
         local dist = math.floor(_player.other.pos_x) - math.floor(_player.pos_x)
         if tools.sign(_previous_dist) ~= tools.sign(dist) and dist ~= 0 then
            _player.switched_sides = true
         end
         if (_player._side == 1 and _player.flip_x ~= 1) or (_player._side == 2 and _player.flip_x ~= 0) then
            _player.should_turn = true
         end
      end
   end
end

local function new_gamestate(_base_gs)
   local _result = Pools.big:alloc()
   local player_objects = Pools.small:alloc()
   local projectiles = Pools.small:alloc()
   for _i, _player in ipairs(_base_gs.player_objects) do
      player_objects[_player._id] = Pools.big:alloc()
      local _np = player_objects[_player._id]
      _np._id = _player._id
      _np.base = _player.base
      _np._prefix = _player._prefix
      _np.type = _player.type
      _np.input = _player.input
      _np.char_str = _player.char_str
      _np._side = _player._side
      _np.selected_sa = _player.selected_sa
      _np.flip_x = _player.flip_x
      _np.previous_pos_x = _player.previous_pos_x
      _np.previous_pos_y = _player.previous_pos_y
      _np.pos_x = _player.pos_x
      _np.pos_y = _player.pos_y
      _np.velocity_x = _player.velocity_x
      _np.velocity_y = _player.velocity_y
      _np.acceleration_x = _player.acceleration_x
      _np.acceleration_y = _player.acceleration_y
      _np._boxes = copytable(_player._boxes)
      _np.remaining_freeze_frames = _player.remaining_freeze_frames
      _np.freeze_just_began = _player.freeze_just_began
      _np.freeze_just_ended = _player.freeze_just_ended
      _np.movement_type = _player.movement_type
      _np.movement_type2 = _player.movement_type2
      _np.is_standing = _player.is_standing
      _np.is_crouching = _player.is_crouching
      _np.is_airborne = _player.is_airborne
      _np.is_being_thrown = _player.is_being_thrown
      _np.is_in_air_recovery = _player.is_in_air_recovery
      _np.is_in_air_reel = _player.is_in_air_reel
      _np.is_blocking = _player.is_blocking
      _np.throw_countdown = _player.throw_countdown
      _np.animation = _player.animation
      _np.animation_frame = _player.animation_frame
      _np.animation_frame_hash = _player.animation_frame_hash
      _np._animation_frame_data = _player._animation_frame_data
      _np.animation_freeze_frames = _player.animation_freeze_frames
      _np.has_animation_just_changed = _player.has_animation_just_changed
      _np.character_state_byte = _player.character_state_byte
      _np.posture = _player.posture
      _np.posture_ext = _player.posture_ext
      _np.standing_state = _player.standing_state
      _np.is_in_pushback = _player.is_in_pushback
      _np.pushback_start_frame = _player.pushback_start_frame
      _np._recovery_time = _player._recovery_time
      _np.previous_recovery_time = _player.previous_recovery_time
      _np.additional_recovery_time = _player.additional_recovery_time
      _np.ends_recovery_next_frame = _player.ends_recovery_next_frame
      _np.remaining_wakeup_time = _player.remaining_wakeup_time
      _np._current_hit_id = _player._current_hit_id
      _np.animation_miss_count = _player.animation_miss_count
      _np.animation_connection_count = _player.animation_connection_count
      _np.connected_action_count = _player.connected_action_count
      _np.action_count = _player.action_count
      _np.action = _player.action
      _np.cooldown = _player.cooldown
      _np.has_just_connected = _player.has_just_connected
      _np.last_received_connection_animation = _player.last_received_connection_animation
      _np.last_received_connection_hit_id = _player.last_received_connection_hit_id
   end
   for _key, _projectile in pairs(_base_gs.projectiles) do
      projectiles[_key] = Pools.big:alloc()
      local _np = projectiles[_key]
      _np._id = _projectile._id
      _np.base = _projectile.base
      _np.emitter_id = _projectile.emitter_id
      _np.projectile_type = _projectile.projectile_type
      _np.projectile_start_type = _projectile.projectile_start_type
      _np.flip_x = _projectile.flip_x
      _np.previous_pos_x = _projectile.previous_pos_x
      _np.previous_pos_y = _projectile.previous_pos_y
      _np.pos_x = _projectile.pos_x
      _np.pos_y = _projectile.pos_y
      _np.velocity_x = _projectile.velocity_x
      _np.velocity_y = _projectile.velocity_y
      _np.acceleration_x = _projectile.acceleration_x
      _np.acceleration_y = _projectile.acceleration_y
      _np._boxes = copytable(_projectile._boxes)
      _np.remaining_freeze_frames = _projectile.remaining_freeze_frames
      _np.freeze_just_began = _projectile.freeze_just_began
      _np.is_forced_one_hit = _projectile.is_forced_one_hit
      _np.lifetime = _projectile.lifetime
      _np.remaining_lifetime = _projectile.remaining_lifetime
      _np.has_activated = _projectile.has_activated
      _np.animation_start_frame = _projectile.animation_start_frame
      _np.animation_freeze_frames = _projectile.animation_freeze_frames
      _np.cooldown = _projectile.cooldown
      _np.tengu_order = _projectile.tengu_order
      _np.alive = _projectile.alive
      _np.is_placeholder = _projectile.is_placeholder
      _np.expired = _projectile.expired
      _np.is_converted = _projectile.is_converted
      _np.remaining_hits = _projectile.remaining_hits
      _np.animation = _projectile.animation
      _np.animation_frame = _projectile.animation_frame
      _np._animation_frame_data = _projectile._animation_frame_data
   end
   _result.P1 = player_objects[1]
   _result.P2 = player_objects[2]
   _result.player_objects = player_objects
   _result.projectiles = projectiles
   _result._stage = _base_gs._stage
   _result.frame_number = _base_gs.frame_number
   _result.screen_x = _base_gs.screen_x
   _result.screen_y = _base_gs.screen_y
   return _result
end

-- ── Batch 9: next_frames, copy_gamestate, next_gamestates ────────────────────

local function next_frames(_obj, _gs, _animation_options)
   local _results = Pools.small:alloc()
   local _fdata
   if _obj.type == "player" then
      _fdata = find_move_frame_data(_obj.char_str, _obj.animation)
   else
      _fdata = find_move_frame_data("projectiles", _obj.animation)
   end
   if not _fdata then
      local _result = Pools.small:alloc()
      _result[1] = Pools.small:alloc()
      _result[1].animation = _obj.animation
      _result[1].frame = _obj.animation_frame
      return _result
   end
   local _max_frames = _fdata.frames and #_fdata.frames or 1
   local _frame_to_check = math.min(_obj.animation_frame + 1, _max_frames)
   local _used_next_anim = false
   if _fdata and _frame_to_check <= #_fdata.frames and _fdata.frames[_frame_to_check] then
      if _fdata.frames[_frame_to_check].loop then
         local _result = Pools.small:alloc()
         _result.animation = _obj.animation
         _result.frame = _fdata.frames[_frame_to_check].loop
         _result.frame_data = _fdata
         _results[#_results + 1] = _result
      else
         if _fdata.frames[_frame_to_check].wakeup then
            local _pfd = frame_data[_obj.char_str] or {}
            local _result = Pools.small:alloc()
            _result.animation = _pfd.standing or _obj.animation
            _result.frame = 0
            _results[#_results + 1] = _result
         else
            for _, _na in pairs(_next_anim_types) do
               if _fdata.frames[_frame_to_check][_na] then
                  local _should_check = true
                  if _na == "optional_anim" then
                     if
                        _animation_options
                        and _animation_options[_obj._id]
                        and _animation_options[_obj._id].ignore_optional_anim
                     then
                        _should_check = false
                     end
                  elseif _na == "next_anim" then
                     _used_next_anim = true
                  end
                  if _should_check then
                     for __, _next_anim in pairs(_fdata.frames[_frame_to_check][_na]) do
                        local _next_anim_anim = _next_anim[1]
                        local _next_anim_frame = _next_anim[2]
                        if _animation_options and _animation_options[_obj._id] and _animation_options[_obj._id]._next_anim then
                           if _animation_options[_obj._id]._next_anim[_obj.animation] then
                              _next_anim_anim = _animation_options[_obj._id]._next_anim[_obj.animation].animation
                              _next_anim_frame = _animation_options[_obj._id]._next_anim[_obj.animation].frame
                           end
                        else
                           if _next_anim_anim == "idle" then
                              local _pfd = frame_data[_obj.char_str] or {}
                              if _obj.posture == 32 then
                                 _next_anim_anim = _pfd.crouching or _obj.animation
                                 _next_anim_frame = 0
                              else
                                 _next_anim_anim = _pfd.standing or _obj.animation
                                 _next_anim_frame = 0
                              end
                           end
                        end
                        local _result = Pools.small:alloc()
                        _result.animation = _next_anim_anim
                        _result.frame = _next_anim_frame
                        _results[#_results + 1] = _result
                     end
                  end
               end
            end
         end
      end
   end
   if not _used_next_anim or #_results == 0 then
      local _result = Pools.small:alloc()
      _result.animation = _obj.animation
      _result.frame = math.min(_obj.animation_frame + 1, _max_frames - 1)
      _result.frame_data = _fdata
      _results[#_results + 1] = _result
   end
   return _results
end

local _player_copy_reference_keys = { "other", "_animation_frame_data", "_boxes", "input" }
local _gs_copy_exclude_keys = { player_objects = true, projectiles = true, collisions = true, previous_gamestate = true }
local _proj_copy_exclude_props = { _animation_frame_data = true }

local function copy_gamestate(_gs)
   local _temp_players = Pools.small:alloc()
   _temp_players.P1 = Pools.small:alloc()
   _temp_players.P2 = Pools.small:alloc()
   for _id, _player in ipairs(_gs.player_objects) do
      for _, _key in ipairs(_player_copy_reference_keys) do
         _temp_players[_player._prefix][_key] = _player[_key]
         _player[_key] = nil
      end
   end

   local next_gs = tools.tempcopy(_gs, Pools.big, _gs_copy_exclude_keys)

   for _prefix, _data in pairs(_temp_players) do
      for _key, _value in pairs(_data) do
         _gs[_prefix][_key] = _value
         next_gs[_prefix][_key] = _value
      end
   end

   next_gs.player_objects = Pools.small:alloc()
   next_gs.player_objects[1] = next_gs.P1
   next_gs.player_objects[2] = next_gs.P2
   next_gs.P1.other = next_gs.P2
   next_gs.P2.other = next_gs.P1
   next_gs.projectiles = tools.tempcopy(_gs.projectiles, Pools.big, _proj_copy_exclude_props)

   return next_gs
end

local function next_gamestates(_gs, _animation_options)
   local _next_states = Pools.small:alloc()
   local _next_frames_list = Pools.small:alloc()

   local _start_gs = copy_gamestate(_gs)
   _start_gs.previous_gamestate = _gs

   update_variables(_start_gs)

   for _id, _player in ipairs(_start_gs.player_objects) do
      if _animation_options and _animation_options[_id] and _animation_options[_id].set then
         _next_frames_list[_id] = Pools.small:alloc()
         _next_frames_list[_id][1] = Pools.small:alloc()
         _next_frames_list[_id][1].animation = _animation_options[_id].set.animation
         _next_frames_list[_id][1].frame = _animation_options[_id].set.frame
      else
         local _bypass_freeze = _player._animation_frame_data
            and _player._animation_frame_data.frames
            and _player._animation_frame_data.frames[_player.animation_frame + 1]
            and _player._animation_frame_data.frames[_player.animation_frame + 1].bypass_freeze
         if (_player.remaining_freeze_frames == 0 and not _player.freeze_just_ended) or _bypass_freeze then
            _next_frames_list[_id] = next_frames(_player, _start_gs, _animation_options)
         else
            _next_frames_list[_id] = Pools.small:alloc()
            _next_frames_list[_id][1] = Pools.small:alloc()
            _next_frames_list[_id][1].animation = _player.animation
            _next_frames_list[_id][1].frame = _player.animation_frame
            _next_frames_list[_id][1].frame_data = _player._animation_frame_data
         end
      end
   end

   local _next_projectiles = Pools.small:alloc()
   for _id, _projectile in pairs(_start_gs.projectiles) do
      local _animation_frame_data = _projectile._animation_frame_data
      local _next_proj = tools.tempcopy(_projectile, Pools.big, _proj_copy_exclude_props)
      _next_proj._animation_frame_data = _animation_frame_data
      if not (_next_proj.projectile_type == "seieienbu" or _next_proj.projectile_type == "00_tenguishi") then
         local _bypass_freeze = _next_proj._animation_frame_data
            and _next_proj._animation_frame_data.frames
            and _next_proj._animation_frame_data.frames[_next_proj.animation_frame + 1]
            and _next_proj._animation_frame_data.frames[_next_proj.animation_frame + 1].bypass_freeze
         if _next_proj.remaining_freeze_frames == 0 or _bypass_freeze then
            local _next_frame = next_frames(_next_proj, _start_gs)[1]
            update_frame_data(_start_gs, _next_proj, _next_frame)
         end
      end
      _next_projectiles[_id] = _next_proj
   end

   for _i, _p1_nf in ipairs(_next_frames_list[1]) do
      for _j, _p2_nf in ipairs(_next_frames_list[2]) do
         local next_gs = copy_gamestate(_start_gs)
         next_gs.previous_gamestate = _start_gs
         next_gs.projectiles = _next_projectiles
         update_frame_data(next_gs, next_gs.P1, _p1_nf)
         update_frame_data(next_gs, next_gs.P2, _p2_nf)
         _next_states[#_next_states + 1] = next_gs
      end
   end

   for _i, next_gs in ipairs(_next_states) do
      update_turn(next_gs)
      move_players(next_gs)
      move_projectiles(next_gs)
      update_sides(next_gs)
      check_collisions(next_gs)
      apply_pushback(next_gs)
      check_side_switch(next_gs)
   end

   return _next_states
end

-- ── Batch 10: simulate_gamestates, predict_hits, predict_gamestate ────────────

local function simulate_gamestates(_gs, _animation_options, _frames_prediction)
   local _start_states = next_gamestates(_gs, _animation_options)
   local _predicted_states = Pools.small:alloc()
   _predicted_states[1] = _start_states
   if _animation_options then
      if _animation_options[1] and _animation_options[1].set then
         _animation_options[1].set = nil
      end
      if _animation_options[2] and _animation_options[2].set then
         _animation_options[2].set = nil
      end
   end
   for _i = 2, _frames_prediction do
      _predicted_states[_i] = Pools.small:alloc()
      for _j, _state in ipairs(_predicted_states[_i - 1]) do
         local _next_gs_list = next_gamestates(_state, _animation_options)
         for _k, next_gs in ipairs(_next_gs_list) do
            table.insert(_predicted_states[_i], next_gs)
         end
      end
   end
   return _predicted_states
end

local function predict_hits(_gs, _animation_options, _frames_prediction)
   local _results = Pools.small:alloc()
   _gs = _gs or new_gamestate(gamestate)
   if _frames_prediction == 0 then
      return _results
   end
   if next_animation[1] ~= _animations.NONE then
      if not _animation_options or not (_animation_options[1] and _animation_options[1].set) then
         if not _animation_options then _animation_options = Pools.small:alloc() end
         if not _animation_options[1] then _animation_options[1] = Pools.small:alloc() end
         _animation_options[1].set = Pools.small:alloc()
         _animation_options[1].set.animation = get_next_animation(_gs.P1, next_animation[1])
         _animation_options[1].set.frame = 0
      end
   end
   if next_animation[2] ~= _animations.NONE then
      if not _animation_options or not (_animation_options[2] and _animation_options[2].set) then
         if not _animation_options then _animation_options = Pools.small:alloc() end
         if not _animation_options[2] then _animation_options[2] = Pools.small:alloc() end
         _animation_options[2].set = Pools.small:alloc()
         _animation_options[2].set.animation = get_next_animation(_gs.P2, next_animation[2])
         _animation_options[2].set.frame = 0
      end
   end
   local _predicted_states = simulate_gamestates(_gs, _animation_options, _frames_prediction)
   for _i, _state_list in ipairs(_predicted_states) do
      for _j, _state in ipairs(_state_list) do
         for _, _hit in ipairs(_state.collisions) do
            if not _results[_hit._delta] then
               _results[_hit._delta] = Pools.small:alloc()
            end
            table.insert(_results[_hit._delta], _hit)
         end
      end
   end
   return _results
end

local function predict_gamestate(_gs, _animation_options, _frames_prediction)
   _gs = _gs or new_gamestate(gamestate)
   if _frames_prediction == 0 then
      return _gs
   end
   if next_animation[1] ~= _animations.NONE then
      if not _animation_options or not (_animation_options[1] and _animation_options[1].set) then
         if not _animation_options then _animation_options = Pools.small:alloc() end
         if not _animation_options[1] then _animation_options[1] = Pools.small:alloc() end
         _animation_options[1].set = { animation = get_next_animation(_gs.P1, next_animation[1]), frame = 0 }
      end
   end
   if next_animation[2] ~= _animations.NONE then
      if not _animation_options or not (_animation_options[2] and _animation_options[2].set) then
         if not _animation_options then _animation_options = Pools.small:alloc() end
         if not _animation_options[2] then _animation_options[2] = Pools.small:alloc() end
         _animation_options[2].set = { animation = get_next_animation(_gs.P2, next_animation[2]), frame = 0 }
      end
   end
   if not _animation_options then _animation_options = Pools.small:alloc() end
   if not _animation_options[1] then _animation_options[1] = Pools.small:alloc() end
   if not _animation_options[2] then _animation_options[2] = Pools.small:alloc() end
   _animation_options[1].ignore_optional_anim = true
   _animation_options[2].ignore_optional_anim = true

   local _predicted_states = simulate_gamestates(_gs, _animation_options, _frames_prediction)
   return _predicted_states[#_predicted_states][1]
end

-- ── Gamestate adapter ────────────────────────────────────────────────────────

local function make_player_gs(_p)
  return {
    pos_x = _p.pos_x,
    pos_y = _p.pos_y,
    flip_x = _p.flip_x,
    velocity_x = _p.velocity_x or 0,
    velocity_y = _p.velocity_y or 0,
    acceleration_x = _p.acceleration_x or 0,
    acceleration_y = _p.acceleration_y or 0,
    animation = _p.animation,
    animation_frame = _p.animation_frame,
    animation_frame_hash = _p.animation_frame_hash,
    _animation_frame_data = _p.animation_frame_data,
    remaining_freeze_frames = _p.remaining_freeze_frames or 0,
    freeze_just_began = false,
    freeze_just_ended = false,
    char_str = _p.char_str,
    char_id = _p.char_id,
    _id = _p._id,
    _prefix = _p.prefix,
    _boxes = _p.boxes,
    posture = _p.posture,
    posture_ext = _p.posture_ext,
    standing_state = _p.standing_state,
    is_standing = (_p.standing_state == 1),
    is_crouching = (_p.standing_state == 2),
    is_airborne = (_p.standing_state == 4),
    is_blocking = _p.is_blocking or false,
    movement_type = _p.movement_type,
    movement_type2 = _p.movement_type2,
    action = _p.action,
    action_count = _p.action_count or 0,
    throw_countdown = _p.throw_countdown or 0,
    is_being_thrown = _p.is_being_thrown or false,
    remaining_wakeup_time = _p.remaining_wakeup_time or 0,
    _recovery_time = _p.recovery_time or 0,
    selected_sa = _p.selected_sa or 1,
    -- effie3rd-specific fields defaulted
    is_in_pushback = false,
    pushback_start_frame = 0,
    is_in_air_recovery = false,
    is_in_air_reel = false,
    _current_hit_id = 0,
    connected_action_count = 0,
    has_just_connected = false,
    animation_connection_count = 0,
    has_animation_just_changed = _p.has_animation_just_changed or false,
    additional_recovery_time = 0,
    ends_recovery_next_frame = false,
    previous_recovery_time = 0,
    cooldown = 0,
  }
end

local function make_gs(player1, player2)
  local _gs = {}
  _gs.frame_number = frame_number
  _gs.screen_x = screen_x or 0
  _gs.screen_y = screen_y or 0
  _gs.projectiles = {}
  _gs._stage = 1

  local _p1 = make_player_gs(player1)
  local _p2 = make_player_gs(player2)
  _p1._id = 1
  _p2._id = 2
  _gs.player_objects = {_p1, _p2}
  _gs.P1 = _p1
  _gs.P2 = _p2
  if _p1._prefix then _gs[_p1._prefix] = _p1 end
  if _p2._prefix then _gs[_p2._prefix] = _p2 end

  return _gs
end

-- ── Public API ───────────────────────────────────────────────────────────────

function prediction.predict_hits(_player1, _player2, _frames_prediction)
  local _gs = make_gs(_player1, _player2)
  return predict_hits(_gs, nil, _frames_prediction or 3)
end

function prediction.predict_gamestate(_player1, _player2, _frames_prediction)
  local _gs = make_gs(_player1, _player2)
  return predict_gamestate(_gs, nil, _frames_prediction or 3)
end

function prediction.get_frame_advantage(_player_obj)
  return get_frame_advantage(make_player_gs(_player_obj))
end

function prediction.predict_frames_before_landing(_player_obj)
  return predict_frames_before_landing(make_player_gs(_player_obj))
end

return prediction
