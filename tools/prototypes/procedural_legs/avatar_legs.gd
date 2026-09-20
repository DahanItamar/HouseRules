extends Node2D
## PARKED PROTOTYPE, NOT SHIPPED. The user rejected this procedural leg rig in
## favour of a full-body video-derived walk atlas; it is kept for reference only.
## To try it again: rebuild the torso with tools/art/build_player_torso.py, draw
## this node behind a Sprite2D showing player_torso_v2.png (one column per
## facing), and feed solve() the distance walked. Tests for it lived in the
## working tree history of tests/test_character_atlas.gd.
##
## Procedural two-bone legs for the player, phase-locked to the distance walked.
##
## The painted upper body comes from the torso atlas; the legs are solved here so
## the gait is always biomechanically consistent. Everything is authored in the
## atlas's 240 px cell space (0.29 virtual px per unit at room scale 1).
##
## Body frame: x = forward along travel, y = walker's right, z = up; the origin is
## the ground point under the pelvis. Each leg is a thigh and a shin solved with
## analytic two-bone IK in that 3D frame, the knee bending toward forward. The
## frame is projected to the screen with the recorded hip pivots of the torso
## column for the lateral axis, the travel direction (depth-compressed) for the
## forward axis and straight up for height.
##
## Gait: one cycle is two steps. Each foot spends STANCE of the cycle planted
## (heel rocker, flat foot, heel rise and toe pivot, all rotating about a fixed
## ground point) and the rest swinging in an arc. The legs are half a cycle apart.
## A stance foot's ground position moves backward in the body frame by exactly
## the distance walked, so it never slides on the floor.

const FOOT_LINE: float = 230.0
## Left and right hip pivots per torso column, in cell pixels (from
## player_torso_v2.json): [left0, right0, left1, ...].
const HIPS: Array[Vector2] = [
	Vector2(112.5, 124.0), Vector2(132.5, 124.0),
	Vector2(118.33, 120.11), Vector2(132.47, 127.89),
	Vector2(125.5, 118.5), Vector2(125.5, 129.5),
	Vector2(133.27, 120.11), Vector2(119.13, 127.89),
	Vector2(128.3, 124.0), Vector2(108.3, 124.0),
	Vector2(120.87, 127.89), Vector2(106.73, 120.11),
	Vector2(114.5, 129.5), Vector2(114.5, 118.5),
	Vector2(107.53, 127.89), Vector2(121.67, 120.11),
]

## Heel-to-heel step length along travel; a cycle is two steps.
const STEP: float = 74.0
const CYCLE: float = STEP * 2.0
## Fraction of the cycle a foot is on the ground.
const STANCE: float = 0.6
## Stance progress where the heel rocker ends and where the heel starts to rise.
const HEEL_ROCKER_END: float = 0.15
const HEEL_RISE_START: float = 0.55
## Foot pitch at heel strike (toe up) and at toe-off (heel up), radians.
const CONTACT_PITCH: float = 0.31
const TOE_OFF_PITCH: float = -0.66
## Extra ankle height at mid-swing.
const SWING_LIFT: float = 7.0
## Foot: heel-to-toe length, ankle joint above and ahead of the heel.
const FOOT_LENGTH: float = 30.0
const ANKLE_FORWARD: float = 7.0
const ANKLE_HEIGHT: float = 9.0
## Hip joint height above the soles when standing (foot line 230, hips at 124).
const HIP_HEIGHT: float = FOOT_LINE - 124.0
## Thigh and shin: straight enough that the standing knee is bent about 10°.
const THIGH: float = 48.7
const SHIN: float = 48.7
const HIP_HALF_WIDTH: float = 10.0
## Feet track under the hips so both legs stay readable head-on.
const WALK_FOOT_HALF_WIDTH: float = 9.0
const IDLE_FOOT_HALF_WIDTH: float = 8.5
## Pelvis rotation: the hip of the leading leg is carried forward.
const PELVIS_TWIST: float = 3.0
## Walking posture: the pelvis rides a little lower than when standing.
const WALK_CROUCH: float = 2.5
## Vertical body bob amplitude (peak to peak 2 x BOB = about 1.3 virtual px),
## lowest just after each heel strike, highest at passing.
const BOB: float = 2.2
const BOB_LOW_PHASE: float = 0.05
## Side-to-side pelvis sway toward the stance leg on front and back views.
const SWAY: float = 1.8
## Ground depth compression of the top-down 3/4 camera (it looks down ~30°).
const DEPTH: float = 0.55
## Depth compression applied to the stride. Softer than DEPTH so walking toward
## or away from the camera keeps a readable stride and a natural cadence (with
## DEPTH the cadence would be 1.8x faster, because the floor moves at the same
## screen speed in every direction).
const STRIDE_DEPTH: float = 0.75
## Phase a walk starts from when standing still: left foot flat under the body,
## right foot passing it, which is the pose closest to standing.
const START_PHASE: float = 0.3
## Swing and stance helpers derived from the constants above.
const SWING_DISTANCE: float = (1.0 - STANCE) * CYCLE
## Flat-foot heel position (forward of the pelvis) at heel strike; chosen so
## that heel strike and toe-off sit symmetrically about the body.
const CONTACT_HEEL: float = STANCE * STEP - FOOT_LENGTH * 0.5

