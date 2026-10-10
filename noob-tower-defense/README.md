# Noob Tower Defense

A wave-based Roblox tower defense game in the style of Tower Defense Simulator. Classic Noobs defend against waves of Infected Noobs, elites and bosses.

This folder is a standalone Roblox project, separate from the Godot game in the rest of this repository. It has a `.gdignore` so Godot does not scan it.

**Studio setup: [docs/STUDIO_SETUP.md](docs/STUDIO_SETUP.md)**

## Master plan

| Step | System | Status |
|---|---|---|
| 1 | Architecture, networking, game loop (GameManager), waves (WaveSpawner), economy, base health, server enemy simulation, client enemy renderer, debug HUD | **Done** (this commit) |
| 2 | Towers: Scout, Soldier, Sniper and Minigunner Noob (4 levels each); grid-snap placement, overlap checks, range circle, targeting modes (First/Last/Strongest/Weakest), upgrade and sell | Next |
| 3 | Enemy presentation: real rigs, walk animations, status-effect visuals (slow tint, stun stars, burn), boss intro and minion-summon effects | The simulation (movement, armor, slow/stun/burn, boss minions) is already done |
| 4 | Loop extras: map voting, difficulty modes, separate lobby and match places (TeleportService), DataStore saves for XP and unlocks | |
| 5 | UI and VFX: arcade HUD, tower bar, upgrade panel, damage numbers, muzzle flashes, tracers, impact particles | |
| 6 | Animations and audio: Animator setup for idle/shoot/reload/death, SoundController (music by phase, SFX pools, victory/defeat stingers) | |
| 7 | Polish and launch: mobile and console input, performance pass, analytics, monetisation (cosmetics only) | |

## Architecture

The server is authoritative and the client only renders. Each side has one bootstrap script, which loads ModuleScript services (server) or controllers (client). Each module has optional `Init` and `Start` methods, like Knit but with no dependency.

```
Server  Main.server ─► PathService ─► EconomyService ─► EnemyService ─► WaveSpawner ─► GameManager
Client  Main.client ─► EnemyRenderer ─► DebugHud            (Step 2+: Placement, TowerMenu, Hud, Sound…)
```

### Folder hierarchy (target layout; † = created at runtime, ‡ = built by hand in Studio)

```
ReplicatedStorage
├─ Shared/                       ← src/shared (Rojo)
│  ├─ Config/  GameConfig, EnemyConfig, WaveConfig   (+ TowerConfig in step 2)
│  ├─ Net/     Remotes           every RemoteEvent/RemoteFunction declared in one place
│  ├─ Path/    PathTrack         waypoint polyline math shared by server and client
│  ├─ Util/    Signal
│  └─ GameState                  phase/attribute names + helpers
├─ Assets/ ‡
│  ├─ Enemies/   InfectedNoob, RunnerNoob, EliteInfected, InfectedBrute, PatientZero, InfectedKing
│  ├─ Towers/    ScoutNoob, SoldierNoob, SniperNoob, MinigunnerNoob   (step 2)
│  ├─ VFX/       MuzzleFlash, Tracer, Impact, DamageNumber            (step 5)
│  ├─ Animations/                                                     (step 6)
│  └─ Sounds/    Music/, SFX/                                         (step 6)
├─ Remotes/ †          RemoteEvents, created by the server from Net/Remotes
├─ GameState †         Configuration whose attributes hold the match state
└─ Runtime/PathPoints † copy of the waypoints (immune to StreamingEnabled)

ServerScriptService
└─ Server/                       ← src/server
   ├─ Main (Script)
   ├─ Services/  PathService, EconomyService, EnemyService, WaveSpawner, GameManager   (+ TowerService)
   └─ Util/      RateLimiter

ServerStorage ‡
├─ Maps/          extra maps swapped into Workspace.Map (map voting, step 4)
└─ ServerOnly/    anything clients must never download

StarterPlayer
└─ StarterPlayerScripts
   └─ Client/                    ← src/client
      ├─ Main (LocalScript)
      └─ Controllers/  EnemyRenderer, DebugHud   (+ PlacementController, TowerMenu, Hud, Sound)

Workspace
├─ Map/ ‡
│  ├─ Waypoints/   parts named 1, 2, 3, … (1 = enemy spawn, last = base)
│  ├─ Path/        the road you see (towers may not be placed on it)
│  ├─ Placeable/   ground towers may stand on (step 2)
│  ├─ Spawn        decorative spawn portal
│  └─ Base         decorative base
├─ Towers/ †       placed towers (server, step 2)
└─ ClientEnemies/ † enemy models (each client makes its own)
```

### Networking and anti-exploit model

| What | How it is shared | Why it is safe and cheap |
|---|---|---|
| Phase, wave, timer, base HP, enemies left, votes | Attributes on `ReplicatedStorage.GameState` | Replicate automatically, including to late joiners. Clients cannot change what the server sees. The timer is sent once as an end timestamp (`TimerEndsAt`), not every second. |
| Cash | Server-side table, mirrored to the `Cash` player attribute and leaderstats | Only `EconomyService` changes it. `TrySpend` checks and subtracts in one step. |
| Enemies | No parts on the server, only data: `{type, health, distance along path}`. Clients get `EnemySpawned` once, `EnemyBatchUpdate` at 10 Hz (only enemies that changed, plus a full sync every 2 s) and `EnemyRemoved` | Bandwidth stays small however many enemies there are. No physics. Clients can't move, damage or delete enemies, because their copies are only visual. |
| Enemy movement on clients | `distance + speed × (serverNow − syncTime)` on the shared `PathTrack`, eased toward each correction | Smooth at any frame rate. Turns at corners are smoothed. |
| Client → server | Requests only: `VoteReady`, `VoteSkip`, `ClientReady` (towers add `PlaceTower` etc.) | Every request is rate-limited (`RateLimiter`) and checked against server state. The client never reports a result. |

What tower placement (step 2) will check on the server: argument types (`typeof`), the current phase, that the tower type exists, `TrySpend` for the cost, that the spot is on `Placeable` (raycast), its distance from every path segment (`PathTrack`), its distance from other towers (math, not physics), the player's tower limit, and the rate limit. Upgrades and sells also check that the player owns the tower. Refunds are calculated on the server.

## Tuning

- `src/shared/Config/GameConfig.luau`: timers, starting cash, wave bonus, base HP, kill reward mode (shared or killer-only), network rates. `DebugStartWave` jumps to a later wave when you play-test in Studio.
- `src/shared/Config/EnemyConfig.luau`: health, speed, armor, reward, leak damage, immunities and boss minion phases.
- `src/shared/Config/WaveConfig.luau`: 20 waves of parallel spawn groups. Bosses come on waves 10 and 20. A typo in an enemy name stops the server at startup.

## Tests

`tests/sim` runs the real server code in a mocked Roblox environment on a virtual clock (Node + [luau-web](https://www.npmjs.com/package/luau-web)):

```sh
cd noob-tower-defense/tests/sim
npm install
npm test
```

Scenarios:
- **Enemies:** path math, slow/stun/burn, armor and armor-piercing, boss minion phases, replication, clear.
- **Victory:** a scripted 800 DPS "tower" clears all 20 waves and the server returns to the lobby.
- **Defeat and reset:** with no defence the base falls on wave 4, nothing spawns after GameOver, the next match resets cash and base, everyone leaving ends the match, and vote spam is handled.

Format with [StyLua](https://github.com/JohnnyMorganz/StyLua): `stylua src` (config in `stylua.toml`).
