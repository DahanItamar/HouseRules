class_name DeedCard
extends Control
## The end of the ladder: the Manager hands over the deed and the keys.
##
## It is raised once, the moment the House is bought, and can be reopened from
## the ledger afterwards. It states the price that was actually paid and the
## chips turned over to earn the right to pay it - no other claim is made.

signal closed

const RECT := Rect2(276, 66, 408, 408)
const MIN_TARGET: float = 44.0

var close_button: Button
var _frame: NinePatchRect
var _art: TextureRect
var _title: Label
var _line: Label
var _open: bool = false


func _init() -> void:
	name = "DeedCard"
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	if _frame == null:
		_build()


func is_open() -> bool:
	return _open


func panel_rect() -> Rect2:
	return RECT


func present(price: int, wagered: int) -> void:
	if _frame == null:
		_build()
	_title.text = tr("DEED_TITLE")
	_line.text = tr("DEED_LINE") % [HouseLevel.grouped(price), HouseLevel.short_chips(wagered)]
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


func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if (
		event.is_action_pressed("back")
		or event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		AudioService.play(&"confirm")
		close()
		return true
	return false


func _build() -> void:
	_frame = ProgressionArt.panel_frame(RECT.position, RECT.size)
	add_child(_frame)
	_art = TextureRect.new()
	_art.name = "DeedArt"
	# See ProgressionArt.icon_rect: the expand mode goes on before the texture.
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture = ProgressionArt.DEED
	_art.custom_minimum_size = Vector2.ZERO
	_art.position = Vector2(RECT.position.x + 44.0, RECT.position.y + 52.0)
	_art.size = Vector2(320, 192)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_title = _label(
		Vector2(RECT.position.x + 30.0, RECT.position.y + 20.0),
		Vector2(RECT.size.x - 60.0, 28),
		22,
		ProgressionArt.IVORY,
		true
	)
	_title.name = "DeedTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line = _label(
		Vector2(RECT.position.x + 30.0, RECT.position.y + 254.0),
		Vector2(RECT.size.x - 60.0, 64),
		Typography.SUPPORTING,
		ProgressionArt.MUTED,
		false
	)
	_line.name = "DeedLine"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = Button.new()
	close_button.name = "DeedClose"
	close_button.text = tr("DEED_CLOSE") % InputRouter.glyph("back")
	close_button.position = Vector2(RECT.position.x + 30.0, RECT.end.y - 30.0 - MIN_TARGET)
	close_button.size = Vector2(RECT.size.x - 60.0, MIN_TARGET)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DialoguePanel._style_button(close_button)
	close_button.pressed.connect(close)
	add_child(close_button)
	ButtonFeedback.attach(close_button)


func _label(
	at: Vector2, dimensions: Vector2, font_size: int, colour: Color, display: bool
) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	add_child(label)
	return label
