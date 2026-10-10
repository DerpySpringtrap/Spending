--[[
	WaveSpawner
	Turns a WaveConfig entry into enemies over time.

	WaveSpawner:StartWave(3)     -- begins spawning wave 3's groups (returns immediately)
	WaveSpawner:IsWaveCleared()  -- true once everything has spawned and nothing is alive
	WaveSpawner:GetRemaining()   -- enemies alive + enemies still to spawn
	WaveSpawner:Stop()           -- cancels any spawning still in progress

	Each StartWave/Stop bumps a run id. A spawning thread that sees a newer run
	id exits, so a game over in the middle of a wave can never leak late spawns
	into the next match.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EnemyConfig = require(Shared.Config.EnemyConfig)
local WaveConfig = require(Shared.Config.WaveConfig)
local Remotes = require(Shared.Net.Remotes)

local WaveSpawner = {}

local enemyService
local runId = 0
local pendingSpawns = 0

-- Fail at server start, not at wave 17, if a wave references a missing enemy.
local function validateConfig()
	assert(#WaveConfig > 0, "WaveConfig has no waves")
	for waveIndex, wave in WaveConfig do
		assert(#wave.Groups > 0, `WaveConfig[{waveIndex}] has no groups`)
		for groupIndex, group in wave.Groups do
			local where = `WaveConfig[{waveIndex}].Groups[{groupIndex}]`
			assert(EnemyConfig[group.Enemy], `{where}: unknown enemy "{group.Enemy}"`)
			assert(group.Count >= 1, `{where}: Count must be >= 1`)
			assert(group.Interval >= 0 and group.Delay >= 0, `{where}: Interval and Delay must be >= 0`)
		end
	end
end

function WaveSpawner:Init(services)
	enemyService = services.EnemyService
	validateConfig()
end

function WaveSpawner:GetWaveCount(): number
	return #WaveConfig
end

function WaveSpawner:GetWave(index: number): WaveConfig.Wave
	return WaveConfig[index]
end

function WaveSpawner:StartWave(index: number)
	local wave = WaveConfig[index]
	assert(wave, `WaveSpawner: wave {index} does not exist`)

	runId += 1
	local myRun = runId
	pendingSpawns = 0
	for _, group in wave.Groups do
		pendingSpawns += group.Count
	end

	for _, group in wave.Groups do
		task.spawn(function()
			if group.Delay > 0 then
				task.wait(group.Delay)
			end
			for i = 1, group.Count do
				if runId ~= myRun then
					return
				end
				-- Count down before spawning, so GetRemaining() never counts an enemy twice.
				pendingSpawns -= 1
				enemyService:Spawn(group.Enemy, { HealthScale = wave.HealthScale })
				if i < group.Count then
					task.wait(group.Interval)
				end
			end
		end)
	end

	Remotes.Event("WaveStarted"):FireAllClients(index, #WaveConfig)
end

function WaveSpawner:Stop()
	runId += 1
	pendingSpawns = 0
end

function WaveSpawner:GetRemaining(): number
	return pendingSpawns + enemyService:GetCount()
end

function WaveSpawner:IsWaveCleared(): boolean
	return pendingSpawns == 0 and enemyService:GetCount() == 0
end

return WaveSpawner
