--[[
	Hud: everything on screen during play (design doc 4.7).

	  Top center   Giggle Coins, coins per second, event timers
	  Top left     tower height, wobble, Fair Snatch Range, protections
	  Top right    the other towers in this server
	  Right        big Shield and Boop buttons
	  Bottom       Index, Shops, Tower, Box, Emotes, Codes, Settings (+ Dev in Studio)
	  Bottom mid   what you're holding, with DROP / Box it
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.Creatures)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Wobble = require(Shared.Wobble)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)

local Hud = {}

local C -- controllers
local State
local ui = {}

local function creatureTitle(entry): (string, Color3)
	local def = Creatures.ById[entry.id]
	if not def then
		return "???", Kit.Colors.Text
	end
	local rarity = Rarities.get(def.Rarity)
	local name = def.Name
	if entry.m then
		name = (Mutations.name(entry.m) or entry.m) .. " " .. name
	end
	return name .. "  " .. rarity.Badge .. " " .. rarity.Name, rarity.Color
end

-- Builders --------------------------------------------------------------------------

local function buildCoins(parent)
	local pill = Kit.panel({
		Name = "Coins",
		Size = UDim2.fromOffset(320, 58),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 244, 205),
		Parent = parent,
	})
	ui.coins = Kit.label({
		Text = "🪙 0",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 2),
		TextColor3 = Color3.fromRGB(150, 95, 20),
		Parent = pill,
	})
	ui.rate = Kit.label({
		Text = "+0/s",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 36),
		TextColor3 = Color3.fromRGB(120, 160, 60),
		Parent = pill,
	})
	ui.timers = Kit.label({
		Name = "Timers",
		Text = "",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(640, 22),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Kit.Colors.TextLight,
		Parent = parent,
	})
	Kit.textStroke(nil, 2).Parent = ui.timers
	ui.carry = Kit.label({
		Name = "Carry",
		Text = "",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(700, 30),
		Position = UDim2.new(0.5, 0, 0, 94),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Kit.Colors.Yellow,
		Visible = false,
		Parent = parent,
	})
	Kit.textStroke(nil, 2.5).Parent = ui.carry
end

local function buildTowerCard(parent)
	local card = Kit.panel({
		Name = "TowerCard",
		Size = UDim2.fromOffset(270, 112),
		Position = UDim2.fromOffset(12, 10),
		Parent = parent,
	})
	Kit.padding(10).Parent = card
	Kit.list(nil, 4).Parent = card
	ui.height = Kit.label({ Text = "🗼 Tower 0 / 10", TextSize = 22, LayoutOrder = 1, Parent = card })
	local barHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 2, Parent = card })
	Kit.label({ Text = "Wobble", TextSize = 16, Size = UDim2.fromOffset(62, 18), Parent = barHolder })
	local _, setWobble = Kit.bar({ Size = UDim2.new(1, -66, 0, 14), Position = UDim2.fromOffset(64, 2), Parent = barHolder })
	ui.setWobble = setWobble
	ui.range = Kit.label({ Text = "Snatch range: 0-6 tall", TextSize = 16, LayoutOrder = 3, TextColor3 = Kit.Colors.Muted, Parent = card })
	ui.saveNote = Kit.label({
		Text = "⚠️ Not saving (Studio test)",
		TextSize = 14,
		LayoutOrder = 4,
		TextColor3 = Kit.Colors.Orange,
		Visible = false,
		Parent = card,
	})

	ui.chips = Kit.new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(270, 140),
		Position = UDim2.fromOffset(12, 128),
		Parent = parent,
	})
	Kit.list(nil, 4).Parent = ui.chips
end

local function chip(text: string, color: Color3, order: number)
	local label = Kit.label({
		Text = text,
		TextSize = 16,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = Kit.Colors.Text,
		LayoutOrder = order,
		TextWrapped = false,
		Parent = ui.chips,
	})
	Kit.corner(10).Parent = label
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = label })
	return label
end

