--[[
	Towers: the creature models standing on each base pad.

	A "host" is anything with a tower: a player's base pad or Sneaky Pete's
	practice tower. The tower itself is just the ordered list in the saved data;
	this service keeps the models in sync with that list.

	Wobble is decided by rules (Wobble.luau). Real physics only runs during a
	topple, for the fun "sproing", and then every creature snaps back into place
	(design doc 5.2 #3). Clients add the jiggle animation on top.
]]

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModel = require(Shared.CreatureModel)
local TowerLayout = require(Shared.TowerLayout)
local Wobble = require(Shared.Wobble)

local Towers = {}

local S
local rng = Random.new()

function Towers.newHost(params)
	return {
		key = params.key,
		origin = params.origin,
		folder = params.folder,
		attributeTarget = params.attributeTarget,
		getEntries = params.getEntries,
		getGlue = params.getGlue,
		models = {},
		toppling = false,
		destroyed = false,
	}
end

function Towers.destroyHost(host)
	host.destroyed = true
	for _, model in host.models do
		model:Destroy()
	end
	host.models = {}
end

local function setAttributes(host)
	local target = host.attributeTarget
	if not target then
		return
	end
	local entries = host.getEntries()
	target:SetAttribute("Wobble", Wobble.ratio(entries, host.getGlue()))
	target:SetAttribute("TowerHeight", TowerLayout.height(entries))
	target:SetAttribute("Height", #entries)
end

-- Make the models match the tower list (creates, moves and removes models).
function Towers.refresh(host)
	if host.destroyed then
		return
	end
	if host.toppling then
		host.pendingRefresh = true
		return
	end
	local entries = host.getEntries()
	local cframes = TowerLayout.layout(entries, host.origin)
	local keep = {}
	for i, entry in entries do
		keep[entry.u] = true
		local model = host.models[entry.u]
		if model and (model.Parent ~= host.folder or model:GetAttribute("Mutation") ~= (entry.m or "")) then
			model:Destroy()
			model = nil
		end
		if not model then
			model = CreatureModel.build(entry.id, entry.m)
			if model then
				model.Name = entry.u
				model:SetAttribute("Uid", entry.u)
				model:PivotTo(cframes[i])
				model.Parent = host.folder
				host.models[entry.u] = model
			end
		else
			model:PivotTo(cframes[i])
		end
		if model then
			model:SetAttribute("Layer", i)
			model:SetAttribute("BasePos", cframes[i].Position)
		end
	end
	for uid, model in host.models do
		if not keep[uid] then
			model:Destroy()
			host.models[uid] = nil
		end
	end
	setAttributes(host)
end

-- World position of the top of the tower (where the next creature goes).
function Towers.topHeight(host): number
	return TowerLayout.height(host.getEntries())
end

-- Sproing! Creatures bounce off with real physics, then hop back in order.
function Towers.topple(host, onDone: (() -> ())?)
	if host.toppling or host.destroyed then
		return false
	end
	host.toppling = true
	if host.attributeTarget then
		host.attributeTarget:SetAttribute("Toppling", true)
	end
	for _, model in host.models do
		local root = model.PrimaryPart
		if root then
			CreatureModel.setCollide(model, true)
			root.Anchored = false
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			root.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(18, 38), rng:NextNumber(-20, 20))
			root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		end
	end

	task.delay(2, function()
		if host.destroyed then
			return
		end
		local entries = host.getEntries()
		local cframes = TowerLayout.layout(entries, host.origin)
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for i, entry in entries do
			local model = host.models[entry.u]
			local root = model and model.Parent and model.PrimaryPart
			if root then
				root.Anchored = true
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				CreatureModel.setCollide(model, false)
				task.delay((i - 1) * 0.04, function()
					if root.Parent then
						TweenService:Create(root, info, { CFrame = cframes[i] }):Play()
					end
				end)
			end
		end
		task.wait(0.75 + #entries * 0.04)
		if host.destroyed then
			return
		end
		host.toppling = false
		host.pendingRefresh = false
		if host.attributeTarget then
			host.attributeTarget:SetAttribute("Toppling", false)
		end
		Towers.refresh(host)
		S.Sync.effectAll({ kind = "Restack", key = host.key, pos = host.origin.Position })
		if onDone then
			onDone()
		end
	end)
	return true
end

-- Comfy Cushion: favorites sit beside the tower and can never be snatched.
function Towers.renderCushions(owner)
	local plot = owner.plot
	if not plot then
		return
	end
	plot.cushionFolder:ClearAllChildren()
	for slot, entry in owner.data.cushions do
		if type(entry) == "table" then
			local model = CreatureModel.build(entry.id, entry.m)
			if model then
				model.Name = entry.u
				model:SetAttribute("Uid", entry.u)
				model:SetAttribute("Cushion", slot)
				model:PivotTo(plot.cushionCF * CFrame.new((slot - 1) * -5, 0, 0))
				model.Parent = plot.cushionFolder
			end
		end
	end
end

-- Creatures that bounced off your own tower land on the ground next to it.
function Towers.renderGround(owner)
	local plot = owner.plot
	if not plot then
		return
	end
	owner.ground = owner.ground or {}
	local inBox = {}
	for _, entry in owner.data.box do
		inBox[entry.u] = entry
	end
	for _, child in plot.groundFolder:GetChildren() do
		local uid = child:GetAttribute("Uid")
		if not (uid and owner.ground[uid] and inBox[uid]) then
			child:Destroy()
		end
	end
	local k = 0
	for uid in owner.ground do
		local entry = inBox[uid]
		if not entry then
			owner.ground[uid] = nil
		elseif not plot.groundFolder:FindFirstChild(uid) then
			k += 1
			local model = CreatureModel.build(entry.id, entry.m)
			if model then
				model.Name = uid
				model:SetAttribute("Uid", uid)
				model:SetAttribute("Ground", true)
				model:PivotTo(plot.groundCF * CFrame.new(k * 3.5, 0, 0) * CFrame.Angles(0, rng:NextNumber(-1, 1), 0))
				model.Parent = plot.groundFolder
			end
		end
	end
end

-- The dome over a base pad: solid-ish for a Bubble Shield, faint for other
-- protections (Arrival Bubble, Nap Mode, New Stacker, Ruffled Feathers).
local DOME_COLORS = {
	Shield = Color3.fromRGB(150, 225, 255),
	Arrival = Color3.fromRGB(255, 190, 230),
	Nap = Color3.fromRGB(200, 180, 255),
	NewStacker = Color3.fromRGB(180, 255, 180),
	Ruffled = Color3.fromRGB(255, 225, 150),
}
function Towers.setDome(owner, kind: string?)
	local plot = owner.plot
	if not plot then
		return
	end
	local dome = plot.dome
	if not kind then
		dome.Transparency = 1
		return
	end
	local h = TowerLayout.height(owner.data.tower) + 10
	local d = Config.Map.PlateRadius * 2 + 12
	dome.Size = Vector3.new(d, math.max(d, h * 1.15), d)
	dome.CFrame = plot.origin * CFrame.new(0, math.max(d, h * 1.15) / 2 - 3, 0)
	dome.Color = DOME_COLORS[kind] or DOME_COLORS.Shield
	dome.Transparency = kind == "Shield" and 0.55 or 0.82
end

function Towers.init(services)
	S = services
end

return Towers
