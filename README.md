<div align="center">

<img src="assets/branding/house_rules_logo.png" alt="House Rules — High Roller Edition" width="380">

</div>

<div align="center">

**House Rules is an offline casino you walk around with a gamepad: nine cabinets across four
rooms, one chip wallet, no real money anywhere in it. The house edge is a test — every cabinet's
payout maths is an engine-free library, and CI plays a million rounds of each one and fails the
build if the measured return drifts more than a percentage point from the declared target.**

Godot 4.7.2 and GDScript on the GL Compatibility renderer, drawn on a 960×540 virtual canvas that
scales to FHD, QHD and native 4K. Presentation and maths never touch: the reels, the felt and the
dealer cannot pay anybody. Reduced Motion is a single policy that every effect in the game honours
rather than a switch each screen reimplements, and every rendered pixel of art came out of a
recorded pipeline whose job IDs — including the rejected takes — are written down in
[`docs/art/GENERATION-REPORT.md`](docs/art/GENERATION-REPORT.md). **No .NET, no outbound network
call, no account, no telemetry, no real-money anything** — saves are plain JSON under `user://`.

<a href="https://github.com/DahanItamar/HouseRules/actions/workflows/ci.yml"><img src="https://github.com/DahanItamar/HouseRules/actions/workflows/ci.yml/badge.svg" alt="Godot checks workflow status"></a>
<img src="https://img.shields.io/badge/tests-566%20passing-a01236?style=flat-square" alt="566 tests passing across 52 scripts">
<img src="https://img.shields.io/badge/assertions-123%2C879-2b2b33?style=flat-square" alt="123,879 assertions">
<img src="https://img.shields.io/badge/RTP%20harness-9%20cabinets%20simulated-a01236?style=flat-square" alt="The RTP harness simulates all nine cabinets, a million rounds each for eight of them">
<img src="https://img.shields.io/badge/acceptance%20criteria-53-2b2b33?style=flat-square" alt="53 numbered acceptance criteria in the spec">

<img src="https://img.shields.io/badge/Godot-4.7.2%20stable-2b2b33?style=flat-square" alt="Godot 4.7.2 stable">
<img src="https://img.shields.io/badge/GUT-9.5.0-2b2b33?style=flat-square" alt="GUT 9.5.0 vendored and pinned">
<img src="https://img.shields.io/badge/cabinets-9-2b2b33?style=flat-square" alt="Nine cabinets">
<img src="https://img.shields.io/badge/rooms-4-2b2b33?style=flat-square" alt="Four rooms">

<a href="docs/SPEC.md">Spec</a> ·
<a href="docs/cabinets/">Cabinets</a> ·
<a href="docs/art/GENERATION-REPORT.md">Art pipeline</a> ·
<a href="docs/DISPLAY-VALIDATION.md">Display</a> ·
<a href="docs/PROGRESSION.md">Progression</a>

</div>

<img src="tests/results/screenshots/menu/01_menu.png" width="100%"
     alt="The House Rules main menu: the crowned House Rules — High Roller Edition badge on the left over painted burgundy chevron rows reading ENTER THE CASINO, REDUCED MOTION OFF and SAVE AND QUIT, a gold selector arrow and a cyan focus ring on the first of them, key art on the right of a host in a pinstripe suit raising a whisky between a manager in black leather holding a folio and a croupier in burgundy fanning cards under a chandelier, and a notice along the bottom reading Play money only. No real-money wagering and no purchases of any kind.">

---

## The house edge is a test

Each cabinet is two things that never touch. `src/domain/` holds the payout maths — thirty scripts,
every one of them `RefCounted` or `Resource`, with no `Node`, no `SceneTree`, no `signal` and not
one autoload named anywhere in the directory. `src/cabinets/` holds the reels, the felt, the
dealer and the sound, and it cannot pay anybody: a cabinet reports a finished round by emitting
`round_resolved(RoundResult)`, and `cabinet_session.gd` is the only file under `src/cabinets/` that
calls `Wallet` at all. The screens under `src/ui/` read the balance and never write it.

That split is not tidiness. It is what lets the test suite pick up the exact same maths object the
player is betting against and run a million rounds of it in a few seconds, with no game running.

