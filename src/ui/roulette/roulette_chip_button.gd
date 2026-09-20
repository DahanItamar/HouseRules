class_name RouletteChipButton
extends Button
## One painted chip in the rack. The selected chip sits on a brass ring; the
## cyan ring appears only for keyboard/controller focus.

const FACE_SIZE: float = 46.0

var amount: int = 1
var chip_texture: Texture2D
var selected: bool = false


func _init(value: int = 1, texture: Texture2D = null) -> void:
	amount = value
	chip_texture = texture
	name = "RouletteChip%d" % value
	custom_minimum_size = Vector2(52, 52)
	size = Vector2(52, 52)
	focus_mode = Control.FOCUS_ALL
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func set_selected(value: bool) -> void:
	if selected != value:
		selected = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var lift := Vector2(0, -3) if selected else Vector2.ZERO
	var alpha := 0.42 if disabled else 1.0
	if selected:
		draw_circle(center + Vector2(0, 2), FACE_SIZE * 0.5 + 3.0, RouletteStyle.BRASS_BRIGHT)
	draw_circle(center + Vector2(0, 2.5), FACE_SIZE * 0.5, Color(0, 0, 0, 0.45))
	var face := Rect2(center + lift - Vector2.ONE * FACE_SIZE * 0.5, Vector2.ONE * FACE_SIZE)
	draw_texture_rect(chip_texture, face, false, Color(1, 1, 1, alpha))
	RouletteStyle.draw_centered(self, str(amount), center + lift, 16, Color(Color("1b120c"), alpha))
	if has_focus():
		draw_arc(
			center,
			FACE_SIZE * 0.5 + FocusRing.OUTSET * 2.0,
			0.0,
			TAU,
			40,
			FocusRing.COLOR,
			float(FocusRing.WIDTH),
			true
		)
	elif is_hovered() and not disabled:
		draw_arc(center + lift, FACE_SIZE * 0.5 + 1.0, 0.0, TAU, 40, RouletteStyle.IVORY, 1.5, true)
