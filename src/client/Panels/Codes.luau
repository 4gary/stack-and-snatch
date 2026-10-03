--[[
	Codes: small coin rewards (never creatures), so YouTubers have something to share.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Kit = require(script.Parent.Parent.UI.Kit)

local Codes = {}

function Codes.build(parent, _, close)
	local frame, content = Kit.window({ Name = "Codes", Title = "Codes", Size = UDim2.fromOffset(460, 260), Parent = parent, OnClose = close })
	local box = Kit.new("TextBox", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Kit.Font,
		PlaceholderText = "Type a code...",
		Text = "",
		TextSize = 24,
		TextColor3 = Kit.Colors.Text,
		ClearTextOnFocus = false,
		Parent = content,
	})
	Kit.corner(12).Parent = box
	Kit.stroke(Kit.Colors.Stroke, 2).Parent = box
	local result = Kit.label({
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 124),
		Parent = content,
	})
	Kit.button({
		Text = "Redeem",
		TextSize = 22,
		Size = UDim2.fromOffset(200, 50),
		Position = UDim2.new(0.5, 0, 0, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Kit.Colors.Green,
		Parent = content,
		OnClick = function()
			result.Text = "..."
			local ok, message = pcall(function()
				return Remotes.get("RedeemCode"):InvokeServer(box.Text)
			end)
			result.Text = ok and tostring(message) or "Oops, try again!"
		end,
	})
	return frame
end

return Codes
