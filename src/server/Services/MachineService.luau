--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)
local EconomyService = require(script.Parent.EconomyService)

export type MachineInstance = {
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number,
	timer: number,
	recipe: Types.Recipe?,
	outputBuffer: string?,
	splitterIndex: number, -- 1 = Front, 2 = Left, 3 = Right
	mergerIndex: number, -- 1 = Left, 2 = Behind, 3 = Right
	storageQueue: { string },
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

function MachineService.GetLeftOffset(orientation: number): Vector3int16
	if orientation == 0 then
		return Vector3int16.new(-1, 0, 0)
	elseif orientation == 90 then
		return Vector3int16.new(0, 0, -1)
	elseif orientation == 180 then
		return Vector3int16.new(1, 0, 0)
	elseif orientation == 270 then
		return Vector3int16.new(0, 0, 1)
	else
		return Vector3int16.new(-1, 0, 0)
	end
end

function MachineService.GetRightOffset(orientation: number): Vector3int16
	local left = MachineService.GetLeftOffset(orientation)
	return Vector3int16.new(-left.X, -left.Y, -left.Z)
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
		splitterIndex = 1,
		mergerIndex = 1,
		storageQueue = {},
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

local function setSmelterLightBrightness(coord: Vector3int16, category: string, brightness: number)
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if placedFolder then
		local partName = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)
		local part = placedFolder:FindFirstChild(partName)
		if part then
			local light = part:FindFirstChild("FurnaceLight")
			if light and light:IsA("PointLight") then
				light.Brightness = brightness
			end
		end
	end
end

