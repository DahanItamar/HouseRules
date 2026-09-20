class_name StatsPanel
extends Control
## The House Ledger: what actually happened, read back to the player.
##
## Two views. OVERVIEW is the session and lifetime record - net, chips staked
## and returned, the best single win, the longest run of winning rounds, rounds
## played, the cabinet played most and the time at the tables. CABINETS breaks
## the same numbers down per machine so the player can see which one has been
## treating them well.
##
## Every figure is read from the save the cabinets already write, so nothing
## here can be inflated: net is returned minus staked, and a negative net is
## stated plainly in a muted red rather than dressed up.

signal closed

enum View { OVERVIEW, CABINETS }

const RECT := Rect2(230, 58, 500, 424)
const VIEW_KEYS: Array[String] = ["LEDGER_VIEW_OVERVIEW", "LEDGER_VIEW_CABINETS"]
const ROW_HEIGHT: float = 26.0
const ROW_TOP: float = 142.0
const MAX_ROWS: int = 8
const MIN_TARGET: float = 44.0
const INSET: float = 26.0

var view: int = View.OVERVIEW
var tabs: Array[Button] = []
var close_button: Button

var _frame: NinePatchRect
var _title: Label
var _standing: Label
var _standing_medallion: TextureRect
var _standing_meter: ProgressMeter
var _rows: Array[Dictionary] = []
var _empty: Label
var _open: bool = false


func _init() -> void:
	name = "StatsPanel"
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	if _frame == null:
		_build()
	Progression.standing_changed.connect(refresh)


func is_open() -> bool:
	return _open


func panel_rect() -> Rect2:
	return RECT


func open(start_view: int = View.OVERVIEW) -> void:
	if _frame == null:
		_build()
	select_view(start_view)
	_open = true
	visible = true
	DialoguePanel.focus_when_ready(close_button)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Control and is_ancestor_of(focused):
		(focused as Control).release_focus()
	closed.emit()


func select_view(index: int) -> void:
	view = posmod(index, VIEW_KEYS.size())
	for tab_index: int in range(tabs.size()):
		_style_tab(tabs[tab_index], tab_index == view)
	refresh()


func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("back"):
		AudioService.play(&"confirm")
		close()
		return true
	if event.is_action_pressed("move_left"):
		select_view(view - 1)
		AudioService.play(&"move")
		return true
	if event.is_action_pressed("move_right"):
		select_view(view + 1)
		AudioService.play(&"move")
		return true
	if event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and is_ancestor_of(focused):
			focused.pressed.emit()
		else:
			close()
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		close_button.grab_focus()
		return true
	return false


## The rows on screen, for automated parity against the save.
func row_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for row: Dictionary in _rows:
		if not (row.label as Label).visible:
			continue
		data.append({"label": (row.label as Label).text, "value": (row.value as Label).text})
	return data


func refresh() -> void:
	if _frame == null:
		return
	var stats := Progression.stats()
	var index := Progression.tier_index()
	_standing_medallion.texture = ProgressionArt.medallion(index)
	_standing.text = (
		tr("LEDGER_STANDING")
		% [
			tr(String(HouseLevel.TIERS[index].name_key)),
			HouseLevel.short_chips(Progression.wagered()),
		]
	)
	_standing_meter.set_ratio(Progression.tier_ratio())
	var lines: Array[Dictionary] = (
		_overview_lines(stats) if view == View.OVERVIEW else _cabinet_lines(stats)
	)
	for row_index: int in range(_rows.size()):
		var row: Dictionary = _rows[row_index]
		var shown := row_index < lines.size()
		(row.label as Label).visible = shown
		(row.value as Label).visible = shown
		(row.icon as TextureRect).visible = shown
		if not shown:
			continue
		var line: Dictionary = lines[row_index]
		(row.label as Label).text = String(line.label)
		(row.value as Label).text = String(line.value)
		(row.value as Label).add_theme_color_override(
			"font_color", line.get("colour", ProgressionArt.IVORY)
		)
		(row.icon as TextureRect).texture = ProgressionArt.icon(StringName(line.icon))
	_empty.visible = lines.is_empty()
	_empty.text = tr("LEDGER_EMPTY")


func _overview_lines(stats: PlayerStats) -> Array[Dictionary]:
	if not stats.has_history():
		return []
	var net := stats.net()
	var lines: Array[Dictionary] = [
		{
			"icon": &"up" if net >= 0 else &"down",
			"label": tr("LEDGER_NET"),
			"value": _signed(net),
			"colour": ProgressionArt.BRASS if net >= 0 else ProgressionArt.DOWN,
		},
		{"icon": &"coin", "label": tr("LEDGER_RETURNED"), "value": _chips(stats.returned)},
		{"icon": &"chips", "label": tr("LEDGER_STAKED"), "value": _chips(stats.staked)},
		{"icon": &"laurel", "label": tr("LEDGER_BEST_WIN"), "value": _chips(stats.best_win)},
		{
			"icon": &"flame",
			"label": tr("LEDGER_STREAK"),
			"value": tr("LEDGER_ROUNDS_VALUE") % stats.longest_streak,
		},
		{
			"icon": &"cabinet",
			"label": tr("LEDGER_ROUNDS"),
			"value": tr("LEDGER_ROUNDS_VALUE") % stats.rounds,
		},
		{
			"icon": &"cabinet",
			"label": tr("LEDGER_FAVOURITE"),
			"value": _cabinet_name(stats.favourite_id),
		},
		{"icon": &"clock", "label": tr("LEDGER_PLAYED"), "value": stats.played_text()},
	]
	return lines


