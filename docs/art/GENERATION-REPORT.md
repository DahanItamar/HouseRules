# M1 asset generation report

## 2026-09-19 layered casino pass (Claude Code with Claude agents)

All generation in this pass went through the connected **Higgsfield MCP**
(claude.ai connector). The account started at 544.25 credits; see the release
notes for the closing balance. Raw outputs live under `assets/source/layered_v2/`
and are never overwritten. Production files are derived from them by the scripts
named below. Discarded experiments are kept only locally in
`assets/source/layered_v2/_rejected/` (git-ignored) and are listed here by job ID.

### Environments (3840×2160 masters)

| Room | Upscale job (`bytedance_image_upscale`, 4K) | Source |
| --- | --- | --- |
| Main Floor | `5c5ddfac-6548-427c-8dc4-979701144298` | `casino_floor_upscale_5c5ddfac.png` |
| High Roller Salon | `280a7aef-b153-443b-8a2d-4b0df079bf72` | `high_roller_upscale_280a7aef.png` |
| VIP Penthouse | `6e623fe9-129e-4c1c-a10f-6dbe5cfca649` | `vip_upscale_6e623fe9.png` |

Each upscale is aligned to its 1344–1672 px original (mean absolute difference
2–3/255, zero shift) and resized with Lanczos to exactly 3840×2160.

### Guests painted into blocked zones

The design decision, directed by the user: every furniture group is one blocked
collision zone that follows its visible rug, platform or rail border. Guests
exist only inside those zones, painted into crops of the clean master with
`nano_banana_pro` image edits, then baked with `tools/art/bake_paint_ins.py`
using the specs `tools/art/bake_main_floor.json`, `bake_high_roller.json` and
`bake_vip.json`. Only pixels inside the named zone polygons change. The player
can never walk behind or among these guests, so they need no runtime depth.
This supersedes the brief's "never bake people" rule for unreachable areas.

| Room | Edit jobs (used) |
| --- | --- |
| Main Floor | lounges `aab0f031-cd41-41eb-91bd-055bae870f03`, slot/blackjack islands `e12f3dda-6c5a-4664-a194-e56049bbed3f`, roulette island + elevator group `8512742b-3c1f-4274-867d-79ef86657839`, cashier `972868c3-a9fe-4ff6-afca-ef267fcbb308`, staircase lock `0d7e1b5f-b4b6-4e4a-be30-b9d0dc462718`, elevator lock `872ba6ee-c5b1-4bc8-899f-371049fc161c` |
| High Roller | table `57a47ce8`, slot alcoves `03b62a4a` and `7edfb3ac`, booths `db96b06e` and `c2102db5`, lounge `9386c85f`, reception `6136874f` |
| VIP | poker `6e2038aa`, roulette `7a659116`, bar `ff4582cf`, lounges `1f5fbc57` and `de3a5c95` |

`_aligned` copies register an edit to its crop (the 16:9 4K edits return
5504×3072, not exactly 16:9). The bake colour fit rejects implausible gains, so
a misregistered edit is never washed out.

### Cabinet hosts (1392×2080 transparent masters)

`gpt_image_2_5` (quality high, 2k, `background: transparent`) created each
adult host. Pose variants are image edits of the same master.
`tools/art/prepare_characters.py tools/art/characters_v2.json` cleans the alpha,
bleeds edge colour under transparent texels, pads a clear border and aligns
variants to the master's head.

| Host | Master | Poses |
| --- | --- | --- |
| Slot hostess (blonde, champagne gown) | `c1d5b6ff-8146-4e6a-8175-6816f12a41fd` | reels `ad4e9f7c`→cutout `fa067838`, player `b4bdfda3`→`090526c4`, anticipation `f6897e09`→`fb0bc395`, win `6eafd364`→`2e4b5e79` (`nano_banana_pro` + `remove_background`) |
| Blackjack dealer (burgundy waistcoat) | `8b0c895c-dce2-4033-9546-0cda188c9b23` | player `eba148e9`, deal `ba374f5e`, reveal `1ca04e09` |
| Vault attendant (navy concierge uniform) | `870301bb-f92f-4d72-9963-3fab7371f4c4` | idle `ffd07bc1`, cash-out `31e592a8`, warning `948a58ac` |

The content filter blocked four hostess edits made with `gpt_image_2_5`
(`c41440ee`, `ffc3ba3b`, `18b86989`, `b8622eb3`). The hostess poses were redone
with `nano_banana_pro` on a grey background and cut out.

### HUD

| File | Job | Notes |
| --- | --- | --- |
| `assets/production/ui/hud_chip_stack.png` (512 px, transparent) | `3dcdc1fc-fb16-423b-a516-4ba60d6ca553` (`gpt_image_2_5`, transparent) | Burgundy and ivory art-deco chip stack with the brass fan emblem, replacing the flat vector chip. Alternate `38e7267f` rejected. |

