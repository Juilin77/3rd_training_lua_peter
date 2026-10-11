-- src/control/tech_throw.lua
-- Dummy tech throw control.

-- 2026-10-11 Peter: simplified from a 3-way Never/Always/Random mode to a plain on/off
-- toggle -- dropped the Random variant, the dummy now either always techs or never does.
function update_tech_throws(_input, _attacker, _defender, _on)
  local _debug = false

  if not is_in_match or not _on then
    _defender.throw.listening = false
    if _debug and _attacker.previous_throw_countdown > 0 then
      print(string.format("%d - %s stopped listening for throws", frame_number, _defender.prefix))
    end
    return
  end

  if _attacker.throw_countdown > _attacker.previous_throw_countdown then
    _defender.throw.listening = true
    if _debug then
      print(string.format("%d - %s listening for throws", frame_number, _defender.prefix))
    end
  end

  if _attacker.throw_countdown == 0 then
    _defender.throw.listening = false
    if _debug and _attacker.previous_throw_countdown > 0  then
      print(string.format("%d - %s stopped listening for throws", frame_number, _defender.prefix))
    end
  end

  if _defender.throw.listening then

    if test_collision(
      _defender.pos_x, _defender.pos_y, _defender.flip_x, _defender.boxes, -- defender
      _attacker.pos_x, _attacker.pos_y, _attacker.flip_x, _attacker.boxes, -- attacker
      {{{"throwable"},{"throw"}}},
      0, -- defender hitbox dilation
      0
    ) then
      _defender.throw.listening = false
      if _debug then
        print(string.format("%d - %s teching throw", frame_number, _defender.prefix))
      end
      _input[_defender.prefix..' Weak Punch'] = true
      _input[_defender.prefix..' Weak Kick'] = true
    end
  end
end
