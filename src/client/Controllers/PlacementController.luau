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

local isDragging = false
local previousDragCoord: Vector3int16? = nil

local function getGhostSizeAndOffset(category: Types.MachineCategory): (Vector3, number)
	if category == "Conveyor" then
		return Vector3.new(4, 1, 4), 0.5
	elseif category == "Splitter" or category == "Merger" then
		return Vector3.new(4, 2, 4), 1.0
	elseif category == "Storage" then
		return Vector3.new(4, 6, 4), 3.0
	else
		return Vector3.new(4, 4, 4), 2.0
	end
end

local function createNeonPortMarker(parentPart: BasePart, isOutput: boolean, size: Vector3): Part
	local port = Instance.new("Part")
	port.Name = isOutput and "OutputPort" or "InputPort"
	port.Size = size
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

local function buildGhostPorts(parentPart: BasePart, category: Types.MachineCategory)
	for _, child in ipairs(parentPart:GetChildren()) do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end

	if category == "Conveyor" then
		local frontPort = createNeonPortMarker(parentPart, true, Vector3.new(2.8, 0.05, 0.3))
		frontPort.CFrame = parentPart.CFrame * CFrame.new(0, 0.51, -1.8)

		local rearPort = createNeonPortMarker(parentPart, false, Vector3.new(2.8, 0.05, 0.3))
		rearPort.CFrame = parentPart.CFrame * CFrame.new(0, 0.51, 1.8)

	elseif category == "Assembler" then
		local outPort = createNeonPortMarker(parentPart, true, Vector3.new(1.6, 0.2, 0.4))
		outPort.CFrame = parentPart.CFrame * CFrame.new(0, 0, -2.05)

		local leftIn = createNeonPortMarker(parentPart, false, Vector3.new(1.2, 0.2, 0.4))
		leftIn.CFrame = parentPart.CFrame * CFrame.new(-1.0, 0, 2.05)

		local rightIn = createNeonPortMarker(parentPart, false, Vector3.new(1.2, 0.2, 0.4))
		rightIn.CFrame = parentPart.CFrame * CFrame.new(1.0, 0, 2.05)
	end
end

local function updateGhostAppearance()
	if not ghostPart then
		return
	end
	local size, _ = getGhostSizeAndOffset(selectedCategory)
	ghostPart.Size = size
	buildGhostPorts(ghostPart, selectedCategory)
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

	buildGhostPorts(part, selectedCategory)
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

local function calculateDragOrientation(fromCoord: Vector3int16, toCoord: Vector3int16): number
	local dx = toCoord.X - fromCoord.X
	local dz = toCoord.Z - fromCoord.Z
	if dz == -1 then
		return 0 -- -Z
	elseif dx == -1 then
		return 90 -- -X
	elseif dz == 1 then
		return 180 -- +Z
	elseif dx == 1 then
		return 270 -- +X
	end
	return orientation
end

-- Auto-orientation snapping for single conveyor placement
local function checkAutoOrientationSnap(coord: Vector3int16): number?
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if not placedFolder then
		return nil
	end

	local neighborOffsets = {
		Vector3int16.new(0, 0, 1),  -- Behind
		Vector3int16.new(1, 0, 0),  -- Right
		Vector3int16.new(0, 0, -1), -- Front
		Vector3int16.new(-1, 0, 0), -- Left
	}

	for _, offset in ipairs(neighborOffsets) do
		local neighborCoord = Vector3int16.new(coord.X + offset.X, coord.Y + offset.Y, coord.Z + offset.Z)
		local neighborWorldPos = GridMath.gridToWorld(neighborCoord)
		for _, obj in ipairs(placedFolder:GetChildren()) do
			if obj:IsA("BasePart") then
				if math.abs(obj.Position.X - neighborWorldPos.X) < 1 and math.abs(obj.Position.Z - neighborWorldPos.Z) < 1 then
					-- Found adjacent machine/conveyor! Determine if its forward direction feeds into coord
					local nameParts = string.split(obj.Name, "_")
					local x, y, z = tonumber(nameParts[2]), tonumber(nameParts[3]), tonumber(nameParts[4])
					if x and y and z then
						local rotY = math.round(obj.Orientation.Y) % 360
						if rotY < 0 then rotY += 360 end

						local fwdDx, fwdDz = 0, 0
						if rotY == 0 then fwdDz = -1
						elseif rotY == 90 or rotY == 270 then
							-- Check CFrame LookVector direction
							local look = obj.CFrame.LookVector
							if look.Z < -0.5 then fwdDz = -1
							elseif look.Z > 0.5 then fwdDz = 1
							elseif look.X < -0.5 then fwdDx = -1
							elseif look.X > 0.5 then fwdDx = 1
							end
						elseif rotY == 180 then fwdDz = 1
						end

						local targetX = neighborCoord.X + fwdDx
						local targetZ = neighborCoord.Z + fwdDz
						if targetX == coord.X and targetZ == coord.Z then
							-- Neighbor is pointing into coord! Auto-snap orientation away from neighbor
							if fwdDz == -1 then return 0
							elseif fwdDx == -1 then return 90
							elseif fwdDz == 1 then return 180
							elseif fwdDx == 1 then return 270
							end
						end
					end
				end
			end
		end
	end

	return nil
end

function PlacementController.IsPlacementActive(): boolean
	return isPlacementActive
end

