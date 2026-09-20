# Ambient life

Cheap, presentation-only motion that keeps the rooms and the cabinets from
reading as still paintings: lights that breathe, shade that drifts, a contact
shadow under the player and a few small accents. Nothing here reads or changes
gameplay state, the wallet or the save.

Everything is a pure function of the layer's `elapsed` clock, so a capture, a
test and the running game all sample the same frame for the same time.

## Rules this system holds itself to

| Rule | Where it is enforced |
| --- | --- |
| Light pools add at most `0.10` alpha | `AmbientLayer.POOL_ALPHA_CAP`, asserted in both ambience tests |
| Drifting shade darkens at most `0.08` | `AmbientLayer.SHADOW_ALPHA_CAP` |
| Sweeps (glints, rune shimmer) peak at `0.24` | `AmbientLayer.SWEEP_ALPHA_CAP` |
| Sparks (motes, fireflies) peak at `0.35` | `AmbientLayer.SPARK_ALPHA_CAP` |
| Reduced motion: pools hold at their average, everything moving disappears | `apply_motion_preference`, `sample_alpha_peaks` |
| No moving accent enters a protected gameplay rectangle | `moving_effect_bounds()` vs `tests/test_cabinet_ambience.gd::PROTECTED` |
| The layer draws under every gameplay node | `CabinetAmbience.attach` inserts directly above the backdrop |

The floor, the HUD and the menus keep the no-glow rule: pools, flicker and
shadow only. Glow and bloom are allowed **inside a cabinet screen**, and only
there.

## Floor rooms

`src/floor/floor_ambient_lights.gd` (`FloorAmbientLights`) is added by
`FloorController` as the `FloorAmbience` node and follows the `room_changed`
signal. Everything it draws is authored per room in `data/floors/<room>.json`,
measured on that room's 4K background in 960x540 virtual pixels:

```jsonc
"lights": [                       // one per painted lamp, sconce or chandelier
  {"at": [77, 336], "radius": 36, "squash": 0.72, "color": "ffd49a",
   "strength": 0.076,             // clamped to POOL_ALPHA_CAP
   "period": 4.8, "phase": 0.0,   // 3-7 s, a different phase per light
   "flicker": 0.3,                // +-30% of strength
   "motes": 4}                    // optional dust rising through the beam
],
"ceiling_shadows": [              // 1-2 per room, over open carpet
  {"at": [480, 300], "radius": 50, "squash": 0.5, "lobes": 4,
   "spin_period": 0.0, "sway": [18, 9], "sway_period": 13.0, "alpha": 0.05}
],
"glints": [                       // a slow sweep across brass signage
  {"name": "salon_sign", "at": [420, 34], "size": [120, 22],
   "interval": 11.0,              // clamped to 8-15 s
   "phase": 0.0, "front": false}  // true = glint above the depth layer
],
"screen_sparkles": [[336, 148]]   // painted cabinet screens catch a rare spark
```

The contact shadow under the player is not authored: it reads
`FloorController.avatar_position` and the avatar's public walk state, stretches
a little along the stride and is pushed away from the nearest lamp. It never
moves or changes the avatar.

Draw order: `shade_canvas` (ceiling shade, contact shadow, wall glints) sits on
the room under the depth layer, so furniture fronts and people cover it;
`light_canvas` (pools, motes) sits above the depth layer, because lamp light
falls on people and furniture fronts alike. Both stay under every prompt and
HUD layer, and light that falls inside the top HUD band is dimmed by exactly
what the band lets through.

## Cabinets

`src/ui/ambient/cabinet_ambience.gd` maps a cabinet id to a backdrop node and an
`AmbientLayer` subclass, and `MiniGame` calls `CabinetAmbience.attach(panel)`
once the panel's art exists. Shipped layers:

| Cabinet | Layer | Effect |
| --- | --- | --- |
| `slot_classic` (Elven Court) | `elven_court_ambient.gd` | fireflies in the forest margins |
| `minefield_vault` (Hexbound Vault) | `hexbound_vault_ambient.gd` | rune shimmer sweeping the carved stone |
| `blackjack`, `poker` | `card_table_ambient.gd` | table-lamp flicker with a felt light pool |
| `roulette` (Ruby Roulette) | `roulette_ambient.gd` | chandelier sweep over the wheel |
| `baccarat` (Velvet Baccarat) | `baccarat_ambient.gd` | candle flicker |
| `match_point` | `match_point_ambient.gd` | cloud-shadow drift |

### Hook: adding a layer for a new cabinet

Upgrade Cluster ("Harlequin Masquerade") and Core Overclock ("Forno d'Oro") are
being built in parallel and have no layer yet. To add one, nothing outside your
own files needs to change except a single row:

1. Write `src/ui/ambient/<theme>_ambient.gd` as `extends AmbientLayer`. Use
   `add_pool(...)` for anything that only breathes, or override `_draw_light`
   and `_draw_shade` for your own accents (`draw_pool`, `draw_pool_clipped` and
   `draw_spark` are provided). Keep every value a pure function of `elapsed`,
   and return `Vector3.ZERO`-equivalent / draw nothing when `reduced_motion` is
   true.
2. Override `sample_alpha_peaks(at_time)` to report your peak alpha per family
   (`"pool"`, `"shadow"`, `"sweep"`, `"spark"`) and `moving_effect_bounds()` to
   report every rectangle a moving accent can touch. The tests use both.
3. Add one row to `CabinetAmbience.LAYERS`:
   `&"<cabinet_id>": {"anchor": "<BackdropNodeName>", "script": <PRELOAD>}`.
   `anchor` is the name of the backdrop node inside the panel's `CabinetArt`
   root; the layer is inserted directly above it, so everything the panel adds
   afterwards draws over it.
4. Add your cabinet id to `CABINETS` in `tests/test_cabinet_ambience.gd` and its
   protected gameplay rectangles to `PROTECTED` there. The suite then checks
   alpha caps, reduced motion, layer order and gameplay clearance for you.

`backdrop_texture` is set for you before `place_overlays(art)` is called, if your
layer defines it, so a sweep can be masked by the painted art underneath.

## Captures

```text
# rooms and cabinets, 3 s at 25 fps
Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 25 \
    res://tools/capture_ambient.tscn -- --capture-size=1920x1080 \
    --frames-dir=<dir> --frames=75 --stills
python tools/art/assemble_ambient_gifs.py <dir> --fps 25 --width 640
```

Results live in `tests/results/screenshots/ambient/`. Add `--reduced-motion` for
the control run, and `--targets=a,b,c` to capture a subset.
