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

## 2026-09-19 Elven Court theme (Classic Slots re-skin)

User direction: every mini-game gets its own theme and HUD. Classic Slots became
**Elven Court**, an enchanted elven royal-court machine hosted by an adult blonde
elf princess (pointed ears, jewelled gold circlet, fitted emerald-and-gold gown).
Symbol indices and slot math are unchanged: cherry -> enchanted berries,
lemon -> golden pear, bell -> silver elven bell, bar -> carved gold leaf bar,
seven -> ruby rune seven, diamond -> moon crystal. All generation went through
the connected **Higgsfield MCP**; this pass spent **36 credits** (one refunded
NSFW false positive on the first "look at the player" prompt, re-phrased as a
polite hostess greeting).

Raw outputs: `assets/source/layered_v2/slot_elven/` (never modified).
Production: `assets/production/characters/hosts/slot_elf_princess*.png` via
`python tools/art/prepare_characters.py tools/art/characters_slot_elven.json`,
and `assets/production/slot/elven/` via `python tools/art/slot_elven_prepare.py`.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Elf princess master (presenting the reels) | `1912132e-8558-4dfd-8f02-2c15b31c4c7a` | `gpt_image_2_5`, 2:3, high, 2k, `background: transparent` (1360x2048, padded to 1392x2080) | 3 |
| Alternate master (rejected) | `d8252d2d-c910-46c2-975f-01ec06ea924c` | same | 3 |
| Reels pose (hands folded, watching reels) | `1f7b10e6-c3f2-49e2-a655-0c1c99d55dcb` | `gpt_image_2_5` edit referencing the master, 2k, transparent | 3 |
| Anticipation pose (hands clasped under chin) | `3b6e426e-6230-4f98-bd22-7af0b1bb9249` | same | 3 |
| Win pose (raised hand, delighted) | `ddbfa51d-0c54-4b36-bbe5-f57edeee1746` | same | 3 |
| Player pose (greets the viewer) | `69bc4bc2-3fe1-4795-a2b4-d0f7be181416` (first try `bea10569-...` returned NSFW, refunded) | same | 3 |
| Cabinet bezel | `036539be-3743-44b7-acfc-793a69e86633` | `nano_banana_pro` 16:9 4k, guided by an uploaded layout sketch (media `1231b256-9eeb-42ad-9965-598f0f981a87`) | 4 |
| Berries / pear / bell / leaf bar / ruby seven | `1dcb34b8-...`, `a79c2b6c-...`, `f3217314-...`, `31566f6a-...`, `ab5b6afd-...` | `gpt_image_2_5`, 1:1, high, 1k, transparent | 2 each |
| Moon crystal | `5357601e-5971-4d30-9890-a4fccd820a2b` | same (first submit rate-limited, not charged) | 2 |
| Lever arm | `87efa7ba-1054-4e1f-a8b0-2a243742668d` | `gpt_image_2_5`, 2:3, high, 1k, transparent | 2 |

Processing: the painted reel opening landed at virtual (254,198)-(706,391), not
on the runtime reel window. `slot_elven_prepare.py` scales the painting uniformly
to the window height and widens only the opening column by 13%, so the opening
matches Rect2(166,151,628,234) exactly. It cuts that rectangle to alpha 0 and
replaces the painted static lever arm with the forest wall above it, keeping the
carved mount. The animated SlotLever pivots in that mount at (860,316). Symbols
are trimmed and re-centred at 1024x1024, and `SlotSymbol.SUBJECT_RECTS` fits the
painted subject, not the square canvas, to each reel cell.

Placement: the host's five poses share one 1392x2080 canvas and one foot anchor
(source 400,2030 -> canvas 30,424, scale 0.142, ~282 px tall). Every pose stays in
x 2-164. She clears the reels, payline, plaque title and status, credits, bet
tray, Spin, result meter and lever (`tests/test_cabinet_hosts.gd`).

## Blackjack salon redesign and the reusable card deck (2026-09-19)

Blackjack was rebuilt as a live-dealer salon: a new table master with a higher
camera, a new stylized painterly dealer standing centred behind the far rail, a
painted shoe and chip stack, and a reusable 52-card deck with illustrated courts.
All generation went through the connected **Higgsfield MCP**; this pass spent
**66 credits** (35 for the table, props and dealer; 31 for the deck).

Raw outputs (never modified): `assets/source/layered_v2/blackjack/` and
`assets/source/layered_v2/cards/`. Production derivatives:
`python assets/source/layered_v2/blackjack/prepare_blackjack_v2.py` ->
`assets/production/blackjack/{dealer,props}/`, and
`python assets/source/layered_v2/cards/prepare_cards.py` -> `assets/production/cards/`.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Table master (chosen) | `d99954b1-8877-4dcf-b2c7-bbc7beceebf0` | `nano_banana_pro` 16:9 4k (served as nano_banana_2), reference = old table (media `6e21e553-...`) | 4 |
| Table alternate (rejected) | `6152d955-c205-493d-b317-3d13d12463e8` | same | 4 |
| Card shoe | `68045eb2-e164-45ed-81d1-7c4cfd8a2902` | `gpt_image_2_5`, 3:2, high, 2k, transparent | 3 |
| Chip stack | `e7403c67-31e8-4717-8910-57f85598746a` | `gpt_image_2_5`, 1:1, high, 2k, transparent | 3 |
| Ivory face stock (paper source) | `c62dd28a-79d0-46a8-af4c-e9ae6b8fcb4a` | `gpt_image_2_5`, 2:3, high, 2k, transparent | 3 |
| First card back (superseded) | `fc531367-4a20-45c5-ae52-849930e1374f` | same | 3 |
| Salon dealer master, cards pose (chosen) | `00078168-8da9-48a4-a279-acd61f3eb480` | `gpt_image_2_5`, 2:3, high, 2k, transparent | 3 |
| Salon dealer alternate (rejected) | `d344680c-4aee-47a5-baa6-7d6768d88587` | same | 3 |
| Deal / reveal / player poses | `b791d185-e7e3-410a-9e63-d5ea784dd78b`, `f23948f6-48bc-42bb-8585-7b624907ddc5`, `51c62ac7-0b40-4163-a342-98af467e4a6b` | `gpt_image_2_5` edit referencing the master, 2k, transparent | 3 each |
| King of spades court half (style key) | `77cbb1a3-f712-44d1-8d7c-8cac791332de` | `gpt_image_2_5`, 4:3, high, 1k | 2 |
| Other 11 court halves | `edb63c23-...` (Q♠), `d6bff1f4-...` (J♠), `54db661d-...` (K♥), `ec95a5d1-...` (Q♥), `8bfa84be-...` (J♥), `5b18c996-...` (K♦), `d5a7e1ff-...` (Q♦), `a611b0c5-...` (J♦), `2e6eab3d-...` (K♣), `e8e8582f-...` (Q♣), `1837fd84-...` (J♣) | `gpt_image_2_5` edit referencing the K♠ half, 4:3, high, 1k | 2 each |
| Suit pip set | `8533fe4e-6b58-48d7-98d6-c6d3e8237b1c` | `gpt_image_2_5`, 1:1, high, 1k, transparent | 2 |
| Ornate ace of spades | `e7fdc80d-f8cc-44a8-a72d-0672b6660391` | same | 2 |
| Card back | `627d91d2-2def-4034-a7e7-e9130153eeb4` | `gpt_image_2_5`, 2:3, high, 2k | 3 |

