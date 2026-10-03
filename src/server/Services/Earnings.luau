--[[
	Earnings: Giggle Coins every second (design doc 4.1 "Earn").

	Taller towers earn more; nappers earn half; a toppling tower pauses for a
	few seconds. Coins are added automatically - no collecting needed.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)

local Earnings = {}

local S

local function tick()
	for _, owner in S.Plots.all() do
		if owner.player and owner.plot then
			local data = owner.data
			local rate = Economy.totalRate(data, owner.napping)
			if owner.host and owner.host.toppling then
				rate = 0
			end
			data.coins += rate * Config.Economy.TickSeconds
			data.playtime += Config.Economy.TickSeconds
			S.Plots.updateLeaderstats(owner)
			S.Sync.tick(owner, rate)
		end
	end
end

function Earnings.init(services)
	S = services
end

function Earnings.start()
	while true do
		task.wait(Config.Economy.TickSeconds)
		local ok, err = pcall(tick)
		if not ok then
			warn("[Earnings]", err)
		end
	end
end

return Earnings
