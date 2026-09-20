# House standing, the ledger, and buying the House

This is the whole of the progression layer, stated plainly enough that a player
could check it. It adds nothing to a payout and takes nothing away: no rung, no
reward and no record touches a paytable, a stake, an RNG stream or a settlement.
`tests/test_progression.gd` asserts that.

## The currency of progress is chips **wagered**

Standing reads `Economy.lifetime_wagered`, the total the cabinets already add to
on every settled round (`CabinetSession.apply_result`). It is the same number the
two wing transition points have always gated on, so this layer is a *reading* of
the existing economy, not a second currency beside it.

Wagered, not won. A lucky run cannot buy standing, and a cold streak cannot lose
it. What a player takes home is a separate number, **net**, and it lives in the
ledger where it cannot be mistaken for progress.

## The ladder

Six rungs. Each one opens something concrete that already exists in the game.

| # | Tier | Chips wagered | What it opens | Marker |
| --- | --- | ---: | --- | ---: |
| 1 | Guest | 0 | The Main Floor | 100 |
| 2 | Regular | 1,500 | The Manager will write you a marker | 100 |
| 3 | High Roller | 5,000 | The High Roller Salon | 100 |
| 4 | Whale | 100,000 | The VIP Penthouse | 250 |
| 5 | Partner | 250,000 | A larger marker | 500 |
| 6 | Owner | 1,000,000 | The Manager will sell you the House | 1,000 |

* **The shipped wing thresholds are unchanged.** High Roller is exactly
  `FloorController.WING_THRESHOLDS.high_roller` (5,000) and Whale is exactly
  `WING_THRESHOLDS.vip` (100,000). The wings still unlock through
  `FloorController.is_wing_unlocked`, and the Manager's one-time invitations
  still come from `OfficeState.pending_invitations`. Standing names those rungs;
  it does not re-implement them.
* **The marker column is the only rung that changes a rule**, and only above
  Whale. `Economy.marker_stipend()` returns `HouseLevel.marker_stipend()` but
  never less than the shipped `Economy.MARKER_STIPEND` of 100, so a profile below
  100,000 wagered sees exactly the marker behaviour it always had. A marker is
  credit, not a payout: it is added to the bank and to the debt in the same
  amount, as it always was.

## Buying the House

The end of the ladder. Two gates, both stated on the Manager's panel before the
choice appears:

1. **Owner standing** — 1,000,000 chips wagered (`HouseLevel.OWNERSHIP_TARGET`).
2. **The price on the desk** — 250,000 chips (`HouseLevel.DEED_PRICE`).

The purchase spends the bank through `Wallet.try_apply(DEED_PRICE, 0)`: the
Wallet's ordinary boundary, with nothing paid back. It is recorded once in the
save as `house_owned` and cannot be bought twice.

**Is it reachable?** At a 25-chip average stake, 1,000,000 wagered is 40,000
rounds. A round at the tables takes a few seconds, so this is tens of hours of
real play — a long arc, deliberately, but an arc with an end, not an asymptote.
Nothing about it is hidden or randomised.

## What the player sees

| Surface | Shows | File |
| --- | --- | --- |
| Floor HUD, beside the bank plate | Rank medallion, tier initial, a slim fill toward the next rung, `1.2M / 5M` | `src/ui/house_level_hud.gd` |
| The moment a rung is reached | A card under the plate naming the tier and the one thing it opened | same |
| The Manager's desk | Medallion, tier, the next rung's bar and number, and a second bar for the whole arc toward owning the House | `src/ui/manager_standing_panel.gd` |
| The House Ledger | Overview and per-cabinet records | `src/ui/stats_panel.gd` |
| The deed | The price actually paid and the chips actually turned over | `src/ui/deed_card.gd` |
| The contracts board | A painted bar per contract, current / target | `src/ui/contracts_board.gd` |

Every bar is one `ProgressMeter` (`src/ui/progress_meter.gd`), clamped to 0..1,
clipped rather than squashed — a bar at 30% shows exactly 30% of the channel and
never a rounded stub that flatters the number — and animated only when
`MotionPolicy` allows it. Reduced motion lands on the final width at once.

## The ledger's figures

All read back from the save the cabinets already write; nothing is estimated.

| Row | Where it comes from |
| --- | --- |
| Net | Σ `cabinet_stats.returned` − Σ `cabinet_stats.wagered` |
| Chips returned / staked | Σ of the same two columns |
| Biggest single win | max `cabinet_stats.best_win` |
| Longest win streak | `SaveGame.longest_win_streak`, counted in `Progression.record_round` |
| Rounds played | Σ `cabinet_stats.rounds` |
| Most played | the cabinet with the most rounds |
| Time at the tables | `SaveGame.played_seconds`, counted only while playing |
| Per-cabinet rows | one row per cabinet with rounds and net |

A negative net is shown with a down chevron in a muted red
(`ProgressionArt.DOWN`), signed, and never dressed up. A player who is down is
told they are down.

## Save format

Schema **3**. The migration from 2 is additive and backfills zeros:

```gdscript
current_win_streak = "0"
longest_win_streak = "0"
acknowledged_tier  = "0"
house_owned        = false
```

Standing itself is *not* stored: it is derived from `lifetime_wagered`, which
every older profile already carries, so a schema-2 save keeps the standing it had
already earned the moment it loads. `acknowledged_tier` is caught up silently on
load, so an existing player is not shown five level-up cards at once.

## Where it is reachable from

The Manager's Office: the secretary offers **The House Ledger** beside the
contracts board, and the Manager offers it beside markers, along with the deed
once both gates are met. The Manager's standing panel is raised whenever he is
talking.

**Caveat:** the game has no pause menu today — `Escape`/`B` on the floor returns
to the title menu — so the ledger is reachable from the office and from the
developer menu's Info section, but not from a pause screen. Adding one is a
separate piece of work.
