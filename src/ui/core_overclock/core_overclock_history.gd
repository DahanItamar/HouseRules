class_name CoreOverclockHistory
extends Control
## The recent-runs strip: what each of the last runs reached before it was
## hauled in or the sea took it, newest first, on a small plate in the top-left
## corner. Red for a run that never cleared the bar, rope for a short one, brass
## for a long one and ember for a very long one.
##
## The chips are deliberately small and muted, and each carries a "x", so the
## strip can never be mistaken for the live multiplier on the chart.
##
## A new chip slides the row along once, in a bounded beat; under reduced motion
## the strip simply redraws with the new chip already in place.

const COLUMNS: int = 3
const ROWS: int = 2
const CHIP_SIZE := Vector2(76.0, 24.0)
const CHIP_GAP := Vector2(8.0, 8.0)
const CAPTION_SIZE: int = 11
const ICON_SIZE: float = 18.0
const ENTRY_SECONDS: float = 0.22

var entries: Array[int] = []
var caption: String = ""
var _entry_left: float = 0.0


func _init() -> void:
	name = "CoreOverclockHistory"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


## Mirrors the cabinet's history. The board owns no state of its own.
func set_entries(values: Array[int]) -> void:
	var arrived := not values.is_empty() and (entries.is_empty() or values[0] != entries[0])
	entries = values.duplicate()
	if arrived and not MotionPolicy.is_reduced():
		_entry_left = ENTRY_SECONDS
	queue_redraw()


func set_caption(text: String) -> void:
	caption = text
	queue_redraw()


func chip_count() -> int:
	return mini(entries.size(), COLUMNS * ROWS)


func _process(delta: float) -> void:
	if _entry_left <= 0.0:
		return
	_entry_left = maxf(_entry_left - delta, 0.0)
	queue_redraw()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_entry_left = 0.0
	queue_redraw()


func _draw() -> void:
	var font: Font = Typography.DISPLAY_FONT
	draw_texture_rect_region(
		CoreOverclockTheme.ICONS,
		Rect2(Vector2(0.0, 0.0), Vector2.ONE * ICON_SIZE),
		CoreOverclockTheme.sheet_region(
			CoreOverclockTheme.ICON_CREST,
			CoreOverclockTheme.ICON_GRID,
			CoreOverclockTheme.ICON_CELL
		)
	)
	draw_string(
		Typography.UI_FONT,
		Vector2(ICON_SIZE + 6.0, 13.0),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CAPTION_SIZE,
		CoreOverclockTheme.MUTED
	)
	var top := ICON_SIZE + 6.0
	var slide := (_entry_left / ENTRY_SECONDS) * 6.0
	for index: int in range(chip_count()):
		var centi := entries[index]
		var chip := Rect2(
			Vector2(
				float(index % COLUMNS) * (CHIP_SIZE.x + CHIP_GAP.x),
				top + float(index / COLUMNS) * (CHIP_SIZE.y + CHIP_GAP.y)
			),
			CHIP_SIZE
		)
		if index == 0:
			chip.position.y -= slide
		var ink := CoreOverclockTheme.crash_color(centi)
		draw_rect(chip, Color(CoreOverclockTheme.NIGHT, 0.7))
		draw_rect(chip, Color(ink, 0.7), false, 1.0)
		var text := CoreOverclockMath.multiplier_text(maxi(centi, 100)) + String.chr(0x00D7)
		var text_size := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.SUPPORTING
		)
		draw_string(
			font,
			Vector2(
				chip.position.x + (CHIP_SIZE.x - text_size.x) * 0.5,
				(
					chip.position.y
					+ CHIP_SIZE.y * 0.5
					+ font.get_ascent(Typography.SUPPORTING) * 0.5
					- 2.0
				)
			),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			Typography.SUPPORTING,
			Color(ink, 0.92)
		)
