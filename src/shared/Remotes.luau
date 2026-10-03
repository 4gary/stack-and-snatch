--[[
	Remotes: every RemoteEvent / RemoteFunction the game uses, by name.
	The server creates them; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- Client -> server requests (the server validates every one of them).
Remotes.Events = {
	"ClientReady",
	"PlaceHeld", -- (dropServerTime)
	"StoreHeld", -- ()
	"TakeFromBox", -- (uid)
	"TowerAction", -- (action, uid)
	"PickUpGround", -- (uid)
	"BuyConveyor", -- (uid)
	"RequestScoop", -- (uid)
	"ScoopResult", -- (sessionId, markerPosition)
	"RequestSnatch", -- (plotIndex | "practice")
	"SnatchResult", -- (sessionId, success, stats)
	"ActivateShield", -- ()
	"Boop", -- ()
	"BuyUpgrade", -- (track)
	"Emote", -- (index)
	"Tutorial", -- (action)
	"SaveSettings", -- (settings)
	"Dev", -- (action, arg) - only works in Studio
	-- Server -> client
	"State", -- full personal snapshot
	"Tick", -- light per-second update (coins, rate)
	"Notify", -- banner message
	"Dialog", -- tutorial / NPC dialog
	"SnatchStart", -- start the steady-hand minigame
	"ScoopStart", -- start the scoop timing minigame
	"Effect", -- sounds + visual effects for everyone
}

Remotes.Functions = {
	"RedeemCode", -- (code) -> message
}

local FOLDER_NAME = "Remotes"

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.Events do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in Remotes.Functions do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
end

local cache = {}

function Remotes.get(name: string): any
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name, 30)
	assert(remote, "Missing remote " .. name)
	cache[name] = remote
	return remote
end

return Remotes
