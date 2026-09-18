class_name FloorController
extends Node2D

const SPEED: float = 88.0
const INTERACTION_RADIUS: float = 76.0
const CASHIER_POSITION := Vector2(660, 410)
const WING_POSITIONS: Dictionary = {&"high_roller": Vector2(250, 265), &"vip": Vector2(790, 242)}
const WING_THRESHOLDS: Dictionary = {&"high_roller": 5000, &"vip": 100_000}
const FLOOR_ART := preload("res://assets/production/environments/casino_floor.png")
const FLOOR_AVATAR_SCRIPT := preload("res://src/floor/floor_avatar.gd")
const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const CYAN := Color("48c5d5")
const AVATAR_RADIUS: float = 15.0
const MACHINE_ZONE_RADIUS: float = 38.0
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
var _cashier_balance: Label
var _cashier_debt: Label
var _ambient_time: float = 0.0
var _dismissed_game: StringName = &""
var _last_nearby_game: StringName = &""
var _prompt_signature: String = ""
var _prompt_tween: Tween
var _cashier_tween: Tween


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
	_build_dust()
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
	_build_cashier_menu()
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
	var nearest: float = INTERACTION_RADIUS
	for id: StringName in cabinet_positions:
		var distance: float = avatar_position.distance_to(cabinet_positions[id])
		if distance <= nearest:
			nearest = distance
			nearby_definition = definitions.get(id)
	for id: StringName in WING_POSITIONS:
		var distance: float = avatar_position.distance_to(WING_POSITIONS[id])
		if distance <= nearest:
			nearest = distance
			nearby_definition = null
			nearby_wing = id
	var current_game: StringName = nearby_definition.id if nearby_definition != null else &""
	if current_game != _last_nearby_game:
		_dismissed_game = &""
	_last_nearby_game = current_game
	if _prompt != null:
		_update_prompt()
	queue_redraw()


func interact() -> bool:
	if nearby_definition != null:
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
		AudioService.play(&"confirm")
		_update_prompt()
		return true
	return false


func set_prompt_visible(is_visible: bool) -> void:
	if _prompt != null:
		_prompt.visible = is_visible
	queue_redraw()


func dismiss_game_prompt() -> void:
	if nearby_definition != null:
		_dismissed_game = nearby_definition.id
		_last_nearby_game = nearby_definition.id
		_update_prompt()


func _physics_process(delta: float) -> void:
	_ambient_time += delta
	queue_redraw()
	if not _cashier_open:
		move_avatar(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("back")
		or event.is_action_pressed("interact")
		or event.is_action_pressed("secondary")
	):
		get_viewport().set_input_as_handled()
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
	elif _cashier_open and event.is_action_pressed("secondary"):
		Economy.repay_debt(Economy.debt)
		_update_prompt()


func _update_prompt() -> void:
	_prompt.position = Vector2(56, 454)
	_prompt.size = Vector2(848, 54)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _cashier_open:
		_refresh_cashier_menu()
		_prompt.text = (
			tr("CASHIER_ACTIONS")
			% [
				InputRouter.glyph("interact"),
				InputRouter.glyph("secondary"),
				InputRouter.glyph("back")
			]
		)
	elif nearby_definition != null:
		if _dismissed_game == nearby_definition.id:
			_prompt.position = Vector2(330, 486)
			_prompt.size = Vector2(300, 34)
			_prompt.text = tr("FLOOR_HELP") % [InputRouter.glyph("move"), InputRouter.glyph("back")]
		elif Wallet.balance < nearby_definition.min_bet:
			_prompt.position = Vector2(260, 354)
			_prompt.size = Vector2(440, 92)
			_prompt.text = (
				tr("FLOOR_UNAVAILABLE")
				% [tr(nearby_definition.name_key), nearby_definition.min_bet]
			)
		else:
			_prompt.position = Vector2(260, 342)
			_prompt.size = Vector2(440, 108)
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
	else:
		_prompt.position = Vector2(330, 486)
		_prompt.size = Vector2(300, 34)
		_prompt.text = (tr("FLOOR_HELP") % [InputRouter.glyph("move"), InputRouter.glyph("back")])
	_animate_prompt_change()
	queue_redraw()


