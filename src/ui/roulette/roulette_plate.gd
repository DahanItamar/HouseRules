class_name RoulettePlate
extends Control
## A flat Ruby Salon HUD plate (mahogany, brass rule, ivory inlay, brass studs).

var fill: Color = RouletteStyle.MAHOGANY


func _init(plate_name: String = "RoulettePlate", rect: Rect2 = Rect2()) -> void:
	name = plate_name
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	RouletteStyle.draw_plate(self, Rect2(Vector2.ZERO, size), fill)
