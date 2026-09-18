class_name StakeSelector
extends Control
## Drawn chip denominations; keyboard/gamepad selection remains owned by MiniGame.

var cabinet: MiniGame
var _hovered_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func chip_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if cabinet == null:
		return rects
	var options := cabinet.stake_options()
	var start_x := 50.0
	var slot_width := (size.x - start_x) / maxf(options.size(), 1)
	for index: int in range(options.size()):
		rects.append(Rect2(start_x + index * slot_width, 5, slot_width, size.y - 5))
	return rects


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hovered_index = _chip_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := _chip_at(event.position)
		var options := cabinet.stake_options()
		if index >= 0 and index < options.size() and cabinet.select_stake(options[index]):
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_index = -1
		queue_redraw()


func _chip_at(point: Vector2) -> int:
	var rects := chip_rects()
	for index: int in range(rects.size()):
		if rects[index].has_point(point):
			return index
	return -1


func _draw() -> void:
	if cabinet == null:
		return
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, 16),
		tr("STAKE_BET"),
		HORIZONTAL_ALIGNMENT_LEFT,
		44,
		12,
		Color("b8ad9c")
	)
	var options: Array[int] = cabinet.stake_options()
	var start_x := 50.0
	var slot_width := (size.x - start_x) / maxf(options.size(), 1)
	var chip_diameter: float = minf(36.0, slot_width - 6.0)
	for index: int in range(options.size()):
		var amount: int = options[index]
		var selected: bool = amount == cabinet.selected_stake
		var center := Vector2(
			start_x + (index + 0.5) * slot_width,
			27.0 if selected else 32.0
		)
		var available: bool = cabinet.context != null and amount <= cabinet.context.balance
		var alpha: float = 1.0 if available else 0.35
		var fill := Color("5a111c", alpha) if index % 2 == 0 else Color("252126", alpha)
		if index == _hovered_index and available and not cabinet.is_round_active:
			fill = fill.lightened(0.12)
		draw_circle(center, chip_diameter * 0.5 + (2.0 if selected else 0.0), Color("0c0b0d", alpha))
		draw_circle(center, chip_diameter * 0.5, fill)
		draw_arc(center, chip_diameter * 0.5 - 3.0, 0.0, TAU, 32, Color("c8a34b", alpha), 2.0)
		if selected:
			draw_arc(center, chip_diameter * 0.5 + 2.0, 0.0, TAU, 32, Color("48c5d5"), 2.0)
		var amount_text := str(amount)
		var text_size := ThemeDB.fallback_font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-text_size.x * 0.5, 5),
			amount_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color("f1e8d8", alpha)
		)
