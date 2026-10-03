--[[
	CreatureModel: builds a cute Stackable out of simple parts.

	Every model has an invisible "Root" part at its bottom-center (the model's
	PrimaryPart and pivot). Everything else is welded to Root, so moving Root
	moves the whole creature. Front is -Z, like every Roblox model.

	Design rules from the doc: big eyes, small bodies, one readable shape, one
	funny accessory, no teeth or claws. Swap any recipe for a real mesh later.
]]

local Creatures = require(script.Parent.Creatures)
local Rarities = require(script.Parent.Rarities)
local Mutations = require(script.Parent.Mutations)

local CreatureModel = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(30, 25, 35)
local BLUSH = Color3.fromRGB(255, 150, 170)
local ORANGE = Color3.fromRGB(255, 160, 50)
local GOLD = Color3.fromRGB(255, 205, 60)
local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

local Builder = {}
Builder.__index = Builder

function Builder.new(def)
	local model = Instance.new("Model")
	model.Name = def.Id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	return setmetatable({
		model = model,
		root = root,
		def = def,
		W = def.Width,
		H = def.Height,
		color = def.Color,
		accent = def.Accent,
		bodyParts = {},
		count = 0,
	}, Builder)
end

-- shape: "Block" | "Ball" | "Cylinder" | "Ellipsoid" | "Wedge"
function Builder:part(shape: string, size: Vector3, cf: CFrame, color: Color3, opts: any?)
	opts = opts or {}
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Transparency = opts.transparency or 0
	p.Reflectance = opts.reflectance or 0
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	self.count += 1
	p.Name = opts.name or ("Part" .. self.count)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = self.model
	if opts.body then
		table.insert(self.bodyParts, p)
	end
	return p
end

function Builder:ball(d: number, pos: Vector3, color: Color3, opts: any?)
	return self:part("Ball", Vector3.new(d, d, d), CFrame.new(pos), color, opts)
end

function Builder:ellipsoid(size: Vector3, cf: CFrame, color: Color3, opts: any?)
	return self:part("Ellipsoid", size, cf, color, opts)
end

function Builder:block(size: Vector3, cf: CFrame, color: Color3, opts: any?)
	return self:part("Block", size, cf, color, opts)
end

-- Vertical cylinder centered on `cf`.
function Builder:vcyl(diameter: number, height: number, cf: CFrame, color: Color3, opts: any?)
	return self:part("Cylinder", Vector3.new(height, diameter, diameter), cf * UP, color, opts)
end

-- Cone made of stacked discs, standing on `bottom`.
function Builder:cone(baseDiameter: number, height: number, bottom: CFrame, color: Color3, tiers: number?, opts: any?)
	tiers = tiers or 4
	local h = height / tiers
	for k = 0, tiers - 1 do
		local d = math.max(0.2, baseDiameter * (1 - k / tiers))
		self:vcyl(d, h, bottom * CFrame.new(0, (k + 0.5) * h, 0), color, opts)
	end
end

-- Two big eyes (and optional blush + smile) on a front face at z = frontZ.
function Builder:face(frontZ: number, eyeY: number, spacing: number, eyeSize: number, opts: any?)
	opts = opts or {}
	for _, side in { -1, 1 } do
		local x = side * spacing / 2
		if opts.sleepy then
			self:block(Vector3.new(eyeSize * 0.9, 0.12, 0.1), CFrame.new(x, eyeY, frontZ - 0.02), BLACK)
		else
			self:ball(eyeSize, Vector3.new(x, eyeY, frontZ + eyeSize * 0.2), WHITE)
			self:ball(eyeSize * 0.55, Vector3.new(x, eyeY - eyeSize * 0.05, frontZ - eyeSize * 0.12), BLACK)
			self:ball(eyeSize * 0.18, Vector3.new(x + eyeSize * 0.12, eyeY + eyeSize * 0.12, frontZ - eyeSize * 0.3), WHITE)
		end
		if not opts.noBlush then
			self:ellipsoid(
				Vector3.new(eyeSize * 0.6, eyeSize * 0.32, 0.12),
				CFrame.new(side * (spacing / 2 + eyeSize * 0.45), eyeY - eyeSize * 0.6, frontZ + 0.02),
				BLUSH,
				{ transparency = 0.2 }
			)
		end
	end
	if not opts.noSmile then
		self:ellipsoid(
			Vector3.new(eyeSize * 0.5, eyeSize * 0.22, 0.1),
			CFrame.new(0, eyeY - eyeSize * 0.75, frontZ + 0.01),
			BLACK
		)
	end
