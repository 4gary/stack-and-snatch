--[[
	Stack & Snatch - client entry point.

	Starts every controller. Controllers receive the shared table `C` in init()
	and look each other up at call time, so load order doesn't matter much.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Root = require(script.Parent.UI.Root)
local Kit = require(script.Parent.UI.Kit)

local ORDER = {
	"State",
	"Sound",
	"Panels",
	"Hud",
	"Notifications",
	"Dialog",
	"Placement",
	"Minigames",
	"Prompts",
	"Animator",
	"Effects",
}

local C = {}
for _, name in ORDER do
	C[name] = require(script.Parent.Controllers[name])
end

Root.init()

for _, name in ORDER do
	local controller = C[name]
	if controller.init then
		local ok, err = pcall(controller.init, C)
		if not ok then
			warn("[Client] init failed:", name, err)
		end
	end
end

-- Settings live in a panel module but must apply as soon as data arrives.
local Settings = require(script.Parent.Panels.Settings)
Settings.init(C)

Kit.clickSound = function()
	C.Sound.play("Click", { pitch = 1.6, volume = 0.2 })
end

for _, name in ORDER do
	local controller = C[name]
	if controller.start then
		task.spawn(function()
			local ok, err = pcall(controller.start)
			if not ok then
				warn("[Client] start failed:", name, err)
			end
		end)
	end
end

Remotes.get("ClientReady"):FireServer()
