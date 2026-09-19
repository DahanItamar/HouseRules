class_name CharacterWalkAtlas
extends RefCounted
## Exact layout and directional mapping for the gutter-safe walk atlas.

const COLUMNS := 8
const ROWS := 4
const CELL_SIZE := Vector2i(240, 240)
const CONTENT_SIZE := Vector2i(222, 222)
const GUTTER := Vector2i(9, 9)
# Source columns run counter-clockwise from north.
const DIRECTION_COLUMNS: Array[int] = [0, 7, 6, 5, 4, 3, 2, 1]


static func direction_index(facing: Vector2) -> int:
	if facing.is_zero_approx():
		return 4
	var clockwise_from_north := atan2(facing.x, -facing.y)
	return posmod(int(round(clockwise_from_north / (PI / 4.0))), 8)


static func region(direction: int, phase: int) -> Rect2:
	var cell := Vector2i(
		DIRECTION_COLUMNS[posmod(direction, DIRECTION_COLUMNS.size())],
		posmod(phase, ROWS)
	)
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE))
