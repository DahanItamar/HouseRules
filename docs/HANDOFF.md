# House Rules — session handoff

Written 2026-09-20 for a fresh session. Last commit on `main`: `14e6da1 fix: seat the
roulette ring and ball on the painted wheel`. Everything through that commit is pushed to
`origin/main`.

**Read this first, then `git status`.** A large amount of finished-but-uncommitted work is on
disk, produced by background agents that DIED WITH THE PREVIOUS SESSION. Nothing is running
now. Nobody is going to finish that work unless the new session does.

---

## 1. Where the project stands

Seven playable cabinets are committed and pushed: Elven Court (slots), Blackjack, Hexbound
Vault, Ruby Roulette, Texas Hold'em vs NPCs, Velvet Baccarat, Match Point. Four rooms are
committed: Main Floor, High Roller Salon, VIP Penthouse, Manager's Office (with the
secretary's first-run tour, the House Contracts board, markers and wing invitations).

The player character was replaced twice; the shipping version is a video-derived walk atlas
(`assets/production/characters/player_walk_v3.png`, 8 facings x 8 phases) built by
`tools/art/build_player_walk_video.py` from five Kling walk videos. This is the third attempt
and the first the user accepted in principle; the first two (generated sprite sheets, then a
procedural leg rig) were rejected.

Committed art also includes: the per-cabinet painted UI kit and input glyph blanks
(`assets/production/ui/kit`, `assets/production/ui/glyphs`), the Harlequin Masquerade theme
set, the Tidewater Gold theme set (now superseded, see §4), and the walk videos.

## 2. Uncommitted work on disk, by workstream

Roughly 430 changed/untracked paths. None of it is committed. Each item below was being built
by an agent that no longer exists; treat the code as a draft that needs verifying, finishing
and testing before it is committed.

| Workstream | Key paths | State |
| --- | --- | --- |
| Video walk + player scale | `src/floor/floor_avatar.gd`, `src/floor/character_walk_atlas.gd`, `tools/art/build_player_walk_video.py`, `tools/capture_walk.gd`, `tests/test_character_atlas.gd`, `tests/test_session.gd` | Atlas built and active (`ACTIVE := WALK_V3`); tests rewritten. Per-room avatar scale calibration (`data/floors/*.json`, `_apply_avatar_scale`) was in progress — verify it is coherent or revert it. |
| Cabinet deck, glyphs, help | `src/ui/deck/`, `src/ui/input_prompt/`, `src/ui/help/`, `src/autoload/input_router.gd`, `src/ui/cabinet_panel.gd`, `src/ui/stake_selector.gd`, `tests/test_cabinet_deck.gd` | The shared deck, device-aware glyphs and redesigned help card. Blackjack was the pilot; rollout to the other games was incomplete. |
| Harlequin Masquerade (`upgrade_cluster`) | `src/domain/upgrade_cluster*.gd`, `src/cabinets/upgrade_cluster/`, `src/ui/upgrade_cluster/`, `data/{cabinets,paytables}/upgrade_cluster.tres`, `docs/cabinets/upgrade_cluster.md`, `assets/production/harlequin/` | Cluster-pays grid, 4-way only, tumbles, 16x/32x/64x ladder, target RTP 96.60%. Verify the RTP harness entry and the sequential VFX timeline. |
| Forno d'Oro (`core_overclock`) | `src/domain/core_overclock*.gd`, `src/cabinets/core_overclock/`, `src/ui/core_overclock/`, `data/{cabinets,paytables}/core_overclock.tres`, `assets/production/forno/` | Crash game, target RTP 97%, re-themed as a pizza bake. **The user rejected the current screen** — see §5. |
| Ambience + transitions | `src/floor/floor_ambient_lights.gd`, `src/ui/ambient/`, `src/floor/room_transition.gd`, `src/ui/transitions/`, `tests/test_cabinet_ambience.gd`, `docs/design/AMBIENT-LIFE.md` | Lamp flicker/light pools/shadows per room, per-cabinet effects, and themed lift/stairs/door transitions. |
| Dev menu + progression | `src/ui/dev_menu/`, `src/autoload/progression.gd`, `src/domain/house_level.gd`, `src/domain/player_stats.gd`, `src/ui/{house_level_hud,manager_standing_panel,stats_panel,deed_card,progress_meter,progression_art}.gd`, `docs/PROGRESSION.md` | Debug-only gear widget; House Level tiers ending in BUYING THE CASINO; net/win/loss stats; contract progress bars. |

