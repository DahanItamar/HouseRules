# Cabinet: Velvet Baccarat (Punto Banco)

> `id: &"baccarat"` · Tier: High Roller · Status: Playable and seated in the High Roller
> Salon (`data/floors/high_roller.json`).

---

## 1. Fantasy

A private high-limit baccarat salon at night: violet velvet drapes, walnut panelling
and brass sconces. A dark-brunette hostess in violet satin deals from a walnut shoe.
She squeezes each hand's cards before turning them face up, then announces the coup.

## 2. Core loop

Choose a chip and place chips on any mix of Player, Banker, Tie, Player Pair and Banker
Pair. Then DEAL. The hostess deals four cards, squeezes the Player hand, then the
Banker hand, and deals any third cards by the fixed tableau. The coup settles every
spot together. CLEAR removes everything, and REBET restores the previous coup's layout.

## 3. Agency class

`PURE_CHANCE`. The player picks which hand to back and how much. No decision changes
the cards: the third-card tableau is fixed.

## 4. Rules

1. The shoe holds eight decks (416 cards). It is freshly shuffled for every coup
   (a continuous shuffler), so every hand has exactly the enumerated odds below.
2. Deal order: Player, Banker, Player, Banker. Aces count 1, two to nine count face
   value, and tens and courts count 0. A hand is worth the last digit of its sum.
3. An 8 or 9 on two cards is a natural, and both hands stand.
4. Otherwise the Player draws on 0-5 and stands on 6-7.
5. If the Player stood, the Banker draws on 0-5. Otherwise the Banker draws on 0-2,
   on 3 unless the Player's third card is 8, on 4 against 2-7, on 5 against 4-7 and
   on 6 against 6-7. The Banker stands on 7.
6. Prices: Player 1:1. Banker 1:1 less 5% commission. Tie 8:1. Player and Banker
   bets push on a tie. Player Pair and Banker Pair (the hand's first two cards share a
   rank, e.g. K-K but not 10-K) pay 11:1.

### Commission rounding

A winning Banker bet of `S` chips is paid `S - ceil(S × 5 / 100)`. The commission is
rounded up to a whole chip, in the house's favour, so a fraction of a chip is never paid
or owed. The rounding is deterministic and happens in `BaccaratMath.commission_for()`.
Every chip on this table (20, 40, 100, 200) is a multiple of 20, and 5% of a multiple of
20 is a whole number, so every Banker stake a player can build pays exactly 19:20. The
rounding only matters for amounts that are not multiples of 20. These cannot be placed
in the game, but the math still handles them: 30 pays 28, 10 pays 9.

## 5. State machine

```
BETTING ──deal──▶ DEALING (coup decided) ─▶ SQUEEZE P ─▶ SQUEEZE B ─▶ [THIRD P] ─▶ [THIRD B] ─▶ REVEALED ─▶ SETTLED ─▶ BETTING
```

| State | Accepts input | Notes |
| --- | --- | --- |
| `BETTING` | Chips, spots, place/remove, Clear, Rebet, Deal, Back | Chips not yet dealt are not deducted. Leaving returns them. |
| `DEALING` … `REVEALED` | Back only, through the stake-at-risk confirmation | `RoundResult` exists before the first card leaves the shoe. The panel holds settlement until every card is face up. |
| `SETTLED` | Same as `BETTING` | The cards, totals, winning box and spot rings stay until the player changes the layout or deals again. |

Confirming Back mid-deal closes the session. `CabinetSession` then completes the
pending result, so the decided coup still settles exactly once.

## 6. Math

`BaccaratOdds.outcome_counts()` enumerates every ordered deal through the tableau,
weighted by exact card counts. The total is 416 × 415 × … × 411 =
4,998,398,275,503,360 six-card sequences. The counts match an independent Python
enumeration exactly:

| Outcome | Sequences | Probability |
| --- | ---: | ---: |
| Banker | 2,292,252,566,437,888 | 45.8597% |
| Player | 2,230,518,282,592,256 | 44.6247% |
| Tie | 475,627,426,473,216 | 9.5156% |

| Bet | Pays | Exact RTP |
| --- | --- | ---: |
| Banker (any legal stake) | 19:20 | **98.9421%** |
| Player | 1:1 | 98.7649% |
| Tie | 8:1 | 85.6404% |
| Player Pair / Banker Pair | 11:1 | 89.6386% (12 × 13·32·31 / (416·415)) |

The prices come from `data/paytables/baccarat.tres` (`BaccaratPaytable`).

**Declared `target_rtp`:** `0.989` (the Banker bet). **Million-round measurement**:
seed 20260918, 20 chips on Banker every coup, recorded in `tests/results/rtp.json`.
It measured **98.99387%**, which is 0.05 percentage points from the exact value. The
strict ±1-point gate passes.

## 7. Bet limits

| Tier | Min chip | Table maximum | Chips |
| --- | --- | --- | --- |
| High Roller | 20 | 400 (total across all five spots) | 20, 40, 100, 200 |

