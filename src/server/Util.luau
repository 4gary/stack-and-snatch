--[[
	Util: small server helpers shared by the services.
]]

local HttpService = game:GetService("HttpService")

local Util = {}

-- Server clock shared with clients (workspace:GetServerTimeNow()).
function Util.now(): number
	return workspace:GetServerTimeNow()
end

-- Short unique id for every creature, so a creature can only ever be in one place.
function Util.uid(): string
	return string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 12)
end

function Util.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Util.character(player: Player?)
	if not player then
		return nil, nil, nil
	end
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return character, nil, nil
	end
	return character, hrp, humanoid
end

function Util.findIndex(list: { any }, predicate: (any) -> boolean): number?
	for i, v in list do
		if predicate(v) then
			return i
		end
	end
	return nil
end

function Util.findByUid(list: { any }, uid: string): number?
	for i, v in list do
		if type(v) == "table" and v.u == uid then
			return i
		end
	end
	return nil
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

-- Rate limiter: returns true at most once every `seconds` per key.
function Util.throttle(store: { [any]: number }, key: any, seconds: number): boolean
	local t = os.clock()
	if store[key] and t - store[key] < seconds then
		return false
	end
	store[key] = t
	return true
end

return Util
