class_name CharacterWalkAtlas
extends RefCounted
## Layout, timing and directional mapping of the player's full-body walk atlas.
##
## Columns are the eight facings clockwise from north (N, NE, E, SE, S, SW, W, NW),
## every one authored (nothing is mirrored at runtime). Rows are the phases of one
## full walk cycle (two steps) in order. Cells are 240 px with a 9 px transparent
## gutter; the standing soles sit on FOOT_LINE (cell centre + 110 px).
##
## Each atlas generation is described by one entry below; switching the player to
## another generation is the single ACTIVE line.

## Built by tools/art/build_player_walk.py: contact, passing, contact, passing.
const WALK_V2 := {
	"path": "res://assets/production/characters/player_walk_v2.png",
	"rows": 4,
	"idle_row": 1,
	## Screen distance of one cycle walking sideways at avatar scale 1 (virtual
	## px): two steps of the east contact frames' ~67 px heel-to-heel stride
	## at GUEST_SCALE 0.29.
	"cycle_distance": 40.0,
}
## Built by tools/art/build_player_walk_video.py from the five Kling walk videos:
## eight evenly phased frames of one filmed cycle, starting at a heel contact
## (contacts on rows 0 and 4, passing beats on rows 2 and 6).
const WALK_V3 := {
	"path": "res://assets/production/characters/player_walk_v3.png",
	"rows": 8,
	"idle_row": 2,
	## Screen distance of one cycle walking sideways at avatar scale 1 (virtual
	## px): the east contact frames plant their shoes 70.5 atlas px apart, so a
	## cycle of two steps covers 141 atlas px, or 141 * GUEST_SCALE on screen.
	## Walking the avatar this far per cycle is what keeps the soles from
	## sliding; set_motion divides by the avatar's scale, so the lock holds in
	## every room.
	"cycle_distance": 41.0,
}
const ACTIVE: Dictionary = WALK_V3

const ATLAS_PATH: String = ACTIVE["path"]
const COLUMNS := 8
const ROWS: int = ACTIVE["rows"]
## Neutral standing frame: a passing beat, feet together under the body.
const IDLE_ROW: int = ACTIVE["idle_row"]
const CYCLE_DISTANCE: float = ACTIVE["cycle_distance"]
const CELL_SIZE := Vector2i(240, 240)
const CONTENT_SIZE := Vector2i(222, 222)
const GUTTER := Vector2i(9, 9)
const FOOT_LINE: float = 230.0
const DIRECTION_COLUMNS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
## Walking toward or away from the camera shows the stride foreshortened, so a
## cycle covers less screen distance vertically than sideways. The floor's own
## foot ellipse squashes depth to 0.6; this sits above that on purpose, because
## the controller drives the same screen speed in every direction and a strict
## 0.6 would spin the depth walks up to a scurry.
const STRIDE_DEPTH: float = 0.75


static func direction_index(facing: Vector2) -> int:
	if facing.is_zero_approx():
		return 4
	var clockwise_from_north := atan2(facing.x, -facing.y)
	return posmod(int(round(clockwise_from_north / (PI / 4.0))), 8)


## Unit screen vector at the centre of a facing column.
static func direction_vector(direction: int) -> Vector2:
	var angle := posmod(direction, 8) * PI / 4.0
	return Vector2(sin(angle), -cos(angle))


static func region(direction: int, phase: int) -> Rect2:
	var cell := Vector2i(
		DIRECTION_COLUMNS[posmod(direction, DIRECTION_COLUMNS.size())], posmod(phase, ROWS)
	)
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE))


## Screen distance of one full cycle at avatar scale 1 walking along `travel`.
static func cycle_distance(travel: Vector2) -> float:
	var direction := travel.normalized() if not travel.is_zero_approx() else Vector2.RIGHT
	return CYCLE_DISTANCE * Vector2(direction.x, direction.y * STRIDE_DEPTH).length()


static func is_mirrored(_direction: int) -> bool:
	return false