## 8. Controller map

| Input | Action |
| --- | --- |
| D-pad / arrows | Native focus moves along the spot row and the rail row. The explicit neighbours are the same ones WASD uses. |
| Left stick / WASD | The same graph: left and right walk the row. Down goes from a spot to the selected chip. Up goes from the rail back to the last spot used. |
| A / Enter / left click | Place the selected chip on the focused spot, or press the focused button |
| X / right click | Take one selected-chip amount back from the focused (or last used) spot |
| Y | Deal |
| Start / F1 | How to play |
| B / Esc | Leave. Cards on the table ask for confirmation first. |

Cyan appears only as keyboard/controller focus. The spots and chips use
`has_focus(true)`, so a mouse click never paints the cyan ring.

## 9. Screen layout (960×540)

| Region | Rect | Contents |
| --- | --- | --- |
| Title plaque | 48,27 276×60 | Title and live status |
| Coup plaque | 48,95 276×118 | Winner, totals, natural/pair tags, payout and commission, winner stripe |
| Hostess lane | 336,0 288×222 | Hostess clipped at the painted far rail (y=222) |
| Help | 770,27 142×44 | How to play |
| Bead road | 636,79 276×134 | 6×15 beads (B crimson, P sapphire, T jade, pearl pair dots), counts |
| Player box | 96,246 330×92 | Total disc (left), two cards, sideways third card |
| Shoe | 444,252 72×60 | Painted walnut shoe; cards travel from its mouth |
| Banker box | 534,246 330×92 | Mirror of the Player box |
| Bet spots | y 346, h 82 | Player Pair 116, Player 176, Tie 152, Banker 176, Banker Pair 116 wide |
| Rail deck | 48,436 864×72 | Credits, chip rack (52 px chips), bet/limit and spot readout, CLEAR, REBET, DEAL |

## 10. Presentation and motion

- `BaccaratMath.deal()` draws the whole coup from the cabinet stream before
  `BaccaratTablePanel.begin_deal()` shows any card. Cards are drawn without
  replacement by rejection from the 416-card shoe.
- Deal: P1, B1, P2 and B2 fly face down from the shoe mouth (0.28 s each).
- Squeeze: both cards of a hand peel from the bottom edge (0.85 s). A pearl fold line
  and a flat shadow band mark the peel. Then the hand's total appears. Third cards
  land sideways and are squeezed in 0.6 s.
- Result: the winning box gets a brass rim and a WINS tag (TIE on both boxes for a
  tie), and the coup plaque names the winner. Winning spots get a brass ring, pushed
  spots a pearl ring, and losing chips dim. A bead is added to the road, the shared win
  flash plays, and wins get a chip burst.
- Hostess beats: idle (watching the shoe), deal (a reach toward the card lane, held
  while the cards land), squeeze (studying a card, held through the squeeze), and
  announce (a warm smile to the player).
- **Reduced motion:** there is no card travel or peel. Every card lands face up at
  once, the totals show, and one bounded brass ring (0.45 s) marks the winning box (or
  both boxes on a tie). The hostess keeps her static master pose and shows her own cue
  bar. Settlement follows after the shortened readable beat. Turning reduced motion on
  mid-deal snaps the coup to its revealed state.
- `tools/capture_baccarat.gd` writes `baccarat_deal_proof.json`. It checks the decided
  cards and totals against the cards and totals on the felt.

## 11. Assets

| Asset | Path | Notes |
| --- | --- | --- |
| Salon backdrop | `assets/production/baccarat/baccarat_salon_backdrop.png` | 3840×2160, no people, plain felt |
| Shoe | `assets/production/baccarat/baccarat_shoe.png` | Walnut and brass, transparent |
| Chips | `assets/production/baccarat/baccarat_chip_{20,40,100,200}.png` | Pearl, lavender, plum, black lacquer; 320 px; values drawn in code |
| Hostess | `assets/production/characters/hosts/baccarat_hostess{,_deal,_squeeze,_announce}.png` | 1392×2080 transparent masters, head-registered |
| Cards | `src/ui/playing_card.gd` + `assets/production/cards/` | The shared premium deck |

Provenance, job IDs and credits are in `docs/art/GENERATION-REPORT.md`
("Velvet Baccarat"). Rebuild with `python tools/art/prepare_baccarat.py`.

## 12. Edge cases

| Case | Handling |
| --- | --- |
| A chip would pass the limit or balance | Refused, with the notice "Table limit or bankroll reached" |
| Deal with an empty layout | Refused, with the notice "Place a chip before the deal" |
| Rebet above the current limit | Refused. The layout is unchanged. |
| Balance below 20 | No chip is available. The status points to the cashier. |
| Back during the deal | Exit confirmation. Confirming settles the already decided coup once. |
| Reduced motion toggled mid-deal | The coup snaps to face up. Settlement proceeds. |
| Player and Banker both backed | Allowed. Both settle, and both push on a tie. |
