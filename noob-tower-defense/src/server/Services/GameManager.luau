--[[
	GameManager
	The match state machine. Runs forever on the server:

		Lobby ──(enough players, countdown / everyone ready)──► Match
		Match: for each wave
			Intermission (countdown, players can vote to skip)
			Wave         (WaveSpawner spawns; ends when the wave is cleared)
			wave-clear cash bonus
		─► Victory (all waves cleared)  or  GameOver (base health hit 0 / everyone left)
		─► End screen countdown ─► reset ─► Lobby

	Everything clients need for the HUD is published as attributes on
	ReplicatedStorage.GameState (see Shared/GameState.luau). Clients can only
	*vote* (VoteReady / VoteSkip); the server decides everything else.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Phase = GameState.Phase
local Attr = GameState.Attr

type Result = "Victory" | "GameOver"

local GameManager = {
	PhaseChanged = Signal.new(), -- (newPhase, oldPhase)
	MatchStarted = Signal.new(),
	MatchEnded = Signal.new(), -- (result, lastWave)
}

local state: Instance -- ReplicatedStorage.GameState
local economy, enemyService, waveSpawner

local currentPhase: string = Phase.Lobby
local matchResult: Result? = nil -- set the moment the match is decided
local votes: { [Player]: true } = {}

--------------------------------------------------------------------------------
-- State helpers
--------------------------------------------------------------------------------

local function setAttr(name: string, value: any)
	state:SetAttribute(name, value)
end

local function setPhase(phase: string)
	table.clear(votes) -- votes always belong to one phase
	if phase == currentPhase then
		return
	end
	local old = currentPhase
	currentPhase = phase
	setAttr(Attr.Phase, phase)
	GameManager.PhaseChanged:Fire(phase, old)
end

local function setTimer(seconds: number?)
	setAttr(Attr.TimerEndsAt, if seconds then workspace:GetServerTimeNow() + seconds else 0)
end

local function votesNeeded(fraction: number): number
	return math.max(1, math.ceil(#Players:GetPlayers() * fraction))
end

local function countVotes(): number
	local count = 0
	for player in votes do
		if player.Parent == Players then
			count += 1
		end
	end
	return count
end

local function voteFraction(): number
	return if currentPhase == Phase.Lobby then 1 else GameConfig.SkipVoteFraction
end

local function publishVotes()
	setAttr(Attr.Votes, countVotes())
	setAttr(Attr.VotesNeeded, votesNeeded(voteFraction()))
end

local function votesPassed(): boolean
	return #Players:GetPlayers() > 0 and countVotes() >= votesNeeded(voteFraction())
end

local function refreshEnemiesLeft()
	setAttr(Attr.EnemiesLeft, if currentPhase == Phase.Wave then waveSpawner:GetRemaining() else 0)
end

--[[
	Runs a countdown and publishes it to clients.
	  shortenTo() may return a smaller number of seconds (e.g. 0 when a skip vote passes).
	  shouldAbort() ends the countdown early and makes it return false.
	Returns true when the timer ran out normally (or was shortened to 0).
]]
local function countdown(seconds: number, shortenTo: (() -> number?)?, shouldAbort: (() -> boolean)?): boolean
	local endsAt = os.clock() + seconds
	setTimer(seconds)
	while true do
		if matchResult or (shouldAbort and shouldAbort()) then
			setTimer(nil)
			return false
		end
		local remaining = endsAt - os.clock()
		local cap = shortenTo and shortenTo()
		if cap and cap < remaining then
			endsAt = os.clock() + cap
			remaining = cap
			setTimer(cap)
		end
		if remaining <= 0 then
			break
		end
		task.wait(math.min(0.2, remaining))
	end
	setTimer(nil)
	return true
end

--------------------------------------------------------------------------------
-- Match events
--------------------------------------------------------------------------------

local function endMatch(result: Result)
	if matchResult then
		return
	end
	matchResult = result
end

local function onEnemyDied(enemy, killer: Player?)
	if currentPhase ~= Phase.Wave then
		return
	end
	local reward = enemy.Def.Reward
	if GameConfig.KillRewardMode == "Killer" and killer and killer.Parent == Players then
		economy:Add(killer, reward)
	else
		economy:AddAll(reward)
	end
end

local function onEnemyLeaked(enemy)
	if matchResult then
		return
	end
	local health = math.max(0, (state:GetAttribute(Attr.BaseHealth) or 0) - enemy.Def.LeakDamage)
	setAttr(Attr.BaseHealth, health)
	if health <= 0 then
		endMatch("GameOver")
	end
end

local function onVote(player: Player)
	if currentPhase ~= Phase.Lobby and currentPhase ~= Phase.Intermission then
		return
	end
	votes[player] = true
	publishVotes()
end

--------------------------------------------------------------------------------
-- Phases
--------------------------------------------------------------------------------

function GameManager:_runLobby()
	setPhase(Phase.Lobby)
	setAttr(Attr.Wave, 0)
	setAttr(Attr.EnemiesLeft, 0)
	publishVotes()

	while true do
		-- Wait for enough players.
		while #Players:GetPlayers() < GameConfig.MinPlayersToStart do
			setTimer(nil)
			task.wait(0.5)
		end
		publishVotes()

		local started = countdown(GameConfig.LobbyCountdown, function()
			return if votesPassed() then GameConfig.AllReadyCountdown else nil
		end, function()
			return #Players:GetPlayers() < GameConfig.MinPlayersToStart
		end)
		if started then
			return
		end
	end
end

function GameManager:_runMatch(): (Result, number)
	matchResult = nil
	local waveCount = waveSpawner:GetWaveCount()
	local firstWave = if RunService:IsStudio() then math.clamp(GameConfig.DebugStartWave, 1, waveCount) else 1

	economy:ResetAll(GameConfig.StartingCash)
	setAttr(Attr.MaxBaseHealth, GameConfig.StartingBaseHealth)
	setAttr(Attr.BaseHealth, GameConfig.StartingBaseHealth)
	setAttr(Attr.WaveCount, waveCount)
	setAttr(Attr.Wave, 0)
	self.MatchStarted:Fire()

	local lastWave = 0
	for wave = firstWave, waveCount do
		-- Intermission: build/upgrade time, skippable by vote.
		setPhase(Phase.Intermission)
		publishVotes()
		local intermission = if wave == firstWave then GameConfig.FirstIntermission else GameConfig.Intermission
		countdown(intermission, function()
			return if votesPassed() then 0 else nil
		end)
		if matchResult then
			break
		end

		-- Wave
		lastWave = wave
		setAttr(Attr.Wave, wave)
		setPhase(Phase.Wave)
		waveSpawner:StartWave(wave)
		refreshEnemiesLeft()
		while not matchResult and not waveSpawner:IsWaveCleared() do
			task.wait(0.2)
			refreshEnemiesLeft()
		end
		if matchResult then
			break
		end

		-- Wave cleared
		local waveDef = waveSpawner:GetWave(wave)
		local bonus = waveDef.Bonus or (GameConfig.WaveBonusBase + GameConfig.WaveBonusPerWave * wave)
		economy:AddAll(bonus)
		Remotes.Event("WaveCleared"):FireAllClients(wave, bonus)
	end

	local result: Result = matchResult or "Victory"
	matchResult = result
	waveSpawner:Stop()
	enemyService:Clear()
	return result, lastWave
end

function GameManager:_runEndScreen(result: Result, lastWave: number)
	setPhase(result)
	setAttr(Attr.EnemiesLeft, 0)
	Remotes.Event("MatchEnded"):FireAllClients(result, lastWave)
	self.MatchEnded:Fire(result, lastWave)
	-- matchResult is still set, which would end the countdown at once; clear it first.
	matchResult = nil
	countdown(GameConfig.EndScreenDuration)
	-- Next step: in a lobby + match place setup, TeleportService sends players
	-- back to the lobby place here instead of looping.
end

-- Cleans up after a crashed match so the server can keep running.
function GameManager:_recover()
	matchResult = nil
	waveSpawner:Stop()
	enemyService:Clear()
	setTimer(nil)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function GameManager:Init(services)
	economy = services.EconomyService
	enemyService = services.EnemyService
	waveSpawner = services.WaveSpawner

	state = GameState.GetFolder()
	setAttr(Attr.Phase, Phase.Lobby)
	setAttr(Attr.Wave, 0)
	setAttr(Attr.WaveCount, waveSpawner:GetWaveCount())
	setAttr(Attr.TimerEndsAt, 0)
	setAttr(Attr.BaseHealth, GameConfig.StartingBaseHealth)
	setAttr(Attr.MaxBaseHealth, GameConfig.StartingBaseHealth)
	setAttr(Attr.EnemiesLeft, 0)
	setAttr(Attr.Votes, 0)
	setAttr(Attr.VotesNeeded, 1)

	enemyService.Died:Connect(onEnemyDied)
	enemyService.Leaked:Connect(onEnemyLeaked)
	enemyService.Spawned:Connect(refreshEnemiesLeft)
	enemyService.Removed:Connect(refreshEnemiesLeft)

	local voteLimiter = RateLimiter.new(2, 4)
	local function handleVote(phase: string)
		return function(player: Player)
			if voteLimiter:Allow(player) and currentPhase == phase then
				onVote(player)
			end
		end
	end
	Remotes.Event("VoteReady").OnServerEvent:Connect(handleVote(Phase.Lobby))
	Remotes.Event("VoteSkip").OnServerEvent:Connect(handleVote(Phase.Intermission))

	Players.PlayerAdded:Connect(function()
		publishVotes()
	end)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		-- PlayerRemoving fires before the player leaves the list.
		task.defer(function()
			publishVotes()
			local inMatch = currentPhase == Phase.Intermission or currentPhase == Phase.Wave
			if inMatch and #Players:GetPlayers() == 0 then
				endMatch("GameOver")
			end
		end)
	end)
end

function GameManager:Start()
	task.spawn(function()
		while true do
			local ok, err = xpcall(function()
				self:_runLobby()
				local result, lastWave = self:_runMatch()
				self:_runEndScreen(result, lastWave)
			end, debug.traceback)
			if not ok then
				warn(`GameManager: match crashed, returning to lobby\n{err}`)
				self:_recover()
				task.wait(1)
			end
		end
	end)
end

function GameManager:GetPhase(): string
	return currentPhase
end

return GameManager
