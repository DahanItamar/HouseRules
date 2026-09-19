class_name FloorCollisionOverlay
extends Node2D
## Developer view of the active room's collision and depth data (F2).
##
## Walkable bounds are green, solids red, occluder baselines yellow, interaction
## anchors white and the avatar's foot ellipse cyan. The floor only creates this
## node in debug builds with developer tools.

const WALK := Color(0.30, 1.0, 0.45, 0.85)
const SOLID_FILL := Color(1.0, 0.15, 0.25, 0.22)
const SOLID_EDGE := Color(1.0, 0.25, 0.35, 0.95)
const BASELINE := Color(1.0, 0.9, 0.25, 0.8)
const ANCHOR := Color(1.0, 1.0, 1.0, 0.95)
const FOOT := Color(0.28, 0.9, 1.0, 1.0)

var floor: FloorController


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if floor == null or floor.room == null:
		return
	var room := floor.room
	_outline(room.walk_bounds, WALK, 2.0)
	for solid: Dictionary in room.solids:
		var points: PackedVector2Array = solid["points"]
		draw_colored_polygon(points, SOLID_FILL)
		_outline(points, SOLID_EDGE, 1.5)
	for occluder: Dictionary in room.occluders:
		var points: PackedVector2Array = occluder["points"]
		var left := INF
		var right := -INF
		for point: Vector2 in points:
			left = minf(left, point.x)
			right = maxf(right, point.x)
		var baseline: float = occluder["baseline"]
		draw_line(Vector2(left, baseline), Vector2(right, baseline), BASELINE, 1.0)
	var font := ThemeDB.fallback_font
	for anchor_id: StringName in room.anchors:
		var at: Vector2 = room.anchors[anchor_id]
		draw_arc(at, 5.0, 0.0, TAU, 20, ANCHOR, 1.5)
		draw_string(
			font, at + Vector2(7, -4), String(anchor_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ANCHOR
		)
	var foot := floor.avatar_position
	draw_set_transform(foot, 0.0, room.foot_radius)
	draw_arc(Vector2.ZERO, 1.0, 0.0, TAU, 32, FOOT, 1.5 / room.foot_radius.y)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(foot, 1.5, FOOT)
	draw_string(
		font,
		foot + Vector2(12, 14),
		"%d, %d  clear %.1f" % [roundi(foot.x), roundi(foot.y), room.clearance(foot)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		FOOT
	)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width)
