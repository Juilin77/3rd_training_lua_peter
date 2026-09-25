# SF3 模組化重構計畫

> 目標：讓 3rd_training.lua 架構對齊 effie3rd，方便將來把 effie3rd 功能直接 drop in。
> 參考：`sf33rd/_reference/effie3rd/3rd_training_lua-main/`

---

## 目標架構

```
3rd_training_lua_peter/
├── 3rd_training.lua         ← 主入口（大幅精簡，只留 callback 骨架）
└── src/
    ├── ui/
    │   └── menu.lua         ← 所有 tab 選單定義（新建）
    ├── control/
    │   ├── dummy_control.lua ← Blocking/Parry/Counter/TechThrow 邏輯（新建）
    │   ├── recording.lua    ← 錄製/回放邏輯（新建）
    │   ├── missions.lua     ← Mission 系統（新建）
    │   └── pattern_replay.lua ← Pattern Replay 系統（新建）
    ├── modules/             ← 將來加 effie3rd 模組用（新建資料夾）
    │   ├── distances/
    │   ├── extra_settings/
    │   └── key_bindings/
    ├── training/            ← 將來加 effie3rd Training tab 用（新建資料夾）
    │   ├── defense/
    │   ├── footsies/
    │   └── ...
    ├── settings.lua         ← save/load training data（新建）
    ├── tools.lua            ← 已存在
    ├── gamestate.lua        ← 已存在
    ├── draw.lua             ← 已存在
    ├── display.lua          ← 已存在
    ├── menu_widgets.lua     ← 已存在
    ├── framedata.lua        ← 已存在
    ├── input_history.lua    ← 已存在
    ├── attack_data.lua      ← 已存在
    ├── frame_advantage.lua  ← 已存在
    ├── frame_table.lua      ← 已存在
    └── character_select.lua ← 已存在
```

---

## 注意事項（執行前必讀）

### require 路徑格式
Peter 版目前用斜線：`require("src/tools")`
effie3rd 用點號：`require("src.tools")`

**兩種在 MAME/FBNeo 都能用。**
建議新建的模組統一改用點號格式，與 effie3rd 對齊：
```lua
-- 舊（保留現有）
require("src/tools")
-- 新（新建模組用這個）
local dummy_control = require("src.control.dummy_control")
```

### 全域 vs 局部變數
- Peter 版目前大量使用全域變數（`training_settings`、`player_objects` 等）
- 搬移時先維持全域，**不要急著改成 local**，避免引入 bug
- 等架構穩定後再逐步 local 化

### 測試方式
- 每個 Phase 完成後在 FBNeo 跑一次確認功能正常
- Phase 之間是獨立的，可以分次執行

---

## Phase 1：建立 `src/ui/menu.lua`（選單定義搬移）✅ 完成（時間不明，2026-09-26 才發現已完成）

**難度：低 | 風險：低**

### 要搬的內容（從 3rd_training.lua）

| 行號範圍 | 內容 |
|---------|------|
| L1660～1674 | save/load popup 選單定義 |
| L1748～1750 | `_replay_file_item` 定義 |
| L1982～2010 | widget 物件定義群（life/stun/meter gauge items 等） |
| L2011～2074 | 其餘 widget 物件定義（parry items、charge items 等） |
| L2075～2325 | `make_multitab_menu(...)` 完整選單結構 |

### 步驟

1. 建立 `src/ui/` 資料夾
2. 建立 `src/ui/menu.lua`，內容結構：
   ```lua
   -- src/ui/menu.lua
   local M = {}

   function M.create()
       -- 把上述所有 widget 定義和 make_multitab_menu 搬進來
       -- widget 物件定義...
       -- main_menu = make_multitab_menu(...)
       return main_menu
   end

   return M
   ```
3. `3rd_training.lua` 改成：
   ```lua
   local menu_ui = require("src.ui.menu")
   -- 在 on_start() 裡：
   main_menu = menu_ui.create()
   ```

### 完成標準
- 遊戲開啟後 6 個 tab 正常顯示
- 選項可以切換，設定可以儲存

---

## Phase 2：建立 `src/settings.lua`（設定存取）✅ 完成（時間不明，2026-09-26 才發現已完成）

**難度：低 | 風險：低**

### 要搬的內容

| 行號 | 函數 |
|------|------|
| L660 | `save_training_data()` |
| L667 | `load_training_data()` |
| L695 | `backup_recordings()` |
| L714 | `restore_recordings()` |

### 步驟

