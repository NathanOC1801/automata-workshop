--!strict

local RunService = game:GetService("RunService")
local ConveyorService = require(script.Services.ConveyorService)
local PlacementService = require(script.Services.PlacementService)

PlacementService.Init()

local TICK_INTERVAL = 0.1 -- 10 Hz simulation tick rate
local accumulator = 0

-- Setup a mock 3-node conveyor chain:
-- C1 at (0, 0, 0), orientation 90 deg (+X)
-- C2 at (1, 0, 0), orientation 90 deg (+X)
-- C3 at (2, 0, 0), orientation 90 deg (+X)
local c1Coord = Vector3int16.new(0, 0, 0)
local c2Coord = Vector3int16.new(1, 0, 0)
local c3Coord = Vector3int16.new(2, 0, 0)

local c1 = ConveyorService.CreateConveyor(c1Coord, 90)
ConveyorService.CreateConveyor(c2Coord, 90)
ConveyorService.CreateConveyor(c3Coord, 90)

print("[Server] Initialized PlacementService and 3-node conveyor chain test.")

local spawnToggle = false

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	while accumulator >= TICK_INTERVAL do
		accumulator -= TICK_INTERVAL

		-- Continuous spawner: if C1 Slot 1 is empty, insert alternating test item
		if c1.slots[1].itemId == nil then
			spawnToggle = not spawnToggle
			local newItemId = spawnToggle and "RawIron" or "RawCopper"
			c1.slots[1].itemId = newItemId
			c1.slots[1].progress = 1.0
		end

		ConveyorService.StepConveyors(TICK_INTERVAL)
	end
end)
