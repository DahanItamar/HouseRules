# Cabinet: Blackjack 21

> `id: &"blackjack"` · Tier: MAIN_FLOOR · Status: Specified (M2)

---

## 1. Fantasy

A felt table, a silent dealer, and the only machine in the building where being good at it actually matters. The house edge here is under one percent — the player who learns basic strategy discovers that this table is the closest thing to a job the casino offers.

**Arcade ancestor:** none — classic casino.

## 2. Core loop

Place a stake, receive two cards, decide hit / stand / double against the dealer's upcard, dealer resolves.

## 3. Agency class

`CHANCE_PLUS_DECISION`

Every decision has a mathematically correct answer given the two visible cards. RTP therefore scales with play quality, and the RTP harness (§7 Flow D of the spec) must run a **scripted basic-strategy player** — measuring this machine with random play would report a number no real player experiences.

Economically this is the floor's reliable earner. Blackjack is where a patient player grinds; the slot is where they spend it.

## 4. Rules

1. Six-deck shoe. Reshuffled when fewer than 52 cards remain (AC-030).
2. Player places a stake, receives two cards face up. Dealer receives one up, one down.
3. Two cards totalling 21 is a **natural**: pays 3:2 and ends the round immediately (AC-031). A dealer natural pushes against a player natural.
4. Aces count 11 unless that busts the hand, then 1. A hand containing an ace counted as 11 is *soft*.
5. Player actions: **Hit**, **Stand**, **Double** (double the stake, take exactly one card, then stand — allowed on any first two cards).
6. Player over 21 busts and loses the stake immediately; the dealer does not play.
7. Dealer reveals the hole card, then **draws on 16 and stands on all 17**, including soft 17 (AC-032).
8. Higher total wins. Equal totals push and the stake is returned.

**Not in v1:** splitting, insurance, surrender. See Assumption 4 in the spec — splitting needs multi-hand state and UI and is a cabinet-sized piece of work on its own.

## 5. State machine

```
BETTING ──deal──▶ DEALING ──▶ [natural?] ──yes──▶ RESOLVING
                                  │no
                                  ▼
                            PLAYER_TURN ──stand/double──▶ DEALER_TURN ──▶ RESOLVING
                                  │ hit                                        │
                                  ├──▶ PLAYER_TURN (not bust)                  │
                                  └──▶ RESOLVING (bust, dealer does not play)  │
                                                                               ▼
                            BETTING ◀───────────────────────────────── tally done
```

| State | Accepts input | Exit leads to |
| --- | --- | --- |
| `BETTING` | Yes — stake adjust, deal, exit | `DEALING` or floor |
| `DEALING` | No (AC-044) | `PLAYER_TURN` or `RESOLVING` |
| `PLAYER_TURN` | Yes — hit, stand, double | `PLAYER_TURN`, `DEALER_TURN`, `RESOLVING` |
| `DEALER_TURN` | No | `RESOLVING` |
| `RESOLVING` | No | `BETTING`, emitting `round_resolved` |

Exiting during `PLAYER_TURN` → `abandon()` → `ABANDONED`, stake forfeit. Exiting in `BETTING` is free.

## 6. Math

Blackjack's RTP is not a closed-form paytable — it emerges from the rule set and the strategy played. The rules chosen here are:

| Rule | Setting | Effect on house edge |
| --- | --- | --- |
| Decks | 6 | baseline |
| Dealer on soft 17 | Stands (S17) | favours the player |
| Blackjack pays | 3:2 | favours the player — 6:5 would roughly triple the edge |
| Double | Any first two cards | favours the player |
| Split | Not offered | **costs** the player |
| Insurance / surrender | Not offered | negligible under basic strategy |

**Declared `target_rtp`:** `0.990`
**Computed RTP:** not computed by hand. Published figures for six-deck S17 with 3:2 naturals and basic strategy sit near 99.6% RTP; removing splits costs the player roughly half a percentage point, which lands this rule set near **99.0%**. This is an estimate, and it is exactly why AC-027 exists — **M3 measures it over a million hands with a scripted basic-strategy player and the declared value is corrected to whatever the harness reports.** No number in this section ships unverified.

**Hit frequency:** ≈43% of hands win outright, ≈9% push, ≈48% lose. Blackjack feels far fairer than the slot because losses arrive without the long dry spells a 17.9% hit rate produces.
**Volatility:** LOW
**Max win:** 3× stake (a doubled hand that wins pays 2× the doubled stake against a 2× outlay). A natural pays 2.5× the stake returned. Cap: 3×.

### Payout table

| Outcome | Pays (returned, including stake) |
| --- | --- |
| Natural (2-card 21), dealer no natural | 2.5× stake |
| Win | 2× stake |
| Win after doubling | 4× original stake (2× the doubled stake) |
| Push | 1× stake |
| Loss / bust | 0 |

### Basic strategy — the harness script

The M3 harness plays this table. It is also the correct answer for any player and may be surfaced in-game as a hint later.

**Hard totals**
- 8 or less: Hit
- 9: Double vs dealer 3–6, else Hit
- 10: Double vs dealer 2–9, else Hit
- 11: Double vs dealer 2–10, else Hit
- 12: Stand vs 4–6, else Hit
- 13–16: Stand vs 2–6, else Hit
- 17+: Stand

