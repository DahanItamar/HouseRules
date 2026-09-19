extends Node

const CASHIER_MOTION_DIRECTOR_SCRIPT := preload("res://src/ui/cashier_motion_director.gd")

var _guard := InstanceGuard.new()
var _floor: FloorController
var _menu: CanvasLayer
var _hud_layer: CanvasLayer
var _bank_panel: Panel
var _chip_icon: CreditChipIcon
var _hud: AnimatedNumberLabel
var _credit_caption: Label
var _message_panel: Panel
var _message: Label
var _contracts: Label
var _contracts_panel: Panel
var _is_playing: bool = false
var _message_serial: int = 0
var _menu_transitioning: bool = false
var _menu_background: TextureRect
var _menu_kicker: Label
var _menu_rule: ColorRect
var _menu_title: Label
var _menu_subtitle: Label
var _menu_prompt_panel: Panel
var _menu_prompt: Label
var _menu_motion_button: Button
var _cashier_motion_director: Node
var _menu_reveal_tween: Tween
var _menu_attract_tween: Tween
var _menu_attract_elapsed: float = 0.0
var _menu_first_breath: bool = true
var _message_tween: Tween
var _bank_feedback_tween: Tween
var _contract_feedback_tween: Tween


func _ready() -> void:
	Engine.max_fps = 60
	get_window().min_size = Vector2i(1280, 720)
	get_tree().auto_accept_quit = false
	if not _guard.acquire():
		get_tree().quit()
		return
	SaveService.load_failed.connect(_show_message)
	SaveService.save_failed.connect(func(_error: Error) -> void: _show_message("SAVE_FAILED"))
	SceneRouter.menu_requested.connect(_show_menu)
	_build_hud()
	add_child(DisconnectPauseOverlay.new())
	var error: Error = SaveService.load_game()
	Wallet.set_test_mode(bool(ProjectSettings.get_setting("house_rules/testing/unlimited_bankroll", false)))
	_build_menu()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	if error != OK:
		_present_message(tr("SAVE_INCOMPATIBLE"))
	Wallet.balance_changed.connect(_on_balance_changed)
	Economy.debt_changed.connect(func(_debt: int) -> void: _refresh_hud())
	Economy.contracts_changed.connect(_on_contracts_changed)
	Economy.contract_completed.connect(_show_contract_completed)
	SceneRouter.session_changed.connect(_refresh_hud)
	InputRouter.active_device_changed.connect(func(_device: int) -> void: _refresh_menu())
	_refresh_hud()
	_refresh_menu()


