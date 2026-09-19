class_name FloorController
extends Node2D

signal cashier_visibility_changed(is_open: bool)
signal room_changed(room_id: StringName)

const SPEED: float = 88.0
## A hitch longer than this is treated as this long, so one late frame can
## never carry the avatar across a room. Motion is also sub-stepped.
const MAX_FRAME_DELTA: float = 0.25
const INTERACTION_RADIUS: float = 76.0
const MAIN_FLOOR := &"main_floor"
const HIGH_ROLLER := &"high_roller"
const VIP := &"vip"
const EXIT_ANCHOR := &"exit"
const CASHIER_POSITION := Vector2(668, 402)
const WING_POSITIONS: Dictionary = {&"high_roller": Vector2(150, 274), &"vip": Vector2(862, 216)}
const WING_THRESHOLDS: Dictionary = {&"high_roller": 5000, &"vip": 100_000}
const FLOOR_AVATAR_SCRIPT := preload("res://src/floor/floor_avatar.gd")
const CASHIER_WAYPOINT_SCRIPT := preload("res://src/floor/cashier_waypoint.gd")
const PRACTICAL_LIGHT_RIG_SCRIPT := preload("res://src/floor/practical_light_rig.gd")
const FLOOR_FOREGROUND_SCRIPT := preload("res://src/floor/floor_foreground.gd")
const COLLISION_OVERLAY_SCRIPT := preload("res://src/floor/floor_collision_overlay.gd")
const PLAQUE_FRAME: Texture2D = preload("res://assets/production/ui/plaque_frame.png")
const PLAQUE_ORNAMENT: Texture2D = preload("res://assets/production/ui/plaque_ornament.png")
## The plaque master is drawn at quarter scale so its brass stays crisp at 4K.
const PLAQUE_SCALE: float = 0.25
const PLAQUE_MARGIN: int = 64
const PLAQUE_PADDING := Vector2(18, 12)
const ANIMATED_PAIR_LABEL_SCRIPT := preload("res://src/ui/animated_pair_label.gd")
const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const CYAN := Color("48c5d5")
const MACHINE_ZONE_RADIUS: float = 50.0
## The join zone matches the brass diamond inlay painted in front of each island.
const MACHINE_ZONE_SCALE := Vector2(1.28, 0.62)
const INLAY_HIGHLIGHT := Color("f2c84b")
const JOIN_DIALOG_SIZE := Vector2(286, 70)
const JOIN_DIALOG_OFFSET := Vector2(-143, 40)
const CAMERA_CENTER := Vector2(480, 270)
const CAMERA_FOCUS_ZOOM := Vector2(1.03, 1.03)
const CAMERA_FOCUS_OFFSET: float = 9.0
const CASHIER_NO_DIRECTION: int = -1
const HUD_BAND_HEIGHT: float = 72.0
const DEV_BUTTON_SIZE := Vector2(190, 44)
const DEV_TARGETS: Array[Dictionary] = [
	{"id": &"spawn", "label": "SPAWN", "position": Vector2(480, 408)},
	{"id": &"slot_classic", "label": "SLOTS", "position": Vector2(324, 246)},
	{"id": &"blackjack", "label": "BLACKJACK", "position": Vector2(493, 246)},
	{"id": &"minefield_vault", "label": "VAULT", "position": Vector2(671, 246)},
	{"id": &"cashier", "label": "CASHIER", "position": CASHIER_POSITION},
	{"id": &"main_floor", "label": "MAIN FLOOR", "position": Vector2(480, 408)},
	{"id": &"high_roller", "label": "HIGH ROLLER SALON", "position": Vector2(150, 274)},
	{"id": &"vip", "label": "VIP PENTHOUSE", "position": Vector2(862, 216)},
]
const ROOM_IDS: Array[StringName] = [&"main_floor", &"high_roller", &"vip"]
var room: FloorRoomLayout
var previous_room_id: StringName = &""
var avatar_position := Vector2(480, 408)
var nearby_definition: CabinetDefinition
var nearby_wing: StringName = &""
var nearby_exit: bool = false
## Playable cabinets in the current room, by id, at their join anchors.
var cabinet_positions: Dictionary = {}
var definitions: Dictionary = {}
var _background: Texture2D
var _prompt: Label
var _prompt_plaque: NinePatchRect
var _prompt_ornament: Sprite2D
var _cashier_open: bool = false
var _avatar_visual: Node2D
var _depth_layer: Node2D
var _cashier_panel: Panel
var _cashier_scrim: ColorRect
var _cashier_balance: AnimatedNumberLabel
var _cashier_debt: AnimatedNumberLabel
var _cashier_amount: AnimatedNumberLabel
var _cashier_preview: Label
var _cashier_marker: Button
var _cashier_repay: Button
var _cashier_close: Button
var _cashier_repay_amount: int = 0
var _ambient_time: float = 0.0
var _dismissed_game: StringName = &""
var _last_nearby_game: StringName = &""
var _prompt_signature: String = ""
var _prompt_tween: Tween
var _prompt_target_visible: bool = false
var _cashier_tween: Tween
var _cashier_transaction_tween: Tween
var _cashier_is_closing: bool = false
var _cashier_transfer_layer: Control
var _cashier_summary_flash: ColorRect
var _floor_camera: Camera2D
var _camera_tween: Tween
var _camera_focus_id: StringName = &""
var _dust: CPUParticles2D
var _practical_lights: Node2D
var _cashier_waypoint: CashierWaypoint
var _directions_layer: CanvasLayer
var _floor_prompts_visible: bool = true
var _has_moved: bool = false
var _dev_tools_enabled: bool = false
var _dev_layer: CanvasLayer
var _dev_panel: Panel
var _dev_buttons: Array[Button] = []
var _dev_open: bool = false
var _floor_foreground: Node2D
var _collision_overlay: Node2D
var _room_layer: CanvasLayer
var _room_status: Label
var _room_back: Button


