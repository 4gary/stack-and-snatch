--[[
	Sound: plays the game's sound effects (ids live in Config.Sounds).
	Boops rise in pitch as towers get taller; nothing is ever loud or scary.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Sound = {}

Sound.enabled = true

local VOLUMES = {
	Stack = 0.5,
	Coin = 0.25,
	Wobble = 0.4,
	Snatch = 0.6,
	Topple = 0.6,
	Restack = 0.4,
	Boop = 0.6,
	Click = 0.25,
	Rare = 0.5,
	Sneeze = 0.35,
	Splash = 0.4,
}

-- opts: { pitch, volume, position (Vector3) }
function Sound.play(name: string, opts: any?)
	if not Sound.enabled then
		return
	end
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	opts = opts or {}
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (opts.volume or VOLUMES[name] or 0.5)
	sound.PlaybackSpeed = opts.pitch or 1
	if opts.position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = opts.position
		holder.Parent = workspace
		sound.RollOffMaxDistance = 260
		sound.Parent = holder
		sound:Play()
		Debris:AddItem(holder, 6)
	else
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 6)
	end
end

function Sound.init()
	local music = Config.Sounds.Music
	if music and music ~= "" then
		local track = Instance.new("Sound")
		track.Name = "Music"
		track.SoundId = music
		track.Looped = true
		track.Volume = 0.25
		track.Parent = SoundService
		track:Play()
		Sound.music = track
	end
end

function Sound.setEnabled(on: boolean)
	Sound.enabled = on
	if Sound.music then
		Sound.music.Volume = on and 0.25 or 0
	end
end

return Sound
