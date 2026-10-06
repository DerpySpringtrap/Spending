class_name TopBar
extends PanelContainer
## Run info strip shared by every run screen: class, HP, gold, potions,
## floor, deck button and the relic bar. Updates itself from EventBus.

signal potion_activated(slot: int)
signal potion_discard_requested(slot: int)
signal deck_pressed

var _hp_label: Label
var _gold_label: Label
var _where: Label
var _potions: HBoxContainer
var _relics: HBoxContainer
var _relic_icons: Dictionary = {}  # relic id -> RelicIcon
var _deck_button: Button
var _initialized := false
var _connections: Array = []


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
	row.add_child(_spacer(8))
	row.add_child(GlyphIcon.make(&"heart", UIStyle.HP_BAR, 26))
	_hp_label = _value_label(row)
	row.add_child(_spacer(4))
	row.add_child(GlyphIcon.make(&"coin", UIStyle.GOLD, 26))
	_gold_label = _value_label(row)
	row.add_child(_spacer(4))
	_potions = HBoxContainer.new()
	_potions.add_theme_constant_override("separation", 2)
	row.add_child(_potions)
	row.add_child(_spacer(4))
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
	_deck_button = Button.new()
	_deck_button.focus_mode = Control.FOCUS_NONE
	_deck_button.custom_minimum_size = Vector2(110, 44)
	_deck_button.add_theme_font_size_override("font_size", UIStyle.SIZE_BODY)
	_deck_button.pressed.connect(func(): deck_pressed.emit())
	row.add_child(_deck_button)
	refresh()
	var on_change := func(_a = null, _b = null, _c = null): refresh()
	for sig in [EventBus.gold_changed, EventBus.run_hp_changed, EventBus.potion_obtained, EventBus.relic_obtained,
			EventBus.card_added_to_deck, EventBus.card_removed_from_deck]:
		sig.connect(on_change)
		_connections.append([sig, on_change])


func _exit_tree() -> void:
	for pair in _connections:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_connections.clear()


func refresh() -> void:
	if not is_inside_tree() or not RunState.active:
		return
	set_hp(RunState.hp, RunState.max_hp)
	_gold_label.text = str(RunState.gold)
	_where.text = "Act %d · Floor %d" % [RunState.act, RunState.floor_number]
	_deck_button.text = "Deck %d" % RunState.deck.size()
	for relic in RunState.relics:
		if not _relic_icons.has(relic.id):
			var icon := RelicIcon.new()
			icon.relic = relic
			_relic_icons[relic.id] = icon
			_relics.add_child(icon)
			if _initialized:
				icon.flash.call_deferred()
	while _potions.get_child_count() < RunState.potions.size():
		var p := PotionIcon.new()
		p.slot = _potions.get_child_count()
		p.activated.connect(func(s): potion_activated.emit(s))
		p.discard_requested.connect(func(s): potion_discard_requested.emit(s))
		_potions.add_child(p)
	for i in _potions.get_child_count():
		var icon: PotionIcon = _potions.get_child(i)
		icon.visible = i < RunState.potions.size()
		icon.potion = RunState.potions[i] if i < RunState.potions.size() else null
	_initialized = true


func set_hp(hp: int, max_hp: int) -> void:
	_hp_label.text = "%d/%d" % [hp, max_hp]


func set_location(text: String) -> void:
	_where.text = text


func potion_icon(slot: int) -> PotionIcon:
	return _potions.get_child(slot) if slot < _potions.get_child_count() else null


func flash_relic(relic_id: StringName) -> void:
	var icon: RelicIcon = _relic_icons.get(relic_id)
	if icon:
		icon.flash()


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
