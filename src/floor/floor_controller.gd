class_name FloorController
extends Node2D

signal cashier_visibility_changed(is_open: bool)

const SPEED: float = 88.0
const INTERACTION_RADIUS: float = 76.0
const CASHIER_POSITION := Vector2(660, 410)
const WING_POSITIONS: Dictionary = {&"high_roller": Vector2(250, 265), &"vip": Vector2(790, 242)}
const WING_THRESHOLDS: Dictionary = {&"high_roller": 5000, &"vip": 100_000}
const FLOOR_ART := preload("res://assets/production/environments/casino_floor.png")
const FLOOR_AVATAR_SCRIPT := preload("res://src/floor/floor_avatar.gd")
const CASINO_PATRON_SCRIPT := preload("res://src/floor/casino_patron.gd")
const CASHIER_WAYPOINT_SCRIPT := preload("res://src/floor/cashier_waypoint.gd")
const MACHINE_ATTRACT_SCRIPT := preload("res://src/floor/machine_attract.gd")
const PRACTICAL_LIGHT_RIG_SCRIPT := preload("res://src/floor/practical_light_rig.gd")
const ANIMATED_PAIR_LABEL_SCRIPT := preload("res://src/ui/animated_pair_label.gd")
const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const CYAN := Color("48c5d5")
const AVATAR_RADIUS: float = 15.0
const MACHINE_ZONE_RADIUS: float = 50.0
const MACHINE_ZONE_SCALE := Vector2(1.48, 0.96)
const JOIN_DIALOG_SIZE := Vector2(286, 70)
const JOIN_DIALOG_OFFSET := Vector2(-143, 42)
const CAMERA_CENTER := Vector2(480, 270)
const CAMERA_FOCUS_ZOOM := Vector2(1.03, 1.03)
const CAMERA_FOCUS_OFFSET: float = 9.0
const CASHIER_NO_DIRECTION: int = -1
const PATRON_LAYOUT: Array[Dictionary] = [
	{"position": Vector2(290, 150), "profile": 0, "phase": 0.0},
	{"position": Vector2(850, 390), "profile": 1, "phase": 0.55},
	{"position": Vector2(700, 150), "profile": 2, "phase": 1.10},
	{"position": Vector2(830, 150), "profile": 3, "phase": 1.65},
	{"position": Vector2(560, 150), "profile": 4, "phase": 2.20},
	{"position": Vector2(390, 150), "profile": 5, "phase": 2.75},
	{"position": Vector2(105, 345), "profile": 6, "phase": 0.30},
	{"position": Vector2(105, 425), "profile": 7, "phase": 0.85},
	{"position": Vector2(505, 145), "profile": 8, "phase": 1.40},
	{"position": Vector2(630, 175), "profile": 9, "phase": 1.95},
]
const DEV_TARGETS: Array[Dictionary] = [
	{"id": &"spawn", "label": "SPAWN", "position": Vector2(480, 408)},
	{"id": &"slot_classic", "label": "SLOTS", "position": Vector2(334, 242)},
	{"id": &"blackjack", "label": "BLACKJACK", "position": Vector2(504, 240)},
	{"id": &"minefield_vault", "label": "VAULT", "position": Vector2(680, 242)},
	{"id": &"cashier", "label": "CASHIER", "position": CASHIER_POSITION},
	{"id": &"high_roller", "label": "HIGH ROLLER GATE", "position": Vector2(250, 265)},
	{"id": &"vip", "label": "VIP GATE", "position": Vector2(790, 242)},
]
static var NAV_OBSTACLES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 0), Vector2(208, 0), Vector2(236, 72), Vector2(258, 194), Vector2(226, 244), Vector2(0, 250)]),
	PackedVector2Array([Vector2(265, 48), Vector2(406, 46), Vector2(427, 112), Vector2(420, 187), Vector2(390, 219), Vector2(278, 219), Vector2(250, 184), Vector2(250, 94)]),
	PackedVector2Array([Vector2(438, 48), Vector2(572, 48), Vector2(591, 99), Vector2(586, 188), Vector2(558, 215), Vector2(450, 215), Vector2(425, 184), Vector2(425, 93)]),
	PackedVector2Array([Vector2(605, 51), Vector2(742, 50), Vector2(770, 102), Vector2(766, 188), Vector2(738, 216), Vector2(628, 216), Vector2(588, 185), Vector2(590, 94)]),
	PackedVector2Array([Vector2(782, 0), Vector2(960, 0), Vector2(960, 236), Vector2(914, 240), Vector2(845, 221), Vector2(780, 188)]),
	PackedVector2Array([Vector2(733, 270), Vector2(960, 248), Vector2(960, 500), Vector2(718, 500), Vector2(690, 451), Vector2(695, 350)]),
	PackedVector2Array([Vector2(0, 300), Vector2(176, 299), Vector2(228, 344), Vector2(231, 474), Vector2(196, 526), Vector2(0, 540)]),
	PackedVector2Array([Vector2(278, 465), Vector2(326, 438), Vector2(600, 438), Vector2(681, 478), Vector2(681, 540), Vector2(270, 540)]),
]
var avatar_position := Vector2(480, 408)
var nearby_definition: CabinetDefinition
var nearby_wing: StringName = &""
var cabinet_positions: Dictionary = {
	&"slot_classic": Vector2(334, 242),
	&"blackjack": Vector2(504, 240),
	&"minefield_vault": Vector2(680, 242),
}
var definitions: Dictionary = {}
var _prompt: Label
var _cashier_open: bool = false
var _avatar_visual: Node2D
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
var _machine_attracts: Dictionary = {}
var _patrons: Array[Node2D] = []
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


