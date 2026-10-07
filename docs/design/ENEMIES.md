# Enemies, Elites, Bosses & Ascension

## Acts & biomes

| Act | Biome | Mood | Ambience bed | Boss |
|---|---|---|---|---|
| 1 | **The Drowned Thicket**: flooded, rotting forest | Murky greens, fog, fireflies | Frogs, dripping water, distant wind | The Drowned Matriarch |
| 2 | **The Gilded Catacombs**: a crypt-city looted and re-gilded by a gold cult | Candlelight, gold on bone | Low choir hum, candle crackle, chains | The Gilded Hierophant |
| 3 | **The Shattered Observatory**: floating clockwork ruins in a storm | Indigo sky, brass, starlight | Thunder, ticking gears, wind gusts | The Orrery |
| 4 | **The Umbral Core**: inside the eclipse (short final act) | Black-violet void, corona light | Deep drone, heartbeat | The Umbral Sovereign |

Act 4 unlocks after your first Act 3 boss victory. It is 3 floors long: rest → shop → elite → boss.

## Intent language

Every enemy shows its next move above its head **before** the player acts. Hovering an intent shows the exact move name and effect.

| Icon | Intent | Number shown |
|---|---|---|
| Sword (size scales with damage) | ATTACK | Final damage after Strength/Weak/your Vulnerable, e.g. `12` or `4×3` |
| Shield | DEFEND | Block amount |
| Upward arrow (red) | BUFF | – |
| Downward drip (purple) | DEBUFF / STRONG_DEBUFF | – |
| Sword + shield / arrow / drip | combined intents | Damage |
| Seedling | SUMMON | – |
| Hourglass | CHARGING | Turns remaining |
| Spiral stars | STUNNED | – |
| Running figure | ESCAPE | – |
| Unique sigil | SPECIAL (gimmick moves) | Tooltip explains |

Intent damage previews update live: applying Weak to an enemy visibly shrinks its sword number.

HP figures below are for Ascension 0. Damage numbers are base values before Strength.

---

## Normal enemies (15)

### Act 1: The Drowned Thicket
| Enemy | HP | Moveset (intent) | Gimmick |
|---|---|---|---|
| **Bog Lurker** | 40–44 | *Lunge*: Attack 11 · *Submerge*: Defend 8 + Buff 1 Strength · *Mud Spit*: Attack 5 + 1 Weak | Tutorial bruiser. Weighted random, never the same move 3× in a row. |
| **Mire Toad** | 18–22 | *Tongue Lash*: Attack 6 · *Bloat*: Buff +2 Strength · *Croak*: Debuff (shuffles 1 Muck status into your discard) | **Toxic Burst:** on death, applies 2 Poison to the player. Teaches kill order. Appears in packs of 2–3. |
| **Thornback Beetle** | 28–32 | *Ram*: Attack 9 · *Harden*: Defend 10 + Thorns +1 | Starts with **3 Thorns**. Punishes multi-hit attacks. |
| **Wisp Lantern** | 12–15 | *Flicker*: gives an ally 6 Block · *Hex*: 1 Vulnerable · *Ember*: Attack 4 | Support: shields its allies. Fragile priority target, always paired. |
| **Hollow Woodsman** | 46–50 | Fixed loop: *Sharpen* (Buff +3 Strength) → *Chop* (Attack 14) → *Chop* | Predictable escalation you can plan around. Hard pool. |

### Act 2: The Gilded Catacombs
| Enemy | HP | Moveset (intent) | Gimmick |
|---|---|---|---|
| **Gilded Skeleton** | 34–38 | *Bone Slash*: Attack 10 · *Shield Up*: Defend 12 · *Rattle*: 1 Weak | **Reassemble:** the first time it dies, it collapses and revives at 50% HP after 1 turn (shows a SPECIAL intent) unless all enemies are dead. |
| **Candle Acolyte** | 22–26 | *Chant*: Buff all enemies +2 Strength · *Wax Seal*: 2 Frail · *Flame*: Attack 7 | Force multiplier. Chant every 3rd turn makes it a must-kill. |
| **Coin Mimic** | 38–42 | *Pilfer*: Attack 8 + steal 15 gold · *Hunker*: Defend 14 · *Flee*: Escape | **Thief:** after stealing twice it flees with your gold. Kill it to get the gold back. |
| **Crypt Hound** | 30–34 | *Bite*: Attack 5×2 · *Howl*: Buff all hounds +1 Strength · *Pounce*: Attack 12 (only if you are Vulnerable) | **Pack Tactics:** +2 damage per other living hound. Appears in pairs. |
| **Embalmer** | 44–48 | *Wrap*: Debuff (adds 2 Bandaged status cards to your draw pile) · *Embalm*: heal an ally 12 or self Defend 10 · *Scalpel*: Attack 6×2 | Deck clutter plus healing. Pressures thin decks and slow kills. |

