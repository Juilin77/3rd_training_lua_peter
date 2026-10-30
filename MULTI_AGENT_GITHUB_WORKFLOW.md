# Multi-Agent GitHub Workflow (Peter + CC + Codex 9527)

Single canonical source for the approval-gate policy and review-verdict rules shared by this
project's CC-facing `CLAUDE.md` and Codex-facing `AGENTS.md` — both files just link here instead
of duplicating this content. Checked into git (unlike `CLAUDE.md`/`AGENTS.md`, which are
gitignored and stay local per machine) so Windows CC, Mac CC, and anyone reading the repo see the
same rules.

## Approval gates

Each of these needs Peter's own explicit approval, separately — approving one never implies the
next:

- **Commit**: needs approval.
- **Feature branch push** (e.g. to open a PR for review): needs approval for that exact commit
  SHA. Approval does not extend to commits added afterward. No version bump / changelog /
  `gh release create` required for this — those are release-only (see below).
- **Opening a PR**: does NOT need a separate ask once the underlying push was already approved —
  it's the natural extension of that push (feature-branch pushes in this project exist to get a
  Codex/human review via PR in the first place), it never touches `master`, and it's trivially
  reversible (close it). Added 2026-10-31 after `master` got branch protection forcing all
  changes through a PR.
- **Merge PR into master**: always its own separate approval, independent of the push approval.
  Merging does not itself trigger a formal release.
- **Formal Release** (cutting a new version for users): a different, heavier process — see
  `.claude/commands/release.md`. Peter saying "push" when he means a formal release still
  requires that full flow (version bump, changelog, `startup.lua`/`3rd_training.lua` update,
  `gh release create`) before `git push` — never skip it to push directly.

## Merge-readiness check: is the last review still fresh?

Before asking Peter for merge approval, re-fetch the PR's current state and compare it against
the last recorded Codex (9527) review:

```
gh pr view <N> --json headRefOid,baseRefOid
```

Compare both SHAs against the `reviewed_head_sha` / `reviewed_base_sha` recorded in the last
review (see `AI-Workspace/reviews/.../POST_IMPLEMENTATION_REVIEW.md` for this project's reviews).
If either SHA differs — including when the diff changed because Peter asked for a different
design mid-session, not just because a new commit was tacked on — the review is stale. Do not
reuse an old APPROVED verdict. Get a fresh Codex review, with a newly recorded verdict and SHA
pair, before requesting merge approval from Peter.

(Discovered the hard way 2026-10-31: Issue #6's original review approved a latch-based "parry
exactly one designated hit" design; Peter later asked for a different "block N hits, parry every
hit after" design instead, which replaced that latch entirely — the old APPROVED no longer
covered what was actually in the PR.)

## Review verdict vocabulary (Codex 9527)

Pre-implementation (used in `PRE_IMPLEMENTATION_REVIEW.md` before CC starts implementing):

- **READY**: implementation may proceed as proposed.
- **REVISE_PLAN**: the approach needs changes before implementation starts.
- **NEEDS_PETER**: an unresolved risk or disagreement requires Peter's decision.

Post-implementation (used in `POST_IMPLEMENTATION_REVIEW.md` after CC implements):

- **APPROVED**: no blocking issues found in the reviewed scope. Does NOT authorize push or merge
  on its own — those are still separate approvals from Peter.
- **REVISE**: specific issues require correction.
- **NEEDS_PETER**: a requirement, trade-off, or behavior requires Peter's decision.

**Escalation threshold**: ordinary technical disagreements between CC and 9527 are resolved
between them without involving Peter. Escalate to NEEDS_PETER only when 9527 identifies a real
risk, likely breakage, or a fundamental problem, and CC still wants to proceed with the original
plan despite that. A disagreement CC simply accepts and revises in response to is not an
escalation.

## Roles (brief)

- **Peter**: sets requirements/priorities, does all in-game testing (no automated tests in this
  project), reports bugs, makes final calls, is the only source of approval for the gates above.
- **CC**: implements, fixes bugs, consults 9527 for independent review, executes approved
  commits/pushes/PRs/merges.
- **Codex 9527**: independent reviewer, read-only — never commits, pushes, or merges. May only
  edit its own `AGENTS.md` and its own owned review section(s) inside `CONTEXT.md`.