const TROUSER_BASE := Color(0.085, 0.078, 0.086)
const TROUSER_SHADOW := Color(0.028, 0.026, 0.031)
const TROUSER_LIGHT := Color(0.185, 0.176, 0.192)
const SATIN := Color(0.15, 0.145, 0.165)
const SATIN_SHEEN := Color(0.24, 0.235, 0.26)
const SHOE := Color(0.035, 0.033, 0.038)
const SHOE_EDGE := Color(0.012, 0.011, 0.014)
const SOLE := Color(0.13, 0.085, 0.07)
const SHOE_GLOSS := Color(0.7, 0.72, 0.78, 0.4)
const SHOE_SHEEN := Color(0.42, 0.43, 0.48, 0.55)
## Trouser silhouette widths (screen cell px) from hip to hem.
const LEG_WIDTHS: Array[float] = [18.5, 16.6, 14.6, 13.6, 12.8]
## The far leg reads a little darker, as if in the near leg's shadow.
const FAR_LEG_SHADE: float = 0.78

## Latest solved pose, see solve().
var pose: Dictionary = {}


## World distance (cell px along the ground) covered by moving `screen_distance`
## cell px on screen in the screen direction `travel`.
static func world_distance(screen_distance: float, travel: Vector2) -> float:
	return screen_distance / forward_axis(travel).length()


## Screen vector of one world unit forward along the screen direction `travel`.
static func forward_axis(travel: Vector2) -> Vector2:
	var direction := travel.normalized() if not travel.is_zero_approx() else Vector2.DOWN
	var world := Vector2(direction.x, direction.y / STRIDE_DEPTH).normalized()
	return Vector2(world.x, world.y * STRIDE_DEPTH)


## Cycle phase in [0, 1) for a total world distance walked.
static func phase_at(distance: float) -> float:
	return fposmod(distance / CYCLE, 1.0)


