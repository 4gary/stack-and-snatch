--[[
	Social: friends (only the owner and their friends can boop a carrier) and
	quick emotes, so the game is fully playable without chat.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(script.Parent.Parent.Util)

local Social = {}

local S
local emoteTimes = {}

local function checkFriends(a: Player, b: Player): boolean
	if a.UserId <= 0 or b.UserId <= 0 then
		return false -- Studio test players
	end
	local ok, result = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	if not ok then
		ok, result = pcall(function()
			return (a :: any):IsFriendsWith(b.UserId)
		end)
	end
	return ok and result == true
end

function Social.onOwnerAdded(owner)
	if not owner.player then
		return
	end
	for _, other in S.Plots.all() do
		if other ~= owner and other.player then
			task.spawn(function()
				if checkFriends(owner.player, other.player) then
					owner.friends[other.userId] = true
					other.friends[owner.userId] = true
				end
			end)
		end
	end
end

function Social.areFriends(a, b): boolean
	return a.friends[b.userId] == true or b.friends[a.userId] == true
end

function Social.init(services)
	S = services
	Remotes.get("Emote").OnServerEvent:Connect(function(player, index)
		local text = type(index) == "number" and Config.Emotes[index]
		if not text or not Util.throttle(emoteTimes, player, Config.EmoteCooldown) then
			return
		end
		S.Sync.effectAll({ kind = "Emote", userId = player.UserId, text = text })
	end)
	Players.PlayerRemoving:Connect(function(player)
		emoteTimes[player] = nil
	end)
end

return Social
