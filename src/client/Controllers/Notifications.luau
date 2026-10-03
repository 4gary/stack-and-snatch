--[[
	Notifications: friendly banners from the cast ("RARE ONE AHOY!").
	Gentle and rare; never purchase pop-ups.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)

local Notifications = {}

local C
local holder
local MAX = 4

local NPC_COLORS = {
	["Professor Puddlewick"] = Color3.fromRGB(110, 170, 255),
	["Grandma Gloop"] = Color3.fromRGB(255, 120, 160),
	["Captain Conveyor"] = Color3.fromRGB(80, 120, 210),
	["Lou the Locksmith"] = Color3.fromRGB(110, 180, 90),
	["Bricklebee"] = Color3.fromRGB(230, 170, 30),
	["Sneaky Pete"] = Color3.fromRGB(120, 120, 200),
	["DJ Bonk"] = Color3.fromRGB(80, 180, 80),
	["Mayor Marshmallow"] = Color3.fromRGB(200, 120, 200),
}

local KIND_COLORS = {
	info = Color3.fromRGB(255, 249, 242),
	good = Color3.fromRGB(225, 255, 225),
	warn = Color3.fromRGB(255, 238, 210),
	rare = Color3.fromRGB(225, 235, 255),
	legendary = Color3.fromRGB(255, 240, 180),
}

function Notifications.show(payload)
	local kind = payload.kind or "info"
	local frame = Kit.panel({
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = KIND_COLORS[kind] or KIND_COLORS.info,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = holder,
	})
	Kit.padding(10).Parent = frame
	Kit.list(nil, 2).Parent = frame
	if payload.npc then
		Kit.label({
			Text = payload.npc,
			TextSize = 18,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 20),
			TextColor3 = NPC_COLORS[payload.npc] or Kit.Colors.Text,
			Parent = frame,
		})
	end
	Kit.label({
		Text = payload.text or "",
		TextSize = kind == "legendary" and 22 or 19,
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = frame })
	Kit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "legendary" or kind == "rare" then
		C.Sound.play("Rare", { pitch = kind == "legendary" and 1.3 or 1.1 })
	end

	local banners = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(banners, child)
		end
	end
	if #banners > MAX then
		table.sort(banners, function(a, b)
			return a.LayoutOrder < b.LayoutOrder -- newest first
		end)
		for i = MAX + 1, #banners do
			banners[i]:Destroy()
		end
	end
	task.delay(kind == "legendary" and 7 or 5, function()
		if frame.Parent then
			Kit.tween(scale, 0.2, { Scale = 0 })
			task.wait(0.2)
			frame:Destroy()
		end
	end)
end

function Notifications.init(controllers)
	C = controllers
	holder = Kit.new("Frame", {
		Name = "Banners",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 400),
		Position = UDim2.new(0.5, 0, 0, 128),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = Root.toasts,
	})
	local layout = Kit.list(nil, 6, Enum.HorizontalAlignment.Center)
	layout.Parent = holder
	Remotes.get("Notify").OnClientEvent:Connect(Notifications.show)
end

return Notifications
