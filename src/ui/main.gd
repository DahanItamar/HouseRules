extends Node

var _guard := InstanceGuard.new()
var _floor: FloorController
var _menu: CanvasLayer
var _hud: Label
var _message: Label
var _is_playing: bool = false


func _ready() -> void:
	Engine.max_fps = 60
	get_tree().auto_accept_quit = false
	if not _guard.acquire():
		get_tree().quit()
		return
	SaveService.load_failed.connect(_show_message)
	SaveService.save_failed.connect(func(_error: Error) -> void: _show_message("SAVE_FAILED"))
	SceneRouter.menu_requested.connect(_show_menu)
	_build_hud()
	var error: Error = SaveService.load_game()
	_build_menu()
	if error != OK:
		_message.text = tr("SAVE_INCOMPATIBLE")
	Wallet.balance_changed.connect(func(_old: int, _new: int) -> void: _refresh_hud())
	Economy.debt_changed.connect(func(_debt: int) -> void: _refresh_hud())
	InputRouter.active_device_changed.connect(func(_device: int) -> void: _refresh_menu())
	_refresh_hud()
	_refresh_menu()


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(32, 24)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color("ffd23f"))
	hud_layer.add_child(_hud)
	_message = Label.new()
	_message.position = Vector2(32, 508)
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", Color("ff8a3d"))
	hud_layer.add_child(_message)


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 6
	add_child(_menu)
	var background := ColorRect.new()
	background.size = Vector2(960, 540)
	background.color = Color("0b0a12")
	_menu.add_child(background)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(120, 180)
	title.add_theme_font_size_override("font_size", 48)
	title.text = tr("GAME_TITLE")
	_menu.add_child(title)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.position = Vector2(124, 282)
	prompt.add_theme_font_size_override("font_size", 20)
	_menu.add_child(prompt)


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