Processing:
- Table: a 1.12x top-centred crop of the 5504x3072 output resized to 3840x2160
  (`blackjack_table_v2.png`); the painted betting circle under the control deck
  was inpainted out (OpenCV Telea plus the felt's own grain). The far walnut
  rail edge is level at virtual y 175.25; the dealer occluder samples this texture.
- Dealer: four aligned 1360x2048 poses (`blackjack_dealer_v2_salon_<pose>.png`);
  the skirt waistband (source y 1215) sits on the rail. A hands layer
  (`..._salon_hands_<pose>.png`) keeps hands, cuffs and held cards, starts 40
  source rows above the rail and is fully opaque 6 rows above it, so it is drawn
  over the rail occluder with no seam; legs (components touching the frame
  bottom) and the skirt stay behind the table. A soft 34% contact shadow is baked
  under the hands.
- Deck: the ivory stock is the inside of the face template; the back is made
  exactly point-symmetric; courts are the generated half plus the same half
  rotated 180 degrees (double-headed), trimmed to the last painted row so the
  halves meet on a dark rule. Ranks, indices and 2-10 pip layouts are laid out in
  `src/ui/playing_card.gd`; no generated text is used anywhere. No third-party
  deck marks, logos or back designs.

## 2026-09-19 Ruby Roulette (European Roulette, VIP Penthouse)

New playable cabinet `roulette`. The hostess is an adult croupier with an auburn
chignon and green eyes, in a fitted ruby satin croupier dress with a black sash.
The HUD is mahogany plates with brass rules, ivory inlay lines and brass studs.
All generation used the connected **Higgsfield MCP**. This pass spent
**33 credits** (19.5 + 10.5 + 3). Other agents spent credits from the same
account in the same window, so compare against these job IDs, not the balance.

Raw outputs: `assets/source/layered_v2/roulette/`. These files are never modified.
Production: `python tools/art/prepare_roulette.py` builds the backdrop, wheel bowl
and rotor, chips and guest busts. `python tools/art/prepare_characters.py
tools/art/characters_roulette.json` builds the croupier masters (1392x2080,
alpha-cleaned, colour-bled, head-registered, clear corners).

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Salon backdrop (used) | `5a29c98f-1394-4459-bf30-cbf71aab3fcc` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160) | 4.5 |
| Higher-angle backdrop (rejected) | `af2a1c16-0c50-4575-b1b8-7e73fa4ea53a` | `gpt_image_2_5` with the first backdrop as reference, 16:9, high, 4k | 4.5 |
| Wheel (bowl and rotor source) | `b4bfdba9-365e-4282-ada3-720bbee69ff5` | `gpt_image_2_5`, 1:1, high, 2k, `background: transparent` | 3 |
| Croupier master (idle, watching the wheel) | `f200083a-92d7-4cff-9224-c773624e3da0` | `gpt_image_2_5`, 2:3, high, 2k, transparent (1360x2048) | 3 |
| Spin launch pose | `0f5712bb-aa97-4d20-baac-8bd33b5c2de3`, cut-out `9cb59a4f-5ff9-483a-ab8b-09437fcb8714` | `nano_banana_pro` edit of the master on grey, 2k, then `remove_background` | 2 + 1 |
| "No more bets" pose | `5d1c5f6e-66c6-4b8b-b50d-41b370d647d1`, cut-out `0621aee7-7895-4b85-8e28-43dc89ea061c` | same | 2 + 1 |
| Announce pose (to the player) | `d1cbdc55-979e-4d4c-80f1-2fa7d9eccf11`, cut-out `b0604db4-d694-4ec5-9fda-9f77146bcdc8` | same | 2 + 1 |
| Guest: Mr. Okada (system bettor) | `56593fc6-8cec-4db9-89a8-7cb38c931652` | `gpt_image_2_5`, 1:1, high, 1k | 2 |
| Guest: Desmond (dreamer) | `dfc293d7-aa46-40dc-b4ca-f90869581ff9` | same | 2 |
| Guest: Signora Lucia (regular) | `3b660a0d-824b-409c-8caf-5a922039ce2c` | same | 2 |
| Chip sheet (ivory, ruby, sapphire, emerald, jet) | `c4a5265b-b772-4845-a158-9f9b677aab83` | `gpt_image_2_5`, 16:9, high, 2k, transparent. Sliced to five 320 px chips. | 3 |

Rejected: the higher-angle backdrop `af2a1c16`. Its far rail sits at about
y=150 virtual, which leaves too little room for a grounded croupier behind the
table. The shallower backdrop gives her about 182 px from head to rail. The raw
file stays in the source folder for provenance.

Exact geometry is drawn in code. The painted wheel is re-centred on its bowl
(source centre 1010,997, radius 1000 px). Rotor radius 472 px becomes
`roulette_wheel_rotor.png`. The 37-pocket ring (radii 0.472 to 0.645) is drawn by
`RouletteWheel` in European wheel order from the paytable, so the ball lands in
the pocket the math chose. The betting layout is also code-drawn on the painted
sapphire felt.

Placement: every croupier pose shares one canvas. Head centre x=735, and her rail
line is at source y=1861 (upper thigh). On screen she is 182 px from head to rail,
anchored at the far rail (y=209) above the wheel. A clipping lane hides her below
the rail, and the wheel sits in front of her. Her lane is clear of the layout,
seat plates, title, result plaque and deck (`tests/test_roulette.gd`).
Known art caveat: the "no more bets" edit is framed about 50 px narrower at the
hip, so the cross-fade shows a small lateral shift of the lower body (under 6
virtual px).

## Penthouse Texas Hold'em table (2026-09-19)

New VIP game `poker`: a sapphire-felt oval table seen from the player's seat, a
platinum-blonde dealer in a black-and-sapphire vest dress standing behind the far
rail, five NPC regulars as portrait busts with one reaction face each, and a
chip-stack prop. Cards reuse the shared `PlayingCard` deck. All generation went
through the connected **Higgsfield MCP**; this pass spent **41.5 credits** by
per-job price (the account is shared with other agents working in parallel, so
the balance delta is larger). One first "reserved smile" edit for the Rock
failed on the provider side and was resubmitted with a softer wording.

Raw outputs: `assets/source/layered_v2/poker/` (never modified).
Production: `python assets/source/layered_v2/poker/prepare_poker.py` ->
`assets/production/poker/` (table, `npc/*.png` 512x512, `props/chips_{pot,black}.png`),
and `python tools/art/prepare_characters.py tools/art/characters_poker_dealer.json`
-> `assets/production/characters/hosts/poker_dealer*.png` (1392x2080, clean alpha
corners, variants head-aligned to the master).

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Table backdrop (used as is) | `c4d00003-5996-40bc-8417-5d4a37ded2b1` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160) | 4.5 |
| Dealer master (rest pose, deck at waist) | `a8a49296-f91f-4b57-a6e6-1fff87497f48` | `gpt_image_2_5`, 2:3, high, 2k, `background: transparent` | 3 |
| Dealer deal / reveal / push poses | `05cdc110-d343-41f9-a12a-74a1d234f680`, `95c246c3-3844-437b-8e0e-f0583bb44870`, `579c1162-fe27-4e7b-9c57-bfbe9dd49c8b` | `gpt_image_2_5` edit referencing the master (`image_references`), 2k, transparent | 3 each |
| Dealer "awaiting the player" pose | `6cdafe90-c2cf-43e4-9cf3-c4fe746987ab` | same | 3 |
| The Shark / Rock / Maniac / Calling Station / Tourist busts | `f6722d87-0266-473a-b450-ab2eac39932c`, `e8c2b761-ed46-4d0f-9df2-c308d4258b8b`, `483fc85f-99ab-420c-9c9a-b36780fa1152`, `9e4ca8bd-5824-451a-a83b-9ed62be4c66c`, `885a9b33-66b9-49ab-824b-05e2e0614b91` | `gpt_image_2_5`, 1:1, high, 1k, dark sapphire studio background | 2 each |
| Reaction faces (Shark, Maniac, Calling Station, Tourist) | `7ac4ceed-bc84-44e0-8429-d915cb842cf2`, `c1abdadf-e6d8-45ce-8d1b-c6b2a7f5a392`, `f9c885c3-4dbf-479d-84d5-cd4c0d95855b`, `cb5d4b56-65cd-454b-954b-75b343ab4ed7` | `gpt_image_2_5` edit referencing each bust, 1k | 2 each |
| Rock reaction face | `0d60be3d-1828-40bd-8095-ed34075192d7` (first try `3279dfcb-6ffa-4fbc-9aa3-ac6129ccc6b9` failed, not charged) | same | 2 |
| Chip stacks (sapphire / white / black) | `50a6a76a-839a-48ba-930e-e5235c9f1c28` | `gpt_image_2_5`, 1:1, high, 1k, transparent | 2 |

Processing: the table is used unmodified; its far padded rail is level at 4k
y=760 (virtual y=190) across x 1300-2600, so the dealer is anchored with her
upper thigh (source 696,1600) on that line at scale 0.095 and a 240x72 patch of
the table texture redrawn over her from the rail down (`PokerDealerPresenter`).
Every pose keeps its hands above the rail, so no separate hands layer is needed.
The chip trio overlaps, so only the free-standing black stack is cut out for
seat bets; the whole trio is the pot pile. Portraits are centre-cropped to
512x512. No text, logos or third-party marks appear in any asset (the dealer
button "D" is drawn in code from a translation key).

## 2026-09-19 Match Point (tennis Plinko, High Roller)

New playable cabinet `match_point`. The hostess is an original adult woman in
country-club tennis chic: a white cropped polo, a white pleated tennis skirt, a
green-and-cream striped sweater tied over her shoulders, a plain green round bag
with no logo, light honey-blonde glossy waves, green eyes, bronzed skin and gold
hoops. She is kept visibly lighter and greener-eyed than the Velvet Baccarat
hostess, who is a darker brunette with brown eyes. The approved master concept is
`assets/source/layered_v2/hostess_bronde/bronde_tennis_4f41ac74.png` (Higgsfield
job `4f41ac74-3187-4b75-b884-19d6b6045816`, `gpt_image_2_5`, transparent,
1360x2048). It was generated before this pass and is not counted below. The HUD
is a scoreboard: racing-green plates with double brass piping and cream enamel
score strips.

All generation used the connected **Higgsfield MCP**. This pass spent
**19.5 credits** (8 + 4 + 4.5 + 3). Another agent spent credits from the same
account in the same window, so compare against these job IDs, not the balance.

