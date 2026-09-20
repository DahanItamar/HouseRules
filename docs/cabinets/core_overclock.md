# Cabinet: Corsair's Reach (crash)

> `id: &"core_overclock"` · Tier: High Roller · Status: Playable, seated in the High Roller Salon

---

## 1. Fantasy

A night sea off a pirate coast. Two crew watch from either side of a chart on
the wall; on the chart a parrot climbs an exponential curve and draws a glowing
trail behind her. Send her up and the multiplier climbs. Call her back in time and it is
served for stake times the gauge. Leave it a second too long and it burns, the
screen flashes white-hot, smoke rolls out of the mouth and the stake is gone.

The cabinet id stays `core_overclock`: the mechanic is a crash game, and the
domain math is theme-free. Only the presentation is a sea chart.

## 2. Core loop

Choose a stake (100, 200, 500 or 1000), optionally give standing orders, then
BAKE. The gauge climbs on an exponential curve. PULL IT OUT banks
`stake × multiplier`; if she reaches her decided end point first, nothing
is paid. One run settles one stake.

## 3. Agency class

`TIMED_CHANCE`. The end point is decided before she leaves the perch; the
only decision is when to call her back. Every choice returns the same
97.00%, so no timer setting is better or worse than any other — only the shape
of the variance changes.

## 4. Rules

1. BAKE draws one uniform integer `u` in `[1, N]` with `N = 1_000_000_000` from
   the cabinet's named RNG stream. That single draw is the whole outcome.
2. The end point, in hundredths of a multiplier ("centi"), is
   `crash = floor(100 × p × N / u)` with `p = 97/100`, capped at 1000000
   (10000.00×).
3. She makes ready for `countdown_seconds` (2.2 s); nothing can be hauled in
   during that. Then the gauge climbs `multiplier(t) = 100 × e^(0.40 t)` centi.
4. PULL IT OUT pays `stake × multiplier / 100` whole chips at the multiplier the
   dial shows. The stake unit is 100 and multipliers are hundredths, so the
   division is exact and no payout ever rounds.
5. If the climb reaches the end point first, she is taken and it pays nothing.
6. An end point below 1.00x (3% of runs) lands on the frame the window would
   have opened, so she is gone before any input can reach it.
7. Standing orders, if given, call her back at exactly that multiplier
   whenever the end point is at or above it.

## 5. State machine

```
IDLE (at anchor) ──cast off──▶ COUNTDOWN (making sail) ──▶ OVERCLOCKING (running)
        ▲                                                   │         │
        └────────────────── SERVED (cashed out) ◀────pull────┘         │
        └────────────────── BURNT (crashed) ◀───────end point─────────┘
```

| State | Presentation | Accepts input | Notes |
| --- | --- | --- | --- |
| `IDLE` | AT ANCHOR | Stake, orders, Cast off, Help, Back | The last run stays on the chart and the board until the next one starts. |
| `COUNTDOWN` | MAKING SAIL | Back only (confirmation) | The stake is committed; the end point already exists. |
| `OVERCLOCKING` | BAKING | Pull it out, Back (confirmation) | The wallet is untouched; the deck shows the live stake as IN PLAY. |
| `CASHED_OUT` | SERVED | Same as `IDLE` | Settled once, at the multiplier on the dial. |
| `CRASHED` | BURNT | Same as `IDLE` | Settled once, paying nothing. |

Confirming Back during a live run forfeits the stake: `CoreOverclockMath.abandon()`
records the end point and returns an `ABANDONED` result of 0, so leaving can
never be cheaper than losing. The guide (F1) opens between runs only, so it can
never be used to pause a live one.

## 6. Math

**The distribution.** The survival function is

```
P(crash ≥ m) = p / m        for m ≥ 1,  p = 0.97
```

Sampling it needs one uniform. With `u` uniform on `{1 … N}` and
`crash = floor(100 p N / u)` centi:

```
P(crash ≥ t) = P(u ≤ 100 p N / t) = floor(100 p N / t) / N
```