func _ready() -> void:
	for id: StringName in cabinet_positions:
		var definition: CabinetDefinition = load("res://data/cabinets/%s.tres" % id)
		assert(
			definition != null and definition.is_valid_definition(),
			"Invalid cabinet resource: %s" % id
		)
		assert(definition.id == id, "Cabinet resource ID must match its registry key: %s" % id)
		assert(not definitions.has(definition.id), "Duplicate cabinet ID: %s" % definition.id)
		definitions[id] = definition
	_build_camera()
	_build_dust()
	_build_practical_lights()
	_build_patrons()
	_build_machine_attracts()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	_avatar_visual = FLOOR_AVATAR_SCRIPT.new()
	_avatar_visual.name = "FloorAvatar"
	_avatar_visual.position = avatar_position
	add_child(_avatar_visual)
	_prompt = Label.new()
	_prompt.size = Vector2(260, 72)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_prompt.add_theme_color_override("font_color", IVORY)
	add_child(_prompt)
	_build_cashier_waypoint()
	_build_cashier_menu()
	_dev_tools_enabled = bool(
		ProjectSettings.get_setting("house_rules/testing/dev_floor_tools", false)
	)
	if _dev_tools_enabled:
		_build_dev_floor_tools()
	SceneRouter.register_floor(self)
	Wallet.balance_changed.connect(func(_old: int, _new: int) -> void: refresh_proximity())
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh_proximity())
	refresh_proximity()


func move_avatar(direction: Vector2, delta: float) -> void:
	var origin := avatar_position
	if not direction.is_zero_approx():
		var motion := direction.normalized() * SPEED * delta
		var steps: int = maxi(1, ceili(motion.length() / 4.0))
		var step := motion / steps
		for _index: int in range(steps):
			var horizontal := avatar_position + Vector2(step.x, 0.0)
			if _is_walkable(horizontal):
				avatar_position = horizontal
			var vertical := avatar_position + Vector2(0.0, step.y)
			if _is_walkable(vertical):
				avatar_position = vertical
	if _avatar_visual != null:
		_avatar_visual.position = avatar_position
		_avatar_visual.call("set_motion", avatar_position - origin)
	if not avatar_position.is_equal_approx(origin):
		_has_moved = true
	refresh_proximity()
	queue_redraw()


