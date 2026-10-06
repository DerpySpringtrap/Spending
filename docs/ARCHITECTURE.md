# Duskbound: Technical Architecture

> Working title. Godot **4.4**, GDScript with static typing throughout.
> Target: PC (Windows/Linux/macOS) and Steam Deck first. 1920×1080 base resolution, resolution-independent UI.

## 1. Guiding principles

1. **Content is data.** Cards, statuses, relics, potions, enemies, encounters and classes are custom `Resource`s (`.tres`). Designers add content by creating resources in the inspector. Code changes are only needed for genuinely new *mechanics*, and those are small `GameEffect` subclasses.
2. **Logic never waits on presentation.** Combat rules resolve instantly and deterministically. They emit signals on the `EventBus`, and a presentation layer replays those signals as animated "beats". Animations never drive game state.
3. **One owner per piece of state.** `RunState` owns the run, `CombatState` owns a fight, `MetaProgress` owns unlocks, `Settings` owns options. Everything else reads from them or listens.
4. **Deterministic, seeded runs.** Separate RNG streams per system make a seed reproduce the same map, rewards and shuffles. This enables daily seeds, bug repros and save/continue.
5. **Small, composable, testable.** The combat engine runs headless with no scenes, so balance simulations and unit tests can run in CI.

## 2. Folder structure

Organised by feature. A feature's scripts and scenes live together. Authored content and imported assets are kept separate from code.

```
res://
├── project.godot
├── default_bus_layout.tres        # Master / Music / SFX / UI / Ambience
├── docs/                          # This file, design docs, roadmap
├── src/                           # All code and code-owned scenes
│   ├── autoload/                  # Singletons (see §3)
│   ├── core/                      # Engine-agnostic helpers: RngStreams, SaveIO
│   ├── data/                      # Resource *class definitions* (CardData, EnemyData…)
│   ├── run/                       # Run-level runtime types: CardInstance, rewards, ascension rules
│   ├── combat/                    # M1: CombatState, Combatant, ActionQueue, DamageCalc
│   │   ├── effects/               # GameEffect subclasses (DealDamage, GainBlock, ApplyStatus…)
│   │   ├── behaviors/             # StatusBehavior / RelicBehavior escape-hatch scripts
│   │   └── ai/                    # EnemyAI subclasses for SCRIPTED bosses
│   ├── presentation/              # PresentationQueue, CombatFX (numbers, particles, shake, hit-stop)
│   ├── map/                       # M3: MapGenerator, map screen, node scenes
│   ├── ui/
│   │   ├── theme/                 # main_theme.tres + style tokens (the "style guide in code")
│   │   ├── components/            # CardView, HealthBar, StatusTray, IntentIcon, Tooltip, RelicBar…
│   │   └── screens/               # main_menu, class_select, reward, shop, rest, event, run_summary
│   └── boot/                      # Temporary entry scene
├── content/                       # Authored .tres data. NO scripts here.
│   ├── classes/<class_id>/        # class.tres, cards/, relics/, potions/
│   ├── cards/{neutral,curses,status}/
│   ├── statuses/
│   ├── enemies/act1…act4/
│   ├── encounters/act1…act4/
│   ├── relics/  potions/  events/
├── assets/                        # Imported media
│   ├── art/{cards,characters,enemies,backgrounds,icons,map}/
│   ├── audio/{music,sfx,ambience}/
│   ├── fonts/  shaders/  vfx/  ui/
└── tests/                         # Headless test scenes (smoke_test.tscn); GUT later
```

**Enums are append-only.** `.tres` files store enum fields as integers, so inserting a value mid-enum silently corrupts existing content. Always add new values at the end.

**Naming:** `snake_case` files/folders, `PascalCase` `class_name`s, `&"snake_case"` StringName ids. A resource's file name matches its id (`content/classes/pyre_warden/cards/kindle.tres` → `id = &"kindle"`).

## 3. Autoloads

Loaded in this order (later ones may depend on earlier ones):

