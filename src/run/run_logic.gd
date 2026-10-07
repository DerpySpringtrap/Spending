class_name RunLogic
extends RefCounted
## Run rules that aren't combat: rewards, encounter/event selection, shop stock
## and prices, rest healing and event outcomes. Pure functions over RunState,
## so screens and the headless run simulator share them.

const CARD_ODDS_NORMAL := [60.0, 37.0, 3.0]   # common / uncommon / rare
const CARD_ODDS_ELITE := [50.0, 40.0, 10.0]
const CARD_ODDS_SHOP := [54.0, 37.0, 9.0]
const RELIC_ODDS := [50.0, 33.0, 17.0]        # common / uncommon / rare
const POTION_CHANCE := 0.4
const EASY_FIGHTS := 3
const REST_HEAL := 0.3
const REMOVAL_BASE_PRICE := 75
const REMOVAL_STEP := 25
## Between acts you recover this share of your missing HP.
const ACT_HEAL := 0.75

const CARD_PRICES := {CardData.Rarity.COMMON: 50, CardData.Rarity.UNCOMMON: 75, CardData.Rarity.RARE: 150}
const RELIC_PRICES := {RelicData.Rarity.COMMON: 150, RelicData.Rarity.UNCOMMON: 250, RelicData.Rarity.RARE: 300, RelicData.Rarity.SHOP: 150}
const POTION_PRICES := {PotionData.Rarity.COMMON: 50, PotionData.Rarity.UNCOMMON: 75, PotionData.Rarity.RARE: 100}


# --- Cards ----------------------------------------------------------------------

static func _roll_rarity(odds: Array, rng: RandomNumberGenerator) -> CardData.Rarity:
	var roll: float = rng.randf() * (odds[0] + odds[1] + odds[2])
	if roll < odds[0]:
		return CardData.Rarity.COMMON
	if roll < odds[0] + odds[1]:
		return CardData.Rarity.UNCOMMON
	return CardData.Rarity.RARE


## [param count] distinct cards from the class pool.
static func roll_card_choices(count: int = 3, odds: Array = CARD_ODDS_NORMAL, stream: StringName = &"rewards") -> Array[CardData]:
	var rng := RunState.rng.get_stream(stream)
	var result: Array[CardData] = []
	var guard := 0
	while result.size() < count and guard < 100:
		guard += 1
		var rarity := _roll_rarity(odds, rng)
		var pool := ContentDB.get_reward_pool(RunState.class_id, rarity)
		if pool.is_empty():
			pool = ContentDB.get_reward_pool(RunState.class_id, CardData.Rarity.COMMON)
		if pool.is_empty():
			break
		var card: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		if not result.has(card):
			result.append(card)
	return result


## Chance that a reward card comes already upgraded: none in Act 1, more in
## later acts, halved at Ascension 12.
static func upgrade_chance() -> float:
	var chance := 0.0 if RunState.act <= 1 else (0.15 if RunState.act == 2 else 0.25)
	if RunState.ascension >= AscensionRules.UPGRADED_REWARD_LEVEL:
		chance *= 0.5
	return chance


## A card reward entry: {"type": "card", "choices": [...], "upgraded": [bool...]}.
static func card_reward(odds: Array) -> Dictionary:
	var choices := roll_card_choices(3, odds)
	var flags: Array[bool] = []
	var rng := RunState.rng.get_stream(&"rewards")
	for card in choices:
		flags.append(card.can_upgrade and rng.randf() < upgrade_chance())
	return {"type": "card", "choices": choices, "upgraded": flags}


static func random_card_of(rarity: CardData.Rarity) -> CardData:
	var pool := ContentDB.get_reward_pool(RunState.class_id, rarity)
	return RunState.rng.pick(pool, &"events") if not pool.is_empty() else null


# --- Relics & potions -----------------------------------------------------------

static func roll_relic_rarity(stream: StringName = &"rewards") -> RelicData.Rarity:
	var rng := RunState.rng.get_stream(stream)
	var roll := rng.randf() * 100.0
	if roll < RELIC_ODDS[0]:
		return RelicData.Rarity.COMMON
	if roll < RELIC_ODDS[0] + RELIC_ODDS[1]:
		return RelicData.Rarity.UNCOMMON
	return RelicData.Rarity.RARE


## A relic the player doesn't own, falling back through other rarities.
static func roll_relic(rarity: int = -1, stream: StringName = &"rewards", exclude: Array = []) -> RelicData:
	var order: Array = [RelicData.Rarity.COMMON, RelicData.Rarity.UNCOMMON, RelicData.Rarity.RARE, RelicData.Rarity.SHOP]
	var first: RelicData.Rarity = roll_relic_rarity(stream) if rarity < 0 else rarity
	order.erase(first)
	order.push_front(first)
	for r in order:
		var options: Array = []
		for relic in ContentDB.get_relics_by_rarity(r, RunState.class_id):
			if not RunState.has_relic(relic.id) and not exclude.has(relic):
				options.append(relic)
		if not options.is_empty():
			return RunState.rng.pick(options, stream)
	return null


