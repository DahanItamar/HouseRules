class_name RouletteBoard
extends Control
## The single-zero betting layout, drawn in code for exact geometry on the
## painted sapphire felt. One cursor serves controller, keyboard and pointer:
## D-pad/stick/WASD step half a cell (numbers, edges, corners), A/Enter or a
## left click places the selected chip, X or a right click takes one back.

signal place_requested(spot_id: String)
signal remove_requested(spot_id: String)
signal cursor_changed(spot_id: String)
## The cursor tried to leave the bottom edge: the deck below takes focus.
signal exit_requested(direction: Vector2i)

const CHIP_SIZE: float = 22.0
const GUEST_OFFSETS: Array[Vector2] = [Vector2(-8, -6), Vector2(8, -6), Vector2(0, 8)]
## Guests' straight-up chips sit in a cell corner so the number stays readable.
const GUEST_CORNERS: Array[Vector2] = [Vector2(-13, -13), Vector2(13, -13), Vector2(-13, 13)]
const STICK_RELEASE: float = 0.45
const WIN_PULSE_SECONDS: float = 0.9

var math: RouletteMath
var geometry: RouletteBoardGeometry
var cursor_index: int = 0
var betting_open: bool = true
## [{"color": Color, "bets": Dictionary}] for the three seated guests.
var guest_bets: Array = []
## Result being presented: pocket and the bets that were on the layout.
var result_pocket: int = -1
var result_bets: Dictionary = {}
var _stick_latched: Dictionary = {}
var _hovering: bool = false
var _win_phase: float = 0.0
var _chip_textures: Dictionary = {}


func setup(table_math: RouletteMath, chip_textures: Dictionary) -> void:
	math = table_math
	_chip_textures = chip_textures
	geometry = RouletteBoardGeometry.new(math)
	size = RouletteBoardGeometry.SIZE
	cursor_index = geometry.index_of(RouletteMath.spot_id(RouletteMath.BetKind.RED))
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(func() -> void: _hovering = false)
	set_process(false)


func cursor_spot_id() -> String:
	return geometry.nodes[cursor_index].id if geometry != null else ""


func set_cursor(index: int) -> void:
	if index < 0 or index >= geometry.nodes.size() or index == cursor_index:
		return
	cursor_index = index
	queue_redraw()
	cursor_changed.emit(cursor_spot_id())


func move_cursor(direction: Vector2i) -> bool:
	var next := geometry.neighbor(cursor_index, direction)
	if next < 0:
		if direction == Vector2i.DOWN:
			exit_requested.emit(direction)
			return true
		return false
	set_cursor(next)
	AudioService.play(&"move")
	return true


## Shows the settled pocket; `pulse` animates the winning cell once.
func show_result(pocket: int, bets: Dictionary, pulse: bool) -> void:
	result_pocket = pocket
	result_bets = bets.duplicate()
	_win_phase = 0.0
	set_process(pulse and not MotionPolicy.is_reduced())
	queue_redraw()


