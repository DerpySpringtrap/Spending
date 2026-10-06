# UI Plan & Style Guide

Deliverable #4: the design language and the Control hierarchies for the combat and map screens. The combat screen is implemented in Milestone 2. The map screen is the blueprint for Milestone 3.

## 1. Design language: flat vector

Placeholder-friendly and readable at any resolution. Shapes are flat fills with rounded corners, no textures or gradients beyond subtle two-tone backgrounds, and strong silhouettes. Real art can replace any piece without changing layout.

### Tokens (single source of truth: `src/ui/theme/ui_style.gd`)

| Token group | Values |
|---|---|
| **Surfaces** | `BG_DEEP #120F17`, `BG #1B1722`, `PANEL #262030`, `PANEL_HI #342B42`, `OUTLINE #0A080D` |
| **Text** | `TEXT #F2ECE4`, `TEXT_DIM #A69FB0`, `TEXT_DISABLED #6B6473` |
| **Accent** | `GOLD #F6B43C` (focus, selection, primary buttons) |
| **Card types** | Attack `#7A3530`, Skill `#2F4F73`, Power `#5A3A78`, Status `#4A4A4A`, Curse `#3A1F3A` |
| **Rarity frames** | Starter/Common `#9AA0A6`, Uncommon `#4FA3E0`, Rare `#E8B34A`, Special `#B07CE0` |
| **Numbers** | Damage `#FF5A4A`, Poison `#7BC950`, Burn `#F07A2A`, Block `#6CB8F0`, Heal `#5BE08A`, Energy `#F6D743`, Buffed `#7CFC8A`, Debuffed `#FF6B6B` |
| **Type** | Display: **Cinzel Bold** (titles, card names, banners). Body: **Nunito** Regular/Bold/ExtraBold (everything else). Sizes: 14 / 16 / 20 / 26 / 36 / 64 |
| **Spacing** | 4-pt grid: 4 / 8 / 12 / 16 / 24 / 32. Corner radius 6 (small), 12 (panels), 14 (cards) |
| **Motion** | Durations: fast 0.12s, base 0.22s, slow 0.4s. Easing: UI in `EASE_OUT + TRANS_CUBIC`, pops `TRANS_BACK`, exits `EASE_IN`. No linear motion. Everything scales with `UIStyle.speed` (fast mode) |

`UIStyle.build_theme()` turns the tokens into a Godot `Theme` (buttons, panels, labels, tooltips, scrollbars, focus rings). `tools/build_theme.gd` (an EditorScript) saves it to `src/ui/theme/main_theme.tres`, which is set as the project's custom theme, so the editor preview matches the game.

### Interaction rules
- Every interactive element has hover, pressed, disabled and **focus** states. The focus ring is a 3px gold outline, so keyboard and gamepad users always see where they are.
- Tooltips appear after 0.25s hover or on focus. One global `TooltipLayer` (autoload), positioned beside the owner and flipped at screen edges.
- Disabled is never the only signal: unaffordable cards also turn their cost red.

## 2. Combat screen (implemented)

```
CombatScreen (Control, full rect)                 src/combat/combat_screen.tscn
├── Background (ColorRect + biome gradient)
├── World (Control, full rect)                     ← screen shake moves this
│   ├── PlayerAnchor (Control, ~22% x, 62% y)
│   │   └── CombatantView (player)
│   └── EnemyRow (HBoxContainer, right half, bottom-aligned)
│       └── CombatantView × n
│           ├── Body (Node2D) → placeholder vector art + AnimationPlayer (idle/attack/hurt)
│           ├── IntentView (enemies, above head)
│           ├── HealthBar (+ block badge)
│           └── StatusTray → StatusIcon × n
├── HUD (Control, full rect, mouse pass-through)
│   ├── TopBar (PanelContainer, top)              class name · HP · gold · relic bar
│   ├── EnergyOrb (bottom-left)
│   ├── ResourceGauge (beside the orb: Heat pips)
│   ├── DrawPileButton (bottom-left corner)
│   ├── DiscardPileButton (bottom-right corner)
│   ├── ExhaustPileButton (above discard, hidden when empty)
│   ├── EndTurnButton (bottom-right, above discard)
│   └── HandView (bottom band, full width)        fan layout, hover, drag, focus
├── FxLayer (Control, full rect, mouse ignore)    flying cards, damage numbers, particles
│   └── TargetingArrow
├── TurnBanner (centered)                         "Your Turn" / "Enemy Turn" / "Overheat!"
├── PileViewer (overlay, hidden)
└── ResultOverlay (overlay, hidden)
```

