extends RefCounted
## A flight of walnut-black stairs with a burgundy runner and brass stair rods
## wipes vertically across the screen.
##
## Climbing, the flight enters from the top and leaves through the bottom, the
## same way the world slides when the view rises; descending reverses it. The
## `progress` value runs 0..1 while covering and 1..2 while revealing, so the
## flight keeps moving in one direction through the room switch.

const STONE := Color("110c0d")
const TREAD := Color("2a1d19")
const RUNNER := Color("4b1019")
const RUNNER_SHADOW := Color("380b13")
const BRASS := Color("c8a34b")
const BRASS_DARK := Color("8a682f")
const TREAD_SPACING: float = 38.0
const RUNNER_WIDTH: float = 0.3


static func paint(canvas: CanvasItem, size: Vector2, progress: float, ascending: bool) -> void:
	var top := panel_top(size, progress, ascending)
	var rect := Rect2(0.0, top, size.x, size.y)
	if rect.end.y <= 0.0 or rect.position.y >= size.y:
		return
	canvas.draw_rect(rect, STONE)
	var runner := Rect2(size.x * (0.5 - RUNNER_WIDTH * 0.5), top, size.x * RUNNER_WIDTH, size.y)
	canvas.draw_rect(runner, RUNNER)
	var steps := int(size.y / TREAD_SPACING)
	for index: int in range(steps):
		var y := top + 20.0 + index * TREAD_SPACING
		# Each tread: a nosing line across the flight, the riser shadow on the
		# runner, and a brass rod holding the runner into the step.
		canvas.draw_line(Vector2(0.0, y), Vector2(size.x, y), TREAD, 2.0)
		canvas.draw_rect(Rect2(runner.position.x, y + 2.0, runner.size.x, 7.0), RUNNER_SHADOW)
		var rod_y := y + 10.0
		canvas.draw_line(
			Vector2(runner.position.x - 8.0, rod_y), Vector2(runner.end.x + 8.0, rod_y), BRASS, 2.0
		)
		canvas.draw_circle(Vector2(runner.position.x - 8.0, rod_y), 2.5, BRASS)
		canvas.draw_circle(Vector2(runner.end.x + 8.0, rod_y), 2.5, BRASS)
	canvas.draw_line(
		Vector2(runner.position.x, top), Vector2(runner.position.x, rect.end.y), BRASS_DARK, 1.5
	)
	canvas.draw_line(Vector2(runner.end.x, top), Vector2(runner.end.x, rect.end.y), BRASS_DARK, 1.5)
	# Brass nosings mark both edges of the flight.
	canvas.draw_rect(Rect2(0.0, top, size.x, 3.0), BRASS)
	canvas.draw_rect(Rect2(0.0, rect.end.y - 3.0, size.x, 3.0), BRASS)


## The flight's top edge: above the screen at 0, covering at 1, below at 2
## (mirrored when descending).
static func panel_top(size: Vector2, progress: float, ascending: bool) -> float:
	var travel := size.y * (progress - 1.0)
	return travel if ascending else -travel
