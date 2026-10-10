--[[
	EnemyRenderer
	Draws the enemies the server simulates. Each enemy is a client-only model
	moved along the shared PathTrack:

		predicted = distance + speed * (serverNow - syncTime)

	The visual distance is advanced every frame and nudged toward the
	prediction, so a server correction never makes a model teleport (unless it
	is more than SNAP_DISTANCE studs off). Turning at waypoints is smoothed too.

	Models come from ReplicatedStorage.Assets.Enemies.<EnemyConfig.Model>.
	If the model is missing, a coloured block noob is built instead, so the
	game is playable before any art exists.

	Signals for later steps (VFX, audio, damage numbers):
		EnemyRenderer.EnemyAdded(visual)
		EnemyRenderer.EnemyDamaged(visual, amount)
		EnemyRenderer.EnemyRemoved(visual, reason)
		EnemyRenderer.BossPhase(visual, phaseIndex)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyConfig = require(Shared.Config.EnemyConfig)
local PathTrack = require(Shared.Path.PathTrack)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local SNAP_DISTANCE = 6 -- studs; bigger corrections teleport instead of easing
local CORRECTION_RATE = 8 -- how quickly visual distance converges on the prediction
local TURN_RATE = 10 -- how quickly models turn to face a new path segment
local HEALTH_BAR_DISTANCE = 150

local NOOB_TORSO = Color3.fromRGB(13, 105, 172)
local NOOB_LEGS = Color3.fromRGB(75, 151, 75)

export type Visual = {
	Id: number,
	Type: string,
	Def: EnemyConfig.EnemyDef,
	Model: Model,
	Distance: number, -- last server distance
	Speed: number,
	SyncTime: number, -- server time of the last distance update
	VisualDistance: number, -- what is drawn
	Rotation: CFrame,
	HeightOffset: number, -- pivot height above the path
	Health: number,
	MaxHealth: number,
	Flags: number, -- status effects: 1 slow, 2 stun, 4 burn
	HealthBar: BillboardGui,
	HealthFill: Frame,
}

local EnemyRenderer = {
	EnemyAdded = Signal.new(),
	EnemyDamaged = Signal.new(),
	EnemyRemoved = Signal.new(),
	BossPhase = Signal.new(),
}

local visuals: { [number]: Visual } = {}
local track: PathTrack.PathTrack
local container: Folder

--------------------------------------------------------------------------------
-- Models
--------------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A classic noob silhouette tinted with the enemy's colour.
local function buildPlaceholder(def: EnemyConfig.EnemyDef): Model
	local s = def.Scale
	local model = Instance.new("Model")
	local torso = makePart("Torso", Vector3.new(2, 2, 1) * s, NOOB_TORSO:Lerp(def.PlaceholderColor, 0.35), model)
	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2) * s, def.PlaceholderColor, model)
	local legs = makePart("Legs", Vector3.new(2, 2, 1) * s, NOOB_LEGS:Lerp(def.PlaceholderColor, 0.35), model)
	local leftArm = makePart("LeftArm", Vector3.new(1, 2, 1) * s, def.PlaceholderColor, model)
	local rightArm = makePart("RightArm", Vector3.new(1, 2, 1) * s, def.PlaceholderColor, model)
	head.Shape = Enum.PartType.Ball

	torso.CFrame = CFrame.new()
	head.CFrame = CFrame.new(0, 1.6 * s, 0)
	legs.CFrame = CFrame.new(0, -2 * s, 0)
	-- Arms stretched forward: the zombie pose.
	leftArm.CFrame = CFrame.new(-1.5 * s, 0.5 * s, -0.75 * s) * CFrame.Angles(math.rad(90), 0, 0)
	rightArm.CFrame = CFrame.new(1.5 * s, 0.5 * s, -0.75 * s) * CFrame.Angles(math.rad(90), 0, 0)

	model.PrimaryPart = torso
	return model
end

local function prepareModel(def: EnemyConfig.EnemyDef): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Enemies")
	local template = folder and folder:FindFirstChild(def.Model)

	if template and not template:IsA("Model") then
		template = nil
	end

	local model: Model
	if template then
		model = template:Clone()
		if not model.PrimaryPart then
			local root = model:FindFirstChild("HumanoidRootPart")
			model.PrimaryPart = if root and root:IsA("BasePart")
				then root
				else model:FindFirstChildWhichIsA("BasePart", true)
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	else
		model = buildPlaceholder(def)
	end

	-- Visual only: no physics, no raycast hits, no touch events. The root is
	-- anchored; the rest stays welded/Motor6D-jointed so animations still play.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	if template then
		-- Real rigs: anchor only the root; limbs follow through their joints.
		if model.PrimaryPart then
			model.PrimaryPart.Anchored = true
		end
	else
		-- Placeholders have no joints, so anchor every part.
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	end
	return model
end