### Act 3: The Shattered Observatory
| Enemy | HP | Moveset (intent) | Gimmick |
|---|---|---|---|
| **Clockwork Sentinel** | 55–60 | *Pulse*: Attack 8 · *Lock-On*: Buff (next attack ×2) · *Purge*: Defend 15 | **Overclock:** attack damage +3 every turn, shown as a visible counter. A race. |
| **Star Shard** | 20–24 | *Prism Ray*: Attack 7 · *Refract*: 1 Weak + 1 Vulnerable | **Constellation:** when one dies, the survivors gain +2 Strength and 8 Block. Appears in packs of 3. Kill evenly or burst all at once. |
| **Storm Harpy** | 40–44 | *Gale*: Attack 4×3 · *Shriek*: 2 Weak · *Ascend* (CHARGING) → *Dive*: Attack 16 | **Airborne:** takes 50% less damage until hit 3 times in one turn, then it is grounded (normal damage, no Dive) for a turn. |
| **Void Leech** | 48–52 | *Drain*: Attack 10, heals for unblocked damage · *Latch*: Debuff Drained (−1 energy next turn) · *Gorge*: Buff +3 Strength | Lifesteal. Block hard-counters it. |
| **Astral Weaver** | 60–65 | *Thread*: Attack 9 + 1 Frail · *Loom*: Defend 12 + 2 Strength · *Rewind* (SPECIAL, every 3rd turn) | **Rewind:** restores its HP to what it was 3 turns ago (a ghost bar shows the value). Rewards burst before the rewind. |

### Encounter pools
*Easy pool* = the first 3 combats of an act. *Hard pool* = the rest.

| Act | Easy pool | Hard pool |
|---|---|---|
| 1 | Bog Lurker · 2 Mire Toads · Thornback Beetle | 3 Mire Toads · Thornback Beetle + Wisp Lantern · Hollow Woodsman · Bog Lurker + Wisp Lantern · Mire Toad + Thornback Beetle |
| 2 | Gilded Skeleton · Coin Mimic · 2 Crypt Hounds | Skeleton + Candle Acolyte · Embalmer + Skeleton · 2 Hounds + Acolyte · Coin Mimic + Acolyte · Embalmer + 2 Hounds |
| 3 | Clockwork Sentinel · 3 Star Shards · Storm Harpy | Void Leech + Star Shard · Astral Weaver · Sentinel + Harpy · Weaver + 2 Star Shards · Void Leech + Harpy |

---

## Elites (8)

Elites drop a **guaranteed relic** plus a card reward with higher rare odds.

