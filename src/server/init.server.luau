--!strict

local RunService = game:GetService("RunService")
local ConveyorService = require(script.Services.ConveyorService)
local MachineService = require(script.Services.MachineService)
local PlacementService = require(script.Services.PlacementService)
local EconomyService = require(script.Services.EconomyService)
local SaveService = require(script.Services.SaveService)

EconomyService.Init()
PlacementService.Init()
SaveService.Init()

local TICK_INTERVAL = 0.1 -- 10 Hz simulation tick rate
local accumulator = 0

print("[Server] Initialized EconomyService, PlacementService, SaveService, ConveyorService, and MachineService.")

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt
	while accumulator >= TICK_INTERVAL do
		accumulator -= TICK_INTERVAL

		-- Step machine processing (Drills, Smelters, Splitters, Mergers, Storage, Sinks, Assemblers)
		MachineService.StepMachines(TICK_INTERVAL)

		-- Step conveyor item simulation and sync to clients
		ConveyorService.StepConveyors(TICK_INTERVAL)
	end
end)
