class_name MatchPointResultPlaque
extends Control
## Scoreboard result plate beside the board: the last court's multiplier on a
## cream enamel score strip with the return, and a strip of recent drops
## (newest first) under it. Holds nothing but what it was shown.

const PLAQUE_SIZE := Vector2(208, 164)
const RESULT_RECT := Rect2(0, 0, 208, 96)
const HISTORY_RECT := Rect2(0, 104, 208, 60)
const SCORE_RECT := Rect2(10, 26, 84, 60)
const HISTORY_LIMIT: int = 8
const CELL_SIZE := Vector2(22, 24)

## Each entry: {"tenths": int, "won": bool, "let": bool}.
var history: Array[Dictionary] = []
var _caption: Label
var _headline: Label
var _detail: Label
var _history_caption: Label
var _pop: float = 1.0
var _pop_tween: Tween


func _init() -> void:
	name = "MatchPointResultPlaque"
	size = PLAQUE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_caption = MatchPointStyle.label(self, Rect2(10, 5, 188, 18), 13, MatchPointStyle.CREAM_MUTED)
	_headline = MatchPointStyle.label(self, Rect2(102, 28, 98, 26), 20, MatchPointStyle.CREAM)
	_headline.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_detail = MatchPointStyle.label(self, Rect2(102, 56, 98, 30), 13, MatchPointStyle.BRASS_BRIGHT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.clip_text = false
	_history_caption = MatchPointStyle.label(
		self,
		Rect2(HISTORY_RECT.position + Vector2(10, 4), Vector2(188, 16)),
		12,
		MatchPointStyle.CREAM_MUTED
	)
	refresh()


## Adds a finished drop to the scoreboard. `detail` is the translated return line.
func push(tenths: int, won: bool, detail: String) -> void:
	history.push_front({"tenths": tenths, "won": won, "let": tenths == 10})
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)
	refresh()
	_detail.text = detail
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	if MotionPolicy.is_reduced() or not is_inside_tree():
		_pop = 1.0
		queue_redraw()
		return
	_pop = 0.8
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_pop, 0.8, 1.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _set_pop(value: float) -> void:
	_pop = value
	queue_redraw()


func refresh() -> void:
	if _caption == null:
		return
	_caption.text = tr("MATCH_POINT_LAST_DROP")
	_history_caption.text = tr("MATCH_POINT_HISTORY")
	if history.is_empty():
		_headline.text = tr("MATCH_POINT_READY")
		_detail.text = tr("MATCH_POINT_READY_DETAIL")
	else:
		var won: bool = history[0].won
		var headline := "MATCH_POINT_RESULT_OUT"
		if won:
			headline = "MATCH_POINT_RESULT_WIN"
		elif history[0].let:
			# A 1x court returns the stake exactly: a let, played again.
			headline = "MATCH_POINT_RESULT_LET"
		_headline.text = tr(headline)
		_headline.add_theme_color_override(
			"font_color", MatchPointStyle.WIN_INK if won else MatchPointStyle.LOSS_INK
		)
	queue_redraw()


func last_tenths() -> int:
	return int(history[0].tenths) if not history.is_empty() else -1


func _draw() -> void:
	MatchPointStyle.draw_plate(self, RESULT_RECT)
	MatchPointStyle.draw_plate(self, HISTORY_RECT)
	MatchPointStyle.draw_strip(self, SCORE_RECT)
	var score := "-" if history.is_empty() else MatchPointMath.multiplier_text(history[0].tenths)
	var score_size := int(round(34.0 * _pop))
	MatchPointStyle.draw_centered(
		self,
		score + ("" if history.is_empty() else "×"),
		SCORE_RECT.get_center(),
		score_size,
		MatchPointStyle.CREAM_INK
	)
	for index: int in range(history.size()):
		var entry: Dictionary = history[index]
		var cell := Rect2(
			HISTORY_RECT.position + Vector2(10 + index * (CELL_SIZE.x + 2.0), 26), CELL_SIZE
		)
		var tenths: int = entry.tenths
		draw_rect(cell, MatchPointStyle.court_fill(tenths))
		draw_rect(cell, MatchPointStyle.BRASS_DIM, false, 1.0)
		MatchPointStyle.draw_centered(
			self,
			MatchPointMath.multiplier_text(tenths),
			cell.get_center(),
			12,
			MatchPointStyle.court_ink(tenths)
		)
