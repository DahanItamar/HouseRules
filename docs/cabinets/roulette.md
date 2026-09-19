# Cabinet: Ruby Roulette (European Roulette)

> `id: &"roulette"` · Tier: VIP · Status: Playable (VIP Penthouse, anchor `roulette`)

---

## 1. Fantasy

A single-zero roulette table in the VIP Penthouse salon at night. An auburn-haired
croupier in ruby satin runs the wheel; three regulars share the table and bet every
spin. The player builds a layout of chips, the croupier launches the ball, calls
"no more bets", and announces the pocket.

## 2. Core loop

Choose a chip, place chips on any mix of inside and outside spots, SPIN. One ball
settles every bet on the layout together. CLEAR removes everything; REBET restores
the previous spin's layout.

## 3. Agency class

`PURE_CHANCE`. Players choose volatility (straight-up long shots or even-money bets).
They cannot change the expected return, because every bet returns 36/37 of its stake.

## 4. Rules

1. The wheel has 37 pockets: 0 to 36, one zero, in physical European order.
2. Chips can go on any of 157 layout spots: 37 straights, 60 splits (including
   0-1, 0-2 and 0-3), 14 streets (including the 0-1-2 and 0-2-3 trios), 23 corners
   (including the 0-1-2-3 first four), 11 six-lines, 3 dozens, 3 columns and
   red/black, odd/even, low/high.
3. The table limit applies to the total on the layout: at least 1 chip, at most 100
   chips, and never more than the player's balance.
4. SPIN draws one uniform pocket from the cabinet's named RNG stream. The result
   stake is the whole layout total. The payout is the sum of every winning bet,
   including its returned stake.
5. Zero loses every outside bet. There is no la partage or en prison rule.

## 5. State machine

```
BETTING ──spin──▶ SPINNING (result decided, wheel presenting) ──ball lands──▶ SETTLED ──▶ BETTING
```

| State | Accepts input | Notes |
| --- | --- | --- |
| `BETTING` | Chips, cursor, place/remove, Clear, Rebet, Spin, Back | Unspun chips are not deducted. Leaving returns them. |
| `SPINNING` | Back only, through the stake-at-risk confirmation | `RoundResult` exists before the ball moves. The panel holds settlement until the ball lands. |
| `SETTLED` | Same as `BETTING` | The winning number marker stays until the next action or after 2.6 s. Then losing chips are swept and the guests bet again. |

Confirming Back during `SPINNING` closes the session. CabinetSession completes the
pending result, so the decided outcome still settles exactly once.

## 6. Math

A spot that covers `k` numbers pays `(36 / k) − 1` to one, so it returns
`36 / k × k / 37 = 36 / 37` of its stake:

| Bet | k | Pays | RTP |
| --- | --- | --- | --- |
| Straight | 1 | 35:1 | 97.297% |
| Split | 2 | 17:1 | 97.297% |
| Street / trio | 3 | 11:1 | 97.297% |
| Corner / first four | 4 | 8:1 | 97.297% |
| Six line | 6 | 5:1 | 97.297% |
| Dozen, column | 12 | 2:1 | 97.297% |
| Red/black, odd/even, low/high | 18 | 1:1 | 97.297% |

The prices come from `data/paytables/roulette.tres` (`RoulettePaytable`).
`tests/test_roulette.gd` enumerates all 37 pockets for every one of the 157 spots.
Each spot returns exactly 36 chips per 37 staked.

**Declared `target_rtp`:** `0.973` · **Exact RTP:** 36/37 = **97.2973%**
**Million-round measurement** (seed 20260918, four uniformly random spots × 10
chips per spin, `tests/results/rtp.json`): **97.7191%**, which is 0.42 percentage
points from the exact value. The strict ±1-point gate passes.

## 7. Bet limits

| Tier | Min chip | Table maximum | Chips |
| --- | --- | --- | --- |
| VIP | 1 | 100 (layout total) | 1, 5, 10, 25, 50 |

## 8. Controller map

| Input | Action |
| --- | --- |
| D-pad / left stick / WASD / arrows | Move the layout cursor in half-cell steps: numbers, shared edges (splits), crossings (corners), and the bottom edge (streets, six-lines). The next row is always reached first, and horizontal moves stay in the row. |
| A / Enter / left click | Place the selected chip on the cursor spot |
| X / right click | Take one selected-chip amount back from the cursor spot |
| Y | Spin |
| Down from the outside row | Focus moves to the chip rack. Clear, Rebet and Spin are buttons in the deck. Up returns to the layout. |
| Start / F1 | How to play |
| B / Esc | Leave. A live spin asks for confirmation first. |

