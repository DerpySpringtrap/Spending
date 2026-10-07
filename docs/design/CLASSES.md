# Classes

Four classes, each built around a secondary resource or mechanic that changes how you sequence cards, not just how much damage you deal. Every class has 3 energy and draws 5 cards per turn unless stated otherwise.

**Card pool target per class (~34 cards):** 2–3 starter-only signature cards + 14 Common + 12 Uncommon + 7 Rare.
Plus a shared Neutral pool (~15), Curses (~8) and Status cards (~6). Full card lists are written in Milestone 4. This doc fixes each class's identity, resource rules and examples.

**Numbers baseline:** 1 energy ≈ 6 damage or 5 block at Common. Upgrades add roughly +30–50% or reduce cost by 1.

---

## Shared keywords & core statuses

| Keyword / Status | Type | Rule |
|---|---|---|
| **Block** | – | Absorbs damage. Removed at the start of your turn. |
| **Strength** | Buff, intensity | +1 damage per hit per stack. Can go negative. |
| **Dexterity** | Buff, intensity | +1 Block per block card per stack. |
| **Vulnerable** | Debuff, duration | Takes 50% more attack damage. |
| **Weak** | Debuff, duration | Deals 25% less attack damage. |
| **Frail** | Debuff, duration | Gains 25% less Block. |
| **Poison** | Debuff, intensity | At the start of its turn, loses HP equal to stacks (ignores Block), then −1 stack. *Slow and inevitable.* |
| **Burn** | Debuff, intensity | At the end of its turn, takes damage equal to stacks (Block applies), then stacks are halved. *Big upfront, burns out fast.* |
| **Stun** | Debuff, flag | Skips its next action. Enemies with Stun show a "Stunned" intent. Bosses gain 1 turn of Stun immunity after being stunned. |
| **Thorns** | Buff, intensity | When attacked, deal stacks damage back to the attacker. |
| **Exhaust** | Keyword | Removed from play for the rest of combat. Shown as **Erase** on Hollow Scribe cards. |
| **Retain** | Keyword | Not discarded at end of turn. |
| **Innate** | Keyword | Always in your opening hand. |
| **Ethereal** | Keyword | Exhausted if still in hand at end of turn. |

Each class resource is a `ClassResourceData` with its own gauge next to the energy orb. Stances are `StatusEffectData` flags, so they use the normal status pipeline and tooltips.

---

## 1. Pyre Warden — *Keeper of the Last Ember*

**Fantasy:** An exiled knight whose armor is a furnace housing the last ember of a dead sun-god. Slow, heavy, and dangerous when stoked. Every swing risks setting themselves alight.

**Stats:** 85 HP · 99 gold · unlocked by default (the "learn the game" class).

### Resource: Heat (0–10, persists between turns)
- **Stoke X:** gain X Heat.
- **Vent X:** a bonus clause. If you have X Heat, spend it and get the bracketed bonus. Otherwise the card still plays without the bonus. (The UI lights the bonus text when you can afford it.)
- **Overheat:** if you **end your turn at 10 Heat**, deal 15 damage to ALL enemies, lose 2 HP and reset Heat to 0. This rewards planning: stoke up and choose whether to Vent for value or ride to an Overheat.

### Archetypes
1. **Overheat engine:** fast Stoke and cards that trigger on Overheat. Aim to Overheat every 2 turns.
2. **Wildfire (Burn stacking):** pile Burn on one enemy, then spread it to all.
3. **Cinderplate (block-and-punish):** big Block, reactive Burn on attackers, convert Block into damage.

### Starting deck (10)
4× Strike (6 dmg) · 3× Defend (5 Block) · **Kindle** · **Vent Flame** · **Smoldering Guard**

| Starting card | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|
| **Kindle** | 1 | Attack | Deal 8 damage. Stoke 2. | 10 dmg, Stoke 3 |
| **Vent Flame** | 1 | Attack | Deal 6 damage to ALL enemies. *Vent 3:* apply 3 Burn to ALL enemies. | 8 dmg, 4 Burn |
| **Smoldering Guard** | 1 | Skill | Gain 8 Block. Stoke 1. | 11 Block |

### Higher-rarity examples
| Card | Rarity | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|---|
| **Bellows** | Uncommon | 1 | Skill | Stoke 4. Draw 1 card. | Stoke 5, draw 2 |
| **Searing Aegis** | Uncommon | 1 | Power | Whenever you're attacked while you have Block, apply 2 Burn to the attacker. | 3 Burn |
| **Wildfire** | Uncommon | 2 | Skill | Every other enemy gains Burn equal to the target's Burn. Exhaust. | Cost 1 |
| **Supernova** | Rare | 2 | Attack | Vent ALL Heat. Deal 4 damage to ALL enemies per Heat vented. | 5 per Heat |
| **Eternal Pyre** | Rare | 3 | Power | Overheating no longer costs HP, and Heat resets to 5 instead of 0. | Cost 2 |

