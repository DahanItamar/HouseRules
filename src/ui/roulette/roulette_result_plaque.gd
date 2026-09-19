class_name RouletteResultPlaque
extends Control
## Winning-number plaque under the wheel: the last pocket on a large lacquer
## disc with its colour, parity and dozen, and the recent numbers as a row of
## small discs, newest first. Holds no game state beyond what it is shown.

const PLAQUE_SIZE := Vector2(242, 104)
const HISTORY_LIMIT: int = 9
const DISC_CENTER := Vector2(42, 42)
const DISC_RADIUS: float = 28.0

var math: RouletteMath
var history: Array[int] = []
var _headline: Label
var _detail: Label
var _caption: Label
var _pop: float = 1.0
var _pop_tween: Tween


func _init(table_math: RouletteMath = null) -> void:
	math = table_math
	name = "RouletteResultPlaque"
	size = PLAQUE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_headline = RouletteStyle.label(self, Rect2(84, 10, 150, 28), 24, RouletteStyle.IVORY)
	_headline.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_detail = RouletteStyle.label(self, Rect2(84, 40, 150, 20), 13, RouletteStyle.BRASS_BRIGHT)
	_caption = RouletteStyle.label(self, Rect2(10, 76, 60, 18), 11, RouletteStyle.IVORY_MUTED)
	refresh()


func push(pocket: int) -> void:
	history.push_front(pocket)
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)
	refresh()
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	if MotionPolicy.is_reduced() or not is_inside_tree():
		_pop = 1.0
		return
	_pop = 0.82
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_pop, 0.82, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _set_pop(value: float) -> void:
	_pop = value
	queue_redraw()


func refresh() -> void:
	if _headline == null:
		return
	_caption.text = tr("ROULETTE_HISTORY")
	if history.is_empty():
		_headline.text = tr("ROULETTE_WHEEL_READY")
		_detail.text = tr("ROULETTE_SINGLE_ZERO")
	else:
		var pocket := history[0]
		_headline.text = pocket_name(pocket)
		_detail.text = pocket_detail(pocket)
	queue_redraw()


func pocket_name(pocket: int) -> String:
	var colour_key := "ROULETTE_COLOR_GREEN"
	if pocket > 0:
		colour_key = "ROULETTE_COLOR_RED" if math.is_red(pocket) else "ROULETTE_COLOR_BLACK"
	return "%d  %s" % [pocket, tr(colour_key)]


func pocket_detail(pocket: int) -> String:
	if pocket == 0:
		return tr("ROULETTE_ZERO_DETAIL")
	var parity := tr("ROULETTE_NAME_EVEN") if pocket % 2 == 0 else tr("ROULETTE_NAME_ODD")
	var half := tr("ROULETTE_NAME_LOW") if pocket <= 18 else tr("ROULETTE_NAME_HIGH")
	return "%s · %s" % [parity, half]


func _draw() -> void:
	RouletteStyle.draw_plate(self, Rect2(Vector2.ZERO, size), Color(RouletteStyle.MAHOGANY, 0.95))
	var radius := DISC_RADIUS * _pop
	draw_circle(DISC_CENTER, DISC_RADIUS + 3.0, RouletteStyle.BRASS)
	if history.is_empty():
		draw_circle(DISC_CENTER, radius, RouletteStyle.MAHOGANY_RAISED)
		draw_circle(DISC_CENTER, 5.0, RouletteStyle.IVORY)
	else:
		draw_circle(DISC_CENTER, radius, RouletteStyle.pocket_color(history[0], math))
		draw_arc(
			DISC_CENTER, radius - 4.0, 0.0, TAU, 40, Color(RouletteStyle.IVORY, 0.5), 1.0, true
		)
		RouletteStyle.draw_centered(
			self, str(history[0]), DISC_CENTER, int(30 * _pop), RouletteStyle.IVORY
		)
	for index: int in range(1, history.size()):
		var at := Vector2(74 + (index - 1) * 20, 85)
		draw_circle(at, 9.0, RouletteStyle.pocket_color(history[index], math))
		draw_arc(at, 9.0, 0.0, TAU, 20, RouletteStyle.BRASS_DIM, 1.0, true)
		RouletteStyle.draw_centered(self, str(history[index]), at, 10, RouletteStyle.IVORY)
