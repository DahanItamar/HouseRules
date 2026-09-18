# Asset Specifications

> Generation-ready briefs for every v1 asset. Written for the Higgsfield MCP server, usable by hand or by any image generator.
> Companion to `docs/SPEC.md` §4 (`assets/`) and Assumption 6.

---

## 1. Read this before generating anything

Image generators produce raster output at their own resolution and their own colours. They do not produce pixel art at an exact frame size in a locked palette, whatever the prompt says. Every generated asset therefore goes through a fixed three-step pipeline, and the specs below assume it:

```
GENERATE → DOWNSAMPLE (nearest-neighbour, exact target size)
         → QUANTIZE   (to HOUSE-RULES-16, no dithering)
         → CLEANUP    (manual: edges, stray pixels, transparency)
```

**Where generation works:** large static elements. Backdrops, cabinet bodies, felt surfaces, single-frame symbols, character portraits, promotional art. Anything where a 4-pixel difference from the brief does not matter.

**Where generation fails, and why each asset below is marked HAND-PIXEL:**

- **Multi-frame animation.** Frame-to-frame consistency is the specific thing these models are worst at. An 8-frame explosion generated as 8 images will not read as one explosion.
- **Small sprites.** Below roughly 64×64, downsampling destroys more than it preserves. Hand-pixelling a 24×32 chip is faster than fixing a generated one.
- **Repeated elements that must match.** 52 card faces must share one visual system exactly. Generation will produce 52 near-misses.

Marks in every cabinet doc's §11 follow these rules. Roughly 60% of v1 assets are GENERATE; the rest are hand work, and no prompt changes that.

---

## 2. The palette — `HOUSE-RULES-16`

Sixteen colours. Every asset quantizes to exactly this set. Neon sits on near-black, with a contrast floor enforced because the target handheld is a **500-nit IPS panel that washes out dark palettes in daylight** (`SPEC.md` §8).

| # | Hex | Role |
| --- | --- | --- |
| 00 | `#0B0A12` | Void — the darkest value, backgrounds |
| 01 | `#1A1826` | Shadow |
| 02 | `#2D2A3E` | Surface — panels, cabinet bodies |
| 03 | `#474259` | Surface light — raised edges |
| 04 | `#6B7280` | Chrome — metal, shoe, trim |
| 05 | `#A9A4BF` | Text secondary |
| 06 | `#E8E6F0` | Text primary |
| 07 | `#FFFFFF` | Specular highlight only — never a fill |
| 08 | `#FF3D7F` | Neon magenta — the house colour |
| 09 | `#00E5FF` | Neon cyan — the second accent |
| 10 | `#9D4DFF` | Neon purple |
| 11 | `#FFD23F` | Gold — **chips and currency, this colour only** |
| 12 | `#FF8A3D` | Orange — warnings, heat |
| 13 | `#39FF6A` | Green — wins, safe tiles |
| 14 | `#FF4D4D` | Red — losses, mines, danger |
| 15 | `#123A2E` | Felt green — table surfaces only |

### Rules that outrank aesthetics

1. **Gold (`#FFD23F`) means currency and nothing else.** If it is on screen, it is about chips.
2. **Neon is decoration layered over legible shapes, never the thing carrying the information.** A number rendered in glow is a number the player cannot read in sunlight. Draw it in `#E8E6F0` or `#FFD23F` and put the glow behind it.
3. **Critical UI text keeps ≥4.5:1 luminance contrast against its background.** `#E8E6F0` on `#0B0A12` or `#2D2A3E` both pass comfortably. `#9D4DFF` on `#2D2A3E` does not — never use it for text.
4. **`#FFFFFF` is a highlight, never a fill.** Pure white flats look wrong against a 16-colour ramp.

---

## 3. Global generation settings

Applied to every GENERATE asset. Append to each prompt.

**Style suffix**
```
16-bit pixel art, flat even lighting, no perspective distortion, crisp hard pixel edges,
limited 16-colour palette, dark neon casino aesthetic, centered composition,
transparent background
```

**Negative prompt** (universal)
```
blur, antialiasing, soft gradient, photorealistic, 3D render, drop shadow, depth of field,
text, letters, numbers, watermark, signature, JPEG artifacts, busy background
```

**Post-process** (universal)
```
nearest-neighbour downsample to exact target dimensions → quantize to HOUSE-RULES-16,
no dithering → manual edge and transparency cleanup
```

---

## 4. Asset briefs

### 4.1 Environment

**`vault_backdrop`** — 960×540, 1 frame, GENERATE
*The single best generation candidate in v1: large, static, atmospheric, no precision required.*
```
PROMPT: interior wall of a retro casino vault, rows of brushed-steel deposit boxes,
magenta and cyan neon tube lighting along the ceiling, deep near-black shadows,
atmospheric haze, symmetrical, empty of characters
```

**`casino_floor_tileset`** — 16×16 per tile, 24 tiles, GENERATE
```
PROMPT: top-down casino floor tileset, patterned carpet in deep purple and magenta,
worn edges, seamless tiling, plus marble walkway variants and wall-edge pieces
```

**`felt_table`** — 960×280, 1 frame, GENERATE
```
PROMPT: top-down blackjack table surface, dark green felt, subtle fabric texture,
faint painted betting arc, worn at the edges, no text, no cards, no chips
```

### 4.2 Cabinets — floor view and front view

Each machine needs a 48×48 top-down sprite for the floor and a large front-facing body for its cabinet screen.

