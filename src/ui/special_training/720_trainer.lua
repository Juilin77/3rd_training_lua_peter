-- src/ui/special_training/720_trainer.lua

function special_training_720_draw()
  if is_in_match and not training_settings.recording_mission_mode
     and special_training_mode[training_settings.special_training_current_mode] == "720" then

    local HUGO_CHAR_ID = 6
    local CARD720 = {8, 2, 4, 6}
    local CARD_SYMBOL = {[8]="^", [2]="v", [4]="<", [6]=">"}

    -- follow character position (default aligned to Tech Throw)
    local _x = screen_width - 138 - get_text_width("Juggle: ")
    local _y = 82
    if training_settings.special_training_follow_character then
      local _px = player.pos_x - screen_x + emu.screenwidth()/2
      local _py = emu.screenheight() - (player.pos_y - screen_y) - ground_offset
      local _half_width = 36
      _x = math.max(_px - _half_width, 4)
      _x = math.min(_x, emu.screenwidth() - 80)
      _y = _py - 100
    end

    -- character check
    if player.char_id ~= HUGO_CHAR_ID then
      gui.text(_x, _y, "720 Trainer: Hugo Only", 0xFFFFFFFF, 0x00000080)
    else

      -- read input
      local _input = joypad.get()
      local _prefix = "P1 "
      local _up    = _input[_prefix.."Up"]    or false
      local _down  = _input[_prefix.."Down"]  or false
      local _left  = _input[_prefix.."Left"]  or false
      local _right = _input[_prefix.."Right"] or false

      local _numpad = 5
      if _up and _right then _numpad=9 elseif _up and _left then _numpad=7
      elseif _down and _right then _numpad=3 elseif _down and _left then _numpad=1
      elseif _up then _numpad=8 elseif _down then _numpad=2
      elseif _right then _numpad=6 elseif _left then _numpad=4 end

      local _cardinal_map = {[8]=8,[2]=2,[4]=4,[6]=6}
      local _dir = _cardinal_map[_numpad]
      if _dir ~= nil then
        local _last = rot720_disp.history[#rot720_disp.history]
        if _last == nil or _last.dir ~= _dir then
          table.insert(rot720_disp.history, {dir=_dir, frame=frame_number})
          rot720_disp.fail_reason = nil
          rot720_disp.success_flash = 0
          if #rot720_disp.sequence < 7 then
            table.insert(rot720_disp.sequence, _dir)
          end
        end
      end

      -- remove entries older than window frames
      while #rot720_disp.history > 0 and frame_number - rot720_disp.history[1].frame > rot720_disp.window do
        table.remove(rot720_disp.history, 1)
      end
      -- clear sequence display after history expires; does not trigger Too Late (Too Late only fires on Punch press)
      if #rot720_disp.history == 0 then
        rot720_disp.sequence = {}
      end

      -- check_720 Condition B
      local function check_720_condB(hist)
        local seen = {}
        local seen_count = 0
        local split_idx = nil
        local x = nil
        for i = 1, #hist do
          local d = hist[i].dir
          if not seen[d] then
            seen[d] = true
            seen_count = seen_count + 1
            if seen_count == 4 then x = d; split_idx = i; break end
          end
        end
        if split_idx == nil then return false end
        local after = {}
        for i = split_idx+1, #hist do after[hist[i].dir] = true end
        for _, d in ipairs(CARD720) do
          if d ~= x and not after[d] then return false end
        end
        return true
      end

      -- detect punch / kick press
      local _kick = _input[_prefix.."Weak Kick"] or _input[_prefix.."Medium Kick"] or _input[_prefix.."Strong Kick"]
      if _kick then
        if _input[_prefix.."Weak Kick"] then rot720_disp.last_button = "LK"
        elseif _input[_prefix.."Medium Kick"] then rot720_disp.last_button = "MK"
        else rot720_disp.last_button = "HK" end
        rot720_disp.fail_reason = "wrong_button"
        rot720_disp.fail_timer = 180
      end
      local _punch = _input[_prefix.."Weak Punch"] or _input[_prefix.."Medium Punch"] or _input[_prefix.."Strong Punch"]
      if _punch then
        if _input[_prefix.."Weak Punch"] then rot720_disp.last_button = "LP"
        elseif _input[_prefix.."Medium Punch"] then rot720_disp.last_button = "MP"
        else rot720_disp.last_button = "HP" end
        local function check_720_condA(hist)
          local cnt = {[2]=0,[4]=0,[6]=0,[8]=0}
          for _, e in ipairs(hist) do cnt[e.dir] = (cnt[e.dir] or 0) + 1 end
          return cnt[2]>=2 and cnt[4]>=2 and cnt[6]>=2 and cnt[8]>=2
        end
        local function pre_filter(hist)
          local unique = {}
          local count = 0
          local has_up = false
          for _, e in ipairs(hist) do
            if not unique[e.dir] then unique[e.dir] = true; count = count + 1 end
            if e.dir == 8 then has_up = true end
          end
          return count >= 3 and has_up
        end
        if not pre_filter(rot720_disp.history) then
          -- silent ignore: insufficient directions or no up input, show nothing
        elseif check_720_condA(rot720_disp.history) or check_720_condB(rot720_disp.history) then
          rot720_disp.success_flash = 180
          rot720_disp.fail_reason = nil
          rot720_disp.fail_timer = 0
          rot720_disp.history = {}
          rot720_disp.sequence = {}
        else
          rot720_disp.fail_reason = "time"
          rot720_disp.fail_timer = 180
        end
      end

      if rot720_disp.success_flash > 0 then
        rot720_disp.success_flash = rot720_disp.success_flash - 1
      end
      if rot720_disp.fail_timer > 0 then
        rot720_disp.fail_timer = rot720_disp.fail_timer - 1
        if rot720_disp.fail_timer == 0 then
          rot720_disp.fail_reason = nil
        end
      end

      -- === draw ===
      local _cell = 8   -- img_dir_small: 8px per cell
      local _gap = 2

      -- title (Tech Throw style)
      local _title = "720 Trainer: "
      gui.text(_x, _y, _title, text_default_color, text_default_border_color)
      local _title_w = get_text_width(_title)

      -- result text inline to the right of title
      if rot720_disp.success_flash > 0 and rot720_disp.success_flash % 8 < 4 then
        gui.text(_x + _title_w, _y, "720!", 0x10FB00FF, text_default_border_color)
      elseif rot720_disp.fail_reason == "time" then
        gui.text(_x + _title_w, _y, "Too Late", 0xE70000FF, text_default_border_color)
      elseif rot720_disp.fail_reason == "wrong_button" then
        gui.text(_x + _title_w, _y, "Wrong Button", 0xE70000FF, text_default_border_color)
      elseif rot720_disp.fail_reason == "incomplete" then
        gui.text(_x + _title_w, _y, "Incomplete", 0xE70000FF, text_default_border_color)
      end

      -- row 1: 7 cells showing direction icons (img_dir_small, 8px each)
      local _row_y = _y + 10
      for i = 1, 7 do
        local _cx = _x + (i-1) * (_cell + _gap)
        local _dir_val = rot720_disp.sequence[i]
        if _dir_val then
          gui.image(_cx, _row_y, img_dir_small[_dir_val])
        else
          gui.box(_cx, _row_y, _cx+8, _row_y+8, 0x333333FF, 0x000000FF)
        end
      end

      -- cell 8: button icon (one cell gap)
      local _btn_cx = _x + 7 * (_cell + _gap) + _gap + 4
      if rot720_disp.last_button == "LP" then
        gui.image(_btn_cx, _row_y, img_LP_button_small)
      elseif rot720_disp.last_button == "MP" then
        gui.image(_btn_cx, _row_y, img_MP_button_small)
      elseif rot720_disp.last_button == "HP" then
        gui.image(_btn_cx, _row_y, img_HP_button_small)
      elseif rot720_disp.last_button == "LK" then
        gui.image(_btn_cx, _row_y, img_LK_button_small)
      elseif rot720_disp.last_button == "MK" then
        gui.image(_btn_cx, _row_y, img_MK_button_small)
      elseif rot720_disp.last_button == "HK" then
        gui.image(_btn_cx, _row_y, img_HK_button_small)
      end

      -- row 2: right-to-left countdown bar
      local _y2 = _row_y + _cell + 4
      local _bar_w = 7 * (_cell + _gap) - _gap
      local _elapsed = 0
      if #rot720_disp.history > 0 then
        _elapsed = frame_number - rot720_disp.history[1].frame
      end
      local _ratio = math.max(0, 1.0 - _elapsed / rot720_disp.window)
      draw_gauge(_x, _y2, _bar_w, 4, _ratio, 0xFF6B00FF, 0x333333FF, nil, true)
      gui.text(_x + _bar_w + 4, _y2, string.format("%dF", math.max(0, rot720_disp.window - _elapsed)), text_default_color, text_default_border_color)

    end -- char check
  end -- mode check
end
