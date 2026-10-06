--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)

local PlacementController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local isPlacementActive = false
local selectedCategory: Types.MachineCategory = "Conveyor"
local orientation = 0 -- 0, 90, 180, 270

local ghostPart: Part? = nil
local currentGridCoord: Vector3int16? = nil
local isCellVacant = true

local function getGhostSizeAndOffset(category: Types.MachineCategory): (Vector3, number)
	if category == "Conveyor" then
		return Vector3.new(4, 1, 4), 0.5
	else
		return Vector3.new(4, 4, 4), 2.0
	end
end

local function createGhostPort(parentPart: Part, name: string, localPos: Vector3, color: Color3): Part
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Size = Vector3.new(1.6, 0.2, 0.4)
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.3
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Parent = parentPart
	return marker
end

local function updateGhostAppearance()
	if not ghostPart then
		return
	end

	local size, _ = getGhostSizeAndOffset(selectedCategory)
	ghostPart.Size = size

	for _, child in ipairs(ghostPart:GetChildren()) do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end

	if selectedCategory == "Conveyor" then
		createGhostPort(ghostPart, "OutputPort", Vector3.new(0, 0.51, -1.8), Color3.fromRGB(0, 255, 100))
		createGhostPort(ghostPart, "InputPort", Vector3.new(0, 0.51, 1.8), Color3.fromRGB(255, 140, 0))
	elseif selectedCategory == "Drill" then
		createGhostPort(ghostPart, "OutputPort", Vector3.new(0, 0, -2.05), Color3.fromRGB(0, 255, 100))
	elseif selectedCategory == "Smelter" then
		createGhostPort(ghostPart, "OutputPort", Vector3.new(0, 0, -2.05), Color3.fromRGB(0, 255, 100))
		createGhostPort(ghostPart, "InputPort", Vector3.new(0, 0, 2.05), Color3.fromRGB(255, 140, 0))
	elseif selectedCategory == "Sink" then
		-- Sink only receives items: Input Port on the receiving side (+Z)
		createGhostPort(ghostPart, "InputPort", Vector3.new(0, 0, 2.05), Color3.fromRGB(255, 140, 0))
	end
end

local function createGhostPart(): Part
	local size, _ = getGhostSizeAndOffset(selectedCategory)
	local part = Instance.new("Part")
	part.Name = "PlacementGhost"
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.5
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(0, 255, 0)
	part.Parent = Workspace

	ghostPart = part
	updateGhostAppearance()

	return part
end

local function destroyGhostPart()
	if ghostPart then
		ghostPart:Destroy()
		ghostPart = nil
	end
end

local function checkCellVacant(coord: Vector3int16): boolean
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if not placedFolder then
		return true
	end
	local worldPos = GridMath.gridToWorld(coord)
	for _, obj in ipairs(placedFolder:GetChildren()) do
		if obj:IsA("BasePart") then
			if math.abs(obj.Position.X - worldPos.X) < 1 and math.abs(obj.Position.Z - worldPos.Z) < 1 then
				return false
			end
		end
	end
	return true
end

function PlacementController.TogglePlacementMode()
	isPlacementActive = not isPlacementActive
	if isPlacementActive then
		createGhostPart()
		print("[PlacementController] Placement mode enabled. Keys 1=Conveyor, 2=Drill, 3=Smelter, 4=Sink. Right-Click/X=Demolish. 'R'=Rotate, 'E'=Toggle.")
	else
		destroyGhostPart()
		print("[PlacementController] Placement mode disabled.")
	end
end

function PlacementController.RotateOrientation()
	if not isPlacementActive then
		return
	end
	orientation = (orientation + 90) % 360
end

function PlacementController.SelectCategory(category: Types.MachineCategory)
	selectedCategory = category
	if isPlacementActive then
		updateGhostAppearance()
	end
	print(string.format("[PlacementController] Selected category: %s", category))
end

function PlacementController.OnInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		PlacementController.TogglePlacementMode()
	elseif input.KeyCode == Enum.KeyCode.R then
		PlacementController.RotateOrientation()
	elseif input.KeyCode == Enum.KeyCode.One then
		PlacementController.SelectCategory("Conveyor")
	elseif input.KeyCode == Enum.KeyCode.Two then
		PlacementController.SelectCategory("Drill")
	elseif input.KeyCode == Enum.KeyCode.Three then
		PlacementController.SelectCategory("Smelter")
	elseif input.KeyCode == Enum.KeyCode.Four then
		PlacementController.SelectCategory("Sink")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isPlacementActive and currentGridCoord and isCellVacant then
			Network.Remotes.PlaceObject:FireServer(currentGridCoord, selectedCategory, orientation)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.X then
		if isPlacementActive and currentGridCoord and not isCellVacant then
			Network.Remotes.RemoveObject:FireServer(currentGridCoord)
		end
	end
end

function PlacementController.OnRenderStepped()
	if not isPlacementActive or not ghostPart then
		return
	end

	local ray = mouse.UnitRay
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList = { ghostPart }
	local playerChar = Players.LocalPlayer and Players.LocalPlayer.Character
	if playerChar then
		table.insert(ignoreList, playerChar)
	end
	raycastParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result and result.Position.Y >= 0 then
		local hitPos = result.Position
		local gridCoord = GridMath.worldToGrid(hitPos)
		currentGridCoord = gridCoord

		local worldPos = GridMath.gridToWorld(gridCoord)
		local _, heightOffset = getGhostSizeAndOffset(selectedCategory)
		local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)

		ghostPart.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

		-- Update port positions relative to ghostPart
		for _, marker in ipairs(ghostPart:GetChildren()) do
			if marker:IsA("BasePart") then
				local isConveyor = (selectedCategory == "Conveyor")
				local y = isConveyor and 0.51 or 0
				local z = 0

				if marker.Name == "OutputPort" then
					z = isConveyor and -1.8 or -2.05
				elseif marker.Name == "InputPort" then
					z = isConveyor and 1.8 or 2.05
				end

				marker.CFrame = ghostPart.CFrame * CFrame.new(0, y, z)
				marker.Transparency = 0.2
			end
		end

		isCellVacant = checkCellVacant(gridCoord)
		if isCellVacant then
			ghostPart.Color = Color3.fromRGB(0, 255, 0)
		else
			ghostPart.Color = Color3.fromRGB(255, 0, 0)
		end
		ghostPart.Transparency = 0.5
	else
		currentGridCoord = nil
		ghostPart.Transparency = 1.0

		for _, marker in ipairs(ghostPart:GetChildren()) do
			if marker:IsA("BasePart") then
				marker.Transparency = 1.0
			end
		end
	end
end

function PlacementController.Init()
	UserInputService.InputBegan:Connect(PlacementController.OnInputBegan)
	RunService.RenderStepped:Connect(PlacementController.OnRenderStepped)
	print("[PlacementController] Initialized.")
end

return PlacementController