--!strict
-- Match-wide tuning. Everything a designer may want to tweak without touching logic.

return table.freeze({
	-- Lobby
	MinPlayersToStart = 1,
	LobbyCountdown = 20, -- seconds once enough players are in
	AllReadyCountdown = 3, -- countdown drops to this when every player has pressed Ready

	-- Between waves
	FirstIntermission = 15, -- time to place the first towers
	Intermission = 8,
	SkipVoteFraction = 0.5, -- fraction of players needed to skip an intermission (rounded up, min 1)

	-- After the match
	EndScreenDuration = 12,

	-- Economy
	StartingCash = 600,
	KillRewardMode = "Shared" :: "Shared" | "Killer", -- Shared: every player gets each kill reward (co-op friendly)
	WaveBonusBase = 100, -- cash for every player when a wave is cleared ...
	WaveBonusPerWave = 20, -- ... plus this much per wave number (wave 10 pays 100 + 200)

	-- Base
	StartingBaseHealth = 150,

	-- Enemies
	MaxEnemies = 300, -- hard safety cap on simultaneous enemies
	EnemyNetRate = 10, -- batched enemy state updates sent to clients per second
	EnemyFullSyncInterval = 2, -- seconds between full re-syncs (corrects any client drift)

	-- Debug: start at a later wave when play-testing in Studio. Ignored in live servers.
	DebugStartWave = 1,
})