## 3. How to verify before committing anything

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gexit
git checkout tests/results/rtp.json   # the suite rewrites its elapsed times
python tools/check_localization.py
gdformat --check src tests ; gdlint src tests
```

Commit in feature-sized sections (the user asked for this explicitly), never one giant commit.
Push in sections too: the repo is ~2.3 GB and a single push can exceed GitHub's 2 GB limit —
`git push origin <sha>:refs/heads/main` for intermediate commits works.

## 4. Pending user decisions

1. **Forno d'Oro hosts.** The user asked for TWO hosts, one per side, and approved the concept.
   Latest art is in `assets/source/layered_v2/forno/`: left character (blonde; `ca887052`
   master) `left_ready_8e26e5f4`, `left_launch_51807f94`, `left_tense_4f6a42b2`,
   `left_cheer_f4080c1d`, `left_burnt_v2_c4f739ea`; right character (caramel brunette;
   `d5a64ecb` master) `right_ready_b3eda408`, `right_launch_15ab7320`,
   `right_baking_ec7dfd6b`, `right_serve_4f6209ad`, `right_burnt_v2_79a04071`.
   The v2 burnt poses replace the earlier ones because the user said the emotions must match
   across both characters per state (both disappointed on a burn, both delighted on a win).
   NOT yet shown to the user; show the matched set before wiring it in. The left character's
   skirt is very short — the user was warned and has not ruled.
2. **Tidewater Gold** (coastal treasure) was replaced by Forno d'Oro at the user's request. Its
   art stays in the repo as unused source and must be marked superseded in the generation
   report, not deleted.
3. Unused earlier hosts also kept for provenance: `hostess_07112492` (rejected as too glossy),
   `hostess_d5a64ecb` (rejected as too skimpy, but her FACE is reused for the right-hand
   character), `hostess_v2_de44b0eb` (chef jacket, unused).

## 5. Known defects the user reported and expects fixed

- **Forno d'Oro screen (rejected outright).** From their screenshot: the raw key
  `CORE_OVERCLOCK_STATUS_BAKING` renders instead of text; two competing multipliers are shown
  (a "1.07x" chip and a "10000.00x" chip while the gauge reads 5.67x); the layout is
  asymmetric with a stray "TIMER OFF" control floating under the graph; and the whole screen
  is static where a crash game needs rising tension. Assets generated for the fix are in
  `assets/source/layered_v2/forno/`: five bake stages (raw `90cced9f`, pale `4a85d177`, golden
  `c6bd7cda`, deep `48e75a9e`, burnt `f93533ac`), a 3x3 flame sheet `e72301e5`, a heat glow
  `fa907f7c`, and the terracotta nine-slice frame `206e16d2`. Intended fix: centre axis with
  the oven/gauge in the middle and a host on each side, one live multiplier, live-drawing
  curve, sweeping needle, pizza baking through the stages, growing flame, embers, rising
  shake, and a flash/smoke meltdown — all bounded by `MotionPolicy`.
- **Buttons everywhere.** The user wants the quick-bet row `10 / 25 / X2 / X5 / ALL` (keeping
  the existing MIN/+10/+25/X2/X5/MAX semantics and clamping) as painted buttons on EVERY
  machine, with keyboard/controller prompts, and the deck kept simple: one primary action, the
  bet row, the balance, one plain-language hint line.
- **Faces drift to a generic model.** Every generated character trends toward the same pretty
  default. Fix by specifying distinctive features explicitly (face shape, brows, nose, lips,
  beauty marks, hair texture and roots) as was done for `ca887052`.

## 6. Higgsfield notes

- Account: Ultra, ~1,900 credits at handoff. `gpt_image_2_5` ~2-4.5 credits, `nano_banana_pro`
  edits 2, `kling3_0` video (pro, 5 s) used for the walk.
- There is a SECOND, separate pool called "boost credits". When it empties, submissions fail
  with `429 not_enough_boost_credits` even though the main balance is untouched. It refills
  after a while; retry rather than assume the feature is gone.
- The content filter rejects wording it reads as sexualised (it blocked "secretary" + leather,
  and a "blazer worn as a top"). Rephrase toward "elegant office fashion", "editorial",
  "tasteful" and regenerate.
- Never reproduce a real person's likeness or a copyrighted character. The user sends
  celebrity/influencer references as *vibe*; build original characters and never name the
  source property in code, locale, docs or prompts.
- Provenance for every generated asset belongs in `docs/art/GENERATION-REPORT.md`
  (job id, model, settings, credits, rejects and why).

## 7. Suggested order for the next session

1. Triage `git status`. For each workstream in §2, run the suite, fix or revert what is broken,
   and commit it as its own section. Start with the walk + deck (most visible), then the two
   new cabinets, then ambience/transitions, then dev menu/progression.
2. Fix the Forno d'Oro screen per §5 and wire in the two hosts per §4.
3. Roll the deck/buttons out to all machines.
4. Full release gate: GUT suite, the million-round RTP harness per cabinet, restore
   `tests/results/rtp.json` timings, rebuild `export/HouseRules.pck`, smoke-launch it from an
   absolute path, record its SHA-256, update the README counts, then push in sections.
5. Housekeeping worth raising with the user: the repo is ~2.3 GB because every 4K master,
   source video and capture set is tracked. Git LFS or pruning intermediate captures would cut
   it substantially.
