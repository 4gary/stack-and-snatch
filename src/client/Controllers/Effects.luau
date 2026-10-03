--[[
	Effects: the signature sounds and silly visuals (design doc 3.3).

	  Stack "boop" (pitch rises with height)   Topple "wheeee" + "ta-da!"
	  Snatch "FWIP!"   Boop glove   Dizzy stars   Emote bubbles   Confetti
	  Coin pops over towers   Sprinkle Rain   Fluff-O-Matic sneezes
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModel = require(Shared.CreatureModel)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Effects = {}

local C
local State
Effects.calm = false
local shakeUntil = 0

local function plotModel(index: number?)
	if not index or index == 0 then
		return nil
	end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function towerTop(model: Instance?): Vector3?
	if not model then
		return nil
	end
	local plate = model:FindFirstChild("Plate")
	if not plate then
		return nil
	end
	return Vector3.new(plate.Position.X, Config.Map.PlateTopY + (model:GetAttribute("TowerHeight") or 0), plate.Position.Z)
end

local function characterOf(userId: number?)
	local player = userId and Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return character, character and character:FindFirstChild("HumanoidRootPart")
end

local function anchorAt(position: Vector3, life: number): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = workspace.CurrentCamera
	Debris:AddItem(part, life)
	return part
end

-- Floating text that rises and fades ("FWIP!", "+12", "Wheeee!").
function Effects.popText(position: Vector3, text: string, color: Color3?, size: number?, life: number?)
	life = life or 1.4
	local part = anchorAt(position, life + 0.1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size or 8, (size or 8) * 0.3)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Kit.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 240, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 35, 80)
	label.Parent = gui
	gui.Parent = part
	TweenService:Create(part, TweenInfo.new(life), { Position = position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

local function burst(position: Vector3, colors: { Color3 }, count: number)
	local part = anchorAt(position, 3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	emitter.Color = ColorSequence.new(keys)
	emitter.Parent = part
	emitter:Emit(count)
end

local CONFETTI = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(110, 210, 255),
	Color3.fromRGB(150, 230, 120),
	Color3.fromRGB(190, 130, 255),
}

local function billboardOn(adornee: BasePart, text: string, offset: number, life: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Kit.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 35, 80)
	label.Parent = gui
	gui.Parent = adornee
	Debris:AddItem(gui, life)
	return gui
end

local function boopGlove(hrp: BasePart)
	local glove = Instance.new("Part")
	glove.Shape = Enum.PartType.Ball
	glove.Size = Vector3.new(3, 3, 3)
	glove.Color = Color3.fromRGB(255, 120, 170)
	glove.Material = Enum.Material.SmoothPlastic
	glove.Anchored = true
	glove.CanCollide = false
	glove.CanQuery = false
	glove.CanTouch = false
	local start = hrp.CFrame * CFrame.new(0, 0.5, -1.5)
	glove.CFrame = start
	glove.Parent = workspace.CurrentCamera
	TweenService:Create(glove, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = hrp.CFrame * CFrame.new(0, 0.5, -6),
		Size = Vector3.new(5, 5, 5),
	}):Play()
	task.delay(0.2, function()
		TweenService:Create(glove, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(glove, 0.5)
end

local function hopHome(from: Vector3, to: Vector3, creatureId: string)
	local model = CreatureModel.build(creatureId, nil, { ghost = true })
	if not model then
		return
	end
	model.Parent = workspace.CurrentCamera
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / 0.9)
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 18, 0)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 8, 0))
		if t >= 1 then
			conn:Disconnect()
			model:Destroy()
		end
	end)
end

local HANDLERS = {}

function HANDLERS.Stack(e)
	local pos = towerTop(plotModel(e.plot))
	local height = e.height or 1
	C.Sound.play("Stack", { pitch = math.clamp(0.8 + height * 0.03, 0.8, 2.2), position = pos })
	if pos then
		Effects.popText(pos + Vector3.new(0, 2, 0), "boop!", Color3.fromRGB(150, 255, 170), 5)
		if e.confetti then
			burst(pos, CONFETTI, 60)
		end
	end
end

