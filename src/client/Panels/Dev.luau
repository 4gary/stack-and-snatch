--[[
	Dev: Studio-only test tools. The server ignores these outside Studio.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Dev = {}

local BUTTONS = {
	{ "+1K coins", "coins", 1000 },
	{ "+100K coins", "coins", 100000 },
	{ "+10M coins", "coins", 10000000 },
	{ "Random creature", "give", "random" },
	{ "Give Legendary", "give", "BubbleBunny" },
	{ "Give Mythic", "give", "KazooKoala" },
	{ "Give Lord Jellington", "give", "LordJellington" },
	{ "Golden Toast Cubert", "give", { "Cubert", "GoldenToast" } },
	{ "Fill my tower", "fill" },
	{ "Topple my tower", "toppleMe" },
	{ "Bot tower (6)", "bot", 6 },
	{ "Bot tower (15)", "bot", 15 },
	{ "Clear bots", "clearBots" },
	{ "My protections ON/OFF", "noProtect" },
	{ "Sprinkle Rain now", "weather" },
	{ "Legendary on belt", "conveyor", "Legendary" },
	{ "Mythic on belt", "conveyor", "Mythic" },
	{ "Wild Epic in meadow", "wild", "PillowPossum" },
	{ "Reset shield timer", "shieldReset" },
	{ "Bounce-Back Ticket", "ticket" },
	{ "Skip tutorial", "skipTutorial" },
	{ "Reset my data", "resetData" },
}

function Dev.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Dev", Title = "Dev Tools (Studio only)", Size = UDim2.fromOffset(700, 520), Parent = parent, OnClose = close })
	local scroll = Kit.scroll({ Parent = content })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(210, 46),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	for i, b in BUTTONS do
		Kit.button({
			Text = b[1],
			TextSize = 17,
			LayoutOrder = i,
			Color = (b[2] == "resetData") and Kit.Colors.Red or (i % 2 == 0 and Kit.Colors.Blue or Kit.Colors.Purple),
			Parent = scroll,
			OnClick = function()
				Remotes.get("Dev"):FireServer(b[2], b[3])
			end,
		})
	end
	return frame
end

return Dev
