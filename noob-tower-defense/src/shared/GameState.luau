--!strict
--[[
	GameState
	Match state the server publishes to every client as attributes on
	ReplicatedStorage.GameState. Attributes replicate automatically (including to
	players who join late) and clients cannot change what the server sees, so
	they are a cheap, exploit-safe way to share HUD values.

	Client:
		local state = GameState.GetFolder()
		state:GetAttributeChangedSignal(GameState.Attr.Wave):Connect(...)

	Per-player cash lives on the Player as the "Cash" attribute (see EconomyService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = {}

GameState.Phase = table.freeze({
	Lobby = "Lobby", -- waiting for players / ready-up countdown
	Intermission = "Intermission", -- countdown before the next wave
	Wave = "Wave", -- enemies are spawning / alive
	Victory = "Victory",
	GameOver = "GameOver",
})

GameState.Attr = table.freeze({
	Phase = "Phase", -- string, one of GameState.Phase
	Wave = "Wave", -- number, current wave (0 before wave 1)
	WaveCount = "WaveCount", -- number, total waves this match
	TimerEndsAt = "TimerEndsAt", -- number, workspace:GetServerTimeNow() when the timer hits 0; 0 = no timer
	BaseHealth = "BaseHealth", -- number
	MaxBaseHealth = "MaxBaseHealth", -- number
	EnemiesLeft = "EnemiesLeft", -- number, alive + still to spawn this wave
	Votes = "Votes", -- number, ready votes in the lobby / skip votes in intermission
	VotesNeeded = "VotesNeeded", -- number
})

GameState.PlayerAttr = table.freeze({
	Cash = "Cash",
})

local FOLDER_NAME = "GameState"

function GameState.GetFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Configuration")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- Seconds left on the published timer (client or server), or nil when no timer runs.
function GameState.GetTimeLeft(folder: Instance): number?
	local endsAt = folder:GetAttribute(GameState.Attr.TimerEndsAt)
	if typeof(endsAt) ~= "number" or endsAt <= 0 then
		return nil
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

return GameState
