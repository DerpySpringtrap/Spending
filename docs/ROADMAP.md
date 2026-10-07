# Roadmap

Each milestone ends with something playable and a review checkpoint before the next one starts.

| # | Milestone | Scope | Exit criteria |
|---|---|---|---|
| **0** | **Architecture** ✅ | Folder layout, autoloads, Resource classes, EventBus, save system, class/enemy design docs | Project boots headless; smoke test passes |
| **1** | **Core combat loop** ✅ | `CombatState`, `Combatant`, `ActionQueue`, damage pipeline, ~12 `GameEffect`s, data-driven statuses (Block, Strength, Dexterity, Weak, Vulnerable, Frail, Poison, Burn, Thorns, Stun), Pyre Warden (starting deck + ~10 cards + Heat/Overheat + starting relic), 3 Act 1 enemies with intents, placeholder UI (buttons and labels) | Win/lose a full fight against each enemy; combat unit tests pass; headless auto-battler runs 1,000 fights |
| **2** | **UI & animation pass** ✅ | Theme/style guide, CardView (live numbers, rarity frames, too-expensive dimming), hand fan + hover, drag-to-play with targeting arrow, HP bars with lagging depletion, status trays + tooltips, intent icons, PresentationQueue, draw/play/discard card motion, lunge + hit-stop + screen shake, damage numbers, death dissolve, keyboard/gamepad input | Combat feels good with placeholder art; fully playable with a controller |
| **3** | **Map & run structure** ✅ *(Act 1, early playable)* | Map generator (branching nodes, path rules), map screen (pan/zoom, fog, animated nodes), rewards, shop (buy/remove/upgrade), rest site (heal/upgrade), treasure, 8 events, potions, relic bar, Acts 1–3 with bosses, run summary + death screen, save/continue, main menu + class select | A complete run with one class from menu to victory/death |
| **4** | **Content** | Remaining 3 classes with full pools (~34 cards each), all 15 enemies, 8 elites, 4 bosses with phases, ~40 relics, ~15 potions, ~20 events, Act 4, meta-progression unlock tracks, ascension 1–15, content validator tool | Every designed entity exists as data and is reachable in a run |
| **5** | **Audio & juice** | Adaptive music with crossfades (map/combat/elite/boss layers), per-biome ambience, full SFX hookup via EventBus, class motifs, particles (hits, statuses, rare sparkle), boss intro cinematic, near-death vignette, victory confetti/light rays, menu transitions | Every EventBus signal has its planned audio-visual response |
| **6** | **Balance & polish** | Auto-battler balance sweeps, win-rate targets per class/ascension, accessibility (text size, colourblind-safe intents, reduced shake), settings menu, mid-combat save, performance pass, bug bash | Release-candidate quality |

## Deliverables mapping
1. Architecture → `docs/ARCHITECTURE.md` + `src/` skeleton ✅
2. Class & enemy designs → `docs/design/CLASSES.md`, `docs/design/ENEMIES.md` ✅
3. Core combat loop in GDScript → Milestone 1 ✅
4. UI scene plans (combat + map Control hierarchies) → `docs/UI_PLAN.md` ✅
5. Animation/audio hook plan + placeholder asset guide → `docs/HOOKS_AND_ASSETS.md` ✅ (audio hookup itself is Milestone 5)
6. Roadmap → this file

## Milestone 1 notes

**Delivered:** combat engine (`src/combat/`), 11 effects, 13 statuses, Pyre Warden (17 cards including starters, Heat/Vent/Overheat, Cinder Heart), Bog Lurker / Mire Toad / Thornback Beetle across 5 encounters, placeholder combat screen (boot → *Start Test Combat*), 47 unit tests, UI smoke test, auto-battler.

**Auto-battler baseline** (starter deck + Cinder Heart, A0, 200 fights each, `GreedyPlayerAI`):

