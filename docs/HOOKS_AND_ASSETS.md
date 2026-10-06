# Animation & Audio Hooks, Placeholder Assets

Deliverable #5: exactly where animation, VFX, SFX and music attach, and what to use for placeholder assets while developing.

## 1. How hooks work

```
CombatState ──emit──► EventBus ──► CombatScreen (director) ──push beats──► PresentationQueue
                         │                                                    │ plays beats in order,
                         │                                                    │ parallel within a group
                         └──► AudioManager hooks (M5) ◄── beat callbacks ──────┘
```

- **Game logic never waits.** `CombatState` resolves a whole card or enemy turn instantly and emits signals with post-change payloads.
- **The director** (`src/combat/combat_screen.gd`, `_on_*` handlers) turns each signal into a **beat**: a callable that starts tweens, AnimationPlayer clips, particles and sounds, plus a duration.
- **`PresentationQueue`** (`src/presentation/presentation_queue.gd`) plays beats one after another. Consecutive beats with the same group key and different targets run **in parallel** (an AoE hits every enemy at once; a multi-hit on one enemy plays hit by hit). Input unlocks only when the queue is idle.
- **Audio attaches to the same beats**, so a sound always lines up with its animation (the impact sound fires on the impact frame, not when the logic ran). Each beat calls `AudioManager.play(&"id")`; `SoundBank` (`src/audio/sound_bank.gd`) maps ids to files, picks a random variant (`hit` → `hit_1..3`) and applies a per-id gain so call sites don't tune the mix. In a parallel group only the first beat plays its sound, so an AoE status doesn't stack five copies.

## 2. Signal → response table

Status: ✅ = implemented in M2, 🔊 = audio hooked up (audio pass). Rows still marked *(planned)* are not wired yet.

| EventBus signal | Beat (group, duration) | Animation / VFX (M2) | Audio (M5) |
|---|---|---|---|
| `combat_started` | – | Enemies slide in; boss intro cinematic for `has_intro_cinematic` | Crossfade to combat / elite / boss track; act ambience continues 🔊 |
| `turn_started` (player) | banner, 0.7s | ✅ "Your Turn" banner slides and fades | Soft gong 🔊 |
| `turn_started` (first enemy) | banner, 0.6s | ✅ "Enemy Turn" banner | Low drum hit 🔊 |
| `block_cleared` | instant | ✅ Block badge shrinks out | – |
| `energy_changed` | instant | ✅ Orb number pops; dims at 0 | Refill shimmer on turn start *(planned)* |
| `class_resource_changed` | 0.1s | ✅ Heat pips fill or drain with a glow | Ember crackle (pitch rises with Heat) 🔊 |
| `class_resource_maxed` | 0.5s | ✅ Gauge flashes, "OVERHEAT!" banner, strong shake | Kettle hiss → boom; class motif 🔊 |
| `card_drawn` | draw, 0.09s each | ✅ Card arcs from the draw pile into the hand; hand re-fans | Card flip, ±5% pitch 🔊 |
| `deck_shuffled` | 0.35s | ✅ Card backs fly from discard to draw | Riffle shuffle 🔊 |
| `card_played` | play, 0.25s | ✅ Card flies to the play spot and scales up; Attack → hero lunge; Power → card dissolves into the hero | Per-card or class play SFX; Powers/signature rares play the class motif 🔊 |
| `card_discarded` | discard, 0.12s | ✅ Card flies to the discard pile, shrinking | Soft whoosh 🔊 |
| `card_exhausted` | 0.3s | ✅ Card burns up (rises, fades to ember) | Paper burn 🔊 |
| `card_created` | 0.45s | ✅ New card shown at centre, then flies to its pile | Sparkle 🔊 |
| `attack_started` | 0.18s | ✅ Enemy lunge (AnimationPlayer `attack`) | Wind-up whoosh 🔊 |
| `damage_dealt` | hit, 0.22–0.35s | ✅ Hurt clip, white flash, damage number, hit sparks, HP bar drop with lagging ghost bar, shake ∝ damage, **hit-stop** (≥15 dmg or heavy move). Poison = green drip, Burn = flare, Blocked = shield sparks | Impact by damage type (slash/blunt/fire/poison); heavy hits add low thump 🔊 |
| `block_gained` | block, 0.15s | ✅ Shield badge pops (back-ease), blue "+N" | Shield clank 🔊 |
| `block_broken` | (with hit) | ✅ Shield shatter particles | Glass/metal crack 🔊 |
| `healed` | 0.2s | ✅ Green "+N", bar rises | Chime 🔊 |
| `status_applied` | status, 0.12s | ✅ Icon pops into the tray; tinted puff on the target; stack counter bumps | Buff rise / debuff fall stingers 🔊 |
| `status_removed` | instant | ✅ Icon fades out | – |
| `status_triggered` | 0.15s | ✅ Icon pulses, tick VFX (Poison drip, Burn flare, Thorns spikes) | Status proc SFX *(planned)* |
| `intent_changed` | instant | ✅ Intent icon and number update with a small pop | – |
| `combatant_died` | 0.6s | ✅ Flash, shrink and fade with an ash burst | Death cry + dissolve 🔊 |
| `boss_phase_changed` | 1.2s | Boss roar, screen flash, phase name banner | Music adds a layer / switches stem *(planned)* |
| `relic_triggered` | instant | ✅ Relic icon in the top bar flashes | Relic tick *(planned)* |
| `combat_ended` | 0.8s | ✅ Victory: hero pose + light burst, overlay. Defeat: desaturate + vignette | Victory/defeat stinger; music ducks 🔊 |
| `run_hp_changed` (≤25% HP) | – | Near-death red vignette pulse (M5) | Heartbeat layer *(planned)* |
| `gold_changed` | – | Coin counter rolls (M3) | Coin clink 🔊 |
| `relic_obtained` | – | Relic flies to the bar (M3) | Rewarding chime 🔊 |
| `screen_changed` | – | SceneRouter fade | Music crossfade per screen 🔊 |

