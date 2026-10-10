--!strict
--[[
	Remotes
	Every RemoteEvent / RemoteFunction in the game is declared in this file, so
	there is exactly one place to audit what a client is allowed to send.

	Server:  Remotes.Init() once at boot (creates ReplicatedStorage.Remotes),
	         then Remotes.Event("EnemySpawned"):FireAllClients(...)
	Client:  Remotes.Event("VoteSkip"):FireServer()   (waits for the server to create it)

	Security rules (enforced by the services that listen, not here):
	  * A client never tells the server a result ("I killed enemy 5", "I have $900").
	    It only sends *requests* ("place a Scout at this position"), which the
	    server validates against its own state: phase, cash, ownership, position,
	    rate limits.
	  * Never trust argument types: check typeof() on everything a client sends.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- Server -> client
	"EnemySpawned", -- (id, typeName, distance, speed, health, maxHealth, serverTime)
	"EnemyBatchUpdate", -- (serverTime, { {id, distance, speed, health}, ... })
	"EnemyRemoved", -- (id, reason: "Killed" | "Leaked" | "Cleared")
	"BossPhase", -- (bossId, phaseIndex)  boss crossed a health threshold and summoned minions
	"WaveStarted", -- (waveIndex, waveCount)
	"WaveCleared", -- (waveIndex, bonusCash)
	"MatchEnded", -- (result: "Victory" | "GameOver", lastWave)

	-- Client -> server (requests only; validated + rate limited on the server)
	"ClientReady", -- client finished loading; server replies with a snapshot
	"VoteReady", -- lobby: ready up
	"VoteSkip", -- intermission: vote to skip the countdown
}

-- Request/response calls. The tower system (step 2) adds PlaceTower, UpgradeTower,
-- SellTower and SetTargetMode here. Only declare a function once a server handler
-- exists for it: invoking a RemoteFunction with no handler hangs the client.
local FUNCTIONS: { string } = {}

local eventSet: { [string]: true } = {}
for _, name in EVENTS do
	eventSet[name] = true
end
local functionSet: { [string]: true } = {}
for _, name in FUNCTIONS do
	functionSet[name] = true
end

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getOrCreate(name: string, className: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

-- Server only: create every remote up front so clients never wait on a missing one.
function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init is server-only")
	for _, name in EVENTS do
		getOrCreate(name, "RemoteEvent")
	end
	for _, name in FUNCTIONS do
		getOrCreate(name, "RemoteFunction")
	end
end

function Remotes.Event(name: string): RemoteEvent
	assert(eventSet[name], `Unknown RemoteEvent "{name}" (declare it in Remotes.luau)`)
	return getOrCreate(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	assert(functionSet[name], `Unknown RemoteFunction "{name}" (declare it in Remotes.luau)`)
	return getOrCreate(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
