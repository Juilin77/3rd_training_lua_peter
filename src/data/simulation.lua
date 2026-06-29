-- src/data/simulation.lua
-- physics simulation core, used for sub-frame blocking fallback
-- used when predict_hitboxes() cannot find frame data (sub-frame animations)
-- depends on globals: predict_object_position(), test_collision(), predict_hurtboxes()
-- depends on globals: frame_data, frame_data_meta

-- returns true if any box in the set is of attack type
function sim_has_attack_boxes(_boxes)
  if not _boxes then return false end
  for _, _box in ipairs(_boxes) do
    if _box.type == "attack" or _box.type == "throw" then
      return true
    end
  end
  return false
end

-- get hit_frames for an animation from frame_data; return the last hit_frame max
local function get_last_hit_frame(_char_str, _animation)
  local _fd = frame_data[_char_str] and frame_data[_char_str][_animation]
  if not _fd or not _fd.hit_frames then return nil end
  local _last = 0
  for _, _hf in ipairs(_fd.hit_frames) do
    local _v = type(_hf) == "number" and _hf or (_hf.max or 0)
    if _v > _last then _last = _v end
  end
  return _last
end

-- calculate hit_id: derive which hit index the current frame belongs to from hit_frames
local function get_next_hit_id(_char_str, _animation, _current_hit_id)
  local _fd = frame_data[_char_str] and frame_data[_char_str][_animation]
  if not _fd or not _fd.hit_frames then return _current_hit_id + 1 end
  return math.min(_current_hit_id + 1, #_fd.hit_frames)
end

-- simulate N frames; return hits table (index = delta frames from now)
-- strategy: for sub-frame animations not in frame_data, use attacker's current live boxes from RAM
--      predict attacker and defender positions, test collision
-- _attacker: player object (attacking side)
-- _defender: player object (defending side / dummy)
-- _frames_prediction: how many frames to simulate ahead (typically 3)
-- _last_hit_id: _dummy.blocking.last_attack_hit_id
function simulate_hit_collision(_attacker, _defender, _frames_prediction, _last_hit_id)
  local _hits = {}

  -- only simulate when attacker has attack boxes (RAM has live attack boxes during sub-frame window)
  if not sim_has_attack_boxes(_attacker.boxes) then
    return _hits
  end

  local _box_type_matches = {{{"vulnerability", "ext. vulnerability"}, {"attack"}}}
  -- if hit_throw property is set, also test throw collision
  if frame_data_meta[_attacker.char_str]
    and frame_data_meta[_attacker.char_str].moves
    and frame_data_meta[_attacker.char_str].moves[_attacker.relevant_animation]
    and frame_data_meta[_attacker.char_str].moves[_attacker.relevant_animation].hit_throw then
    table.insert(_box_type_matches, {{"throwable"}, {"throw"}})
  end

  local _attacker_boxes = _attacker.boxes

  -- delta=0: already in contact this frame; skip position prediction, test collision directly
  local _defender_boxes_now = predict_hurtboxes(_defender, 0)
  if _defender_boxes_now and #_defender_boxes_now > 0 then
    if test_collision(
      _defender.pos_x, _defender.pos_y, _defender.flip_x, _defender_boxes_now,
      _attacker.pos_x, _attacker.pos_y, _attacker.flip_x, _attacker_boxes,
      _box_type_matches,
      0, 4, 0, 0
    ) then
      local _hit_id = get_next_hit_id(_attacker.char_str, _attacker.relevant_animation, _last_hit_id or 0)
      _hits[1] = {
        delta  = 1,  -- report as 1 even though detected now; gives 1 extra frame for input to take effect
        frame  = (_attacker.relevant_animation_frame or 0) + 1,
        hit_id = _hit_id,
        pos_x  = _attacker.pos_x,
        pos_y  = _attacker.pos_y,
      }
      return _hits
    end
  end

  -- simulate N frames
  for _i = 1, _frames_prediction do
    -- predict attacker position using existing velocity model
    local _attacker_pos = predict_object_position(_attacker, _i)

    -- predict defender position and hurtboxes
    local _defender_pos = predict_object_position(_defender, _i)
    local _defender_boxes = predict_hurtboxes(_defender, _i)

    -- use attacker's current boxes (live RAM data during sub-frame; not available in frame_data)

    if _defender_boxes and #_defender_boxes > 0 and _attacker_boxes and #_attacker_boxes > 0 then
      if test_collision(
        _defender_pos[1], _defender_pos[2], _defender.flip_x, _defender_boxes,
        _attacker_pos[1], _attacker_pos[2], _attacker.flip_x, _attacker_boxes,
        _box_type_matches,
        0, -- defender hurtbox dilation x
        4, -- defender hurtbox dilation y
        0, -- attacker hitbox dilation x
        0  -- attacker hitbox dilation y
      ) then
        local _hit_id = get_next_hit_id(_attacker.char_str, _attacker.relevant_animation, _last_hit_id or 0)
        _hits[_i] = {
          delta        = _i,
          frame        = (_attacker.relevant_animation_frame or 0) + _i,
          hit_id       = _hit_id,
          pos_x        = _attacker_pos[1],
          pos_y        = _attacker_pos[2],
        }
        break -- MVP: stop at first hit found
      end
    end
  end

  return _hits
end
