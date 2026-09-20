class_name DevLauncher
extends Control
## The floating developer widget: a round brass ring with a wrench drawn in
## code. Click to open the developer panel; drag to park it on any screen edge.
##
## It never takes keyboard focus, so a closed widget cannot steal input from
## the game. Debug builds only (see DevOverlay).

signal activated
signal dropped(at: Vector2)

const DIAMETER: float = 44.0
const DRAG_THRESHOLD: float = 6.0
const REST_ALPHA: float = 0.55
const HOVER_ALPHA: float = 1.0
const BRASS := Color("c8a34b")
const BRASS_DARK := Color("6e5225")
const FILL := Color("141013")
const IVORY := Color("f1e8d8")

var is_open: bool = false:
	set(value):
		is_open = value
		_refresh_alpha()
		queue_redraw()
var _hovered: bool = false
var _pressing: bool = false
var _dragging: bool = false
var _press_origin := Vector2.ZERO
var _grab_offset := Vector2.ZERO


func _init() -> void:
	name = "DevLauncher"
	size = Vector2(DIAMETER, DIAMETER)
	custom_minimum_size = size
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Developer menu (F10 / `)"
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_refresh_alpha()


## The widget as a clickable circle: only the ring's disc accepts the mouse.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= DIAMETER * 0.5


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressing = true
			_dragging = false
			_press_origin = button.global_position
			_grab_offset = button.global_position - global_position
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				dropped.emit(position)
			else:
				activated.emit()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressing:
		if not _dragging and motion.global_position.distance_to(_press_origin) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			position = _clamped(motion.global_position - _grab_offset)
		accept_event()


func is_dragging() -> bool:
	return _dragging


## Nearest screen edge for a free position: the widget is parked flush on it.
static func snap_to_edge(at: Vector2, screen: Vector2, margin: float = 2.0) -> Vector2:
	var limit := screen - Vector2(DIAMETER, DIAMETER) - Vector2(margin, margin)
	var clamped := Vector2(clampf(at.x, margin, limit.x), clampf(at.y, margin, limit.y))
	var distances: Array[float] = [
		clamped.x - margin, limit.x - clamped.x, clamped.y - margin, limit.y - clamped.y
	]
	var nearest := distances.find(distances.min())
	match nearest:
		0:
			clamped.x = margin
		1:
			clamped.x = limit.x
		2:
			clamped.y = margin
		_:
			clamped.y = limit.y
	return clamped


func _clamped(at: Vector2) -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(clampf(at.x, 0.0, screen.x - DIAMETER), clampf(at.y, 0.0, screen.y - DIAMETER))


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_alpha()
	queue_redraw()


func _refresh_alpha() -> void:
	modulate.a = HOVER_ALPHA if _hovered or is_open or _dragging else REST_ALPHA


func _draw() -> void:
	var center := size * 0.5
	var radius := DIAMETER * 0.5 - 1.0
	draw_circle(center, radius, FILL)
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, BRASS, 3.0, true)
	draw_arc(center, radius - 5.0, 0.0, TAU, 48, BRASS_DARK, 1.0, true)
	_draw_wrench(center, BRASS if not is_open else IVORY)


## A diagonal wrench: an open jaw at the top right and a round eye at the
## bottom left, joined by a straight handle.
func _draw_wrench(center: Vector2, color: Color) -> void:
	var axis := Vector2(1, -1).normalized()
	var normal := Vector2(axis.y, -axis.x)
	var head := center + axis * 8.0
	var tail := center - axis * 8.5
	draw_line(tail, head, color, 4.0, true)
	draw_circle(head, 5.6, color)
	var jaw := PackedVector2Array(
		[
			head + axis * 1.0 + normal * 2.0,
			head + axis * 7.0 + normal * 2.0,
			head + axis * 7.0 - normal * 2.0,
			head + axis * 1.0 - normal * 2.0,
		]
	)
	draw_colored_polygon(jaw, FILL)
	draw_circle(tail, 3.6, color)
	draw_circle(tail, 1.5, FILL)