static func roll_potion(stream: StringName = &"rewards") -> PotionData:
	var options := ContentDB.get_potions_for(RunState.class_id)
	if options.is_empty():
		return null
	var weights := options.map(func(p): return [65.0, 25.0, 10.0][p.rarity])
	return RunState.rng.pick_weighted(options, weights, stream)


# --- Combat rewards -------------------------------------------------------------

static func gold_amount(base_min: int, base_max: int) -> int:
	var gold := RunState.rng.get_stream(&"rewards").randi_range(base_min, base_max)
	var mult := 1.0
	for relic in RunState.relics:
		mult *= relic.gold_gain_multiplier
	if RunState.ascension >= 13:
		mult *= 0.75
	return roundi(gold * mult)


## Reward entries: {"type": "gold"|"card"|"relic"|"potion", ...}
static func combat_rewards(node_type: String, extra_relic: bool = false) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	match node_type:
		MapGenerator.TYPE_ELITE:
			rewards.append({"type": "gold", "amount": gold_amount(25, 35)})
			var relic := roll_relic()
			if relic:
				rewards.append({"type": "relic", "relic": relic})
			rewards.append(card_reward(CARD_ODDS_ELITE))
		MapGenerator.TYPE_BOSS:
			rewards.append({"type": "gold", "amount": gold_amount(95, 105)})
			var boss_relics := roll_boss_relics(3)
			if not boss_relics.is_empty():
				rewards.append({"type": "relic_choice", "choices": boss_relics})
			rewards.append(card_reward([0.0, 0.0, 100.0]))
		_:
			rewards.append({"type": "gold", "amount": gold_amount(10, 20)})
			rewards.append(card_reward(CARD_ODDS_NORMAL))
	if extra_relic:
		var bonus := roll_relic()
		if bonus:
			rewards.append({"type": "relic", "relic": bonus})
	if RunState.rng.get_stream(&"rewards").randf() < POTION_CHANCE:
		var potion := roll_potion()
		if potion:
			rewards.append({"type": "potion", "potion": potion})
	return rewards


## Up to [param count] distinct boss relics the player doesn't own.
static func roll_boss_relics(count: int) -> Array[RelicData]:
	var options: Array[RelicData] = []
	for relic in ContentDB.get_relics_by_rarity(RelicData.Rarity.BOSS, RunState.class_id):
		if not RunState.has_relic(relic.id):
			options.append(relic)
	RunState.rng.shuffle(options, &"rewards")
	return options.slice(0, count)


## Moves the run to the next act: heal part of the missing HP, new map, and
## the easy-fight counter starts over.
static func advance_act() -> void:
	RunState.act += 1
	RunState.heal(ceili((RunState.max_hp - RunState.hp) * ACT_HEAL))
	RunState.monster_fights = 0
	RunState.seen_encounters.clear()
	if RunState.act >= GameManager.SECRET_ACT:
		RunState.map_data = MapGenerator.generate_final(RunState.act)
	else:
		RunState.map_data = MapGenerator.generate(RunState.rng.get_stream(&"map"), RunState.act, RunState.ascension)
	RunState.current_node = ""
	RunState.visited_nodes.clear()
	RunState.floor_number = 0
	EventBus.act_started.emit(RunState.act)


static func treasure_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var relic := roll_relic()
	if relic:
		rewards.append({"type": "relic", "relic": relic})
	rewards.append({"type": "gold", "amount": gold_amount(20, 40)})
	return rewards


# --- Encounters & events --------------------------------------------------------

static func pick_encounter(node_type: String) -> EncounterData:
	var pool := EncounterData.Pool.HARD
	match node_type:
		MapGenerator.TYPE_ELITE:
			pool = EncounterData.Pool.ELITE
		MapGenerator.TYPE_BOSS:
			pool = EncounterData.Pool.BOSS
		_:
			pool = EncounterData.Pool.EASY if RunState.monster_fights < EASY_FIGHTS else EncounterData.Pool.HARD
	var options := ContentDB.get_encounters(RunState.act, pool)
	if options.is_empty():
		options = ContentDB.get_encounters(RunState.act, EncounterData.Pool.HARD)
	var recent: Array = RunState.seen_encounters.slice(-2)
	var fresh: Array = options.filter(func(e): return not recent.has(String(e.id)))
	if fresh.is_empty():
		fresh = options
	var weights := fresh.map(func(e): return e.weight)
	var enc: EncounterData = RunState.rng.pick_weighted(fresh, weights, &"encounters")
	RunState.seen_encounters.append(String(enc.id))
	return enc


