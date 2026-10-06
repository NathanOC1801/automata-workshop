--!strict

local RunService = game:GetService("RunService")
local ConveyorService = require(script.Services.ConveyorService)
local MachineService = require(script.Services.MachineService)
local PlacementService = require(script.Services.PlacementService)

PlacementService.Init()

local TICK_INTERVAL = 0.1 -- 10 Hz simulation tick rate
local accumulator = 0

print("[Server] Initialized PlacementService, ConveyorService, and MachineService.")

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	while accumulator >= TICK_INTERVAL do
		accumulator -= TICK_INTERVAL

		-- Step machine processing (Drills, Smelters, etc.)
		MachineService.StepMachines(TICK_INTERVAL)

		-- Step conveyor item simulation and sync to clients
		ConveyorService.StepConveyors(TICK_INTERVAL)
	end
end)