**Soft totals**
- A2–A3: Double vs 5–6, else Hit
- A4–A5: Double vs 4–6, else Hit
- A6: Double vs 3–6, else Hit
- A7: Double vs 3–6, Stand vs 2/7/8, Hit vs 9/10/A
- A8+: Stand

## 7. Bet limits

| Tier | Min | Max |
| --- | --- | --- |
| MAIN_FLOOR | 5 | 100 |

Higher minimum than the slot, deliberately. Blackjack is the better game for the player, so it costs more to sit down.

## 8. Controller map

| Input | Action | Available in state |
| --- | --- | --- |
| D-pad ←/→ | Decrease / increase stake | `BETTING` |
| A / Cross | Deal | `BETTING` |
| A / Cross | Hit | `PLAYER_TURN` |
| X / Square | Stand | `PLAYER_TURN` |
| Y / Triangle | Double (hidden unless legal) | `PLAYER_TURN`, first two cards only |
| B / Circle | Return to floor | `BETTING` |

Double is hidden rather than greyed when illegal — a greyed button on a 7" screen is a button the player squints at.

## 9. Screen layout (960×540)

```
┌────────────────────────────────────────────────────────────────┐
│  CHIPS 1,240                                      DEBT 100     │ ← 16px
│                                                                │
│                    DEALER     17                               │ ← 16px
│                  ┌───┐┌───┐┌───┐                               │
│                  │ K ││ 5 ││ 2 │                               │
│                  └───┘└───┘└───┘                               │
│                                                                │
│                  ── shoe ──  ▓▓▓▓▒▒░░                          │ ← penetration bar
│                                                                │
│                  ┌───┐┌───┐                                    │
│                  │ A ││ 9 │                                    │
│                  └───┘└───┘                                    │
│                    YOU     SOFT 20          STAKE  25          │ ← 16px
│                                                                │
│  (A) HIT   (X) STAND   (Y) DOUBLE            (B) LEAVE         │ ← glyphs swap
└────────────────────────────────────────────────────────────────┘
```

Card faces at 56×80 in base-viewport space. Rank and suit must be legible at 8px — this is the hardest readability case in v1 and the reason the M4 pass exists. A 10 and a K must be distinguishable at arm's length on a 7" panel, which means rank glyphs get more pixel budget than suit pips.

The shoe penetration bar is decoration in v1 — nothing is counted — but it sells the six-deck fiction and costs one sprite.

## 10. Audio cues

| Moment | Cue |
| --- | --- |
| Stake change | Chip stack click |
| Deal | Two card slides, 120ms apart |
| Hit | Single card slide |
| Double | Chip stack doubling, then one decisive slide |
| Dealer reveal | Hole card flip, a beat of silence before the draw |
| Dealer draws | One slide per card, tension bed rising with each |
| Player bust | Low thud, bed cuts |
| Win | Chips pushed across felt |
| Natural | Distinct fanfare — it must not sound like an ordinary win |
| Push | Neutral single tone; the player should know instantly nothing happened |

## 11. Assets required

| Asset | Dimensions | Frames | Method | Notes |
| --- | --- | --- | --- | --- |
| Card faces | 56×80 | 52 | HAND-PIXEL | Rank legibility at 8px is the constraint; generation cannot hold 52 consistent faces |
| Card back | 56×80 | 1 | GENERATE | Neon geometric, one design |
| Card slide | 56×80 | 4 | HAND-PIXEL | Deal animation |
| Felt table surface | 960×280 | 1 | GENERATE | Dark green/near-black, subtle texture, no busy pattern behind cards |
| Dealer figure | 128×160 | 4 | GENERATE + cleanup | Idle, deal, reveal, react — static poses, animated by cleanup |
| Chip stack | 24×32 | 5 | GENERATE | One per denomination |
| Shoe + penetration bar | 96×48 | 1 | GENERATE | |
| Floor sprite (table from above) | 64×48 | 1 | GENERATE | |

## 12. Juice & tells

Blackjack's tension is not in the cards, it is in **the dealer's hole card.** The design pauses a full beat between the reveal and the first draw, because that is the moment the player already knows whether they won and is waiting to be told.

The dealer figure carries the only personality on the Main Floor. Four poses is enough: idle, dealing, revealing, and a single reaction that differs on a player win versus a dealer win. It should never gloat — the House owner does that later, and the contrast matters.

A player natural is the one outcome that gets an unambiguous, distinct fanfare. It is the rarest good thing that happens at this table (about one hand in 21) and it must never be confused with an ordinary win.

## 13. Edge cases

| Case | Handling | AC |
| --- | --- | --- |
| Exit during `PLAYER_TURN` | `abandon()` → ABANDONED, stake forfeit | AC-009 |
| Double with insufficient balance | Double hidden; balance checked before the option is offered | AC-011 |
| Shoe exhausted mid-hand | Reshuffle happens between hands only, never mid-hand; the 52-card threshold guarantees a full hand is always dealable | AC-030 |
| Both player and dealer natural | Push, stake returned | AC-031 |
| Player and dealer both bust | Impossible — player bust resolves before the dealer plays | — |
| Ace revaluation | Hand value computed as the highest total ≤21; a soft hand that would bust silently recounts the ace as 1 | — |
| Input mashed during `DEALER_TURN` | Ignored | AC-044 |

## 14. Open questions

- **Should basic strategy be surfaced as an in-game hint?** — blocks: nothing. It is a UI addition with no architectural consequence and no v1 commitment. The strategy table already exists in §6 for the harness, so the data cost is zero.