local function buildHealthBar(visual: Visual, topOffset: number)
	local def = visual.Def
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromScale(if def.IsBoss then 6 else 2.6 * def.Scale, if def.IsBoss then 0.6 else 0.3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, topOffset + 0.8, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = HEALTH_BAR_DISTANCE
	billboard.Enabled = def.IsBoss == true -- normal enemies show it once damaged
	billboard.Adornee = visual.Model.PrimaryPart

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = billboard
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke", back)
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(0, 0, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)

	billboard.Parent = visual.Model
	visual.HealthBar = billboard
	visual.HealthFill = fill
end

local function setHealth(visual: Visual, health: number)
	local previous = visual.Health
	visual.Health = health
	local fraction = if visual.MaxHealth > 0 then math.clamp(health / visual.MaxHealth, 0, 1) else 0
	visual.HealthFill.Size = UDim2.fromScale(fraction, 1)
	visual.HealthFill.BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(90, 220, 90), fraction)
	if fraction < 1 then
		visual.HealthBar.Enabled = true
	end
	if health < previous then
		EnemyRenderer.EnemyDamaged:Fire(visual, previous - health)
	end
end

--------------------------------------------------------------------------------
-- Network handlers
--------------------------------------------------------------------------------

local function onSpawned(
	id: number,
	typeName: string,
	distance: number,
	speed: number,
	health: number,
	maxHealth: number,
	serverTime: number
)
	local existing = visuals[id]
	if existing then
		-- Already known (snapshot overlapped a live spawn): just resync.
		existing.Distance, existing.Speed, existing.SyncTime = distance, speed, serverTime
		setHealth(existing, health)
		return
	end
	local def = EnemyConfig[typeName]
	if not def then
		warn(`EnemyRenderer: unknown enemy type "{typeName}"`)
		return
	end

	local model = prepareModel(def)
	model.Name = `{typeName}_{id}`
	model:PivotTo(CFrame.new())
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	local heightOffset = -bottom -- pivot sits at the origin, so this is pivot -> feet
	local topOffset = boxCFrame.Position.Y + boxSize.Y / 2

	local start = track:GetCFrameAt(distance)
	local visual: Visual = {
		Id = id,
		Type = typeName,
		Def = def,
		Model = model,
		Distance = distance,
		Speed = speed,
		SyncTime = serverTime,
		VisualDistance = distance,
		Rotation = start.Rotation,
		HeightOffset = heightOffset,
		Health = health,
		MaxHealth = maxHealth,
		Flags = 0,
		HealthBar = nil :: any,
		HealthFill = nil :: any,
	}
	buildHealthBar(visual, topOffset)
	setHealth(visual, health)
	model:PivotTo(CFrame.new(start.Position + Vector3.new(0, heightOffset, 0)) * visual.Rotation)
	model.Parent = container

	visuals[id] = visual
	EnemyRenderer.EnemyAdded:Fire(visual)
end

local function onBatch(serverTime: number, batch: { { number } })
	for _, entry in batch do
		local visual = visuals[entry[1]]
		if visual then
			visual.Distance = entry[2]
			visual.Speed = entry[3]
			visual.SyncTime = serverTime
			visual.Flags = entry[5] or 0
			if entry[4] ~= visual.Health then
				setHealth(visual, entry[4])
			end
		end
	end
end

local function playDeath(model: Model)
	-- Placeholder death: sink and fade. Step 6 swaps this for a death animation + VFX.
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play()
		elseif part:IsA("BillboardGui") then
			part.Enabled = false
		end
	end
	task.delay(0.4, function()
		model:Destroy()
	end)
end

local function onRemoved(id: number, reason: string)
	local visual = visuals[id]
	if not visual then
		return
	end
	visuals[id] = nil
	EnemyRenderer.EnemyRemoved:Fire(visual, reason)
	if reason == "Killed" then
		playDeath(visual.Model)
	else
		visual.Model:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Per-frame movement
--------------------------------------------------------------------------------

local function update(dt: number)
	local now = workspace:GetServerTimeNow()
	local correction = 1 - math.exp(-CORRECTION_RATE * dt)
	local turn = 1 - math.exp(-TURN_RATE * dt)
	local length = track.Length

	for _, visual in visuals do
		local predicted = math.min(visual.Distance + visual.Speed * (now - visual.SyncTime), length)
		local drawn = visual.VisualDistance + visual.Speed * dt
		if math.abs(predicted - drawn) > SNAP_DISTANCE then
			drawn = predicted
		else
			drawn += (predicted - drawn) * correction
		end
		drawn = math.clamp(drawn, 0, length)
		visual.VisualDistance = drawn

		local target = track:GetCFrameAt(drawn)
		visual.Rotation = visual.Rotation:Lerp(target.Rotation, turn)
		visual.Model:PivotTo(CFrame.new(target.Position + Vector3.new(0, visual.HeightOffset, 0)) * visual.Rotation)
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function EnemyRenderer:Init()
	local runtime = ReplicatedStorage:WaitForChild("Runtime")
	track = PathTrack.fromFolder(runtime:WaitForChild("PathPoints"))

	container = Instance.new("Folder")
	container.Name = "ClientEnemies"
	container.Parent = workspace
end

function EnemyRenderer:Start()
	Remotes.Event("EnemySpawned").OnClientEvent:Connect(onSpawned)
	Remotes.Event("EnemyBatchUpdate").OnClientEvent:Connect(onBatch)
	Remotes.Event("EnemyRemoved").OnClientEvent:Connect(onRemoved)
	Remotes.Event("BossPhase").OnClientEvent:Connect(function(id: number, phaseIndex: number)
		local visual = visuals[id]
		if visual then
			EnemyRenderer.BossPhase:Fire(visual, phaseIndex)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

function EnemyRenderer:GetVisual(id: number): Visual?
	return visuals[id]
end

function EnemyRenderer:GetTrack(): PathTrack.PathTrack
	return track
end

return EnemyRenderer
