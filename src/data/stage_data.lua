-- src/data/stage_data.lua
-- Per-stage playfield limits in character coordinates (ported from effie3rd stage_data.lua)
-- left/right are pos_x limits of the playfield, screen_left/screen_right are camera limits

stage_data = {
  stages = {
    [0] = {name = "gill", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [1] = {name = "alex", left = 80, right = 955, screen_left = 272, screen_right = 764},
    [2] = {name = "ryu", left = 80, right = 939, screen_left = 272, screen_right = 748},
    [3] = {name = "yun", left = 80, right = 951, screen_left = 272, screen_right = 760},
    [4] = {name = "dudley", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [5] = {name = "necro", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [6] = {name = "hugo", left = 76, right = 945, screen_left = 268, screen_right = 754},
    [7] = {name = "ibuki", left = 79, right = 943, screen_left = 271, screen_right = 752},
    [8] = {name = "elena", left = 76, right = 935, screen_left = 268, screen_right = 744},
    [9] = {name = "oro", left = 76, right = 945, screen_left = 268, screen_right = 754},
    [10] = {name = "yang", left = 80, right = 951, screen_left = 272, screen_right = 760},
    [11] = {name = "ken", left = 80, right = 955, screen_left = 272, screen_right = 764},
    [12] = {name = "sean", left = 76, right = 945, screen_left = 268, screen_right = 754},
    [13] = {name = "urien", left = 76, right = 951, screen_left = 268, screen_right = 760},
    [14] = {name = "gouki", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [15] = {name = "shingouki", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [16] = {name = "chunli", left = 70, right = 951, screen_left = 272, screen_right = 760},
    [17] = {name = "makoto", left = 84, right = 945, screen_left = 276, screen_right = 754},
    [18] = {name = "dudley", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [19] = {name = "twelve", left = 80, right = 943, screen_left = 272, screen_right = 752},
    [20] = {name = "remy", left = 82, right = 943, screen_left = 274, screen_right = 752},
  }
}

-- pos_x limits a given character can actually reach on the current stage
function get_stage_limits(_stage, _char_str)
  local _entry = stage_data.stages[_stage] or stage_data.stages[0]
  local _limit_left = _entry.left + character_specific[_char_str].corner_offset_left
  local _limit_right = _entry.right - character_specific[_char_str].corner_offset_right
  return _limit_left, _limit_right
end