## Solves the whole lower body. `distance` is the world distance walked (cell
## px), `travel` the screen direction of travel, `column` the torso column,
## `blend` 0 = standing, 1 = walking. Returns screen positions in cell pixels:
## {"phase", "offset" (torso shift), "legs": [left, right], "order": [far, near]}.
static func solve(
	distance: float, travel: Vector2, column: int, blend: float, reduced: bool
) -> Dictionary:
	var phase := phase_at(distance)
	var weight := clampf(blend, 0.0, 1.0)
	var hips: Array[Vector2] = [HIPS[column * 2], HIPS[column * 2 + 1]]
	var hip_centre := (hips[0] + hips[1]) * 0.5
	var origin := Vector2(hip_centre.x, hip_centre.y + HIP_HEIGHT)
	var lateral_axis := (hips[1] - hips[0]) * 0.5 / HIP_HALF_WIDTH
	var forward := forward_axis(travel)
	var frontness := absf(Vector2(sin(column * PI / 4.0), -cos(column * PI / 4.0)).y)
	# Reduced motion drops the bob but holds the pelvis at the bob's lowest
	# height, so the legs keep the reach they need at heel strike.
	var bob := -BOB if reduced else -BOB * cos(TAU * 2.0 * (phase - BOB_LOW_PHASE))
	var sway := 0.0 if reduced else -SWAY * frontness * cos(TAU * (phase - START_PHASE))
	var lift := (bob - WALK_CROUCH) * weight
	sway *= weight
	var legs: Array[Dictionary] = []
	for side: int in [-1, 1]:
		var leg_phase := fposmod(phase + (0.0 if side < 0 else 0.5), 1.0)
		var hip := Vector3(
			PELVIS_TWIST * cos(TAU * leg_phase) * weight,
			side * HIP_HALF_WIDTH + sway,
			HIP_HEIGHT + lift
		)
		var gait := _foot(leg_phase)
		var ankle_x := lerpf(0.0, gait.x, weight)
		var ankle_z := lerpf(ANKLE_HEIGHT, gait.y, weight)
		var pitch := lerpf(0.0, gait.z, weight)
		var foot_y := side * lerpf(IDLE_FOOT_HALF_WIDTH, WALK_FOOT_HALF_WIDTH, weight)
		var ankle := Vector3(ankle_x, foot_y, ankle_z)
		var knee := _knee(hip, ankle)
		var foot_forward := Vector3(cos(pitch), 0.0, sin(pitch))
		var foot_up := Vector3(-sin(pitch), 0.0, cos(pitch))
		var heel := ankle - foot_forward * ANKLE_FORWARD - foot_up * ANKLE_HEIGHT
		var toe := heel + foot_forward * FOOT_LENGTH
		var project := func(point: Vector3) -> Vector2:
			return origin + forward * point.x + lateral_axis * point.y + Vector2(0.0, -point.z)
		var thigh := (knee - hip).normalized()
		var shin := (ankle - knee).normalized()
		var stance := leg_phase < STANCE and weight > 0.0
		legs.append(
			{
					"side": side,
					"leg_phase": leg_phase,
					"stance": stance,
					"hip": project.call(hip),
					"knee": project.call(knee),
					"ankle": project.call(ankle),
					"heel": project.call(heel),
					"toe": project.call(toe),
					"hip_3d": hip,
					"knee_3d": knee,
					"ankle_3d": ankle,
					"heel_3d": heel,
					"toe_3d": toe,
					"pitch": pitch,
					"knee_flex": acos(clampf(thigh.dot(shin), -1.0, 1.0)),
					"depth": (project.call(Vector3(hip.x, hip.y, 0.0)) + project.call(heel)).y,
					"shoe": _shoe_points(heel, foot_forward, foot_up, project),
					"shoe_frame": [heel, foot_forward, foot_up],
			}
		)
	var order: Array = [0, 1] if legs[0]["depth"] <= legs[1]["depth"] else [1, 0]
	return {
		"phase": phase,
		"offset": lateral_axis * sway + Vector2(0.0, -lift),
		"legs": legs,
		"order": order,
		"origin": origin,
		"forward": forward,
		"lateral": lateral_axis,
	}


## Walking foot for one leg phase: Vector3(ankle forward, ankle height, pitch).
static func _foot(leg_phase: float) -> Vector3:
	if leg_phase < STANCE:
		return _stance_foot(leg_phase)
	var t := (leg_phase - STANCE) / (1.0 - STANCE)
	var start := _stance_foot(STANCE)
	var end := _stance_foot(0.0)
	var ease := t * t * (3.0 - 2.0 * t)
	# Hermite in the moving body frame: at both ends the foot's world velocity
	# is zero (slope -SWING_DISTANCE), so lift-off and touchdown are smooth.
	var x := _hermite(start.x, end.x, -SWING_DISTANCE, -SWING_DISTANCE, t)
	var z := lerpf(start.y, end.y, ease) + SWING_LIFT * pow(sin(PI * t), 2.0)
	var pitch := lerpf(start.z, end.z, ease)
	return Vector3(x, z, pitch)


## Stance foot as Vector3(ankle forward, ankle height, pitch). The flat heel
## point moves back by exactly the distance walked, so contact never slides.
static func _stance_foot(leg_phase: float) -> Vector3:
	var progress := leg_phase / STANCE
	var ground := CONTACT_HEEL - leg_phase * CYCLE
	var pitch := 0.0
	var heel := Vector2(ground, 0.0)
	if progress < HEEL_ROCKER_END:
		var k := progress / HEEL_ROCKER_END
		pitch = CONTACT_PITCH * (1.0 - k * k * (3.0 - 2.0 * k))
	elif progress > HEEL_RISE_START:
		var k := (progress - HEEL_RISE_START) / (1.0 - HEEL_RISE_START)
		pitch = TOE_OFF_PITCH * k * k
		# Heel rise pivots on the planted toe.
		heel = Vector2(ground + FOOT_LENGTH, 0.0) - Vector2(cos(pitch), sin(pitch)) * FOOT_LENGTH
	var ankle := heel + _rotated(Vector2(ANKLE_FORWARD, ANKLE_HEIGHT), pitch)
	return Vector3(ankle.x, ankle.y, pitch)


