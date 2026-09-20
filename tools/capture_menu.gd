extends Node
## Captures the main menu at real output size.
##
##   godot --path . tools/capture_menu.tscn -- --capture-size=1920x1080
##
## `capture_game.gd` cannot photograph the menu: the shipped project sets
## `house_rules/testing/start_on_floor`, so `Main` defers straight past the menu
## onto the casino floor and the shot named `01_menu` is really the floor. This
## tool clears that setting before `Main` is built, so the menu is what loads.
##
## Saves and the instance lock are isolated from the player's own data.

const OUTPUT := "res://tests/results/screenshots/menu"

var _output := OUTPUT
var _requested_size := Vector2i(1920, 1080)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = "res://tests/results/screenshots".path_join(
				argument.trim_prefix("--capture-dir=")
			)
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	get_window().mode = Window.MODE_WINDOWED
	get_window().borderless = true
	get_window().size = _requested_size
	DirAccess.make_dir_recursive_absolute(_output)
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	# The one line this tool exists for: without it Main walks straight past
	# the menu and the capture photographs the floor instead.
	ProjectSettings.set_setting("house_rules/testing/start_on_floor", false)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._refresh_hud()
	# The menu reveal is a tween; let it land before the shutter.
	await get_tree().create_timer(1.1).timeout
	await _snapshot("01_menu")
	if not main._menu_rows.is_empty():
		main._menu_rows[1].grab_focus()
		await get_tree().create_timer(0.3).timeout
		await _snapshot("02_menu_focus")
	get_tree().quit()


func _snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_output.path_join(name + ".png")))
	print("SCREENSHOT %s %s" % [name, image.get_size()])
