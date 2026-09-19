class_name BaccaratResultPlaque
extends Control
## Coup plaque under the title: who won, the two totals and how the hand ended
## (natural, draws), then what the player's layout returned. A flat stripe in
## the winner's colour runs down the left edge. Holds no game state.

const PLAQUE_SIZE := Vector2(276, 118)
const STRIPE_WIDTH: float = 8.0

var stripe: Color = BaccaratStyle.PLUM
var _headline: Label
var _detail: Label
var _payout: Label
var _pop: float = 1.0
var _pop_tween: Tween


func _init() -> void:
	name = "BaccaratResultPlaque"
	size = PLAQUE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_headline = BaccaratStyle.label(self, Rect2(24, 10, 240, 34), 26, BaccaratStyle.PEARL)
	_headline.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_detail = BaccaratStyle.label(self, Rect2(24, 46, 240, 22), 15, BaccaratStyle.BRASS_BRIGHT)
	_payout = BaccaratStyle.label(self, Rect2(24, 72, 240, 36), 14, BaccaratStyle.PEARL_MUTED)
	_payout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_payout.clip_text = false
	show_waiting()


func show_waiting() -> void:
	if _headline == null:
		return
	stripe = BaccaratStyle.PLUM
	_headline.text = tr("BACCARAT_PLACE_YOUR_BETS")
	_detail.text = tr("BACCARAT_TABLE_RULE")
	_payout.text = tr("BACCARAT_TABLE_PRICES")
	_payout.add_theme_color_override("font_color", BaccaratStyle.PEARL_MUTED)
	queue_redraw()


func show_dealing() -> void:
	if _headline == null:
		return
	stripe = BaccaratStyle.PLUM
	_headline.text = tr("BACCARAT_NO_MORE_BETS")
	_detail.text = tr("BACCARAT_DEALING_DETAIL")
	_payout.text = ""
	queue_redraw()


## The coup's cards are all face up: name the winner and how the hand ended.
func show_coup(coup: Dictionary) -> void:
	if _headline == null:
		return
	var winner: int = coup.winner
	stripe = BaccaratStyle.winner_color(winner)
	_headline.text = headline_for(winner)
	_detail.text = detail_for(coup)
	_payout.text = ""
	_pop_in()
	queue_redraw()


func show_payout(text: String, won: bool) -> void:
	if _payout == null:
		return
	_payout.text = text
	_payout.add_theme_color_override(
		"font_color", BaccaratStyle.WIN_INK if won else BaccaratStyle.LOSS_INK
	)


func headline_for(winner: int) -> String:
	match winner:
		BaccaratRules.Winner.PLAYER:
			return tr("BACCARAT_PLAYER_WINS")
		BaccaratRules.Winner.BANKER:
			return tr("BACCARAT_BANKER_WINS")
	return tr("BACCARAT_TIE_RESULT")


func detail_for(coup: Dictionary) -> String:
	var player: int = coup.player_total
	var banker: int = coup.banker_total
	var text := ""
	match int(coup.winner):
		BaccaratRules.Winner.PLAYER:
			text = tr("BACCARAT_OVER") % [player, banker]
		BaccaratRules.Winner.BANKER:
			text = tr("BACCARAT_OVER") % [banker, player]
		_:
			text = tr("BACCARAT_BOTH") % player
	if coup.natural:
		text += " · " + tr("BACCARAT_NATURAL")
	if coup.player_pair or coup.banker_pair:
		text += " · " + tr("BACCARAT_PAIR_TAG")
	return text


func headline_text() -> String:
	return _headline.text if _headline != null else ""


func _pop_in() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	if MotionPolicy.is_reduced() or not is_inside_tree():
		_pop = 1.0
		_headline.scale = Vector2.ONE
		return
	_headline.pivot_offset = Vector2(0, 17)
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_pop, 0.86, 1.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _set_pop(value: float) -> void:
	_pop = value
	_headline.scale = Vector2.ONE * value


func _draw() -> void:
	BaccaratStyle.draw_plate(self, Rect2(Vector2.ZERO, size), Color(BaccaratStyle.LACQUER, 0.95))
	draw_rect(Rect2(Vector2(8, 10), Vector2(STRIPE_WIDTH, size.y - 20)), stripe)
