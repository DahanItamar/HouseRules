# Cabinet: Classic 3-Reel

> `id: &"slot_classic"` · Tier: MAIN_FLOOR · Status: Specified (M1)

---

## 1. Fantasy

A chrome-and-neon fruit machine with a physical arm. No features, no bonus rounds, no story — pull, watch three reels stop one at a time, and find out. It is the first thing the player sees because it is the easiest thing in the building to understand.

**Arcade ancestor:** none — the original casino machine.

## 2. Core loop

Set a stake, pull the arm, three reels stop left to right, the payline resolves.

## 3. Agency class

`PURE_CHANCE`

The player chooses only the stake. Nothing about how they play changes the expected return, so the RTP harness runs it with a fixed stake and no strategy. This is deliberate: it is the baseline the other two machines are measured against.

## 4. Rules

1. The player selects a stake between the tier's min and max.
2. Pulling the arm deducts the stake and spins three independent reels.
3. Each reel draws one symbol from its weighted strip. All three reels use the same strip.
4. Reels stop left to right, 400ms apart, so a two-symbol match builds tension before the third lands.
5. The single payline is the centre row. Three matching symbols pay that symbol's multiplier.
6. Exactly two CHERRY symbols anywhere on the line pay 1× (stake returned).
7. Payouts do not stack — the best single outcome pays.

## 5. State machine

```
IDLE ──stake changed──▶ IDLE
IDLE ──arm pulled─────▶ SPINNING ──reel 1──▶ SPINNING ──reel 2──▶ SPINNING
                                                                      │
                                                                  reel 3
                                                                      ▼
                        IDLE ◀──tally done── RESOLVING ◀──────────────┘
```

| State | Accepts input | Exit leads to |
| --- | --- | --- |
| `IDLE` | Yes — stake adjust, pull, exit | `SPINNING` or floor |
| `SPINNING` | No (AC-044) | `RESOLVING` |
| `RESOLVING` | No | `IDLE`, emitting `round_resolved` |

Exiting during `SPINNING` or `RESOLVING` → `abandon()` → `ABANDONED`, stake forfeit.

## 6. Math

Each of the three reels uses an identical 31-stop strip:

| Symbol | Stops | p(one reel) |
| --- | --- | --- |
| CHERRY | 8 | 0.25806 |
| LEMON | 7 | 0.22581 |
| BELL | 6 | 0.19355 |
| BAR | 5 | 0.16129 |
| SEVEN | 4 | 0.12903 |
| DIAMOND | 1 | 0.03226 |
| **Total** | **31** | **1.00000** |

`p(three of a kind) = (stops / 31)³`

**Declared `target_rtp`:** `0.955`
**Computed RTP:** **95.50%** — arithmetic in the paytable below
**Hit frequency:** 19.06% — roughly one paying spin in 5.2
**Volatility:** MEDIUM
**Max win:** 500× stake (three DIAMOND). Capped at 500×, so at the tier maximum of 50 chips the largest single payout is 25,000 — well inside the integer range (§8 of the spec).

### Paytable

| Outcome | Probability | Pays | Contribution |
| --- | --- | --- | --- |
| 3 × DIAMOND | 0.00003357 | 500× | 0.01678 |
| 3 × SEVEN | 0.00214830 | 19× | 0.04082 |
| 3 × BAR | 0.00419657 | 16× | 0.06715 |
| 3 × BELL | 0.00725051 | 12× | 0.08701 |
| 3 × LEMON | 0.01151354 | 11× | 0.12665 |
| 3 × CHERRY | 0.01718640 | 10× | 0.17186 |
| Exactly 2 × CHERRY | 0.14823269 | 3× | 0.44470 |
| **Total RTP** | | | **0.95495** |

The two-cherry consolation carries 44.5% of the total return. It keeps the first
machine lively while the single-stop 500× DIAMOND remains genuinely rare. That
distribution also makes the one-million-round RTP gate materially less sensitive
to jackpot count without changing the declared return or maximum win.

## 7. Bet limits

| Tier | Min | Max |
| --- | --- | --- |
| MAIN_FLOOR | 1 | 50 |

## 8. Controller map

| Input | Action | Available in state |
| --- | --- | --- |
| D-pad ←/→ | Decrease / increase stake | `IDLE` |
| D-pad ↑ | Max bet | `IDLE` |
| A / Cross | Pull the arm | `IDLE` |
| B / Circle | Return to floor | `IDLE` |
| Any | Ignored | `SPINNING`, `RESOLVING` |

## 9. Screen layout (960×540)

