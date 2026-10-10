--[[
	EconomyService
	Server-owned cash for each player. The server table is the source of truth;
	it is mirrored to the player's "Cash" attribute (for the HUD) and to
	leaderstats (for the player list). Clients can never write either in a way
	the server sees, so the only way to gain cash is through this service.

	Economy:TrySpend(player, 350) -> true if the player could afford it (and pays)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)

local EconomyService = {}

local cash: { [Player]: number } = {}

local function publish(player: Player)
	local amount = cash[player]
	if amount == nil then
		return
	end
	player:SetAttribute(GameState.PlayerAttr.Cash, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Cash")
	if value then
		(value :: IntValue).Value = amount
	end
end

local function setup(player: Player)
	if cash[player] ~= nil then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Cash"
	value.Parent = leaderstats
	leaderstats.Parent = player

	cash[player] = GameConfig.StartingCash
	publish(player)
end

function EconomyService:Init()
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		cash[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

function EconomyService:Get(player: Player): number
	return cash[player] or 0
end

function EconomyService:Set(player: Player, amount: number)
	if cash[player] == nil then
		return
	end
	cash[player] = math.max(0, math.floor(amount))
	publish(player)
end

function EconomyService:Add(player: Player, amount: number)
	if cash[player] == nil or amount <= 0 then
		return
	end
	self:Set(player, cash[player] + amount)
end

function EconomyService:AddAll(amount: number)
	for _, player in Players:GetPlayers() do
		self:Add(player, amount)
	end
end

function EconomyService:ResetAll(amount: number)
	for _, player in Players:GetPlayers() do
		self:Set(player, amount)
	end
end

-- Server code runs one thread at a time between yields, so check-then-subtract is atomic.
function EconomyService:TrySpend(player: Player, amount: number): boolean
	local current = cash[player]
	if current == nil or amount < 0 or current < amount then
		return false
	end
	self:Set(player, current - amount)
	return true
end

return EconomyService
