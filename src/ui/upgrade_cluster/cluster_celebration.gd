class_name ClusterCelebration
extends Control
## Phase 5: the big-win moment, after every cascade has finished.
##
## The stage darkens behind a vignette, the masquerade crest scales in, the tier
## word appears on its blank ribbon and the payout counts up beside it. The tier
## morphs as the counter passes 50x and 100x, so the word the player ends on is
## the one the win earned. It holds, then fades and gives the screen back.
##
## It is a modal, bounded moment: it is the one thing allowed to cover the board
## and the readouts, and only because it always ends.

## The crest keeps its own 1710x1947 proportions exactly, so the ribbon rectangle
## measured on the art lands on the painted ribbon at any output size.
const CREST_RECT := Rect2(350, 54, 260, 296)
const COUNTER_RECT := Rect2(300, 354, 360, 58)

var tier: String = ""
var shown_payout: int = 0
var _target_payout: int = 0
var _stake: int = 1
var _vignette: float = 0.0
var _crest: TextureRect
var _banner: Banner
var _running: bool = false


func _init() -> void:
	name = "ClusterCelebration"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(960, 540)
	visible = false
	z_index = 60
	_crest = ClusterTheme.plate(
		ClusterTheme.CREST, CREST_RECT, "Crest", TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	_crest.pivot_offset = CREST_RECT.size * 0.5
	add_child(_crest)
	# The tier word belongs on the crest's painted ribbon, and a Control draws
	# itself under its children, so the lettering gets its own layer on top.
	_banner = Banner.new()
	_banner.moment = self
	_banner.size = size
	add_child(_banner)


## True when `payout` on `stake` earns any tier at all.
static func earns_celebration(payout: int, stake: int) -> bool:
	return not ClusterTheme.celebration_tier(float(payout) / maxf(stake, 1.0)).is_empty()


func is_running() -> bool:
	return _running


## True while the moment is on screen and has something to draw.
func is_open() -> bool:
	return _vignette > 0.0


func has_active_motion() -> bool:
	return _running


## Runs the whole celebration and returns when the screen is clear again.
func play(payout: int, stake: int) -> void:
	_stake = maxi(stake, 1)
	_target_payout = payout
	tier = ClusterTheme.celebration_tier(float(payout) / float(_stake))
	if tier.is_empty():
		return
	_running = true
	visible = true
	shown_payout = 0
	AudioService.play(&"win")
	if MotionPolicy.is_reduced():
		# No rise, no count-up, no vignette swell: the final state, held for one
		# short bounded beat, then gone.
		_vignette = 0.78
		shown_payout = _target_payout
		_crest.scale = Vector2.ONE
		_crest.modulate.a = 1.0
		modulate.a = 1.0
		_redraw()
		var still := create_tween()
		still.tween_interval(ClusterTheme.phase(ClusterTheme.CELEBRATION_HOLD_SECONDS))
		await still.finished
		_finish()
		return
	_vignette = 0.0
	modulate.a = 1.0
	_crest.scale = Vector2(0.55, 0.55)
	_crest.modulate.a = 0.0
	var rise := create_tween().set_parallel(true)
	rise.tween_method(_set_vignette, 0.0, 0.78, ClusterTheme.CELEBRATION_RISE_SECONDS)
	(
		rise
		. tween_property(_crest, "scale", Vector2.ONE, ClusterTheme.CELEBRATION_RISE_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	rise.tween_property(_crest, "modulate:a", 1.0, ClusterTheme.CELEBRATION_RISE_SECONDS * 0.6)
	await rise.finished
	var count := create_tween()
	(
		count
		. tween_method(_set_payout, 0, _target_payout, ClusterTheme.CELEBRATION_COUNT_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	await count.finished
	_set_payout(_target_payout)
	var hold := create_tween()
	hold.tween_interval(ClusterTheme.CELEBRATION_HOLD_SECONDS)
	await hold.finished
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, ClusterTheme.CELEBRATION_FADE_SECONDS)
	await fade.finished
	_finish()


## Ends the moment at once and gives the screen back, whatever phase it is in.
func settle() -> void:
	if _running:
		shown_payout = _target_payout
		_finish()


func _finish() -> void:
	_running = false
	visible = false
	modulate.a = 1.0
	_vignette = 0.0
	_crest.scale = Vector2.ONE
	_crest.modulate.a = 1.0
	_redraw()


func _set_vignette(value: float) -> void:
	_vignette = value
	_redraw()


## The tier morphs as the counter climbs, so the word tracks the number beside it.
func _set_payout(value: int) -> void:
	shown_payout = value
	tier = ClusterTheme.celebration_tier(float(value) / float(_stake))
	if tier.is_empty():
		tier = "big"
	_redraw()


func tier_text() -> String:
	return TranslationServer.translate(ClusterTheme.tier_key(tier))


func _redraw() -> void:
	queue_redraw()
	if _banner != null:
		_banner.queue_redraw()


func _draw() -> void:
	if _vignette <= 0.0:
		return
	# A flat darkening plus a soft edge fall-off. Four bands, no shader, no bloom.
	draw_rect(Rect2(Vector2.ZERO, size), Color(ClusterTheme.VOID, _vignette * 0.80))
	for step: int in range(4):
		var inset := 26.0 * float(step)
		draw_rect(
			Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0),
			Color(ClusterTheme.VOID, _vignette * 0.10),
			false,
			26.0
		)


## The tier word on the crest's ribbon and the payout counter under it, drawn
## above the crest art.
class Banner:
	extends Control

	var moment: ClusterCelebration

	func _init() -> void:
		name = "Banner"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if moment == null or not moment.is_open():
			return
		var display := Typography.DISPLAY_FONT
		var word := moment.tier_text()
		var crest := ClusterCelebration.CREST_RECT
		var ribbon := Rect2(
			crest.position + ClusterTheme.CREST_RIBBON.position * crest.size,
			ClusterTheme.CREST_RIBBON.size * crest.size
		)
		var word_size := 30
		while (
			word_size > 11
			and (
				display.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
				> ribbon.size.x
			)
		):
			word_size -= 1
		draw_string(
			display,
			Vector2(
				ribbon.position.x,
				(
					ribbon.get_center().y
					+ (display.get_ascent(word_size) - display.get_descent(word_size)) * 0.5
				)
			),
			word,
			HORIZONTAL_ALIGNMENT_CENTER,
			ribbon.size.x,
			word_size,
			Color("7a4a17")
		)
		var counter := ClusterCelebration.COUNTER_RECT
		draw_style_box(
			ClusterTheme.box(Color(ClusterTheme.VOID, 0.86), ClusterTheme.EDGE_BRIGHT, 2, 8),
			counter
		)
		draw_string(
			display,
			Vector2(
				counter.position.x,
				counter.get_center().y + (display.get_ascent(42) - display.get_descent(42)) * 0.5
			),
			str(moment.shown_payout),
			HORIZONTAL_ALIGNMENT_CENTER,
			counter.size.x,
			42,
			ClusterTheme.WIN
		)
