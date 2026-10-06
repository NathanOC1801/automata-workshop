--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)

local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)
local MachineService = require(script.Parent.MachineService)
local EconomyService = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)

local PlacementService = {}

local PLACEMENT_COSTS: { [Types.MachineCategory]: number } = {
	Conveyor = 5,
	Drill = 50,
	Smelter = 80,
	Splitter = 30,
	Merger = 30,
	Storage = 40,
	Sink = 20,
	Assembler = 100,
}

local TIER_REQUIREMENTS: { [Types.MachineCategory]: number } = {
	Conveyor = 1,
	Drill = 1,
	Smelter = 1,
	Splitter = 1,
	Merger = 1,
	Storage = 1,
	Sink = 1,
	Assembler = 2,
}

local function getOrCreatePlacedObjectsFolder(): Folder
	local folder = Workspace:FindFirstChild("PlacedObjects")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "PlacedObjects"
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

local placedObjectsFolder = getOrCreatePlacedObjectsFolder()

-- Flush 3D neon port markers using Enum.Material.Neon
local function createNeonPort(parentPart: BasePart, isOutput: boolean, size: Vector3?): Part
	local port = Instance.new("Part")
	port.Name = isOutput and "OutputPort" or "InputPort"
	port.Size = size or Vector3.new(1.5, 1.5, 0.2)
	port.Color = isOutput and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 140, 0)
	port.Material = Enum.Material.Neon
	port.Anchored = true
	port.CanCollide = false
	port.CanTouch = false
	port.CanQuery = false
	port.CastShadow = false
	port.Parent = parentPart
	return port
end

-- 0° -> -Z, 90° -> -X, 180° -> +Z, 270° -> +X
local function getForwardVector(orientation: number): Vector3
	local rad = math.rad(orientation)
	return Vector3.new(-math.sin(rad), 0, -math.cos(rad))
end

function PlacementService.OnPlaceObjectRequest(
	player: Player,
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number,
	bypassCost: boolean?
)
	-- Validate target cell is empty
	if not GridService.IsCellEmpty(coord) then
		warn(string.format("[PlacementService] Cell (%d, %d, %d) is already occupied!", coord.X, coord.Y, coord.Z))
		return
	end

	-- Check tier permission & placement cost unless bypassed (e.g. during SaveService load)
	if not bypassCost then
		local requiredTier = TIER_REQUIREMENTS[category] or 1
		local playerTier = ProgressionService.GetUnlockedTier(player)
		if playerTier < requiredTier then
			warn(string.format("[PlacementService] Player %s has not unlocked Tier %d for %s", player.Name, requiredTier, category))
			return
		end

		local cost = PLACEMENT_COSTS[category] or 10
		if not EconomyService.DeductCredits(player, cost) then
			warn(string.format("[PlacementService] Player %s does not have enough credits for %s ($%d)", player.Name, category, cost))
			return
		end
	end

	-- Register cell in GridService
	local machineId = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)

	-- Handle machine logic registration
	if category == "Conveyor" then
		ConveyorService.CreateConveyor(coord, orientation)
	elseif category == "Drill" or category == "Smelter" or category == "Sink" or category == "Splitter" or category == "Merger" or category == "Storage" or category == "Assembler" then
		MachineService.CreateMachine(coord, category, orientation)
	else
		GridService.SetCell(coord, {
			machineId = machineId,
			category = category,
			orientation = orientation,
		})
	end

	-- Spawn physical visual model in Workspace.PlacedObjects
	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = machineId
	part:SetAttribute("OwnerUserId", player.UserId)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic

	local heightOffset = 0.5
	local createdPorts: { { port: Part, offset: Vector3, yawRad: number? } } = {}

	if category == "Conveyor" then
		part.Size = Vector3.new(4, 1, 4)
		part.Color = Color3.fromRGB(80, 80, 85)
		heightOffset = 0.5

		-- AssemblyLinearVelocity matching forward direction at 8 studs/sec for conveyor riding physics
		local fwdVector = getForwardVector(orientation)
		part.AssemblyLinearVelocity = fwdVector * 8

		table.insert(createdPorts, {
			port = createNeonPort(part, true, Vector3.new(2.8, 0.05, 0.3)),
			offset = Vector3.new(0, 0.51, -1.8),
		})
		table.insert(createdPorts, {
			port = createNeonPort(part, false, Vector3.new(2.8, 0.05, 0.3)),
			offset = Vector3.new(0, 0.51, 1.8),
		})

	elseif category == "Drill" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(180, 90, 40)
		part.Material = Enum.Material.DiamondPlate
		heightOffset = 2.0

		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(0, 0, -2.01) })

		local dust = Instance.new("ParticleEmitter")
		dust.Name = "DustParticles"
		dust.Color = ColorSequence.new(Color3.fromRGB(160, 140, 120))
		dust.Size = NumberSequence.new(0.5, 1.5)
		dust.Transparency = NumberSequence.new(0.5, 1.0)
		dust.Lifetime = NumberRange.new(1.0, 2.0)
		dust.Rate = 10
		dust.Speed = NumberRange.new(1, 3)
		dust.Parent = part

	elseif category == "Smelter" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(130, 50, 40)
		part.Material = Enum.Material.Brick
		heightOffset = 2.0

		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(0, 0, 2.01) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(0, 0, -2.01) })

		local light = Instance.new("PointLight")
		light.Name = "FurnaceLight"
		light.Color = Color3.fromRGB(255, 120, 30)
		light.Range = 12
		light.Brightness = 0
		light.Parent = part

		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "SmokeParticles"
		smoke.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
		smoke.Size = NumberSequence.new(0.8, 2.5)
		smoke.Transparency = NumberSequence.new(0.3, 1.0)
		smoke.Lifetime = NumberRange.new(2.0, 3.5)
		smoke.Rate = 12
		smoke.Speed = NumberRange.new(2, 5)
		smoke.Enabled = false
		smoke.Parent = part

	elseif category == "Assembler" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(45, 85, 125)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 2.0

		table.insert(createdPorts, {
			port = createNeonPort(part, true, Vector3.new(1.6, 0.2, 0.4)),
			offset = Vector3.new(0, 0, -2.01),
		})
		table.insert(createdPorts, {
			port = createNeonPort(part, false, Vector3.new(1.2, 0.2, 0.4)),
			offset = Vector3.new(-1.0, 0, 2.01),
		})
		table.insert(createdPorts, {
			port = createNeonPort(part, false, Vector3.new(1.2, 0.2, 0.4)),
			offset = Vector3.new(1.0, 0, 2.01),
		})

	elseif category == "Splitter" then
		part.Size = Vector3.new(4, 2, 4)
		part.Color = Color3.fromRGB(60, 140, 200)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 1.0

		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(0, 0, 2.01) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(0, 0, -2.01) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(-2.01, 0, 0), yawRad = math.rad(90) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(2.01, 0, 0), yawRad = math.rad(90) })

	elseif category == "Merger" then
		part.Size = Vector3.new(4, 2, 4)
		part.Color = Color3.fromRGB(180, 140, 50)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 1.0

		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(-2.01, 0, 0), yawRad = math.rad(90) })
		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(0, 0, 2.01) })
		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(2.01, 0, 0), yawRad = math.rad(90) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(0, 0, -2.01) })

	elseif category == "Storage" then
		part.Size = Vector3.new(4, 6, 4)
		part.Color = Color3.fromRGB(70, 75, 80)
		part.Material = Enum.Material.Metal
		heightOffset = 3.0

		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(0, -1.5, 2.01) })
		table.insert(createdPorts, { port = createNeonPort(part, true), offset = Vector3.new(0, -1.5, -2.01) })

	elseif category == "Sink" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(50, 50, 60)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 2.0

		table.insert(createdPorts, { port = createNeonPort(part, false), offset = Vector3.new(0, 0, 2.01) })
	else
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(120, 120, 120)
		heightOffset = 2.0
	end

	local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)
	part.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

	for _, data in ipairs(createdPorts) do
		local portCFrame = part.CFrame * CFrame.new(data.offset)
		if data.yawRad then
			portCFrame = portCFrame * CFrame.Angles(0, data.yawRad, 0)
		end
		data.port.CFrame = portCFrame
	end

	part.Parent = placedObjectsFolder
	print(string.format("[PlacementService] Successfully placed %s at (%d, %d, %d)", category, coord.X, coord.Y, coord.Z))
