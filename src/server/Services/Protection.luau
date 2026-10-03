--[[
	Protection: the fairness rules from design doc 4.4. Snatching should feel
	like a prank between friends, never a robbery.

	  Arrival Bubble       free shield on every join (3+ minutes, and until you move)
	  New Stacker          first 20 minutes of playtime: can't be snatched from
	  Nap Mode             idle ~2 minutes: tower sleeps, can't be snatched, earns 50%
	  Bubble Shield        button; blocks snatching completely while up
	  Ruffled Feathers     90 seconds of protection after being snatched from
	  Fair Snatch Range    only towers about half to double your height
	  Bounce-Back Ticket   one shield-ignoring revenge attempt after being snatched
	  Offline              your tower goes home with you
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Util = require(script.Parent.Parent.Util)

local Protection = {}

local S
local P = Config.Protection
local intruderNotices = {}

function Protection.onOwnerAdded(owner)
	local now = Util.now()
	owner.joinTime = now
	owner.lastActive = now
	owner.moved = false
end

function Protection.markActive(owner)
	owner.lastActive = Util.now()
	if owner.napping then
		owner.napping = false
		S.Plots.refreshPlot(owner)
		S.Sync.markDirty(owner)
	end
end

-- Everything protecting this owner's tower right now.
function Protection.state(owner)
	local now = Util.now()
	local exempt = owner.isBot or owner.devNoProtection
	local st = {}
	st.arrivalLeft = math.max(0, owner.joinTime + P.ArrivalBubbleSeconds - now)
	st.arrival = not exempt and (st.arrivalLeft > 0 or not owner.moved)
	st.newStackerLeft = math.max(0, P.NewStackerSeconds - owner.data.playtime)
	st.newStacker = not exempt and st.newStackerLeft > 0
	st.napping = not exempt and owner.napping
	st.ruffledLeft = math.max(0, owner.ruffledUntil - now)
	st.shieldLeft = math.max(0, owner.shieldUntil - now)
	st.shieldReadyIn = math.max(0, owner.shieldReadyAt - now)
	return st
end

-- Short status for the sign over the base pad. Returns text, protected, domeKind.
function Protection.statusText(owner)
	local st = Protection.state(owner)
	if st.shieldLeft > 0 then
		return "🛡️ Bubble Shield " .. Format.time(st.shieldLeft), true, "Shield"
	elseif st.arrival then
		return "💠 Arrival Bubble", true, "Arrival"
	elseif st.newStacker then
		return "🌱 New Stacker", true, "NewStacker"
	elseif st.napping then
		return "💤 Napping", true, "Nap"
	elseif st.ruffledLeft > 0 then
		return "🐤 Ruffled Feathers " .. Format.time(st.ruffledLeft), true, "Ruffled"
	end
	return "", false, nil
end

-- Can `snatcher` start a snatch on `target`'s tower? Returns ok, reason, usesTicket.
function Protection.canSnatch(target, snatcher)
	if target == snatcher then
		return false, "That's your own tower, silly!"
	end
	if #target.data.tower == 0 then
		return false, "There's nothing on that tower to snatch!"
	end
	if target.host and target.host.toppling then
		return false, "That tower is still bouncing back!"
	end
	local st = Protection.state(target)
	if st.arrival then
		return false, "They just arrived - their Arrival Bubble is up!"
	end
	if st.newStacker then
		return false, "They're a New Stacker - protected for now!"
	end
	if st.napping then
		return false, "Shh! That tower is napping."
	end
	if st.ruffledLeft > 0 then
		return false, "That tower's feathers are still ruffled (" .. Format.time(st.ruffledLeft) .. ")."
	end
	local usesTicket = false
	local ticket = snatcher.ticket
	if ticket and ticket.targetKey == target.key and ticket.expires > Util.now() then
		usesTicket = true
	end
	if st.shieldLeft > 0 and not usesTicket then
		return false, "Their Bubble Shield is up!"
	end
	local myHeight = #snatcher.data.tower
	if not snatcher.devNoProtection and not Economy.inFairRange(myHeight, #target.data.tower) then
		local lo, hi = Economy.fairRange(myHeight)
		return false, string.format("Out of your Fair Snatch Range (towers %d-%d tall).", lo, hi)
	end
	return true, nil, usesTicket
end

function Protection.activateShield(owner)
	local now = Util.now()
	if owner.shieldUntil > now then
		S.Sync.notify(owner, "Your Bubble Shield is already up!", "info")
		return
	end
	if now < owner.shieldReadyAt then
		S.Sync.notify(owner, "Bubble Shield is recharging (" .. Format.time(owner.shieldReadyAt - now) .. ").", "info", "Lou the Locksmith")
		return
	end
	local level = Economy.upgradeLevel(owner.data, "Shield")
	owner.shieldUntil = now + level.Duration
	owner.shieldReadyAt = owner.shieldUntil + level.Recharge
	Protection.markActive(owner)
	S.Sync.notify(owner, string.format("Bubble Shield up for %d seconds!", level.Duration), "good", "Lou the Locksmith")
	S.Sync.effectAll({ kind = "Shield", key = owner.key, plot = owner.plot and owner.plot.index })
	S.Onboarding.onShield(owner)
	Protection.refreshVisuals(owner, true)
	S.Sync.markDirty(owner)
end

function Protection.refreshVisuals(owner, force: boolean?)
	local text, _, kind = Protection.statusText(owner)
	local height = #owner.data.tower
	if force or text ~= owner.lastStatus or kind ~= owner.lastDomeKind or height ~= owner.lastDomeHeight then
		owner.lastStatus = text
		owner.lastDomeKind = kind
		owner.lastDomeHeight = height
		S.Towers.setDome(owner, kind)
		S.Plots.refreshPlot(owner)
	end
end

local function tick()
	local now = Util.now()
	for _, owner in S.Plots.all() do
		if owner.player then
			local _, hrp = Util.character(owner.player)
			if hrp then
				local pos = hrp.Position
				if owner.joinPos and not owner.moved and Util.flatDistance(pos, owner.joinPos) > 6 then
					owner.moved = true
					S.Sync.markDirty(owner)
				end
				if owner.lastPos and (pos - owner.lastPos).Magnitude > 0.5 then
					owner.lastActive = now
				end
				owner.lastPos = pos
			end
			local napping = now - owner.lastActive > P.NapAfterSeconds
			if napping ~= owner.napping then
				owner.napping = napping
				if not napping then
					S.Sync.notify(owner, "Your tower woke up!", "info")
				end
				S.Sync.markDirty(owner)
			end
		end
		Protection.refreshVisuals(owner)
	end

	-- Sneaky Pete's friendly heads-up when someone wanders up to your tower.
	for _, owner in S.Plots.all() do
		if owner.player and owner.plot and #owner.data.tower > 0 then
			for _, other in Players:GetPlayers() do
				if other ~= owner.player and not owner.friends[other.UserId] then
					local _, hrp = Util.character(other)
					if hrp and Util.flatDistance(hrp.Position, owner.plot.center) < P.IntruderNoticeRange then
						local key = owner.key .. ":" .. other.UserId
						if Util.throttle(intruderNotices, key, P.IntruderNoticeCooldown) then
							S.Sync.notify(owner, other.DisplayName .. " is eyeing your tower!", "warn", "Sneaky Pete")
						end
					end
				end
			end
		end
	end
end

function Protection.init(services)
	S = services
	Remotes.get("ActivateShield").OnServerEvent:Connect(function(player)
		local owner = S.Plots.get(player)
		if owner then
			Protection.activateShield(owner)
		end
	end)
end

function Protection.start()
	while true do
		task.wait(0.5)
		local ok, err = pcall(tick)
		if not ok then
			warn("[Protection]", err)
		end
	end
end

return Protection
