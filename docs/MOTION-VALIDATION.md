# Motion validation

House Rules captures temporal presentation evidence from the running Godot build,
not from mocked UI states. The deterministic capture journey uses seed
`20260918`, a 1920x1080 output, and the real menu, floor practical-light loop,
cashier transaction, help reveal/dismiss, live-wager exit cancel/confirm,
blackjack deal/live-hand reflow/reveal, and vault safe/hazard reveal paths.

The curated full-motion frames live in
`tests/results/screenshots/motion_full/`. Every before/mid pair has a distinct
SHA-256 digest, proving visible state changes across time. The reduced-motion
menu pair lives in `tests/results/screenshots/motion_reduced/`; both frames are
byte-identical with SHA-256
`232DFB0A7939FAC5D5830995A0DBC5CA403CC0E3BC2F578C1B65C6B112CDE1B6`,
proving the accessibility path reaches and holds its stable final composition.

`tests/results/screenshots/motion_manifest.json` records the selected frame pairs.
`tests/test_motion_evidence.gd` decodes every referenced frame, verifies exact FHD
dimensions, requires each full-motion pair to change, and checks the reduced menu
pair against its recorded byte-stable SHA-256 digest.
It also checks the blackjack dealer lane independently, so card movement elsewhere
on the table cannot masquerade as evidence of the dealer's deal and reveal gestures.
The player-table ROI separately proves that a Hit refans the existing hand while
the new card travels in; this deterministic presentation fixture is restored to
the authoritative hand before the capture journey performs its real Stand action.
The exit-confirm pair ends on the floor, proving the destructive choice traverses
the real cabinet-session route rather than only animating a detached dialog.
The capture runner accepts `--reduced-motion` and resets its test override before
exit so the preference cannot leak into another run.

These screenshots establish deterministic temporal differences and stable
reduced-motion behavior. They do not replace the physical controller, handheld,
or 4K display pass.