| Elite | Act | HP | Moveset (intent) | Gimmick |
|---|---|---|---|---|
| **Gorehorn Bull** | 1 | 82–88 | *Bellow* (turn 1): Buff +2 Strength · *Gore*: Attack 16 · *Trample*: Attack 7×2 + 1 Vulnerable | **Enrage:** gains +2 Strength whenever you play a Skill. Punishes turtling. |
| **Swamp Witch** + **Familiar** | 1 | 60–64 / 24 | Witch: *Hex*: Debuff (a random card in hand costs +1 this combat) · *Bog Bolt*: Attack 12 · *Bond*: both gain 10 Block. Familiar: *Nip*: Attack 5 · *Lick Wounds*: heals Witch 8 | **Familiar** revives 2 turns after dying while the Witch lives. Dive the Witch, or control the toad. |
| **The Gilded Knight** | 2 | 120–126 | *Cleave*: Attack 18 · *En Garde*: Buff (counters each attack for 5 this turn) · *Shield Bash*: Attack 10 + Defend 10 | **Gilded Plate (8):** gains Block equal to its stacks at end of each turn and loses 1 stack per unblocked hit. Multi-hit strips it. |
| **Twin Reliquaries** | 2 | 55 each | Alternate: one *Smites* (Attack 14) while the other *Wards* (both gain 12 Block); swap roles each turn | **Soul Link:** if one dies, the other resurrects it at full HP in 2 turns (CHARGING countdown). Kill both inside the window. |
| **Plague Censer** | 2 | 95–100 | *Swing*: Attack 14 · *Fumigate*: 2 Weak + 2 Frail · *Censer Smash*: Attack 22 (every 3rd turn) | **Incense:** at the end of your turn, applies 1 Poison to you per card you played that turn. Taxes combo turns. |
| **Chronomancer Construct** | 3 | 140–150 | *Gear Grind*: Attack 12×2 · *Stasis*: Debuff (freezes 2 random cards in hand; unplayable next turn) · *Reset*: clear its debuffs + 20 Block | **Tick:** every 10 cards you play, it immediately takes an extra turn. A visible counter is shown. |
| **Starfall Seraph** | 3 | 130 + 3 Halo Fragments (14 each) | Seraph: *Judgement*: Attack 20 · *Radiance*: Attack 6 to you and all summons + 1 Weak. Fragments: *Mend*: heal Seraph 10 | **Halo:** the Seraph takes 75% less damage while any Fragment lives. Fragments respawn one at a time every 3 turns. AoE check. |
| **Mirror Knight** | 4 | 160 | *Reflected Strike*: Attack 15 · *Shatter*: Attack 6×3 · *Polish*: Buff +3 Strength + Defend 10 | **Mirror:** whenever you apply a debuff to it, it applies 1 stack of the same debuff to you (Poison and Burn included). Forces you to adapt your main plan. |

---

## Bosses (4)

Each boss has a 2–3 second intro cinematic (camera pan, name card, music sting) and multiple phases with clear transitions: the boss is invulnerable for the transition beat, its intents reset, and the music adds a layer. Each boss's unique reward is a signature boss relic, always one of the three boss-relic choices.

### Act 1: The Drowned Matriarch, *Queen of the Sunken Brood* (240 HP)
| Phase | Trigger | Moves | Gimmick |
|---|---|---|---|
| **1. Bog Court** | Start | *Tidal Slam*: Attack 18 · *Murk*: shuffle 3 Muck into your discard · *Call the Brood*: Summon 2 Mire Toads (if fewer than 2) | Starts with 2 Mire Toads. She **gains 6 Block per living toad** at end of turn. Kill the brood or chew through Block. |
| **2. The Deep** | ≤ 50% HP | *Whirlpool*: Attack 7×3 · *Undertow*: Debuff (discard 2 random cards at the start of your next turn) · *Inhale* (CHARGING 1) → *Devour*: Attack 32 | On entering: remaining toads are devoured (she heals 10 each) and her debuffs are cleansed. Devour is fully telegraphed, so plan a big Block turn. |

**Signature reward:** **Brackwater Pearl** (boss relic): +1 Energy per turn. At the start of each combat, shuffle 2 Muck into your draw pile.

### Act 2: The Gilded Hierophant, *Voice of the Golden Tithe* (320 HP)
| Phase | Trigger | Moves | Gimmick |
|---|---|---|---|
| **1. The Tithe** | Start | *Scepter*: Attack 14 · *Sermon*: all enemies +2 Strength · *Tithe*: Attack 10 + steal 25 gold | Flanked by **2 Gold Idols** (30 HP, no attacks). Each living Idol gives the Hierophant 10 Block per turn. |
| **2. Molten Wealth** | Both Idols dead **or** ≤ 50% HP | *Golden Rain*: Attack 5×4 · *Gilded Cage*: Debuff (2 random cards in your draw pile become Gilded: unplayable this combat) · *Consecrate* (CHARGING 1) → *Judgement*: Attack 35 | On entering: gains 1 Strength per 25 gold it stole. All stolen gold is returned on defeat. Rewards killing the Idols fast. |

