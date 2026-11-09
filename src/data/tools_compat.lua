-- src/data/tools_compat.lua
-- Completes the "stub for missing effie3rd modules" pattern already used inside
-- src/data/prediction.lua's own header (_fd/_move_data/_stage_boundaries/_debug_on) for the
-- 3 pieces that were assumed-global but never actually created: tools, Pools, copytable.
-- (win-codex PRE-review #28, round 5/6)
-- Must load before src/data/prediction.lua needs these globals.

-- Pools: effie3rd uses pooled table allocation (Frame_Table_Pool/Mempool) to cut GC pressure.
-- Confirmed via grep: our ported prediction.lua only ever calls :alloc(), never :free() -- the
-- reuse/pooling behavior itself is never exercised by our code paths, so a trivial non-pooling
-- stub is functionally equivalent (just without the GC-pressure optimization, which is a pure
-- perf concern in effie3rd's own design, not a correctness one).
local _fresh_table_pool = { alloc = function() return {} end }
Pools = {
  small = _fresh_table_pool,
  big = _fresh_table_pool,
  draw = _fresh_table_pool,
  temp = _fresh_table_pool,
}

-- copytable: not an effie3rd function at all (confirmed via repo-wide grep of effie3rd's own
-- source, no match) -- our port invented this name, used only for copying box-array fields.
-- Plain recursive table copy.
function copytable(_orig)
  if type(_orig) ~= "table" then return _orig end
  local _copy = {}
  for k, v in pairs(_orig) do
    _copy[copytable(k)] = copytable(v)
  end
  return _copy
end

tools = {}

function tools.sign(n) return n > 0 and 1 or (n == 0 and 0 or -1) end
function tools.round(n) return math.floor(n + 0.5) end
function tools.trunc(n) return n >= 0 and math.floor(n) or math.ceil(n) end
-- NOT effie3rd's own convention (flip_x==0 -> -1) -- our project's own convention is the
-- opposite, confirmed at blocking.lua's predict_hitboxes ("local _sign = 1; if flip_x ~= 0 then
-- _sign = -1 end"). Using effie3rd's convention here would reverse every position/movement
-- prediction (win-codex PRE-review #28, round 8, confirmed bug).
function tools.flip_to_sign(flip_x) return flip_x == 0 and 1 or -1 end

-- tempcopy: real recursive-copy-with-exclusion semantics (win-codex PRE-review #28, round 7 --
-- not just an alias to copytable, which has no _exclude support). Pool arg kept for call-site
-- signature compat but ignored, matching the trivial-alloc Pools stub above.
function tools.tempcopy(_orig, _pool, _exclude)
  if type(_orig) ~= "table" then return _orig end
  local _copy = {}
  for k, v in pairs(_orig) do
    if not (_exclude and _exclude[k]) then
      _copy[tools.tempcopy(k, _pool, _exclude)] = tools.tempcopy(v, _pool, _exclude)
    end
  end
  return _copy
end

-- is_pressing_down is verbatim-portable: our input table already uses the same
-- "prefix .. ' Down'" key convention (gamestate.lua's read_single_input). NOTE: the simulated
-- player objects built by make_gs/make_player_gs expose this as "_prefix" (underscore), not
-- "prefix" -- using the real player's field name here would silently read nil (win-codex
-- PRE-review #28, round 8).
function tools.is_pressing_down(player, input)
  return input[player._prefix .. " Down"]
end
function tools.is_pressing_up(player, input)
  return input[player._prefix .. " Up"]
end

-- is_pressing_forward/back: effie3rd gates on player.side (1/2, which side of the screen this
-- player is currently on, NOT which controller port). We don't store a .side field, but
-- prediction.lua's own simulation already computes and maintains the equivalent _side field
-- every simulated frame (get_side_local/update_sides, prediction.lua) -- read that directly
-- instead of porting a separate side-tracking mechanism.
function tools.is_pressing_forward(player, input)
  if player._side == 2 then
    return input[player._prefix .. " Left"]
  else
    return input[player._prefix .. " Right"]
  end
end
function tools.is_pressing_back(player, input)
  if player._side == 2 then
    return input[player._prefix .. " Right"]
  else
    return input[player._prefix .. " Left"]
  end
end

-- test_collision already exists as a project-wide global (src/framedata.lua) -- same parameter
-- list prediction.lua calls it with, just alias it.
tools.test_collision = test_collision

-- has_boxes/get_boxes/get_pushboxes/format_box: effie3rd's versions operate on *raw* RAM box
-- arrays (box[1] = numeric type code) and convert via get_box_type_string. Our boxes
-- (gamestate.lua's read_box) are already in named-field form (box.type as a string --
-- "push"/"attack"/"ext. vulnerability"/etc, box.left/width/bottom/height) -- the same shape
-- effie3rd's own format_box() *outputs*, not its raw input. So these need simplified rewrites
-- comparing box.type directly, not verbatim ports.
function tools.has_boxes(boxes, types)
  for _, box in pairs(boxes) do
    for _, t in pairs(types) do
      if box.type == t then return true end
    end
  end
  return false
end

function tools.get_boxes(boxes, types, _extended, out)
  local res = out or {}
  for _, box in pairs(boxes) do
    for _, t in pairs(types) do
      if box.type == t then
        res[#res + 1] = box
      end
    end
  end
  return res
end

function tools.get_pushboxes(player)
  for _, box in pairs(player._boxes or player.boxes or {}) do
    if box.type == "push" then
      return box
    end
  end
  return nil
end

function tools.format_box(box, _extended, out)
  if not box then return out or {} end
  local result = out or {}
  for k, v in pairs(box) do
    result[k] = v
  end
  return result
end

-- BOXES: only these two members are actually referenced in prediction.lua.
tools.BOXES = {
  PUSH = { "push" },
  ATTACK_AND_THROW = { "attack", "throw" },
}
