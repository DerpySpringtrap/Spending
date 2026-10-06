class_name CardView
extends Control
## A card, drawn as flat vector art. Rarity-coloured frame, type-coloured body,
## cost orb, name, type line and a live description (BBCode from CardText).
##
## Visual states: affordable/dimmed, glowing (ready to play), selected,
## face-down (pile animations). Hover/press are reported to the owner
## (HandView, PileViewer) through signals; this node never plays cards itself.

signal hovered(view: CardView)
signal unhovered(view: CardView)
signal pressed(view: CardView, event: InputEventMouseButton)

const SIZE := Vector2(200, 280)
const ART_RECT := Rect2(14, 38, 172, 104)
const ORB_CENTER := Vector2(22, 22)
const ORB_RADIUS := 21.0

var card: CardInstance
var affordable := true:
	set(v):
		if affordable != v:
			affordable = v
			_update_cost_label()
			queue_redraw()
var glowing := false:
	set(v):
		if glowing != v:
			glowing = v
			queue_redraw()
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()
var face_down := false:
	set(v):
		face_down = v
		_set_text_visible(not v)
		queue_redraw()
## Shown cost (may differ from the printed one).
var display_cost := 0

var _name: Label
var _type: Label
var _desc: RichTextLabel
var _cost: Label
var _sparkle: GPUParticles2D
var _upgrade_flash := 0.0:
	set(v):
		_upgrade_flash = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2, SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_build()
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))
	if card:
		_apply_card()


func setup(p_card: CardInstance) -> CardView:
	card = p_card
	if is_inside_tree():
		_apply_card()
	return self


func set_description(bbcode: String) -> void:
	if _desc:
		_desc.text = "[center]%s[/center]" % bbcode


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		pressed.emit(self, event)
		accept_event()


# --- Building -----------------------------------------------------------------

func _build() -> void:
	_name = Label.new()
	_name.position = Vector2(40, 8)
	_name.size = Vector2(SIZE.x - 54, 26)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.add_theme_font_override("font", UIStyle.display_font())
	_name.add_theme_font_size_override("font_size", 17)
	UIStyle.outline_label(_name, 5)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	_type = Label.new()
	_type.position = Vector2(14, ART_RECT.end.y + 2)
	_type.size = Vector2(SIZE.x - 28, 18)
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type.add_theme_font_override("font", UIStyle.bold_font())
	_type.add_theme_font_size_override("font_size", 12)
	_type.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type)

	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.scroll_active = false
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(14, ART_RECT.end.y + 22)
	_desc.size = Vector2(SIZE.x - 28, SIZE.y - ART_RECT.end.y - 32)
	_desc.add_theme_font_override("normal_font", UIStyle.bold_font())
	_desc.add_theme_font_override("bold_font", UIStyle.heavy_font())
	_desc.add_theme_font_size_override("normal_font_size", 15)
	_desc.add_theme_font_size_override("bold_font_size", 15)
	_desc.add_theme_constant_override("line_separation", -2)
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc)

	_cost = Label.new()
	_cost.position = ORB_CENTER - Vector2(ORB_RADIUS, ORB_RADIUS)
	_cost.size = Vector2(ORB_RADIUS * 2, ORB_RADIUS * 2)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost.add_theme_font_override("font", UIStyle.display_font())
	_cost.add_theme_font_size_override("font_size", 24)
	UIStyle.outline_label(_cost, 6)
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost)


func _apply_card() -> void:
	var data := card.data
	_name.text = card.get_display_name()
	_fit_name()
	_name.add_theme_color_override("font_color", UIStyle.BUFFED if card.upgraded else UIStyle.TEXT)
	_type.text = "%s · %s" % [String(CardData.CardType.keys()[data.type]).capitalize(),
			String(CardData.Rarity.keys()[data.rarity]).capitalize()]
	display_cost = card.get_cost()
	_update_cost_label()
	set_description(CardText.render(card, null, null, true))
	if data.rarity == CardData.Rarity.RARE and _sparkle == null:
		_add_sparkle()
	queue_redraw()


## Shrinks the name font until it fits the banner (long names like
## "Smoldering Guard+").
func _fit_name() -> void:
	var font := UIStyle.display_font()
	var font_size := 17
	while font_size > 11 and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _name.size.x - 4:
		font_size -= 1
	_name.add_theme_font_size_override("font_size", font_size)


func _update_cost_label() -> void:
	if _cost == null or card == null:
		return
	var printed := card.data.get_cost(card.upgraded)
	match display_cost:
		CardData.COST_UNPLAYABLE:
			_cost.text = ""
		CardData.COST_X:
			_cost.text = "X"
		_:
			_cost.text = str(display_cost)
	var color := UIStyle.TEXT
	if not affordable:
		color = UIStyle.DEBUFFED
	elif display_cost >= 0 and printed >= 0 and display_cost < printed:
		color = UIStyle.BUFFED
	_cost.add_theme_color_override("font_color", color)


