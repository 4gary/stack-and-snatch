--[[
	Meadows: wild Stackables bounce around Muffin Meadows. They're free, but you
	have to scoop them gently: a quick timing tap (stop the marker in the green).
	Rarer creatures have a smaller green zone and a faster marker.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModel = require(Shared.CreatureModel)
local Creatures = require(Shared.Creatures)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Util = require(script.Parent.Parent.Util)

local Meadows = {}

local S
local MW = Config.Meadows
local M = Config.Map
local rng = Random.new()
local wild = {} -- [uid] = { uid, id, m, pos, model, lockedBy, lockUntil }
local count = 0
local scoopStart

local function randomSpot(): Vector3
	local a = rng:NextNumber(0, 2 * math.pi)
	local r = rng:NextNumber(M.MeadowInner + 3, M.MeadowOuter - 3)
	local x, z = r * math.cos(a), r * math.sin(a)
	return Vector3.new(x, S.Map.groundAt(x, z), z)
end

local function label(model: Model, def)
	local rarity = Rarities.get(def.Rarity)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(8, 1.8)
	gui.StudsOffset = Vector3.new(0, def.Height + 1.8, 0)
	gui.MaxDistance = rarity.Tier >= 3 and 140 or 60
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "Wild " .. def.Name .. "\n" .. rarity.Badge .. " " .. rarity.Name
	text.TextColor3 = rarity.Color
	text.TextStrokeTransparency = 0.1
	text.TextStrokeColor3 = Color3.fromRGB(50, 30, 60)
	text.Parent = gui
	gui.Parent = model
end

local function place(w)
	w.pos = randomSpot()
	w.model:PivotTo(CFrame.new(w.pos) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
	w.model:SetAttribute("BasePos", w.pos)
end

function Meadows.spawn(forcedId: string?)
	local def = forcedId and Creatures.ById[forcedId]
	if not def then
		def = Creatures.randomOfRarity(Rarities.roll(MW.Weights, rng), rng)
	end
	local model = CreatureModel.build(def.Id, nil)
	if not model then
		return
	end
	local uid = Util.uid()
	model.Name = uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Rarity", def.Rarity)
	label(model, def)
	local w = { uid = uid, id = def.Id, model = model }
	place(w)
	model.Parent = S.Map.Wild
	wild[uid] = w
	count += 1
	if Rarities.tier(def.Rarity) >= Rarities.tier("Epic") then
		S.Sync.notifyAll("A wild " .. def.Name .. " is bouncing around Muffin Meadows!", "rare", "Professor Puddlewick")
	end
end

local function removeWild(uid: string)
	local w = wild[uid]
	if w then
		wild[uid] = nil
		count -= 1
		w.model:Destroy()
	end
end

function Meadows.requestScoop(owner, uid: any)
	if type(uid) ~= "string" then
		return
	end
	local w = wild[uid]
	if not w then
		return
	end
	local now = Util.now()
	if owner.session then
		return
	end
	if not S.Stacking.handsFree(owner) then
		S.Sync.notify(owner, "Your hands are full! Stack or Box what you're holding first.", "info")
		return
	end
	if (owner.scoopCooldownUntil or 0) > now then
		S.Sync.notify(owner, "Catch your breath for a second!", "info")
		return
	end
	if w.lockedBy and w.lockedBy ~= owner.key and (w.lockUntil or 0) > now then
		S.Sync.notify(owner, "Someone else is already scooping that one!", "info")
		return
	end
	local _, hrp = Util.character(owner.player)
	if not hrp or Util.flatDistance(hrp.Position, w.pos) > MW.ScoopDistance + 6 then
		return
	end
	local def = Creatures.ById[w.id]
	local session = {
		kind = "scoop",
		id = Util.uid(),
		uid = uid,
		start = now,
		zone = MW.ZoneByRarity[def.Rarity] or 0.2,
	}
	owner.session = session
	w.lockedBy = owner.key
	w.lockUntil = now + 10
	S.Protection.markActive(owner)
	scoopStart:FireClient(owner.player, session.id, {
		zone = session.zone,
		speed = MW.MarkerSpeedByRarity[def.Rarity] or 1,
		creatureId = w.id,
	})
end

function Meadows.scoopResult(owner, sessionId: any, marker: any)
	local session = owner.session
	if not session or session.kind ~= "scoop" or session.id ~= sessionId then
		return
	end
	owner.session = nil
	local w = wild[session.uid]
	if not w then
		return
	end
	w.lockedBy = nil
	local elapsed = Util.now() - session.start
	local success = type(marker) == "number" and marker == marker and elapsed >= 0.25 and math.abs(marker - 0.5) <= session.zone / 2
	local def = Creatures.ById[w.id]
	if success then
		local entry = S.Stacking.newEntry(w.id, nil)
		if S.Stacking.give(owner, entry, "meadow") then
			owner.data.stats.scooped += 1
			removeWild(session.uid)
			S.Sync.notify(owner, "Gently does it! You scooped a " .. def.Name .. "!", "good", "Professor Puddlewick")
			S.Sync.effectAll({ kind = "Scoop", userId = owner.userId, ok = true })
		end
	else
		owner.scoopCooldownUntil = Util.now() + MW.FailCooldown
		place(w)
		S.Sync.notify(owner, "Boing! The " .. def.Name .. " bounced away!", "warn")
		S.Sync.effectAll({ kind = "Scoop", userId = owner.userId, ok = false })
	end
end

function Meadows.onOwnerRemoving(owner)
	for _, w in wild do
		if w.lockedBy == owner.key then
			w.lockedBy = nil
		end
	end
	owner.session = nil
end

function Meadows.init(services)
	S = services
	scoopStart = Remotes.get("ScoopStart")
	Remotes.get("RequestScoop").OnServerEvent:Connect(function(player, uid)
		local owner = S.Plots.get(player)
		if owner then
			Meadows.requestScoop(owner, uid)
		end
	end)
	Remotes.get("ScoopResult").OnServerEvent:Connect(function(player, sessionId, marker)
		local owner = S.Plots.get(player)
		if owner then
			Meadows.scoopResult(owner, sessionId, marker)
		end
	end)
end

function Meadows.start()
	for _ = 1, MW.MaxWild do
		pcall(Meadows.spawn)
	end
	while true do
		task.wait(MW.RespawnInterval)
		if count < MW.MaxWild then
			local ok, err = pcall(Meadows.spawn)
			if not ok then
				warn("[Meadows]", err)
			end
		end
		-- clear scoop sessions nobody finished
		local now = Util.now()
		for _, owner in S.Plots.all() do
			local session = owner.session
			if session and session.kind == "scoop" and now - session.start > 15 then
				owner.session = nil
			end
		end
	end
end

return Meadows
