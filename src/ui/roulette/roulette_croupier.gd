class_name RouletteCroupier
extends CabinetHost
## Ruby Salon croupier: an adult woman with an auburn chignon, green eyes and a
## fitted ruby satin croupier dress with a black sash. She stands behind the
## far rail at the wheel end of the table; the rail hides her below the upper
## thigh, so her figure is registered to the rail line, not to her feet.
##
## Beats: calm watch of the wheel while bets go down, a spin launch as the ball
## is released, the "no more bets" palm-down sweep while it drops, and a warm
## announcement to the player once the pocket is known. Presentation-only.

const POSE_IDLE := preload("res://assets/production/characters/hosts/roulette_croupier.png")
const POSE_SPIN := preload("res://assets/production/characters/hosts/roulette_croupier_spin.png")
const POSE_NO_MORE_BETS := preload(
	"res://assets/production/characters/hosts/roulette_croupier_no_more_bets.png"
)
const POSE_ANNOUNCE := preload(
	"res://assets/production/characters/hosts/roulette_croupier_announce.png"
)
## Head-registered masters share one 1392x2080 canvas; x=735 is her head centre.
const STANCE_X: float = 735.0
## Source row where the table's far rail crosses her upper thigh.
const RAIL_SOURCE_Y: float = 1861.0
## Head-top (y=35) to rail is 1826 source px -> 182 virtual px.
const FIGURE_SCALE: float = 182.0 / 1826.0
const SPIN_HOLD_SECONDS: float = 1.25


func _init() -> void:
	name = "RouletteCroupier"
	display_scale = FIGURE_SCALE
	fade_seconds = 0.2
	lean_radians = 0.0
	breath_period = 4.6
	cue_color = RouletteStyle.BRASS_BRIGHT
	add_pose(_pose(&"idle", POSE_IDLE, Rect2(276, 35, 877, 2029)))
	add_pose(_pose(&"spin", POSE_SPIN, Rect2(276, 36, 1057, 2028)))
	add_pose(_pose(&"no_more_bets", POSE_NO_MORE_BETS, Rect2(344, 36, 896, 2025)))
	add_pose(_pose(&"announce", POSE_ANNOUNCE, Rect2(129, 36, 1247, 2028)))
	rest_pose = &"idle"


## Places the rail anchor at `rail_point` inside this control.
func place_on_rail(rail_point: Vector2, lane_size: Vector2) -> void:
	size = lane_size
	anchor_point = rail_point
	if is_node_ready():
		_layout_sprites()


func _layout_sprites() -> void:
	super._layout_sprites()
	# The shared cue bar sits under the anchor; the rail would hide it here, so
	# the reduced-motion cue rides just above the rail line instead.
	if _cue != null:
		_cue.position.y = anchor_point.y - 10.0


func launch_spin() -> void:
	# "No more bets" is held while the ball drops, until the announcement.
	play_beat(&"spin", [[&"spin", SPIN_HOLD_SECONDS], [&"no_more_bets", -1.0]])


func announce_result() -> void:
	play_beat(&"announce", [[&"announce", -1.0]])


## Bets reopen: back to watching the wheel.
func open_betting() -> void:
	_stop_beat()
	last_beat = &"idle"
	show_pose(rest_pose)


static func _pose(id: StringName, texture: Texture2D, used: Rect2) -> Pose:
	return Pose.new(id, texture, Vector2(STANCE_X, RAIL_SOURCE_Y), used)
