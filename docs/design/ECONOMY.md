# Economy

> Companion to `docs/SPEC.md` §2.1 (AC-024 … AC-027) and §7 Flow B.
> v1 scope is Main Floor only. The three-tier curve is designed here so the data model doesn't change when tiers 2 and 3 are built.

---

## 1. The contradiction this document exists to resolve

Every machine in a casino returns less than it takes. That is what a casino is. The three v1 machines are no exception:

| Machine | RTP | House edge | Bleed per round at a 10-chip stake |
| --- | --- | --- | --- |
| Classic 3-Reel | 95.40% | 4.60% | −0.46 chips |
| Minefield Vault | 97.00% | 3.00% | −0.30 chips |
| Blackjack | ~99.00% | ~1.00% | −0.10 chips |

A player who only pulls levers trends monotonically toward zero. But the campaign asks them to climb from 200 chips to 5,000 on the Main Floor, and eventually to a million. **Variance cannot carry that.** Over enough rounds the house edge is not a risk, it is a certainty.

This is the central design problem, and it is resolved by construction rather than by hoping the player gets lucky:

**Machines are where chips are spent. Contracts are where chips are earned.**

That inversion is the whole economy. The machines provide the texture, the tension and the fantasy; they are a cost centre by design. Progress comes from objectives that pay flat, variance-free rewards. A player who never wins a jackpot still finishes the game.

### The consequence for the player's mental model

This is worth stating plainly because it shapes everything downstream: the player is not trying to beat the house. They are trying to **survive the house long enough to complete contracts.** The machines are the obstacle course, not the income. Once that clicks, a losing streak reads as attrition rather than failure, which is exactly the feeling a casino game should produce and almost never does.

---

## 2. The tuning dial

There is exactly one number that sets campaign length:

```
net chips per hour = (contracts per hour × average reward) − (rounds per hour × average bleed)
```

Machine bleed is fixed by the RTPs above and measured by the M3 harness (AC-027). Contract income is free to set. So **contract reward size is the single dial** that controls pacing, and tuning it requires no change to any machine.

### Measured inputs

| Input | Estimate | Source |
| --- | --- | --- |
| Slot spins per minute | ~4 | 2.2s spin + stagger + decision |
| Blackjack hands per minute | ~3 | deal, decide, dealer draw, tally |
| Minefield rounds per minute | ~2 | variable; scales with reveals |
| Average stake, Main Floor | ~12 chips | mid-range of the three cabinets |
| **Machine bleed** | **≈ 60–110 chips/hour** | derived from the table in §1 |

At those rates the machines are remarkably gentle — an hour of continuous play at Main Floor stakes costs about 100 chips. That is deliberate. A punishing bleed would make the marker fire constantly and turn the debt mechanic from a story beat into an annoyance.

### Setting the dial

| Target | Contracts/hr | Avg reward | Net/hr | Hours to clear Main Floor |
| --- | --- | --- | --- | --- |
| Brisk (v1 demo) | 4 | 600 | ≈ +2,300 | ~2.1 |
| Standard | 4 | 400 | ≈ +1,500 | ~3.2 |
| Grindy | 3 | 300 | ≈ +800 | ~6.0 |

**v1 ships "Brisk."** The Main Floor is the only tier that exists, so it has to demonstrate the full arc — broke, marker, recovery, tier threshold — inside a session someone will actually finish. The Standard column is the intended setting once three tiers exist.

---

## 3. Chip curve

| Tier | Reached by | Bet range | Entry | Target exit | Designed hours |
| --- | --- | --- | --- | --- | --- |
| **Main Floor** | Start. Holds the Cashier. | 1 – 100 | 200 | 5,000 | 2 (v1) / 3 (full) |
| High-Roller | Staircase | 50 – 2,500 | 5,000 | 100,000 | 5 |
| VIP Penthouse | Elevator | 1,000 – 50,000 | 100,000 | 1,000,000 | 8 |

