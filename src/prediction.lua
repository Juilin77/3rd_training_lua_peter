-- src/prediction.lua
-- 進階預測函數，補強 predict_hitboxes() 無法處理的情況

local ok, prediction_module = pcall(require, "src/data/prediction")
if not ok then prediction_module = nil end

function predict_hits_simulation(_attacker, _defender, _frames, _last_hit_id)
  -- 先試新的物理模擬（effie3rd prediction module）
  if prediction_module then
    local _ok, _new_hits = pcall(function()
      return prediction_module.predict_hits(_attacker, _defender, _frames)
    end)
    if _ok and _new_hits then
      local _result = {}
      for _delta = 1, _frames do
        local _hits_at_delta = _new_hits[_delta]
        if _hits_at_delta and #_hits_at_delta > 0 then
          local _h = _hits_at_delta[1]
          _result[_delta] = {
            delta  = _delta,
            frame  = _h.frame or ((_attacker.relevant_animation_frame or 0) + _delta),
            hit_id = (_h.hit_id and _h.hit_id > 0) and _h.hit_id or ((_last_hit_id or 0) + 1),
            pos_x  = _attacker.pos_x,
            pos_y  = _attacker.pos_y,
          }
          return _result  -- 找到第一個 hit 就回傳
        end
      end
      -- 新模組沒找到，fallback
    end
  end

  -- Fallback：舊的 simulate_hit_collision
  return simulate_hit_collision(_attacker, _defender, _frames, _last_hit_id)
end