function PlacementController.TogglePlacementMode()
	isPlacementActive = not isPlacementActive
	isDragging = false
	previousDragCoord = nil
	if isPlacementActive then
		ghostPart = createGhostPart()
		print("[PlacementController] Placement mode enabled. Keys 1=Conveyor, 2=Drill, 3=Smelter, 4=Splitter, 5=Merger, 6=Storage, 7=Sink, 8=Assembler. Right-Click/X=Demolish. 'R'=Rotate, 'E'=Toggle.")
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
	if ghostPart then
		buildGhostPorts(ghostPart, selectedCategory)
	end
end

function PlacementController.SelectCategory(category: Types.MachineCategory)
	selectedCategory = category
	isDragging = false
	previousDragCoord = nil
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
		PlacementController.SelectCategory("Splitter")
	elseif input.KeyCode == Enum.KeyCode.Five then
		PlacementController.SelectCategory("Merger")
	elseif input.KeyCode == Enum.KeyCode.Six then
		PlacementController.SelectCategory("Storage")
	elseif input.KeyCode == Enum.KeyCode.Seven then
		PlacementController.SelectCategory("Sink")
	elseif input.KeyCode == Enum.KeyCode.Eight then
		PlacementController.SelectCategory("Assembler")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isPlacementActive then
			if selectedCategory == "Conveyor" then
				isDragging = true
				previousDragCoord = nil
			elseif currentGridCoord and isCellVacant then
				Network.Remotes.PlaceObject:FireServer(currentGridCoord, selectedCategory, orientation)
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.X then
		if isPlacementActive and currentGridCoord and not isCellVacant then
			Network.Remotes.RemoveObject:FireServer(currentGridCoord)
		end
	end
end

function PlacementController.OnInputEnded(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
		previousDragCoord = nil
	end
end

function PlacementController.OnRenderStepped()
	if not isPlacementActive or not ghostPart then
		return
	end

	local ray = mouse.UnitRay
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local excludeList: { Instance } = { ghostPart }
	if player.Character then
		table.insert(excludeList, player.Character)
	end
	raycastParams.FilterDescendantsInstances = excludeList

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result and result.Position.Y >= 0 then
		local hitPos = result.Position
		local gridCoord = GridMath.worldToGrid(hitPos)
		currentGridCoord = gridCoord

		local worldPos = GridMath.gridToWorld(gridCoord)
		local _, heightOffset = getGhostSizeAndOffset(selectedCategory)
		local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)

		-- Auto-orientation snap check when placing single conveyor
		if selectedCategory == "Conveyor" and not isDragging then
			local snapOrient = checkAutoOrientationSnap(gridCoord)
			if snapOrient then
				orientation = snapOrient
			end
		end

		ghostPart.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

		-- Update child port CFrames for ghost
		if selectedCategory == "Conveyor" then
			local frontPort = ghostPart:FindFirstChild("OutputPort")
			if frontPort and frontPort:IsA("BasePart") then
				frontPort.CFrame = ghostPart.CFrame * CFrame.new(0, 0.51, -1.8)
			end
			local rearPort = ghostPart:FindFirstChild("InputPort")
			if rearPort and rearPort:IsA("BasePart") then
				rearPort.CFrame = ghostPart.CFrame * CFrame.new(0, 0.51, 1.8)
			end
		elseif selectedCategory == "Assembler" then
			local outPort = ghostPart:FindFirstChild("OutputPort")
			if outPort and outPort:IsA("BasePart") then
				outPort.CFrame = ghostPart.CFrame * CFrame.new(0, 0, -2.05)
			end
			local inputPorts: { BasePart } = {}
			for _, child in ipairs(ghostPart:GetChildren()) do
				if child.Name == "InputPort" and child:IsA("BasePart") then
					table.insert(inputPorts, child)
				end
			end
			if #inputPorts >= 2 then
				inputPorts[1].CFrame = ghostPart.CFrame * CFrame.new(-1.0, 0, 2.05)
				inputPorts[2].CFrame = ghostPart.CFrame * CFrame.new(1.0, 0, 2.05)
			end
		end

		isCellVacant = checkCellVacant(gridCoord)
		if isCellVacant then
			ghostPart.Color = Color3.fromRGB(0, 255, 0)
		else
			ghostPart.Color = Color3.fromRGB(255, 0, 0)
		end
		ghostPart.Transparency = 0.5

		-- Drag-to-build logic for conveyors
		if isDragging and selectedCategory == "Conveyor" and isCellVacant then
			if previousDragCoord == nil then
				Network.Remotes.PlaceObject:FireServer(gridCoord, "Conveyor", orientation)
				previousDragCoord = gridCoord
			elseif previousDragCoord ~= gridCoord then
				local dragOrient = calculateDragOrientation(previousDragCoord, gridCoord)
				orientation = dragOrient
				Network.Remotes.PlaceObject:FireServer(gridCoord, "Conveyor", dragOrient)
				previousDragCoord = gridCoord
			end
		end
	else
		currentGridCoord = nil
		ghostPart.Transparency = 1.0
	end
end

function PlacementController.Init()
	UserInputService.InputBegan:Connect(PlacementController.OnInputBegan)
	UserInputService.InputEnded:Connect(PlacementController.OnInputEnded)
	RunService.RenderStepped:Connect(PlacementController.OnRenderStepped)
	print("[PlacementController] Initialized.")
end

return PlacementController
