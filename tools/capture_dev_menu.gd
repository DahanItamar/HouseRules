extends Node
## Developer menu QA: renders the floating widget closed on the floor and over
## a table, the panel open on each section (mouse and keyboard focus), the
## panel over a live cabinet, the FPS readout and the widget parked on the
## right edge. Saves and dev settings are isolated from the player's own.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_dev_menu.tscn
##     -- --capture-dir=dev_menu --capture-size=1920x1080

const OUTPUT := "res://tests/results/screenshots"

var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _main: Node
var _overlay: CanvasLayer


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if _requested_size.x > 0 and _requested_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().size = _requested_size
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	var wallet: Node = scene_root.get_node("Wallet")
	scene_root.get_node("MotionPolicy").call("set_reduced_motion_for_tests", false)
	DirAccess.make_dir_recursive_absolute(_output)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	_overlay = scene_root.get_node("DevOverlay") as CanvasLayer
	_overlay.set("settings_path", isolated.path_join("dev_settings.cfg"))
	var launcher: DevLauncher = _overlay.get("launcher")
	launcher.position = Vector2(2, 480)
	_main = load("res://src/ui/main.tscn").instantiate()
	_main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(_main)
	saves.new_game(20260919)
	wallet.call("set_test_mode", true)
	_main._start_playing()
	await get_tree().create_timer(1.2).timeout
	var panel: DevPanel = _overlay.get("panel")
	var actions: DevActions = _overlay.get("actions")

	await _snapshot("01_widget_closed_floor")
	_overlay.call("open_panel", false)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("02_panel_rooms")
	for section: int in [DevPanel.Section.GAMES, DevPanel.Section.TEST, DevPanel.Section.INFO]:
		panel.select_section(section)
		await get_tree().create_timer(0.3).timeout
		await _snapshot("0%d_panel_%s" % [section + 2, DevPanel.SECTION_NAMES[section].to_lower()])
	panel.select_section(DevPanel.Section.TEST)
	panel.focus_first()
	panel.move_focus(1)
	panel.move_focus(1)
	await get_tree().create_timer(0.2).timeout
	await _snapshot("06_panel_keyboard_focus")
	_overlay.call("close_panel")

	await actions.open_cabinet(&"blackjack")
	await get_tree().create_timer(1.4).timeout
	await _snapshot("07_widget_closed_over_blackjack")
	_overlay.call("open_panel", false)
	panel.select_section(DevPanel.Section.GAMES)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("08_panel_over_blackjack")
	_overlay.call("close_panel")

	await actions.open_cabinet(&"slot_classic")
	await get_tree().create_timer(1.4).timeout
	_overlay.call("set_fps_visible", true)
	await get_tree().create_timer(0.6).timeout
	await _snapshot("09_widget_and_fps_over_slots")
	_overlay.call("open_panel", false)
	panel.select_section(DevPanel.Section.INFO)
	await get_tree().create_timer(0.4).timeout
	await _snapshot("10_panel_info_over_slots")
	_overlay.call("close_panel")
	_overlay.call("set_fps_visible", false)

	await actions.go_to_room(&"vip")
	await get_tree().create_timer(1.2).timeout
	launcher.dropped.emit(Vector2(930, 250))
	await get_tree().create_timer(0.2).timeout
	await _snapshot("11_widget_right_edge_vip")
	_overlay.call("open_panel", false)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("12_panel_from_right_edge_vip")
	_overlay.call("close_panel")
	launcher.position = Vector2(2, 480)
	get_tree().quit()


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
