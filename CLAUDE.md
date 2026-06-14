# 3rd_training_lua_peter

## 概覽
- FightCade v2 / FBNeo 的 SF3 3rd Strike 訓練模式腳本
- GitHub：https://github.com/Juilin77/3rd_training_lua_peter
- 目前版本：v0.19

## 主要檔案
- `3rd_training.lua` — 主腳本（所有功能都在這）
- `src/startup.lua` — 版本號
- `src/gamestate.lua` — 遊戲狀態、`reset_player_objects()`
- `src/memory_adresses.lua` — 所有記憶體位址
- `saved/recording_missions/` — Mission 存檔（.gitignore 排除）

## Callback 執行順序（每幀）
1. `before_frame()` → 讀 input、執行 recording/replay
2. 遊戲模擬一幀
3. `on_gui()` → 繪製 UI、處理選單開關
- `on_load_state()` → savestate 載入後立即觸發

## 重要全域變數
- `player_objects[1]`, `player_objects[2]` — 每次 savestate load 後重建
- `player`, `dummy` — 每幀在 `before_frame()` 根據 `swap_characters` 設定
- `mission_dummy_id = 3 - mission_play_side`
- `is_fightcade_replay` — 觀戰模式偵測，跳過 `joypad.set`

## 架構陷阱（必讀）
1. **`dummy` / `player` 在 `on_load_state()` 是 stale** → 永遠用 `player_objects[N]`
2. **`reset_player_objects()` 清掉 input.down** → 需先保存再還原
3. **`savestate.load()` 是非同步的** → `on_load_state()` 在下一幀之前觸發
4. **`os.execute()` 在 Windows 很慢** → 用 flag 確保只跑一次

## Mission 系統
- 存檔分兩個：`mission_slot_X.json`（metadata）+ `mission_slot_X.inputs.json`（inputs，lazy-load）
- 回放用 `player_objects[mission_dummy_id]`，不用 `dummy`
- `mission_replay_active = true` 可讓 dummy 停止 AI 行為只播 inputs

## 工作慣例
- 手動在遊戲裡測試，沒有自動化測試
- Bug 修復不需要重構周邊程式碼
- 不需要加多餘的 error handling
- 用繁體中文溝通，回覆要簡短