func _is_walkable(point: Vector2) -> bool:
	if not Rect2(
		AVATAR_RADIUS,
		AVATAR_RADIUS,
		960.0 - AVATAR_RADIUS * 2.0,
		540.0 - AVATAR_RADIUS * 2.0
	).has_point(point):
		return false
	for polygon: PackedVector2Array in NAV_OBSTACLES:
		if _circle_hits_polygon(point, AVATAR_RADIUS, polygon):
			return false
	return true


func _circle_hits_polygon(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	var radius_squared := radius * radius
	for index: int in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(
			center, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		if center.distance_squared_to(closest) <= radius_squared:
			return true
	return false


func refresh_proximity() -> void:
	nearby_definition = null
	nearby_wing = &""
	var nearest_score: float = INF
	for id: StringName in cabinet_positions:
		var score := _machine_proximity_score(avatar_position, cabinet_positions[id])
		if score <= 1.0 and score <= nearest_score:
			nearest_score = score
			nearby_definition = definitions.get(id)
	if nearby_definition == null:
		var nearest_wing_distance: float = INTERACTION_RADIUS
		for id: StringName in WING_POSITIONS:
			var distance: float = avatar_position.distance_to(WING_POSITIONS[id])
			if distance <= nearest_wing_distance:
				nearest_wing_distance = distance
				nearby_wing = id
	var current_game: StringName = nearby_definition.id if nearby_definition != null else &""
	_update_machine_attracts(current_game)
	_update_camera_focus(current_game)
	if current_game != _last_nearby_game:
		_dismissed_game = &""
	_last_nearby_game = current_game
	if _prompt != null:
		_update_prompt()
	_update_cashier_waypoint()
	queue_redraw()


func interact() -> bool:
	if nearby_definition != null:
		if _dismissed_game == nearby_definition.id:
			return false
		if Wallet.balance < nearby_definition.min_bet:
			return false
		SceneRouter.enter_cabinet(nearby_definition)
		AudioService.play(&"confirm")
		return true
	if nearby_wing != &"":
		_update_prompt()
		return false
	if avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS:
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
	if _dev_open:
		if event.is_action_pressed("back"):
			_toggle_dev_floor_tools(false)
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
		if _cashier_open:
			_close_cashier()
		elif nearby_definition != null and _dismissed_game != nearby_definition.id:
			_dismissed_game = nearby_definition.id
			_update_prompt()
		else:
			SceneRouter.return_to_menu()
	elif event.is_action_pressed("interact"):
		if _cashier_open:
			Economy.take_marker()
			_update_prompt()
		else:
			interact()


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
			% [
				InputRouter.glyph("move"),
				InputRouter.glyph("interact"),
				InputRouter.glyph("back")
			]
		)
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
		_prompt.position = WING_POSITIONS[nearby_wing] + Vector2(-115, 64)
		_prompt.size = Vector2(230, 72)
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
		MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.x,
		MACHINE_ZONE_RADIUS * MACHINE_ZONE_SCALE.y
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
	_prompt.position = final_position if MotionPolicy.is_reduced() else final_position + Vector2(0, 8)
	_prompt.scale = Vector2.ONE
	_prompt_tween = create_tween().set_parallel(true)
	var duration := MotionPolicy.finite_duration(0.15)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD)
	if not MotionPolicy.is_reduced():
		_prompt_tween.tween_property(_prompt, "position", final_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.12).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_prompt_tween.tween_property(_prompt, "position", exit_position, 0.12).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
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
	visibility_changed.connect(func() -> void: _directions_layer.visible = visible)


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
			and Economy.is_below_solvency_floor()
			and not near_cashier
			and not _cashier_open
		)
	)


func _build_patrons() -> void:
	for index: int in range(PATRON_LAYOUT.size()):
		var layout: Dictionary = PATRON_LAYOUT[index]
		var patron := CASINO_PATRON_SCRIPT.new() as Node2D
		patron.name = "CasinoPatron%d" % (index + 1)
		patron.position = layout["position"] as Vector2
		patron.z_index = 2
		patron.call("configure", int(layout["profile"]), float(layout["phase"]))
		add_child(patron)
		_patrons.append(patron)


