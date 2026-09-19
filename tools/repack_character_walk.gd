extends SceneTree
## Rebuilds the irregular 1774x887 character sheet as 32 isolated integer cells.
##
## The Higgsfield master averages 221.75 pixels per frame, so sampling it as a
## regular atlas crosses frame boundaries. Each source frame is cropped using
## independently rounded boundaries, normalized to 222x222, then placed inside
## a 240x240 transparent cell. The nine-pixel gutter keeps linear filtering from
## borrowing pixels from a neighboring direction or gait phase.

const SOURCE := "res://assets/production/characters/casino_guest_walk_32.png"
const OUTPUT := "res://assets/production/characters/casino_guest_walk_integer.png"
const COLUMNS := 8
const ROWS := 4
const CONTENT_SIZE := Vector2i(222, 222)
const CELL_SIZE := Vector2i(240, 240)
const GUTTER := Vector2i(9, 9)


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(not source.is_empty(), "Character walk master is missing")
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create_empty(
		CELL_SIZE.x * COLUMNS,
		CELL_SIZE.y * ROWS,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var source_start := Vector2i(
				roundi(float(column) * source.get_width() / COLUMNS),
				roundi(float(row) * source.get_height() / ROWS)
			)
			var source_end := Vector2i(
				roundi(float(column + 1) * source.get_width() / COLUMNS),
				roundi(float(row + 1) * source.get_height() / ROWS)
			)
			var frame := source.get_region(Rect2i(source_start, source_end - source_start))
			frame.resize(CONTENT_SIZE.x, CONTENT_SIZE.y, Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(
				frame,
				Rect2i(Vector2i.ZERO, CONTENT_SIZE),
				Vector2i(column, row) * CELL_SIZE + GUTTER
			)
	var error := atlas.save_png(OUTPUT)
	assert(error == OK, "Could not save integer character walk atlas")
	print("REPACKED character atlas ", atlas.get_size(), " cell=", CELL_SIZE)
	quit()
