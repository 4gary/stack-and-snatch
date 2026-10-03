--[[
	Weather: every ~15 minutes the sky does something silly for 2 minutes.
	Launch has one type, Sprinkle Rain: creatures stacked during it can come out
	Sprinkled. State lives on ReplicatedStorage.GameState so clients can show it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(script.Parent.Parent.Util)

local Weather = {}

local S
local W = Config.Weather
local active = false
local endsAt = 0
local nextAt = 0

local function state()
	return ReplicatedStorage:WaitForChild("GameState")
end

function Weather.isActive(): boolean
	return active and Util.now() < endsAt
end

function Weather.begin(duration: number?)
	active = true
	endsAt = Util.now() + (duration or W.Duration)
	nextAt = endsAt + W.Interval
	local gs = state()
	gs:SetAttribute("WeatherActive", true)
	gs:SetAttribute("WeatherName", "Sprinkle Rain")
	gs:SetAttribute("WeatherEndsAt", endsAt)
	gs:SetAttribute("NextWeatherAt", nextAt)
	S.Sync.notifyAll("BONK-BONK! It's Sprinkle Rain! Stack creatures now for a chance at Sprinkled!", "rare", "DJ Bonk")
end

local function finish()
	active = false
	local gs = state()
	gs:SetAttribute("WeatherActive", false)
	gs:SetAttribute("NextWeatherAt", nextAt)
	S.Sync.notifyAll("The Sprinkle Rain stopped. See you next time!", "info", "DJ Bonk")
end

function Weather.init(services)
	S = services
end

function Weather.start()
	nextAt = Util.now() + W.FirstDelay
	local gs = state()
	gs:SetAttribute("WeatherActive", false)
	gs:SetAttribute("NextWeatherAt", nextAt)
	while true do
		task.wait(1)
		local now = Util.now()
		if active and now >= endsAt then
			finish()
		elseif not active and now >= nextAt then
			Weather.begin()
		end
	end
end

return Weather