func _process(delta: float) -> void:
	if (
		_menu == null
		or not _menu.visible
		or not MotionPolicy.allows_continuous_motion()
		or _menu_prompt_panel == null
	):
		return
	_menu_attract_elapsed += delta
	var cadence := 2.0 if _menu_first_breath else 6.0
	if _menu_attract_elapsed < cadence:
		return
	_menu_attract_elapsed = 0.0
	_menu_first_breath = false
	_play_menu_breath()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_bank_panel = _panel(Vector2(18, 16), Vector2(168, 52), Color("17161af2"), Color("c8a34b"))
	_bank_panel.pivot_offset = _bank_panel.size * 0.5
	_hud_layer.add_child(_bank_panel)
	_chip_icon = CreditChipIcon.new()
	_chip_icon.position = Vector2(28, 25)
	_hud_layer.add_child(_chip_icon)
	_credit_caption = Label.new()
	_credit_caption.add_theme_font_override("font", Typography.UI_FONT)
	_credit_caption.position = Vector2(72, 20)
	_credit_caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	_credit_caption.add_theme_font_size_override("font_size", Typography.BODY_MIN)
	_credit_caption.add_theme_color_override("font_color", Color("b8ad9c"))
	_hud_layer.add_child(_credit_caption)
	_hud = AnimatedNumberLabel.new()
	_hud.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_hud.position = Vector2(72, 34)
	_hud.size = Vector2(126, 30)
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_color", Color("f2c84b"))
	_hud_layer.add_child(_hud)
	_message_panel = _panel(
		Vector2(220, 104), Vector2(520, 40), Color("17161af2"), Color("c8a34b")
	)
	_message_panel.visible = false
	_hud_layer.add_child(_message_panel)
	_message = Label.new()
	_message.add_theme_font_override("font", Typography.UI_FONT)
	_message.position = Vector2(236, 111)
	_message.size = Vector2(488, 26)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message.add_theme_font_size_override("font_size", Typography.BODY_MIN)
	_message.add_theme_color_override("font_color", Color("f1e8d8"))
	_message.visible = false
	_hud_layer.add_child(_message)
	_contracts_panel = _panel(
		Vector2(594, 16), Vector2(348, 80), Color("17161ae8"), Color("6e5225")
	)
	_contracts_panel.pivot_offset = _contracts_panel.size * 0.5
	_hud_layer.add_child(_contracts_panel)
	_contracts = Label.new()
	_contracts.add_theme_font_override("font", Typography.UI_FONT)
	_contracts.position = Vector2(610, 22)
	_contracts.size = Vector2(316, 68)
	_contracts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_contracts.add_theme_font_size_override("font_size", Typography.BODY_MIN)
	_contracts.add_theme_color_override("font_color", Color("b8ad9c"))
	_hud_layer.add_child(_contracts)


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 6
	add_child(_menu)
	_menu_background = TextureRect.new()
	_menu_background.name = "CasinoHallArt"
	_menu_background.texture = preload("res://assets/production/environments/casino_menu_hall.png")
	_menu_background.size = Vector2(960, 540)
	_menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_menu.add_child(_menu_background)
	var lighting := CasinoLighting.new()
	lighting.name = "MenuLighting"
	lighting.size = Vector2(960, 540)
	lighting.mode = CasinoLighting.Mode.MENU
	_menu.add_child(lighting)
	var menu_ambient := CasinoAmbient.new()
	menu_ambient.name = "MenuAmbient"
	menu_ambient.position = Vector2(548, 18)
	menu_ambient.size = Vector2(392, 86)
	menu_ambient.mode = CasinoAmbient.Mode.LOBBY
	menu_ambient.accent = Color("f2c84b")
	_menu.add_child(menu_ambient)
	var readability := ColorRect.new()
	readability.size = Vector2(548, 540)
	readability.color = Color("0c0b0dcc")
	_menu.add_child(readability)
	_menu_rule = ColorRect.new()
	_menu_rule.name = "BrassRule"
	_menu_rule.position = Vector2(70, 116)
	_menu_rule.size = Vector2(72, 3)
	_menu_rule.color = Color("c8a34b")
	_menu.add_child(_menu_rule)
	_menu_kicker = Label.new()
	_menu_kicker.name = "Kicker"
	_menu_kicker.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_menu_kicker.position = Vector2(70, 82)
	_menu_kicker.text = tr("MENU_KICKER")
	_menu_kicker.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	_menu_kicker.add_theme_color_override("font_color", Color("c8a34b"))
	_menu.add_child(_menu_kicker)
	_menu_title = Label.new()
	_menu_title.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_menu_title.name = "Title"
	_menu_title.position = Vector2(66, 140)
	_menu_title.add_theme_font_size_override("font_size", 58)
	_menu_title.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu_title.text = tr("GAME_TITLE")
	_menu.add_child(_menu_title)
	_menu_subtitle = Label.new()
	_menu_subtitle.name = "Subtitle"
	_menu_subtitle.add_theme_font_override("font", Typography.UI_FONT)
	_menu_subtitle.position = Vector2(72, 222)
	_menu_subtitle.size = Vector2(380, 60)
	_menu_subtitle.text = tr("MENU_SUBTITLE")
	_menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_subtitle.add_theme_font_size_override("font_size", 18)
	_menu_subtitle.add_theme_color_override("font_color", Color("b8ad9c"))
	_menu.add_child(_menu_subtitle)
	_menu_prompt_panel = _panel(
		Vector2(70, 320), Vector2(360, 104), Color("17161af2"), Color("c8a34b")
	)
	_menu_prompt_panel.name = "PromptPanel"
	_menu.add_child(_menu_prompt_panel)
	_menu_prompt = Label.new()
	_menu_prompt.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_menu_prompt.name = "Prompt"
	_menu_prompt.position = Vector2(92, 339)
	_menu_prompt.size = Vector2(316, 70)
	_menu_prompt.add_theme_font_size_override("font_size", Typography.PROMINENT)
	_menu_prompt.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu.add_child(_menu_prompt)
	_build_motion_preference_button()
	_play_menu_reveal()