which is `0.97 × 100 / t` up to one part in `N`.

**Why it is exactly 97% however the player plays.** A player who always pulls
out at `t` (in centi) gets `t/100` times the stake with that probability, so

```
E[return] / stake = (t / 100) × floor(100 p N / t) / N
                  = 0.97 − ε,     0 ≤ ε < t / (100 N)
```

The return does not depend on `t`. With `N = 10^9` and the 10000.00× cap the
worst-case shortfall is `10^6 / 10^11 = 10^-5`, that is **0.001 percentage
points**; for every whole multiplier up to 20× it is below `2 × 10^-8`.
`tests/test_core_overclock.gd` asserts both bounds for every centi from 100 to
2000 and for the decade targets.

**The instant burn is exactly 3%.** `100 p N / 100 = 0.97 N = 970_000_000` is a
whole number, so `P(crash ≥ 1.00×) = 0.97` exactly and
`P(burn before 1.00×) = 0.03` exactly — 30 million of the billion uniforms, with
no rounding anywhere.

**Rounding.** Payout is `stake × centi / 100` in integer arithmetic. Legal
stakes are multiples of the stake unit, which equals the multiplier scale (100),
so the division is exact: a payout never rounds and no chip is ever created or
destroyed. A stake that is not a multiple of 100 would round down, and the
cabinet does not offer one.

**Declared `target_rtp`:** `0.97` · **Exact RTP:** 97.00% at every timer setting.

**Million-round measurement** (seed 20260918, 100 a run, standing orders cycling
1.20×, 2.00×, 5.00× and 10.00×, `tests/results/rtp.json`): **96.7513%**. The
mixed sample's payout-multiple variance is about 3.47, a standard error of
**0.186 percentage points**, so the 0.249-point gap is 1.3 standard errors. The
strict ±1-point gate passes.

| Timer | Reached | Exact return | Payout-multiple variance |
| --- | ---: | ---: | ---: |
| 1.20× | 80.833% | 97.00% | 0.222 |
| 2.00× | 48.5% | 97.00% | 0.999 |
| 5.00× | 19.4% | 97.00% | 3.91 |
| 10.00× | 9.7% | 97.00% | 8.76 |
| 100.00× | 0.97% | 97.00% | 93.1 |

## 7. Bet limits

| Tier | Min | Max | Stake keys |
| --- | --- | --- | --- |
| High Roller | 100 | 1000 | 100, 200, 500, 1000, plus the shared MIN / 10 / 25 / X2 / X5 / ALL row |

## 8. Controller map

| Input | Action |
| --- | --- |
| A / Enter / left click | BAKE, then PULL IT OUT |
| X | Step the standing orders: off, 1.20x, 1.50x, 2.00x, 3.00x, 5.00x, 10.00x |
| Y | Same as A (the one key that matters is always reachable) |
| LB / RB, Q / E, scroll | Change the stake |
| RT / R | Table maximum |
| D-pad / left stick / WASD | Walk the timer, How to play and the primary key |
| Start / F1 | How to play (between runs only) |
| B / Esc | Leave. During a run a stake-at-risk confirmation asks first; confirming forfeits the stake. |

The primary key has focus when the cabinet opens and again after every bake.
Cyan appears only on keyboard/controller focus.

## 9. Screen layout (960×540)

The screen is laid out on the centre line, with the left and right columns the
same width and the same margin.

| Region | Rect | Contents |
| --- | --- | --- |
| Standing orders | 48,27 176x44 | Mirrors How to play at the other end of the header |
| Title plate | 330,27 300×70 | FORNO D'ORO and the live status line |
| How to play | 736,27 176×44 | Shared header control |
| Bake curve | 48,88 252×212 | Multiplier against time, on a terracotta plate |
| Recent runs | 48,310 252×100 | The last six end points, 3 × 2 muted chips |
| Multiplier | centre 464,226 | Set as bare type over the chart; there is no dial to cover the graph |
| Chart | 232,116 496x274 | The crash box: the parrot climbs inside it and the trail is drawn there |
| Host lanes | 36,118 160x300 and 764,118 160x300 | The two crew, one either side of the chart, clear of it and of the deck |
| Control deck | 48,422 864×91 | Shared deck: balance, bet, quick bets, primary key |

