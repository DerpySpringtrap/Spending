--!strict
--[[
	PathTrack
	The enemy route as a polyline of waypoints. Enemies are stored as a single
	number, "distance travelled along the track", and positions are derived from
	it. Server and client use the same math, so the server only has to send
	(distance, speed, time) and every client can draw the enemy smoothly by itself.

	local track = PathTrack.fromFolder(workspace.Map.Waypoints)
	track:GetLength()          --> total studs from spawn to base
	track:GetPositionAt(42)    --> Vector3 42 studs along the path
	track:GetCFrameAt(42)      --> same position, facing the direction of travel
]]

local PathTrack = {}
PathTrack.__index = PathTrack

export type PathTrack = typeof(setmetatable(
	{} :: {
		Points: { Vector3 },
		Cumulative: { number }, -- Cumulative[i] = distance from point 1 to point i
		Length: number,
	},
	PathTrack
))

function PathTrack.new(points: { Vector3 }): PathTrack
	assert(#points >= 2, "PathTrack needs at least 2 waypoints")
	local cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return setmetatable({
		Points = points,
		Cumulative = cumulative,
		Length = cumulative[#points],
	}, PathTrack)
end

-- Builds a track from the children of `folder`, ordered by their numeric names
-- ("1", "2", "3", ...). Children may be BaseParts, Attachments or Vector3Values.
function PathTrack.fromFolder(folder: Instance): PathTrack
	local entries: { { index: number, position: Vector3 } } = {}
	for _, child in folder:GetChildren() do
		local index = tonumber(child.Name)
		if not index then
			warn(`PathTrack: ignoring "{child:GetFullName()}" (waypoints must be named 1, 2, 3, ...)`)
			continue
		end
		local position: Vector3
		if child:IsA("BasePart") then
			position = child.Position
		elseif child:IsA("Attachment") then
			position = child.WorldPosition
		elseif child:IsA("Vector3Value") then
			position = child.Value
		else
			warn(`PathTrack: ignoring "{child:GetFullName()}" ({child.ClassName} is not a waypoint type)`)
			continue
		end
		table.insert(entries, { index = index, position = position })
	end
	table.sort(entries, function(a, b)
		return a.index < b.index
	end)

	local points = {}
	for _, entry in entries do
		table.insert(points, entry.position)
	end
	return PathTrack.new(points)
end

function PathTrack.GetLength(self: PathTrack): number
	return self.Length
end

-- Index i of the segment (Points[i] -> Points[i + 1]) that contains `distance`.
function PathTrack._segmentAt(self: PathTrack, distance: number): number
	local cumulative = self.Cumulative
	local low, high = 1, #cumulative - 1
	while low < high do
		local mid = (low + high + 1) // 2
		if cumulative[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

function PathTrack.GetPositionAt(self: PathTrack, distance: number): Vector3
	distance = math.clamp(distance, 0, self.Length)
	local i = self:_segmentAt(distance)
	local a, b = self.Points[i], self.Points[i + 1]
	local segmentLength = self.Cumulative[i + 1] - self.Cumulative[i]
	if segmentLength <= 0 then
		return a
	end
	return a:Lerp(b, (distance - self.Cumulative[i]) / segmentLength)
end

-- Position plus a yaw-only rotation facing the direction of travel.
function PathTrack.GetCFrameAt(self: PathTrack, distance: number): CFrame
	distance = math.clamp(distance, 0, self.Length)
	local position = self:GetPositionAt(distance)
	local i = self:_segmentAt(distance)
	-- Walk forward past zero-length segments to find a usable direction.
	local direction = Vector3.zero
	while i < #self.Points do
		local delta = self.Points[i + 1] - self.Points[i]
		direction = Vector3.new(delta.X, 0, delta.Z)
		if direction.Magnitude > 1e-3 then
			break
		end
		i += 1
	end
	if direction.Magnitude <= 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + direction)
end

-- 0 at the spawn, 1 at the base.
function PathTrack.GetProgress(self: PathTrack, distance: number): number
	return math.clamp(distance / self.Length, 0, 1)
end

return PathTrack
