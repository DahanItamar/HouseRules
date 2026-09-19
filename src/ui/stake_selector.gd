class_name StakeSelector
extends Control
## Shared casino wager console. Pointer and controller use one denomination model.

var cabinet: MiniGame
var _buttons: Array[Button] = []
var _button_amounts: Array[int] = []
var _bet_flash: float = 0.0
var _stake_value: AnimatedNumberLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_stake_value = AnimatedNumberLabel.new()
	_stake_value.name = "AnimatedStakeValue"
	_stake_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stake_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake_value.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_stake_value.add_theme_font_size_override("font_size", Typography.CONTROL)
	_stake_value.add_theme_color_override("font_color", Color("fff0d4"))
	add_child(_stake_value)
	_rebuild_buttons()
	_layout_buttons()
	refresh_controls()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	_button_amounts = cabinet.available_stakes() if cabinet != null else []
	for amount: int in _button_amounts:
		var button := Button.new()
		button.name = "BetAmount%d" % amount
		button.text = str(amount)
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", Typography.UI_FONT)
		button.add_theme_font_size_override("font_size", Typography.CONTROL)
		button.add_theme_color_override("font_color", Color("f2e6cf"))
		button.add_theme_color_override("font_disabled_color", Color("82776d"))
		button.add_theme_stylebox_override(
			"normal", _button_style(Color("21191b"), Color("665b50"), 1)
		)
		button.add_theme_stylebox_override(
			"hover", _button_style(Color("342126"), Color("c8a34b"), 2)
		)
		button.add_theme_stylebox_override(
			"pressed", _button_style(Color("661727"), Color("f2c84b"), 3)
		)
		button.add_theme_stylebox_override(
			"focus", _button_style(Color("2c2023"), Color("48c5d5"), 2)
		)
		button.add_theme_stylebox_override(
			"disabled", _button_style(Color("1b1718"), Color("3e3733"), 1)
		)
		button.pressed.connect(_select_amount.bind(amount))
		add_child(button)
		ButtonFeedback.attach(button)
		_buttons.append(button)


func _process(delta: float) -> void:
	if _bet_flash > 0.0:
		_bet_flash = maxf(0.0, _bet_flash - delta * 4.5)
		queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		_bet_flash = 0.0
		for button: Button in _buttons:
			button.modulate = Color.WHITE
	queue_redraw()


func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var gap := 4.0
	var button_width := (size.x - gap * float(_buttons.size() - 1)) / maxf(_buttons.size(), 1)
	for index: int in range(_buttons.size()):
		rects.append(Rect2(Vector2(index * (button_width + gap), 38), Vector2(button_width, 40)))
	return rects


func chip_rects() -> Array[Rect2]:
	return button_rects()


func refresh_controls() -> void:
	if cabinet == null:
		return
	var available := cabinet.available_stakes()
	if available != _button_amounts:
		_rebuild_buttons()
		_layout_buttons()
	var displayed_stake := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	for index: int in range(_buttons.size()):
		var button := _buttons[index]
		var amount := _button_amounts[index]
		var is_selected := amount == displayed_stake
		button.disabled = cabinet.is_round_active
		button.set_pressed_no_signal(is_selected)
		button.add_theme_stylebox_override(
			"normal",
			_button_style(
				Color("661727") if is_selected else Color("21191b"),
				Color("f2c84b") if is_selected else Color("665b50"),
				3 if is_selected else 1
			)
		)
		button.modulate = Color.WHITE
	_stake_value.set_number(displayed_stake)
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
	if _stake_value != null:
		_stake_value.position = Vector2(48.0, 1.0)
		_stake_value.size = Vector2(72.0, 32.0)


func _select_amount(amount: int) -> void:
	if cabinet != null and cabinet.select_stake(amount):
		_bet_flash = 1.0
	refresh_controls()


func _draw() -> void:
	if cabinet == null or cabinet.context == null:
		return
	var displayed_stake := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	draw_string(
		Typography.UI_FONT,
		Vector2(8, 20),
		tr("BET_IN_PLAY") if cabinet.is_round_active else tr("BET_TOTAL"),
		HORIZONTAL_ALIGNMENT_LEFT,
		42,
		Typography.CAPTION,
		Color("b8aa97")
	)
	var limit_text := "%d-%d" % [cabinet.context.definition.min_bet, cabinet.bet_cap()]
	draw_string(
		Typography.UI_FONT,
		Vector2(128, 20),
		"LIMIT %s" % limit_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		88,
		Typography.MICRO,
		Color("b8aa97")
	)
	var after_bet := maxi(0, cabinet.context.balance - displayed_stake)
	var funds_text := "DEV FUNDS  ∞" if Wallet.test_mode_enabled else tr("BET_AFTER") % after_bet
	draw_string(
		Typography.UI_FONT,
		Vector2(218, 20),
		funds_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		size.x - 218,
		Typography.MICRO,
		Color("b8aa97")
	)
	if _bet_flash > 0.0:
		draw_rect(Rect2(0, 34, size.x * _bet_flash, 2), Color("48c5d5"))


func _button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	return style
