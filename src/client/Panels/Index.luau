--[[
	Index: Professor Puddlewick's creature book. Every creature and mutation you
	have ever owned. Undiscovered creatures show as silhouettes.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModel = require(Shared.CreatureModel)
local Creatures = require(Shared.Creatures)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)

local Kit = require(script.Parent.Parent.UI.Kit)

local Index = {}

local ui = { cards = {} }
local selectedId = nil
local lastData = nil

local function viewport(parent, def)
	local vp = Kit.new("ViewportFrame", {
		Size = UDim2.new(1, -8, 0, 96),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 210),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		Parent = parent,
	})
	local model = CreatureModel.build(def.Id, nil)
	if model then
		model:PivotTo(CFrame.new())
		model.Parent = vp
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local size = math.max(def.Width, def.Height)
	camera.CFrame = CFrame.lookAt(Vector3.new(size * 0.7, def.Height * 0.6 + size * 0.5, -size * 2.3), Vector3.new(0, def.Height * 0.45, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

local function showDetails(def)
	selectedId = def.Id
	local data = lastData
	local page = data and data.index[def.Id]
	if not page then
		ui.details.Text = "??? - not discovered yet. Find one on the conveyor or in Muffin Meadows!"
		return
	end
	local rarity = Rarities.get(def.Rarity)
	local muts = {}
	for _, m in Mutations.Order do
		table.insert(muts, (page[m] and "✅ " or "⬜ ") .. Mutations.ById[m].Name .. " x" .. Mutations.ById[m].Multiplier)
	end
	ui.details.Text = string.format(
		"%s  ·  %s %s  ·  %s  ·  %s/s\n%s\nStacking: %s\nMutations: %s",
		def.Name,
		rarity.Badge,
		rarity.Name,
		Creatures.Shapes[def.Shape].Name,
		Format.number(def.Rate),
		def.Trait,
		def.Effect,
		table.concat(muts, "   ")
	)
end

function Index.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Index", Title = "Index - Creature Book", Size = UDim2.fromOffset(820, 560), Parent = parent, OnClose = close })
	ui.header = Kit.label({ Text = "", TextSize = 19, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, Parent = content })
	local scroll = Kit.scroll({ Size = UDim2.new(1, 0, 1, -128), Position = UDim2.fromOffset(0, 28), Parent = content })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(124, 158),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	for i, def in Creatures.List do
		local card = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Kit.Colors.PanelDark,
			LayoutOrder = i,
			Parent = scroll,
		})
		Kit.corner(12).Parent = card
		local stroke = Kit.stroke(Rarities.get(def.Rarity).Color, 3)
		stroke.Parent = card
		local vp = viewport(card, def)
		local name = Kit.label({
			Text = def.Name,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -6, 0, 32),
			Position = UDim2.fromOffset(3, 100),
			Parent = card,
		})
		local rarity = Rarities.get(def.Rarity)
		Kit.label({
			Text = rarity.Badge .. " " .. rarity.Name,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -6, 0, 16),
			Position = UDim2.fromOffset(3, 132),
			TextColor3 = rarity.Color:Lerp(Kit.Colors.Text, 0.35),
			Parent = card,
		})
		local dots = Kit.label({
			Text = "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -8, 0, 14),
			Position = UDim2.fromOffset(4, 4),
			Parent = card,
		})
		card.Activated:Connect(function()
			showDetails(def)
		end)
		ui.cards[def.Id] = { card = card, vp = vp, name = name, dots = dots }
	end
	ui.details = Kit.label({
		Text = "Tap a creature to read about it.",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 92),
		Position = UDim2.new(0, 0, 1, -94),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = content,
	})
	return frame
end

function Index.refresh(data)
	lastData = data
	local found = Economy.indexCount(data.index)
	ui.header.Text = string.format(
		"%d / %d discovered  ·  +%d%% coins forever",
		found,
		#Creatures.List,
		math.floor(found * Config.Economy.IndexBonusPerCreature * 100 + 0.5)
	)
	for _, def in Creatures.List do
		local card = ui.cards[def.Id]
		local page = data.index[def.Id]
		if page then
			card.vp.ImageColor3 = Color3.new(1, 1, 1)
			card.name.Text = def.Name
			local marks = ""
			for _, m in Mutations.Order do
				if page[m] then
					marks ..= (m == "GoldenToast" and "🟡" or m == "Glittery" and "✨" or "🌈")
				end
			end
			card.dots.Text = marks
		else
			card.vp.ImageColor3 = Color3.new(0, 0, 0)
			card.name.Text = "???"
			card.dots.Text = ""
		end
	end
	if selectedId then
		showDetails(Creatures.ById[selectedId])
	end
end

return Index