**Signature reward:** **Tithe Collector** (boss relic): +1 Energy per turn. Shop prices are 25% higher.

### Act 3: The Orrery, *Engine of the Fixed Stars* (400 HP)
| Phase | Trigger | Moves | Gimmick |
|---|---|---|---|
| **1. Alignment** | Start | Mars: *Starfire* Attack 9×2 · Venus: *Grace* heal 15 + 2 Strength · Saturn: *Ring Wall* Defend 20 + 2 Frail on you | Three planets orbit, and the one in front picks the move. **Intents are shown two turns ahead** (a small "next" icon). |
| **2. Gravity Well** | ≤ 66% HP | *Collapse*: Attack 20 · *Pull*: you draw 2 extra cards next turn + gain Weight | **Weight:** at the end of your turn, take 2 damage per card left in your hand. Punishes hoarding (watch your Retain). |
| **3. Supernova** | ≤ 33% HP | Alternates *Solar Flare* (Attack 10×2) and *Corona Shield* (Defend 25) | A **5-turn countdown** starts. At 0, it deals 99 damage. A hard DPS check, fully visible from the first turn of the phase. |

**Signature reward:** **Clockwork Heart** (boss relic): +1 Energy per turn. You draw 1 fewer card on turn 1 of each combat.

### Act 4 (Final): The Umbral Sovereign, *The Eclipse Made Flesh* (600 HP)
| Phase | Trigger | Moves | Gimmick |
|---|---|---|---|
| **1. Penumbra** | Start | *Night Lash*: Attack 16 · *Dim*: 2 Weak + 2 Frail · *Shade Ward*: Defend 25 | **Feeds on your class:** each time you gain or spend your class resource (Heat, phase changes, Ink, Sap/summons), it gains 1 Umbra. At 10 Umbra it unleashes *Total Darkness* (Attack 40) and resets. Visible meter. |
| **2. Umbra** | ≤ 60% HP | *Mimicry*: copies the last Power card you played onto itself · *Void Rend*: Attack 8×4 | Turns your engine against you. Remaining Umbra carries over. |
| **3. Corona** | ≤ 25% HP | *Dying Light*: Attack 25 + Burn 5 · *Last Eclipse* (CHARGING 2) → Attack 60 | Destroys all your summons on entry. Its light-ray VFX intensify toward the final blow. |

**Reward:** run victory (ending cinematic, confetti and light rays), +XP, ascension unlock for the class.

---

## Ascension (15 levels, cumulative)

Unlocked per class by winning at the current level.

| Lvl | Modifier |
|---|---|
| 1 | Elite nodes appear ~40% more often on the map |
| 2 | Normal enemies deal +10% damage (rounded up) |
| 3 | Elites deal +10% damage |
| 4 | Bosses deal +10% damage |
| 5 | Rest sites heal 25% of max HP (down from 30%) |
| 6 | Start each run at 90% HP |
| 7 | Normal enemies have +10% HP |
| 8 | Elites have +10% HP and gain one random **affix**: *Armored* (start with 15 Block), *Enraged* (+3 damage per hit), *Vampiric* (heals 50% of unblocked damage) or *Regenerating* (heals 4/turn) |
| 9 | Bosses have +10% HP |
| 10 | Start each run with the curse **Weight of Dusk** (Unplayable, Ethereal) |
| 11 | One fewer potion slot |
| 12 | Upgraded cards appear 50% less often in rewards (normally 15% of reward cards in Act 2, 25% from Act 3) |
| 13 | Gold rewards −25%; shop prices +10% |
| 14 | −5 max HP |
| 15 | Enemies use their enhanced movesets (the per-move `ascension_amount_bonus` fields), and each boss gains an extra trick: the Matriarch brings a third Broodling; the Hierophant's Idols revive once; the Orrery starts with 2 Strength; the Sovereign's Umbra threshold drops from 12 to 10 |

**Implementation:** a global `AscensionRules` table in `src/run/` applies HP/damage scaling and map/reward modifiers. Per-move enhancements are authored on `EnemyMoveData` (`ascension_threshold` / `ascension_amount_bonus`), so designers tune them in the inspector.