func _build_dev_floor_tools() -> void:
	_dev_layer = CanvasLayer.new()
	_dev_layer.name = "DeveloperFloorTools"
	_dev_layer.layer = 40
	add_child(_dev_layer)
	_dev_panel = Panel.new()
	_dev_panel.name = "DeveloperLocations"
	_dev_panel.position = Vector2(316, 104)
	_dev_panel.size = Vector2(328, 228)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("161215f5")
	panel_style.border_color = Color("8a682f")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color("07050680")
	panel_style.shadow_size = 8
	_dev_panel.add_theme_stylebox_override("panel", panel_style)
	_dev_layer.add_child(_dev_panel)
	var title := Label.new()
	title.text = "DEV LOCATIONS  ·  F1 CLOSE"
	title.position = Vector2(16, 12)
	title.size = Vector2(296, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Typography.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", Typography.CONTROL)
	title.add_theme_color_override("font_color", IVORY)
	_dev_panel.add_child(title)
	for index: int in range(DEV_TARGETS.size()):
		var target: Dictionary = DEV_TARGETS[index]
		var button := _dev_button(
			String(target.label),
			Vector2(16 + (index % 2) * 150, 46 + (index / 2) * 40),
			Vector2(142, 34)
		)
		button.name = "DevTarget_%s" % String(target.id)
		button.pressed.connect(_dev_warp_to.bind(target.id))
		_dev_buttons.append(button)
	var close := _dev_button("CLOSE", Vector2(166, 166), Vector2(142, 34))
	close.name = "DevLocationsClose"
	close.pressed.connect(_toggle_dev_floor_tools.bind(false))
	_dev_buttons.append(close)
	var note := Label.new()
	note.text = "HIGH ROLLER + VIP ARE LOCKED GATE PREVIEWS"
	note.position = Vector2(16, 204)
	note.size = Vector2(296, 16)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", Typography.UI_FONT)
	note.add_theme_font_size_override("font_size", Typography.MICRO)
	note.add_theme_color_override("font_color", Color("a99e90"))
	_dev_panel.add_child(note)
	_toggle_dev_floor_tools(DisplayServer.get_name() != "headless")


func _dev_button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = dimensions
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
	for target: Dictionary in DEV_TARGETS:
		if target.id != target_id:
			continue
		if _cashier_open:
			_close_cashier()
		avatar_position = target.position as Vector2
		if _avatar_visual != null:
			_avatar_visual.position = avatar_position
		_has_moved = true
		_toggle_dev_floor_tools(false)
		refresh_proximity()
		AudioService.play(&"move")
		return


func _build_machine_attracts() -> void:
	var machine_ids: Array = cabinet_positions.keys()
	for index: int in range(machine_ids.size()):
		var id: StringName = machine_ids[index]
		var attract := MACHINE_ATTRACT_SCRIPT.new() as MachineAttract
		attract.name = "MachineAttract_%s" % id
		# The small live identity now sits on the cabinet surface rather than
		# floating in the player's walking space.
		attract.position = cabinet_positions[id] + Vector2(0, -44)
		attract.z_index = 0
		attract.configure(_machine_attract_kind(id), float(index) / float(machine_ids.size()))
		add_child(attract)
		_machine_attracts[id] = attract


func _machine_attract_kind(id: StringName) -> MachineAttract.Kind:
	match id:
		&"slot_classic":
			return MachineAttract.Kind.SLOT
		&"blackjack":
			return MachineAttract.Kind.BLACKJACK
		_:
			return MachineAttract.Kind.VAULT


func _update_machine_attracts(nearby_id: StringName) -> void:
	for id: StringName in _machine_attracts:
		var attract: MachineAttract = _machine_attracts[id]
		attract.set_near(id == nearby_id)


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
	_camera_tween.tween_property(
		_floor_camera, "position", target_position, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(
		_floor_camera, "zoom", target_zoom, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	for attract: MachineAttract in _machine_attracts.values():
		attract.apply_motion_preference(reduced)
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
	draw_texture_rect(FLOOR_ART, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 540), Color("0c0b0d24"))
	_draw_floor_lighting()
	draw_rect(Rect2(0, 0, 960, 88), Color("0c0b0d9c"))
	draw_rect(Rect2(32, 92, 896, 352), Color("0c0b0d18"), false, 2.0)
	for id: StringName in cabinet_positions:
		var at: Vector2 = cabinet_positions[id]
		var is_near: bool = nearby_definition != null and nearby_definition.id == id
		var cadence := 1.15 if is_near else 3.2
		var phase := _ambient_time * TAU / cadence + float(cabinet_positions.keys().find(id)) * 1.9
		var pulse := (sin(phase) + 1.0) * 0.5 if MotionPolicy.allows_continuous_motion() else 0.0
		_draw_machine_zone(id, at, is_near, pulse)
	draw_string(
		ThemeDB.fallback_font,
		CASHIER_POSITION + Vector2(-46, -45),
		tr("CASHIER_NAME"),
		HORIZONTAL_ALIGNMENT_CENTER,
		92,
		Typography.CRITICAL,
		IVORY
	)
	for wing: StringName in WING_POSITIONS:
		var wing_at: Vector2 = WING_POSITIONS[wing]
		var plaque := Rect2(wing_at - Vector2(34, 14), Vector2(68, 28))
		draw_rect(plaque, Color("17161acc"))
		draw_rect(plaque, Color("6e5225"), false, 2.0)
		draw_arc(wing_at + Vector2(0, -3), 5.0, PI, TAU, 16, BRASS, 2.0)
		draw_rect(Rect2(wing_at + Vector2(-6, -3), Vector2(12, 10)), Color("6e5225"))
	if _prompt != null and _prompt.visible:
		var prompt_rect := Rect2(_prompt.position - Vector2(12, 8), _prompt.size + Vector2(24, 16))
		var join_dialog := nearby_definition != null and _dismissed_game != nearby_definition.id
		var prompt_alpha := _prompt.modulate.a
		if join_dialog:
			draw_rect(
				Rect2(prompt_rect.position + Vector2(6, 7), prompt_rect.size),
				Color("05040570") * Color(1, 1, 1, prompt_alpha)
			)
		var surface := Color("17161ab8") if join_dialog else Color("17161ae8")
		var border := (
			_machine_accent(nearby_definition.id)
			if join_dialog and nearby_definition != null
			else Color("6e5225")
		)
		draw_rect(prompt_rect, surface * Color(1, 1, 1, prompt_alpha))
		draw_rect(prompt_rect, border * Color(1, 1, 1, prompt_alpha), false, 2.0)


func _draw_machine_zone(id: StringName, at: Vector2, is_near: bool, pulse: float) -> void:
	var accent := _machine_accent(id)
	var ring_color := Color(accent, 0.20 + pulse * 0.06)
	var ring_width := 1.5
	if is_near and _dismissed_game != id:
		ring_color = Color(CYAN, 0.76 + pulse * 0.18)
		ring_width = 3.0
	draw_set_transform(at, 0.0, MACHINE_ZONE_SCALE)
	if is_near and _dismissed_game != id:
		draw_circle(Vector2.ZERO, MACHINE_ZONE_RADIUS - 2.0, Color(accent, 0.075))
	draw_arc(Vector2.ZERO, MACHINE_ZONE_RADIUS, 0.0, TAU, 64, ring_color, ring_width, true)
	if is_near and _dismissed_game != id:
		draw_arc(
			Vector2.ZERO,
			MACHINE_ZONE_RADIUS + 5.0 + pulse * 2.0,
			0.0,
			TAU,
			64,
			Color(CYAN, 0.24),
			1.5,
			true
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_floor_lighting() -> void:
	var drift := sin(_ambient_time * 0.18) * 24.0 if MotionPolicy.allows_continuous_motion() else 0.0
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(278 + drift, 88), Vector2(354 + drift, 88),
			Vector2(438 + drift, 444), Vector2(314 + drift, 444),
		]),
		Color("d9b44a12")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(610 - drift, 88), Vector2(680 - drift, 88),
			Vector2(648 - drift, 444), Vector2(526 - drift, 444),
		]),
		Color("8fb8c712")
	)
	draw_rect(Rect2(0, 88, 960, 10), Color("09070a42"))
	draw_rect(Rect2(0, 436, 960, 16), Color("09070a4d"))


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
	_cashier_balance = _cashier_number_label(
		Vector2(32, 74), Vector2(396, 34), 22, Color("f2c84b")
	)
	_cashier_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_debt = _cashier_number_label(
		Vector2(32, 108), Vector2(396, 26), 16, Color("b8ad9c")
	)
	_cashier_debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amount_caption := _cashier_label(
		tr("CASHIER_REPAY_AMOUNT"), Vector2(32, 142), Vector2(196, 24), 14, Color("b8ad9c")
	)
	amount_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cashier_amount = _cashier_number_label(
		Vector2(228, 138), Vector2(200, 32), 22, IVORY
	)
	_cashier_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var adjustment_specs: Array[Dictionary] = [
		{
			"name": "RepayMinusTen",
			"text": "-10",
			"action": func() -> void: _adjust_cashier_repayment(-10)
		},
		{"name": "RepayMinusOne", "text": "-1", "action": func() -> void: _adjust_cashier_repayment(-1)},
		{"name": "RepayPlusOne", "text": "+1", "action": func() -> void: _adjust_cashier_repayment(1)},
		{"name": "RepayPlusTen", "text": "+10", "action": func() -> void: _adjust_cashier_repayment(10)},
		{"name": "RepayMaximum", "text": tr("CASHIER_PAY_ALL"), "action": _maximize_cashier_repayment},
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
	_cashier_marker = _cashier_button(
		tr("CASHIER_TAKE_MARKER"), Vector2(20, 272), Vector2(200, 56)
	)
	_cashier_marker.name = "TakeMarker"
	_cashier_marker.pressed.connect(_take_cashier_marker)
	_cashier_repay = _cashier_button("", Vector2(240, 272), Vector2(200, 56))
	_cashier_repay.name = "RepayDebt"
	_cashier_repay.pressed.connect(_confirm_cashier_repayment)
	_cashier_close = _cashier_button(
		tr("CASHIER_CLOSE"), Vector2(130, 348), Vector2(200, 44)
	)
	_cashier_close.name = "CloseCashier"
	_cashier_close.pressed.connect(_close_cashier)
	for index: int in range(adjustment_buttons.size()):
		var button := adjustment_buttons[index]
		button.focus_neighbor_left = adjustment_buttons[maxi(index - 1, 0)].get_path()
		button.focus_neighbor_right = adjustment_buttons[
			mini(index + 1, adjustment_buttons.size() - 1)
		].get_path()
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
			_cashier_tween.tween_property(
				_cashier_panel, "scale", Vector2.ONE, duration
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		tr("CASHIER_ADD_TEST_MARKER")
		if Wallet.test_mode_enabled
		else tr("CASHIER_TAKE_MARKER")
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
	_cashier_tween.tween_property(_cashier_panel, "modulate:a", 0.0, 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_cashier_tween.tween_property(_cashier_panel, "scale", Vector2(0.97, 0.97), 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
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
	_cashier_transaction_tween.tween_property(
		_cashier_summary_flash, "color:a", 0.0, MotionPolicy.finite_duration(0.38)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		_cashier_transaction_tween.tween_property(
			chip, "modulate:a", 1.0, 0.08
		).set_delay(delay)
		_cashier_transaction_tween.tween_property(
			chip, "position", destination + Vector2(index * 4.0, -index * 2.0), 0.30
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_cashier_transaction_tween.tween_property(
			chip, "scale", Vector2(0.48, 0.48), 0.30
		).set_delay(delay)
		_cashier_transaction_tween.tween_property(
			chip, "modulate:a", 0.0, 0.11
		).set_delay(delay + 0.24)
		_cashier_transaction_tween.tween_callback(chip.queue_free).set_delay(delay + 0.36)
