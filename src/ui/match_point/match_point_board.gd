class_name MatchPointBoard
extends Node2D
## The Match Point peg field: 12 rows of brass court-stud posts on the painted
## grass-green panel, a brass serve hatch at the top and 13 cream-enamel courts
## with the current risk table's multipliers. Board coordinates are screen
## coordinates on the 960x540 canvas.
##
## The court and the left/right path are decided by MatchPointMath before
## drop() is called. The ball hops post to post along exactly that path, so it
## always ends in the decided court; nothing here simulates physics or picks an
## outcome. Reduced motion puts the ball straight into the court and marks the
## path with one bounded ring cue.

signal ball_landed(court: int)
signal peg_hit(row: int)

const BALL_TEXTURE := preload("res://assets/production/match_point/match_point_ball.png")
const PEG_TEXTURE := preload("res://assets/production/match_point/match_point_peg.png")
const CENTER_X: float = 480.0
const PITCH: float = 28.0
const ROW_PITCH: float = 26.0
const FIRST_ROW_Y: float = 96.0
const ROWS: int = 12
const COURTS: int = 13
const PEG_SIZE := Vector2(14, 14)
## Radius of the cream stud cap the ball touches.
const PEG_RADIUS: float = 4.0
const BALL_RADIUS: float = 7.0
const COURT_TOP: float = 398.0
const COURT_HEIGHT: float = 34.0
const COURT_MOUTH: float = 8.0
const HATCH_RECT := Rect2(456, 34, 48, 26)
const SERVE_SECONDS: float = 0.55
const SERVE_TOSS: float = 18.0
const FIRST_HOP_SECONDS: float = 0.16
const LAST_HOP_SECONDS: float = 0.115
const HOP_HEIGHT: float = 7.0
const DROP_SECONDS: float = 0.2
const SETTLE_SECONDS: float = 0.36
const REDUCED_CUE_SECONDS: float = 0.45

var math: MatchPointMath
var risk: MatchPointMath.Risk = MatchPointMath.Risk.MEDIUM
## Court the current ball is heading for or resting in (-1 = none yet).
var target_court: int = -1
var landed_court: int = -1
var dropping: bool = false
var ball_position: Vector2
## Rows whose post the ball has touched on the current drop (for the trail).
var hit_rows: int = 0
var _path: Array[int] = []
var _waypoints: Array[Vector2] = []
var _durations: Array[float] = []
var _hops: Array[float] = []
var _segment: int = 0
var _segment_time: float = 0.0
var _settle_time: float = -1.0
var _cue_left: float = 0.0


func setup(board_math: MatchPointMath) -> void:
	name = "MatchPointBoard"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	math = board_math
	ball_position = hatch_rest()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	set_process(false)


static func peg_position(row: int, index: int) -> Vector2:
	return Vector2(
		CENTER_X + (float(index) - float(row + 2) * 0.5) * PITCH, FIRST_ROW_Y + row * ROW_PITCH
	)


static func pegs_in_row(row: int) -> int:
	return row + 3


static func court_center_x(court: int) -> float:
	return CENTER_X + (float(court) - float(COURTS - 1) * 0.5) * PITCH


static func court_rect(court: int) -> Rect2:
	return Rect2(court_center_x(court) - PITCH * 0.5 + 1.0, COURT_TOP, PITCH - 2.0, COURT_HEIGHT)


## Where a landed ball rests: in the court mouth, above the multiplier.
static func court_rest(court: int) -> Vector2:
	return Vector2(court_center_x(court), COURT_TOP - 1.0)


static func hatch_rest() -> Vector2:
	return Vector2(CENTER_X, HATCH_RECT.position.y + HATCH_RECT.size.y * 0.5)


## Everything the host and HUD must keep clear of: posts, courts and hatch.
static func field_rect() -> Rect2:
	var left := peg_position(ROWS - 1, 0).x - PEG_SIZE.x
	var right := peg_position(ROWS - 1, pegs_in_row(ROWS - 1) - 1).x + PEG_SIZE.x
	return Rect2(
		left, HATCH_RECT.position.y, right - left, COURT_TOP + COURT_HEIGHT - HATCH_RECT.position.y
	)


