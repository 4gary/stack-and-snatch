--[[
	Onboarding: the first 3 minutes (design doc 4.8). Fast, funny, hands-on.

	  1  Professor: free Pancake Pup -> pop it on your plate
	  2  Professor: coins for two more -> buy from Captain Conveyor, reach 3 tall
	  3  Sneaky Pete: try the practice tower -> then he topples it on purpose
	  4  Lou: first Bubble Shield upgrade is free -> tap the shield
	  99 done: starter quests open up

	New Stacker Protection is on the whole time, so nobody can snatch from you.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Onboarding = {}

local S
local DONE = 99

local STEPS = {
	[1] = {
		npc = "Professor Puddlewick",
		text = "Oh dear, oh my, oh science! The Fluff-O-Matic sneezed! Here, catch this Pancake Pup! Now stand on your base pad and tap DROP when it's centered over your plate.",
		arrow = "plate",
	},
	[2] = {
		npc = "Professor Puddlewick",
		text = "See? Happy Stackables make Giggle Coins! Here are some coins - grab two more from Captain Conveyor's belt and stack them. Taller tower = more coins!",
		arrow = "conveyor",
	},
	[3] = {
		npc = "Sneaky Pete",
		text = "Psst! Want to learn the Snatch? Try my practice tower in the plaza. Hold, pull gently, and keep the dot in the ring!",
		arrow = "practice",
	},
	[4] = {
		npc = "Lou the Locksmith",
		text = "Tap the Bubble Shield... to keep your tower... safe. ...First upgrade's on me.",
		arrow = "shield",
	},
}

local function send(owner)
	local step = owner.data.tutorial
	local info = STEPS[step]
	if not info then
		return
	end
	local progress = nil
	if step == 2 then
		progress = string.format("Tower: %d / 3 tall", #owner.data.tower)
	end
	S.Sync.dialog(owner, {
		step = step,
		npc = info.npc,
		text = info.text,
		arrow = info.arrow,
		progress = progress,
		canSkip = true,
	})
end

local function setStep(owner, step: number)
	owner.data.tutorial = step
	S.Sync.markDirty(owner)
	if step == DONE then
		local lines = {}
		for _, q in Config.Quests do
			table.insert(lines, "• " .. q.Text)
		end
		S.Sync.dialog(owner, {
			step = DONE,
			npc = "Mayor Marshmallow",
			text = "By the power of fluff, I declare you a Stacker! Try these starter quests:\n" .. table.concat(lines, "\n"),
			final = true,
		})
	else
		send(owner)
	end
end

local function givePup(owner)
	local data = owner.data
	if #data.tower == 0 and not data.held and #data.box == 0 then
		S.Stacking.give(owner, S.Stacking.newEntry("PancakePup", nil), "gift")
	end
end

function Onboarding.onOwnerAdded(owner)
	if owner.isBot then
		return
	end
	local data = owner.data
	if data.tutorial >= DONE then
		return
	end
	if data.tutorial < 1 then
		data.tutorial = 1
	end
	task.delay(1.5, function()
		if S.Plots.byKey[owner.key] ~= owner then
			return
		end
		if data.tutorial == 1 then
			givePup(owner)
		end
		send(owner)
	end)
end

function Onboarding.resend(owner)
	if owner.data.tutorial > 0 and owner.data.tutorial < DONE then
		send(owner)
	end
end

function Onboarding.onPlaced(owner)
	local data = owner.data
	if data.tutorial == 1 and #data.tower >= 1 then
		data.coins += Config.Economy.TutorialCoinGift
		setStep(owner, 2)
	elseif data.tutorial == 2 then
		if #data.tower >= 3 then
			setStep(owner, 3)
		else
			send(owner)
		end
	end
end

function Onboarding.onBought(owner)
	if owner.data.tutorial == 2 then
		S.Sync.notify(owner, "Now carry it home and DROP it on your tower!", "info", "Professor Puddlewick")
	end
end

function Onboarding.onPracticeSnatch(owner, success: boolean)
	if owner.data.tutorial ~= 3 then
		return
	end
	if success then
		task.delay(1.5, function()
			S.Practice.demoTopple()
			S.Sync.notify(owner, "Whoops! See? They all hop home. No harm done! Getting snatched is part of the game.", "info", "Sneaky Pete")
		end)
	end
	task.delay(3.5, function()
		if owner.data.tutorial ~= 3 then
			return
		end
		if owner.data.upgrades.Shield < 2 then
			owner.data.upgrades.Shield = 2
		end
		setStep(owner, 4)
	end)
end

function Onboarding.onShield(owner)
	if owner.data.tutorial == 4 then
		setStep(owner, DONE)
	end
end

function Onboarding.skip(owner)
	local data = owner.data
	if data.tutorial >= DONE then
		return
	end
	if data.tutorial <= 1 then
		givePup(owner)
		data.coins += Config.Economy.TutorialCoinGift
	end
	setStep(owner, DONE)
end

function Onboarding.init(services)
	S = services
	Remotes.get("Tutorial").OnServerEvent:Connect(function(player, action)
		local owner = S.Plots.get(player)
		if not owner then
			return
		end
		if action == "skip" then
			Onboarding.skip(owner)
		end
	end)
end

return Onboarding
