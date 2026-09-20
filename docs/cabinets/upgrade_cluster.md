# Cabinet: Harlequin Masquerade (Upgrade Cluster)

> `id: &"upgrade_cluster"` · Tier: HIGH_ROLLER · Status: Playable (not placed on a floor yet)

---

## 1. Fantasy

A carnival theatre after the curtain goes up. A hostess in a blush satin jacket and
emerald harlequin face paint works the stage beside a gilded board of gems and
masquerade props, with two jester sidekicks leaning on the frame. Matching gems
burst, the board tumbles, and a brass rail above it climbs 2x, 4x, 8x… while she
keeps presenting the next drop.

**Arcade ancestor:** the match-three cascade (Columns, Puzzle Bobble) crossed with a
cluster-pays slot.

## 2. Core loop

Set a bet → PLAY → every cluster of five or more pays, shatters and tumbles, the
upgrade bar charges on what it destroyed, and the round settles when a tumble makes
no new cluster.

## 3. Agency class

`PURE_CHANCE`. The player chooses only the stake. Return does not scale with play
quality, so the RTP harness needs no strategy: one board a round is the whole game.

## 4. Rules

1. The board is **7x7 = 49 cells**. Seven is the smallest square that makes a
   five-cell cluster a real event rather than a near-certainty: with the shipped
   weights about one board in three pays, and the geometry still leaves room for a
   cluster to grow past twenty cells on a good tumble chain.
2. There are **eight symbols**: four low (emerald, rose, amethyst and pearl
   harlequin diamonds) and four high (masquerade mask, jester hat, carnival bells,
   theatre ticket). Low symbols are weighted 18 each and high symbols 7 each, out of
   100.
3. **Cells connect in four directions only: up, down, left and right.** A diagonal
   never joins a cluster, and the grid edge is a wall, not a wrap. Five or more
   connected cells of the same symbol are a cluster and pay.
4. Every cluster on the board pays at once. A cluster is priced by its symbol and by
   the band its size falls in: 5, 6, 7, 8-9, 10-11, 12-14, 15-19, 20+.
5. **Tumble.** Every paying cell is destroyed. What is left in each column falls to
   the bottom keeping its order, and the holes that open at the top are filled from
   the same stream. If the new board has a cluster, it pays too, and so on. The round
   ends on the first board with no cluster on it (at most 64 tumbles, a guard that
   has never been approached).
6. **The upgrade bar.** Every destroyed symbol charges it, cumulatively across the
   whole round. The bar lights a rung at 4, 9, 14, 20, 27, 35, 44 and 55 destroyed
   symbols, for 2x, 4x, 8x, 16x, 32x, 64x, 128x and 256x. A cascade is paid at the
   rung its own destroyed symbols have just reached, so the first cluster of a round
   already earns at least 2x.
7. **Settlement.** The round's win is the sum over cascades of
   `cluster prices x that cascade's multiplier`, capped at 10 000x the bet, converted
   to chips once (see §6). Nothing is paid per cascade.

## 5. State machine

```
IDLE ──play──▶ DECIDED (whole round drawn) ──replay──▶ CELEBRATION? ──▶ SETTLED ──▶ IDLE
```

| State | Accepts input | Notes |
| --- | --- | --- |
| `IDLE` | Bet, quick bet, Play, Back, F1 | Nothing is staked yet. |
| `DECIDED` | Back only, through the stake-at-risk confirmation | `RoundResult` exists in full - every tumble and the final multiplier - before one tile moves. Play is swallowed, so a second press cannot start another round or skip the replay. |
| `CELEBRATION` | Back only | Only when the win is 15x or more. Bounded: it always ends. |
| `SETTLED` | Same as `IDLE` | The wallet moves exactly once, here. |

Confirming Back mid-replay closes the session; `CabinetSession` completes the pending
result, so the already-decided round still settles exactly once.

## 6. Math

`UpgradeClusterMath.play()` draws the entire round from one
`RandomNumberGenerator` and returns it as a `RoundResult` whose `detail` is a
complete replay script: the opening grid, and per cascade the clusters with their
cells and prices, the destroyed cells, the running charge, the multiplier, the win
and the grid the tumble produced.

### Units and rounding

Prices are **milli-bet integers**: 320 means 0.32 x the bet. The third decimal is
never shown; it exists so the table can be tuned to an exact RTP. With two-decimal
prices, the four cheapest entries on the board (0.25, 0.30, 0.35, 0.40) all round
down by about half a percent each, and because they carry most of the expectation
that alone cost **0.7 percentage points** of return. At milli granularity the same
error is a tenth of that.

One round is summed in milli-bet units, capped, and converted **once**:

```
payout = (units * stake + 500) / 1000        # integer, round-half-up
```

Nothing rounds per cascade, so a long tumble chain cannot bleed chips. Round-half-up
is very slightly generous (about +0.05 chips on a winning round at a 10-chip stake,
under 0.02 percentage points of RTP) and is included in every measurement below.

### Paytable

Milli-bet prices per symbol per band, from `data/paytables/upgrade_cluster.tres`.
Shown here as the two decimals the machine prints.