| Autoload | Script | Responsibility |
|---|---|---|
| `EventBus` | `src/autoload/event_bus.gd` | Global signals only, no state. Logic emits; UI/animation/audio listen. |
| `ContentDB` | `src/autoload/content_db.gd` | Scans `res://content/` at boot, indexes every resource by type + id, reports duplicate ids, answers pool queries ("all uncommon Pyre Warden cards"). Handles `.remap` in exported builds. |
| `Settings` | `src/autoload/settings.gd` | Volumes per bus, screen-shake scale, fast mode, fullscreen, UI scale. `user://settings.cfg`. |
| `MetaProgress` | `src/autoload/meta_progress.gd` | Permanent unlocks, per-class ascension and XP, lifetime stats, bestiary. `user://meta.json`. |
| `RunState` | `src/autoload/run_state.gd` | Current run: class, HP, gold, deck, relics, potions, act/floor, map, RNG. `user://run.json`. |
| `AudioManager` | `src/autoload/audio_manager.gd` | Crossfading music (2 players), ambience layer, pooled SFX with pitch variance. |
| `SceneRouter` | `src/autoload/scene_router.gd` | All screen changes with fade transitions and input blocking. Emits `screen_changed`. |
| `GameManager` | `src/autoload/game_manager.gd` | Flow decisions: new run, continue, start combat, end run → summary. The only place that picks the next screen. |
| `TooltipLayer` | `src/autoload/tooltip_layer.gd` | One global tooltip for mouse hover and keyboard/gamepad focus (`EventBus.tooltip_requested`). |