The stick moves one step per push (a latched deadzone), not one step per frame.
Cyan appears only on keyboard/controller focus: the layout cursor ring and deck
buttons. With the pointer, the cursor ring is brass.

## 9. Screen layout (960×540)

| Region | Rect | Contents |
| --- | --- | --- |
| Croupier lane | 22,0 236×209 | Croupier clipped at the far rail (upper thigh), standing behind the wheel |
| Wheel | centre 137,245, r 130, y-squash 0.56 | Painted bowl + rotor, code-drawn 37-pocket ring, ball |
| Title plaque | 296,27 262×60 | Title and live status |
| Seat plates | 296,96 3 × 198×88 | Guest portrait, name, style + chip colour, reaction line |
| Help | 770,27 142×44 | How to play |
| Betting layout | 296,212 616×220 | 44 px cells, dozens and outside rows 44 px tall |
| Result plaque | 48,324 242×104 | Last pocket, colour/parity/half, recent numbers |
| Deck | 48,436 864×72 | Credits, chip rack (52 px chips), bet/limit and spot readout, CLEAR, REBET, SPIN |

## 10. Table life

Three seated guests bet every spin with wheel chips in their own colours. They use
a fixed presentation seed and never touch `RouletteMath.bets`, the cabinet RNG
stream or the wallet (`RouletteTableGuests`).

| Guest | Style | Bets | Lines |
| --- | --- | --- | --- |
| Mr. Okada (teal) | Careful system bettor | Martingale on a colour: 5 → doubles after a loss. He resets after a win or above 80 and then switches colour. | "One unit, 5. The system holds." / "As calculated." / "A minor variance." |
| Desmond (amber) | Reckless dreamer | 10 on 17 every spin, plus a random straight-up long shot half the time | "All on 17! Feel it?" / "SEVENTEEN! I told you!" / "Next one. Definitely." |
| Signora Lucia (plum) | Superstitious regular | 5 each on 7, 14 and 23 (her grandmother's birthday) | "Nonna's birthday: 7, 14, 23." / "Grazie, Nonna!" / "(sigh) Not today, cara." |

Guest straight-up chips sit in a cell corner so the printed number stays readable.

## 11. Presentation and motion

- The pocket is decided by `RouletteMath.spin()` before `RouletteWheel.spin_to()`.
  The ball runs against the rotor for five relative turns. It eases onto the
  target pocket's rotor-frame angle, then drops from the track with two decaying
  hops. The final angle is exact by construction. `tools/capture_roulette.gd`
  writes `roulette_motion_proof.json`, which checks the decided pocket against the
  ball and the layout marker.
- Croupier beats: idle (watching the wheel), spin launch, "no more bets" held
  while the ball drops, and a result announcement toward the player.
- Result: an ivory marker with a brass crown on the winning number, and brass rings
  on winning chips. Losing chips dim until the sweep. There is a shared win flash
  and chip burst for wins.
- **Reduced motion:** the rotor stays still and the ball appears in its pocket at
  once. One bounded brass ring around the pocket (0.45 s) is the cue, and the
  croupier keeps her static master pose. Settlement follows after a shortened
  readable beat.

## 12. Assets

| Asset | Path | Notes |
| --- | --- | --- |
| Salon backdrop | `assets/production/roulette/roulette_salon_backdrop.png` | 3840×2160, no people |
| Wheel bowl / rotor | `assets/production/roulette/roulette_wheel_bowl.png`, `roulette_wheel_rotor.png` | Re-centred painted wheel. The numbered pocket ring is drawn in code. |
| Chips | `assets/production/roulette/roulette_chip_{1,5,10,25,50}.png` | Painted, 320 px, transparent. Guest chips are the ivory chip tinted. |
| Guests | `assets/production/roulette/guest_{system,dreamer,regular}.png` | 512 px painted busts |
| Croupier | `assets/production/characters/hosts/roulette_croupier{,_spin,_no_more_bets,_announce}.png` | 1392×2080 transparent masters, head-registered |

Provenance, job IDs and credits are in `docs/art/GENERATION-REPORT.md`
("Ruby Roulette").

## 13. Edge cases

| Case | Handling |
| --- | --- |
| Chip would exceed limit or balance | Refused, with the notice "Table limit or bankroll reached" |
| Spin with an empty layout | Refused, with the notice "Place a chip before you spin" |
| Rebet above the current limit | Refused. The layout is unchanged. |
| Balance below 1 | No chip is available. The status points to the cashier. |
| Back during the spin | Exit confirmation. Confirming settles the already decided result once. |
| Reduced motion toggled mid-spin | The wheel snaps to the landed state. Settlement proceeds. |
