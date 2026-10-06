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

function PlacementService.OnPlaceObjectRequest(
	player: Player,
	coord: Vector3int16,
	category: Types.MachineCategory,
	orientation: number
)
	-- Validate target cell is empty
	if not GridService.IsCellEmpty(coord) then
		warn(string.format("[PlacementService] Cell (%d, %d, %d) is already occupied!", coord.X, coord.Y, coord.Z))
		return
	end

	-- Register cell in GridService
	local machineId = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)

	-- Handle machine logic registration
	if category == "Conveyor" then
		ConveyorService.CreateConveyor(coord, orientation)
	elseif category == "Drill" or category == "Smelter" then
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
	else
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(120, 120, 120)
		heightOffset = 2.0
	end

	local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)
	part.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

	-- Top directional arrow GUI
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.Parent = part

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.fromScale(1, 1)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "▲"
	arrowLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	arrowLabel.TextScaled = true
	arrowLabel.Font = Enum.Font.SourceSansBold
	arrowLabel.Parent = surfaceGui

	part.Parent = placedObjectsFolder
	print(string.format("[PlacementService] Successfully placed %s at (%d, %d, %d)", category, coord.X, coord.Y, coord.Z))
end

function PlacementService.Init()
	Network.Remotes.PlaceObject.OnServerEvent:Connect(function(player, coord, category, orientation)
		if typeof(coord) == "Vector3int16" and typeof(category) == "string" and typeof(orientation) == "number" then
			PlacementService.OnPlaceObjectRequest(player, coord, category :: Types.MachineCategory, orientation)
		end
	end)
end

return PlacementService
