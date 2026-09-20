class_name CoreOverclockHostess
extends CabinetHost
## The Forno d'Oro pizzaiola: an original adult woman with very long caramel
## hair, an olive tan, a black crop tee and a black bistro apron, flour on her
## forearms, a wooden peel in her hand. She works at the counter beside the
## oven; the control deck hides her below the hip, so her figure is registered
## to that cut line, not to her feet.
##
## Beats: at the counter between bakes, watching the oven while one is in, a
## delighted serve when it comes out, and a wince when it burns. Only one pose
## master exists so far, so every beat currently settles on it and reduced
## motion is already the shipped behaviour; adding a pose is one `add_pose` line
## here plus its texture in CoreOverclockTheme.
##
## Presentation-only: she never reads or writes game state, and she stands clear
## of the gauge, the history strip and the deck.

const SERVE_HOLD_SECONDS: float = 2.2
const WINCE_HOLD_SECONDS: float = 1.6
## Painted bounds of the master, in source pixels (printed by the art script).
const USED_MASTER := Rect2(224, 33, 912, 2011)


func _init() -> void:
	name = "CoreOverclockHostess"
	display_scale = CoreOverclockTheme.HOSTESS_SCALE
	fade_seconds = 0.2
	lean_radians = 0.0
	breath_period = 4.4
	cue_color = CoreOverclockTheme.EMBER
	add_pose(
		Pose.new(
			&"idle", CoreOverclockTheme.HOSTESS, CoreOverclockTheme.HOSTESS_ANCHOR, USED_MASTER
		)
	)
	rest_pose = &"idle"


## Places the cut line (the top of the control deck) at `cut_point` in the lane.
func place_on_cut(cut_point: Vector2, lane_size: Vector2) -> void:
	size = lane_size
	anchor_point = cut_point
	if is_node_ready():
		_layout_sprites()


func _layout_sprites() -> void:
	super._layout_sprites()
	# The deck hides the cue's default place under the anchor, so the state cue
	# rides just above the cut line instead.
	if _cue != null:
		_cue.position.y = anchor_point.y - 10.0


## She turns to the oven for as long as a pizza is in it. With one master pose
## this is the bounded state cue; the beat is already wired for her watch pose.
func watch_the_oven() -> void:
	play_beat(&"watch", [[_pose_or_rest(&"watch"), -1.0]])


## The result is known: a served pizza earns the serve beat, a burnt one the
## wince, and either way she returns to the counter.
func react_to_result(served: bool) -> void:
	if served:
		play_beat(&"serve", [[_pose_or_rest(&"serve"), SERVE_HOLD_SECONDS]])
	else:
		play_beat(&"wince", [[_pose_or_rest(&"wince"), WINCE_HOLD_SECONDS]])


func reset_to_idle() -> void:
	_stop_beat()
	last_beat = &"idle"
	show_pose(rest_pose)


## The named pose if it has been generated, otherwise the master.
func _pose_or_rest(id: StringName) -> StringName:
	return id if pose_texture(id) != null else rest_pose
