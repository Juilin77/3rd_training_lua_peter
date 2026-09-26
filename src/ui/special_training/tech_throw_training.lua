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

    if _just_thrown then
      throw_tech_disp.delta = nil
      throw_tech_disp.success = nil
    end

    -- Lower bar: forward/down parry validity (throw-invulnerable while active).
    -- Freezes the instant a result lands, same as validity_time below, instead
    -- of continuing to track live parry state after the outcome is already decided.
    if throw_tech_disp.delta == nil then
      throw_tech_disp.cooldown_time = math.max(
        _target.parry_forward and _target.parry_forward.validity_time or 0,
        _target.parry_down and _target.parry_down.validity_time or 0
      )
    end

    if _just_thrown then
      throw_tech_disp.grab_frame = frame_number
      throw_tech_disp.armed = true
      throw_tech_disp.parry_at_grab = throw_tech_disp.cooldown_time
      -- tracked over the wider early_press_tracking_window (not the narrower
      -- real valid window) purely so a genuinely too-early press can still be
      -- reported as "Too Early" below instead of defaulting to "Too Late"
      local _pre = throw_tech_disp.last_lplk_frame
      if _pre >= frame_number - throw_tech_disp.early_press_tracking_window and _pre < frame_number then
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
    throw_tech_disp.name = "Tech Throw: "
    throw_tech_disp.name_color = nil
    local _is_parry_active = throw_tech_disp.success == false and (throw_tech_disp.parry_at_grab or 0) > 0
    local _is_pre_press = throw_tech_disp.success == true and throw_tech_disp.delta and throw_tech_disp.delta < 0
    -- pointer on the lower (parry-validity) bar: only meaningful for the
    -- Parry Active failure, since a success means parry wasn't a factor at all
    throw_tech_disp.cooldown_marker = _is_parry_active and throw_tech_disp.cooldown_time or nil
    throw_tech_disp.cooldown_text_color = _is_parry_active and 0xE70000FF or nil
    -- signed frame count relative to the grab connecting (frame 0), matching
    -- Parry Mode's +N/-N convention: negative = pressed N frames before the
    -- grab (pre-press), positive = pressed N frames after (reactive), 0 = at
    -- the grab frame itself. Color (green/red) comes from success/miss
    -- automatically via draw_parry_gauge_group, this only controls the text.
    if throw_tech_disp.delta == nil then
      throw_tech_disp.ratio_text_override = nil
    elseif throw_tech_disp.delta > 0 then
      throw_tech_disp.ratio_text_override = string.format("+%d", throw_tech_disp.delta)
    else
      throw_tech_disp.ratio_text_override = string.format("%d", throw_tech_disp.delta)
    end
    draw_parry_gauge_group(_x, _y, throw_tech_disp, _gauge_x_scale)
    if throw_tech_disp.success == false then
      local _word
      if _is_parry_active then
        _word = "Parry Active"
      elseif throw_tech_disp.delta and throw_tech_disp.delta < 0 then
        _word = "Too Early"
      else
        _word = "Too Late"
      end
      gui.text(_x + 49, _y, _word, 0xE70000FF, text_default_border_color)
    elseif throw_tech_disp.success == true then
      local _word = _is_pre_press and "Pre-Press" or "Success"
      gui.text(_x + 49, _y, _word, 0x10FB00FF, text_default_border_color)
    end
  end
end
