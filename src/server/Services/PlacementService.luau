--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)

local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)
local MachineService = require(script.Parent.MachineService)

local PlacementService = {}

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

local function createPortMarker(parentPart: Part, name: string, localPos: Vector3, size: Vector3, color: Color3)
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Size = size
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.CFrame = parentPart.CFrame * CFrame.new(localPos)
	marker.Parent = parentPart
end

function PlacementService.OnPlaceObjectRequest(
	player: Player,
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number
)
	if not GridService.IsCellEmpty(coord) then
		warn(string.format("[PlacementService] Cell (%d, %d, %d) is already occupied!", coord.X, coord.Y, coord.Z))
		return
	end

	local machineId = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)

	if category == "Conveyor" then
		ConveyorService.CreateConveyor(coord, orientation)
	else
		MachineService.CreateMachine(coord, category, orientation)
	end

	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = machineId
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic

	local heightOffset = 0.5
	if category == "Conveyor" then
		part.Size = Vector3.new(4, 1, 4)
		part.Color = Color3.fromRGB(80, 80, 85)
		heightOffset = 0.5
	elseif category == "Drill" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(180, 90, 40)
		part.Material = Enum.Material.DiamondPlate
		heightOffset = 2.0
	elseif category == "Smelter" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(130, 50, 40)
		part.Material = Enum.Material.Brick
		heightOffset = 2.0

		local light = Instance.new("PointLight")
		light.Name = "FurnaceLight"
		light.Color = Color3.fromRGB(255, 120, 30)
		light.Range = 12
		light.Brightness = 0
		light.Parent = part
	elseif category == "Splitter" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(60, 110, 150)
		heightOffset = 2.0
	elseif category == "Merger" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(130, 90, 160)
		heightOffset = 2.0
	elseif category == "Storage" then
		part.Size = Vector3.new(4, 6, 4)
		part.Color = Color3.fromRGB(70, 75, 80)
		part.Material = Enum.Material.CorrodedMetal
		heightOffset = 3.0
	elseif category == "Sink" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(50, 50, 60)
		heightOffset = 2.0
	else
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(120, 120, 120)
		heightOffset = 2.0
	end

	local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)
	part.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

	local green = Color3.fromRGB(0, 255, 100)
	local orange = Color3.fromRGB(255, 140, 0)

	if category == "Conveyor" then
		createPortMarker(part, "OutputPort", Vector3.new(0, 0.51, -1.8), Vector3.new(1.6, 0.2, 0.4), green)
		createPortMarker(part, "InputPort", Vector3.new(0, 0.51, 1.8), Vector3.new(1.6, 0.2, 0.4), orange)
	elseif category == "Drill" then
		createPortMarker(part, "OutputPort", Vector3.new(0, 0, -2.05), Vector3.new(1.6, 0.2, 0.4), green)
	elseif category == "Smelter" then
		createPortMarker(part, "OutputPort", Vector3.new(0, 0, -2.05), Vector3.new(1.6, 0.2, 0.4), green)
		createPortMarker(part, "InputPort", Vector3.new(0, 0, 2.05), Vector3.new(1.6, 0.2, 0.4), orange)
	elseif category == "Splitter" then
		createPortMarker(part, "InputPort", Vector3.new(0, 0, 2.05), Vector3.new(1.6, 0.2, 0.4), orange)
		createPortMarker(part, "OutputPortFront", Vector3.new(0, 0, -2.05), Vector3.new(1.6, 0.2, 0.4), green)
		createPortMarker(part, "OutputPortLeft", Vector3.new(-2.05, 0, 0), Vector3.new(0.4, 0.2, 1.6), green)
		createPortMarker(part, "OutputPortRight", Vector3.new(2.05, 0, 0), Vector3.new(0.4, 0.2, 1.6), green)
	elseif category == "Merger" then
		createPortMarker(part, "OutputPortFront", Vector3.new(0, 0, -2.05), Vector3.new(1.6, 0.2, 0.4), green)
		createPortMarker(part, "InputPortBack", Vector3.new(0, 0, 2.05), Vector3.new(1.6, 0.2, 0.4), orange)
		createPortMarker(part, "InputPortLeft", Vector3.new(-2.05, 0, 0), Vector3.new(0.4, 0.2, 1.6), orange)
		createPortMarker(part, "InputPortRight", Vector3.new(2.05, 0, 0), Vector3.new(0.4, 0.2, 1.6), orange)
	elseif category == "Storage" then
		createPortMarker(part, "OutputPort", Vector3.new(0, -1, -2.05), Vector3.new(1.6, 0.2, 0.4), green)
		createPortMarker(part, "InputPort", Vector3.new(0, -1, 2.05), Vector3.new(1.6, 0.2, 0.4), orange)
	elseif category == "Sink" then
		createPortMarker(part, "InputPort", Vector3.new(0, 0, 2.05), Vector3.new(1.6, 0.2, 0.4), orange)
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

	if category == "Conveyor" then
		ConveyorService.RemoveConveyor(coord)
	else
		MachineService.RemoveMachine(coord)
	end

	local targetName = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)
	local targetPart = placedObjectsFolder:FindFirstChild(targetName)
	if targetPart then
		targetPart:Destroy()
	end

	print(string.format("[PlacementService] Successfully removed %s at (%d, %d, %d)", category, coord.X, coord.Y, coord.Z))
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