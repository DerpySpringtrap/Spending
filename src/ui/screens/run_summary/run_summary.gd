extends Control
## End of run: victory or defeat, stats, final deck and relics.

func _ready() -> void:
	var s: Dictionary = GameManager.last_run_summary
	var victory: bool = s.get("victory", false)
	UIBuild.backdrop(self, 0.6)
	var column := UIBuild.center_column(self, 16, 0)
	var title := UIBuild.title("Victory" if victory else "Defeat", 96)
	title.add_theme_color_override("font_color", UIStyle.GOLD if victory else UIStyle.DAMAGE)
	column.add_child(title)
	var stats: Dictionary = s.get("stats", {})
	var subtitle := "The Gilded Hierophant has fallen. The Catacombs are yours!" if victory \
			else "Fell in Act %d, floor %d%s." % [s.get("act", 1), s.get("floor", 0),
				(" to " + str(stats.get("killed_by"))) if stats.has("killed_by") else ""]
	var sub := UIBuild.label(subtitle, &"", UIStyle.SIZE_H2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	var meta_panel := _meta_panel(s)
	column.add_child(meta_panel)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(grid)
	column.add_child(panel)
	var rows := [
		["Floor reached", s.get("floor", 0)], ["Enemies slain", stats.get("enemies_killed", 0)],
		["Elites slain", stats.get("elites_killed", 0)], ["Cards played", stats.get("cards_played", 0)],
		["Damage dealt", stats.get("damage_dealt", 0)], ["Damage taken", stats.get("damage_taken", 0)],
		["Biggest hit", stats.get("biggest_hit", 0)], ["Gold earned", stats.get("gold_earned", 0)],
		["Ascension", s.get("ascension", 0)], ["Seed", s.get("seed", 0)],
		["XP earned", s.get("xp", 0)], ["Final HP", "%d/%d" % [s.get("hp", 0), s.get("max_hp", 0)]],
	]
	for r in rows:
		grid.add_child(UIBuild.label(r[0], &"DimLabel", UIStyle.SIZE_BODY))
		var v := UIBuild.label(str(r[1]), &"", UIStyle.SIZE_LARGE)
		v.add_theme_font_override("font", UIStyle.heavy_font())
		grid.add_child(v)

	var relic_row := HBoxContainer.new()
	relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_row.add_theme_constant_override("separation", 8)
	for relic in s.get("relics", []):
		var icon := RelicIcon.new()
		icon.relic = relic
		relic_row.add_child(icon)
	column.add_child(relic_row)

	var deck_flow := HFlowContainer.new()
	deck_flow.custom_minimum_size = Vector2(1500, 0)
	deck_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	deck_flow.add_theme_constant_override("h_separation", 6)
	deck_flow.add_theme_constant_override("v_separation", 6)
	for card in s.get("deck", []):
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE * 0.5
		var view := CardView.new().setup(card)
		view.pivot_offset = Vector2.ZERO
		view.scale = Vector2(0.5, 0.5)
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		view.hovered.connect(func(v): EventBus.tooltip_requested.emit(v, card.get_display_name(), CardText.render(card)))
		view.unhovered.connect(func(v): EventBus.tooltip_cleared.emit(v))
		holder.add_child(view)
		deck_flow.add_child(holder)
	column.add_child(deck_flow)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	var again := UIBuild.button("New Run", true, Vector2(240, 64))
	again.pressed.connect(func(): GameManager.go_to_screen(&"class_select"))
	buttons.add_child(again)
	var menu := UIBuild.button("Main Menu", false, Vector2(240, 64))
	menu.pressed.connect(func(): GameManager.go_to_screen(&"main_menu"))
	buttons.add_child(menu)
	UIBuild.stagger_in([title, sub, meta_panel, panel, relic_row, deck_flow, buttons], 0.1)
	again.grab_focus.call_deferred()
	if victory:
		_confetti()


## Class level, an XP bar that fills with this run's XP, and any unlocks.
func _meta_panel(s: Dictionary) -> Control:
	var meta: Dictionary = s.get("meta", {})
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(720, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	if meta.is_empty():
		return panel
	var cls := ContentDB.get_character_class(s.get("class_id", &""))
	var new_xp: int = meta.get("new_xp", 0)
	var old_xp: int = meta.get("old_xp", 0)
	var level := MetaProgress.level_for_xp(new_xp)
	var header := UIBuild.label("%s · Level %d   (+%d XP)" % [cls.display_name if cls else "", level, meta.get("xp", 0)],
			&"HeadingLabel", 26, UIStyle.GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(680, 22)
	bar.show_percentage = false
	var bounds := MetaProgress.level_bounds(new_xp)
	if bounds.y < 0:
		bar.max_value = 1
		bar.value = 1
	else:
		bar.min_value = bounds.x
		bar.max_value = bounds.y
		bar.value = clampi(old_xp, bounds.x, bounds.y)
		bar.create_tween().tween_property(bar, "value", float(new_xp), UIStyle.dur(1.2)).set_delay(UIStyle.dur(0.6)) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	box.add_child(bar)
	var next_text := "Max level" if bounds.y < 0 else "%d / %d XP to level %d" % [new_xp, bounds.y, level + 1]
	var next := UIBuild.label(next_text, &"DimLabel", UIStyle.SIZE_BODY)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(next)
	for unlock: String in meta.get("unlocks", []):
		var line := UIBuild.label("★ " + unlock, &"", UIStyle.SIZE_LARGE, UIStyle.GOLD.lightened(0.2))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
	if not (meta.get("unlocks", []) as Array).is_empty():
		get_tree().create_timer(UIStyle.dur(1.0)).timeout.connect(func(): AudioManager.play(&"relic", 0.0))
	return panel


func _confetti() -> void:
	for k in 6:
		var p := GPUParticles2D.new()
		p.amount = 50
		p.lifetime = 4.0
		p.position = Vector2(160 + k * 320, -20)
		p.texture = CombatFX._dot()
		var m := ParticleProcessMaterial.new()
		m.particle_flag_disable_z = true
		m.direction = Vector3(0, 1, 0)
		m.spread = 40.0
		m.initial_velocity_min = 80.0
		m.initial_velocity_max = 220.0
		m.gravity = Vector3(0, 120, 0)
		m.scale_min = 0.2
		m.scale_max = 0.45
		m.color = Color.from_hsv(k / 6.0, 0.6, 1.0)
		p.process_material = m
		add_child(p)
