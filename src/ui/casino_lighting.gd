class_name CasinoLighting
extends Control
## Shared, low-contrast architectural light and edge shadow treatment.

enum Mode { MENU, SLOT, BLACKJACK, VAULT }

var mode: Mode = Mode.MENU
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	var warm := Color("d9b44a")
	var accent := warm
	if mode == Mode.BLACKJACK:
		accent = Color("4a9d7c")
	elif mode == Mode.VAULT:
		# Hexbound Vault: the crypt's candlelight, not a cold vault-blue beam.
		accent = Color("c98a3e")
	elif mode == Mode.SLOT:
		accent = Color("a92c3f")
	var drift := sin(elapsed * 0.22) * 34.0
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(145 + drift, 0),
				Vector2(225 + drift, 0),
				Vector2(430 + drift, size.y),
				Vector2(300 + drift, size.y),
			]
		),
		Color(warm, 0.025)
	)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(size.x - 205 - drift, 0),
				Vector2(size.x - 130 - drift, 0),
				Vector2(size.x - 275 - drift, size.y),
				Vector2(size.x - 420 - drift, size.y),
			]
		),
		Color(accent, 0.022)
	)
	# Flat nested edge shadows provide depth without a decorative glow. There is
	# no full-width strip across the top: headers carry their own opaque plates.
	draw_rect(Rect2(0, size.y - 18, size.x, 18), Color("09070a66"))
	draw_rect(Rect2(0, 0, 14, size.y), Color("09070a47"))
	draw_rect(Rect2(size.x - 14, 0, 14, size.y), Color("09070a47"))
	draw_rect(Rect2(14, 12, size.x - 28, size.y - 30), Color("c8a34b30"), false, 1.0)
