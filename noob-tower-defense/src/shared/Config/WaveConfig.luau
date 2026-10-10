--!strict
--[[
	WaveConfig
	Waves[i] describes wave i.

	Groups       spawn in parallel. Each group spawns `Count` × `Enemy`, one every
	             `Interval` seconds, starting `Delay` seconds after the wave begins.
	HealthScale  multiplies every enemy's max health this wave (default 1).
	Bonus        overrides the wave-clear cash bonus (default from GameConfig).
	BossWave     tells clients to switch to boss music / show the boss banner.

	The wave ends when every enemy has spawned and none is left alive.
	Enemy names are checked at server start (WaveSpawner:Init), so a typo fails loudly.
]]

export type Group = {
	Enemy: string,
	Count: number,
	Interval: number,
	Delay: number,
}

export type Wave = {
	Groups: { Group },
	HealthScale: number?,
	Bonus: number?,
	BossWave: boolean?,
}

local function group(enemy: string, count: number, interval: number, delay: number?): Group
	return { Enemy = enemy, Count = count, Interval = interval, Delay = delay or 0 }
end

local Waves: { Wave } = {
	-- 1-5: teach the basics
	{ Groups = { group("Infected", 5, 1.6) } },
	{ Groups = { group("Infected", 8, 1.3) } },
	{ Groups = { group("Infected", 8, 1.2), group("Runner", 3, 1.0, 6) } },
	{ Groups = { group("Infected", 10, 1.0), group("Runner", 6, 0.8, 4) } },
	{ Groups = { group("Infected", 8, 1.0), group("Elite", 2, 3.0, 5) } },

	-- 6-9: armour appears, groups overlap
	{ Groups = { group("Runner", 12, 0.6), group("Elite", 3, 2.5, 3) } },
	{ Groups = { group("Infected", 15, 0.8), group("Brute", 1, 1, 8) } },
	{ Groups = { group("Elite", 6, 1.5), group("Runner", 10, 0.5, 6) } },
	{ Groups = { group("Infected", 20, 0.5), group("Brute", 3, 3.0, 5) }, HealthScale = 1.1 },

	-- 10: first boss
	{
		Groups = { group("Infected", 8, 1.0), group("PatientZero", 1, 1, 6) },
		BossWave = true,
		Bonus = 500,
	},

	-- 11-19: mixed pressure, health ramps up
	{ Groups = { group("Runner", 16, 0.4), group("Elite", 5, 1.5, 4) }, HealthScale = 1.15 },
	{ Groups = { group("Brute", 5, 2.5), group("Infected", 20, 0.5, 2) }, HealthScale = 1.2 },
	{ Groups = { group("Elite", 10, 1.0), group("Runner", 15, 0.4, 5) }, HealthScale = 1.25 },
	{ Groups = { group("Brute", 8, 1.8), group("Elite", 8, 1.2, 4) }, HealthScale = 1.3 },
	{
		Groups = { group("Infected", 30, 0.3), group("Runner", 20, 0.3, 6), group("Brute", 4, 2.0, 10) },
		HealthScale = 1.35,
	},
	{ Groups = { group("Elite", 15, 0.8), group("Brute", 6, 1.5, 6) }, HealthScale = 1.45 },
	{ Groups = { group("Runner", 30, 0.25), group("Elite", 12, 0.8, 3) }, HealthScale = 1.55 },
	{ Groups = { group("Brute", 12, 1.2), group("Elite", 12, 0.8, 5) }, HealthScale = 1.65 },
	{
		Groups = { group("Infected", 30, 0.25), group("Elite", 15, 0.6, 4), group("Brute", 10, 1.0, 8) },
		HealthScale = 1.8,
	},

	-- 20: final boss
	{
		Groups = { group("Elite", 10, 0.8), group("InfectedKing", 1, 1, 8), group("Brute", 6, 2.5, 20) },
		BossWave = true,
		HealthScale = 1.2,
		Bonus = 0,
	},
}

return table.freeze(Waves)
