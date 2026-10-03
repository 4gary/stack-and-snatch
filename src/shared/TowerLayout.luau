--[[
	TowerLayout: turns a tower list into world positions.

	Creatures stack straight up; each one is shifted sideways by the offset it
	was dropped at, and offsets accumulate, so a sloppy tower visibly leans.
	Shared so the server's models and the client's ghost preview line up.
]]

local Creatures = require(script.Parent.Creatures)

local TowerLayout = {}

-- Returns an array of bottom-center CFrames (one per entry) and the CFrame of
-- the top surface (where the next creature would sit, before its own offset).
function TowerLayout.layout(entries: { any }, origin: CFrame): ({ CFrame }, CFrame)
	local cframes = table.create(#entries)
	local x, y, z = 0, 0, 0
	for i, entry in entries do
		if i > 1 then
			x += entry.x or 0
			z += entry.z or 0
		end
		cframes[i] = origin * CFrame.new(x, y, z)
		local def = Creatures.ById[entry.id]
		y += def and def.Height or 2
	end
	return cframes, origin * CFrame.new(x, y, z)
end

function TowerLayout.height(entries: { any }): number
	local y = 0
	for _, entry in entries do
		local def = Creatures.ById[entry.id]
		y += def and def.Height or 2
	end
	return y
end

return TowerLayout
