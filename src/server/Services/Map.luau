--[[
	Map: builds Bumbleberry Bay at runtime (design doc 3.1).

	  Sneeze Plaza (center)   the Fluff-O-Matic, shops, Sneaky Pete's practice tower
	  Conveyor belt           Captain Conveyor's belt loops around the plaza
	  Muffin Meadows          sponge-cake hills where wild Stackables bounce
	  8 Base Pads             one per player, around the edge
	  Fizzy Shore             soda-water beach around the island

	Everything is built from simple parts so it can be swapped for real art later.
	Plot / stall / pegs parts are tagged with CollectionService so the client can
	add ProximityPrompts to them.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Map = {}

local M = Config.Map
local UP = CFrame.Angles(0, 0, math.pi / 2)

local PLOT_COLORS = {
	Color3.fromRGB(255, 140, 170),
	Color3.fromRGB(255, 190, 110),
	Color3.fromRGB(255, 230, 110),
	Color3.fromRGB(140, 220, 140),
	Color3.fromRGB(110, 210, 230),
	Color3.fromRGB(130, 160, 255),
	Color3.fromRGB(190, 140, 255),
	Color3.fromRGB(255, 150, 230),
}

-- Part helpers -------------------------------------------------------------------

local function part(parent: Instance, shape: string, size: Vector3, cf: CFrame, color: Color3, props: any?)
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function block(parent, size, cf, color, props)
	return part(parent, "Block", size, cf, color, props)
end

local function ball(parent, d, pos, color, props)
	return part(parent, "Ball", Vector3.new(d, d, d), CFrame.new(pos), color, props)
end

local function ellipsoid(parent, size, cf, color, props)
	return part(parent, "Ellipsoid", size, cf, color, props)
end

-- Vertical cylinder centered on cf.
local function vcyl(parent, diameter, height, cf, color, props)
	return part(parent, "Cylinder", Vector3.new(height, diameter, diameter), cf * UP, color, props)
end

local function billboard(adornee: BasePart, title: string, color: Color3, sizeX: number, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromScale(sizeX, 1.6)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(60, 40, 70)
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

local function polar(radius: number, angle: number, y: number): Vector3
	return Vector3.new(radius * math.cos(angle), y, radius * math.sin(angle))
end

-- Faces outward from the plaza center at the given angle.
local function outwardCF(radius: number, angle: number, y: number): CFrame
	local pos = polar(radius, angle, y)
	return CFrame.lookAt(pos, Vector3.new(pos.X * 2, y, pos.Z * 2))
end

-- NPCs -------------------------------------------------------------------------------

local SKIN = Color3.fromRGB(255, 214, 180)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(30, 25, 35)

local function eyes(parent, head: CFrame, headD: number, color: Color3?)
	for _, side in { -1, 1 } do
		local base = head * CFrame.new(side * headD * 0.18, headD * 0.08, -headD * 0.42)
		ball(parent, headD * 0.24, base.Position, color or WHITE)
		ball(parent, headD * 0.13, (base * CFrame.new(0, 0, -headD * 0.07)).Position, BLACK)
	end
end

local NpcBuilders = {}

function NpcBuilders.Professor(parent, cf)
	ellipsoid(parent, Vector3.new(3.2, 4.2, 2.6), cf * CFrame.new(0, 2.1, 0), WHITE)
	local head = cf * CFrame.new(0, 5, 0)
	ball(parent, 2.6, head.Position, SKIN)
	eyes(parent, head, 2.6)
	for k = -2, 2 do
		ball(parent, 0.9, (head * CFrame.new(k * 0.45, 1.1, 0.2)).Position, Color3.fromRGB(200, 200, 210))
	end
	for _, side in { -1, 1 } do -- goggles on backwards
		vcyl(parent, 0.8, 0.3, head * CFrame.new(side * 0.5, 0.25, 1.25) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(80, 200, 255))
	end
	block(parent, Vector3.new(2.7, 0.25, 0.25), head * CFrame.new(0, 0.25, 1.2), Color3.fromRGB(60, 60, 70))
end

function NpcBuilders.Gloop(parent, cf)
	ellipsoid(parent, Vector3.new(3.4, 4, 2.8), cf * CFrame.new(0, 2, 0), Color3.fromRGB(255, 160, 190))
	block(parent, Vector3.new(2.4, 2.6, 0.2), cf * CFrame.new(0, 2, -1.35), WHITE)
	for k = 1, 4 do
		ball(parent, 0.35, (cf * CFrame.new((k - 2.5) * 0.5, 1.3 + (k % 2) * 0.6, -1.5)).Position, Color3.fromRGB(200, 30, 70))
	end
	local head = cf * CFrame.new(0, 4.8, 0)
	ball(parent, 2.5, head.Position, SKIN)
	eyes(parent, head, 2.5)
	ball(parent, 1.4, (head * CFrame.new(0, 1.3, 0.3)).Position, Color3.fromRGB(220, 220, 230))
end

function NpcBuilders.Captain(parent, cf)
	local brown = Color3.fromRGB(160, 120, 95)
	ellipsoid(parent, Vector3.new(4.4, 4.2, 3.6), cf * CFrame.new(0, 2.1, 0), brown)
	local head = cf * CFrame.new(0, 4.9, -0.2)
	ellipsoid(parent, Vector3.new(3.2, 2.6, 2.8), head, brown)
	eyes(parent, head * CFrame.new(0, 0.3, 0), 2.6)
	ellipsoid(parent, Vector3.new(1.8, 0.9, 0.8), head * CFrame.new(0, -0.5, -1.2), Color3.fromRGB(230, 200, 180))
	for _, side in { -1, 1 } do
		vcyl(parent, 0.3, 1.4, head * CFrame.new(side * 0.4, -1.3, -1.2), WHITE)
	end
	vcyl(parent, 2.4, 0.6, head * CFrame.new(0, 1.4, 0), Color3.fromRGB(30, 50, 110))
	vcyl(parent, 1.8, 0.3, head * CFrame.new(0, 1.85, 0), WHITE)
end

function NpcBuilders.Lou(parent, cf)
	ellipsoid(parent, Vector3.new(2.2, 1.6, 5), cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(170, 220, 140))
	ball(parent, 3.4, (cf * CFrame.new(0, 2.6, 0.9)).Position, Color3.fromRGB(220, 150, 90))
	vcyl(parent, 1.6, 0.25, cf * CFrame.new(1.8, 2.6, 0.9) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 210, 60))
	local head = cf * CFrame.new(0, 2.2, -2)
	ball(parent, 1.8, head.Position, Color3.fromRGB(170, 220, 140))
	for _, side in { -1, 1 } do
		vcyl(parent, 0.2, 1.2, head * CFrame.new(side * 0.4, 1.2, 0), Color3.fromRGB(170, 220, 140))
		ball(parent, 0.5, (head * CFrame.new(side * 0.4, 1.9, -0.1)).Position, WHITE)
		ball(parent, 0.25, (head * CFrame.new(side * 0.4, 1.9, -0.35)).Position, BLACK)
	end
end

function NpcBuilders.Bee(parent, cf)
	local yellow = Color3.fromRGB(255, 215, 60)
	local body = cf * CFrame.new(0, 2.4, 0)
	ellipsoid(parent, Vector3.new(3, 3.6, 3), body, yellow)
	for k = -1, 1 do
		block(parent, Vector3.new(3.05, 0.4, 3.05), body * CFrame.new(0, k * 0.9 - 0.3, 0), BLACK, { Transparency = 0 })
	end
	for _, side in { -1, 1 } do
		ellipsoid(parent, Vector3.new(0.3, 2.2, 1.4), body * CFrame.new(side * 1.6, 0.8, 0.9) * CFrame.Angles(0, 0, side * 0.6), WHITE, { Transparency = 0.4 })
	end
	local head = cf * CFrame.new(0, 5, 0)
	ball(parent, 2.4, head.Position, yellow)
	eyes(parent, head, 2.4)
	ellipsoid(parent, Vector3.new(2.6, 1.3, 2.6), head * CFrame.new(0, 0.8, 0), Color3.fromRGB(255, 150, 40))
end

function NpcBuilders.Pete(parent, cf)
	local grey = Color3.fromRGB(150, 150, 160)
	ellipsoid(parent, Vector3.new(3, 3.8, 2.6), cf * CFrame.new(0, 1.9, 0), Color3.fromRGB(70, 90, 170))
	for k = -1, 1 do
		block(parent, Vector3.new(3.05, 0.35, 2.65), cf * CFrame.new(0, 1.9 + k * 0.8, 0), WHITE)
	end
	local head = cf * CFrame.new(0, 4.7, 0)
	ball(parent, 2.6, head.Position, grey)
	block(parent, Vector3.new(2.4, 0.6, 0.4), head * CFrame.new(0, 0.2, -1.05), BLACK)
	eyes(parent, head, 2.6)
	for _, side in { -1, 1 } do
		part(parent, "Wedge", Vector3.new(0.3, 0.9, 0.8), head * CFrame.new(side * 0.85, 1.2, 0) * CFrame.Angles(0, math.pi / 2, 0), grey)
	end
	-- striped tail
	for k = 0, 3 do
		ball(parent, 0.9, (cf * CFrame.new(0, 1 + k * 0.5, 1.6 + k * 0.4)).Position, k % 2 == 0 and grey or BLACK)
	end
end

function NpcBuilders.Frog(parent, cf)
	local green = Color3.fromRGB(120, 210, 100)
	ellipsoid(parent, Vector3.new(3.4, 3.4, 3), cf * CFrame.new(0, 1.7, 0), green)
	local head = cf * CFrame.new(0, 4, 0)
	ellipsoid(parent, Vector3.new(3, 2, 2.6), head, green)
	for _, side in { -1, 1 } do
		ball(parent, 1.1, (head * CFrame.new(side * 0.8, 1, -0.6)).Position, WHITE)
		ball(parent, 0.55, (head * CFrame.new(side * 0.8, 1, -1.05)).Position, BLACK)
		vcyl(parent, 1.2, 0.5, head * CFrame.new(side * 1.55, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), BLACK)
	end
	block(parent, Vector3.new(3.4, 0.3, 0.4), head * CFrame.new(0, 1.3, 0), BLACK)
end

function NpcBuilders.Mayor(parent, cf)
	vcyl(parent, 3.2, 4.2, cf * CFrame.new(0, 2.1, 0), WHITE)
	local head = cf * CFrame.new(0, 2.6, -1.4)
	eyes(parent, head, 2.4)
	vcyl(parent, 2.2, 0.25, cf * CFrame.new(0, 4.3, 0), BLACK)
	vcyl(parent, 1.6, 1.8, cf * CFrame.new(0, 5.3, 0), BLACK)
	block(parent, Vector3.new(1.65, 0.35, 1.65), cf * CFrame.new(0, 4.6, 0), Color3.fromRGB(220, 50, 80))
	ball(parent, 0.8, (cf * CFrame.new(0, 2.2, -1.65)).Position, Color3.fromRGB(255, 200, 40))
end

local NPCS = {
	{ Id = "Professor", Name = "Professor Puddlewick", Angle = 60, Color = Color3.fromRGB(150, 200, 255), Action = "Index", Prompt = "Open Index", Builder = "Professor" },
	{ Id = "Gloop", Name = "Grandma Gloop", Angle = 110, Color = Color3.fromRGB(255, 140, 170), Action = "Shop:Glue", Prompt = "Sticky Jam", Builder = "Gloop" },
	{ Id = "Bricklebee", Name = "Bricklebee", Angle = 160, Color = Color3.fromRGB(255, 200, 60), Action = "Shop:Base", Prompt = "Base upgrades", Builder = "Bee" },
	{ Id = "Lou", Name = "Lou the Locksmith", Angle = 210, Color = Color3.fromRGB(170, 220, 140), Action = "Shop:Shield", Prompt = "Bubble Shields", Builder = "Lou" },
	{ Id = "Pete", Name = "Sneaky Pete", Angle = 255, Color = Color3.fromRGB(150, 160, 230), Action = "Talk:Pete", Prompt = "Snatch tips", Builder = "Pete" },
	{ Id = "Mayor", Name = "Mayor Marshmallow", Angle = 310, Color = Color3.fromRGB(255, 240, 230), Action = "Talk:Mayor", Prompt = "Ribbons", Builder = "Mayor" },
	{ Id = "DJ", Name = "DJ Bonk", Angle = 25, Color = Color3.fromRGB(120, 210, 100), Action = "Emotes", Prompt = "Emotes", Builder = "Frog" },
}

local function buildStall(parent: Instance, spec)
	local model = Instance.new("Model")
	model.Name = spec.Id
	local angle = math.rad(spec.Angle)
	local front = outwardCF(28, angle, 0)
	-- counter
	local counter = block(model, Vector3.new(8, 3, 2.5), front * CFrame.new(0, 1.5, 0), spec.Color)
	counter.Name = "Counter"
	block(model, Vector3.new(8.4, 0.4, 3), front * CFrame.new(0, 3.2, 0), WHITE)
	-- awning on posts
	for _, side in { -1, 1 } do
		vcyl(model, 0.5, 8, front * CFrame.new(side * 3.8, 4, 2.5), WHITE)
	end
	for k = 0, 5 do
		block(
			model,
			Vector3.new(1.4, 0.4, 5.5),
			front * CFrame.new(-3.5 + k * 1.4, 8.2, 1.5) * CFrame.Angles(math.rad(-12), 0, 0),
			k % 2 == 0 and spec.Color or WHITE
		)
	end
	-- NPC stands behind the counter, facing out
	local npcCF = front * CFrame.new(0, 0, 3)
	NpcBuilders[spec.Builder](model, npcCF)
	billboard(counter, spec.Name, spec.Color, 12, 8.5)

	CollectionService:AddTag(counter, "NpcStall")
	counter:SetAttribute("Npc", spec.Id)
	counter:SetAttribute("NpcName", spec.Name)
	counter:SetAttribute("Action", spec.Action)
	counter:SetAttribute("PromptText", spec.Prompt)
	model.Parent = parent
	return model, front
end

-- Plots ------------------------------------------------------------------------------

local function buildPlot(parent: Instance, index: number)
	local angle = (index - 0.5) * 2 * math.pi / M.PlotCount
	local center = polar(M.PlotRingRadius, angle, 0)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local platePos = Vector3.new(center.X, M.PlateTopY, center.Z)
	local origin = CFrame.lookAt(platePos, Vector3.new(0, M.PlateTopY, 0)) -- -Z faces the plaza

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- pad, trim and plate
	local pad = vcyl(model, M.PadRadius * 2, 1, CFrame.new(center.X, M.PadTopY - 0.5, center.Z), Color3.fromRGB(170, 230, 140), {
		Material = Enum.Material.Grass,
		Name = "Pad",
	})
	vcyl(model, M.PadRadius * 2 + 2, 0.8, CFrame.new(center.X, M.PadTopY - 0.6, center.Z), color, { Name = "Trim" })
	vcyl(model, M.PlateRadius * 2, 0.6, CFrame.new(center.X, M.PlateTopY - 0.3, center.Z), Color3.fromRGB(255, 250, 240), { Name = "Plate" })
	vcyl(model, M.PlateRadius * 2 + 0.8, 0.4, CFrame.new(center.X, M.PlateTopY - 0.45, center.Z), color, { Name = "PlateRim" })

	-- climbing pegs on the plaza side of the tower (snatchers hop up from here)
	local pegs = block(model, Vector3.new(0.8, 5, 0.8), origin * CFrame.new(0, 1.9, -(M.PlateRadius + 0.8)), color, { Name = "Pegs" })
	for k = 0, 2 do
		vcyl(model, 0.35, 1.4, origin * CFrame.new(0, 0.6 + k * 1.5, -(M.PlateRadius + 0.8)) * CFrame.Angles(math.pi / 2, 0, 0) * UP, WHITE)
	end
	CollectionService:AddTag(pegs, "SnatchPegs")
	pegs:SetAttribute("PlotIndex", index)

	-- the Bubble Shield dome (shown while a shield or protection is up)
	local dome = ellipsoid(model, Vector3.new(M.PlateRadius * 2 + 12, 20, M.PlateRadius * 2 + 12), origin * CFrame.new(0, 6, 0), Color3.fromRGB(170, 230, 255), {
		Name = "Dome",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Glass,
	})

	-- sign post with name, height and status
	local signCF = origin * CFrame.new(M.PlateRadius + 5, 0, -(M.PadRadius - 4))
	vcyl(model, 0.6, 7, signCF * CFrame.new(0, 3.5, 0), WHITE, { Name = "SignPost" })
	local board = block(model, Vector3.new(5, 2.4, 0.4), signCF * CFrame.new(0, 7, 0), color, { Name = "SignBoard" })
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(16, 5)
	sign.StudsOffset = Vector3.new(0, 4.5, 0)
	sign.MaxDistance = 260
	sign.LightInfluence = 0
	sign.Adornee = board
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = sign
	for i, info in { { "Title", 0.42 }, { "Info", 0.3 }, { "Status", 0.28 } } do
		local label = Instance.new("TextLabel")
		label.Name = info[1]
		label.LayoutOrder = i
		label.Size = UDim2.fromScale(1, info[2])
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = i == 1 and WHITE or Color3.fromRGB(255, 245, 200)
		label.TextStrokeTransparency = 0.15
		label.TextStrokeColor3 = Color3.fromRGB(70, 40, 80)
		label.Text = i == 1 and "Empty Base Pad" or ""
		label.Parent = sign
	end
	sign.Parent = board

	-- welcome mat (shows the owner's name)
	local spawnPos = center + (Vector3.new(0, 0, 0) - center).Unit * (M.PlateRadius + 6)
	local mat = block(model, Vector3.new(6, 0.15, 4), CFrame.lookAt(Vector3.new(spawnPos.X, M.PadTopY + 0.08, spawnPos.Z), Vector3.new(center.X, M.PadTopY + 0.08, center.Z)), color, { Name = "WelcomeMat" })
	local matGui = Instance.new("SurfaceGui")
	matGui.Face = Enum.NormalId.Top
	matGui.LightInfluence = 0
	local matLabel = Instance.new("TextLabel")
	matLabel.Name = "Label"
	matLabel.Size = UDim2.fromScale(1, 1)
	matLabel.BackgroundTransparency = 1
	matLabel.Font = Enum.Font.FredokaOne
	matLabel.TextScaled = true
	matLabel.TextColor3 = WHITE
	matLabel.Text = "WELCOME"
	matLabel.Rotation = 180
	matLabel.Parent = matGui
	matGui.Parent = mat

	-- comfy cushion (unsnatchable favorite)
	local cushionLocal = CFrame.new(M.CushionOffset)
	local cushion = ellipsoid(model, Vector3.new(4.5, 1.2, 4.5), origin * cushionLocal * CFrame.new(0, -0.3, 0), Color3.fromRGB(255, 170, 210), { Name = "Cushion" })
	billboard(cushion, "Comfy Cushion", Color3.fromRGB(255, 200, 230), 7, 2.5).MaxDistance = 60

	-- coin jar (decoration)
	local jarCF = origin * CFrame.new(9, 0, 4)
	vcyl(model, 3, 4, jarCF * CFrame.new(0, 1.4, 0), Color3.fromRGB(220, 240, 255), { Transparency = 0.55, Material = Enum.Material.Glass, Name = "Jar" })
	vcyl(model, 2.6, 2, jarCF * CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 205, 60), { Name = "Coins", Material = Enum.Material.Foil })

	local towerFolder = Instance.new("Folder")
	towerFolder.Name = "Tower"
	towerFolder.Parent = model
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "Ground"
	groundFolder.Parent = model
	local cushionFolder = Instance.new("Folder")
	cushionFolder.Name = "CushionSlot"
	cushionFolder.Parent = model

	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("Height", 0)
	model:SetAttribute("Rate", 0)
	model:SetAttribute("Wobble", 0)
	model:SetAttribute("ShieldUntil", 0)
	model:SetAttribute("Protected", false)
	model:SetAttribute("Status", "")
	model:SetAttribute("Toppling", false)
	model:SetAttribute("BaseYaw", select(2, origin:ToOrientation()))
	model.PrimaryPart = pad
	model.Parent = parent

	return {
		index = index,
		angle = angle,
		color = color,
		center = center,
		origin = origin,
		spawnCF = CFrame.lookAt(spawnPos + Vector3.new(0, M.PadTopY + 3, 0), Vector3.new(center.X, M.PadTopY + 3, center.Z)),
		cushionCF = origin * cushionLocal * CFrame.new(0, 0.3, 0),
		groundCF = origin * CFrame.new(6, M.PadTopY - M.PlateTopY, 6),
		model = model,
		pegs = pegs,
		dome = dome,
		sign = sign,
		matLabel = matLabel,
		towerFolder = towerFolder,
		groundFolder = groundFolder,
		cushionFolder = cushionFolder,
		owner = nil,
	}
end

-- World ------------------------------------------------------------------------------

local function buildLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.6
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(140, 128, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(180, 170, 190)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.22
		atmosphere.Haze = 0.6
		atmosphere.Color = Color3.fromRGB(255, 220, 240)
		atmosphere.Decay = Color3.fromRGB(190, 220, 255)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("SillyColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "SillyColor"
		cc.Saturation = 0.15
		cc.Brightness = 0.02
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end
end

local function buildIsland(map: Instance)
	-- island, beach and fizzy soda sea
	vcyl(map, M.IslandRadius * 2, 6, CFrame.new(0, -3, 0), Color3.fromRGB(160, 225, 130), { Material = Enum.Material.Grass, Name = "Island" })
	vcyl(map, M.IslandRadius * 2 + 40, 6, CFrame.new(0, -3.4, 0), Color3.fromRGB(255, 230, 180), { Material = Enum.Material.Sand, Name = "FizzyShore" })
	block(map, Vector3.new(1400, 1, 1400), CFrame.new(0, -6.5, 0), Color3.fromRGB(240, 220, 170), { Material = Enum.Material.Sand, Name = "SeaFloor" })
	block(map, Vector3.new(1400, 3, 1400), CFrame.new(0, -3, 0), Color3.fromRGB(120, 220, 230), {
		Name = "SodaSea",
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.Glass,
	})
	-- invisible fence far out in the soda so nobody wanders off forever
	local fenceRadius = M.IslandRadius + 70
	for k = 0, 31 do
		local a = k / 32 * 2 * math.pi
		block(map, Vector3.new(fenceRadius * 2 * math.pi / 32 + 4, 80, 4), CFrame.lookAt(polar(fenceRadius, a, 30), Vector3.new(0, 30, 0)), WHITE, {
			Transparency = 1,
			Name = "Fence",
		})
	end
	-- bubbles fizzing up from the soda
	local fizz = block(map, Vector3.new(500, 1, 500), CFrame.new(0, -2, 0), WHITE, { Transparency = 1, CanCollide = false, CanQuery = false, Name = "Fizz" })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 40
	emitter.Lifetime = NumberRange.new(2, 4)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.Size = NumberSequence.new(0.6)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 255))
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = fizz
end

local function buildPlaza(map: Instance)
	vcyl(map, M.PlazaRadius * 2, 0.4, CFrame.new(0, 0, 0), Color3.fromRGB(255, 225, 235), { Name = "Plaza" })
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		vcyl(map, 5, 0.42, CFrame.new(polar(M.PlazaRadius - 6, a, 0)), Color3.fromRGB(255, 200, 220), { Name = "PlazaTile" })
	end

	-- Fluff-O-Matic 3000
	local machine = Instance.new("Model")
	machine.Name = "FluffOMatic"
	vcyl(machine, 16, 6, CFrame.new(0, 3.2, 0), Color3.fromRGB(255, 170, 200))
	ellipsoid(machine, Vector3.new(15, 11, 15), CFrame.new(0, 9, 0), Color3.fromRGB(200, 170, 255))
	local chimney = vcyl(machine, 3.4, 8, CFrame.new(-2, 17, 2), Color3.fromRGB(150, 150, 190))
	chimney.Name = "Chimney"
	ellipsoid(machine, Vector3.new(6, 2, 4), CFrame.new(-2, 21.5, 2), WHITE)
	for k = 0, 5 do
		local a = k / 6 * 2 * math.pi
		ball(machine, 1.6, polar(7.6, a, 6.2), Color3.fromRGB(255, 230, 120))
	end
	vcyl(machine, 0.5, 4, CFrame.new(-7.5, 8, -3) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(80, 80, 90))
	ball(machine, 1.4, Vector3.new(-8.4, 10, -3), Color3.fromRGB(240, 60, 80))
	-- chute down to the belt start (+X)
	local chuteLen = Config.Conveyor.Radius - 8
	local chute = block(machine, Vector3.new(chuteLen, 0.6, 5), CFrame.new(8 + chuteLen / 2, 3.6, 0) * CFrame.Angles(0, 0, math.atan2(-5, chuteLen)), Color3.fromRGB(255, 240, 180), { CanCollide = false })
	chute.Name = "Chute"
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 2.5
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(255, 220, 240), Color3.fromRGB(220, 230, 255))
	smoke.EmissionDirection = Enum.NormalId.Right -- cylinder X axis points up
	smoke.Parent = chimney
	local sneeze = smoke:Clone()
	sneeze.Name = "SneezePuff"
	sneeze.Rate = 0
	sneeze.Speed = NumberRange.new(8, 14)
	sneeze.SpreadAngle = Vector2.new(40, 40)
	sneeze.Parent = chimney
	billboard(chimney, "FLUFF-O-MATIC 3000", Color3.fromRGB(255, 200, 240), 20, 9)
	machine.Parent = map
	Map.chimney = chimney

	-- Captain Conveyor's podium at the belt start
	local podiumCF = outwardCF(38, math.rad(-22), 0)
	local captain = Instance.new("Model")
	captain.Name = "Captain"
	local podium = vcyl(captain, 5, 1.5, podiumCF * CFrame.new(0, 0.75, 0), Color3.fromRGB(80, 120, 200))
	NpcBuilders.Captain(captain, podiumCF * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(-60), 0))
	billboard(podium, "Captain Conveyor", Color3.fromRGB(140, 190, 255), 12, 9)
	CollectionService:AddTag(podium, "NpcStall")
	podium:SetAttribute("Npc", "Captain")
	podium:SetAttribute("NpcName", "Captain Conveyor")
	podium:SetAttribute("Action", "Talk:Captain")
	podium:SetAttribute("PromptText", "Ahoy!")
	captain.Parent = map

	local stalls = Instance.new("Folder")
	stalls.Name = "Stalls"
	stalls.Parent = map
	Map.stalls = {}
	for _, spec in NPCS do
		local _, front = buildStall(stalls, spec)
		Map.stalls[spec.Id] = front
	end

	-- Mayor Marshmallow's leaderboard board
	local mayorFront = Map.stalls.Mayor
	local board = block(map, Vector3.new(9, 6, 0.5), mayorFront * CFrame.new(7.5, 5, 1) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(255, 245, 235), { Name = "TallestBoard" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(360, 240)
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextColor3 = Color3.fromRGB(110, 60, 120)
	list.Text = "Tallest Towers"
	list.Parent = gui
	gui.Parent = board
	Map.tallestLabel = list

	-- spawn fallback (players are moved to their base pad right away)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.new(0, 0.3, -16)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = map
end

local function buildConveyor(map: Instance)
	local C = Config.Conveyor
	local belt = Instance.new("Model")
	belt.Name = "Belt"
	local segments = 72
	local segLen = 2 * math.pi * C.Radius / segments + 0.35
	for k = 0, segments - 1 do
		local a = (k + 0.5) / segments * 2 * math.pi
		local cf = CFrame.lookAt(polar(C.Radius, a, C.BeltTopY - 0.25), polar(C.Radius, a, C.BeltTopY - 0.25) + Vector3.new(-math.sin(a), 0, math.cos(a)))
		block(belt, Vector3.new(6, 0.5, segLen), cf, k % 2 == 0 and Color3.fromRGB(90, 90, 120) or Color3.fromRGB(105, 105, 140), { Name = "Belt" })
		for _, side in { -1, 1 } do
			block(belt, Vector3.new(0.4, 0.25, segLen), cf * CFrame.new(side * 3.1, 0.35, 0), Color3.fromRGB(255, 215, 80), { Name = "Rail" })
		end
	end
	belt.Parent = map
end

local function buildMeadows(map: Instance)
	local meadow = Instance.new("Model")
	meadow.Name = "MuffinMeadows"
	local rng = Random.new(2026)
	local plotAngles = {}
	for i = 1, M.PlotCount do
		plotAngles[i] = (i - 0.5) * 2 * math.pi / M.PlotCount
	end
	local function nearPath(a: number): boolean
		for _, pa in plotAngles do
			local d = math.abs((a - pa + math.pi) % (2 * math.pi) - math.pi)
			if d < math.rad(10) then
				return true
			end
		end
		return false
	end
	local cake = { Color3.fromRGB(255, 225, 150), Color3.fromRGB(255, 210, 170), Color3.fromRGB(250, 235, 190) }
	local placed = 0
	local tries = 0
	while placed < 18 and tries < 400 do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(M.MeadowInner + 8, M.MeadowOuter - 6)
		if not nearPath(a) then
			local d = rng:NextNumber(14, 24)
			local hill = ball(meadow, d, polar(r, a, -d / 2 + rng:NextNumber(2.2, 3.6)), cake[rng:NextInteger(1, #cake)], { Name = "Hill" })
			hill.Material = Enum.Material.Sand
			placed += 1
		end
	end
	-- lollipop trees
	local candy = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 200, 80), Color3.fromRGB(170, 120, 255) }
	for k = 1, 12 do
		local a = rng:NextNumber(0, 2 * math.pi)
		if not nearPath(a) then
			local r = rng:NextNumber(M.MeadowInner + 2, M.IslandRadius - 12)
			if r < M.MeadowOuter or r > M.PlotRingRadius + M.PadRadius + 8 then
				local base = polar(r, a, 0)
				vcyl(meadow, 0.6, 9, CFrame.new(base + Vector3.new(0, 4.5, 0)), WHITE, { Name = "Stick" })
				vcyl(meadow, 5, 1, CFrame.new(base + Vector3.new(0, 10, 0)) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), candy[k % #candy + 1], { Name = "Lollipop" })
			end
		end
	end
	-- marshmallow clouds
	for _ = 1, 14 do
		local center = polar(rng:NextNumber(40, 260), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(90, 150))
		for _ = 1, 4 do
			ball(meadow, rng:NextNumber(12, 22), center + Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-3, 3), rng:NextNumber(-12, 12)), WHITE, {
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Name = "Cloud",
			})
		end
	end
	-- sign
	local signPole = vcyl(meadow, 0.6, 6, CFrame.new(polar(M.MeadowInner + 2, math.rad(0), 3)), WHITE)
	billboard(signPole, "Muffin Meadows", Color3.fromRGB(255, 220, 140), 14, 4)
	meadow.Parent = map
end

local function buildPaths(map: Instance)
	for i = 1, M.PlotCount do
		local a = (i - 0.5) * 2 * math.pi / M.PlotCount
		local inner, outer = M.PlazaRadius - 1, M.PlotRingRadius - M.PadRadius + 1
		local mid = (inner + outer) / 2
		local pos = polar(mid, a, 0.1)
		block(map, Vector3.new(9, 0.2, outer - inner), CFrame.lookAt(pos, Vector3.new(0, 0.1, 0)), Color3.fromRGB(255, 244, 220), { Name = "Path" })
	end
end

local function buildPractice(map: Instance)
	-- Sneaky Pete's practice tower, right in front of his stall
	local angle = math.rad(255 + 13)
	local pos = polar(35, angle, 0)
	local origin = CFrame.lookAt(Vector3.new(pos.X, M.PlateTopY, pos.Z), Vector3.new(0, M.PlateTopY, 0))
	local model = Instance.new("Model")
	model.Name = "PracticeTower"
	vcyl(model, 9, 0.6, CFrame.new(pos.X, M.PlateTopY - 0.3, pos.Z), Color3.fromRGB(200, 210, 255), { Name = "Plate" })
	vcyl(model, 9.8, 1.2, CFrame.new(pos.X, M.PlateTopY - 1, pos.Z), Color3.fromRGB(70, 90, 170), { Name = "Base" })
	local pegs = block(model, Vector3.new(0.8, 4, 0.8), origin * CFrame.new(0, 1.4, -5.3), Color3.fromRGB(150, 160, 230), { Name = "Pegs" })
	CollectionService:AddTag(pegs, "SnatchPegs")
	pegs:SetAttribute("PlotIndex", 0)
	pegs:SetAttribute("Practice", true)
	billboard(pegs, "Practice Tower", Color3.fromRGB(190, 200, 255), 10, 14)
	local folder = Instance.new("Folder")
	folder.Name = "Tower"
	folder.Parent = model
	model:SetAttribute("Practice", true)
	model:SetAttribute("Wobble", 0.25)
	model:SetAttribute("Toppling", false)
	model:SetAttribute("BaseYaw", select(2, origin:ToOrientation()))
	model.Parent = map
	Map.practice = {
		origin = origin,
		folder = folder,
		model = model,
		pegs = pegs,
	}
end

-- Public -------------------------------------------------------------------------------

function Map.init()
	buildLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	Map.folder = map

	buildIsland(map)
	buildPlaza(map)
	buildConveyor(map)
	buildMeadows(map)
	buildPaths(map)
	buildPractice(map)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	Map.plots = {}
	for i = 1, M.PlotCount do
		Map.plots[i] = buildPlot(plotsFolder, i)
	end

	for _, name in { "Conveyor", "Wild", "Effects" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
		Map[name] = folder
	end
end

-- Where to stand when hopping to the top of a tower (beside the top creature).
function Map.snatchStandCF(origin: CFrame, topHeight: number): CFrame
	local pos = (origin * CFrame.new(0, topHeight + 3, -4.2)).Position
	local look = (origin * CFrame.new(0, topHeight + 3, 0)).Position
	return CFrame.lookAt(pos, look)
end

-- Where a snatcher lands after hopping back down.
function Map.snatchLandCF(origin: CFrame): CFrame
	local pos = (origin * CFrame.new(0, 2.5, -(M.PlateRadius + 4))).Position
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

-- Raycast down onto the island (ignores players and creatures).
function Map.groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Map.folder }
	local result = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0), params)
	if result and result.Instance.Name ~= "SodaSea" then
		return result.Position.Y
	end
	return 0
end

return Map
