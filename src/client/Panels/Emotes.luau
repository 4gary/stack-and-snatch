--[[
	Emotes: quick friendly reactions, so the game is fully playable without chat.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Emotes = {}

function Emotes.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Emotes", Title = "DJ Bonk's Emotes", Size = UDim2.fromOffset(460, 280), Parent = parent, OnClose = close })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 54),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	local colors = { Kit.Colors.Pink, Kit.Colors.Blue, Kit.Colors.Green, Kit.Colors.Purple, Kit.Colors.Orange, Kit.Colors.Yellow }
	for i, text in Config.Emotes do
		Kit.button({
			Text = text,
			TextSize = 22,
			LayoutOrder = i,
			Color = colors[(i - 1) % #colors + 1],
			Parent = content,
			OnClick = function()
				Remotes.get("Emote"):FireServer(i)
				close()
			end,
		})
	end
	return frame
end

return Emotes
