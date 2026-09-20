class_name BetControl
extends Control
## The deck's bet control: "YOUR BET", the current value, the painted chip stack
## that shows the bet as chips, the table limit under it and − / + steppers that
## name their inputs (LB/RB, Q/E). Mouse: click − / +, or scroll over the control.
##
## Presentation only. It never changes the stake itself: it asks for a step with
## `step_requested` and the owner applies it through the cabinet's rules.

signal step_requested(direction: int)

## Steppers are round kit medallions with the input glyph set on their foot.
const STEP_SIZE := Vector2(48, 56)
const MEDALLION_DIAMETER: float = 42.0
## The chip stack is drawn this tall; its width follows the painted art.
const CHIP_HEIGHT: float = 48.0
## Painted plate scale for the bet plate (its corners stay small at 56 px tall).
const PLATE_SCALE: float = 0.09

var style: DeckStyle = DeckStyle.casino()
var amount: int = 0
var caption: String = ""
var limit_text: String = ""
var editable: bool = true
var denominations: Array[int] = []
var _minus: StepButton
var _plus: StepButton
var _value_shift: float = 0.0
var _value_alpha: float = 1.0
var _sweep: float = 0.0
var _change_tween: Tween
var _has_amount: bool = false
var _plate: KitPlate


func _init() -> void:
	name = "BetControl"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_minus = StepButton.new()
	_minus.name = "BetStepDown"
	_minus.sign_text = String.chr(0x2212)
	_minus.action = &"bet_down"
	_minus.pressed.connect(func() -> void: step_requested.emit(-1))
	add_child(_minus)
	_plus = StepButton.new()
	_plus.name = "BetStepUp"
	_plus.sign_text = "+"
	_plus.action = &"bet_up"
	_plus.pressed.connect(func() -> void: step_requested.emit(1))
	add_child(_plus)


func _ready() -> void:
	for button: StepButton in [_minus, _plus]:
		button.style = style
		button.medallion = UiKit.texture(style.kit_theme, "medallion")
		button.medallion_region = UiKit.region(style.kit_theme, "medallion")
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		# Keyboard/controller focus only: a cyan ring around the medallion.
		button.add_theme_stylebox_override("focus", empty)
		ButtonFeedback.attach(button)
	if UiKit.has_part(style.kit_theme, "panel"):
		_plate = KitPlate.new()
		_plate.name = "BetPlate"
		_plate.configure(style.kit_theme, "panel", PLATE_SCALE)
		add_child(_plate)
		move_child(_plate, 0)
	resized.connect(_layout)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	_layout()


func step_down_button() -> Button:
	return _minus


func step_up_button() -> Button:
	return _plus


## Updates what the control shows. `can_down`/`can_up` say whether a step in that
## direction would change the stake; out-of-range steps are shown as unavailable.
func set_state(
	next_amount: int,
	next_editable: bool,
	can_down: bool,
	can_up: bool,
	next_caption: String,
	next_limit: String,
	next_denominations: Array[int]
) -> void:
	var previous := amount
	amount = next_amount
	editable = next_editable
	caption = next_caption
	limit_text = next_limit
	denominations = next_denominations
	_minus.visible = editable
	_plus.visible = editable
	_minus.disabled = not can_down
	_plus.disabled = not can_up
	for button: StepButton in [_minus, _plus]:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW
		)
		button.queue_redraw()
	if _has_amount and previous != amount:
		_play_change(signi(amount - previous))
	_has_amount = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not editable:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		step_requested.emit(1)
		accept_event()
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step_requested.emit(-1)
		accept_event()


func _layout() -> void:
	var top := (size.y - STEP_SIZE.y) * 0.5
	_minus.position = Vector2(0, top)
	_minus.size = STEP_SIZE
	_plus.position = Vector2(size.x - STEP_SIZE.x, top)
	_plus.size = STEP_SIZE
	if _plate != null:
		_plate.fit(_inner_rect())
	queue_redraw()


func _inner_rect() -> Rect2:
	return Rect2(Vector2(STEP_SIZE.x + 6.0, 0), Vector2(size.x - STEP_SIZE.x * 2.0 - 12.0, size.y))


