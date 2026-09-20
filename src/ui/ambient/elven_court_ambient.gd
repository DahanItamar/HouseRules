extends AmbientLayer
## Elven Court: fireflies drifting through the moonlit forest either side of the
## cabinet. They live only in the painted forest margins, above the bezel art and
## under the hostess, lever, reels and controls.

const TINT := Color("e6f4a6")
## Forest margins the fireflies wander: left of the cabinet (behind the
## hostess), the right-hand trees beyond the lever and below the help button,
## and the top-left canopy.
const REGIONS: Array[Rect2] = [
	Rect2(10, 70, 104, 330),
	Rect2(893, 110, 58, 300),
	Rect2(12, 10, 150, 50),
]
const REGION_COUNTS: Array[int] = [6, 4, 3]
const HALO_RADIUS: float = 6.5
const HALO_SHARE: float = 0.22

var _home_region := PackedInt32Array()


func _ready() -> void:
	for region: int in range(REGIONS.size()):
		for _index: int in range(REGION_COUNTS[region]):
			_home_region.append(region)
	super._ready()


func firefly_count() -> int:
	return _home_region.size()


## Firefly `index` at `at_time`: (x, y, alpha). Each one wanders a slow
## Lissajous path inside its region and glows on its own 3.5-6 s cycle.
func firefly_state(index: int, at_time: float = elapsed) -> Vector3:
	if reduced_motion:
		return Vector3(0.0, 0.0, 0.0)
	var region := REGIONS[_home_region[index]]
	var key := index * 37 + 5
	var speed_x := 0.07 + hash01(key) * 0.08
	var speed_y := 0.05 + hash01(key + 1) * 0.07
	var along := Vector2(
		0.5 + 0.44 * sin(at_time * speed_x + hash01(key + 2) * TAU),
		0.5 + 0.44 * sin(at_time * speed_y + hash01(key + 3) * TAU)
	)
	var wobble := Vector2(
		sin(at_time * 0.9 + float(index)), cos(at_time * 0.7 + float(index) * 1.3)
	)
	var point := region.position + region.size * along + wobble * 1.5
	var glow_period := 3.5 + hash01(key + 4) * 2.5
	var pulse := maxf(0.0, sin((at_time / glow_period + hash01(key + 5)) * TAU))
	return Vector3(point.x, point.y, SPARK_ALPHA_CAP * 0.85 * pulse * pulse)


func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := super.sample_alpha_peaks(at_time)
	for index: int in range(_home_region.size()):
		var state := firefly_state(index, at_time)
		peaks["spark"] = maxf(peaks["spark"], state.z)
		peaks["pool"] = maxf(peaks["pool"], state.z * HALO_SHARE)
	return peaks


func moving_effect_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for region: Rect2 in REGIONS:
		bounds.append(region.grow(HALO_RADIUS + 2.0))
	return bounds


func _draw_light(canvas: Node2D) -> void:
	if reduced_motion:
		return
	for index: int in range(_home_region.size()):
		var state := firefly_state(index)
		if state.z <= 0.001:
			continue
		var point := Vector2(state.x, state.y)
		draw_pool(canvas, point, HALO_RADIUS, 1.0, TINT, state.z * HALO_SHARE)
		draw_spark(canvas, point, 2.0, TINT, state.z)