## Analytic two-bone IK: the knee lies in the plane of the leg and the forward
## axis, on the forward side.
static func _knee(hip: Vector3, ankle: Vector3) -> Vector3:
	var axis := ankle - hip
	var reach := clampf(axis.length(), absf(THIGH - SHIN) + 0.01, THIGH + SHIN - 0.001)
	var along := axis.normalized()
	var a := (reach * reach + THIGH * THIGH - SHIN * SHIN) / (2.0 * reach)
	var h := sqrt(maxf(THIGH * THIGH - a * a, 0.0))
	var bend := Vector3(1.0, 0.0, 0.0)
	bend = (bend - along * bend.dot(along)).normalized()
	return hip + along * a + bend * h


static func _hermite(p0: float, p1: float, m0: float, m1: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return (
		(2.0 * t3 - 3.0 * t2 + 1.0) * p0
		+ (t3 - 2.0 * t2 + t) * m0
		+ (-2.0 * t3 + 3.0 * t2) * p1
		+ (t3 - t2) * m1
	)


static func _rotated(point: Vector2, angle: float) -> Vector2:
	return Vector2(
		point.x * cos(angle) - point.y * sin(angle), point.x * sin(angle) + point.y * cos(angle)
	)


## Oxford silhouette: footprint and upper points in the foot frame, projected.
## (x from the heel toward the toe, y lateral, z up from the sole.)
static func _shoe_points(
	heel: Vector3, forward: Vector3, up: Vector3, project: Callable
) -> PackedVector2Array:
	var shape: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.7, 3.0, 0.0),
		Vector3(0.7, -3.0, 0.0),
		Vector3(3.0, 3.8, 0.0),
		Vector3(3.0, -3.8, 0.0),
		Vector3(7.5, 3.6, 0.0),
		Vector3(7.5, -3.6, 0.0),
		Vector3(12.0, 3.5, 1.2),
		Vector3(12.0, -3.5, 1.2),
		Vector3(19.5, 4.9, 0.0),
		Vector3(19.5, -4.9, 0.0),
		Vector3(25.5, 4.2, 0.0),
		Vector3(25.5, -4.2, 0.0),
		Vector3(28.8, 2.4, 0.2),
		Vector3(28.8, -2.4, 0.2),
		Vector3(30.0, 0.0, 0.6),
		Vector3(0.2, 3.0, 6.8),
		Vector3(0.2, -3.0, 6.8),
		Vector3(3.0, 3.6, 10.0),
		Vector3(3.0, -3.6, 10.0),
		Vector3(9.0, 3.9, 11.0),
		Vector3(9.0, -3.9, 11.0),
		Vector3(16.0, 4.3, 8.0),
		Vector3(16.0, -4.3, 8.0),
		Vector3(22.5, 4.2, 5.6),
		Vector3(22.5, -4.2, 5.6),
		Vector3(27.5, 2.4, 3.6),
		Vector3(27.5, -2.4, 3.6),
		Vector3(29.6, 0.0, 2.2),
	]
	var points := PackedVector2Array()
	for p: Vector3 in shape:
		var lateral := Vector3(0.0, p.y, 0.0)
		points.append(project.call(heel + forward * p.x + up * p.z + lateral))
	return Geometry2D.convex_hull(points)


func _draw() -> void:
	if pose.is_empty():
		return
	var scale_factor := FloorAvatar.GUEST_SCALE
	draw_set_transform(
		FloorAvatar.FOOT_OFFSET - Vector2(FloorAvatar.GUEST_CELL_SIZE) * 0.5 * scale_factor,
		0.0,
		Vector2.ONE * scale_factor
	)
	var legs: Array = pose["legs"]
	_draw_pelvis(legs[0]["hip"], legs[1]["hip"])
	var order: Array = pose["order"]
	for rank: int in range(order.size()):
		var leg: Dictionary = legs[order[rank]]
		var shade := FAR_LEG_SHADE if rank == 0 else 1.0
		_draw_shoe(leg, shade)
		_draw_trouser(leg, shade)
	draw_set_transform(Vector2.ZERO)


## Seat of the trousers: fills the crotch between the thighs under the jacket.
func _draw_pelvis(left: Vector2, right: Vector2) -> void:
	draw_line(left, right, TROUSER_SHADOW, 18.0, true)
	draw_circle(left, 9.0, TROUSER_SHADOW, true, -1.0, true)
	draw_circle(right, 9.0, TROUSER_SHADOW, true, -1.0, true)


