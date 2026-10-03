--[[
	Practice: Sneaky Pete's practice tower in the plaza. Snatch from it as much
	as you like; the creatures always hop right back. Used by the tutorial.
]]

local Practice = {}

local S

local ENTRIES = {
	{ u = "practice1", id = "PancakePup", x = 0, z = 0 },
	{ u = "practice2", id = "Cubert", x = 0.3, z = 0 },
	{ u = "practice3", id = "Blobby", x = -0.2, z = 0.1 },
	{ u = "practice4", id = "Toastie", x = 0.2, z = 0 },
	{ u = "practice5", id = "BouncyBean", x = -0.1, z = 0 },
}

function Practice.init(services)
	S = services
	Practice.host = S.Towers.newHost({
		key = "practice",
		origin = S.Map.practice.origin,
		folder = S.Map.practice.folder,
		attributeTarget = S.Map.practice.model,
		getEntries = function()
			return ENTRIES
		end,
		getGlue = function()
			return 0
		end,
	})
	S.Towers.refresh(Practice.host)
end

-- Pete knocks it over on purpose to show that nothing is ever lost.
function Practice.demoTopple()
	if S.Towers.topple(Practice.host) then
		S.Sync.effectAll({ kind = "Topple", key = "practice", practice = true })
	end
end

return Practice
