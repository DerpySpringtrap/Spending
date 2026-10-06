# Duskbound

A run-based roguelike deckbuilder in the style of Slay the Spire / Monster Train, built with **Godot 4.4** and GDScript. *Duskbound* is a working title.

## Status
Milestone 2 (UI & animation) is complete. Combat has the full flat vector presentation: fanned hand, drag-to-play with a targeting arrow, animated HP bars, intents, statuses with tooltips, hit-stop, screen shake, damage numbers, and controller support. Next up: Milestone 3, the map and run structure. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Docs
- [Architecture](docs/ARCHITECTURE.md): folder layout, autoloads, data model, combat/event flow, saving
- [Classes](docs/design/CLASSES.md): Pyre Warden, Moonblade, Hollow Scribe, Rootmother
- [Enemies](docs/design/ENEMIES.md): normal enemies, elites, bosses, ascension
- [UI plan & style guide](docs/UI_PLAN.md): design tokens, combat and map screen hierarchies
- [Animation & audio hooks](docs/HOOKS_AND_ASSETS.md): signal → animation/SFX table, placeholder asset sources
- [Content guide](docs/CONTENT_GUIDE.md): adding cards, statuses, relics and enemies as data
- [Roadmap](docs/ROADMAP.md)

## Running
Open `project.godot` in Godot 4.4+, press F5, then **Start Test Combat**.
Controls: **drag** a card onto an enemy (or above the hand for untargeted cards). Keyboard/gamepad: `←`/`→` choose a card, `Enter`/A pick it up, `←`/`→` choose a target, `Enter`/A play, `Esc`/B cancel. `E`/Y end turn · `Q`/LB draw pile · `W`/RB discard pile · `1`–`9` play by position · `A` auto-play (debug).

Tests (exit code 0 = pass):
```bash
godot --headless --path . res://tests/test_runner.tscn                         # unit tests
godot --headless --path . res://tests/smoke_test.tscn                          # save/RNG smoke test
godot --headless --path . res://tests/ui_smoke_test.tscn                       # plays the combat screen with real input
godot --headless --path . res://tests/sim/auto_battler.tscn -- --fights=1000   # balance simulation
```

## Adding content
Create a resource (right-click in the FileSystem dock → New Resource → `CardData`, `RelicData`, `EnemyData`…) under the matching `content/` folder and give it a unique `id`. `ContentDB` picks it up automatically at startup. See the [content guide](docs/CONTENT_GUIDE.md).

## Credits
- Fonts: [Cinzel](https://github.com/NDISCOVER/Cinzel) and [Nunito](https://github.com/googlefonts/nunito), SIL Open Font License (licenses in `assets/fonts/`).
