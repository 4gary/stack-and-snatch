--[[
	Progress: the Index (creature book), height ribbons and starter quests.

	The Index remembers every creature + mutation you have ever owned, even if it
	gets snatched later, so losing a creature never undoes Index progress.
	Each creature in your Index adds a small permanent coin bonus.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)

local Progress = {}

local S

function Progress.recordIndex(owner, entry)
	local def = Creatures.ById[entry.id]
	if not def then
		return
	end
	local index = owner.data.index
	local isNewCreature = index[entry.id] == nil
	index[entry.id] = index[entry.id] or {}
	local page = index[entry.id]
	local variant = entry.m or "base"
	local isNewVariant = not page[variant]
	page[variant] = true
	if isNewCreature then
		S.Sync.notify(
			owner,
			"New Index entry: " .. def.Name .. "! (+" .. math.floor(Config.Economy.IndexBonusPerCreature * 100) .. "% coins forever)",
			"good",
			"Professor Puddlewick"
		)
	elseif isNewVariant and entry.m then
		S.Sync.notify(owner, "New Index variant: " .. (Mutations.name(entry.m) or entry.m) .. " " .. def.Name .. "!", "good", "Professor Puddlewick")
	end
	S.Sync.markDirty(owner)
end

function Progress.completeQuest(owner, questId: string)
	local data = owner.data
	if data.quests[questId] then
		return
	end
	for _, quest in Config.Quests do
		if quest.Id == questId then
			data.quests[questId] = true
			data.coins += quest.Reward
			S.Sync.notify(owner, "Quest complete: " .. quest.Text .. "! +" .. Format.number(quest.Reward) .. " coins", "good", "Mayor Marshmallow")
			S.Sync.effect(owner, { kind = "Quest" })
			S.Sync.markDirty(owner)
			return
		end
	end
end

-- Called whenever a creature comes into your hands (bought, scooped, snatched).
function Progress.onCreatureGained(owner, entry, source: string?)
	Progress.recordIndex(owner, entry)
	local def = Creatures.ById[entry.id]
	if def and Rarities.tier(def.Rarity) >= Rarities.tier("Rare") and source ~= "box" then
		Progress.completeQuest(owner, "catchRare")
	end
end

function Progress.onTowerChanged(owner)
	local data = owner.data
	local height = #data.tower
	if height >= 5 then
		Progress.completeQuest(owner, "reach5")
	end
	for _, h in Config.RibbonHeights do
		local key = tostring(h)
		if height >= h and not data.ribbons[key] then
			data.ribbons[key] = true
			S.Sync.notify(owner, "By the power of fluff, I declare your tower " .. h .. " creatures tall! Have a ribbon!", "rare", "Mayor Marshmallow")
			S.Sync.effectAll({ kind = "Ribbon", key = owner.key, plot = owner.plot and owner.plot.index, height = h })
		end
	end
end

-- Mayor Marshmallow's "Tallest Towers" board in the plaza.
local function updateBoard()
	local rows = {}
	for _, owner in S.Plots.all() do
		if owner.plot then
			table.insert(rows, { name = owner.name, height = #owner.data.tower })
		end
	end
	table.sort(rows, function(a, b)
		return a.height > b.height
	end)
	local lines = { "🏆 Tallest Towers 🏆" }
	for i = 1, math.min(5, #rows) do
		table.insert(lines, string.format("%d. %s - %d tall", i, rows[i].name, rows[i].height))
	end
	if #rows == 0 then
		table.insert(lines, "Be the first to stack!")
	end
	S.Map.tallestLabel.Text = table.concat(lines, "\n")
end

function Progress.init(services)
	S = services
end

function Progress.start()
	while true do
		pcall(updateBoard)
		task.wait(5)
	end
end

return Progress
