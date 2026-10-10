# Studio setup

Getting the step 1 build running in Roblox Studio takes about 15 minutes. At the end, placeholder Infected Noobs walk your path in waves, the HUD counts down, and the match ends in Victory or Game Over, then returns to the lobby.

## 1. Get the code into Studio

### Option A: Rojo (recommended)

[Rojo](https://rojo.space) syncs the `.luau` files into Studio live, so you can edit in VS Code and use git.

1. Install Rojo 7.4 or newer (`rokit add rojo-rbx/rojo` or the VS Code "Rojo" extension) and the Rojo Studio plugin.
2. In a terminal: `cd noob-tower-defense` then `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**.

Rojo only manages `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Everything you build by hand (the map, `Assets`, `ServerStorage`) is left alone.

### Option B: copy and paste by hand

Create these objects in the Explorer and paste in each file's contents. The names must match exactly.

| Create this | Class | Paste from |
|---|---|---|
| `ReplicatedStorage/Shared` | Folder | |
| `Shared/GameState` | ModuleScript | `src/shared/GameState.luau` |
| `Shared/Config` | Folder | |
| `Shared/Config/GameConfig` | ModuleScript | `src/shared/Config/GameConfig.luau` |
| `Shared/Config/EnemyConfig` | ModuleScript | `src/shared/Config/EnemyConfig.luau` |
| `Shared/Config/WaveConfig` | ModuleScript | `src/shared/Config/WaveConfig.luau` |
| `Shared/Net` | Folder | |
| `Shared/Net/Remotes` | ModuleScript | `src/shared/Net/Remotes.luau` |
| `Shared/Path` | Folder | |
| `Shared/Path/PathTrack` | ModuleScript | `src/shared/Path/PathTrack.luau` |
| `Shared/Util` | Folder | |
| `Shared/Util/Signal` | ModuleScript | `src/shared/Util/Signal.luau` |
| `ServerScriptService/Server` | Folder | |
| `Server/Main` | **Script** | `src/server/Main.server.luau` |
| `Server/Services` | Folder | |
| `Server/Services/PathService` | ModuleScript | `src/server/Services/PathService.luau` |
| `Server/Services/EconomyService` | ModuleScript | `src/server/Services/EconomyService.luau` |
| `Server/Services/EnemyService` | ModuleScript | `src/server/Services/EnemyService.luau` |
| `Server/Services/WaveSpawner` | ModuleScript | `src/server/Services/WaveSpawner.luau` |
| `Server/Services/GameManager` | ModuleScript | `src/server/Services/GameManager.luau` |
| `Server/Util` | Folder | |
| `Server/Util/RateLimiter` | ModuleScript | `src/server/Util/RateLimiter.luau` |
| `StarterPlayer/StarterPlayerScripts/Client` | Folder | |
| `Client/Main` | **LocalScript** | `src/client/Main.client.luau` |
| `Client/Controllers` | Folder | |
| `Client/Controllers/EnemyRenderer` | ModuleScript | `src/client/Controllers/EnemyRenderer.luau` |
| `Client/Controllers/DebugHud` | ModuleScript | `src/client/Controllers/DebugHud.luau` |

Do **not** create `ReplicatedStorage.Remotes`, `ReplicatedStorage.GameState` or `ReplicatedStorage.Runtime`. The server creates them when it starts.

## 2. Build the map (Workspace)

1. **Ground and road.** Make a flat baseplate (Terrain or Parts) and lay out a winding road. Put the road parts in a Folder `Workspace/Map/Path`.
2. **Map folder.** Your `Workspace` should look like this:
   ```
   Workspace
   └─ Map            (Folder)
      ├─ Waypoints   (Folder)  ← required
      ├─ Path        (Folder)  road visuals
      ├─ Spawn       (Model)   optional decoration at the start
      └─ Base        (Model)   optional decoration at the end
   ```
3. **Waypoints (required).** Inside `Map/Waypoints`, add one small Part at the start, one at every corner, and one at the base:
   - Name them `1`, `2`, `3`, … in walking order (`1` = spawn, highest number = base). Numbers only.
   - Size `1, 1, 1`. **Anchored ✔**, CanCollide ✘, CanQuery ✘, CanTouch ✘, Transparency `1`.
   - Put each one at the **centre of the road, on the road surface**. The server takes each part's Position as a point on the ground, and the client stands enemies on that line using each model's own height.
   - Turn on Studio's grid snap (Model tab → Move: 1 stud) so straight sections are exactly straight.
   - About 300–600 studs of total path suits the default enemy speeds. Infected walk 6 studs/s, so a 450-stud path takes about 75 s.
4. **Lighting (optional, makes a big difference).** Lighting → Technology `Future`. Add `Atmosphere`, `Bloom` (Intensity 0.6) and `ColorCorrection` (Saturation 0.15, Contrast 0.1). Raise `Lighting.ExposureCompensation` slightly. That gives the bright arcade look of TDS.

StreamingEnabled can stay on. The server publishes the waypoint positions into `ReplicatedStorage.Runtime.PathPoints`, so clients never need the waypoint parts streamed in.

## 3. (Optional) Enemy models

Without models, each enemy is drawn as a coloured block noob. To use real models, create `ReplicatedStorage/Assets/Enemies` (Folders) and add one Model per enemy, named after the `Model` field in `EnemyConfig`:

`InfectedNoob`, `RunnerNoob`, `EliteInfected`, `InfectedBrute`, `PatientZero`, `InfectedKing`

- Use an R6 or R15 rig (Avatar tab → Rig Builder, then recolour it: green skin, torn shirt…). Set its **PrimaryPart** to `HumanoidRootPart`.
- Leave the limbs unanchored and jointed. The renderer anchors only the root, so animations keep working (step 6).
- You don't have to position the model: the renderer finds the feet from its bounding box and stands it on the path.
- For bosses, scale the rig up with the Scale tool (Model → Scale).

## 4. Play-test

1. **Play (F5).** The Output should show `[NoobTD] server started (5 services)`.
2. The HUD at the top reads `Lobby · Wave 0/20 …` with a 20 s countdown. Click **Ready** to cut it to 3 s.
3. **Intermission** (15 s): this is where tower placement goes in step 2. Click **Skip** to start right away.
4. Waves of placeholder noobs walk the path. With no towers yet they reach the base, base HP drops, and around wave 4 you get **Game Over**. After 12 s the server returns to the Lobby.
5. For multiplayer: Test tab → Clients and Servers → 2 Players → Start. Skipping needs half the players (rounded up). Ready needs everyone.

To test later waves (bosses) before towers exist: in `GameConfig`, set `DebugStartWave = 10`. It only applies in Studio. Bosses will leak until step 2 adds towers. That still lets you watch them walk, and you can check the minion phases in the headless tests (`tests/sim`).

## 5. Game settings

- **Game Settings → Security:** leave "Allow HTTP Requests" and "Enable Studio Access to API Services" off for now. DataStores come in step 4.
- **Players → CharacterAutoLoads:** leave on. Players walk around the map as in TDS.
- **StarterPlayer → DevComputerMovementMode / camera:** leave the defaults. Step 2 adds a placement camera mode.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `PathService: Workspace.Map is missing` | The folder must be named exactly `Map` and sit directly in Workspace. |
| `PathTrack: ignoring "…" (waypoints must be named 1, 2, 3, ...)` | Rename that waypoint to a number. |
| Enemies float or sink | The waypoints aren't on the road surface. Move them so their centre sits on top of the road. |
| `WaveConfig[n].Groups[m]: unknown enemy` | A typo in `WaveConfig`. The name must be a key in `EnemyConfig`. |
| Nothing happens on Play | Check that `Server/Main` is a **Script** (not a ModuleScript) and `Client/Main` is a **LocalScript**. |
