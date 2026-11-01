# Project Status

A concise, public-safe snapshot of this repo's current state, kept up to date alongside
releases. For the full, detailed changelog see the README's Changelog section. This file is
meant for quick machine- or human-readable status checks without needing to dig through commit
history.

## Last verified
2026-10-31

## Version / branch
v0.33, branch `master`

## verified_code_commit
`92c2ccf` — the code state the "Completed since last update" and "Verification" sections
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

## Verification
v0.32's three Frame Table fixes and the jump-removal decision were all verified in-game by the
maintainer before release. v0.33's Red Parry N-hit change was verified in-game on Gouki SA1
(N=1 and N=2, both confirmed correct); the mid-attack counter-reset follow-up fix was found and
confirmed via the same manual testing process.

## Open work
- GitHub Issue #7 (open): Makoto SA2 (force_recording carry) — Parry never triggers, all hits
  land as a block instead
- GitHub Issue #8 (open): Gouki red fireball (5B/HP) — the live projectile predictor registers
  a false hit, wasting the parry before the real hit lands
- Dummy Blocking: Makoto SA3 (power-up mode) not yet verified
- SA Blocking systemic fix: Ryu SA2 and Elena SA2 still need migrating to the offset-table
  approach, plus roughly 9 more characters not yet covered
- Follow Character for Tech Throw: implemented but commented out, pending a per-character
  push-box-height calculation

## Next priorities
Not yet ordered — to be set by the maintainer.

## Open questions (public-safe)
None currently.