func _ready() -> void:
	# 4K masters are mipmapped, so the downscaled room stays crisp without shimmer.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room = FloorRoomLayout.load_room(MAIN_FLOOR)
	_prefetch_rooms()
	_background = room.background()
	_load_room_cabinets()
	_build_camera()
	_build_dust()
	_build_practical_lights()
	_depth_layer = Node2D.new()
	_depth_layer.name = "DepthLayer"
	_depth_layer.y_sort_enabled = true
	_depth_layer.z_index = 2
	add_child(_depth_layer)
	_floor_foreground = FLOOR_FOREGROUND_SCRIPT.new() as Node2D
	_floor_foreground.name = "FloorForeground"
	_floor_foreground.call("configure", room)
	_depth_layer.add_child(_floor_foreground)
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	_avatar_visual = FLOOR_AVATAR_SCRIPT.new()
	_avatar_visual.name = "FloorAvatar"
	_avatar_visual.position = avatar_position
	_depth_layer.add_child(_avatar_visual)
	_prompt = Label.new()
	_prompt.z_index = 10
	_prompt.size = Vector2(260, 72)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_constant_override("line_spacing", 2)
	_prompt.add_theme_color_override("font_color", IVORY)
	_build_prompt_plaque()
	add_child(_prompt)
	_build_cashier_waypoint()
	_build_cashier_menu()
	_build_room_hud()
	_dev_tools_enabled = (
		bool(ProjectSettings.get_setting("house_rules/testing/dev_floor_tools", false))
		and OS.is_debug_build()
	)
	if _dev_tools_enabled:
		_build_dev_floor_tools()
	SceneRouter.register_floor(self)
	SceneRouter.session_changed.connect(_sync_overlay_layers)
	visibility_changed.connect(_sync_overlay_layers)
	Wallet.balance_changed.connect(func(_old: int, _new: int) -> void: refresh_proximity())
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh_proximity())
	refresh_proximity()


func move_avatar(direction: Vector2, delta: float) -> void:
	var origin := avatar_position
	if not direction.is_zero_approx():
		var motion := direction.normalized() * SPEED * clampf(delta, 0.0, MAX_FRAME_DELTA)
		avatar_position = room.resolve_motion(avatar_position, motion)
	if _avatar_visual != null:
		_avatar_visual.position = avatar_position
		_avatar_visual.call("set_motion", avatar_position - origin)
	if not avatar_position.is_equal_approx(origin):
		_has_moved = true
	refresh_proximity()
	queue_redraw()


func _is_walkable(point: Vector2) -> bool:
	return room.is_walkable(point)


## Starts loading the other rooms' 4K layers in the background, so switching
## rooms never stalls on a synchronous texture load.
func _prefetch_rooms() -> void:
	for room_id: StringName in ROOM_IDS:
		if room_id == MAIN_FLOOR:
			continue
		var layout := FloorRoomLayout.load_room(room_id)
		for path: String in [layout.background_path, layout.foreground_path]:
			if not ResourceLoader.has_cached(path):
				ResourceLoader.load_threaded_request(path)


## Loads the current room's playable cabinets. A cabinet whose game has not
## been built yet is skipped, so rooms can list planned tables safely.
func _load_room_cabinets() -> void:
	cabinet_positions.clear()
	for id: StringName in room.cabinets:
		var path := "res://data/cabinets/%s.tres" % id
		if not ResourceLoader.exists(path) or not CabinetSceneRegistry.has_scene(id):
			continue
		var definition: CabinetDefinition = definitions.get(id, load(path))
		assert(definition != null and definition.is_valid_definition(), "Invalid cabinet: %s" % id)
		assert(definition.id == id, "Cabinet resource ID must match its registry key: %s" % id)
		definitions[id] = definition
		cabinet_positions[id] = room.anchor(id)


## A preview room has no playable table yet and says so.
func is_preview_room() -> bool:
	return room != null and room.preview_only and cabinet_positions.is_empty()


## Wings open once the player has wagered enough, and always in the test bank.
func is_wing_unlocked(wing_id: StringName) -> bool:
	return Wallet.test_mode_enabled or Economy.lifetime_wagered >= int(WING_THRESHOLDS[wing_id])


func is_main_floor() -> bool:
	return room != null and room.id == MAIN_FLOOR


## Switches the whole environment. The same avatar, wallet and save carry over.
func enter_room(room_id: StringName) -> void:
	assert(room_id in ROOM_IDS, "Unknown floor room: %s" % room_id)
	if room != null and room.id == room_id:
		return
	if _cashier_open:
		_close_cashier()
	var from_id: StringName = room.id if room != null else MAIN_FLOOR
	room = FloorRoomLayout.load_room(room_id)
	previous_room_id = from_id
	_background = room.background()
	_floor_foreground.call("configure", room)
	_load_room_cabinets()
	if room_id == MAIN_FLOOR:
		avatar_position = WING_POSITIONS.get(from_id, room.return_point)
	else:
		avatar_position = room.spawn
	if _avatar_visual != null:
		_avatar_visual.position = avatar_position
	var main := is_main_floor()
	if _practical_lights != null:
		_practical_lights.visible = main
	_dismissed_game = &""
	_refresh_room_hud()
	refresh_proximity()
	queue_redraw()
	room_changed.emit(room.id)
	AudioService.play(&"confirm")


func return_to_main_floor() -> void:
	enter_room(MAIN_FLOOR)


func refresh_proximity() -> void:
	nearby_definition = null
	nearby_wing = &""
	nearby_exit = false
	var nearest_score: float = INF
	for id: StringName in cabinet_positions:
		var score := _machine_proximity_score(avatar_position, cabinet_positions[id])
		if score <= 1.0 and score <= nearest_score:
			nearest_score = score
			nearby_definition = definitions.get(id)
	if is_main_floor() and nearby_definition == null:
		var nearest_wing_distance: float = INTERACTION_RADIUS
		for id: StringName in WING_POSITIONS:
			var distance: float = avatar_position.distance_to(WING_POSITIONS[id])
			if distance <= nearest_wing_distance:
				nearest_wing_distance = distance
				nearby_wing = id
	elif not is_main_floor() and nearby_definition == null and room.anchors.has(EXIT_ANCHOR):
		nearby_exit = avatar_position.distance_to(room.anchor(EXIT_ANCHOR)) <= INTERACTION_RADIUS
	var current_game: StringName = nearby_definition.id if nearby_definition != null else &""
	_update_camera_focus(current_game)
	if current_game != _last_nearby_game:
		_dismissed_game = &""
	_last_nearby_game = current_game
	if _prompt != null:
		_update_prompt()
	_update_cashier_waypoint()
	queue_redraw()


func interact() -> bool:
	if nearby_exit:
		return_to_main_floor()
		return true
	if nearby_definition != null:
		if _dismissed_game == nearby_definition.id:
			return false
		if Wallet.balance < nearby_definition.min_bet:
			return false
		SceneRouter.enter_cabinet(nearby_definition)
		AudioService.play(&"confirm")
		return true
	if nearby_wing != &"":
		if is_wing_unlocked(nearby_wing):
			enter_room(nearby_wing)
			return true
		_update_prompt()
		return false
	if is_main_floor() and avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS:
		_cashier_open = true
		cashier_visibility_changed.emit(true)
		_cashier_repay_amount = mini(10, _cashier_repayment_limit())
		AudioService.play(&"confirm")
		_update_prompt()
		return true
	return false


