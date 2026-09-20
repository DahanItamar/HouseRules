extends RefCounted
## Brass-and-black lift doors that slide shut from both sides of the screen.
##
## Each leaf carries half of an art-deco sunburst, so the closed doors show one
## fan at the seam. A lintel above them holds a floor dial whose needle ticks
## between stops (left to right going up, right to left going down) and a pair
## of arrow lamps. Everything is flat, code-drawn colour: no glow or gradient.

const LEAF := Color("141013")
const LEAF_PANEL := Color("1b1418")
const BRASS := Color("c8a34b")
const BRASS_DARK := Color("8a682f")
const LAMP_OFF := Color("3a2e22")
const LINTEL := Color("0f0b0e")
const LINTEL_HEIGHT: float = 58.0
const STOPS: int = 4
const DIAL_RADIUS: float = 19.0
const DIAL_SWEEP_START: float = PI + 0.3
const DIAL_SWEEP_END: float = TAU - 0.3
const FAN_RAYS: int = 6
const FAN_RADIUS: float = 96.0


## `closed` runs from 0 (open) to 1 (shut). `indicator` runs 0..1 across the ride.
static func paint(
	canvas: CanvasItem, size: Vector2, closed: float, indicator: float, ascending: bool
) -> void:
	var half := size.x * 0.5
	var travel := half * (1.0 - clampf(closed, 0.0, 1.0))
	_leaf(canvas, Rect2(-travel, 0.0, half, size.y), true)
	_leaf(canvas, Rect2(half + travel, 0.0, half, size.y), false)
	var lintel_alpha := clampf((closed - 0.2) / 0.55, 0.0, 1.0)
	if lintel_alpha > 0.0:
		_lintel(canvas, size, lintel_alpha, indicator, ascending)


## The needle's stop for a ride progress; the lamps tick between whole floors.
static func needle_stop(indicator: float, ascending: bool) -> int:
	var stop := clampi(floori(clampf(indicator, 0.0, 1.0) * STOPS + 0.0001), 0, STOPS)
	return stop if ascending else STOPS - stop


static func _leaf(canvas: CanvasItem, rect: Rect2, is_left: bool) -> void:
	if rect.size.x <= 0.0:
		return
	canvas.draw_rect(rect, LEAF)
	var meeting_x := rect.end.x if is_left else rect.position.x
	var inward := -1.0 if is_left else 1.0
	var hub := Vector2(meeting_x, rect.size.y * 0.6)
	# An upper and a lower panel frame the sunburst; a brass rail runs between.
	var left := rect.position.x + (26.0 if is_left else 40.0)
	var right := rect.end.x - (40.0 if is_left else 26.0)
	var upper_top := LINTEL_HEIGHT + 22.0
	var upper_bottom := hub.y - FAN_RADIUS - 16.0
	var lower_top := hub.y + 18.0
	var lower_bottom := rect.end.y - 62.0
	for panel: Rect2 in [
		Rect2(left, upper_top, right - left, upper_bottom - upper_top),
		Rect2(left, lower_top, right - left, lower_bottom - lower_top),
	]:
		canvas.draw_rect(panel, LEAF_PANEL)
		canvas.draw_rect(panel, BRASS_DARK, false, 1.5)
	canvas.draw_rect(Rect2(rect.position.x, hub.y + 6.0, rect.size.x, 2.0), BRASS_DARK)
	# Reeded brass strips beside the meeting edge.
	for strip: int in range(3):
		var x := meeting_x + inward * (11.0 + strip * 5.0)
		canvas.draw_line(
			Vector2(x, LINTEL_HEIGHT + 8.0), Vector2(x, rect.end.y - 44.0), BRASS_DARK, 1.0
		)
	# Half a sunburst; the other leaf completes it when the doors meet.
	var start_angle := PI if is_left else PI * 1.5
	for ray: int in range(FAN_RAYS + 1):
		var angle := start_angle + (PI * 0.5) * float(ray) / FAN_RAYS
		var tip := hub + Vector2.from_angle(angle) * FAN_RADIUS
		canvas.draw_line(hub + Vector2.from_angle(angle) * 14.0, tip, BRASS_DARK, 1.5, true)
	canvas.draw_arc(hub, FAN_RADIUS, start_angle, start_angle + PI * 0.5, 24, BRASS, 2.0, true)
	canvas.draw_arc(hub, 14.0, start_angle, start_angle + PI * 0.5, 12, BRASS, 2.0, true)
	# Kick plate and the brass meeting stile.
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 34.0, rect.size.x, 2.0), BRASS_DARK)
	canvas.draw_rect(Rect2(meeting_x - (3.0 if is_left else 0.0), 0.0, 3.0, rect.size.y), BRASS)


static func _lintel(
	canvas: CanvasItem, size: Vector2, alpha: float, indicator: float, ascending: bool
) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, size.x, LINTEL_HEIGHT), Color(LINTEL, alpha))
	canvas.draw_rect(Rect2(0.0, LINTEL_HEIGHT - 2.0, size.x, 2.0), Color(BRASS, alpha))
	var hub := Vector2(size.x * 0.5, LINTEL_HEIGHT - 16.0)
	var brass := Color(BRASS, alpha)
	var brass_dark := Color(BRASS_DARK, alpha)
	canvas.draw_arc(
		hub, DIAL_RADIUS + 4.0, DIAL_SWEEP_START - 0.12, DIAL_SWEEP_END + 0.12, 28, brass, 1.5, true
	)
	var stop := needle_stop(indicator, ascending)
	for index: int in range(STOPS + 1):
		var angle := lerpf(DIAL_SWEEP_START, DIAL_SWEEP_END, float(index) / STOPS)
		var direction := Vector2.from_angle(angle)
		var reached := index <= stop if ascending else index >= stop
		canvas.draw_line(
			hub + direction * (DIAL_RADIUS - 5.0),
			hub + direction * DIAL_RADIUS,
			brass if reached else brass_dark,
			2.0,
			true
		)
	var needle_angle := lerpf(DIAL_SWEEP_START, DIAL_SWEEP_END, float(stop) / STOPS)
	canvas.draw_line(
		hub, hub + Vector2.from_angle(needle_angle) * (DIAL_RADIUS - 2.0), brass, 2.0, true
	)
	canvas.draw_circle(hub, 3.0, brass)
	canvas.draw_line(hub + Vector2(-30.0, 4.0), hub + Vector2(30.0, 4.0), brass_dark, 1.5)
	for side: float in [-1.0, 1.0]:
		var lamp := hub + Vector2(side * 52.0, -6.0)
		_arrow(
			canvas, lamp + Vector2(0.0, -6.0), true, Color(BRASS if ascending else LAMP_OFF, alpha)
		)
		_arrow(
			canvas, lamp + Vector2(0.0, 7.0), false, Color(LAMP_OFF if ascending else BRASS, alpha)
		)


static func _arrow(canvas: CanvasItem, center: Vector2, up: bool, color: Color) -> void:
	var tip := -5.0 if up else 5.0
	(
		canvas
		. draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(0.0, tip),
					center + Vector2(6.0, -tip * 0.7),
					center + Vector2(-6.0, -tip * 0.7),
				]
			),
			color
		)
	)