end

function PlacementService.OnRemoveObjectRequest(player: Player, coord: Vector3int16)
	local cell = GridService.GetCell(coord)
	if not cell then
		warn(string.format("[PlacementService] Cannot remove: Cell (%d, %d, %d) is empty!", coord.X, coord.Y, coord.Z))
		return
	end

	local category = cell.category

	-- Unregister logic state
	if category == "Conveyor" then
		ConveyorService.RemoveConveyor(coord)
	elseif category == "Drill" or category == "Smelter" or category == "Sink" or category == "Splitter" or category == "Merger" or category == "Storage" or category == "Assembler" then
		MachineService.RemoveMachine(coord)
	else
		GridService.ClearCell(coord)
	end

	-- Refund 100% placement cost
	local refund = PLACEMENT_COSTS[category] or 10
	EconomyService.AddCredits(player, refund)

	-- Find and destroy physical model in Workspace.PlacedObjects
	local targetName = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)
	local targetPart = placedObjectsFolder:FindFirstChild(targetName)
	if targetPart then
		targetPart:Destroy()
	end

	print(string.format("[PlacementService] Successfully removed %s at (%d, %d, %d) [Refunded $%d]", category, coord.X, coord.Y, coord.Z, refund))
end

function PlacementService.Init()
	Network.Remotes.PlaceObject.OnServerEvent:Connect(function(player, coord, category, orientation)
		if typeof(coord) == "Vector3int16" and typeof(category) == "string" and typeof(orientation) == "number" then
			PlacementService.OnPlaceObjectRequest(player, coord, category :: Types.MachineCategory, orientation)
		end
	end)

	Network.Remotes.RemoveObject.OnServerEvent:Connect(function(player, coord)
		if typeof(coord) == "Vector3int16" then
			PlacementService.OnRemoveObjectRequest(player, coord)
		end
	end)
end

return PlacementService
