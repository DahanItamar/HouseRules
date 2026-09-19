class_name RouletteBoardGeometry
extends RefCounted
## Exact layout geometry for the single-zero betting board, in board-local
## virtual pixels. Every betting node is one domain spot: number centres are
## straight-ups, shared edges are splits, crossings are corners, the bottom
## edge carries streets and six-lines, and the zero edge carries the zero
## splits, trios and first four. Presentation only; ids come from RouletteMath.

const CELL: float = 44.0
const HALF: float = 22.0
const COLUMNS: int = 12
const GRID_LEFT: float = 44.0
const GRID_RIGHT: float = GRID_LEFT + CELL * COLUMNS
const GRID_BOTTOM: float = CELL * 3.0
const DOZEN_TOP: float = GRID_BOTTOM
const OUTSIDE_TOP: float = GRID_BOTTOM + CELL
const SIZE := Vector2(GRID_RIGHT + CELL, OUTSIDE_TOP + CELL)
## Pointer tolerance around a line before an edge bet is chosen over a number.
const EDGE_SNAP: float = 7.0
const OUTSIDE_KINDS: Array[RouletteMath.BetKind] = [
	RouletteMath.BetKind.LOW,
	RouletteMath.BetKind.EVEN,
	RouletteMath.BetKind.RED,
	RouletteMath.BetKind.BLACK,
	RouletteMath.BetKind.ODD,
	RouletteMath.BetKind.HIGH,
]

## Each node: {"id", "position", "numbers", "rect"} (rect is empty for edges).
var nodes: Array[Dictionary] = []
var _index_by_id: Dictionary = {}

@warning_ignore("integer_division")
func _init(math: RouletteMath) -> void:
	_add_node(RouletteMath.spot_id(RouletteMath.BetKind.STRAIGHT, [0]), zero_rect(), math)
	for ly: int in range(1, 7):
		for lx: int in range(0, 24):
			var id := lattice_spot_id(lx, ly)
			if not id.is_empty():
				var rect := cell_rect(lx / 2, ly / 2) if lx % 2 == 1 and ly % 2 == 1 else Rect2()
				_add_node(id, rect, math, lattice_position(lx, ly))
	for row: int in range(3):
		var id := RouletteMath.group_spot_id(RouletteMath.BetKind.COLUMN, 2 - row)
		_add_node(id, Rect2(GRID_RIGHT, row * CELL, CELL, CELL), math)
	for dozen: int in range(3):
		var id := RouletteMath.group_spot_id(RouletteMath.BetKind.DOZEN, dozen)
		_add_node(id, Rect2(GRID_LEFT + dozen * CELL * 4.0, DOZEN_TOP, CELL * 4.0, CELL), math)
	for index: int in range(OUTSIDE_KINDS.size()):
		var id := RouletteMath.spot_id(OUTSIDE_KINDS[index])
		_add_node(id, Rect2(GRID_LEFT + index * CELL * 2.0, OUTSIDE_TOP, CELL * 2.0, CELL), math)


static func number_at(column: int, row: int) -> int:
	return column * 3 + 3 - row


static func cell_rect(column: int, row: int) -> Rect2:
	return Rect2(GRID_LEFT + column * CELL, row * CELL, CELL, CELL)


static func zero_rect() -> Rect2:
	return Rect2(0, 0, GRID_LEFT, GRID_BOTTOM)


@warning_ignore("integer_division")
static func number_rect(number: int) -> Rect2:
	if number == 0:
		return zero_rect()
	var column := (number - 1) / 3
	return cell_rect(column, 3 - (number - column * 3))


static func lattice_position(lx: int, ly: int) -> Vector2:
	return Vector2(GRID_LEFT + lx * HALF, ly * HALF)


## Domain id of the bet at lattice point (lx 0..23, ly 1..6), or "" if none.
@warning_ignore("integer_division")
static func lattice_spot_id(lx: int, ly: int) -> String:
	var kind := RouletteMath.BetKind.STRAIGHT
	var numbers: Array[int] = []
	var columns: Array[int] = [lx / 2]
	if lx % 2 == 0:
		columns = [lx / 2 - 1, lx / 2]
	var rows: Array[int] = [ly / 2]
	if ly == 6:
		rows = [0, 1, 2]
	elif ly % 2 == 0:
		rows = [ly / 2 - 1, ly / 2]
	for column: int in columns:
		for row: int in rows:
			if column >= 0:
				numbers.append(number_at(column, row))
	if lx == 0:
		numbers.append(0)
		if ly == 6:
			numbers = [0, 1, 2, 3]
	match [numbers.size(), ly == 6]:
		[1, false]:
			kind = RouletteMath.BetKind.STRAIGHT
		[2, false]:
			kind = RouletteMath.BetKind.SPLIT
		[3, false], [3, true]:
			kind = RouletteMath.BetKind.STREET
		[4, false], [4, true]:
			kind = RouletteMath.BetKind.CORNER
		[6, true]:
			kind = RouletteMath.BetKind.SIX_LINE
		_:
			return ""
	return RouletteMath.spot_id(kind, numbers)


