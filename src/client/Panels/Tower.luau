--[[
	Tower: manage your stack. Reorder creatures (the stacking puzzle!), move a
	favorite to the Comfy Cushion, or take one into your hands. Changes that
	would make the tower too wobbly are refused by the server.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Creatures)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Wobble = require(Shared.Wobble)

local Kit = require(script.Parent.Parent.UI.Kit)

local Tower = {}

local ui = {}

local function entryName(entry): string
	local def = Creatures.ById[entry.id]
	local name = def and def.Name or "???"
	if entry.m then
		name = (Mutations.name(entry.m) or entry.m) .. " " .. name
	end
	return name
end

local function smallButton(parent, text, color, order, onClick)
	return Kit.button({
		Text = text,
		TextSize = 18,
		Size = UDim2.fromOffset(44, 40),
		Color = color,
		LayoutOrder = order,
		Parent = parent,
		OnClick = onClick,
	})
end

local function action(name: string, uid: any)
	Remotes.get("TowerAction"):FireServer(name, uid)
end

function Tower.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Tower", Title = "My Tower", Size = UDim2.fromOffset(640, 520), Parent = parent, OnClose = close })
	ui.header = Kit.label({ Text = "", TextSize = 18, Size = UDim2.new(1, 0, 0, 24), Parent = content })
	ui.cushion = Kit.panel({
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Color3.fromRGB(255, 225, 240),
		Parent = content,
	})
	ui.cushionText = Kit.label({ Text = "", TextSize = 17, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = ui.cushion })
	ui.cushionTake = Kit.button({
		Text = "✋ Take",
		TextSize = 17,
		Size = UDim2.fromOffset(100, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Kit.Colors.Blue,
		Parent = ui.cushion,
		OnClick = function()
			action("uncushion", "1")
		end,
	})
	ui.list = Kit.scroll({ Size = UDim2.new(1, 0, 1, -116), Position = UDim2.fromOffset(0, 86), Parent = content })
	Kit.list(nil, 6).Parent = ui.list
	Kit.label({
		Text = "Top of the tower is listed first. ▲▼ reorder · 🛋 move to Comfy Cushion · ✋ take into your hands",
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -26),
		TextColor3 = Kit.Colors.Muted,
		Parent = content,
	})
	return frame
end

function Tower.refresh(data)
	local tower = data.tower
	local ratio = Wobble.ratio(tower, Economy.glueReduce(data))
	ui.header.Text = string.format(
		"%d / %d tall  ·  Wobble %s  ·  Sticky Jam Lv %d  ·  %s coins/s",
		#tower,
		Economy.maxSlots(data),
		Format.percent(ratio),
		data.upgrades.Glue,
		Format.number(data.rate or 0)
	)
	local cushion = data.cushions[1]
	if type(cushion) == "table" then
		ui.cushionText.Text = "🛋 Comfy Cushion: " .. entryName(cushion) .. " (never snatchable)"
		ui.cushionTake.Visible = true
	else
		ui.cushionText.Text = "🛋 Comfy Cushion: empty - a creature here can never be snatched"
		ui.cushionTake.Visible = false
	end

	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") or child.Name == "Empty" then
			child:Destroy()
		end
	end
	local multiplier = Economy.heightMultiplier(tower)
	for i = #tower, 1, -1 do
		local entry = tower[i]
		local def = Creatures.ById[entry.id]
		local rarity = Rarities.get(def and def.Rarity or "Common")
		local row = Kit.panel({
			Size = UDim2.new(1, -12, 0, 50),
			LayoutOrder = #tower - i,
			BackgroundColor3 = i == #tower and Color3.fromRGB(255, 240, 220) or Kit.Colors.Panel,
			Parent = ui.list,
		})
		Kit.label({
			Text = string.format("%d. %s %s", i, rarity.Badge, entryName(entry)) .. (i == #tower and "  (top - snatchable!)" or ""),
			TextSize = 17,
			Size = UDim2.new(1, -230, 0, 24),
			Position = UDim2.fromOffset(10, 3),
			TextColor3 = rarity.Color:Lerp(Kit.Colors.Text, 0.5),
			Parent = row,
		})
		Kit.label({
			Text = string.format("%s · %s/s", def and Creatures.Shapes[def.Shape].Name or "", Format.number(Economy.creatureRate(tower, i) * multiplier)),
			TextSize = 14,
			Size = UDim2.new(1, -230, 0, 18),
			Position = UDim2.fromOffset(10, 27),
			TextColor3 = Kit.Colors.Muted,
			Parent = row,
		})
		local buttons = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(212, 40),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = row,
		})
		Kit.list(Enum.FillDirection.Horizontal, 4).Parent = buttons
		smallButton(buttons, "▲", Kit.Colors.Purple, 1, function()
			action("up", entry.u)
		end).Visible = i < #tower
		smallButton(buttons, "▼", Kit.Colors.Purple, 2, function()
			action("down", entry.u)
		end).Visible = i > 1
		smallButton(buttons, "🛋", Kit.Colors.Pink, 3, function()
			action("cushion", entry.u)
		end)
		smallButton(buttons, "✋", Kit.Colors.Blue, 4, function()
			action("take", entry.u)
		end)
	end
	if #tower == 0 then
		Kit.label({ Text = "Your tower is empty! Buy a creature from Captain Conveyor and DROP it on your plate.", TextSize = 17, Size = UDim2.new(1, -12, 0, 50), Parent = ui.list }).Name = "Empty"
	end
end

return Tower
