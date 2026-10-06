extends CanvasLayer
## Global tooltip (autoload: TooltipLayer).
##
## Any control shows a tooltip with
##   EventBus.tooltip_requested.emit(self, "Title", "Body with [b]BBCode[/b]")
## and hides it with EventBus.tooltip_cleared.emit(self). Works for mouse hover
## and keyboard/gamepad focus alike. Positioned beside the owner, flipped at
## screen edges.

const SHOW_DELAY := 0.25
const MAX_WIDTH := 340.0
const GAP := 12.0

var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _owner: Control
var _timer: SceneTreeTimer


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.BG_DEEP, 0.97), UIStyle.RADIUS_SMALL, UIStyle.GOLD.darkened(0.45), 2, 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_override("font", UIStyle.display_font())
	_title.add_theme_font_size_override("font_size", UIStyle.SIZE_LARGE)
	_title.add_theme_color_override("font_color", UIStyle.GOLD)
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(MAX_WIDTH - 24, 0)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)
	EventBus.tooltip_requested.connect(_on_requested)
	EventBus.tooltip_cleared.connect(_on_cleared)


func _on_requested(owner: Control, title: String, body: String) -> void:
	if title.is_empty() and body.is_empty():
		_on_cleared(_owner)
		return
	_owner = owner
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_panel.visible = false
	_timer = get_tree().create_timer(SHOW_DELAY, true, false, true)
	var timer := _timer
	var owner_id := owner.get_instance_id()
	timer.timeout.connect(func():
		if timer == _timer and is_instance_valid(_owner) and _owner.get_instance_id() == owner_id:
			_show())


## [param owner] null clears whatever tooltip is showing.
func _on_cleared(owner: Control) -> void:
	if owner == null or owner == _owner:
		_owner = null
		_timer = null
		_panel.visible = false


func _show() -> void:
	_panel.reset_size()
	_panel.visible = true
	_panel.modulate.a = 0.0
	await get_tree().process_frame  # Let the panel size itself to the text.
	if not is_instance_valid(_owner) or not _owner.is_visible_in_tree():
		_panel.visible = false
		return
	var viewport := _panel.get_viewport_rect().size
	var rect := _owner.get_global_rect()
	var size := _panel.size
	var pos := Vector2(rect.end.x + GAP, rect.position.y)
	if pos.x + size.x > viewport.x:
		pos.x = rect.position.x - GAP - size.x
	if pos.x < 0:
		pos = Vector2(rect.get_center().x - size.x / 2, rect.position.y - size.y - GAP)
	pos.x = clampf(pos.x, 8, viewport.x - size.x - 8)
	pos.y = clampf(pos.y, 8, viewport.y - size.y - 8)
	_panel.position = pos
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.1)
