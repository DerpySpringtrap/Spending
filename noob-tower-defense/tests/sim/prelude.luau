-- Minimal Roblox mock for headless simulation of the server code.
local now = 0
local DT = 1 / 30
local failures = {}
local warnings = {}
local function fail(msg)
	table.insert(failures, msg)
	print("FAIL: " .. msg)
end

local os = setmetatable({ clock = function() return now end }, { __index = os })

local function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	table.insert(warnings, table.concat(parts, " "))
	print("WARN:", ...)
end

-- Scheduler -----------------------------------------------------------------
local sleepers = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		fail("thread error: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end
local task = {}
function task.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
function task.wait(s)
	s = math.max(s or 0, 1 / 60)
	table.insert(sleepers, { co = coroutine.running(), at = now + s, start = now })
	return coroutine.yield()
end
function task.delay(s, f, ...)
	table.insert(sleepers, { fn = f, args = table.pack(...), at = now + (s or 0), start = now })
end
function task.defer(f, ...)
	task.delay(0, f, ...)
end
local function wakeSleepers()
	local due = {}
	local rest = {}
	for _, s in sleepers do
		if s.at <= now + 1e-9 then table.insert(due, s) else table.insert(rest, s) end
	end
	sleepers = rest
	table.sort(due, function(a, b) return a.at < b.at end)
	for _, s in due do
		if s.fn then
			task.spawn(s.fn, table.unpack(s.args, 1, s.args.n))
		else
			resume(s.co, now - s.start)
		end
	end
end

-- Signals -------------------------------------------------------------------
local function newEvent()
	local handlers = {}
	local ev = {}
	function ev:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect()
			c.Connected = false
			local i = table.find(handlers, c)
			if i then table.remove(handlers, i) end
		end
		c.fn = fn
		table.insert(handlers, c)
		return c
	end
	function ev:Fire(...)
		for _, c in table.clone(handlers) do
			if c.Connected then task.spawn(c.fn, ...) end
		end
	end
	return ev
end

-- Datatypes -----------------------------------------------------------------
local Vector3 = {}
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	if k == "Unit" then local m = v.Magnitude; return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)

local Color3 = {}
function Color3.fromRGB(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
function Color3.new(r, g, b) return { R = r, G = g, B = b } end

-- Instances -----------------------------------------------------------------
local Methods = {}
local InstanceMT = {}
InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m then return m end
	local v = self._props[key]
	if v ~= nil then return v end
	for _, c in self._children do
		if c._props.Name == key then return c end
	end
	return nil
end
InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = self._props.Parent
		if old then
			local i = table.find(old._children, self)
			if i then table.remove(old._children, i) end
		end
		self._props.Parent = value
		if value then table.insert(value._children, self) end
		if value and value._props.ChildAdded then value._props.ChildAdded:Fire(self) end
	else
		self._props[key] = value
	end
end
InstanceMT.__tostring = function(self) return self._props.Name end

local remoteLog = {} -- name -> list of { time, args }
local function newInstance(className, name)
	local self = setmetatable({
		_props = { Name = name or className, ClassName = className },
		_children = {},
		_attrs = {},
		_attrSignals = {},
	}, InstanceMT)
	if className == "RemoteEvent" then
		self._props.OnServerEvent = newEvent()
		self._props.OnClientEvent = newEvent()
	end
	return self
end
local Instance = { new = function(className) return newInstance(className) end }

local classTree = {
	Part = { "BasePart" }, Folder = {}, Configuration = {}, Vector3Value = { "ValueBase" }, IntValue = { "ValueBase" },
}
function Methods.IsA(self, class)
	if self.ClassName == class or class == "Instance" then return true end
	for _, parent in classTree[self.ClassName] or {} do
		if parent == class then return true end
	end
	return false
end
function Methods.FindFirstChild(self, name)
	for _, c in self._children do
		if c._props.Name == name then return c end
	end
	return nil
end
function Methods.WaitForChild(self, name)
	local c = Methods.FindFirstChild(self, name)
	if not c then error("WaitForChild would hang: " .. self.Name .. "." .. name) end
	return c
end
function Methods.GetChildren(self) return table.clone(self._children) end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in i._children do table.insert(out, c); walk(c) end
	end
	walk(self)
	return out
end
function Methods.FindFirstChildOfClass(self, class)
	for _, c in self._children do
		if c.ClassName == class then return c end
	end
	return nil
end
function Methods.GetFullName(self)
	local p = self._props.Parent
	return if p then Methods.GetFullName(p) .. "." .. self.Name else self.Name
end
function Methods.Destroy(self) self.Parent = nil end
function Methods.SetAttribute(self, name, value)
	if self._attrs[name] == value then return end
	self._attrs[name] = value
	local sig = self._attrSignals[name]
	if sig then sig:Fire() end
end
function Methods.GetAttribute(self, name) return self._attrs[name] end
function Methods.GetAttributeChangedSignal(self, name)
	self._attrSignals[name] = self._attrSignals[name] or newEvent()
	return self._attrSignals[name]
end
local function log(remote, target, ...)
	remoteLog[remote.Name] = remoteLog[remote.Name] or {}
	table.insert(remoteLog[remote.Name], { t = now, target = target, args = table.pack(...) })
end
function Methods.FireAllClients(self, ...) log(self, "all", ...) end
function Methods.FireClient(self, player, ...) log(self, player, ...) end
function Methods.GetServerTimeNow() return now end
function Methods.GetPlayers(self) return table.clone(self._children) end
function Methods.GetService(self, name) return self._props.Services[name] end

local game = newInstance("DataModel", "game")
local workspace = newInstance("Workspace", "Workspace")
local ReplicatedStorage = newInstance("ReplicatedStorage", "ReplicatedStorage")
local ServerScriptService = newInstance("ServerScriptService", "ServerScriptService")
local Players = newInstance("Players", "Players")
Players._props.PlayerAdded = newEvent()
Players._props.PlayerRemoving = newEvent()
local heartbeat = newEvent()
local RunService = newInstance("RunService", "RunService")
RunService._props.Heartbeat = heartbeat
Methods.IsServer = function() return true end
Methods.IsStudio = function() return true end
game._props.Services = {
	Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = RunService,
	ServerScriptService = ServerScriptService, Workspace = workspace,
}

local function addPlayer(name)
	local p = newInstance("Player", name)
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
local function removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end

-- Modules ---------------------------------------------------------------------
local moduleCache = {}
local function require(inst)
	if moduleCache[inst] == nil then
		moduleCache[inst] = inst._props._fn(inst)
	end
	return moduleCache[inst]
end
local roots = { ReplicatedStorage = ReplicatedStorage, ServerScriptService = ServerScriptService }
local function defineModule(path, className, fn)
	local parts = string.split(path, "/")
	local node = roots[parts[1]]
	for i = 2, #parts - 1 do
		local child = Methods.FindFirstChild(node, parts[i])
		if not child then
			child = newInstance("Folder", parts[i])
			child.Parent = node
		end
		node = child
	end
	local inst = newInstance(className, parts[#parts])
	inst._props._fn = fn
	inst.Parent = node
	return inst
end

local function step(seconds, until_)
	local target = now + seconds
	while now < target - 1e-9 do
		now += DT
		heartbeat:Fire(DT)
		wakeSleepers()
		if until_ and until_() then return true end
	end
	return false
end
