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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	var texture := TEXTURES[symbol_index]
	var source_size := texture.get_size()
	var scale_factor: float = minf(size.x / source_size.x, size.y / source_size.y)
	var draw_size := source_size * scale_factor
	draw_texture_rect(texture, Rect2((size - draw_size) * 0.5, draw_size), false)
