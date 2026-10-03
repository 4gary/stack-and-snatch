--[[
	Signal: a tiny in-script event (connect / fire), used by client controllers.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self.handlers
	handlers[fn] = true
	return {
		Disconnect = function()
			handlers[fn] = nil
		end,
	}
end

function Signal:Fire(...)
	for fn in table.clone(self.handlers) do
		task.spawn(fn, ...)
	end
end

return Signal
