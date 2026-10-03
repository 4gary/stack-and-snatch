--[[
	Prompts: ProximityPrompts for everything you can walk up to.

	  Conveyor creatures   Buy
	  Wild creatures       Scoop
	  Tower pegs           Snatch! (shows why not, e.g. "Shielded")
	  Ground creatures     Pick up (your own base only)
	  NPC stalls           Shop / Talk

	Prompts are created on the client so each player sees the right text;
	the server validates every request.
]]

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Remotes = require(Shared.Remotes)

local Prompts = {}

local C
local State
local pegPrompts = {} -- [pegs part] = prompt

local function prompt(parent: Instance, action: string, object: string, distance: number?, order: number?)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.UIOffset = Vector2.new(0, (order or 0) * 60)
	p.Parent = parent
	return p
end

local function creatureName(model: Instance): string
	local def = Creatures.ById[model:GetAttribute("CreatureId") or ""]
	local name = def and def.Name or "Creature"
	local m = model:GetAttribute("Mutation")
	if m and m ~= "" then
		name = (Mutations.name(m) or m) .. " " .. name
	end
	return name
end

-- Conveyor -------------------------------------------------------------------------------
local function onConveyorItem(model: Instance)
	local root = model:WaitForChild("Root", 5)
	if not root then
		return
	end
	local price = model:GetAttribute("Price") or 0
	local p = prompt(root, "Buy 💰" .. Format.number(price), creatureName(model), Config.Conveyor.BuyDistance - 2)
	p.Triggered:Connect(function()
		Remotes.get("BuyConveyor"):FireServer(model:GetAttribute("Uid"))
	end)
end

-- Muffin Meadows ----------------------------------------------------------------------------
local function onWild(model: Instance)
	local root = model:WaitForChild("Root", 5)
	if not root then
		return
	end
	local p = prompt(root, "Scoop", "Wild " .. creatureName(model), Config.Meadows.ScoopDistance - 2)
	p.Triggered:Connect(function()
		if C.Minigames.isBusy() then
			return
		end
		Remotes.get("RequestScoop"):FireServer(model:GetAttribute("Uid"))
	end)
end

-- Snatch pegs -----------------------------------------------------------------------------
local function onPegs(pegs: BasePart)
	local practice = pegs:GetAttribute("Practice") == true
	local index = pegs:GetAttribute("PlotIndex") or 0
	local p = prompt(pegs, practice and "Practice Snatch" or "Snatch!", practice and "Sneaky Pete's tower" or "", Config.Snatch.PromptDistance)
	p.HoldDuration = 0.25
	p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	p.Triggered:Connect(function()
		if C.Minigames.isBusy() then
			return
		end
		Remotes.get("RequestSnatch"):FireServer(index)
	end)
	pegPrompts[pegs] = p
end

local function updatePegs()
	local data = State.data
	for pegs, p in pegPrompts do
		if not pegs.Parent then
			pegPrompts[pegs] = nil
			continue
		end
		if pegs:GetAttribute("Practice") then
			p.Enabled = true
			continue
		end
		local plot = pegs.Parent
		local index = pegs:GetAttribute("PlotIndex")
		local ownerName = plot:GetAttribute("OwnerName") or ""
		local height = plot:GetAttribute("Height") or 0
		local mine = data and data.plotIndex == index
		if ownerName == "" or mine or height == 0 then
			p.Enabled = false
			continue
		end
		p.Enabled = true
		p.ObjectText = ownerName .. "'s tower (" .. height .. " tall)"
		local status = plot:GetAttribute("Status") or ""
		local ticketHere = data and data.ticket and data.ticket.plot == index
		local myHeight = data and #data.tower or 0
		if (plot:GetAttribute("ShieldUntil") or 0) > State.now() then
			p.ActionText = ticketHere and "Revenge Snatch! 🎟️" or "🛡️ Shielded"
		elseif plot:GetAttribute("Toppling") then
			p.ActionText = "Bouncing back..."
		elseif status ~= "" then
			p.ActionText = status
		elseif not Economy.inFairRange(myHeight, height) and not (data and data.protection and data.protection.devNoProtection) then
			p.ActionText = "Out of range"
		else
			p.ActionText = ticketHere and "Revenge Snatch! 🎟️" or "Snatch!"
		end
	end
end

-- Ground creatures on my own pad ---------------------------------------------------------
local groundPrompts = {}
local function updateGround()
	local plot = State.plotModel()
	local folder = plot and plot:FindFirstChild("Ground")
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		if not groundPrompts[model] then
			local root = model:FindFirstChild("Root")
			if root then
				local p = prompt(root, "Pick up", creatureName(model), 10)
				p.Triggered:Connect(function()
					Remotes.get("PickUpGround"):FireServer(model:GetAttribute("Uid"))
				end)
				groundPrompts[model] = p
			end
		end
	end
	for model in groundPrompts do
		if not model.Parent then
			groundPrompts[model] = nil
		end
	end
end

-- NPC stalls ------------------------------------------------------------------------------
local TALK = {
	Pete = {
		"Gentle hands, quick feet! Only the very top creature can be snatched.",
		"If a tower topples, every creature hops home. Nobody loses anything!",
		"Shields, napping towers and new players can't be snatched. That's the rules!",
		"Got snatched? Boop the carrier with your Boop button before they get home!",
	},
	Mayor = {
		"By the power of fluff, I declare... ribbons at 10, 25, 50 and 100 tall!",
		"The tallest towers in the server are on my board. Is yours up there?",
	},
	Captain = {
		"RARE ONE AHOY! Legendary and Mythic creatures ride my belt on a timer - watch the clock up top!",
		"Walk up to a creature on the belt and press the button to buy it. Then carry it home!",
	},
}
local talkIndex = {}

local function onStall(part: BasePart)
	local action = part:GetAttribute("Action") or ""
	local p = prompt(part, part:GetAttribute("PromptText") or "Talk", part:GetAttribute("NpcName") or "", 8)
	p.Triggered:Connect(function()
		local kind, arg = string.match(action, "^(%a+):?(%a*)$")
		if kind == "Shop" then
			C.Panels.open("Shop", arg)
		elseif kind == "Index" then
			C.Panels.open("Index")
		elseif kind == "Emotes" then
			C.Panels.open("Emotes")
		elseif kind == "Talk" then
			local lines = TALK[arg]
			if lines then
				talkIndex[arg] = (talkIndex[arg] or 0) % #lines + 1
				C.Notifications.show({ text = lines[talkIndex[arg]], npc = part:GetAttribute("NpcName"), kind = "info" })
			end
		end
	end)
end

local function watchFolder(name: string, handler)
	task.spawn(function()
		local folder = workspace:WaitForChild(name, 60)
		if not folder then
			return
		end
		folder.ChildAdded:Connect(function(child)
			task.spawn(handler, child)
		end)
		for _, child in folder:GetChildren() do
			task.spawn(handler, child)
		end
	end)
end

local function watchTag(tag: string, handler)
	CollectionService:GetInstanceAddedSignal(tag):Connect(handler)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(handler, inst)
	end
end

function Prompts.init(controllers)
	C = controllers
	State = C.State
	watchFolder("Conveyor", onConveyorItem)
	watchFolder("Wild", onWild)
	watchTag("SnatchPegs", onPegs)
	watchTag("NpcStall", onStall)
end

function Prompts.start()
	while true do
		task.wait(0.4)
		pcall(updatePegs)
		pcall(updateGround)
	end
end

return Prompts
