# Cabinet: Minefield Vault

> `id: &"minefield_vault"` · Tier: MAIN_FLOOR · Status: Specified (M2)

---

## 1. Fantasy

A 5×5 grid of vault deposit boxes. Some are wired. Open one, the multiplier climbs and the cash-out button gets louder. Open another. The game never stops you — it just keeps asking whether this is enough.

**Arcade ancestor:** Minesweeper, by way of the modern "Mines" gambling game.

## 2. Core loop

Set a stake and a mine count, reveal tiles one at a time, cash out before hitting a mine.

## 3. Agency class

`CHANCE_PLUS_DECISION`

The decision is *when to stop* — and it has a remarkable property: **it does not matter.** Every cash-out point carries identical expected value, because the multiplier is derived from true odds at every step (§6). The player cannot beat this machine with strategy and cannot ruin it either.

That makes it the purest instrument in the building. It is entirely about nerve, and the design says so honestly rather than implying a skill that isn't there. The RTP harness scripts a fixed cash-out rule purely for reproducibility; any rule produces the same measured RTP, which is itself a useful test assertion.

## 4. Rules

1. The player sets a stake and chooses a mine count from 1 to 24.
2. Mines are placed uniformly at random across the 25 tiles when the round begins (AC-033). Placement is fixed at that moment — the game does not move mines in response to picks.
3. The player reveals tiles one at a time. Each safe reveal raises the running multiplier (AC-034).
4. The player may cash out after any safe reveal, paying stake × the current multiplier (AC-035).
5. Revealing a mine ends the round with a payout of zero (AC-036). All remaining mines are shown.
6. Revealing every safe tile cashes out automatically at the maximum multiplier for that mine count.

## 5. State machine

```
BETTING ──begin──▶ REVEALING ──safe tile──▶ REVEALING
                       │  │                     │
                       │  └──cash out──────────▶│
                       │                        ▼
                       └──mine──▶ BUSTED ──▶ RESOLVING ──▶ BETTING
                                                 ▲
                                  CASHED_OUT ────┘
```

| State | Accepts input | Exit leads to |
| --- | --- | --- |
| `BETTING` | Yes — stake, mine count, begin, exit | `REVEALING` or floor |
| `REVEALING` | Yes — move cursor, reveal, cash out | `REVEALING`, `BUSTED`, `CASHED_OUT` |
| `BUSTED` | No (AC-044) | `RESOLVING` |
| `CASHED_OUT` | No | `RESOLVING` |
| `RESOLVING` | No | `BETTING`, emitting `round_resolved` |

Exiting during `REVEALING` → `abandon()` → `ABANDONED`, stake forfeit.

## 6. Math

With `M` mines on 25 tiles, the probability that the first `k` reveals are all safe is:

```
P(k safe) = C(25 − M, k) / C(25, k)
```

The fair multiplier is its reciprocal. Applying a flat house edge `h = 0.03`:

```
multiplier(k) = (1 − h) × C(25, k) / C(25 − M, k)
```

**The key property:** because the multiplier is the true reciprocal odds at every `k`, expected value at every cash-out point is exactly `(1 − h) × stake`. Cashing out at one tile and cashing out at twenty are equally good bets. The house edge is 3% regardless of how the player plays — which is why §3 calls the decision irrelevant and the nerve real.

**Declared `target_rtp`:** `0.970`
**Computed RTP:** **97.00%** exactly, at every mine count and every cash-out strategy, by construction.
**Hit frequency:** player-controlled. At 3 mines, the chance of surviving one reveal is 88%; of surviving five, 49.6%.
**Volatility:** player-selected — LOW at 1 mine, extreme at 24. Declared as HIGH in `CabinetDefinition` since the tail dominates.
**Max win:** capped at **5,000×**. Uncapped, clearing all 13 safe tiles at 12 mines pays C(25,12) ≈ 5,200,300× — an overflow risk and a design absurdity. The cap binds only in outcomes with probability below 1 in 5 million, and it is recorded in §13 because an uncapped multiplier is exactly the failure mode §8 of the spec warns about.

### Multiplier curve at 3 mines (22 safe tiles)

| Safe reveals `k` | P(reach) | Multiplier | EV as % of stake |
| --- | --- | --- | --- |
| 1 | 0.8800 | 1.10× | 97% |
| 2 | 0.7713 | 1.26× | 97% |
| 3 | 0.6739 | 1.45× | 97% |
| 5 | 0.4962 | 1.96× | 97% |
| 10 | 0.1978 | 4.90× | 97% |
| 15 | 0.0567 | 17.11× | 97% |
| 22 (all clear) | 0.0004 | 2,231× | 97% |

The rightmost column is the whole design. It is identical at every row.

## 7. Bet limits

| Tier | Min | Max |
| --- | --- | --- |
| MAIN_FLOOR | 1 | 25 |

Lowest maximum on the floor, because the multiplier tail is the longest. A 25-chip stake can still return 55,775 at 3 mines fully cleared.

## 8. Controller map

| Input | Action | Available in state |
| --- | --- | --- |
| D-pad ←/→ | Stake | `BETTING` |
| D-pad ↑/↓ | Mine count (1–24) | `BETTING` |
| A / Cross | Begin round | `BETTING` |
| D-pad / left stick | Move the snap cursor across the grid (AC-039) | `REVEALING` |
| A / Cross | Reveal the selected tile | `REVEALING` |
| X / Square | Cash out | `REVEALING`, after ≥1 safe reveal |
| B / Circle | Return to floor | `BETTING` |

