class_name BaccaratBeadRoad
extends Control
## The bead road: every coup of this visit as one bead, filled top to bottom
## and then left to right, the way a table's bead plate is kept. Banker beads
## are crimson "B", Player sapphire "P" and Tie jade "T"; a pearl dot at the
## top-left marks a Player pair, at the bottom-right a Banker pair. When the
## plate is full the oldest column drops off. Holds only what it is shown.

const PLATE_SIZE := Vector2(276, 134)
const ROWS: int = 6
const COLUMNS: int = 15
const CELL: float = 16.0
const GRID_ORIGIN := Vector2(18, 32)
const BEAD_RADIUS: float = 7.0

## Each entry: {"winner": int, "player_pair": bool, "banker_pair": bool}.
var beads: Array[Dictionary] = []
var _caption: Label
var _counts: Label


func _init() -> void:
	name = "BaccaratBeadRoad"
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_caption = BaccaratStyle.label(self, Rect2(12, 7, 110, 20), 13, BaccaratStyle.PEARL_MUTED)
	_counts = BaccaratStyle.label(self, Rect2(118, 7, 146, 20), 13, BaccaratStyle.PEARL)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	refresh()


func push(coup: Dictionary) -> void:
	(
		beads
		. append(
			{
				"winner": int(coup.get("winner", BaccaratRules.Winner.TIE)),
				"player_pair": bool(coup.get("player_pair", false)),
				"banker_pair": bool(coup.get("banker_pair", false)),
			}
		)
	)
	while beads.size() > ROWS * COLUMNS:
		beads = beads.slice(ROWS)
	refresh()


func count_of(winner: int) -> int:
	var total: int = 0
	for bead: Dictionary in beads:
		if bead.winner == winner:
			total += 1
	return total


func refresh() -> void:
	if _caption == null:
		return
	_caption.text = tr("BACCARAT_BEAD_ROAD")
	_counts.text = (
		tr("BACCARAT_ROAD_COUNTS")
		% [
			count_of(BaccaratRules.Winner.BANKER),
			count_of(BaccaratRules.Winner.PLAYER),
			count_of(BaccaratRules.Winner.TIE),
		]
	)
	queue_redraw()


func bead_center(index: int) -> Vector2:
	@warning_ignore("integer_division")
	var column: int = index / ROWS
	var row: int = index % ROWS
	return GRID_ORIGIN + Vector2(column * CELL + CELL * 0.5, row * CELL + CELL * 0.5)


func _draw() -> void:
	BaccaratStyle.draw_plate(self, Rect2(Vector2.ZERO, size), Color(BaccaratStyle.LACQUER, 0.95))
	var grid := Rect2(GRID_ORIGIN, Vector2(COLUMNS * CELL, ROWS * CELL))
	draw_rect(grid, BaccaratStyle.LACQUER_DEEP)
	for column: int in range(COLUMNS + 1):
		var x := grid.position.x + column * CELL
		draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), BaccaratStyle.PEARL_FAINT)
	for row: int in range(ROWS + 1):
		var y := grid.position.y + row * CELL
		draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), BaccaratStyle.PEARL_FAINT)
	var letters := [tr("BACCARAT_BEAD_PLAYER"), tr("BACCARAT_BEAD_BANKER"), tr("BACCARAT_BEAD_TIE")]
	for index: int in range(beads.size()):
		var bead: Dictionary = beads[index]
		var center := bead_center(index)
		draw_circle(center, BEAD_RADIUS, BaccaratStyle.winner_color(bead.winner))
		BaccaratStyle.draw_centered(self, letters[bead.winner], center, 10, BaccaratStyle.PEARL)
		if bead.player_pair:
			draw_circle(center + Vector2(-5, -5), 2.2, BaccaratStyle.PEARL)
		if bead.banker_pair:
			draw_circle(center + Vector2(5, 5), 2.2, BaccaratStyle.PEARL)
