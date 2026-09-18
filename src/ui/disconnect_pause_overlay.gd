class_name DisconnectPauseOverlay
extends CanvasLayer

var _paused_for_disconnect: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color("0b0a12e8")
	shade.size = Vector2(960, 540)
	add_child(shade)
	var message := Label.new()
	message.position = Vector2(180, 245)
	message.size = Vector2(600, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color("ffd23f"))
	message.text = tr("GAMEPAD_RECONNECT")
	add_child(message)
	InputRouter.gamepad_connection_changed.connect(set_gamepad_connected)
	hide()


func set_gamepad_connected(connected: bool) -> void:
	if connected:
		hide()
		if _paused_for_disconnect:
			get_tree().paused = false
			_paused_for_disconnect = false
		return
	show()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_for_disconnect = true
