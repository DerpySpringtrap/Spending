--!strict
--[[
	EnemyConfig
	One entry per enemy type. Shared so the client knows display names, model
	names and colours without asking the server.

	MaxHealth     hit points (before a wave's HealthScale)
	Speed         studs per second along the path
	Armor         0..0.9, fraction of incoming damage ignored (armor-piercing attacks skip it)
	Reward        cash per kill
	LeakDamage    base health lost if it reaches the end of the path
	Model         ReplicatedStorage.Assets.Enemies.<Model>; a placeholder is built if it is missing
	Scale         placeholder size multiplier (and a hint for your real model's size)
	Immune        status effects it ignores, e.g. { Stun = true }
	IsBoss        boss health bar, boss music, roar on spawn
	Minions       for bosses: when health falls to `At` (fraction of max), spawn `Count` × `Enemy`
]]

export type MinionPhase = {
	At: number,
	Enemy: string,
	Count: number,
}

export type EnemyDef = {
	DisplayName: string,
	MaxHealth: number,
	Speed: number,
	Armor: number,
	Reward: number,
	LeakDamage: number,
	Model: string,
	Scale: number,
	PlaceholderColor: Color3,
	Immune: { [string]: boolean }?,
	IsBoss: boolean?,
	Minions: { MinionPhase }?,
}

local EnemyConfig: { [string]: EnemyDef } = {
	Infected = {
		DisplayName = "Infected Noob",
		MaxHealth = 6,
		Speed = 6,
		Armor = 0,
		Reward = 6,
		LeakDamage = 5,
		Model = "InfectedNoob",
		Scale = 1,
		PlaceholderColor = Color3.fromRGB(110, 170, 70),
	},

	Runner = {
		DisplayName = "Runner Noob",
		MaxHealth = 4,
		Speed = 12,
		Armor = 0,
		Reward = 5,
		LeakDamage = 4,
		Model = "RunnerNoob",
		Scale = 0.85,
		PlaceholderColor = Color3.fromRGB(230, 200, 60),
	},

	Elite = {
		DisplayName = "Elite Infected",
		MaxHealth = 25,
		Speed = 7,
		Armor = 0.15,
		Reward = 14,
		LeakDamage = 12,
		Model = "EliteInfected",
		Scale = 1.1,
		PlaceholderColor = Color3.fromRGB(150, 70, 190),
	},

	Brute = {
		DisplayName = "Infected Brute",
		MaxHealth = 60,
		Speed = 3.5,
		Armor = 0.3,
		Reward = 25,
		LeakDamage = 25,
		Model = "InfectedBrute",
		Scale = 1.6,
		PlaceholderColor = Color3.fromRGB(70, 110, 50),
		Immune = { Stun = true },
	},

	PatientZero = {
		DisplayName = "Patient Zero",
		MaxHealth = 2500,
		Speed = 2.5,
		Armor = 0.15,
		Reward = 400,
		LeakDamage = 9999,
		Model = "PatientZero",
		Scale = 3,
		PlaceholderColor = Color3.fromRGB(200, 40, 40),
		Immune = { Stun = true },
		IsBoss = true,
		Minions = {
			{ At = 0.75, Enemy = "Runner", Count = 4 },
			{ At = 0.5, Enemy = "Infected", Count = 6 },
			{ At = 0.25, Enemy = "Elite", Count = 3 },
		},
	},

	InfectedKing = {
		DisplayName = "The Infected King",
		MaxHealth = 9000,
		Speed = 2,
		Armor = 0.25,
		Reward = 1000,
		LeakDamage = 9999,
		Model = "InfectedKing",
		Scale = 4,
		PlaceholderColor = Color3.fromRGB(90, 0, 20),
		Immune = { Stun = true, Slow = true },
		IsBoss = true,
		Minions = {
			{ At = 0.8, Enemy = "Elite", Count = 4 },
			{ At = 0.6, Enemy = "Brute", Count = 2 },
			{ At = 0.4, Enemy = "Runner", Count = 10 },
			{ At = 0.2, Enemy = "Brute", Count = 3 },
		},
	},
}

return table.freeze(EnemyConfig)
