-- src/data/sa_offsets.lua
-- Per-SA hit timing tables for Layer 0 super-freeze anchored blocking (TODO 1.33).
-- Anchor: t0 = the frame superfreeze_decount rises from 0 to positive (super flash start),
-- detected in src/control/blocking.lua.
--
-- Key: sa_offset_data[char_str][selected_sa]  (selected_sa = 1/2/3, read from RAM)
-- Anim override: sa_offset_data[char_str].anims["<anim_id>"] takes priority over the
-- selected_sa slot -- for hidden supers (Gouki SGS / KKZ) that flash without changing
-- selected_sa. Same three-state semantics (table / false / nil falls through to the slot).
-- The capture tool prints anim=<id> at t0 to identify them.
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
--              a window covers [t0 + offset - 2, t0 + offset + hold]. Each hit may carry
--              its own hold override: set it to reach the next window (next offset - 2)
--              to chain a true blockstring (gap shorter than blockstun) into one
--              continuous guard -- dropping to neutral inside a blockstring breaks the
--              game's guard chain and later hits connect; overlapping windows
--              merge into a continuous hold. Layer 0 exits once the last window has elapsed
--              or the attacker fully recovers, whichever comes first.
--   max_dist = optional whiff check: at t0, if the hurtbox distance to the dummy is
--              greater than max_dist, the schedule is not activated
--   far_mode = what happens beyond max_dist: default is suppress (assume the SA whiffs,
--              right for stationary moves); "fallback" holds block until recovery instead,
--              for full-travel moves (e.g. Ken SA3 crosses the whole screen) where the SA
--              still connects from any range but arrives later than the measured offsets (Layer 0 still
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
    [1] = { -- SA1 Shoryureppa, captured 2026-07-19 at dist 20/24 (offsets steady within
            -- 1 frame): 10 hits in three shoryu clusters. Clusters 1-2 chain into one
            -- guard (gaps <= 14f, inside blockstun); the only real gap is before the
            -- third shoryu (neutral ~100-112). Its first window opens early (offset 115
            -- for a 117-118 arrival) because a from-neutral re-block needs more lead.
            -- At range only the tail connects with shifted timing (dist 145 -> hit at 89),
            -- so far_mode falls back to a proximity-gated hold.
      max_dist = 60,
      far_mode = "fallback",
      hold = 4,
      hits = {
        { offset = 51, action = "block", type = 3, hold = 6 },
        { offset = 58, action = "block", type = 3, hold = 7 },
        { offset = 66, action = "block", type = 3, hold = 13 }, -- chains across the 14f gap
        { offset = 80, action = "block", type = 3, hold = 6 },
        { offset = 87, action = "block", type = 3, hold = 7 },
        { offset = 95, action = "block", type = 3 },            -- neutral gap follows
        { offset = 115, action = "block", type = 3, hold = 8 }, -- third shoryu, early open
        { offset = 124, action = "block", type = 3, hold = 6 },
        { offset = 131, action = "block", type = 3, hold = 7 },
        { offset = 139, action = "block", type = 3 },
      },
    },
    [2] = { -- SA2 Shinryuken, captured 2026-07-19 at dist 19/20/58: offsets identical at
            -- every range (vertical move, no travel). 3 hits connect point blank, a 4th
            -- at slight range (72) -- scheduled too, its window just passes unused when
            -- it whiffs. All gaps 6-8f: one chained guard, no real segmentation point.
      max_dist = 100,
      hold = 4,
      hits = {
        { offset = 52, action = "block", type = 3 },
        { offset = 58, action = "block", type = 3 },
        { offset = 64, action = "block", type = 3, hold = 6 },
        { offset = 72, action = "block", type = 3 },
      },
    },
    [3] = { -- SA3 Shippu Jinraikyaku, captured 2026-07-19 at dist 18 and 81 (offsets
            -- steady within 1 frame): 5 hits 14-16f apart -- one true blockstring, so
            -- every window chains via per-hit hold into a single continuous guard.
            -- Replaces the hand-tuned force_recording entries (1834/1d24) which could
            -- only hold until full recovery; this exits right after the last hit.
            -- SA3 travels the full screen, so beyond the measured range it falls back
            -- to a plain hold (far_mode) instead of assuming a whiff.
      max_dist = 110,
      far_mode = "fallback",
      hold = 4,
      hits = {
        { offset = 52, action = "block", type = 3, hold = 14 },
        { offset = 68, action = "block", type = 3, hold = 12 },
        { offset = 82, action = "block", type = 3, hold = 14 },
        { offset = 98, action = "block", type = 3, hold = 14 },
        { offset = 114, action = "block", type = 3 },
      },
    },
  },
  gouki = {
    [1] = false, -- SA1 Messatsu Gou Hadou: projectile system (projectiles 55/64)
    [2] = { -- SA2 Messatsu Gou Shoryu, captured 2026-07-19 at dist 24 (two identical runs):
            -- three shoryu clusters, 7 hits, real neutral gaps after clusters 1 and 2.
            -- Cluster openers after a gap start early (offset -2 extra lead) because a
            -- from-neutral re-block needs it. Third cluster hits are 20f apart --
            -- borderline with blockstun, chained to be safe. He lunges forward, so at
            -- range the timing shifts completely (dist 124 -> 91/111/132): far_mode.
      max_dist = 50,
      far_mode = "fallback",
      hold = 4,
      hits = {
        { offset = 51, action = "block", type = 3, hold = 7 },
        { offset = 60, action = "block", type = 3 },             -- neutral gap follows
        { offset = 81, action = "block", type = 3, hold = 9 },   -- cluster 2 opener, early
        { offset = 92, action = "block", type = 3 },             -- neutral gap follows
        { offset = 115, action = "block", type = 3, hold = 6 }, -- cluster 3: 20f apart, trying
        { offset = 135, action = "block", type = 3, hold = 6 }, -- individual early-open windows
        { offset = 155, action = "block", type = 3, hold = 6 }, -- to cut walk-back drift; if any
                                                                -- of these gets HIT, chain them
                                                                -- back (hold 24/20)
      },
    },
    [3] = { -- SA3 Messatsu Gou Rasen, captured 2026-07-19 at dist 23/27 (identical runs):
            -- stationary rising hurricane, 3 hits chained, whiffs already at dist 123
            -- so the default suppress handles range -- no far_mode needed. The schedule
            -- exits right after the last window instead of holding through his long spin,
            -- which is where most of the fallback drift (-128) came from.
      max_dist = 80,
      hold = 4,
      hits = {
        { offset = 54, action = "block", type = 3, hold = 6 },
        { offset = 62, action = "block", type = 3 },
        { offset = 68, action = "block", type = 3 },
      },
    },
    anims = { -- hidden supers: super flash without changing selected_sa (see header).
              -- Identified 2026-07-19 via the flash diagnostic: 9c98 = Kongou Kokuretsu
              -- Zan (KKZ, blockable quake), 9c18 = Shun Goku Satsu (raging demon -- it
              -- glides near full screen; its grab connect once masqueraded as a KKZ hit).
      ["9c98"] = { -- KKZ, verified point blank 2026-07-19: quake hit at t0+74, BLOCK.
                   -- Layered move: the close-range pillar (this hit) is UNPARRYABLE --
                   -- block only; the later outer wave IS parryable (future parry
                   -- scheduling: keep hit 1 as block, wave hits may be parry/red_parry).
                   -- The wave's timing at edge range is still unmeasured (its window
                   -- goes here once captured). Whiffs entirely by hurtbox dist ~141;
                   -- no max_dist on purpose -- a whiffed KKZ only costs ~10 frames of
                   -- pointless guard while a wrong cutoff would eat a hit.
        hold = 8,
        hits = {
          { offset = 74, action = "block", type = 3 },
        },
        -- KNOWN LIMITATION (investigated at length 2026-07-19, closed by Peter's call):
        -- in a narrow edge band (~hurtbox 141) a late lingering wave hits for 7 even
        -- while the dummy held guard for 6+ seconds (exit rel=375 verified) -- it lands
        -- with NO hit-connection events (no marker, no hit-count), outlives Gouki's
        -- recovery, yet a human can block it for 1 chip. Out of scope: the goal here is
        -- distance-aware standing block, which works at every practical range.
      },
      ["9c18"] = false, -- Shun Goku Satsu: unblockable command grab, nothing to schedule
    },
  },
  q = {
    [1] = { -- SA1 Critical Combo Attack, captured 2026-07-19 at dist 11/12 (identical
            -- runs): 5 hits ~21-26f apart, chained with a stance switch -- hit 4 is the
            -- LOW (crouch window, matches the KDTC parry guide); the hit-5 HITs in
            -- capture were combo carryover from the eaten low, it should be a mid.
            -- First mixed-height table in the pipeline. He dashes far: timing shifts by
            -- dist 141 and it still connects from 272, so far_mode with a wide gate.
      max_dist = 50,
      far_mode = "fallback",
      far_guard_dist = 120,
      far_type = 2, -- far fallback holds CROUCH: his punches are all crouch-blockable
                    -- while a standing hold eats the two lows (verified in capture)
      hold = 4,
      hits = {
        { offset = 56, action = "block", type = 3, hold = 21 },
        { offset = 79, action = "block", type = 3, hold = 21 },
        { offset = 102, action = "block", type = 3, hold = 21 },
        { offset = 125, action = "block", type = 2, hold = 24 }, -- low: crouch window
        { offset = 151, action = "block", type = 2 },            -- also low (both HIT a
                                                                 -- standing fallback)
      },
    },
    -- [2] opened for offset capture 2026-07-19 (was false -> hand-tuned force_recording
    -- 8464): the measured schedule table will replace this line
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
    [3] = { -- SA3 Hammer Frenzy, captured 2026-07-19 at dist 29: 5 hits, gaps 20-30f
            -- (borderline with blockstun) so every window chains into one guard. He
            -- walks forward swinging: at dist 191 only 2 hits connect at shifted times,
            -- hence far_mode. Note: two capture runs recorded stray PARRY events,
            -- likely a one-frame direction flip when Hugo crosses sides -- harmless
            -- (still a clean defense) but keep an eye on it.
      max_dist = 60,
      far_mode = "fallback",
      far_guard_dist = 160, -- his hammer connects from far outside body range: raise the
                            -- proximity gate so the guard is up before the reach, not
                            -- the body, arrives (HIT at dist ~130+ with the default gate)
      hold = 4,
      hits = {
        { offset = 56, action = "block", type = 3, hold = 22 },
        { offset = 80, action = "block", type = 3, hold = 25 },
        { offset = 107, action = "block", type = 3, hold = 18 },
        { offset = 127, action = "block", type = 3, hold = 28 },
        { offset = 157, action = "block", type = 3 },
      },
    },
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
  makoto = {
    [1] = { -- SA1 Seichuusen Godanzuki, captured 2026-07-19: hit 1 lands at t0+51
            -- (matches the startup measured for anim 1438). On block she stops after
            -- hit 1, so a single window is the complete block schedule; hits 2-5 only
            -- happen on hit. max_dist 105 comes from the old proxy_max_dist measurement.
      max_dist = 105,
      hold = 4,
      hits = {
        { offset = 51, action = "block", type = 3 },
      },
    },
    [2] = { -- SA2 Abare Tosanami, captured 2026-07-19 over 6 runs from point blank to
            -- dist 214: always 4 blocked hits (kick series + landing hit after the jump).
            -- Hits 1-3 are a true blockstring (20f apart, inside blockstun), so their
            -- windows chain via per-hit hold into one continuous guard -- dropping to
            -- neutral there breaks the game's guard chain and hits 2-3 connect.
            -- The only real gap is her jump before the landing hit (window 98-128).
            -- Arrival shifts up to +4 frames at long range, covered by the chained hold.
      max_dist = 224,
      hold = 4,
      hits = {
        { offset = 52, action = "block", type = 3, hold = 19 }, -- chains into hit 2 window
        { offset = 73, action = "block", type = 3, hold = 18 }, -- chains into hit 3 window
        { offset = 93, action = "block", type = 3 },            -- neutral gap follows (her jump)
        { offset = 127, action = "block", type = 3, hold = 8 }, -- landing hit, arrives 128-133 by
                                                                -- range; wider window [125,135]
                                                                -- because 2f lead proved too tight
                                                                -- for a from-neutral re-block here
      },
    },
  },
  elena = {
    [2] = false, -- SA2 Brave Dance: existing force_recording entries with per-hit low types (4dc4/5074)
  },
}
