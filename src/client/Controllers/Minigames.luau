--[[
	Minigames: the two skill moments.

	Snatch (3-5 seconds, design doc 4.3): hold down and keep the jiggling dot
	inside the ring while you pull. The steady bar fills while you hold inside
	the ring; wiggle outside too long and the tower topples.
	  PC: hold the mouse button and drag   Mobile: hold and drag your thumb
	  Console: hold R2 / A and steer with the left stick

	Scoop (Muffin Meadows): stop the marker in the green zone.

	The client only reports what happened; the server sanity-checks and decides.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Creatures)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)

local Minigames = {}

local C
local AREA = 300 -- pixels across the snatch play area
local snatchUi = {}
local scoopUi = {}
local snatchConn = nil
local scoopConn = nil

-- Snatch ----------------------------------------------------------------------------------

local function buildSnatch()
	local overlay = Kit.new("TextButton", {
		Name = "SnatchOverlay",
		Text = "",
		AutoButtonColor = false,
		Modal = true, -- frees the mouse in first person / shift-lock
		BackgroundColor3 = Color3.fromRGB(40, 20, 60),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = Root.overlay,
	})
	local panel = Kit.panel({
		Name = "Panel",
		Size = UDim2.fromOffset(AREA + 60, AREA + 150),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = overlay,
	})
	local title = Kit.label({
		Text = "Steady... steady...",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 8),
		Parent = panel,
	})
	local area = Kit.new("Frame", {
		Name = "Area",
		Size = UDim2.fromOffset(AREA, AREA),
		Position = UDim2.new(0.5, 0, 0, 46),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(240, 230, 250),
		Parent = panel,
	})
	Kit.round().Parent = area
	local ring = Kit.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(200, 255, 210),
		BackgroundTransparency = 0.3,
		Parent = area,
	})
	Kit.round().Parent = ring
	local ringStroke = Kit.stroke(Kit.Colors.Green, 4)
	ringStroke.Parent = ring
	local dot = Kit.new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Kit.Colors.Pink,
		ZIndex = 3,
		Parent = area,
	})
	Kit.round().Parent = dot
	Kit.stroke(Color3.fromRGB(120, 40, 80), 3).Parent = dot
	local steadyFrame, setSteady = Kit.bar({
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Kit.Colors.Green,
		Parent = panel,
	})
	Kit.label({ Text = "Steady", TextSize = 14, Size = UDim2.fromOffset(60, 14), Position = UDim2.fromOffset(4, -15), Parent = steadyFrame })
	local _, setTime = Kit.bar({
		Size = UDim2.new(1, -40, 0, 10),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Kit.Colors.Blue,
		Parent = panel,
	})
	local hint = Kit.label({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -26),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Kit.Colors.Muted,
		Parent = panel,
	})
	snatchUi = {
		overlay = overlay,
		title = title,
		area = area,
		ring = ring,
		ringStroke = ringStroke,
		dot = dot,
		setSteady = setSteady,
		setTime = setTime,
		hint = hint,
	}
end

local function pointerPosition(): Vector2
	return UserInputService:GetMouseLocation()
end

function Minigames.startSnatch(sessionId: string, params)
	if snatchConn then
		snatchConn:Disconnect()
	end
	local ui = snatchUi
	ui.overlay.Visible = true
	local ringPx = params.ring * AREA
	ui.ring.Size = UDim2.fromOffset(ringPx * 2, ringPx * 2)
	local def = params.creatureId and Creatures.ById[params.creatureId]
	ui.title.Text = (params.practice and "Practice: " or "") .. "Steady... " .. (def and def.Name or "")
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	ui.hint.Text = touch and "Hold your thumb down and drag to keep the dot in the ring!"
		or (UserInputService.GamepadEnabled and not UserInputService.MouseEnabled) and "Hold R2 and steer with the stick!"
		or "Hold the mouse button and drag to keep the dot in the ring!"

	local seedX, seedY = math.random() * 100, math.random() * 100
	local driftAngle = math.random() * math.pi * 2
	local start = os.clock()
	local holding = false
	local anchor = Vector2.zero
	local correction = Vector2.zero
	local stickOffset = Vector2.zero
	local stickAccum = Vector2.zero
	local lastPointer = Vector2.zero
	local steady, outside = 0, 0
	local done = false

	local function finish(success: boolean)
		if done then
			return
		end
		done = true
		if snatchConn then
			snatchConn:Disconnect()
			snatchConn = nil
		end
		ui.title.Text = success and "FWIP!" or "Wheeee!"
		Remotes.get("SnatchResult"):FireServer(sessionId, success, { steady = steady, outside = outside })
		task.delay(0.6, function()
			ui.overlay.Visible = false
		end)
	end

	local holdInput: InputObject? = nil -- the press (mouse / finger / button) doing the pulling
	local function isHoldInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	local inputs = {}
	table.insert(inputs, UserInputService.InputBegan:Connect(function(input)
		if holdInput == nil and isHoldInput(input) then
			holdInput = input
			holding = true
			local pos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or pointerPosition()
			anchor = pos - correction
			lastPointer = pos
		end
	end))
	table.insert(inputs, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if holdInput and holdInput.UserInputType == Enum.UserInputType.MouseButton1 then
				lastPointer = pointerPosition()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			if input == holdInput then
				lastPointer = Vector2.new(input.Position.X, input.Position.Y)
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stickOffset = Vector2.new(input.Position.X, -input.Position.Y)
		end
	end))
	table.insert(inputs, UserInputService.InputEnded:Connect(function(input)
		if input == holdInput or (holdInput and input.UserInputType == holdInput.UserInputType and input.KeyCode == holdInput.KeyCode and input.UserInputType ~= Enum.UserInputType.Touch) then
			holdInput = nil
			holding = false
		end
	end))

	local function step(dt: number)
		local t = os.clock() - start
		-- The dot wanders: smooth noise plus a slow drift that keeps growing.
		driftAngle += dt * 0.7
		local wander = Vector2.new(math.noise(t * 0.9, seedX), math.noise(t * 0.9, seedY)) * ringPx * params.drift * 2.4
		local slide = Vector2.new(math.cos(driftAngle), math.sin(driftAngle)) * ringPx * params.drift * 0.45 * t
		if holding then
			if holdInput and holdInput.UserInputType == Enum.UserInputType.MouseButton1 then
				lastPointer = pointerPosition()
			end
			correction = (lastPointer - anchor)
		end
		stickAccum += stickOffset * dt * 260
		local scale = Root.scale.Scale > 0 and Root.scale.Scale or 1
		local offset = wander + slide + correction / scale + stickAccum
		local limit = AREA / 2 - 8
		if offset.Magnitude > limit then
			offset = offset.Unit * limit
		end
		ui.dot.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		local inside = offset.Magnitude <= ringPx
		ui.ringStroke.Color = inside and Kit.Colors.Green or Kit.Colors.Red
		if holding then
			if inside then
				steady += dt
			else
				outside += dt
			end
		end
		ui.setSteady(steady / params.required)
		ui.setTime(1 - t / params.limit)
		if steady >= params.required then
			finish(true)
		elseif outside >= params.maxOutside or t >= params.limit then
			finish(false)
		end
	end
	snatchConn = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[Minigames] snatch error:", err)
			finish(false)
		end
		if done then
			for _, conn in inputs do
				conn:Disconnect()
			end
		end
	end)
