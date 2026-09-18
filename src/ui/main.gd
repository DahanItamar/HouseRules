extends Node

var _guard := InstanceGuard.new()
var _floor: FloorController
var _menu: CanvasLayer
var _hud_layer: CanvasLayer
var _hud: Label
var _message: Label
var _contracts: Label
var _contracts_panel: Panel
var _is_playing: bool = false


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
	_build_menu()
	if error != OK:
		_message.text = tr("SAVE_INCOMPATIBLE")
	Wallet.balance_changed.connect(func(_old: int, _new: int) -> void: _refresh_hud())
	Economy.debt_changed.connect(func(_debt: int) -> void: _refresh_hud())
	Economy.contracts_changed.connect(_refresh_hud)
	Economy.contract_completed.connect(_show_contract_completed)
	SceneRouter.session_changed.connect(_refresh_hud)
	InputRouter.active_device_changed.connect(func(_device: int) -> void: _refresh_menu())
	_refresh_hud()
	_refresh_menu()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	var bank_panel := _panel(Vector2(22, 18), Vector2(286, 54), Color("17161ae8"), Color("c8a34b"))
	_hud_layer.add_child(bank_panel)
	_hud = Label.new()
	_hud.position = Vector2(38, 29)
	_hud.add_theme_font_size_override("font_size", Typography.PROMINENT)
	_hud.add_theme_color_override("font_color", Color("f2c84b"))
	_hud_layer.add_child(_hud)
	_message = Label.new()
	_message.position = Vector2(344, 500)
	_message.size = Vector2(572, 28)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_message.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_message.add_theme_color_override("font_color", Color("f1e8d8"))
	_hud_layer.add_child(_message)
	_contracts_panel = _panel(
		Vector2(638, 18), Vector2(300, 108), Color("17161ae8"), Color("6e5225")
	)
	_hud_layer.add_child(_contracts_panel)
	_contracts = Label.new()
	_contracts.position = Vector2(654, 27)
	_contracts.size = Vector2(268, 92)
	_contracts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_contracts.add_theme_font_size_override("font_size", 12)
	_contracts.add_theme_color_override("font_color", Color("b8ad9c"))
	_hud_layer.add_child(_contracts)


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 6
	add_child(_menu)
	var background := TextureRect.new()
	background.name = "CasinoHallArt"
	background.texture = preload("res://assets/production/environments/casino_menu_hall.png")
	background.size = Vector2(960, 540)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_menu.add_child(background)
	var readability := ColorRect.new()
	readability.size = Vector2(548, 540)
	readability.color = Color("0c0b0dcc")
	_menu.add_child(readability)
	var brass_rule := ColorRect.new()
	brass_rule.position = Vector2(70, 116)
	brass_rule.size = Vector2(72, 3)
	brass_rule.color = Color("c8a34b")
	_menu.add_child(brass_rule)
	var kicker := Label.new()
	kicker.position = Vector2(70, 82)
	kicker.text = tr("MENU_KICKER")
	kicker.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	kicker.add_theme_color_override("font_color", Color("c8a34b"))
	_menu.add_child(kicker)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(66, 140)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("f1e8d8"))
	title.text = tr("GAME_TITLE")
	_menu.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(72, 222)
	subtitle.size = Vector2(380, 60)
	subtitle.text = tr("MENU_SUBTITLE")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("b8ad9c"))
	_menu.add_child(subtitle)
	var prompt_panel := _panel(
		Vector2(70, 320), Vector2(360, 104), Color("17161af2"), Color("c8a34b")
	)
	_menu.add_child(prompt_panel)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.position = Vector2(92, 339)
	prompt.size = Vector2(316, 70)
	prompt.add_theme_font_size_override("font_size", Typography.PROMINENT)
	prompt.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu.add_child(prompt)


func _panel(at: Vector2, dimensions: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh_menu() -> void:
	(_menu.get_node("Prompt") as Label).text = (
		tr("MENU_CONTROLS") % [InputRouter.glyph("interact"), InputRouter.glyph("back")]
	)


func _refresh_hud() -> void:
	_hud.text = tr("HUD_CHIPS") % Wallet.balance
	if Economy.debt > 0:
		_hud.text += "     " + tr("HUD_DEBT") % Economy.debt
	if Economy.is_below_solvency_floor():
		_hud.text += "     " + tr("HUD_CASHIER")
	if _contracts != null:
		_contracts.visible = SceneRouter.session == null
		_contracts_panel.visible = _contracts.visible
		_contracts.text = tr("CONTRACTS_HEADING") + "\n" + "\n".join(Economy.contract_lines())


func _start_playing() -> void:
	if SaveService.is_write_blocked:
		return
	if _floor == null:
		_floor = preload("res://src/floor/floor.tscn").instantiate() as FloorController
		add_child(_floor)
	_floor.show()
	_floor.set_physics_process(true)
	_floor.set_process_unhandled_input(true)
	_menu.hide()
	_is_playing = true
	AudioService.play(&"confirm")


func _show_menu() -> void:
	_is_playing = false
	if _floor != null:
		_floor.hide()
		_floor.set_physics_process(false)
		_floor.set_process_unhandled_input(false)
	_menu.show()


func _show_message(key: String) -> void:
	if _message != null:
		_message.text = tr(key)


func _show_contract_completed(title_key: String, reward: int) -> void:
	_message.text = tr("CONTRACT_COMPLETE") % [tr(title_key), reward]


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing:
		if event.is_action_pressed("interact"):
			_start_playing()
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