end

-- Recipes ----------------------------------------------------------------------

local Recipes = {}

function Recipes.PancakePup(b)
	local W, H = b.W, b.H
	b:vcyl(W, H * 0.6, CFrame.new(0, H * 0.3, 0), b.color, { body = true })
	b:vcyl(W * 0.9, H * 0.38, CFrame.new(0, H * 0.79, 0), b.color:Lerp(WHITE, 0.15), { body = true })
	b:block(Vector3.new(0.9, 0.2, 0.9), CFrame.new(0, H + 0.08, 0), Color3.fromRGB(255, 235, 120))
	for _, side in { -1, 1 } do
		b:ellipsoid(
			Vector3.new(0.7, 0.3, 1.5),
			CFrame.new(side * W * 0.47, H * 0.7, -0.3) * CFrame.Angles(0, 0, side * 0.5),
			b.accent
		)
	end
	b:ball(0.6, Vector3.new(0, H * 0.45, -W / 2 - 0.15), b.accent)
	b:face(-W / 2 + 0.05, H * 0.62, 1.2, 0.55, { noSmile = true })
end

function Recipes.Toastie(b)
	local W, H = b.W, b.H
	b:block(Vector3.new(W + 0.25, H * 0.9, W + 0.25), CFrame.new(0, H * 0.45, 0), b.accent, { body = true })
	b:block(Vector3.new(W, H, W), CFrame.new(0, H * 0.5, 0), b.color, { body = true })
	b:ellipsoid(Vector3.new(W * 0.9, H * 0.5, W * 0.45), CFrame.new(0, H * 0.75, W * 0.25), b.color, { body = true })
	b:face(-W / 2 - 0.02, H * 0.55, 1.3, 0.6)
end

function Recipes.Blobby(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H, W * 0.9), CFrame.new(0, H / 2, 0), b.color, { body = true, transparency = 0.12 })
	b:ellipsoid(Vector3.new(W * 0.3, H * 0.2, W * 0.2), CFrame.new(-W * 0.18, H * 0.8, -W * 0.2), WHITE, { transparency = 0.4 })
	b:face(-W * 0.43, H * 0.55, 1.2, 0.65)
end

function Recipes.Cubert(b)
	local W, H = b.W, b.H
	b:block(Vector3.new(W, H, W * 0.9), CFrame.new(0, H / 2, 0), b.color, { body = true })
	b:face(-W * 0.45 - 0.02, H * 0.65, 1.3, 0.7, { noSmile = true })
	b:block(Vector3.new(1.3, 0.22, 0.2), CFrame.new(0, H * 0.36, -W * 0.45 - 0.08), b.accent)
	for _, side in { -1, 1 } do
		b:ball(0.4, Vector3.new(side * 0.7, H * 0.38, -W * 0.45 - 0.08), b.accent)
	end
end

function Recipes.PebblePenguin(b)
	local H = b.H
	b:ball(H, Vector3.new(0, H / 2, 0), b.color, { body = true })
	b:ellipsoid(Vector3.new(H * 0.68, H * 0.72, H * 0.3), CFrame.new(0, H * 0.42, -H * 0.37), WHITE)
	b:block(Vector3.new(0.4, 0.25, 0.5), CFrame.new(0, H * 0.58, -H * 0.53), b.accent)
	for _, side in { -1, 1 } do
		b:ellipsoid(Vector3.new(0.7, 0.25, 0.9), CFrame.new(side * 0.55, 0.12, -H * 0.3), b.accent)
	end
	b:face(-H * 0.45, H * 0.7, 1.0, 0.5, { noSmile = true })
end

