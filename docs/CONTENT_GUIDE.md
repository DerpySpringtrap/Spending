# Content Guide

How to add cards, statuses, relics and enemies without writing code. Every piece of content is a `.tres` resource. `ContentDB` finds it automatically if it's under `res://content/` and has a unique `id`.

> **Rule: name the file after its id.** `content/classes/pyre_warden/cards/kindle.tres` → `id = &"kindle"`. `tests/unit/test_content.gd` enforces this.

## Adding a card
1. In the FileSystem dock, right-click the class's `cards/` folder → **New Resource… → CardData**. (Easier: duplicate a similar card with Ctrl+D.)
2. Fill in `id`, `display_name`, `type`, `rarity`, `target_mode`, `cost` and `card_pool` (the class id).
3. Add **effects**. Each is a `GameEffect` subclass:

| Effect | Does | Key fields |
|---|---|---|
| `DealDamageEffect` | Damage (attack or tick types) | `amount`, `times`, `target`, `damage_type` |
| `GainBlockEffect` | Block | `amount`, `target = SELF` |
| `ApplyStatusEffect` | Add/remove status stacks (Powers too) | `status`, `amount`, `target` |
| `DrawCardsEffect` | Draw | `amount` |
| `GainEnergyEffect` | Energy | `amount` |
| `GainClassResourceEffect` | Stoke / gain Ink / Sap (negative spends) | `amount` |
| `SpendClassResourceEffect` | Vent / Inscribe / Graft bonus clause | `amount` (cost), `spend_all`, `bonus_effects` |
| `HealEffect` | Heal | `amount`, `target` |
| `AddCardToPileEffect` | Create cards (status clutter, tokens) | `card`, `pile`, `amount` = copies |
| `SpreadStatusEffect` | Copy target's stacks to the other enemies | `status` |
| `OverheatEffect` | Pyre Warden's Overheat (used by the Heat resource) | blast/recoil/reset values |
| `SummonEnemyEffect` | Adds enemies mid-fight (boss adds) | `enemy`, `amount`, `max_enemies` |
| `RemoveDebuffsEffect` | Cleanses debuffs (phase changes) | `target` |

4. **Upgrades:** set `upgrade_delta` on each effect (+3 damage, +1 Burn…), and/or `upgraded_cost`, `upgrade_adds_keywords`, `upgraded_description`.
5. **Description:** write it with tokens. `Deal {dmg} damage. Stoke {heat}.` Each token must match an effect's `value_key`. The card shows live numbers: Strength, Weak and the hovered enemy's Vulnerable are all included. Keywords such as *Exhaust* are appended automatically.
6. **Scaling:** set an effect's `scale` to multiply its amount by X (energy spent / resource vented), the current class resource, the exhaust pile size or the hand size.
7. Run the tests (below). `test_content` fails if a token has no matching effect.

## Adding a status
`content/statuses/<id>.tres` → **StatusEffectData**.
- **Stat modifiers** cover most buffs/debuffs: `damage_dealt_flat_per_stack` (Strength), `damage_dealt_multiplier` (Weak), `damage_taken_multiplier` (Vulnerable), `block_gained_*` (Dexterity/Frail), `retains_block`, `skips_turn`.
- **Decay:** how stacks go down (`DECREMENT_ON_ROUND_END` for Weak-style durations, `HALVE_ON_TURN_END` for Burn…).
- **Triggers:** `EffectTrigger` = timing + effects. Tick a status with `amount_from_stacks` (Poison: `TURN_START` → `DealDamageEffect(type POISON, target SELF)`). Reactive statuses use `ATTACKED` + `target = ATTACKER` (Thorns).
- A **Power card** is just `ApplyStatusEffect(target SELF)` with a status that carries the triggers.

## Adding a relic
`RelicData` with `triggers` (e.g. `COMBAT_START` → `GainClassResourceEffect 3`), plus optional passive run modifiers (energy, draw, max HP, potion slots).

## Adding an enemy
1. `EnemyData`: HP range, tier, act, `gimmick_text` and `starting_statuses` (passives like Thorns or Toxic Burst are statuses).
2. Add at least one `EnemyPhaseData`. `selection`:
   - `WEIGHTED_RANDOM` with per-move `weight`, `max_consecutive`, `cooldown`, `min_turn`
   - `SEQUENCE` for fixed loops
   - `SCRIPTED` with an `EnemyAI` subclass for bosses
3. Each `EnemyMoveData` has an `intent` (what the icon shows), `effects`, and an optional ascension bonus.
   - Enemy effects target from the enemy's point of view: `CHOSEN` = the player, `SELF` = the enemy, `ALL_ENEMIES` = the player's side.
4. Bosses: add more phases with lower `hp_threshold` values and optional `on_enter_effects`.
5. Put it in an `EncounterData` (act + pool) so the run can roll it.

## Adding an event
`content/events/<id>.tres` → **EventData**: title, description, `glyph` (placeholder art) and a list of `EventChoice`s.
- Each choice has button `text`, `result_text`, optional `min_gold` / `min_hp` requirements and `outcomes`.
- `EventOutcome` types cover gold, HP (flat or `percent` of max HP), max HP, a specific card (curses), a random class card of a rarity, card removal or upgrade (the player picks), random upgrades, relics, potions and `FIGHT` (an `EncounterData`; winning grants a bonus relic).

## Adding a potion
**PotionData**: `effects` (any GameEffects), `target_mode` (`SINGLE_ENEMY` shows the targeting arrow), `liquid_color` for the bottle, and `usable_outside_combat` (only Heal effects apply on the map).

## Art hooks
Until real art exists, bodies, card art and icons are flat vector placeholders drawn in code (`PlaceholderArt`, `VectorIcons`).
- Give an enemy real art by setting `EnemyData.visual_scene` to a scene with an `AnimationPlayer` named `AnimationPlayer` that has clips `idle`, `attack`, `hurt` (optionally `cast`, `victory`).
- Do the same for a class with `CharacterClassData.combat_scene`.
- Set `icon` on statuses and relics to replace their glyphs.

## Rules that keep data safe
- **Enums are append-only.** Godot stores enum fields as integers in `.tres`. Inserting a value mid-enum silently changes the meaning of existing content. Always add new values at the end.
- Reference content by `id` in code and saves, never by path.

## Checking your work
```bash
godot --headless --path . res://tests/test_runner.tscn             # unit + content validation tests
godot --headless --path . res://tests/sim/auto_battler.tscn -- --fights=1000   # balance sim
godot --headless --path . res://tests/ui_smoke_test.tscn           # drives the combat screen
```
In the editor: F5 → **Start Test Combat** to play it.