## Ball centre resting on top of the post it strikes on `row` after `rights`
## right hops, nudged toward the side it will fall to.
static func contact_point(row: int, rights: int, next_hop: int) -> Vector2:
	var side := 1.0 if next_hop == 1 else -1.0
	return peg_position(row, rights + 1) + Vector2(side * 2.0, -(PEG_RADIUS + BALL_RADIUS))


## The whole travel for a path: the hatch, one contact per row, the court.
static func waypoints_for(path: Array[int]) -> Array[Vector2]:
	var points: Array[Vector2] = [hatch_rest()]
	var rights: int = 0
	for row: int in range(path.size()):
		points.append(contact_point(row, rights, path[row]))
		rights += path[row]
	points.append(court_rest(rights))
	return points


func set_risk(next_risk: MatchPointMath.Risk) -> void:
	risk = next_risk
	queue_redraw()


## Starts the ball down `path`, which must end in `court`. Reduced motion puts
## it in the court at once with one bounded ring cue instead of the travel.
func drop(path: Array[int], court: int) -> void:
	_path = path.duplicate()
	target_court = court
	landed_court = -1
	hit_rows = 0
	_waypoints = waypoints_for(_path)
	_durations.clear()
	_hops.clear()
	_durations.append(SERVE_SECONDS)
	_hops.append(SERVE_TOSS)
	for row: int in range(1, _path.size()):
		var t := float(row - 1) / float(maxi(_path.size() - 2, 1))
		_durations.append(lerpf(FIRST_HOP_SECONDS, LAST_HOP_SECONDS, t))
		_hops.append(HOP_HEIGHT * lerpf(1.0, 0.8, t))
	_durations.append(DROP_SECONDS)
	_hops.append(HOP_HEIGHT * 0.6)
	_segment = 0
	_segment_time = 0.0
	_settle_time = -1.0
	if MotionPolicy.is_reduced():
		_land()
		_cue_left = REDUCED_CUE_SECONDS
		set_process(true)
		return
	dropping = true
	ball_position = _waypoints[0]
	set_process(true)
	queue_redraw()


## Snaps any travel to its final state (reduced-motion switch or teardown).
func settle() -> void:
	if dropping:
		_land()
	_settle_time = -1.0
	_cue_left = 0.0
	queue_redraw()


func is_animating() -> bool:
	return dropping or _settle_time >= 0.0 or _cue_left > 0.0


## A new round: the ball goes back to the hatch and the trail clears.
func reset_for_serve() -> void:
	if dropping:
		return
	landed_court = -1
	target_court = -1
	hit_rows = 0
	_path.clear()
	ball_position = hatch_rest()
	queue_redraw()


func _on_motion_preference_changed(_reduced: bool) -> void:
	settle()


func _process(delta: float) -> void:
	if _cue_left > 0.0:
		_cue_left = maxf(0.0, _cue_left - delta)
		queue_redraw()
	if dropping:
		_advance(delta)
	elif _settle_time >= 0.0:
		_settle_time += delta
		var progress := clampf(_settle_time / SETTLE_SECONDS, 0.0, 1.0)
		# Two small decaying bounces in the court mouth.
		var bounce := absf(sin(progress * PI * 2.0)) * (1.0 - progress) * 5.0
		ball_position = court_rest(landed_court) - Vector2(0, bounce)
		if progress >= 1.0:
			_settle_time = -1.0
			ball_position = court_rest(landed_court)
		queue_redraw()
	if not dropping and _settle_time < 0.0 and _cue_left <= 0.0:
		set_process(false)


func _advance(delta: float) -> void:
	_segment_time += delta
	while dropping and _segment_time >= _durations[_segment]:
		_segment_time -= _durations[_segment]
		_segment += 1
		if _segment <= _path.size():
			hit_rows = _segment
			peg_hit.emit(_segment - 1)
		if _segment >= _durations.size():
			_land()
			if not MotionPolicy.is_reduced():
				_settle_time = 0.0
			return
	var from := _waypoints[_segment]
	var to := _waypoints[_segment + 1]
	var u := clampf(_segment_time / _durations[_segment], 0.0, 1.0)
	if _segment == 0:
		# Serve: tossed up out of the hatch, then falling onto the first post.
		var rise := sin(u * PI) * _hops[0]
		ball_position = Vector2(lerpf(from.x, to.x, u), lerpf(from.y, to.y, u * u) - rise)
	else:
		# A short hop off the post: up a little, then down onto the next one.
		var arc := 4.0 * u * (1.0 - u) * _hops[_segment]
		ball_position = Vector2(lerpf(from.x, to.x, u), lerpf(from.y, to.y, u * u) - arc)
	queue_redraw()


