# Claude execution brief: layered casino art and character direction

You are the lead environment artist, character artist, UI presentation designer,
and Godot integration engineer for **House Rules**. Work in the existing repository;
do not return only advice, mockups, or prompts. Generate the final assets, integrate
them, verify them in-engine, and commit each completed milestone.

## Non-negotiable outcome

Rebuild the casino presentation so characters look physically placed in the scene,
not pasted over a flattened background. Keep the visual identity of the current
casino floor, but deliver it as a layered composition:

1. A clean environment background with no people.
2. Separate transparent adult character assets placed above that background at
   authored anchors.
3. A transparent foreground/occlusion layer containing the fronts of tables,
   chairs, rails, couches, plants, cashier furniture, and other objects that should
   cover a character when the character walks behind them.
4. Collision polygons that follow the visible footprint of every solid object.
5. Unique adult hostess/dealer art for every mini-game, with the face, eyes, torso,
   hands, and body direction intentionally aimed at either the game board or the
   player as specified below.

Do not solve depth by baking people into the background. Characters must remain
separate so they can animate, be moved, and be correctly occluded.

## Required tools and source handling

- Use the available **Higgsfield MCP** image workflow for final environment and
  character generation when it is connected. If it is unavailable, use the best
  available image-generation tool and record that fallback in the generation log.
- Inspect the current imported art before generating replacements:
  - `assets/production/environments/casino_floor.png`
  - `assets/production/environments/high_roller_room.png`
  - `assets/production/environments/vip_room.png`
  - `assets/production/characters/patrons/`
  - `assets/production/characters/hosts/`
- Never overwrite source-generation outputs. Save approved production derivatives
  under `assets/production/` and preserve prompt/tool provenance in
  `docs/art/GENERATION-REPORT.md`.
- Assets must be sharp at FHD, QHD, and UHD. Environment masters should be at
  least 3840x2160. Full-body character masters should be at least 1024x1536.
- Transparent assets must contain real alpha. No black, white, green, or magenta
  matte may remain around hair, hands, clothing, glasses, cards, or champagne.
- No copyrighted casino brands, logos, watermarks, generated text, or fake UI.

## Main-floor layered deliverables

Preserve the current warm burgundy, walnut, and brass art-deco direction. Recreate
or carefully edit the same floor composition into these production assets:

- `assets/production/environments/casino_floor_background_v2.png`
- `assets/production/environments/casino_floor_foreground_v2.png`
- `assets/production/environments/casino_floor_collision_v2.png`
- `assets/production/environments/casino_floor_composite_preview_v2.png`

The preview must demonstrate the intended final composite but is not used as the
runtime collision source. The foreground file must be transparent except for real
object fronts. The collision image is a development reference mask; runtime uses
Godot polygons authored from the same silhouettes.

### Character placement rules

- Use a consistent foot/root anchor. The feet determine navigation and depth; the
  torso must never determine collision.
- Standing guests belong on open carpet beside an attraction, never centered on a
  machine, table, chair, plant, or painted object.
- Seated guests must align with the chair or couch perspective. Their hips must
  contact the seat, their feet must land naturally, and foreground furniture must
  cover the correct lower-body portion.
- Guests at a machine face the machine. Guests talking face one another. Guests at
  the bar face the counter or another guest. Do not make the whole room look at the
  player.
- Keep each machine title, reels/cards/grid, join ring, and approach lane readable.
- Do not place full-body portraits directly over cabinet artwork.
- Vary adult guests across gender presentation, age, hair, skin tone, body type,
  clothing, seated/standing pose, drink/empty hands, and gaze direction while
  retaining the same premium illustration style.
- Use restrained local idle motion only: breathing, a small head turn, a sip, a
  card/chip gesture, or conversation gesture. No rigid whole-body bobbing.

Update `src/floor/floor_controller.gd`, `src/floor/casino_patron.gd`, and the
foreground renderer as needed. Use y/depth ordering or explicit depth bands plus
the transparent foreground. The player and guests must disappear behind the
correct object edge and reappear in front when their foot anchor crosses it.

### Collision requirements

- Author collision from visible furniture footprints, not broad rectangles.
- Cover stairs/railings, all three main game islands, elevator structure, couches,
  tables, plants with large pots, cashier desk/rail, and bottom planter.
- Preserve a continuous walkable route from spawn to every playable cabinet,
  cashier, return route, and developer destination.
- Prevent high-delta tunnelling and slide along furniture edges.
- Add a developer collision-overlay toggle that shows walkable space, solid
  polygons, foot anchor, and interaction anchors without appearing in release mode.
- Never use an invisible blocker that contradicts the visible edge by more than
  four virtual pixels.

## Mini-game character assets

Every playable mini-game must have its own adult person with a unique face,
hairstyle, clothing, pose, and animation language. Reusing the main player or a
different mini-game's person is forbidden.

### Classic Slots