function MachineService.StepMachines(dt: number)
	for _, machine in pairs(machines) do
		local fwdOffset = MachineService.GetForwardOffset(machine.orientation)
		local frontCoord = Vector3int16.new(
			machine.coord.X + fwdOffset.X,
			machine.coord.Y + fwdOffset.Y,
			machine.coord.Z + fwdOffset.Z
		)
		local behindOffset = MachineService.GetBehindOffset(machine.orientation)
		local behindCoord = Vector3int16.new(
			machine.coord.X + behindOffset.X,
			machine.coord.Y + behindOffset.Y,
			machine.coord.Z + behindOffset.Z
		)
		local leftOffset = MachineService.GetLeftOffset(machine.orientation)
		local leftCoord = Vector3int16.new(
			machine.coord.X + leftOffset.X,
			machine.coord.Y + leftOffset.Y,
			machine.coord.Z + leftOffset.Z
		)
		local rightOffset = MachineService.GetRightOffset(machine.orientation)
		local rightCoord = Vector3int16.new(
			machine.coord.X + rightOffset.X,
			machine.coord.Y + rightOffset.Y,
			machine.coord.Z + rightOffset.Z
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
						machine.timer = 0
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
				setSmelterLightBrightness(machine.coord, machine.category, 3)
				machine.timer += dt
				if machine.timer >= machine.recipe.craftDuration then
					local outputItem: string? = nil
					for itemId, count in pairs(machine.recipe.outputs) do
						outputItem = itemId
						break
					end
					machine.outputBuffer = outputItem
					machine.recipe = nil
					machine.timer = 0
					setSmelterLightBrightness(machine.coord, machine.category, 0)
				end
			-- If idle and outputBuffer is clear, attempt to pull input from Behind conveyor's Slot 4
			elseif machine.outputBuffer == nil then
				setSmelterLightBrightness(machine.coord, machine.category, 0)
				local behindConveyor = ConveyorService.GetConveyor(behindCoord)
				if behindConveyor then
					local slot4 = behindConveyor.slots[4]
					if slot4.itemId ~= nil then
						local matchingRecipe = findMatchingRecipe(slot4.itemId)
						if matchingRecipe and matchingRecipe.machineType == "Smelter" then
							slot4.itemId = nil
							slot4.progress = 0.0
							machine.recipe = matchingRecipe
							machine.timer = 0
							setSmelterLightBrightness(machine.coord, machine.category, 3)
						end
					end
				end
			end

		elseif machine.category == "Splitter" then
			-- 1 Input at Behind -> 3 Outputs at Front, Left, Right (round-robin)
			if machine.outputBuffer == nil then
				local behindConveyor = ConveyorService.GetConveyor(behindCoord)
				if behindConveyor then
					local slot4 = behindConveyor.slots[4]
					if slot4.itemId ~= nil then
						machine.outputBuffer = slot4.itemId
						slot4.itemId = nil
						slot4.progress = 0.0
					end
				end
			end

			if machine.outputBuffer ~= nil then
				local directions = {
					{ coord = frontCoord, name = "Front" },
					{ coord = leftCoord, name = "Left" },
					{ coord = rightCoord, name = "Right" },
				}

				-- Attempt round-robin ejection starting from splitterIndex
				for attempt = 0, 2 do
					local dirIdx = ((machine.splitterIndex - 1 + attempt) % 3) + 1
					local targetData = directions[dirIdx]
					local targetConveyor = ConveyorService.GetConveyor(targetData.coord)
					if targetConveyor then
						local slot1 = targetConveyor.slots[1]
						if slot1.itemId == nil then
							slot1.itemId = machine.outputBuffer :: Types.ItemId
							slot1.progress = 1.0
							machine.outputBuffer = nil
							machine.splitterIndex = (dirIdx % 3) + 1
							break
						end
					end
				end
			end

		elseif machine.category == "Merger" then
			-- 3 Inputs at Left, Behind, Right -> 1 Output at Front (round-robin)
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

			if machine.outputBuffer == nil then
				local inputs = {
					{ coord = leftCoord, name = "Left" },
					{ coord = behindCoord, name = "Behind" },
					{ coord = rightCoord, name = "Right" },
				}

				for attempt = 0, 2 do
					local inIdx = ((machine.mergerIndex - 1 + attempt) % 3) + 1
					local targetData = inputs[inIdx]
					local inConveyor = ConveyorService.GetConveyor(targetData.coord)
					if inConveyor then
						local slot4 = inConveyor.slots[4]
						if slot4.itemId ~= nil then
							machine.outputBuffer = slot4.itemId
							slot4.itemId = nil
							slot4.progress = 0.0
							machine.mergerIndex = (inIdx % 3) + 1

							-- Eject immediately to Front if possible
							local frontConveyor = ConveyorService.GetConveyor(frontCoord)
							if frontConveyor then
								local slot1 = frontConveyor.slots[1]
								if slot1.itemId == nil then
									slot1.itemId = machine.outputBuffer :: Types.ItemId
									slot1.progress = 1.0
									machine.outputBuffer = nil
								end
							end
							break
						end
					end
				end
			end

		elseif machine.category == "Storage" then
			-- Storage Silo: FIFO Queue Capacity 50. Input Behind (+Z), Output Front (-Z).
			-- Pull from Behind
			if #machine.storageQueue < 50 then
				local behindConveyor = ConveyorService.GetConveyor(behindCoord)
				if behindConveyor then
					local slot4 = behindConveyor.slots[4]
					if slot4.itemId ~= nil then
						table.insert(machine.storageQueue, slot4.itemId)
						slot4.itemId = nil
						slot4.progress = 0.0
					end
				end
			end

			-- Eject to Front
			if #machine.storageQueue > 0 then
				local frontConveyor = ConveyorService.GetConveyor(frontCoord)
				if frontConveyor then
					local slot1 = frontConveyor.slots[1]
					if slot1.itemId == nil then
						local nextItem = table.remove(machine.storageQueue, 1)
						if nextItem then
							slot1.itemId = nextItem :: Types.ItemId
							slot1.progress = 1.0
						end
					end
				end
			end

		elseif machine.category == "Sink" then
			-- Item Sink: Pull items from Behind conveyor's Slot 4 and consume them for credits
			local behindConveyor = ConveyorService.GetConveyor(behindCoord)
			if behindConveyor then
				local slot4 = behindConveyor.slots[4]
				if slot4.itemId ~= nil then
					local consumedItem = slot4.itemId
					slot4.itemId = nil
					slot4.progress = 0.0
					print(string.format("[Sink] Consumed %s for +10 Credits at (%d, %d, %d)", consumedItem, machine.coord.X, machine.coord.Y, machine.coord.Z))

					-- Award credits to all active players
					for _, player in ipairs(Players:GetPlayers()) do
						EconomyService.AddCredits(player, 10)
					end
				end
			end
		end
	end
end

return MachineService