function Recipes.Sockworm(b)
	local W, H = b.W, b.H
	local D = W * 0.45
	b:ellipsoid(Vector3.new(W, H, D), CFrame.new(0, H / 2, 0), b.color, { body = true })
	for _, x in { -W * 0.28, W * 0.05 } do
		b:block(Vector3.new(0.45, H * 0.92, D * 0.95), CFrame.new(x, H / 2, 0), b.accent)
	end
	b:ellipsoid(Vector3.new(1.2, H * 0.9, D * 0.9), CFrame.new(W * 0.43, H * 0.5, 0), b.accent)
	b:face(-D / 2 + 0.05, H * 0.6, 1.1, 0.6)
end

function Recipes.MuffinMole(b)
	local W, H = b.W, b.H
	b:vcyl(W * 0.82, H * 0.55, CFrame.new(0, H * 0.275, 0), b.accent, { body = true })
	b:ellipsoid(Vector3.new(W * 1.05, H * 0.65, W), CFrame.new(0, H * 0.67, 0), b.color, { body = true })
	local rng = Random.new(7)
	for _ = 1, 6 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(0.2, W * 0.35)
		b:ball(0.35, Vector3.new(math.cos(a) * r, H * 0.93, math.sin(a) * r), Color3.fromRGB(60, 50, 140))
	end
	b:ball(0.45, Vector3.new(0, H * 0.5, -W * 0.44), BLUSH)
	b:face(-W * 0.4, H * 0.66, 1.2, 0.5, { noSmile = true })
end

function Recipes.BouncyBean(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W * 0.9, H, W * 0.8), CFrame.new(0, H / 2, 0) * CFrame.Angles(0, 0, 0.15), b.color, { body = true })
	b:ellipsoid(Vector3.new(0.9, 0.2, 0.5), CFrame.new(0.3, H + 0.05, 0) * CFrame.Angles(0, 0, 0.5), b.accent)
	b:face(-W * 0.38, H * 0.58, 1.0, 0.55)
end

function Recipes.Hamwich(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H * 0.42, W * 0.9), CFrame.new(0, H * 0.21, 0), b.color, { body = true })
	b:ellipsoid(Vector3.new(W * 0.95, H * 0.45, W * 0.85), CFrame.new(0, H * 0.78, 0), b.color:Lerp(WHITE, 0.1), { body = true })
	for i = 1, 3 do
		b:ball(0.18, Vector3.new((i - 2) * 0.5, H * 0.99, 0.2 * i - 0.3), WHITE)
	end
	b:ball(H * 0.6, Vector3.new(0, H * 0.5, -W * 0.3), b.accent)
	for _, side in { -1, 1 } do
		b:ball(0.35, Vector3.new(side * 0.4, H * 0.78, -W * 0.3), BLUSH)
	end
	b:face(-W * 0.3 - H * 0.28, H * 0.53, 0.55, 0.32, { noBlush = true })
end

function Recipes.Jellybelly(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H, W * 0.9), CFrame.new(0, H / 2, 0), b.color, { body = true, transparency = 0.25 })
	b:ellipsoid(Vector3.new(W * 0.5, H * 0.5, W * 0.4), CFrame.new(0, H * 0.45, 0), b.accent, { transparency = 0.3 })
	b:face(-W * 0.43, H * 0.6, 1.2, 0.6)
end

function Recipes.SirWobbles(b)
	local H = b.H
	b:ball(H, Vector3.new(0, H / 2, 0), b.color, { body = true })
	local crown = CFrame.new(0.3, H * 0.98, 0) * CFrame.Angles(0, 0, -0.3)
	b:vcyl(H * 0.7, 0.55, crown, b.accent)
	for k = 0, 4 do
		local a = k / 5 * 2 * math.pi
		b:block(Vector3.new(0.25, 0.5, 0.25), crown * CFrame.new(math.cos(a) * H * 0.3, 0.45, math.sin(a) * H * 0.3), b.accent)
	end
	b:ball(0.35, (crown * CFrame.new(0, 0.1, -H * 0.36)).Position, Color3.fromRGB(230, 60, 80))
	b:face(-H * 0.45, H * 0.55, 1.0, 0.6)
end

