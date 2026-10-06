class_name PotionIcon
extends Control
## A potion slot: a flat vector bottle filled with the potion's colour, or an
## empty outline. Left click drinks, right click discards (owner decides).

signal activated(slot: int)
signal discard_requested(slot: int)

var slot := 0
var potion: PotionData:
	set(v):
		potion = v
		queue_redraw()
var show_hint := true
var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(40, 48)
	pivot_offset = Vector2(20, 24)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func():
		_hover = true
		queue_redraw()
		if potion:
			var hint := "\n\n[color=#%s]Click to drink · Right-click to discard[/color]" % UIStyle.TEXT_DIM.to_html(false) if show_hint else ""
			EventBus.tooltip_requested.emit(self, potion.display_name, potion.description + hint)
		else:
			EventBus.tooltip_requested.emit(self, "Empty slot", "Potions you find go here."))
	mouse_exited.connect(func():
		_hover = false
		queue_redraw()
		EventBus.tooltip_cleared.emit(self))


func _gui_input(event: InputEvent) -> void:
	if potion == null or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(slot)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		discard_requested.emit(slot)
		accept_event()


func center_global() -> Vector2:
	return global_position + size / 2


func _draw() -> void:
	var c := size / 2
	var body := Rect2(c.x - 13, c.y - 6, 26, 26)
	var neck := Rect2(c.x - 6, c.y - 18, 12, 12)
	if potion == null:
		draw_style_box(UIStyle.box(Color(1, 1, 1, 0.05), 10, Color(1, 1, 1, 0.25), 2), body)
		draw_style_box(UIStyle.box(Color(1, 1, 1, 0.05), 3, Color(1, 1, 1, 0.25), 2), neck)
		return
	var glow := 0.35 if _hover else 0.0
	if glow > 0.0:
		draw_circle(c + Vector2(0, 4), 24, Color(potion.liquid_color, glow))
	draw_style_box(UIStyle.box(UIStyle.OUTLINE, 12), body.grow(3))
	draw_style_box(UIStyle.box(UIStyle.OUTLINE, 4), neck.grow(3))
	draw_style_box(UIStyle.box(Color("#C8D6E0", 0.35), 10), body)
	draw_style_box(UIStyle.box(Color("#C8D6E0", 0.35), 3), neck)
	draw_style_box(UIStyle.box(potion.liquid_color, 9), Rect2(body.position + Vector2(2, 8), body.size - Vector2(4, 10)))
	draw_rect(Rect2(neck.position.x - 2, neck.position.y - 4, neck.size.x + 4, 5), Color("#8A6A45"))
	draw_circle(c + Vector2(-6, 6), 3, Color(1, 1, 1, 0.6))
