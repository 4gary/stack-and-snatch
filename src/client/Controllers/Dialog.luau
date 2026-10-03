--[[
	Dialog: the tutorial's NPC dialog box plus a bouncing arrow that points at
	what to do next (your plate, the conveyor, the practice tower, the shield).
]]

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)

local Dialog = {}

local C
local ui = {}
local arrowTarget = nil
local arrowGui: BillboardGui? = nil
local arrowPart: BasePart? = nil
local typing = 0

local function buildArrow()
	local part = Instance.new("Part")
	part.Name = "TutorialArrow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 6)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⬇️"
	label.TextScaled = true
	label.Font = Kit.Font
	label.Parent = gui
	gui.Enabled = false
	gui.Parent = part
	arrowGui = gui
	arrowPart = part
end

local function targetPosition(): Vector3?
	if arrowTarget == "plate" then
		local origin = C.State.myOrigin()
		return origin and origin.Position + Vector3.new(0, 7, 0)
	elseif arrowTarget == "conveyor" then
		local hrp = C.State.rootPart()
		if hrp then
			local p = hrp.Position
			local flat = Vector3.new(p.X, 0, p.Z)
			local dir = flat.Magnitude > 1 and flat.Unit or Vector3.new(1, 0, 0)
			return dir * Config.Conveyor.Radius + Vector3.new(0, 7, 0)
		end
	elseif arrowTarget == "practice" then
		for _, pegs in CollectionService:GetTagged("SnatchPegs") do
			if pegs:GetAttribute("Practice") then
				return pegs.Position + Vector3.new(0, 16, 0)
			end
		end
	end
	return nil
end

local function setArrow(target: string?)
	arrowTarget = target
	C.Hud.pulseShield(target == "shield")
end

local function build()
	local box = Kit.panel({
		Name = "Dialog",
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(12, 280),
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		Visible = false,
		Parent = Root.hud,
	})
	Kit.padding(12).Parent = box
	Kit.list(nil, 6).Parent = box
	ui.box = box
	ui.npc = Kit.label({ Text = "", TextSize = 22, LayoutOrder = 1, TextColor3 = Kit.Colors.Pink, Parent = box })
	ui.text = Kit.label({
		Text = "",
		TextSize = 19,
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = box,
	})
	ui.progress = Kit.label({ Text = "", TextSize = 17, LayoutOrder = 3, TextColor3 = Kit.Colors.Green, Visible = false, Parent = box })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = box })
	Kit.list(Enum.FillDirection.Horizontal, 8).Parent = row
	ui.ok = Kit.button({
		Text = "Got it!",
		TextSize = 18,
		Size = UDim2.fromOffset(120, 38),
		Color = Kit.Colors.Green,
		LayoutOrder = 1,
		Parent = row,
		OnClick = function()
			box.Visible = false
		end,
	})
	ui.skip = Kit.button({
		Text = "Skip tutorial",
		TextSize = 16,
		Size = UDim2.fromOffset(130, 38),
		Color = Kit.Colors.Grey,
		LayoutOrder = 2,
		Parent = row,
		OnClick = function()
			Remotes.get("Tutorial"):FireServer("skip")
			box.Visible = false
			setArrow(nil)
		end,
	})
end

function Dialog.show(payload)
	ui.box.Visible = true
	ui.npc.Text = payload.npc or ""
	ui.progress.Visible = payload.progress ~= nil
	ui.progress.Text = payload.progress or ""
	ui.skip.Visible = payload.canSkip == true
	ui.ok.Text = payload.final and "Let's stack!" or "Got it!"
	setArrow(payload.arrow)
	-- typewriter
	typing += 1
	local token = typing
	local text = payload.text or ""
	ui.text.Text = ""
	task.spawn(function()
		local len = utf8.len(text) or #text
		for i = 1, len, 2 do
			if token ~= typing then
				return
			end
			local cut = utf8.offset(text, i + 2)
			ui.text.Text = cut and string.sub(text, 1, cut - 1) or text
			task.wait(0.012)
		end
		if token == typing then
			ui.text.Text = text
		end
	end)
	if payload.final then
		setArrow(nil)
	end
end

function Dialog.init(controllers)
	C = controllers
	build()
	buildArrow()
	Remotes.get("Dialog").OnClientEvent:Connect(Dialog.show)
	C.State.changed:Connect(function(data)
		if data.tutorial >= 99 and arrowTarget then
			setArrow(nil)
		end
	end)
end

function Dialog.start()
	local t = 0
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		t += dt
		local pos = arrowTarget and targetPosition()
		if pos and arrowGui and arrowPart then
			arrowGui.Enabled = true
			arrowPart.Position = pos + Vector3.new(0, math.abs(math.sin(t * 4)) * 2, 0)
		elseif arrowGui then
			arrowGui.Enabled = false
		end
	end)
end

return Dialog
