extends Control
## The Bog Merchant: buy cards, relics and potions, or pay to remove a card.

var _stock: Dictionary
var _top_bar: TopBar
var _picker: PileViewer
var _message: Label
var _price_labels: Array = []  # [Label, price, sold_check: Callable]
var _removal: Button


func _ready() -> void:
	_stock = RunLogic.shop_stock()
	UIBuild.backdrop(self, 0.6)
	_top_bar = UIBuild.top_bar(self)
	var column := UIBuild.center_column(self, 18)
	column.add_child(UIBuild.title("The Bog Merchant", 48))
	var greeting := UIBuild.label("\"Everything has a price, warden. Even the fire in your chest.\"", &"DimLabel", UIStyle.SIZE_LARGE)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(greeting)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 14)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards_row)
	for entry in _stock.cards:
		cards_row.add_child(_card_item(entry))

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 40)
	lower.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(lower)
	var relic_box := _shelf("Relics")
	lower.add_child(relic_box)
	for entry in _stock.relics:
		relic_box.get_child(1).add_child(_relic_item(entry))
	var potion_box := _shelf("Potions")
	lower.add_child(potion_box)
	for entry in _stock.potions:
		potion_box.get_child(1).add_child(_potion_item(entry))
	var service := _shelf("Services")
	lower.add_child(service)
	_removal = UIBuild.button("Remove a card\n%d gold" % _stock.removal_price, false, Vector2(220, 90))
	_removal.pressed.connect(_on_removal)
	service.get_child(1).add_child(_removal)

	_message = UIBuild.label("", &"", UIStyle.SIZE_LARGE, UIStyle.DEBUFFED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var leave := UIBuild.button("Leave", true, Vector2(240, 60))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func():
		leave.disabled = true
		GameManager.complete_node())
	column.add_child(leave)
	_picker = PileViewer.new()
	add_child(_picker)
	_refresh_prices()
	leave.grab_focus.call_deferred()


func _shelf(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UIBuild.label(title, &"HeadingLabel", 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	return box


func _price_tag(price: int, sale: bool = false) -> HBoxContainer:
	var tag := HBoxContainer.new()
	tag.alignment = BoxContainer.ALIGNMENT_CENTER
	tag.add_child(GlyphIcon.make(&"coin", UIStyle.GOLD, 22))
	var l := UIBuild.label(("%d  SALE" if sale else "%d") % price, &"", UIStyle.SIZE_LARGE)
	l.add_theme_font_override("font", UIStyle.heavy_font())
	tag.add_child(l)
	return tag


func _card_item(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.SIZE * 0.82
	box.add_child(holder)
	var view := CardView.new().setup(CardInstance.new(entry.card))
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2(0.82, 0.82)
	holder.add_child(view)
	var tag := _price_tag(entry.price, entry.get("sale", false))
	box.add_child(tag)
	_price_labels.append([tag.get_child(1), entry])
	view.hovered.connect(func(v): EventBus.tooltip_requested.emit(v, "", CardTooltips.for_card(v.card)))
	view.unhovered.connect(func(v): EventBus.tooltip_cleared.emit(v))
	view.pressed.connect(func(_v, event):
		if event.button_index == MOUSE_BUTTON_LEFT and _buy(entry):
			RunState.add_card(entry.card)
			_sold(box))
	return box


func _relic_item(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var icon := RelicIcon.new()
	icon.relic = entry.relic
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _buy(entry):
			RunState.add_relic(entry.relic)
			_sold(box))
	box.add_child(icon)
	var tag := _price_tag(entry.price)
	box.add_child(tag)
	_price_labels.append([tag.get_child(1), entry])
	return box


func _potion_item(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var icon := PotionIcon.new()
	icon.potion = entry.potion
	icon.show_hint = false
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.activated.connect(func(_s):
		if RunState.potions.find(null) < 0:
			_show_message("Your potion slots are full.")
		elif _buy(entry):
			RunState.add_potion(entry.potion)
			_sold(box))
	box.add_child(icon)
	var tag := _price_tag(entry.price)
	box.add_child(tag)
	_price_labels.append([tag.get_child(1), entry])
	return box


func _buy(entry: Dictionary) -> bool:
	if entry.sold:
		return false
	if not RunState.can_afford(entry.price):
		_show_message("Not enough gold.")
		return false
	RunState.add_gold(-entry.price)
	entry.sold = true
	_refresh_prices()
	_top_bar.refresh()
	return true


func _sold(item: Control) -> void:
	EventBus.tooltip_cleared.emit(null)
	var t := item.create_tween()
	t.tween_property(item, "modulate:a", 0.15, UIStyle.dur(0.25))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_removal() -> void:
	if _stock.removal_used:
		return
	if not RunState.can_afford(_stock.removal_price):
		_show_message("Not enough gold.")
		return
	_picker.open_picker("Remove a Card (%d gold)" % _stock.removal_price, RunState.deck, "remove", func(card: CardInstance):
		RunState.add_gold(-_stock.removal_price)
		RunState.remove_card(card)
		RunState.removals += 1
		_stock.removal_used = true
		_removal.disabled = true
		_removal.text = "Card removed"
		_refresh_prices()
		_top_bar.refresh())


func _refresh_prices() -> void:
	for pair in _price_labels:
		var label: Label = pair[0]
		var entry: Dictionary = pair[1]
		label.add_theme_color_override("font_color", UIStyle.TEXT_DIM if entry.sold else (UIStyle.TEXT if RunState.can_afford(entry.price) else UIStyle.DEBUFFED))
		if entry.sold:
			label.text = "Sold"


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var t := _message.create_tween()
	t.tween_interval(1.5)
	t.tween_property(_message, "modulate:a", 0.0, 0.5)
