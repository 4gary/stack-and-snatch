--[[
	Wobble: the stacking rules. Pure functions, shared by server and client.

	"Rules decide, animation shows" (design doc 4.2 / 5.2): the tower is an
	ordered list of creatures, bottom first. Stability is a score built from
	simple, predictable rules, so the same placement always gives the same result:

	  layer wobble = (what's underneath + what's on top + the creature's own wobble
	                  + how far off-center you dropped it + how far the stack leans)
	                 x special pairings (sock drape, doughnut ring, floating bunny)
	                 x squishy absorption from the creatures below
	                 x a little extra for every layer of height

	  tower wobble = sum of layer wobbles x (1 - Sticky Jam reduction)

	The tower topples when its wobble goes above its capacity.

	Tower entries look like { u = uid, id = creatureId, m = mutation?, x = offX, z = offZ }.
]]

local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.Creatures)

local Wobble = {}

local W = Config.Wobble
local P = Config.Pendulum

local function offsetPenalty(ox: number, oz: number): number
	local mag = math.sqrt(ox * ox + oz * oz)
	local t = math.min(1, mag / P.Amplitude)
	return W.OffsetPenaltyMax * t * t
end

-- Wobble contributed by each layer. Returns (layers, total before glue).
function Wobble.layers(entries: { any })
	local result = table.create(#entries, 0)
	local absorb = 1
	local leanX, leanZ = 0, 0
	local total = 0
	for i, entry in entries do
		local def = Creatures.ById[entry.id]
		-- The bottom creature always sits centered on the plate.
		local ox, oz = 0, 0
		if i > 1 then
			ox, oz = entry.x or 0, entry.z or 0
		end
		leanX += ox
		leanZ += oz
		local w = 0
		if def and i > 1 then
			local below = Creatures.ById[entries[i - 1].id]
			local belowBase = 1
			local belowFactor = 1
			if below then
				belowBase = below.Wobble.Below or W.BelowByShape[below.Shape] or 1
				belowFactor = below.Wobble.NextLayerFactor or 1
			end
			local lean = math.sqrt(leanX * leanX + leanZ * leanZ)
			w = belowBase
				+ (W.AboveByShape[def.Shape] or 0)
				+ (def.Wobble.Self or 0)
				+ offsetPenalty(ox, oz)
				+ W.LeanPenaltyPerStud * lean
			w *= belowFactor * (def.Wobble.OwnLayerFactor or 1)
			w *= math.max(W.MinAbsorbFactor, absorb)
			w *= 1 + W.HeightGrowth * i
			w = math.max(0, w)
		end
		if def then
			absorb *= 1 - (def.Wobble.Absorb or 0)
		end
		result[i] = w
		total += w
	end
	return result, total
end

-- How much wobble the tower can take before toppling.
function Wobble.capacity(entries: { any }): number
	local cap = W.Capacity
	local bottom = entries[1] and Creatures.ById[entries[1].id]
	if bottom and bottom.Wobble.BottomCapacity then
		cap += bottom.Wobble.BottomCapacity
	end
	return cap
end

-- Total wobble score after Sticky Jam.
function Wobble.total(entries: { any }, glueReduce: number): number
	local _, total = Wobble.layers(entries)
	return total * (1 - (glueReduce or 0))
end

-- 0 = rock steady, 1 = about to topple.
function Wobble.ratio(entries: { any }, glueReduce: number): number
	if #entries <= 1 then
		return 0
	end
	return Wobble.total(entries, glueReduce) / Wobble.capacity(entries)
end

function Wobble.isStable(entries: { any }, glueReduce: number): boolean
	return Wobble.total(entries, glueReduce) <= Wobble.capacity(entries)
end

-- The placement swing --------------------------------------------------------
-- The ghost creature sways in a figure-8 above the tower. Both sides compute it
-- from server time, so the server knows exactly where a drop at time t lands.
function Wobble.swingPeriod(layerCount: number): number
	return math.max(P.MinPeriod, P.BasePeriod - P.PeriodShrinkPerLayer * layerCount)
end

function Wobble.swingOffset(serverTime: number, layerCount: number): (number, number)
	if layerCount <= 0 then
		return 0, 0 -- the first creature always sits neatly on the plate
	end
	local theta = 2 * math.pi * (serverTime / Wobble.swingPeriod(layerCount))
	local x = P.Amplitude * math.sin(theta)
	local z = P.Amplitude * 0.45 * math.sin(2 * theta)
	return x, z
end

-- Round offsets so they save compactly and both sides agree exactly.
function Wobble.roundOffset(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

-- Copy of `entries` with `candidate` added on top.
function Wobble.withTop(entries: { any }, candidate: any): { any }
	local copy = table.clone(entries)
	table.insert(copy, candidate)
	return copy
end

return Wobble
