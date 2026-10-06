--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)
local EconomyService = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local Network = require(ReplicatedStorage.Shared.Network)

export type MachineInstance = {
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number,
	timer: number,
	recipe: Types.Recipe?,
	selectedRecipeId: string?,
	selectedResource: string?, -- "RawIron" or "RawCopper" for Drills
	outputBuffer: string?,
	inputBuffer: { [string]: number },
	splitterIndex: number, -- 1 = Front, 2 = Left, 3 = Right
	mergerIndex: number, -- 1 = Left, 2 = Behind, 3 = Right
	storageQueue: { string },
}

local MachineService = {}

local machines: { [string]: MachineInstance } = {}

local function coordToKey(coord: Vector3int16): string
	return string.format("%d,%d,%d", coord.X, coord.Y, coord.Z)
end

-- 0° -> -Z, 90° -> -X, 180° -> +Z, 270° -> +X
function MachineService.GetForwardOffset(orientation: number): Vector3int16
	if orientation == 0 then
		return Vector3int16.new(0, 0, -1)
	elseif orientation == 90 then
		return Vector3int16.new(-1, 0, 0)
	elseif orientation == 180 then
		return Vector3int16.new(0, 0, 1)
	elseif orientation == 270 then
		return Vector3int16.new(1, 0, 0)
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
		return Vector3int16.new(0, 0, 1)
	elseif orientation == 180 then
		return Vector3int16.new(1, 0, 0)
	elseif orientation == 270 then
		return Vector3int16.new(0, 0, -1)
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
		selectedRecipeId = nil,
		selectedResource = nil,
		outputBuffer = nil,
		inputBuffer = {},
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

local function findMatchingRecipe(inputId: string, category: string): Types.Recipe?
	for _, recipe in pairs(Recipes) do
		if recipe.machineType == category and recipe.inputs[inputId :: Types.ItemId] ~= nil then
			return recipe
		end
	end
	return nil
end

local function setSmelterVisualState(coord: Vector3int16, category: string, isCrafting: boolean)
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if placedFolder then
		local partName = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)
		local part = placedFolder:FindFirstChild(partName)
		if part then
			local light = part:FindFirstChild("FurnaceLight")
			if light and light:IsA("PointLight") then
				light.Brightness = isCrafting and 3 or 0
			end
			local emitter = part:FindFirstChild("SmokeParticles")
			if emitter and emitter:IsA("ParticleEmitter") then
				emitter.Enabled = isCrafting
			end
		end
	end
end

local function checkRecipeSatisfied(machine: MachineInstance, recipe: Types.Recipe): boolean
	for itemId, count in pairs(recipe.inputs) do
		local currentCount = machine.inputBuffer[itemId] or 0
		if currentCount < count then
			return false
		end
	end
	return true
end

