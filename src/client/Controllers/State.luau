--[[
	State: the latest snapshot of *my* game state from the server, plus helpers
	for finding my base pad. Other controllers listen to State.changed.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local State = {}

State.data = nil -- last full snapshot (see server Sync.buildState)
State.changed = Signal.new() -- (data)
State.ticked = Signal.new() -- (data)
State.player = Players.LocalPlayer

function State.now(): number
	return workspace:GetServerTimeNow()
end

function State.plotModel(index: number?)
	index = index or (State.data and State.data.plotIndex)
	if not index or index == 0 then
		return nil
	end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

-- Bottom-center of a tower (top of the stacking plate), facing the plaza.
function State.originOf(model: Instance?): CFrame?
	if not model then
		return nil
	end
	local plate = model:FindFirstChild("Plate")
	if not plate then
		return nil
	end
	local yaw = model:GetAttribute("BaseYaw") or 0
	return CFrame.new(plate.Position.X, Config.Map.PlateTopY, plate.Position.Z) * CFrame.Angles(0, yaw, 0)
end

function State.myOrigin(): CFrame?
	return State.originOf(State.plotModel())
end

function State.rootPart(): BasePart?
	local character = State.player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function State.onOwnPad(): boolean
	local model = State.plotModel()
	local hrp = State.rootPart()
	if not model or not hrp or not model.PrimaryPart then
		return false
	end
	local center = model.PrimaryPart.Position
	local dx, dz = hrp.Position.X - center.X, hrp.Position.Z - center.Z
	return math.sqrt(dx * dx + dz * dz) <= Config.Map.PadRadius + 2 and hrp.Position.Y < Config.Map.PadTopY + 14
end

function State.init()
	Remotes.get("State").OnClientEvent:Connect(function(data)
		State.data = data
		State.changed:Fire(data)
	end)
	Remotes.get("Tick").OnClientEvent:Connect(function(tick)
		local data = State.data
		if not data then
			return
		end
		data.coins = tick.coins
		data.rate = tick.rate
		data.protection = tick.protection
		State.ticked:Fire(data)
	end)
end

return State
