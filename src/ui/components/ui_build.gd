class_name UIBuild
extends RefCounted
## Small helpers so every screen is assembled from the same parts and tokens.


static func backdrop(parent: Control, dim: float = 0.35, act: int = 1) -> BiomeBackdrop:
	var bd := BiomeBackdrop.new()
	bd.act = act
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bd)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(UIStyle.BG_DEEP, dim)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(shade)
	return bd


static func top_bar(parent: Control) -> TopBar:
	var bar := TopBar.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 64
	parent.add_child(bar)
	return bar


static func label(text: String, variation: StringName = &"", size: int = 0, color: Color = Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = UIStyle.SIZE_H1) -> Label:
	var l := label(text, &"TitleLabel", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.outline_label(l, 8)
	return l


static func button(text: String, primary: bool = false, min_size: Vector2 = Vector2(220, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	return b


static func rich(text: String, size: int = UIStyle.SIZE_LARGE) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.text = text
	return r


## Full-rect CenterContainer holding a VBox; returns the VBox.
static func center_column(parent: Control, separation: int = 20, top_margin: int = 64) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = top_margin
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


## Gentle entrance: fade + rise for a list of controls, staggered.
static func stagger_in(nodes: Array, delay_step: float = 0.06) -> void:
	for i in nodes.size():
		var n: CanvasItem = nodes[i]
		n.modulate.a = 0.0
		var t := n.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(UIStyle.dur(i * delay_step))
		t.tween_property(n, "modulate:a", 1.0, UIStyle.dur(0.3))
