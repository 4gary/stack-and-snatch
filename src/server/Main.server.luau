--[[
	Stack & Snatch - server entry point.

	Builds the world, creates the remotes, then starts every service.
	Services never require each other directly; they receive the shared
	`Services` table in init() and look each other up at call time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

Remotes.init()

local gameState = ReplicatedStorage:FindFirstChild("GameState") or Instance.new("Folder")
gameState.Name = "GameState"
gameState.Parent = ReplicatedStorage

local ORDER = {
	"Map",
	"Data",
	"Sync",
	"Towers",
	"Practice",
	"Plots",
	"Stacking",
	"Protection",
	"Progress",
	"Earnings",
	"Conveyor",
	"Meadows",
	"Snatch",
	"Shops",
	"Weather",
	"Social",
	"Onboarding",
	"Dev",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(script.Parent.Services[name])
end

for _, name in ORDER do
	local service = Services[name]
	if service.init then
		service.init(Services)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.start then
		task.spawn(service.start)
	end
end

print("[Stack & Snatch] server ready")
