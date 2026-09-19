# Live motion benchmark

House Rules uses current public Stake Originals pages as a pacing and hierarchy
reference, not as a visual asset source. The playable canvases are account or
region gated in the QA environment, and Stake does not publish animation timing.
The timing budgets below are therefore House Rules targets inferred from the
officially documented interaction loops.

## Transferable patterns

- One dominant action at a time. Persistent wallet and stake controls stay
  stable while the reels, cards, or grid carry the live round.
- A meaningful state change follows input immediately. A safe Mines reveal
  raises the multiplier and presents the continue-or-cash-out decision; a mine
  ends the round. Blackjack exposes only legal hand actions.
- Presentation never changes the resolved outcome or delays settlement.
- Longer anticipation belongs only to a genuine outcome state. House Rules does
  not fabricate slot near misses.
- Celebration is proportional and interruptible. Ordinary results use one
  readable beat; only a high-multiple result earns the longer treatment.
- Reduced motion is a complete, stable presentation path rather than a disabled
  or partially animated version of the game.

## Interaction budgets

| Event | House Rules target |
| --- | ---: |
| Button acknowledgement | 0–100 ms |
| Focus or enable transition | 120–220 ms |
| Safe Vault reveal | 180–260 ms |
| Mine/bust reveal | 320–500 ms |
| Blackjack card travel | 220–300 ms |
| Blackjack card stagger | 70–110 ms |
| Normal slot round | 1.4–1.7 s |
| Genuine slot anticipation round | 1.9–2.2 s |
| Result readability beat | 220–350 ms |
| Ordinary win emphasis | at most 500 ms |
| Big-win emphasis | at most 1.2 s and interruptible |

## Primary references

- [Stake Originals Mines](https://stake.com/casino/games/mines?game=mines):
  5×5 reveal loop, player-selected risk, multiplier progression, and cash-out.
- [Stake Originals Blackjack](https://stake.com/casino/games/blackjack): clean
  legal-action flow and explicitly described fast animation.
- [Stake Originals collection](https://stake.com/casino/group/stake-originals?sort=asc):
  shared manual-play hierarchy and variable-volatility patterns.
- [Stake casino home](https://stake.com/casino/home): dark restrained surfaces
  with selective color emphasis across Originals.

The references support the behavioral hierarchy. They do not prove proprietary
frame timings; the table above is the acceptance contract for this project.
