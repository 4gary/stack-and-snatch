--[[
	Placement: the ghost preview and the DROP button (design doc 4.2).

	While you hold a creature on your base pad, a see-through ghost sways in a
	figure-8 over your tower. The jelly-bean bar shows how wobbly the tower would
	be if you dropped it right now. Tap DROP when it's centered for a satisfying
	"boop"; drop it at the edge of the swing and the tower wobbles a lot more.

	The swing is a pure function of server time (Wobble.swingOffset), so the
	server recomputes exactly where you dropped it.
]]

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureModel = require(Shared.CreatureModel)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local TowerLayout = require(Shared.TowerLayout)
local Wobble = require(Shared.Wobble)

local Placement = {}

local C
local State
local ghost: Model? = nil
local ghostKey = nil
local target: BasePart? = nil
local active = false
local lastDrop = 0
local lastWarn = 0

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
		ghostKey = nil
	end
end

local function ensureTarget()
	if target and target.Parent then
		return target
	end
	local ring = Instance.new("Part")
	ring.Name = "AimRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 2.2, 2.2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 255, 150)
	ring.Transparency = 0.35
	ring.Parent = workspace.CurrentCamera
	target = ring
	return ring
end

local function canPlace(data): boolean
	return data ~= nil
		and data.held ~= nil
		and data.carrying == nil
		and not C.State.myTowerToppling()
		and not data.inSession
		and #data.tower < Economy.maxSlots(data)
		and State.onOwnPad()
end

function Placement.drop()
	local data = State.data
	if not canPlace(data) then
		return
	end
	local now = os.clock()
	if now - lastDrop < 0.5 then
		return
	end
	lastDrop = now
	Remotes.get("PlaceHeld"):FireServer(State.now())
	clearGhost()
end

local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	if on then
		ContextActionService:BindAction("StackDrop", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Placement.drop()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
	else
		ContextActionService:UnbindAction("StackDrop")
		clearGhost()
		if target then
			target.Transparency = 1
		end
		C.Hud.setPreview(false)
	end
end

local function update()
	local data = State.data
	if not canPlace(data) then
		setActive(false)
		return
	end
	local origin = State.myOrigin()
	if not origin then
		setActive(false)
		return
	end
	setActive(true)

	local held = data.held
	local key = held.u .. ":" .. tostring(held.m)
	if ghostKey ~= key then
		clearGhost()
		ghost = CreatureModel.build(held.id, held.m, { ghost = true })
		if ghost then
			ghost.Parent = workspace.CurrentCamera
			ghostKey = key
		end
	end

	local n = #data.tower
	local t = State.now()
	local x, z = Wobble.swingOffset(t, n)
	local _, topCF = TowerLayout.layout(data.tower, origin)
	if ghost then
		local bob = 0.4 + 0.15 * math.sin(t * 6)
		ghost:PivotTo(topCF * CFrame.new(x, bob, z))
	end
	local ring = ensureTarget()
	ring.CFrame = topCF * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = n == 0 and 1 or 0.35

	local candidate = { id = held.id, x = Wobble.roundOffset(x), z = Wobble.roundOffset(z) }
	local ratio = Wobble.total(Wobble.withTop(data.tower, candidate), Economy.glueReduce(data))
		/ Wobble.capacity(Wobble.withTop(data.tower, candidate))
	C.Hud.setPreview(n > 0, ratio)
end

function Placement.init(controllers)
	C = controllers
	State = C.State
end

function Placement.start()
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(update)
		if not ok then
			if os.clock() - lastWarn > 5 then
				lastWarn = os.clock()
				warn("[Placement]", err)
			end
			setActive(false)
		end
	end)
end

return Placement