**`slot_classic_body`** — 320×400, 1 frame, GENERATE
```
PROMPT: front-facing retro slot machine cabinet, chrome body, magenta and cyan neon
tube trim outlining the frame, three empty circular reel windows, a pull arm on the
right side, dark background, symmetrical, no symbols in the windows
```

**`blackjack_table_floor`** — 64×48, 1 frame, GENERATE
```
PROMPT: top-down view of a semicircular blackjack table, dark green felt, chrome rail,
dealer position at the flat edge, small neon underglow
```

**`vault_door_floor`** — 48×48, 2 frames, GENERATE
```
PROMPT: top-down view of a heavy circular vault door set into the floor, brushed steel,
cyan indicator light. Frame 2: indicator light off
```

### 4.2a Cashier and wing transitions

**`cashier_cage`** — 128×96, 1 frame, GENERATE
```
PROMPT: top-down view of a casino cashier cage, brass window bars, marble counter,
warm gold interior light spilling onto the carpet, small teller booth, no characters
```

**`cashier_panel_frame`** — 400×220, 1 frame, GENERATE
```
PROMPT: ornate brass and dark wood panel frame for a casino cashier window, art-deco
corners, empty centre, magenta neon edge lighting, front-facing, symmetrical
```

**`staircase_up`** — 96×128, 1 frame, GENERATE
```
PROMPT: top-down view of a carpeted casino staircase ascending, red velvet rope across
the base, brass stanchions, magenta neon strip along each step edge
```

**`elevator_doors`** — 80×112, 3 frames, GENERATE
```
PROMPT: top-down view of polished brass elevator doors set into a casino wall, art-deco
chevron inlay, small call panel. Frames: closed, lit, open
```

**`waypoint_arrow`** — 24×24, 4 frames, HAND-PIXEL
Screen-edge pointer toward the Cashier (AC-049). Small, animated, must read at the edge of a 7" panel — hand work.

### 4.3 Slot symbols — 64×64, 1 frame each, GENERATE

One prompt per symbol, all sharing the style suffix. Generate as a set in one session so they share a visual language.

| Asset | Prompt core |
| --- | --- |
| `sym_cherry` | a pair of glossy red cherries on a green stem, thick dark outline |
| `sym_lemon` | a single bright yellow lemon, thick dark outline |
| `sym_bell` | a golden liberty bell with a highlight on the shoulder |
| `sym_bar` | a chunky rectangular BAR ingot, gold and chrome, horizontal banding |
| `sym_seven` | a lucky number seven in bold neon magenta with a cyan outline |
| `sym_diamond` | a faceted cyan diamond with a white specular highlight, the most visually valuable symbol of the set |

> `sym_diamond` is the 500× symbol. It must be instantly distinguishable from every other symbol at 64×64 on a 7" screen — brightest value, highest saturation, most distinct silhouette.

### 4.4 Characters

**`dealer`** — 128×160, 4 poses, GENERATE + heavy cleanup
```
PROMPT: pixel art casino dealer behind a table, waist-up, sharp black waistcoat,
white shirt, bow tie, neutral unreadable expression, front-facing, symmetrical
POSES: idle (hands resting) · dealing (one arm extended) · revealing (turning a card) ·
       reacting (slight head tilt)
```
Generate the four poses separately and hand-align them to a shared skeleton in cleanup. They will not line up on their own.

**`player_avatar`** — 32×48, 8 frames, HAND-PIXEL
Four directions × 2-frame walk cycle. Too small and too motion-critical to generate.

### 4.5 Hand-pixel list

No prompts — these are hand work. Listed so the asset budget is honest.

| Asset | Dimensions | Frames | Cabinet |
| --- | --- | --- | --- |
| Card faces | 56×80 | 52 | Blackjack |
| Card slide | 56×80 | 4 | Blackjack |
| Reel blur strip | 64×192 | 4 | Slot |
| Slot arm | 32×96 | 6 | Slot |
| Win flash overlay | 960×540 | 3 | Slot |
| Tile reveal | 56×56 | 5 | Minefield |
| Detonation | 96×96 | 8 | Minefield |
| Snap cursor | 64×64 | 2 | Minefield, shared |
| Cash-out panel frame | 176×80 | 3 | Minefield |
| Player avatar | 32×48 | 8 | Floor |
| Controller glyphs | 16×16 | 24 | Shared — Xbox + keyboard sets |

**The 52 card faces are the largest single piece of hand work in v1.** They are also the hardest readability problem (`docs/cabinets/blackjack.md` §9): a 10 and a K must be distinguishable at 8px on a 7" panel at arm's length. Budget accordingly, and prototype three ranks before committing to all 52.

---

## 5. Fonts

A pixel font with a hard legibility floor, not a decorative one. Requirements:

- Renders cleanly at **8px and 16px** in base-viewport space with no antialiasing (AC-042)
- Digits `0`–`9` are unambiguous at 8px — `6`/`8`, `3`/`8` and `1`/`7` are the pairs that fail
- Full Latin coverage, and the file kept separable so a Hebrew-capable face can be swapped in later without a layout rewrite (`SPEC.md` §2: localization-ready)

Numerals carry chip balances, stakes and multipliers — the three things a player checks constantly. If a digit is ambiguous at 8px, the font is wrong regardless of how it looks.

---

## 6. Checklist before an asset is accepted

- [ ] Exact target dimensions, no off-by-one
- [ ] Every pixel is one of the sixteen palette colours
- [ ] Transparent background where specified, with no halo fringe
- [ ] No antialiased edges
- [ ] Gold `#FFD23F` appears only on currency
- [ ] Legible at 1× (viewed at 50% on a desktop monitor ≈ handheld viewing conditions)
- [ ] Animation frames align on a shared origin