| Encounter | Pool | Win % | Avg rounds | Avg HP lost |
|---|---|---|---|---|
| a1_two_toads | Easy | 100 | 2.9 | 4.8 |
| a1_bog_lurker | Easy | 100 | 4.0 | 5.4 |
| a1_beetle | Easy | 100 | 3.0 | 15.6 |
| a1_three_toads | Hard | 100 | 3.8 | 13.1 |
| a1_toad_and_beetle | Hard | 100 | 4.3 | 29.4 |

Early read for M6 tuning: Thornback Beetle is heavy for the easy pool (the AI attacks straight into 3 Thorns), and two Mire Toads are very light.

## Milestone 2 notes

**Delivered:** design tokens + generated Theme (`src/ui/theme/`), Cinzel/Nunito fonts (OFL), flat vector glyph set, `PresentationQueue` beat system, combat director rewrite, and components:
- Cards: CardView (live numbers, rarity frames, dimmed when unaffordable, glow, rare sparkle, upgrade glow), HandView (fan, hover lift, drag-to-play, AoE arming, keyboard/gamepad focus and targeting), TargetingArrow.
- Combatants: CombatantView (placeholder vector bodies, code-built AnimationPlayer clips, hit flash, dissolve death shader), HealthBar (lagging ghost bar, block badge), StatusTray/StatusIcon, IntentView.
- HUD and overlays: EnergyOrb, ResourceGauge, PileButton, TurnBanner, TopBar/RelicIcon, PileViewer, ResultOverlay, global TooltipLayer, CombatFX (damage numbers, GPU particle bursts, screen shake, hit-stop), BiomeBackdrop.

**Input map:** `end_turn` (E / Y), `view_draw` (Q / LB), `view_discard` (W / RB), `view_deck` (D / Back), plus the built-in `ui_*` actions.

**Verification:** `tests/ui_smoke_test.tscn` plays with real mouse-drag and keyboard input events and checks after every animation burst that HP, block, statuses, intents, hand, pile counts, energy and Heat on screen match the combat state.

**Deferred:** class select and main menu (M3, with the map), settings menu (M6), boss intro cinematic and near-death vignette (M5).

## Milestone 3 notes: early playable

**Delivered:** main menu (with options), class select (Warden playable, the other three shown as coming), seeded map generator (15 floors, Slay the Spire–style room rules) with fog of war, reward / shop / rest / treasure / event screens, card picker (upgrade previews, removal), potions in and out of combat (targeted potions use the arrow), run summary with stats, save on map + continue, debug hotkeys.

**Content added:** 14 Warden cards (30 total), 4 new powers, 11 relics, 8 potions, 2 curses, 5 events, Wisp Lantern, Hollow Woodsman, Gorehorn Bull and Swamp Witch elites, and the Drowned Matriarch boss with Broodlings. Data-only via new `EventData` / `EventChoice` / `EventOutcome` resources plus `SummonEnemyEffect` and `RemoveDebuffsEffect`.

**Scope note:** the run ends in victory after the Act 1 boss. Acts 2–3 need the Milestone 4 enemy content.

**Balance pass (simulators):** the first full-run simulation won 0% of runs. Traces showed the Matriarch's re-summoned Toxic Burst toads poisoning the player to death, so she now summons dedicated Broodlings with a cooldown. The Gorehorn Bull, Thornback Beetle and Mire Toad were also toned down. Current numbers for the deliberately simple AI (no block planning, random paths):

| Measure | Result |
|---|---|
| Full Act 1 runs won (`run_sim`, 300 runs) | 14% (avg floor 12.9) |
| Boss at full HP, starter + 8 random cards | 40% |
| Gorehorn Bull / Swamp Witch at full HP, starter + 4 cards | 99% / 100% (≈42 / 26 HP lost) |
| Hallway fights | 100%, 9–25 HP lost on average |

A human player should do considerably better than this AI. Treat these as a baseline to compare against play-testing feedback.

## Milestones 4–5 progress: test build 2

Built in the order requested: sound, the Moonblade, Act 2, meta-progression.

