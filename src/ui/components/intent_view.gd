class_name IntentView
extends Control
## Enemy intent above the head: glyph + damage number (e.g. "6x3"), gently
## bobbing. Tooltip explains the move.

const SIZE := Vector2(120, 56)

var move: EnemyMoveData
var damage := 0
var hits := 0
var stunned := false
var _bob := 0.0
var _pop := 1.0:
	set(v):
		_pop = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func():
		if move or stunned:
			EventBus.tooltip_requested.emit(self, _title(), _tooltip()))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func set_intent(p_move: EnemyMoveData, p_damage: int, p_hits: int) -> void:
	var changed := p_move != move or p_damage != damage or p_hits != hits or stunned != (p_move == null)
	move = p_move
	damage = p_damage
	hits = p_hits
	stunned = p_move == null
	if changed and is_visible_in_tree():
		_pop = 0.6
		create_tween().tween_property(self, "_pop", 1.0, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta
	queue_redraw()


func _glyph() -> StringName:
	if stunned:
		return &"stun"
	return VectorIcons.INTENT_GLYPHS.get(move.intent, &"question") if move else &""


func _title() -> String:
	return "Stunned" if stunned else move.display_name


func _tooltip() -> String:
	if stunned:
		return "Skips its next action."
	var text := move.intent_tooltip if not move.intent_tooltip.is_empty() else String(EnemyMoveData.Intent.keys()[move.intent]).capitalize()
	var dmg_text := str(damage) if hits <= 1 else "%d x%d" % [damage, hits]
	return text.replace("{dmg}", "[color=#%s][b]%s[/b][/color]" % [UIStyle.DAMAGE.to_html(false), dmg_text]).replace("{times}", str(hits))


func _draw() -> void:
	var glyph := _glyph()
	if glyph == &"":
		return
	var y := sin(_bob * 2.6) * 3.0
	var color: Color = VectorIcons.INTENT_COLORS.get(glyph, Color.WHITE)
	var size_px := 40.0 * _pop
	var icon_center := Vector2(28, SIZE.y / 2 + y)
	if damage > 0:
		size_px *= clampf(0.85 + damage / 40.0, 0.85, 1.3)  # Bigger sword for bigger hits.
	VectorIcons.draw(self, glyph, icon_center, size_px, color)
	if move and VectorIcons.INTENT_SECONDARY.has(move.intent) and not stunned:
		var sec: StringName = VectorIcons.INTENT_SECONDARY[move.intent]
		VectorIcons.draw(self, sec, icon_center + Vector2(14, 12), 20, VectorIcons.INTENT_COLORS.get(sec, Color.WHITE))
	if damage > 0:
		var f := UIStyle.display_font()
		var txt := str(damage) + (("x%d" % hits) if hits > 1 else "")
		var pos := Vector2(52, SIZE.y / 2 + 10 + y)
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 7, UIStyle.OUTLINE)
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
