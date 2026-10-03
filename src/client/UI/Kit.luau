--[[
	Kit: tiny UI toolkit. Big, friendly, rounded, candy-colored, mobile-first.
]]

local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne

Kit.Colors = {
	Panel = Color3.fromRGB(255, 249, 242),
	PanelDark = Color3.fromRGB(250, 236, 245),
	Stroke = Color3.fromRGB(130, 80, 150),
	Text = Color3.fromRGB(85, 50, 95),
	TextLight = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(150, 125, 160),
	Pink = Color3.fromRGB(255, 130, 175),
	Blue = Color3.fromRGB(110, 185, 255),
	Green = Color3.fromRGB(110, 205, 120),
	Yellow = Color3.fromRGB(255, 205, 70),
	Orange = Color3.fromRGB(255, 165, 80),
	Red = Color3.fromRGB(240, 90, 100),
	Purple = Color3.fromRGB(175, 120, 255),
	Grey = Color3.fromRGB(190, 180, 195),
	Gold = Color3.fromRGB(255, 210, 70),
}

-- Kit.new("Frame", { Size = ..., Parent = ... }, { children })
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(radius: number?)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Kit.round()
	return Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Kit.stroke(color: Color3?, thickness: number?)
	return Kit.new("UIStroke", {
		Color = color or Kit.Colors.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(color: Color3?, thickness: number?)
	return Kit.new("UIStroke", {
		Color = color or Color3.fromRGB(70, 35, 80),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Kit.padding(px: number)
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.list(direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?)
	return Kit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Kit.label(props: { [string]: any })
	local defaults = {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.Text,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	return Kit.new("TextLabel", defaults)
end

function Kit.panel(props: { [string]: any })
	local defaults = {
		BackgroundColor3 = Kit.Colors.Panel,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = Kit.new("Frame", defaults)
	Kit.corner(16).Parent = frame
	Kit.stroke().Parent = frame
	return frame
end

function Kit.tween(inst: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

Kit.clickSound = nil -- set by the Sound controller

-- A chunky button. props.OnClick is called on activation.
function Kit.button(props: { [string]: any })
	local onClick = props.OnClick
	local color = props.Color or Kit.Colors.Pink
	local btn = Kit.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = Kit.Font,
		Text = props.Text or "",
		TextColor3 = props.TextColor or Kit.Colors.TextLight,
		TextSize = props.TextSize or 22,
		TextWrapped = true,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	Kit.corner(props.Radius or 14).Parent = btn
	Kit.stroke(color:Lerp(Color3.new(0, 0, 0), 0.35), 3).Parent = btn
	Kit.textStroke(color:Lerp(Color3.new(0, 0, 0), 0.5), 1.5).Parent = btn
	local scale = Kit.new("UIScale", { Parent = btn })
	btn.MouseButton1Down:Connect(function()
		Kit.tween(scale, 0.08, { Scale = 0.92 })
	end)
	btn.MouseButton1Up:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	btn.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	if onClick then
		btn.Activated:Connect(function()
			if Kit.clickSound then
				Kit.clickSound()
			end
			onClick(btn)
		end)
	end
	return btn
end

function Kit.setButtonEnabled(btn: TextButton, enabled: boolean, color: Color3?)
	btn.AutoButtonColor = enabled
	btn.BackgroundColor3 = enabled and (color or btn.BackgroundColor3) or Kit.Colors.Grey
	btn.Active = enabled
end

-- A centered window with a title and a close button. Returns frame, content.
function Kit.window(props: { [string]: any })
	local frame = Kit.panel({
		Name = props.Name or "Window",
		Size = props.Size or UDim2.fromOffset(620, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = props.Parent,
	})
	local title = Kit.label({
		Name = "Title",
		Text = props.Title or "",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -120, 0, 44),
		Position = UDim2.fromOffset(60, 6),
		TextColor3 = props.TitleColor or Kit.Colors.Text,
		Parent = frame,
	})
	Kit.button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -52, 0, 8),
		Color = Kit.Colors.Red,
		Parent = frame,
		OnClick = function()
			if props.OnClose then
				props.OnClose()
			else
				frame.Visible = false
			end
		end,
	})
	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.fromOffset(12, 56),
		Parent = frame,
	})
	return frame, content, title
end

function Kit.scroll(props: { [string]: any })
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Colors.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		defaults[k] = v
	end
	return Kit.new("ScrollingFrame", defaults)
end

-- A horizontal fill bar. Returns the frame and a setter (fraction, color?).
function Kit.bar(props: { [string]: any })
	local frame = Kit.new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 16),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.fromRGB(235, 225, 235),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Kit.round().Parent = frame
	Kit.stroke(Kit.Colors.Stroke, 2).Parent = frame
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or Kit.Colors.Green,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Kit.round().Parent = fill
	local function set(fraction: number, color: Color3?)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return frame, set
end

-- Green -> yellow -> red for a 0..1 wobble ratio.
function Kit.wobbleColor(ratio: number): Color3
	if ratio < 0.5 then
		return Kit.Colors.Green:Lerp(Kit.Colors.Yellow, ratio / 0.5)
	end
	return Kit.Colors.Yellow:Lerp(Kit.Colors.Red, math.clamp((ratio - 0.5) / 0.5, 0, 1))
end

return Kit