**Audio (part of M5):** every sound is synthesized by `tools/audio/synth_audio.py`: 45 SFX, 6 music loops (menu, map ×2, combat, elite, boss), 2 ambiences. The combat director plays sounds on its beats, screens pick their music and ambience, and every button gets hover/click sounds. Options has volume sliders. Still to do: boss stems, heartbeat layer.

**Moonblade:** 32 cards, phases (Waxing, Waning, Eclipse), Lunar Charge, 3 class relics. New engine pieces: `ChangeStanceEffect`, `ConditionalEffect`, once-per-turn and requires-status triggers, the phase-changes scale, Moonfall's cost reduction. Tuned down from the design (+2 per phase instead of +3, Riposte 2, 66 HP, Moonstep draws only when upgraded) after the simulator showed it far ahead of the Warden.

**Act 2:** Gilded Skeleton, Candle Acolyte, Coin Mimic, Crypt Hound, Embalmer; elites Gilded Knight, Twin Reliquaries, Plague Censer; the Gilded Hierophant with two Gold Idols. New engine pieces: revive once (Reassemble), gold theft returned on kill, enemy escape, stack loss on HP loss. Bosses now offer a choice of 3 boss relics; the next act heals 75% of missing HP. The run is won after the Act 2 boss.

**Meta-progression:** class XP and levels 1–4 (cards at 2 and 4, class relics at 3), the Moonblade unlocks after any finished run, wins unlock the next Ascension. Ascension 1 (more elites) and 14 (−5 max HP) are now in. Debug `F8` unlocks everything.

**Simulator numbers** (deliberately simple AI, A0, 200 runs, both acts):

| Class | Full-run wins | Notes |
|---|---|---|
| Pyre Warden | ~2% | The AI doesn't plan Heat or Vent, so this undersells the class |
| Moonblade | ~16% | Act 2 boss ~33% with starter + 10 random cards |

Play-testing feedback on Act 2 difficulty is the most useful next input.

## Milestone 4 progress: test build 3

**Balance pass:** Pyre Warden buffed (85 HP, Overheat 15 / 2 recoil, stronger starters); Moonblade's Starfall and Silver Tempest trimmed; Embalmer and Candle Acolyte softened. The simulator AI now values reaching Overheat.

**Hollow Scribe:** 32 cards, Ink (start 2, +1 per turn, +1 per discard or Erase), Footnotes, Inscribe, Dog-Eared Tome + 3 class relics. New engine pieces: `ChooseCardsEffect` (the player picks cards; the card pauses and resumes after), a multi-select picker, `ExhaustFromHandEffect`, always-on `class_triggers`, card-type trigger filters, resource cost discounts. Unlocks by reaching the Act 2 boss.

**Act 3:** Clockwork Sentinel, Star Shard, Storm Harpy, Void Leech, Astral Weaver; elites Chronomancer Construct and Starfall Seraph; the Orrery (alignment → gravity well → Supernova countdown). New engine pieces: lifesteal, HP rewind. The run is now won after the Act 3 boss.

**Simulator numbers** (simple AI, A0, 400 runs, base unlocks, all three acts):

| Class | Full-run wins |
|---|---|
| Pyre Warden | ~7% |
| Moonblade | ~6% |
| Hollow Scribe | ~9% |

Most simulated runs still end at the Act 1 boss; a person should get much further. Next up: Rootmother, Act 4, more relics/potions/events, the remaining ascension levels.

## Backlog (requested, not yet scheduled)
- **Card art:** every card gets its own illustration. Art is themed per class, so the same kind of card (e.g. an attack) looks different for the Pyre Warden than for the Moonblade, and depicts what that specific card does. Hook: `CardData.art` already exists; `CardView` currently draws a placeholder type glyph when it's empty. Lower priority than sound, the second class and Act 2.
- **Real audio to replace the synthesized placeholders:** source sound effects from free SFX sites and copyright-free music (CC0 preferred; anything CC-BY gets a line in `CREDITS.md`). If downloads are blocked in the build environment, send the user a list of links to download and hand back. The swap is data-only: drop files with the same names into `assets/audio/` or edit the tables in `src/audio/sound_bank.gd`. Requested for later, not now.
