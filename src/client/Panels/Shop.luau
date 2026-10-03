--[[
	Shop: Grandma Gloop (Sticky Jam), Bricklebee (Base), Lou the Locksmith
	(Bubble Shield + Comfy Cushion). Giggle Coins only.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Shop = {}

local ui = {}
local selected = "Glue"

local QUOTES = {
	Glue = "\"A little jam fixes everything, sweetie!\" Sticky Jam makes every layer wobble less, and makes the snatch ring smaller for raiders.",
	Base = "\"Bzzt! Let's build it bigger!\" A bigger base pad holds a taller tower and a bigger Box.",
	Shield = "\"Slow and steady... keeps the tower steady.\" Bubble Shields block snatching completely while they're up.",
}

local function describe(track: string, level)
	if not level then
		return "-"
	end
	if track == "Glue" then
		return string.format("Wobble -%d%% · snatch ring tighter (Lv %d)", math.floor(level.Reduce * 100 + 0.5), level.Ring)
	elseif track == "Base" then
		return string.format("%d tower slots · %d Box spaces", level.Slots, level.Box)
	elseif track == "Shield" then
		return string.format("Shield lasts %ds · recharges in %ds", level.Duration, level.Recharge)
	end
	return ""
end

local C

function Shop.build(parent, controllers, close)
	C = controllers
	local frame, content = Kit.window({ Name = "Shop", Title = "Shops", Size = UDim2.fromOffset(600, 430), Parent = parent, OnClose = close })
	local tabs = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = content })
	Kit.list(Enum.FillDirection.Horizontal, 8).Parent = tabs
	ui.tabs = {}
	for i, track in Config.UpgradeOrder do
		local info = Config.Upgrades[track]
		ui.tabs[track] = Kit.button({
			Text = info.Npc,
			TextSize = 17,
			Size = UDim2.fromOffset(182, 44),
			LayoutOrder = i,
			Color = Kit.Colors.Purple,
			Parent = tabs,
			OnClick = function()
				selected = track
				if C.State.data then
					Shop.refresh(C.State.data)
				end
			end,
		})
	end
	local body = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 56), Parent = content })
	Kit.list(nil, 8).Parent = body
	ui.title = Kit.label({ Text = "", TextSize = 26, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), Parent = body })
	ui.quote = Kit.label({ Text = "", TextSize = 17, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 60), TextColor3 = Kit.Colors.Muted, Parent = body })
	ui.level = Kit.label({ Text = "", TextSize = 20, LayoutOrder = 3, Parent = body })
	ui.now = Kit.label({ Text = "", TextSize = 18, LayoutOrder = 4, Parent = body })
	ui.next = Kit.label({ Text = "", TextSize = 18, LayoutOrder = 5, TextColor3 = Color3.fromRGB(70, 140, 70), Parent = body })
	ui.buy = Kit.button({
		Text = "Upgrade",
		TextSize = 22,
		Size = UDim2.fromOffset(260, 52),
		LayoutOrder = 6,
		Color = Kit.Colors.Green,
		Parent = body,
		OnClick = function()
			Remotes.get("BuyUpgrade"):FireServer(selected)
		end,
	})
	ui.extra = Kit.label({ Text = "", TextSize = 16, LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 44), TextColor3 = Kit.Colors.Muted, Parent = body })
	return frame
end

function Shop.onOpen(track: any)
	if type(track) == "string" and Config.Upgrades[track] then
		selected = track
	end
end

function Shop.refresh(data)
	local info = Config.Upgrades[selected]
	for track, btn in ui.tabs do
		btn.BackgroundColor3 = track == selected and Kit.Colors.Pink or Kit.Colors.Purple
	end
	local current, level, maxLevel = Economy.upgradeLevel(data, selected)
	local nextLevel = Economy.nextUpgrade(data, selected)
	ui.title.Text = info.Npc .. " - " .. info.Title
	ui.quote.Text = QUOTES[selected] or ""
	ui.level.Text = string.format("Level %d / %d", level, maxLevel)
	ui.now.Text = "Now: " .. describe(selected, current)
	if nextLevel then
		ui.next.Text = "Next: " .. describe(selected, nextLevel)
		ui.buy.Text = "Upgrade · 💰" .. Format.number(nextLevel.Cost)
		Kit.setButtonEnabled(ui.buy, data.coins >= nextLevel.Cost, Kit.Colors.Green)
	else
		ui.next.Text = "Maxed out!"
		ui.buy.Text = "MAX"
		Kit.setButtonEnabled(ui.buy, false)
	end
	if selected == "Shield" then
		ui.extra.Text = "Comfy Cushion: your favorite creature sits beside your tower and can NEVER be snatched. Move one there from the Tower or Box menu."
	else
		ui.extra.Text = "Everything here is bought with Giggle Coins. Protection is earned, never bought."
	end
end

Shop.tick = Shop.refresh

return Shop
