--[[
	Mutations: rare visual variants that earn more. Always earned through play,
	never sold. Launch set from the MVP column of the design doc.
]]

local Mutations = {}

Mutations.Order = { "Sprinkled", "Glittery", "GoldenToast" }

Mutations.ById = {
	Sprinkled = {
		Name = "Sprinkled",
		Multiplier = 1.5,
		Color = Color3.fromRGB(255, 120, 190),
		Look = "Covered in rainbow sprinkles",
	},
	Glittery = {
		Name = "Glittery",
		Multiplier = 2,
		Color = Color3.fromRGB(190, 230, 255),
		Look = "Sparkles constantly",
	},
	GoldenToast = {
		Name = "Golden Toast",
		Multiplier = 8,
		Color = Color3.fromRGB(255, 196, 60),
		Look = "Shiny golden crust",
	},
}

function Mutations.multiplier(mutation: string?): number
	if mutation and Mutations.ById[mutation] then
		return Mutations.ById[mutation].Multiplier
	end
	return 1
end

function Mutations.name(mutation: string?): string?
	if mutation and Mutations.ById[mutation] then
		return Mutations.ById[mutation].Name
	end
	return nil
end

return Mutations
