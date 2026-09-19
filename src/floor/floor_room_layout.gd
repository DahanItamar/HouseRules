class_name FloorRoomLayout
extends RefCounted
## One walkable room, loaded from `data/floors/<id>.json`.
##
## Guests are painted into the background inside blocked zones the player can
## never enter (see tools/art/bake_paint_ins.py), so no guest needs runtime depth.
##
## The same file drives the art pipeline (`tools/art/floor_layers.py`), so the
## collision polygons, depth-sorted occluder pieces and anchors used here are the
## exact shapes that produced the layered art. Coordinates are virtual 960x540.

const VIRTUAL_SIZE := Vector2(960, 540)
const MAX_STEP: float = 2.0

var id: StringName = &""
var label: String = ""
var preview_only: bool = false
var background_path: String = ""
var foreground_path: String = ""
var foot_radius := Vector2(10, 6)
## Rooms painted at a closer camera draw the same avatar larger (1.0 = main floor).
var avatar_scale: float = 1.0
var spawn := Vector2.ZERO
var return_point := Vector2.ZERO
var walk_bounds := PackedVector2Array()
## Each entry: {"name": String, "points": PackedVector2Array}.
var solids: Array[Dictionary] = []
## Each entry: {"name": String, "baseline": float, "points": PackedVector2Array}.
var occluders: Array[Dictionary] = []
var anchors: Dictionary = {}
## Playable cabinet ids; each has an anchor of the same name.
var cabinets: Array[StringName] = []

var _warped_bounds := PackedVector2Array()
var _warped_blockers: Array[PackedVector2Array] = []


static func load_room(room_id: StringName) -> FloorRoomLayout:
	return from_file("res://data/floors/%s.json" % room_id)


static func from_file(path: String) -> FloorRoomLayout:
	var text := FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Missing floor layout: %s" % path)
	var data: Variant = JSON.parse_string(text)
	assert(data is Dictionary, "Floor layout is not a JSON object: %s" % path)
	var layout := FloorRoomLayout.new()
	layout._parse(data as Dictionary)
	return layout


func _parse(data: Dictionary) -> void:
	id = StringName(data.get("id", ""))
	label = String(data.get("label", ""))
	preview_only = bool(data.get("preview_only", false))
	background_path = String(data.get("background", ""))
	foreground_path = String(data.get("foreground", ""))
	foot_radius = _vector(data.get("foot_radius", [10, 6]))
	avatar_scale = float(data.get("avatar_scale", 1.0))
	spawn = _vector(data["spawn"])
	return_point = _vector(data.get("return_point", data["spawn"]))
	walk_bounds = _points(data["walk_bounds"])
	for entry: Dictionary in data.get("solids", []):
		solids.append({"name": String(entry["name"]), "points": _points(entry["points"])})
	for entry: Dictionary in data.get("occluders", []):
		(
			occluders
			. append(
				{
					"name": String(entry["name"]),
					"baseline": float(entry["baseline"]),
					"points": _points(entry["points"]),
				}
			)
		)
	for cabinet_id: String in data.get("cabinets", []):
		cabinets.append(StringName(cabinet_id))
	var raw_anchors: Dictionary = data.get("anchors", {})
	for key: String in raw_anchors:
		anchors[StringName(key)] = _vector(raw_anchors[key])
	_rebuild_warped_geometry()


func background() -> Texture2D:
	return load(background_path) as Texture2D


func foreground() -> Texture2D:
	return load(foreground_path) as Texture2D


func anchor(anchor_id: StringName) -> Vector2:
	return anchors.get(anchor_id, spawn)


## The avatar's foot ellipse fits inside the walk bounds and touches no solid.
func is_walkable(point: Vector2) -> bool:
	var warped := _warp(point)
	var radius := foot_radius.x
	if not Geometry2D.is_point_in_polygon(warped, _warped_bounds):
		return false
	if _distance_to_outline(warped, _warped_bounds) < radius:
		return false
	for polygon: PackedVector2Array in _warped_blockers:
		if Geometry2D.is_point_in_polygon(warped, polygon):
			return false
		if _distance_to_outline(warped, polygon) < radius:
			return false
	return true


## Moves from `origin` by `motion`, sliding along blocking edges. Motion is
## split into sub-steps no longer than MAX_STEP so a long frame cannot tunnel.
func resolve_motion(origin: Vector2, motion: Vector2) -> Vector2:
	var position := origin
	if motion.is_zero_approx():
		return position
	var steps: int = maxi(1, ceili(motion.length() / MAX_STEP))
	var step := motion / float(steps)
	for _index: int in range(steps):
		var candidate := position + step
		if is_walkable(candidate):
			position = candidate
			continue
		var tangent := _slide(position, step)
		if not tangent.is_zero_approx() and is_walkable(position + tangent):
			position += tangent
			continue
		if is_walkable(position + Vector2(step.x, 0.0)):
			position += Vector2(step.x, 0.0)
		elif is_walkable(position + Vector2(0.0, step.y)):
			position += Vector2(0.0, step.y)
	return position


## Distance in virtual pixels from `point` to the nearest solid or bound edge.
func clearance(point: Vector2) -> float:
	var warped := _warp(point)
	var nearest := _distance_to_outline(warped, _warped_bounds)
	for polygon: PackedVector2Array in _warped_blockers:
		nearest = minf(nearest, _distance_to_outline(warped, polygon))
	return nearest


func _slide(position: Vector2, step: Vector2) -> Vector2:
	var warped := _warp(position + step)
	var best_distance := INF
	var best_edge := Vector2.ZERO
	var outlines: Array[PackedVector2Array] = [_warped_bounds]
	outlines.append_array(_warped_blockers)
	for polygon: PackedVector2Array in outlines:
		for index: int in range(polygon.size()):
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			var closest := Geometry2D.get_closest_point_to_segment(warped, a, b)
			var distance := warped.distance_to(closest)
			if distance < best_distance:
				best_distance = distance
				best_edge = b - a
	if best_edge.is_zero_approx():
		return Vector2.ZERO
	var tangent := _unwarp(best_edge).normalized()
	return tangent * step.dot(tangent)


func _rebuild_warped_geometry() -> void:
	_warped_bounds = _warp_polygon(walk_bounds)
	_warped_blockers.clear()
	for solid: Dictionary in solids:
		_warped_blockers.append(_warp_polygon(solid["points"]))


# The foot ellipse becomes a circle of radius rx when y is stretched by rx / ry.
func _warp(point: Vector2) -> Vector2:
	return Vector2(point.x, point.y * foot_radius.x / foot_radius.y)


func _unwarp(vector: Vector2) -> Vector2:
	return Vector2(vector.x, vector.y * foot_radius.y / foot_radius.x)


func _warp_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(_warp(point))
	return result


static func _distance_to_outline(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for index: int in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(
			point, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		nearest = minf(nearest, point.distance_to(closest))
	return nearest


static func _vector(value: Variant) -> Vector2:
	var pair: Array = value
	return Vector2(float(pair[0]), float(pair[1]))


static func _points(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for pair: Array in value:
		result.append(Vector2(float(pair[0]), float(pair[1])))
	return result
