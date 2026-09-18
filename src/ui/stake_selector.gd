class_name StakeSelector
extends Control
## Shared casino bet console. Every game uses the same exact wager operations.

const ACTIONS: Array[Dictionary] = [
	{"name": "BetMin", "label": "MIN", "operation": MiniGame.BetOperation.MIN},
	{"name": "BetAdd10", "label": "+10", "operation": MiniGame.BetOperation.ADD_10},
	{"name": "BetAdd25", "label": "+25", "operation": MiniGame.BetOperation.ADD_25},
	{"name": "BetTimes2", "label": "X2", "operation": MiniGame.BetOperation.MULTIPLY_2},
	{"name": "BetTimes5", "label": "X5", "operation": MiniGame.BetOperation.MULTIPLY_5},
	{"name": "BetMax", "label": "MAX", "operation": MiniGame.BetOperation.MAX},
]

var cabinet: MiniGame
var _buttons: Array[Button] = []
var _active_operation: int = -1
var _bet_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	for action: Dictionary in ACTIONS:
		var button := Button.new()
		button.name = action.name
		button.text = action.label
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", Typography.UI_FONT)
		button.add_theme_font_size_override("font_size", Typography.CONTROL)
		button.add_theme_color_override("font_color", Color("f2e6cf"))
		button.add_theme_color_override("font_disabled_color", Color("746a60"))
		button.add_theme_stylebox_override(
			"normal", _button_style(Color("24171a"), Color("8a682f"), 2)
		)
		button.add_theme_stylebox_override(
			"hover", _button_style(Color("671321"), Color("f2c84b"), 3)
		)
		button.add_theme_stylebox_override(
			"pressed", _button_style(Color("3b0c14"), Color("fff0a0"), 4)
		)
		button.add_theme_stylebox_override(
			"focus", _button_style(Color("301318"), Color("4cc9d7"), 2)
		)
		button.add_theme_stylebox_override(
			"disabled", _button_style(Color("1f191a"), Color("4d433c"), 1)
		)
		button.pressed.connect(_apply_operation.bind(int(action.operation)))
		add_child(button)
		_buttons.append(button)
	_layout_buttons()
	refresh_controls()
	set_process(true)


func _process(delta: float) -> void:
	if _bet_flash > 0.0:
		_bet_flash = maxf(0.0, _bet_flash - delta * 2.8)
		queue_redraw()


func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var gap := 4.0
	var button_width := (size.x - gap * float(_buttons.size() - 1)) / maxf(_buttons.size(), 1)
	for index: int in range(_buttons.size()):
		rects.append(Rect2(Vector2(index * (button_width + gap), 42), Vector2(button_width, 38)))
	return rects


func chip_rects() -> Array[Rect2]:
	# Compatibility for older callers; these are now semantic button targets.
	return button_rects()


func refresh_controls() -> void:
	if cabinet == null:
		return
	for index: int in range(_buttons.size()):
		var operation := int(ACTIONS[index].operation)
		var button := _buttons[index]
		button.disabled = not cabinet.can_apply_bet(operation)
		button.add_theme_stylebox_override(
			"normal",
			_button_style(
				Color("6b1725") if operation == _active_operation else Color("24171a"),
				Color("48c5d5") if operation == _active_operation else Color("8a682f"),
				3 if operation == _active_operation else 2
			)
		)
	queue_redraw()


func focus_first_available() -> void:
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_buttons()
		queue_redraw()


func _layout_buttons() -> void:
	var rects := button_rects()
	for index: int in range(mini(rects.size(), _buttons.size())):
		_buttons[index].position = rects[index].position
		_buttons[index].size = rects[index].size


func _apply_operation(operation: int) -> void:
	if cabinet != null and cabinet.apply_bet(operation):
		_active_operation = operation
		_bet_flash = 1.0
		var button_index := _operation_index(operation)
		if button_index >= 0:
			var button := _buttons[button_index]
			button.pivot_offset = button.size * 0.5
			button.scale = Vector2(0.88, 0.88)
			create_tween().tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(
				Tween.TRANS_BACK
			)
		refresh_controls()


func _draw() -> void:
	if cabinet == null or cabinet.context == null:
		return
	var displayed_stake := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	draw_string(
		Typography.UI_FONT,
		Vector2(8, 18),
		tr("BET_IN_PLAY") if cabinet.is_round_active else tr("BET_TOTAL"),
		HORIZONTAL_ALIGNMENT_LEFT,
		96,
		Typography.CAPTION,
		Color("b8aa97")
	)
	var chip_center := Vector2(size.x - 54.0, 20.0)
	var glow_alpha := 0.18 + _bet_flash * 0.42
	draw_circle(chip_center, 24.0 + _bet_flash * 3.0, Color("48c5d5", glow_alpha))
	draw_circle(chip_center, 21.0, Color("601521"))
	draw_arc(chip_center, 19.0, 0.0, TAU, 48, Color("f2c84b"), 2.0)
	draw_string(
		Typography.DISPLAY_FONT,
		chip_center + Vector2(-34.0, 7.0),
		str(displayed_stake),
		HORIZONTAL_ALIGNMENT_CENTER,
		68.0,
		Typography.CONTROL,
		Color("fff0d4")
	)
	var after_bet := maxi(0, cabinet.context.balance - displayed_stake)
	var after_bet_text := "AFTER BET  ∞" if Wallet.test_mode_enabled else tr("BET_AFTER") % after_bet
	draw_string(
		Typography.UI_FONT,
		Vector2(104, 24),
		after_bet_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 168,
		Typography.MICRO,
		Color("b8aa97")
	)


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(24)
	style.shadow_color = Color("08060799")
	style.shadow_size = 3
	return style


func _operation_index(operation: int) -> int:
	for index: int in range(ACTIONS.size()):
		if int(ACTIONS[index].operation) == operation:
			return index
	return -1
