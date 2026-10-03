--[[
	Root: the one ScreenGui everything lives in, with layers and a UIScale so
	the same layout works on phones, tablets, PCs and consoles.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Kit = require(script.Parent.Kit)

local Root = {}

Root.userScale = 1

local function layer(name: string, z: number)
	return Kit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = Root.gui,
	})
end

function Root.updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local base = math.min(size.X / 1280, (size.Y - 58) / 680)
	Root.scale.Scale = math.clamp(base, 0.5, 1.25) * Root.userScale
end

function Root.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	Root.gui = Kit.new("ScreenGui", {
		Name = "StackAndSnatch",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	Root.scale = Kit.new("UIScale", { Parent = Root.gui })
	Root.hud = layer("Hud", 1)
	Root.panels = layer("Panels", 5)
	Root.overlay = layer("Overlay", 10)
	Root.toasts = layer("Toasts", 20)

	Root.updateScale()
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(Root.updateScale)
			Root.updateScale()
		end
	end
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	-- Our "Server Towers" list replaces the default player list.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function Root.setUserScale(scale: number)
	Root.userScale = scale
	Root.updateScale()
end

return Root
