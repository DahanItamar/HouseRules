class_name BaccaratHandZone
extends Control
## One hand's box on the felt (Player or Banker): its name, a pearl total disc
## on the outer edge and a tag for naturals and the winner. The cards are
## separate BaccaratCard nodes laid inside this box by the table panel.

const DISC_RADIUS: float = 20.0
const DISC_INSET: float = 30.0
const DISC_Y: float = 50.0
const CUE_SECONDS: float = 0.45

var hand_key: String = ""
var tint: Color = BaccaratStyle.PLAYER_BLUE
## The disc sits on this side of the box: -1 left (Player), +1 right (Banker).
var disc_side: int = -1
## Shown total, or -1 while the cards are still face down.
var total: int = -1
var tag_text: String = ""
var won: bool = false
var lost: bool = false
var _cue: float = 0.0
var _cue_tween: Tween


func _init(
	key: String = "", rect: Rect2 = Rect2(), colour: Color = Color.WHITE, side: int = -1
) -> void:
	hand_key = key
	tint = colour
	disc_side = side
	name = "BaccaratHand_%s" % key
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func disc_center() -> Vector2:
	var x := DISC_INSET if disc_side < 0 else size.x - DISC_INSET
	return Vector2(x, DISC_Y)


func set_total(value: int) -> void:
	total = value
	queue_redraw()


func set_outcome(tag: String, is_winner: bool, is_loser: bool) -> void:
	tag_text = tag
	won = is_winner
	lost = is_loser
	queue_redraw()


func reset() -> void:
	total = -1
	tag_text = ""
	won = false
	lost = false
	_stop_cue()
	queue_redraw()


## One bounded brass ring around the box (reduced motion's single state cue).
func play_cue() -> void:
	_stop_cue()
	_cue = 1.0
	queue_redraw()
	if not is_inside_tree():
		return
	_cue_tween = create_tween()
	_cue_tween.tween_method(_set_cue, 1.0, 0.0, MotionPolicy.finite_duration(CUE_SECONDS))


func cue_active() -> bool:
	return _cue > 0.0


func _set_cue(value: float) -> void:
	_cue = value
	queue_redraw()


func _stop_cue() -> void:
	if _cue_tween != null and _cue_tween.is_valid():
		_cue_tween.kill()
	_cue_tween = null
	_cue = 0.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var face := StyleBoxFlat.new()
	face.bg_color = Color(tint, 0.10 if lost else 0.18)
	face.set_corner_radius_all(8)
	face.anti_aliasing = true
	draw_style_box(face, rect)
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.set_corner_radius_all(8)
	border.anti_aliasing = true
	border.border_color = BaccaratStyle.BRASS_BRIGHT if won else Color(BaccaratStyle.PEARL, 0.35)
	border.set_border_width_all(3 if won else 1)
	draw_style_box(border, rect.grow(-1.0))
	if _cue > 0.0:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(10)
		ring.anti_aliasing = true
		ring.border_color = Color(BaccaratStyle.BRASS_BRIGHT, _cue)
		ring.set_border_width_all(2)
		draw_style_box(ring, rect.grow(3.0))
	var center := disc_center()
	BaccaratStyle.draw_centered(
		self, tr(hand_key), Vector2(center.x, 14), 14, BaccaratStyle.PEARL, Typography.UI_FONT
	)
	draw_circle(
		center, DISC_RADIUS + 3.0, BaccaratStyle.BRASS if not won else BaccaratStyle.BRASS_BRIGHT
	)
	draw_circle(center, DISC_RADIUS, BaccaratStyle.LACQUER_DEEP)
	draw_arc(center, DISC_RADIUS - 3.0, 0.0, TAU, 40, tint, 2.0, true)
	var shown := str(total) if total >= 0 else tr("BACCARAT_TOTAL_HIDDEN")
	BaccaratStyle.draw_centered(self, shown, center, 24, BaccaratStyle.PEARL)
	if not tag_text.is_empty():
		BaccaratStyle.draw_centered(
			self,
			tag_text,
			Vector2(center.x, 83),
			12,
			BaccaratStyle.WIN_INK if won else BaccaratStyle.PEARL_MUTED,
			Typography.UI_FONT
		)
