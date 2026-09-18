class_name SlotSpinButton
extends Button
## Physical primary action for the classic slot control deck.


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var active_radius := 36.0 if button_pressed else 39.0
	var brass := Color("f0c45e") if is_hovered() or has_focus() else Color("c8a34b")
	var face := Color("3a0d14") if disabled else Color("781827")
	for side: float in [-1.0, 1.0]:
		var from := center + Vector2(side * 42.0, -14.0)
		for line: int in range(3):
			draw_line(
				from + Vector2(0, line * 14),
				from + Vector2(side * 25.0, line * 14),
				brass,
				4.0
			)
	draw_circle(center, 44.0, Color("28130e"))
	draw_circle(center, 41.0, brass)
	draw_circle(center, active_radius, face)
	draw_arc(center, active_radius - 4.0, 0.0, TAU, 48, Color("f1e8d8"), 2.0)
	var label := tr("SLOT_SPIN")
	var text_size := ThemeDB.fallback_font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21
	)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-text_size.x * 0.5, 7.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		21,
		Color("8d8272") if disabled else Color("f8ecd0")
	)
