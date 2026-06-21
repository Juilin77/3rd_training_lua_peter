# Guard Jump

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


Providing these replays prevents headache for users figuring out how to properly generate these replays and make them function in any given situation where it is applicable.

Hopefully these replays helps users practice against this technique while the "Counter Attack" functionality is being re-written.  These replays won't be required forever unless you want to use them in some advanced use case.

But for now its best to add this feature so people can know of it's existence and provide replays for advanced players that wish to practice against it in non knockdown scenarios.

These replays are also provided for the purpose of randomized reaction or ordered reaction training for advanced users.

If you want randomization between the three replays then simply load each one into a different replay slot and use the "Random" replay mode with no other replay slots populated.

One such advanced use case example would be a Makoto player using the ability use replay weighting to simulate weighted decisions in order to practice post hayate mixups against an opponent that favors specific types of defensive options.

Thank you for your support in this matter and please enjoy!