The grid cursor is the reference implementation of the snap cursor required by AC-039. Roulette needs a far harder version of the same component later, so building it here first against a clean 5×5 grid is deliberate.

## 9. Screen layout (960×540)

```
┌────────────────────────────────────────────────────────────────┐
│  CHIPS 1,240                                      DEBT 100     │ ← 16px
│                                                                │
│              ┌────┬────┬────┬────┬────┐                        │
│              │ ✦  │ ✦  │ ▓▓ │ ✦  │ ▓▓ │                        │
│              ├────┼────┼────┼────┼────┤      MINES    3        │ ← 16px
│              │ ▓▓ │ ✦  │ ▓▓ │ ▓▓ │ ▓▓ │                        │
│              ├────┼────┼────┼────┼────┤      STAKE   10        │ ← 16px
│              │ ▓▓ │ ▓▓ │ ╔══╗ ▓▓ │ ▓▓ │                        │
│              ├────┼────┼─╚══╝┼────┼────┤                       │
│              │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │                        │
│              ├────┼────┼────┼────┼────┤    ┌──────────────┐    │
│              │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │    │   4.90×      │    │ ← 16px, the
│              └────┴────┴────┴────┴────┘    │  CASH 49     │    │   loudest
│                                            └──────────────┘    │   thing here
│  (A) OPEN    (X) CASH OUT                    (B) LEAVE         │
└────────────────────────────────────────────────────────────────┘
```

`╔══╗` marks the snap cursor. `✦` is a revealed safe tile, `▓▓` unrevealed. Tiles are 56×56 with 4px gutters — comfortably above the readability floor, which is why this cabinet is the right place to prove the cursor.

The cash-out panel is the single most important element on screen and gets the most visual weight: it grows, brightens and pulses faster as the multiplier climbs. It is the cabinet's entire psychological mechanism.

## 10. Audio cues

| Moment | Cue |
| --- | --- |
| Cursor move | Soft tick |
| Safe reveal | Rising tone, pitch stepping up with each consecutive safe tile — the pitch *is* the multiplier |
| Multiplier update | Cash-out panel pulse, tempo rising with `k` |
| Cash out | Vault door opening, then coins |
| Mine | Sharp detonation, everything cuts to silence, remaining mines revealed one per 100ms |
| All clear | Full vault fanfare, distinct from an ordinary cash-out |

The rising pitch on consecutive safe reveals is the core feel. It must be audibly uncomfortable by the eighth tile — that discomfort is the product.

## 11. Assets required

| Asset | Dimensions | Frames | Method | Notes |
| --- | --- | --- | --- | --- |
| Tile: unrevealed | 56×56 | 1 | GENERATE | Deposit-box door, brushed metal |
| Tile: safe revealed | 56×56 | 1 | GENERATE | Open box, chips inside |
| Tile: mine revealed | 56×56 | 1 | GENERATE | Wired charge |
| Tile reveal | 56×56 | 5 | HAND-PIXEL | Door swing |
| Detonation | 96×96 | 8 | HAND-PIXEL | Generation cannot hold an 8-frame explosion consistently |
| Snap cursor | 64×64 | 2 | HAND-PIXEL | Pulse loop |
| Cash-out panel frame | 176×80 | 3 | HAND-PIXEL | Three intensity states |
| Vault wall backdrop | 960×540 | 1 | GENERATE | Best generation candidate in v1 — large, static, atmospheric |
| Floor sprite (vault door from above) | 48×48 | 2 | GENERATE | |

## 12. Juice & tells

This cabinet has no tells to design, because it has nothing to hide — mine placement is fixed at round start and uniform, and the multiplier is the honest reciprocal of the odds. There is no near-miss engineering, no weighting, no "close call" the machine manufactures.

Everything is therefore in the **escalation**. Pitch rises per safe tile. The cash-out panel grows and pulses faster. The unrevealed tiles do not change at all — the tension comes entirely from what the player has already survived, which is exactly where it comes from in the real decision.

The moment after a detonation gets full silence for 400ms before the remaining mines reveal. Losing needs room.

## 13. Edge cases

| Case | Handling | AC |
| --- | --- | --- |
| Exit during `REVEALING` | `abandon()` → ABANDONED, stake forfeit | AC-009 |
| Cash out with zero reveals | Not offered — cash out requires `k ≥ 1` | AC-035 |
| 24 mines, one safe tile | Legal. One reveal, 24.25×, then auto-cash-out | AC-034 |
| All safe tiles cleared | Auto cash-out at maximum multiplier | AC-035 |
| Multiplier exceeds the cap | Clamped to 5,000×. Binds only below p = 1/5,200,300 | AC-010 |
| Input during `BUSTED` | Ignored | AC-044 |
| Mine count outside 1–24 | Clamped at the UI; the domain layer asserts | AC-033 |

## 14. Open questions

- **Does the cap at 5,000× need a visible indicator in the UI?** — blocks: nothing. It binds so rarely that showing it would be noise, but a player who reaches it and sees a wrong number would be right to file a bug. Decide during M4 polish.
