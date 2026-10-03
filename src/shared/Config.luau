--[[
	Config: every tunable number in one place.

	Anything marked "design suggestion" in the design doc lives here so it can be
	balanced without touching game logic. Times are in seconds, distances in studs.
]]

local Config = {}

Config.GameName = "Stack & Snatch"
Config.CurrencyName = "Giggle Coins"

-- Map ------------------------------------------------------------------------
Config.Map = {
	PlotCount = 8,
	PlotRingRadius = 128, -- distance of base pad centers from the plaza center
	PadRadius = 20,
	PadTopY = 1, -- top surface of a base pad
	PlateRadius = 7,
	PlateTopY = 1.6, -- top surface of the stacking plate (towers start here)
	PlazaRadius = 42,
	IslandRadius = 185,
	MeadowInner = 60,
	MeadowOuter = 100,
	CushionOffset = Vector3.new(-9, 0, 4), -- relative to the plate, in plot space
}

-- Stacking & wobble ("rules decide, animation shows") ------------------------
Config.Wobble = {
	Capacity = 100, -- tower topples when the wobble score goes above this
	HeightGrowth = 0.03, -- every layer up adds 3% to that layer's wobble
	OffsetPenaltyMax = 6, -- wobble added by a drop at the very edge of the swing
	LeanPenaltyPerStud = 0.8, -- wobble per stud the stack has drifted off-center
	MinAbsorbFactor = 0.3, -- squishy creatures can soak up at most 70% of wobble
	-- Base wobble a layer gets from the shape *underneath* it.
	BelowByShape = {
		Flat = 0.6,
		Blocky = 1.2,
		Round = 5,
		Squishy = 2,
		Pointy = 7,
		Weird = 1.5,
	},
	-- Extra wobble from the shape of the creature being placed on top.
	AboveByShape = {
		Flat = 0,
		Blocky = 0,
		Round = 0.8,
		Squishy = 0.3,
		Pointy = -0.2,
		Weird = 0.5,
	},
}

-- The placement "swing": the ghost creature sways in a figure-8 over the tower
-- and you tap DROP when it is centered. The swing is a pure function of server
-- time so the server can recompute exactly where you dropped it.
Config.Pendulum = {
	Amplitude = 2.0,
	BasePeriod = 2.6,
	MinPeriod = 1.2,
	PeriodShrinkPerLayer = 0.03,
	TimestampTolerance = 0.5, -- how far a reported drop time may be from server time
}

-- Economy ----------------------------------------------------------------------
Config.Economy = {
	HeightBonusPerLayer = 0.10, -- each layer adds +10% to the whole tower
	IndexBonusPerCreature = 0.02, -- design suggestion: +2% per creature in your Index
	CushionIncomeMultiplier = 1, -- cushion creatures earn base rate (no height bonus)
	NapIncomeMultiplier = 0.5,
	OfflineIncomeMultiplier = 0.10,
	OfflineMaxSeconds = 8 * 60 * 60,
	TutorialCoinGift = 100,
	TickSeconds = 1,
	CoinPopEvery = 3, -- seconds between floating "+coins" pops over a tower
}

-- Upgrades (all bought with Giggle Coins only; nothing here is ever sold for Robux).
Config.Upgrades = {
	Glue = {
		Title = "Sticky Jam",
		Npc = "Grandma Gloop",
		Levels = {
			{ Cost = 0, Reduce = 0.00, Ring = 0 },
			{ Cost = 300, Reduce = 0.08, Ring = 1 },
			{ Cost = 3000, Reduce = 0.16, Ring = 2 },
			{ Cost = 30000, Reduce = 0.24, Ring = 3 },
			{ Cost = 250000, Reduce = 0.32, Ring = 4 },
		},
	},
	Base = {
		Title = "Base Pad",
		Npc = "Bricklebee",
		Levels = {
			{ Cost = 0, Slots = 10, Box = 8 },
			{ Cost = 200, Slots = 16, Box = 10 },
			{ Cost = 2500, Slots = 24, Box = 12 },
			{ Cost = 25000, Slots = 36, Box = 15 },
			{ Cost = 200000, Slots = 50, Box = 20 },
		},
	},
	Shield = {
		Title = "Bubble Shield",
		Npc = "Lou the Locksmith",
		Levels = {
			{ Cost = 0, Duration = 30, Recharge = 150 },
			{ Cost = 500, Duration = 40, Recharge = 135 },
			{ Cost = 1500, Duration = 50, Recharge = 120 },
			{ Cost = 15000, Duration = 60, Recharge = 105 },
			{ Cost = 120000, Duration = 75, Recharge = 90 },
		},
	},
}
Config.UpgradeOrder = { "Glue", "Base", "Shield" }

