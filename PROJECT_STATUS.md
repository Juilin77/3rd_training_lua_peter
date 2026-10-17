# Project Status

A concise, public-safe snapshot of this repo's current state, kept up to date alongside
releases. For the full, detailed changelog see the README's Changelog section. This file is
meant for quick machine- or human-readable status checks without needing to dig through commit
history.

## Last verified
2026-10-17

## Version / branch
v0.30, branch `master`

## verified_code_commit
`dbd54d7` — the code state the "Completed since last update" and "Verification" sections
below actually describe. Updating this file is itself a commit after this one, so don't treat
this file's own latest commit as equal to `verified_code_commit`; run `git log -1 --
PROJECT_STATUS.md` for that (`status_source_commit`).

## Completed since last update
- Frame Table's Start/Total/Advantage are now computed from the attack or parry's own startup
  instead of the display timeline, matching Display Frame Advantage's definition
- Frame Table's dimmed residual only shows for a true 90-frame continuation, not every new
  action, so repeated reps start on a clean row
- Frame Table correctly shows startup/active for a counterattack or reversal, and correctly
  shows hitstun instead of startup/recovery when both players trade hits at the same time
- Ping Delay no longer stretches the first real input to extra output frames on buffer creation

## Verification
All v0.30 changes were verified in-game by the maintainer across multiple scenarios (parry
lockout recovery, jump-to-air-attack timing, movement/mash/cancel-chain display behavior,
reversal timing, simultaneous trades, knockdown/wakeup, SA Only mode), not just reviewed as
code.

## Open work
- Dummy Blocking: Makoto SA2 (command grab) and SA3 (power-up mode) not yet verified
- SA Blocking systemic fix: Ryu SA2 and Elena SA2 still need migrating to the offset-table
  approach, plus roughly 9 more characters not yet covered
- Follow Character for Tech Throw: implemented but commented out, pending a per-character
  push-box-height calculation
- A Red Parry timing fix and a Frame Trap display change exist as uncommitted local work, not
  yet verified in-game

## Next priorities
Not yet ordered — to be set by the maintainer.

## Open questions (public-safe)
None currently.
