class_name CasinoAmbient
extends Control
## Quiet moving marquee points keep cabinet stages alive without obscuring play.

var elapsed: float = 0.0
var accent := Color("c8a34b")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	for index: int in range(16):
		var phase := elapsed * 1.8 + index * 0.7
		var alpha := 0.12 + (sin(phase) + 1.0) * 0.12
		var point := Vector2(44 + index * 58, 82 + sin(phase * 0.55) * 3.0)
		draw_circle(point, 2.0 if index % 4 else 3.0, Color(accent, alpha))