Raw outputs: `assets/source/layered_v2/match_point/`. These files are never
modified. Production: `python tools/art/prepare_match_point.py` copies the
backdrop, slices the ball and peg, and builds the hostess masters. Each cut-out is
de-fringed against its measured grey edit backdrop: the edge colour is un-mixed
from the grey and near-grey rim texels lose alpha, which takes the grey share of
soft-edge texels from 43% to 3–6%. Each cut-out is then scaled from 1696x2528 to
the 1360x2048 house canvas and passed through the shared
`tools/art/prepare_characters.py` steps (alpha floor, colour bleed, pose
registration, 16 px clear border). The results are 1392x2080 masters with clear
corners.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Idle pose (watching the board, ball in hand) | `d92433bb-3695-4ef3-8875-5f1f477cfe3f`, cut-out `70a9384e-4bdc-4afe-b056-10c21cea91d1` | `nano_banana_pro` edit, master job as image reference, 2:3, 2k, on flat grey (the job reports `nano_banana_2`), then `remove_background` | 2 + 1 |
| Serve pose (tossing the ball up to the right) | `619d5f00-3065-4353-abb5-08b61e3e6b82`, cut-out `32598080-b390-4788-aa59-342e1671770b` | same | 2 + 1 |
| Watch pose (anticipation, hands clasped) | `1b9932fe-141d-4d6c-9341-d46dbde9b472`, cut-out `760929b5-af21-4fb9-8756-2c7cde9f8f6a` | same | 2 + 1 |
| Celebrate pose (fist pump to the player) | `37bf61b2-2851-42b5-a2b4-85c97c8bff32`, cut-out `acc757fc-b703-4118-917f-c675bef65041` | same | 2 + 1 |
| Clubhouse cabinet backdrop | `f1f01d22-372d-4fdc-a31c-366d17cb2ac9` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160) | 4.5 |
| Prop sheet (tennis ball, brass court-stud post) | `f41b5c0c-d466-4492-aaf5-208305f6b933` | `gpt_image_2_5`, 3:2, high, 2k, `background: transparent`; sliced to a 256 px ball and a 128 px post | 3 |

Nothing was rejected or regenerated.

Exact geometry is drawn in code. The backdrop's plain racing-green panel (x 270
to 690 virtual) carries a code-drawn field: 12 rows of posts at 28 px pitch, 13
cream-enamel courts, and a brass serve hatch. The ball follows the path the math
decided. The courts, multipliers and hatch contain no generated text.

Placement: the four poses are registered on the midpoint between the eyes, with
per-pose size ratios (serve 0.96, watch 0.89, celebrate 0.96) because the edits
came back at slightly different figure scales. The cut line sits 1480 source px
below the eyes, which is the top of the deck at y=440. She stands in the
clubhouse window alcove at display scale 0.211, and a clipping lane
(0,27 280×413) hides her below mid-thigh. Every pose fits inside the lane, and the
lane is clear of the field, title, result plaque, risk plate, Help and deck
(`tests/test_match_point.gd`).

Known art caveats: the serve edit came back framed lower (its head is about 250
source px lower on the canvas), so it is registered by the eye line rather than
the canvas. Its lower cut is closest to the deck (2050 of 2063 source px). The
celebrate pose turns her torso toward the viewer, so the cross-fade from the
watch pose changes silhouette more than the other beats.

## 2026-09-19 Staff paint-ins (cocktail waitresses)

Four original adult staff characters are painted into the blocked furniture
zones, using the same method as the guests: a crop of the current production
background, a `nano_banana_pro` edit (2k, 1:1, served as `nano_banana_2`) with
the crop and the approved concept job as image references, then the bake in
`tools/art/bake_paint_ins.py`. The player can never enter these zones, so none
of the staff need runtime depth. Each patch uses the new optional `clip_rects`
key: the bake intersects the zone mask with a rectangle around the added woman,
so everyone else in the zone stays exactly as the master had them, with no
redrawn guests. All four aligned at shift (0,0).

Concept jobs (approved, `assets/source/layered_v2/waitress/`):

| Staff | Concept job | Look |
| --- | --- | --- |
| Espresso waitress | `78079b0d-00f6-4668-a5fa-ea7bb452c2a1` | espresso waves with curtain bangs, black satin corset vest over a white shirt, black pencil mini skirt, champagne tray |
| Ponytail server | `2f18427a-467e-48cd-a306-2ad9ace1d3f4` | jet-black high ponytail, black silk shirt, black leather mini skirt, notepad |
| Corset server | `a5fefa1e-6e30-4026-a49a-62222ee3eb76` | black leather corset over an ivory satin blouse, short leather skirt, cocktail tray; hair changed in the edit from copper-red to dark black-cherry auburn so she is not confused with the red-haired roulette croupier |
| Burgundy hostess | `4a329a00-868a-4573-9dff-4a4946d86a2a` | platinum bob, burgundy leather wrap mini dress, clutch |
| Option 2 (not used) | `b01e4296-b758-4fba-9832-56679eda6143` | vinyl dress concept, not placed |

Edits (2 credits each, 8 credits in total; every edit was accepted on its first
attempt, so none were redone):

| Staff | Edit job | Crop media | Room / zone / crop (virtual px) | clip_rects | Placement |
| --- | --- | --- | --- | --- | --- |
| Espresso | `a3fc2dd8-f44d-4fa3-be49-4805f964ae4c` | `da59fbce-9b89-4c23-ac81-1ab7a8399e75` | Main Floor `LoungeDais`, `[0,300,240,240]` | `[158,385,212,494]` | stands inside the brass rail to the right of the lower lounge group and offers champagne flutes to the man in the navy suit |
| Ponytail | `e24eeabe-3647-4b40-933b-3ab2d512560a` | `c00e5661-8b85-460a-9bdf-eff7ab0c8939` | VIP `zone_bar`, `[688,40,272,272]` | `[871,100,913,210]` | stands on the marble ring at the service end of the bar and writes an order on her notepad, facing the counter and bartender |
| Corset | `3f416a97-6616-413c-a1ff-43d0232b320f` | `22c8ddcb-0dad-4687-b46b-2999b36f49c1` | High Roller `zone_lr_lounge`, `[735,280,225,225]` | `[850,328,912,448]` | walks between the lamp table and the globe console, behind the balustrade, serving two martinis to the seated couple |
| Burgundy | `d7cebfb7-d12d-45eb-97d7-7fd61c4a9273` | `e770ad0a-2b14-43d4-9f13-eb66e4d11f96` | High Roller `zone_reception`, `[750,40,210,210]` | `[792,88,886,214]` | stands at the left corner of the reception desk with one hand on it, talking to the concierge |

Outputs are saved as `assets/source/layered_v2/paint_in/staff_<name>_<room>_<job8>.png`.
The High Roller centre table, both slot alcoves and the Main Floor cashier/office
area are untouched. After the bake, `floor_layers.py build` regenerated the
foreground, collision and preview for all three rooms. Only the High Roller
foreground changed: the `lr_plant_a` and `lr_rail` occluders overlap the corset
server, and they are cut from the same background pixels. `check` passes for all
three rooms. Before/after crops at 1:1 and full-room previews are in
`tests/results/screenshots/staff_paint_ins/`.

Scale note: every figure matches the painted guests in her own group (lounge
guests are drawn larger than the island guests near the back wall). The corset
server (about 108 virtual px tall) and the espresso waitress (about 97 px) are
the tallest standing figures in their rooms.

## 2026-09-19 Velvet Baccarat (Punto Banco, High Roller Salon)

New playable cabinet `baccarat`. The hostess is an original adult woman built from
the approved concept `assets/source/layered_v2/hostess_bronde/bronde_evening_4d76e701.png`
(Higgsfield job `4d76e701-d06e-4c18-959a-bb33bded4f4f`, `gpt_image_2_5`, transparent,
1360x2048). She has long glossy dark-brunette hair with honey balayage in big waves,
bronzed skin, brown eyes and gold hoops, and wears a violet satin ruched midi dress. She
drops the white shoulder bag in every table pose, so no pose change makes it appear
or vanish. She stays distinct from the Match Point hostess (lighter blonde, green eyes,
tennis whites). The HUD is violet lacquer plates with brass rules, pearl inlay lines
and pearl studs.

All generation used the connected **Higgsfield MCP**. This pass spent
**21.5 credits** (17.5 for the batch at 16:37:05 UTC, then 4 x 1 for background removal
at 16:39:45 to 16:39:52 UTC). The account is shared with another agent, so compare
against these job IDs and times, not the balance.

Raw outputs: `assets/source/layered_v2/baccarat/`. These files are never modified.
Production: `python tools/art/prepare_baccarat.py` builds everything. For the hostess,
it un-mattes each cut-out: it un-mixes the studio grey (137,137,137) that
`remove_background` leaves in edge texels and pulls the rim in by 3 px. It then
normalises every pose to the same stature (head-top to sole 1990 px) and head column,
and runs the shared `prepare_characters.py` alpha clean, colour bleed and 16 px clear
border. The results are four 1392x2080 masters with clear corners.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Hostess idle (watching the shoe) | `ac8e1b5c-ef66-4238-b471-912ea2e10d11`, cut-out `1da6b775-4763-4c5a-b49c-b95e24bd6445` | `nano_banana_pro` edit, job `4d76e701` as image reference, 2:3, 2k, grey studio background, then `remove_background` | 2 + 1 |
| Hostess dealing (hand toward the card lane) | `7b9aa6bb-1954-4239-bf7b-5728c9f55132`, cut-out `88a6aff8-be88-4712-bb87-53344d619ea3` | same | 2 + 1 |
| Hostess squeeze (studying a card) | `cbc5f6f3-b349-40fe-8d50-dabbb4140329`, cut-out `1b01554e-7053-48b7-803d-967717a2ca74` | same | 2 + 1 |
| Hostess announce (smile, gaze to the player) | `b3351222-8f53-4f8d-890a-12325ee4cdb4`, cut-out `69f02fd1-4905-4954-8cf9-f6f738224435` | same | 2 + 1 |
| Private salon backdrop (violet and walnut, no people) | `8443d56d-76ba-44cc-8f36-90c38352de33` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160) | 4.5 |
| Chip sheet (pearl, lavender, plum, black lacquer) | `726a4b95-b3c3-406d-9a71-1d24d152b43d` | `gpt_image_2_5`, 16:9, high, 2k, `background: transparent`. Sliced to four 320 px chips (20, 40, 100, 200). | 3 |
| Card shoe (walnut and brass) | `94872ed0-c1ac-4977-aab9-97b95aabf504` | `gpt_image_2_5`, 1:1, high, 1k, `background: transparent`. Trimmed to 926x774. | 2 |

