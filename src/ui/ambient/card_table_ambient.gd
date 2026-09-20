extends AmbientLayer
## Blackjack and Texas Hold'em: the room's lamps flicker very slightly and the
## felt carries the table lamp's soft light pool, breathing with it. Cards,
## chips, plates, the dealer and every control draw above this layer.

const SCONCE := Color("ffcf8c")
const FELT_LIGHT := Color("ffe6b4")


func _ready() -> void:
	if cabinet_id == &"poker":
		_dress_poker()
	else:
		_dress_blackjack()
	super._ready()


func _draw_light(canvas: Node2D) -> void:
	draw_pools(canvas)


func _dress_blackjack() -> void:
	# Wall sconces behind the dealer's rail.
	add_pool(Vector2(62, 22), 36.0, 1.0, SCONCE, 0.07, 4.4, 0.13)
	add_pool(Vector2(258, 36), 42.0, 1.0, SCONCE, 0.075, 5.3, 0.58)
	add_pool(Vector2(700, 40), 42.0, 1.0, SCONCE, 0.075, 3.9, 0.36)
	add_pool(Vector2(897, 22), 36.0, 1.0, SCONCE, 0.07, 6.1, 0.82)
	# The table lamp's pool across the felt, a low wide ellipse.
	add_pool(Vector2(480, 272), 330.0, 0.32, FELT_LIGHT, 0.05, 6.6, 0.27, 0.25)


func _dress_poker() -> void:
	# The pendant over the table and its pool on the felt breathe together.
	add_pool(Vector2(480, 10), 92.0, 0.3, FELT_LIGHT, 0.076, 5.2, 0.4)
	add_pool(Vector2(480, 300), 360.0, 0.28, FELT_LIGHT, 0.05, 5.2, 0.4, 0.25)
	add_pool(Vector2(187, 50), 34.0, 1.0, SCONCE, 0.07, 4.6, 0.71)
	add_pool(Vector2(772, 50), 34.0, 1.0, SCONCE, 0.07, 3.8, 0.09)
