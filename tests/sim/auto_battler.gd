extends Node
## Headless balance simulator: plays Act 1 encounters with the Pyre Warden's
## starting deck using GreedyPlayerAI and reports win rate, length and damage.
##
## godot --headless --path . res://tests/sim/auto_battler.tscn -- --fights=1000 --ascension=0 --seed=1
## Exit code 1 if any fight hit an engine error (timeout or invalid state).

var _fights := 1000
var _ascension := 0
var _seed := 1


func _ready() -> void:
	_parse_args()
	var cls := ContentDB.get_character_class(&"pyre_warden")
	var encounters: Array[EncounterData] = []
	encounters.append_array(ContentDB.get_encounters(1, EncounterData.Pool.EASY))
	encounters.append_array(ContentDB.get_encounters(1, EncounterData.Pool.HARD))
	encounters.sort_custom(func(a, b): return String(a.id) < String(b.id))
	var per_encounter := maxi(1, _fights / encounters.size())
	var ai := GreedyPlayerAI.new()
	var started := Time.get_ticks_msec()
	var timeouts := 0
	var total_fights := 0
	var total_wins := 0

	print("\nAuto-battler: Pyre Warden starter deck + Cinder Heart, A%d, %d fights per encounter\n" % [_ascension, per_encounter])
	print("| Encounter | Pool | Win % | Avg turns | Avg HP lost (wins) | Worst HP lost |")
	print("|---|---|---|---|---|---|")
	for enc in encounters:
		var wins := 0
		var turns := 0
		var hp_lost_total := 0
		var worst := 0
		for i in per_encounter:
			var deck: Array[CardInstance] = []
			for data in cls.starting_deck:
				deck.append(CardInstance.new(data))
			var relics: Array[RelicData] = [cls.starting_relic]
			var rng := RngStreams.new(hash("%d:%s:%d" % [_seed, enc.id, i]))
			var combat := CombatState.create(cls, deck, cls.max_hp, cls.max_hp, relics, enc, _ascension, rng)
			combat.start()
			while not combat.is_over():
				ai.play_turn(combat)
			turns += combat.round_number
			if combat.result == CombatState.Result.VICTORY:
				wins += 1
				var lost := cls.max_hp - combat.player.hp
				hp_lost_total += lost
				worst = maxi(worst, lost)
			elif not combat.player.is_dead:
				timeouts += 1
		total_fights += per_encounter
		total_wins += wins
		print("| %s | %s | %.1f | %.1f | %.1f | %d |" % [
			enc.id, EncounterData.Pool.keys()[enc.pool], 100.0 * wins / per_encounter,
			float(turns) / per_encounter, float(hp_lost_total) / maxi(wins, 1), worst,
		])
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\n%d fights in %.2fs (%.0f fights/s). Overall win rate %.1f%%. Timeouts: %d" % [
		total_fights, elapsed, total_fights / maxf(elapsed, 0.001), 100.0 * total_wins / total_fights, timeouts,
	])
	get_tree().quit(1 if timeouts > 0 else 0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"fights": _fights = int(parts[1])
			"ascension": _ascension = int(parts[1])
			"seed": _seed = int(parts[1])