### Rejected or superseded (local only)

- Cut-out floor guest sprites (19 jobs) and the separate lock-sign prop
  `ae3480a8`. They were replaced by guests and signs painted into blocked zones,
  because the cut-outs read as pasted onto the furniture.
- Cut-out experiments: green screen `be5e4aad`, mattes `03daabcb`, `09af776d`
  and `cd67791e`.
- Retries: High Roller slot `a1397ab9` (guest too large), VIP roulette
  `47647776` (couple outside the platform). Alternate host masters `974f8058`
  and `b660239c`.

## 2026-09-19 character motion correction

The runtime floor guest now uses `assets/production/characters/casino_guest_walk_32.png`,
a transparent 8-direction by 4-phase walk atlas derived from the approved burgundy-tuxedo
guest. The built-in image editing workflow was used after external Higgsfield reference
upload was denied by the environment's data-export guard. Runtime tests verify the native
1774×887 2:1 grid, transparent background, all four leg phases, and direction mapping.

Eight Higgsfield images generated successfully on 2026-09-18 using `recraft_v4_1`, utility variant, 1k source resolution. Initial balance 746 credits; final balance 736 credits: 10 credits consumed, matching the preflight estimate of 1.25 per image. No retries or subscriptions were purchased.

The Image Prompt Engineer persona from `tools/agency-agents/design-image-prompt-engineer.md` supplied structured subject, environment, lighting, style and technical constraints, adapted from photography to flat game sprites. The linked repository definition is a working method, not evidence of asset acceptance.

## Deliverables and provenance

`tools/art/generation-manifest.json` records exact prompts, parameters, stable indices, provider job IDs, original URLs, source paths and draft paths. Eight unmodified source PNGs are in `assets/source/`; Godot ignores this source-art folder. Processed draft PNGs are in `assets/drafts/`.

| Asset | Final draft size | Status |
| --- | --- | --- |
| slot_classic_body | 320 x 400 | Cleanup pending |
| sym_cherry | 64 x 64 | Cleanup pending |
| sym_lemon | 64 x 64 | Cleanup pending |
| sym_bell | 64 x 64 | Cleanup pending |
| sym_bar | 64 x 64 | Cleanup pending |
| sym_seven | 64 x 64 | Cleanup pending |
| sym_diamond | 64 x 64 | Cleanup pending |
| vault_backdrop | 960 x 540 | Cleanup pending |

## Reproducible processing and validation

