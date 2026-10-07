# Duskbound

A run-based roguelike deckbuilder in the style of Slay the Spire / Monster Train, built with **Godot 4.4** and GDScript. *Duskbound* is a working title.

## Status: playable test build
A full run with four classes: main menu → class select → branching map → fights, elites, rest sites, the merchant, treasure and events → **Act 1** boss → boss relic → **Act 2** → boss relic → **Act 3** → run summary. After your first Act 3 win, runs continue into **Act 4: The Umbral Core**, a short final act (rest → shop → elite → the Umbral Sovereign). Death is permanent; runs auto-save on the map and can be continued from the main menu.

### What's in this build
- **Pyre Warden** (30 cards): Heat (Stoke, Vent, Overheat), Burn and Block.
- **Moonblade** (32 cards, unlocked after your first run): Wax/Wane/Shift between phases, build Lunar Charge, enter Eclipse.
- **Hollow Scribe** (32 cards, unlocked by reaching the Act 2 boss): discard and Erase cards for Ink, trigger Footnotes, Inscribe. Some cards open a picker: click cards, then Confirm.
- **Rootmother** (32 cards, unlocked by defeating the Act 2 boss): summon saplings that stand in front of you, take single-target hits (leftover damage carries through if they die) and act at the end of your turn; Sap and Graft; Poison.
- **Act 1** (The Drowned Thicket), **Act 2** (The Gilded Catacombs), **Act 3** (The Shattered Observatory) and **Act 4** (The Umbral Core): 17 enemies, 8 elites, 4 bosses.
- 38 relics (5 boss relics), 14 potions, 2 curses, 15 events.
- **Meta-progression:** each class earns XP per run. Level 2 and 4 add new cards to the reward pool, level 3 adds class relics. Winning a run unlocks the next Ascension level (1–15) for that class.
- Synthesized music, ambience and sound effects for every screen and combat beat (volume sliders in Options).
- Still to come: the Astromancer (fifth class), card art, real recorded audio (see the roadmap).

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

**Debug keys** (in the editor and in play-test builds): `F1` help · `F2` +100 gold · `F3` full heal · `F4` win the fight · `F6` skip to the boss (on the map) · `F7` add a random rare card · `F8` unlock every class, card, relic and ascension · `F9` add a potion.

The Options menu (main menu) has volume sliders (master, music, SFX, UI, ambience), fast animations, screen-shake strength, damage-number and fullscreen toggles. To replay a run, enter the same seed on the class-select screen; the run summary shows the seed.

### What feedback is most useful
- Difficulty: which fights feel unfair or trivial? (The simulator's numbers are in `docs/ROADMAP.md`.)
- Cards that feel useless, too strong, or confusing.
- Anything unclear on screen: intents, statuses, Heat, phases and Lunar Charge, Ink and the card picker, summons, the Umbra meter, tooltips.
- Sound: anything too loud, repetitive or missing.
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

## Exporting a Windows build
Install the Godot 4.4.1 export templates (Editor → Manage Export Templates), then:
```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Duskbound.exe
```
The preset (`export_presets.cfg`) embeds the game data in the .exe, leaves out `tests/`, `tools/` and `docs/`, and sets the `playtest` feature tag so the debug keys stay on. Remove that tag for a public release.

## Adding content
Create a resource (right-click in the FileSystem dock → New Resource → `CardData`, `RelicData`, `EnemyData`…) under the matching `content/` folder and give it a unique `id`. `ContentDB` picks it up automatically at startup. See the [content guide](docs/CONTENT_GUIDE.md).

## Credits
- Fonts: [Cinzel](https://github.com/NDISCOVER/Cinzel) and [Nunito](https://github.com/googlefonts/nunito), SIL Open Font License (licenses in `assets/fonts/`).