Each tier is a **separate room**, reached through a transition point on the main floor rather than by unlocking a roped-off corner of one space. That is how real casinos are laid out — the stakes rise as you go up, and the people downstairs cannot see what happens upstairs.

In v1 both transition points exist and are locked, each showing its lifetime-wagered threshold (AC-051). A locked staircase the player walks past for two hours is doing real work: it advertises that the building is bigger than the room they are standing in.

**The Cashier stays on the main floor, always.** Not one per wing. A player upstairs who goes broke walks back down to ask for credit, which is both the authentic behavior and the version that keeps the reachability guarantee (AC-048) trivial to verify.

Tier thresholds are stored on `CabinetDefinition.unlock_chips` and gate against `SaveGame.lifetime_wagered`, **not** the current balance. This matters: gating on current balance would mean a player who unlocks High-Roller and then loses chips gets locked out again, which is both punitive and a save-scumming incentive. Lifetime wagered only goes up.

### Per-cabinet bet limits, Main Floor

| Cabinet | Min | Max | Why |
| --- | --- | --- | --- |
| Classic 3-Reel | 1 | 50 | Lowest entry — the first machine a new player touches |
| Blackjack | 5 | 100 | Best RTP on the floor, so it costs more to sit down |
| Minefield Vault | 1 | 25 | Longest multiplier tail; the cap keeps the payout bounded |

---

## 4. Contracts

Flat, variance-free rewards for observable objectives. Granted independently of machine outcomes (AC-024) — a contract that completes on a losing round still pays.

Three are active at any time. Completing one rolls a replacement from the pool.

| Contract | Reward | Cabinet | Notes |
| --- | --- | --- | --- |
| Pull the arm 25 times | 300 | Slot | Pure participation; always completable |
| Land three of a kind | 500 | Slot | p ≈ 3.9% per spin — expect ~25 spins |
| Land three DIAMOND | 2,000 | Slot | p ≈ 1/4096. A lottery ticket, not a plan |
| Win 5 hands | 400 | Blackjack | |
| Be dealt a natural 21 | 700 | Blackjack | p ≈ 1/21 per hand |
| Win a doubled hand | 600 | Blackjack | |
| Clear 8 tiles in one round | 600 | Minefield | At 3 mines, p ≈ 29% |
| Cash out above 10× | 900 | Minefield | |
| Survive a round at 10+ mines | 800 | Minefield | |
| Play all three cabinets | 400 | Any | Nudges the player around the floor |

**Design rule:** every pool must contain at least one contract completable by participation alone. A player on a catastrophic losing streak must still have a path to income that does not require winning. "Pull the arm 25 times" is that path, and something like it must exist in every tier.

---

## 5. The marker — anti-ruin as story

**The guarantee (AC-026): the player can never reach a state where they cannot place a bet.** Not "unlikely to". Cannot. A softlock in a game about gambling would be the single worst failure this design is capable of.

The player starts clean: **200 chips, zero debt.** Debt is not a starting condition the player inherits — it is something they choose, and that distinction is the whole point of the mechanic.

When the balance falls below the **solvency floor**, a marker becomes available **at the Cashier**. It is an emergency loan the player walks over and asks for, not an offer that appears:

```
chips += MARKER_STIPEND        (100)
debt  += MARKER_STIPEND
```

Saved immediately. There is no limit on markers and no penalty beyond the debt itself.

| Constant | Value | Notes |
| --- | --- | --- |
| `STARTING_CHIPS` | 200 | Starting debt is zero |
| `SOLVENCY_FLOOR` | 20 chips | Below this the marker unlocks at the Cashier |
| `MARKER_STIPEND` | 100 chips | Enough for several rounds at any Main Floor cabinet |

### Why the Cashier, and not a pop-up

An offer that appears the instant you go broke is the house pouncing on you. Making the player stand up, cross the floor and ask the cage for credit is the authentic version of that moment — and the uncomfortable one, which is the one this game wants.

