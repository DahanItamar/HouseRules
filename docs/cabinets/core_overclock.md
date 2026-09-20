# Cabinet: Forno d'Oro (crash)

> `id: &"core_overclock"` · Tier: High Roller · Status: Playable (floor placement pending)

---

## 1. Fantasy

An Italian pizzeria at the end of service. A pizzaiola works the peel beside a
wood-fired oven; a brass oven gauge on the wall reads how far the bake has come.
Send a pizza in and the gauge climbs. Pull it out at the right moment and it is
served for stake times the gauge. Leave it a second too long and it burns, the
screen flashes white-hot, smoke rolls out of the mouth and the stake is gone.

The cabinet id stays `core_overclock`: the mechanic is a crash game, and the
domain math is theme-free. Only the presentation is a bakery.

## 2. Core loop

Choose a stake (100, 200, 500 or 1000), optionally set the oven timer, then
BAKE. The gauge climbs on an exponential curve. PULL IT OUT banks
`stake × multiplier`; if the bake reaches its decided burn point first, nothing
is paid. One pizza settles one stake.

## 3. Agency class

`TIMED_CHANCE`. The burn point is decided before the dough is on the stone; the
only decision is when to pull the pizza out. Every choice returns the same
97.00%, so no timer setting is better or worse than any other — only the shape
of the variance changes.

## 4. Rules

1. BAKE draws one uniform integer `u` in `[1, N]` with `N = 1_000_000_000` from
   the cabinet's named RNG stream. That single draw is the whole outcome.
2. The burn point, in hundredths of a multiplier ("centi"), is
   `crash = floor(100 × p × N / u)` with `p = 97/100`, capped at 1000000
   (10000.00×).
3. The oven heats for `countdown_seconds` (1.6 s); no pizza can be pulled out
   during that. Then the gauge climbs `multiplier(t) = 100 × e^(0.40 t)` centi.
4. PULL IT OUT pays `stake × multiplier / 100` whole chips at the multiplier the
   dial shows. The stake unit is 100 and multipliers are hundredths, so the
   division is exact and no payout ever rounds.
5. If the climb reaches the burn point first, the pizza burns and pays nothing.
6. A burn point below 1.00× (3% of bakes) burns on the frame the window would
   have opened, so the pizza is gone before any input can reach it.
7. The oven timer, if set, pulls the pizza out at exactly that multiplier
   whenever the burn point is at or above it.

## 5. State machine

```
IDLE (dough ready) ──bake──▶ COUNTDOWN (oven heating) ──▶ OVERCLOCKING (baking)
        ▲                                                   │         │
        └────────────────── SERVED (cashed out) ◀────pull────┘         │
        └────────────────── BURNT (crashed) ◀───────burn point─────────┘
```

| State | Presentation | Accepts input | Notes |
| --- | --- | --- | --- |
| `IDLE` | DOUGH READY | Stake, timer, Bake, Help, Back | The last bake stays on the gauge and the board until the next one starts. |
| `COUNTDOWN` | OVEN HEATING | Back only (confirmation) | The stake is committed; the burn point already exists. |
| `OVERCLOCKING` | BAKING | Pull it out, Back (confirmation) | The wallet is untouched; the deck shows the live stake as IN PLAY. |
| `CASHED_OUT` | SERVED | Same as `IDLE` | Settled once, at the multiplier on the dial. |
| `CRASHED` | BURNT | Same as `IDLE` | Settled once, paying nothing. |

Confirming Back during a live bake forfeits the stake: `CoreOverclockMath.abandon()`
records the burn point and returns an `ABANDONED` result of 0, so leaving can
never be cheaper than losing. The guide (F1) opens between bakes only, so it can
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

