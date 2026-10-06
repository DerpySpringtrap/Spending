# Duskbound

A run-based roguelike deckbuilder in the style of Slay the Spire / Monster Train, built with **Godot 4.4** and GDScript. *Duskbound* is a working title.

## Status: early playable build
A complete Act 1 run with the **Pyre Warden**: main menu → class select → branching map → fights, elites, rest sites, the merchant, treasure and events → the **Drowned Matriarch** boss → run summary. Death is permanent; runs auto-save on the map and can be continued from the main menu.

### What's in this build
- 30 Pyre Warden cards built around Heat (Stoke, Vent, Overheat), Burn and Block.
- 11 relics, 8 potions, 2 curses, 5 events.
- 7 normal enemies across 8 hallway encounters, 2 elites (Gorehorn Bull, Swamp Witch + Familiar).
- The 2-phase Drowned Matriarch boss with summoned Broodlings.
- Act 2–3, the other three classes and meta-progression unlocks come in later milestones (see the roadmap).

### Play-testing
Open `project.godot` in Godot 4.4+ and press **F5**.

| Action | Mouse | Keyboard / gamepad |
|---|---|---|
| Play a card | Drag onto an enemy, or above the hand for untargeted cards | `←`/`→` pick card, `Enter`/A, then `←`/`→` pick target, `Enter`/A |
| Cancel | Right-click | `Esc` / B |
| End turn | End Turn button | `E` / Y |
| Draw / discard pile | Click the piles | `Q` / LB, `W` / RB |
| Deck | Deck button (top right) | `D` / Back |
| Potions | Click to drink, right-click to discard | – |
| Map | Click a glowing room | `←`/`→` + `Enter` |
| Auto-play a turn | – | `A` (in combat) |

**Debug keys** (only when running from the editor): `F1` help · `F2` +100 gold · `F3` full heal · `F4` win the fight · `F6` skip to the boss (on the map) · `F7` add a random rare card · `F9` add a potion.

The Options menu (main menu) has fast animations, screen-shake strength, damage-number and fullscreen toggles. To replay a run, enter the same seed on the class-select screen; the run summary shows the seed.

### What feedback is most useful
- Difficulty: which fights feel unfair or trivial? (The simulator's numbers are in `docs/ROADMAP.md`.)
- Cards that feel useless, too strong, or confusing.
- Anything unclear on screen: intents, statuses, Heat, tooltips.
- Pacing: animation speed, how long fights and the act take.

## Docs
- [Architecture](docs/ARCHITECTURE.md): folder layout, autoloads, data model, combat/event flow, saving
- [Classes](docs/design/CLASSES.md): Pyre Warden, Moonblade, Hollow Scribe, Rootmother
- [Enemies](docs/design/ENEMIES.md): normal enemies, elites, bosses, ascension
- [UI plan & style guide](docs/UI_PLAN.md): design tokens, combat and map screen hierarchies
- [Animation & audio hooks](docs/HOOKS_AND_ASSETS.md): signal → animation/SFX table, placeholder asset sources
- [Content guide](docs/CONTENT_GUIDE.md): adding cards, statuses, relics and enemies as data
- [Roadmap](docs/ROADMAP.md)

## Tests
Exit code 0 = pass.
```bash
godot --headless --path . res://tests/test_runner.tscn                         # unit tests
godot --headless --path . res://tests/smoke_test.tscn                          # save/RNG smoke test
godot --headless --path . res://tests/ui_smoke_test.tscn                       # plays the combat screen with real input
godot --headless --path . res://tests/flow_test.tscn                           # plays a whole run through the real screens
godot --headless --path . res://tests/sim/auto_battler.tscn -- --fights=1000 --extra=4   # per-encounter balance
godot --headless --path . res://tests/sim/run_sim.tscn -- --runs=300           # full-run simulator
```

## Adding content
Create a resource (right-click in the FileSystem dock → New Resource → `CardData`, `RelicData`, `EnemyData`…) under the matching `content/` folder and give it a unique `id`. `ContentDB` picks it up automatically at startup. See the [content guide](docs/CONTENT_GUIDE.md).

## Credits
- Fonts: [Cinzel](https://github.com/NDISCOVER/Cinzel) and [Nunito](https://github.com/googlefonts/nunito), SIL Open Font License (licenses in `assets/fonts/`).
