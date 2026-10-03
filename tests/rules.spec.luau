local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.Creatures)
local Rarities = require(script.Parent.Rarities)
local Wobble = require(script.Parent.Wobble)
local Economy = require(script.Parent.Economy)
local Format = require(script.Parent.Format)

-- Roster integrity ---------------------------------------------------------------
check(#Creatures.List == 24, "24 creatures in the launch roster")
local seen = {}
for _, def in Creatures.List do
	check(not seen[def.Id], "unique id " .. def.Id)
	seen[def.Id] = true
	check(Rarities.ById[def.Rarity] ~= nil, def.Id .. " has a known rarity")
	check(Creatures.Shapes[def.Shape] ~= nil, def.Id .. " has a known shape")
	check(def.Rate > 0 and def.Price and def.Price > 0, def.Id .. " has rate and price")
	check(def.Height > 0 and def.Width > 0, def.Id .. " has a size")
	check(type(def.Look) == "string", def.Id .. " has a look recipe")
end
for _, r in Rarities.Order do
	check(Creatures.ByRarity[r] and #Creatures.ByRarity[r] > 0, "at least one creature of rarity " .. r)
end

-- Rates rise with rarity ---------------------------------------------------------
local maxRateByTier = {}
for _, def in Creatures.List do
	local t = Rarities.tier(def.Rarity)
	maxRateByTier[t] = math.max(maxRateByTier[t] or 0, def.Rate)
end
for t = 2, 7 do
	check(maxRateByTier[t] > maxRateByTier[t - 1], "best rate increases at tier " .. t)
end

-- Wobble rules ---------------------------------------------------------------------
local function e(id, x, z)
	return { id = id, x = x or 0, z = z or 0 }
end
local function tower(id, n, x)
	local t = {}
	for i = 1, n do
		table.insert(t, e(id, i > 1 and (x or 0) or 0))
	end
	return t
end

near(Wobble.total({ e("Cubert") }, 0), 0, 1e-9, "a single creature never wobbles")
near(Wobble.total({ e("Cubert"), e("Cubert") }, 0), 1.0 * 1.06, 1e-6, "two centered Cuberts")
check(
	Wobble.total({ e("ConeKitten"), e("Cubert") }, 0) > Wobble.total({ e("Cubert"), e("ConeKitten") }, 0),
	"pointy underneath is worse than pointy on top"
)
check(
	Wobble.total({ e("PebblePenguin"), e("Cubert") }, 0) > Wobble.total({ e("PancakePup"), e("Cubert") }, 0),
	"round underneath is worse than flat underneath"
)
check(
	Wobble.total({ e("Cubert"), e("Cubert", 2, 0) }, 0) > Wobble.total({ e("Cubert"), e("Cubert", 0.5, 0) }, 0),
	"off-center drops wobble more"
)
check(
	Wobble.total({ e("Sockworm"), e("SirWobbles") }, 0) < Wobble.total({ e("Cubert"), e("SirWobbles") }, 0),
	"Sockworm drape glues the next layer"
)
check(
	Wobble.total({ e("PillowPossum"), e("Cubert"), e("Cubert") }, 0) < Wobble.total({ e("Cubert"), e("Cubert"), e("Cubert") }, 0) - 0.5,
	"Pillow Possum halves wobble above"
)
check(Wobble.capacity({ e("WaffleWalrusJr") }) == Config.Wobble.Capacity + 15, "Waffle Walrus widens the base")
check(Wobble.total(tower("Cubert", 30), 0.24) < Wobble.total(tower("Cubert", 30), 0), "glue reduces wobble")

-- Balance sanity: careful stackers get tall, sloppy ones topple sooner.
local function maxStable(id, x, glue)
	local t = {}
	for i = 1, 120 do
		table.insert(t, e(id, i > 1 and x or 0, 0))
		if not Wobble.isStable(t, glue) then
			return i - 1
		end
	end
	return 120
end
local careful = maxStable("Cubert", 0, 0)
local sloppy = maxStable("Cubert", 0, 0) -- placeholder replaced below
local zigzag = {}
for i = 1, 120 do
	local x = (i % 2 == 0) and 1.6 or -1.6
	table.insert(zigzag, e("Cubert", i > 1 and x or 0, 0))
	if not Wobble.isStable(zigzag, 0) then
		sloppy = i - 1
		break
	end
end
print(string.format("  balance: careful Cubert tower tops out at %d, sloppy zigzag at %d, careful+max glue at %d",
	careful, sloppy, maxStable("Cubert", 0, 0.32)))
check(careful >= 25, "careful stacking reaches at least 25 without glue")
check(sloppy < careful, "sloppy stacking topples sooner")
check(sloppy >= 6, "even sloppy stacking reaches 6")
check(maxStable("Cubert", 0, 0.32) >= 50, "careful + max glue reaches 50 (max base slots)")
check(maxStable("Cubert", 0.4, 0) < careful, "a steady lean topples sooner than centered")

-- The placement swing
local x0, z0 = Wobble.swingOffset(0, 3)
near(x0, 0, 1e-9, "swing is centered at t=0")
near(z0, 0, 1e-9, "swing z is centered at t=0")
local px, pz = Wobble.swingOffset(Wobble.swingPeriod(3) / 4, 3)
near(px, Config.Pendulum.Amplitude, 1e-6, "swing reaches full amplitude at quarter period")
local fx, fz = Wobble.swingOffset(123.4, 0)
check(fx == 0 and fz == 0, "first creature is never offset")
check(Wobble.swingPeriod(100) == Config.Pendulum.MinPeriod, "swing period floors at MinPeriod")

-- Economy ----------------------------------------------------------------------------
near(Economy.towerRate({ e("PancakePup") }), 1, 1e-9, "single pancake pup earns 1/s")
near(Economy.towerRate({ e("PancakePup"), e("PancakePup") }), 2 * 1.1, 1e-9, "height bonus applies")
near(
	Economy.towerRate({ e("Cubert"), e("ConeKitten") }),
	(2 + 22 * 2.5) * 1.1,
	1e-9,
	"Cone Kitten earns x2.5 on top"
)
near(
	Economy.towerRate({ e("ConeKitten"), e("Cubert") }),
	(22 + 2) * 1.1,
	1e-9,
	"Cone Kitten earns normally when not on top"
)
near(
	Economy.towerRate({ e("Cubert"), e("MuffinMole"), e("Cubert") }),
	(2 * 1.1 + 6 + 2 * 1.1) * 1.2,
	1e-9,
	"Muffin Mole boosts its neighbors"
)
check(Economy.effectiveHeight({ e("GummyGiraffe") }) == 3, "Gummy Giraffe counts as 3 layers")
near(Economy.towerRate({ e("Cubert"), e("KazooKoala"), e("Cubert"), e("Cubert") }),
	(2 + 900 * 1.2 + 2 + 2) * 1.3, 1e-6, "Kazoo Koala earns more with creatures above")
local data = {
	tower = { e("Cubert"), e("Cubert") },
	cushions = { { id = "PancakePup" } },
	index = { Cubert = { base = true }, PancakePup = { base = true } },
	upgrades = { Glue = 3, Base = 1, Shield = 1 },
}
near(Economy.totalRate(data), ((2 + 2) * 1.1 + 1) * 1.04, 1e-9, "total rate with cushion and index bonus")
near(Economy.totalRate(data, true), ((2 + 2) * 1.1 + 1) * 1.04 * 0.5, 1e-9, "napping halves income")
near(Economy.glueReduce(data), 0.16, 1e-9, "glue level 3")
check(Economy.maxSlots(data) == 10, "base level 1 has 10 slots")
local nextUp, nextLevel = Economy.nextUpgrade(data, "Glue")
check(nextUp.Cost == 30000 and nextLevel == 4, "next glue upgrade")
data.upgrades.Glue = 5
check(Economy.nextUpgrade(data, "Glue") == nil, "max level has no next upgrade")

local lo, hi = Economy.fairRange(0)
check(lo == 0 and hi == 6, "new players can snatch towers up to 6 tall")
lo, hi = Economy.fairRange(40)
check(lo == 20 and hi == 80, "fair range is half to double")
check(not Economy.inFairRange(40, 5), "mega towers can't snatch tiny towers")
check(Economy.inFairRange(3, 8), "small towers can reach slightly bigger ones")

-- Format -------------------------------------------------------------------------------
check(Format.number(0) == "0", "format 0")
check(Format.number(999) == "999", "format 999")
check(Format.number(1234) == "1.2K", "format 1.2K got " .. Format.number(1234))
check(Format.number(1999999) == "1.9M", "format rounds down 1.9M got " .. Format.number(1999999))
check(Format.number(250000) == "250K", "format 250K got " .. Format.number(250000))
check(Format.number(3.5) == "3.5", "format small decimals")
check(Format.number(4.2e9) == "4.2B", "format billions")
check(Format.time(125) == "2:05", "format time")
check(Format.time(3725) == "1:02:05", "format hours")

-- Rarity roll
local rng = Random.new(42)
local counts = {}
for _ = 1, 2000 do
	local r = Rarities.roll(Config.Conveyor.Weights, rng)
	counts[r] = (counts[r] or 0) + 1
end
check((counts.Common or 0) > (counts.Uncommon or 0), "commons are most common")
check((counts.Uncommon or 0) > (counts.Rare or 0), "uncommons beat rares")
