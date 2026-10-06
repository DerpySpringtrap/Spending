# Duskbound

A run-based roguelike deckbuilder in the style of Slay the Spire / Monster Train, built with **Godot 4.4** and GDScript. *Duskbound* is a working title.

## Status
Milestone 1 (core combat loop) is complete. You can play Pyre Warden fights against Act 1 enemies on a placeholder UI. Next up: Milestone 2, the UI and animation pass. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Docs
- [Architecture](docs/ARCHITECTURE.md): folder layout, autoloads, data model, combat/event flow, saving
- [Classes](docs/design/CLASSES.md): Pyre Warden, Moonblade, Hollow Scribe, Rootmother
- [Enemies](docs/design/ENEMIES.md): normal enemies, elites, bosses, ascension
- [Content guide](docs/CONTENT_GUIDE.md): adding cards, statuses, relics and enemies as data
- [Roadmap](docs/ROADMAP.md)

## Running
Open `project.godot` in Godot 4.4+, press F5, then **Start Test Combat**.
Controls: click a card, then an enemy · `1`–`9` select · `E` end turn · `A` auto-play turn · `Esc` cancel.

Tests (exit code 0 = pass):
```bash
godot --headless --path . res://tests/test_runner.tscn                         # unit tests
godot --headless --path . res://tests/smoke_test.tscn                          # save/RNG smoke test
godot --headless --path . res://tests/ui_smoke_test.tscn                       # drives the combat screen
godot --headless --path . res://tests/sim/auto_battler.tscn -- --fights=1000   # balance simulation
```

## Adding content
Create a resource (right-click in the FileSystem dock → New Resource → `CardData`, `RelicData`, `EnemyData`…) under the matching `content/` folder and give it a unique `id`. `ContentDB` picks it up automatically at startup. See the [content guide](docs/CONTENT_GUIDE.md).
