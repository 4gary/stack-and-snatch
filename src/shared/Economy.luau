--[[
	Economy: coin rates, upgrade lookups and the Fair Snatch Range.
	Pure functions, shared by server and client so the HUD always matches.

	coins per second = (sum of creature rates x mutation x trait bonuses)
	                   x height multiplier x (1 + Index bonus) x nap factor
	                   + cushion creatures at their base rate
]]

local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.Creatures)
local Mutations = require(script.Parent.Mutations)

local Economy = {}

local E = Config.Economy

-- Height that counts for the height bonus (Gummy Giraffe counts as 3).
function Economy.effectiveHeight(entries: { any }): number
	local h = 0
	for _, entry in entries do
		local def = Creatures.ById[entry.id]
		h += (def and def.Bonus.HeightLayers) or 1
	end
	return h
end

function Economy.heightMultiplier(entries: { any }): number
	return 1 + E.HeightBonusPerLayer * math.max(0, Economy.effectiveHeight(entries) - 1)
end

-- Coins per second for one creature at position i in the tower.
function Economy.creatureRate(entries: { any }, i: number): number
	local entry = entries[i]
	local def = Creatures.ById[entry.id]
	if not def then
		return 0
	end
	local n = #entries
	local rate = def.Rate * Mutations.multiplier(entry.m)
	if def.Bonus.TopMultiplier and i == n then
		rate *= def.Bonus.TopMultiplier
	end
	if def.Bonus.PerAbove then
		rate *= 1 + def.Bonus.PerAbove * (n - i)
	end
	local adjacent = 0
	local below = entries[i - 1] and Creatures.ById[entries[i - 1].id]
	local above = entries[i + 1] and Creatures.ById[entries[i + 1].id]
	if below and below.Bonus.Adjacent then
		adjacent += below.Bonus.Adjacent
	end
	if above and above.Bonus.Adjacent then
		adjacent += above.Bonus.Adjacent
	end
	return rate * (1 + adjacent)
end

function Economy.towerRate(entries: { any }): number
	local sum = 0
	for i in entries do
		sum += Economy.creatureRate(entries, i)
	end
	return sum * Economy.heightMultiplier(entries)
end

function Economy.cushionRate(cushions: { any }): number
	local sum = 0
	for _, entry in cushions do
		if type(entry) == "table" then
			local def = Creatures.ById[entry.id]
			if def then
				sum += def.Rate * Mutations.multiplier(entry.m) * E.CushionIncomeMultiplier
			end
		end
	end
	return sum
end

function Economy.indexCount(index: { [string]: any }): number
	local count = 0
	for id in index do
		if Creatures.ById[id] then
			count += 1
		end
	end
	return count
end

function Economy.indexBonus(index: { [string]: any }): number
	return E.IndexBonusPerCreature * Economy.indexCount(index)
end

-- Total coins per second for a player's saved data.
function Economy.totalRate(data: any, napping: boolean?): number
	local rate = Economy.towerRate(data.tower) + Economy.cushionRate(data.cushions)
	rate *= 1 + Economy.indexBonus(data.index)
	if napping then
		rate *= E.NapIncomeMultiplier
	end
	return rate
end

-- Upgrades --------------------------------------------------------------------
function Economy.upgradeLevel(data: any, track: string)
	local levels = Config.Upgrades[track].Levels
	local level = math.clamp(data.upgrades[track] or 1, 1, #levels)
	return levels[level], level, #levels
end

function Economy.nextUpgrade(data: any, track: string)
	local levels = Config.Upgrades[track].Levels
	local level = data.upgrades[track] or 1
	return levels[level + 1], level + 1
end

function Economy.glueReduce(data: any): number
	return (Economy.upgradeLevel(data, "Glue")).Reduce
end

function Economy.maxSlots(data: any): number
	return (Economy.upgradeLevel(data, "Base")).Slots
end

function Economy.boxCapacity(data: any): number
	return (Economy.upgradeLevel(data, "Base")).Box
end

-- Fair Snatch Range: which tower heights you are allowed to snatch from.
function Economy.fairRange(myHeight: number): (number, number)
	local fr = Config.Protection.FairRange
	local minH = math.floor(myHeight * fr.MinFraction)
	local maxH = math.max(math.ceil(myHeight * fr.MaxMultiplier), fr.MinCap, myHeight + fr.MaxExtra)
	return minH, maxH
end

function Economy.inFairRange(myHeight: number, targetHeight: number): boolean
	local minH, maxH = Economy.fairRange(myHeight)
	return targetHeight >= minH and targetHeight <= maxH
end

return Economy