func _build_motion_preference_button() -> void:
	_menu_motion_button = Button.new()
	_menu_motion_button.name = "ReducedMotionToggle"
	_menu_motion_button.position = Vector2(70, 444)
	_menu_motion_button.size = Vector2(360, 56)
	_menu_motion_button.toggle_mode = true
	_menu_motion_button.focus_mode = Control.FOCUS_ALL
	_menu_motion_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu_motion_button.add_theme_font_override("font", Typography.UI_FONT)
	_menu_motion_button.add_theme_font_size_override("font_size", 18)
	_menu_motion_button.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu_motion_button.add_theme_color_override("font_hover_color", Color("fff4d8"))
	_menu_motion_button.add_theme_color_override("font_focus_color", Color("fff4d8"))
	_menu_motion_button.add_theme_color_override("font_pressed_color", Color("f2c84b"))
	_menu_motion_button.add_theme_stylebox_override(
		"normal", _menu_button_style(Color("17161ae8"), Color("6e5225"), 1)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"hover", _menu_button_style(Color("242027f2"), Color("c8a34b"), 1)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"pressed", _menu_button_style(Color("302719f2"), Color("f2c84b"), 2)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"focus", _menu_button_style(Color("00000000"), Color("f2c84b"), 3)
	)
	_menu_motion_button.tooltip_text = tr("MENU_REDUCED_MOTION_HELP")
	_menu_motion_button.pressed.connect(_toggle_motion_preference)
	ButtonFeedback.attach(_menu_motion_button)
	_menu.add_child(_menu_motion_button)
	_refresh_motion_preference_button()


func _menu_button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style


