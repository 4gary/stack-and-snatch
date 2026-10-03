--[[
	Settings: Calm mode (less shaking and jiggling), sound, and UI size.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)

local Settings = {}

local C
local ui = {}
local current = { calm = false, sfx = true, uiScale = 1 }
local applied = false

function Settings.apply(settings)
	current.calm = settings.calm == true
	current.sfx = settings.sfx ~= false
	current.uiScale = settings.uiScale or 1
	C.Animator.calm = current.calm
	C.Effects.calm = current.calm
	C.Sound.setEnabled(current.sfx)
	Root.setUserScale(current.uiScale)
end

local function save()
	Settings.apply(current)
	Remotes.get("SaveSettings"):FireServer(current)
	Settings.refresh()
end

function Settings.build(parent, controllers, close)
	C = controllers
	local frame, content = Kit.window({ Name = "Settings", Title = "Settings", Size = UDim2.fromOffset(460, 330), Parent = parent, OnClose = close })
	Kit.list(nil, 10, Enum.HorizontalAlignment.Center).Parent = content
	ui.calm = Kit.button({
		Text = "",
		TextSize = 20,
		Size = UDim2.fromOffset(380, 52),
		LayoutOrder = 1,
		Color = Kit.Colors.Blue,
		Parent = content,
		OnClick = function()
			current.calm = not current.calm
			save()
		end,
	})
	ui.sfx = Kit.button({
		Text = "",
		TextSize = 20,
		Size = UDim2.fromOffset(380, 52),
		LayoutOrder = 2,
		Color = Kit.Colors.Purple,
		Parent = content,
		OnClick = function()
			current.sfx = not current.sfx
			save()
		end,
	})
	Kit.label({ Text = "Text & button size", TextSize = 18, LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center, Parent = content })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(380, 50), LayoutOrder = 4, Parent = content })
	Kit.list(Enum.FillDirection.Horizontal, 8).Parent = row
	ui.sizes = {}
	for i, option in { { "Small", 0.85 }, { "Normal", 1 }, { "Large", 1.15 } } do
		ui.sizes[option[2]] = Kit.button({
			Text = option[1],
			TextSize = 18,
			Size = UDim2.fromOffset(120, 46),
			LayoutOrder = i,
			Color = Kit.Colors.Pink,
			Parent = row,
			OnClick = function()
				current.uiScale = option[2]
				save()
			end,
		})
	end
	Settings.refresh()
	return frame
end

function Settings.refresh()
	if not ui.calm then
		return
	end
	ui.calm.Text = "Calm mode: " .. (current.calm and "ON (less shaking)" or "OFF")
	ui.sfx.Text = "Sound effects: " .. (current.sfx and "ON" or "OFF")
	for scale, btn in ui.sizes do
		btn.BackgroundColor3 = math.abs(scale - current.uiScale) < 0.01 and Kit.Colors.Green or Kit.Colors.Pink
	end
end

-- Apply saved settings from the first state snapshot.
function Settings.init(controllers)
	C = controllers
	C.State.changed:Connect(function(data)
		if not applied and data.settings then
			applied = true
			Settings.apply(data.settings)
		end
	end)
end

return Settings
