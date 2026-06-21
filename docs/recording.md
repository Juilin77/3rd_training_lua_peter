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