From the repository root on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/art/postprocess.ps1
```

This process-scoped execution option does not change system execution policy. The script uses System.Drawing and C# for center-sampled nearest-neighbour resizing, then nearest RGB palette quantization with no dithering. It preserves source opacity and converts alpha to binary. It writes exact target dimensions and excludes currency gold and table-only felt green from this non-currency, non-table batch. `tools/art/validation.json` records observed dimensions, color counts, transparency counts and SHA-256 hashes. All eight drafts passed dimensions, allowed palette and binary-alpha checks. All eight currently have zero transparent pixels.

## Visual review and remaining work

These are generation and quantization drafts, **not accepted production assets**. Visual inspection of cabinet, lemon, diamond and backdrop found:

- Cabinet and symbols retain opaque backgrounds. Masking, edge cleanup and halo inspection are still required.
- Lemon and diamond occupy too little of their 64 x 64 canvas. Crop/recompose before final nearest resizing; compare all six symbols for equal visual weight and make diamond clearly dominant.
- Cabinet highlights contain large white areas; convert broad white fills to primary-text/off-white or chrome and reserve pure white for small specular points.
- Backdrop uses strong perspective and dense, bright texture despite the flat-view prompt. Reduce distraction around the minefield interaction area before acceptance.
- Handheld readability, 1x review of every symbol, shared origins and final human cleanup have not been accepted. No hand-pixel animation or card-face work is claimed complete.

The generation gallery was displayed once with all eight exact job IDs. No further generations were submitted after this first quality-review batch.

## Brief conflicts resolved or recorded

Palette rules explicitly outrank aesthetics. Lemon, bell and BAR prompts ask for yellow/gold, but gold is currency-only: this batch substitutes orange/chrome. BAR uses an ingot silhouette without letters, consistent with the global no-text instruction. SEVEN requires a single numeral 7, so its specific requirement overrides the generic no-numbers negative. Transparent backgrounds are a cleanup deliverable; requesting transparency from a model without an alpha control would not establish compliance.

`tools/art/backlog.json` prepares remaining generation candidates from the master brief and all three cabinet asset lists without submitting them. The blackjack cabinet calls 24 x 32 chips GENERATE while the master brief says chips that small should be hand-pixelled; this discrepancy is recorded. Multiframe floor indicators and elevator states require aligned manual derivation, not independent animation-frame generation. The original specifications were not edited.

## M2 completion batch — 2026-09-18

The remaining generation backlog was submitted through the Higgsfield MCP after
model and cost preflight. The batch used 161.25 credits (736 to 574.75): seventeen
Recraft V4.1 images including two review-driven replacements, plus five Seedance
videos. Recraft V4.1 utility produced fifteen accepted still masters;
Seedance 2.5 produced five four-second, silent motion masters using the related
still job as its start-image reference. The disputed 24×32 chip stack was not
generated because the master brief correctly assigns work at that size to manual
pixel art.

The source set is stored under `assets/source/m2/` and
`assets/source/animations/`. Exact job IDs, result URLs, prompt summaries,
generation parameters, target dimensions and local paths are recorded in
`tools/art/m2-generation-manifest.json`. The download helper can reproduce the
local source set without submitting new jobs.

The palette pipeline generated exact-size drafts under `assets/drafts/m2/` and
recorded dimensions, palette counts and hashes in
`tools/art/m2-validation.json`. All fifteen still drafts pass automated dimension
and HOUSE-RULES-16 palette checks. These checks do not imply visual acceptance.

Visual review rejected the first dealer (blank face) and first floor sheet
(incorrect grid); both were regenerated once. The corrected dealer has a readable
face and shared neutral pose. The corrected floor source still needs manual tile
extraction and seam correction before it can become an accepted 24-tile set.
Generated motion is retained as animation source footage; frame extraction,
shared-origin alignment, palette quantization and in-game timing remain required
before any MP4 can be called a production sprite animation.

## 2026-09-19 Witcher's Vault theme (Minefield Vault re-skin)

User direction: every mini-game gets its own theme and HUD. The vault became
**Witcher's Vault**, a monster-hunter's treasure crypt. Mines are cursed rune
sigils; safe tiles reveal silver moon coins with a violet gem. Game math is
unchanged. All generation went through the connected **Higgsfield MCP**. This
pass spent **26.5 credits**; the account's transaction log also shows the
concurrent Slot and Blackjack passes.

Raw outputs: `assets/source/layered_v2/vault_witcher/` (never modified).
Production: `assets/production/characters/hosts/vault_witcher_sorceress*.png`
via `python tools/art/prepare_characters.py tools/art/characters_vault_witcher.json`,
and `assets/production/vault/witcher/` via
`python tools/art/prepare_vault_witcher.py`.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Sorceress master (indicate pose) | `683397aa-cfb2-4d60-8e98-c6790a5d7ac3` | `gpt_image_2_5`, 2:3, high, 2k, `background: transparent` (1360x2048, padded to 1392x2080) | 3 |
| Idle pose (key ring, gaze on grid) | `1bee6a83-bc9d-4fe0-85e7-1d45207ce1d0`, cut-out `9ad395c9-492e-4b70-9a67-e312c59483d4` | `nano_banana_pro` edit of the master on grey, 2k, then `remove_background` | 2 + 1 |
| Cash-out pose (palm-up to player) | `bdb500f8-c743-48ec-b8b7-78135ac4ef4b`, cut-out `5ef43ed9-eb87-4433-9b74-79c9ee300469` | same | 2 + 1 |
| Curse warning (raised palm, faint silver ward sign) | `d6fa9987-7284-416e-88b7-6697309489a6`, cut-out `0fad4a35-c6c6-40ba-aa71-a90bc5ba3283` | same | 2 + 1 |
| Crypt backdrop (used) | `c816f431-6241-4b5c-91bf-7a3ae9755e96` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160) | 4.5 |
| Sealed rune tile | `4555b947-d89e-4a98-a266-3b4344982309` | `gpt_image_2_5`, 1:1, high, 1k, transparent | 2 |
| Safe tile (silver coins and gem) | `c1548e5b-e004-4f08-96da-c0fb4cd24b5a` | `gpt_image_2_5` edit referencing the sealed tile, transparent | 2 |
| Cursed tile (crimson rune sigil) | `6dfc5bdc-246b-4336-a3f4-b3f53bfa58ef` | same | 2 |

Rejected: backdrop `d19f9aeb-089b-4f59-8156-06c395d975b0` (`nano_banana_pro`
4k, 4 credits). It rendered flat and cartoon-like, clashing with the painterly
sorceress. The raw file stays in the source folder for provenance.

Placement: every pose is registered to the master's head on one 1392x2080
canvas (stance centre x=772). Each pose keeps its own sole line and is rescaled
by `ratio` to the master's 1994 px stature. On screen she is 264 px tall, with
her boots at canvas (735, 386) on the crypt flagstones, clear of the grid,
meter, status, deck, Cash Out and How to Play. Known art caveat: the cash-out
edit drew bare hands where the other poses wear gloves.
