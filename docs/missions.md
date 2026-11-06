# Missions

![Missions](../screenshots/missions.png)

Record and replay full matches (Raw Missions) across dedicated slots, and replay individual attack patterns against the dummy.

Pattern files come from two independent sources: patterns you've curated by hand (just `.json`/`.inputs.json` files dropped into `patterns/<character>/`), and the Bookmark Scan tools below, which analyze a recorded Raw Mission and cut out attack patterns automatically.

**Note:** Bookmark Scan's analysis step depends on a separate private tool that isn't included in this repository. The menu options are there, but without that tool, scanning won't find anything to play back. Everything else on this tab (Raw Mission recording/replay, Pattern Replay, and all the Clear options) works standalone.

## Step by Step

### 1. Record a Raw Mission

Raw Missions capture a full match (both players, every frame) into a slot, savestate included, so you can replay it later exactly as it happened.

1. Open the training menu (**Start**), go to the **Missions** tab.
2. Turn **Recording Mission Mode** On. (This grays out Dummy, Recording, Rules, and Special Training while active.)
3. Set **Record Raw Mission in Slot** to the slot you want to record into.
4. Close the menu.
5. Go to [fightcade.com/game/sfiii3nr1/replays](https://www.fightcade.com/game/sfiii3nr1/replays) and pick a match, then click **View replay** so FBNeo loads and plays it back with the Lua script still attached.
6. While the replay is playing, press **Alt+5** to start recording — this is a keyboard hotkey, not a menu option. It also takes a savestate at this instant, so playback always starts from exactly here.
7. Let the replay play out to capture whatever you want.
8. Press **Alt+5** again to stop. The mission saves automatically and the slot selector auto-advances to the next empty slot — there are 10 slots total, so you can capture up to 10 segments this way.
9. Open the menu again and turn **Recording Mission Mode** Off. The other tabs become usable again.

### 2. Replay a Raw Mission

1. Turn **Replay Raw Mission for Slot** On (this gate unlocks the three options below).
2. Set **Raw Mission Slot** to the one you recorded.
3. Set **Play Side** — which side the dummy plays back (1P or 2P).
4. Turn **Replay Raw Mission** On to start playback; toggle Off to stop.

### 3. Scan a Raw Mission for attack patterns (Bookmark Scan)

> Requires the separate private analysis tool mentioned above. If you don't have it, skip to Section 4 — hand-placed pattern files work the same way.

1. Make sure you have a recorded Raw Mission (Section 1).
2. Turn **Analyze Raw Mission for Bookmarks** On (gate).
3. Set **Analyze Raw Mission Slot** to the match you want to scan.
4. Choose the analyzer with **Scan Pattern for Character**, then confirm with **LP** to run it.
5. Scanned patterns are saved into `patterns/<character>/` and become selectable in Pattern Replay below.

### 4. Play back a pattern (Pattern Replay)

For your own curated patterns, drop `.json`/`.inputs.json` files into `patterns/<character>/` — the same steps below apply, scanned or hand-placed.

1. Select your P2 character and equip the Super Art the pattern expects.
2. Turn **Analyze Raw Mission for Bookmarks** On. (This also loads the character list patterns/ were found under — same step needed even for hand-placed files.)
3. Set **Pattern Character** to the matching character.
   - Only characters with a pattern matching your current P2 character + SA combo will appear.
4. Pick a specific file under **Pattern (P2: ?)**.
   - Shows "empty" until a scan or hand-curated files produce a match.
5. (Optional) Set **Pattern Replay Mode**: `normal` (selected pattern only), `random`, `ordered`, or `repeat` (loop current pattern).
6. Turn **Pattern Replay** On to play it against your dummy; toggle Off to stop.

#### Example: the included Ken patterns

`patterns/ken/` ships with 3 ready-made bookmark patterns (a combo into SA3, and two throws) — no scanning or private tooling needed, they're hand-picked `.json` files you can play back right away:

1. Select Ken as P2, with SA3 equipped.
2. Turn **Analyze Raw Mission for Bookmarks** On.
3. Set **Pattern Character** to `ken`.
4. Pick one of the 3 files under **Pattern (P2: KEN)**.
5. Turn **Pattern Replay** On to play it against your Ken.

### 5. Clear saved data

**Raw Missions:**

| Action | Steps |
|---|---|
| Clear one slot | **Clear Raw Slot** → select slot → confirm with **LP** (a confirmation message shows for 5 frames) |
| Clear all slots | Select **Clear All Raw Slots** |

**Bookmark patterns:**

1. Turn **Clear Bookmark Slot** On (gate).
2. Set **Character** to the character whose patterns you want to browse.
3. Then either:
   - **Bookmark Slot** → select a file → confirm with **LP** to delete it
   - **Clear Chara All Bookmark Slot** → deletes all patterns for the selected character
   - **Clear All Bookmark Slot** → deletes all patterns for every character, regardless of the gate or selected Character

## Option Reference

| Option | Description |
|--------|-------------|
| Recording Mission Mode | Enable Raw Mission record mode. While on, the Dummy, Recording, Rules, and Special Training tabs are grayed out. |
| Record Raw Mission in Slot | Choose which Raw Mission slot to record a full match into. Only active while Recording Mission Mode is on. |
| Replay Raw Mission for Slot | Gate for replaying a recorded Raw Mission. Enables "Raw Mission Slot", "Play Side", and "Replay Raw Mission" below. |
| Raw Mission Slot | Choose which recorded Raw Mission to replay. |
| Play Side | Which side the dummy plays during Raw Mission replay: 1P or 2P. |
| Replay Raw Mission | Start or stop replaying the selected Raw Mission (toggle: start / stop). |
| Analyze Raw Mission for Bookmarks | Gate for the Bookmark Scan tools. Enables "Analyze Raw Mission Slot" and "Scan Pattern for Character" below. |
| Analyze Raw Mission Slot | Choose which recorded Raw Mission to scan for attack patterns. |
| Scan Pattern for Character | Choose the analyzer, then confirm with LP to run it against the selected Raw Mission Slot. Requires the separate private analysis tool mentioned above. |
| Pattern Character | Choose which character's bookmark patterns "Pattern (P2: ?)" below lists. Only shows entries if your live P2 character and SA match a character that has scanned patterns. |
| Pattern (P2: ?) | Select a pattern file to use for Pattern Replay. Shows "empty" until a scan (or hand-curated files in `patterns/<character>/`) produces a match. |
| Pattern Replay Mode | Playback order for patterns: normal (selected pattern only), random, ordered, or repeat (loop current pattern). |
| Pattern Replay | Start or stop pattern replay against the dummy (toggle: start / stop). |
| Clear Raw Slot | Select a Raw Mission slot and confirm with LP to erase it. A confirmation message appears for 5 frames. |
| Clear All Raw Slots | Erase every Raw Mission slot at once. |
| Clear Bookmark Slot | Gate for deleting bookmark pattern files. Enables "Character", "Bookmark Slot", and "Clear Chara All Bookmark Slot" below. |
| Character | Choose which character's bookmark patterns to browse for deletion. |
| Bookmark Slot | Select a bookmark pattern file and confirm with LP to delete it. |
| Clear Chara All Bookmark Slot | Erase every bookmark pattern belonging to the character currently selected above. |
| Clear All Bookmark Slot | Erase every bookmark pattern for every character, regardless of the Clear Bookmark Slot gate or selected Character. |
