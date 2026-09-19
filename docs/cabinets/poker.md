# Cabinet: Texas Hold'em (Penthouse table)

> `id: &"poker"` · Tier: VIP · Status: Built

---

## 1. Fantasy

The penthouse's private card table: a sapphire felt under a pendant lamp, the
city skyline behind a platinum-blonde dealer, and five regulars with very
different ideas about poker. It is the one room where reading people pays: the
Shark punishes mistakes, the Calling Station never lets a bluff through, and the
Tourist hands out gifts to anyone patient enough to wait for them.

**Arcade ancestor:** none — classic card room.

## 2. Core loop

Pick table stakes → post blinds and receive two cards → fold, check/call or
bet/raise on four streets against five NPCs → showdown or everyone folds → pot
(minus rake) is pushed to the winner.

## 3. Agency class

`CHANCE_PLUS_SKILL`

The player makes every decision a real poker player makes, against opponents
who also decide. There is **no fixed RTP**: the return is a property of the
player's strategy. The economics harness therefore measures one declared,
reproducible baseline strategy and labels the figure skill-dependent (§6).

## 4. Rules

1. Six seats: the player (seat 0) and five NPCs (seats 1–5, clockwise: the
   Shark, the Rock, the Maniac, the Calling Station, the Tourist). The dealer
   button moves one seat clockwise every hand.
2. **Fixed limit.** The selected stake `S` is the small bet and the big blind;
   the small blind is `S/2` (all table stakes are even). Preflop and flop bets
   and raises are `S`; turn and river bets and raises are `2S`. Each street
   allows one bet and three raises (the big blind counts as the preflop bet).
3. Standard Hold'em order: blinds, two hole cards each, preflop betting from the
   seat after the big blind, burn + flop (3), turn (1), river (1), each with a
   betting round starting left of the button; showdown if two or more remain.
4. Hands rank from the best five of seven cards: straight flush, four of a
   kind, full house, flush, straight (A-2-3-4-5 is the lowest straight; no
   wrap-around), three of a kind, two pair, pair, high card, with kickers.
   Suits never break ties; equal hands split.
5. **Pots.** Side pots are built by contribution level; folded chips stay in
   the pots they were put into. Chips nobody matched (an uncalled bet) are
   returned to their owner as a one-seat pot. Split pots divide evenly; odd
   chips go to the first winner clockwise from the button.
