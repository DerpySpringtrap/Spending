class_name HealthBar
extends Control
## HP bar with smooth depletion and a lagging "ghost" bar that shows how much
## was just lost. Turns blue while the owner has Block, with a shield badge.

const BAR_HEIGHT := 20.0

var max_hp := 1
var _shown_hp := 1.0:
	set(v):
		_shown_hp = v
		queue_redraw()
var _ghost_hp := 1.0:
	set(v):
		_ghost_hp = v
		queue_redraw()
var _target_hp := 1
var _block := 0
var _badge_scale := 0.0:
	set(v):
		_badge_scale = v
		queue_redraw()
var _tween: Tween
var _ghost_tween: Tween
var _badge_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(190, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(hp: int, p_max_hp: int, block: int = 0) -> void:
	max_hp = maxi(p_max_hp, 1)
	_target_hp = hp
	_shown_hp = hp
	_ghost_hp = hp
	set_block(block, false)


func set_hp(hp: int, p_max_hp: int, animate: bool = true) -> void:
	max_hp = maxi(p_max_hp, 1)
	var lost := hp < _target_hp
	_target_hp = hp
	if not animate:
		_shown_hp = hp
		_ghost_hp = hp
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_shown_hp", float(hp), UIStyle.dur(0.22)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	if lost:
		_ghost_tween.tween_interval(UIStyle.dur(0.4))
		_ghost_tween.tween_property(self, "_ghost_hp", float(hp), UIStyle.dur(0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		_ghost_tween.tween_property(self, "_ghost_hp", float(hp), UIStyle.dur(0.22))


func set_block(block: int, animate: bool = true) -> void:
	var gained := block > _block
	_block = block
	if _badge_tween:
		_badge_tween.kill()
	if not animate:
		_badge_scale = 1.0 if block > 0 else 0.0
		return
	_badge_tween = create_tween()
	if block > 0:
		if gained:
			_badge_scale = 0.4 if _badge_scale < 0.5 else _badge_scale
			_badge_tween.tween_property(self, "_badge_scale", 1.3, UIStyle.dur(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_badge_tween.tween_property(self, "_badge_scale", 1.0, UIStyle.dur(0.12))
		else:
			_badge_tween.tween_property(self, "_badge_scale", 1.0, UIStyle.dur(0.1))
	else:
		_badge_tween.tween_property(self, "_badge_scale", 0.0, UIStyle.dur(0.15)).set_ease(Tween.EASE_IN)
	queue_redraw()


func get_shown_hp() -> int:
	return _target_hp


func get_shown_block() -> int:
	return _block


func _draw() -> void:
	var bar := Rect2(Vector2(0, (size.y - BAR_HEIGHT) / 2), Vector2(size.x, BAR_HEIGHT))
	draw_style_box(UIStyle.box(UIStyle.OUTLINE, 7), bar.grow(2))
	draw_style_box(UIStyle.box(Color("#2A1F24"), 6), bar)
	var ghost_w := bar.size.x * clampf(_ghost_hp / max_hp, 0.0, 1.0)
	if ghost_w > 1.0:
		draw_style_box(UIStyle.box(UIStyle.HP_GHOST, 6), Rect2(bar.position, Vector2(ghost_w, bar.size.y)))
	var hp_w := bar.size.x * clampf(_shown_hp / max_hp, 0.0, 1.0)
	if hp_w > 1.0:
		var color := UIStyle.HP_BAR_BLOCKED if _block > 0 else UIStyle.HP_BAR
		draw_style_box(UIStyle.box(color, 6), Rect2(bar.position, Vector2(hp_w, bar.size.y)))
		draw_rect(Rect2(bar.position + Vector2(4, 3), Vector2(maxf(hp_w - 8, 0), 4)), Color(1, 1, 1, 0.18))
	var font := UIStyle.heavy_font()
	var text := "%d / %d" % [_target_hp, max_hp]
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	var text_pos := Vector2(bar.get_center().x - text_size.x / 2, bar.get_center().y + 5)
	draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UIStyle.OUTLINE)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.TEXT)
	if _badge_scale > 0.01:
		var c := Vector2(-6, bar.get_center().y)
		var s := 38.0 * _badge_scale
		VectorIcons.draw(self, &"shield", c, s, UIStyle.BLOCK, UIStyle.OUTLINE)
		var btxt := str(_block)
		var bsize := font.get_string_size(btxt, HORIZONTAL_ALIGNMENT_CENTER, -1, int(18 * _badge_scale))
		var bpos := c + Vector2(-bsize.x / 2, 6 * _badge_scale)
		draw_string_outline(font, bpos, btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _badge_scale), 4, UIStyle.OUTLINE)
		draw_string(font, bpos, btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _badge_scale), Color.WHITE)