func set_prompt_visible(is_visible: bool) -> void:
	_floor_prompts_visible = is_visible
	if _prompt != null:
		_update_prompt()
	_update_cashier_waypoint()
	queue_redraw()


func dismiss_game_prompt() -> void:
	if nearby_definition != null:
		_dismissed_game = nearby_definition.id
		_last_nearby_game = nearby_definition.id
		_update_prompt()


func _physics_process(delta: float) -> void:
	if MotionPolicy.allows_continuous_motion():
		_ambient_time += delta
	queue_redraw()
	if not _cashier_open and not _dev_open:
		move_avatar(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta)


func _unhandled_input(event: InputEvent) -> void:
	if _dev_tools_enabled and event.is_action_pressed("help"):
		_toggle_dev_floor_tools()
		get_viewport().set_input_as_handled()
		return
	if _dev_tools_enabled and _is_key_press(event, KEY_F2):
		toggle_collision_overlay()
		get_viewport().set_input_as_handled()
		return
	if _dev_open:
		if event.is_action_pressed("back"):
			_toggle_dev_floor_tools(false)
			get_viewport().set_input_as_handled()
		return
	if not is_main_floor():
		if event.is_action_pressed("back"):
			if nearby_definition != null and _dismissed_game != nearby_definition.id:
				dismiss_game_prompt()
			else:
				return_to_main_floor()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			interact()
			get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("back")
		or event.is_action_pressed("interact")
		or event.is_action_pressed("secondary")
		or (_cashier_open and _cashier_direction(event) != CASHIER_NO_DIRECTION)
	):
		get_viewport().set_input_as_handled()
	if _cashier_is_closing:
		return
	if _cashier_open:
		if event.is_action_pressed("back"):
			_close_cashier()
		elif event.is_action_pressed("interact"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and _cashier_panel.is_ancestor_of(focused):
				(focused as Button).pressed.emit()
		else:
			_move_cashier_focus(_cashier_direction(event))
		return
	if event.is_action_pressed("back"):
		if nearby_definition != null and _dismissed_game != nearby_definition.id:
			_dismissed_game = nearby_definition.id
			_update_prompt()
		else:
			SceneRouter.return_to_menu()
	elif event.is_action_pressed("interact"):
		interact()


static func _is_key_press(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.keycode == keycode


func _update_prompt() -> void:
	var previous_text := _prompt.text
	_prompt.position = Vector2(56, 454)
	_prompt.size = Vector2(848, 54)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _cashier_is_closing:
		_prompt.text = ""
	elif _cashier_open:
		_prompt.position = Vector2(56, 486)
		_prompt.size = Vector2(848, 42)
		_refresh_cashier_menu()
		_prompt.text = (
			tr("CASHIER_ACTIONS")
			% [InputRouter.glyph("move"), InputRouter.glyph("interact"), InputRouter.glyph("back")]
		)
	elif not is_main_floor() and nearby_definition == null:
		_prompt.position = Vector2(330, 482)
		_prompt.size = Vector2(300, 34)
		if nearby_exit:
			_prompt.text = tr("ROOM_EXIT_PROMPT") % InputRouter.glyph("interact")
		else:
			_prompt.text = ""
	elif nearby_definition != null:
		if _dismissed_game == nearby_definition.id:
			_prompt.text = ""
		elif Wallet.balance < nearby_definition.min_bet:
			_prompt.position = _join_dialog_position(nearby_definition.id)
			_prompt.size = JOIN_DIALOG_SIZE
			_prompt.text = (
				tr("FLOOR_UNAVAILABLE")
				% [tr(nearby_definition.name_key), nearby_definition.min_bet]
			)
		else:
			_prompt.position = _join_dialog_position(nearby_definition.id)
			_prompt.size = JOIN_DIALOG_SIZE
			_prompt.text = (
				tr("FLOOR_JOIN_DIALOG")
				% [
					tr(nearby_definition.name_key),
					nearby_definition.min_bet,
					nearby_definition.max_bet,
					InputRouter.glyph("interact"),
					InputRouter.glyph("back")
				]
			)
	elif nearby_wing != &"":
		var wing_at: Vector2 = WING_POSITIONS[nearby_wing]
		_prompt.position = Vector2(clampf(wing_at.x - 115.0, 24.0, 706.0), wing_at.y + 40.0)
		_prompt.size = Vector2(230, 72)
		if is_wing_unlocked(nearby_wing):
			_prompt.text = (
				tr("WING_ENTER")
				% [InputRouter.glyph("interact"), tr("WING_" + String(nearby_wing).to_upper())]
			)
		else:
			_prompt.text = (
				tr("WING_LOCKED")
				% [tr("WING_" + String(nearby_wing).to_upper()), WING_THRESHOLDS[nearby_wing]]
			)
	elif avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS:
		_prompt.position = Vector2(350, 472)
		_prompt.size = Vector2(260, 44)
		_prompt.text = tr("CASHIER_PROMPT") % InputRouter.glyph("interact")
	elif not _has_moved:
		_prompt.position = Vector2(330, 486)
		_prompt.size = Vector2(300, 34)
		_prompt.text = (tr("FLOOR_HELP") % [InputRouter.glyph("move"), InputRouter.glyph("back")])
	else:
		_prompt.text = ""
	_prompt_target_visible = _floor_prompts_visible and not _prompt.text.is_empty()
	if _prompt_target_visible:
		_prompt.visible = true
		_animate_prompt_change()
	else:
		_prompt.text = previous_text
		_animate_prompt_hide()
	queue_redraw()


func _build_prompt_plaque() -> void:
	_prompt_plaque = NinePatchRect.new()
	_prompt_plaque.name = "PromptPlaque"
	_prompt_plaque.texture = PLAQUE_FRAME
	_prompt_plaque.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_prompt_plaque.set_patch_margin(side, PLAQUE_MARGIN)
	_prompt_plaque.scale = Vector2.ONE * PLAQUE_SCALE
	_prompt_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_plaque.z_index = 9
	_prompt_plaque.visible = false
	add_child(_prompt_plaque)
	_prompt_ornament = Sprite2D.new()
	_prompt_ornament.name = "PromptOrnament"
	_prompt_ornament.texture = PLAQUE_ORNAMENT
	_prompt_ornament.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_prompt_ornament.scale = Vector2.ONE * PLAQUE_SCALE * 1.6
	_prompt_ornament.z_index = 9
	_prompt_ornament.visible = false
	add_child(_prompt_ornament)


## The brass plaque tracks the prompt's rectangle and fade every frame.
func _sync_prompt_plaque() -> void:
	if _prompt_plaque == null:
		return
	var shown := _prompt != null and _prompt.visible and not _prompt.text.is_empty()
	_prompt_plaque.visible = shown
	var join_dialog := nearby_definition != null and _dismissed_game != nearby_definition.id
	_prompt_ornament.visible = shown and join_dialog
	if not shown:
		return
	var rect := Rect2(_prompt.position - PLAQUE_PADDING, _prompt.size + PLAQUE_PADDING * 2.0)
	_prompt_plaque.position = rect.position
	_prompt_plaque.size = rect.size / PLAQUE_SCALE
	_prompt_plaque.modulate.a = _prompt.modulate.a
	_prompt_ornament.position = Vector2(rect.get_center().x, rect.position.y + 1.0)
	_prompt_ornament.modulate.a = _prompt.modulate.a


func _join_dialog_position(game_id: StringName) -> Vector2:
	var machine_position: Vector2 = cabinet_positions.get(game_id, CAMERA_CENTER)
	var intended := machine_position + JOIN_DIALOG_OFFSET
	return Vector2(
		clampf(intended.x, 24.0, 960.0 - JOIN_DIALOG_SIZE.x - 24.0),
		clampf(intended.y, 104.0, 540.0 - JOIN_DIALOG_SIZE.y - 24.0)
	)


func nearby_definition_position() -> Vector2:
	if nearby_definition == null:
		return CAMERA_CENTER
	return cabinet_positions.get(nearby_definition.id, CAMERA_CENTER)


func _machine_proximity_score(point: Vector2, machine_position: Vector2) -> float:
	var delta := point - machine_position
	var radii := Vector2(
		MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.x, MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.y
	)
	return Vector2(delta.x / radii.x, delta.y / radii.y).length()


func _animate_prompt_change() -> void:
	var signature := "%s|%s" % [_prompt.text, _prompt.position]
	if signature == _prompt_signature:
		return
	_prompt_signature = signature
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt.modulate.a = 0.25
	_prompt.pivot_offset = _prompt.size * 0.5
	var final_position := _prompt.position
	_prompt.position = (
		final_position if MotionPolicy.is_reduced() else final_position + Vector2(0, 8)
	)
	_prompt.scale = Vector2.ONE
	_prompt_tween = create_tween().set_parallel(true)
	var duration := MotionPolicy.finite_duration(0.15)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD)
	if not MotionPolicy.is_reduced():
		(
			_prompt_tween
			. tween_property(_prompt, "position", final_position, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)


func _animate_prompt_hide() -> void:
	if _prompt_signature == "hidden":
		return
	_prompt_signature = "hidden"
	if _prompt_tween != null:
		_prompt_tween.kill()
	if not _prompt.visible or MotionPolicy.is_reduced():
		_finish_prompt_hide()
		return
	var exit_position := _prompt.position + Vector2(0, 6)
	_prompt_tween = create_tween().set_parallel(true)
	(
		_prompt_tween
		. tween_property(_prompt, "modulate:a", 0.0, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_prompt_tween
		. tween_property(_prompt, "position", exit_position, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_prompt_tween.finished.connect(_finish_prompt_hide)


func _finish_prompt_hide() -> void:
	if _prompt_target_visible:
		return
	_prompt.visible = false
	_prompt.text = ""
	_prompt.modulate.a = 1.0
	_prompt_tween = null
	queue_redraw()


func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.name = "CasinoDust"
	_dust.position = Vector2(480, 270)
	_dust.amount = 42
	_dust.lifetime = 6.5
	_dust.preprocess = 6.5
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(440, 220)
	_dust.direction = Vector2.UP
	_dust.spread = 35.0
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 8.0
	_dust.gravity = Vector2.ZERO
	_dust.scale_amount_min = 0.8
	_dust.scale_amount_max = 2.2
	_dust.color = Color("f2d58d32")
	_dust.z_index = 1
	add_child(_dust)


func _build_camera() -> void:
	_floor_camera = Camera2D.new()
	_floor_camera.name = "FloorCamera"
	_floor_camera.position = CAMERA_CENTER
	_floor_camera.position_smoothing_enabled = false
	_floor_camera.enabled = true
	add_child(_floor_camera)


func _build_practical_lights() -> void:
	_practical_lights = PRACTICAL_LIGHT_RIG_SCRIPT.new() as Node2D
	_practical_lights.name = "PracticalLightRig"
	_practical_lights.z_index = 1
	add_child(_practical_lights)


func _build_cashier_waypoint() -> void:
	_directions_layer = CanvasLayer.new()
	_directions_layer.name = "FloorDirections"
	_directions_layer.layer = 4
	add_child(_directions_layer)
	_cashier_waypoint = CASHIER_WAYPOINT_SCRIPT.new() as CashierWaypoint
	_directions_layer.add_child(_cashier_waypoint)


func _update_cashier_waypoint() -> void:
	if _cashier_waypoint == null:
		return
	var near_cashier := avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS
	_cashier_waypoint.update_route(
		avatar_position,
		CASHIER_POSITION,
		(
			_floor_prompts_visible
			and visible
			and is_main_floor()
			and Economy.is_below_solvency_floor()
			and not near_cashier
			and not _cashier_open
		)
	)


## CanvasLayers ignore their parent's visibility, so floor-owned overlays follow
## the floor explicitly and never sit on top of a cabinet session.
func _sync_overlay_layers() -> void:
	var floor_visible := is_visible_in_tree() and SceneRouter.session == null
	if _directions_layer != null:
		_directions_layer.visible = floor_visible
	if _dev_layer != null:
		_dev_layer.visible = floor_visible
		if not floor_visible and _dev_open:
			_toggle_dev_floor_tools(false)
	if _room_layer != null:
		_room_layer.visible = floor_visible and room != null and not is_main_floor()


func _build_room_hud() -> void:
	_room_layer = CanvasLayer.new()
	_room_layer.name = "RoomHud"
	_room_layer.layer = 8
	add_child(_room_layer)
	_room_status = Label.new()
	_room_status.name = "RoomStatus"
	# The room's name is painted into its architecture; this line only says the
	# room is a preview, next to the way back.
	_room_status.position = Vector2(50, 426)
	_room_status.size = Vector2(420, 22)
	_room_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_room_status.add_theme_font_override("font", Typography.UI_FONT)
	_room_status.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	_room_status.add_theme_color_override("font_color", BRASS)
	_room_layer.add_child(_room_status)
	_room_back = Button.new()
	_room_back.name = "BackToMainFloor"
	_room_back.position = Vector2(48, 452)
	_room_back.size = Vector2(212, 48)
	_room_back.focus_mode = Control.FOCUS_ALL
	_room_back.add_theme_font_override("font", Typography.UI_FONT)
	_room_back.add_theme_font_size_override("font_size", Typography.CONTROL)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("141013f2") if state != "pressed" else Color("0c0a0c")
		style.border_color = CYAN if state == "focus" else BRASS
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(6)
		_room_back.add_theme_stylebox_override(state, style)
	_room_back.pressed.connect(return_to_main_floor)
	_room_layer.add_child(_room_back)
	ButtonFeedback.attach(_room_back)
	_refresh_room_hud()


func _refresh_room_hud() -> void:
	if _room_layer == null:
		return
	_room_status.text = tr("ROOM_PREVIEW_ONLY") if is_preview_room() else ""
	_room_back.text = tr("ROOM_BACK_BUTTON") % InputRouter.glyph("back")
	_sync_overlay_layers()


func toggle_collision_overlay(force: Variant = null) -> void:
	if not _dev_tools_enabled:
		return
	if _collision_overlay == null:
		_collision_overlay = COLLISION_OVERLAY_SCRIPT.new() as Node2D
		_collision_overlay.name = "CollisionOverlay"
		_collision_overlay.z_index = 30
		_collision_overlay.set("floor", self)
		add_child(_collision_overlay)
		_collision_overlay.visible = false
	_collision_overlay.visible = not _collision_overlay.visible if force == null else bool(force)


func collision_overlay_visible() -> bool:
	return _collision_overlay != null and _collision_overlay.visible


func _build_dev_floor_tools() -> void:
	_dev_layer = CanvasLayer.new()
	_dev_layer.name = "DeveloperFloorTools"
	_dev_layer.layer = 40
	add_child(_dev_layer)
	_dev_panel = Panel.new()
	_dev_panel.name = "DeveloperLocations"
	_dev_panel.position = Vector2(270, 84)
	_dev_panel.size = Vector2(420, 356)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("161215f5")
	panel_style.border_color = Color("8a682f")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	_dev_panel.add_theme_stylebox_override("panel", panel_style)
	_dev_layer.add_child(_dev_panel)
	var title := Label.new()
	title.text = tr("DEV_LOCATIONS_TITLE")
	title.position = Vector2(16, 10)
	title.size = Vector2(388, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Typography.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", Typography.CONTROL)
	title.add_theme_color_override("font_color", IVORY)
	_dev_panel.add_child(title)
	for index: int in range(DEV_TARGETS.size()):
		var target: Dictionary = DEV_TARGETS[index]
		var button := _dev_button(
			String(target.label),
			Vector2(16 + (index % 2) * 198, 44 + (index / 2) * 52),
			DEV_BUTTON_SIZE
		)
		button.name = "DevTarget_%s" % String(target.id)
		button.pressed.connect(_dev_warp_to.bind(target.id))
		_dev_buttons.append(button)
	var overlay := _dev_button("COLLISION  ·  F2", Vector2(16, 252), DEV_BUTTON_SIZE)
	overlay.name = "DevCollisionOverlay"
	overlay.pressed.connect(func() -> void: toggle_collision_overlay())
	_dev_buttons.append(overlay)
	var close := _dev_button("CLOSE", Vector2(214, 252), DEV_BUTTON_SIZE)
	close.name = "DevLocationsClose"
	close.pressed.connect(_toggle_dev_floor_tools.bind(false))
	_dev_buttons.append(close)
	var note := Label.new()
	note.text = tr("DEV_LOCATIONS_NOTE")
	note.position = Vector2(16, 306)
	note.size = Vector2(388, 36)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", Typography.UI_FONT)
	note.add_theme_font_size_override("font_size", Typography.CAPTION)
	note.add_theme_color_override("font_color", Color("a99e90"))
	_dev_panel.add_child(note)
	_toggle_dev_floor_tools(false)


func _dev_button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = dimensions
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", Typography.UI_FONT)
	button.add_theme_font_size_override("font_size", Typography.CAPTION)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("5a111c") if state != "pressed" else Color("351016")
		style.border_color = CYAN if state == "focus" else Color("8a682f")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	_dev_panel.add_child(button)
	ButtonFeedback.attach(button)
	return button


func _toggle_dev_floor_tools(force_open: Variant = null) -> void:
	if not _dev_tools_enabled or _dev_panel == null:
		return
	_dev_open = not _dev_open if force_open == null else bool(force_open)
	_dev_panel.visible = _dev_open
	if _dev_open and not _dev_buttons.is_empty():
		_dev_buttons[0].call_deferred("grab_focus")
	elif not _dev_open:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Control and _dev_panel.is_ancestor_of(focused):
			(focused as Control).release_focus()


func _dev_warp_to(target_id: StringName) -> void:
	_toggle_dev_floor_tools(false)
	if target_id in ROOM_IDS:
		enter_room(target_id)
		return
	if not is_main_floor():
		enter_room(MAIN_FLOOR)
	for target: Dictionary in DEV_TARGETS:
		if target.id != target_id:
			continue
		if _cashier_open:
			_close_cashier()
		avatar_position = target.position as Vector2
		if _avatar_visual != null:
			_avatar_visual.position = avatar_position
		_has_moved = true
		refresh_proximity()
		AudioService.play(&"move")
		return


func _update_camera_focus(game_id: StringName) -> void:
	if _floor_camera == null or game_id == _camera_focus_id:
		return
	_camera_focus_id = game_id
	if _camera_tween != null:
		_camera_tween.kill()
	if not MotionPolicy.allows_camera_emphasis():
		_floor_camera.position = CAMERA_CENTER
		_floor_camera.zoom = Vector2.ONE
		return
	var target_position := CAMERA_CENTER
	var target_zoom := Vector2.ONE
	if game_id != &"" and cabinet_positions.has(game_id):
		var toward_machine: Vector2 = cabinet_positions[game_id] - CAMERA_CENTER
		if not toward_machine.is_zero_approx():
			target_position += toward_machine.normalized() * CAMERA_FOCUS_OFFSET
		target_zoom = CAMERA_FOCUS_ZOOM
	_camera_tween = create_tween().set_parallel(true)
	var duration := MotionPolicy.finite_duration(0.24)
	(
		_camera_tween
		. tween_property(_floor_camera, "position", target_position, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_camera_tween
		. tween_property(_floor_camera, "zoom", target_zoom, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _apply_motion_preference(reduced: bool) -> void:
	if _dust != null:
		_dust.emitting = not reduced
		_dust.visible = not reduced
	if reduced:
		_ambient_time = 0.0
		_settle_cashier_motion()
		if _prompt_tween != null:
			_prompt_tween.kill()
			_prompt_tween = null
		if _prompt != null:
			_update_prompt()
			_prompt.modulate = Color.WHITE
			_prompt.scale = Vector2.ONE
		if _camera_tween != null:
			_camera_tween.kill()
		if _floor_camera != null:
			_floor_camera.position = CAMERA_CENTER
			_floor_camera.zoom = Vector2.ONE
	else:
		_camera_focus_id = &""
		var current_game: StringName = nearby_definition.id if nearby_definition != null else &""
		_update_camera_focus(current_game)
	queue_redraw()


func _settle_cashier_motion() -> void:
	if _cashier_tween != null and _cashier_tween.is_valid():
		_cashier_tween.kill()
	_cashier_tween = null
	if _cashier_panel != null:
		var keep_open := _cashier_open and not _cashier_is_closing
		_cashier_panel.visible = keep_open
		_cashier_panel.mouse_filter = (
			Control.MOUSE_FILTER_STOP if keep_open else Control.MOUSE_FILTER_IGNORE
		)
		_cashier_panel.modulate = Color.WHITE
		_cashier_panel.scale = Vector2.ONE
	if _cashier_scrim != null:
		_cashier_scrim.visible = _cashier_open and not _cashier_is_closing
		_cashier_scrim.modulate.a = 1.0
	_cashier_is_closing = false
	if _cashier_transaction_tween != null and _cashier_transaction_tween.is_valid():
		_cashier_transaction_tween.kill()
	_cashier_transaction_tween = null
	if _cashier_transfer_layer != null:
		for child: Node in _cashier_transfer_layer.get_children():
			child.queue_free()
	if _cashier_summary_flash != null:
		_cashier_summary_flash.color.a = 0.0
	if _cashier_preview != null:
		_cashier_preview.add_theme_color_override("font_color", Color("b8ad9c"))


func _draw() -> void:
	draw_texture_rect(_background, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 540), Color("0c0b0d24"))
	# A flat band behind the top HUD keeps its text readable over the back wall.
	draw_rect(Rect2(0, 0, 960, HUD_BAND_HEIGHT), Color("0c0b0d9c"))
	for id: StringName in cabinet_positions:
		var at: Vector2 = cabinet_positions[id]
		var is_near: bool = nearby_definition != null and nearby_definition.id == id
		var cadence := 1.15 if is_near else 3.2
		var phase := _ambient_time * TAU / cadence + float(cabinet_positions.keys().find(id)) * 1.9
		var pulse := (sin(phase) + 1.0) * 0.5 if MotionPolicy.allows_continuous_motion() else 0.0
		_draw_machine_zone(id, at, is_near, pulse)
	_sync_prompt_plaque()


func _draw_machine_zone(id: StringName, at: Vector2, is_near: bool, pulse: float) -> void:
	# The inlay itself is painted into the carpet. Only when the player stands
	# on it does a thin brass line trace its rim, so the floor stays clean.
	if not is_near or _dismissed_game == id:
		return
	var half := Vector2(
		MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.x, MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.y
	)
	var rim := PackedVector2Array(
		[
			at + Vector2(-half.x, 0),
			at + Vector2(0, -half.y),
			at + Vector2(half.x, 0),
			at + Vector2(0, half.y),
			at + Vector2(-half.x, 0),
		]
	)
	draw_polyline(rim, Color(INLAY_HIGHLIGHT, 0.55 + pulse * 0.35), 2.0, true)


func _machine_accent(id: StringName) -> Color:
	match id:
		&"slot_classic":
			return Color("a91f3a")
		&"blackjack":
			return Color("16856f")
		_:
			return Color("3157a8")


func _build_cashier_menu() -> void:
	_cashier_scrim = ColorRect.new()
	_cashier_scrim.name = "CashierScrim"
	_cashier_scrim.position = Vector2.ZERO
	_cashier_scrim.size = Vector2(960, 540)
	_cashier_scrim.color = Color("09070acc")
	_cashier_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_cashier_scrim.z_index = 29
	_cashier_scrim.visible = false
	add_child(_cashier_scrim)
	_cashier_panel = Panel.new()
	_cashier_panel.name = "CashierMenu"
	_cashier_panel.position = Vector2(250, 56)
	_cashier_panel.size = Vector2(460, 410)
	_cashier_panel.z_index = 30
	_cashier_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("120d10fa")
	panel_style.border_color = BRASS
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color("000000aa")
	panel_style.shadow_size = 14
	_cashier_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_cashier_panel)
	var title := _cashier_label(
		tr("CASHIER_NAME"), Vector2(24, 16), Vector2(412, 42), 32, Color("f1e8d8")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.position = Vector2(54, 64)
	rule.size = Vector2(352, 2)
	rule.color = BRASS
	_cashier_panel.add_child(rule)
	_cashier_balance = _cashier_number_label(Vector2(32, 74), Vector2(396, 34), 22, Color("f2c84b"))
	_cashier_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_debt = _cashier_number_label(Vector2(32, 108), Vector2(396, 26), 16, Color("b8ad9c"))
	_cashier_debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amount_caption := _cashier_label(
		tr("CASHIER_REPAY_AMOUNT"), Vector2(32, 142), Vector2(196, 24), 14, Color("b8ad9c")
	)
	amount_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cashier_amount = _cashier_number_label(Vector2(228, 138), Vector2(200, 32), 22, IVORY)
	_cashier_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var adjustment_specs: Array[Dictionary] = [
		{
			"name": "RepayMinusTen",
			"text": "-10",
			"action": func() -> void: _adjust_cashier_repayment(-10)
		},
		{
			"name": "RepayMinusOne",
			"text": "-1",
			"action": func() -> void: _adjust_cashier_repayment(-1)
		},
		{
			"name": "RepayPlusOne",
			"text": "+1",
			"action": func() -> void: _adjust_cashier_repayment(1)
		},
		{
			"name": "RepayPlusTen",
			"text": "+10",
			"action": func() -> void: _adjust_cashier_repayment(10)
		},
		{
			"name": "RepayMaximum",
			"text": tr("CASHIER_PAY_ALL"),
			"action": _maximize_cashier_repayment
		},
	]
	var adjustment_buttons: Array[Button] = []
	for index: int in range(adjustment_specs.size()):
		var spec: Dictionary = adjustment_specs[index]
		var adjust := _cashier_button(
			String(spec.text), Vector2(20 + index * 84, 178), Vector2(76, 46)
		)
		adjust.name = String(spec.name)
		adjust.pressed.connect(spec.action as Callable)
		adjustment_buttons.append(adjust)
	_cashier_preview = ANIMATED_PAIR_LABEL_SCRIPT.new() as Label
	_cashier_preview.position = Vector2(24, 232)
	_cashier_preview.size = Vector2(412, 26)
	_cashier_preview.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_cashier_preview.add_theme_font_size_override("font_size", 15)
	_cashier_preview.add_theme_color_override("font_color", Color("b8ad9c"))
	_cashier_panel.add_child(_cashier_preview)
	_cashier_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_summary_flash = ColorRect.new()
	_cashier_summary_flash.name = "TransactionFlash"
	_cashier_summary_flash.position = Vector2(24, 70)
	_cashier_summary_flash.size = Vector2(412, 68)
	_cashier_summary_flash.color = Color("58d68d00")
	_cashier_summary_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cashier_summary_flash.z_index = 10
	_cashier_panel.add_child(_cashier_summary_flash)
	_cashier_transfer_layer = Control.new()
	_cashier_transfer_layer.name = "ChipTransferLayer"
	_cashier_transfer_layer.size = _cashier_panel.size
	_cashier_transfer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cashier_transfer_layer.z_index = 20
	_cashier_panel.add_child(_cashier_transfer_layer)
	_cashier_marker = _cashier_button(tr("CASHIER_TAKE_MARKER"), Vector2(20, 272), Vector2(200, 56))
	_cashier_marker.name = "TakeMarker"
	_cashier_marker.pressed.connect(_take_cashier_marker)
	_cashier_repay = _cashier_button("", Vector2(240, 272), Vector2(200, 56))
	_cashier_repay.name = "RepayDebt"
	_cashier_repay.pressed.connect(_confirm_cashier_repayment)
	_cashier_close = _cashier_button(tr("CASHIER_CLOSE"), Vector2(130, 348), Vector2(200, 44))
	_cashier_close.name = "CloseCashier"
	_cashier_close.pressed.connect(_close_cashier)
	for index: int in range(adjustment_buttons.size()):
		var button := adjustment_buttons[index]
		button.focus_neighbor_left = adjustment_buttons[maxi(index - 1, 0)].get_path()
		button.focus_neighbor_right = (
			adjustment_buttons[mini(index + 1, adjustment_buttons.size() - 1)].get_path()
		)
		button.focus_neighbor_bottom = _cashier_repay.get_path()
	_cashier_marker.focus_neighbor_top = adjustment_buttons[0].get_path()
	_cashier_marker.focus_neighbor_right = _cashier_repay.get_path()
	_cashier_marker.focus_neighbor_bottom = _cashier_close.get_path()
	_cashier_repay.focus_neighbor_top = adjustment_buttons[adjustment_buttons.size() - 1].get_path()
	_cashier_repay.focus_neighbor_left = _cashier_marker.get_path()
	_cashier_repay.focus_neighbor_bottom = _cashier_close.get_path()
	_cashier_close.focus_neighbor_top = _cashier_repay.get_path()


func _cashier_label(
	text_value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_cashier_panel.add_child(label)
	return label


func _cashier_number_label(
	at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> AnimatedNumberLabel:
	var label := AnimatedNumberLabel.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_cashier_panel.add_child(label)
	return label


func _cashier_button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = dimensions
	button.add_theme_font_override("font", Typography.UI_FONT)
	button.add_theme_font_size_override("font_size", Typography.CONTROL)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("5a111c") if state != "pressed" else Color("351016")
		style.border_color = CYAN if state == "focus" else BRASS
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color("24191c")
	disabled_style.border_color = Color("5e554c")
	disabled_style.set_border_width_all(2)
	disabled_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_disabled_color", Color("756d64"))
	_cashier_panel.add_child(button)
	ButtonFeedback.attach(button)
	return button


func _refresh_cashier_menu() -> void:
	if _cashier_panel == null:
		return
	if not _cashier_open:
		_animate_cashier_close()
		return
	var opening := not _cashier_panel.visible or _cashier_is_closing
	if _cashier_is_closing:
		_cashier_is_closing = false
		if _cashier_tween != null and _cashier_tween.is_valid():
			_cashier_tween.kill()
		_cashier_panel.modulate = Color.WHITE
		_cashier_panel.scale = Vector2.ONE
	_cashier_panel.visible = true
	_cashier_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_cashier_scrim.visible = true
	_cashier_scrim.modulate.a = 1.0
	if opening:
		_cashier_panel.pivot_offset = _cashier_panel.size * 0.5
		_cashier_panel.modulate.a = 0.0
		_cashier_panel.scale = Vector2.ONE if MotionPolicy.is_reduced() else Vector2(0.96, 0.96)
		if _cashier_tween != null:
			_cashier_tween.kill()
		_cashier_tween = create_tween().set_parallel(true)
		var duration := MotionPolicy.finite_duration(0.18)
		_cashier_tween.tween_property(_cashier_panel, "modulate:a", 1.0, duration)
		if not MotionPolicy.is_reduced():
			(
				_cashier_tween
				. tween_property(_cashier_panel, "scale", Vector2.ONE, duration)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)
	var repayment_limit := _cashier_repayment_limit()
	_cashier_repay_amount = (
		clampi(_cashier_repay_amount, 1, repayment_limit) if repayment_limit > 0 else 0
	)
	if Wallet.test_mode_enabled:
		_cashier_balance.set_infinity()
		_cashier_balance.text = tr("CASHIER_TEST_BANK")
	else:
		_cashier_balance.set_number(Wallet.balance, tr("CASHIER_CHIPS"))
	_cashier_debt.set_number(Economy.debt, tr("CASHIER_DEBT"))
	_cashier_amount.set_number(_cashier_repay_amount, tr("CASHIER_REPAY_VALUE"))
	var remaining_debt := maxi(Economy.debt - _cashier_repay_amount, 0)
	if Wallet.test_mode_enabled:
		_cashier_preview.call("set_literal", tr("CASHIER_PREVIEW_TEST") % remaining_debt)
	else:
		_cashier_preview.call(
			"set_numbers",
			maxi(Wallet.balance - _cashier_repay_amount, 0),
			remaining_debt,
			tr("CASHIER_PREVIEW")
		)
	_cashier_marker.disabled = not Economy.can_take_marker()
	_cashier_marker.text = (
		tr("CASHIER_ADD_TEST_MARKER") if Wallet.test_mode_enabled else tr("CASHIER_TAKE_MARKER")
	)
	_cashier_repay.disabled = repayment_limit <= 0
	_cashier_repay.text = tr("CASHIER_CONFIRM_REPAY") % _cashier_repay_amount
	for button_name: String in ["RepayMinusTen", "RepayMinusOne"]:
		(_cashier_panel.get_node(button_name) as Button).disabled = (
			repayment_limit <= 0 or _cashier_repay_amount <= 1
		)
	for button_name: String in ["RepayPlusOne", "RepayPlusTen", "RepayMaximum"]:
		(_cashier_panel.get_node(button_name) as Button).disabled = (
			repayment_limit <= 0 or _cashier_repay_amount >= repayment_limit
		)
	if opening:
		_cashier_initial_focus().call_deferred("grab_focus")


func _cashier_repayment_limit() -> int:
	return Economy.repayment_limit()


func _adjust_cashier_repayment(delta: int) -> void:
	var repayment_limit := _cashier_repayment_limit()
	if repayment_limit <= 0:
		return
	_cashier_repay_amount = clampi(_cashier_repay_amount + delta, 1, repayment_limit)
	AudioService.play(&"move")
	_refresh_cashier_menu()


func _maximize_cashier_repayment() -> void:
	_cashier_repay_amount = _cashier_repayment_limit()
	AudioService.play(&"move")
	_refresh_cashier_menu()


func _confirm_cashier_repayment() -> void:
	var repaid := _cashier_repay_amount
	if repaid <= 0 or not Economy.repay_debt(repaid):
		return
	AudioService.play(&"confirm")
	_cashier_repay_amount = mini(10, _cashier_repayment_limit())
	_refresh_cashier_menu()
	_play_cashier_transaction(repaid, false)
	_cashier_initial_focus().call_deferred("grab_focus")


func _cashier_initial_focus() -> Button:
	if not _cashier_marker.disabled:
		return _cashier_marker
	if not _cashier_repay.disabled:
		return _cashier_repay
	return _cashier_close


func _close_cashier() -> void:
	_cashier_open = false
	cashier_visibility_changed.emit(false)
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Control and _cashier_panel.is_ancestor_of(focused):
		(focused as Control).release_focus()
	_refresh_cashier_menu()
	refresh_proximity()


func _take_cashier_marker() -> void:
	if not Economy.take_marker():
		return
	AudioService.play(&"confirm")
	_refresh_cashier_menu()
	_play_cashier_transaction(Economy.MARKER_STIPEND, true)
	_cashier_initial_focus().call_deferred("grab_focus")


func _animate_cashier_close() -> void:
	if not _cashier_panel.visible:
		return
	if _cashier_tween != null and _cashier_tween.is_valid():
		_cashier_tween.kill()
	_cashier_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if MotionPolicy.is_reduced():
		_cashier_panel.visible = false
		_cashier_scrim.visible = false
		_cashier_panel.modulate = Color.WHITE
		_cashier_panel.scale = Vector2.ONE
		_cashier_is_closing = false
		return
	_cashier_is_closing = true
	_cashier_tween = create_tween().set_parallel(true)
	(
		_cashier_tween
		. tween_property(_cashier_panel, "modulate:a", 0.0, 0.14)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_cashier_tween
		. tween_property(_cashier_panel, "scale", Vector2(0.97, 0.97), 0.14)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_cashier_tween.tween_property(_cashier_scrim, "modulate:a", 0.0, 0.14)
	_cashier_tween.chain().tween_callback(
		func() -> void:
			_cashier_panel.visible = false
			_cashier_scrim.visible = false
			_cashier_scrim.modulate.a = 1.0
			_cashier_panel.modulate = Color.WHITE
			_cashier_panel.scale = Vector2.ONE
			_cashier_is_closing = false
			_update_prompt()
	)


func _cashier_direction(event: InputEvent) -> int:
	if event.is_action_pressed("move_left"):
		return Side.SIDE_LEFT
	if event.is_action_pressed("move_right"):
		return Side.SIDE_RIGHT
	if event.is_action_pressed("move_up"):
		return Side.SIDE_TOP
	if event.is_action_pressed("move_down"):
		return Side.SIDE_BOTTOM
	return CASHIER_NO_DIRECTION


func _move_cashier_focus(direction: int) -> void:
	if direction == CASHIER_NO_DIRECTION:
		return
	var focused := get_viewport().gui_get_focus_owner() as Control
	if focused == null or not _cashier_panel.is_ancestor_of(focused):
		_cashier_initial_focus().grab_focus()
		return
	var next := focused.find_valid_focus_neighbor(direction)
	if next != null and _cashier_panel.is_ancestor_of(next):
		next.grab_focus()
		AudioService.play(&"move")


func _play_cashier_transaction(amount: int, borrowing: bool) -> void:
	if _cashier_transaction_tween != null and _cashier_transaction_tween.is_valid():
		_cashier_transaction_tween.kill()
	for child: Node in _cashier_transfer_layer.get_children():
		child.queue_free()
	_cashier_summary_flash.color = Color("58d68d2e")
	_cashier_preview.add_theme_color_override("font_color", Color("8ce9b2"))
	_cashier_transaction_tween = create_tween().set_parallel(true)
	(
		_cashier_transaction_tween
		. tween_property(_cashier_summary_flash, "color:a", 0.0, MotionPolicy.finite_duration(0.38))
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_cashier_transaction_tween.tween_method(
		func(weight: float) -> void:
			_cashier_preview.add_theme_color_override(
				"font_color", Color("8ce9b2").lerp(Color("b8ad9c"), weight)
			),
		0.0,
		1.0,
		MotionPolicy.finite_duration(0.38)
	)
	if MotionPolicy.is_reduced():
		return
	var origin := Vector2(120, 282) if borrowing else Vector2(218, 92)
	var destination := Vector2(218, 92) if borrowing else Vector2(338, 282)
	var chip_count := clampi(ceili(float(amount) / 25.0), 2, 5)
	for index: int in range(chip_count):
		var chip := CreditChipIcon.new()
		chip.name = "TransferChip%d" % index
		chip.position = origin + Vector2(index * 5.0, -index * 3.0)
		chip.scale = Vector2(0.72, 0.72)
		chip.modulate.a = 0.0
		_cashier_transfer_layer.add_child(chip)
		var delay := index * 0.035
		_cashier_transaction_tween.tween_property(chip, "modulate:a", 1.0, 0.08).set_delay(delay)
		(
			_cashier_transaction_tween
			. tween_property(
				chip, "position", destination + Vector2(index * 4.0, -index * 2.0), 0.30
			)
			. set_delay(delay)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_cashier_transaction_tween
			. tween_property(chip, "scale", Vector2(0.48, 0.48), 0.30)
			. set_delay(delay)
		)
		_cashier_transaction_tween.tween_property(chip, "modulate:a", 0.0, 0.11).set_delay(
			delay + 0.24
		)
		_cashier_transaction_tween.tween_callback(chip.queue_free).set_delay(delay + 0.36)
