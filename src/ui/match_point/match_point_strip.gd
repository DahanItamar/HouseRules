class_name MatchPointStrip
extends Control
## A cream enamel score strip with a thin brass edge, set into a scoreboard plate.

var fill: Color = MatchPointStyle.CREAM


func _init(strip_name: String = "MatchPointStrip", rect: Rect2 = Rect2()) -> void:
	name = strip_name
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	MatchPointStyle.draw_strip(self, Rect2(Vector2.ZERO, size), fill)
