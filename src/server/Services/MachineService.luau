--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)

export type MachineInstance = {
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number,
	timer: number,
	recipe: Types.Recipe?,
	outputBuffer: string?,
}

local MachineService = {}

local machines: { [string]: MachineInstance } = {}

local function coordToKey(coord: Vector3int16): string
	return string.format("%d,%d,%d", coord.X, coord.Y, coord.Z)
end

function MachineService.GetForwardOffset(orientation: number): Vector3int16
	if orientation == 0 then
		return Vector3int16.new(0, 0, -1)
	elseif orientation == 90 then
		return Vector3int16.new(1, 0, 0)
	elseif orientation == 180 then
		return Vector3int16.new(0, 0, 1)
	elseif orientation == 270 then
		return Vector3int16.new(-1, 0, 0)
	else
		return Vector3int16.new(0, 0, -1)
	end
end

function MachineService.GetBehindOffset(orientation: number): Vector3int16
	local fwd = MachineService.GetForwardOffset(orientation)
	return Vector3int16.new(-fwd.X, -fwd.Y, -fwd.Z)
end

function MachineService.CreateMachine(coord: Vector3int16, category: Types.MachineCategory, orientation: number): MachineInstance
	local key = coordToKey(coord)
	local machine: MachineInstance = {
		coord = coord,
		category = category,
		orientation = orientation,
		timer = 0,
		recipe = nil,
		outputBuffer = nil,
	}

	machines[key] = machine
	GridService.SetCell(coord, {
		machineId = string.format("%s_%s", category, key),
		category = category,
		orientation = orientation,
	})

	return machine
end

function MachineService.GetMachine(coord: Vector3int16): MachineInstance?
	local key = coordToKey(coord)
	return machines[key]
end

function MachineService.RemoveMachine(coord: Vector3int16)
	local key = coordToKey(coord)
	machines[key] = nil
	GridService.ClearCell(coord)
end

local function findMatchingRecipe(inputId: string): Types.Recipe?
	for _, recipe in pairs(Recipes) do
		if recipe.inputs[inputId :: Types.ItemId] ~= nil then
			return recipe
		end
	end
	return nil
end

function MachineService.StepMachines(dt: number)
	for _, machine in pairs(machines) do
		local fwdOffset = MachineService.GetForwardOffset(machine.orientation)
		local frontCoord = Vector3int16.new(
			machine.coord.X + fwdOffset.X,
			machine.coord.Y + fwdOffset.Y,
			machine.coord.Z + fwdOffset.Z
		)

		if machine.category == "Drill" then
			-- Drill produces 1 RawIron every 2.0s
			machine.timer += dt
			if machine.timer >= 2.0 then
				local frontConveyor = ConveyorService.GetConveyor(frontCoord)
				if frontConveyor then
					local slot1 = frontConveyor.slots[1]
					if slot1.itemId == nil then
						slot1.itemId = "RawIron"
						slot1.progress = 1.0
						machine.timer = 0 -- reset timer on successful ejection
					end
				end
			end

		elseif machine.category == "Smelter" then
			-- Attempt to eject outputBuffer first
			if machine.outputBuffer ~= nil then
				local frontConveyor = ConveyorService.GetConveyor(frontCoord)
				if frontConveyor then
					local slot1 = frontConveyor.slots[1]
					if slot1.itemId == nil then
						slot1.itemId = machine.outputBuffer :: Types.ItemId
						slot1.progress = 1.0
						machine.outputBuffer = nil
					end
				end
			end

			-- If actively crafting
			if machine.recipe ~= nil then
				machine.timer += dt
				if machine.timer >= machine.recipe.craftDuration then
					-- Finished craft! Get output item
					local outputItem: string? = nil
					for itemId, count in pairs(machine.recipe.outputs) do
						outputItem = itemId
						break
					end
					machine.outputBuffer = outputItem
					machine.recipe = nil
					machine.timer = 0
				end
			-- If idle and outputBuffer is clear, attempt to pull input from Behind conveyor's Slot 4
			elseif machine.outputBuffer == nil then
				local behindOffset = MachineService.GetBehindOffset(machine.orientation)
				local behindCoord = Vector3int16.new(
					machine.coord.X + behindOffset.X,
					machine.coord.Y + behindOffset.Y,
					machine.coord.Z + behindOffset.Z
				)
				local behindConveyor = ConveyorService.GetConveyor(behindCoord)
				if behindConveyor then
					local slot4 = behindConveyor.slots[4]
					if slot4.itemId ~= nil then
						local matchingRecipe = findMatchingRecipe(slot4.itemId)
						if matchingRecipe and matchingRecipe.machineType == "Smelter" then
							-- Pull input item and start crafting
							slot4.itemId = nil
							slot4.progress = 0.0
							machine.recipe = matchingRecipe
							machine.timer = 0
						end
					end
				end
			end
		end
	end
end

return MachineService
