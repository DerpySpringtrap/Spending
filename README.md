# Duskbound

A run-based roguelike deckbuilder in the style of Slay the Spire / Monster Train, built with **Godot 4.4** and GDScript. *Duskbound* is a working title.

## Status
Milestone 0 (architecture) is complete. Next up: Milestone 1, the core combat loop. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Docs
- [Architecture](docs/ARCHITECTURE.md): folder layout, autoloads, data model, combat/event flow, saving
- [Classes](docs/design/CLASSES.md): Pyre Warden, Moonblade, Hollow Scribe, Rootmother
- [Enemies](docs/design/ENEMIES.md): normal enemies, elites, bosses, ascension
- [Roadmap](docs/ROADMAP.md)

## Running
Open `project.godot` in Godot 4.4+ and press F5.

Headless smoke test:
```bash
godot --headless --path . res://tests/smoke_test.tscn   # exit code 0 = pass
```

## Adding content
Create a resource (right-click in the FileSystem dock → New Resource → `CardData`, `RelicData`, `EnemyData`…) under the matching `content/` folder and give it a unique `id`. `ContentDB` picks it up automatically at startup.