```mermaid
flowchart TD
    DEF["data/cabinets/slot_classic.tres<br/>target_rtp = 0.955"]
    MATH["src/domain/slot_machine_math.gd<br/>RefCounted — no Node, no autoload, no signal"]
    DEF -- "declares the target" --> MATH
    MATH -- "one round → RoundResult(stake, payout)" --> CAB["src/cabinets/slot_classic/<br/>reels, lever, hostess, PCM cues"]
    MATH -- "1,000,000 rounds, seed 20260918" --> HARNESS["tests/test_rtp_harness.gd"]
    CAB -- "emits round_resolved" --> SESSION["CabinetSession.apply_result<br/>the one file in src/cabinets that calls Wallet"]
    SESSION -- "stake and payout as one transaction" --> WALLET["Wallet — integer chips, never a float"]
    SESSION -- "would take the balance below zero" --> REJECT["transaction_rejected<br/>round ABANDONED, stake forfeited"]
    HARNESS -- "|observed − target| ≤ 0.01" --> PASS["tests/results/rtp.json"]
    HARNESS -- "|observed − target| > 0.01" --> FAIL["AC-027 fails — CI red"]
```

### What the harness printed

Two of the nine lines from a full suite run on 2026-09-20, copied verbatim; the other seven are
the same shape and all nine are in [`tests/results/rtp.json`](tests/results/rtp.json).

```json
{"absolute_error":0.0000830000000000553,"cabinet":"slot_classic","elapsed_ms":3235,"observed_rtp":0.955083,"returned":9550830,"rounds":1000000,"seed":20260918,"strategy":"spin","target_rtp":0.955,"wagered":10000000}
{"absolute_error":0.0000518885176702399,"cabinet":"blackjack","elapsed_ms":7617,"observed_rtp":0.99005188851767,"returned":10854820,"rounds":1000000,"seed":20260918,"strategy":"basic strategy","target_rtp":0.99,"wagered":10963890}
```

Notice `wagered` on the blackjack line: **10,963,890 chips staked against 1,000,000 rounds of a
10-chip bet**, because the harness plays basic strategy and basic strategy doubles down. The
measured 99.005% is what a player actually gets back, not a paytable multiplied out on paper. And
because the seed is fixed, those two lines reproduce the committed `rtp.json` digit for digit —
the only field that moves between one run and the next is `elapsed_ms`.

## Nine cabinets, nine sets of maths

Every one of them is seated on a floor you can walk to. Nothing here opens only from a menu.

| | Cabinet | Room | Mechanic | Target | Measured |
|:-:|---|---|---|---:|---:|
| <img src="assets/production/ui/icons/icon_slot_classic.png" width="34"> | **Elven Court** | Main Floor | 3-reel, weighted strips, one payline | 95.50% | 95.508% |
| <img src="assets/production/ui/icons/icon_blackjack.png" width="34"> | **Blackjack 21** | Main Floor | six-deck shoe, 3:2, dealer stands on all 17s | 99.00% | 99.005% |
| <img src="assets/production/ui/icons/icon_minefield_vault.png" width="34"> | **Hexbound Vault** | Main Floor | 5×5 mines, true odds less the edge, cash out any time | 97.00% | 96.399% |
| <img src="assets/production/ui/icons/icon_baccarat.png" width="34"> | **Velvet Baccarat** | High Roller Salon | punto banco, eight-deck shoe, exact commission | 98.90% | 98.994% |
| <img src="assets/production/ui/icons/icon_match_point.png" width="34"> | **Match Point** | High Roller Salon | 12-row plinko, thirteen courts, three risk curves | 96.00% | 96.132% |
| <img src="assets/production/ui/icons/icon_core_overclock.png" width="34"> | **Corsair's Reach** | High Roller Salon | crash — haul it in before the sea takes her | 97.00% | 96.751% |
| <img src="assets/production/ui/icons/icon_roulette.png" width="34"> | **Ruby Roulette** | VIP Penthouse | single-zero wheel, full inside/outside layout | 97.30% | 97.719% |
| <img src="assets/production/ui/icons/icon_poker.png" width="34"> | **Texas Hold'em** | VIP Penthouse | five NPC archetypes, raked pot | *skill* | 106.494% |
| <img src="assets/production/ui/icons/icon_upgrade_cluster.png" width="34"> | **Harlequin Masquerade** | VIP Penthouse | cluster pays, tumbles, a 2× to 256× upgrade bar | 96.60% | 96.459% |

Eight of the nine are measured over **1,000,000 rounds each** and asserted to within one
percentage point of the `target_rtp` declared in their `.tres` — that is acceptance criterion
AC-027, and it is a build failure, not a warning. Hold'em is the exception and says so in its own
record: return there depends on how well you play, so the harness deals **100,000 hands** of a
declared baseline strategy against the five NPCs and records the result as a baseline rather than
a target, including each NPC's big-blinds-per-100 so a regression in one opponent is visible.

Corsair's Reach is the crash cabinet: a parrot climbs an exponential curve inside a painted chart
frame, the multiplier is set as bare type over it, and the crew either side react to the same
frame she does. There is no ship and no dial, because a crash game is one object climbing a line
and everything else on the canvas competes with the number you are deciding against.