Model note: the four pose edits were requested as `nano_banana_pro` and billed as
"Nano Banana Pro", but the job status reports the backend as `nano_banana_2`.

Local output names: `hostess_{idle,deal,squeeze,announce}_nb_<job>.png` (the edits on
grey) and `hostess_*_cutout_<job>.png` (transparent). Production files are
`assets/production/characters/hosts/baccarat_hostess{,_deal,_squeeze,_announce}.png`
and `assets/production/baccarat/baccarat_{salon_backdrop,shoe,chip_20,chip_40,chip_100,chip_200}.png`.
Nothing was rejected; each asset took one generation.

Placement: every pose shares one canvas. Head centre x=696, and her rail line is at
source y=1030 (hip, just above the side slit). On screen she is 182 px from head to
rail. The painted far rail's top edge is at virtual y=222 (backdrop row 889). A
clipping lane (336,0 288x222) hides her below the rail. The lane stays clear of the
title, coup plaque, bead road, help button, hand boxes, card slots, bet spots and deck
(`tests/test_baccarat.gd`). The dealing pose's hand and card fall below the rail, so
they are hidden: the arm reads as reaching down to the felt. The code-drawn cards
travel from the painted shoe.

Known art caveats: the idle edit turns her side-on, so the slit and ruching are out of
view in that pose, and her hips sit a few px left of the other poses under the rail.
A faint light rim remains on a few hair strands of the idle pose after un-matting. It
is about half a virtual pixel at game scale.

## 2026-09-19 High Roller Salon goes playable (Baccarat table and Match Point alcove)

The Salon's painted blackjack dealer and left slot alcove are repainted so that the room shows the two cabinets it now hosts. Both are `nano_banana_pro` edits (the server runs them as `nano_banana_2`) of 4x crops of the current `high_roller_background_v2.png`, baked by `tools/art/bake_paint_ins.py` (patches appended to `tools/art/bake_high_roller.json`).

| Patch | Edit job | Crop upload | References | Crop (virtual px) | Bake clip | Credits |
| --- | --- | --- | --- | --- | --- | --- |
| Baccarat table: violet hostess replaces the male dealer, baccarat felt and walnut shoe, brass join diamond below the rug | `4ea2298f-bc6e-43f9-be35-39ac30bfc530` | `70cbd9bf-9cd4-4748-a50a-7d3e8ab47641` | baccarat hostess master `4d76e701-d06e-4c18-959a-bb33bded4f4f` | [336,96,288,192] | `zone_table_rug` + head rect [452,96,510,118] + inlay rect [452,253,510,276] | 2 |
| Match Point alcove: green-and-cream tennis ball-drop cabinet, empty stool, brass join diamond | `451f28bd-1218-4e19-b5ed-cffc51fcf9d6` | `d150a99d-1e15-494a-a18b-d952b1423b37` | Match Point backdrop `f1f01d22-372d-4fdc-a31c-366d17cb2ac9` for palette | [214,0,160,160] | `zone_slot_left_alcove` + crest rect [264,0,326,100] + inlay rect [266,128,314,154] | 2 |

Both colour fits were rejected by the correlation guard (the content changed by design), so the raw paint is baked; it already matches the room palette. The edit's extra wall sconces fall outside the clip and are not baked. Raw outputs: `assets/source/layered_v2/paint_in/hr_games/`. Layout: `data/floors/high_roller.json` now lists `baccarat` at [480,268] and `match_point` at [290,141], `preview_only: false`.

## 2026-09-19 Manager's Office (new room, office door, secretary and Manager)

