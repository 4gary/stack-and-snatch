--[[
	Data: saving player progress (design doc 5.2 #8).

	Uses DataStore UpdateAsync with a session lock, so a player's data can only be
	open on one server at a time (prevents data loss and duplication). Every
	creature has a unique id and lives in exactly one place.

	In Studio, saving only works if the place is published and "Enable Studio
	Access to API Services" is on (Game Settings > Security). Without it the game
	still runs; progress just isn't saved, and the HUD says so.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Data = {}

local D = Config.Data
local store = nil
local storeDisabledReason = nil

Data.VERSION = 1

function Data.default()
	local cushions = {}
	for i = 1, Config.Protection.CushionSlots do
		cushions[i] = false
	end
	return {
		v = Data.VERSION,
		coins = 0,
		tower = {}, -- bottom to top: { u, id, m, x, z }
		box = {}, -- stored creatures: { u, id, m }
		cushions = cushions, -- unsnatchable favorites (false = empty slot)
		held = nil, -- creature in your hands
		transit = {}, -- snatched from you and still being carried away
		upgrades = { Glue = 1, Base = 1, Shield = 1 },
		index = {}, -- [creatureId] = { base = true, Sprinkled = true, ... }
		ribbons = {}, -- ["10"] = true
		quests = {}, -- [questId] = true
		playtime = 0,
		tutorial = 0, -- 0 = new, 1..4 = step, 99 = done
		lastOnline = 0,
		stats = { snatches = 0, snatched = 0, topples = 0, bought = 0, scooped = 0 },
		codes = {},
		settings = { calm = false, uiScale = 1, sfx = true },
	}
end

-- Fill in anything missing (older saves, new features).
function Data.reconcile(data: any)
	local fresh = Data.default()
	if type(data) ~= "table" then
		return fresh
	end
	for k, v in fresh do
		if data[k] == nil and k ~= "held" then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and (k == "upgrades" or k == "stats" or k == "settings") then
			for k2, v2 in v do
				if data[k][k2] == nil then
					data[k][k2] = v2
				end
			end
		end
	end
	for i = 1, Config.Protection.CushionSlots do
		if data.cushions[i] == nil then
			data.cushions[i] = false
		end
	end
	data.v = Data.VERSION
	return data
end

local function isStudioAccessError(message: string): boolean
	message = string.lower(message)
	return string.find(message, "studio", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
		or string.find(message, "api services", 1, true) ~= nil
		or string.find(message, "403", 1, true) ~= nil
end

function Data.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(D.StoreName)
	end)
	if ok then
		store = result
	else
		storeDisabledReason = tostring(result)
		warn("[Data] DataStores unavailable, progress will not save:", result)
	end
end

function Data.isPersistent(): boolean
	return store ~= nil
end

function Data.disabledReason(): string?
	return storeDisabledReason
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Load (and lock) a player's data. Yields. Returns data, canSave.
function Data.load(player: Player)
	if not store then
		return Data.reconcile(nil), false
	end
	for attempt = 1, D.LoadRetries do
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(record)
				record = record or {}
				local lock = record.lock
				if
					lock
					and lock.job ~= game.JobId
					and os.time() - (lock.time or 0) < D.SessionLockStale
					and attempt < D.LoadRetries
				then
					lockedElsewhere = true
					return nil -- cancel the write; try again shortly
				end
				loaded = record.data
				record.lock = { job = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and not lockedElsewhere then
			return Data.reconcile(loaded), true
		end
		if not ok then
			local message = tostring(err)
			if RunService:IsStudio() and isStudioAccessError(message) then
				warn("[Data] Studio can't reach DataStores (publish the place and enable API access to save):", message)
				storeDisabledReason = message
				store = nil
				return Data.reconcile(nil), false
			end
			warn(string.format("[Data] load attempt %d for %s failed: %s", attempt, player.Name, message))
		end
		task.wait(D.LoadRetryDelay)
	end
	-- Could not load safely: play with fresh data but never save over the real save.
	warn("[Data] giving up loading", player.Name, "- this session will not save")
	return Data.reconcile(nil), false
end

-- Save; `release` drops the session lock (on leave / shutdown). Yields.
function Data.save(player: Player, data: any, release: boolean?): boolean
	if not store then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.job ~= game.JobId and os.time() - (lock.time or 0) < D.SessionLockStale then
				return nil -- another server owns this data now; don't clobber it
			end
			record.data = data
			record.lock = (not release) and { job = game.JobId, time = os.time() } or nil
			return record
		end)
	end)
	if not ok then
		warn("[Data] save failed for", player.Name, err)
	end
	return ok
end

return Data
