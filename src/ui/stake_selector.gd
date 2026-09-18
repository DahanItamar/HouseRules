class_name StakeSelector
extends Control
## Drawn chip denominations; keyboard/gamepad selection remains owned by MiniGame.

var cabinet: MiniGame


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


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
	var chip_diameter: float = 38.0
	var gap: float = 7.0
	var start_x: float = 52.0
	for index: int in range(options.size()):
		var amount: int = options[index]
		var selected: bool = amount == cabinet.selected_stake
		var center := Vector2(
			start_x + index * (chip_diameter + gap) + chip_diameter * 0.5,
			24.0 if selected else 28.0
		)
		var available: bool = cabinet.context != null and amount <= cabinet.context.balance
		var alpha: float = 1.0 if available else 0.35
		var fill := Color("5a111c", alpha) if index % 2 == 0 else Color("252126", alpha)
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
