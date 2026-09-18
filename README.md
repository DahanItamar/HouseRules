# House Rules

Offline Godot casino prototype: a walkable floor, three cabinets on one session
contract, integer chip wallet, cashier recovery, and versioned local saves.

**Engine:** Godot **4.7.2 standard**, GDScript (installed Windows engine reports
`4.7.2.stable.official.ed1daf0bf`). No .NET or runtime networking.

## Run

Open `project.godot` with Godot 4.7.2 and press F6 on `src/ui/main.tscn`, or F5.
The first editor import generates translations and script class metadata.

```powershell
& 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe' --editor --path .
```

Enter / gamepad A starts or interacts. WASD / left stick / D-pad moves.
Escape / B leaves a cabinet or returns to the menu; leaving a live round forfeits
its stake. Left/right adjusts stakes. Blackjack: X stands, Y doubles. Vault:
up/down chooses mines before betting, directional input selects boxes during a
round, X cashes out. The cashier is at the lower right of the floor.

New games start with 200 chips and no debt. Below 20 chips, the cashier can grant
a 100-chip marker. Saves live in Godot's `user://` directory, normally
`%APPDATA%/Godot/app_userdata/House Rules/save.json` on Windows.

## Verify

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
godot --headless --path . -s tests/slot_rtp_diagnostic.gd
```

Use the full executable path above when `godot` is not an alias on your machine.
GUT 9.5.0 is vendored and pinned to commit
`8255c6305761754748f9fd641da5fd8f51c1708a`.
Install `tools/requirements-dev.txt` for `gdformat --check src tests` and
`gdlint src tests`. CI runs formatting, lint, GUT and one million production-math
rounds per cabinet, and uploads JSON evidence even on failure.

**Known acceptance failure:** the fixed-seed million-round slot run falls outside
AC-027's ±1 percentage-point threshold. Its exact weighted-strip return matches
the locked paytable. The failing gate remains enabled; a separate ten-million
round diagnostic does not substitute for acceptance. See
`docs/IMPLEMENTATION-NOTES.md` and `tests/results/` for evidence.

## Structure

- `src/domain/`: cabinet math and contracts; no Nodes, SceneTree, signals or autoload access.
- `src/autoload/`: the six specified singletons.
- `src/cabinets/`: scenes and controllers; all wallet settlement goes through `CabinetSession`.
- `src/platform/`: atomic local storage and the platform interface.
- `data/`: editable cabinet definitions and paytables.
- `tests/`: GUT behavioral tests, deterministic replay and real RTP simulations.
- `assets/drafts/`: generated, palette-quantized art awaiting cleanup.

The upstream agency prompts and license are pinned under `tools/agency-agents/`;
`docs/AGENT-PIPELINE.md` records their roles and Godot-specific adaptations.

## Scope and limitations

This implementation brings the first three domain models and RTP harness forward
into M1, as requested. All three have functional controller-operated prototype
screens. Final pixel art, audio, staged visual transitions, physical handheld
validation, and later wing content remain later milestone work. Three persistent
contracts rotate from the ten-objective Main Floor pool and pay flat rewards
independently of cabinet outcomes. Generated drafts are not final accepted assets; see
`docs/art/GENERATION-REPORT.md`.

Fractional payouts round down once to whole chips. This affects low-stake vault
and odd-stake blackjack RTP; the simulation records its actual stake and strategy.
Currency is serialized as decimal strings to avoid JSON precision loss.
Save loading uses `SaveService.load_game()` to distinguish the operation from
GDScript's resource `load()` function. Named RNG states are persisted; a newly
entered blackjack table starts a fresh six-deck shoe.