**Million-round measurement** (seed 20260918, 100 a bake, oven timer cycling
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
| X | Step the oven timer: off, 1.20×, 1.50×, 2.00×, 3.00×, 5.00×, 10.00× |
| Y | Same as A (the one key that matters is always reachable) |
| LB / RB, Q / E, scroll | Change the stake |
| RT / R | Table maximum |
| D-pad / left stick / WASD | Walk the timer, How to play and the primary key |
| Start / F1 | How to play (between bakes only) |
| B / Esc | Leave. During a bake a stake-at-risk confirmation asks first; confirming forfeits the stake. |

The primary key has focus when the cabinet opens and again after every bake.
Cyan appears only on keyboard/controller focus.

## 9. Screen layout (960×540)

The screen is laid out on the centre line, with the left and right columns the
same width and the same margin.

| Region | Rect | Contents |
| --- | --- | --- |
| Oven timer | 48,27 176×44 | Mirrors How to play at the other end of the header |
| Title plate | 330,27 300×70 | FORNO D'ORO and the live status line |
| How to play | 736,27 176×44 | Shared header control |
| Bake curve | 48,88 252×212 | Multiplier against time, on a terracotta plate |
| Recent bakes | 48,310 252×100 | The last six burn points, 3 × 2 muted chips |
| Oven gauge | centre 480,232 · 268×268 | The only live multiplier: dial, sweep, needle, value |
| Pizza | centre 480,390 · 60 px | The bake itself, browning as the gauge climbs |
| Host lane | 660,88 252×322 | The pizzaiola at the oven, clipped at the deck |
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

- The burn point is decided in `CoreOverclockMath.begin()` before anything
  moves. `advance(delta)` replays it and returns the settled result on the step
  that ends the bake; the cabinet settles the wallet once, there.
- **Alive:** the curve draws itself with a bright pulsing head and a faint
  trail; the gauge needle rides a spring, so it sweeps with a little overshoot,
  and the dial warms in colour as the bake goes on; the pizza on the counter
  browns through the bake; live flame tongues grow in the oven mouth with heat
  shimmer above them; embers lift out of the mouth and flour hangs in the lamp
  light; the whole plate drifts on a slow parallax; the multiplier pops and
  ticks at each whole multiple; the screen shake and the fire's rumble grow with
  the heat.
- **The burn:** the needle is kicked past its stop and settles, the screen
  flashes white-hot, smoke rolls out of the mouth and over the pizza, embers
  scatter, and the stage settles from one decaying impact.
- **The serve:** the pizza is shown baked to the multiplier it reached, embers
  and flour burst, and the win flash plays in brass.
- **Reduced motion:** no shake, no flashes, no embers, no smoke, no flour, no
  parallax, static flames, the needle tracks the value exactly, and the number
  changes without a pop. The bake itself still runs, because the timing is
  gameplay rather than decoration; a player who does not want to react can set
  the oven timer, which is exact.
- `tools/capture_core_overclock.gd` writes `core_overclock_motion_proof.json`,
  which records the decided burn point, the uniform it came from and the settled
  multiplier against what the dial read.

## 12. Assets

| Asset | Path | Notes |
| --- | --- | --- |
| Kitchen backdrop | `assets/production/forno/forno_backdrop.png` | 3840×2160, no people, no text |
| Oven gauge | `assets/production/forno/forno_oven_gauge.png` | 1024 px, blank cream dial drawn on in code |
| Pizza / burnt pizza | `assets/production/forno/forno_pizza.png`, `forno_burnt_pizza.png` | 768 px, transparent |
| Terracotta frame | `assets/production/forno/forno_frame.png` | 1024 px nine-slice, 140 px margin |
| Ingredient icons | `assets/production/forno/forno_icons.png` | 3×2 cells of 256 |
| Embers, flour, smoke | `assets/production/forno/forno_embers.png` | 4×4 cells of 256 |
| Pizzaiola | `assets/production/characters/hosts/forno_hostess.png` | 1392×2080 transparent master (placeholder pending her final art) |

Every reference lives in `src/ui/core_overclock/core_overclock_theme.gd`, so the
skin is one file. Rebuild with `python tools/art/prepare_forno.py`; provenance
is in `docs/art/GENERATION-REPORT.md` under "Forno d'Oro".

## 13. Edge cases and scope

| Case | Handling |
| --- | --- |
| Balance below 100 | No stake key is enabled and BAKE is disabled. The deck points to the cashier. |
| Stake above the balance | That key is disabled; after a loss the selection drops to the largest affordable key. |
| Bake without a coverable stake | Refused with "No stake your credits can cover". |
| Pull during the countdown | Refused: there is no window until the oven is hot. |
| Burn point below 1.00× | Burns on the frame the window opens; nothing can be pulled out. |
| Oven timer above the burn point | The pizza burns as it would have anyway. |
| Oven timer exactly at the burn point | Served: reaching the setting pulls it out. |
| A long frame past both the timer and the burn point | The timer wins whenever it is at or below the burn point; it is checked first and settles at exactly its setting. |
| Back during a bake | Stake-at-risk confirmation. Confirming forfeits the stake and records the burn point. |
| F1 during a bake | Refused with "The guide opens between bakes"; a live bake is never paused. |
| Reduced motion toggled mid-bake | Effects stop at once; the needle snaps to the value and the bake runs on. |
| Autoplay | Not implemented. The oven timer covers the same ground without hiding the decision. |
