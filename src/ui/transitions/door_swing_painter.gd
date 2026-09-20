extends RefCounted
## A walnut door swings across the screen on its hinge, then swings open again
## onto the next room.
##
## `progress` 0..1 swings the door shut toward the viewer (its free edge grows
## as it approaches); 1..2 swings it open away from the viewer (the free edge
## shrinks into the new room). The door is projected in code: raised panels,
## grain and a brass handle all follow the same perspective.

const WALNUT := Color("4a2b1a")
const WALNUT_PANEL := Color("573220")
const WALNUT_DARK := Color("26150c")
const GRAIN := Color("3b2215")
const GRAIN_LIGHT := Color("5a3622")
const GRAIN_LINES: int = 26
const FAN_RAYS: int = 8
const PANEL_COLUMNS: Array = [[0.07, 0.33], [0.37, 0.63], [0.67, 0.93]]
const PANEL_ROWS: Array = [[0.07, 0.44], [0.62, 0.9]]
const BRASS := Color("c8a34b")
const BRASS_DARK := Color("8a682f")
## How much taller the free edge looks at a right angle (perspective).
const PERSPECTIVE: float = 0.22
## Angled doors catch less of the room's light.
const ANGLE_SHADE: float = 0.38


static func paint(canvas: CanvasItem, size: Vector2, progress: float, hinge_left: bool) -> void:
	var closing := progress <= 1.0
	var swing := 1.0 - progress if closing else progress - 1.0
	var angle := clampf(swing, 0.0, 1.0) * PI * 0.5
	var width := size.x * cos(angle)
	if width < 1.0:
		return
	var bulge := sin(angle) * PERSPECTIVE * (1.0 if closing else -0.6)
	var shade := 1.0 - sin(angle) * ANGLE_SHADE
	var frame := {"size": size, "width": width, "bulge": bulge, "hinge_left": hinge_left}
	canvas.draw_colored_polygon(_quad(frame, 0.0, 0.0, 1.0, 1.0), _shaded(WALNUT, shade))
	# Straight vertical grain, a little uneven so the veneer never reads as stripes.
	for grain: int in range(GRAIN_LINES):
		var grain_u := (grain + 0.5 + sin(grain * 2.3) * 0.3) / GRAIN_LINES
		var tone := GRAIN if grain % 3 != 1 else GRAIN_LIGHT
		canvas.draw_line(
			project(frame, grain_u, 0.0), project(frame, grain_u, 1.0), _shaded(tone, shade), 1.0
		)
	# Six raised panels: three across, a tall row over a short one.
	for column: Array in PANEL_COLUMNS:
		for row: Array in PANEL_ROWS:
			_panel(canvas, frame, shade, column[0], row[0], column[1], row[1])
	# A brass lock rail between the rows carries a deco fan over the middle.
	var rail_color := _shaded(BRASS_DARK, shade)
	canvas.draw_line(project(frame, 0.05, 0.56), project(frame, 0.95, 0.56), rail_color, 2.0)
	_fan(canvas, frame, _shaded(BRASS, shade))
	canvas.draw_line(project(frame, 0.0, 0.96), project(frame, 1.0, 0.96), rail_color, 2.0)
	# The stile edges and a brass lever handle near the free edge.
	canvas.draw_line(project(frame, 0.0, 0.0), project(frame, 0.0, 1.0), WALNUT_DARK, 4.0)
	canvas.draw_line(project(frame, 1.0, 0.0), project(frame, 1.0, 1.0), WALNUT_DARK, 4.0)
	var rose := project(frame, 0.955, 0.51)
	canvas.draw_circle(rose, 6.0 * cos(angle) + 2.0, _shaded(BRASS, shade))
	canvas.draw_line(
		rose, project(frame, 0.905, 0.515), _shaded(BRASS, shade), 3.0 * cos(angle) + 1.5, true
	)


static func _panel(
	canvas: CanvasItem, frame: Dictionary, shade: float, u0: float, v0: float, u1: float, v1: float
) -> void:
	var panel := _quad(frame, u0, v0, u1, v1)
	canvas.draw_colored_polygon(panel, _shaded(WALNUT_PANEL, shade))
	var outline := panel.duplicate()
	outline.append(panel[0])
	canvas.draw_polyline(outline, _shaded(WALNUT_DARK, shade), 2.0, true)
	var inset := Vector2((u1 - u0) * 0.1, (v1 - v0) * 0.08)
	var inlay := _quad(frame, u0 + inset.x, v0 + inset.y, u1 - inset.x, v1 - inset.y)
	inlay.append(inlay[0])
	canvas.draw_polyline(inlay, _shaded(BRASS_DARK, shade), 1.0, true)


## A half sunburst rising from the lock rail, drawn in door space.
static func _fan(canvas: CanvasItem, frame: Dictionary, color: Color) -> void:
	var hub := Vector2(0.5, 0.56)
	var radius := Vector2(0.07, 0.1)
	var arc := PackedVector2Array()
	for step: int in range(FAN_RAYS + 1):
		var angle := PI * float(step) / FAN_RAYS
		var tip := hub + Vector2(-cos(angle) * radius.x, -sin(angle) * radius.y)
		var root := hub + Vector2(-cos(angle) * radius.x * 0.18, -sin(angle) * radius.y * 0.18)
		canvas.draw_line(project(frame, root.x, root.y), project(frame, tip.x, tip.y), color, 1.5)
	for step: int in range(25):
		var angle := PI * float(step) / 24.0
		var point := hub + Vector2(-cos(angle) * radius.x, -sin(angle) * radius.y)
		arc.append(project(frame, point.x, point.y))
	canvas.draw_polyline(arc, color, 2.0, true)


## Door-space (u across from the hinge, v down) to screen space.
static func project(frame: Dictionary, u: float, v: float) -> Vector2:
	var size: Vector2 = frame["size"]
	var width: float = frame["width"]
	var bulge: float = frame["bulge"]
	var x := u * width
	if not frame["hinge_left"]:
		x = size.x - x
	var top := -u * bulge * size.y * 0.5
	var bottom := size.y + u * bulge * size.y * 0.5
	return Vector2(x, lerpf(top, bottom, v))


static func _quad(
	frame: Dictionary, u0: float, v0: float, u1: float, v1: float
) -> PackedVector2Array:
	return PackedVector2Array(
		[
			project(frame, u0, v0),
			project(frame, u1, v0),
			project(frame, u1, v1),
			project(frame, u0, v1)
		]
	)


static func _shaded(color: Color, shade: float) -> Color:
	return Color(color.r * shade, color.g * shade, color.b * shade, color.a)
