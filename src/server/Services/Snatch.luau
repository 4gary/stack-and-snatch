--[[
	Snatch: pulling a creature off the top of someone's tower (design doc 4.3).

	  1. You can only snatch from the very top of a tower.
	  2. Wiggle too much and the tower topples - you get nothing.
	  3. If the tower topples, every creature hops back home. The owner loses nothing.
	  4. Bubble Shields block snatching completely while they're up.
	  5. If the owner (or their friend) boops you while you carry their creature,
	     it hops right back home.
	  6. Nobody can snatch from you when you're offline, and you're safe for a bit
	     when you first join.

	Flow: request -> server checks every rule -> hop up the pegs -> steady-hand
	minigame on the client -> server sanity-checks the result -> success (carry
	it home) or topple (dizzy stars, nothing lost). The server decides everything.
]]

local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Format = require(Shared.Format)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Wobble = require(Shared.Wobble)
local Economy = require(Shared.Economy)
local Util = require(script.Parent.Parent.Util)

local Snatch = {}

local S
local SN = Config.Snatch
local snatchStart
local boopTimes = {}

local function creatureName(entry): string
	local def = entry and Creatures.ById[entry.id]
	return def and def.Name or "creature"
end

local function defaultSpeed(): number
	return StarterPlayer.CharacterWalkSpeed
end

function Snatch.isTowerBusy(owner): boolean
	local lock = owner.snatchLock
	return lock ~= nil and lock.session ~= nil and lock.snatcher.session == lock.session
end

