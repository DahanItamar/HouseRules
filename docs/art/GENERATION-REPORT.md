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

