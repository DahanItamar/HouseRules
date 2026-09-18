class_name CreditChipIcon
extends Control
## Resolution-independent casino chip stack used by the global credit HUD.


func _ready() -> void:
	custom_minimum_size = Vector2(38, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	for chip_data: Array in [
		[Vector2(19, 24), Color("5a111c")],
		[Vector2(15, 18), Color("f1e8d8")],
		[Vector2(21, 12), Color("5a111c")],
	]:
		var center: Vector2 = chip_data[0]
		var fill: Color = chip_data[1]
		draw_circle(center, 9.0, Color("0c0b0d"))
		draw_circle(center, 8.0, fill)
		draw_arc(center, 6.0, 0.0, TAU, 24, Color("c8a34b"), 2.0)
		draw_line(center + Vector2(-8, 0), center + Vector2(-4, 0), Color("c8a34b"), 2.0)
		draw_line(center + Vector2(4, 0), center + Vector2(8, 0), Color("c8a34b"), 2.0)
