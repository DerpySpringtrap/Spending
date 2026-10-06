extends Node
## Headless smoke test for the architecture skeleton.
## Run: godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on failure.

var _failures := 0


func _ready() -> void:
	_test_rng_determinism()
	_test_run_save_roundtrip()
	_test_card_upgrade_data()
	print("SMOKE TEST: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAILED: " + message)


func _test_rng_determinism() -> void:
	var a := RngStreams.new(1234)
	var b := RngStreams.new(1234)
	a.get_stream(&"combat").randi()  # Consuming one stream must not affect others.
	_check(a.get_stream(&"map").randi() == b.get_stream(&"map").randi(), "map stream independent of combat stream")
	var restored := RngStreams.from_dict(a.to_dict())
	_check(restored.get_stream(&"rewards").randi() == a.get_stream(&"rewards").randi(), "RNG state survives save/load")


func _make_test_class() -> CharacterClassData:
	var strike := CardData.new()
	strike.id = &"test_strike"
	strike.display_name = "Strike"
	strike.upgraded_cost = 0
	var relic := RelicData.new()
	relic.id = &"test_relic"
	relic.max_hp_bonus = 5
	var potion := PotionData.new()
	potion.id = &"test_potion"
	var cls := CharacterClassData.new()
	cls.id = &"test_class"
	cls.max_hp = 70
	cls.starting_deck = [strike, strike, strike]
	cls.starting_relic = relic
	# Register directly so save/load can resolve ids without .tres files.
	ContentDB.cards[strike.id] = strike
	ContentDB.relics[relic.id] = relic
	ContentDB.potions[potion.id] = potion
	ContentDB.classes[cls.id] = cls
	return cls


func _test_run_save_roundtrip() -> void:
	var cls := _make_test_class()
	RunState.start(cls, 3, 42)
	_check(RunState.max_hp == 75 and RunState.hp == 75, "starting relic max HP bonus applied")
	_check(RunState.deck.size() == 3, "starting deck copied")
	_check(RunState.potions.size() == 3, "3 potion slots below ascension 11")
	RunState.upgrade_card(RunState.deck[0])
	RunState.add_gold(50)
	RunState.add_potion(ContentDB.get_potion(&"test_potion"))
	RunState.save_run()
	var expected := RunState.to_dict()
	RunState.active = false
	RunState.deck.clear()
	_check(RunState.load_run(), "run loads")
	_check(RunState.deck.size() == 3 and RunState.deck[0].upgraded, "deck and upgrades restored")
	_check(RunState.gold == expected["gold"], "gold restored")
	_check(RunState.potions[0] != null and RunState.potions[0].id == &"test_potion", "potion restored")
	_check(RunState.has_relic(&"test_relic"), "relic restored")
	RunState.clear()
	_check(not RunState.has_saved_run(), "run save deleted on clear")


func _test_card_upgrade_data() -> void:
	var card := CardData.new()
	card.cost = 2
	card.upgraded_cost = 1
	card.keywords = [CardData.KW_EXHAUST]
	card.upgrade_removes_keywords = [CardData.KW_EXHAUST]
	_check(card.get_cost(false) == 2 and card.get_cost(true) == 1, "upgrade cost")
	_check(card.has_keyword(CardData.KW_EXHAUST, false), "base keyword")
	_check(not card.has_keyword(CardData.KW_EXHAUST, true), "upgrade removes keyword")
	var inst := CardInstance.new(card)
	var clone := inst.clone_for_combat()
	clone.cost_override_this_combat = 0
	_check(inst.get_cost() == 2 and clone.get_cost() == 0, "combat clone doesn't leak cost changes")
