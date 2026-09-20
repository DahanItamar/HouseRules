class_name HarlequinHost
extends Control
## The Harlequin Masquerade's stage company: the hostess standing at the right of
## the board and the two jester sidekicks at the foot of the frame.
##
## Presentation only. The panel tells it which beat the round has reached; it
## never reads game state, changes a result or affects settlement timing. Every
## beat is a cross-fade between head-registered masters plus one bounded local
## motion, so nobody bobs.

enum Beat { IDLE, MASK, PRESENT, CHEER, POUT }

const BEAT_TEXTURES: Dictionary = {
	Beat.IDLE: ClusterTheme.HOST_IDLE,
	Beat.MASK: ClusterTheme.HOST_MASK,
	Beat.PRESENT: ClusterTheme.HOST_PRESENT,
	Beat.CHEER: ClusterTheme.HOST_CHEER,
	Beat.POUT: ClusterTheme.HOST_POUT,
}
const CROSSFADE_SECONDS: float = 0.22
## How far a sidekick hops or leans. Small, local, and never a whole-body bob.
const SIDEKICK_HOP: float = 7.0

var beat: Beat = Beat.IDLE
var _host: TextureRect
var _host_fade: TextureRect
var _left: TextureRect
var _right: TextureRect
var _host_tween: Tween
var _sidekick_tween: Tween


func _init() -> void:
	name = "HarlequinHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(960, 540)


func build() -> void:
	# The outgoing pose sits under the incoming one so a beat change dissolves
	# rather than cutting.
	_host_fade = _figure("HostessOutgoing", ClusterTheme.HOST_IDLE, ClusterTheme.HOSTESS_RECT)
	_host_fade.modulate.a = 0.0
	_host = _figure("Hostess", ClusterTheme.HOST_IDLE, ClusterTheme.HOSTESS_RECT)
	_left = _figure("SidekickPink", ClusterTheme.SIDEKICK_PINK, ClusterTheme.SIDEKICK_LEFT_RECT)
	_right = _figure("SidekickGreen", ClusterTheme.SIDEKICK_GREEN, ClusterTheme.SIDEKICK_RIGHT_RECT)
	# The sidekicks lean on the *front* of the painted frame, so they sit above
	# the board root while the hostess stays behind it on the stage. Their
	# rectangles are clear of the grid, so neither can ever cover a cell.
	for sidekick: Control in [_left, _right]:
		sidekick.z_index = 4


func _figure(node_name: String, texture: Texture2D, rect: Rect2) -> TextureRect:
	var figure := ClusterTheme.plate(
		texture, rect, node_name, TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	figure.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y)
	add_child(figure)
	return figure


func hostess() -> TextureRect:
	return _host


func sidekicks() -> Array[TextureRect]:
	return [_left, _right]


## Every rectangle the company occupies, in panel space.
func occupied_rects() -> Array[Rect2]:
	return [
		ClusterTheme.HOSTESS_RECT,
		ClusterTheme.SIDEKICK_LEFT_RECT,
		ClusterTheme.SIDEKICK_RIGHT_RECT,
	]


## Moves the company to `next`. The pose swap is a cross-fade; the sidekicks add
## one short local reaction.
func set_beat(next: Beat) -> void:
	if next == beat or _host == null:
		return
	beat = next
	var texture: Texture2D = BEAT_TEXTURES[next]
	if _host_tween != null and _host_tween.is_valid():
		_host_tween.kill()
	if MotionPolicy.is_reduced() or not is_inside_tree():
		_host.texture = texture
		_host.modulate.a = 1.0
		_host_fade.modulate.a = 0.0
		_react()
		return
	_host_fade.texture = _host.texture
	_host_fade.modulate.a = 1.0
	_host.texture = texture
	_host.modulate.a = 0.0
	_host_tween = create_tween().set_parallel(true)
	_host_tween.tween_property(_host, "modulate:a", 1.0, CROSSFADE_SECONDS)
	_host_tween.tween_property(_host_fade, "modulate:a", 0.0, CROSSFADE_SECONDS)
	_react()


## The sidekicks answer the beat: a hop for a win, a slump for a dead spin.
func _react() -> void:
	if _sidekick_tween != null and _sidekick_tween.is_valid():
		_sidekick_tween.kill()
	var rests := [
		ClusterTheme.SIDEKICK_LEFT_RECT.position, ClusterTheme.SIDEKICK_RIGHT_RECT.position
	]
	var figures := [_left, _right]
	var lift := 0.0
	match beat:
		Beat.PRESENT:
			lift = -SIDEKICK_HOP
		Beat.CHEER:
			lift = -SIDEKICK_HOP * 1.6
		Beat.POUT:
			lift = SIDEKICK_HOP * 0.4
	if MotionPolicy.is_reduced() or not is_inside_tree():
		for index: int in range(figures.size()):
			(figures[index] as Control).position = (rests[index] as Vector2) + Vector2(0, lift)
		return
	_sidekick_tween = create_tween().set_parallel(true)
	for index: int in range(figures.size()):
		var figure: Control = figures[index]
		var rest: Vector2 = rests[index]
		(
			_sidekick_tween
			. tween_property(figure, "position", rest + Vector2(0, lift), 0.18)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
			. set_delay(0.04 * float(index))
		)
		_sidekick_tween.chain().tween_property(figure, "position", rest, 0.26).set_trans(
			Tween.TRANS_QUAD
		)


## Ends every beat motion at once, leaving the company in its final pose.
func settle() -> void:
	if _host_tween != null and _host_tween.is_valid():
		_host_tween.kill()
	_host_tween = null
	if _sidekick_tween != null and _sidekick_tween.is_valid():
		_sidekick_tween.kill()
	_sidekick_tween = null
	if _host == null:
		return
	_host.modulate.a = 1.0
	_host_fade.modulate.a = 0.0
	_left.position = ClusterTheme.SIDEKICK_LEFT_RECT.position
	_right.position = ClusterTheme.SIDEKICK_RIGHT_RECT.position


func has_active_motion() -> bool:
	return (
		(_host_tween != null and _host_tween.is_valid())
		or (_sidekick_tween != null and _sidekick_tween.is_valid())
	)
