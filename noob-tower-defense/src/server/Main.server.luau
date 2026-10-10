--[[
	Server bootstrap: the only Script on the server. Every system is a
	ModuleScript service with optional :Init(services) and :Start().

	  Init  runs in order, one service at a time. Wire up references, remotes and
	        signals here; do not start loops or yield for long.
	  Start runs after every Init has finished, each in its own thread.

	To add a service (TowerService in step 2): create the module in Services/
	and add its name to ORDER after the services it depends on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local ORDER = {
	"PathService",
	"EconomyService",
	"EnemyService",
	"WaveSpawner",
	"GameManager",
}

Remotes.Init()

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}
for _, name in ORDER do
	services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print(`[NoobTD] server started ({#ORDER} services)`)
