-- src/data/sa_offsets.lua
-- Per-SA hit timing tables for Layer 0 super-freeze anchored blocking (TODO 1.33).
-- Anchor: t0 = the frame superfreeze_decount rises from 0 to positive (super flash start),
-- detected in src/control/blocking.lua.
--
-- Key: sa_offset_data[char_str][selected_sa]  (selected_sa = 1/2/3, read from RAM)
--
-- Entry semantics (three states):
--   table -> offset schedule available: block windows are driven at t0 + offset per hit,
--            dummy returns to neutral between windows
--   false -> explicit passthrough: Layer 0 stays out, the SA is already handled by existing
--            mechanisms (projectile system, hand-tuned force_recording carry, Phase 1/2)
--   nil   -> no data: fallback hold from t0 until the attacker fully recovers
--
-- Schedule entry fields:
--   hits     = { { offset = N, action = "block", type = T }, ... }
--              offset: frames from t0 to the hit. Measure with a debug session.
--                      Do NOT reuse the sa_p2_frame-anchored offsets from framedata_meta
--                      (first_hit_offset / p2_hit2_offset): their anchor is the Phase 2
--                      trigger frame at the END of the freeze, not t0.
--              action: "block" | "parry" | "red_parry". Only "block" is implemented;
--                      "parry" / "red_parry" are reserved for per-hit parry scheduling
--                      and are currently treated as "block".
--              type:   1 = any (keep current stance), 2 = low (down-back), 3 = high/mid (back)
--                      same convention as framedata_meta hits
--   hold     = optional block window width in frames after the hit frame (default 4);
--              a window covers [t0 + offset - 2, t0 + offset + hold]; overlapping windows
--              merge into a continuous hold. Layer 0 exits once the last window has elapsed
--              or the attacker fully recovers, whichever comes first.
--   max_dist = optional whiff check: at t0, if the hurtbox distance to the dummy is
--              greater than max_dist, the schedule is not activated (Layer 0 still
--              suppresses Phase 1/2 for that SA so the whiff does not trigger a hold)
--   variant_anims = reserved for SAs whose hit count depends on button strength
--                   (e.g. Makoto SA2 LK/MK/HK); not implemented yet. First version rule:
--                   put the LONGEST variant in hits - scheduling a window for a hit that
--                   never comes only holds block a little longer, which is harmless.
--
-- Example (offsets below are PLACEHOLDERS, fill in from a debug session before enabling):
-- sa_offset_data.makoto = {
--   [1] = { -- SA1 Seichuusen Godanzuki (sub-frame, invisible to per-frame prediction)
--     max_dist = 105,
--     hold = 4,
--     hits = {
--       { offset = 52, action = "block", type = 3 },
--       { offset = 55, action = "block", type = 3 },
--       { offset = 58, action = "block", type = 3 },
--       { offset = 61, action = "block", type = 3 },
--       { offset = 64, action = "block", type = 3 },
--     },
--   },
-- }

sa_offset_data = {
  -- Hand-tuned SAs keep their existing mechanisms and are NOT migrated (TODO 1.33 rule);
  -- they are marked false so neither the schedule nor the fallback interferes with them.
  ryu = {
    [1] = false, -- SA1 Shinkuu Hadoken: multi-hit projectile, projectile system handles it
    [2] = false, -- SA2 Shin Shoryuken: hand-tuned force_recording carry (framedata_meta 894c/8be4)
    [3] = false, -- SA3 Denjin Hadoken: unblockable projectile, parry style handles it
  },
  ken = {
    [1] = false, -- SA1 Shoryureppa: hand-tuned force_recording carry (framedata_meta 1214)
    [2] = false, -- SA2 Shinryuken: hand-tuned force_recording carry (framedata_meta 15b4)
    [3] = false, -- SA3 Shippu Jinraikyaku: existing force_recording entries (1834/1d24)
  },
  gouki = {
    [1] = false, -- SA1 Messatsu Gou Hadou: projectile system (projectiles 55/64)
  },
  q = {
    [1] = false, -- SA1 Critical Combo Attack: low hits (type 2), prediction loop blocks it crouching;
                 -- fallback would stand-block and get hit, so Layer 0 must stay out
    [2] = false, -- SA2 Deadly Double Combination: hand-tuned force_recording (framedata_meta 8464)
    [3] = false, -- SA3 Total Destruction: command grab, unblockable
  },
  -- Grab-type SAs are unblockable: mark false so Layer 0 does not hold block pointlessly
  -- while suppressing prediction. Gouki's hidden supers (Shun Goku Satsu, Kongou Kokuretsu Zan)
  -- cannot be expressed here: they are not selected_sa values, so they resolve to whatever
  -- SA is selected and may hit fallback -- harmless, the dummy gets grabbed/hit either way.
  alex = {
    [1] = false, -- SA1 Hyper Bomb: command grab
    [3] = false, -- SA3 Stun Gun Headbutt: command grab
  },
  hugo = {
    [1] = false, -- SA1 Gigas Breaker: command grab
    [2] = false, -- SA2 Megaton Press: command grab (catches jumps)
  },
  oro = {
    [1] = false, -- SA1 Kishin Riki: command grab (EX included)
  },
  necro = {
    [2] = false, -- SA2 Slam Dance: command grab
    [3] = false, -- SA3 Electric Snake: floor current, all hits LOW; neither fallback nor the
                 -- projectile system crouch-blocks it (verified in-game 2026-07-05, same as
                 -- pre-1.33) -- needs low-block support in projectile prediction, not an offset
                 -- table, because projectile arrival timing depends on distance
  },
  ibuki = {
    [2] = false, -- SA2 Yoroi Doshi: close version is an unblockable grab; far fireball version
                 -- is handled by the projectile system, which Layer 0 never gates anyway
    [3] = false, -- SA3 Yami Shigure: knives hit LOW; neither fallback nor the projectile
                 -- system crouch-blocks them (verified in-game 2026-07-05, same as pre-1.33),
                 -- see necro SA3 note
  },
  -- makoto is deliberately ABSENT (nil -> fallback): her hand-tuned entries (SA1 1438
  -- force_recording + proxy_hits, SA2 force_recording group) never worked reliably --
  -- that failure is why TODO 1.33 exists. Fallback hold overrides them on purpose.
  -- Upgrade path: measure per-hit offsets in a debug session and add a schedule table here.
  elena = {
    [2] = false, -- SA2 Brave Dance: existing force_recording entries with per-hit low types (4dc4/5074)
  },
}