local function buildServerList(parent)
	local panel = Kit.panel({
		Name = "ServerTowers",
		Size = UDim2.fromOffset(230, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -12, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 0.1,
		Parent = parent,
	})
	Kit.padding(8).Parent = panel
	Kit.list(nil, 2).Parent = panel
	Kit.label({ Text = "Server Towers", TextSize = 18, LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	ui.serverList = panel
	ui.serverRows = {}
end

local function roundButton(parent, props)
	local btn = Kit.button({
		Name = props.Name,
		Text = props.Text,
		TextSize = props.TextSize or 22,
		Size = UDim2.fromOffset(props.Size, props.Size),
		Position = props.Position,
		AnchorPoint = Vector2.new(1, 0.5),
		Color = props.Color,
		Radius = props.Size,
		Parent = parent,
		OnClick = props.OnClick,
	})
	local sub = Kit.label({
		Name = "Sub",
		Text = props.Sub or "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 20, 0, 18),
		Position = UDim2.new(0.5, 0, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Kit.Colors.TextLight,
		Parent = btn,
	})
	Kit.textStroke(nil, 2).Parent = sub
	return btn, sub
end

local function buildActions(parent)
	ui.shield, ui.shieldSub = roundButton(parent, {
		Name = "Shield",
		Text = "🛡️\nShield",
		Size = 96,
		Position = UDim2.new(1, -14, 0.5, -70),
		Color = Kit.Colors.Blue,
		Sub = "Ready! [G]",
		OnClick = function()
			Remotes.get("ActivateShield"):FireServer()
		end,
	})
	ui.boop, ui.boopSub = roundButton(parent, {
		Name = "Boop",
		Text = "✋\nBoop",
		Size = 84,
		Position = UDim2.new(1, -20, 0.5, 52),
		Color = Kit.Colors.Pink,
		Sub = "[F]",
		OnClick = function()
			Hud.boop()
		end,
	})
	local pulse = Kit.new("UIStroke", {
		Color = Kit.Colors.Yellow,
		Thickness = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ui.shield,
	})
	ui.shieldPulse = pulse
end

local BOTTOM = {
	{ Id = "Index", Icon = "📖", Label = "Index" },
	{ Id = "Shop", Icon = "🛒", Label = "Shops" },
	{ Id = "Tower", Icon = "🗼", Label = "Tower" },
	{ Id = "Box", Icon = "📦", Label = "Box" },
	{ Id = "Emotes", Icon = "😄", Label = "Emotes" },
	{ Id = "Codes", Icon = "🎁", Label = "Codes" },
	{ Id = "Settings", Icon = "⚙️", Label = "Settings" },
	{ Id = "Dev", Icon = "🛠️", Label = "Dev", StudioOnly = true },
}

local function buildBottomBar(parent)
	local bar = Kit.new("Frame", {
		Name = "BottomBar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 70),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
	})
	local layout = Kit.list(Enum.FillDirection.Horizontal, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar
	ui.bottomButtons = {}
	for i, item in BOTTOM do
		local btn = Kit.button({
			Name = item.Id,
			Text = item.Icon,
			TextSize = 30,
			Size = UDim2.fromOffset(64, 64),
			Color = i % 2 == 0 and Kit.Colors.Purple or Kit.Colors.Pink,
			LayoutOrder = i,
			Visible = not item.StudioOnly,
			Parent = bar,
			OnClick = function()
				C.Panels.toggle(item.Id)
			end,
		})
		local caption = Kit.label({
			Text = item.Label,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.new(0, 0, 1, -16),
			TextColor3 = Kit.Colors.TextLight,
			Parent = btn,
		})
		Kit.textStroke(nil, 1.5).Parent = caption
		ui.bottomButtons[item.Id] = btn
	end
end

local function buildHeldPanel(parent)
	local panel = Kit.panel({
		Name = "Held",
		Size = UDim2.fromOffset(520, 84),
		Position = UDim2.new(0.5, 0, 1, -86),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = parent,
	})
	ui.held = panel
	ui.heldTitle = Kit.label({
		Text = "",
		TextSize = 22,
		Size = UDim2.new(1, -250, 0, 28),
		Position = UDim2.fromOffset(14, 8),
		Parent = panel,
	})
	ui.heldHint = Kit.label({
		Text = "",
		TextSize = 16,
		Size = UDim2.new(1, -250, 0, 40),
		Position = UDim2.fromOffset(14, 36),
		TextColor3 = Kit.Colors.Muted,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})
	ui.drop = Kit.button({
		Name = "Drop",
		Text = "DROP! [Q]",
		TextSize = 24,
		Size = UDim2.fromOffset(130, 62),
		Position = UDim2.new(1, -110, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Kit.Colors.Green,
		Parent = panel,
		OnClick = function()
			C.Placement.drop()
		end,
	})
	ui.store = Kit.button({
		Name = "Store",
		Text = "📦 Box it",
		TextSize = 18,
		Size = UDim2.fromOffset(92, 62),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Kit.Colors.Purple,
		Parent = panel,
		OnClick = function()
			Remotes.get("StoreHeld"):FireServer()
		end,
	})

	-- the placement wobble preview ("jelly-bean bar")
	local preview = Kit.panel({
		Name = "Preview",
		Size = UDim2.fromOffset(360, 44),
		Position = UDim2.new(0.5, 0, 1, -180),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = parent,
	})
	ui.preview = preview
	ui.previewText = Kit.label({
		Text = "",
		TextSize = 17,
		Size = UDim2.new(0, 150, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Parent = preview,
	})
	local _, setPreview = Kit.bar({ Size = UDim2.new(1, -176, 0, 16), Position = UDim2.new(0, 166, 0.5, -8), Parent = preview })
	ui.setPreview = setPreview
end

-- Updates ----------------------------------------------------------------------------

function Hud.setPreview(visible: boolean, ratio: number?)
	ui.preview.Visible = visible
	if visible and ratio then
		local text = ratio > 1 and "TOPPLE RISK!" or ("Wobble after drop: " .. Format.percent(ratio))
		ui.previewText.Text = text
		ui.previewText.TextColor3 = ratio > 1 and Kit.Colors.Red or Kit.Colors.Text
		ui.setPreview(ratio, Kit.wobbleColor(ratio))
	end
end

function Hud.pulseShield(on: boolean)
	ui.shieldPulse.Thickness = on and 6 or 0
	ui.pulseShield = on
end

function Hud.boop()
	Remotes.get("Boop"):FireServer()
end

local function updateCoins(data)
	ui.coins.Text = "🪙 " .. Format.number(data.coins)
	local napping = data.protection and data.protection.napping
	ui.rate.Text = "+" .. Format.number(data.rate) .. "/s" .. (napping and "  💤 napping (50%)" or "")
end

local function updateProtection(data)
	for _, child in ui.chips:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local p = data.protection
	if not p then
		return
	end
	local order = 0
	local function add(text, color)
		order += 1
		chip(text, color, order)
	end
	if p.shieldLeft > 0 then
		add("🛡️ Bubble Shield " .. Format.time(p.shieldLeft), Color3.fromRGB(190, 235, 255))
	end
	if p.arrival then
		local text = p.arrivalLeft > 0 and ("🫧 Arrival Bubble " .. Format.time(p.arrivalLeft)) or "🫧 Arrival Bubble (until you move)"
		add(text, Color3.fromRGB(255, 215, 240))
	end
	if p.newStacker then
		add("🌱 New Stacker " .. Format.time(p.newStackerLeft), Color3.fromRGB(205, 255, 200))
	end
	if p.napping then
		add("💤 Nap Mode (move to wake)", Color3.fromRGB(220, 210, 255))
	end
	if p.ruffledLeft > 0 then
		add("🪶 Ruffled Feathers " .. Format.time(p.ruffledLeft), Color3.fromRGB(255, 235, 190))
	end
	if p.devNoProtection then
		add("🛠️ Dev: protections off", Color3.fromRGB(255, 200, 200))
	end
	local ticket = data.ticket
	if ticket then
		local left = ticket.expires - State.now()
		if left > 0 then
			add("🎟️ Bounce-Back vs " .. ticket.name .. " " .. Format.time(left), Color3.fromRGB(255, 225, 160))
		end
	end

	-- shield button
	if p.shieldLeft > 0 then
		ui.shieldSub.Text = "Up " .. Format.time(p.shieldLeft)
		Kit.setButtonEnabled(ui.shield, false)
	elseif p.shieldReadyIn > 0 then
		ui.shieldSub.Text = "Recharge " .. Format.time(p.shieldReadyIn)
		Kit.setButtonEnabled(ui.shield, false)
	else
		ui.shieldSub.Text = "Ready! [G]"
		Kit.setButtonEnabled(ui.shield, true, Kit.Colors.Blue)
	end
end

local function updateTower(data)
	local slots = Economy.maxSlots(data)
	ui.height.Text = string.format("🗼 Tower %d / %d tall", #data.tower, slots)
	local ratio = Wobble.ratio(data.tower, Economy.glueReduce(data))
	ui.setWobble(ratio, Kit.wobbleColor(ratio))
	local lo, hi = Economy.fairRange(#data.tower)
	ui.range.Text = string.format("Snatch range: %d-%d tall", lo, hi)
	ui.saveNote.Visible = not data.canSave
	ui.bottomButtons.Dev.Visible = data.isStudio == true
end

local function updateHeld(data)
	local held = data.held
	local carrying = data.carrying
	if carrying then
		ui.held.Visible = false
		local left = Config.Snatch.CarryTimeout - (State.now() - carrying.started)
		local def = Creatures.ById[carrying.id]
		ui.carry.Visible = true
		ui.carry.Text = string.format("🏃 Run home with %s's %s! (%s)", carrying.fromName, def and def.Name or "creature", Format.time(left))
		return
	end
	ui.carry.Visible = false
	if not held then
		ui.held.Visible = false
		return
	end
	ui.held.Visible = true
	local title, color = creatureTitle(held)
	ui.heldTitle.Text = title
	ui.heldTitle.TextColor3 = color:Lerp(Kit.Colors.Text, 0.45)
	local onPad = State.onOwnPad()
	local full = #data.tower >= Economy.maxSlots(data)
	if data.toppling then
		ui.heldHint.Text = "Your tower is bouncing back..."
	elseif full then
		ui.heldHint.Text = "Tower full! Upgrade your base or Box it."
	elseif onPad then
		ui.heldHint.Text = #data.tower == 0 and "Tap DROP to set it on your plate!" or "Tap DROP when the ghost is centered over the tower!"
	else
		ui.heldHint.Text = "Walk to your base pad to stack it."
	end
	Kit.setButtonEnabled(ui.drop, onPad and not full and not data.toppling, Kit.Colors.Green)
end

local function updateServerList()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	local rows = {}
	for _, model in plots:GetChildren() do
		local name = model:GetAttribute("OwnerName")
		if name and name ~= "" then
			table.insert(rows, {
				name = name,
				height = model:GetAttribute("Height") or 0,
				status = model:GetAttribute("Status") or "",
				shield = (model:GetAttribute("ShieldUntil") or 0) > State.now(),
				mine = State.data and model:GetAttribute("PlotIndex") == State.data.plotIndex,
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.height > b.height
	end)
	for i, row in rows do
		local label = ui.serverRows[i]
		if not label then
			label = Kit.label({ TextSize = 15, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, Parent = ui.serverList })
			ui.serverRows[i] = label
		end
		local icon = ""
		if row.shield then
			icon = " 🛡️"
		elseif string.find(row.status, "💤", 1, true) then
			icon = " 💤"
		elseif row.status ~= "" then
			icon = " 🫧"
		end
		label.Text = string.format("%s%s - %d tall%s", row.mine and "⭐ " or "", row.name, row.height, icon)
		label.Visible = true
	end
	for i = #rows + 1, #ui.serverRows do
		ui.serverRows[i].Visible = false
	end
end

local function updateTimers()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	if not gs then
		return
	end
	local now = State.now()
	local parts = {}
	local nextLeg = gs:GetAttribute("NextLegendaryAt")
	if nextLeg then
		table.insert(parts, "★ Legendary in " .. Format.time(nextLeg - now))
	end
	local nextMyth = gs:GetAttribute("NextMythicAt")
	if nextMyth then
		table.insert(parts, "✦ Mythic in " .. Format.time(nextMyth - now))
	end
	if gs:GetAttribute("WeatherActive") then
		table.insert(parts, "🌈 Sprinkle Rain! " .. Format.time((gs:GetAttribute("WeatherEndsAt") or now) - now) .. " left")
	elseif gs:GetAttribute("NextWeatherAt") then
		table.insert(parts, "🌈 Sprinkle Rain in " .. Format.time(gs:GetAttribute("NextWeatherAt") - now))
	end
	ui.timers.Text = table.concat(parts, "   ·   ")
end

local function refresh(data)
	if not data then
		return
	end
	updateCoins(data)
	updateProtection(data)
	updateTower(data)
	updateHeld(data)
end

function Hud.init(controllers)
	C = controllers
	State = C.State
	local parent = Root.hud
	buildCoins(parent)
	buildTowerCard(parent)
	buildServerList(parent)
	buildActions(parent)
	buildBottomBar(parent)
	buildHeldPanel(parent)

	State.changed:Connect(refresh)
	State.ticked:Connect(function(data)
		updateCoins(data)
		updateProtection(data)
	end)

	ContextActionService:BindAction("StackShield", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Remotes.get("ActivateShield"):FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
	ContextActionService:BindAction("StackBoop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Hud.boop()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
end

function Hud.start()
	local pulseT = 0
	while true do
		task.wait(0.25)
		pulseT += 0.25
		pcall(updateTimers)
		pcall(updateServerList)
		if State.data then
			pcall(updateHeld, State.data)
		end
		if ui.pulseShield then
			ui.shieldPulse.Thickness = (math.floor(pulseT * 2) % 2 == 0) and 6 or 2
		end
	end
end

return Hud
