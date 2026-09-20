extends AmbientLayer
## Hexbound Vault: the crypt's candles flicker and a faint shimmer runs through
## the carved runes of the pillar and the alcove border. The shimmer is masked by
## the painted stone, so only the carved glyphs catch it; the tile grid, status
## panels and controls are all drawn above this layer and never touched.

const CANDLE := Color("ffae5c")
const RUNE_TINT := Color("cbb9ff")
const RUNE_SECONDS: float = 2.8
## Carved glyphs: the right pillar (below the help button) and the alcove's top
## border, above the tile grid.
const RUNE_SWEEPS: Array[Dictionary] = [
	{"rect": Rect2(872, 76, 70, 294), "vertical": true, "interval": 8.6, "phase": 1.2},
	{"rect": Rect2(283, 64, 394, 18), "vertical": false, "interval": 11.2, "phase": 5.6},
]

var _sweeps: Array[AmbientSweep] = []


func _ready() -> void:
	# Left candelabra and right wall candles, each with a quick candle flicker.
	add_pool(Vector2(206, 146), 58.0, 1.0, CANDLE, 0.075, 1.9, 0.21)
	add_pool(Vector2(845, 156), 56.0, 1.0, CANDLE, 0.075, 2.3, 0.64)
	for spec: Dictionary in RUNE_SWEEPS:
		var sweep := AmbientSweep.new()
		sweep.name = "RuneShimmer%d" % _sweeps.size()
		sweep.configure(
			spec["rect"],
			backdrop_texture,
			RUNE_TINT,
			{"vertical": spec["vertical"], "band": 0.1, "slant": 0.25}
		)
		add_child(sweep)
		_sweeps.append(sweep)
	super._ready()


func rune_strength(index: int, at_time: float = elapsed) -> float:
	if reduced_motion:
		return 0.0
	var spec: Dictionary = RUNE_SWEEPS[index]
	var local := fposmod(at_time - float(spec["phase"]), float(spec["interval"]))
	if local >= RUNE_SECONDS:
		return 0.0
	return SWEEP_ALPHA_CAP * 0.85 * sin(PI * local / RUNE_SECONDS)


func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := super.sample_alpha_peaks(at_time)
	for index: int in range(RUNE_SWEEPS.size()):
		peaks["sweep"] = maxf(peaks["sweep"], rune_strength(index, at_time))
	return peaks


func moving_effect_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for spec: Dictionary in RUNE_SWEEPS:
		bounds.append(spec["rect"])
	return bounds


func _advance() -> void:
	for index: int in range(_sweeps.size()):
		var spec: Dictionary = RUNE_SWEEPS[index]
		var local := fposmod(elapsed - float(spec["phase"]), float(spec["interval"]))
		_sweeps[index].show_progress(lerpf(-0.2, 1.2, local / RUNE_SECONDS), rune_strength(index))


func _draw_light(canvas: Node2D) -> void:
	draw_pools(canvas)
