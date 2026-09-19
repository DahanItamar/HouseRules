# Production art

Runtime-ready high-resolution art lives here. Unlike `assets/drafts`, these files
are not palette-quantized and are intended for linear filtering at FHD, QHD and 4K.

## Environment provenance

| File | Generator | Job ID | Date | Purpose |
| --- | --- | --- | --- | --- |
| `environments/casino_menu_hall.png` | Higgsfield GPT Image 2.5 | `d6cd9584-56ca-4ab4-ba67-47313c5261b9` | 2026-09-18 | Main-menu casino hall with clear title negative space |
| `environments/casino_floor.png` | Higgsfield GPT Image 2.5 | `1f1d0769-dc88-401b-b6d6-89d9223371fc` | 2026-09-18 | Top-down Art Deco casino floor environment |

## Slot-symbol provenance

The magenta-mask masters live under `assets/source/redesign/slot_symbols/` and
are excluded from release exports. `tools/key_magenta.gd` converts them into the
transparent, mipmapped runtime files under `slot/symbols/`.

| Symbol | Higgsfield job ID |
| --- | --- |
| Cherries | `8828149b-014b-4782-9114-b8e68bf799b3` |
| Lemon | `cd6fcc04-7882-427a-b1a1-5281bceb4277` |
| Bell | `6775bfd9-4411-4410-b207-6291f2c58745` |
| BAR | `f3bfa26f-33fb-4ba4-ba0c-50d631a39465` |
| Seven | `3da5920b-5b1a-4227-afb6-608e1903a57f` |
| Diamond | `3ef5350d-ba4b-457d-b5d8-cd3498fa919f` |

## Slot-screen provenance

| File | Generator | Job ID | Date | Purpose |
| --- | --- | --- | --- | --- |
| `slot/symbols/slot_fullscreen_bezel.png` | Higgsfield GPT Image 2.5 | `16f8cc7e-58ae-4b65-93dc-978d2620bd58` | 2026-09-18 | Full-screen transparent Art Deco reel bezel and control deck |

## Vault-tile provenance

The three matching 1536 px transparent masters were generated as one visual family,
then Lanczos-downsampled to 224 px runtime textures (4× their 56 px logical size).

| File | Generator | Generation ID | Date | Purpose |
| --- | --- | --- | --- | --- |
| `vault/tile_unrevealed.png` | OpenAI ImageGen | `exec-b76b9dd1-416e-4c7b-b48e-ec52167e404b` | 2026-09-19 | Closed navy, gunmetal and brass security tile |
| `vault/tile_safe_revealed.png` | OpenAI ImageGen | `exec-1937b419-b67b-4875-808a-28d76e6fa817` | 2026-09-19 | Matching revealed cyan-diamond reward state |
| `vault/tile_mine_revealed.png` | OpenAI ImageGen | `exec-1b18d4a7-c2e9-4a41-9681-2d1d3959d2f6` | 2026-09-19 | Matching revealed red mechanical hazard state |
