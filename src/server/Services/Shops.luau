--[[
	Shops: Grandma Gloop (Sticky Jam), Bricklebee (Base), Lou the Locksmith
	(Bubble Shield). Everything is bought with Giggle Coins earned in play -
	protection, glue and snatching power are never sold for Robux.
	Also handles codes (small coin rewards only, never creatures).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Shops = {}

local S

function Shops.buy(owner, track: any)
	if type(track) ~= "string" or not Config.Upgrades[track] then
		return
	end
	local data = owner.data
	local nextLevel, levelNumber = Economy.nextUpgrade(data, track)
	local info = Config.Upgrades[track]
	if not nextLevel then
		S.Sync.notify(owner, info.Title .. " is already maxed out!", "info", info.Npc)
		return
	end
	if data.coins < nextLevel.Cost then
		S.Sync.notify(owner, "You need " .. Format.number(nextLevel.Cost) .. " Giggle Coins for that.", "info", info.Npc)
		return
	end
	data.coins -= nextLevel.Cost
	data.upgrades[track] = levelNumber
	local lines = {
		Glue = "A little jam fixes everything, sweetie! Sticky Jam level " .. levelNumber .. "!",
		Base = "Bzzt! Let's build it bigger! Base level " .. levelNumber .. "!",
		Shield = "Slow and steady... keeps the tower steady. Shield level " .. levelNumber .. ".",
	}
	S.Sync.notify(owner, lines[track] or (info.Title .. " upgraded!"), "good", info.Npc)
	S.Sync.effect(owner, { kind = "Upgrade", track = track })
	if owner.host then
		S.Towers.refresh(owner.host)
	end
	S.Plots.refreshPlot(owner)
	S.Sync.markDirty(owner)
end

function Shops.redeem(owner, code: any): string
	if type(code) ~= "string" then
		return "Hmm, that's not a code."
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		return "That code didn't work. Check the spelling!"
	end
	if owner.data.codes[code] then
		return "You already used that code!"
	end
	owner.data.codes[code] = true
	owner.data.coins += reward.Coins or 0
	S.Sync.markDirty(owner)
	return "Yay! +" .. Format.number(reward.Coins or 0) .. " Giggle Coins!"
end

function Shops.init(services)
	S = services
	Remotes.get("BuyUpgrade").OnServerEvent:Connect(function(player, track)
		local owner = S.Plots.get(player)
		if owner then
			Shops.buy(owner, track)
		end
	end)
	Remotes.get("RedeemCode").OnServerInvoke = function(player, code)
		local owner = S.Plots.get(player)
		if not owner then
			return "Still loading, try again in a moment!"
		end
		return Shops.redeem(owner, code)
	end
end

return Shops
