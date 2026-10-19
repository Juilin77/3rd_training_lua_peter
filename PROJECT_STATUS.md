# Project Status

A concise, public-safe snapshot of this repo's current state, kept up to date alongside
releases. For the full, detailed changelog see the README's Changelog section. This file is
meant for quick machine- or human-readable status checks without needing to dig through commit
history.

## Last verified
2026-10-19

## Version / branch
v0.31, branch `master`

## verified_code_commit
`1de5c88` — the code state the "Completed since last update" and "Verification" sections
below actually describe. Updating this file is itself a commit after this one, so don't treat
this file's own latest commit as equal to `verified_code_commit`; run `git log -1 --
PROJECT_STATUS.md` for that (`status_source_commit`).

## Completed since last update
- Frame Table now gives a player's own Super Art activation freeze display priority over
  active/projectile/parry, so canceling a hit-confirmed normal into an SA shows the correct
  freeze color instead of red
- Added a Guard Type sub-option under Dummy's Blocking Mode (Always only): All, Stand Only, or
  Crouch Only
- Fixed a Missions-menu crash on a public-only install (no private pattern-scan tool) when
  Analyze Raw Mission for Bookmarks is enabled
- Recording a Raw Mission now keeps its target slot fixed for the whole recording, and
  Clear Raw Slot/Clear All Raw Slots can no longer delete an actively-recording slot
- Per-character recordings no longer risk being saved under, or overwriting, a different
  character's file after a disk read issue; they also retry loading before giving up, keep
  unsaved edits intact across a character switch, and stop repeating the same console warning
- Added Clear Profile (via the renamed Manage Profiles) and Clear All Profiles; the default
  profile name now starts with PROFILE_<CHARACTER>_ with a longer allowed length
- Consistent indentation and Title Case for several menu sub-options (see README changelog for
  the full list)
- Fixed a missing letter (W) in the profile/filename text editor's character set

## Verification
The SA freeze display fix, the Guard Type feature (All/Stand Only/Crouch Only, all three
tested), and the menu indentation/Title Case changes were verified in-game by the maintainer.
The recording persistence fix was verified for the ordinary save/load/playback path after a
real in-game issue surfaced it; its specific retry, pending-table, and conflict-diagnostic code
paths were reviewed but not separately exercised in-game. The profile management additions
(Clear Profile, Clear All Profiles) and the public-only-install menu crash fix were reviewed but
not yet confirmed in-game by the maintainer.

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