static func pick_event() -> EventData:
	var options: Array = ContentDB.get_events(RunState.act).filter(func(e): return not RunState.seen_events.has(String(e.id)))
	if options.is_empty():
		options = ContentDB.get_events(RunState.act)
	if options.is_empty():
		return null
	var ev: EventData = RunState.rng.pick(options, &"events")
	RunState.seen_events.append(String(ev.id))
	return ev


static func choice_available(choice: EventChoice) -> String:
	if choice.min_gold > 0 and RunState.gold < choice.min_gold:
		return "Requires %d gold" % choice.min_gold
	if choice.min_hp > 0 and RunState.hp <= choice.min_hp:
		return "Requires more than %d HP" % choice.min_hp
	return ""


## Applies one outcome. Returns a follow-up the UI must handle:
## "" (done), "remove" / "upgrade" (player picks a card), "fight" (start the
## outcome's encounter).
static func apply_outcome(outcome: EventOutcome) -> String:
	var amount := outcome.amount
	if outcome.percent:
		amount = maxi(1, roundi(RunState.max_hp * outcome.amount / 100.0))
	match outcome.type:
		EventOutcome.Type.GAIN_GOLD:
			RunState.add_gold(amount)
		EventOutcome.Type.LOSE_GOLD:
			RunState.add_gold(-amount)
		EventOutcome.Type.HEAL:
			RunState.heal(amount)
		EventOutcome.Type.LOSE_HP:
			RunState.set_hp(maxi(RunState.hp - amount, 1))
		EventOutcome.Type.GAIN_MAX_HP:
			RunState.change_max_hp(amount)
		EventOutcome.Type.LOSE_MAX_HP:
			RunState.change_max_hp(-amount)
		EventOutcome.Type.GAIN_CARD:
			if outcome.card:
				RunState.add_card(outcome.card)
		EventOutcome.Type.GAIN_RANDOM_CARD:
			var card := random_card_of(outcome.rarity)
			if card:
				RunState.add_card(card)
		EventOutcome.Type.REMOVE_CARD:
			return "remove"
		EventOutcome.Type.UPGRADE_CARD:
			return "upgrade"
		EventOutcome.Type.UPGRADE_RANDOM_CARDS:
			var options := RunState.deck.filter(func(c): return c.can_upgrade())
			RunState.rng.shuffle(options, &"events")
			for i in mini(amount, options.size()):
				RunState.upgrade_card(options[i])
		EventOutcome.Type.GAIN_RELIC:
			var relic := roll_relic(outcome.relic_rarity, &"events")
			if relic:
				RunState.add_relic(relic)
		EventOutcome.Type.GAIN_POTION:
			for i in maxi(amount, 1):
				var potion := roll_potion(&"events")
				if potion:
					RunState.add_potion(potion)
		EventOutcome.Type.FIGHT:
			return "fight"
	return ""


# --- Shop -----------------------------------------------------------------------

static func _price(base: int) -> int:
	var rng := RunState.rng.get_stream(&"shop")
	var mult := rng.randf_range(0.9, 1.1)
	for relic in RunState.relics:
		mult *= relic.shop_price_multiplier
	if RunState.ascension >= 13:
		mult *= 1.1
	return roundi(base * mult)


static func shop_stock() -> Dictionary:
	var cards: Array = []
	for card in roll_card_choices(7, CARD_ODDS_SHOP, &"shop"):
		cards.append({"card": card, "price": _price(CARD_PRICES.get(card.rarity, 50)), "sold": false})
	# One card is on sale.
	if not cards.is_empty():
		var sale: Dictionary = RunState.rng.pick(cards, &"shop")
		sale.price = roundi(sale.price * 0.5)
		sale["sale"] = true
	var relics: Array = []
	var taken: Array = []
	for i in 3:
		var relic := roll_relic(-1, &"shop", taken)
		if relic:
			taken.append(relic)
			relics.append({"relic": relic, "price": _price(RELIC_PRICES.get(relic.rarity, 150)), "sold": false})
	var potions: Array = []
	for i in 3:
		var potion := roll_potion(&"shop")
		if potion:
			potions.append({"potion": potion, "price": _price(POTION_PRICES.get(potion.rarity, 50)), "sold": false})
	return {"cards": cards, "relics": relics, "potions": potions,
		"removal_price": REMOVAL_BASE_PRICE + REMOVAL_STEP * RunState.removals, "removal_used": false}


# --- Rest -----------------------------------------------------------------------

static func rest_heal_amount() -> int:
	var fraction := 0.25 if RunState.ascension >= AscensionRules.REST_HEAL_LEVEL else REST_HEAL
	return roundi(RunState.max_hp * fraction)