function Recipes.DoughnutDuck(b)
	local W, H = b.W, b.H
	local ringR = W * 0.33
	local seg = 10
	for k = 0, seg - 1 do
		local a = k / seg * 2 * math.pi
		b:ball(H * 0.8, Vector3.new(math.cos(a) * ringR, H * 0.4, math.sin(a) * ringR), b.color, { body = true })
	end
	b:vcyl(W * 0.95, H * 0.2, CFrame.new(0, H * 0.1, 0), Color3.fromRGB(225, 170, 100), { body = true })
	b:ball(1.4, Vector3.new(0, H * 0.95, -ringR - 0.2), b.accent)
	b:block(Vector3.new(0.6, 0.2, 0.5), CFrame.new(0, H * 0.88, -ringR - 1.0), ORANGE)
	b:face(-ringR - 0.85, H * 1.05, 0.6, 0.35, { noSmile = true, noBlush = true })
end

function Recipes.ConeKitten(b)
	local W, H = b.W, b.H
	local headD = W * 0.85
	b:ball(headD, Vector3.new(0, headD / 2, 0), b.color, { body = true })
	for _, side in { -1, 1 } do
		b:part(
			"Wedge",
			Vector3.new(0.25, 0.7, 0.6),
			CFrame.new(side * headD * 0.32, headD * 0.92, 0) * CFrame.Angles(0, math.pi / 2 * side, 0),
			b.color
		)
	end
	b:cone(1.5, H - headD * 0.85, CFrame.new(0, headD * 0.85, 0), b.accent, 5)
	b:ball(0.5, Vector3.new(0, H + 0.1, 0), BLUSH)
	b:face(-headD * 0.45, headD * 0.5, 0.9, 0.5)
end

function Recipes.PillowPossum(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H * 0.7, W * 0.8), CFrame.new(0, H * 0.35, 0), WHITE, { body = true })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			b:ball(0.5, Vector3.new(sx * W * 0.45, H * 0.35, sz * W * 0.35), WHITE)
		end
	end
	b:ball(1.5, Vector3.new(0, H * 0.75, -W * 0.25), b.color, { body = true })
	for _, side in { -1, 1 } do
		b:ball(0.5, Vector3.new(side * 0.55, H * 1.05, -W * 0.25), BLUSH)
	end
	b:ball(0.3, Vector3.new(0, H * 0.68, -W * 0.25 - 0.75), BLUSH)
	b:face(-W * 0.25 - 0.7, H * 0.8, 0.6, 0.35, { sleepy = true, noSmile = true })
end

function Recipes.DiscoBallBat(b)
	local H = b.H
	b:ball(H, Vector3.new(0, H / 2, 0), b.color, { body = true, reflectance = 0.45 })
	for _, side in { -1, 1 } do
		b:part(
			"Wedge",
			Vector3.new(0.2, H * 0.6, H * 0.8),
			CFrame.new(side * H * 0.62, H * 0.6, 0) * CFrame.Angles(0, 0, side * 0.4) * CFrame.Angles(0, math.pi / 2, 0),
			b.accent
		)
		b:part("Wedge", Vector3.new(0.2, 0.6, 0.5), CFrame.new(side * H * 0.25, H * 1.05, 0), b.accent)
	end
	b:face(-H * 0.45, H * 0.55, 1.0, 0.55)
end

function Recipes.WaffleWalrus(b)
	local W, H = b.W, b.H
	b:block(Vector3.new(W, H * 0.55, W * 0.9), CFrame.new(0, H * 0.275, 0), b.color, { body = true })
	for k = -1, 1 do
		b:block(Vector3.new(0.18, 0.1, W * 0.88), CFrame.new(k * W * 0.25, H * 0.56, 0), b.color:Lerp(BLACK, 0.25))
		b:block(Vector3.new(W * 0.98, 0.1, 0.18), CFrame.new(0, H * 0.56, k * W * 0.22), b.color:Lerp(BLACK, 0.25))
	end
	b:ellipsoid(Vector3.new(2.2, 1.4, 1.7), CFrame.new(0, H * 0.55 + 0.6, -W * 0.25), b.accent)
	for _, side in { -1, 1 } do
		b:vcyl(0.22, 0.8, CFrame.new(side * 0.35, H * 0.55 + 0.05, -W * 0.25 - 0.75), WHITE)
	end
	b:vcyl(1.1, 0.3, CFrame.new(0, H * 0.55 + 1.35, -W * 0.25), Color3.fromRGB(40, 60, 120))
	b:face(-W * 0.25 - 0.8, H * 0.55 + 0.85, 0.7, 0.35, { noSmile = true })