func _panel(at: Vector2, dimensions: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color("05040570")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh_menu() -> void:
	_menu_prompt.text = (
		tr("MENU_CONTROLS") % [InputRouter.glyph("interact"), InputRouter.glyph("back")]
	)
	_refresh_motion_preference_button()


func _refresh_motion_preference_button() -> void:
	if _menu_motion_button == null:
		return
	var state_key := "SETTING_ON" if MotionPolicy.is_reduced() else "SETTING_OFF"
	_menu_motion_button.text = (
		tr("MENU_REDUCED_MOTION") % [InputRouter.glyph("secondary"), tr(state_key)]
	)
	_menu_motion_button.button_pressed = MotionPolicy.is_reduced()
	_menu_motion_button.accessibility_name = tr("MENU_REDUCED_MOTION_ACCESSIBLE") % tr(state_key)


func _toggle_motion_preference() -> void:
	MotionPolicy.set_reduced_motion(not MotionPolicy.is_reduced())
	AudioService.play(&"confirm")


func _play_menu_reveal() -> void:
	_menu_attract_elapsed = 0.0
	_menu_first_breath = true
	if _menu_reveal_tween != null:
		_menu_reveal_tween.kill()
	if MotionPolicy.is_reduced():
		_apply_menu_final_state()
		return
	_menu_background.modulate.a = 0.0
	_menu_kicker.modulate.a = 0.0
	_menu_rule.modulate.a = 0.0
	_menu_rule.scale.x = 0.25
	_menu_title.modulate.a = 0.0
	_menu_title.position = Vector2(66, 148)
	_menu_subtitle.modulate.a = 0.0
	_menu_subtitle.position.y = 230.0
	_menu_prompt_panel.modulate.a = 0.0
	_menu_prompt.modulate.a = 0.0
	_menu_motion_button.modulate.a = 0.0
	_menu_motion_button.position.y = 452.0
	_menu_prompt_panel.pivot_offset = _menu_prompt_panel.size * 0.5
	_menu_prompt_panel.scale = Vector2(0.98, 0.98)
	_menu_reveal_tween = create_tween().set_parallel(true)
	_menu_reveal_tween.tween_property(_menu_background, "modulate:a", 1.0, 0.24)
	_menu_reveal_tween.tween_property(_menu_kicker, "modulate:a", 1.0, 0.14).set_delay(0.04)
	_menu_reveal_tween.tween_property(_menu_rule, "modulate:a", 1.0, 0.14).set_delay(0.06)
	_menu_reveal_tween.tween_property(
		_menu_rule, "scale:x", 1.0, 0.18
	).set_delay(0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_reveal_tween.tween_property(_menu_title, "modulate:a", 1.0, 0.18).set_delay(0.08)
	_menu_reveal_tween.tween_property(
		_menu_title, "position:y", 140.0, 0.18
	).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_reveal_tween.tween_property(_menu_subtitle, "modulate:a", 1.0, 0.16).set_delay(0.13)
	_menu_reveal_tween.tween_property(
		_menu_subtitle, "position:y", 222.0, 0.18
	).set_delay(0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_reveal_tween.tween_property(_menu_prompt_panel, "modulate:a", 1.0, 0.18).set_delay(0.18)
	_menu_reveal_tween.tween_property(_menu_prompt, "modulate:a", 1.0, 0.18).set_delay(0.18)
	_menu_reveal_tween.tween_property(
		_menu_prompt_panel, "scale", Vector2.ONE, 0.18
	).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_reveal_tween.tween_property(_menu_motion_button, "modulate:a", 1.0, 0.16).set_delay(0.23)
	_menu_reveal_tween.tween_property(
		_menu_motion_button, "position:y", 444.0, 0.18
	).set_delay(0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_menu_breath() -> void:
	if _menu_attract_tween != null and _menu_attract_tween.is_valid():
		_menu_attract_tween.kill()
	_menu_prompt_panel.pivot_offset = _menu_prompt_panel.size * 0.5
	_menu_attract_tween = create_tween().set_parallel(true)
	_menu_attract_tween.tween_property(_menu_prompt_panel, "scale", Vector2(1.018, 1.018), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_attract_tween.tween_property(_menu_prompt, "modulate", Color("fff4d8"), 0.16)
	_menu_attract_tween.chain().set_parallel(true)
	_menu_attract_tween.tween_property(_menu_prompt_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_menu_attract_tween.tween_property(_menu_prompt, "modulate", Color.WHITE, 0.24)


func _apply_menu_final_state() -> void:
	if _menu_background == null:
		return
	_menu_background.modulate.a = 1.0
	_menu_kicker.modulate = Color.WHITE
	_menu_rule.modulate = Color.WHITE
	_menu_rule.scale = Vector2.ONE
	_menu_title.modulate.a = 1.0
	_menu_title.position = Vector2(66, 140)
	_menu_subtitle.modulate = Color.WHITE
	_menu_subtitle.position.y = 222.0
	_menu_prompt_panel.modulate.a = 1.0
	_menu_prompt_panel.scale = Vector2.ONE
	_menu_prompt.modulate = Color.WHITE
	_menu_motion_button.modulate = Color.WHITE
	_menu_motion_button.position.y = 444.0


func _on_motion_preference_changed(reduced: bool) -> void:
	_refresh_motion_preference_button()
	if reduced:
		if _menu_reveal_tween != null:
			_menu_reveal_tween.kill()
		if _menu_attract_tween != null:
			_menu_attract_tween.kill()
		_apply_menu_final_state()
		if _message_tween != null:
			_message_tween.kill()
		_apply_message_final_state()
	elif _menu != null and _menu.visible:
		_play_menu_reveal()


func _refresh_hud() -> void:
	if Wallet.test_mode_enabled:
		_hud.set_infinity()
	else:
		var balance_format := "%d"
		if Economy.debt > 0:
			balance_format += "  /  " + str(Economy.debt)
		_hud.set_number(Wallet.balance, balance_format)
	_credit_caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	if Wallet.test_mode_enabled and Economy.debt > 0:
		_hud.text += "  /  " + str(Economy.debt)
	if _contracts != null:
		var on_floor: bool = (
			_is_playing
			and SceneRouter.session == null
			and (_floor == null or not _floor._cashier_open)
		)
		_bank_panel.visible = on_floor
		_chip_icon.visible = on_floor
		_credit_caption.visible = on_floor
		_hud.visible = on_floor
		_contracts.visible = on_floor
		_contracts_panel.visible = _contracts.visible
		_contracts.text = tr("CONTRACTS_HEADING") + "\n" + "\n".join(Economy.contract_lines())


func _on_balance_changed(old_balance: int, new_balance: int) -> void:
	_refresh_hud()
	_chip_icon.play_transaction(new_balance - old_balance)
	if _bank_feedback_tween != null:
		_bank_feedback_tween.kill()
	_bank_panel.scale = Vector2.ONE
	_hud.modulate = Color.WHITE
	if MotionPolicy.is_reduced():
		return
	_bank_feedback_tween = create_tween().set_parallel(true)
	_bank_feedback_tween.tween_property(_bank_panel, "scale", Vector2(1.035, 1.035), 0.10).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_bank_feedback_tween.tween_property(_hud, "modulate", Color("fff0a0"), 0.10)
	_bank_feedback_tween.chain().tween_property(_bank_panel, "scale", Vector2.ONE, 0.16).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_bank_feedback_tween.parallel().tween_property(_hud, "modulate", Color.WHITE, 0.16)


func _on_contracts_changed() -> void:
	_refresh_hud()
	if _contract_feedback_tween != null:
		_contract_feedback_tween.kill()
	_contracts_panel.scale = Vector2.ONE
	_contracts.modulate = Color.WHITE
	_contracts.position.x = 610.0
	if MotionPolicy.is_reduced() or not _contracts.visible:
		return
	_contracts.position.x = 622.0
	_contracts.modulate.a = 0.62
	_contract_feedback_tween = create_tween().set_parallel(true)
	_contract_feedback_tween.tween_property(_contracts, "position:x", 610.0, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_contract_feedback_tween.tween_property(_contracts, "modulate:a", 1.0, 0.16)
	_contract_feedback_tween.tween_property(
		_contracts_panel, "scale", Vector2(1.015, 1.015), 0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_contract_feedback_tween.chain().tween_property(
		_contracts_panel, "scale", Vector2.ONE, 0.14
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_playing() -> void:
	if SaveService.is_write_blocked or _menu_transitioning:
		return
	if DisplayServer.get_name() == "headless":
		_show_floor_now()
		return
	_menu_transitioning = true
	_start_playing_animated()


func _start_playing_animated() -> void:
	await ScreenTransition.cover()
	_show_floor_now()
	await ScreenTransition.reveal()
	_menu_transitioning = false


func _show_floor_now() -> void:
	if _floor == null:
		_floor = preload("res://src/floor/floor.tscn").instantiate() as FloorController
		add_child(_floor)
		_cashier_motion_director = CASHIER_MOTION_DIRECTOR_SCRIPT.new()
		_cashier_motion_director.name = "CashierMotionDirector"
		add_child(_cashier_motion_director)
		_cashier_motion_director.bind(_floor)
		_floor.cashier_visibility_changed.connect(func(_is_open: bool) -> void: _refresh_hud())
	_floor.show()
	_floor.set_physics_process(true)
	_floor.set_process_unhandled_input(true)
	_menu.hide()
	_is_playing = true
	_refresh_hud()
	AudioService.play_ambient()
	AudioService.play(&"confirm")


func _show_menu() -> void:
	if _menu_transitioning:
		return
	if _floor != null:
		_floor.set_physics_process(false)
		_floor.set_process_unhandled_input(false)
	if DisplayServer.get_name() == "headless":
		_show_menu_now()
		return
	_menu_transitioning = true
	_show_menu_animated()


func _show_menu_animated() -> void:
	await ScreenTransition.cover()
	_show_menu_now()
	await ScreenTransition.reveal()
	_menu_transitioning = false


func _show_menu_now() -> void:
	_is_playing = false
	if _floor != null:
		_floor.hide()
		_floor.set_physics_process(false)
		_floor.set_process_unhandled_input(false)
	_menu.show()
	_play_menu_reveal()
	AudioService.stop_ambient()
	_refresh_hud()


func _show_message(key: String) -> void:
	if _message != null:
		_present_message(tr(key))


func _show_contract_completed(title_key: String, reward: int) -> void:
	_message_serial += 1
	var serial := _message_serial
	_present_message(tr("CONTRACT_COMPLETE") % [tr(title_key), reward])
	await get_tree().create_timer(3.2).timeout
	if serial == _message_serial:
		_dismiss_message()


func _present_message(text_value: String) -> void:
	if _message_tween != null:
		_message_tween.kill()
	_message.text = text_value
	if text_value.is_empty():
		_message_panel.hide()
		_message.hide()
		return
	_message_panel.show()
	_message.show()
	_apply_message_final_state()
	if MotionPolicy.is_reduced():
		return
	_message_panel.modulate.a = 0.0
	_message.modulate.a = 0.0
	_message_panel.position.y = 98.0
	_message.position.y = 105.0
	_message_tween = create_tween().set_parallel(true)
	_message_tween.tween_property(_message_panel, "modulate:a", 1.0, 0.15)
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.15)
	_message_tween.tween_property(_message_panel, "position:y", 104.0, 0.17).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_message_tween.tween_property(_message, "position:y", 111.0, 0.17).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _dismiss_message() -> void:
	if _message_tween != null:
		_message_tween.kill()
	if MotionPolicy.is_reduced() or DisplayServer.get_name() == "headless":
		_message.text = ""
		_message_panel.hide()
		_message.hide()
		_apply_message_final_state()
		return
	_message_tween = create_tween().set_parallel(true)
	_message_tween.tween_property(_message_panel, "modulate:a", 0.0, 0.14)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.14)
	_message_tween.tween_property(_message_panel, "position:y", 98.0, 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_message_tween.tween_property(_message, "position:y", 105.0, 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_message_tween.finished.connect(
		func() -> void:
			_message.text = ""
			_message_panel.hide()
			_message.hide()
			_apply_message_final_state()
	)


func _apply_message_final_state() -> void:
	if _message_panel == null or _message == null:
		return
	_message_panel.modulate = Color.WHITE
	_message.modulate = Color.WHITE
	_message_panel.position.y = 104.0
	_message.position.y = 111.0


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing:
		if event.is_action_pressed("interact"):
			_start_playing()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("secondary"):
			_toggle_motion_preference()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("back"):
			_quit_game()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if SceneRouter.session != null:
		SceneRouter.return_to_floor()
	elif SaveService.state != null:
		SaveService.save()
	_guard.release()
	get_tree().quit()


func _exit_tree() -> void:
	_guard.release()
