class_name AscensionRules
extends RefCounted
## Global ascension modifiers (see docs/design/ENEMIES.md). Per-move bonuses
## are authored on EnemyMoveData instead.

const ELITE_SPAWN_BONUS_LEVEL := 1
const REST_HEAL_LEVEL := 5
const START_DAMAGED_LEVEL := 6
const CURSE_LEVEL := 10
const POTION_SLOT_LEVEL := 11
const MAX_HP_LEVEL := 14
const MAX_HP_PENALTY := 5


static func enemy_damage_multiplier(tier: EnemyData.Tier, ascension: int) -> float:
	match tier:
		EnemyData.Tier.NORMAL, EnemyData.Tier.MINION:
			return 1.1 if ascension >= 2 else 1.0
		EnemyData.Tier.ELITE:
			return 1.1 if ascension >= 3 else 1.0
		EnemyData.Tier.BOSS:
			return 1.1 if ascension >= 4 else 1.0
	return 1.0


static func enemy_hp_multiplier(tier: EnemyData.Tier, ascension: int) -> float:
	match tier:
		EnemyData.Tier.NORMAL, EnemyData.Tier.MINION:
			return 1.1 if ascension >= 7 else 1.0
		EnemyData.Tier.ELITE:
			return 1.1 if ascension >= 8 else 1.0
		EnemyData.Tier.BOSS:
			return 1.1 if ascension >= 9 else 1.0
	return 1.0


static func move_bonus(move: EnemyMoveData, ascension: int) -> int:
	if move.ascension_threshold > 0 and ascension >= move.ascension_threshold:
		return move.ascension_amount_bonus
	return 0
