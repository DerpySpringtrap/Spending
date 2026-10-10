local function check(cond, msg)
	if not cond then fail(msg .. " (t=" .. string.format("%.2f", now) .. ")") else print("ok: " .. msg) end
end
local map = newInstance("Folder", "Map"); map.Parent = workspace
local wps = newInstance("Folder", "Waypoints"); wps.Parent = map
local pts = { Vector3.new(0, 0, 0), Vector3.new(40, 0, 0), Vector3.new(40, 0, 40), Vector3.new(60, 0, 40) }
for i, p in pts do local part = newInstance("Part", tostring(i)); part.Position = p; part.Parent = wps end
local alice = addPlayer("Alice")
local main = __modules["ServerScriptService/Server/Main"]
task.spawn(main._props._fn, main)
local state = ReplicatedStorage.GameState
local Remotes = ReplicatedStorage.Remotes
local Enemy = require(__modules["ServerScriptService/Server/Services/EnemyService"])
local phaseLog = {}
state:GetAttributeChangedSignal("Phase"):Connect(function()
	table.insert(phaseLog, state:GetAttribute("Phase") .. "@" .. string.format("%.1f", now))
end)
local function phase() return state:GetAttribute("Phase") end
local function timeLeft() local e = state:GetAttribute("TimerEndsAt"); return if e > 0 then e - now else nil end
local function remoteCount(name, since)
	local n = 0
	for _, e in remoteLog[name] or {} do if e.t >= (since or 0) then n += 1 end end
	return n
end
