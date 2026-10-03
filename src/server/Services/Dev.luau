--[[
	Dev: Studio-only test tools (the client shows a Dev panel in Studio).
	Every action is ignored outside Studio.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)
local Wobble = require(Shared.Wobble)
local Economy = require(Shared.Economy)

local Dev = {}

local S
local rng = Random.new()

local function stableTower(count: number, pool: { string })
	local entries = {}
	for _ = 1, count do
		local entry = { u = S.Stacking.newEntry("Cubert").u, id = pool[rng:NextInteger(1, #pool)], x = 0, z = 0 }
		table.insert(entries, entry)
		if not Wobble.isStable(entries, 0.16) then
			table.remove(entries)
			entry.id = "Cubert"
			table.insert(entries, entry)
		end
	end
	return entries
end

local ACTIONS = {}

function ACTIONS.coins(owner, amount)
	owner.data.coins += math.clamp(tonumber(amount) or 1000, 0, 1e12)
	S.Sync.markDirty(owner)
end

function ACTIONS.give(owner, creatureId)
	local mutation = nil
	if type(creatureId) == "table" then
		creatureId, mutation = creatureId[1], creatureId[2]
	end
	if not Creatures.ById[creatureId] then
		creatureId = Creatures.List[rng:NextInteger(1, #Creatures.List)].Id
	end
	if not S.Stacking.give(owner, S.Stacking.newEntry(creatureId, mutation), "dev") then
		S.Sync.notify(owner, "Hands full - Box or stack what you're holding first.", "info")
	end
end

function ACTIONS.fill(owner)
	local data = owner.data
	local slots = Economy.maxSlots(data)
	local pool = { "Cubert", "PancakePup", "Hamwich", "MuffinMole", "Toastie" }
	data.tower = stableTower(math.max(0, slots - #data.tower) + #data.tower, pool)
	while #data.tower > slots do
		table.remove(data.tower)
	end
	if owner.host then
		S.Towers.refresh(owner.host)
	end
	S.Progress.onTowerChanged(owner)
	S.Plots.refreshPlot(owner)
	S.Plots.updateLeaderstats(owner)
	S.Sync.markDirty(owner)
end

function ACTIONS.bot(owner, size)
	local count = math.clamp(tonumber(size) or 6, 1, 30)
	local pool = { "Cubert", "PancakePup", "Hamwich", "Blobby", "BouncyBean", "SirWobbles", "JellybellyJelly" }
	local bot = S.Plots.addBot(stableTower(count, pool))
	if bot then
		S.Sync.notify(owner, bot.name .. " built a " .. count .. "-tall tower on pad " .. bot.plot.index .. ". Go snatch from it!", "good")
	else
		S.Sync.notify(owner, "No free base pads for a bot.", "warn")
	end
end

function ACTIONS.clearBots(owner)
	for _, other in S.Plots.all() do
		if other.isBot then
			S.Plots.removeOwner(other)
		end
	end
	S.Sync.notify(owner, "Bots cleared.", "info")
end

function ACTIONS.noProtect(owner)
	owner.devNoProtection = not owner.devNoProtection
	owner.moved = true
	S.Sync.notify(owner, owner.devNoProtection and "Your protections are OFF (others can snatch from you, no Fair Range)." or "Your protections are back ON.", "info")
	S.Sync.markDirty(owner)
end

function ACTIONS.weather()
	S.Weather.begin()
end

function ACTIONS.conveyor(_, rarity)
	S.Conveyor.spawn(type(rarity) == "string" and rarity or "Legendary")
end

function ACTIONS.wild(_, creatureId)
	S.Meadows.spawn(type(creatureId) == "string" and creatureId or nil)
end

function ACTIONS.shieldReset(owner)
	owner.shieldUntil = 0
	owner.shieldReadyAt = 0
	S.Sync.markDirty(owner)
end

function ACTIONS.ticket(owner)
	for _, other in S.Plots.all() do
		if other ~= owner and other.plot then
			owner.ticket = { targetKey = other.key, targetName = other.name, expires = S.Sync.now() + 300 }
			S.Sync.notify(owner, "Dev: Bounce-Back Ticket for " .. other.name .. "'s tower.", "info")
			S.Sync.markDirty(owner)
			return
		end
	end
end

function ACTIONS.skipTutorial(owner)
	S.Onboarding.skip(owner)
end

function ACTIONS.resetData(owner)
	local fresh = S.Data.default()
	for k in owner.data do
		owner.data[k] = nil
	end
	for k, v in fresh do
		owner.data[k] = v
	end
	S.Stacking.detachHeld(owner)
	if owner.host then
		S.Towers.refresh(owner.host)
	end
	S.Towers.renderCushions(owner)
	S.Towers.renderGround(owner)
	S.Plots.refreshPlot(owner)
	S.Plots.updateLeaderstats(owner)
	S.Sync.markDirty(owner)
	S.Onboarding.onOwnerAdded(owner)
end

function ACTIONS.toppleMe(owner)
	if owner.host and S.Towers.topple(owner.host) then
		S.Sync.effectAll({ kind = "Topple", key = owner.key, plot = owner.plot.index })
	end
end

function Dev.init(services)
	S = services
	Remotes.get("Dev").OnServerEvent:Connect(function(player, action, arg)
		if not RunService:IsStudio() then
			return
		end
		local owner = S.Plots.get(player)
		local fn = type(action) == "string" and ACTIONS[action]
		if owner and fn then
			local ok, err = pcall(fn, owner, arg)
			if not ok then
				warn("[Dev]", action, err)
			end
		end
	end)
end

return Dev
