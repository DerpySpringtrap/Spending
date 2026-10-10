--!strict
--[[
	Signal
	A small, dependency-free event object for server-side and client-side code
	(the same idea as BindableEvent, without the Instance or the argument copying).

	local died = Signal.new()
	local connection = died:Connect(function(enemy) ... end)
	died:Fire(enemy)
	connection:Disconnect()

	Handlers run in their own thread (task.spawn), so one failing handler never
	stops the others and a handler may yield.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Handler = (...any) -> ()

type ConnectionImpl = Connection & {
	_signal: any,
	_fn: Handler,
}

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { ConnectionImpl } }, Signal))

local function disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: Handler): Connection
	local connection: ConnectionImpl = {
		Connected = true,
		Disconnect = disconnect :: any,
		_signal = self,
		_fn = fn,
	}
	table.insert(self._handlers, connection)
	return connection
end

function Signal.Once(self: Signal, fn: Handler): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Snapshot so handlers may connect/disconnect while we iterate.
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: Signal)
	for _, connection in table.clone(self._handlers) do
		connection:Disconnect()
	end
end

return Signal