6. **Player limits.** The player can never commit more than their balance at
   the start of the hand (like Blackjack's double): short of a full call or
   raise they go all in for what they have and side pots follow.
7. **NPC stacks are table chips only.** Each NPC starts with 40 stakes and tops
   back up to 40 stakes before a hand whenever below 24 stakes (the most one
   seat can put in a capped hand), so NPCs are never all in. NPC chips never
   touch the wallet.
8. **Rake:** 10% of each contested pot the player wins (integer, rounded down),
   at most 3 stakes per hand, and none when the hand ends before the flop
   ("no flop, no drop"). Returned uncalled bets are never raked. NPC pots are
   not raked (they are not money).
9. **Result.** `RoundResult.stake` = every chip the player put in the pot this
   hand (blinds included). `payout` = the player's share of the pots they won,
   minus rake. WIN if payout > stake, PUSH if equal, otherwise LOSS. Folding
   pays 0.

## 5. State machine

```
IDLE ──deal──▶ HAND (PokerMath resolves NPCs until the player must act)
                  │
                  ├─ PLAYER_TURN ──fold/check/call/bet/raise──▶ HAND
                  │
                  └─ hand over ──▶ REVEAL (panel replays the recorded events)
                                        │
                                        ▼
                               RESOLVED: round_resolved → wallet → IDLE
```

| State | Accepts input | Exit leads to |
| --- | --- | --- |
| `IDLE` | Yes — stakes, deal, help, leave | `HAND` or floor |
| `HAND` (presentation catching up) | No (AC-044): A/X/Y are consumed | `PLAYER_TURN` or `REVEAL` |
| `PLAYER_TURN` | Yes — fold (only facing a bet), check/call, bet/raise | `HAND` |
| `REVEAL` | No | `IDLE` after the result beat |

Exiting during a live hand opens the shared stake-at-risk confirmation; leaving
calls `abandon()` → `ABANDONED` and forfeits every chip already committed.
Exiting in `IDLE` is free. `PokerMath` resolves synchronously and records every
step as an event; `PokerTablePanel` only replays them (presentation never feeds
back into the rules), and settlement waits for the replay
(`_gates_result_on_reveal`).

## 6. Math and economics

The rules are pure `RefCounted` domain code: `PokerHandEval` (bit-packed
7-card evaluator; score = category << 20 | five 4-bit ranks), `PokerOdds`
(Chen preflop score mapped to an exact percentile over all 1,326 starting
hands; Monte-Carlo equity from the explicit stream), `PokerNpc` (personalities)
and `PokerMath` (table flow, pots, rake). Every random draw — the shuffle and
every NPC equity sample — uses the cabinet's `RNGService.stream(&"poker")`, so a
hand replays identically from the same seed and inputs (AC-014).

### NPC model

Each decision reads only public state plus the NPC's own cards:

- **Preflop:** hand percentile vs. a play range (`vpip`, widened by late
  position and tilt) and a raise range (`pfr`, narrowed by every raise already
  in). Facing three or more bets only the stronger half continues.
- **Postflop:** Monte-Carlo equity against the live opponents (cached once per
  street; 16–48 samples by skill), plus misread noise and tilt. `strength =
  equity × (opponents + 1)` (1.0 = a fair share). Bet/raise strong hands with
  probability `aggression`; bluff weak ones with `bluff`; call when equity beats
  `lerp(0.34, pot odds, odds_skill) − call_bias`, else fold.
- **Mistakes:** with probability `mistake` a random legal action replaces the
  reasoned one — the Tourist folds monsters and calls with air.
- **Tilt:** losing more than 6 stakes in a hand adds `tilt_gain` (loosens and
  speeds up play); it decays 20% per hand.

| NPC | vpip | pfr | aggr. | bluff | mistake | odds skill | call bias | samples | tilt |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| The Shark (TAG, exact odds) | .22 | .16 | .78 | .09 | .02 | 1.0 | 0 | 48 | .05 |
| The Rock (very tight, passive) | .12 | .05 | .25 | .01 | .03 | 0.6 | −.06 | 32 | .04 |
| The Maniac (LAG, bluffs) | .55 | .34 | .88 | .34 | .07 | 0.3 | .05 | 24 | .30 |
| The Calling Station (calls anything) | .62 | .03 | .12 | .02 | .08 | 0.1 | .20 | 24 | .15 |
| The Tourist (novice, random errors) | .42 | .08 | .30 | .10 | .17 | 0.0 | .05 | 16 | .25 |

### Baseline and declared target

Baseline player (`PokerMath.baseline_action`): plays the top 25% of starting
hands, raises the top 10% (up to the third bet), then bets/raises with
`strength ≥ 1.6`, calls when equity beats pot odds, otherwise checks or folds.

`tests/poker_economics.gd` plays **100,000 hands** at stake 10 with seed
20260918 and records the result in `tests/results/rtp.json` (entry `poker`,
`skill_dependent: true`), including rake paid, win/fold/showdown rates and each
NPC's win rate in big blinds per 100 hands.

Tuning history (20,000-hand runs, same seed): with 5% rake the baseline
returned 113.4% (+23.7 bb/100) — a chip faucet for any tight player. Raising the
rake to 10% gave 108.6%; softening only the two weakest regulars (Calling
Station call bias .26 → .20, Tourist mistakes .24 → .17) gave 105.7% (+10.2
bb/100), with the Shark (+17 bb/100) still the best player at the table.
Disciplined play wins modestly; loose or passive play loses.

**Measured baseline (100,000 hands, seed 20260918, stake 10):** return
**1.06494** (standard error 0.0087), +11.6 bb/100; the player wins 12.8% of hands
outright, folds 75.3% and reaches showdown in 22.1%; rake paid 180,659 chips on
1,781,770 wagered. NPC results in bb/100: Shark +15.3, Maniac +10.3, Rock −1.3,
Tourist −15.1, Calling Station −38.9.

**Declared `target_rtp`:** `1.065` (the measured baseline, rounded).
**Tolerance:** ±0.03 — more than three standard errors at 100k hands.
`tests/test_poker_domain.gd` checks the recorded 100k figure against the target
within ±0.03 and a fresh 1,500-hand sample within ±0.25 (about 3.5 SE at that
size). This is a skill-dependent return, not a guarantee: a looser or more
passive player returns less, and a stronger one more.
**Volatility:** MEDIUM. **Max loss per hand:** 24 stakes (capped betting).
**Max win:** bounded by five opponents' capped contributions (≈ 5 × 24 stakes).

## 7. Bet limits

| Tier | Stakes (big blind) | Min | Max |
| --- | --- | ---: | ---: |
| VIP | 4 · 10 · 20 · 50 · 100 | 4 | 100 |

A hand can cost up to 24 stakes; the player may start any hand with at least
one stake and go all in below that.

## 8. Controller map

| Input | Action | Available in state |
| --- | --- | --- |
| A / Enter | Deal in · Check · Call | IDLE, PLAYER_TURN |
| X | Fold (only when facing a bet) | PLAYER_TURN |
| Y | Bet / Raise by the fixed limit | PLAYER_TURN |
| D-pad / stick left-right | Change table stakes | IDLE |
| Start / F1 | How to play | any |
| B / Esc | Leave (live hand: stake-at-risk confirmation) | any |

Every action is also a 44 px+ mouse button; cyan appears only on focus.

## 9. Screen layout (960×540)

```
┌ TEXAS HOLD'EM plaque ┐           dealer            [? HOW TO PLAY]
│ status line          │  [MANIAC]  (behind rail) [CALLING STATION]
                            [cards]                 [cards]
[ROCK plate][cards]      ▢ ▢ ▢ ▢ ▢  board          [cards][TOURIST plate]
                         [chips] POT 120
[SHARK plate][cards]      [your 2 cards]  (D)       [YOU · credits · hand]
┌ CREDITS │ stakes 4 10 20 50 100  /  TO CALL POT LIMIT IN │ FOLD │ CALL │ RAISE ┐
```

Credits and stake values use the 16 px critical size; labels are 12 px+.

## 10. Audio cues

| Moment | Cue |
| --- | --- |
| Blind / call / bet | `chip` |
| Deal | `card_deal`; board turn `card_flip` |
| Check / fold | `tick` / `card` |
| Showdown | `reveal` |
| Win / split / loss | `blackjack_win` / `blackjack_push` / `blackjack_loss` |

## 11. Assets required

Generated through the Higgsfield MCP (see `docs/art/GENERATION-REPORT.md`):
table backdrop 3840×2160, dealer master + deal/reveal/push/player poses
(1392×2080 transparent), five NPC busts plus reaction faces (512×512), chip
stack art. Cards are the shared `PlayingCard` deck.

## 12. Juice & tells

- NPCs visibly *think*: the acting seat gets a silver top rule and a bounded
  progress hairline; think time follows personality (Shark 0.8 s, Maniac
  0.35 s), is shortened by tilt, and never touches the game stream.
- Aggressive actions flash the NPC's painted reaction face; pot winners keep it
  with a brass plate edge; folded seats dim and their cards are mucked to the
  dealer.
- Cards fly from the dealer's hand; street bets slide into the pot; the dealer
  turns the board, looks up at the player while they decide and pushes the pot.
- Showdown dims every card outside the winning five.
- After the player folds, the rest of the hand plays out 2.5× faster.
- Reduced motion: cards are placed instantly, NPC thinking is 0.12 s, the dealer
  holds her master pose and acknowledges each beat with one bounded cue bar.

## 13. Edge cases

| Case | Handling | AC |
| --- | --- | --- |
| Exit mid-hand | `abandon()` → ABANDONED, committed chips forfeit | AC-009 |
| Input while NPCs act or the reveal plays | Consumed and ignored | AC-044 |
| Player balance below a call/raise | All in for the balance; side pots | AC-010 |
| Everyone folds to the player | Pot returned/awarded, no rake without a flop | — |
| Uncalled bet | Returned unraked as a one-seat pot | — |
| Split pot with an odd chip | First winner clockwise from the button | — |
| Test bank (unlimited) | Credits show ∞; stakes still capped at 100 | — |

## 14. Open questions

- No-limit / pot-limit variants would need a raise-sizing control (the stake
  adjust keys are free during a hand for that). Blocks nothing.
- NPC opponent modelling (adapting to the player's own aggression) is not
  implemented; the baseline edge would shrink with it.
