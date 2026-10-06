extends CanvasLayer
## Play-testing shortcuts (autoload: DebugTools). Active in debug builds only
## (running from the editor), never in exported release builds.
##
## F1 help · F2 +100 gold · F3 full heal · F4 win the current fight
## F6 skip to the boss (on the map) · F7 add a random rare card · F9 +1 potion

var _toast: Label
var _help: PanelContainer


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color("#7BE0C8"))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.position = Vector2(24, 80)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_help = PanelContainer.new()
	_help.position = Vector2(24, 120)
	_help.visible = false
	var text := Label.new()
	text.text = "DEBUG KEYS\nF1  this help\nF2  +100 gold\nF3  full heal\nF4  win the current fight\nF6  skip to the boss (on the map)\nF7  add a random rare card\nF9  add a random potion"
	_help.add_child(text)
	add_child(_help)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			_help.visible = not _help.visible
		KEY_F2:
			if RunState.active:
				RunState.add_gold(100)
				_say("+100 gold")
		KEY_F3:
			if RunState.active:
				RunState.set_hp(RunState.max_hp)
				var combat := _combat()
				if combat:
					combat.heal(combat.player, combat.player.max_hp)
				_say("Healed")
		KEY_F4:
			var combat := _combat()
			if combat and not combat.is_over():
				for enemy in combat.living_enemies():
					combat.deal_damage(combat.player, enemy, 9999, DamageInfo.Type.HP_LOSS)
				_say("Fight won")
		KEY_F6:
			_skip_to_boss()
		KEY_F7:
			if RunState.active:
				var card := RunLogic.random_card_of(CardData.Rarity.RARE)
				if card:
					RunState.add_card(card)
					_say("Added " + card.display_name)
		KEY_F9:
			if RunState.active:
				var potion := RunLogic.roll_potion()
				if potion and RunState.add_potion(potion) >= 0:
					_say("Added " + potion.display_name)
		_:
			return
	get_viewport().set_input_as_handled()


func _combat() -> CombatState:
	var scene := get_tree().current_scene
	if scene and "combat" in scene and scene.combat is CombatState:
		return scene.combat
	return null


func _skip_to_boss() -> void:
	var scene := get_tree().current_scene
	if not RunState.active or scene == null or String(scene.name) != "MapScreen":
		_say("F6 works on the map")
		return
	for id in RunState.map_data.nodes:
		if int(RunState.map_data.nodes[id].floor) == MapGenerator.FLOORS - 1:
			RunState.current_node = id
			RunState.floor_number = MapGenerator.FLOORS
			RunState.monster_fights = RunLogic.EASY_FIGHTS
			GameManager.go_to_screen(&"map")
			_say("Skipped to the boss")
			return


func _say(text: String) -> void:
	_toast.text = "[debug] " + text
	_toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(_toast, "modulate:a", 0.0, 0.5)
