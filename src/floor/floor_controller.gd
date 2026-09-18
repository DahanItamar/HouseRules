class_name FloorController
extends Node2D

const SPEED: float = 180.0
const INTERACTION_RADIUS: float = 76.0
const CASHIER_POSITION := Vector2(780, 350)
const WING_POSITIONS: Dictionary = {&"high_roller": Vector2(90, 180), &"vip": Vector2(870, 180)}
const WING_THRESHOLDS: Dictionary = {&"high_roller": 5000, &"vip": 100_000}
const FLOOR_TEXTURES: Dictionary = {
	&"slot_classic": preload("res://assets/drafts/m2/slot_classic_floor.png"),
	&"blackjack": preload("res://assets/drafts/m2/blackjack_table_floor.png"),
	&"minefield_vault": preload("res://assets/drafts/m2/vault_door_floor.png"),
	&"cashier": preload("res://assets/drafts/m2/cashier_cage.png"),
	&"high_roller": preload("res://assets/drafts/m2/staircase_up.png"),
	&"vip": preload("res://assets/drafts/m2/elevator_doors.png"),
}
var avatar_position := Vector2(200, 330)
var nearby_definition: CabinetDefinition
var nearby_wing: StringName = &""
var cabinet_positions: Dictionary = {
	&"slot_classic": Vector2(250, 200),
	&"blackjack": Vector2(480, 200),
	&"minefield_vault": Vector2(710, 200),
}
var definitions: Dictionary = {}
var _prompt: Label
var _cashier_open: bool = false


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
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_prompt.add_theme_color_override("font_color", Color("e8e6f0"))
	add_child(_prompt)
	SceneRouter.register_floor(self)
	Wallet.balance_changed.connect(func(_old: int, _new: int) -> void: refresh_proximity())
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh_proximity())
	refresh_proximity()


func move_avatar(direction: Vector2, delta: float) -> void:
	if not direction.is_zero_approx():
		avatar_position += direction.normalized() * SPEED * delta
	avatar_position = avatar_position.clamp(Vector2(64, 110), Vector2(896, 440))
	refresh_proximity()
	queue_redraw()


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


func _physics_process(delta: float) -> void:
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
			_cashier_open = false
			refresh_proximity()
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
	_prompt.position = Vector2(70, 455)
	if _cashier_open:
		_prompt.text = (
			tr("CASHIER_ACTIONS")
			% [
				InputRouter.glyph("interact"),
				InputRouter.glyph("secondary"),
				InputRouter.glyph("back")
			]
		)
	elif nearby_definition != null:
		_prompt.position = cabinet_positions[nearby_definition.id] + Vector2(-95, -85)
		if Wallet.balance < nearby_definition.min_bet:
			_prompt.text = (
				tr("FLOOR_UNAVAILABLE")
				% [tr(nearby_definition.name_key), nearby_definition.min_bet]
			)
		else:
			_prompt.text = (
				tr("FLOOR_PROMPT")
				% [
					tr(nearby_definition.name_key),
					nearby_definition.min_bet,
					nearby_definition.max_bet,
					InputRouter.glyph("interact")
				]
			)
	elif nearby_wing != &"":
		_prompt.position = WING_POSITIONS[nearby_wing] + Vector2(-80, 74)
		_prompt.text = (
			tr("WING_LOCKED")
			% [tr("WING_" + String(nearby_wing).to_upper()), WING_THRESHOLDS[nearby_wing]]
		)
	elif avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS:
		_prompt.text = tr("CASHIER_PROMPT") % InputRouter.glyph("interact")
	else:
		_prompt.text = (tr("FLOOR_HELP") % [InputRouter.glyph("move"), InputRouter.glyph("back")])


func _draw() -> void:
	draw_rect(Rect2(40, 94, 880, 358), Color("1a1826"))
	for x: int in range(56, 920, 32):
		draw_line(Vector2(x, 94), Vector2(x, 452), Color("2d2a3e"))
	for id: StringName in cabinet_positions:
		var at: Vector2 = cabinet_positions[id]
		draw_texture_rect(FLOOR_TEXTURES[id], Rect2(at - Vector2(32, 24), Vector2(64, 48)), false)
	draw_texture_rect(
		FLOOR_TEXTURES.cashier, Rect2(CASHIER_POSITION - Vector2(50, 38), Vector2(100, 76)), false
	)
	draw_string(
		ThemeDB.fallback_font,
		CASHIER_POSITION + Vector2(-42, 4),
		tr("CASHIER_NAME"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		Typography.CRITICAL,
		Color("e8e6f0")
	)
	draw_texture_rect(
		FLOOR_TEXTURES.high_roller,
		Rect2(WING_POSITIONS.high_roller - Vector2(36, 48), Vector2(72, 96)),
		false
	)
	draw_texture_rect(
		FLOOR_TEXTURES.vip, Rect2(WING_POSITIONS.vip - Vector2(30, 42), Vector2(60, 84)), false
	)
	draw_circle(avatar_position, 12, Color("e8e6f0"))
	draw_circle(avatar_position + Vector2(0, -5), 5, Color("ff3d7f"))
