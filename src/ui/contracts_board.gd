class_name ContractsBoard
extends Control
## The House Contracts board at reception: the three active contracts with
## progress bars and rewards, plus the most recent completions.
##
## It only reads Economy; contract progress, completion and rewards stay in
## Economy.record_round. The board sits on the left of the office so the player
## at reception, the secretary and the room controls stay visible.
##
## Each row's bar is a painted `ProgressMeter`, so it fills smoothly when a
## contract advances and lands on its final width at once under reduced motion.

signal closed

const RECT := Rect2(48, 72, 404, 372)
const SURFACE := Color("0e0b0df5")
const BRASS := Color("c8a34b")
const IVORY := Color("f1e8d8")
const MUTED := Color("b8ad9c")
const ROW_TOP: float = 66.0
const ROW_HEIGHT: float = 56.0
const BAR_WIDTH: float = 290.0
const LOG_LINES: int = 3

var _panel: Panel
var _rows: Array[Dictionary] = []
var _log_lines: Array[Label] = []
var _close: Button
var _open: bool = false


func _init() -> void:
	name = "ContractsBoard"
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_build()
	Economy.contracts_changed.connect(refresh)


func is_open() -> bool:
	return _open


func panel_rect() -> Rect2:
	return RECT


func close_button() -> Button:
	return _close


func open() -> void:
	if _panel == null:
		_build()
	refresh()
	_open = true
	visible = true
	DialoguePanel.focus_when_ready(_close)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _close.has_focus():
		_close.release_focus()
	closed.emit()


func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("back") or event.is_action_pressed("interact"):
		AudioService.play(&"confirm")
		close()
		return true
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		if event.is_action_pressed(action):
			_close.grab_focus()
			return true
	return false


## Display data for automated parity checks: one entry per active contract.
func row_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for row: Dictionary in _rows:
		if not (row.title as Label).visible:
			continue
		(
			data
			. append(
				{
					"title": (row.title as Label).text,
					"progress": (row.progress as Label).text,
					"reward": (row.reward as Label).text,
					"fill": (row.meter as ProgressMeter).shown_ratio(),
				}
			)
		)
	return data


func log_text() -> PackedStringArray:
	var lines := PackedStringArray()
	for label: Label in _log_lines:
		if label.visible and not label.text.is_empty():
			lines.append(label.text)
	return lines


func refresh() -> void:
	if _panel == null:
		return
	var contracts := Economy.contract_rows()
	for index: int in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var shown := index < contracts.size()
		for key: String in ["title", "progress", "reward", "meter"]:
			(row[key] as CanvasItem).visible = shown
		if not shown:
			continue
		var contract: Dictionary = contracts[index]
		(row.title as Label).text = tr(contract.title_key)
		(row.progress as Label).text = (
			tr("CONTRACT_BOARD_PROGRESS") % [contract.progress, contract.target]
		)
		(row.reward as Label).text = tr("CONTRACT_BOARD_REWARD") % contract.reward
		var ratio := float(contract.progress) / maxf(float(contract.target), 1.0)
		(row.meter as ProgressMeter).set_ratio(ratio)
	var entries := Economy.completion_log
	for index: int in range(_log_lines.size()):
		var label := _log_lines[index]
		if entries.is_empty():
			label.text = tr("CONTRACT_BOARD_LOG_EMPTY") if index == 0 else ""
		elif index < entries.size():
			label.text = (
				tr("CONTRACT_BOARD_LOG_LINE")
				% [tr(String(entries[index].title_key)), int(entries[index].reward)]
			)
		else:
			label.text = ""
		label.visible = not label.text.is_empty()


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "BoardPanel"
	_panel.position = RECT.position
	_panel.size = RECT.size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = Color(BRASS, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	for y: float in [8.0, RECT.size.y - 9.0]:
		_rule(Vector2(16, y), RECT.size.x - 32.0)
	var title := _label(
		tr("CONTRACT_BOARD_TITLE"), Vector2(18, 14), Vector2(368, 28), 22, IVORY, true
	)
	title.name = "BoardTitle"
	var subtitle := _label(
		tr("CONTRACT_BOARD_SUBTITLE"), Vector2(18, 40), Vector2(368, 18), 12, MUTED, false
	)
	subtitle.name = "BoardSubtitle"
	for index: int in range(Economy.CONTRACT_SLOTS):
		var top := ROW_TOP + index * ROW_HEIGHT
		var row := {
			"title": _label("", Vector2(18, top), Vector2(290, 22), 16, IVORY, false),
			"reward": _label("", Vector2(306, top), Vector2(80, 22), 16, BRASS, true),
			"meter": _meter(Vector2(18, top + 26), index),
			"progress": _label("", Vector2(316, top + 21), Vector2(70, 20), 14, MUTED, false),
		}
		(row.reward as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		(row.progress as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		(row.title as Label).name = "ContractTitle%d" % index
		_rows.append(row)
	var log_top := ROW_TOP + Economy.CONTRACT_SLOTS * ROW_HEIGHT + 2.0
	_rule(Vector2(18, log_top), RECT.size.x - 36.0)
	var log_title := _label(
		tr("CONTRACT_BOARD_LOG_TITLE"), Vector2(18, log_top + 6), Vector2(368, 18), 13, BRASS, true
	)
	log_title.name = "LogTitle"
	for index: int in range(LOG_LINES):
		var line := _label(
			"", Vector2(18, log_top + 26 + index * 16), Vector2(368, 16), 13, MUTED, false
		)
		line.name = "LogLine%d" % index
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_log_lines.append(line)
	_close = Button.new()
	_close.name = "CloseBoard"
	_close.text = tr("CONTRACT_BOARD_CLOSE") % InputRouter.glyph("back")
	_close.position = Vector2(18, RECT.size.y - 54.0)
	_close.size = Vector2(RECT.size.x - 36.0, 44)
	_close.focus_mode = Control.FOCUS_ALL
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DialoguePanel._style_button(_close)
	_close.pressed.connect(close)
	_panel.add_child(_close)
	ButtonFeedback.attach(_close)


func _label(
	text_value: String,
	at: Vector2,
	dimensions: Vector2,
	font_size: int,
	color: Color,
	display: bool
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = dimensions
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label


func _meter(at: Vector2, index: int) -> ProgressMeter:
	var meter := ProgressMeter.new()
	meter.name = "ContractFill%d" % index
	meter.position = at
	meter.size = Vector2(BAR_WIDTH, 11)
	_panel.add_child(meter)
	return meter


func _rule(at: Vector2, width: float) -> void:
	var rule := ColorRect.new()
	rule.name = "BrassRule"
	rule.color = Color(BRASS, 0.7)
	rule.position = at
	rule.size = Vector2(width, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
