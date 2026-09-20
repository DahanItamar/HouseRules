extends CanvasLayer
## Global developer overlay (autoload `DevOverlay`), debug builds only.
##
## A floating brass widget, bottom-left by default, opens a slide-out panel
## for jumping between rooms, spots and tables, flipping test toggles and
## reading the running game's state. F10 or ` toggles it from anywhere.
##
## In a release export `OS.is_debug_build()` is false: the node adds no
## children, reads no settings and handles no input.

const LAYER: int = 120
const SETTINGS_PATH := "user://dev_settings.cfg"
const SETTINGS_SECTION := "dev_overlay"
## The left gutter beside every cabinet deck (decks start at x = 48).
const DEFAULT_LAUNCHER_POSITION := Vector2(2, 480)
const PANEL_MARGIN: float = 8.0
const PANEL_TOP: float = 16.0
const SLIDE_SECONDS: float = 0.16
const TOGGLE_KEYS: Array[Key] = [KEY_F10, KEY_QUOTELEFT]
const FPS_REFRESH_SECONDS: float = 0.25

## Tests simulate a release export by setting this to false before _ready.
var debug_build_override: Variant = null
var settings_path: String = SETTINGS_PATH
var enabled: bool = false
var launcher: DevLauncher
var panel: DevPanel
var actions: DevActions
var fps_label: Label
var _previous_focus: Control
var _slide: Tween
var _fps_elapsed: float = 0.0
var _fps_frames: int = 0


static func is_enabled_for(debug_build: bool) -> bool:
	return debug_build


func _ready() -> void:
	enabled = is_enabled_for(
		OS.is_debug_build() if debug_build_override == null else bool(debug_build_override)
	)
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	actions = DevActions.new()
	actions.name = "DevActions"
	add_child(actions)
	panel = DevPanel.new()
	panel.visible = false
	add_child(panel)
	panel.build(actions, self)
	panel.close_requested.connect(close_panel)
	fps_label = Label.new()
	fps_label.name = "DevFrameReadout"
	fps_label.position = Vector2(836, 4)
	fps_label.size = Vector2(120, 22)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	fps_label.add_theme_font_override("font", Typography.UI_FONT)
	fps_label.add_theme_font_size_override("font_size", Typography.CAPTION)
	fps_label.add_theme_color_override("font_color", DevPanel.IVORY)
	var readout_style := StyleBoxFlat.new()
	readout_style.bg_color = Color("0e0c0ee0")
	readout_style.border_color = DevPanel.BRASS_DIM
	readout_style.set_border_width_all(1)
	readout_style.set_corner_radius_all(4)
	fps_label.add_theme_stylebox_override("normal", readout_style)
	fps_label.visible = false
	add_child(fps_label)
	# The widget is added last so it stays clickable above its own panel.
	launcher = DevLauncher.new()
	launcher.position = DEFAULT_LAUNCHER_POSITION
	launcher.activated.connect(toggle_panel.bind(false))
	launcher.dropped.connect(_on_launcher_dropped)
	add_child(launcher)
	_load_settings()


func _process(delta: float) -> void:
	if fps_label == null or not fps_label.visible:
		return
	_fps_elapsed += delta
	_fps_frames += 1
	if _fps_elapsed < FPS_REFRESH_SECONDS:
		return
	var frame_ms := _fps_elapsed * 1000.0 / float(_fps_frames)
	_fps_elapsed = 0.0
	_fps_frames = 0
	var readout := "%d FPS  ·  %.1f ms" % [roundi(Engine.get_frames_per_second()), frame_ms]
	fps_label.text = readout


# --- Opening and closing ------------------------------------------------------------


func is_open() -> bool:
	return panel != null and panel.visible


func toggle_panel(from_keyboard: bool = false) -> void:
	if is_open():
		close_panel()
	else:
		open_panel(from_keyboard)


## Opens the panel on the widget's side of the screen. Keyboard opens focus the
## first row; mouse opens leave focus alone so no cyan ring appears.
func open_panel(from_keyboard: bool = false) -> void:
	if not enabled or is_open():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	panel.select_section(panel.section)
	panel.visible = true
	launcher.is_open = true
	_set_floor_hold(true)
	var target := panel_target_position()
	if _slide != null:
		_slide.kill()
	if MotionPolicy.is_reduced() or DisplayServer.get_name() == "headless":
		panel.position = target
	else:
		var hidden_x := -panel.size.x if _panel_on_left() else get_viewport_size().x
		panel.position = Vector2(hidden_x, target.y)
		_slide = create_tween()
		(
			_slide
			. tween_property(panel, "position", target, SLIDE_SECONDS)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	if from_keyboard:
		panel.focus_first()
	AudioService.play(&"confirm")


func close_panel() -> void:
	if not is_open():
		return
	if _slide != null:
		_slide.kill()
		_slide = null
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and panel.is_ancestor_of(focused):
		focused.release_focus()
	panel.visible = false
	launcher.is_open = false
	_set_floor_hold(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


func panel_target_position() -> Vector2:
	var screen := get_viewport_size()
	var x := launcher.position.x + DevLauncher.DIAMETER + PANEL_MARGIN
	if not _panel_on_left():
		x = launcher.position.x - PANEL_MARGIN - panel.size.x
	x = clampf(x, PANEL_MARGIN, screen.x - panel.size.x - PANEL_MARGIN)
	return Vector2(x, clampf(PANEL_TOP, 0.0, maxf(screen.y - panel.size.y, 0.0)))


func _panel_on_left() -> bool:
	return launcher.position.x + DevLauncher.DIAMETER * 0.5 < get_viewport_size().x * 0.5


func get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## The avatar stands still while the panel owns the keyboard and pad.
func _set_floor_hold(held: bool) -> void:
	var controller: FloorController = SceneRouter.floor
	if is_instance_valid(controller):
		controller.dev_overlay_open = held


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouse:
		return
	if _is_toggle(event):
		toggle_panel(true)
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	if (
		event.is_action_pressed(&"ui_cancel")
		or (InputMap.has_action(&"back") and event.is_action_pressed(&"back"))
	):
		close_panel()
	else:
		panel.handle_navigation(event)
	# While open the panel owns keys and pad buttons, so nothing reaches the game.
	get_viewport().set_input_as_handled()


static func _is_toggle(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return (
		key != null
		and key.pressed
		and not key.echo
		and (key.keycode in TOGGLE_KEYS or key.physical_keycode in TOGGLE_KEYS)
	)


# --- FPS readout ------------------------------------------------------------------


func fps_visible() -> bool:
	return fps_label != null and fps_label.visible


func toggle_fps() -> void:
	set_fps_visible(not fps_visible())


func set_fps_visible(shown: bool) -> void:
	if fps_label == null:
		return
	fps_label.visible = shown
	_fps_elapsed = 0.0
	_fps_frames = 0
	_save_settings()


# --- Settings -----------------------------------------------------------------------


func _on_launcher_dropped(at: Vector2) -> void:
	launcher.position = DevLauncher.snap_to_edge(at, get_viewport_size())
	if is_open():
		panel.position = panel_target_position()
	_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved: Variant = config.get_value(SETTINGS_SECTION, "launcher_position", null)
	if saved is Vector2:
		launcher.position = DevLauncher.snap_to_edge(saved as Vector2, get_viewport_size())
	fps_label.visible = bool(config.get_value(SETTINGS_SECTION, "fps_visible", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "launcher_position", launcher.position)
	config.set_value(SETTINGS_SECTION, "fps_visible", fps_visible())
	config.save(settings_path)