| Symbol | Weight | 5 | 6 | 7 | 8-9 | 10-11 | 12-14 | 15-19 | 20+ |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Emerald diamond | 18 | 0.25 | 0.38 | 0.50 | 0.75 | 1.26 | 2.51 | 5.03 | 12.57 |
| Rose diamond | 18 | 0.30 | 0.45 | 0.60 | 0.91 | 1.51 | 3.02 | 6.03 | 15.08 |
| Amethyst diamond | 18 | 0.35 | 0.53 | 0.70 | 1.06 | 1.76 | 3.52 | 7.04 | 17.60 |
| Pearl diamond | 18 | 0.40 | 0.60 | 0.80 | 1.21 | 2.01 | 4.02 | 8.04 | 20.11 |
| Masquerade mask | 7 | 0.63 | 0.94 | 1.26 | 1.89 | 3.14 | 6.28 | 12.57 | 31.42 |
| Jester hat | 7 | 0.88 | 1.32 | 1.76 | 2.64 | 4.40 | 8.80 | 17.60 | 43.99 |
| Carnival bells | 7 | 1.26 | 1.89 | 2.51 | 3.77 | 6.28 | 12.57 | 25.14 | 62.84 |
| Theatre ticket | 7 | 1.89 | 2.83 | 3.77 | 5.66 | 9.43 | 18.85 | 37.71 | 94.26 |

### Tuning

Return is **exactly linear** in every entry of `pays`: the weights decide the boards,
the boards decide the clusters and the charge, and the prices only scale what those
clusters are worth. Retuning the cabinet to a new RTP is therefore one multiplication
of this one array, verified by one run of the diagnostic below - never a hunt through
the weights.

The shipped table is a clean reference curve (0.20 / 0.30 / 0.40 / 0.60 / 1.00 / 2.00
/ 4.00 / 10.00 for the cheapest symbol, scaled per symbol) multiplied by
**12.56837** and rounded to whole milli-bet units. That factor came from measuring
the reference curve over ten million rounds and dividing into the target.

**Declared `target_rtp`:** `0.966` · **Measured (10 000 000 rounds, seed 20260918,
10 a board):** see `tests/results/upgrade_cluster_diagnostic.json`.

| Sample | Rounds | Observed RTP |
| --- | ---: | ---: |
| Strict AC-027 gate (`tests/test_rtp_harness.gd`) | 1 000 000 | see `tests/results/rtp.json` |
| Diagnostic (`tests/upgrade_cluster_rtp_diagnostic.gd`) | 10 000 000 | 96.6% ± 0.11 |

### Volatility

Payout-multiple variance is about **13.0**, so a one-million-round sample has a
standard error of roughly **0.36 percentage points**. That is why the strict ±1-point
gate is the right size for this cabinet and why the paytable was tuned against a ten
million round sample rather than the gate's own.

Measured over ten million rounds at a 10-chip stake:

| Statistic | Value |
| --- | ---: |
| Hit rate (any payout) | ~36.4% |
| Mean tumbles per round | ~0.45 |
| Deepest tumble chain seen | 8 |
| Rounds reaching 16x on the bar | ~0.8% |
| Rounds reaching 64x | ~1 in 4 500 |
| Rounds reaching 256x | ~1 in 1 000 000 |
| Big win (>= 15x) | ~1 in 127 |
| Super win (>= 50x) | ~1 in 1 700 |
| Mega win (>= 100x) | ~1 in 8 600 |
| Largest win observed | ~748x |

## 7. Bet limits

| Tier | Min bet | Max bet | Chips |
| --- | --- | --- | --- |
| HIGH_ROLLER | 1 | 100 | 1, 2, 5, 10, 25, 50, 100 |

## 8. Controller map

| Input | Action |
| --- | --- |
| A / Enter / click PLAY | Play the board |
| LB / RB, Q / E, left / right, scroll over the bet | Step the bet through the legal denominations |
| RT / R | Table maximum |
| MIN / 10 / 25 / X2 / X5 / ALL | The shared quick-bet keys in the deck |
| Start / F1 | How to play (LB/RB or left/right turn the page) |
| B / Esc | Leave. A live round asks for confirmation first. |

Everything valid now is on screen and names its own input. Cyan appears only as the
keyboard/controller focus ring.

## 9. Screen layout (960x540)

| Region | Rect | Contents |
| --- | --- | --- |
| Title plate | 48,27 240x40 | HARLEQUIN MASQUERADE |
| Help | 48,74 176x44 | How to play |
| Upgrade bar | 296,24 368x44 | Painted rail, eight rungs 2x-256x, charge rule |
| Grid frame | 312,72 336x342 | Ornate harlequin frame; its inner window is the board exactly |
| Board | 354,118 252x252 | 7x7 cells, 36 px pitch, 32 px tiles |
| Round readout | 48,130 240x132 | ROUND WIN, x bet, tumble count, status line |
| Paytable legend | 48,270 240x144 | The eight symbols and what a cluster of five pays |
| Sidekicks | 288,320 54x96 and 614,324 82x92 | Jesters leaning on the frame's lower corners |
| Hostess | 700,96 212x317 | Standing on the stage, right of the board |
| Deck | 48,422 864x91 | Shared `CabinetDeck`: instruction rail, balance, bet, quick bets, PLAY |