end

function Recipes.AccordionAlpaca(b)
	local W, H = b.W, b.H
	local bodyH = H * 0.62
	local folds = 4
	for k = 0, folds - 1 do
		local c = (k % 2 == 0) and b.accent or b.color
		b:block(
			Vector3.new(W * (k % 2 == 0 and 1 or 0.9), bodyH / folds, W * 0.8),
			CFrame.new(0, (k + 0.5) * bodyH / folds, 0),
			c,
			{ body = true }
		)
	end
	b:ball(1.6, Vector3.new(0, bodyH + 0.6, -0.3), b.color, { body = true })
	for _, side in { -1, 1 } do
		b:ellipsoid(Vector3.new(0.3, 0.7, 0.3), CFrame.new(side * 0.5, bodyH + 1.4, -0.3), b.color)
	end
	b:face(-1.05, bodyH + 0.65, 0.7, 0.4)
end

function Recipes.BubbleBunny(b)
	local H = b.H
	local bodyD = H * 0.55
	b:ball(bodyD, Vector3.new(0, H * 0.42, 0), b.color, { body = true })
	for _, side in { -1, 1 } do
		b:ellipsoid(Vector3.new(0.35, 1.0, 0.25), CFrame.new(side * 0.3, H * 0.42 + bodyD * 0.65, 0) * CFrame.Angles(0, 0, side * -0.2), b.color)
		b:ellipsoid(Vector3.new(0.18, 0.7, 0.1), CFrame.new(side * 0.3, H * 0.42 + bodyD * 0.65, -0.1) * CFrame.Angles(0, 0, side * -0.2), b.accent)
	end
	b:ball(H, Vector3.new(0, H / 2, 0), Color3.fromRGB(190, 230, 255), { transparency = 0.75, name = "Bubble" })
	b:face(-bodyD * 0.45, H * 0.45, 0.7, 0.4)
end

function Recipes.GummyGiraffe(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W * 0.9, H * 0.32, W * 0.75), CFrame.new(0, H * 0.16, 0), b.color, { body = true, transparency = 0.1 })
	b:vcyl(0.75, H * 0.48, CFrame.new(0, H * 0.52, -0.2) * CFrame.Angles(0.15, 0, 0), b.color, { body = true, transparency = 0.1 })
	b:ellipsoid(Vector3.new(1.1, 0.9, 1.4), CFrame.new(0, H * 0.84, -0.45), b.color, { body = true, transparency = 0.1 })
	for _, side in { -1, 1 } do
		b:vcyl(0.15, 0.4, CFrame.new(side * 0.25, H * 0.84 + 0.6, -0.35), b.accent)
		b:ball(0.25, Vector3.new(side * 0.25, H * 0.84 + 0.82, -0.35), b.accent)
	end
	for k = 1, 4 do
		b:ball(0.4, Vector3.new((k % 2 == 0 and 1 or -1) * 0.6, H * 0.18 + 0.1 * k, (k - 2.5) * 0.4), b.accent)
	end
	b:face(-1.1, H * 0.86, 0.55, 0.3, { noBlush = true })
end

function Recipes.TeapotTurtle(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H * 0.75, W * 0.9), CFrame.new(0, H * 0.4, 0), b.color, { body = true })
	b:vcyl(1.3, 0.3, CFrame.new(0, H * 0.8, 0), b.accent)
	b:ball(0.45, Vector3.new(0, H * 0.98, 0), b.accent)
	b:vcyl(0.35, 1.3, CFrame.new(W * 0.55, H * 0.55, 0) * CFrame.Angles(0, 0, -0.9), b.accent)
	b:block(Vector3.new(0.3, 1.0, 0.3), CFrame.new(-W * 0.55, H * 0.45, 0), b.accent)
	b:ball(1.2, Vector3.new(0, H * 0.32, -W * 0.48), Color3.fromRGB(190, 230, 160))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			b:ball(0.6, Vector3.new(sx * W * 0.35, 0.25, sz * W * 0.3), Color3.fromRGB(190, 230, 160))
		end
	end
	b:face(-W * 0.48 - 0.55, H * 0.36, 0.55, 0.35, { noBlush = true })
