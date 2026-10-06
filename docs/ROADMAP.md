# Roadmap

Each milestone ends with something playable and a review checkpoint before the next one starts.

| # | Milestone | Scope | Exit criteria |
|---|---|---|---|
| **0** | **Architecture** ✅ | Folder layout, autoloads, Resource classes, EventBus, save system, class/enemy design docs | Project boots headless; smoke test passes |
| **1** | **Core combat loop** | `CombatState`, `Combatant`, `ActionQueue`, damage pipeline, ~12 `GameEffect`s, data-driven statuses (Block, Strength, Dexterity, Weak, Vulnerable, Frail, Poison, Burn, Thorns, Stun), Pyre Warden (starting deck + ~10 cards + Heat/Overheat + starting relic), 3 Act 1 enemies with intents, placeholder UI (buttons and labels) | Win/lose a full fight against each enemy; combat unit tests pass; headless auto-battler runs 1,000 fights |
| **2** | **UI & animation pass** | Theme/style guide, CardView (live numbers, rarity frames, too-expensive dimming), hand fan + hover, drag-to-play with targeting arrow, HP bars with lagging depletion, status trays + tooltips, intent icons, PresentationQueue, draw/play/discard card motion, lunge + hit-stop + screen shake, damage numbers, death dissolve, keyboard/gamepad input | Combat feels good with placeholder art; fully playable with a controller |
| **3** | **Map & run structure** | Map generator (branching nodes, path rules), map screen (pan/zoom, fog, animated nodes), rewards, shop (buy/remove/upgrade), rest site (heal/upgrade), treasure, 8 events, potions, relic bar, Acts 1–3 with bosses, run summary + death screen, save/continue, main menu + class select | A complete run with one class from menu to victory/death |
| **4** | **Content** | Remaining 3 classes with full pools (~34 cards each), all 15 enemies, 8 elites, 4 bosses with phases, ~40 relics, ~15 potions, ~20 events, Act 4, meta-progression unlock tracks, ascension 1–15, content validator tool | Every designed entity exists as data and is reachable in a run |
| **5** | **Audio & juice** | Adaptive music with crossfades (map/combat/elite/boss layers), per-biome ambience, full SFX hookup via EventBus, class motifs, particles (hits, statuses, rare sparkle), boss intro cinematic, near-death vignette, victory confetti/light rays, menu transitions | Every EventBus signal has its planned audio-visual response |
| **6** | **Balance & polish** | Auto-battler balance sweeps, win-rate targets per class/ascension, accessibility (text size, colourblind-safe intents, reduced shake), settings menu, mid-combat save, performance pass, bug bash | Release-candidate quality |

## Deliverables mapping
1. Architecture → `docs/ARCHITECTURE.md` + `src/` skeleton ✅
2. Class & enemy designs → `docs/design/CLASSES.md`, `docs/design/ENEMIES.md` ✅
3. Core combat loop in GDScript → Milestone 1
4. UI scene plans (combat + map Control hierarchies) → start of Milestone 2
5. Animation/audio hook plan + placeholder asset guide → start of Milestone 2 (hooks) and Milestone 5 (audio)
6. Roadmap → this file
