--[[
	Plots: who owns which base pad, and the join / leave flow.

	An "owner" is the runtime record for whoever is using a base pad: a real
	player, or (in Studio) a test bot. It holds the saved `data` plus session-only
	state like shield timers. Other services receive owners, never raw players.

	When you leave, your tower goes home with you (offline is fully safe).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Wobble = require(Shared.Wobble)
local Util = require(script.Parent.Parent.Util)

local Plots = {}

local S -- services table
Plots.byPlayer = {} -- [Player] = owner
Plots.byKey = {} -- [key] = owner
local loading = {} -- players whose data is still loading
local saving = {} -- [player] = true while the leave-save is running

local function newOwner(params)
	return {
		key = params.key,
		player = params.player,
		isBot = params.isBot or false,
		userId = params.userId,
		name = params.name,
		data = params.data,
		canSave = params.canSave or false,
		plot = nil,
		host = nil,
		-- session-only state
		joinTime = Util.now(),
		moved = false,
		joinPos = nil,
		lastPos = nil,
		lastActive = Util.now(),
		napping = false,
		shieldUntil = 0,
		shieldReadyAt = 0,
		ruffledUntil = 0,
		ticket = nil, -- Bounce-Back Ticket { targetKey, targetName, expires }
		carry = nil, -- creature this player is carrying away from someone's tower
		session = nil, -- active snatch / scoop minigame
		stunnedUntil = 0,
		friends = {},
		devNoProtection = false,
		heldModel = nil,
		lastHeight = 0,
	}
end

function Plots.get(player: Player)
	return Plots.byPlayer[player]
end

function Plots.all()
	return Plots.byKey
end

function Plots.ownerOfPlot(index: number)
	local plot = S.Map.plots[index]
	return plot and plot.owner
end

local function freePlot()
	for _, plot in S.Map.plots do
		if not plot.owner then
			return plot
		end
	end
	return nil
end

-- Is this owner's character standing on their own base pad?
function Plots.onOwnPad(owner, slack: number?): boolean
	if not owner.plot then
		return false
	end
	local _, hrp = Util.character(owner.player)
	if not hrp then
		return false
	end
	local dist = Util.flatDistance(hrp.Position, owner.plot.center)
	return dist <= Config.Map.PadRadius + (slack or 2) and hrp.Position.Y < Config.Map.PadTopY + 14
end

-- Refresh the attributes + sign that everyone sees for this plot.
function Plots.refreshPlot(owner)
	local plot = owner.plot
	if not plot then
		return
	end
	local data = owner.data
	local height = #data.tower
	local model = plot.model
	model:SetAttribute("Height", height)
	model:SetAttribute("Rate", Economy.totalRate(data, owner.napping))
	model:SetAttribute("Wobble", Wobble.ratio(data.tower, Economy.glueReduce(data)))
	model:SetAttribute("Glue", data.upgrades.Glue)
	local status, protected = S.Protection.statusText(owner)
	model:SetAttribute("Status", status)
	model:SetAttribute("Protected", protected)
	model:SetAttribute("ShieldUntil", owner.shieldUntil)

	local sign = plot.sign
	sign.Title.Text = owner.name .. "'s Tower"
	local ribbons = ""
	for _, h in Config.RibbonHeights do
		if data.ribbons[tostring(h)] then
			ribbons ..= "🎀"
		end
	end
	sign.Info.Text = string.format("%d tall · %s/s %s", height, Format.number(model:GetAttribute("Rate")), ribbons)
	sign.Status.Text = status
end

local function clearPlot(plot)
	plot.owner = nil
	local model = plot.model
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("Height", 0)
	model:SetAttribute("Rate", 0)
	model:SetAttribute("Wobble", 0)
	model:SetAttribute("ShieldUntil", 0)
	model:SetAttribute("Protected", false)
	model:SetAttribute("Status", "")
	model:SetAttribute("Toppling", false)
	plot.sign.Title.Text = "Empty Base Pad"
	plot.sign.Info.Text = ""
	plot.sign.Status.Text = ""
	plot.matLabel.Text = "WELCOME"
	plot.dome.Transparency = 1
	plot.towerFolder:ClearAllChildren()
	plot.groundFolder:ClearAllChildren()
	plot.cushionFolder:ClearAllChildren()
end

local function assignPlot(owner, plot)
	owner.plot = plot
	plot.owner = owner
	plot.model:SetAttribute("OwnerUserId", owner.userId)
	plot.model:SetAttribute("OwnerName", owner.name)
	plot.matLabel.Text = "WELCOME, " .. string.upper(owner.name) .. "!"
	owner.host = S.Towers.newHost({
		key = owner.key,
		origin = plot.origin,
		folder = plot.towerFolder,
		attributeTarget = plot.model,
		getEntries = function()
			return owner.data.tower
		end,
		getGlue = function()
			return Economy.glueReduce(owner.data)
		end,
	})
	S.Towers.refresh(owner.host)
	S.Towers.renderCushions(owner)
	S.Towers.renderGround(owner)
	Plots.refreshPlot(owner)
end

local function setupLeaderstats(owner)
	local player = owner.player
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local height = Instance.new("IntValue")
	height.Name = "Height"
	height.Value = #owner.data.tower
	height.Parent = stats
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = Format.number(owner.data.coins)
	coins.Parent = stats
	stats.Parent = player
end

function Plots.updateLeaderstats(owner)
	if not owner.player then
		return
	end
	local stats = owner.player:FindFirstChild("leaderstats")
	if stats then
		stats.Height.Value = #owner.data.tower
		stats.Coins.Value = Format.number(owner.data.coins)
	end
end

-- Move a character to its base pad.
function Plots.sendHome(owner)
	if not owner.plot then
		return
	end
	local character, hrp = Util.character(owner.player)
	if character and hrp then
		character:PivotTo(owner.plot.spawnCF)
	end
end

local function onCharacterAdded(owner, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not hrp or not humanoid or Plots.byKey[owner.key] ~= owner then
		return
	end
	task.defer(function()
		if owner.plot and character.Parent then
			character:PivotTo(owner.plot.spawnCF)
		end
		owner.joinPos = owner.joinPos or owner.plot and owner.plot.spawnCF.Position
		S.Stacking.attachHeld(owner)
	end)
	humanoid.Died:Connect(function()
		S.Snatch.onCarrierLost(owner, "fell over")
	end)
end

local function returnTransit(owner)
	-- Creatures that were being carried away when we last left come home to the box.
	local data = owner.data
	if #data.transit > 0 then
		for _, entry in data.transit do
			table.insert(data.box, { u = entry.u, id = entry.id, m = entry.m })
		end
		data.transit = {}
		return true
	end
	return false
end

local function offlineEarnings(owner)
	local data = owner.data
	if data.lastOnline and data.lastOnline > 0 then
		local away = math.min(os.time() - data.lastOnline, Config.Economy.OfflineMaxSeconds)
		if away > 60 then
			local earned = math.floor(Economy.totalRate(data) * Config.Economy.OfflineIncomeMultiplier * away)
			if earned > 0 then
				data.coins += earned
				return earned
			end
		end
	end
	return 0
end

local function onPlayerAdded(player: Player)
	if loading[player] or Plots.byPlayer[player] then
		return
	end
	loading[player] = true
	local data, canSave = S.Data.load(player)
	loading[player] = nil
	if not player.Parent then
		if canSave then
			S.Data.save(player, data, true)
		end
		return
	end

	local owner = newOwner({
		key = "u" .. player.UserId,
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		data = data,
		canSave = canSave,
	})
	local cameHome = returnTransit(owner)
	local earned = offlineEarnings(owner)

	Plots.byPlayer[player] = owner
	Plots.byKey[owner.key] = owner
	setupLeaderstats(owner)

	local plot = freePlot()
	if plot then
		assignPlot(owner, plot)
	end

	S.Protection.onOwnerAdded(owner)
	S.Social.onOwnerAdded(owner)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(owner, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, owner, player.Character)
	end

	S.Sync.markDirty(owner)
	S.Onboarding.onOwnerAdded(owner)

	task.delay(2, function()
		if not plot then
			S.Sync.notify(owner, "All 8 base pads are taken! Try another server.", "warn")
		end
		if earned > 0 then
			S.Sync.notify(owner, "You earned " .. Format.number(earned) .. " Giggle Coins while dreaming!", "good", "Professor Puddlewick")
		end
		if cameHome then
			S.Sync.notify(owner, "Your snatched creatures hopped home to your Box!", "good", "Sneaky Pete")
		end
		if not owner.canSave then
			S.Sync.notify(owner, "Progress isn't saving this session (Studio test without API access).", "warn")
		end
	end)
end

-- Remove an owner (player leaving, or a bot being cleared).
function Plots.removeOwner(owner)
	if Plots.byKey[owner.key] ~= owner then
		return
	end
	S.Snatch.onOwnerRemoving(owner)
	S.Meadows.onOwnerRemoving(owner)
	Plots.byKey[owner.key] = nil
	if owner.player then
		Plots.byPlayer[owner.player] = nil
	end
	local freed = owner.plot
	if owner.plot then
		clearPlot(owner.plot)
		owner.plot = nil
	end
	if owner.host then
		S.Towers.destroyHost(owner.host)
		owner.host = nil
	end
	-- Hand the free pad to someone who joined while every pad was taken.
	if freed then
		for _, waiting in Plots.byKey do
			if waiting.player and not waiting.plot then
				assignPlot(waiting, freed)
				Plots.sendHome(waiting)
				S.Sync.markDirty(waiting)
				S.Sync.notify(waiting, "A base pad opened up - it's yours now!", "good", "Bricklebee")
				break
			end
		end
	end
end

local function onPlayerRemoving(player: Player)
	local owner = Plots.byPlayer[player]
	if not owner then
		return
	end
	Plots.removeOwner(owner)
	owner.data.lastOnline = os.time()
	if owner.canSave then
		saving[player] = true
		S.Data.save(player, owner.data, true)
		saving[player] = nil
	end
end

-- Bots (Studio testing only): an owner with no player, so you can practice
-- snatching from a "real" tower when testing alone.
local botCount = 0
function Plots.addBot(entries)
	local plot = freePlot()
	if not plot then
		return nil
	end
	botCount += 1
	local data = S.Data.default()
	data.tower = entries
	data.tutorial = 99
	data.playtime = 99999
	local owner = newOwner({
		key = "bot" .. botCount,
		player = nil,
		isBot = true,
		userId = -1000 - botCount,
		name = "TestBot" .. botCount,
		data = data,
	})
	owner.moved = true
	Plots.byKey[owner.key] = owner
	assignPlot(owner, plot)
	return owner
end

function Plots.init(services)
	S = services
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	game:BindToClose(function()
		local pending = 0
		for player, owner in Plots.byPlayer do
			if owner.canSave then
				pending += 1
				owner.data.lastOnline = os.time()
				task.spawn(function()
					S.Data.save(player, owner.data, true)
					pending -= 1
				end)
			end
		end
		local start = os.clock()
		while (pending > 0 or next(saving) ~= nil) and os.clock() - start < 25 do
			task.wait(0.2)
		end
	end)
end

function Plots.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- autosave
	while true do
		task.wait(Config.Data.AutosaveInterval)
		for player, owner in Plots.byPlayer do
			if owner.canSave then
				owner.data.lastOnline = os.time()
				task.spawn(S.Data.save, player, owner.data, false)
			end
		end
	end
end

-- Save one owner right away (after important trades like a completed snatch).
function Plots.saveSoon(owner)
	if owner.player and owner.canSave then
		task.spawn(S.Data.save, owner.player, owner.data, false)
	end
end

return Plots