UI-only audio: `AudioManager` watches `SceneTree.node_added`, so **every `BaseButton` in the game automatically gets hover and click sounds** on the UI bus. Card hover, map node selection, reward claims (gold/relic/potion/card), shop purchases and resting call `AudioManager.play_ui_id` / `play` directly.

## 3. Music & ambience

**Implemented:** every sound is synthesized by `tools/audio/synth_audio.py` (numpy + scipy + ffmpeg; run `python3 tools/audio/synth_audio.py` to regenerate) into `assets/audio/{sfx,music,ambience}/` as OGG. Music: menu, map (act 1/act 2), combat, elite, boss, all seamless loops in related keys. Ambience: swamp, crypt. `AudioManager._on_screen_changed` picks the screen's music and act ambience; the combat screen picks combat/elite/boss from the encounter pool. Volume sliders for all five buses are in **Options** on the main menu. To use real recordings, drop files with the same names into `assets/audio/` (or edit the `SoundBank` tables).

Original plan (stems and heartbeat layer still to do):
- **Buses:** Master → Music, SFX, UI, Ambience (already in `default_bus_layout.tres`; volume sliders backed by `Settings`).
- **Tracks:** map/exploration, normal combat, elite combat, boss (2 stems: phase 1 and phase 2+ layer), victory and defeat stingers, main menu. Per-act variants of combat/map in the same key and tempo so crossfades are seamless.
- **Crossfades:** `AudioManager.play_music(stream, fade)` already crossfades two players. M5 adds stem layering for bosses (two synced players, the layer faded in on `boss_phase_changed`).
- **Ambience:** one loop per act (frogs and drips / candle crackle and choir hum / wind and gears / void drone), started on `act_started` and kept under the music.
- **Class motifs:** a 2–4 second accent per class, played on top of the music when `CardData.plays_class_motif` cards resolve.

## 4. Placeholder assets & tools

Prefer **CC0** (no attribution) while prototyping. Keep a `CREDITS.md` line for anything CC-BY.

| Need | Source | License | Notes |
|---|---|---|---|
| UI icons (intents, statuses, relics) | **game-icons.net** | CC BY 3.0 | 4,000+ flat icons that fit the vector style. Export as SVG and tint in Godot |
| UI kit, cursors, generic icons | **Kenney.nl** (UI Pack, Game Icons, Board Game Icons) | CC0 | Clean flat shapes |
| Particles / VFX textures | **Kenney Particle Pack**, **Godot Shaders** (godotshaders.com) | CC0 / per-shader (mostly MIT/CC0) | Dissolve, glow and outline shaders |
| SFX | **Kenney** (Interface, Impact, RPG, Casino packs for card flips) | CC0 | Card, UI and impact sounds out of the box |
| SFX (generate) | **jsfxr / ChipTone / Bfxr** | Output is yours | Quick hit/coin/powerup sounds |
| SFX (library) | **Freesound.org** (filter to CC0), **Sonniss GDC bundles** | CC0 / royalty-free | Check each file's license |
| Music | **Kevin MacLeod / Incompetech** | CC BY 4.0 | Big catalogue, credit required |
| Music (CC0) | **OpenGameArt** (filter CC0), Juhani Junkala's packs | CC0 | Loopable chiptune and orchestral |
| Music (make your own) | **BeepBox**, **LMMS**, **Bosca Ceoil** | Free | Fast placeholder loops in the same key |
| Fonts | **Google Fonts** (Cinzel, Nunito in use) | SIL OFL | Already in `assets/fonts/` with licenses |
| Vector art tools | **Inkscape**, **Figma** (free tier), **Krita** | Free | Inkscape SVG → Godot imports SVG directly |
| Animation | Godot AnimationPlayer; **Spine** / **DragonBones** later for skeletal | – | Placeholder rigs are code-built AnimationPlayer clips |

**Swap-in path for real art:** each `CombatantView` builds its placeholder body from `PlaceholderArt` only when `EnemyData.visual_scene` / `CharacterClassData.combat_scene` is empty. Assign a scene with the same AnimationPlayer clip names (`idle`, `attack`, `hurt`) and the real art takes over with no code changes.
