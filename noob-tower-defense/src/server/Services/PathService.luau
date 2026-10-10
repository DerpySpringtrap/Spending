--[[
	PathService
	Reads the enemy route from Workspace.Map.Waypoints (parts named 1, 2, 3, ...)
	and publishes the waypoint positions to ReplicatedStorage.Runtime.PathPoints.

	Why publish a copy: with StreamingEnabled the client may not have the
	waypoint parts streamed in. ReplicatedStorage always replicates in full, so
	every client gets the exact same track the server simulates on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathTrack = require(ReplicatedStorage.Shared.Path.PathTrack)

local PathService = {}

PathService.Track = (nil :: any) :: PathTrack.PathTrack

function PathService:Init()
	local map = workspace:WaitForChild("Map", 10)
	assert(map, "PathService: Workspace.Map is missing (see docs/STUDIO_SETUP.md)")
	local waypoints = map:WaitForChild("Waypoints", 10)
	assert(waypoints, "PathService: Workspace.Map.Waypoints is missing (see docs/STUDIO_SETUP.md)")

	self.Track = PathTrack.fromFolder(waypoints)
	assert(self.Track:GetLength() > 0, "PathService: the waypoints are all at the same position")

	-- Build the whole folder before parenting it, so it replicates as one unit.
	local runtime = ReplicatedStorage:FindFirstChild("Runtime")
	if not runtime then
		runtime = Instance.new("Folder")
		runtime.Name = "Runtime"
		runtime.Parent = ReplicatedStorage
	end
	local old = runtime:FindFirstChild("PathPoints")
	if old then
		old:Destroy()
	end
	local published = Instance.new("Folder")
	published.Name = "PathPoints"
	for index, point in self.Track.Points do
		local value = Instance.new("Vector3Value")
		value.Name = tostring(index)
		value.Value = point
		value.Parent = published
	end
	published.Parent = runtime
end

function PathService:GetTrack(): PathTrack.PathTrack
	return self.Track
end

return PathService