end

function Recipes.RainbowYak(b)
	local W, H = b.W, b.H
	local boxH = H * 0.6
	b:block(Vector3.new(W, boxH, W * 0.9), CFrame.new(0, boxH / 2, 0), b.color, { body = true })
	local rainbow = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(110, 220, 110),
		Color3.fromRGB(90, 170, 255),
		Color3.fromRGB(170, 110, 255),
	}
	for k, c in rainbow do
		b:block(Vector3.new(W * 0.9, boxH / 8, 0.1), CFrame.new(0, boxH * 0.15 + (k - 1) * boxH / 8, -W * 0.45 - 0.05), c)
	end
	for _, side in { -1, 1 } do
		b:block(Vector3.new(W * 0.5, 0.15, W * 0.8), CFrame.new(side * W * 0.62, boxH + 0.1, 0) * CFrame.Angles(0, 0, side * 0.5), b.color)
	end
	b:ball(1.9, Vector3.new(0, boxH + 0.7, 0), b.accent, { body = true })
	for _, side in { -1, 1 } do
		b:vcyl(0.25, 0.8, CFrame.new(side * 0.85, boxH + 1.4, 0) * CFrame.Angles(0, 0, side * -0.7), Color3.fromRGB(120, 90, 60))
	end
	b:face(-0.9, boxH + 0.8, 0.7, 0.42)
end

function Recipes.MarshmallowMoose(b)
	local W, H = b.W, b.H
	b:vcyl(W * 0.85, H * 0.72, CFrame.new(0, H * 0.36, 0), b.color, { body = true })
	b:ellipsoid(Vector3.new(1.8, 1.2, 1.5), CFrame.new(0, H * 0.72 + 0.4, -W * 0.25), b.color, { body = true })
	for _, side in { -1, 1 } do
		local base = CFrame.new(side * 0.7, H * 0.72 + 0.95, -W * 0.25)
		b:vcyl(0.35, 0.9, base * CFrame.Angles(0, 0, side * -0.8), b.accent)
		b:vcyl(0.3, 0.55, base * CFrame.new(side * 0.45, 0.5, 0) * CFrame.Angles(0, 0, side * -0.2), b.accent)
	end
	b:face(-W * 0.25 - 0.72, H * 0.72 + 0.45, 0.6, 0.35)
end

function Recipes.KazooKoala(b)
	local H = b.H
	b:ball(H, Vector3.new(0, H / 2, 0), b.color, { body = true })
	for _, side in { -1, 1 } do
		b:ball(1.2, Vector3.new(side * H * 0.48, H * 0.85, 0), b.color, { body = true })
		b:ellipsoid(Vector3.new(0.7, 0.7, 0.2), CFrame.new(side * H * 0.48, H * 0.85, -0.45), BLUSH)
	end
	b:ellipsoid(Vector3.new(0.6, 0.75, 0.4), CFrame.new(0, H * 0.48, -H * 0.48), BLACK)
	b:part("Cylinder", Vector3.new(1.2, 0.25, 0.25), CFrame.new(0.45, H * 0.3, -H * 0.47) * CFrame.Angles(0, 0.4, 0), b.accent)
	b:face(-H * 0.44, H * 0.62, 1.1, 0.45, { noSmile = true })
end

function Recipes.LordJellington(b)
	local W, H = b.W, b.H
	b:ellipsoid(Vector3.new(W, H * 0.8, W * 0.9), CFrame.new(0, H * 0.4, 0), b.color, { body = true, transparency = 0.25 })
	local crown = CFrame.new(0, H * 0.82, 0)
	b:vcyl(1.5, 0.45, crown, b.accent)
	for k = 0, 5 do
		local a = k / 6 * 2 * math.pi
		b:block(Vector3.new(0.22, 0.45, 0.22), crown * CFrame.new(math.cos(a) * 0.62, 0.4, math.sin(a) * 0.62), b.accent)
	end
	b:ball(0.3, (crown * CFrame.new(0, 0.05, -0.75)).Position, Color3.fromRGB(120, 255, 200))
	b:face(-W * 0.42, H * 0.45, 1.1, 0.6)