A new walkable room, `manager_office`, reached through a walnut office door on
the Main Floor's right wall, just north of the cashier cage. The executive
assistant Vivienne Hale works the reception desk and hosts the House Contracts
board and the first-run tour. The Manager, Aurelio Vance, works the large desk:
he extends markers and gives the one-time wing invitations. All generation went
through the connected **Higgsfield MCP**. This pass spent **22.5 credits** on its
own jobs, confirmed against the account's transaction history (other agents
spent from the same account in the same window). Raw outputs are in
`assets/source/layered_v2/manager_office/` and are never modified.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Secretary concept (used) | `351fbaab-be0f-4dfe-a11f-9cd9806fd049` | `gpt_image_2_5` (flare), 2:3, high, 2k, `background: transparent` (1360x2048) | 3 (coordinator's session) |
| Secretary concept A (not used) | `0735f36d` (`secretary_a_0735f36d.png`) | same | 3 (coordinator's session) |
| Manager concept (used) | `2e32a226-fd54-40a1-8ab0-c468cac526fd` | same | 3 (coordinator's session) |
| Blocked concept: "executive secretary", leather pencil skirt with slit, tights | `6ad30438-7974-4aa1-8768-03a318d2a8de` | same; content filter (`nsfw`) | 0 (refunded) |
| Blocked concept: leather sheath with front zip, tights | `fadc1a78-260b-40c1-b61b-66b4f36224a9` | same; content filter (`nsfw`) | 0 (refunded) |
| Office background, empty | `3f847bd5-0413-4976-b159-a5ab59a55f94` | `gpt_image_2_5`, 16:9, high, 4k (3840x2160), High Roller upscale `280a7aef` as style reference | 4.5 |
| Main Floor office door paint-in | `ab622cff-dc2a-46fd-ad06-b5fcd2d0ac77` | `nano_banana_pro` (served as `nano_banana_2`), 1:1, 2k, edit of the 768x768 crop at virtual (768, 168) | 2 |
| Manager painted behind his desk | `66d71da7-6115-4fcc-91b8-d54d32ee3f81` | `nano_banana_pro`, 1:1, 2k, office crop (360, 12) plus the concept job as reference | 2 |
| Secretary painted behind reception | `c903628f-c985-4a91-8ceb-744972694a1d` | `nano_banana_pro`, 1:1, 2k, office crop (720, 240) plus the concept job as reference | 2 |
| Secretary "explaining with the tablet" | `811e3c5a-970f-4ec3-97a8-109d41d958b5`, cut-out `1cd03863-ae70-42cb-ba88-3e6c6a50aa3f` | `nano_banana_pro`, 2:3, 2k, concept job as reference, grey studio; then `remove_background` | 2 + 1 |
| Secretary "pointing the way" | `0e2f3f62-5d8e-4aad-ae15-53dbaa41f91e`, cut-out `b0ccc852-eb76-4b51-91dc-11d78ce374b8` | same | 2 + 1 |
| Manager "offering a marker" | `a1c93701-e2a2-4f2f-993e-f97f790078dd`, cut-out `9206ca94-e9f5-4d9f-8a08-ade16c7f88db` | same | 2 + 1 |
| Manager "raising his glass" | `2cfa02b4-0822-4227-b483-e1d602ea5520`, cut-out `a07c0ecd-46bc-4512-ba20-56986433dddc` | same | 2 + 1 |

Filter wording: "secretary" together with leather, tights and a slit was
blocked. The accepted wording was "personal assistant" or "executive assistant",
"stylish office fashion" and "fashion-editorial", with no tights, bows or slits.
The pose edits used "elegant executive assistant" and passed on the first try.

Processing:

- `python tools/art/bake_paint_ins.py tools/art/bake_manager_office.json` bakes
  the Manager and the secretary into
  `assets/production/environments/manager_office_background_v2.png`. Pixels
  change only inside the `ManagerDesk` and `Reception` solids, plus a head
  rectangle above each desk. They are the real people in the room. The player
  can never walk behind them.
- The office door patch is appended to `tools/art/bake_main_floor.json` (zone
  `OfficeDoor`, plus the top of the wall). The full Main Floor bake includes
  every agent's patches. The wall stands south of the VIP platform, so it
  correctly hides one rope post. The VIP lock sign stays visible above it.
- `python tools/art/floor_layers.py build data/floors/manager_office.json` (and
  `main_floor.json`) writes the foreground, collision and preview files.
- `python tools/art/prepare_characters.py tools/art/characters_office_staff.json`
  builds `assets/production/characters/staff/{secretary,manager}*.png`
  (1392x2080, clear corners). New optional keys in the tool:
  - `defringe` removes the grey studio matte that the background remover leaves
    on hair.
  - `grade_to` fits each person's face-skin statistics to their painted face in
    the office background, which gives a warm, lower-key room grade.
  - `match_to` first fits each pose's skin and head-to-torso colour to the base
    pose, then applies the same room grade. Every pose of one person shares one
    look.
  - Evidence: `tests/results/screenshots/office_fhd/cameo_grade_sheet.png` shows
    every graded cameo beside the painted face.
- In-game, the staff appear only as brass-framed portrait cameos inside the
  dialogue panel (head to mid-torso). A pose is mirrored whenever needed so the
  person faces the text. In the office, the panel sits beside the painted
  speaker with a brass pointer. No full-body figure is drawn over any room.

No text, logos or brand marks are in any generated image. The door plaque is
blank brass.

## 2026-09-19 Player character and eight-direction walk cycle

The old burgundy player blended into the burgundy carpet, and its atlas had no leg motion in the front and back views (the feet stayed the same width in every frame) and only one passing pose in the side view. The code also mapped the atlas columns backwards, so every side and diagonal walk faced away from the direction of travel. The column map is fixed in `src/floor/character_walk_atlas.gd` (clockwise N…NW, no mirroring). The new player is an original character in an ivory dinner jacket with a teal pocket square, chosen to read clearly on the burgundy, navy and green floors.

| Asset | Job | Model / settings | Credits |
| --- | --- | --- | --- |
| Player master (front, transparent) | `fdd4d071-023e-46fb-871d-bd85ed90851a` | `gpt_image_2_5`, 2:3, high, 2k | 3 |
| East walk sheet (4x2, 8 frames) | `919bbe86-e289-42e1-a719-b8c0126dd551` | `nano_banana_pro` (served as `nano_banana_2`), master as reference, 16:9, 2k | 2 |
| South walk sheet (4 frames) | `1fda4226-6171-4825-9941-935cf7d7df08` | same | 2 |
| North walk sheet (4 frames) | `1d559697-1f70-47cf-aa5f-c83d6e7100ec` | same | 2 |
| South-east walk sheet (4 frames) | `6fb1a3c6-f714-4008-9ec0-e52778380f0e` | same | 2 |
| North-east walk sheet (4 frames) | `485daf1c-4130-47ac-aa16-9f6487387b5f` | same | 2 |
| Passing-pose edit of five strides (rejected: legs came back unchanged) | `ad10073b-ff91-43ae-ac64-854eb828684e`, input upload `d91ba4d9-fb13-4c58-bb21-63385e19ded7` | `nano_banana_pro` edit, 21:9, 2k | 2 |

The generated sheets barely move the legs between frames, so `tools/art/build_player_walk.py` synthesises the cycle from their stride frames so that both legs move on every beat: for the front and back walks it mirrors the legs below the jacket hem to put the other foot forward and levels the feet for the passing beats; for the side and diagonal walks it slides each leg in under the hips (shoes keep their shape) for the passing beats. Passing beats rise by 1.2% of the figure height. It keys out the flat grey, scales each sheet once, puts the lowest foot on the atlas foot line and mirrors the east-side columns for the west. It writes `assets/production/characters/player_walk_v2.png` (8 x 4 cells of 240 px with a 9 px transparent gutter). Uploaded reference crops (`ref_*.png`) and the raw sheets are in `assets/source/layered_v2/walk_v2/`. In-engine proof: `tests/results/screenshots/walk_fhd/` (`walk_sheet.png`, a real-time `walk_loop.gif` from `tools/capture_walk.tscn`, and `walk_cycles.gif`, a close-up of every direction's four beats).

### Biomechanical gait sheets (second pass)

The first stride sheets still read as sliding, so each view was regenerated with an explicit gait brief: 8 phases (right heel-strike contact, down, passing with the swing knee bent about 60 degrees and the foot lifted, toe-off, then the same on the left), alternating arms, heel-to-toe roll, a vertical bob that is lowest at "down" and highest at "passing", and depth cues for the front and back views (a satin trouser stripe and a left-wrist watch let the model tell the legs apart). The master `fdd4d071` was the reference each time; `nano_banana_pro` (served as `nano_banana_2`), 16:9, 2k, 2 credits each.

| View | Job | Used frames (contact, passing, contact, passing) |
| --- | --- | --- |
| Back (walking away) | `1d78e945-9228-4cf4-923b-ac1ea24e06ea` | 1, 2, 4, 3 |
| 3/4 back (upper right) | `baacd1d6-86b3-4bb0-afe8-23a7a442aae6` | 1, 3, 4, 7 |
| Side profile (right) | `f150f73b-df03-4431-b9cb-41d524fe6a61` | 1, 2, 4, 3 |
| 3/4 front (lower right) | `18d33ca1-15ac-4aca-b999-b98b1f996e2e` | 1, 3, 4, 7 |
| Front (toward camera) | `a7dded37-6385-4426-8600-d38f2746626d` | not used: the body came out turned sideways and the "down" frames as crouches |

In every sheet the model drew the "down" phase as a crouching lunge and repeated the first row in the second, so the atlas keeps four beats per direction taken from the contact and passing frames. The straight-on front walk stays synthesised from the earlier front stride (`walk_south_1fda4226.png`) as described above. Raw sheets: `assets/source/layered_v2/walk_v2/gait_*.png`.

## 2026-09-19 Vivienne seated at reception

The executive assistant stood beside an empty chair at the Manager's Office reception, which read as pasted on. One `nano_banana_pro` edit (served as `nano_banana_2`, 1:1, 2k, 2 credits) of the current reception crop (upload `610e9570-d9c5-4d36-99b9-5fbf79d06065`, virtual crop [720,240,240,240]) with her concept `351fbaab-be0f-4dfe-a11f-9cd9806fd049` as the identity reference seats her in the burgundy chair behind the desk, writing in an appointment book beside her tablet and turning toward the entrance. Job `5b3ad23d-d8d3-45c9-a886-7437a27e8b8c`, saved as `assets/source/layered_v2/manager_office/office_secretary_seated_5b3ad23d.png`; it replaces the standing paint-in in `tools/art/bake_manager_office.json` (clip: `Reception` + [798,248,906,294] so the old standing figure is erased above the desk line). The dialogue pointer in `src/floor/office_host.gd` now aims at her seat (856, 304).

## 2026-09-19 Themed control-deck UI kit

One painted kit per cabinet theme for the redesigned control decks: a nine-slice panel frame, a nine-slice button plate and a round medallion (the How to Play button; its "?" is drawn in code because generated text is not allowed). All `gpt_image_2_5`, 1:1, high, 1k, `background: transparent`, 3 credits each (21 jobs, 63 credits). Several outputs leaked partial transparency into the centre, so every panel and button centre is repainted as one flat colour sampled just inside the rim; the manifest `assets/production/ui/kit/ui_kit.json` records the nine-slice margin and centre colour per piece. Raw outputs: `assets/source/layered_v2/ui_kit/`.

| Theme | Panel | Button | Medallion |
| --- | --- | --- | --- |
| Elven Court | `7493e0c1-135a-40a6-8ffc-8023bda75230` | `6a4a5246-607f-461d-a7cc-913718b3e26b` | `0452e67f-e09d-41d3-a299-d45efa594e5f` |
| Blackjack | `cf1fb4f0-704a-4dce-9ae6-a344a7e7da65` | `539ec5c4-ae45-46fe-871e-9799e35c24ce` | `ec6efef3-e0fa-4a34-8360-125ff73df719` |
| Hexbound Vault | `99bb325f-2c0b-4360-9194-494012cb66eb` | `0dfb3f25-91e1-469e-8300-618c5240b29d` | `e4836562-db6c-4465-8c5e-a05cb5e83a16` |
| Ruby Roulette | `02e6995f-6b58-4ca4-a8e4-b6af12e115a3` | `21fa9c4b-a260-41bc-9a5b-91d30d45fa51` | `a70b1410-82c0-4a70-ab3f-327d7e5e8b1b` |
| Texas Hold'em | `76b87d1c-6175-4657-9f85-b144b063ae5d` | `2ef1e098-8849-4853-a08a-449dad527263` | `30cc92f5-62ed-4c87-805f-76c68c2578ce` |
| Velvet Baccarat | `2df96987-ea9d-45a0-b5a6-78fb1cf0dd57` | `61a81b7b-a92f-4d17-bd14-3af5a1834d38` | `ac1f7647-13e3-4038-9672-6d7bfa39739a` |
| Match Point | `5ea9369d-d44b-4dfa-9e67-f9bb9abb3a5a` | `a7af954d-2d99-4525-aded-a4b2f16d8b51` | `9b864a24-2bb3-4487-b69b-0ea7a2d2d475` |

## 2026-09-20 Harlequin Masquerade (Upgrade Cluster, cluster-pays grid)

The theme for the new `upgrade_cluster` cabinet: a carnival-theatre machine whose
harlequin diamond motif matches the cluster grid. All raw outputs are Higgsfield
transparent PNGs (or, for the four pose variants, opaque renders on a studio grey)
and live in `assets/source/layered_v2/harlequin/`. They are never modified.

Production files are derived by `tools/art/prepare_harlequin.py` (stage dressing,
tiles, sidekicks and the pose cut-outs) and
`tools/art/prepare_characters.py tools/art/characters_harlequin.json` (de-fringe,
head-registered alignment onto the shared 1392×2080 canvas, alpha clean, pad).

| Asset | Job | Production file |
| --- | --- | --- |
| Hostess master (identity reference for the poses) | `34997eda-22fa-4044-bba1-2c66a8d4918d` | `characters/hosts/harlequin_hostess.png` |
| Pose: presenting | `75558280-d677-4cb3-90b3-1d4ae24b3c1c` | `characters/hosts/harlequin_hostess_present.png` |
| Pose: celebration | `7362e4c2-d2fd-4581-9e1e-7aadfb37bfc0` | `characters/hosts/harlequin_hostess_cheer.png` |
| Pose: mock pout | `fdb0da89-aecc-4235-9b4b-857fffd3cbdd` | `characters/hosts/harlequin_hostess_pout.png` |
| Pose: mask raised | `fc5e136e-82b5-4f83-8dc7-c51a4dd6baf0` | `characters/hosts/harlequin_hostess_mask.png` |
| Stage backdrop (3840×2160, no people) | `17738331-3f89-4eb5-9d7c-401ddf18ba13` | `harlequin/harlequin_stage_backdrop.png` |
| Grid frame | `7225de82-fb67-4443-aed3-356a8e37ac8d` | `harlequin/harlequin_grid_frame.png` |
| Multiplier bar plate | `65c9ff3f-2228-4bde-b2ee-29ffb4b8fd8a` | `harlequin/harlequin_multiplier_bar.png` |
| Celebration crest (blank ribbon) | `a3842cf0-ff12-4248-a2e4-c412a259b76d` | `harlequin/harlequin_crest.png` |
| Gem shard sheet (4×4) | `d4408a2c-9bcb-4132-b75b-c4001cc2a618` | `harlequin/harlequin_shards.png` |
| Tile: emerald diamond | `bcf3e691-3c0e-4f07-97e8-b0aecb9bd8b0` | `harlequin/harlequin_tile_gem_green.png` |
| Tile: rose diamond | `aea5de95-6ea1-4b04-8c53-1480ab9292cc` | `harlequin/harlequin_tile_gem_pink.png` |
| Tile: amethyst diamond | `cea0179e-9a3c-4c9d-9bd7-63f95bbaa6cd` | `harlequin/harlequin_tile_gem_violet.png` |
| Tile: pearl diamond | `b40952f0-5e2f-4fec-ae74-01dfd5e1016c` | `harlequin/harlequin_tile_gem_ivory.png` |
| Tile: masquerade mask | `48067704-e9b3-4d69-9c4d-749a05459eb0` | `harlequin/harlequin_tile_mask.png` |
| Tile: jester hat | `080010b9-53a8-494f-bdae-3560852d34ff` | `harlequin/harlequin_tile_jester_hat.png` |
| Tile: carnival bells | `ab29c0c8-f8f9-4f0a-9ec7-a4332d6b066f` | `harlequin/harlequin_tile_bells.png` |
| Tile: theatre ticket | `cac2cc55-fe38-472f-b0db-7265a32c7c96` | `harlequin/harlequin_tile_ticket.png` |
| Sidekick: pink jester | `f098eadd-e909-4fd3-bf89-ad8013acc57a` | `harlequin/harlequin_sidekick_pink.png` |
| Sidekick: green jester | `f93b2e9d-3554-4e25-ba56-5c69d4b8bf5c` | `harlequin/harlequin_sidekick_green.png` |

### Processing notes

**The studio grey could not be keyed by distance.** The four pose renders carry a
warm vignette that swings the background by more than 60 levels corner to centre,
*and* a wall-to-floor step with a painted cast shadow, so no single threshold and no
fitted quadratic surface separated the figure cleanly (both were tried; the fitted
surface left the floor and shadow attached). What works is a property the two sides
do not share: the backdrop, the floor and the shadow are all near-neutral and
mid-toned, while her skin, jacket, hair and the harlequin stripe are warm or
saturated and her trousers and boots are far darker than any backdrop texel. The key
is therefore "near-neutral **and** mid-toned **and** reachable from a corner of the
frame without crossing the figure" — the connectivity test is what preserves the grey
that belongs to her, such as the folds in the ivory blouse.

**The presenting pose came back holding a chess board**, which has nothing to do with
this machine. It is erased by polygon on the raw canvas, before any rescaling, in
`ERASE` in `prepare_harlequin.py`; what is left is the open presenting palm the beat
actually needs. The polygon steps around her fingertips, so a few pixels of the
board's near edge survive on her fingers and read as a painted nail at runtime size.

**Tiles** are trimmed to their paint and re-centred in a 256 px cell at one visual
weight, so a narrow harlequin gem and a wide pair of bells carry the same weight on
the board without either touching a cell edge.

**No new generations were made for this pass.** The Higgsfield MCP server failed to
connect for the whole session (`CONNECTION_CLOSED`), so every asset here is one the
user supplied; nothing was regenerated or re-rolled. The one asset that would have
benefited — a presenting pose without the chess board — was solved by editing instead.

## Video walk cycle (player_walk_v3)

The three earlier attempts at the player's walk all failed for the same reason:
nothing in them was a real gait. Two were generated sprite sheets whose "frames"
barely moved the legs, and the third was a procedural leg rig bolted under a static
torso. This pass films the gait instead and samples it.

### The five Kling clips

One shot per authored facing, all of the same ivory-dinner-jacket player on a flat
mid-grey seamless plate, from `generate_video`, model `kling3_0`, mode `pro`, 5 s,
aspect `1:1`, sound off, `cfg_scale` 0.5, delivered at 1440x1440 / 24 fps (121
frames). Sources live in `assets/source/layered_v2/walk_v2/`.

| Facing | Job id | Start image media id | File |
| --- | --- | --- | --- |
| E (side, walking right) | `512bf8fa-456e-4c6a-9d27-1594fa2fce7d` | `3661051b-03df-44e2-a443-e191cfc1f0d9` | `video_side_512bf8fa.mp4` |
| S (toward the camera) | `4921f301-c4dd-4044-88fc-0ca9f6f9067c` | `f1b3f8f2-6d97-43ee-ada8-677f999a39c9` | `video_front_4921f301.mp4` |
| N (away from the camera) | `454b106f-8f4d-4f3c-9fb5-83a913400c6b` | `f19e1385-7337-4484-baf3-89dd1d3e69a2` | `video_back_454b106f.mp4` |
| SE (three-quarter front) | `55aa5bdd-4206-40dd-93dc-c8f5a119f5b8` | `a305d9a0-41aa-4bca-9ded-71f78595ad1a` | `video_front34_55aa5bdd.mp4` |
| NE (three-quarter back) | `4658ceb8-5be0-4e13-ada9-7cf19f63206a` | `385f6cf1-3119-477a-99d1-5fcac16a6424` | `video_back34_4658ceb8.mp4` |

The prompt asked for the gait by name rather than for "a walk cycle": *"clear heel
strike, the swing leg bending at the knee and passing the standing leg, toe-off,
arms swinging opposite to the legs, gentle up-and-down body bob. The camera tracks
smoothly alongside him so he stays centred in the frame at the same size the whole
time. Plain flat mid-grey seamless background, no floor texture, no shadows, no
other people, no cuts. Same outfit and face throughout."* Naming the landmarks is
what made the legs actually alternate, and asking for a tracking camera is what kept
the figure one size for long enough to cut a cycle out of it.

**Credits.** All five clips were generated in the preceding session. This pass
regenerated nothing -- every view came out usable -- so it spent 0 credits; the
balance read 1942.25 (`ultra`) both before and after.

### From clip to atlas

`tools/art/build_player_walk_video.py` writes
`assets/production/characters/player_walk_v3.png`: 8 facing columns
(N, NE, E, SE, S, SW, W, NW, clockwise from north) by 8 phase rows, 240 px cells
with a 9 px transparent gutter, 1920x1920. W, SW and NW are horizontal mirrors of
E, SE and NE, which also flips their footedness, as a mirrored walker's should.

1. **Key.** `key_out` from `build_player_walk.py` unmixes the flat grey. That alone
   leaves the soft ground shadow, which is the same grey darkened, so a second test
   marks every pixel lying on the backdrop's own line in RGB between 0.45x and 1.10x
   its brightness, and keeps only the part of that mask a border flood fill reaches.
   A grey fold inside the jacket therefore cannot punch a hole. Everything two pixels
   inside the silhouette is forced back to full alpha and its original colour,
   because a pure distance key reads the lapel piping and the shirt's shadow side as
   half transparent and unmixes their colour away; only the rim stays soft. Edge
   pixels are then de-fringed (alpha x1.18 - 34), which leaves 3.7% of the
   partial-alpha pixels near-neutral mid-tone and no visible halo over magenta.
2. **Find the cycle.** Three silhouette signals per frame: the feet's horizontal
   separation measured across three bands of the lower body (0.74, 0.84 and 0.90 of
   the figure height, so the back view's shoes and the front view's shins each get a
   band that shows the stride), and the signed offset of the lowest foot from the
   body axis. Each is flattened against a quadratic first, because the back view's
   legs overlap progressively as the model turns a few degrees over the clip and that
   slow slide buries the gait. A one-harmonic least-squares fit, scanned to a
   twentieth of a frame, gives the **step** period; the cycle is twice it. Fitting at
   the step rate rather than the cycle rate is what avoids the half/double ambiguity
   that made an autocorrelation of the footedness signal pick 16.7 frames for NE.
3. **Phase 0.** The crests of the fitted step wave are the contacts. Of the two in a
   cycle it takes the one where the fitted once-per-cycle footedness wave is high,
   i.e. the contact with the leading foot on the screen-right of the body axis.
4. **Sample.** Eight even phases, each snapped to the nearest real frame. Nothing is
   cross-faded, so no beat can morph. At a ~33-frame cycle the snap lands within 2%
   of the ideal phase.
5. **Stabilise.** Each frame is aligned on the centre of its head-and-collar band --
   the one part of the silhouette that tracks the body without the swinging arms'
   bias -- which removes the model's drift across the plate (up to 57 px in the back
   clip) while leaving the hips and shoulders free to sway 2-6 atlas px around the
   axis. Vertically the whole cycle shares one ground reference, so the natural bob
   survives: the head rises and falls 5-6 atlas px (1.4-1.7 virtual px) twice per
   cycle, lowest at the contacts on rows 0 and 4 and highest at the passing beats on
   rows 2 and 6.
6. **Scale.** One factor per view, to 200 px tall with the cycle's lowest sole on the
   foot line (cell centre + 110 px). Every column lands at 191-199 px.

| Facing | Clip | Steady window | Cycle (frames) | Source frames |
| --- | --- | --- | --- | --- |
| N | `video_back_454b106f` | 14-86 | 34.4 | 25, 30, 34, 38, 43, 47, 51, 56 |
| NE | `video_back34_4658ceb8` | 14-86 | 32.6 | 37, 41, 45, 49, 53, 57, 62, 66 |
| E | `video_side_512bf8fa` | 14-96 | 33.6 | 35, 39, 43, 47, 51, 56, 60, 64 |
| SE | `video_front34_55aa5bdd` | 14-76 | 32.9 | 16, 20, 24, 29, 33, 37, 41, 45 |
| S | `video_front_4921f301` | 14-66 | 28.5 | 36, 39, 43, 47, 50, 54, 57, 61 |

The windows end before the camera pushes in far enough for the shoes to reach the
bottom of the plate: past frame ~76 the front and three-quarter-front clips clip the
figure, and a clipped silhouette breaks both the ground reference and the gait
signals.

**Honest caveats.** The back view's foot separation is genuinely weak -- the legs
overlap for most of its cycle -- so its second contact (row 4) reads only a little
wider than its passing beats, and its phase is the least certain of the five; its
body bob and its row-0 contact are still in step with the rest. The front clip's
cycle is 28.5 frames against 33-34 for the others, so its footfall rate differs at
the source; phase-normalising to eight rows makes that invisible in game. Footedness
across views is matched by the fitted once-per-cycle wave, which is strong for E and
SE and faint for the two depth views, so which of N's or S's two contacts is "the
right heel" is arbitrary -- what is guaranteed is that every column starts on a
contact and passes on rows 2 and 6, which is what keeps turns from popping.

### Playing it back

`CharacterWalkAtlas.ACTIVE` is now `WALK_V3` (8 rows, idle row 2). The frame comes
from distance walked, never from a timer: `FloorAvatar.set_motion` takes the
displacement that actually survived collision, divides it by the avatar's scale and
advances `walk_cycles` by that over `CYCLE_DISTANCE`. Walking into a wall therefore
does not animate in place, and the soles stay locked to the carpet at any room scale.

`CYCLE_DISTANCE` is 41.0 virtual px, measured from the art rather than chosen: the
east contact frames plant their shoes 70.5 atlas px apart, a cycle is two of those
steps, and 141 x `GUEST_SCALE` (0.29) is 40.9. At `FloorController.SPEED` (88 px/s)
that is 2.15 cycles a second at avatar scale 1, and 1.4-1.6 at the scales the rooms
actually draw him -- a brisk but natural walk. `STRIDE_DEPTH` stays 0.75: the floor's
own foot ellipse squashes depth to 0.6, but the controller drives the same screen
speed in every direction, so a strict 0.6 would spin the depth walks up into a
scurry. Depth walks therefore slip a little; sideways walks do not slip at all.

Two robustness fixes came out of the capture rig. The walk pose is now held 0.18 s
after the last movement, and the gait only resets to the standing frame after 0.3 s
of actually standing still, so a single slow frame can no longer restart the stride
mid-walk. Before that, a capture frame that stalled on a 1920x1080 read-back was
resetting the phase every other step.

### Player scale against the painted adults

The player was measured against standing painted adults in each room's 4K
background, read off a virtual-coordinate grid. A drawn player is 200 x 0.29 = 58
virtual px tall at avatar scale 1, so the scale a room needs is the painted adult's
height in virtual px divided by 58.

| Room | Painted reference | Height and foot y | Implied scale |
| --- | --- | --- | --- |
| Main Floor | slots couple | 67 px at y=188 | 1.16 |
| Main Floor | vault couple | 71 px at y=215 | 1.22 |
| Main Floor | cashier waitress | 93 px at y=465 | 1.60 |
| Main Floor | lounge waitress | 90 px at y=477 | 1.55 |
| High Roller | reception hostess | 107 px at y=197 | 1.84 |
| High Roller | lounge waitress, bottom right | 100 px at y=445 | 1.72 |
| VIP | roulette couple | 72 px at y=215 | 1.24 |
| Manager's Office | the Manager (head count; his feet are behind the desk) | ~173 px at y=202 | ~2.98 |
| Manager's Office | desk front face read as a 0.75 m rule | ~132 px at y=195 | ~2.28 |

`data/floors/<room>.json` carries `avatar_scale_far` (top of the walk bounds) and
`avatar_scale_near` (bottom); `FloorRoomLayout.avatar_scale_at` lerps between them
from the foot y, and `FloorController._apply_avatar_scale` feeds the avatar its own
position every frame. New values:

| Room | far | near | Was |
| --- | --- | --- | --- |
| `main_floor` | 1.00 | 1.67 | 1.11 / 1.73 |
| `high_roller` | 1.85 | 1.75 | 1.80 / 1.80 |
| `vip` | 1.28 | 1.60 | 1.56 / 1.18 |
| `manager_office` | 2.60 | 3.20 | 2.45 / 1.30 |

Main Floor is a least-squares line through its four samples. The VIP and the office
ramps were **inverted** -- the player shrank as he walked toward the camera -- which
is most of why he read as tiny in those rooms; both now grow toward the near edge.
High Roller keeps a nearly flat ramp because its two references disagree with
perspective by only 7%, and in the wrong direction.

**Honest caveat: the backgrounds are not perspective-consistent.** The Manager and
the VIP bar hostess are painted as hero figures, larger than the same room's other
adults; the VIP elevator doors and the office bookcases imply adults far smaller than
the people standing next to them. Where sources disagree the calibration favours the
larger, so the player never reads as a child, and it favours adults standing on floor
the player can actually walk on. The office is the least certain of the four, because
it holds no standing adult with visible feet: 2.60 / 3.20 puts the player at 161 px
at the Manager's desk against the Manager's ~173, which reads as two adults, but it
is an estimate from a head count and a desk height, not a measurement.

Proof crops are in `tests/results/screenshots/walk_fhd/scale_*_after.png`, one per
room, from `tools/capture_walk.tscn --scale-check` (add `--legacy-scale` for the
before shot). In-engine walk proof is `walk_sheet.png` (8 facings x 8 phases),
`walk_loop.gif` (a real-time square walk around the spawn) and `walk_cycles.gif`
(one full cycle in each of the eight directions, cropped to the avatar and upscaled,
so a sliding sole would show as the carpet slipping under a planted foot).

### Progression and stats UI

The House standing kit was generated with **Higgsfield** `gpt_image_2_5` (1:1,
1k, transparent background) and processed by `tools/art/prepare_progression.py`
into `assets/production/ui/progression/` with a manifest, `progression.json`,
that records each piece's kind, nine-patch margin and flat centre colour.

| Piece | Job |
| --- | --- |
| Progress-bar track (brass rim, milled edge, stepped end caps) | `b2d793e1-c398-4c34-b73f-0e79876c8e74` |
| Progress-bar fill (brushed brass capsule) | `86e1fde1-d1a4-41d0-a537-4ea081f5ff3d` |
| Stats/ledger panel frame (brass double rule, fan corners, walnut inlay) | `2c0382a9-8ad7-4e78-ab2e-5a87b4f7d3a1` |
| Rank medallions, one row of five | `494570ad-98ef-417a-9142-ae90308d2649` |
| Deed and keys on a velvet cushion | `f92a6f07-142a-4c32-be38-120bfa767386` |
| Stat icon sheet, 4x2 | `029a8af5-834c-4c74-8935-f6f3e8b0576a` |

Processing, in the same shape as the glyph kit:

* The three nine-slice pieces are trimmed to their silhouette, any partial
  transparency inside is composited over the flat centre sampled just within the
  rim, and the bars have every column between their end caps replaced by the
  median column, so a horizontal stretch is exact. The track's flat channel is
  levelled to one colour; the fill is **not**, because its vertical brushed
  sheen is the only thing that stops the bar reading as a plain rectangle, and
  that axis is never stretched. The track also records the channel's inset
  (37 / 18 px), which is how `ProgressMeter` insets the fill instead of guessing.
* The medallion row and the icon sheet are split on their alpha gaps, cleaned on
  every solid part rather than the largest one (a flame is three strands, a
  laurel is two halves and a knot), then trimmed and centred on one square
  canvas each: 256 px for the six ranks, 128 px for the eight icons.
* **Five medallions were painted for six ranks.** Partner is the Owner key
  tinted to aged bronze (`PARTNER_TINT` in the prepare script), so the pure gold
  key stays Owner's alone. The manifest marks `rank_partner` as derived.
* The deed's parchment is deliberately blank; its wording is drawn in code.

Contact sheet: `tests/results/screenshots/ui_assets/progression_sheet.png`.
Every produced PNG has fully transparent corners and is imported with mipmaps,
so the 920 px bar master stays sharp at UHD while drawing 11-14 px tall on the
960x540 virtual canvas.

**The Higgsfield MCP was unavailable for part of this session** (the connector
reported `CONNECTION_CLOSED`), so no further pieces were generated after the six
above; the sixth rank was derived from an existing medallion rather than
generated, as noted.

## 2026-09-20 Forno d'Oro v2: the centred oven and the nine-stage bake

The first Forno screen was rejected. Three things were wrong with it, and all
three were art problems rather than code problems:

* the oven was painted off to the right, so the dial and the pizza hung over the
  middle of the counter attached to nothing;
* the pizza had exactly one painted state, browned by a colour tint, so the bake
  never actually looked like a bake;
* a drawn bake curve plotted the same multiplier the dial was already showing.

The curve is gone. The pizza is now the cabinet's real readout: it is made on
the counter during the countdown and then browns in the oven mouth, and the dial
under it carries the number. All `gpt_image_2_5`, high, `background: transparent`
except the backdrop. Raw outputs are in `assets/source/layered_v2/forno/` and are
never modified; production files come from `tools/art/prepare_forno.py`.

| Asset | Job | Production file |
| --- | --- | --- |
| Counter backdrop, oven dead centre, no people (16:9) | `7ac3c1fc-6e2e-4ff8-909f-a9a1e9bec2ed` | — |
| The same backdrop upscaled to 4K (`bytedance_image_upscale`) | `f9f4f802-c31d-483e-a9a6-eef799fee0f4` | `forno/forno_backdrop_v2.png` |
| Bake 6, the hero margherita (identity reference for the set) | `009638a4-b1fe-4163-94df-2e9906cfac0a` | `forno/forno_bake_6.png` |
| Bake 0, dough ball | `129dd089-0d92-4802-b29a-fc19c680a805` | `forno/forno_bake_0.png` |
| Bake 1, stretched base | `2df8e78d-3acd-4a1a-8525-e05a025c242e` | `forno/forno_bake_1.png` |
| Bake 2, sauced | `cb8c5df2-1700-405b-b21f-154c32cec80f` | `forno/forno_bake_2.png` |
| Bake 3, topped and raw | `fd0356a5-61fa-4e11-8a4f-b1c8e7304a59` | `forno/forno_bake_3.png` |
| Bake 4, early | `f93adda1-70e6-4ed8-a1be-6e340d10b29d` | `forno/forno_bake_4.png` |
| Bake 5, melting | `cec2e859-7501-42eb-9d49-6f43e5f2222a` | `forno/forno_bake_5.png` |
| Bake 7, deep | `e0098e96-1bb7-4872-8621-b9132ce21dca` | `forno/forno_bake_7.png` |
| Bake 8, burnt | `bdc071a8-f112-439b-a1e0-f1f0eef27889` | `forno/forno_bake_8.png` |

Stages 0-8 were generated from the hero with `image_references`, so every stage
is the same pizza. They are cut to one shared 512 px cell at **one shared scale**
taken from the widest piece, so the dough ball stays small and the finished pizza
stays large; sizing each stage to fill its own cell would have thrown the growth
away and made the dough read as big as the pizza.

Superseded but kept for provenance: `forno_backdrop.png` (the off-centre oven),
`forno_pizza.png` and `forno_burnt_pizza.png` (the single-state pizza), and
`forno_oven_gauge.png`'s drawn companion curve.

### Themed UI kit for the two new cabinets

The kit from 2026-09-19 covered seven themes. Forno d'Oro had no entry at all, so
its deck fell back to flat plates, and Harlequin Masquerade was borrowing the
Hexbound Vault's button and medallion. Both now have their own. Same recipe as
the original kit: `gpt_image_2_5`, 1:1, high, 1k, `background: transparent`.

| Theme | Panel | Button | Medallion |
| --- | --- | --- | --- |
| Forno d'Oro | `20d1f991-6c26-4083-a37b-490f049c97db` | `0f62cd34-1392-4006-a69f-5d5d8412827d` | `86317252-d873-4fa2-bec2-02123d441ef7` |
| Harlequin Masquerade | `b9ac3d1f-3261-419e-b648-4079f922ed60` | `0066278b-d563-4de1-aed0-66480817a886` | `2bde3eee-2456-40f9-9a0f-a69bcc90b275` |

## 2026-09-20 Main menu chevron rows

The menu was a badge, a prompt panel and one settings key. It became a list the
player walks, which needed a plate that reads as a row rather than a button: a
long burgundy chevron with a brass rim and a point on its right end.

Generated with `gpt_image_2_5`, 16:9, high, 1k, `background: transparent`, then
cut by `tools/art/prepare_ui_kit.py` into a nine-slice whose centre is repainted
flat so a stretched row does not bloom down its middle.

| Plate | Production file | Region | Patch margin |
| --- | --- | --- | --- |
| Row, at rest | `assets/production/ui/kit/menu_chevron.png` | `Rect2(0, 297, 1343, 129)` | 25 |
| Row, lit | `assets/production/ui/kit/menu_chevron_hot.png` | `Rect2(18, 291, 1315, 145)` | 37 |
| Selector arrowhead | `assets/production/ui/kit/menu_selector.png` | whole image | n/a |

Two plates rather than one tint: a lit row is a different painting -- brighter
rim, warmer face, a wider point -- and tinting the rest plate washes the brass
out instead of lighting it. The arrowhead is a separate sprite because it sits
*outside* the row's box, to the left of it, and moves between rows on focus.

The cyan focus ring is drawn by the engine over the top of whichever plate is
showing. It is mandated by `CLAUDE.md` for keyboard and controller focus and is
not part of the painted art.

## 2026-09-20 Corsair's Reach (the crash cabinet, re-themed)

Forno d'Oro was replaced. The maths, the id `core_overclock` and the verified
97% return are unchanged; everything the player sees was regenerated. The
Forno set is deleted -- see the superseded note at the end of its own section.

Generated with `gpt_image_2_5`. Cut and composed by
`tools/art/prepare_corsair.py`, which never modifies the raw outputs under
`assets/source/layered_v2/corsair/`. The job id is the hex suffix on each
source filename.

| Piece | Source | Production file |
| --- | --- | --- |
| Night sea | `sea_4k.png` | `corsair/corsair_sea.png` |
| Chart frame | `crash_frame_592335ce.png` | `corsair/corsair_frame.png` |
| Parrot, flight sheet | `parrot_flight_f4cd7a4a.png` | `corsair/corsair_parrot_flight.png` |
| Parrot, icon | `parrot_023a0f22.png` | `corsair/corsair_parrot.png` |
| Trail | `trail_9dbed124.png` | `corsair/corsair_trail.png` |
| Compass | `compass_13f114f4.png` | `corsair/corsair_compass.png` |
| Crest | `crest_2b1f476e.png` | `corsair/corsair_crest.png` |
| Deck trim | `deck_trim_317dbeed.png` | `corsair/corsair_deck_trim.png` |
| Wreck | `wreck_14c9dff1.png` | `corsair/corsair_wreck.png` |
| Ship, wake, foam | `ship_568a1063.png`, `wake_45c672bf.png`, `foam_79a94205.png` | `corsair_ship/wake/foam.png` |

### The crew

| State | Source |
| --- | --- |
| Ready | `crew_v3_ready_ea6f81cb.png` |
| Tense | `crew_v3_tense_033b6430.png` |
| Cheer | `crew_v3_cheer_96cada4d.png` |
| Wince | `crew_v3_wince_f2d4370c.png` |

**One frame holds both women per state.** That is the point: their reaction is
shared by construction, so the pair can never be caught feeling different things
about the same result. `prepare_corsair.py` then splits each frame down its
middle and stands each woman in her own narrow edge lane. Asking the generator
to place them in the lanes directly was tried and abandoned -- it cropped their
heads and drifted their costumes between states.

Rejected takes, kept for provenance:

* `crew_v2_captain_b6699072.png` and `captain_cutout.png` -- a tricorn hat that
  cropped the top of her head off at the frame edge.
* `crew_v2_nohat_0024d784.png` -- hat removed, but the two women were put in
  matching uniforms, which the user rejected: they are a crew, not staff.
* `payline_8140aa65.png` -- a drawn payline for the curve, superseded when the
  parrot became the line object and the trail was moved to live drawing in
  `core_overclock_flight.gd`.
* `ship_568a1063.png`, `wake_45c672bf.png`, `foam_79a94205.png` -- the ship and
  water, cut when the cabinet became one object climbing a line. The files are
  still built by the pipeline but nothing on the canvas reads them.

### The parrot is the line

The multiplier is drawn as a parrot climbing `exp(SHAPE * t)` with the glowing
trail laid live behind her, not as a dial. `FLAP_SECONDS` is 0.46 and
`BOB_PIXELS` is 5: a bird that beats faster than the eye can separate reads as
a vibrating sprite rather than flight, and without the rise and fall inside the
beat the wings move while the bird slides. `growth_per_second` went 0.40 to
0.12 in the same pass, so 2x takes 5.8 s instead of 1.7 -- that does not touch
the return, which is drawn before she leaves, only how long the nerve is held.
