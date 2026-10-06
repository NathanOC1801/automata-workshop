--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)

local GridService = require(script.Parent.GridService)
local ConveyorService = require(script.Parent.ConveyorService)

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
	GridService.SetCell(coord, {
		machineId = machineId,
		category = category,
		orientation = orientation,
	})

	-- Handle machine specific creation
	if category == "Conveyor" then
		ConveyorService.CreateConveyor(coord, orientation)
	end

	-- Spawn physical/visual Part in Workspace.PlacedObjects
	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = machineId
	part.Size = Vector3.new(4, 1, 4)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(80, 80, 85)

	-- Flush position with surface (+0.5Y offset) and apply orientation
	local posWithOffset = worldPos + Vector3.new(0, 0.5, 0)
	part.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

	-- Add directional arrow GUI on top surface
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