function HANDLERS.Topple(e)
	local model = e.practice and workspace.Map:FindFirstChild("PracticeTower") or plotModel(e.plot)
	local pos = model and model:FindFirstChild("Plate") and model.Plate.Position + Vector3.new(0, 8, 0)
	C.Sound.play("Topple", { position = pos })
	if pos then
		Effects.popText(pos + Vector3.new(0, 6, 0), "Wheeeee!", Color3.fromRGB(255, 200, 120), 10, 2)
	end
	if State.data and e.plot == State.data.plotIndex and not Effects.calm then
		shakeUntil = os.clock() + 0.6
	end
end

function HANDLERS.Restack(e)
	local pos = typeof(e.pos) == "Vector3" and e.pos or nil
	C.Sound.play("Restack", { pitch = 1.2, position = pos })
	if pos then
		Effects.popText(pos + Vector3.new(0, 8, 0), "Ta-da!", Color3.fromRGB(180, 255, 200), 7, 1.6)
	end
end

function HANDLERS.Snatch(e)
	local _, hrp = characterOf(e.userId)
	C.Sound.play("Snatch", { position = hrp and hrp.Position })
	if hrp then
		Effects.popText(hrp.Position + Vector3.new(0, 5, 0), "FWIP!", Color3.fromRGB(255, 240, 120), 8)
	end
end

function HANDLERS.SnatchHome(e)
	local _, hrp = characterOf(e.userId)
	if hrp then
		Effects.popText(hrp.Position + Vector3.new(0, 6, 0), "Snatched!", Color3.fromRGB(255, 200, 120), 8)
		burst(hrp.Position, CONFETTI, 30)
	end
end

function HANDLERS.Boop(e)
	local _, hrp = characterOf(e.userId)
	if hrp then
		boopGlove(hrp)
		C.Sound.play("Boop", { pitch = 1.4, position = hrp.Position })
		Effects.popText(hrp.Position + Vector3.new(0, 5, 0), "BOOP!", Color3.fromRGB(255, 140, 190), 6, 0.8)
	end
end

function HANDLERS.Knockback(e)
	local hrp = State.rootPart()
	if hrp and typeof(e.dir) == "Vector3" then
		hrp.AssemblyLinearVelocity = e.dir
	end
end

function HANDLERS.HopHome(e)
	local to = towerTop(plotModel(e.plot))
	if to and typeof(e.from) == "Vector3" and e.id then
		hopHome(e.from, to, e.id)
	end
end

function HANDLERS.Dizzy(e)
	local _, hrp = characterOf(e.userId)
	if hrp then
		billboardOn(hrp, "💫 💫 💫", 4, Config.Snatch.StunSeconds)
	end
end

function HANDLERS.Emote(e)
	local _, hrp = characterOf(e.userId)
	if hrp then
		local gui = billboardOn(hrp, e.text or "", 5.5, 3)
		gui.Size = UDim2.fromScale(7, 1.8)
		local label = gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.BackgroundTransparency = 0
			label.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
			label.TextColor3 = Color3.fromRGB(90, 50, 100)
			label.TextStrokeTransparency = 1
			Kit.corner(12).Parent = label
		end
	end
end

function HANDLERS.Sneeze(e)
	local chimney = workspace:FindFirstChild("Map")
		and workspace.Map:FindFirstChild("FluffOMatic")
		and workspace.Map.FluffOMatic:FindFirstChild("Chimney")
	local puff = chimney and chimney:FindFirstChild("SneezePuff")
	if puff then
		puff:Emit(12)
	end
	if e.rarity and e.rarity ~= "Common" and e.rarity ~= "Uncommon" and chimney then
		C.Sound.play("Sneeze", { position = chimney.Position })
		Effects.popText(chimney.Position + Vector3.new(0, 6, 0), "AH-CHOO!", Color3.fromRGB(255, 220, 240), 10)
	end
end

function HANDLERS.Shield(e)
	local pos = towerTop(plotModel(e.plot))
	C.Sound.play("Rare", { pitch = 0.8, position = pos })
end

function HANDLERS.Ribbon(e)
	local pos = towerTop(plotModel(e.plot))
	if pos then
		burst(pos, CONFETTI, 80)
		Effects.popText(pos + Vector3.new(0, 4, 0), "🎀 " .. tostring(e.height) .. " TALL!", Color3.fromRGB(255, 200, 230), 12, 3)
	end
	C.Sound.play("Rare", { pitch = 1.5, position = pos })
