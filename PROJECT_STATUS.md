# Project Status

A concise, public-safe snapshot of this repo's current state, kept up to date alongside
releases. For the full, detailed changelog see the README's Changelog section. This file is
meant for quick machine- or human-readable status checks without needing to dig through commit
history.

## Last verified
2026-11-07

## Version / branch
v0.34, branch `master`

## verified_code_commit
`7be076c` — the code state the "Completed since last update" and "Verification" sections
below actually describe. Updating this file is itself a commit after this one, so don't treat
this file's own latest commit as equal to `verified_code_commit`; run `git log -1 --
PROJECT_STATUS.md` for that (`status_source_commit`).

## Completed since last update
- v0.32: Fixed three Frame Table bugs found during a single bug hunt — the first captured cell
  disappearing after a savestate reload, a jump's first frame missing a pre-classify gate, and
  a same-kind trigger (dash/mash) crossing the 90-frame display cap being wrongly treated as a
  new trigger instead of a continuation. Peter's final call: jump removed entirely from the
  Frame Table (its variable, repeatable length was the root cause of nearly all these bugs);
  dash remains
- v0.33: Red Parry now blocks the first N hits then parries every hit from hit N+1 onward,
  instead of stopping after a single designated hit, and a follow-up fix stopped the hit
  counter from resetting itself mid-attack (found during manual testing on a 6-hit attack)
- v0.34: Added a Ryu SA3 Denjin Hadoken charge-level training display (Special Training mode;
  cumulative charge gauge + independent pure-charge-duration stopwatch); extended the Red Parry
  hit-count reset to also cover SA/projectile activations using an animation not registered in
  the frame-data table (e.g. Gouki SA1); renamed the entry scripts to match the repo rename
  (`3rd_training.lua` → `sf33rd_training.lua`, `3rd_spectator.lua` → `sf33rd_spectator.lua`)

## Verification
v0.32's three Frame Table fixes and the jump-removal decision were all verified in-game by the
maintainer before release. v0.33's Red Parry N-hit change was verified in-game on Gouki SA1
(N=1 and N=2, both confirmed correct); the mid-attack counter-reset follow-up fix was found and
confirmed via the same manual testing process. v0.34's Denjin Hadoken display was iterated and
verified in-game by the maintainer against Frame Table's own frame count across multiple bug
rounds (stale-value flash, fill direction, tick positions, off-by-one frame count, counting
through superfreeze/projectile flight, savestate-reload staleness). The blocked_hit_count reset
fix's SA-activation half is a reviewed, low-risk addition; its projectile-listening half has a
known residual risk (see Open work / Issue #15) accepted as-is by the maintainer, not separately
verified in-game yet.

## Open work
- GitHub Issue #7 (open): Makoto SA2 (force_recording carry) — Parry never triggers, all hits
  land as a block instead
- GitHub Issue #8 (open): Gouki red fireball (5B/HP) — the live projectile predictor registers
  a false hit, wasting the parry before the real hit lands
- GitHub Issue #15 (open): the blocked_hit_count reset's projectile-listening rising edge isn't
  a fully reliable new-attack boundary for multi-hit projectiles with hitbox gaps between hits;
  needs redesigning to key off attack identity/lifecycle instead
- Dummy Blocking: Makoto SA3 (power-up mode) not yet verified
- SA Blocking systemic fix: Ryu SA2 and Elena SA2 still need migrating to the offset-table
  approach, plus roughly 9 more characters not yet covered
- Follow Character for Tech Throw: implemented but commented out, pending a per-character
  push-box-height calculation

## Next priorities
Not yet ordered — to be set by the maintainer.

## Open questions (public-safe)
None currently.
