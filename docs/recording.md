# Recording

![Recording](../screenshots/recording.png)

Record and manage input sequences across up to 8 slots. Control playback order, timing, and save/load sequences to files.

| Option | Description |
|--------|-------------|
| Auto Crop First Frames | Automatically remove leading empty frames (no input) when recording ends. |
| Auto Crop Last Frames | Automatically remove trailing empty frames when recording ends. |
| Replay Mode | Order in which multiple slots are played back: normal (current slot only), random, ordered (sequential), or repeat variants that loop each slot before moving to the next. |
| Slot | Currently active slot for recording and playback (slots 1–8). |
| Weight | Probability weight for this slot in random replay mode — higher values mean it is selected more often (0–100). |
| Counter-attack delay | Frame offset for the counter-attack trigger. Negative values fire earlier, positive values fire later (range: −40 to 40). |
| Counter-attack max random deviation | Maximum random frame deviation applied to the counter-attack trigger timing (range: −600 to 600). |
| Clear slot | Erase all recorded data in the currently selected slot. |
| Clear all slots | Erase recorded data in all 8 slots at once. |
| Save slot to file | Save the current slot's recording to a file (opens a save dialog). |
| Load slot from file | Load a recording from a file into the current slot (opens a load dialog). |

---

## Guard Jump

The way guard jump works is that there are situations where you are throw invulnerable (cannot be thrown). These situations are after a reset, knockdown and blocking or being hit by an attack. This unthrowable state lasts for 6 frames.  Guard jump should be input to block for this duration, jumping in a direction and then blocking again.

The current implementation of Counter-Attack Move does not work with how guard jump functions and needs to be input for all of these situations.  

This is because it requires pre-buffered frames of input (the assumption of holding block beforehand in this case).  

Because of its current implementation it will only work properly when knocked down. So in the other listed situations such as being reset or your opponent going for a tick throw, the Counter-Attack Move version in the dummy menu will get thrown if timed correctly.

To properly test guard jump in these situations you must use provided replays.

To use these replays go to the recording menu and follow these steps;

1. Pick a slot you wish to load the replay into
2. Navigate to "Load slot from file" and hit Light Punch
3. Use left and right on your lever or keyboard to navigate the files in your recordings folder and find the Guard Jump you wish to use.
4. Make sure the replay slot where this is loaded is active and replay mode is set to normal.
5. Set "Counter Attack - Delay" in the recording menu to -4 (NEGATIVE 4) for each Guard Jump replay used.
6. Navigate to the "Dummy" menu and set "Counter Attack - Move" to none, and "Counter Attack - Action" to recording.

Now every time your opponent is knocked down, is reset, blocks or gets hit it will attempt to guard jump in the direction of the replay used.

There are three files provided;
1. Neutral Guard jump
2. Guard Jump Back (most commonly used and is what Guard Jump in the Dummy menu currently uses)
3. Guard Jump Forward (To get out of the corner or just try to jump over you)

If you want randomization between the three replays then simply load each one into a different replay slot and use the "Random" replay mode with no other replay slots populated.
