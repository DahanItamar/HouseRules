class_name MatchPointPlate
extends Control
## A flat Match Point scoreboard plate: racing green with double brass piping.

var fill: Color = MatchPointStyle.RACING_GREEN


func _init(plate_name: String = "MatchPointPlate", rect: Rect2 = Rect2()) -> void:
	name = plate_name
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	MatchPointStyle.draw_plate(self, Rect2(Vector2.ZERO, size), fill)
