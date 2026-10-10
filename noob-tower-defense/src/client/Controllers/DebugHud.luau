--[[
	DebugHud
	A minimal, functional HUD so the game loop can be play-tested now. Step 5
	replaces it with the full arcade-style HUD; that one reads the same
	GameState attributes, so nothing on the server changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Net.Remotes)

local Attr = GameState.Attr
local Phase = GameState.Phase

local DebugHud = {}

local state: Instance
local player = Players.LocalPlayer
local statusLabel: TextLabel
local timerLabel: TextLabel
local voteButton: TextButton

local function label(parent: Instance, name: string, size: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Parent = parent
	return text
end

local function refresh()
	local phase = state:GetAttribute(Attr.Phase) or Phase.Lobby
	local wave = state:GetAttribute(Attr.Wave) or 0
	local waveCount = state:GetAttribute(Attr.WaveCount) or 0
	local base = state:GetAttribute(Attr.BaseHealth) or 0
	local maxBase = state:GetAttribute(Attr.MaxBaseHealth) or 0
	local enemies = state:GetAttribute(Attr.EnemiesLeft) or 0
	local cash = player:GetAttribute(GameState.PlayerAttr.Cash) or 0

	statusLabel.Text =
		`{phase}  ·  Wave {wave}/{waveCount}  ·  Enemies {enemies}  ·  Base {base}/{maxBase}  ·  ${cash}`

	local votes = state:GetAttribute(Attr.Votes) or 0
	local needed = state:GetAttribute(Attr.VotesNeeded) or 1
	if phase == Phase.Lobby then
		voteButton.Visible = true
		voteButton.Text = `Ready ({votes}/{needed})`
	elseif phase == Phase.Intermission then
		voteButton.Visible = true
		voteButton.Text = `Skip ({votes}/{needed})`
	else
		voteButton.Visible = false
	end
end

local function refreshTimer()
	local left = GameState.GetTimeLeft(state)
	if left then
		local seconds = math.ceil(left)
		timerLabel.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	else
		timerLabel.Text = ""
	end
end

function DebugHud:Init()
	state = GameState.GetFolder()

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(620, 64)
	bar.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
	bar.BackgroundTransparency = 0.2
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", bar).Color = Color3.fromRGB(255, 200, 60)

	statusLabel = label(bar, "Status", UDim2.new(1, 0, 0, 30), 20)
	timerLabel = label(bar, "Timer", UDim2.new(1, 0, 0, 30), 26)
	timerLabel.Position = UDim2.fromOffset(0, 30)
	timerLabel.TextColor3 = Color3.fromRGB(255, 220, 90)

	voteButton = Instance.new("TextButton")
	voteButton.AnchorPoint = Vector2.new(0.5, 0)
	voteButton.Position = UDim2.new(0.5, 0, 0, 80)
	voteButton.Size = UDim2.fromOffset(180, 40)
	voteButton.BackgroundColor3 = Color3.fromRGB(70, 190, 90)
	voteButton.Font = Enum.Font.FredokaOne
	voteButton.TextSize = 22
	voteButton.TextColor3 = Color3.new(1, 1, 1)
	voteButton.Parent = gui
	Instance.new("UICorner", voteButton).CornerRadius = UDim.new(0, 10)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DebugHud:Start()
	for _, name in Attr do
		state:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal(GameState.PlayerAttr.Cash):Connect(refresh)

	voteButton.Activated:Connect(function()
		local phase = state:GetAttribute(Attr.Phase)
		if phase == Phase.Lobby then
			Remotes.Event("VoteReady"):FireServer()
		elseif phase == Phase.Intermission then
			Remotes.Event("VoteSkip"):FireServer()
		end
	end)

	RunService.Heartbeat:Connect(refreshTimer)
	refresh()
end

return DebugHud
