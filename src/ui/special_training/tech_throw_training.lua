-- src/ui/special_training/tech_throw_training.lua

function special_training_tech_throw_draw()
  if is_in_match and not training_settings.recording_mission_mode and special_training_mode[training_settings.special_training_current_mode] == "Tech Throw" then
    local _target = player
    local _gauge_x_scale = 4

    -- LP+LK input tracking
    local _raw_input = joypad.get()
    local _prefix = _target.prefix
    local _lplk = (_raw_input[_prefix .. " Weak Punch"] or false) and (_raw_input[_prefix .. " Weak Kick"] or false)
    local _just_lplk = _lplk and not throw_tech_disp.prev_lplk
    throw_tech_disp.prev_lplk = _lplk
    if _just_lplk then
      throw_tech_disp.last_lplk_frame = frame_number
    end

    -- Grab detection (rising edge of is_being_thrown)
    local _just_thrown = _target.is_being_thrown and not throw_tech_disp.prev_being_thrown
    throw_tech_disp.prev_being_thrown = _target.is_being_thrown

    -- Lower bar: forward/down parry validity (throw-invulnerable while active)
    throw_tech_disp.cooldown_time = math.max(
      _target.parry_forward and _target.parry_forward.validity_time or 0,
      _target.parry_down and _target.parry_down.validity_time or 0
    )

    if _just_thrown then
      throw_tech_disp.grab_frame = frame_number
      throw_tech_disp.armed = true
      throw_tech_disp.delta = nil
      throw_tech_disp.success = nil
      throw_tech_disp.parry_at_grab = throw_tech_disp.cooldown_time
      local _pre = throw_tech_disp.last_lplk_frame
      if _pre >= frame_number - 5 and _pre < frame_number then
        throw_tech_disp.pre_press_delta = _pre - frame_number
      else
        throw_tech_disp.pre_press_delta = nil
      end
      throw_tech_disp.frozen_x = nil  -- set during draw
      throw_tech_disp.frozen_y = nil
    end

    -- Window tracking
    if throw_tech_disp.armed then
      local _fi = frame_number - throw_tech_disp.grab_frame
      if throw_tech_disp.delta == nil then
        throw_tech_disp.validity_time = math.max(5 - _fi, 0)
      end

      if _just_lplk and throw_tech_disp.delta == nil then
        throw_tech_disp.delta = _fi
      end

      -- Use RAM action for success: handles pre-press (held LP+LK before throw) correctly.
      -- action 43 = defender tech, 44 = attacker tech. Propagates 1F after the tech frame.
      local _teched = _target.action == 43 or _target.action == 44
      if _teched then
        if throw_tech_disp.delta == nil then
          throw_tech_disp.delta = throw_tech_disp.pre_press_delta or 0
        end
        throw_tech_disp.success = true
        throw_tech_disp.armed = false
      elseif _fi >= 6 then
        if throw_tech_disp.delta == nil then
          throw_tech_disp.delta = throw_tech_disp.pre_press_delta or 5
        end
        throw_tech_disp.success = false
        throw_tech_disp.armed = false
      end
    end

    -- Draw parry-style gauge
    local _x = screen_width - 138 - get_text_width("Juggle: ")
    local _y = 82
    -- Follow Character for tech throw: not yet implemented; head position varies by character
    -- local _player = _target
    -- if not training_settings.special_training_follow_character then throw_tech_disp.frozen_x = nil end
    -- if training_settings.special_training_follow_character then
    --   if throw_tech_disp.frozen_x then
    --     _x = throw_tech_disp.frozen_x
    --     _y = throw_tech_disp.frozen_y
    --   else
    --     local _px = _player.pos_x - screen_x + emu.screenwidth()/2
    --     local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
    --     local _half_width = throw_tech_disp.max_cooldown * _gauge_x_scale / 2
    --     _x = _px - _half_width
    --     _x = math.max(_x, 4)
    --     _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
    --     local _push_height = 90
    --     for _, _box in ipairs(_player.boxes) do
    --       if _box.type == "push" then
    --         _push_height = _box.bottom + _box.height
    --         break
    --       end
    --     end
    --     _y = _py - _push_height - 16
    --     if throw_tech_disp.armed then
    --       throw_tech_disp.frozen_x = _x
    --       throw_tech_disp.frozen_y = _y
    --     end
    --   end
    -- end
    throw_tech_disp.name = "Tech Throw: "
    throw_tech_disp.name_color = nil
    draw_parry_gauge_group(_x, _y, throw_tech_disp, _gauge_x_scale)
    if throw_tech_disp.success == false then
      local _word
      if (throw_tech_disp.parry_at_grab or 0) > 0 then
        _word = "Parry Active"
      elseif throw_tech_disp.delta and throw_tech_disp.delta < 0 then
        _word = "Too Early"
      else
        _word = "Too Late"
      end
      gui.text(_x + 49, _y, _word, 0xE70000FF, text_default_border_color)
    elseif throw_tech_disp.success == true then
      gui.text(_x + 49, _y, "Success", 0x10FB00FF, text_default_border_color)
    end
  end
end
