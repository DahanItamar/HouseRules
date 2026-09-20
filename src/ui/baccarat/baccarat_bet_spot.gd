class_name BaccaratBetSpot
extends Button
## One betting spot painted on the violet felt: its name, its price, and the
## player's chips as a small stack. A / Enter / left click places the selected
## chip; X / right click takes one back. After a coup the spot shows whether it
## won, pushed or lost. Cyan appears only for keyboard/controller focus.

signal place_requested(spot_id: String)
signal remove_requested(spot_id: String)

enum Settle { NONE, WIN, PUSH, LOSE }

const CHIP_SIZE: float = 30.0
const CHIP_STEP: float = 3.0
const MAX_STACK: int = 3

var spot_id: String = ""
var tint: Color = BaccaratStyle.PLUM
var title_text: String = ""
var price_text: String = ""
var chips: int = 0
var settle_state: Settle = Settle.NONE
var chip_textures: Dictionary = {}
var chip_values: Array[int] = []
var betting_open: bool = true


func _init(id: String = "", rect: Rect2 = Rect2(), colour: Color = BaccaratStyle.PLUM) -> void:
	spot_id = id
	tint = colour
	name = "BaccaratSpot_%s" % id
	position = rect.position
	size = rect.size
	custom_minimum_size = rect.size
	focus_mode = Control.FOCUS_ALL
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	pressed.connect(func() -> void: place_requested.emit(spot_id))


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		remove_requested.emit(spot_id)
		accept_event()


func set_state(amount: int, state: Settle, open: bool) -> void:
	if chips == amount and settle_state == state and betting_open == open:
		return
	chips = amount
	settle_state = state
	betting_open = open
	queue_redraw()


## Largest-first chip breakdown of `amount` for the stack drawing.
func stack_for(amount: int) -> Array[int]:
	var stack: Array[int] = []
	var left := amount
	var values := chip_values.duplicate()
	values.sort()
	values.reverse()
	for value: int in values:
		while left >= value and stack.size() < MAX_STACK:
			stack.append(value)
			left -= value
	if stack.is_empty() and amount > 0 and not values.is_empty():
		stack.append(values[-1])
	stack.reverse()
	return stack


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var dim := settle_state == Settle.LOSE
	var fill_alpha := 0.20 if dim else 0.36
	if settle_state == Settle.WIN:
		fill_alpha = 0.55
	elif is_hovered() and betting_open:
		fill_alpha = 0.46
	var face := StyleBoxFlat.new()
	face.bg_color = Color(tint, fill_alpha)
	face.set_corner_radius_all(10)
	face.anti_aliasing = true
	draw_style_box(face, rect)
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.set_corner_radius_all(10)
	border.anti_aliasing = true
	match settle_state:
		Settle.WIN:
			border.border_color = BaccaratStyle.BRASS_BRIGHT
			border.set_border_width_all(3)
		Settle.PUSH:
			border.border_color = BaccaratStyle.PEARL
			border.set_border_width_all(2)
		_:
			border.border_color = Color(BaccaratStyle.PEARL, 0.35 if dim else 0.7)
			border.set_border_width_all(1)
	draw_style_box(border, rect.grow(-1.0))
	var ink := Color(BaccaratStyle.PEARL, 0.55 if dim else 1.0)
	var title_size := 18 if size.x >= 150 else 15
	BaccaratStyle.draw_centered(self, title_text, Vector2(size.x * 0.5, 17), title_size, ink)
	BaccaratStyle.draw_centered(
		self,
		price_text,
		Vector2(size.x * 0.5, 35),
		12,
		Color(BaccaratStyle.BRASS_BRIGHT, 0.55 if dim else 1.0),
		Typography.UI_FONT
	)
	_draw_stack(Vector2(size.x * 0.5, size.y - 20.0), dim)
	if has_focus(true):
		draw_style_box(FocusRing.style(10.0), rect)


func _draw_stack(base: Vector2, dim: bool) -> void:
	if chips <= 0:
		return
	var stack := stack_for(chips)
	var tint_alpha := 0.5 if dim else 1.0
	for index: int in range(stack.size()):
		var at := base + Vector2(0, -index * CHIP_STEP)
		var texture: Texture2D = chip_textures.get(stack[index])
		draw_circle(at + Vector2(0, 2), CHIP_SIZE * 0.5, Color(0, 0, 0, 0.4 * tint_alpha))
		if texture != null:
			draw_texture_rect(
				texture,
				Rect2(at - Vector2.ONE * CHIP_SIZE * 0.5, Vector2.ONE * CHIP_SIZE),
				false,
				Color(1, 1, 1, tint_alpha)
			)
	var top := base + Vector2(0, -(stack.size() - 1) * CHIP_STEP)
	var ink := BaccaratChipButton.ink_for(stack[-1])
	BaccaratStyle.draw_centered(self, str(chips), top, 13, Color(ink, tint_alpha))