Other notable cards: *Molten Bastion* (Rare. Gain Block equal to 2× Heat; your Block isn't removed next turn), *Brand* (Common, 0. Apply 3 Burn. Stoke 1).

### Starting relic: **Cinder Heart**
> At the start of each combat, gain 3 Heat.
Puts Vent bonuses in reach on turn 1 and teaches the resource immediately.

### Visual identity
- **Palette:** charcoal `#2B2522`, ember orange `#E8692C`, molten gold `#F6B43C`, ash white `#E9E2D8`.
- **Card frame:** blackened riveted iron with glowing cracks. A shader uniform brightens the cracks as Heat rises, so the whole hand "heats up".
- **Silhouette:** hulking and broad-shouldered, tower shield and great-mace, chimney-plumed helm venting sparks.

### Sound identity
- Heavy metal thuds, forge hammer-on-anvil impacts, flame whoosh/roar, bellows breaths.
- **Motif:** low brass + taiko hit. **Overheat:** rising kettle hiss → bass boom.

---

## 2. Moonblade — *Duelist of the Waning Court*

**Fantasy:** A fencer of a lunar order who fights in rhythm with the moon's phases. Elegant footwork, ripostes, a blade that glows silver or violet with each phase. Rewards tempo and precise sequencing.

**Stats:** 66 HP · 99 gold · unlocked after your first completed run (win or lose).

### Mechanic: Phases (stance) + Lunar Charge
- You start each combat in **no phase**. Cards say **Wax** (enter Waxing), **Wane** (enter Waning) or **Shift** (swap to the other phase; enters Waxing if in none).
  - **Waxing:** your Attacks deal **+2 damage per hit**. (Flat, so it's exact in previews and loves multi-hit cards.)
  - **Waning:** cards grant **+2 Block**, and when an enemy attacks you, **Riposte for 2 damage**.
- Every phase *change* grants **1 Lunar Charge** (max 4).
- Changing phase with **4 Charges** enters **Eclipse** instead: +3 damage per hit, +3 Block, Riposte 3, and draw 2 cards. At end of turn you return to no phase and Charges reset to 0.

### Archetypes
1. **Phase dance:** cheap Shift cards plus payoffs that trigger on every phase change (draw, damage, energy).
2. **Riposte:** stay in Waning and win by punishing attacks (block-and-punish).
3. **Flurry:** 0-cost and multi-hit attacks that scale with Waxing's per-hit bonus.

### Starting deck (10)
4× Strike · 3× Defend · **Crescent Cut** · **Tidal Parry** · **Moonstep**

| Starting card | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|
| **Crescent Cut** | 1 | Attack | Deal 6 damage. Wax. | 9 dmg |
| **Tidal Parry** | 1 | Skill | Gain 6 Block. Wane. | 9 Block |
| **Moonstep** | 0 | Skill | Shift. | Draw 1 card, Retain |

### Higher-rarity examples
| Card | Rarity | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|---|
| **Moonlit Flurry** | Uncommon | 1 | Attack | Deal 2 damage 4 times. | 5 times |
| **Silver Reflection** | Uncommon | 1 | Power | Your Riposte deals double damage. | Also Innate |
| **Orbit** | Uncommon | 2 | Power | Whenever you change phase, draw 1 card. | Cost 1 |
| **Total Eclipse** | Rare | 2 | Skill | Gain 4 Lunar Charges and enter Eclipse. Exhaust. | Cost 1 |
| **Moonfall** | Rare | 3 | Attack | Deal 30 damage. Costs 1 less for each phase change this turn. | 40 dmg |

### Starting relic: **Moonsilver Locket**
> The first time you change phase each turn, draw 1 card.
Makes phase-changing feel good from turn 1 and smooths the card flow the class needs.

### Visual identity
- **Palette:** midnight navy `#141A33`, moon silver `#C9D2E3`, pale gold `#E9D8A6`, eclipse violet `#7A5CC7`.
- **Card frame:** slender silver filigree. A crescent at the top of every card waxes/wanes with your current phase and turns violet during Eclipse.
- **Silhouette:** slim, long flowing cape, rapier, crescent-moon halo behind the head.

### Sound identity
- Crisp steel rings, rapier whips, glass chimes on phase change.
- **Motif:** harp / celesta arpeggio (rising for Waxing, falling for Waning). **Eclipse:** reversed cymbal into a choir pad.

---

## 3. Hollow Scribe — *Author of Unwritten Endings*

**Fantasy:** A hollow, ink-stained archivist animated by a cursed tome. It fights by editing its own book: discarding drafts, erasing pages, rewriting fate. The deck-manipulation class.

**Stats:** 72 HP · 99 gold · unlocked by reaching the Act 2 boss.

### Resource: Ink (0–10, persists between turns)
- Start each combat with **2 Ink** and gain **1 Ink** at the start of each turn (added after simulator testing so Inscribe is usable).
- Gain **1 Ink** whenever you **discard** a card manually (not the end-of-turn discard) or **Erase** (exhaust) a card.
- **Inscribe X:** a bonus clause. Spend X Ink for the bracketed effect (same UI as Vent).
- **Footnote:** a keyword for effects that trigger *when the card is discarded* (`on_discard_effects`). Footnote cards are good to play and good to throw away.

### Archetypes
1. **Palimpsest (discard engine):** draw-and-discard cycling with Footnote payoffs.
2. **Erasure (exhaust):** Erase cards for Ink and burst. Payoffs scale with the Erased pile.
3. **Cursed Lexicon:** turns Curses and Status cards (normally deck clutter) into fuel. Strong against enemies that shuffle junk into your deck.

### Starting deck (10)
4× Strike · 3× Defend · **Quill Jab** · **Blot** · **Marginalia**

| Starting card | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|
| **Quill Jab** | 1 | Attack | Deal 7 damage. *Inscribe 2:* deal 7 more. | 9 + 9 |
| **Blot** | 0 | Skill | Draw 2 cards. Discard 1 card. | Draw 3 |
| **Marginalia** | 1 | Skill | Gain 6 Block. *Footnote:* gain 4 Block. | 8 / 6 |

### Higher-rarity examples
| Card | Rarity | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|---|
| **Splatter** | Uncommon | 0 | Attack | Deal 4 damage. *Footnote:* deal 4 damage to ALL enemies. | 6 / 6 |
| **Redact** | Uncommon | 0 | Skill | Erase a card in your hand. Gain 2 Ink. Draw 1 card. | Gain 3 Ink |
| **Errata** | Uncommon | 1 | Power | Whenever you Erase a card, deal 3 damage to a random enemy. | 5 dmg |
| **Unwritten Ending** | Rare | 2 | Attack | Deal 4 damage for each card in your Erased pile. Erase. | 5 per card |
| **Living Manuscript** | Rare | 2 | Power | At the start of your turn, gain 2 Ink. Inscribe costs 1 less. | Cost 1 |

Other notable card: *Bind the Curse* (Rare. Erase all Curses and Statuses in your hand. Gain 3 Ink and 5 Block for each).

### Starting relic: **Dog-Eared Tome**
> At the start of each combat, choose a card in your draw pile and put it into your hand.
Deck manipulation as the identity from turn 1: you always open with the card you want.

### Visual identity
- **Palette:** parchment `#E9DFC7`, ink blue-black `#1C2230`, sepia `#8A6A45`, rubric crimson `#A3283A`.
- **Card frame:** torn parchment with ink-bleed edges and margin doodles. Rare cards get illuminated gold-leaf corners. Erased cards dissolve into ink droplets.
- **Silhouette:** gaunt hooded figure, an open tome floating at the shoulder, quill-staff, loose pages orbiting.

### Sound identity
- Paper rustles, quill scratches, page flips, ink splats, wax-stamp thunks.
- **Motif:** harpsichord / music-box phrase. **Erase:** reversed paper tear.

---

## 4. Rootmother — *The Walking Grove*

**Fantasy:** An ancient druid whose body is a living forest. They grow sapling allies that fight and shield for them, and fill the air with rot spores. The summoner class.

**Stats:** 60 HP · 99 gold · unlocked by defeating the Act 2 boss.

### Mechanic: Summons + Sap
- **Summons** stand in front of the Rootmother, max 3. Each is a small `Combatant` with HP, its own status tray and a visible intent. Summons act at the end of your turn, before enemies.
- **Single-target enemy attacks hit the frontmost summon first** (a Taunting summon before any other). If the hit kills the summon, the leftover damage carries through to you (changed from the original design after simulator testing: free soak made the class far too strong). AoE attacks hit everyone.
- **Sap (0–10, persists):** at the start of your turn, gain 1 Sap per living summon.
- **Graft X:** bonus clause. Spend X Sap for the bracketed effect.

| Base summon | HP | Acts at end of your turn |
|---|---|---|
| **Sproutling** | 3 | Deal 2 damage to a random enemy |
| **Thornling** | 3 | Deal 2 damage to the front enemy (upgraded: 5 HP, 3 damage) |
| **Sporecap** | 3 | Apply 2 Poison to a random enemy |
| **Barkguard** | 6 | Gain 2 Block; Taunt (always targeted first) |
| **Elder Treant** | 10 (+5 per summon sacrificed) | Deal 6 damage to the front enemy; Taunt |

### Archetypes
1. **Swarm:** keep 3 summons alive, with payoffs per summon and per summon action.
2. **Spore Rot (Poison):** Sporecaps plus Poison stacking and multiplying.
3. **Elder Grove:** sacrifice and merge summons into one huge Elder Treant.

### Starting deck (10)
4× Strike · 3× Defend · **Sow Thornling** · **Spore Puff** · **Nourish**

| Starting card | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|
| **Sow Thornling** | 1 | Skill | Summon a Thornling. | Thornling+ (5 HP / 3 dmg) |
| **Spore Puff** | 1 | Skill | Apply 3 Poison. *Graft 2:* apply 3 Poison to ALL enemies. | 4 / 4 |
| **Nourish** | 1 | Skill | Gain 5 Block. Your summons gain +2 max HP. | 7 Block, +3 HP |

### Higher-rarity examples
| Card | Rarity | Cost | Type | Effect | Upgraded |
|---|---|---|---|---|---|
| **Overgrowth** | Uncommon | 1 | Power | At the start of your turn, if you have fewer than 3 summons, summon a Sproutling. | Innate |
| **Fungal Bloom** | Uncommon | 1 | Skill | Apply 2 Poison to ALL enemies for each Sporecap you have. | 3 per Sporecap |
| **Chorus of Leaves** | Uncommon | 1 | Attack | Deal 4 damage, +4 for each summon. | 6 + 5 each |
| **Elder Treant** | Rare | 3 | Skill | Sacrifice all summons. Summon an Elder Treant with 2× their total HP that deals 3 + their total damage. Exhaust. | Cost 2 |
| **Mycelial Network** | Rare | 2 | Power | Whenever a summon deals damage, apply 1 Poison to the target. | Cost 1 |

### Starting relic: **Seed of the First Tree**
> At the start of each combat, summon a Sproutling.
Shows the summon rules (front-line soaking, end-of-turn actions) on turn 1 of every fight.

### Visual identity
- **Palette:** moss green `#4F7A3A`, bark brown `#5B4030`, bioluminescent teal `#4FD1C5`, spore pink `#E58FB0`.
- **Card frame:** living wood. Vines creep along the border, and flowers bloom across it when the card is upgraded (pairs with the upgrade-glow animation).
- **Silhouette:** tall, antler-branch crown, robe of leaves, staff topped with a glowing seed. Summons are small round silhouettes in front, readable at a glance.

### Sound identity
- Wood creaks, leaf rustles, soft earthy thumps, spore puffs, bubbling sap.
- **Motif:** wooden flute + kalimba. **Summon:** rising marimba glissando ending in a sprout "pop".

---

## 5. Astromancer (planned) — *Keeper of the Spiral Galaxy*

> Requested for later; not scheduled yet. Name and numbers are working placeholders.

**Fantasy:** A star-mage who carries a tiny galaxy around her. She fights by setting cards into orbit around herself and letting them swing back with more force each time they come around. Fits the astronomy feel of Act 3.

**Stats (draft):** ~70 HP · 99 gold · unlock condition to be decided (for example, defeat the Orrery).

### Mechanic: Orbit
- Some cards say **Launch**: when played, instead of going to the discard pile they enter **Orbit**, a ring of up to 3 slots around her.
- At the start of each turn, every orbiting card advances one step. When a card completes its orbit, its **Perigee** effect fires (a stronger echo of the card) and it returns to her hand.
- **Momentum** (resource, 0–10): gained each time a card completes an orbit. Spent by payoff cards ("Spend 3 Momentum: …") or kept for passive bonuses.
- Archetype ideas: *Satellites* (many small Launch cards for steady echoes), *Slingshot* (speed up orbits for burst turns), *Gravity Well* (hold cards in orbit for defence while Momentum builds).

### Visual identity
- **Palette:** galaxy purple. Deep violet `#2A1050`, nebula magenta `#B04AD0`, starlight lavender `#D9C8FF`, with soft cyan star specks `#8FE3F0`. Clearly different from the Moonblade's silver-and-navy.
- **Silhouette:** a woman in a long flowing robe that fades into a starfield at the hem, a spiral galaxy halo behind her, and small glowing planets/cards circling her (the Orbit slots shown on screen).
- **Card frame:** dark violet with a faint nebula swirl; Launch cards get an orbit-ring border.

### Sound identity
- Shimmering synth pads, glassy chimes, a soft whoosh as cards pass perigee. **Motif:** rising arpeggio with a reverb tail, like light travelling across space.

---

## Meta-progression per class
Each class has an XP track (XP = floors reached + bosses + victory bonus). Tiers unlock in order:
1. +5 class cards added to the reward pool
2. +3 class relics
3. Alternate starting relic (choose at class select)
4. +5 more class cards (including a second build-around rare per archetype)
5. Card-back / frame cosmetic, and Ascension unlocked for this class
