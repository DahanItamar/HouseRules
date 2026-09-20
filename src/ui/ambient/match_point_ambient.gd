extends AmbientLayer
## Match Point: slow cloud shadows drift across the grass court seen through the
## clubhouse window. The shade is cut to the window glass, so it never darkens
## the frame, the plinko board, the panels or the hostess.

const SHADOW := Color("0a1606")
## The lower window glass (lawn, hedges and court) in cabinet space.
const WINDOW := Rect2(52, 150, 164, 212)
const CLOUDS: Array[Dictionary] = [
	{"y": 232.0, "radius": 78.0, "speed": 3.4, "offset": 0.1, "alpha": 0.065},
	{"y": 292.0, "radius": 92.0, "speed": 2.7, "offset": 0.55, "alpha": 0.07},
	{"y": 340.0, "radius": 66.0, "speed": 4.1, "offset": 0.83, "alpha": 0.06},
]
const SQUASH: float = 0.38


## Cloud `index` centre at `at_time`. Reduced motion holds each at its rest spot.
func cloud_center(index: int, at_time: float = elapsed) -> Vector2:
	var cloud: Dictionary = CLOUDS[index]
	var radius: float = cloud["radius"]
	var travel := WINDOW.size.x + radius * 2.0
	var along: float = float(cloud["offset"]) * travel
	if not reduced_motion:
		along = fposmod(along + at_time * float(cloud["speed"]), travel)
	return Vector2(WINDOW.position.x - radius + along, float(cloud["y"]))


func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := super.sample_alpha_peaks(at_time)
	for cloud: Dictionary in CLOUDS:
		peaks["shadow"] = maxf(peaks["shadow"], minf(float(cloud["alpha"]), SHADOW_ALPHA_CAP))
	return peaks


func moving_effect_bounds() -> Array[Rect2]:
	return [WINDOW]


func _draw_shade(canvas: Node2D) -> void:
	for index: int in range(CLOUDS.size()):
		var cloud: Dictionary = CLOUDS[index]
		draw_pool_clipped(
			canvas,
			cloud_center(index),
			float(cloud["radius"]),
			SQUASH,
			SHADOW,
			minf(float(cloud["alpha"]), SHADOW_ALPHA_CAP),
			WINDOW
		)
