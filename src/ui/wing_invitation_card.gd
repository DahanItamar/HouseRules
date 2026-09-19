class_name WingInvitationCard
extends Control
## The Manager's formal, one-time invitation into an unlocked wing.
##
## A flat near-black card with a double brass rule. Presenting the card records
## the invitation (OfficeState), so it is shown once per save. It sits on the
## left of the office, clear of the player at the Manager's desk.

signal accepted(wing_id: StringName)

const RECT := Rect2(48, 76, 380, 292)
const SURFACE := Color("0e0b0df8")
const BRASS := Color("c8a34b")
const IVORY := Color("f1e8d8")
const MUTED := Color("b8ad9c")

var wing_id: StringName = &""
var _panel: Panel
var _title: Label
var _body: Label
var _accept: Button
var _open: bool = false


func _init() -> void:
	name = "WingInvitationCard"
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_build()


func is_open() -> bool:
	return _open


func panel_rect() -> Rect2:
	return RECT


func accept_button() -> Button:
	return _accept


func title_text() -> String:
	return _title.text


func present(wing: StringName, threshold: int) -> void:
	if _panel == null:
		_build()
	wing_id = wing
	_title.text = tr("INVITE_WING_" + String(wing).to_upper())
	_body.text = tr("INVITE_BODY") % [tr("INVITE_WING_" + String(wing).to_upper()), threshold]
	_open = true
	visible = true
	OfficeState.record_invitation(wing)
	DialoguePanel.focus_when_ready(_accept)


func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("interact") or event.is_action_pressed("back"):
		_accept.pressed.emit()
		return true
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		if event.is_action_pressed(action):
			_accept.grab_focus()
			return true
	return false


func _on_accept() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _accept.has_focus():
		_accept.release_focus()
	AudioService.play(&"confirm")
	accepted.emit(wing_id)


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "InvitationPanel"
	_panel.position = RECT.position
	_panel.size = RECT.size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	# The inner rule completes the formal double-rule card border.
	var inner := Panel.new()
	inner.name = "InnerRule"
	inner.position = Vector2(7, 7)
	inner.size = RECT.size - Vector2(14, 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.draw_center = false
	inner_style.border_color = Color(BRASS, 0.55)
	inner_style.set_border_width_all(1)
	inner.add_theme_stylebox_override("panel", inner_style)
	_panel.add_child(inner)
	var kicker := _label(Vector2(24, 22), Vector2(332, 18), 13, BRASS, true)
	kicker.name = "Kicker"
	kicker.text = tr("INVITE_KICKER")
	_title = _label(Vector2(24, 44), Vector2(332, 40), 30, IVORY, true)
	_title.name = "WingTitle"
	var rule := ColorRect.new()
	rule.color = BRASS
	rule.position = Vector2(RECT.size.x * 0.5 - 36.0, 92)
	rule.size = Vector2(72, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
	_body = _label(Vector2(28, 104), Vector2(324, 100), 16, IVORY, false)
	_body.name = "InvitationText"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var signature := _label(Vector2(28, 204), Vector2(324, 20), 14, MUTED, true)
	signature.name = "Signature"
	signature.text = tr("INVITE_SIGNATURE")
	_accept = Button.new()
	_accept.name = "AcceptInvitation"
	_accept.text = tr("INVITE_ACCEPT") % InputRouter.glyph("interact")
	_accept.position = Vector2(24, RECT.size.y - 62.0)
	_accept.size = Vector2(RECT.size.x - 48.0, 44)
	_accept.focus_mode = Control.FOCUS_ALL
	_accept.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DialoguePanel._style_button(_accept)
	_accept.pressed.connect(_on_accept)
	_panel.add_child(_accept)
	ButtonFeedback.attach(_accept)


func _label(at: Vector2, dimensions: Vector2, font_size: int, color: Color, display: bool) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label