<img src="tests/results/screenshots/core_overclock_fhd/05_long_climb.png" width="100%"
     alt="Corsair's Reach mid-run: a moonlit sea, a rope-and-brass chart frame holding the word RUNNING above a bare 5.69× and a HAUL 1138 line, a scarlet macaw climbing a glowing gold trail from the bottom-left corner of the frame, a pirate crew member standing in a lane either side watching her, and a bottom deck with balance 4800, 200 in play, a MIN/10/25/X2/X5/ALL quick-bet row and a cyan-focused HAUL IT IN button">

<img src="tests/results/screenshots/05_blackjack.png" width="100%"
     alt="Blackjack 21: a dealer in a burgundy waistcoat and bow tie stands behind green felt holding the deck beside a wooden shoe, her hole card face down under a SHOWING 10 badge, the player's 10 of spades and jack of diamonds under a TOTAL 20 badge with a 10-chip stack beside them, and a bottom deck reading You have 20 with DOUBLE TO 20, STAND and a cyan-focused HIT">

<img src="tests/results/screenshots/upgrade_cluster_fhd/06_shatter.png" width="100%"
     alt="Harlequin Masquerade mid-tumble: a 7×7 grid of jewels, bells and jester symbols inside a green-and-cream diamond frame between theatre curtains, an upgrade bar across the top stepping 2× to 256× with 2× lit, a ROUND WIN panel reading 24 at 2.42 × your bet and The board is tumbling, a cluster-of-five paytable down the left, and a host in a pink jacket and carnival mask presenting the board from the right">

<img src="tests/results/screenshots/poker_fhd/06_showdown.png" width="100%"
     alt="Texas Hold'em showdown in the VIP Penthouse: a dealer in front of a night skyline, five named NPC panels around the table reading THE MANIAC fold, THE ROCK pair, THE SHARK fold, THE TOURIST fold and CALLING STATION straight, with a pot of 35">

## Walking the floor

Each room is composed, not painted flat. A 3840×2160 background carries the room with its guests
already in it; a second transparent 3840×2160 layer carries only the *fronts* of things — plants,
rope lines, lamps, the cashier cage, the office doorway — and each of those fronts is cut out as a
polygon pinned to a `baseline`, the y where that object meets the floor. Inside the y-sorted depth
layer a character whose feet are above the baseline draws behind the object and one whose feet are
below it draws in front, so you walk behind the cashier's plant and back out in front of it without
a single hand-placed sprite.

Collision is traced from what you can see, not boxed around it. Across the four rooms that is
**40 solid polygons over 468 vertices**, named after the furniture they follow —
`GrandStaircase`, `SlotIsland`, `CashierCage`, `Lounge`, `EntrancePlanter` — plus **70
occluders**. `F2` draws the lot over the running game.

<img src="tests/results/screenshots/floor_collision_overlay.png" width="100%"
     alt="The Main Floor from the header image with F2 pressed: red polygons trace the exact outline of each rug, island, planter and the curved cashier cage, green marks the walkable bounds, yellow lines mark occluder baselines, white rings label the slot_classic, blackjack, minefield_vault, cashier, high_roller, vip and office anchors, and a cyan dot under the player's feet reads 480, 408 clear 95.0">

The red outlines are the whole argument: they follow the curve of the cashier cage and the corner
of each rug rather than a rectangle drawn around them, so you slide along the furniture you can see
instead of stopping in open carpet. The cyan dot is the foot anchor — the only thing that decides
both collision and depth, which is why a character's torso can overlap a machine without ever
reaching it.

The staircase and the lift are real destinations, not coordinates on the same floor plan. Each
room loads its own background, foreground, collision set, spawn and return point, keeps one player
and one wallet across the transition, and exits on <kbd>Esc</kbd> to a visible back control.

<img src="tests/results/screenshots/room_high_roller.png" width="100%"
     alt="The High Roller Salon: a HIGH ROLLER SALON sign over a panelled wall, a baccarat table under two lamps at the centre with a hostess in purple dealing to three seated guests, leather booths and railed daises in each corner with guests drinking and talking, a concierge desk on the right, and the player standing in the lift doorway at the bottom under a prompt reading Enter Return to the Main Floor">

## Run it

