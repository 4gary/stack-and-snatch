--[[
	ConveyorPath: where a creature on Captain Conveyor's belt is at a given time.

	The belt is a circle around the Sneeze Plaza. Both the server (to check you
	are close enough to buy) and the client (to animate smoothly) use this, so
	the server never has to stream positions every frame.
]]

local Config = require(script.Parent.Config)

local ConveyorPath = {}

local C = Config.Conveyor

ConveyorPath.StartAngle = 0 -- radians; the Fluff-O-Matic chute points here

function ConveyorPath.duration(): number
	return (2 * math.pi * C.Radius * C.LoopFraction) / C.Speed
end

-- Bottom-center CFrame of an item that has been riding for `elapsed` seconds.
-- `itemHeight` lifts it so it sits on the belt; the creature faces where it's going.
function ConveyorPath.cframeAt(elapsed: number): CFrame
	local angle = ConveyorPath.StartAngle + (C.Speed * elapsed) / C.Radius
	local pos = Vector3.new(C.Radius * math.cos(angle), C.BeltTopY, C.Radius * math.sin(angle))
	-- Tangent for counter-clockwise travel (increasing angle).
	local forward = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return CFrame.lookAt(pos, pos + forward)
end

function ConveyorPath.positionAt(elapsed: number): Vector3
	return ConveyorPath.cframeAt(elapsed).Position
end

return ConveyorPath
