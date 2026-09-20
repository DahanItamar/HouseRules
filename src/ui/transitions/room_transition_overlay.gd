extends Control
## Full-screen, code-drawn overlay for a passage between floor rooms.
##
## `progress` runs 0..1 while the overlay closes over the old room and 1..2 while
## it opens onto the new one. The kind picks the theme: lift doors, a stair
## wipe, a hinged office door, or a warm dip to black (also the short
## reduced-motion crossfade). While visible it swallows pointer input so nothing
## underneath can be clicked mid-passage.

const LIFT_DOORS := preload("res://src/ui/transitions/lift_doors_painter.gd")
const STAIR_WIPE := preload("res://src/ui/transitions/stair_wipe_painter.gd")
const DOOR_SWING := preload("res://src/ui/transitions/door_swing_painter.gd")
const WARM_BLACK := Color("0d0908")
const VIEW_SIZE := Vector2(960, 540)

var kind: StringName = &""
## True going into a wing (up the stairs, up the lift, in through the door).
var ascending: bool = true
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
## Lift ride progress 0..1, read by the floor dial.
var indicator: float = 0.0:
	set(value):
		indicator = value
		queue_redraw()


func _init() -> void:
	name = "RoomTransitionOverlay"
	position = Vector2.ZERO
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func begin(transition_kind: StringName, is_ascending: bool) -> void:
	kind = transition_kind
	ascending = is_ascending
	indicator = 0.0
	progress = 0.0


## How closed the overlay is: 0 open, 1 fully covering.
func coverage() -> float:
	return clampf(1.0 - absf(1.0 - progress), 0.0, 1.0)


func _draw() -> void:
	match kind:
		&"lift":
			LIFT_DOORS.paint(self, VIEW_SIZE, coverage(), indicator, ascending)
		&"stairs":
			STAIR_WIPE.paint(self, VIEW_SIZE, progress, ascending)
		&"door":
			# Going in, the door hangs on the left and sweeps with the walk;
			# coming back out, it hangs on the right.
			DOOR_SWING.paint(self, VIEW_SIZE, progress, ascending)
		_:
			draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(WARM_BLACK, coverage()))