```
┌────────────────────────────────────────────────────────────────┐
│  CHIPS 1,240                                      DEBT 100     │ ← 16px (AC-042)
│                                                                │
│        ╔══════════╦══════════╦══════════╗                      │
│        ║          ║          ║          ║                      │
│   ═════╣  CHERRY  ║  CHERRY  ║   BELL   ╠═════ payline         │
│        ║          ║          ║          ║                      │
│        ╚══════════╩══════════╩══════════╝                      │
│                                                     ┌──┐       │
│                  STAKE  ◀  10  ▶                    │▓▓│ arm   │
│                                                     └──┘       │
│   ┌──────────────────────────────────────┐                     │
│   │ 3×DIAMOND 500   3×SEVEN  80          │ ← paytable, 8px min │
│   │ 3×BAR      40   3×BELL   20          │                     │
│   │ 3×LEMON    12   3×CHERRY  8   2×CH 1 │                     │
│   └──────────────────────────────────────┘                     │
│  (A) PULL          (◀▶) STAKE          (B) LEAVE               │ ← glyphs swap, AC-038
└────────────────────────────────────────────────────────────────┘
```

`CHIPS`, `DEBT` and `STAKE` are the 16px elements. The paytable is 8px and is the densest text on screen — it is the element to check first in the M4 readability pass.

## 10. Audio cues

| Moment | Cue |
| --- | --- |
| Stake change | Short mechanical click, pitch rising with the stake |
| Arm pull | Heavy ratchet, then a reel-spin loop |
| Reel stop | Percussive thunk, one per reel, 400ms apart |
| Anticipation | When reels 1 and 2 match, the reel-3 loop pitches up a semitone and the bed ducks |
| Near-miss | Reel 3 lands adjacent to the match — a single descending tone, no fanfare |
| Win | Coin cascade, length scaling with multiplier; 500× triggers the full jackpot bed |
| Loss | Nothing. Silence after the third thunk is the loss cue. |

## 11. Assets required

| Asset | Dimensions | Frames | Method | Notes |
| --- | --- | --- | --- | --- |
| Cabinet body | 320×400 | 1 | GENERATE | Chrome + neon trim, front-facing, flat lighting |
| Symbol: CHERRY | 64×64 | 1 | GENERATE | |
| Symbol: LEMON | 64×64 | 1 | GENERATE | |
| Symbol: BELL | 64×64 | 1 | GENERATE | |
| Symbol: BAR | 64×64 | 1 | GENERATE | |
| Symbol: SEVEN | 64×64 | 1 | GENERATE | |
| Symbol: DIAMOND | 64×64 | 1 | GENERATE | Highest value — most visual weight |
| Reel blur strip | 64×192 | 4 | HAND-PIXEL | Vertical motion blur loop; generation cannot hold frame consistency |
| Arm | 32×96 | 6 | HAND-PIXEL | Pull-down and return |
| Win flash overlay | 960×540 | 3 | HAND-PIXEL | Additive, palette-locked |
| Floor sprite (cabinet seen from above) | 48×48 | 2 | GENERATE | Attract-mode blink |

Prompts and palette constraints for every GENERATE row are in `docs/art/ASSET-SPECS.md`.

## 12. Juice & tells

The whole machine rests on one moment: **reels 1 and 2 matching.** That is the only anticipation this design has, and everything is arranged to sell it — the 400ms stagger exists so the player registers the match before the third reel commits, the audio pitches up, and the bed ducks.

Near-miss is handled honestly. When reel 3 stops one position off a three-of-a-kind, the symbol above or below the payline is visible, but the game does **not** weight reel 3 to produce near-misses more often than chance. That is the standard trick in commercial slot design and it is deliberately not used here: the strips are uniform and the math in §6 is the whole truth. A player who counts symbols gets the real answer.

Celebration scales in three bands: under 20× a coin tick, 20–100× a cascade, above 100× the full bed with a screen flash.

## 13. Edge cases

| Case | Handling | AC |
| --- | --- | --- |
| Exit mid-spin | `abandon()` → ABANDONED, stake forfeit | AC-009 |
| Arm mashed during spin | Ignored — `SPINNING` accepts no input | AC-044 |
| Stake raised above balance | Stake clamps to `min(max_bet, balance)` | AC-011 |
| Balance below min bet on approach | Cabinet shown unavailable on the floor; cannot be entered | AC-004 |
| Max win at max stake | 500 × 50 = 25,000 chips; inside int64 by a wide margin | AC-010 |

## 14. Open questions

None. This cabinet is fully specified and blocks nothing.
