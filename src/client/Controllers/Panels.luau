--[[
	Panels: opens one menu window at a time (shops, Index, tower, box, ...).
	Menus only open when the player taps them - never pop-ups during play.
]]

local Root = require(script.Parent.Parent.UI.Root)

local Panels = {}

local C
local modules = {}
local frames = {}
local current = nil

local NAMES = { "Shop", "Index", "Tower", "Box", "Emotes", "Codes", "Settings", "Dev" }

function Panels.close()
	if current and frames[current] then
		frames[current].Visible = false
	end
	current = nil
end

function Panels.open(name: string, arg: any?)
	local module = modules[name]
	if not module then
		return
	end
	if current and current ~= name then
		Panels.close()
	end
	if not frames[name] then
		frames[name] = module.build(Root.panels, C, Panels.close)
	end
	current = name
	frames[name].Visible = true
	if module.onOpen then
		module.onOpen(arg)
	end
	if module.refresh and C.State.data then
		module.refresh(C.State.data)
	end
end

function Panels.toggle(name: string)
	if current == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

function Panels.isOpen(name: string): boolean
	return current == name
end

function Panels.init(controllers)
	C = controllers
	local folder = script.Parent.Parent.Panels
	for _, name in NAMES do
		local moduleScript = folder:FindFirstChild(name)
		if moduleScript then
			modules[name] = require(moduleScript)
		end
	end
	local function refresh(data)
		local module = current and modules[current]
		if module and module.refresh then
			local ok, err = pcall(module.refresh, data)
			if not ok then
				warn("[Panels]", current, err)
			end
		end
	end
	C.State.changed:Connect(refresh)
	C.State.ticked:Connect(function(data)
		local module = current and modules[current]
		if module and module.tick then
			pcall(module.tick, data)
		end
	end)
end

return Panels