end

-- Scoop -------------------------------------------------------------------------------

local function buildScoop()
	local panel = Kit.panel({
		Name = "Scoop",
		Size = UDim2.fromOffset(440, 190),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = Root.overlay,
	})
	local title = Kit.label({
		Text = "Gently...",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 8),
		Parent = panel,
	})
	local bar = Kit.new("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 220, 220),
		Parent = panel,
	})
	Kit.corner(12).Parent = bar
	Kit.stroke(Kit.Colors.Stroke, 2).Parent = bar
	local zone = Kit.new("Frame", {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Kit.Colors.Green,
		Parent = bar,
	})
	Kit.corner(10).Parent = zone
	local marker = Kit.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 10, 1, 14),
		BackgroundColor3 = Color3.fromRGB(90, 50, 110),
		ZIndex = 3,
		Parent = bar,
	})
	Kit.corner(4).Parent = marker
	local button = Kit.button({
		Name = "Scoop",
		Text = "SCOOP! [E]",
		TextSize = 26,
		Size = UDim2.fromOffset(220, 58),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Kit.Colors.Green,
		Parent = panel,
	})
	scoopUi = { panel = panel, title = title, zone = zone, marker = marker, button = button }
end

function Minigames.startScoop(sessionId: string, params)
	if scoopConn then
		scoopConn:Disconnect()
	end
	local ui = scoopUi
	local def = Creatures.ById[params.creatureId]
	ui.title.Text = "Gently scoop the " .. (def and def.Name or "creature") .. "!"
	ui.zone.Size = UDim2.fromScale(params.zone, 1)
	ui.panel.Visible = true
	local start = os.clock()
	local done = false
	local marker = 0
	local clickConn, keyConn

	local function finish()
		if done then
			return
		end
		done = true
		if scoopConn then
			scoopConn:Disconnect()
			scoopConn = nil
		end
		if clickConn then
			clickConn:Disconnect()
		end
		if keyConn then
			keyConn:Disconnect()
		end
		local hit = math.abs(marker - 0.5) <= params.zone / 2
		ui.title.Text = hit and "Got it!" or "Boing!"
		Remotes.get("ScoopResult"):FireServer(sessionId, marker)
		task.delay(0.5, function()
			ui.panel.Visible = false
		end)
	end

	clickConn = ui.button.Activated:Connect(finish)
	keyConn = UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then
			return -- typing in chat or a text box
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			finish()
		end
	end)
	scoopConn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) * params.speed
		marker = 1 - math.abs((t % 2) - 1) -- ping-pong 0..1
		ui.marker.Position = UDim2.fromScale(marker, 0.5)
		if os.clock() - start > 7 then
			finish()
		end
	end)
end

function Minigames.isBusy(): boolean
	return (snatchUi.overlay and snatchUi.overlay.Visible) or (scoopUi.panel and scoopUi.panel.Visible) or false
end

function Minigames.init(controllers)
	C = controllers
	buildSnatch()
	buildScoop()
	Remotes.get("SnatchStart").OnClientEvent:Connect(function(sessionId, params)
		C.Panels.close()
		Minigames.startSnatch(sessionId, params)
	end)
	Remotes.get("ScoopStart").OnClientEvent:Connect(function(sessionId, params)
		Minigames.startScoop(sessionId, params)
	end)
end

return Minigames
