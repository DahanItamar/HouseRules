class_name SnapCursor
extends RefCounted

signal moved(index: int)

var columns: int
var rows: int
var index: int = 0


func _init(grid_columns: int = 1, grid_rows: int = 1) -> void:
	columns = maxi(1, grid_columns)
	rows = maxi(1, grid_rows)


func reset() -> void:
	index = 0
	moved.emit(index)


func move(direction: Vector2i) -> bool:
	if direction == Vector2i.ZERO:
		return false
	var position := Vector2i(index % columns, index / columns)
	position.x = posmod(position.x + signi(direction.x), columns)
	position.y = posmod(position.y + signi(direction.y), rows)
	var next_index: int = position.y * columns + position.x
	if next_index == index:
		return false
	index = next_index
	moved.emit(index)
	return true