func clear_result() -> void:
	result_pocket = -1
	result_bets.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_win_phase += delta
	if _win_phase >= WIN_PULSE_SECONDS:
		_win_phase = WIN_PULSE_SECONDS
		set_process(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hovering = true
		var hovered := geometry.hit_test((event as InputEventMouseMotion).position)
		if hovered >= 0:
			set_cursor(hovered)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		var target := geometry.hit_test(button.position)
		if target < 0:
			return
		set_cursor(target)
		grab_focus()
		if button.button_index == MOUSE_BUTTON_LEFT:
			place_requested.emit(cursor_spot_id())
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			remove_requested.emit(cursor_spot_id())
			accept_event()
		return
	if _swallow_stick_repeat(event):
		accept_event()
		return
	var direction := _direction_of(event)
	if direction != Vector2i.ZERO:
		move_cursor(direction)
		accept_event()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		place_requested.emit(cursor_spot_id())
		accept_event()
	elif event.is_action_pressed("secondary"):
		remove_requested.emit(cursor_spot_id())
		accept_event()


func _direction_of(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		return Vector2i.UP
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	return Vector2i.ZERO


## An analog stick held past the deadzone moves the cursor once per push.
func _swallow_stick_repeat(event: InputEvent) -> bool:
	var motion := event as InputEventJoypadMotion
	if motion == null:
		return false
	if absf(motion.axis_value) < STICK_RELEASE:
		_stick_latched[motion.axis] = false
		return true
	if bool(_stick_latched.get(motion.axis, false)):
		return true
	_stick_latched[motion.axis] = true
	return false


func _draw() -> void:
	if geometry == null:
		return
	_draw_layout()
	_draw_cursor_highlight()
	_draw_result_marker()
	_draw_all_chips()
	_draw_cursor_ring()


func _draw_layout() -> void:
	var board := Rect2(Vector2.ZERO, RouletteBoardGeometry.SIZE)
	var shadow_height := RouletteBoardGeometry.GRID_BOTTOM + 12.0
	draw_rect(Rect2(-6, -6, board.size.x + 12, shadow_height), Color("06091a66"))
	for number: int in range(0, 37):
		var rect := RouletteBoardGeometry.number_rect(number)
		draw_rect(rect.grow(-1.5), Color(RouletteStyle.pocket_color(number, math), 0.92))
		RouletteStyle.draw_centered(self, str(number), rect.get_center(), 19, RouletteStyle.IVORY)
	for index: int in range(geometry.nodes.size()):
		var rect: Rect2 = geometry.nodes[index].rect
		if rect.size == Vector2.ZERO or (geometry.nodes[index].numbers as Array).size() < 12:
			continue
		draw_rect(rect.grow(-1.5), RouletteStyle.LAYOUT_CLOTH)
		_draw_outside_face(geometry.nodes[index].id, rect)
	_draw_rules()


func _draw_rules() -> void:
	var line := Color(RouletteStyle.IVORY, 0.78)
	var left := RouletteBoardGeometry.GRID_LEFT
	var right := RouletteBoardGeometry.GRID_RIGHT
	var grid_bottom := RouletteBoardGeometry.GRID_BOTTOM
	var outside_top := RouletteBoardGeometry.OUTSIDE_TOP
	var board := RouletteBoardGeometry.SIZE
	for column: int in range(RouletteBoardGeometry.COLUMNS + 1):
		var x := left + column * RouletteBoardGeometry.CELL
		draw_line(Vector2(x, 0), Vector2(x, grid_bottom), line, 1.5)
		if column % 4 == 0:
			draw_line(Vector2(x, grid_bottom), Vector2(x, outside_top), line, 1.5)
		if column % 2 == 0:
			draw_line(Vector2(x, outside_top), Vector2(x, board.y), line, 1.5)
	for row: int in range(1, 3):
		var y := row * RouletteBoardGeometry.CELL
		draw_line(Vector2(left, y), Vector2(board.x, y), line, 1.5)
	draw_line(Vector2(left, outside_top), Vector2(right, outside_top), line, 1.5)
	draw_rect(Rect2(0, 0, board.x, grid_bottom), RouletteStyle.BRASS, false, 2.0)
	draw_rect(
		Rect2(left, grid_bottom, right - left, board.y - grid_bottom),
		RouletteStyle.BRASS,
		false,
		2.0
	)
	draw_line(Vector2(right, 0), Vector2(right, grid_bottom), RouletteStyle.BRASS, 2.0)


func _draw_outside_face(id: String, rect: Rect2) -> void:
	var spot := math.spot(id)
	var center := rect.get_center()
	match int(spot.kind):
		RouletteMath.BetKind.RED, RouletteMath.BetKind.BLACK:
			var fill := (
				RouletteStyle.RUBY if spot.kind == RouletteMath.BetKind.RED else RouletteStyle.EBONY
			)
			var diamond := PackedVector2Array(
				[
					center + Vector2(0, -13),
					center + Vector2(24, 0),
					center + Vector2(0, 13),
					center + Vector2(-24, 0),
				]
			)
			draw_colored_polygon(diamond, fill)
			diamond.append(diamond[0])
			draw_polyline(diamond, RouletteStyle.IVORY, 1.5, true)
		_:
			var face := tr(RouletteSpotNames.face_key(id))
			RouletteStyle.draw_centered(self, face, center, 16, RouletteStyle.IVORY)


func _draw_cursor_highlight() -> void:
	var node: Dictionary = geometry.nodes[cursor_index]
	var tint := Color(RouletteStyle.BRASS_BRIGHT, 0.26 if betting_open else 0.12)
	for number: int in node.numbers:
		draw_rect(RouletteBoardGeometry.number_rect(number).grow(-2.0), tint)
	var rect: Rect2 = node.rect
	if rect.size != Vector2.ZERO and (node.numbers as Array).size() >= 12:
		draw_rect(rect.grow(-2.0), tint)


func _draw_cursor_ring() -> void:
	if not betting_open:
		return
	var at: Vector2 = geometry.nodes[cursor_index].position
	var ring := RouletteStyle.FOCUS if has_focus() else RouletteStyle.BRASS_BRIGHT
	if not has_focus() and not _hovering:
		ring = Color(RouletteStyle.BRASS_BRIGHT, 0.6)
	draw_arc(at, 13.0, 0.0, TAU, 32, ring, 2.5, true)


## The dolly: an ivory marker with a brass crown on the winning number.
func _draw_result_marker() -> void:
	if result_pocket < 0:
		return
	var rect := RouletteBoardGeometry.number_rect(result_pocket)
	var pulse := 0.0
	if is_processing():
		pulse = sin(_win_phase / WIN_PULSE_SECONDS * PI)
	draw_rect(rect.grow(-1.0), Color(RouletteStyle.BRASS_BRIGHT, 0.28 + pulse * 0.2))
	draw_rect(rect.grow(-1.0), RouletteStyle.BRASS_BRIGHT, false, 3.0)
	var top := Vector2(rect.get_center().x, rect.position.y + 9.0)
	draw_circle(top, 7.0, RouletteStyle.IVORY)
	draw_arc(top, 7.0, 0.0, TAU, 20, RouletteStyle.BRASS, 2.0, true)
	draw_circle(top, 3.0, RouletteStyle.BRASS)


func _draw_all_chips() -> void:
	var settling := result_pocket >= 0
	for guest_index: int in range(guest_bets.size()):
		var entry: Dictionary = guest_bets[guest_index]
		for id: String in entry.bets as Dictionary:
			var won := settling and math.returned_for(id, 1, result_pocket) > 0
			var alpha := 1.0 if not settling or won else 0.32
			var offsets := GUEST_CORNERS if id.begins_with("straight") else GUEST_OFFSETS
			var offset: Vector2 = offsets[guest_index % offsets.size()]
			_draw_guest_chip(geometry.chip_position(id) + offset, entry.color, alpha)
	var player_bets: Dictionary = math.bets if not math.bets.is_empty() else result_bets
	for id: String in player_bets:
		var won := settling and math.returned_for(id, 1, result_pocket) > 0
		var alpha := 1.0 if not settling or won else 0.36
		draw_chip_stack(self, geometry.chip_position(id), int(player_bets[id]), alpha, won)


func _draw_guest_chip(at: Vector2, tint: Color, alpha: float) -> void:
	var texture: Texture2D = _chip_textures.get(1)
	var rect := Rect2(at - Vector2.ONE * 8.0, Vector2.ONE * 16.0)
	draw_circle(at + Vector2(0, 1.5), 8.0, Color(0, 0, 0, 0.35 * alpha))
	draw_texture_rect(texture, rect, false, Color(tint, alpha))


## A player stack: the top chip is the largest denomination the stack can show,
## with a height hint underneath and the exact amount on its face.
func draw_chip_stack(canvas: CanvasItem, at: Vector2, amount: int, alpha: float, won: bool) -> void:
	var denomination := 1
	for value: int in _chip_textures.keys():
		if value <= amount and value > denomination:
			denomination = value
	var texture: Texture2D = _chip_textures.get(denomination)
	var layers := clampi(int(ceil(float(amount) / float(denomination))), 1, 4)
	var half := CHIP_SIZE * 0.5
	canvas.draw_circle(at + Vector2(0, 2), half, Color(0, 0, 0, 0.4 * alpha))
	for layer: int in range(layers):
		var lift := Vector2(0, -2.0 * layer)
		canvas.draw_texture_rect(
			texture,
			Rect2(at + lift - Vector2.ONE * half, Vector2.ONE * CHIP_SIZE),
			false,
			Color(1, 1, 1, alpha)
		)
	var face := at + Vector2(0, -2.0 * (layers - 1))
	if won:
		canvas.draw_arc(face, half + 2.0, 0.0, TAU, 28, RouletteStyle.WIN_INK, 2.0, true)
	RouletteStyle.draw_centered(canvas, str(amount), face, 11, Color(Color("1b120c"), alpha))
