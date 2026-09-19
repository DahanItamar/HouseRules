class_name BaccaratPlate
extends Control
## A flat Velvet Baccarat HUD plate (violet lacquer, brass rule, pearl inlay).

var fill: Color = BaccaratStyle.LACQUER


func _init(plate_name: String = "BaccaratPlate", rect: Rect2 = Rect2()) -> void:
	name = plate_name
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	BaccaratStyle.draw_plate(self, Rect2(Vector2.ZERO, size), fill)
