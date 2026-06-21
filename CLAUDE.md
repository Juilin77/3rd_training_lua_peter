# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要：Push 前先跑 Release
- **每次 push 前必須詢問 Peter 是否要發版**
- Release 流程在 `.claude/commands/release.md`（版本號、README changelog、startup.lua、gh release create）

## 概覽
- FightCade v2 / FBNeo 的 SF3 3rd Strike 訓練模式 Lua 腳本
- GitHub：https://github.com/Juilin77/3rd_training_lua_peter
- 目前版本：v0.22
- 版本號在 `src/startup.lua`

## 執行方式
- 無自動化測試；所有測試在 FBNeo 遊戲內手動進行
- 腳本由 FBNeo 的 Lua scripting 功能載入，不能直接用 `lua` 指令執行

## 主要檔案
- `3rd_training.lua` — 所有功能的主腳本（12000+ 行），`before_frame()` / `on_gui()` / `on_load_state()` 三個主 callback
- `src/menu_widgets.lua` — 選單 widget 系統（checkbox / list / integer / map / gauge / button）
- `src/gamestate.lua` — 每幀讀取 RAM、更新 player_objects；`read_player_vars()` 定義所有 player 欄位
- `src/draw.lua` — 座標轉換、`draw_gauge()`、`get_text_width()`、`draw_parry_gauge_group()`
- `src/memory_adresses.lua` — 所有 RAM 位址常數
- `src/frame_table.lua` — Frame Table 顯示邏輯（獨立模組）

## Callback 執行順序（每幀）
1. `before_frame()` → 讀 input、執行 recording/replay、process_pending_input_sequence
2. 遊戲模擬一幀
3. `on_gui()` → 繪製所有 UI、處理選單開關
- `on_load_state()` → savestate 載入後在兩幀之間觸發

## 重要全域變數
- `player_objects[1]`, `player_objects[2]` — 每次 savestate load 後由 `reset_player_objects()` 重建
- `player`, `dummy` — 每幀在 `before_frame()` 根據 `swap_characters` 設定（`on_load_state()` 裡是 stale，要用 `player_objects[N]`）
- `training_settings` — 所有設定的單一 table，變更後由 `save_training_data()` 寫入 JSON
- `screen_width = 383`, `screen_height = 223`, `ground_offset = 23`

## 架構陷阱（必讀）
1. **`dummy` / `player` 在 `on_load_state()` 是 stale** → 永遠用 `player_objects[N]`
2. **`reset_player_objects()` 清掉 input.down** → savestate load 後若需要 pressed 偵測，先保存再還原
3. **`savestate.load()` 是非同步的** → 呼叫後不立即執行，`on_load_state()` 在下一幀之前觸發
4. **`os.execute()` 在 Windows 很慢** → 用 flag 確保只跑一次
5. **Lua 5.1 位元運算** → 不能用 `|` / `&` / `<<`，要用 `bit.bor()` / `bit.band()` / `bit.lshift()`

## Player 物件常用欄位（src/gamestate.lua read_player_vars）
完整欄位參考：`../_reference/player_fields.md`（11 分類）
```
pos_x, pos_y          — 遊戲空間座標（signed word，base+0x64/0x68）
action                — 動作 ID（dword，base+0xAC）；43=defender tech throw，44=attacker tech throw
animation             — 動畫 ID（hex string，base+0x202）
is_attacking          — 正在攻擊
is_being_thrown       — 被投中（base+0x3CF）
throw_countdown       — 投擲倒數（base+0x434）
parry_forward/down/air/antiair — parry 狀態物件（各含 validity_time, cooldown_time, delta, success）
flip_x                — 面向（0=朝右，非0=朝左）
life, stun_timer, meter_gauge — 血量、暈眩計時、EX 槽
```

## 座標轉換（src/draw.lua）
```lua
game_to_screen_space(_game_x, _game_y)   -- 回傳 (screen_x, screen_y)
game_to_screen_space_x(_x)               -- _x - screen_x + emu.screenwidth()/2
game_to_screen_space_y(_y)               -- emu.screenheight() - (_y - screen_y) - ground_offset
get_text_width(_text)                    -- #_text * 4（固定寬度字體，每字元 4px）
```
`screen_x` / `screen_y` 由 `draw_read()` 每幀從 RAM 讀取（鏡頭位移），所有角色跟隨 UI 都需要扣掉這個 offset。

## 選單 Widget 系統（src/menu_widgets.lua）
六種 widget 類型：`checkbox_menu_item` / `list_menu_item` / `integer_menu_item` / `map_menu_item` / `gauge_menu_item` / `button_menu_item`。

所有 widget 的共通介面：`:draw(x,y,selected)` / `:left()` / `:right()` / `:reset()` / `:legend()` / `:is_disabled(fn)`.

加新選項的完整流程：
1. 在 `training_settings = {}` 初始化中加 key 和預設值（約 L1905）
2. 在對應的選單 tab entries 中用對應 widget 建立項目（約 L2183 的 Special Training tab）
3. 可加 `.is_disabled = function() return ... end` 讓選項在特定 mode 下灰掉
4. 選單的 `on_toggle_entry` callback 會自動呼叫 `save_training_data()`，無需手動儲存
5. 在 `on_gui()` 裡讀取 `training_settings.your_key` 使用

## Special Training 架構
`special_training_mode[]` 是 mode index → mode 名稱的 table（`"Parry"` / `"Charge"` / `"Tech Throw"` / `"Juggle"` / `"720"` 等）。

`training_settings.special_training_current_mode` 為目前選中的 index。

**`follow_character` 標準模式**（parry / charge / tech throw 都用這套）：
```lua
local _x, _y = <固定預設值>
if training_settings.special_training_follow_character then
  local _px = _player.pos_x - screen_x + emu.screenwidth()/2
  local _py = emu.screenheight() - (_player.pos_y - screen_y) - ground_offset
  local _half_width = 23 * _gauge_x_scale * 0.5
  _x = math.max(_px - _half_width, 4)
  _x = math.min(_x, emu.screenwidth() - (_half_width * 2.0 + 14))
  _y = _py - 100   -- 角色頭上
end
```
`_player.pos_y` 是腳底座標，螢幕 Y 向下為正，所以 `-N` 是往上。

## draw_parry_gauge_group（src/draw.lua / 3rd_training.lua）
```lua
draw_parry_gauge_group(_x, _y, _parry_object, _scale)
-- _parry_object 需有：name, validity_time, max_validity, cooldown_time, max_cooldown, delta, success
-- 回傳值：佔用高度（可用來排列多個 gauge: _y_offset += margin + return_value）
-- 在 _y 行畫標題文字，_y+8 起畫 gauge bar，_y+7/_y+13 畫 validity/cooldown 數字
```

## Mission 系統
- 存檔分兩個：`mission_slot_X.json`（metadata）+ `mission_slot_X.inputs.json`（inputs，lazy-load）
- 回放用 `player_objects[mission_dummy_id]`，不用 `dummy`（`mission_dummy_id = 3 - mission_play_side`）

## 工作慣例
- 手動在遊戲裡測試，沒有自動化測試
- Bug 修復不需要重構周邊程式碼；不加多餘的 error handling
- 用繁體中文溝通，回覆要簡短