func _animate_prompt_change() -> void:
	var signature := "%s|%s" % [_prompt.text, _prompt.position]
	if signature == _prompt_signature:
		return
	_prompt_signature = signature
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt.modulate.a = 0.25
	_prompt.pivot_offset = _prompt.size * 0.5
	_prompt.scale = Vector2(0.98, 0.98)
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD)
	_prompt_tween.tween_property(_prompt, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func _build_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.name = "CasinoDust"
	dust.position = Vector2(480, 270)
	dust.amount = 32
	dust.lifetime = 6.5
	dust.preprocess = 6.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(440, 220)
	dust.direction = Vector2.UP
	dust.spread = 35.0
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 8.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 2.2
	dust.color = Color("f2d58d24")
	dust.z_index = 1
	add_child(dust)


func _draw() -> void:
	draw_texture_rect(FLOOR_ART, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 540), Color("0c0b0d24"))
	_draw_floor_lighting()
	draw_rect(Rect2(0, 0, 960, 88), Color("0c0b0d9c"))
	draw_rect(Rect2(32, 92, 896, 352), Color("0c0b0d18"), false, 2.0)
	for id: StringName in cabinet_positions:
		var at: Vector2 = cabinet_positions[id]
		var is_near: bool = nearby_definition != null and nearby_definition.id == id
		var phase := _ambient_time * 1.8 + float(cabinet_positions.keys().find(id)) * 1.9
		var pulse := (sin(phase) + 1.0) * 0.5
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
		if join_dialog:
			draw_rect(Rect2(prompt_rect.position + Vector2(6, 7), prompt_rect.size), Color("05040570"))
		draw_rect(prompt_rect, Color("17161ad4") if join_dialog else Color("17161af0"))
		draw_rect(prompt_rect, CYAN if join_dialog else Color("6e5225"), false, 2.0)


func _draw_machine_zone(id: StringName, at: Vector2, is_near: bool, pulse: float) -> void:
	var accent := _machine_accent(id)
	var ring_color := Color(accent, 0.42)
	var ring_width := 2.0
	if is_near and _dismissed_game != id:
		ring_color = Color(CYAN, 0.72 + pulse * 0.22)
		ring_width = 3.0
	draw_set_transform(at, 0.0, Vector2(1.65, 0.62))
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
	var drift := sin(_ambient_time * 0.18) * 24.0
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(278 + drift, 88), Vector2(354 + drift, 88),
			Vector2(438 + drift, 444), Vector2(314 + drift, 444),
		]),
		Color("d9b44a0a")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(610 - drift, 88), Vector2(680 - drift, 88),
			Vector2(648 - drift, 444), Vector2(526 - drift, 444),
		]),
		Color("8fb8c70a")
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
	_cashier_panel = Panel.new()
	_cashier_panel.name = "CashierMenu"
	_cashier_panel.position = Vector2(270, 112)
	_cashier_panel.size = Vector2(420, 316)
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
	var title := _cashier_label("CASHIER", Vector2(24, 18), Vector2(372, 42), 32, Color("f1e8d8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.position = Vector2(54, 68)
	rule.size = Vector2(312, 2)
	rule.color = BRASS
	_cashier_panel.add_child(rule)
	_cashier_balance = _cashier_label("", Vector2(32, 86), Vector2(356, 42), 24, Color("f2c84b"))
	_cashier_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashier_debt = _cashier_label("", Vector2(32, 128), Vector2(356, 28), 16, Color("b8ad9c"))
	_cashier_debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var marker := _cashier_button("TAKE 100 MARKER", Vector2(28, 180), Vector2(176, 62))
	marker.name = "TakeMarker"
	marker.pressed.connect(func() -> void: Economy.take_marker(); _refresh_cashier_menu())
	var repay := _cashier_button("REPAY DEBT", Vector2(216, 180), Vector2(176, 62))
	repay.name = "RepayDebt"
	repay.pressed.connect(func() -> void: Economy.repay_debt(Economy.debt); _refresh_cashier_menu())
	var close := _cashier_button("CLOSE", Vector2(122, 254), Vector2(176, 42))
	close.name = "CloseCashier"
	close.pressed.connect(_close_cashier)


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
	_cashier_panel.add_child(button)
	ButtonFeedback.attach(button)
	return button


func _refresh_cashier_menu() -> void:
	if _cashier_panel == null:
		return
	var opening := _cashier_open and not _cashier_panel.visible
	_cashier_panel.visible = _cashier_open
	if opening:
		_cashier_panel.pivot_offset = _cashier_panel.size * 0.5
		_cashier_panel.modulate.a = 0.0
		_cashier_panel.scale = Vector2(0.96, 0.96)
		if _cashier_tween != null:
			_cashier_tween.kill()
		_cashier_tween = create_tween().set_parallel(true)
		_cashier_tween.tween_property(_cashier_panel, "modulate:a", 1.0, 0.18)
		_cashier_tween.tween_property(
			_cashier_panel, "scale", Vector2.ONE, 0.18
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cashier_balance.text = "TEST BANK  ∞" if Wallet.test_mode_enabled else "CHIPS  %d" % Wallet.balance
	_cashier_debt.text = "NO OUTSTANDING MARKER" if Economy.debt == 0 else "MARKER DEBT  %d" % Economy.debt
	(_cashier_panel.get_node("TakeMarker") as Button).disabled = not Economy.is_below_solvency_floor()
	(_cashier_panel.get_node("RepayDebt") as Button).disabled = Economy.debt <= 0


func _close_cashier() -> void:
	_cashier_open = false
	_refresh_cashier_menu()
	refresh_proximity()
