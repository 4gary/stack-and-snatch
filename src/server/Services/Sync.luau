--[[
	Sync: sends each player their own state, plus notifications and effects.

	Full "State" snapshots go out when something changes (throttled); a light
	"Tick" goes out every second with coins, income and protection timers.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local Util = require(script.Parent.Parent.Util)

local Sync = {}

local S
local dirty = {}
local stateRemote, tickRemote, notifyRemote, effectRemote, dialogRemote

function Sync.markDirty(owner)
	if owner and owner.player then
		dirty[owner] = true
	end
end

local function protectionInfo(owner)
	local st = S.Protection.state(owner)
	return {
		arrival = st.arrival,
		arrivalLeft = st.arrivalLeft,
		moved = owner.moved,
		newStacker = st.newStacker,
		newStackerLeft = st.newStackerLeft,
		napping = st.napping,
		ruffledLeft = st.ruffledLeft,
		shieldLeft = st.shieldLeft,
		shieldReadyIn = st.shieldReadyIn,
		devNoProtection = owner.devNoProtection,
	}
end

function Sync.buildState(owner)
	local data = owner.data
	local ground = {}
	if owner.ground then
		for uid in owner.ground do
			table.insert(ground, uid)
		end
	end
	local carrying = nil
	if owner.carry then
		carrying = {
			id = owner.carry.entry.id,
			m = owner.carry.entry.m,
			fromName = owner.carry.from.name,
			started = owner.carry.start,
		}
	end
	local ticket = nil
	if owner.ticket then
		local target = S.Plots.byKey[owner.ticket.targetKey]
		ticket = {
			name = owner.ticket.targetName,
			expires = owner.ticket.expires,
			plot = target and target.plot and target.plot.index or 0,
		}
	end
	return {
		coins = data.coins,
		rate = Economy.totalRate(data, owner.napping),
		tower = data.tower,
		box = data.box,
		cushions = data.cushions,
		held = data.held,
		upgrades = data.upgrades,
		index = data.index,
		ribbons = data.ribbons,
		quests = data.quests,
		stats = data.stats,
		settings = data.settings,
		tutorial = data.tutorial,
		ground = ground,
		carrying = carrying,
		ticket = ticket,
		plotIndex = owner.plot and owner.plot.index or 0,
		canSave = owner.canSave,
		isStudio = RunService:IsStudio(),
		protection = protectionInfo(owner),
		toppling = owner.host and owner.host.toppling or false,
		inSession = owner.session ~= nil,
	}
end

function Sync.tick(owner, rate: number)
	if owner.player then
		tickRemote:FireClient(owner.player, {
			coins = owner.data.coins,
			rate = rate,
			protection = protectionInfo(owner),
			napping = owner.napping,
		})
	end
end

-- kind: "info" | "good" | "warn" | "rare" | "legendary"
function Sync.notify(owner, text: string, kind: string?, npc: string?)
	if owner and owner.player then
		notifyRemote:FireClient(owner.player, { text = text, kind = kind or "info", npc = npc })
	end
end

function Sync.notifyAll(text: string, kind: string?, npc: string?)
	notifyRemote:FireAllClients({ text = text, kind = kind or "info", npc = npc })
end

function Sync.effect(owner, payload)
	if owner and owner.player then
		effectRemote:FireClient(owner.player, payload)
	end
end

function Sync.effectAll(payload)
	effectRemote:FireAllClients(payload)
end

function Sync.dialog(owner, payload)
	if owner and owner.player then
		dialogRemote:FireClient(owner.player, payload)
	end
end

function Sync.init(services)
	S = services
	stateRemote = Remotes.get("State")
	tickRemote = Remotes.get("Tick")
	notifyRemote = Remotes.get("Notify")
	effectRemote = Remotes.get("Effect")
	dialogRemote = Remotes.get("Dialog")
	Remotes.get("ClientReady").OnServerEvent:Connect(function(player)
		local owner = S.Plots.get(player)
		if owner then
			Sync.markDirty(owner)
			S.Onboarding.resend(owner)
		end
	end)
	Remotes.get("SaveSettings").OnServerEvent:Connect(function(player, settings)
		local owner = S.Plots.get(player)
		if owner and type(settings) == "table" then
			local s = owner.data.settings
			if type(settings.calm) == "boolean" then
				s.calm = settings.calm
			end
			if type(settings.sfx) == "boolean" then
				s.sfx = settings.sfx
			end
			if type(settings.uiScale) == "number" and settings.uiScale == settings.uiScale then
				s.uiScale = math.clamp(settings.uiScale, 0.7, 1.4)
			end
		end
	end)
end

function Sync.start()
	while true do
		task.wait(0.15)
		for owner in dirty do
			dirty[owner] = nil
			if owner.player and owner.player.Parent and S.Plots.byKey[owner.key] == owner then
				local ok, err = pcall(function()
					stateRemote:FireClient(owner.player, Sync.buildState(owner))
				end)
				if not ok then
					warn("[Sync]", err)
				end
			end
		end
	end
end

-- Server time helper for other services.
Sync.now = Util.now

return Sync