1. 建立 `src/settings.lua`：
   ```lua
   local M = {}
   function M.save() ... end
   function M.load() ... end
   function M.backup_recordings() ... end
   function M.restore_recordings() ... end
   return M
   ```
2. 主檔 `require("src.settings")`，替換原本的直接呼叫

### 完成標準
- 重啟 FBNeo 後設定正確載入
- 切換角色後錄製槽正確 restore

---

## Phase 3：建立 `src/control/dummy_control.lua`（Dummy 邏輯）✅ 完成，且比計畫更徹底——拆成 pose.lua/blocking.lua/counter_attack.lua/tech_throw.lua 四個檔案（時間不明，2026-09-26 才發現已完成）

**難度：中 | 風險：中**

### 要搬的函數

| 行號 | 函數 | 說明 |
|------|------|------|
| L751 | `update_pose()` | Pose 控制 |
| L927 | `update_blocking()` | Blocking 核心（最複雜，~447 行） |
| L1374 | `update_fast_wake_up()` | Fast Wake Up |
| L1387 | `update_counter_attack()` | Counter Attack |
| L1533 | `update_tech_throws()` | Tech Throw 邏輯 |

### 步驟

1. 建立 `src/control/` 資料夾
2. 建立 `src/control/dummy_control.lua`：
   ```lua
   local M = {}

   function M.update_pose(input, player_obj, pose) ... end
   function M.update_blocking(input, player, dummy, mode, style, red_parry_hit_count) ... end
   function M.update_fast_wake_up(input, player, dummy, mode) ... end
   function M.update_counter_attack(input, attacker, defender, stick, button) ... end
   function M.update_tech_throws(input, attacker, defender, mode) ... end

   function M.update()
       -- 在 before_frame() 裡呼叫的統一入口
       update_pose(...)
       update_blocking(...)
       update_fast_wake_up(...)
       update_counter_attack(...)
       update_tech_throws(...)
   end

   return M
   ```
3. `before_frame()` 裡改呼叫 `dummy_control.update()`

### 注意
- `update_blocking()` 有大量 log 呼叫，依賴全域 `log_categories_display`，搬移時確認可存取
- `update_counter_attack()` 依賴 `queue_input_sequence()`，這個函數在 Phase 4 才搬，暫時留全域

### 完成標準
- Dummy blocking 正常運作
- Tech throw 可以正確觸發
- Counter attack 動作正確

---

## Phase 4：建立 `src/control/recording.lua`（錄製/回放）✅ 完成（時間不明，2026-09-26 才發現已完成）

**難度：中 | 風險：中**

### 要搬的函數

| 行號 | 函數 |
|------|------|
| L97 | `queue_input_sequence()` |
| L114 | `process_pending_input_sequence()` |
| L226 | `clear_input_sequence()` |
| L230 | `is_playing_input_sequence()` |
| L234 | `make_input_empty()` |
| L325 | `make_input_sequence()` 及 stick/button gesture tables |
| L591 | `make_recording_slot()` |
| L1582 | `clear_slot()` |
| L1587 | `clear_all_slots()` |
| L1624 | `save_recording_slot_to_file()` |
| L1640 | `load_recording_slot_from_file()` |
| L2326 | `stick_input_to_sequence_input()` |
| L2354 | `can_play_recording()` |
| L2367 | `find_random_recording_slot()` |
| L2400 | `go_to_next_ordered_slot()` |
| L2414 | `set_recording_state()` |
| L2489 | `update_recording()` |

### 完成標準
- 錄製/回放正常
- 存檔/讀檔 popup 正常運作
- Slot 切換正確

---

## Phase 5：建立 `src/control/missions.lua`（Mission 系統）✅ 完成（時間不明，2026-09-26 才發現已完成）

**難度：中 | 風險：低**

### 要搬的函數

| 行號 | 函數 |
|------|------|
| L618 | `make_mission_slot()` |
| L633 | `refresh_mission_recording_slots_names()` |
| L1795 | `get_mission_slot_paths()` |
| L1803 | `save_mission_to_file()` |
| L1818 | `load_missions_from_files()` |
| L1832 | `delete_mission_slot_files()` |
| L1839 | `clear_mission_slot()` |
| L1847 | `clear_all_mission_slots()` |
| L1855 | `mission_replay_queue_inputs()` |
| L1866 | `replay_current_mission()` |
| L1890 | `update_mission_recording()` |

### 完成標準
- Mission 錄製/回放正常
- Slot 存取正常

---

## Phase 6：建立 `src/control/pattern_replay.lua`（Pattern Replay）✅ 完成（時間不明，2026-09-26 才發現已完成）

**難度：低 | 風險：低**

