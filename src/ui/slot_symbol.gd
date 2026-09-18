class_name SlotSymbol
extends Control
## High-resolution Higgsfield reel icon, keyed from exact magenta-mask masters.

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/production/slot/symbols/cherry.png"),
	preload("res://assets/production/slot/symbols/lemon.png"),
	preload("res://assets/production/slot/symbols/bell.png"),
	preload("res://assets/production/slot/symbols/bar.png"),
	preload("res://assets/production/slot/symbols/seven.png"),
	preload("res://assets/production/slot/symbols/diamond.png"),
]

var symbol_index: int = 0:
	set(value):
		symbol_index = posmod(value, TEXTURES.size())
		queue_redraw()
var spin_strength: float = 0.0
var _motion_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(true)


func _process(delta: float) -> void:
	_motion_time = fmod(_motion_time + delta, 120.0)
	queue_redraw()


func set_spin_strength(value: float) -> void:
	spin_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var texture := TEXTURES[symbol_index]
	var source_size := texture.get_size()
	var scale_factor: float = minf(size.x / source_size.x, size.y / source_size.y)
	var draw_size := source_size * scale_factor
	var phase := float(symbol_index) * 0.91 + position.x * 0.013 + position.y * 0.007
	var idle_offset := Vector2(0.0, sin(_motion_time * 1.7 + phase) * (1.25 - spin_strength))
	var draw_origin := (size - draw_size) * 0.5 + idle_offset
	if spin_strength > 0.001:
		for trail: float in [-18.0, -10.0, 10.0, 18.0]:
			var trail_alpha := spin_strength * (0.10 if absf(trail) < 12.0 else 0.055)
			draw_texture_rect(
				texture,
				Rect2(draw_origin + Vector2(0.0, trail * spin_strength), draw_size),
				false,
				Color(0.76, 0.91, 1.0, trail_alpha)
			)
	draw_texture_rect(texture, Rect2(draw_origin, draw_size), false)
	if spin_strength < 0.05:
		# A narrow re-drawn source slice creates sheen while respecting transparency.
		var sweep := fmod(_motion_time * 0.16 + phase * 0.11, 1.0)
		var strip_width := maxf(draw_size.x * 0.075, 1.0)
		var source_x := clampf(sweep * source_size.x, 0.0, source_size.x - 1.0)
		var source_width := minf(source_size.x * 0.075, source_size.x - source_x)
		var destination_x := draw_origin.x + sweep * draw_size.x
		draw_texture_rect_region(
			texture,
			Rect2(Vector2(destination_x, draw_origin.y), Vector2(strip_width, draw_size.y)),
			Rect2(Vector2(source_x, 0.0), Vector2(source_width, source_size.y)),
			Color(1.0, 0.94, 0.66, 0.16)
		)
