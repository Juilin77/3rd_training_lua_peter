# Project Status

A concise, public-safe snapshot of this repo's current state, kept up to date alongside
releases. For the full, detailed changelog see the README's Changelog section. This file is
meant for quick machine- or human-readable status checks without needing to dig through commit
history.

## Last verified
2026-11-14

## Version / branch
v0.36, branch `master`

## verified_code_commit
`1e54da2` — the code state the "Completed since last update" and "Verification" sections
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
- v0.35: bundles several fixes that had already been merged to `master` but not yet released,
  plus this session's new work. Gouki SA2 (8c28)'s activation hit was categorically unparryable
  under Parry/Red Parry — fixed via a memory-write cheat ported from effie3rd, plus a separate
  dispatch double-fire bug that held the forward press for 2 frames instead of 1 (Issue #34,
  closed; also resolves and closes Issue #30, same root cause). Also
  restored the melee admission physics engine for deep multi-hit combo parry failures
  (Issue #28); extended Gouki 5B's cooldown+hold admission fix to 5A (Issue #26); fixed Gouki
  5B/SA1 projectile false-early-prediction (Issue #8); corrected ~34 wrong/typo'd move-name
  comments across 12 characters; added Raw Mission/Pattern Replay walkthroughs and Denjin
  Hadoken docs
- v0.36: Added a Gouki Air Down K jump-apex timing trainer (Special Training mode: per-jump
  pre-drawn timeline, traveling pointer, success / too-early / too-late outcome readout) and a
  matching Display tab reference line (Issue #37, closed via PR #38). Went through 4 rounds of
  in-game iteration with the maintainer plus win-codex POST-implementation review (APPROVED after
  two revision rounds, catching a pointer-color/outcome-logic mismatch and two documentation
  inaccuracies). Also fixed two small pre-existing documentation gaps found along the way:
  Denjin Hadoken was missing from README's Main Features, and the Follow Character docs wrongly
  listed 720 mode as grayed out

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
verified in-game yet. v0.35's Issue #34 fix was tested extensively in-game by the maintainer
(hit1, hits 2-7, sides swapped, Red Parry N=1/N=2, nonzero residual cooldown, a whiff, and an
ordinary non-super attack as a regression check) and independently code-reviewed by win-codex
(APPROVED after one revision round). The other fixes bundled into v0.35 (Issues #8, #26, #28)
were each verified and reviewed at the time of their own merge, prior to this release pass — see
their respective PR history for that record, not repeated here.
- v0.36's Air Down K trainer was verified in-game by the maintainer across both jump types
  (normal and big forward jump): early/late/perfect timing outcomes, the too-early/too-late
  readout labels, the traveling pointer's color through a full descent, mode/match/player-
  identity invalidation (switching modes mid-jump, switching character/slot, leaving/re-entering
  a match, loading a savestate), and that neutral/backward jumps and non-jump airborne specials
  no longer start the tracker. One known, documented-not-fixed limitation shipped as-is: mashing
  the input button while an attempt is still unconfirmed could misattribute the outcome to the
  wrong press (not yet confirmed to actually happen in-game).

## Architecture: the prediction engine

A two-layer pipeline already drives most of the project's Block/Parry/Red Parry detection:
**PRIMARY** (`predict_hitboxes()` in `src/control/blocking.lua`, geometric hitbox/hurtbox
collision per simulated frame against real `frame_data`) and **FALLBACK**
(`predict_hits_simulation()` in `src/prediction.lua` → `src/data/prediction.lua`, a
physics-based simulation ported from the effie3rd reference mod, used when PRIMARY can't
resolve a hit). Issues #8, #26, and #28 were all fixed through this pipeline.

**Known hard limit, confirmed not a prediction-quality gap**: a 0/1-frame-startup Super Art's
activation hit can't be parried via real input timing at all, because the game doesn't sample
defender input into the parry-validity RAM byte during/immediately after the attacker's
superfreeze — no amount of better prediction changes that. Gouki SA2's hit1 (#30/#34) hit this
wall; the fix ported effie3rd's own workaround, a direct memory write forcing parry validity to
max for that one hit (shipped in v0.35). Expect the same workaround to be needed for any other
character's 0/1-frame-startup SA activation hit — an accepted exception to routing everything
through the real engine, not something to keep re-solving differently.

Long-term goal and tracking issue: #41 (every character/move using Block/Parry/Red Parry
correctly through this engine, except where the limitation above applies).

## Open work
- GitHub Issue #7 (open): Makoto SA2 (force_recording carry) — Parry never triggers, all hits
  land as a block instead
- GitHub Issue #15 (open): the blocked_hit_count reset's projectile-listening rising edge isn't
  a fully reliable new-attack boundary for multi-hit projectiles with hitbox gaps between hits;
  needs redesigning to key off attack identity/lifecycle instead
- GitHub Issue #22 (open): Gouki SA1 gets hit unblocked when projectile-correction block is active
- GitHub Issue #23 (open): audit other multi-hit projectiles for the cooldown+hold admission gap
  already fixed for Gouki 5B
- GitHub Issue #24 (open): investigate whether melee multi-hit moves need their own
  cooldown-style admission fix
- GitHub Issue #29 (open): Tatsumaki/hurricane-kick family — phantom block admission on
  non-connecting hit slots
- GitHub Issue #31 (open): Chun-Li EX-kick extension moves missing frame_data
- GitHub Issue #32 (open): PRIMARY admission occasionally grants near-zero timing margin after
  a freeze/hitstop stall
- GitHub Issue #41 (open, epic): tracks the items above plus the long-term goal of universal
  Parry/Red Parry coverage via the prediction engine — see Architecture section above
- Dummy Blocking: Makoto SA3 (power-up mode) not yet verified
- SA Blocking systemic fix: Ryu SA2 and Elena SA2 still need migrating to the offset-table
  approach, plus roughly 9 more characters not yet covered
- Follow Character for Tech Throw: implemented but commented out, pending a per-character
  push-box-height calculation

## Next priorities
Not yet ordered as a sequence, but the maintainer's current long-term focus is Issue #41
(universal Parry/Red Parry coverage via the prediction engine) — see Architecture section above.

## Open questions (public-safe)
None currently.
