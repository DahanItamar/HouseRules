class_name CashierWaypoint
extends Panel

## Screen-space route marker used only when the player can claim a recovery marker.

const SAFE_MARGIN: float = 16.0
const MARKER_SIZE := Vector2(204, 44)
const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const SURFACE := Color("17161aeb")

var _arrow: Polygon2D
var _caption: Label
var _active: bool = false
var _visibility_tween: Tween


func _ready() -> void:
	name = "CashierWaypoint"
	size = MARKER_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	var plaque := StyleBoxFlat.new()
	plaque.bg_color = SURFACE
	plaque.border_color = Color(BRASS, 0.82)
	plaque.set_border_width_all(1)
	plaque.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", plaque)

	_arrow = Polygon2D.new()
	_arrow.name = "DirectionArrow"
	_arrow.polygon = PackedVector2Array([Vector2(10, 0), Vector2(-7, -7), Vector2(-7, 7)])
	_arrow.color = BRASS
	_arrow.position = Vector2(23, 22)
	add_child(_arrow)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.position = Vector2(44, 4)
	_caption.size = Vector2(150, 36)
	_caption.text = tr("CASHIER_WAYPOINT")
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", Typography.UI_FONT)
	_caption.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	_caption.add_theme_color_override("font_color", IVORY)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	hide()


func update_route(origin_world: Vector2, target_world: Vector2, should_show: bool) -> void:
	_caption.text = tr("CASHIER_WAYPOINT")
	var canvas_transform := get_viewport().get_canvas_transform()
	var origin_screen := canvas_transform * origin_world
	var target_screen := canvas_transform * target_world
	var direction := target_screen - origin_screen
	if not direction.is_zero_approx():
		_arrow.rotation = direction.angle()

	var viewport_size := get_viewport_rect().size
	var desired := target_screen - Vector2(MARKER_SIZE.x * 0.5, MARKER_SIZE.y + 50.0)
	position = Vector2(
		clampf(desired.x, SAFE_MARGIN, viewport_size.x - MARKER_SIZE.x - SAFE_MARGIN),
		clampf(desired.y, SAFE_MARGIN, viewport_size.y - MARKER_SIZE.y - SAFE_MARGIN)
	)

	if should_show == _active:
		return
	_active = should_show
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null
	if should_show:
		show()
		pivot_offset = size * 0.5
		modulate.a = 1.0 if MotionPolicy.is_reduced() else 0.0
		scale = Vector2.ONE if MotionPolicy.is_reduced() else Vector2(0.98, 0.98)
		if not MotionPolicy.is_reduced():
			_visibility_tween = create_tween().set_parallel(true)
			_visibility_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_OUT)
			_visibility_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(
				Tween.TRANS_QUAD
			).set_ease(Tween.EASE_OUT)
	else:
		if MotionPolicy.is_reduced() or not visible:
			hide()
			modulate.a = 1.0
			scale = Vector2.ONE
			return
		_visibility_tween = create_tween().set_parallel(true)
		_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_visibility_tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.12).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_visibility_tween.finished.connect(_finish_hide)


func _finish_hide() -> void:
	if _active:
		return
	hide()
	modulate.a = 1.0
	scale = Vector2.ONE
	_visibility_tween = null


func route_angle() -> float:
	return _arrow.rotation
