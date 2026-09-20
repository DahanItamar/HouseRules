# Cabinet: Match Point (tennis Plinko)

> `id: &"match_point"` · Tier: High Roller · Status: Playable and seated in the High Roller Salon (`data/floors/high_roller.json`)

---

## 1. Fantasy

A country-club Plinko cabinet in the clubhouse at golden hour. A honey-blonde
hostess in tennis whites serves a tennis ball into a brass hatch at the top of a
grass-green board. The ball hops off twelve rows of brass court-stud posts and
drops into one of thirteen cream-enamel courts, each marked with its multiplier.

## 2. Core loop

Choose a stake (10, 20, 50, 100 or 200) and a risk table (Low, Medium or High),
then SERVE. One ball settles one stake. The result plaque shows the court's
multiplier and payout, and the recent-drops strip keeps the last eight courts.

## 3. Agency class

`PURE_CHANCE`. Risk chooses the volatility only: all three tables have the same
exact return. There is no autoplay and no multi-ball (see §13).

## 4. Rules

1. The board has 12 rows of posts and 13 courts, numbered 1 to 13 from the left.
2. SERVE draws one uniform integer in `[0, 4096)` from the cabinet's named RNG
   stream. That single draw is the whole outcome.
3. Draws are ordered court by court. Court *k* (0-based) owns a block of exactly
   `C(12, k)` draws, so its probability is `C(12, k) / 4096` (the binomial
   distribution of twelve fair left/right hops).
4. The offset inside the court's block is unranked into one of the `C(12, k)`
   left/right sequences with exactly *k* rights. Each of the 4096 sequences comes
   from exactly one draw. The ball animates that sequence.
5. Payout = stake × multiplier. The multipliers are stored in tenths and every
   legal stake is a multiple of 10, so payouts are whole credits with no rounding.
6. The stake must be at least 10, at most 200, and never more than the balance.

## 5. State machine

```
READY ──serve──▶ IN PLAY (result decided, ball presenting) ──ball in court──▶ SETTLED ──▶ READY
```

| State | Accepts input | Notes |
| --- | --- | --- |
| `READY` | Stake, risk, Serve, Help, Back | The court trail from the last drop stays until the next serve. |
| `IN PLAY` | Back only, through the stake-at-risk confirmation | `RoundResult` exists before the ball moves. The panel holds settlement until the ball is in the court, then waits 0.5 s. |
| `SETTLED` | Same as `READY` | Result plaque, history, win flash and chip burst on wins. |

Confirming Back during `IN PLAY` closes the session. CabinetSession completes the
pending result, so the decided outcome still settles exactly once.

## 6. Math

`P(court k) = C(12, k) / 4096`:

| Court | 1/13 | 2/12 | 3/11 | 4/10 | 5/9 | 6/8 | 7 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Ways | 1 | 12 | 66 | 220 | 495 | 792 | 924 |
| Probability | 0.0244% | 0.293% | 1.611% | 5.371% | 12.085% | 19.336% | 22.559% |
| Low | 9.7× | 2.7× | 1.4× | 1.2× | 1.1× | 1× | 0.5× |
| Medium | 33× | 8× | 3× | 1.6× | 1.2× | 0.7× | 0.3× |
| High | 120× | 20× | 6× | 2.2× | 0.8× | 0.3× | 0.2× |

Exact return per table: `Σ C(12, k) × tenths[k] / (10 × 4096)`. Every table gives
**39320 / 40960 = 95.99609375%**. The value is stored as
`exact_return_numerator` in `data/paytables/match_point.tres`, and
`tests/test_match_point.gd` checks it for each risk, together with symmetry.

| Risk | Exact RTP | Variance (× stake²) | Beats the stake | Top prize |
| --- | ---: | ---: | ---: | ---: |
| Low | 95.99609375% | 0.121 | 38.77% (plus 38.67% a 1× let) | 9.7× |
| Medium | 95.99609375% | 1.108 | 38.77% | 33× |
| High | 95.99609375% | 10.332 | 14.60% | 120× |

