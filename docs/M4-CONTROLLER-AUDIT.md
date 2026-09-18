# M4 Controller Audit

This matrix records the shipped controller path for every player interaction.
`tests/test_input.gd` protects every named action's D-pad, face-button and
left-stick bindings. The game never requires pointer input.

| Context | Interaction | Named action | Xbox control |
| --- | --- | --- | --- |
| Main menu | Start | `interact` | A |
| Main menu | Quit | `back` | B |
| Casino floor | Walk | `move_left/right/up/down` | Left stick or D-pad |
| Casino floor | Enter cabinet, use cashier, inspect wing | `interact` | A |
| Casino floor | Return to menu | `back` | B |
| All cabinets | Lower/raise stake | `move_left/right` | Left stick or D-pad |
| All cabinets | Start round / hit / reveal | `interact` | A |
| All cabinets | Leave before a round | `back` | B |
| Blackjack | Stand | `secondary` | X |
| Blackjack | Double down | `tertiary` | Y |
| Minefield Vault | Lower/raise mine count | `move_up/down` | Left stick or D-pad |
| Minefield Vault | Move grid cursor | `move_left/right/up/down` | Left stick or D-pad |
| Minefield Vault | Cash out | `secondary` | X |

The state guards in each cabinet ignore actions that are invalid in the current
state. Leaving during an active round uses the existing abandon path and never
requires a keyboard-only confirmation.

## Device checklist

Automated tests certify the binding graph. Before release, perform this short
hardware pass with the keyboard and mouse disconnected:

1. Start a new game and walk diagonally with both the left stick and D-pad.
2. Enter, play one round, and leave each of the three cabinets.
3. Use the cashier and inspect both locked wing transition points.
4. Return to the menu and quit with B.

Gamepad disconnect recovery is tracked as its own M4 task because it changes
pause behavior rather than the action coverage audited here.

## Handheld readability checklist

Automated UI tests enforce the base-viewport minimums: 8px for body text and
16px for chips, stake and multiplier. Before release, review the 960×540 build
at native size on the target 7-inch display and confirm that the vault cursor,
cabinet prompts and gold-on-dark chip totals remain distinct at arm's length.
