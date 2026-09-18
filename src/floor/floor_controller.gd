class_name FloorController
extends Node2D

const SPEED: float = 180.0
const INTERACTION_RADIUS: float = 76.0
const CASHIER_POSITION := Vector2(780, 350)
const WING_POSITIONS: Dictionary = {&"high_roller": Vector2(90, 180), &"vip": Vector2(870, 180)}
const WING_THRESHOLDS: Dictionary = {&"high_roller": 5000, &"vip": 100_000}
const FLOOR_ART := preload("res://assets/production/environments/casino_floor.png")
const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const CYAN := Color("48c5d5")
var avatar_position := Vector2(480, 408)
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
	_prompt.size = Vector2(260, 72)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_prompt.add_theme_color_override("font_color", IVORY)
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
	queue_redraw()


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
	_prompt.position = Vector2(56, 454)
	_prompt.size = Vector2(848, 54)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		_prompt.position = cabinet_positions[nearby_definition.id] + Vector2(-130, 64)
		_prompt.size = Vector2(260, 74)
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
		_prompt.position = WING_POSITIONS[nearby_wing] + Vector2(-115, 64)
		_prompt.size = Vector2(230, 72)
		_prompt.text = (
			tr("WING_LOCKED")
			% [tr("WING_" + String(nearby_wing).to_upper()), WING_THRESHOLDS[nearby_wing]]
		)
	elif avatar_position.distance_to(CASHIER_POSITION) <= INTERACTION_RADIUS:
		_prompt.text = tr("CASHIER_PROMPT") % InputRouter.glyph("interact")
	else:
		_prompt.text = (tr("FLOOR_HELP") % [InputRouter.glyph("move"), InputRouter.glyph("back")])
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(FLOOR_ART, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 540), Color("0c0b0d24"))
	draw_rect(Rect2(0, 0, 960, 88), Color("0c0b0d9c"))
	draw_rect(Rect2(32, 92, 896, 352), Color("0c0b0d18"), false, 2.0)
	for id: StringName in cabinet_positions:
		var at: Vector2 = cabinet_positions[id]
		var is_near: bool = nearby_definition != null and nearby_definition.id == id
		draw_circle(at, 34.0, Color("0c0b0d99"))
		draw_arc(at, 38.0, 0.0, TAU, 48, CYAN if is_near else BRASS, 3.0)
		draw_string(
			ThemeDB.fallback_font,
			at + Vector2(-66, -48),
			tr((definitions[id] as CabinetDefinition).name_key),
			HORIZONTAL_ALIGNMENT_CENTER,
			132,
			Typography.SUPPORTING,
			IVORY
		)
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
		draw_arc(wing_at, 30.0, 0.0, TAU, 36, Color("6e5225"), 2.0)
	# A tailored, high-contrast floor avatar with a grounded shadow.
	draw_circle(avatar_position + Vector2(0, 11), 15.0, Color("0c0b0d99"))
	draw_polygon(
		PackedVector2Array(
			[
				avatar_position + Vector2(-9, 13),
				avatar_position + Vector2(-7, -5),
				avatar_position + Vector2(0, -11),
				avatar_position + Vector2(7, -5),
				avatar_position + Vector2(9, 13),
			]
		),
		PackedColorArray([Color("5a111c")])
	)
	draw_circle(avatar_position + Vector2(0, -13), 6.0, IVORY)
	draw_line(avatar_position + Vector2(-7, 2), avatar_position + Vector2(7, 2), BRASS, 2.0)
	if _prompt != null and _prompt.visible:
		var prompt_rect := Rect2(_prompt.position - Vector2(12, 8), _prompt.size + Vector2(24, 16))
		draw_rect(prompt_rect, Color("17161af0"))
		draw_rect(prompt_rect, CYAN if nearby_definition != null else Color("6e5225"), false, 2.0)
