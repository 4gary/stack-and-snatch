--[[
	Box: creatures you're storing. Take one into your hands to stack it, or put
	a favorite on the Comfy Cushion.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Creatures)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Box = {}

local ui = {}

function Box.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Box", Title = "My Box", Size = UDim2.fromOffset(560, 480), Parent = parent, OnClose = close })
	ui.header = Kit.label({ Text = "", TextSize = 18, Size = UDim2.new(1, -230, 0, 40), Parent = content })
	ui.store = Kit.button({
		Text = "📦 Put held in Box",
		TextSize = 16,
		Size = UDim2.fromOffset(220, 40),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Color = Kit.Colors.Purple,
		Parent = content,
		OnClick = function()
			Remotes.get("StoreHeld"):FireServer()
		end,
	})
	ui.list = Kit.scroll({ Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 48), Parent = content })
	Kit.list(nil, 6).Parent = ui.list
	return frame
end

function Box.refresh(data)
	ui.header.Text = string.format("%d / %d creatures stored", #data.box, Economy.boxCapacity(data))
	ui.store.Visible = data.held ~= nil
	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") or child.Name == "Empty" then
			child:Destroy()
		end
	end
	local ground = {}
	for _, uid in data.ground or {} do
		ground[uid] = true
	end
	for i, entry in data.box do
		local def = Creatures.ById[entry.id]
		local rarity = Rarities.get(def and def.Rarity or "Common")
		local name = def and def.Name or "???"
		if entry.m then
			name = (Mutations.name(entry.m) or entry.m) .. " " .. name
		end
		local row = Kit.panel({ Size = UDim2.new(1, -12, 0, 50), LayoutOrder = i, Parent = ui.list })
		Kit.label({
			Text = rarity.Badge .. " " .. name .. (ground[entry.u] and "  (on the ground by your tower)" or ""),
			TextSize = 17,
			Size = UDim2.new(1, -230, 0, 24),
			Position = UDim2.fromOffset(10, 3),
			TextColor3 = rarity.Color:Lerp(Kit.Colors.Text, 0.5),
			Parent = row,
		})
		Kit.label({
			Text = string.format("%s · %s · %s/s", rarity.Name, def and Creatures.Shapes[def.Shape].Name or "", Format.number((def and def.Rate or 0) * Mutations.multiplier(entry.m))),
			TextSize = 14,
			Size = UDim2.new(1, -230, 0, 18),
			Position = UDim2.fromOffset(10, 27),
			TextColor3 = Kit.Colors.Muted,
			Parent = row,
		})
		Kit.button({
			Text = "✋ Hold",
			TextSize = 16,
			Size = UDim2.fromOffset(96, 40),
			Position = UDim2.new(1, -112, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = Kit.Colors.Blue,
			Parent = row,
			OnClick = function()
				Remotes.get("TakeFromBox"):FireServer(entry.u)
			end,
		})
		Kit.button({
			Text = "🛋 Cushion",
			TextSize = 15,
			Size = UDim2.fromOffset(100, 40),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = Kit.Colors.Pink,
			Parent = row,
			OnClick = function()
				Remotes.get("TowerAction"):FireServer("cushionFromBox", entry.u)
			end,
		})
	end
	if #data.box == 0 then
		Kit.label({ Text = "Your Box is empty.", TextSize = 17, Size = UDim2.new(1, -12, 0, 40), Parent = ui.list }).Name = "Empty"
	end
end

return Box
