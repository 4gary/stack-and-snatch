--[[
	Animator: makes the world feel alive and wobbly (client-side only).

	  Towers     jiggle like jelly, more when the tower is wobblier; new creatures
	             drop in with a squash; Toastie hops; Disco Ball Bat spins;
	             Lord Jellington makes the whole tower dance
	  Conveyor   creatures ride the belt smoothly (ConveyorPath + server time)
	  Meadows    wild creatures bounce in place

	The server owns where everything really is; this only moves local copies.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ConveyorPath = require(Shared.ConveyorPath)

local Animator = {}

local C
local State
Animator.calm = false

local seen = {} -- [model] = first time this client saw it (for drop-in animation)
local initialized = false

local function rootOf(model: Instance): BasePart?
	return model:FindFirstChild("Root") :: BasePart?
end

local function dropOffset(model: Model, now: number): number
	local first = seen[model]
	if not first then
		seen[model] = initialized and now or -100
		first = seen[model]
	end
	local t = now - first
	if t >= 0.45 then
		return 0
	end
	-- fall from 4 studs with a little bounce
	if t < 0.3 then
		local k = t / 0.3
		return 4 * (1 - k * k)
	end
	return math.sin((t - 0.3) / 0.15 * math.pi) * 0.35
end

local function animateTower(towerFolder: Instance, plotModel: Instance, now: number, camPos: Vector3)
	if plotModel:GetAttribute("Toppling") then
		return
	end
	local children = towerFolder:GetChildren()
	local n = #children
	if n == 0 then
		return
	end
	local first = rootOf(children[1])
	if first and (first.Position - camPos).Magnitude > 420 then
		return
	end
	local wobble = plotModel:GetAttribute("Wobble") or 0
	local yaw = plotModel:GetAttribute("BaseYaw") or 0
	local basis = CFrame.Angles(0, yaw, 0)
	local right = basis.RightVector
	local back = basis.LookVector

	local dance = false
	for _, model in children do
		if model:GetAttribute("CreatureId") == "LordJellington" then
			dance = true
			break
		end
	end
	local amp = (0.12 + math.clamp(wobble, 0, 1.2) * 1.1) * (dance and 1.6 or 1) * (Animator.calm and 0.4 or 1)
	local speed = dance and 5.5 or 3.6

	for _, model in children do
		local root = rootOf(model)
		local basePos = model:GetAttribute("BasePos")
		local layer = model:GetAttribute("Layer") or 1
		if root and basePos then
			local h = layer / math.max(n, 1)
			local sway = amp * h ^ 1.5 * math.sin(now * speed + layer * 0.18)
			local swayZ = amp * 0.4 * h ^ 1.5 * math.sin(now * speed * 0.7 + layer * 0.25)
			local y = dropOffset(model, now)
			local id = model:GetAttribute("CreatureId")
			local spin = 0
			if id == "Toastie" then
				local phase = (now + layer * 7) % 60
				if phase < 0.5 then
					y += math.sin(phase / 0.5 * math.pi) * 1.2
				end
			elseif id == "DiscoBallBat" then
				spin = now * 0.8
			elseif id == "BouncyBean" then
				y += math.abs(math.sin(now * 5 + layer)) * 0.15
			end
			local pos = basePos + right * sway + back * swayZ + Vector3.new(0, y, 0)
			root.CFrame = CFrame.new(pos) * basis * CFrame.Angles(0, spin, 0) * CFrame.Angles(swayZ * 0.04, 0, -sway * 0.06)
		end
	end
end

local function animateConveyor(now: number)
	local folder = workspace:FindFirstChild("Conveyor")
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		local root = rootOf(model)
		local spawnAt = model:GetAttribute("SpawnAt")
		if root and spawnAt then
			local elapsed = now - spawnAt
			local hop = math.abs(math.sin(elapsed * 4)) * 0.4
			root.CFrame = ConveyorPath.cframeAt(elapsed) * CFrame.new(0, hop, 0)
		end
	end
end

local function animateWild(now: number)
	local folder = workspace:FindFirstChild("Wild")
	if not folder then
		return
	end
	for i, model in folder:GetChildren() do
		local root = rootOf(model)
		local basePos = model:GetAttribute("BasePos")
		if root and basePos then
			local t = now + i * 1.7
			local hop = math.abs(math.sin(t * 3)) * 1.6
			local wander = Vector3.new(math.cos(t * 0.4) * 2, hop, math.sin(t * 0.4) * 2)
			root.CFrame = CFrame.new(basePos + wander) * CFrame.Angles(0, t * 0.4 + math.pi / 2, 0)
		end
	end
end

function Animator.init(controllers)
	C = controllers
	State = C.State
end

function Animator.start()
	task.delay(2, function()
		initialized = true
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = State.now()
		local ok, err = pcall(function()
			animateConveyor(now)
			animateWild(now)
			acc += dt
			if acc < 1 / 40 then
				return
			end
			acc = 0
			local camera = workspace.CurrentCamera
			local camPos = camera and camera.CFrame.Position or Vector3.zero
			local plots = workspace:FindFirstChild("Plots")
			if plots then
				for _, plot in plots:GetChildren() do
					local tower = plot:FindFirstChild("Tower")
					if tower then
						animateTower(tower, plot, now, camPos)
					end
				end
			end
			local map = workspace:FindFirstChild("Map")
			local practice = map and map:FindFirstChild("PracticeTower")
			if practice and practice:FindFirstChild("Tower") then
				animateTower(practice.Tower, practice, now, camPos)
			end
		end)
		if not ok then
			warn("[Animator]", err)
		end
	end)
	-- forget models that are gone
	while true do
		task.wait(10)
		for model in seen do
			if not model.Parent then
				seen[model] = nil
			end
		end
	end
end

return Animator