func _cabinet_lines(stats: PlayerStats) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for row: Dictionary in stats.rows:
		if lines.size() >= MAX_ROWS:
			break
		var net: int = int(row.net)
		(
			lines
			. append(
				{
					"icon": &"up" if net >= 0 else &"down",
					"label":
					tr("LEDGER_CABINET_ROW") % [_cabinet_name(StringName(row.id)), int(row.rounds)],
					"value": _signed(net),
					"colour": ProgressionArt.BRASS if net >= 0 else ProgressionArt.DOWN,
				}
			)
		)
	return lines


func _cabinet_name(cabinet_id: StringName) -> String:
	if cabinet_id == &"":
		return tr("LEDGER_NONE")
	var definition := load("res://data/cabinets/%s.tres" % cabinet_id) as CabinetDefinition
	return tr(definition.name_key) if definition != null else String(cabinet_id)


func _chips(amount: int) -> String:
	return tr("LEDGER_CHIPS") % HouseLevel.grouped(amount)


## Net is always signed, so a win and a loss can never be misread.
func _signed(amount: int) -> String:
	if amount < 0:
		return tr("LEDGER_CHIPS") % HouseLevel.grouped(amount)
	return tr("LEDGER_CHIPS_UP") % HouseLevel.grouped(amount)


# --- Construction ---------------------------------------------------------------


func _build() -> void:
	_frame = ProgressionArt.panel_frame(RECT.position, RECT.size)
	add_child(_frame)
	var left := RECT.position.x + INSET
	var width := RECT.size.x - INSET * 2.0
	_title = _label(
		tr("LEDGER_TITLE"),
		Vector2(left, RECT.position.y + 20.0),
		Vector2(width, 28),
		20,
		ProgressionArt.IVORY,
		true
	)
	_title.name = "LedgerTitle"
	_standing_medallion = ProgressionArt.icon_rect(
		&"coin", Vector2(left, RECT.position.y + 52.0), 30.0
	)
	_standing_medallion.name = "LedgerMedallion"
	add_child(_standing_medallion)
	_standing = _label(
		"",
		Vector2(left + 38.0, RECT.position.y + 52.0),
		Vector2(width - 38.0, 20),
		Typography.SUPPORTING,
		ProgressionArt.MUTED,
		false
	)
	_standing.name = "LedgerStanding"
	_standing_meter = ProgressMeter.new()
	_standing_meter.name = "LedgerMeter"
	_standing_meter.position = Vector2(left + 38.0, RECT.position.y + 72.0)
	_standing_meter.size = Vector2(width - 38.0, 10)
	add_child(_standing_meter)
	var tab_width := (width - 8.0) / 2.0
	for index: int in range(VIEW_KEYS.size()):
		var tab := _button(
			tr(VIEW_KEYS[index]),
			Vector2(left + index * (tab_width + 8.0), RECT.position.y + 92.0),
			Vector2(tab_width, MIN_TARGET)
		)
		tab.name = "LedgerTab%d" % index
		tab.pressed.connect(select_view.bind(index))
		tabs.append(tab)
	for index: int in range(MAX_ROWS):
		var top := RECT.position.y + ROW_TOP + index * ROW_HEIGHT
		var row := {
			"icon": ProgressionArt.icon_rect(&"coin", Vector2(left, top + 2.0), 22.0),
			"label":
			_label(
				"",
				Vector2(left + 30.0, top),
				Vector2(width - 160.0, 24),
				Typography.SUPPORTING,
				ProgressionArt.MUTED,
				false
			),
			"value":
			_label(
				"",
				Vector2(left + width - 130.0, top),
				Vector2(130, 24),
				Typography.CONTROL,
				ProgressionArt.IVORY,
				true
			),
		}
		(row.label as Label).name = "LedgerRowLabel%d" % index
		(row.value as Label).name = "LedgerRowValue%d" % index
		(row.value as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		(row.label as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(row.icon)
		_rows.append(row)
	_empty = _label(
		"",
		Vector2(left, RECT.position.y + ROW_TOP + 16.0),
		Vector2(width, 40),
		Typography.SUPPORTING,
		ProgressionArt.MUTED,
		false
	)
	_empty.name = "LedgerEmpty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = _button(
		tr("LEDGER_CLOSE") % InputRouter.glyph("back"),
		Vector2(left, RECT.end.y - INSET - MIN_TARGET),
		Vector2(width, MIN_TARGET)
	)
	close_button.name = "LedgerClose"
	close_button.pressed.connect(close)
	select_view(View.OVERVIEW)


func _label(
	text_value: String,
	at: Vector2,
	dimensions: Vector2,
	font_size: int,
	colour: Color,
	display: bool
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = dimensions
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	add_child(label)
	return label


func _button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = dimensions
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DialoguePanel._style_button(button)
	add_child(button)
	ButtonFeedback.attach(button)
	return button


func _style_tab(tab: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a2c16") if active else Color("181316")
	style.border_color = ProgressionArt.BRASS if active else ProgressionArt.BRASS_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	tab.add_theme_stylebox_override("normal", style)
	tab.add_theme_color_override(
		"font_color", ProgressionArt.IVORY if active else ProgressionArt.MUTED
	)
