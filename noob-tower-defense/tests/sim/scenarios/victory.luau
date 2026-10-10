step(0.1)
check(phase() == "Lobby" and timeLeft() and timeLeft() > 15, "lobby countdown running")
Remotes.VoteReady.OnServerEvent:Fire(alice)
step(0.3)
check(timeLeft() <= 3.01, "all ready shortens countdown to 3s: " .. tostring(timeLeft()))
step(5, function() return phase() == "Intermission" end)
check(phase() == "Intermission", "match starts")
check(alice:GetAttribute("Cash") == 600 and state:GetAttribute("BaseHealth") == 150, "cash 600, base 150")
Remotes.VoteSkip.OnServerEvent:Fire(alice)
step(0.5)
check(phase() == "Wave" and state:GetAttribute("Wave") == 1, "skip vote starts wave 1")
step(0.1)
check(state:GetAttribute("EnemiesLeft") == 5, "wave 1 enemies left = 5: " .. tostring(state:GetAttribute("EnemiesLeft")))

-- Fake tower: 800 DPS on the enemy furthest along, plus slows/burns on others.
local kills = 0
Enemy.Died:Connect(function() kills += 1 end)
heartbeat:Connect(function(dt)
	local list = Enemy:GetAll()
	table.sort(list, function(a, b) return a.Distance > b.Distance end)
	if list[1] then Enemy:Damage(list[1], 800 * dt, alice) end
	if list[2] then Enemy:ApplyEffect(list[2], { Kind = "Slow", Magnitude = 0.2, Duration = 0.5 }) end
	if list[3] then Enemy:ApplyEffect(list[3], { Kind = "Burn", Magnitude = 1, Duration = 2, Source = alice }) end
end)
local maxLeft = 0
state:GetAttributeChangedSignal("EnemiesLeft"):Connect(function() maxLeft = math.max(maxLeft, state:GetAttribute("EnemiesLeft")) end)
-- auto-skip each intermission
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if phase() == "Intermission" then task.delay(1, function() Remotes.VoteSkip.OnServerEvent:Fire(alice) end) end
end)
step(5000, function() return phase() == "Victory" or phase() == "GameOver" end)
check(phase() == "Victory", "victory after all waves: " .. tostring(phase()))
check(state:GetAttribute("Wave") == 20, "reached wave 20")
check(remoteCount("BossPhase") == 7, "both bosses ran all minion phases: " .. remoteCount("BossPhase"))
check(remoteCount("WaveCleared") == 20, "20 wave clears")
check(remoteCount("MatchEnded") == 1, "one MatchEnded")
check(Enemy:GetCount() == 0, "field empty")
print("kills", kills, "maxLeft", maxLeft, "base", state:GetAttribute("BaseHealth"), "cash", alice:GetAttribute("Cash"), "time", now)
check(alice:GetAttribute("Cash") > 5000, "cash accumulated")
step(13)
check(phase() == "Lobby", "back to lobby after end screen")
check(state:GetAttribute("EnemiesLeft") == 0 and state:GetAttribute("Wave") == 0, "lobby state reset")
print("phase log", table.concat(phaseLog, ", "):sub(1, 400))