local function consumeRecipeIngredients(machine: MachineInstance, recipe: Types.Recipe)
	for itemId, count in pairs(recipe.inputs) do
		local currentCount = machine.inputBuffer[itemId] or 0
		machine.inputBuffer[itemId] = math.max(0, currentCount - count)
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
			local deposit = GridService.GetDepositAt(machine.coord)
			if deposit == "Iron" then
				machine.selectedResource = "RawIron"
			elseif deposit == "Copper" then
				machine.selectedResource = "RawCopper"
			else
				machine.selectedResource = nil
			end

			if machine.selectedResource ~= nil then
				machine.timer += dt
				if machine.timer >= 2.0 then
					local frontConveyor = ConveyorService.GetConveyor(frontCoord)
					if frontConveyor then
						local slot1 = frontConveyor.slots[1]
						if slot1.itemId == nil then
							slot1.itemId = machine.selectedResource :: Types.ItemId
							slot1.progress = 1.0
							machine.timer = 0
						end
					end
				end
			else
				machine.timer = 0
			end

		elseif machine.category == "Smelter" then
			-- Eject output
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

			-- Crafting state
			if machine.recipe ~= nil then
				setSmelterVisualState(machine.coord, machine.category, true)
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
					setSmelterVisualState(machine.coord, machine.category, false)
				end
			elseif machine.outputBuffer == nil then
				setSmelterVisualState(machine.coord, machine.category, false)
				local behindConveyor = ConveyorService.GetConveyor(behindCoord)
				if behindConveyor then
					local slot4 = behindConveyor.slots[4]
					if slot4.itemId ~= nil then
						local matchingRecipe = findMatchingRecipe(slot4.itemId, "Smelter")
						if matchingRecipe then
							slot4.itemId = nil
							slot4.progress = 0.0
							machine.recipe = matchingRecipe
							machine.timer = 0
							setSmelterVisualState(machine.coord, machine.category, true)
						end
					end
				end
			end

		elseif machine.category == "Assembler" then
			-- Eject output
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

			-- Pull ingredients from behind conveyor AND adjacent feeder conveyors at rear
			local sourceCoords = { behindCoord, leftCoord, rightCoord }
			for _, srcCoord in ipairs(sourceCoords) do
				local inConveyor = ConveyorService.GetConveyor(srcCoord)
				if inConveyor then
					local slot4 = inConveyor.slots[4]
					if slot4.itemId ~= nil then
						local item = slot4.itemId
						local current = machine.inputBuffer[item] or 0
						machine.inputBuffer[item] = current + 1
						slot4.itemId = nil
						slot4.progress = 0.0
					end
				end
			end

			-- Check active crafting or select recipe
			if machine.recipe ~= nil then
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
				end
			elseif machine.outputBuffer == nil then
				local targetRecipe: Types.Recipe? = nil
				if machine.selectedRecipeId and Recipes[machine.selectedRecipeId] then
					targetRecipe = Recipes[machine.selectedRecipeId]
				end

				if targetRecipe and targetRecipe.machineType == "Assembler" then
					if checkRecipeSatisfied(machine, targetRecipe) then
						consumeRecipeIngredients(machine, targetRecipe)
						machine.recipe = targetRecipe
						machine.timer = 0
					end
				else
					for _, recipe in pairs(Recipes) do
						if recipe.machineType == "Assembler" then
							if checkRecipeSatisfied(machine, recipe) then
								consumeRecipeIngredients(machine, recipe)
								machine.recipe = recipe
								machine.timer = 0
								break
							end
						end
					end
				end
			end

		elseif machine.category == "Splitter" then
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
			local behindConveyor = ConveyorService.GetConveyor(behindCoord)
			if behindConveyor then
				local slot4 = behindConveyor.slots[4]
				if slot4.itemId ~= nil then
					local consumedItem = slot4.itemId
					slot4.itemId = nil
					slot4.progress = 0.0
					print(string.format("[Sink] Consumed %s for +10 Credits at (%d, %d, %d)", consumedItem, machine.coord.X, machine.coord.Y, machine.coord.Z))

					for _, player in ipairs(Players:GetPlayers()) do
						EconomyService.AddCredits(player, 10)
						ProgressionService.ProcessSinkConsumption(player, consumedItem)
					end
				end
			end
		end
	end
end

function MachineService.Init()
	Network.Remotes.GetMachineState.OnServerInvoke = function(player, coord)
		if typeof(coord) == "Vector3int16" then
			local machine = MachineService.GetMachine(coord)
			if machine then
				local status = "Idle"
				local progress = 0.0
				if machine.category == "Drill" then
					local deposit = GridService.GetDepositAt(coord)
					if deposit then
						status = string.format("Mining: %s Deposit", deposit)
					else
						status = "No Deposit Detected"
					end
					progress = math.clamp(machine.timer / 2.0, 0, 1)
				elseif machine.recipe ~= nil then
					status = "Crafting..."
					progress = math.clamp(machine.timer / machine.recipe.craftDuration, 0, 1)
				elseif machine.outputBuffer ~= nil then
					status = "Output Full"
					progress = 1.0
				end

				return {
					category = machine.category,
					status = status,
					progress = progress,
					recipe = (machine.recipe and machine.recipe.displayName) or (machine.selectedRecipeId and Recipes[machine.selectedRecipeId] and Recipes[machine.selectedRecipeId].displayName) or "None",
					selectedRecipeId = machine.selectedRecipeId,
					selectedResource = machine.selectedResource,
					inputBuffer = machine.inputBuffer,
					storageCount = #machine.storageQueue,
				}
			end
		end
		return nil
	end

	Network.Remotes.SelectRecipe.OnServerEvent:Connect(function(player, coord, recipeId)
		if typeof(coord) == "Vector3int16" and typeof(recipeId) == "string" then
			local machine = MachineService.GetMachine(coord)
			if machine and machine.category == "Assembler" then
				if Recipes[recipeId] then
					machine.selectedRecipeId = recipeId
					machine.recipe = nil
					machine.inputBuffer = {}
					machine.timer = 0
				end
			end
		end
	end)

	Network.Remotes.ClearBuffer.OnServerEvent:Connect(function(player, coord)
		if typeof(coord) == "Vector3int16" then
			local machine = MachineService.GetMachine(coord)
			if machine then
				machine.inputBuffer = {}
				machine.outputBuffer = nil
				machine.storageQueue = {}
				machine.recipe = nil
				machine.timer = 0
				print(string.format("[MachineService] Cleared buffer for machine at (%d, %d, %d)", coord.X, coord.Y, coord.Z))
			end
		end
	end)
end

return MachineService
