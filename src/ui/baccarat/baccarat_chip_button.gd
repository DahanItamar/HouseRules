class_name BaccaratChipButton
extends Button
## One pearl-and-violet chip in the rack. The selected chip rests on a brass
## ring and lifts a little; cyan appears only for keyboard/controller focus.

const FACE_SIZE: float = 46.0

var amount: int = 20
var chip_texture: Texture2D
var selected: bool = false


func _init(value: int = 20, texture: Texture2D = null) -> void:
	amount = value
	chip_texture = texture
	name = "BaccaratChip%d" % value
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


## Ink that reads on the chip's own centre (dark on pearl/lavender, pearl on plum/black).
static func ink_for(value: int) -> Color:
	return BaccaratStyle.INK if value <= 40 else BaccaratStyle.PEARL


func _draw() -> void:
	var center := size * 0.5
	var lift := Vector2(0, -3) if selected else Vector2.ZERO
	var alpha := 0.42 if disabled else 1.0
	if selected:
		draw_circle(center + Vector2(0, 2), FACE_SIZE * 0.5 + 3.0, BaccaratStyle.BRASS_BRIGHT)
	draw_circle(center + Vector2(0, 2.5), FACE_SIZE * 0.5, Color(0, 0, 0, 0.45))
	var face := Rect2(center + lift - Vector2.ONE * FACE_SIZE * 0.5, Vector2.ONE * FACE_SIZE)
	if chip_texture != null:
		draw_texture_rect(chip_texture, face, false, Color(1, 1, 1, alpha))
	var ink := ink_for(amount)
	BaccaratStyle.draw_centered(self, str(amount), center + lift, 16, Color(ink, alpha))
	if has_focus(true):
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
		draw_arc(center + lift, FACE_SIZE * 0.5 + 1.0, 0.0, TAU, 40, BaccaratStyle.PEARL, 1.5, true)
