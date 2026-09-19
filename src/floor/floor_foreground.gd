class_name FloorForeground
extends Node2D
## Exact floor-art cutouts rendered above characters to restore object depth.

const FLOOR_ART := preload("res://assets/production/environments/casino_floor.png")
const VIEW_SIZE := Vector2(960, 540)
static var OCCLUDERS: Array[Dictionary] = [
	{
		"name": "SlotMachineFront",
		"points": PackedVector2Array([
			Vector2(278, 145), Vector2(420, 145), Vector2(420, 187),
			Vector2(390, 219), Vector2(278, 219), Vector2(250, 184),
		]),
	},
	{
		"name": "BlackjackMachineFront",
		"points": PackedVector2Array([
			Vector2(425, 145), Vector2(586, 145), Vector2(586, 188),
			Vector2(558, 215), Vector2(450, 215), Vector2(425, 184),
		]),
	},
	{
		"name": "VaultMachineFront",
		"points": PackedVector2Array([
			Vector2(590, 145), Vector2(766, 145), Vector2(766, 188),
			Vector2(738, 216), Vector2(628, 216), Vector2(588, 185),
		]),
	},
	{
		"name": "LoungeFront",
		"points": PackedVector2Array([
			Vector2(0, 390), Vector2(176, 390), Vector2(228, 430),
			Vector2(231, 474), Vector2(196, 526), Vector2(0, 540),
		]),
	},
	{
		"name": "CashierFront",
		"points": PackedVector2Array([
			Vector2(695, 350), Vector2(960, 330), Vector2(960, 500),
			Vector2(718, 500), Vector2(690, 451),
		]),
	},
	{
		"name": "PlanterFront",
		"points": PackedVector2Array([
			Vector2(278, 465), Vector2(326, 438), Vector2(600, 438),
			Vector2(681, 478), Vector2(681, 540), Vector2(270, 540),
		]),
	},
]


func _ready() -> void:
	for definition: Dictionary in OCCLUDERS:
		var patch := Polygon2D.new()
		patch.name = String(definition.name)
		patch.polygon = definition.points as PackedVector2Array
		patch.uv = _source_uvs(patch.polygon)
		patch.texture = FLOOR_ART
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(patch)


func occluder_count() -> int:
	return get_child_count()


func _source_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var source_size := Vector2(FLOOR_ART.get_size())
	var scale := source_size / VIEW_SIZE
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point * scale)
	return result
