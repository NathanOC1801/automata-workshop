--!strict

local RunService = game:GetService("RunService")
local ConveyorService = require(script.Services.ConveyorService)

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

-- Insert an initial item into Slot 1 of C1
c1.slots[1].itemId = "RawIron"
c1.slots[1].progress = 1.0

print("[Server] Initialized 3-node conveyor chain test. Inserted 'RawIron' into C1 Slot 1.")

local tickCount = 0
local MAX_TEST_TICKS = 15

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	while accumulator >= TICK_INTERVAL do
		accumulator -= TICK_INTERVAL
		tickCount += 1

		ConveyorService.StepConveyors(TICK_INTERVAL)

		if tickCount <= MAX_TEST_TICKS then
			-- Find current item position for logging
			local foundPos = "None"
			for _, coord in ipairs({ c1Coord, c2Coord, c3Coord }) do
				local conv = ConveyorService.GetConveyor(coord)
				if conv then
					for _, slot in ipairs(conv.slots) do
						if slot.itemId then
							foundPos = string.format("Cell (%d,%d,%d) Slot %d", coord.X, coord.Y, coord.Z, slot.slotIndex)
							break
						end
					end
				end
			end
			print(string.format("[Conveyor Test - Tick %02d] Item Location: %s", tickCount, foundPos))
		end
	end
end)
