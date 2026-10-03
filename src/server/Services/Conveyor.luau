--[[
	Conveyor: the Fluff-O-Matic sneezes creatures onto Captain Conveyor's belt,
	which loops around the plaza. Walk up and buy one with Giggle Coins.

	The server decides what spawns (weighted by rarity, plus guaranteed
	Legendary and Mythic timers so players can plan). Clients animate the ride
	from each item's SpawnAt time (ConveyorPath), so it stays smooth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ConveyorPath = require(Shared.ConveyorPath)
local CreatureModel = require(Shared.CreatureModel)
local Creatures = require(Shared.Creatures)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Util = require(script.Parent.Parent.Util)

local Conveyor = {}

local S
local C = Config.Conveyor
local rng = Random.new()
local items = {} -- [uid] = item
local count = 0

Conveyor.items = items

local function gameState()
	return ReplicatedStorage:FindFirstChild("GameState")
end

local function makeLabel(model: Model, def, mutation: string?, price: number)
	local rarity = Rarities.get(def.Rarity)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(9, 2.6)
	gui.StudsOffset = Vector3.new(0, def.Height + 2.2, 0)
	gui.MaxDistance = rarity.Tier >= 3 and 160 or 70
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local function line(text, color, size, order)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(1, size)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.1
		label.TextStrokeColor3 = Color3.fromRGB(50, 30, 60)
		label.Parent = gui
	end
	local name = def.Name
	if mutation then
		name = (Mutations.name(mutation) or mutation) .. " " .. name
	end
	line(name, Color3.fromRGB(255, 255, 255), 0.38, 1)
	line(rarity.Badge .. " " .. rarity.Name .. " · " .. Format.number(def.Rate * Mutations.multiplier(mutation)) .. "/s", rarity.Color, 0.3, 2)
	line("🪙 " .. Format.number(price), Color3.fromRGB(255, 225, 90), 0.32, 3)
	gui.Parent = model
end

local function rollMutation(): string?
	for _, m in C.MutationChances do
		if rng:NextNumber() < m.Chance then
			return m.Mutation
		end
	end
	return nil
end

-- Put a creature on the belt. `forced` = specific rarity or creature id (dev / timers).
function Conveyor.spawn(forcedRarity: string?, forcedId: string?, forcedMutation: string?)
	local def
	if forcedId then
		def = Creatures.ById[forcedId]
	end
	if not def then
		local rarity = forcedRarity or Rarities.roll(C.Weights, rng)
		def = Creatures.randomOfRarity(rarity, rng)
	end
	local mutation = forcedMutation or rollMutation()
	local price = math.floor(def.Price * (mutation and math.min(Mutations.multiplier(mutation), 4) or 1))
	local uid = Util.uid()
	local spawnAt = Util.now()

	local model = CreatureModel.build(def.Id, mutation)
	if not model then
		return
	end
	model.Name = uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("SpawnAt", spawnAt)
	model:SetAttribute("Price", price)
	model:SetAttribute("Rarity", def.Rarity)
	model:PivotTo(ConveyorPath.cframeAt(0))
	makeLabel(model, def, mutation, price)
	model.Parent = S.Map.Conveyor

	items[uid] = { uid = uid, id = def.Id, m = mutation, price = price, spawnAt = spawnAt, model = model }
	count += 1

	local rarity = Rarities.get(def.Rarity)
	S.Sync.effectAll({ kind = "Sneeze", rarity = def.Rarity })
	if rarity.Announce then
		local name = def.Name
		if mutation then
			name = (Mutations.name(mutation) or mutation) .. " " .. name
		end
		local text = rarity.BigAnnounce and ("RARE ONE AHOY! A " .. rarity.Name .. " " .. name .. " is on the belt! Hold onto yer hats!")
			or ("Ahoy! A " .. rarity.Name .. " " .. name .. " on the belt!")
		S.Sync.notifyAll(text, rarity.BigAnnounce and "legendary" or "rare", "Captain Conveyor")
	end
	return uid
end

local function remove(uid: string)
	local item = items[uid]
	if item then
		items[uid] = nil
		count -= 1
		if item.model then
			item.model:Destroy()
		end
	end
end

function Conveyor.buy(owner, uid: any)
	if type(uid) ~= "string" then
		return
	end
	local item = items[uid]
	if not item then
		S.Sync.notify(owner, "Too slow! Someone else got that one.", "info", "Captain Conveyor")
		return
	end
	if not S.Stacking.handsFree(owner) then
		S.Sync.notify(owner, "Your hands are full! Stack or Box what you're holding first.", "info")
		return
	end
	local _, hrp = Util.character(owner.player)
	if not hrp then
		return
	end
	local elapsed = Util.now() - item.spawnAt
	local pos = ConveyorPath.positionAt(elapsed)
	if Util.flatDistance(hrp.Position, pos) > C.BuyDistance + C.Speed * 0.6 + 4 then
		S.Sync.notify(owner, "Get a little closer to the belt!", "info")
		return
	end
	if owner.data.coins < item.price then
		S.Sync.notify(owner, "You need " .. Format.number(item.price) .. " Giggle Coins for that one.", "info", "Captain Conveyor")
		return
	end
	owner.data.coins -= item.price
	owner.data.stats.bought += 1
	remove(uid)
	local entry = S.Stacking.newEntry(item.id, item.m)
	S.Stacking.give(owner, entry, "conveyor")
	S.Protection.markActive(owner)
	S.Sync.effectAll({ kind = "Buy", userId = owner.userId })
	S.Sync.notify(owner, "Got it! Carry it home and stack it.", "good", "Captain Conveyor")
	S.Onboarding.onBought(owner)
end

function Conveyor.init(services)
	S = services
	local state = gameState()
	if not state then
		state = Instance.new("Folder")
		state.Name = "GameState"
		state.Parent = ReplicatedStorage
	end
	Remotes.get("BuyConveyor").OnServerEvent:Connect(function(player, uid)
		local owner = S.Plots.get(player)
		if owner then
			Conveyor.buy(owner, uid)
		end
	end)
end

function Conveyor.start()
	local state = gameState()
	local nextLegendary = Util.now() + C.LegendaryEvery
	local nextMythic = Util.now() + C.MythicEvery
	state:SetAttribute("NextLegendaryAt", nextLegendary)
	state:SetAttribute("NextMythicAt", nextMythic)
	local duration = ConveyorPath.duration()
	local nextSpawn = 0
	while true do
		task.wait(0.25)
		local now = Util.now()
		for uid, item in items do
			if now - item.spawnAt > duration then
				remove(uid)
			end
		end
		if now >= nextMythic then
			nextMythic = now + C.MythicEvery
			state:SetAttribute("NextMythicAt", nextMythic)
			pcall(Conveyor.spawn, "Mythic")
			nextSpawn = now + C.SpawnInterval
		elseif now >= nextLegendary then
			nextLegendary = now + C.LegendaryEvery
			state:SetAttribute("NextLegendaryAt", nextLegendary)
			pcall(Conveyor.spawn, "Legendary")
			nextSpawn = now + C.SpawnInterval
		elseif now >= nextSpawn and count < C.MaxItems then
			nextSpawn = now + C.SpawnInterval
			local ok, err = pcall(Conveyor.spawn)
			if not ok then
				warn("[Conveyor]", err)
			end
		end
	end
end

return Conveyor
