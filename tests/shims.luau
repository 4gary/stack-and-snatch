-- Minimal Roblox shims so the pure shared modules run outside Roblox.
__modules = {}
local loaded = {}

local function proxy(name)
	return { __module = name }
end

function __scriptFor(name)
	return {
		Name = name,
		Parent = setmetatable({}, {
			__index = function(_, key)
				return proxy(key)
			end,
		}),
	}
end

function require(target)
	local name = target.__module
	if loaded[name] == nil then
		local factory = __modules[name]
		assert(factory, "no module named " .. tostring(name))
		loaded[name] = factory(__scriptFor(name))
	end
	return loaded[name]
end

Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end

Vector3 = {}
function Vector3.new(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ seed = seed or 1 }, Random)
end
function Random:NextNumber(a, b)
	self.seed = (self.seed * 1103515245 + 12345) % 2147483648
	local f = self.seed / 2147483648
	if a then
		return a + (b - a) * f
	end
	return f
end
function Random:NextInteger(a, b)
	return math.floor(self:NextNumber(a, b + 1))
end

-- Tiny assertion helpers --------------------------------------------------------
local passed, failures = 0, {}
function check(cond, message)
	if cond then
		passed += 1
	else
		table.insert(failures, message)
	end
end
function near(a, b, eps, message)
	check(math.abs(a - b) <= (eps or 1e-6), (message or "near") .. string.format(" (got %.4f, want %.4f)", a, b))
end
function __finish(name)
	print(string.format("%s: %d checks passed", name, passed))
	if #failures > 0 then
		for _, f in failures do
			print("  FAIL: " .. f)
		end
		error(string.format("%d check(s) failed in %s", #failures, name))
	end
end