end

-- Generic fallbacks by shape, in case a recipe is missing.
local function genericBody(b)
	local W, H = b.W, b.H
	local shape = b.def.Shape
	if shape == "Flat" then
		b:vcyl(W, H, CFrame.new(0, H / 2, 0), b.color, { body = true })
		b:face(-W / 2, H * 0.55, 1.2, 0.5)
	elseif shape == "Round" then
		b:ball(H, Vector3.new(0, H / 2, 0), b.color, { body = true })
		b:face(-H * 0.45, H * 0.55, 1.0, 0.55)
	elseif shape == "Pointy" then
		b:cone(W, H, CFrame.new(), b.color, 5, { body = true })
		b:face(-W * 0.4, H * 0.25, 0.9, 0.45)
	else
		b:ellipsoid(Vector3.new(W, H, W * 0.9), CFrame.new(0, H / 2, 0), b.color, { body = true })
		b:face(-W * 0.43, H * 0.55, 1.1, 0.55)
	end
end

-- Mutations ------------------------------------------------------------------------

local SPRINKLE_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(130, 230, 120),
	Color3.fromRGB(200, 130, 255),
	WHITE,
}

local function applyMutation(b, mutation: string?)
	if not mutation then
		return
	end
	local mainPart = b.bodyParts[1]
	if mutation == "Sprinkled" then
		local rng = Random.new(#b.def.Id * 31)
		for k = 1, 14 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local r = rng:NextNumber(0, b.W * 0.38)
			b:block(
				Vector3.new(0.12, 0.12, 0.4),
				CFrame.new(math.cos(a) * r, b.H + 0.02, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				SPRINKLE_COLORS[(k % #SPRINKLE_COLORS) + 1]
			)
		end
	elseif mutation == "Glittery" then
		if mainPart then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Mutations.ById.Glittery.Color
			sparkles.Parent = mainPart
		end
	elseif mutation == "GoldenToast" then
		for _, p in b.bodyParts do
			p.Color = GOLD
			p.Reflectance = 0.3
		end
		if mainPart then
			local light = Instance.new("PointLight")
			light.Color = GOLD
			light.Range = 8
			light.Brightness = 1.2
			light.Parent = mainPart
		end
	end
end

-- Public API ------------------------------------------------------------------------

-- Build a creature model. opts.ghost = see-through preview with no effects.
function CreatureModel.build(creatureId: string, mutation: string?, opts: any?): Model?
	opts = opts or {}
	local def = Creatures.ById[creatureId]
	if not def then
		warn("[CreatureModel] unknown creature", creatureId)
		return nil
	end
	local b = Builder.new(def)
	local recipe = Recipes[def.Look]
	if recipe then
		recipe(b)
	else
		genericBody(b)
	end
	applyMutation(b, mutation)

	local rarity = Rarities.get(def.Rarity)
	if rarity.Tier >= 4 and not opts.ghost and b.bodyParts[1] then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.Color
		glow.Range = 6 + rarity.Tier
		glow.Brightness = 0.6
		glow.Parent = b.bodyParts[1]
	end

	b.model:SetAttribute("CreatureId", creatureId)
	b.model:SetAttribute("Mutation", mutation or "")
	if opts.ghost then
		CreatureModel.makeGhost(b.model)
	end
	if opts.cframe then
		b.model:PivotTo(opts.cframe)
	end
	return b.model
end

function CreatureModel.makeGhost(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name ~= "Root" then
				d.Transparency = 1 - (1 - d.Transparency) * 0.45
			end
			d.CastShadow = false
			d.CanQuery = false
		elseif d:IsA("Sparkles") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
end

function CreatureModel.setCollide(model: Model, on: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			d.CanCollide = on
		end
	end
end

-- Unanchored + massless so it can ride on a character.
function CreatureModel.prepareForCarry(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
end

return CreatureModel
