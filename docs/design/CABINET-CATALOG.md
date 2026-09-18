# Cabinet Catalog — designed, unscheduled

> The thirteen machines that are **not** in v1. Listed in `docs/SPEC.md` §2 as explicitly out of scope.
>
> These are content against the v1 framework, not new engineering. Each implements the same `MiniGame` contract (`SPEC.md` §6) and puts its math in `src/domain/`. **If any machine here cannot be built without changing that contract, that is a finding about the contract** — and it is worth checking against this list before M2 closes, because the cheapest time to discover a missing seam is before three cabinets depend on it.
>
> To promote one: copy `docs/cabinets/_TEMPLATE.md`, fill every heading, and raise a change proposal via `/spec-architect` (delta mode).

---

## Carried from the original concept

### European Roulette
`PURE_CHANCE` · Target RTP 97.30% (single zero, fixed by the wheel) · Volatility selectable by bet type

Full board, inside and outside bets, chip stacks placed on the felt. **The hardest UI in the whole design** — 37 numbered regions plus outside bets on a 960×540 screen, navigated with a stick. It is the reason the base resolution is 960×540 and not 640×360, and the reason the snap cursor is built early on Minefield's clean 5×5 grid (`docs/cabinets/minefield-vault.md` §8). Do not attempt this cabinet until the cursor has shipped somewhere easier.

### Video Poker
`CHANCE_PLUS_SKILL` · Target RTP 99.54% at optimal play (9/6 Jacks or Better) · Volatility MEDIUM

Five-card draw against a paytable. Optimal play is a solved problem, which makes it the natural "job" machine of the upper tiers — and the first cabinet where RTP genuinely scales with player knowledge rather than player nerve.

### Dungeon Quest Slot
`PURE_CHANCE` with a presentation layer · Target RTP ~96%

An RPG-themed slot where reel combinations attack a monster displayed above the reels. Defeating it triggers a loot bonus. Mechanically a slot with a state that persists across spins — **the first machine that needs round-to-round memory**, which is worth checking against the `MiniGame` contract early since v1's three machines are all stateless between rounds.

### Vault Heist Slot
`CHANCE_PLUS_SKILL` · Target RTP ~96%

Three Vault symbols start a timed lock-picking mini-game. A machine containing a second machine — it needs a nested `MiniGame`, or a state within a state. The contract supports this as written; confirm before building.

### Pachinko / Plinko
`PURE_CHANCE` · Target RTP ~96% · Volatility HIGH

Physics-driven token drop through pegs into multiplier basins. The only v1-adjacent cabinet whose outcome comes from a physics simulation rather than a distribution, which makes it the one machine where **determinism under AC-014 is genuinely hard** — Godot's physics is not deterministic across frame rates. Either fix the timestep and seed the drop, or compute the outcome from the distribution first and animate toward it. The second approach is almost certainly correct and should be decided before any physics code is written.

### Cyber-Race Terminal
`PURE_CHANCE` · Target RTP ~95% · Volatility MEDIUM

Betting terminal for simulated pixel-art races with dynamic odds. Win/place/show betting, a field of runners with published odds. Needs an odds model — the first machine where the *displayed* odds and the *actual* probabilities must be reconciled in the UI.

---

## New originals — arcade verbs × gambling odds

### Snake Eyes
Snake · `CHANCE_PLUS_SKILL` · RTP scales with skill · Volatility HIGH

Eat dice pips to grow; each pip compounds the multiplier. Cash out at any moment, or hit a wall and lose the stake. A push-your-luck curve where, unlike Minefield Vault, **skill genuinely shifts the odds** — a better player survives longer at the same multiplier. That makes it the mirror of the Vault and a good place to demonstrate the difference.

### Break the Bank
Breakout / Arkanoid · `CHANCE_PLUS_SKILL` · RTP 85% novice → ~110% mastery

Bricks are chip denominations, paddle lives cost chips, the vault behind the wall is the jackpot. One of the machines that can exceed 100% RTP for an expert, making it a genuine earner rather than a cost centre. Requires a skill-banded RTP model the harness can measure at multiple skill levels — a real extension to the M3 harness, not just a new cabinet.

### Card Invaders
Space Invaders · `CHANCE_PLUS_SKILL` · RTP ~92% novice → ~105% mastery

Descending cards; shoot to collect a five-card poker hand. Hand rank sets the payout, but holding out for a flush lets the invaders reach the bottom. The tension is an explicit trade between hand quality and time — the cleanest skill/greed axis in the catalog.

### Crosswalk
Frogger · `PURE_CHANCE` · RTP 97% · Volatility player-selected

Advance lane by lane, the multiplier rises per lane, one hit busts. Mathematically a re-skin of Minefield Vault with a different fantasy, which makes it cheap to build and a good test of whether `src/domain/` is genuinely reusable across cabinets.

### Jackpot Table
Pixel pinball · `CHANCE_PLUS_SKILL` · RTP ~94%

Bumpers are multipliers, ramps spell J-A-C-K-P-O-T, the drain ends the round. Carries the same physics-determinism problem as Plinko, and the same answer.

### The Grabber
Claw machine · `PURE_CHANCE`, honestly disclosed · RTP ~90%

A claw with a **visible grip-strength meter** — the cabinet openly displays its own house edge as a mechanic. Thematically the most interesting machine in the building: it is the one that tells the truth about what all the others are doing. Worth building late, when the player has enough context for that to land.

### Beat the Dealer
Rhythm / DDR · `CHANCE_PLUS_SKILL` · RTP scales steeply with accuracy

Note accuracy sets the payout multiplier; the dealer taunts on the off-beat. Needs audio-synchronized input, which is the one technical capability in this catalog that nothing in v1 establishes — budget it as engineering, not content.

---

## What this catalog tells you about the framework

Reading the thirteen together surfaces four capabilities v1 does not have, all of which are cheaper to plan for than to retrofit:

| Capability | First needed by | Note |
| --- | --- | --- |
| Round-to-round persistent state | Dungeon Quest Slot | v1's three machines are all stateless between rounds |
| Nested mini-games | Vault Heist Slot | A `MiniGame` hosting a `MiniGame` |
| Deterministic physics outcomes | Plinko, Jackpot Table | Resolve from the distribution, then animate toward it |
| Skill-banded RTP measurement | Break the Bank | The M3 harness measures one RTP per machine; these need a curve |

None of these require changing the v1 contract. All four are worth a five-minute check against it before M2 closes.
