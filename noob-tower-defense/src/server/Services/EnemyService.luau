--[[
	EnemyService
	Server-authoritative enemy simulation.

	An enemy on the server is plain data (no Parts, no Humanoids): its type, its
	health and how far along the path it has walked. Every Heartbeat the server
	advances each enemy by speed * dt. Clients receive:
	  * EnemySpawned    once per enemy (id, type, distance, speed, health, maxHealth, time)
	  * EnemyBatchUpdate at GameConfig.EnemyNetRate Hz, only for enemies whose
	                    speed/health/effects changed, plus a periodic full sync
	  * EnemyRemoved    when it dies, leaks into the base, or the match is cleared
	and draw the model themselves by predicting distance + speed * elapsed time.

	This keeps the network cost tiny (no physics replication of hundreds of
	rigs), keeps movement perfectly smooth on every client, and means an
	exploiter cannot move, damage or delete an enemy: only server code calls
	Damage / ApplyEffect.

	API for other services (towers in step 2):
		EnemyService:Spawn(typeName, { Distance?, HealthScale? }) -> Enemy?
		EnemyService:Damage(enemy, amount, sourcePlayer?, { PierceArmor? }) -> damage dealt
		EnemyService:ApplyEffect(enemy, { Kind, Magnitude, Duration, TickInterval?, Source? })
		EnemyService:GetEnemiesInRange(position, range) -> { Enemy }
		EnemyService:GetPosition(enemy) -> Vector3
		Signals: Spawned(enemy), Died(enemy, killer?), Leaked(enemy), Removed(enemy, reason)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local EnemyConfig = require(Shared.Config.EnemyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type EffectKind = "Slow" | "Stun" | "Burn"

export type EffectSpec = {
	Kind: EffectKind,
	-- Slow: fraction of speed removed (0.3 = 30% slower, capped at 0.9).
	-- Burn: damage per tick (ignores armour). Stun: unused.
	Magnitude: number,
	Duration: number,
	TickInterval: number?, -- Burn: seconds between ticks (default 1)
	Source: Player?, -- who gets credit for burn kills
}

type ActiveEffect = {
	Magnitude: number,
	Remaining: number,
	TickInterval: number,
	TickTimer: number,
	Source: Player?,
}

export type Enemy = {
	Id: number,
	Type: string,
	Def: EnemyConfig.EnemyDef,
	Health: number,
	MaxHealth: number,
	HealthScale: number,
	Distance: number,
	Speed: number,
	Alive: boolean,
	Effects: { [string]: ActiveEffect },
	NextMinionPhase: number,
	SpawnedAt: number,
}

export type SpawnOptions = {
	Distance: number?,
	HealthScale: number?,
}

export type DamageOptions = {
	PierceArmor: boolean?,
}

-- Sent to clients so they can show slow/stun/burn visuals.
local EFFECT_FLAGS = { Slow = 1, Stun = 2, Burn = 4 }
local MINION_SPACING = 1.5 -- studs between minions spawned behind a boss

local EnemyService = {
	Spawned = Signal.new(),
	Died = Signal.new(),
	Leaked = Signal.new(),
	Removed = Signal.new(),
}

local enemies: { [number]: Enemy } = {}
local enemyCount = 0
local nextId = 0
local dirty: { [number]: true } = {}
local syncTimer = 0
local fullSyncTimer = 0
local warnedCap = false
local track -- PathTrack, set in Init

local spawnedRemote: RemoteEvent
local batchRemote: RemoteEvent
local removedRemote: RemoteEvent
local bossPhaseRemote: RemoteEvent

local function effectFlags(enemy: Enemy): number
	local flags = 0
	for kind in enemy.Effects do
		flags += EFFECT_FLAGS[kind] or 0
	end
	return flags
end

local function pack(enemy: Enemy): { number }
	return { enemy.Id, enemy.Distance, enemy.Speed, enemy.Health, effectFlags(enemy) }
end

local function computeSpeed(enemy: Enemy): number
	if enemy.Effects.Stun then
		return 0
	end
	local slow = enemy.Effects.Slow
	return enemy.Def.Speed * (if slow then 1 - slow.Magnitude else 1)
end

local function sendSpawn(enemy: Enemy, player: Player?)
	local args = {
		enemy.Id,
		enemy.Type,
		enemy.Distance,
		enemy.Speed,
		enemy.Health,
		enemy.MaxHealth,
		workspace:GetServerTimeNow(),
	}
	if player then
		spawnedRemote:FireClient(player, table.unpack(args))
	else
		spawnedRemote:FireAllClients(table.unpack(args))
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function EnemyService:Init(services)
	track = services.PathService:GetTrack()

	spawnedRemote = Remotes.Event("EnemySpawned")
	batchRemote = Remotes.Event("EnemyBatchUpdate")
	removedRemote = Remotes.Event("EnemyRemoved")
	bossPhaseRemote = Remotes.Event("BossPhase")

	-- A client that just loaded asks once for every enemy already on the field.
	local synced: { [Player]: true } = {}
	local readyLimiter = RateLimiter.new(1, 2)
	Remotes.Event("ClientReady").OnServerEvent:Connect(function(player)
		if synced[player] or not readyLimiter:Allow(player) then
			return
		end
		synced[player] = true
		for _, enemy in enemies do
			sendSpawn(enemy, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		synced[player] = nil
	end)
end

function EnemyService:Start()
	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

--------------------------------------------------------------------------------
-- Spawning / removal
--------------------------------------------------------------------------------

function EnemyService:Spawn(typeName: string, options: SpawnOptions?): Enemy?
	local def = EnemyConfig[typeName]
	if not def then
		warn(`EnemyService: unknown enemy type "{typeName}"`)
		return nil
	end
	if enemyCount >= GameConfig.MaxEnemies then
		if not warnedCap then
			warnedCap = true
			warn(`EnemyService: MaxEnemies ({GameConfig.MaxEnemies}) reached, skipping spawns`)
		end
		return nil
	end

	local healthScale = options and options.HealthScale or 1
	local maxHealth = def.MaxHealth * healthScale
	nextId += 1
	local enemy: Enemy = {
		Id = nextId,
		Type = typeName,
		Def = def,
		Health = maxHealth,
		MaxHealth = maxHealth,
		HealthScale = healthScale,
		Distance = math.clamp(options and options.Distance or 0, 0, track.Length),
		Speed = def.Speed,
		Alive = true,
		Effects = {},
		NextMinionPhase = 1,
		SpawnedAt = os.clock(),
	}
	enemies[enemy.Id] = enemy
	enemyCount += 1

	sendSpawn(enemy)
	self.Spawned:Fire(enemy)
	return enemy
end

function EnemyService:_remove(enemy: Enemy, reason: "Killed" | "Leaked" | "Cleared")
	if not enemy.Alive then
		return
	end
	enemy.Alive = false
	enemies[enemy.Id] = nil
	enemyCount -= 1
	dirty[enemy.Id] = nil
	removedRemote:FireAllClients(enemy.Id, reason)
	self.Removed:Fire(enemy, reason)
end

-- Removes every enemy without rewards (match over / reset).
function EnemyService:Clear()
	for _, enemy in self:GetAll() do
		self:_remove(enemy, "Cleared")
	end
	warnedCap = false
end

--------------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------------

-- Returns the damage actually dealt (after armour, capped at remaining health).
function EnemyService:Damage(enemy: Enemy, amount: number, source: Player?, options: DamageOptions?): number
	if not enemy.Alive or amount <= 0 then
		return 0
	end
	local armor = if options and options.PierceArmor then 0 else math.clamp(enemy.Def.Armor, 0, 0.9)
	local dealt = math.min(enemy.Health, amount * (1 - armor))
	enemy.Health -= dealt
	dirty[enemy.Id] = true

	if enemy.Health <= 1e-6 then
		enemy.Health = 0
		self:_remove(enemy, "Killed")
		self.Died:Fire(enemy, source)
	else
		self:_checkMinionPhases(enemy)
	end
	return dealt
end

-- Applies a status effect. Re-applying the same kind keeps the stronger
-- magnitude and the longer duration (no stacking). Returns false if immune.
function EnemyService:ApplyEffect(enemy: Enemy, spec: EffectSpec): boolean
	if not enemy.Alive or spec.Duration <= 0 then
		return false
	end
	local immune = enemy.Def.Immune
	if immune and immune[spec.Kind] then
		return false
	end

	local magnitude = if spec.Kind == "Slow" then math.clamp(spec.Magnitude, 0, 0.9) else spec.Magnitude
	local existing = enemy.Effects[spec.Kind]
	if existing then
		existing.Magnitude = math.max(existing.Magnitude, magnitude)
		existing.Remaining = math.max(existing.Remaining, spec.Duration)
		existing.Source = spec.Source or existing.Source
	else
		local interval = math.max(0.1, spec.TickInterval or 1)
		enemy.Effects[spec.Kind] = {
			Magnitude = magnitude,
			Remaining = spec.Duration,
			TickInterval = interval,
			TickTimer = interval,
			Source = spec.Source,
		}
	end
	dirty[enemy.Id] = true
	return true
end

function EnemyService:_tickEffects(enemy: Enemy, dt: number)
	for kind, effect in enemy.Effects do
		if kind == "Burn" then
			local tickTime = math.min(dt, effect.Remaining)
			effect.TickTimer -= tickTime
			while effect.TickTimer <= 0 and enemy.Alive do
				effect.TickTimer += effect.TickInterval
				self:Damage(enemy, effect.Magnitude, effect.Source, { PierceArmor = true })
			end
			if not enemy.Alive then
				return
			end
		end
		effect.Remaining -= dt
		if effect.Remaining <= 0 then
			enemy.Effects[kind] = nil
			dirty[enemy.Id] = true
		end
	end
end

-- Bosses summon minions behind themselves each time they cross a health threshold.
function EnemyService:_checkMinionPhases(enemy: Enemy)
	local phases = enemy.Def.Minions
	if not phases then
		return
	end
	while enemy.NextMinionPhase <= #phases do
		local phaseIndex = enemy.NextMinionPhase
		local phase = phases[phaseIndex]
		if enemy.Health / enemy.MaxHealth > phase.At then
			break
		end
		enemy.NextMinionPhase += 1
		bossPhaseRemote:FireAllClients(enemy.Id, phaseIndex)
		for i = 1, phase.Count do
			self:Spawn(phase.Enemy, {
				Distance = math.max(0, enemy.Distance - i * MINION_SPACING),
				HealthScale = enemy.HealthScale,
			})
		end
	end
end

--------------------------------------------------------------------------------
-- Simulation
--------------------------------------------------------------------------------

function EnemyService:_step(dt: number)
	-- Snapshot: damage-over-time can kill enemies and bosses can spawn minions mid-loop.
	for _, enemy in self:GetAll() do
		if not enemy.Alive then
			continue
		end
		self:_tickEffects(enemy, dt)
		if not enemy.Alive then
			continue
		end

		local speed = computeSpeed(enemy)
		if speed ~= enemy.Speed then
			enemy.Speed = speed
			dirty[enemy.Id] = true
		end

		enemy.Distance += speed * dt
		if enemy.Distance >= track.Length then
			enemy.Distance = track.Length
			self:_remove(enemy, "Leaked")
			self.Leaked:Fire(enemy)
		end
	end
	self:_replicate(dt)
end

function EnemyService:_replicate(dt: number)
	syncTimer += dt
	fullSyncTimer += dt
	if syncTimer < 1 / GameConfig.EnemyNetRate then
		return
	end
	syncTimer = 0

	local batch = {}
	if fullSyncTimer >= GameConfig.EnemyFullSyncInterval then
		fullSyncTimer = 0
		for _, enemy in enemies do
			table.insert(batch, pack(enemy))
		end
	else
		for id in dirty do
			local enemy = enemies[id]
			if enemy then
				table.insert(batch, pack(enemy))
			end
		end
	end
	table.clear(dirty)

	if #batch > 0 then
		batchRemote:FireAllClients(workspace:GetServerTimeNow(), batch)
	end
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function EnemyService:GetById(id: number): Enemy?
	return enemies[id]
end

function EnemyService:GetCount(): number
	return enemyCount
end

function EnemyService:GetAll(): { Enemy }
	local list = table.create(enemyCount)
	for _, enemy in enemies do
		table.insert(list, enemy)
	end
	return list
end

function EnemyService:GetPosition(enemy: Enemy): Vector3
	return track:GetPositionAt(enemy.Distance)
end

-- Enemies whose path position is within `range` studs of `origin` (horizontal distance).
function EnemyService:GetEnemiesInRange(origin: Vector3, range: number): { Enemy }
	local result = {}
	local rangeSquared = range * range
	for _, enemy in enemies do
		local offset = track:GetPositionAt(enemy.Distance) - origin
		if offset.X * offset.X + offset.Z * offset.Z <= rangeSquared then
			table.insert(result, enemy)
		end
	end
	return result
end

return EnemyService
