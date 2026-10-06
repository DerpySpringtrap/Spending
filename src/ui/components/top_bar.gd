class_name TopBar
extends PanelContainer
## Run info strip shared by combat and (Milestone 3) map screens:
## class name, HP, gold, location and the relic bar.

var _hp_label: Label
var _gold_label: Label
var _where: Label
var _relics: HBoxContainer
var _relic_icons: Dictionary = {}  # relic id -> RelicIcon


func _ready() -> void:
	theme_type_variation = &"BarPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = RunState.get_class_data().display_name if RunState.active else ""
	row.add_child(title)
	row.add_child(_spacer(12))
	row.add_child(GlyphIcon.make(&"heart", UIStyle.HP_BAR, 26))
	_hp_label = _value_label(row)
	row.add_child(_spacer(8))
	row.add_child(GlyphIcon.make(&"coin", UIStyle.GOLD, 26))
	_gold_label = _value_label(row)
	row.add_child(_spacer(8))
	_where = Label.new()
	_where.theme_type_variation = &"DimLabel"
	_where.add_theme_font_size_override("font_size", UIStyle.SIZE_BODY)
	row.add_child(_where)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	_relics = HBoxContainer.new()
	_relics.add_theme_constant_override("separation", 6)
	row.add_child(_relics)
	refresh()
	EventBus.gold_changed.connect(_on_gold_changed)


func refresh() -> void:
	if not RunState.active:
		return
	set_hp(RunState.hp, RunState.max_hp)
	_gold_label.text = str(RunState.gold)
	_where.text = "Act %d" % RunState.act
	for relic in RunState.relics:
		if not _relic_icons.has(relic.id):
			var icon := RelicIcon.new()
			icon.relic = relic
			_relic_icons[relic.id] = icon
			_relics.add_child(icon)


func set_hp(hp: int, max_hp: int) -> void:
	_hp_label.text = "%d/%d" % [hp, max_hp]


func set_location(text: String) -> void:
	_where.text = text


func flash_relic(relic_id: StringName) -> void:
	var icon: RelicIcon = _relic_icons.get(relic_id)
	if icon:
		icon.flash()


func _on_gold_changed(_old: int, new_value: int) -> void:
	if is_instance_valid(_gold_label):
		_gold_label.text = str(new_value)


func _value_label(row: HBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UIStyle.heavy_font())
	label.add_theme_font_size_override("font_size", UIStyle.SIZE_LARGE)
	row.add_child(label)
	return label


func _spacer(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