-- Minigame difficulty from the target tower (glue + steadiness + top rarity).
local function minigameParams(target, practice: boolean)
	if practice then
		return {
			ring = SN.BaseRing + 0.04,
			drift = SN.BaseDrift * 0.8,
			required = 1.6,
			limit = 1.6 + SN.ExtraTime + 1,
			maxOutside = SN.MaxOutside + 0.25,
		}
	end
	local data = target.data
	local glueLevel = Config.Upgrades.Glue.Levels[data.upgrades.Glue] or Config.Upgrades.Glue.Levels[1]
	local ringLevel = glueLevel.Ring
	local stability = 1 - math.clamp(Wobble.ratio(data.tower, Economy.glueReduce(data)), 0, 1)
	local top = data.tower[#data.tower]
	local def = top and Creatures.ById[top.id]
	local tier = def and Rarities.tier(def.Rarity) or 1
	local required = SN.BaseRequired + SN.RequiredStability * stability + SN.RequiredPerRarity * (tier - 1)
	return {
		ring = SN.BaseRing - SN.RingShrinkPerGlue * ringLevel,
		drift = SN.BaseDrift + SN.DriftPerGlue * ringLevel,
		required = required,
		limit = required + SN.ExtraTime,
		maxOutside = SN.MaxOutside,
	}
end

-- Carry effects -----------------------------------------------------------------------

local function clearCarryFx(owner)
	local fx = owner.carryFx
	if fx then
		for _, inst in fx do
			inst:Destroy()
		end
		owner.carryFx = nil
	end
	local _, _, humanoid = Util.character(owner.player)
	if humanoid and owner.stunnedUntil <= Util.now() then
		humanoid.WalkSpeed = defaultSpeed()
	end
end

local function addCarryFx(owner, entry, fromName: string)
	local character, hrp, humanoid = Util.character(owner.player)
	if not character or not hrp or not humanoid then
		return
	end
	local def = Creatures.ById[entry.id]
	local rarity = Rarities.get(def.Rarity)
	humanoid.WalkSpeed = SN.CarrySpeedByRarity[def.Rarity] or 14

	local a0 = Instance.new("Attachment")
	a0.Name = "CarryTrail0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "CarryTrail1"
	a1.Position = Vector3.new(0, -1.5, 0)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 1.6
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(rarity.Color, Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = hrp

	local gui = Instance.new("BillboardGui")
	gui.Name = "CarryTag"
	gui.Size = UDim2.fromScale(10, 1.4)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rarity.Color
	label.TextStrokeTransparency = 0
	label.Text = "🏃 Carrying " .. fromName .. "'s " .. def.Name .. "!"
	label.Parent = gui
	gui.Adornee = hrp
	gui.Parent = hrp

	owner.carryFx = { a0, a1, trail, gui }
end

-- Putting a creature back on its owner's tower (or in their box if it won't fit).
local function returnToOwner(from, entry)
	local data = from.data
	local i = Util.findByUid(data.transit, entry.u)
	if i then
		table.remove(data.transit, i)
	end
	local plainEntry = { u = entry.u, id = entry.id, m = entry.m, x = 0, z = 0 }
	local candidate = Wobble.withTop(data.tower, plainEntry)
	if #data.tower < Economy.maxSlots(data) and Wobble.isStable(candidate, Economy.glueReduce(data)) then
		table.insert(data.tower, plainEntry)
		return "tower"
	end
	table.insert(data.box, { u = entry.u, id = entry.id, m = entry.m })
	return "box"
end

local function ownerStillHere(owner): boolean
	return S.Plots.byKey[owner.key] == owner
end

-- The carry ends with the creature hopping home (booped, timeout, fell, left...).
function Snatch.cancelCarry(carrier, reason: string?)
	local c = carrier.carry
	if not c then
		return
	end
	carrier.carry = nil
	clearCarryFx(carrier)
	S.Stacking.attachHeld(carrier) -- removes the carried model (hands are empty again)
	local _, hrp = Util.character(carrier.player)
	local from = c.from
	if ownerStillHere(from) then
		local where = returnToOwner(from, c.entry)
		if from.host then
			S.Towers.refresh(from.host)
		end
		S.Plots.refreshPlot(from)
		S.Plots.updateLeaderstats(from)
		S.Sync.markDirty(from)
		S.Sync.notify(
			from,
			"Your " .. creatureName(c.entry) .. " hopped back home" .. (where == "box" and " (into your Box)!" or "!"),
			"good",
			"Sneaky Pete"
		)
		S.Sync.effectAll({
			kind = "HopHome",
			from = hrp and hrp.Position or nil,
			plot = from.plot and from.plot.index,
			id = c.entry.id,
		})
	end
	if reason then
		S.Sync.notify(carrier, reason, "warn")
	end
	S.Sync.markDirty(carrier)
end

-- Made it home with the creature: it's yours now.
local function arrive(carrier)
	local c = carrier.carry
	local from = c.from
	carrier.carry = nil
	clearCarryFx(carrier)
	if not ownerStillHere(from) then
		S.Stacking.attachHeld(carrier)
		return
	end
	local i = Util.findByUid(from.data.transit, c.entry.u)
	if i then
		table.remove(from.data.transit, i)
	end
	local entry = { u = c.entry.u, id = c.entry.id, m = c.entry.m }
	carrier.data.held = entry
	S.Stacking.attachHeld(carrier)
	S.Progress.onCreatureGained(carrier, entry, "snatch")
	carrier.data.stats.snatches += 1
	from.data.stats.snatched += 1
	local now = Util.now()
	from.ticket = { targetKey = carrier.key, targetName = carrier.name, expires = now + Config.Protection.BounceBackSeconds }

	S.Sync.notify(carrier, "Snatch complete! Stack your new " .. creatureName(entry) .. "!", "good", "Sneaky Pete")
	S.Sync.notify(
		from,
		carrier.name .. " snatched your " .. creatureName(entry) .. "! You got a Bounce-Back Ticket: one revenge snatch on their tower that ignores their shield ("
			.. Format.time(Config.Protection.BounceBackSeconds) .. ").",
		"warn",
		"Sneaky Pete"
	)
	S.Sync.effectAll({ kind = "SnatchHome", userId = carrier.userId })
	S.Progress.completeQuest(carrier, "realSnatch")
	S.Sync.markDirty(carrier)
	S.Sync.markDirty(from)
	S.Plots.saveSoon(from)
	S.Plots.saveSoon(carrier)
end

function Snatch.onCarrierLost(owner, why: string)
	if owner.carry then
		Snatch.cancelCarry(owner, "Oops, you " .. why .. "! The creature hopped back home.")
	end
end

-- Snatch sessions ---------------------------------------------------------------------

local function releaseCharacter(owner, landCF: CFrame?)
	local character, hrp = Util.character(owner.player)
	if character and hrp then
		hrp.Anchored = false
		if landCF then
			character:PivotTo(landCF)
		end
	end
end

local function endSession(owner)
	local session = owner.session
	if not session or session.kind ~= "snatch" then
		return nil
	end
	owner.session = nil
	if session.target and session.target.snatchLock and session.target.snatchLock.snatcher == owner then
		session.target.snatchLock = nil
	end
	return session
end

local function stun(owner)
	local _, _, humanoid = Util.character(owner.player)
	owner.stunnedUntil = Util.now() + SN.StunSeconds
	if humanoid then
		humanoid.WalkSpeed = 0
		task.delay(SN.StunSeconds, function()
			if owner.stunnedUntil <= Util.now() + 0.05 and humanoid.Parent and not owner.carry then
				humanoid.WalkSpeed = defaultSpeed()
			end
		end)
	end
	S.Sync.effectAll({ kind = "Dizzy", userId = owner.userId })
end

local function resolve(owner, session, success: boolean)
	local practice = session.practice
	local host = practice and S.Practice.host or (session.target and session.target.host)
	local landCF = host and S.Map.snatchLandCF(host.origin)

	if practice then
		releaseCharacter(owner, landCF)
		if success then
			S.Sync.notify(owner, "FWIP! Nice snatch! (Practice creatures hop right back.)", "good", "Sneaky Pete")
			S.Sync.effectAll({ kind = "Snatch", userId = owner.userId, practice = true })
		else
			S.Towers.topple(host)
			S.Sync.effectAll({ kind = "Topple", key = host.key, practice = true })
			stun(owner)
			S.Sync.notify(owner, "Wheee! Too wiggly! See? They all hop home. No harm done!", "info", "Sneaky Pete")
		end
		S.Onboarding.onPracticeSnatch(owner, success)
		return
	end

	local target = session.target
	if not ownerStillHere(target) or not target.host then
		releaseCharacter(owner, landCF)
		return
	end
	local data = target.data
	if success and #data.tower > 0 then
		local entry = table.remove(data.tower)
		table.insert(data.transit, { u = entry.u, id = entry.id, m = entry.m })
		target.ruffledUntil = Util.now() + Config.Protection.RuffledFeathersSeconds
		S.Towers.refresh(target.host)
		S.Plots.refreshPlot(target)
		S.Plots.updateLeaderstats(target)
		releaseCharacter(owner, landCF)
		owner.carry = { entry = entry, from = target, start = Util.now() }
		S.Stacking.attachHeld(owner)
		addCarryFx(owner, entry, target.name)
		S.Sync.effectAll({ kind = "Snatch", userId = owner.userId, plot = target.plot and target.plot.index })
		S.Sync.notify(owner, "FWIP! Got the " .. creatureName(entry) .. "! Run home before " .. target.name .. " boops you!", "good", "Sneaky Pete")
		S.Sync.notify(target, owner.name .. " snatched your " .. creatureName(entry) .. "! Go boop them to bring it home!", "warn", "Sneaky Pete")
		S.Sync.markDirty(target)
	else
		releaseCharacter(owner, landCF)
		S.Towers.topple(target.host)
		S.Sync.effectAll({ kind = "Topple", key = target.key, plot = target.plot and target.plot.index })
		stun(owner)
		S.Sync.notify(owner, "Wheee! The tower toppled! Everyone hops home - better luck next time.", "info", "Sneaky Pete")
		S.Sync.notify(target, owner.name .. " tried to snatch from you and toppled your tower! Nothing lost.", "info", "Sneaky Pete")
	end
	S.Sync.markDirty(owner)
end

function Snatch.request(owner, plotIndex: any)
	if type(plotIndex) ~= "number" then
		return
	end
	local now = Util.now()
	if owner.session or owner.carry or owner.stunnedUntil > now then
		return
	end
	if owner.data.held then
		S.Sync.notify(owner, "You need empty hands to snatch!", "info", "Sneaky Pete")
		return
	end
	local character, hrp = Util.character(owner.player)
	if not character or not hrp then
		return
	end

	local practice = plotIndex == 0
	local target, host, pegs
	if practice then
		host = S.Practice.host
		pegs = S.Map.practice.pegs
	else
		target = S.Plots.ownerOfPlot(plotIndex)
		if not target or not target.host then
			return
		end
		host = target.host
		pegs = target.plot.pegs
		if not owner.plot then
			S.Sync.notify(owner, "You need a base pad to carry creatures home to!", "info")
			return
		end
	end

	if Util.flatDistance(hrp.Position, pegs.Position) > SN.PromptDistance + SN.ServerDistanceSlack then
		return
	end

	local usesTicket = false
	if practice then
		if host.toppling then
			S.Sync.notify(owner, "Hang on, the practice tower is still bouncing back!", "info", "Sneaky Pete")
			return
		end
	else
		local ok, reason, ticket = S.Protection.canSnatch(target, owner)
		if not ok then
			S.Sync.notify(owner, reason, "info", "Sneaky Pete")
			return
		end
		if Snatch.isTowerBusy(target) then
			S.Sync.notify(owner, "Someone's already on that tower! Wait your turn.", "info", "Sneaky Pete")
			return
		end
		usesTicket = ticket
	end

	local params = minigameParams(target, practice)
	local session = {
		kind = "snatch",
		id = Util.uid(),
		practice = practice,
		target = target,
		params = params,
		requested = now,
	}
	owner.session = session
	if target then
		target.snatchLock = { snatcher = owner, session = session }
		if usesTicket then
			owner.ticket = nil
			S.Sync.notify(owner, "Bounce-Back Ticket used - their shield can't stop you this time!", "good", "Sneaky Pete")
		elseif owner.ticket and owner.ticket.targetKey == target.key then
			owner.ticket = nil -- one revenge attempt only
		end
		S.Sync.notify(target, owner.name .. " is climbing your tower! Get ready to boop!", "warn", "Sneaky Pete")
		for _, entry in target.data.tower do
			local def = Creatures.ById[entry.id]
			if def and def.Alarm then
				S.Sync.effectAll({ kind = "Alarm", plot = target.plot.index })
				S.Sync.notify(target, "Teapot Turtle whistles! Someone's on your tower!", "warn")
				break
			end
		end
		S.Sync.markDirty(target)
	end
	S.Protection.markActive(owner)

	-- Hop up the pegs.
	local stand = S.Map.snatchStandCF(host.origin, S.Towers.topHeight(host))
	hrp.Anchored = true
	TweenService:Create(hrp, TweenInfo.new(SN.HopUpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = stand }):Play()
	S.Sync.effectAll({ kind = "Hop", userId = owner.userId })

	task.delay(SN.HopUpTime, function()
		if owner.session ~= session then
			return
		end
		character:PivotTo(stand)
		session.start = Util.now()
		snatchStart:FireClient(owner.player, session.id, {
			ring = params.ring,
			drift = params.drift,
			required = params.required,
			limit = params.limit,
			maxOutside = params.maxOutside,
			practice = practice,
			creatureId = (function()
				local entries = host.getEntries()
				local top = entries[#entries]
				return top and top.id
			end)(),
		})
	end)
	-- Safety net: if the client never answers, the tower wins.
	task.delay(SN.HopUpTime + params.limit + 4, function()
		if owner.session == session then
			endSession(owner)
			resolve(owner, session, false)
		end
	end)
end

function Snatch.result(owner, sessionId: any, success: any, stats: any)
	local session = owner.session
	if not session or session.kind ~= "snatch" or session.id ~= sessionId or not session.start then
		return
	end
	endSession(owner)
	local params = session.params
	local elapsed = Util.now() - session.start
	local ok = success == true
	if ok then
		-- Sanity checks: you can't finish faster than the steady time needed.
		if elapsed < params.required - 0.4 or elapsed > params.limit + 2 then
			ok = false
		end
		if type(stats) == "table" and type(stats.steady) == "number" and stats.steady < params.required * 0.85 then
			ok = false
		end
	end
	-- Flag suspiciously perfect streaks for review (never punish automatically).
	if ok and type(stats) == "table" and stats.outside == 0 then
		owner.perfectStreak = (owner.perfectStreak or 0) + 1
		if owner.perfectStreak >= SN.PerfectFlagStreak then
			warn(string.format("[Snatch] %s has %d perfect snatches in a row", owner.name, owner.perfectStreak))
		end
	else
		owner.perfectStreak = 0
	end
	resolve(owner, session, ok)
end

-- Boop! -------------------------------------------------------------------------------

function Snatch.boop(owner)
	if not Util.throttle(boopTimes, owner.key, SN.BoopCooldown) then
		return
	end
	local _, hrp = Util.character(owner.player)
	if not hrp then
		return
	end
	S.Protection.markActive(owner)
	S.Sync.effectAll({ kind = "Boop", userId = owner.userId })
	for _, carrier in S.Plots.all() do
		local c = carrier.carry
		if c and carrier ~= owner and (c.from == owner or S.Social.areFriends(c.from, owner)) then
			local _, chrp = Util.character(carrier.player)
			if chrp and (chrp.Position - hrp.Position).Magnitude <= SN.BoopRange then
				Snatch.cancelCarry(carrier, "BOOP! " .. owner.name .. " booped you - the creature hopped back home!")
				local dir = chrp.Position - hrp.Position
				dir = Vector3.new(dir.X, 0, dir.Z)
				dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(1, 0, 0)
				if carrier.player then
					S.Sync.effect(carrier, { kind = "Knockback", dir = dir * SN.BoopKnockback + Vector3.new(0, 30, 0) })
				end
				S.Sync.notify(owner, "BOOP! Your creature is hopping home!", "good", "Sneaky Pete")
			end
		end
	end
end

-- Cleanup when someone leaves --------------------------------------------------------

function Snatch.onOwnerRemoving(owner)
	-- They were carrying someone's creature: it hops home.
	if owner.carry then
		Snatch.cancelCarry(owner, nil)
	end
	-- Someone was carrying *their* creature: put it straight back in their data.
	for _, carrier in S.Plots.all() do
		local c = carrier.carry
		if c and c.from == owner then
			carrier.carry = nil
			clearCarryFx(carrier)
			S.Stacking.attachHeld(carrier)
			returnToOwner(owner, c.entry)
			S.Sync.notify(carrier, owner.name .. " left, so their " .. creatureName(c.entry) .. " hopped home.", "info")
			S.Sync.markDirty(carrier)
		end
		-- Someone was mid-snatch on their tower.
		local session = carrier.session
		if session and session.kind == "snatch" and session.target == owner then
			endSession(carrier)
			releaseCharacter(carrier, S.Map.snatchLandCF(owner.host.origin))
		end
	end
	-- Their own snatch in progress.
	local session = endSession(owner)
	if session then
		releaseCharacter(owner, nil)
	end
	owner.snatchLock = nil
end

function Snatch.init(services)
	S = services
	snatchStart = Remotes.get("SnatchStart")
	Remotes.get("RequestSnatch").OnServerEvent:Connect(function(player, plotIndex)
		local owner = S.Plots.get(player)
		if owner then
			Snatch.request(owner, plotIndex)
		end
	end)
	Remotes.get("SnatchResult").OnServerEvent:Connect(function(player, sessionId, success, stats)
		local owner = S.Plots.get(player)
		if owner then
			Snatch.result(owner, sessionId, success, stats)
		end
	end)
	Remotes.get("Boop").OnServerEvent:Connect(function(player)
		local owner = S.Plots.get(player)
		if owner then
			Snatch.boop(owner)
		end
	end)
end

function Snatch.start()
	while true do
		task.wait(0.2)
		local now = Util.now()
		for _, owner in S.Plots.all() do
			local c = owner.carry
			if c then
				local _, hrp = Util.character(owner.player)
				if not ownerStillHere(c.from) then
					owner.carry = nil
					clearCarryFx(owner)
					S.Stacking.attachHeld(owner)
				elseif not hrp then
					Snatch.cancelCarry(owner, "Oops! The creature hopped back home.")
				elseif S.Plots.onOwnPad(owner) then
					local ok, err = pcall(arrive, owner)
					if not ok then
						warn("[Snatch] arrive failed", err)
					end
				elseif now - c.start > SN.CarryTimeout then
					Snatch.cancelCarry(owner, "The creature got sleepy and hopped back home!")
				end
			end
			if owner.ticket and owner.ticket.expires < now then
				owner.ticket = nil
				S.Sync.markDirty(owner)
			end
		end
	end
end

return Snatch