Everything is inside TV-safe (48, 27, 864×486) and every control is at least
44 px. The dial, the curve, the recent board, the timer and the deck are the
protected rectangles: `tests/test_core_overclock.gd` asserts nothing covers them.

## 10. HUD language

Terracotta tile plates with tomato-and-basil corners (the painted nine-slice
frame), a cream dial with dark ink, brass structure, and charred-oak deck plates
with a terracotta primary key. One accent per meaning: basil green for served,
tomato for burnt, brass for the timer. Cyan is keyboard/controller focus only.

## 11. Presentation and motion

- The end point is decided in `CoreOverclockMath.begin()` before anything
  moves. `advance(delta)` replays it and returns the settled result on the step
  that ends the run; the cabinet settles the wallet once, there.
- **The climb:** the parrot flies the curve and the trail is drawn live behind
  her, fading out at the tail so the eye is pulled to the head. She banks with
  the slope and rises and falls inside each wing beat, so the flap moves her
  rather than only animating her.
- **The end:** the screen goes white, the break-up plays through its four
  painted stages where she was, and the chart settles.
- **The haul:** the multiplier she reached is held on the chart, and both crew
  cheer together

## 12. Assets

| Asset | Path | Notes |
| --- | --- | --- |
| Night sea backdrop | `assets/production/corsair/corsair_sea.png` | 3840x2160, no people, no text |
| Parrot flight cycle | `assets/production/corsair/corsair_parrot_flight.png` | 2x2 sheet, 512 px cells, body fixed and only the wings moving |
| Trail beam | `assets/production/corsair/corsair_trail.png` | 1024x256, tiled along the climb, edges feathered to nothing |
| Chart frame | `assets/production/corsair/corsair_frame.png` | 1536x864 nine-slice, 114 px margin; the crash box and the small HUD plates are both cut from it |
| Crew, one frame per state | `assets/production/corsair/corsair_crew_{ready,tense,cheer,wince}.png` | 1920x1080, both women in each frame so their reaction is shared by construction |
| Break-up | `assets/production/corsair/corsair_wreck.png` | 2x2 sheet, 512 px cells |
| Ingredient icons | `assets/production/corsair/corsair_icons.png` | 3×2 cells of 256 |
| Embers, flour, smoke | `assets/production/corsair/corsair_embers.png` | 4×4 cells of 256 |

Every reference lives in `src/ui/core_overclock/core_overclock_theme.gd`, so the
skin is one file. Rebuild with `python tools/art/prepare_corsair.py`; provenance
is in `docs/art/GENERATION-REPORT.md` under "Corsair's Reach".

## 13. Edge cases and scope

| Case | Handling |
| --- | --- |
| Balance below 100 | No stake key is enabled and BAKE is disabled. The deck points to the cashier. |
| Stake above the balance | That key is disabled; after a loss the selection drops to the largest affordable key. |
| Bake without a coverable stake | Refused with "No stake your credits can cover". |
| Pull during the countdown | Refused: there is no window until she is away. |
| End point below 1.00× | Burns on the frame the window opens; nothing can be pulled out. |
| Orders above the end point | She is taken as she would have been anyway. |
| Orders exactly at the end point | Hauled in: reaching the setting calls her back. |
| A long frame past both the timer and the end point | The timer wins whenever it is at or below the end point; it is checked first and settles at exactly its setting. |
| Back during a run | Stake-at-risk confirmation. Confirming forfeits the stake and records the end point. |
| F1 during a run | Refused with "The guide opens between runs"; a live bake is never paused. |
| Reduced motion toggled mid-bake | Effects stop at once; the needle snaps to the value and the run runs on. |
| Autoplay | Not implemented. Standing orders cover the same ground without hiding the decision. |
