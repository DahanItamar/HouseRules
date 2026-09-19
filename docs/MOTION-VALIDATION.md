# Motion validation

House Rules captures temporal presentation evidence from the running Godot build,
not from mocked UI states. The deterministic capture journey uses seed
`20260918`, a 1920x1080 output, and the real menu, cashier transaction,
blackjack deal/reveal, and vault reveal paths.

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
The capture runner accepts `--reduced-motion` and resets its test override before
exit so the preference cannot leak into another run.

These screenshots establish deterministic temporal differences and stable
reduced-motion behavior. They do not replace the physical controller, handheld,
or 4K display pass.
