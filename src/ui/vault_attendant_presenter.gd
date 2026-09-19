extends CabinetHost
## Hexbound Vault keeper: an adult sorceress monster-hunter with raven-black hair,
## violet eyes and a silver crescent medallion, in a fitted black velvet coat and
## leather bodice. She stands on the crypt flagstones in the right lane, turned
## three-quarters toward the rune-sealed tile grid on screen-left.
##
## Motion language: measured 0.22 s fades, no lean and no bounce. Beats: calm
## idle with her key ring between rounds, tile indication (the master pose) while
## a round is live, a small bounded acknowledgement of a safe tile, a raised-palm
## curse warning with a faint silver ward sign, a palm-up cash-out presentation
## to the player, and a reset. Presentation-only.

const POSE_INDICATE := preload(
	"res://assets/production/characters/hosts/vault_witcher_sorceress.png"
)
const POSE_IDLE := preload(
	"res://assets/production/characters/hosts/vault_witcher_sorceress_idle.png"
)
const POSE_CASHOUT := preload(
	"res://assets/production/characters/hosts/vault_witcher_sorceress_cashout.png"
)
const POSE_WARNING := preload(
	"res://assets/production/characters/hosts/vault_witcher_sorceress_warning.png"
)

## Right lane between the grid (ends x=638) and the right safe edge. The crypt
## back wall meets the flagstones at y~370; she stands just in front of it.
const LANE_POSITION := Vector2(646, 100)
const LANE_SIZE := Vector2(204, 300)
## Planted boot anchor inside the lane (canvas 735, 386: on the flagstones).
const FOOT_POINT := Vector2(89, 286)
## Head-top to boot sole is 1994 source px -> 264 px tall on the 960x540 canvas.
const FIGURE_SCALE: float = 264.0 / 1994.0
## Every pose is head-registered on one 1392x2080 canvas; x=772 is the centre of
## her stance. Each pose keeps its own sole line and is rescaled to one stature.
const STANCE_X: float = 772.0
const MASTER_HEIGHT: float = 1994.0
const RESULT_HOLD_SECONDS: float = 1.8
const SAFE_NOD_RADIANS: float = -0.004


func _init() -> void:
	name = "VaultAttendant"
	position = LANE_POSITION
	size = LANE_SIZE
	display_scale = FIGURE_SCALE
	anchor_point = FOOT_POINT
	fade_seconds = 0.22
	lean_radians = 0.0
	breath_period = 5.0
	# Reduced-motion cue: moon-silver, never the cyan reserved for focus.
	cue_color = Color("c9d2dc")
	contact_shadow_size = Vector2(46, 7)
	contact_shadow_offset = Vector2(0, -1)
	add_pose(_pose(&"indicate", POSE_INDICATE, 2042.0, 1994.0, Rect2(179, 47, 910, 1997)))
	add_pose(_pose(&"idle", POSE_IDLE, 2028.0, 1981.0, Rect2(448, 46, 602, 1984)))
	add_pose(_pose(&"cashout", POSE_CASHOUT, 2048.0, 2000.0, Rect2(198, 47, 894, 2003)))
	add_pose(_pose(&"warning", POSE_WARNING, 2013.0, 1965.0, Rect2(276, 47, 796, 1968)))
	rest_pose = &"idle"


## Live round: indicate the grid; between rounds: calm idle with her key ring.
func set_round_active(active: bool) -> void:
	set_rest_pose(&"indicate" if active else &"idle")


## Safe tile: keep indicating, acknowledge with one small bounded nod/cue.
func acknowledge_safe() -> void:
	last_beat = &"safe"
	if MotionPolicy.is_reduced():
		play_beat(&"safe", [])
		return
	if _figure == null:
		return
	_stop_beat()
	show_pose(rest_pose)
	_beat_tween = create_tween()
	(
		_beat_tween
		. tween_property(_figure, "skew", SAFE_NOD_RADIANS, 0.11)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_beat_tween.tween_property(_figure, "skew", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


## Cursed rune revealed: she faces the player with a raised, warding palm.
func warn_mine() -> void:
	if last_beat == &"mine" and has_active_gesture():
		return
	play_beat(&"mine", [[&"warning", RESULT_HOLD_SECONDS]])


## Cash-out or all-clear: palm-up presentation toward the player.
func present_cash_out() -> void:
	if last_beat == &"cashout" and has_active_gesture():
		return
	play_beat(&"cashout", [[&"cashout", RESULT_HOLD_SECONDS]])


## `sole_y` is the pose's boot-sole line and `figure_height` its head-to-sole
## height in source pixels; the ratio gives every pose the master's stature.
static func _pose(
	id: StringName, texture: Texture2D, sole_y: float, figure_height: float, used: Rect2
) -> Pose:
	return Pose.new(id, texture, Vector2(STANCE_X, sole_y), used, MASTER_HEIGHT / figure_height)