### 要搬的函數

| 行號 | 函數 |
|------|------|
| L1688 | `scan_replay_files()` |
| L1709 | `direct_play_pattern()` |
| L1752 | `no_pattern_available()` |
| L1759 | `_replay_file_item:draw()` |
| L1769 | `pick_random_pattern_index()` |
| L1775 | `pick_next_ordered_pattern_index()` |

### 完成標準
- Pattern scan 正常
- Pattern replay（normal/random/ordered/repeat）正常

---

## Phase 7：清理主檔案 ✅ 完成（2026-09-26）

死代碼刪除（debug position prediction + frame advantage 測試殘留）+ 9 項 inline 邏輯搬移（ping_delay.lua 新建、debug_display.lua 新建、tools.lua/recording.lua/missions.lua/pattern_replay.lua/settings.lua 各自補上對應函式），`3rd_training.lua` 從 1042 行降到 852 行。`before_frame()`/`on_gui()` 現在剩下的都是合理的每幀排程呼叫，沒有殘留的 inline business logic。

**難度：高 | 風險：中**

完成 Phase 1～6 後，`3rd_training.lua` 應精簡為：

```lua
require("src/startup")
-- ... print 版本資訊 ...

-- 載入已存在的模組
require("src/tools")
require("src/memory_adresses")
require("src/draw")
require("src/display")
require("src/menu_widgets")
require("src/framedata")
require("src/gamestate")
require("src/input_history")
require("src/attack_data")
require("src/frame_advantage")
require("src/frame_table")
require("src/character_select")

-- 載入新模組
local settings_mod   = require("src.settings")
local dummy_control  = require("src.control.dummy_control")
local recording      = require("src.control.recording")
local missions       = require("src.control.missions")
local pattern_replay = require("src.control.pattern_replay")
local menu_ui        = require("src.ui.menu")

-- 全域設定
recording_slot_count = 8
-- ... debug options ...
-- ... path constants ...

function on_start()
    settings_mod.load()
    main_menu = menu_ui.create()
    -- hotkey 綁定
end

function before_frame()
    draw_read()
    gamestate_read()
    -- write game vars（還沒搬的保留在這裡）
    dummy_control.update()
    recording.update()
    missions.update()
    pattern_replay.update()
end

function on_gui()
    -- 繪製 UI（display、frame_table 等已模組化的直接呼叫）
    menu_draw(main_menu)
end

function on_load_state()
    reset_player_objects()
    recording.on_load_state()
end

emu.registerstart(on_start)
emu.registerbefore(before_frame)
gui.register(on_gui)
savestate.registerload(on_load_state)
```

### 要做的事
- 確認 `draw_parry_gauge_group()` (L3046) 歸屬：移到 `src/draw.lua`
- 確認 `write_player_vars()` (L2583) 歸屬：移到 `src/gamestate.lua`
- 清理 `on_gui()` 裡殘留的 inline 邏輯

---

## Phase 8 以後：加入 effie3rd 功能

架構對齊後，加新功能的流程：

### Dummy tab 功能（E-D2～E-D7）
→ 加進 `src/control/dummy_control.lua`
→ 選單 entries 加進 `src/ui/menu.lua` 的 `create_dummy_tab()`

### 獨立模組（E-M1 Distances、E-M2 Extra Settings、E-M3 Key Bindings）
→ 從 effie3rd 複製整個子資料夾到 `src/modules/`
→ 在 `src/ui/menu.lua` 加入 Modules tab

### Training 模式（E-T1～E-T5）
→ 從 effie3rd 複製整個子資料夾到 `src/training/`
→ 建立 `src/modes.lua` 管理器（直接從 effie3rd 搬）
→ 在 `src/ui/menu.lua` 加入 Training tab

---

## 執行優先順序建議

| 優先 | Phase | 理由 |
|------|-------|------|
| 1 | Phase 1（menu.lua） | 影響最小，收益最高，為後續打基礎 |
| 2 | Phase 2（settings.lua） | 簡單，解耦 save/load |
| 3 | Phase 3（dummy_control.lua） | 與 effie3rd E-D2～D4 直接對應，搬完就能加新功能 |
| 4 | Phase 4（recording.lua） | 最複雜，可以放後面 |
| 5 | Phase 5（missions.lua） | 獨立性高，風險低 |
| 6 | Phase 6（pattern_replay.lua） | 最小，最後做 |
| 7 | Phase 7（清理主檔） | 等前面都穩定後才做 |
| 8 | Phase 8+（加 effie3rd 功能） | 架構就位後隨時可開始 |
