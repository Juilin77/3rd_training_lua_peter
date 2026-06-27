-- src/data/simulation.lua
-- 物理模擬核心，用於 sub-frame blocking fallback
-- 當 predict_hitboxes() 找不到 frame data（sub-frame 動畫）時使用
-- 依賴全域函數：predict_object_position(), test_collision(), predict_hurtboxes()
-- 依賴全域變數：frame_data, frame_data_meta

-- 判斷一組 boxes 裡是否有 attack 類型的 box
function sim_has_attack_boxes(_boxes)
  if not _boxes then return false end
  for _, _box in ipairs(_boxes) do
    if _box.type == "attack" or _box.type == "throw" then
      return true
    end
  end
  return false
end

-- 從 frame_data 裡取出某 animation 的 hit_frames 結構，回傳最後一個 hit_frame max
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

-- 計算 hit_id（從 hit_frames 結構推導出目前幀屬於第幾個 hit）
local function get_next_hit_id(_char_str, _animation, _current_hit_id)
  local _fd = frame_data[_char_str] and frame_data[_char_str][_animation]
  if not _fd or not _fd.hit_frames then return _current_hit_id + 1 end
  return math.min(_current_hit_id + 1, #_fd.hit_frames)
end

-- N 幀模擬，回傳 hits table（index = delta，即從現在算第幾幀後命中）
-- 策略：對 sub-frame 動畫（frame_data 查不到），直接用 attacker 當前的 boxes（從 RAM 讀到的）
--      預測 attacker 和 defender 的位置，測試碰撞
-- _attacker: player 物件（攻擊方）
-- _defender: player 物件（防禦方/dummy）
-- _frames_prediction: 要往前模擬幾幀（通常 3）
-- _last_hit_id: _dummy.blocking.last_attack_hit_id
function simulate_hit_collision(_attacker, _defender, _frames_prediction, _last_hit_id)
  local _hits = {}

  -- 只在 attacker 有 attack box 時才模擬（sub-frame 期間 RAM 有 attack boxes）
  if not sim_has_attack_boxes(_attacker.boxes) then
    return _hits
  end

  local _box_type_matches = {{{"vulnerability", "ext. vulnerability"}, {"attack"}}}
  -- 如果有 hit_throw 特性，也加入投擲碰撞
  if frame_data_meta[_attacker.char_str]
    and frame_data_meta[_attacker.char_str].moves
    and frame_data_meta[_attacker.char_str].moves[_attacker.relevant_animation]
    and frame_data_meta[_attacker.char_str].moves[_attacker.relevant_animation].hit_throw then
    table.insert(_box_type_matches, {{"throwable"}, {"throw"}})
  end

  local _attacker_boxes = _attacker.boxes

  -- delta=0：當前幀就已接觸，不做位置預測，直接測碰撞
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
        delta  = 0,
        frame  = (_attacker.relevant_animation_frame or 0),
        hit_id = _hit_id,
        pos_x  = _attacker.pos_x,
        pos_y  = _attacker.pos_y,
      }
      return _hits
    end
  end

  -- 模擬 N 幀
  for _i = 1, _frames_prediction do
    -- 預測 attacker 位置（使用 Peter 版現有的速度模型）
    local _attacker_pos = predict_object_position(_attacker, _i)

    -- 預測 defender 位置與 hurtboxes
    local _defender_pos = predict_object_position(_defender, _i)
    local _defender_boxes = predict_hurtboxes(_defender, _i)

    -- 使用 attacker 當前 boxes（sub-frame 期間 RAM 即時資料，無法從 frame_data 查）

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
        break -- MVP：找到第一個 hit 就停
      end
    end
  end

  return _hits
end
