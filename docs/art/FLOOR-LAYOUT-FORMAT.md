# Floor room layout format

Each walkable room (Main Floor, High Roller Salon, VIP Penthouse) is authored once
as `data/floors/<room>.json`. Godot loads the same file at runtime
(`src/floor/floor_room_layout.gd`), and `tools/art/floor_layers.py` renders the
foreground, collision reference and composite preview from it. A room's depth and
collision data lives only in this file.

All coordinates are **virtual canvas pixels** (960×540). Background masters are
3840×2160, so one virtual pixel is exactly four master pixels.

## Zones, guests and the player

Every furniture group (a game island, a lounge, the cashier cage, a bar, a lift
lobby) is one **blocked zone**. Its polygon follows the visible rug, platform or
rail border. The player walks up to that edge but never enters it.

Guests exist **only inside blocked zones**, painted directly into the room by an
image-edit model and baked into the background (`tools/art/bake_paint_ins.py`,
one spec per room such as `tools/art/bake_main_floor.json`). The player can never
stand behind, in front of or among them, so baked guests never need runtime
depth. Each bake patch names the zones it may change, and only pixels inside
those polygons are replaced.

Occluders exist only where the player **can** walk behind an object: plants and
lamps along the back wall, the entrance planter, the cashier cage seen from the
aisle above it, rope posts, and similar.

## Fields

| Field | Meaning |
| --- | --- |
| `id`, `label` | Stable room id and the developer label shown on screen. |
| `preview_only` | `true` for rooms without playable games. The room says so on screen and shows no fake controls. |
| `background` | 3840×2160 environment with baked-in guests (output of the room's bake spec). |
| `foreground` | Transparent 3840×2160 layer holding only real object fronts. Built by `floor_layers.py build`. |
| `collision_reference` | Development mask: white = walkable, black = solid. Not used at runtime and excluded from the export. |
| `composite_preview` | Background with the foreground on top. Excluded from the export. |
| `foot_radius` | `[rx, ry]` foot ellipse. A position is walkable when this ellipse fits inside `walk_bounds` and touches no solid. |
| `spawn` | Where the avatar appears when entering the room. |
| `return_point` | Where the avatar stands when it comes back to this room. |
| `walk_bounds` | Outer polygon of the floor the avatar may stand on. |
| `solids` | `{name, points}` blocked zones following visible borders. Each edge must stay within four virtual pixels of the visible edge. |
| `occluders` | `{name, baseline, points, refine?}` depth pieces. `points` outline the part of the foreground this piece owns, and the foreground alpha supplies the exact silhouette. `baseline` is the y where the object meets the floor: when the player's feet are above the baseline, the object covers the player; when the feet are below it, the player draws in front. `refine: "foliage"` drops carpet showing between leaves. |
| `anchors` | Named interaction points (cabinet join spots, cashier, room exits). Each must be walkable and connected to `spawn`. |

## Workflow

1. Trace zones with `python tools/art/floor_layers.py grid <layout> <dir>` and
   check them with `overlay`.
2. Paint guests into crops of the clean upscale master with Higgsfield. Keep
   every person inside a zone, then run `python tools/art/bake_paint_ins.py <spec>`.
3. Run `python tools/art/floor_layers.py build <layout>` to rebuild the
   foreground from the baked background.
4. Run `python tools/art/floor_layers.py check <layout>`, which rejects
   destinations that are unwalkable or not connected to the spawn.
5. Run `tests/test_floor_composition.gd`.
