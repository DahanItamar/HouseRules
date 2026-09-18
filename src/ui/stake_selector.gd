class_name StakeSelector
extends Control
## Shared casino bet console. Every game uses the same exact wager operations.

const ACTIONS: Array[Dictionary] = [
	{"name": "BetMin", "label": "MIN", "operation": MiniGame.BetOperation.MIN},
	{"name": "BetAdd10", "label": "+10", "operation": MiniGame.BetOperation.ADD_10},
	{"name": "BetAdd25", "label": "+25", "operation": MiniGame.BetOperation.ADD_25},
	{"name": "BetTimes2", "label": "×2", "operation": MiniGame.BetOperation.MULTIPLY_2},
	{"name": "BetTimes5", "label": "×5", "operation": MiniGame.BetOperation.MULTIPLY_5},
	{"name": "BetMax", "label": "MAX", "operation": MiniGame.BetOperation.MAX},
]

var cabinet: MiniGame
var _buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	for action: Dictionary in ACTIONS:
		var button := Button.new()
		button.name = action.name
		button.text = action.label
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", Typography.CONTROL)
		button.add_theme_color_override("font_color", Color("f2e6cf"))
		button.add_theme_color_override("font_disabled_color", Color("746a60"))
		button.add_theme_stylebox_override(
			"normal", _button_style(Color("301318"), Color("8a682f"), 1)
		)
		button.add_theme_stylebox_override(
			"hover", _button_style(Color("671321"), Color("c6a04a"), 2)
		)
		button.add_theme_stylebox_override(
			"pressed", _button_style(Color("451019"), Color("f2d47a"), 2)
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
		_buttons[index].disabled = not cabinet.can_apply_bet(int(ACTIONS[index].operation))
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
	if cabinet != null:
		cabinet.apply_bet(operation)


func _draw() -> void:
	if cabinet == null or cabinet.context == null:
		return
	var displayed_stake := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, 17),
		tr("BET_IN_PLAY") if cabinet.is_round_active else tr("BET_TOTAL"),
		HORIZONTAL_ALIGNMENT_LEFT,
		112,
		Typography.CAPTION,
		Color("b8aa97")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(120, 29),
		str(displayed_stake),
		HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - 128,
		Typography.PROMINENT,
		Color("f2c84b")
	)
	var after_bet := maxi(0, cabinet.context.balance - displayed_stake)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, 35),
		tr("BET_AFTER") % after_bet,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 16,
		Typography.MICRO,
		Color("b8aa97")
	)


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style
