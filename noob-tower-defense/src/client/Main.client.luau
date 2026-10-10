--[[
	Client bootstrap: the only LocalScript. Controllers mirror the server's
	services: optional :Init() then :Start(), both in order. Start must not yield.
	Once everything listens, the client tells the server it is ready and receives
	a snapshot of the enemies already on the field.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Net.Remotes)

local ORDER = {
	"EnemyRenderer",
	"DebugHud",
}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers = {}
for _, name in ORDER do
	controllers[name] = require(controllersFolder:WaitForChild(name))
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller:Init(controllers)
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		controller:Start()
	end
end

Remotes.Event("ClientReady"):FireServer()