Every control is at least 44x44 and inside TV-safe (48,27 864x486).
`tests/test_upgrade_cluster.gd` asserts that, that the readouts and the board never
overlap each other or the deck, and that neither the hostess, the sidekicks nor the
floating arithmetic can ever stand on one of them.

## 10. Presentation and motion

The round is finished before the screen is told anything; the panel only replays it.
Each cascade runs a **strictly sequential** timeline, each phase awaited so the
ordering is a property of the code rather than timers that happen to agree:

1. **Pulse.** The winning cluster brightens, swells and takes a brass ring.
2. **The arithmetic.** A label pops over the cluster on an elastic tween with what
   the machine just worked out - `0.32  x256` - holds long enough to read, then
   floats up and fades. It is clamped inside the board and can never cover the
   upgrade bar, the readout or the deck.
3. **Shatter.** *Only now* do the tiles burst into painted gem shards and leave.
4. **Tumble.** Survivors fall, new symbols arrive from above the board (clipped by
   the board, so they come out from behind the painted frame) with a bounce, and the
   board takes one 3 px landing bump.
5. **Celebration**, once every cascade is done and only at 15x or more: the stage
   darkens behind a vignette, the masquerade crest scales in, the tier word is drawn
   in brass on the crest's own blank ribbon, and the payout ticks up beneath it. The
   word morphs with the counter - BIG WIN, SUPER WIN at 50x, MEGA WIN at 100x - so
   the word the player ends on is the one the win earned. It holds 1.5 s and fades.

Glow, vignette, screen shake and the big-win popup are permitted here because this is
a cabinet screen. The floor, the HUD and the menus keep the flat no-glow rule.

**The hostess** has five head-registered poses and cross-fades between them: mask
(the round starts), present (a cluster is paying), cheer (the round won), pout (a
dead board), idle. The sidekicks answer each beat with one short hop or slump. None
of it is a whole-body bob, and none of it touches the result or its timing.

**Reduced motion** bounds every phase to 0.09 s, and each phase becomes its final
state rather than a shortened animation: the win ring is *held* instead of pulsed (so
the cluster stays marked while its number is on screen), no shards are spawned at
all, tiles land without travelling, there is no screen shake, and the celebration
shows its finished state - full vignette, crest at rest, payout complete - for one
short hold. `tests/test_upgrade_cluster.gd` asserts each of those.

## 11. Assets

The theme is recorded in exactly one place, `src/ui/upgrade_cluster/cluster_theme.gd`:
every texture, colour, rectangle and duration. Re-skinning the cabinet is a change to
that file.

| Asset | Path | Notes |
| --- | --- | --- |
| Stage backdrop | `assets/production/harlequin/harlequin_stage_backdrop.png` | 3840x2160, no people, centre kept clear |
| Grid frame | `assets/production/harlequin/harlequin_grid_frame.png` | Trimmed to its paint; its inner window is 12.5% / 13.35% of the art |
| Multiplier bar | `assets/production/harlequin/harlequin_multiplier_bar.png` | Nine-slice, middle **tiled** so the diamond band repeats instead of smearing |
| Crest | `assets/production/harlequin/harlequin_crest.png` | Blank ribbon; the tier word is drawn in code |
| Shards | `assets/production/harlequin/harlequin_shards.png` | 4x4 sheet of 256 px gem shards |
| Tiles | `assets/production/harlequin/harlequin_tile_*.png` | Eight 256 px cells, each trimmed and re-centred at one visual weight |
| Sidekicks | `assets/production/harlequin/harlequin_sidekick_{pink,green}.png` | 512 px painted jesters |
| Hostess | `assets/production/characters/hosts/harlequin_hostess{,_mask,_present,_cheer,_pout}.png` | 1392x2080 transparent masters, head-registered |

Built by `tools/art/prepare_harlequin.py` (stage, tiles, sidekicks, pose cut-outs)
and `tools/art/prepare_characters.py tools/art/characters_harlequin.json` (de-fringe,
align, pad). Raw generation outputs under `assets/source/layered_v2/harlequin/` are
never modified. Job ids are in `docs/art/GENERATION-REPORT.md` under "Harlequin
Masquerade".

## 12. Edge cases

| Case | Handling |
| --- | --- |
| Play with no affordable bet | Refused, with the notice "Set a bet you can cover first" |
| Play pressed again mid-replay | Swallowed. One round at a time; the replay cannot be skipped into settlement. |
| Back during the replay | Exit confirmation. Confirming settles the already-decided result exactly once. |
| Reduced motion toggled mid-replay | The remaining phases take their bounded form; the board and the total stay correct. |
| A round with no cluster at all | Zero cascades, zero payout, the hostess pouts, the bar stays at 1x. |
| A tumble chain that never dies | Impossible in practice; `max_cascades` (64) is a hard stop and is recorded in the round. |
| Win above the ceiling | Capped at 10 000x the bet, and `detail.capped` records that it happened. |
