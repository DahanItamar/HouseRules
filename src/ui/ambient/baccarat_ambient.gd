extends AmbientLayer
## Velvet Baccarat: the salon's candle sconces flicker with a quicker, softer
## candle rhythm, and the felt by the far rail catches the centre candle's light.
## Every zone, spot, card, plate and control draws above this layer.

const CANDLE := Color("ffb867")
const CANDLE_PERIOD: float = 1.9
const CANDLE_DEPTH: float = 0.3


func _ready() -> void:
	add_pool(Vector2(74, 48), 46.0, 1.0, CANDLE, 0.075, CANDLE_PERIOD * 1.13, 0.17, CANDLE_DEPTH)
	add_pool(Vector2(478, 54), 50.0, 1.0, CANDLE, 0.075, CANDLE_PERIOD, 0.52, CANDLE_DEPTH)
	add_pool(Vector2(885, 44), 46.0, 1.0, CANDLE, 0.075, CANDLE_PERIOD * 0.91, 0.86, CANDLE_DEPTH)
	# The rail-side felt follows the centre candle at a lower, wider breath.
	add_pool(Vector2(480, 238), 300.0, 0.16, CANDLE, 0.045, CANDLE_PERIOD, 0.52, 0.25)
	super._ready()


func _draw_light(canvas: Node2D) -> void:
	draw_pools(canvas)
