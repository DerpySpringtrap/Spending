class_name PlayerSeat
extends RefCounted
## One hero's side of a fight: the hero, their card piles, relics, summons and
## per-turn counters. Solo fights have one seat; co-op fights have one per
## player. CombatState's player/hand/pile fields read the active seat.

var index: int = 0
var player: PlayerCombatant
var draw_pile: Array[CardInstance] = []  ## Top of the pile is the END of the array.
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var relics: Array[RelicData] = []
## This hero's allies (Rootmother). Dead ones stay in the list.
var summons: Array[SummonCombatant] = []
var cards_played_this_turn: int = 0
var stance_changes_this_turn: int = 0
## The run's gold, mirrored so thieves know how much they can take.
var player_gold: int = 0
## Co-op: this hero pressed End Turn and waits for the others.
var ended_turn: bool = false
## The card choice this hero still has to make, or {} (see CombatState.request_choice).
var pending_choice: Dictionary = {}
## Gold each thief took from this hero (thief id -> amount), returned when it dies.
var stolen: Dictionary = {}


func _init(p_index: int, p_player: PlayerCombatant) -> void:
	index = p_index
	player = p_player
	player.seat_index = p_index