**Declared `target_rtp`:** `0.96` · **Exact RTP:** 95.99609375%
**Million-round measurement** (seed 20260918, 10 per drop, risk cycles Low,
Medium and High, `tests/results/rtp.json`): **96.1322%**. That is 0.14
percentage points from the exact value (about 0.7 standard errors, since the
mixed sample's standard error is about 0.20 points). The strict ±1-point gate
passes.

## 7. Bet limits

| Tier | Min | Max | Stake keys |
| --- | --- | --- | --- |
| High Roller | 10 | 200 | 10, 20, 50, 100, 200 (only keys the balance can cover are enabled) |

## 8. Controller map

| Input | Action |
| --- | --- |
| D-pad / left stick / arrows / WASD | Move focus. Left and right walk a row: the deck row is the stake keys then Serve, and the risk row is Low, Medium and High. Up goes from the deck to the risk row, then to Help. Down goes back to Serve. |
| A / Enter / left click | Press the focused key. If nothing has focus, A serves. |
| Y | Serve |
| X | Next risk table |
| Start / F1 | How to play |
| B / Esc | Leave. While the ball is in play, a stake-at-risk confirmation asks first. |

Serve has focus when the cabinet opens and again after every result. Cyan
appears only on keyboard/controller focus. A selected stake or risk is shown as a
cream enamel key face.

## 9. Screen layout (960×540)

| Region | Rect | Contents |
| --- | --- | --- |
| Hostess lane | 0,27 280×413 | Hostess in the window alcove, clipped by the deck at mid-thigh |
| Serve hatch | 456,34 48×26 | Brass hatch; the next ball waits here |
| Peg field and courts | 284,34 392×398 | 12 rows of posts (28 px pitch, 26 px rows), 13 courts 26×34 with 16 px multipliers |
| Help | 704,27 208×44 | How to play |
| Title plate | 704,79 208×70 | Title and live status |
| Result plaque | 704,157 208×96 | Last multiplier on a cream score strip, "WINNER / LET / OUT", court and payout |
| Recent drops | 704,261 208×60 | The last eight multipliers, newest first |
| Risk plate | 704,329 208×103 | Low / Medium / High keys (62×48), centre and edge multipliers |
| Deck | 48,440 864×72 | Credits, stake keys (52×52), bet · risk and top court prize, SERVE (172×64) |

## 10. HUD language

Scoreboard styling: flat racing-green plates with double brass piping, and cream
enamel score strips with dark green ink. Courts are brass (5× and up), cream (1×
and up) or racing green (below 1×). The HUD has no gradients and no glow.
`MatchPointStyle` is distinct from Ruby Roulette (mahogany plates with studs),
Blackjack (walnut and felt), the Elven Court slot and Hexbound Vault.

## 11. Presentation and motion

- The court and the path are decided in `MatchPointMath.drop()` before
  `MatchPointBoard.drop()` runs. The board builds its waypoints from the path: the
  hatch, one contact on top of the struck post per row, and the court mouth.
  `MatchPointBoard.waypoints_for()` always ends at the decided court for all 4096
  paths, and the tests check every one of them.
- Serve: the ball is tossed up out of the hatch (0.55 s). It then makes 11 short
  hops of 7 px off each post, speeding up slightly from 0.16 s to 0.115 s per row,
  drops into the court, and settles with two small decaying bounces. Each post the
  ball touches turns cream with a brass ring, which leaves a readable trail. Each
  contact plays a soft tick. A full drop takes about 2.5 s.
- Result: the landed court gets a bright brass outline and the other courts dim.
  The result plaque pops once, the history strip updates, and wins get the shared
  win flash and a chip burst from the court.
- Hostess beats: idle (watching the board, ball in hand), the serve toss toward
  the hatch, anticipation with clasped hands while the ball drops, and a fist pump
  to the player on a win. After a loss she returns to watching the board.
- `tools/capture_match_point.gd` writes `match_point_motion_proof.json`, which
  records the decided court, draw and path against the board's landed court.
- **Reduced motion:** the ball appears in its court at once, the path trail is
  drawn, and one bounded brass ring (0.45 s) around the ball is the cue. The
  hostess keeps her static idle master and shows one bounded cue bar. Settlement
  follows after a shortened beat. Switching to reduced motion mid-drop snaps the
  ball into the decided court.

## 12. Assets

| Asset | Path | Notes |
| --- | --- | --- |
| Clubhouse backdrop | `assets/production/match_point/match_point_backdrop.png` | 3840×2160, no people, no text |
| Tennis ball | `assets/production/match_point/match_point_ball.png` | 256 px, transparent |
| Court-stud post | `assets/production/match_point/match_point_peg.png` | 128 px, transparent |
| Hostess | `assets/production/characters/hosts/match_point_hostess{,_serve,_watch,_celebrate}.png` | 1392×2080 transparent masters, de-fringed, eye-line registered |

Provenance, job IDs and credits are in `docs/art/GENERATION-REPORT.md`
("Match Point"). Rebuild with `python tools/art/prepare_match_point.py`.

## 13. Edge cases and scope

| Case | Handling |
| --- | --- |
| Balance below 10 | No stake key is enabled and Serve is disabled. The status points to the cashier. |
| Stake above the balance | That key is disabled. After a loss, the selection drops to the largest affordable key. |
| Serve without a coverable stake | Refused with "No stake your credits can cover". |
| Risk change or second serve mid-drop | Refused. There is one ball at a time and the risk locks while it is in play. |
| Back mid-drop | Exit confirmation. Confirming settles the already decided result once. |
| Reduced motion toggled mid-drop | The ball snaps to the decided court and settlement proceeds. |
| Autoplay / multi-ball | Not implemented. One ball per serve keeps every result readable. |