Deliberately **not** autoloads: `CombatState` (one per fight, owned by the combat screen, so it's freed afterwards and tests can create it freely) and the `PresentationQueue` (lives in the combat scene).

## 4. Core data model (Resource classes)

All in `src/data/`. Every class is `@tool` so the inspector shows typed, grouped fields.

```
GameEffect (abstract)          amount, upgrade_delta, times, target, value_key
 └─ M1 subclasses: DealDamage, GainBlock, ApplyStatus, DrawCards, GainEnergy,
                   GainClassResource, SpendClassResource(+bonus effects), Summon,
                   AddCardToPile, ExhaustCards, Heal, LoseHP, ChangeStance, …

EffectTrigger                  timing (TURN_START, ATTACKED, CARD_PLAYED, …), effects[],
                               amount_from_stacks, every_nth, required_card_tag

CardData                       id, name, description template, type, rarity, target_mode,
                               cost (X / unplayable), effects[], keywords[], tags[],
                               on_discard_effects[], upgrade fields, presentation overrides
StatusEffectData               kind, stack_mode, decay, stat modifiers (flat/multiplier),
                               retains_block, skips_turn, triggers[], behavior_script, VFX/SFX
RelicData                      rarity, class_restriction, triggers[], counter, passive run modifiers
PotionData                     target_mode, effects[], usable_outside_combat
EnemyData                      tier, act, hp range, starting_statuses[], phases[], gold, visuals
 └─ EnemyPhaseData             hp_threshold, selection (SEQUENCE/WEIGHTED/SCRIPTED),
                               moves[], opening_moves[], on_enter_effects[], passive_triggers[]
     └─ EnemyMoveData          intent, effects[], weight, max_consecutive, cooldown,
                               ascension bonus, animation/sfx/vfx
EncounterData                  act, pool (EASY/HARD/ELITE/BOSS), enemies[], weight
CharacterClassData             stats, starting_deck[], starting_relic, secondary_resource,
                               stances[], palette, frame, motif + SFX
ClassResourceData              Heat / Lunar Charge / Ink / Sap: max, persistence, on-max effects
StatusStack                    (status, stacks) authoring helper
```

Runtime (non-Resource) types:

- `CardInstance` (`src/run/`): a specific copy with `upgraded`, a session-unique `uid` (lets UI nodes follow a card between piles), and combat-only cost overrides. At combat start, each deck card is cloned so temporary changes never leak into the deck.
- `RngStreams` (`src/core/`): per-system seeded RNG, serialisable.
- M1 will add `CombatState`, `Combatant` (player, enemy, summon), `EffectContext`, `DamageInfo`, `ActionQueue`.

### Why this shape scales

- **Powers are statuses.** A Power card is just `ApplyStatus(self, "inferno", 1)`. All persistent effects (powers, buffs, debuffs, relics, enemy passives) go through one `EffectTrigger` dispatch, so a new timing hook only has to be added in one place.
- **Description templates.** `"Deal {dmg} damage."` maps `{dmg}` to the effect whose `value_key == &"dmg"`. The card view calls `effect.preview_amount(ctx)`, which runs the same damage pipeline as real play (Strength, Weak, hovered target's Vulnerable). Displayed numbers are therefore always exact, and are coloured green or red when modified.
- **Escape hatches.** `behavior_script` on statuses and relics, and `ai_script` on boss phases, cover the 10% of designs that don't fit the declarative model. Nobody needs to fork the engine for them.

## 5. Combat architecture (Milestone 1: implemented)

```
 Input (CardView drag / keyboard)                       Presentation (M2)
        │ play_card(card, target)                              ▲
        ▼                                                      │ replays beats
 ┌────────────── CombatState (pure logic, no Nodes) ──────┐    │
 │ ActionQueue ──► GameEffect.execute(ctx) ──► Combatant  │    │
 │      ▲                 │  damage pipeline             │    │
 │      └── triggers ◄────┘  (statuses, relics, powers)   │    │
 └────────────────────────┬───────────────────────────────┘    │
                          │ emits                              │
                          ▼                                    │
                      EventBus ──► PresentationQueue ──────────┘
                          ├──► AudioManager hooks (M5)
                          └──► Stats / achievements
```

- **Turn loop:** `COMBAT_START` → [player turn: reset block → `TURN_START` triggers → gain energy → draw → player acts → `TURN_END` triggers → discard hand (retain/ethereal) → status decay] → [each enemy: `TURN_START` → execute intent → `TURN_END` → roll next intent] → `ROUND_END` → repeat.
- **ActionQueue:** effects push actions rather than recursing, so trigger chains (a Thorns kill that fires a "when an enemy dies" relic) resolve in a predictable FIFO order with no stack overflows.
- **Damage pipeline** (single function, used both for real play and for previews): base → + flat (Strength, phase bonuses) → × outgoing multipliers (Weak) → × incoming multipliers (Vulnerable) → + incoming flat → floor at 0 → block absorbs → HP loss → triggers.
- **Code map:** `src/combat/combat_state.gd` (rules and turn loop), `combatant.gd` / `player_combatant.gd` / `enemy_combatant.gd`, `effect_context.gd`, `action_queue.gd`, `damage_calc.gd` (the one pipeline, also used for previews), `card_text.gd` (live descriptions), `effects/` (11 GameEffects), `ai/enemy_ai.gd` (intent selection), `ai/greedy_player_ai.gd` (sim/autoplay AI).
- **Status timing:** Weak/Vulnerable/Frail decay at round end. If an enemy applies one during its turn, the first decay is skipped, so "1 Weak" always covers the player's next turn. Poison ticks at turn start (ignores Block). Burn ticks at turn end (blocked by Block) and then halves.
- **Presentation replay:** the queue groups signals into beats (e.g. `attack_started` + `damage_dealt` + `status_applied` = one beat), plays each beat's animation, then the next. Player input is disabled while beats are pending. Fast mode shortens beats; tests skip them entirely.

## 6. Event bus

`EventBus` signals are grouped as run flow, combat flow, resources, cards & piles, damage/block/statuses, and UI-wide requests (tooltip, screen shake, hit-stop). Full list with payload docs: `src/autoload/event_bus.gd`.

Rules:
- **Payloads carry post-change values** (`hp_after`, `stacks_after`, `block_after`), because presentation lags logic during replay.
- Logic code may only call `EventBus.<signal>.emit(...)`. UI/audio code may only `connect`.
- Screen-local interactions (card hover inside the hand) use local signals. Only events that cross system boundaries go on the bus.

The animation and audio hook plan (deliverable #5) will map every signal to its animation, VFX, SFX and music response.

## 7. Saving

| File | Owner | When written | Contents |
|---|---|---|---|
| `user://settings.cfg` | Settings | On change | Volumes, video, accessibility |
| `user://meta.json` | MetaProgress | Run start/end, unlock earned | Unlocks, ascension per class, class XP, stats, bestiary |
| `user://run.json` | RunState | On arriving at the map after each node | Full run state including RNG stream states and map |

- **Atomic writes** (`.tmp` + rename) and a `_save_version` field for migrations (`SaveIO`).
- Content is referenced by **id**, never by resource path, so files can move. Unknown ids load as warnings and are skipped, so removing a card doesn't brick old saves.
- **Continue semantics:** Slay the Spire style. Quitting mid-combat resumes at the start of that node with the same seed. Because RNG streams are restored, the fight replays identically, which prevents save-scumming.
- Meta and run saves are fully independent. Deleting a corrupt run file never costs the player unlocks.

## 8. UI architecture (Milestone 2: implemented; full plan in `docs/UI_PLAN.md`)

- **One `Theme` resource** (`src/ui/theme/main_theme.tres`, set as the project theme) defines fonts, sizes, colours, StyleBoxes and spacing. It is generated from `UIStyle` (`src/ui/theme/ui_style.gd`), the single source of design tokens; run `tools/build_theme.gd` (File → Run in the script editor) after changing tokens. Components that draw in code read the same constants.
- **Presentation:** `src/presentation/presentation_queue.gd` plays beats and `combat_fx.gd` does numbers, particles, shake and hit-stop. The combat director is `src/combat/combat_screen.gd` (one handler per EventBus signal). Components live in `src/ui/components/`.
- Screens are `Control` trees with proper anchors and containers. Gameplay visuals (characters, VFX) are `Node2D` in a `SubViewport` or `CanvasLayer` underneath the UI.
- Every interactive control has focus neighbours set. Cards in hand are focusable, and an input map (`end_turn`, `view_deck`, `view_draw`, `view_discard`, `map`, `confirm`, `cancel`) works on keyboard and gamepad.

## 9. Testing & tooling

All runnable headless; exit code 0 = pass.

| Command (`godot --headless --path . <scene>`) | What it checks |
|---|---|
| `res://tests/test_runner.tscn` | All `tests/unit/test_*.gd`: damage pipeline, status decay, turn flow, Heat, enemy AI, content validation |
| `res://tests/smoke_test.tscn` | Autoloads, RNG determinism, run save round-trip |
| `res://tests/ui_smoke_test.tscn` | Drives the real combat screen (select, target, auto-play to victory). Add `-- --shots=<dir>` with a display for screenshots |
| `res://tests/sim/auto_battler.tscn -- --fights=1000 --ascension=0` | Balance sim with `GreedyPlayerAI`; prints win rate, turns and HP lost per encounter |

The test framework is a tiny built-in one (`tests/test_case.gd`). Every method named `test_*` is run.
- M4 adds an editor-side **content validator** (missing art, unknown keywords in descriptions, `{tokens}` without a matching `value_key`, cards that aren't in any pool).

## 10. Decisions made (change any of these if you disagree)

| Decision | Choice | Why |
|---|---|---|
| Engine version | Godot 4.4 | Stable, typed loops and arrays, good 2D tooling |
| Layout | Slay the Spire-style single lane: hero on the left, up to 5 enemies on the right; Rootmother summons stand in front of the hero | Keeps targeting readable; Monster Train lanes would double UI scope |
| Renderer | Forward+ by default | Switch to Compatibility if we target web/mobile |
| Base resolution | 1920×1080, `canvas_items` stretch, `expand` aspect | Crisp UI at any size; ultrawide shows more background |
| Save model | Save on map, no mid-combat saves until M6 | Simplest robust model; prevents save-scumming |
| Testing | Small built-in xUnit runner (`tests/test_case.gd`) | Zero dependencies, runs headless in CI; can migrate to GUT if we need its extras |
