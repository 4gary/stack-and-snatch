--[[
	Rarities: the seven tiers from the design doc.
	Each tier also has a shape badge so rarity never relies on color alone.
]]

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.ById = {
	Common = {
		Tier = 1,
		Name = "Common",
		Color = Color3.fromRGB(235, 235, 235),
		Badge = "●",
	},
	Uncommon = {
		Tier = 2,
		Name = "Uncommon",
		Color = Color3.fromRGB(110, 220, 120),
		Badge = "▲",
	},
	Rare = {
		Tier = 3,
		Name = "Rare",
		Color = Color3.fromRGB(80, 160, 255),
		Badge = "■",
		Announce = true,
	},
	Epic = {
		Tier = 4,
		Name = "Epic",
		Color = Color3.fromRGB(180, 100, 255),
		Badge = "◆",
		Announce = true,
	},
	Legendary = {
		Tier = 5,
		Name = "Legendary",
		Color = Color3.fromRGB(255, 200, 40),
		Badge = "★",
		Announce = true,
		BigAnnounce = true,
	},
	Mythic = {
		Tier = 6,
		Name = "Mythic",
		Color = Color3.fromRGB(255, 110, 200),
		Badge = "✦",
		Announce = true,
		BigAnnounce = true,
	},
	Secret = {
		Tier = 7,
		Name = "Wobbly Wonder",
		Color = Color3.fromRGB(150, 255, 245),
		Badge = "❖",
		Announce = true,
		BigAnnounce = true,
	},
}

function Rarities.get(id: string)
	return Rarities.ById[id] or Rarities.ById.Common
end

function Rarities.tier(id: string): number
	return Rarities.get(id).Tier
end

-- Pick a rarity id from a weights table such as Config.Conveyor.Weights.
function Rarities.roll(weights: { [string]: number }, rng: Random): string
	local total = 0
	for _, id in Rarities.Order do
		total += weights[id] or 0
	end
	local pick = rng:NextNumber() * total
	for _, id in Rarities.Order do
		local w = weights[id] or 0
		if w > 0 then
			if pick < w then
				return id
			end
			pick -= w
		end
	end
	return "Common"
end

return Rarities
