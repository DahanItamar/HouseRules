# M1 asset generation report

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
