# 3rd_training_lua
Training mode for Street Fighter III 3rd Strike (Japan 990512), on Fightcade v2.0.91

The right version of Fightcade can be downloaded [here](https://www.fightcade.com/)

![All Features](screenshots/allopen.png)

## Main Features
- Can set dummy to counter-attack with any move on frame 1 after any hit / block / parry / wake-up
- Can record and replay sequences into 8 different slots
- Can replay sequences randomly and as counter-attack
- Can save/load recorded sequences to/from files
- Can display hit/hurt/throwboxes
- Can display input history for both players
- Special training mode to train parries and red parries

## Documentation
- [How to Use](docs/how_to_use.md)
- [Dummy](docs/dummy.md)
- [Recording](docs/recording.md)
- [Missions](docs/missions.md)
- [Display](docs/display.md)
- [Rules](docs/rules.md)
- [Special Training](docs/special_training.md)

## Bug reporting / Contribute
If you want to be informed when a new version come out and/or discuss the current bugs and features, you can join the [Discord server](https://discord.gg/CDXQyFmcSe) of the project.

This training mode is still in development and you may encounter bugs or missing features while using it. Please report any bug on the **#bugs** channel, and any feature request on the **#features** channel of the discord server.

If you wish to contribute or give any feedback, feel free to get in touch or submit pull requests.

## Troubleshooting
**Q: Missing rom, zip file not found**

A: Make sure you have the proper roms. You must have at least 2 roms: _sfiii3.zip_ and _sfiii3a.zip_. sfiii3 is the japanese version and the zip contains _sfiii3_japan_nocd.29f400.u2_. sfiiia is the american version and contains _sfiii3_usa.29f400.u2_.

You may need to rename zip files so they match exactly what the emulator expect for.

**Q: When I run the script, the characters can no longer move**

A: You are probably using the script on FBA-RR which is not supported anymore, in order to benefit from the last features and improvement you must run the script on Fightcade2's FBNeo emulator. However if you still want to use FBA-RR, you can go back to v0.6 which was the last version supported on FBA-RR.

**Q: Emulator crash when I run lua script**

A: Check video settings, you musn't use "Enhanced" blitter option.

**Q: UI looks weird and hitboxes are misplaced**

A: Check video settings, you must use "Basic" blitter option with no scanlines if you want the UI to work properly.

**Q: Emulator doesn't run at all, there's a missing dll**

A: Install prerequires from [here](https://github.com/TASVideos/BizHawk-Prereqs/releases/latest/)

## Changelog
### v0.23 (29/06/2026)
- [Feature] Dummy Pose: added directional jump and dash options — Forward Jump, Neutral Jump, Back Jump, Super Fwd Jump, Super Jump, Super Back Jump, Forward Dash, Back Dash (contribution of @Juilin77)
- [Feature] Dummy Blocking: SA pre-block state machine — dummy pre-blocks during super freeze and maintains block hold through SA chip hits; proxy_max_dist uses hurtbox edge distance for accuracy (contribution of @Juilin77)
- [Fix] Dummy Blocking: removed blocking_style early-return that broke SA blocking for Ryu SA1 (Shinkuu Hadoken) and all non-force_recording supers (contribution of @Juilin77)
- [Fix] Dummy Blocking: Ryu SA2 (Shin Shoryuken) all chip hits now correctly blocked with visible neutral gaps between hits (分段擋); fixed carry_offset overwrite bug and moved carry_hold to fire-time instead of hit-event time (contribution of @Juilin77)
- [Fix] Input History: frame hold count now starts from 1 instead of 0 (contribution of @Juilin77)
- [Improvement] Codebase modularized: dummy control, recording, missions, pattern replay, menu UI, and special training modes extracted into src/control/ and src/ui/; 3rd_training.lua reduced from ~12000 to ~9000 lines (contribution of @Juilin77)

### v0.22 (22/06/2026)
- [Fix] Frame Table: single-move specials no longer show green recovery frames — active-to-recovery phase changes within the same move are now correctly classified using the `action` field (contribution of @Juilin77)
- [Fix] Frame Table: cancel gap frame (1-frame blue between cancel active and new startup) retroactively relabeled to startup (contribution of @Juilin77)
- [Fix] Multiple nil-access crash guards added across frame_table, framedata, and blocking code (contribution of @Juilin77)
- [Improvement] README: complete documentation overhaul — new How to Use section with hotkey table, screenshots for all menu tabs, Display sub-sections with color legends, Special Training sub-sections per mode with screenshots (contribution of @Juilin77)

### v0.21 (20/06/2026)
- [Improvement] Capitalized on-screen labels in Display Damage Info (Damage/Stun/Combo etc.) and Display Frame Advantage (Startup/Hit Frame/Advantage etc.) popups (contribution of @Juilin77)
- [Improvement] Frame Table cancel detection: when a move cancel is detected (active resumes after recovery with animation change), recovery frames are relabeled as startup, showing a cleaner green|red | green|red|blue pattern (contribution of @Juilin77)
- [Feature] Frame Table: added "Projectile" state (coffee brown) for projectile moves; fixes all-green bug where fireball recovery was misclassified as startup (contribution of @Juilin77)
- [Fix] Frame Table: throw moves (normal throws, command grabs, multi-hit throws) now correctly show blue recovery frames and calculate Total/Adv using deferred neutral tracking beyond the 90-frame buffer (contribution of @Juilin77)
- [Feature] Added 720 Input Trainer (Special Training → Mode → 720, Hugo only): detects 720° rotation using SF3's 11-frame window (Condition A+B, confirmed from 3s-decomp); shows "720!" on success, "Too Late"/"Wrong Button" on failure with 3-second display (contribution of @Juilin77)

### v0.20 (18/06/2026)
- [Feature] Throw Tech Training (Special Training → Mode → Tech Throw): shows a 5-frame throw tech window after being grabbed, with a delta marker showing when LP+LK was pressed and result feedback — Success (green), Too Late, Too Early, or Parry Active (red) (contribution of @Juilin77)
- [Improvement] Tech Throw gauge extended timeout window to 6F to account for action propagation delay; validity bar freezes at input frame to eliminate off-by-one visual gap (contribution of @Juilin77)
- [Feature] Added Juggle Air Timer (Special Training → Mode → Juggle): gauge displays remaining air hitstun frames for the dummy with tick marks matching SF3 juggle decay values (contribution of @Juilin77)
- [Feature] Added Life Loss Indicator above health bars: when Display Gauges Numbers is enabled and HP is below max, draws a ㄇ-shaped red bracket over the lost HP region with the amount lost in yellow at center, displayed independently for both P1 and P2 (contribution of @Juilin77)
- [Improvement] Standardized all menu labels and on-screen display text to Title Case (contribution of @Juilin77)

### v0.19 (15/06/2026)
- [Feature] Added Frame Table: a real-time per-frame state timeline (startup/active/recovery/hitstun/parry/invincible) for both players with a color legend (contribution of @Juilin77)
- [Improvement] Frame Table capture arms on `has_just_attacked`/`has_just_thrown` to correctly catch invincible startup frames (contribution of @Juilin77)
- [Improvement] Frame Table shows P1/P2 Start/Total/Adv stats independently, resetting on each new capture (contribution of @Juilin77)
- [Improvement] Frame Table blocks enlarged and labeled with per-segment frame durations (contribution of @Juilin77)
- [Fix] Fixed frame count accumulation across capture windows for combos longer than 90 frames (contribution of @Juilin77)
- [Improvement] An attack now arms the opponent's Frame Table in sync, so the defender's capture starts with real neutral pre-roll frames (contribution of @Juilin77)
- [Improvement] Adv value color-coded green/red/yellow, matching `frame_advantage.lua` (contribution of @Juilin77)
- [Improvement] Combos longer than 90 frames keep a dimmed afterimage of the previous capture window (contribution of @Juilin77)
- [Fix] Combo cancels (e.g. 236EXP into 2MP) now correctly split the second hit's startup from the first hit's recovery (contribution of @Juilin77)
- [Fix] Fixed a JSON syntax error in `urien_framedata.json` that broke Urien frame data loading (contribution of @Juilin77)
- [Fix] Reset P1/P2 position before Pattern Replay to fix position drift (contribution of @Juilin77)

### v0.18 (14/06/2026)
- [Feature] Added "Pattern Replay Mode" (normal / random / ordered / repeat) for Replay Import patterns (contribution of @Juilin77)
- [Improvement] Replaced "Direct Play (LP)" button with a "Pattern Replay" start/stop toggle, mirroring Mission Replay (contribution of @Juilin77)
- [Improvement] "Pattern" entry now always shows after scanning (including `empty`), grayed out until a pattern is found; resets to `Pattern (P2: ?) : empty` when the P2 character changes (contribution of @Juilin77)

### v0.17 (11/06/2026)
- [Improvement] Missions tab redesign: "Record Mission in Slot" and "Replay Mission for Slot" now both show `slot N (content / empty)` inline in the menu item itself (contribution of @Juilin77)
- [Improvement] Reordered Play Side above Replay Mission; Replay Mission and Play Side are grayed out when no recording exists in the selected replay slot (contribution of @Juilin77)
- [Feature] Added on-screen frame counter during Mission Replay (top-right HUD) (contribution of @Juilin77)
- [Fix] Corrected `replay_output_path` to point to `replay-pattern-trainer/patterns/` for Direct Play (contribution of @Juilin77)

### v0.16 (17/05/2026)
- [Fix] Replaced os.execute mkdir with .gitkeep — saved/recording_missions/ directory now ships with the repo, eliminating startup freeze (contribution of @Juilin77)

### v0.15 (17/05/2026)
- [Fix] Mission recording slots no longer empty after reloading script — saved/recording_missions/ directory is now created automatically on startup (contribution of @Juilin77)

### v0.14 (10/05/2026)
- [Fix] Mission recording no longer freezes 5-6 seconds on first Alt+5 press (contribution of @Juilin77)
- [Fix] Mission recording frame counter now displays correctly instead of always showing 0 (contribution of @Juilin77)
- [Improvement] Increased mission slots from 5 to 10 (contribution of @Juilin77)

### v0.13 (29/04/2026)
- [Fix] Dummy behavior is now disabled when Mission settings are off (contribution of @Juilin77)
- [Improvement] Follow Character option is grayed out when Special Training is set to none (contribution of @Juilin77)
- [Improvement] Recording frame count is hidden when Mission recording is on (contribution of @Juilin77)
- [Feature] Added independent Clear Slot button (LP to confirm) (contribution of @Juilin77)

### v0.12 (23/04/2026)
- [Feature] Replay Mission ON/OFF toggle in Missions tab — replay starts on menu close, pauses on menu open (contribution of @Juilin77)
- [Feature] Mission recording now captures both P1 and P2 inputs simultaneously; Play Side setting determines which side the dummy replays (contribution of @Juilin77)
- [Feature] Replay Slot list now includes a "None" option; Replay Mission toggle is grayed out when no recording exists in the selected slot (contribution of @Juilin77)
- [Feature] After stopping recording (Alt+5), automatically advances to the next empty Mission Slot to prevent overwriting (contribution of @Juilin77)
- [Improvement] Dummy tab is grayed out when Replay Mission is ON (contribution of @Juilin77)
- [Improvement] FightCade spectator mode: training script no longer interferes with match inputs (contribution of @Juilin77)
- [Fix] Character select: 2P can now be controlled using 1P controls again (contribution of @Juilin77)
- [Fix] Play Side = 2P: player can now move freely during mission replay (contribution of @Juilin77)

### v0.11 (22/04/2026)
- [Feature] Mission recording/replay system (Alt+5 to start/stop recording, auto-replay on menu close) (contribution of @Juilin77)
- [Feature] Mission slots management (clear slot, clear all slots) (contribution of @Juilin77)
- [Improvement] Gray out irrelevant menu tabs when Recording Mission Mode is ON (contribution of @Juilin77)
- [Improvement] Hotkey hints moved from screen overlay to console (contribution of @Juilin77)
- [Improvement] Startup load speed optimized (mission inputs lazy-loaded) (contribution of @Juilin77)

### v0.10 (29/05/2022)
- [Feature] Charge special training (contribution of @ProfessorAnon)
- [Feature] Hyakuretsu Kyaku special training (contribution of @ProfessorAnon)
- [Feature] Dynamic input display (switch sides to avoid overlapping action) (contribution of @ProfessorAnon)
- [Feature] Damage data display (contribution of @sammygutierrez)
- [Feature] New 3rd_spectator.lua script for displaying info during replays without messing with input
- [Feature] Number display for all gauges and bonuses
- [Feature] Frame advantage display
- [Feature] Character switch is now a lot easier:
  - Initial loading puts you right in the character select screen
  - You can go back to the character select screen by hitting alt-1 or from the entry in the training menu
  - Both characters and SA can be selected directly from P1 controller
  - Game intro animation is sped up by default, but this can be disabled in the options
- [Feature] Gill and Shin Gouki can be selected from the character select screen
- [Feature] Added back jump, forward jump, super jump, super forward jump, super back jump counter-attack options
- [Feature] Added auto-crop last frames option
- [Feature] Added guard jump first basic implementation + replays for advanced scenarios (courtesy of @Shodokan)
- [Feature] Added "ordered" and "repeat ordered" replay modes
- [Feature] Blocking system is now working in 4rd Strike (thanks to @speedmccool25 frame data recording)
- [Bugfix] Fixed random parry not behaving properly
- [Bugfix] Fixed self-cancellable LP/LK not correctly blocked on various characters
- [FrameData][Q] added missing back mp + SA2

### v0.9 (04/04/2021)
- [Feature] Projectiles are now blocked/parried
- [Feature] The dummy will now counter-attack on landing after an air recovery
- [Feature] Yun's Genei Jin is now fully blocked/parried by the dummy
- [Feature] Added 4rd Strike rom support in collaboration with @speedmccool25, but no frame data recorded yet.
- [Improvement] When loading a save state, the recording state is reset to a useful state depending on the state you were before
- [Bugfix/Improvement] All characters can now block/parry meaties and all first frame wake up hits
- [Bugfix/Improvement] Fixed a lot of bugs in the overall blocking/parrying/counter-attack system
- [Bugfix/Improvement] Revamped the wake-up / fast wake-up triggering and counter-attack system to be more reliable and maintainable
- [Bugfix] Fixed recordings not loading correctly on US-regioned machines

### v0.8 (23/12/2020)
- [Feature] Special trainings section + parry special training
- [Feature] Stun delayed reset mode
- [Improvement] Added new menu categories and made a better split of options between them
- [Improvement] Changed counter-attack random deviation cap from 40 to 600
- [Bugfix] Fixed incorrect index causing errors when using random replay and weights
- [Bugfix] [issue#21](https://github.com/Grouflon/3rd_training_lua/issues/21) When the game is paused and hitboxes are enabled, an error occurs when loading a savestate
- [Bugfix] [issue#29](https://github.com/Grouflon/3rd_training_lua/issues/29) If you make a recording and rename it with lower case or space in its name, it won't launch
- [Bugfix] [issue#22](https://github.com/Grouflon/3rd_training_lua/issues/22) Input flipping is now decided upon character position diff instead of sprite flip (should fix wrong manipulations occuring after some moves)
- [Bufix] [Fixed meter gauges not updating after loading a save state](https://trello.com/c/7eMUwOHg/76-meter-refill-does-not-update-max-values-correctly-when-coming-back-to-select-screen-or-using-save-states)
- [FrameData] Added some missing Makoto wake up data
- [FrameData] Added some missing Ken wake up data
- [FrameData] Added some missing Ibuki frame data

### v0.7 (12/11/2020)
- Changed main supported emulator from FBA-rr to Fightcade's FBNeo fork
- [Feature] Main player now acts as the training dummy during recording and pre-recording
- [Feature] Added input history display for both players
- [Feature] Added a weight to each replay slot to control randomness (Contribution of @BoredKittenz)
- Redesigned controller display
- [Bugfix] [issue#8](https://github.com/Grouflon/3rd_training_lua/issues/8) Cannot Link moves into super
- [Bugfix] [issue#15](https://github.com/Grouflon/3rd_training_lua/issues/15) Time based super like geneijin not consistent with their meter usage
- [Bugfix] [issue#19](https://github.com/Grouflon/3rd_training_lua/issues/19) Error: Failed to save training settings to training settings.json
- [Bugfix] [issue#18](https://github.com/Grouflon/3rd_training_lua/issues/18) Another Big Issue: Constant Negative Edge While Recording
- [Bugfix] [issue#17](https://github.com/Grouflon/3rd_training_lua/issues/17) Large Issue : P2 cannot do EX moves even if they have meter

### v0.6 (04/04/2020)
- Can save/load recorded sequences to/from files
- Keep recordings between sessions (saved per character inside training_settings.json)
- Added counter-attack delay and maximum random deviation to recording slots
- Random blocking mode won't stop blocking in the middle of a true blockstring
- Added First Hit blocking mode
- Added refill delay for life and meter into training settings
- [Bugfix] Fixed dummy bricking when triggering a recording counter attack with nothing recorded
- [Frame Data] Elena
- [Frame Data] Q
- [Frame Data] Ryu
- [Frame Data] Remy
- [Frame Data] Twelve
- [Frame Data] Chun-Li
- [Frame Data] Sean
- [Frame Data] Necro
- [Frame Data] Dudley
- [Frame Data] Yang
- [Frame Data] Yun

### v0.5 (23/03/2020)
- Auto refill life mode
- Auto refill meter mode + ability to set a precise meter amount from the menu
- Infinite Super Art Timer mode
- input autofire (rapid movement when holding key) in menus
- Frame data prediction can resync itself to the actual animation frame, and thus handle a lot more blocking situations
- All 2 hits blocking / parying Fixed
- Blocking / parying of self cancellable moves supported
- Improved wording of some menu elements
- [Bugfix] Fixed infinite meter not working for player 2
- [Bugfix] Fixed recording counterattack triggering in the middle of a blockstring
- [Bugfix] Fixed recording counterattack restarting on hit
- [Frame Data] Oro
- [Frame Data] Ken

### v0.4 (13/02/2020)
- Urien frame data
- Gouki frame data
- Makoto frame data
- Random fast wake up
- Random blocking
- Throws teching
- Added music volume control
- [Bugfix] Fixed Dudley not crouching correctly
- [Bugfix] Fixed Oro not crouching correctly
- [Bugfix] Do not counter attack on state load anymore

### v0.3 (28/01/2020)
- Can now record sequences within 8 different slots
- Can play recorded sequences repeatedly and on random
- Recorded sequences can by triggered as a counter-attack

### v0.2 (26/01/2020)
- New blocking system: Now works by recording hitboxes characteristics to a file for every move and predict hitbox collisions with actual frame data.
- Can switch main player between P1 and P2
- Removed all old frame data
- Entered frame data for Ibuki, Alex and Hugo

### v0.1 (25/11/2019)
- Basic blocking and training options
- Can set dummy to block, parry and red parry after x hits
- Can set dummy to counter-attack with any move after hit, block parry or wake up
- Entered frame data by hand for Ibuki and Urien