func _play_change(direction: int) -> void:
	if _change_tween != null and _change_tween.is_valid():
		_change_tween.kill()
	if MotionPolicy.is_reduced() or not is_inside_tree():
		_value_shift = 0.0
		_value_alpha = 1.0
		_sweep = 0.0
		return
	# The new value slides in from the side it came from; a brass rule sweeps
	# under it once. Bounded and presentation only.
	_value_shift = -8.0 * float(direction)
	_value_alpha = 0.35
	_sweep = 0.0
	_change_tween = create_tween().set_parallel(true)
	(
		_change_tween
		. tween_method(_set_value_shift, _value_shift, 0.0, 0.16)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_change_tween.tween_method(_set_value_alpha, _value_alpha, 1.0, 0.12)
	_change_tween.tween_method(_set_sweep, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD)
	_change_tween.finished.connect(func() -> void: _set_sweep(0.0))


func _set_value_shift(value: float) -> void:
	_value_shift = value
	queue_redraw()


func _set_value_alpha(value: float) -> void:
	_value_alpha = value
	queue_redraw()


func _set_sweep(value: float) -> void:
	_sweep = value
	queue_redraw()


func is_animating() -> bool:
	return _change_tween != null and _change_tween.is_valid()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		if _change_tween != null and _change_tween.is_valid():
			_change_tween.kill()
		_change_tween = null
		_value_shift = 0.0
		_value_alpha = 1.0
		_sweep = 0.0
		queue_redraw()


func _draw() -> void:
	var inner := _inner_rect()
	if _plate == null:
		draw_style_box(style.panel_box(style.inset, style.inset_edge, 1), inner)
	# The bet as chips: the same painted stack the table uses for a wager.
	var chip := style.chip_texture
	var chip_size := Vector2(
		CHIP_HEIGHT * float(chip.get_width()) / float(chip.get_height()), CHIP_HEIGHT
	)
	var chip_rect := Rect2(
		Vector2(inner.position.x + 10.0, inner.position.y + (inner.size.y - CHIP_HEIGHT) * 0.5),
		chip_size
	)
	var chip_tint := Color.WHITE if amount > 0 else Color(1, 1, 1, 0.25)
	draw_texture_rect(chip, chip_rect, false, chip_tint)
	var text_x := chip_rect.end.x + 12.0
	var text_width := inner.end.x - text_x - 8.0
	var caption_font := Typography.UI_FONT
	var value_font := Typography.DISPLAY_FONT
	draw_string(
		caption_font,
		Vector2(text_x, inner.position.y + 14.0),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		Typography.MICRO,
		style.caption
	)
	var value_color := style.value
	value_color.a *= _value_alpha
	var value_text := str(amount)
	draw_string(
		value_font,
		Vector2(text_x + _value_shift, inner.position.y + 38.0),
		value_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		26,
		value_color
	)
	if _sweep > 0.0:
		var value_width := (
			value_font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		)
		var sweep_color := style.edge_bright
		sweep_color.a = 1.0 - _sweep * 0.6
		draw_rect(
			Rect2(Vector2(text_x, inner.position.y + 41.0), Vector2(value_width * _sweep, 1.5)),
			sweep_color
		)
	draw_string(
		caption_font,
		Vector2(text_x, inner.end.y - 4.0),
		limit_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		Typography.MICRO,
		style.caption
	)


## A − or + stepper: the game's round medallion with a big sign drawn in code and
## the input glyph set on its foot like a badge.
class StepButton:
	extends Button

	const IVORY := Color("f1e8d8")
	const CYAN := Color("48c5d5")

	var sign_text: String = "+"
	var action: StringName = &"bet_up"
	var style: DeckStyle = DeckStyle.casino()
	var medallion: Texture2D
	var medallion_region := Rect2()

	func _ready() -> void:
		text = ""
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		InputRouter.active_device_changed.connect(func(_device: int) -> void: queue_redraw())
		InputRouter.gamepad_family_changed.connect(func(_family: int) -> void: queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var diameter := BetControl.MEDALLION_DIAMETER
		var center := Vector2(size.x * 0.5, diameter * 0.5 + 1.0)
		var hovered := is_hovered() and not disabled
		var tint := Color.WHITE
		if disabled:
			tint = Color(0.5, 0.5, 0.5)
		elif get_draw_mode() == DRAW_PRESSED:
			tint = Color(0.8, 0.8, 0.8)
		elif hovered:
			tint = Color(1.14, 1.12, 1.08)
		var disc := Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))
		if medallion != null:
			draw_texture_rect_region(medallion, disc, medallion_region, tint)
		else:
			draw_circle(center, diameter * 0.5, style.edge * tint, true, -1.0, true)
			draw_circle(center, diameter * 0.5 - 2.0, style.inset, true, -1.0, true)
		if has_focus():
			draw_arc(center, diameter * 0.5 + 2.0, 0.0, TAU, 48, CYAN, 2.0, true)
		var font := Typography.DISPLAY_FONT
		var sign_size := 30
		var ink := style.text_disabled if disabled else IVORY
		draw_string(
			font,
			Vector2(
				0, center.y + (font.get_ascent(sign_size) - font.get_descent(sign_size)) * 0.5 - 2.0
			),
			sign_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			sign_size,
			ink
		)
		var spec := InputRouter.glyph_spec(action)
		var glyph_height := 17.0
		var glyph_width := InputGlyph.measure(spec, glyph_height)
		InputGlyph.draw_spec(
			self,
			spec,
			Rect2(
				Vector2((size.x - glyph_width) * 0.5, size.y - glyph_height),
				Vector2(glyph_width, glyph_height)
			)
		)
