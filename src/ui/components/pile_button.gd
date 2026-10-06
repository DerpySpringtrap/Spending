class_name PileButton
extends Button
## Draw / discard / exhaust pile: a little stack of card backs with a count.
## Click (or its shortcut) to open the pile viewer.

var pile_name := "Draw"
var count := 0:
	set(v):
		if v != count:
			count = v
			_bump()
		queue_redraw()
var accent := UIStyle.GOLD
var _bump_scale := 1.0:
	set(v):
		_bump_scale = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(96, 112)
	flat = true
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _ready() -> void:
	mouse_entered.connect(func(): EventBus.tooltip_requested.emit(self, "%s pile" % pile_name, tooltip_body()))
	mouse_exited.connect(func(): EventBus.tooltip_cleared.emit(self))


func tooltip_body() -> String:
	return "%d card%s. Click to view." % [count, "" if count == 1 else "s"]


func center_global() -> Vector2:
	return global_position + size / 2


func _bump() -> void:
	_bump_scale = 1.2
	create_tween().tween_property(self, "_bump_scale", 1.0, UIStyle.dur(0.18)).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	var c := size / 2 + Vector2(0, -8)
	var card := Vector2(54, 72) * _bump_scale
	var layers := mini(3, maxi(count, 1))
	for i in layers:
		var off := Vector2(-4 + i * 4, 4 - i * 4)
		var rect := Rect2(c - card / 2 + off, card)
		draw_style_box(UIStyle.box(UIStyle.PANEL_HI if count > 0 else UIStyle.PANEL, 7, UIStyle.OUTLINE, 2), rect)
		if i == layers - 1 and count > 0:
			draw_style_box(UIStyle.box(Color.TRANSPARENT, 5, accent.darkened(0.35), 2), rect.grow(-6))
	var f := UIStyle.display_font()
	var txt := str(count)
	var badge := c + Vector2(card.x / 2 - 2, card.y / 2 - 4)
	draw_circle(badge, 17, UIStyle.OUTLINE)
	draw_circle(badge, 15, accent.darkened(0.25))
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(f, badge + Vector2(-ts.x / 2, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.BG_DEEP)
	var lf := UIStyle.bold_font()
	var ls := lf.get_string_size(pile_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string_outline(lf, Vector2(size.x / 2 - ls.x / 2, size.y - 2), pile_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, UIStyle.OUTLINE)
	draw_string(lf, Vector2(size.x / 2 - ls.x / 2, size.y - 2), pile_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.TEXT_DIM)
