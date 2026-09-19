extends SceneTree
## Rebuilds the 4x3 Higgsfield win atlas with exact, gutter-safe integer cells.

const SOURCE := "res://assets/production/effects/casino_win_burst.png"
const OUTPUT := "res://assets/production/effects/casino_win_burst_integer.png"
const COLUMNS := 4
const ROWS := 3
const CELL := Vector2i(256, 344)
const CONTENT := Vector2i(254, 340)
const OFFSET := Vector2i(1, 2)


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(not source.is_empty(), "Win burst source atlas is required")
	var output := Image.create_empty(COLUMNS * CELL.x, ROWS * CELL.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for row: int in range(ROWS):
		var top := roundi(float(row) * source.get_height() / ROWS)
		var bottom := roundi(float(row + 1) * source.get_height() / ROWS)
		for column: int in range(COLUMNS):
			var source_rect := Rect2i(
				column * source.get_width() / COLUMNS,
				top,
				source.get_width() / COLUMNS,
				bottom - top
			)
			var frame := source.get_region(source_rect)
			frame.resize(CONTENT.x, CONTENT.y, Image.INTERPOLATE_LANCZOS)
			output.blit_rect(
				frame,
				Rect2i(Vector2i.ZERO, CONTENT),
				Vector2i(column * CELL.x, row * CELL.y) + OFFSET
			)
	var error := output.save_png(ProjectSettings.globalize_path(OUTPUT))
	assert(error == OK, "Could not save integer win burst atlas")
	print("REPACKED_WIN_BURST ", output.get_size())
	quit()
