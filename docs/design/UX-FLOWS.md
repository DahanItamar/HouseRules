# UX Flows & Transition State Machine

> Companion to `docs/SPEC.md` §7. The spec states what happens; this states what the player *sees and feels* while it happens.
> Answers the first open question from the original concept doc: the exact visual and interaction flow from floor to machine.

---

## 1. The signature moment

The floor-to-cabinet transition happens more often than anything else in the game — several hundred times across a campaign. It is the closest thing House Rules has to a signature, and it is also the easiest thing to get wrong, because a transition that is 200ms too slow becomes unbearable by the fiftieth repetition and one that is too fast makes the casino feel like a menu.

**The rule: the floor never unloads behind a cabinet.** The cabinet rises over a dimmed, still-running floor. (Moving between *rooms* is the one case that does unload — see §5b, where the cost is paid deliberately to make a room change feel different from sitting down.) Ambient crowd noise stays audible under the machine's audio bed. The player is always in the casino, never in a screen about the casino. This costs memory and buys the entire atmosphere.

---

## 2. Approach → seated

Five phases, 520ms total. Every duration below is a starting value for M4 tuning, not a law.

| Phase | Duration | Visual | Audio | Input |
| --- | --- | --- | --- | --- |
| **Idle** | — | Cabinet runs its attract loop | Floor ambience only | Movement |
| **Proximity** | 120ms | Cabinet outline brightens; prompt fades up above it | Soft proximity chime, once | Movement, interact |
| **Commit** | 200ms | Camera pushes toward the cabinet; floor desaturates to 40% | Ambience ducks 6dB | **None** — locked |
| **Rise** | 200ms | Cabinet UI slides up from the lower edge, overshooting 8px and settling | Machine bed crossfades in | None |
| **Seated** | — | Cabinet owns the screen; floor visible and dimmed at the edges | Machine bed over ducked ambience | Full cabinet controls |

Exiting reverses the same timings at 0.8× — leaving should feel slightly faster than arriving.

### The prompt

Appears above the cabinet, never in a corner. It carries the cabinet name, the bet range, and the glyph for the interact action, all of which swap on device change (AC-038).

```
        ┌─────────────────────────┐
        │  CLASSIC 3-REEL         │  ← 16px
        │  1 – 50 chips           │  ← 8px
        │  (A) PLAY               │  ← glyph swaps
        └─────────────────────────┘
                   ▼
              [ cabinet ]
```

### The unavailable state (AC-004)

When the balance is below the cabinet's minimum bet, the prompt still appears — desaturated, with the reason stated. A cabinet that goes silent when you can't afford it teaches the player nothing; one that says why teaches them what to go do.

```
        ┌─────────────────────────┐
        │  BLACKJACK 21           │
        │  NEEDS 5 CHIPS          │  ← #FF8A3D, not red — this is
        │                         │     information, not an error
        └─────────────────────────┘
```

Interact is refused with a soft negative tone and no camera movement.

---

## 3. Persistent HUD

Two elements never disappear, on the floor and inside every cabinet:

| Element | Position | Size | Rule |
| --- | --- | --- | --- |
| Chip balance | Top-left | 16px, gold `#FFD23F` | Rolls rather than snaps on change; roll duration scales with magnitude, capped at 800ms |
| Debt | Top-right | 16px, `#FF8A3D` | Hidden at zero debt. Appears on the first marker; hides again only when fully repaid. |
| Cashier waypoint | Screen edge, pointing | 16px, `#FF8A3D` | Only while below the solvency floor (AC-049) |

The debt counter appearing for the first time — after the first marker — is a narrative beat. It should arrive with no fanfare at all. A number that simply shows up and stays is more unsettling than one that announces itself.

Its *disappearing* is the other beat. A player who repays down to zero watches the counter vanish, and that should also be silent. No fanfare for clearing a debt you chose to take on.

---

## 4. Round resolution

The tally is the payoff, and it is the same shape in every cabinet so the player learns it once.