end

function HANDLERS.Alarm(e)
	local pos = towerTop(plotModel(e.plot))
	C.Sound.play("Rare", { pitch = 2, volume = 0.7, position = pos })
	if pos then
		Effects.popText(pos + Vector3.new(0, 3, 0), "Tweeeeet!", Color3.fromRGB(150, 240, 220), 8)
	end
end

function HANDLERS.Quest()
	C.Sound.play("Rare", { pitch = 1.6 })
end

function HANDLERS.Upgrade()
	C.Sound.play("Rare", { pitch = 1.2 })
end

function HANDLERS.Buy(e)
	local _, hrp = characterOf(e.userId)
	C.Sound.play("Coin", { pitch = 1.4, position = hrp and hrp.Position })
end

function HANDLERS.Scoop(e)
	local _, hrp = characterOf(e.userId)
	if hrp then
		Effects.popText(hrp.Position + Vector3.new(0, 5, 0), e.ok and "Scooped!" or "Boing!", nil, 6)
	end
	C.Sound.play(e.ok and "Stack" or "Wobble", { pitch = e.ok and 1.6 or 0.8, position = hrp and hrp.Position })
end

function HANDLERS.Hop(e)
	local _, hrp = characterOf(e.userId)
	C.Sound.play("Wobble", { pitch = 1.5, position = hrp and hrp.Position })
end

-- Coin pops over nearby towers ------------------------------------------------------------
local function coinPops()
	local plots = workspace:FindFirstChild("Plots")
	local camera = workspace.CurrentCamera
	if not plots or not camera then
		return
	end
	for _, plot in plots:GetChildren() do
		local rate = plot:GetAttribute("Rate") or 0
		local pos = towerTop(plot)
		if rate > 0 and pos and (pos - camera.CFrame.Position).Magnitude < 160 and not plot:GetAttribute("Toppling") then
			Effects.popText(pos + Vector3.new(0, 1.5, 0), "+" .. Format.number(rate * Config.Economy.CoinPopEvery), Color3.fromRGB(255, 220, 80), 4, 1.2)
		end
	end
end

-- Sprinkle Rain -----------------------------------------------------------------------------
local weatherPart: BasePart? = nil
local function updateWeather()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local active = gs and gs:GetAttribute("WeatherActive") == true
	if active and not weatherPart then
		local part = Instance.new("Part")
		part.Name = "SprinkleRain"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(120, 1, 120)
		part.Parent = workspace.CurrentCamera
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 220
		emitter.Lifetime = NumberRange.new(2.5, 3.5)
		emitter.Speed = NumberRange.new(20, 30)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Size = NumberSequence.new(0.35)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-150, 150)
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CONFETTI[1]),
			ColorSequenceKeypoint.new(0.25, CONFETTI[2]),
			ColorSequenceKeypoint.new(0.5, CONFETTI[3]),
			ColorSequenceKeypoint.new(0.75, CONFETTI[4]),
			ColorSequenceKeypoint.new(1, CONFETTI[5]),
		})
		emitter.Parent = part
		weatherPart = part
	elseif not active and weatherPart then
		weatherPart:Destroy()
		weatherPart = nil
	end
end

function Effects.init(controllers)
	C = controllers
	State = C.State
	Remotes.get("Effect").OnClientEvent:Connect(function(e)
		local handler = type(e) == "table" and HANDLERS[e.kind]
		if handler then
			local ok, err = pcall(handler, e)
			if not ok then
				warn("[Effects]", e.kind, err)
			end
		end
	end)
end

function Effects.start()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if weatherPart and camera then
			weatherPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
		end
		if camera and os.clock() < shakeUntil then
			local k = (shakeUntil - os.clock()) * 0.6
			camera.CFrame = camera.CFrame * CFrame.new(math.random(-10, 10) / 100 * k, math.random(-10, 10) / 100 * k, 0)
		end
	end)
	local t = 0
	while true do
		task.wait(0.5)
		t += 0.5
		pcall(updateWeather)
		if t % Config.Economy.CoinPopEvery < 0.5 then
			pcall(coinPops)
		end
	end
end

return Effects
