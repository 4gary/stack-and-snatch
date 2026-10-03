--[[
	Stacking: the creature in your hands, placing it on your tower, the Box,
	rearranging your tower, and the Comfy Cushion.

	Placement uses the swing: the ghost sways over your tower and you tap DROP.
	The server recomputes where it landed from the drop time (Wobble.swingOffset)
	and decides with the wobble rules whether it stacks or the tower topples.
	Toppling your own tower never loses anything: everyone hops back, and the
	creature you tried to add lands on the ground next to the tower.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local CreatureModel = require(Shared.CreatureModel)
local Economy = require(Shared.Economy)
local Wobble = require(Shared.Wobble)
local Util = require(script.Parent.Parent.Util)

local Stacking = {}

local S
local rng = Random.new()

local function creatureName(entry): string
	local def = entry and Creatures.ById[entry.id]
	return def and def.Name or "creature"
end

local function plain(entry)
	return { u = entry.u, id = entry.id, m = entry.m }
end

function Stacking.newEntry(creatureId: string, mutation: string?)
	return { u = Util.uid(), id = creatureId, m = mutation }
end

function Stacking.handsFree(owner): boolean
	return owner.data.held == nil and owner.carry == nil
end

-- The creature model riding above your head --------------------------------------

function Stacking.detachHeld(owner)
	if owner.heldModel then
		owner.heldModel:Destroy()
		owner.heldModel = nil
	end
end

function Stacking.attachHeld(owner)
	Stacking.detachHeld(owner)
	local held = owner.data.held or (owner.carry and owner.carry.entry)
	if not held then
		return
	end
	local character, hrp = Util.character(owner.player)
	if not character or not hrp then
		return
	end
	local model = CreatureModel.build(held.id, held.m)
	if not model then
		return
	end
	model.Name = "HeldCreature"
	model:PivotTo(hrp.CFrame * CFrame.new(0, 3.4, 0))
	CreatureModel.prepareForCarry(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = character
	owner.heldModel = model
end

-- Put a creature into an owner's hands. Returns false if their hands are full.
function Stacking.give(owner, entry, source: string?): boolean
	if not Stacking.handsFree(owner) then
		return false
	end
	owner.data.held = plain(entry)
	S.Progress.onCreatureGained(owner, owner.data.held, source)
	Stacking.attachHeld(owner)
	S.Sync.markDirty(owner)
	return true
end

local function afterTowerChange(owner)
	if owner.host then
		S.Towers.refresh(owner.host)
	end
	S.Progress.onTowerChanged(owner)
	S.Plots.refreshPlot(owner)
	S.Plots.updateLeaderstats(owner)
	S.Sync.markDirty(owner)
end

local function towerLocked(owner): boolean
	if owner.host and owner.host.toppling then
		S.Sync.notify(owner, "Wait a sec - your tower is still bouncing back!", "info")
		return true
	end
	if S.Snatch.isTowerBusy(owner) then
		S.Sync.notify(owner, "Someone's climbing your tower! Boop them first.", "warn", "Sneaky Pete")
		return true
	end
	return false
end

-- Drop the held creature on your tower -------------------------------------------

function Stacking.place(owner, dropTime: any)
	local data = owner.data
	local held = data.held
	if not held or not owner.plot or not owner.host then
		return
	end
	if towerLocked(owner) then
		return
	end
	if not S.Plots.onOwnPad(owner, 4) then
		S.Sync.notify(owner, "Stand on your base pad to stack!", "info")
		return
	end
	if #data.tower >= Economy.maxSlots(data) then
		S.Sync.notify(owner, "Your tower is full! Bricklebee can build you a bigger base.", "warn", "Bricklebee")
		return
	end

	local now = Util.now()
	if type(dropTime) ~= "number" or dropTime ~= dropTime or math.abs(dropTime - now) > Config.Pendulum.TimestampTolerance then
		dropTime = now
	end
	local n = #data.tower
	local x, z = Wobble.swingOffset(dropTime, n)
	local entry = { u = held.u, id = held.id, m = held.m, x = Wobble.roundOffset(x), z = Wobble.roundOffset(z) }
	if n == 0 then
		entry.x, entry.z = 0, 0
	end

	data.held = nil
	Stacking.detachHeld(owner)
	S.Protection.markActive(owner)

	if not Wobble.isStable(Wobble.withTop(data.tower, entry), Economy.glueReduce(data)) then
		-- Too wobbly: sproing! Nobody is lost; the new creature lands on the ground.
		table.insert(data.box, plain(entry))
		owner.ground = owner.ground or {}
		owner.ground[entry.u] = true
		data.stats.topples += 1
		S.Towers.topple(owner.host, function()
			S.Towers.renderGround(owner)
			S.Sync.markDirty(owner)
		end)
		S.Sync.effectAll({ kind = "Topple", key = owner.key, plot = owner.plot.index })
		S.Sync.notify(
			owner,
			"Wheeee! Too wobbly! Everyone hops back home. Your " .. creatureName(entry) .. " landed next to the tower.",
			"warn"
		)
		S.Plots.refreshPlot(owner)
		S.Sync.markDirty(owner)
		return
	end

	-- Sprinkle Rain: creatures stacked during the weather may get Sprinkled.
	if not entry.m and S.Weather.isActive() and rng:NextNumber() < Config.Weather.MutationChance then
		entry.m = "Sprinkled"
		S.Progress.recordIndex(owner, entry)
		S.Sync.notify(owner, "Sprinkle Rain made your " .. creatureName(entry) .. " Sprinkled! (x1.5 coins)", "rare")
	end

	table.insert(data.tower, entry)
	afterTowerChange(owner)
	local def = Creatures.ById[entry.id]
	S.Sync.effectAll({
		kind = "Stack",
		key = owner.key,
		plot = owner.plot.index,
		height = #data.tower,
		confetti = def and def.Confetti or nil,
	})
	S.Onboarding.onPlaced(owner)
end

-- The Box -----------------------------------------------------------------------------

function Stacking.storeHeld(owner)
	local data = owner.data
	if not data.held then
		return
	end
	if #data.box >= Economy.boxCapacity(data) then
		S.Sync.notify(owner, "Your Box is full! Stack something or upgrade your base.", "warn", "Bricklebee")
		return
	end
	table.insert(data.box, plain(data.held))
	data.held = nil
	Stacking.detachHeld(owner)
	S.Sync.markDirty(owner)
end

function Stacking.takeFromBox(owner, uid: any)
	if type(uid) ~= "string" then
		return
	end
	local data = owner.data
	if not Stacking.handsFree(owner) then
		S.Sync.notify(owner, "Your hands are full!", "info")
		return
	end
	local i = Util.findByUid(data.box, uid)
	if not i then
		return
	end
	local entry = table.remove(data.box, i)
	data.held = plain(entry)
	if owner.ground then
		owner.ground[uid] = nil
	end
	S.Towers.renderGround(owner)
	Stacking.attachHeld(owner)
	S.Sync.markDirty(owner)
end

function Stacking.pickUpGround(owner, uid: any)
	if type(uid) ~= "string" or not (owner.ground and owner.ground[uid]) then
		return
	end
	Stacking.takeFromBox(owner, uid)
end

-- Rearranging the tower -----------------------------------------------------------

local function freeCushionSlot(data): number?
	for slot = 1, Config.Protection.CushionSlots do
		if data.cushions[slot] == false or data.cushions[slot] == nil then
			return slot
		end
	end
	return nil
end

-- Try a new tower order; refuses changes that would leave the tower too wobbly.
local function tryTower(owner, newTower): boolean
	if not Wobble.isStable(newTower, Economy.glueReduce(owner.data)) then
		S.Sync.notify(owner, "That would make the tower too wobbly! Try another spot.", "warn", "Grandma Gloop")
		return false
	end
	owner.data.tower = newTower
	return true
end

function Stacking.towerAction(owner, action: any, uid: any)
	if type(action) ~= "string" then
		return
	end
	local data = owner.data
	S.Protection.markActive(owner)

	if action == "uncushion" then
		local slot = tonumber(uid)
		local entry = slot and data.cushions[slot]
		if type(entry) ~= "table" then
			return
		end
		if Stacking.handsFree(owner) then
			data.held = plain(entry)
			Stacking.attachHeld(owner)
		elseif #data.box < Economy.boxCapacity(data) then
			table.insert(data.box, plain(entry))
		else
			S.Sync.notify(owner, "Your hands and Box are full!", "info")
			return
		end
		data.cushions[slot] = false
		S.Towers.renderCushions(owner)
		S.Plots.refreshPlot(owner)
		S.Sync.markDirty(owner)
		return
	end

	if type(uid) ~= "string" then
		return
	end

	if action == "cushionFromBox" then
		local slot = freeCushionSlot(data)
		local i = Util.findByUid(data.box, uid)
		if not slot then
			S.Sync.notify(owner, "Your Comfy Cushion is taken! Move that creature off first.", "info", "Lou the Locksmith")
			return
		end
		if i then
			data.cushions[slot] = plain(table.remove(data.box, i))
			S.Towers.renderCushions(owner)
			S.Plots.refreshPlot(owner)
			S.Sync.markDirty(owner)
		end
		return
	end

	-- Everything below changes the tower itself.
	local i = Util.findByUid(data.tower, uid)
	if not i or towerLocked(owner) then
		return
	end
	local tower = data.tower

	if action == "take" then
		if not Stacking.handsFree(owner) then
			S.Sync.notify(owner, "Your hands are full!", "info")
			return
		end
		local newTower = table.clone(tower)
		local entry = table.remove(newTower, i)
		if tryTower(owner, newTower) then
			data.held = plain(entry)
			Stacking.attachHeld(owner)
			afterTowerChange(owner)
		end
	elseif action == "up" or action == "down" then
		local j = action == "up" and i + 1 or i - 1
		if j < 1 or j > #tower then
			return
		end
		local newTower = table.clone(tower)
		newTower[i], newTower[j] = newTower[j], newTower[i]
		if tryTower(owner, newTower) then
			afterTowerChange(owner)
		end
	elseif action == "cushion" then
		local slot = freeCushionSlot(data)
		if not slot then
			S.Sync.notify(owner, "Your Comfy Cushion is taken! Move that creature off first.", "info", "Lou the Locksmith")
			return
		end
		local newTower = table.clone(tower)
		local entry = table.remove(newTower, i)
		if tryTower(owner, newTower) then
			data.cushions[slot] = plain(entry)
			S.Towers.renderCushions(owner)
			afterTowerChange(owner)
		end
	end
end

function Stacking.init(services)
	S = services
	local Remotes = require(Shared.Remotes)
	Remotes.get("PlaceHeld").OnServerEvent:Connect(function(player, dropTime)
		local owner = S.Plots.get(player)
		if owner then
			Stacking.place(owner, dropTime)
		end
	end)
	Remotes.get("StoreHeld").OnServerEvent:Connect(function(player)
		local owner = S.Plots.get(player)
		if owner then
			Stacking.storeHeld(owner)
		end
	end)
	Remotes.get("TakeFromBox").OnServerEvent:Connect(function(player, uid)
		local owner = S.Plots.get(player)
		if owner then
			Stacking.takeFromBox(owner, uid)
		end
	end)
	Remotes.get("PickUpGround").OnServerEvent:Connect(function(player, uid)
		local owner = S.Plots.get(player)
		if owner then
			Stacking.pickUpGround(owner, uid)
		end
	end)
	Remotes.get("TowerAction").OnServerEvent:Connect(function(player, action, uid)
		local owner = S.Plots.get(player)
		if owner then
			Stacking.towerAction(owner, action, uid)
		end
	end)
end

return Stacking