func _land() -> void:
	dropping = false
	hit_rows = _path.size()
	landed_court = target_court
	ball_position = court_rest(landed_court)
	queue_redraw()
	ball_landed.emit(landed_court)


func _draw() -> void:
	_draw_hatch()
	_draw_pegs()
	_draw_courts()
	_draw_ball()


func _draw_hatch() -> void:
	draw_texture_rect(MatchPointStyle.HATCH, HATCH_RECT, false)
	# Once the served ball rests in its court, the next ball waits in the hatch.
	if not dropping and landed_court >= 0:
		_draw_ball_at(hatch_rest(), 1.0)


func _draw_pegs() -> void:
	var lit := _lit_pegs()
	for row: int in range(ROWS):
		for index: int in range(pegs_in_row(row)):
			var at := peg_position(row, index)
			var rect := Rect2(at - Vector2(PEG_SIZE.x * 0.5, PEG_RADIUS + 1.0), PEG_SIZE)
			draw_texture_rect(PEG_TEXTURE, rect, false)
			if lit.has(Vector2i(row, index)):
				# The ball's trail: studs it touched turn bright cream with a brass ring.
				draw_circle(at, PEG_RADIUS + 1.5, MatchPointStyle.BRASS_BRIGHT)
				draw_circle(at, PEG_RADIUS, MatchPointStyle.CREAM)


func _lit_pegs() -> Dictionary:
	var lit: Dictionary = {}
	var rights: int = 0
	for row: int in range(mini(hit_rows, _path.size())):
		lit[Vector2i(row, rights + 1)] = true
		rights += _path[row]
	return lit


func _draw_courts() -> void:
	var table := math.tenths_for(risk) if math != null else PackedInt32Array()
	var baseline := Rect2(court_rect(0).position.x - 3.0, COURT_TOP - 3.0, 0, 3)
	baseline.size.x = court_rect(COURTS - 1).end.x - baseline.position.x + 3.0
	draw_rect(baseline, MatchPointStyle.BRASS)
	for court: int in range(COURTS):
		var rect := court_rect(court)
		var tenths: int = table[court] if court < table.size() else 0
		# The court that took the ball keeps its own light; the rest fall back,
		# so the eye lands on the one that paid without anything being hidden.
		var tint := Color.WHITE
		if landed_court >= 0 and court != landed_court:
			tint = Color(0.52, 0.52, 0.52)
		draw_texture_rect(MatchPointStyle.court_plate(tenths), rect, false, tint)
		var ink := MatchPointStyle.court_ink(tenths)
		if landed_court >= 0 and court != landed_court:
			ink = Color(ink, 0.55)
		MatchPointStyle.draw_centered(
			self,
			MatchPointMath.multiplier_text(tenths),
			rect.get_center() + Vector2(0, COURT_MOUTH * 0.5),
			16,
			ink
		)
		# The plate paints its own rim, so only the court that paid gets a second
		# one drawn over the top of it.
		if court == landed_court:
			draw_rect(rect.grow(1.0), MatchPointStyle.BRASS_BRIGHT, false, 3.0)
	if _cue_left > 0.0 and landed_court >= 0:
		var alpha := clampf(_cue_left / REDUCED_CUE_SECONDS, 0.0, 1.0)
		draw_arc(
			court_rest(landed_court),
			BALL_RADIUS + 5.0,
			0.0,
			TAU,
			28,
			Color(MatchPointStyle.BRASS_BRIGHT, alpha),
			2.0,
			true
		)


func _draw_ball() -> void:
	if not dropping and landed_court < 0:
		_draw_ball_at(hatch_rest(), 1.0)
		return
	_draw_ball_at(ball_position, 1.0)


func _draw_ball_at(at: Vector2, alpha: float) -> void:
	var side := BALL_RADIUS * 2.0 + 2.0
	# Flat contact shadow, offset down-right; no glow.
	draw_circle(at + Vector2(1.5, 2.0), BALL_RADIUS, Color(0, 0, 0, 0.35 * alpha))
	draw_texture_rect(
		BALL_TEXTURE,
		Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)),
		false,
		Color(1, 1, 1, alpha)
	)
