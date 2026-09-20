class_name CoreOverclockBurst
extends Node2D
## Spray, spindrift and smoke, cut from the painted break-up sheet.
##
## `sparks()` throws a handful of spray off the head of the line when a run is
## hauled in or when the sea takes it; `puff()` puts one spindrift cloud or smoke
## roll on the screen for the launch, the haul and the break-up. Both are finite:
## every particle has a life and the node is empty again when they end.
##
## Reduced motion shows neither - the number, the deck and the recent-runs strip
## carry the same information without anything flying across the screen.

const SPARK_SECONDS: float = 1.0
const SPARK_GRAVITY: float = 520.0
const SPARK_SIZE: float = 26.0
const PUFF_SECONDS: float = 0.6
const BURST_SEED: int = 4531

var _sparks: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "CoreOverclockBurst"
	_rng.seed = BURST_SEED


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


## A handful of spray thrown up out of `origin`.
func sparks(origin: Vector2, count: int) -> void:
	if MotionPolicy.is_reduced():
		return
	for _index: int in range(count):
		var angle := _rng.randf_range(-PI * 0.9, -PI * 0.1)
		var speed := _rng.randf_range(130.0, 300.0)
		var cell: int = CoreOverclockTheme.EMBER_SPARKS[_rng.randi_range(
			0, CoreOverclockTheme.EMBER_SPARKS.size() - 1
		)]
		(
			_sparks
			. append(
				{
					"at": origin,
					"velocity": Vector2(cos(angle), sin(angle)) * speed,
					"spin": _rng.randf_range(-5.0, 5.0),
					"turn": _rng.randf_range(0.0, TAU),
					"cell": cell,
					"left": SPARK_SECONDS,
				}
			)
		)
	queue_redraw()


## One spindrift cloud or smoke roll from the sheet, centred on `origin`.
func puff(origin: Vector2, cell: int, width: float, seconds: float = PUFF_SECONDS) -> void:
	if MotionPolicy.is_reduced():
		return
	_puffs.append({"at": origin, "cell": cell, "width": width, "left": seconds, "span": seconds})
	queue_redraw()


func is_busy() -> bool:
	return not _sparks.is_empty() or not _puffs.is_empty()


func clear() -> void:
	_sparks.clear()
	_puffs.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_busy():
		return
	var alive: Array[Dictionary] = []
	for spark: Dictionary in _sparks:
		spark["left"] = float(spark["left"]) - delta
		if float(spark["left"]) <= 0.0:
			continue
		spark["velocity"] = (spark["velocity"] as Vector2) + Vector2(0.0, SPARK_GRAVITY * delta)
		spark["at"] = (spark["at"] as Vector2) + (spark["velocity"] as Vector2) * delta
		spark["turn"] = float(spark["turn"]) + float(spark["spin"]) * delta
		alive.append(spark)
	_sparks = alive
	var drifting: Array[Dictionary] = []
	for item: Dictionary in _puffs:
		item["left"] = float(item["left"]) - delta
		item["at"] = (item["at"] as Vector2) + Vector2(0.0, -26.0 * delta)
		if float(item["left"]) > 0.0:
			drifting.append(item)
	_puffs = drifting
	queue_redraw()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		clear()


func _draw() -> void:
	for item: Dictionary in _puffs:
		var progress := 1.0 - float(item["left"]) / float(item["span"])
		var width := float(item["width"]) * (0.6 + progress * 0.6)
		var alpha := 1.0 - progress * progress
		draw_texture_rect_region(
			CoreOverclockTheme.EMBERS,
			Rect2((item["at"] as Vector2) - Vector2.ONE * width * 0.5, Vector2.ONE * width),
			CoreOverclockTheme.sheet_region(
				int(item["cell"]), CoreOverclockTheme.EMBER_GRID, CoreOverclockTheme.EMBER_CELL
			),
			Color(1.0, 1.0, 1.0, alpha)
		)
	for spark: Dictionary in _sparks:
		var fade := clampf(float(spark["left"]) / (SPARK_SECONDS * 0.45), 0.0, 1.0)
		draw_set_transform(spark["at"] as Vector2, float(spark["turn"]), Vector2.ONE)
		draw_texture_rect_region(
			CoreOverclockTheme.EMBERS,
			Rect2(Vector2.ONE * -SPARK_SIZE * 0.5, Vector2.ONE * SPARK_SIZE),
			CoreOverclockTheme.sheet_region(
				int(spark["cell"]), CoreOverclockTheme.EMBER_GRID, CoreOverclockTheme.EMBER_CELL
			),
			Color(1.0, 1.0, 1.0, fade)
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