- Character: clearly adult blonde hostess in a bright gold or champagne dress;
  glamorous and tasteful, not explicit.
- Body direction: three-quarter pose turned toward the reel window.
- Face and eyes: alternate between watching the reels and acknowledging the player
  after a result; do not stare at the camera continuously.
- Hands: one hand may present the reels or rest near the cabinet; never cover reel
  symbols, payline, credits, total bet, result, lever, or Spin control.
- Animation beats: calm idle, anticipatory glance on spin, clear win reaction, and
  neutral reset. Reduced motion uses a static pose plus one bounded state cue.
- Save the approved transparent master as
  `assets/production/characters/hosts/slot_hostess_v2.png`.

### Blackjack

- Character: clearly adult professional dealer with a distinct face and uniform.
- Body direction: torso squared toward the table/player relationship, shoulders
  angled naturally for dealing.
- Face and eyes: look at the cards during deal/reveal, then briefly toward the player
  while awaiting Hit/Stand/Double. Do not permanently face the camera.
- Hands: the dealing hand must visually align with the real card travel lane. Keep
  the dealer outside the player/dealer card bounds and total badges.
- Animation beats: shuffle/rest, deal, hole-card reveal, player decision wait,
  dealer draw, win/loss acknowledgement, reset.
- Preserve presentation-only behavior; dealer animation must never mutate game
  math or settlement timing.
- Save the approved transparent master as
  `assets/production/characters/hosts/blackjack_dealer_v2.png`.

### Minefield Vault

- Character: clearly adult vault attendant/security concierge with a unique face,
  fitted formal uniform, keycard or clipboard, and no resemblance to the Slot or
  Blackjack hosts.
- Body direction: three-quarter pose turned toward the tile grid/vault board.
- Face and eyes: track the selected tile; glance toward the player only for cash-out,
  mine, or all-clear results.
- Hands: presentation hand may indicate the board but must never cover tiles,
  multiplier, mine selector, credit display, or Cash Out control.
- Animation beats: calm security idle, tile indication, safe acknowledgement, mine
  warning, cash-out presentation, reset.
- Save the approved transparent master as
  `assets/production/characters/hosts/vault_attendant_v2.png`.

## Room requirements

The Main Floor, High Roller Salon, and VIP Penthouse must be genuinely separate
visual destinations. The F1 developer menu must switch to the selected environment,
not merely move the avatar to another coordinate on the Main Floor.

- Each room needs its own background, foreground occlusion, collision set, spawn,
  return point, and developer label.
- A preview-only room must say so explicitly and must not show fake playable controls.
- Escape/B and a visible return control must return to the previous floor safely.
- Room switching must preserve wallet/save state and must not create a second player.

## UI composition constraints

- Preserve a 960x540 virtual canvas and verify native FHD, QHD, and UHD output.
- Do not add glow, bloom, gradient panels, floating labels, or giant interaction
  circles to hide placement problems.
- Use flat near-black surfaces, warm off-white text, brass structure, and a cyan
  focus border only for keyboard/controller focus.
- HUD panels must not cover people, interaction targets, or room navigation.
- Every control must remain inside TV-safe bounds and keep a minimum 44px target.

## Required implementation order and Git checkpoints

Complete and commit each step before starting the next:

1. `art: generate layered casino floor masters`
2. `fix: align floor characters and authored depth`
3. `fix: trace visible furniture collision`
4. `art: generate cabinet-directed host characters`
5. `feat: integrate directed dealer and hostess motion`
6. `test: add floor composition and collision regression coverage`
7. `build: refresh verified House Rules package`

Do not combine unfinished work into one giant commit. Never reset or discard existing
user changes. Push `main` only after the full release gate passes.

## Mandatory QA and acceptance criteria

- Capture Main Floor screenshots with the player above, below, left, and right of
  every major furniture island. Verify expected foreground coverage in each case.
- Capture each seated and standing guest at FHD and QHD. No guest may float, intersect
  a machine, or face an implausible direction.
- Capture Slot, Blackjack, and Vault in idle, active, result, and reduced-motion
  states. The correct unique person must appear and must not obstruct gameplay.
- Test all eight player movement directions, diagonal collision sliding, and high
  frame-delta movement.
- Test every developer-room button, room return action, and developer destination.
- Add automated assertions for alpha corners, source resolution, unique resource
  paths, protected gameplay rectangles, foreground-above-character ordering,
  destination walkability, and collision-boundary samples.
- Run the complete GUT suite and one-million-round RTP harness. Restore canonical
  elapsed-time-only RTP fixture values after the run.
- Rebuild `export/HouseRules.pck`, smoke-launch it with an absolute path, record its
  SHA-256, open the visible build for review, and report the exact commits.

The task is not complete because generated files exist. It is complete only when the
layered assets are integrated, collisions match the visible scene, characters look
grounded and correctly directed, tests pass, the package is rebuilt, and visual
captures prove the result.