**Hand layout:** cards sit on an arc (radius ~2200px). Spacing compresses as the hand grows, up to 10 cards. The hovered or focused card scales to 1.25, straightens, rises above the hand, and pushes its neighbours aside. Cards pivot at the bottom centre.

**Drag-to-play:**
- *Single-target:* the card lifts to a "ready" spot and a bezier **TargetingArrow** follows the cursor. The enemy under it shows a reticle, and the card text previews damage against that enemy. Release on an enemy plays the card; release elsewhere or right-click cancels.
- *Untargeted / AoE:* the card follows the cursor. Crossing the play line (~40% screen height) gives it a gold glow. For AoE cards **every** enemy shows the reticle. Release above the line plays it.

**Keyboard/gamepad:** ←/→ (D-pad) moves the hand focus. Accept (Enter/Space/A) picks up the focused card. For targeted cards, ←/→ cycles enemies, Accept plays, Cancel (Esc/B) puts the card back. `E`/Y ends the turn; `Q`/LB views the draw pile and `W`/RB the discard pile. `1`–`9` play a card by position.

## 3. Map screen (Milestone 3 blueprint)

```
MapScreen (Control, full rect)                    src/map/map_screen.tscn
├── Background (biome parchment / starfield per act)
├── MapViewport (SubViewportContainer, full rect, stretch)
│   └── SubViewport
│       └── MapWorld (Node2D)
│           ├── PathLayer (Node2D)                Line2D per edge; dashed = unexplored, solid gold = travelled
│           ├── NodeLayer (Node2D)
│           │   └── MapNodeView × n               icon (combat/elite/rest/shop/treasure/event/boss),
│           │                                     idle bob, pulse when selectable, check-mark when visited
│           ├── FogLayer (Node2D + shader)        reveals floors up to current + 2
│           ├── PlayerMarker
│           └── MapCamera (Camera2D)              smooth pan to current floor, scroll-wheel/trigger zoom,
│                                                 drag to pan, limits clamp to the map
├── HUD (Control)
│   ├── TopBar (shared component with combat: HP · gold · potions · relics · deck button)
│   ├── Legend (PanelContainer, right)            icon key with tooltips
│   └── ActTitle (Label, top centre, fades in on act start)
└── DeckViewer (overlay, shared PileViewer component)
```

- **Generation:** 7 columns × 15 floors. 6 paths walked bottom to top, merging where they cross. Node types follow Slay the Spire–style rules: no elites before floor 6, a rest site before the boss, a treasure at mid-act, no two shops in a row.
- **Navigation:** selectable nodes are focusable. ←/→ moves between the reachable options and Accept travels. The camera follows focus.
- **Fog of war:** unexplored floors are desaturated and their icons hidden behind "?" until within 2 floors. The boss is always visible as a looming silhouette.

## 4. Other screens (Milestone 3)
All share TopBar, PileViewer (deck view), the CardView component and the tokens above.

- **Reward screen:** three CardViews on a podium with a hover lift. Gold, relic and potion rows above. A "Skip" button.
- **Shop:** a card shelf (5 class + 2 neutral), relic shelf, potion shelf, card-removal service. Prices are tinted red when unaffordable.
- **Rest site:** two big choice buttons (Rest: heal 30% · Smith: upgrade a card). Upgrading shows a before/after CardView with the upgrade glow.
- **Main menu, class select, run summary:** the class select uses each class's palette as the full-screen background, crossfading as you browse.