-- Conveyor (Captain Conveyor's belt) -----------------------------------------
Config.Conveyor = {
	Radius = 50,
	BeltTopY = 0.6,
	Speed = 7, -- studs per second
	LoopFraction = 0.95, -- how much of the loop an item rides before going back in
	SpawnInterval = 3.5,
	MaxItems = 16,
	BuyDistance = 14,
	-- Spawn weights per rarity (design suggestion).
	Weights = {
		Common = 62,
		Uncommon = 25,
		Rare = 9.5,
		Epic = 3,
		Legendary = 0.4,
		Mythic = 0.09,
		Secret = 0.01,
	},
	-- Guaranteed timers so players can plan for big arrivals.
	LegendaryEvery = 240,
	MythicEvery = 720,
	-- Chance a conveyor creature arrives already mutated.
	MutationChances = {
		{ Mutation = "GoldenToast", Chance = 0.004 },
		{ Mutation = "Glittery", Chance = 0.03 },
		{ Mutation = "Sprinkled", Chance = 0.02 },
	},
}

-- Muffin Meadows (free wild creatures you scoop with a timing tap) ------------
Config.Meadows = {
	MaxWild = 6,
	RespawnInterval = 10,
	ScoopDistance = 12,
	FailCooldown = 3,
	Weights = {
		Common = 70,
		Uncommon = 22,
		Rare = 6.5,
		Epic = 1.4,
		Legendary = 0.1,
	},
	-- Width of the green zone on the scoop bar (fraction of the bar) by rarity.
	ZoneByRarity = {
		Common = 0.30,
		Uncommon = 0.24,
		Rare = 0.18,
		Epic = 0.13,
		Legendary = 0.09,
		Mythic = 0.07,
		Secret = 0.05,
	},
	MarkerSpeedByRarity = {
		Common = 0.9,
		Uncommon = 1.05,
		Rare = 1.2,
		Epic = 1.4,
		Legendary = 1.6,
		Mythic = 1.8,
		Secret = 2.0,
	},
}

-- Protection & fairness (section 4.4) -------------------------------------------
Config.Protection = {
	ArrivalBubbleSeconds = 180, -- free shield on join; also stays up until you move
	NapAfterSeconds = 120, -- idle this long and your tower falls asleep
	NewStackerSeconds = 20 * 60, -- first 20 minutes of total playtime
	RuffledFeathersSeconds = 90, -- free protection after being snatched from
	BounceBackSeconds = 300, -- revenge-snatch ticket lifetime
	CushionSlots = 1,
	FairRange = {
		MinFraction = 0.5, -- can snatch towers at least half your height...
		MaxMultiplier = 2, -- ...and at most double your height...
		MinCap = 6, -- ...but small towers can always reach towers up to this tall
		MaxExtra = 5, -- and always at least your height + 5
	},
	IntruderNoticeRange = 32,
	IntruderNoticeCooldown = 20,
}

-- Snatching (section 4.3) ---------------------------------------------------------
Config.Snatch = {
	PromptDistance = 12,
	ServerDistanceSlack = 8,
	HopUpTime = 0.7,
	BaseRing = 0.34, -- ring radius as a fraction of the minigame area
	RingShrinkPerGlue = 0.035,
	BaseDrift = 0.55, -- how hard the dot wanders (fraction of ring radius per second)
	DriftPerGlue = 0.08,
	BaseRequired = 2.0, -- seconds of steady pulling needed
	RequiredStability = 1.2, -- + up to this many seconds for a very steady tower
	RequiredPerRarity = 0.25, -- + this per rarity tier of the top creature
	ExtraTime = 2.5, -- time limit = required + this
	MaxOutside = 0.75, -- seconds outside the ring before the tower topples
	StunSeconds = 2,
	CarryTimeout = 120,
	BoopRange = 11,
	BoopCooldown = 1.2,
	BoopKnockback = 45,
	CarrySpeedByRarity = {
		Common = 15,
		Uncommon = 14,
		Rare = 13,
		Epic = 12,
		Legendary = 11,
		Mythic = 10,
		Secret = 9,
	},
	PerfectFlagStreak = 6, -- log players who are "perfect" this many times in a row
}

-- Weather (one type for launch: Sprinkle Rain) -----------------------------------
Config.Weather = {
	FirstDelay = 240,
	Interval = 900,
	Duration = 120,
	MutationChance = 0.35, -- chance a creature stacked during the rain gets Sprinkled
}

Config.RibbonHeights = { 10, 25, 50, 100 }

Config.Quests = {
	{ Id = "reach5", Text = "Reach 5 tall", Reward = 150 },
	{ Id = "catchRare", Text = "Catch a Rare (or better)", Reward = 500 },
	{ Id = "realSnatch", Text = "Do a real snatch", Reward = 300 },
}

Config.Emotes = { "LOL!", "Nice snatch!", "Boop!", "Wheee!", "Ahoy!", "Oops!" }
Config.EmoteCooldown = 2

-- Codes (small rewards only; never creatures).
Config.Codes = {
	BOING = { Coins = 250 },
	WOBBLE = { Coins = 500 },
	GIGGLES = { Coins = 1000 },
}

Config.Data = {
	StoreName = "StackAndSnatch_PlayerData_v1",
	AutosaveInterval = 60,
	SessionLockStale = 30 * 60, -- a lock older than this is treated as abandoned
	LoadRetries = 5,
	LoadRetryDelay = 4,
}

-- Sounds. Built-in engine sounds are used as placeholders; paste your own
-- Creator Store sound ids ("rbxassetid://123") here to replace them.
Config.Sounds = {
	Stack = "rbxasset://sounds/electronicpingshort.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Wobble = "rbxasset://sounds/action_jump_land.mp3",
	Snatch = "rbxasset://sounds/swoosh.wav",
	Topple = "rbxasset://sounds/action_falling.mp3",
	Restack = "rbxasset://sounds/action_jump.mp3",
	Boop = "rbxasset://sounds/action_jump_land.mp3",
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Sneeze = "rbxasset://sounds/swoosh.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Music = "", -- e.g. a bouncy ukulele track id
}

return Config
