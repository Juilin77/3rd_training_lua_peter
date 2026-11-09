-- src/prediction.lua
-- advanced prediction: handles cases predict_hitboxes() cannot cover

local ok, prediction_module = pcall(require, "src/data/prediction")
if not ok then prediction_module = nil end

function predict_hits_simulation(_attacker, _defender, _frames, _last_hit_id)
  -- try new physics simulation first (effie3rd prediction module) -- but only when frame_data
  -- actually exists for the attacker's current animation. Without it the engine can never find a
  -- hit, so an empty result would be ambiguous ("genuinely no hit" vs "couldn't check at all") --
  -- known caller with no frame_data at all: blocking.lua's no-frame-data fallback branch
  -- (win-codex PRE-review #28, round 7, "unsupported simulation is not evidence of no collision")
  local _has_frame_data = frame_data[_attacker.char_str] and frame_data[_attacker.char_str][_attacker.relevant_animation]
  if prediction_module and _has_frame_data then
    local _ok, _new_hits = pcall(function()
      return prediction_module.predict_hits(_attacker, _defender, _frames, _last_hit_id)
    end)
    if _ok and _new_hits then
      for _delta = 1, _frames do
        local _hits_at_delta = _new_hits[_delta]
        if _hits_at_delta and #_hits_at_delta > 0 then
          -- the engine simulates both players (and projectiles) -- only accept a hit owned by
          -- the attacker's own simulation slot (always 1, since make_gs always puts the attacker
          -- in slot 1) and of melee/player type, not a stray defender or projectile collision
          -- (win-codex PRE-review #28, round 6/7: collision ownership was unfiltered)
          for _hi = 1, #_hits_at_delta do
            local _h = _hits_at_delta[_hi]
            if _h._owner_id == 1 and _h.blocking_type == "player" then
              return {
                [_delta] = {
                  delta  = _delta,
                  frame  = _h.frame or ((_attacker.relevant_animation_frame or 0) + _delta),
                  hit_id = (_h.hit_id and _h.hit_id > 0) and _h.hit_id or ((_last_hit_id or 0) + 1),
                  pos_x  = _attacker.pos_x,
                  pos_y  = _attacker.pos_y,
                }
              }
            end
          end
        end
      end
      -- new module ran cleanly with real frame_data and genuinely found nothing -- trust it,
      -- do not fall through to the legacy shortcut (that was the original bug: a flawed legacy
      -- "relabel the lingering previous hit" guess overriding a correct "no hit yet" answer)
      return {}
    end
  end

  -- fallback: legacy simulate_hit_collision -- reached only on pcall failure or genuinely no
  -- frame_data at all for this animation
  return simulate_hit_collision(_attacker, _defender, _frames, _last_hit_id)
end
