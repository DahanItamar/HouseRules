class_name MatchPointHostess
extends CabinetHost
## Match Point hostess: an adult woman in country-club tennis chic (white
## cropped polo, white pleated skirt, a green-and-cream striped sweater tied over
## her shoulders, a plain green round bag) with light honey-blonde waves, green
## eyes and gold hoops. She stands in the clubhouse window alcove to the left of
## the board; the scoreboard deck hides her below mid-thigh, so her figure is
## registered to that cut line, not to her feet.
##
## Beats: calm idle watching the board with a ball in hand, the serve toss toward
## the hatch, anticipation while the ball drops, and a delighted fist pump to the
## player on a win. Presentation-only; she never reads or writes game state.

const POSE_IDLE := preload("res://assets/production/characters/hosts/match_point_hostess.png")
const POSE_SERVE := preload(
	"res://assets/production/characters/hosts/match_point_hostess_serve.png"
)
const POSE_WATCH := preload(
	"res://assets/production/characters/hosts/match_point_hostess_watch.png"
)
const POSE_CELEBRATE := preload(
	"res://assets/production/characters/hosts/match_point_hostess_celebrate.png"
)
## Eye-line registration on the shared 1392x2080 canvas: each pose's midpoint
## between the eyes lands on the same screen point, and `ratio` evens out the
## small figure-size differences between the pose edits.
const CUT_BELOW_EYES: float = 1480.0
const FIGURE_SCALE: float = 0.211
const SERVE_HOLD_SECONDS: float = 0.75
const CELEBRATE_HOLD_SECONDS: float = 2.2


func _init() -> void:
	name = "MatchPointHostess"
	display_scale = FIGURE_SCALE
	fade_seconds = 0.2
	lean_radians = 0.0
	breath_period = 4.4
	cue_color = MatchPointStyle.BRASS_BRIGHT
	add_pose(_pose(&"idle", POSE_IDLE, Vector2(788, 261), 1.0, Rect2(313, 45, 745, 2019)))
	add_pose(_pose(&"serve", POSE_SERVE, Vector2(611, 508), 0.96, Rect2(224, 64, 1085, 1999)))
	add_pose(_pose(&"watch", POSE_WATCH, Vector2(792, 306), 0.89, Rect2(258, 45, 831, 1996)))
	add_pose(
		_pose(&"celebrate", POSE_CELEBRATE, Vector2(732, 271), 0.96, Rect2(343, 44, 870, 2020))
	)
	rest_pose = &"idle"


## Places the cut line (the top of the deck) at `cut_point` inside this control.
func place_on_cut(cut_point: Vector2, lane_size: Vector2) -> void:
	size = lane_size
	anchor_point = cut_point
	if is_node_ready():
		_layout_sprites()


func _layout_sprites() -> void:
	super._layout_sprites()
	# The deck hides the default cue position under the anchor, so the
	# reduced-motion cue rides just above the cut line instead.
	if _cue != null:
		_cue.position.y = anchor_point.y - 10.0


func serve() -> void:
	play_beat(&"serve", [[&"serve", SERVE_HOLD_SECONDS], [&"watch", -1.0]])


## The result is known: a win earns the fist pump to the player; otherwise she
## returns to watching the board.
func react_to_result(won: bool) -> void:
	if won:
		play_beat(&"celebrate", [[&"celebrate", CELEBRATE_HOLD_SECONDS]])
	else:
		play_beat(&"reset", [[&"idle", -1.0]])


func reset_to_idle() -> void:
	_stop_beat()
	last_beat = &"idle"
	show_pose(rest_pose)


static func _pose(
	id: StringName, texture: Texture2D, eyes: Vector2, ratio: float, used: Rect2
) -> Pose:
	return Pose.new(id, texture, eyes + Vector2(0, CUT_BELOW_EYES / ratio), used, ratio)
