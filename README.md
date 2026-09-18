# House Rules

Offline Godot casino MVP: a walkable floor, three playable cabinets on one
session contract, integer chip wallet, contracts, cashier recovery, versioned
local saves, controller-first UI, high-resolution generated art, native motion
and audio.

**Engine:** Godot **4.7.2 standard**, GDScript (installed Windows engine reports
`4.7.2.stable.official.ed1daf0bf`). No .NET or runtime networking.

## Run

Open `project.godot` with Godot 4.7.2 and press F6 on `src/ui/main.tscn`, or F5.
The first editor import generates translations and script class metadata.

```powershell
& 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe' --editor --path .
```

From any PowerShell directory, launch the current packaged MVP with absolute
paths (the PCK path must not be relative to `C:\Users\USER`):

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64.exe' --main-pack 'D:\Dev\repos\HouseRules\export\HouseRules.pck'
```

Enter / gamepad A starts or interacts. WASD / left stick / D-pad moves.
Escape / B leaves a cabinet or returns to the menu; leaving a live round forfeits
its stake. F1 / Menu opens the current game's How to Play card. Left/right moves
between casino chip denominations. Blackjack: X stands, Y doubles. Vault:
up/down chooses mines before betting, directional input selects boxes during a
round, X cashes out. The cashier is at the lower right of the floor.

New games start with 200 chips and no debt. Below 20 chips, the cashier can grant
a 100-chip marker. Saves live in Godot's `user://` directory, normally
`%APPDATA%/Godot/app_userdata/House Rules/save.json` on Windows.

## Verify

```powershell
python tools/check_localization.py
godot --headless --editor --path . --import --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
godot --headless --path . -s tests/slot_rtp_diagnostic.gd
```

Use the full executable path above when `godot` is not an alias on your machine.
GUT 9.5.0 is vendored and pinned to commit
`8255c6305761754748f9fd641da5fd8f51c1708a`.
Install `tools/requirements-dev.txt` for `gdformat --check src tests` and
`gdlint src tests`. CI runs formatting, lint, GUT and one million production-math
rounds per cabinet, and uploads JSON evidence even on failure. The current release
gate passes **48/48 tests and 1,180 assertions**. All three fixed-seed million-round
RTP measurements pass AC-027; see `tests/results/rtp.json`.

## Windows build

Install the Godot 4.7.2 export templates, then use **Project → Export → Windows
Desktop**, or run:

```powershell
godot --headless --path . --export-release "Windows Desktop" export/HouseRules.exe
```

Without export templates, rebuild the testable PCK with:

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-pack "Windows Desktop" export/HouseRules.pck
```

The preset embeds the PCK and excludes tests, documentation, tooling, and
Higgsfield source masters from the player build. The executable supports
resizable/high-DPI Windows displays and Xbox-compatible controllers.

## Structure

- `src/domain/`: cabinet math and contracts; no Nodes, SceneTree, signals or autoload access.
- `src/autoload/`: runtime services for wallet, saves, economy, RNG, scenes, input and audio.
- `src/cabinets/`: scenes and controllers; all wallet settlement goes through `CabinetSession`.
- `src/platform/`: atomic local storage and the platform interface.
- `data/`: editable cabinet definitions and paytables.
- `tests/`: GUT behavioral tests, deterministic replay and real RTP simulations.
- `assets/production/`: high-resolution runtime environments and finished art.
- `assets/drafts/`: legacy palette-quantized prototypes; Higgsfield masters remain under `assets/source/`.

The upstream agency prompts and license are pinned under `tools/agency-agents/`;
`docs/AGENT-PIPELINE.md` records their roles and Godot-specific adaptations.

## Scope and limitations

All three cabinets have controller-operated, art-backed screens with native
motion and deterministic PCM cues. Three persistent contracts rotate from the
ten-objective Main Floor pool and pay flat rewards independently of cabinet
outcomes. Higgsfield still and motion masters, processing manifests and provenance
are retained under `assets/source/`, `assets/drafts/` and `tools/art/`.

The 960×540 logical canvas renders UI directly at FHD/ROG Ally X, QHD and 4K
output resolution with no QHD letterboxing; see `docs/DISPLAY-VALIDATION.md`.
Automated tests cannot replace the final physical-device pass for OS DPI,
sunlight readability, controller firmware and display safe margins. High-Roller
and VIP wings remain visibly locked because their rooms are v2 scope.

Fractional payouts round down once to whole chips. This affects low-stake vault
and odd-stake blackjack RTP; the simulation records its actual stake and strategy.
Currency is serialized as decimal strings to avoid JSON precision loss.
Save loading uses `SaveService.load_game()` to distinguish the operation from
GDScript's resource `load()` function. Named RNG states are persisted; a newly
entered blackjack table starts a fresh six-deck shoe.
