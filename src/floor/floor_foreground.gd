class_name FloorForeground
extends Node2D
## Object fronts cut from the room's transparent foreground layer.
##
## Every occluder becomes a textured piece whose node origin sits on the object's
## floor baseline. Inside the y-sorted depth layer a character whose feet are
## above that baseline draws first (behind the object) and one whose feet are
## below it draws on top, so people pass behind and in front of furniture at the
## visible edge. The foreground alpha supplies the exact silhouette.

const VIEW_SIZE := Vector2(960, 540)

var layout: FloorRoomLayout
var _texture: Texture2D


func _init() -> void:
	y_sort_enabled = true


func configure(room: FloorRoomLayout) -> void:
	layout = room
	if is_node_ready():
		_rebuild()


func _ready() -> void:
	_rebuild()


func occluder_count() -> int:
	return get_child_count()


func piece(piece_name: String) -> Polygon2D:
	return get_node_or_null(piece_name) as Polygon2D


func texture() -> Texture2D:
	return _texture


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if layout == null:
		return
	_texture = layout.foreground()
	var texel_scale := Vector2(_texture.get_size()) / VIEW_SIZE
	for occluder: Dictionary in layout.occluders:
		var baseline: float = occluder["baseline"]
		var points: PackedVector2Array = occluder["points"]
		var local := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point: Vector2 in points:
			local.append(point - Vector2(0.0, baseline))
			uvs.append(point * texel_scale)
		var patch := Polygon2D.new()
		patch.name = String(occluder["name"])
		patch.position = Vector2(0.0, baseline)
		patch.polygon = local
		patch.uv = uvs
		patch.texture = _texture
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		patch.set_meta("baseline", baseline)
		add_child(patch)
