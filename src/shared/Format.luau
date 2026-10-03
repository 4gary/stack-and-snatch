--[[
	Format: friendly number and time strings ("1.2K", "3.4M", "2:05").
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	local text
	if n < 1000 then
		if n < 10 and math.floor(n) ~= n then
			text = string.format("%.1f", n)
		else
			text = tostring(math.floor(n))
		end
	else
		local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
		local scaled = n / 10 ^ (tier * 3)
		if scaled >= 100 then
			text = string.format("%d%s", math.floor(scaled), SUFFIXES[tier + 1])
		else
			text = string.format("%.1f%s", math.floor(scaled * 10) / 10, SUFFIXES[tier + 1])
		end
	end
	return negative and ("-" .. text) or text
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

return Format