func _set_text_visible(v: bool) -> void:
	for node in [_name, _type, _desc, _cost]:
		if node:
			node.visible = v


func _add_sparkle() -> void:
	_sparkle = GPUParticles2D.new()
	_sparkle.amount = 10
	_sparkle.lifetime = 1.4
	_sparkle.position = SIZE / 2
	_sparkle.texture = CombatFX._dot()
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(SIZE.x / 2, SIZE.y / 2, 0)
	m.gravity = Vector3(0, -20, 0)
	m.initial_velocity_max = 10.0
	m.scale_min = 0.15
	m.scale_max = 0.35
	m.color = Color(1.0, 0.86, 0.5, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	_sparkle.process_material = m
	add_child(_sparkle)


## Upgrade "glow" (rest site / smith): white flash sweeping out plus a pulse.
func play_upgrade_glow() -> void:
	_upgrade_flash = 1.0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "_upgrade_flash", 0.0, UIStyle.dur(0.7)).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", scale * 1.08, UIStyle.dur(0.15)).set_trans(Tween.TRANS_BACK)
	t.chain().tween_property(self, "scale", scale, UIStyle.dur(0.25))


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	if face_down:
		_draw_back(rect)
		return
	var data := card.data if card else null
	var body_color := UIStyle.type_color(data.type) if data else UIStyle.PANEL
	var frame_color := UIStyle.rarity_color(data.rarity) if data else UIStyle.TEXT_DIM
	var dim := 1.0 if affordable else 0.55

	# Glow / selection halo
	if glowing or selected:
		var halo := UIStyle.box(Color.TRANSPARENT, UIStyle.RADIUS_CARD + 6, UIStyle.GOLD, 0)
		halo.shadow_color = Color(UIStyle.GOLD, 0.85 if glowing else 0.6)
		halo.shadow_size = 18
		draw_style_box(halo, rect)

	# Shadow + frame + body
	var frame := UIStyle.box(frame_color.darkened(1.0 - dim), UIStyle.RADIUS_CARD, UIStyle.OUTLINE, 3)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 5)
	draw_style_box(frame, rect)
	var body := UIStyle.box(body_color.darkened(1.0 - dim), UIStyle.RADIUS_CARD - 4)
	draw_style_box(body, rect.grow(-7))

	# Art window: two-tone sky + glyph
	var art := UIStyle.box(body_color.lightened(0.18).darkened(1.0 - dim), 8, UIStyle.OUTLINE, 2)
	draw_style_box(art, ART_RECT)
	draw_rect(Rect2(ART_RECT.position + Vector2(2, ART_RECT.size.y * 0.62), Vector2(ART_RECT.size.x - 4, ART_RECT.size.y * 0.38 - 2)),
			Color(0, 0, 0, 0.18))
	if data:
		var glyph_color := body_color.lightened(0.65).darkened(1.0 - dim)
		VectorIcons.draw(self, VectorIcons.card_glyph(data), ART_RECT.get_center(), 78, glyph_color)
		var tag_glyph := VectorIcons.card_tag_glyph(data)
		if tag_glyph != &"":
			var badge := ART_RECT.end - Vector2(24, 24)
			draw_circle(badge, 17, UIStyle.OUTLINE)
			draw_circle(badge, 15, body_color.darkened(0.25))
			VectorIcons.draw(self, tag_glyph, badge, 22, UIStyle.GOLD.darkened(1.0 - dim))

	# Name banner
	draw_style_box(UIStyle.box(Color(0, 0, 0, 0.35), 6), Rect2(36, 8, SIZE.x - 46, 26))

	# Cost orb
	if data and data.cost != CardData.COST_UNPLAYABLE:
		draw_circle(ORB_CENTER, ORB_RADIUS + 3, UIStyle.OUTLINE)
		draw_circle(ORB_CENTER, ORB_RADIUS, UIStyle.ENERGY.darkened(0.35 if affordable else 0.7))
		draw_circle(ORB_CENTER + Vector2(-3, -4), ORB_RADIUS * 0.62, Color(UIStyle.ENERGY.lightened(0.2), 0.55 if affordable else 0.15))

	if _upgrade_flash > 0.0:
		draw_style_box(UIStyle.box(Color(1, 1, 1, _upgrade_flash * 0.6), UIStyle.RADIUS_CARD), rect)


func _draw_back(rect: Rect2) -> void:
	var back := UIStyle.box(UIStyle.PANEL_HI, UIStyle.RADIUS_CARD, UIStyle.OUTLINE, 3)
	back.shadow_color = Color(0, 0, 0, 0.4)
	back.shadow_size = 6
	draw_style_box(back, rect)
	draw_style_box(UIStyle.box(Color.TRANSPARENT, UIStyle.RADIUS_CARD - 6, UIStyle.GOLD.darkened(0.4), 3), rect.grow(-12))
	VectorIcons.draw(self, &"sun", rect.get_center(), 90, UIStyle.GOLD.darkened(0.35))
