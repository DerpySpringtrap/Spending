class_name MapNodeButton
extends Control
## One node on the act map: a disc with the room glyph. Pulses when you can
## travel there, shows a check once visited, hides behind "?" in the fog.

signal chosen(node_id: String)

const INFO := {
	"monster": {"glyph": &"sword", "color": Color("#C9C2B8"), "name": "Enemy", "desc": "A fight. Win to earn gold and a card."},
	"elite": {"glyph": &"horns", "color": Color("#E0453A"), "name": "Elite", "desc": "A dangerous foe. Guaranteed relic."},
	"rest": {"glyph": &"campfire", "color": Color("#F0A040"), "name": "Rest Site", "desc": "Heal, or upgrade a card."},
	"shop": {"glyph": &"coin", "color": Color("#F6D743"), "name": "Merchant", "desc": "Buy cards, relics and potions, or remove a card."},
	"treasure": {"glyph": &"chest", "color": Color("#D9A441"), "name": "Treasure", "desc": "A chest with a relic inside."},
	"event": {"glyph": &"question", "color": Color("#7BE0C8"), "name": "Unknown", "desc": "Something strange awaits."},
	"boss": {"glyph": &"skull", "color": Color("#B07CE0"), "name": "Boss", "desc": "The Drowned Matriarch."},
}

var node_id := ""
var node_type := "monster"
var reachable := false
var visited := false
var current := false
var fogged := false
var _hover := false
var _time := 0.0


func setup(id: String, type: String, is_boss_size: bool) -> MapNodeButton:
	node_id = id
	node_type = type
	var s := 150.0 if is_boss_size else 64.0
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)
	pivot_offset = size / 2
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL if reachable else Control.FOCUS_NONE
	mouse_entered.connect(func():
		_hover = true
		var info: Dictionary = INFO.get(node_type, INFO.monster)
		if fogged:
			EventBus.tooltip_requested.emit(self, "Unexplored", "Get closer to see what's here.")
		else:
			EventBus.tooltip_requested.emit(self, info.name, info.desc))
	mouse_exited.connect(func():
		_hover = false
		EventBus.tooltip_cleared.emit(self))
	focus_entered.connect(func(): _hover = true)
	focus_exited.connect(func(): _hover = false)


func _gui_input(event: InputEvent) -> void:
	if not reachable:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		accept_event()
		chosen.emit(node_id)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var info: Dictionary = INFO.get(node_type, INFO.monster)
	var c := size / 2
	var r := size.x * 0.42
	var color: Color = info.color
	var pulse := (sin(_time * 4.0) * 0.5 + 0.5) if reachable else 0.0
	if _hover and reachable:
		r *= 1.15
	if reachable:
		draw_circle(c, r + 10 + pulse * 6, Color(UIStyle.GOLD, 0.18 + pulse * 0.2))
	draw_circle(c, r + 3, UIStyle.OUTLINE)
	var disc := UIStyle.PANEL_HI if not visited else UIStyle.PANEL
	draw_circle(c, r, disc)
	if current:
		draw_arc(c, r + 1, 0, TAU, 40, UIStyle.GOLD, 4.0)
	elif reachable:
		draw_arc(c, r + 1, 0, TAU, 40, UIStyle.GOLD.lerp(Color.WHITE, pulse * 0.4), 3.0)
	if fogged:
		VectorIcons.draw(self, &"question", c, r * 1.1, Color(1, 1, 1, 0.25), Color.TRANSPARENT)
		return
	var glyph_color := color if not visited else color.darkened(0.55)
	VectorIcons.draw(self, info.glyph, c, r * 1.25, glyph_color)
	if visited and not current:
		draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, 0), c + Vector2(-r * 0.1, r * 0.35), c + Vector2(r * 0.5, -r * 0.35)]), UIStyle.HEAL, 5.0)