1. **Outcome reveal** — the machine shows what happened (reels stop, dealer's hand resolves, tiles reveal)
2. **Beat** — 300ms of nothing. Losing needs room; winning needs anticipation.
3. **Tally** — the payout counts up into the chip balance, the counter rolling in step with a coin tick
4. **Return** — the cabinet resets to its betting state

Celebration scales in three bands, consistently across every machine:

| Win size | Response |
| --- | --- |
| < 20× stake | Coin tick, counter roll |
| 20–100× | Coin cascade, brief screen-edge glow |
| > 100× | Full bed, screen flash, extended tally |

A loss gets silence. No sad trombone, no consolation animation — the absence of sound after a resolution is the clearest loss signal available and it never gets tiring.

---

## 5. Interruptions

| Event | Behavior |
| --- | --- |
| Pause pressed mid-round | Round state frozen, overlay dims the cabinet. Resume returns to the exact state. The round is **not** abandoned. |
| Exit requested mid-round | Confirmation prompt naming the stake at risk: *"Leave now and forfeit 25 chips?"* On confirm → `abandon()` → `ABANDONED` (AC-009) |
| Gamepad disconnected | Auto-pause, overlay showing the reconnect prompt. Resumes on reconnect. Never resolves a round on the player's behalf. |
| Balance hits the solvency floor | **No pop-up.** The tally completes, then the cashier waypoint fades in at the screen edge. The player is never interrupted and never offered anything. |

That last row is the important one. The game does not offer credit — it only stops hiding where credit is. The player has to stand up, cross the floor and ask, which is the authentic version of that moment and a far more uncomfortable thing to do than clicking "Accept" on a dialog.

---

## 5a. The Cashier

A cage on the main floor, always reachable (AC-048). Two actions, and the menu shows only the ones that currently apply.

```
┌──────────────────────────────────────┐
│           THE CASHIER                │ ← 16px
│                                      │
│   CHIPS  14              DEBT  300   │ ← 16px, gold / orange
│                                      │
│   ▸ TAKE A MARKER          +100      │  only below the solvency floor
│     REPAY DEBT                       │  only when debt > 0
│     LEAVE                            │
└──────────────────────────────────────┘
```

**Taking a marker.** One confirmation naming both numbers — *"Take 100 chips. You will owe 400."* — then chips and debt rise together and the save is written immediately. The teller has no dialogue and no reaction. The House does not gloat about this; it is simply business, which is worse.

**Repaying.** A slider from 1 to `min(balance, debt)`, D-pad to adjust, shoulder buttons for ×10 steps, with a "pay all" shortcut. Both numbers move live as the slider does, so the player sees the trade before committing.

Repaying into insolvency is permitted (`ECONOMY.md` §5). The confirmation says plainly what will happen — *"This leaves you with 4 chips."* — and then lets the player do it. It is their decision, and the waypoint will be waiting for them.

---

## 5b. Wing transitions

The staircase and the elevator are the only two ways off the main floor. Both are locked in v1 and both show why.

```
        ┌─────────────────────────┐
        │  HIGH-ROLLER LOUNGE     │  ← 16px
        │  LOCKED                 │  ← #FF8A3D
        │  WAGER 5,000 TO ENTER   │  ← 8px
        │  3,240 / 5,000          │  ← progress, gold
        └─────────────────────────┘
```

Gating is on **lifetime wagered**, not current balance (`ECONOMY.md` §3) — so the bar only ever fills, and a losing streak never takes back access the player already earned.

An unlocked transition is a full room change, not the 520ms cabinet rise: fade to black over 300ms, load, fade up over 300ms, avatar at the new room's entrance (AC-050). Slower than a cabinet on purpose. Changing rooms should feel like going somewhere; sitting at a machine should not.

The locked state is doing real work in v1. A player walks past that staircase for two hours, watching a number climb toward a room they cannot enter yet. It advertises that the building is bigger than the room they are standing in — which is the only way a single-floor v1 can imply the full game.

---

## 6. Screen states every surface must define

From `uilint` discipline: each of these is a real state a player will see, and each is a place games ship broken.

| State | Floor | Cabinet |
| --- | --- | --- |
| **Empty** | First launch — the floor with three cabinets and 200 chips. An intro line naming the goal. | No round in progress: betting UI, paytable visible, last result still shown |
| **Loading** | None — the floor is the first thing loaded | Cabinet rise is the loading state; it is never longer than the 200ms animation |
| **Error** | Save failure: a non-blocking toast naming the problem. Play continues; the run is not lost to a disk hiccup. | Wallet rejection: the cabinet returns to betting with the stake clamped, and says why |
| **Partial** | A locked tier wing: visible, dimmed, with its unlock threshold shown | Cabinet at max win cap: pays the cap, states it plainly rather than showing a wrong number |
| **Success** | Tier threshold crossed — a one-time beat, then the new wing unlocks | Round resolved, tally complete, ready for the next bet |

---

## 7. Open questions

- **Where exactly does the Cashier sit on the main floor?** — blocks: nothing architectural · needed by: M3. It must be visible from the cabinet cluster so the waypoint rarely has far to point, but not so central that the player walks through it constantly. A layout question, not a design one.

**Resolved:** *one room or several* → a main floor holding the Cashier and the three cabinets, with a staircase and an elevator to separate upper-tier rooms (§5b, AC-050, AC-051).
- **Does the attract loop differ per cabinet?** — blocks: nothing. One shared blink is enough for v1; per-cabinet attract animations are pure polish and are listed in each cabinet doc's §11 as 2-frame floor sprites.