The anti-softlock guarantee survives the move intact, but its mechanism changes and both halves matter:

1. **The Cashier is always reachable** from the main floor, in every game state (AC-048).
2. **While below the solvency floor, a persistent waypoint points at it** (AC-049).

Without the second, the guarantee would depend on the player knowing where to go, which is not a guarantee. The *mechanism* is never hidden; only the asking is.

### Why a floor of 20 rather than the lowest minimum bet

The slot's minimum bet is 1 chip. Taken literally, a player is only "unable to bet" at zero — which would mean grinding 1-chip spins for as long as their luck held before the game acknowledged anything was wrong. That is technically solvent and practically miserable.

The floor is therefore a configured value above the lowest minimum bet, set so the marker fires while the player still has enough to act with dignity.

AC-025 was amended to say "below the configured solvency floor" for exactly this reason.

### Debt as the narrative engine

Debt is not a punishment and does not gate anything. It is a number that only goes up, displayed permanently in the HUD, owed to the entity the player is ultimately trying to beat.

That is the point. Going broke does not end a session — **it advances the plot.** Every marker deepens the reason to walk into the Penthouse at the end. A player who has taken twelve markers arrives at the final table owing 1,200 chips to the person sitting across from it, and that is a better story than any scripted setup could produce.

### Repayment

Debt does not strictly accumulate. The player repays at the Cashier, in any amount up to `min(balance, debt)` (AC-046). Chips and debt fall together in one transaction (AC-047), and debt is clamped at zero (AC-053).

Three rules, each load-bearing:

1. **Repayment is player-initiated only.** Nothing deducts debt automatically. An automatic skim off winnings would silently eat contract income and break the pacing model in §2 — the player would be working against a dial they cannot see.
2. **Any amount, any time.** No minimum payment, no schedule, no interest. The pressure comes from the number being visible, not from a mechanic punishing you.
3. **Repaying into insolvency is allowed.** A player may hand over everything and drop below the solvency floor again. That is a bad decision the game permits, because the guarantee still holds — the waypoint reappears and the Cashier still has credit.

The interesting consequence: a player can now arrive at the endgame **debt-free**, having paid The House back in full. That is a different final scene than arriving owing 1,200 chips, and both are earned. The debt counter stops being a one-way ratchet and becomes a statement about how the player chose to play.

---

## 6. Verification

The economy is verified mechanically, not by feel. Three checks, all in CI:

1. **RTP conformance (AC-027).** The harness runs one million rounds per cabinet against the shipped domain math and asserts measured RTP is within one percentage point of `target_rtp`. Blackjack runs the basic-strategy script from `docs/cabinets/blackjack.md` §6; Minefield runs a fixed cash-out rule.
2. **Minefield edge invariance.** Measured RTP must be 97% at *every* scripted cash-out depth from 1 to 22. If it varies with strategy, the multiplier derivation is wrong. This is a stronger assertion than check 1 and is specific to this machine's construction.
3. **Solvency (AC-026).** A simulated player betting maximum on the worst-RTP cabinet, losing every round, for 10,000 rounds, must never reach a state with no legal bet available — taking a marker whenever one is offered. This is the anti-softlock proof and it is the most important test in the repository.
4. **Repayment invariants (AC-046, AC-047, AC-053).** Across a fuzz run of random repay amounts against random balances and debts: `debt` never goes negative, `chips` never goes negative, and `chips + debt` falls by exactly the repaid amount every time. Three assertions, and they catch every clamping bug this mechanic can have.

---

## 7. Open questions

- **Should contract rewards scale with tier?** — blocks: High-Roller design · needed by: post-v1. A flat 600-chip contract is transformative on the Main Floor and irrelevant at VIP stakes, so rewards almost certainly need to scale with the tier's bet range. Not a v1 problem, but the contract data model should carry a tier field from the start to avoid a migration.