Requires **Godot 4.7.2 stable** and nothing else — no .NET, no export templates for development,
no account, no asset download. Open `project.godot` in the editor and press <kbd>F5</kbd>, or point
the binary straight at the project:

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --path .
```

That opens on the menu at the top of this page. <kbd>WASD</kbd> or the left stick moves. Step into
a cabinet's brass inlay and <kbd>Enter</kbd> joins; <kbd>Esc</kbd> leaves, forfeiting the stake if
a round is live. <kbd>X</kbd> on the main menu toggles Reduced Motion. <kbd>F1</kbd> opens any
cabinet's help card, <kbd>F2</kbd> the collision overlay, and <kbd>F10</kbd> the developer menu in
a debug build.

Below, `godot` is that same 4.7.2 binary — substitute the full path if it is not on your `PATH`.

| Command | |
|---|---|
| `python tools/check_localization.py` | Passes: 623 keys, 451 referenced. No user-facing string is hardcoded |
| `gdformat --check src tests` and `gdlint src tests` | The formatting and lint gate, from `tools/requirements-dev.txt` |
| `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit` | 566 tests, 123,879 assertions, 52 scripts — 285 s, because it plays 8,100,000 real rounds on the way |
| `godot --headless --path . -s tests/slot_rtp_diagnostic.gd` | Slot variance diagnosis, written to `tests/results/slot_diagnostic.json` |

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) — the **Godot checks** workflow behind the
badge — runs those four in that order on a pinned Godot 4.7.2 Linux build, with a resource-import
pass before the suite, and uploads `tests/results/*.json` as an artifact even when the run fails,
so the RTP evidence for a red build is downloadable from the run that produced it.

> [!WARNING]
> **If the suite leaves your working tree dirty, it is `tests/results/rtp.json` and nothing is
> wrong.** The harness rewrites that file with fresh `elapsed_ms` timings on every run, so the
> measurements are identical but the diff is not empty. Run `git checkout tests/results/rtp.json`
> afterwards; the canonical fixture is the one in the index.

## Under the hood — briefly

- **Reduced motion is a policy, not a setting each screen reinvents.** `MotionPolicy` is an
  autoload that 72 files under `src/` consult; it scales finite animations and removes ambient
  motion entirely, and `tests/test_reduced_motion_handoff.gd` proves a live spin, an ambient event
  and a credit transaction all settle on their exact canonical rest state when it is switched on
  mid-animation. Every cabinet's capture set includes its reduced-motion frames.
- **Every rendered asset has a recorded provenance.** The 4K room masters, the transparent host
  characters and the nine cabinet medallions were generated through a logged pipeline —
  [`docs/art/GENERATION-REPORT.md`](docs/art/GENERATION-REPORT.md) names the job ID behind each
  one, including the rejected takes — and the production files are derived from those raw outputs
  by scripts in `tools/art/`, never by hand-editing a master.
- **Currency is integer chips, end to end.** `Wallet` never performs floating-point arithmetic on
  a balance, fractional payouts round down once, and saves serialise currency as decimal strings so
  JSON cannot lose precision. RNG streams are named and persisted; a fresh blackjack table always
  starts a fresh six-deck shoe.
- **Controller-first, and checked at three resolutions.** Every interaction completes on a gamepad,
  prompts swap glyph sets when the active device changes, and the 960×540 canvas is verified at
  FHD, QHD and native 4K with no QHD letterboxing — see
  [`docs/DISPLAY-VALIDATION.md`](docs/DISPLAY-VALIDATION.md).

## Honestly

- **The repository is large on purpose: 3.15 GB of tracked files.** 1.94 GB is 4K art masters and
  their sources, and a further 1.2 GB is 718 committed screenshots — the capture sets that back
  every visual claim above, re-shot against the current build rather than kept from older ones.
  Cloning it is a real download; that was the trade made to keep the evidence in the repository
  rather than in a bug tracker.
- **There is no LICENSE file.** Nothing here is licensed for reuse yet. The vendored GUT 9.5.0 and
  the bundled Barlow Condensed family carry their own licences
  (`assets/fonts/OFL-BarlowCondensed.txt`).
- **The spec was written for a smaller game than the one that shipped.** Its fifty-three numbered
  acceptance criteria are current and are what the suite asserts, but the prose around them was
  drawn when v1 meant three machines and two locked doors. Read the criteria as the contract and
  the narrative as history.
- **The quick-bet row is not on every machine.** Elven Court, Blackjack, Hexbound Vault, Corsair's
  Reach and Harlequin Masquerade carry `MIN/10/25/X2/X5/ALL`. Roulette and Baccarat bet by placing
  chips of a chosen denomination on spots and Hold'em and Match Point use fixed stake keys, so the
  row does not map onto them. Whether it should is a design decision that has not been made.

> This README covers what the project is and how to see it run. The design behind it lives in
> [`docs/SPEC.md`](docs/SPEC.md) — fifty-three numbered acceptance criteria, the ones cited above
> among them — and one file per cabinet under [`docs/cabinets/`](docs/cabinets/), each stating its
> fantasy, its maths and its RTP before a line of it was written.

---

<div align="center">

Built by <a href="https://github.com/DahanItamar">Itamar Dahan</a> · © 2026

</div>