func _add_node(id: String, rect: Rect2, math: RouletteMath, at: Vector2 = Vector2.INF) -> void:
	var spot := math.spot(id)
	assert(not spot.is_empty(), "Board node %s must be a domain spot" % id)
	var center := at if at != Vector2.INF else rect.get_center()
	_index_by_id[id] = nodes.size()
	nodes.append({"id": id, "position": center, "numbers": spot.numbers, "rect": rect})


func index_of(id: String) -> int:
	return int(_index_by_id.get(id, -1))


func node_position(id: String) -> Vector2:
	var index := index_of(id)
	return nodes[index].position if index >= 0 else Vector2.ZERO


## Where chips sit on a spot. Wide outside boxes keep their printed label clear
## by stacking chips toward the right-hand end of the box.
func chip_position(id: String) -> Vector2:
	var index := index_of(id)
	if index < 0:
		return Vector2.ZERO
	var rect: Rect2 = nodes[index].rect
	var at: Vector2 = nodes[index].position
	if rect.size.x >= CELL * 2.0 and not id.begins_with("red") and not id.begins_with("black"):
		at.x += rect.size.x * 0.5 - 18.0
	return at


## Next node in a direction, or -1 at the edge of the board. Vertical moves go
## to the nearest row first; horizontal moves stay in the same row. Boxes (the
## zero, dozens, columns, outside bets) count by their edges and spans, so a
## half-cell step never skips a box and never drifts into another row.
func neighbor(from_index: int, direction: Vector2i) -> int:
	if from_index < 0 or from_index >= nodes.size():
		return 0
	var origin: Vector2 = nodes[from_index].position
	var axis := Vector2(direction)
	var vertical := direction.y != 0
	var best := -1
	var best_key := Vector3(INF, INF, INF)
	for index: int in range(nodes.size()):
		var along := ((nodes[index].position as Vector2) - origin).dot(axis)
		if along < 4.0:
			continue
		var edge := _edge_distance(nodes[index], origin, axis, along)
		var span := _span_distance(nodes[index], origin, vertical)
		if not vertical and span > 4.0:
			continue
		var centre_offset := absf(((nodes[index].position as Vector2) - origin).cross(axis))
		var key := Vector3(snappedf(edge, 4.0), span, along + centre_offset * 0.01)
		if not vertical:
			key = Vector3(snappedf(edge, 4.0), along, centre_offset)
		if key < best_key:
			best_key = key
			best = index
	return best


## Boxes are the zero and the outside bets; number cells navigate as points.
static func _box(node: Dictionary) -> Rect2:
	var numbers: Array = node.numbers
	if numbers.size() >= 12 or (numbers.size() == 1 and int(numbers[0]) == 0):
		return node.rect
	return Rect2()


static func _edge_distance(node: Dictionary, origin: Vector2, axis: Vector2, along: float) -> float:
	var rect := _box(node)
	if rect.size == Vector2.ZERO:
		return along
	var near := rect.position if axis.x + axis.y > 0.0 else rect.end
	var gap := (near - origin).dot(axis)
	# A box the origin already overlaps on this axis is beside it, not ahead.
	return gap if gap >= 0.0 else along


## Sideways distance from the origin to a node's box (or centre, for edges).
static func _span_distance(node: Dictionary, origin: Vector2, vertical: bool) -> float:
	var rect := _box(node)
	var at: Vector2 = node.position
	if vertical:
		if rect.size == Vector2.ZERO:
			return absf(at.x - origin.x)
		return maxf(0.0, maxf(rect.position.x - origin.x, origin.x - rect.end.x))
	if rect.size == Vector2.ZERO:
		return absf(at.y - origin.y)
	return maxf(0.0, maxf(rect.position.y - origin.y, origin.y - rect.end.y))


## Node under a board-local pointer position, or -1 outside the board.
func hit_test(point: Vector2) -> int:
	if not Rect2(Vector2.ZERO, SIZE).has_point(point):
		return -1
	if point.y >= GRID_BOTTOM + EDGE_SNAP or point.x >= GRID_RIGHT:
		for index: int in range(nodes.size()):
			var rect: Rect2 = nodes[index].rect
			if rect.size != Vector2.ZERO and rect.has_point(point) and index > 0:
				if (nodes[index].numbers as Array).size() > 1:
					return index
		return -1
	if point.x < GRID_LEFT - EDGE_SNAP:
		return 0 if point.y < GRID_BOTTOM else -1
	var lx := _snap_axis((point.x - GRID_LEFT) / HALF, EDGE_SNAP / HALF, 23)
	var ly := _snap_axis(point.y / HALF, EDGE_SNAP / HALF, 6)
	return index_of(lattice_spot_id(lx, maxi(ly, 1)))


## Odd lattice values are cell centres; even values are lines, used only when
## the pointer is within `tolerance` of the line.
static func _snap_axis(value: float, tolerance: float, maximum: int) -> int:
	var line := int(round(value / 2.0)) * 2
	if absf(value - line) <= tolerance:
		return clampi(line, 0, maximum)
	return clampi(int(floor(value / 2.0)) * 2 + 1, 1, maximum)