func _draw_trouser(leg: Dictionary, shade: float) -> void:
	var hip: Vector2 = leg["hip"]
	var knee: Vector2 = leg["knee"]
	var ankle: Vector2 = leg["ankle"]
	var hem := ankle + (ankle - knee).normalized() * 3.0
	var spine: Array[Vector2] = [hip, hip.lerp(knee, 0.5), knee, knee.lerp(hem, 0.5), hem]
	var normals: Array[Vector2] = []
	for index: int in range(spine.size()):
		var before := spine[maxi(index - 1, 0)]
		var after := spine[mini(index + 1, spine.size() - 1)]
		var normal := (after - before).normalized().orthogonal()
		if normals.is_empty():
			if normal.x < 0.0:
				normal = -normal
		elif normal.dot(normals[-1]) < 0.0:
			normal = -normal
		normals.append(normal)
	# Satin side stripe runs down the outer seam: where the walker's outward
	# lateral direction faces the camera it shows, at its screen offset.
	# On a leg seen as a vertical cylinder a surface direction (x, y) in world
	# ground space appears at x across the silhouette and faces the camera
	# when y (toward the viewer) is not negative.
	var lateral: Vector2 = pose["lateral"]
	var outward := Vector2(lateral.x, lateral.y / DEPTH).normalized() * float(leg["side"])
	var seam := clampf(outward.x * signf(normals[2].x + 0.001), -0.92, 0.92)
	var seam_visible := smoothstep(-0.45, 0.1, outward.y)
	# Orientation shading so a gait also reads head-on: a thigh swung forward
	# turns its front to the overhead light, a shin angled back turns away, and
	# a bent knee pulls the cloth tight over the kneecap.
	var thigh_forward := ((leg["knee_3d"] as Vector3) - (leg["hip_3d"] as Vector3)).normalized().x
	var shin_forward := ((leg["ankle_3d"] as Vector3) - (leg["knee_3d"] as Vector3)).normalized().x
	var flex := clampf(float(leg["knee_flex"]) / 1.1, 0.0, 1.0)
	var section_light: Array[float] = [
		0.5 * maxf(thigh_forward, 0.0),
		0.45 * maxf(thigh_forward, 0.0),
		0.35 * flex + 0.2 * maxf(thigh_forward, 0.0),
		-0.3 * maxf(-shin_forward, 0.0),
		-0.4 * maxf(-shin_forward, 0.0),
	]
	var samples: Array[float] = [-1.0, -0.62, -0.25, 0.2, 0.6, 1.0]
	for extra: float in [seam - 0.16, seam, seam + 0.16]:
		if extra > -0.99 and extra < 0.99:
			samples.append(extra)
	samples.sort()
	var outline_left := PackedVector2Array()
	var outline_right := PackedVector2Array()
	for index: int in range(spine.size() - 1):
		var a := spine[index]
		var b := spine[index + 1]
		var na := normals[index] * LEG_WIDTHS[index] * 0.5
		var nb := normals[index + 1] * LEG_WIDTHS[index + 1] * 0.5
		for column: int in range(samples.size() - 1):
			var s0 := samples[column]
			var s1 := samples[column + 1]
			var la := section_light[index]
			var lb := section_light[index + 1]
			var a0 := _trouser_colour(s0, seam, seam_visible, shade, la)
			var a1 := _trouser_colour(s1, seam, seam_visible, shade, la)
			var b0 := _trouser_colour(s0, seam, seam_visible, shade, lb)
			var b1 := _trouser_colour(s1, seam, seam_visible, shade, lb)
			draw_polygon(
				PackedVector2Array([a + na * s0, a + na * s1, b + nb * s1, b + nb * s0]),
				PackedColorArray([a0, a1, b1, b0])
			)
		outline_left.append(a - na)
		outline_right.append(a + na)
		if index == spine.size() - 2:
			outline_left.append(b - nb)
			outline_right.append(b + nb)
	# Anti-aliased silhouette so the flat-filled polygons match the soft,
	# linearly filtered torso edges.
	var outline := outline_left.duplicate()
	outline_right.reverse()
	outline.append_array(outline_right)
	outline.append(outline[0])
	draw_polyline(outline, TROUSER_SHADOW * Color(shade, shade, shade, 1.0), 1.4, true)


