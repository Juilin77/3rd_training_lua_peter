-- src/control/ping_delay.lua
-- ping delay: buffers the human player's own input by N frames

ping_delay_frames = {0, 1, 2, 3, 4, 5, 6}
ping_delay_names = {"Off", "16.7ms (1f)", "33.3ms (2f)", "50.0ms (3f)", "66.7ms (4f)", "83.3ms (5f)", "100.0ms (6f)"}

function update_ping_delay(_input, _player)
  local _ping_frames = ping_delay_frames[training_settings.ping_delay]
  if is_in_match and not is_menu_open and _ping_frames and _ping_frames > 0 then
    ping_delay_buffer = ping_delay_buffer or {}
    local _snapshot = {}
    for _key, _val in pairs(_input) do
      if _key:sub(1, 2) == _player.prefix then
        _snapshot[_key] = _val
      end
    end
    table.insert(ping_delay_buffer, _snapshot)
    while #ping_delay_buffer > _ping_frames + 1 do
      table.remove(ping_delay_buffer, 1)
    end
    local _delayed = ping_delay_buffer[1]
    if _delayed then
      for _key, _val in pairs(_delayed) do
        _input[_key] = _val
      end
    end
  else
    ping_delay_buffer = nil
  end
end
