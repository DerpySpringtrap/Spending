class_name EnergyOrb
extends Control
## Energy display: a glowing orb with "current/max". Pops on change, dims at 0.

var current := 0
var maximum := 3
var _pop := 1.0:
	set(v):
		_pop = v
		queue_redraw()
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(110, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func(): EventBus.tooltip_requested.emit(self, "Energy", "Spend Energy to play cards. Refills at the start of your turn."))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func set_energy(value: int, p_max: int) -> void:
	if value != current:
		_pop = 1.25
		create_tween().tween_property(self, "_pop", 1.0, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current = value
	maximum = p_max
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := 44.0 * _pop
	var lit := current > 0
	var glow := 0.25 + 0.1 * sin(_time * 2.0) if lit else 0.0
	draw_circle(c, r + 12, Color(UIStyle.ENERGY, glow))
	draw_circle(c, r + 4, UIStyle.OUTLINE)
	draw_circle(c, r, UIStyle.ENERGY.darkened(0.2 if lit else 0.75))
	draw_circle(c + Vector2(-8, -10), r * 0.55, Color(UIStyle.ENERGY.lightened(0.35), 0.5 if lit else 0.1))
	var f := UIStyle.display_font()
	var txt := "%d/%d" % [current, maximum]
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	var pos := c + Vector2(-ts.x / 2, 11)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 8, UIStyle.OUTLINE)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