func _trouser_colour(
	s: float, seam: float, seam_visible: float, shade: float, light: float
) -> Color:
	# Light from the upper left: a soft highlight left of centre, falling into
	# shadow toward the right edge.
	var colour := TROUSER_BASE.lerp(TROUSER_SHADOW, smoothstep(0.15, 1.0, s))
	colour = colour.lerp(TROUSER_LIGHT, maxf(0.0, 1.0 - absf(s + 0.45) / 0.4) * 0.8)
	colour = colour.lerp(TROUSER_SHADOW, smoothstep(0.85, 1.0, -s) * 0.6)
	if light > 0.0:
		colour = colour.lerp(TROUSER_LIGHT, light * (1.0 - 0.5 * absf(s + 0.2)))
	else:
		colour = colour.lerp(TROUSER_SHADOW, -light)
	var stripe := maxf(0.0, 1.0 - absf(s - seam) / 0.15) * seam_visible
	colour = colour.lerp(SATIN, stripe * 0.75)
	colour = colour.lerp(SATIN_SHEEN, maxf(0.0, 1.0 - absf(s - seam) / 0.05) * seam_visible * 0.45)
	return Color(colour.r * shade, colour.g * shade, colour.b * shade, 1.0)


func _draw_shoe(leg: Dictionary, shade: float) -> void:
	var outline: PackedVector2Array = leg["shoe"]
	if outline.size() < 3:
		return
	var tint := Color(shade, shade, shade, 1.0)
	draw_colored_polygon(outline, SHOE * tint)
	var frame: Array = leg["shoe_frame"]
	var heel: Vector3 = frame[0]
	var forward: Vector3 = frame[1]
	var up: Vector3 = frame[2]
	var origin: Vector2 = pose["origin"]
	var screen_forward: Vector2 = pose["forward"]
	var lateral: Vector2 = pose["lateral"]
	var project := func(x: float, y: float, z: float) -> Vector2:
		var point := heel + forward * x + up * z + Vector3(0.0, y, 0.0)
		return origin + screen_forward * point.x + lateral * point.y + Vector2(0.0, -point.z)
	# The sole edge on the side facing the camera, with the heel block.
	var near_side := 3.6 if lateral.y >= 0.0 else -3.6
	if absf(lateral.y) < 0.2:
		near_side = 3.6 if lateral.x < 0.0 else -3.6
	var sole := PackedVector2Array(
		[
			project.call(0.3, near_side * 0.85, 0.8),
			project.call(7.0, near_side, 0.8),
			project.call(12.0, near_side * 0.95, 1.8),
			project.call(19.5, near_side * 1.3, 0.8),
			project.call(27.5, near_side * 0.7, 0.9),
		]
	)
	draw_polyline(sole, SOLE * tint, 1.3, true)
	# Seen from behind, a lifting heel turns the leather sole to the camera.
	var sole_facing := -screen_forward.y * clampf(-sin(float(leg["pitch"])) * 2.0, 0.0, 1.0)
	if sole_facing > 0.05:
		var footprint := PackedVector2Array()
		for point: Vector2 in [
			Vector2(0.3, 0.0), Vector2(1.0, 3.0), Vector2(7.5, 3.4), Vector2(19.5, 4.6),
			Vector2(27.5, 3.0), Vector2(29.6, 0.0), Vector2(27.5, -3.0), Vector2(19.5, -4.6),
			Vector2(7.5, -3.4), Vector2(1.0, -3.0),
		]:
			footprint.append(project.call(point.x, point.y, 0.2))
		var sole_colour := SOLE * tint
		sole_colour.a = clampf(sole_facing, 0.0, 1.0)
		draw_colored_polygon(footprint, sole_colour)
		var heel_block := PackedVector2Array(
			[
				project.call(0.3, 3.0, 0.1), project.call(6.5, 3.2, 0.1),
				project.call(6.5, -3.2, 0.1), project.call(0.3, -3.0, 0.1),
			]
		)
		draw_colored_polygon(heel_block, Color(SHOE_EDGE, sole_colour.a))
	draw_line(project.call(7.0, near_side, 0.4), project.call(7.0, near_side, 2.2), SOLE * tint, 1.0, true)
	# Patent-leather gloss on the toe cap and along the vamp.
	var sheen := PackedVector2Array(
		[project.call(12.5, 0.0, 8.6), project.call(19.0, 0.0, 6.4), project.call(24.5, 0.0, 4.6)]
	)
	draw_polyline(sheen, SHOE_SHEEN * tint, 1.6, true)
	var gloss_centre: Vector2 = project.call(25.2, -near_side * 0.25, 4.2)
	draw_circle(gloss_centre, 1.2, SHOE_GLOSS * tint, true, -1.0, true)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, SHOE_EDGE, 1.2, true)
