# Cabinet: <Display Name>

> `id: &"<snake_case_id>"` · Tier: <MAIN_FLOOR | HIGH_ROLLER | VIP> · Status: <Specified | Built | Catalog only>

Copy this file to add a machine. Every heading is required. A heading you cannot fill is a design hole, not a formatting problem — find it now, because §8 of `docs/SPEC.md` exists to catch exactly these.

---

## 1. Fantasy

<The three seconds a player spends walking up to it. What does the cabinet promise? One or two sentences, written as the player would feel it, not as the system works.>

**Arcade ancestor:** <what 80s/90s game it borrows its verbs from, or "none — classic casino">

## 2. Core loop

<One sentence: bet → act → resolve.>

## 3. Agency class

<PURE_CHANCE | CHANCE_PLUS_DECISION | CHANCE_PLUS_SKILL>

<One line on what the player actually controls, and therefore whether RTP is fixed or scales with play quality. This determines whether the RTP harness needs a scripted strategy (§7 Flow D of the spec) and which one.>

## 4. Rules

<Complete. A reader implements from this section alone.>

## 5. State machine

```
<States and transitions. Name the state that accepts input; AC-044 requires every other
state to ignore it. Name every terminal state and which RoundResult.Outcome it produces.>
```

| State | Accepts input | Exit leads to |
| --- | --- | --- |
| | | |

## 6. Math

<The actual model. Probabilities, weights, distributions — real numbers, not "tuned later".
This is the section the headless harness verifies against.>

**Declared `target_rtp`:** <0.xx>
**Computed RTP:** <show the arithmetic, or state the reference and that M3 measures it>
**Hit frequency:** <p(any win) per round>
**Volatility:** <LOW | MEDIUM | HIGH>
**Max win:** <multiple of stake — and the cap, because an uncapped multiplier is an overflow (§8)>

### Paytable

| Outcome | Probability | Pays | Contribution to RTP |
| --- | --- | --- | --- |
| | | | |

## 7. Bet limits

| Tier | Min | Max |
| --- | --- | --- |

## 8. Controller map

| Input | Action | Available in state |
| --- | --- | --- |
| A / Cross | | |
| B / Circle | | |
| D-pad | | |

<Every interaction must be reachable on a gamepad — AC-037. If a row here says "mouse", the design is not finished.>

## 9. Screen layout (960×540)

```
<ASCII wireframe at the locked base resolution. Mark the chip balance, the current stake,
and any multiplier — these carry the 16px minimum under AC-042. Body text is 8px minimum.>
```

## 10. Audio cues

| Moment | Cue |
| --- | --- |
| Bet placed | |
| Anticipation | |
| Near-miss | |
| Win | |
| Loss | |

## 11. Assets required

<Feeds docs/art/ASSET-SPECS.md. Exact dimensions in base-viewport pixels and frame counts.
Mark each as GENERATE (static, suits image generation) or HAND-PIXEL (animated or small,
where generation fails — see Assumption 6 in the spec).>

| Asset | Dimensions | Frames | Method | Notes |
| --- | --- | --- | --- | --- |

## 12. Juice & tells

<Near-miss framing, anticipation timing, how celebration scales with win size. This is the
difference between a correct machine and one worth sitting at.>

## 13. Edge cases

| Case | Handling | AC |
| --- | --- | --- |
| Exit mid-round | `abandon()` → ABANDONED, stake forfeit | AC-009 |
| Input during a non-accepting state | Ignored | AC-044 |
| | | |

## 14. Open questions

<Each tagged with what it blocks. None may block M1 or M2 for a scheduled cabinet.>
