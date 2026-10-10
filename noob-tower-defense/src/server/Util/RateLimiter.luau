--!strict
--[[
	RateLimiter
	Token bucket per player. Put one in front of every client -> server remote so
	an exploiter spamming requests costs you nothing.

	local limiter = RateLimiter.new(5, 10) -- 5 requests/second, bursts of up to 10
	remote.OnServerEvent:Connect(function(player, ...)
		if not limiter:Allow(player) then return end
		...
	end)
]]

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, updatedAt: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_rate: number,
		_burst: number,
		_buckets: { [Player]: Bucket },
	},
	RateLimiter
))

local limiters: { RateLimiter } = setmetatable({}, { __mode = "v" }) :: any

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in limiters do
		limiter._buckets[player] = nil
	end
end)

function RateLimiter.new(perSecond: number, burst: number?): RateLimiter
	local self = setmetatable({
		_rate = perSecond,
		_burst = burst or perSecond,
		_buckets = {},
	}, RateLimiter)
	table.insert(limiters, self)
	return self
end

function RateLimiter.Allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { tokens = self._burst, updatedAt = now }
		self._buckets[player] = bucket
	end
	bucket.tokens = math.min(self._burst, bucket.tokens + (now - bucket.updatedAt) * self._rate)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimiter
