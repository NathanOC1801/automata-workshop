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

local function createNeonPort(parentPart: BasePart, localOffset: Vector3, isOutput: boolean): Part
	local port = Instance.new("Part")
	port.Name = isOutput and "OutputPort" or "InputPort"
	port.Size = Vector3.new(1.5, 1.5, 0.4)
	port.Color = isOutput and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 120, 0)
	port.Material = Enum.Material.Neon
	port.Anchored = true
	port.CanCollide = false
	port.Parent = parentPart
	return port
end

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

	-- Check placement cost
	local cost = PLACEMENT_COSTS[category] or 10
	if not EconomyService.DeductCredits(player, cost) then
		warn(string.format("[PlacementService] Player %s does not have enough credits for %s ($%d)", player.Name, category, cost))
		return
	end

	-- Register cell in GridService
	local machineId = string.format("%s_%d_%d_%d", category, coord.X, coord.Y, coord.Z)

	-- Handle machine logic registration
	if category == "Conveyor" then
		ConveyorService.CreateConveyor(coord, orientation)
	elseif category == "Drill" or category == "Smelter" or category == "Sink" or category == "Splitter" or category == "Merger" or category == "Storage" then
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
		createNeonPort(part, Vector3.new(0, 0, -2), true) -- Front Output
	elseif category == "Smelter" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(130, 50, 40)
		part.Material = Enum.Material.Brick
		heightOffset = 2.0

		createNeonPort(part, Vector3.new(0, 0, 2), false)  -- Back Input
		createNeonPort(part, Vector3.new(0, 0, -2), true) -- Front Output

		local light = Instance.new("PointLight")
		light.Name = "FurnaceLight"
		light.Color = Color3.fromRGB(255, 120, 30)
		light.Range = 12
		light.Brightness = 0
		light.Parent = part
	elseif category == "Splitter" then
		part.Size = Vector3.new(4, 2, 4)
		part.Color = Color3.fromRGB(60, 140, 200)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 1.0

		createNeonPort(part, Vector3.new(0, 0, 2), false)   -- Back Input
		createNeonPort(part, Vector3.new(0, 0, -2), true)  -- Front Output
		createNeonPort(part, Vector3.new(-2, 0, 0), true)  -- Left Output
		createNeonPort(part, Vector3.new(2, 0, 0), true)   -- Right Output
	elseif category == "Merger" then
		part.Size = Vector3.new(4, 2, 4)
		part.Color = Color3.fromRGB(180, 140, 50)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 1.0

		createNeonPort(part, Vector3.new(-2, 0, 0), false) -- Left Input
		createNeonPort(part, Vector3.new(0, 0, 2), false)  -- Back Input
		createNeonPort(part, Vector3.new(2, 0, 0), false)  -- Right Input
		createNeonPort(part, Vector3.new(0, 0, -2), true)  -- Front Output
	elseif category == "Storage" then
		part.Size = Vector3.new(4, 6, 4)
		part.Color = Color3.fromRGB(70, 75, 80)
		part.Material = Enum.Material.Metal
		heightOffset = 3.0

		createNeonPort(part, Vector3.new(0, -1, 2), false)  -- Back Input
		createNeonPort(part, Vector3.new(0, -1, -2), true) -- Front Output
	elseif category == "Sink" then
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(50, 50, 60)
		part.Material = Enum.Material.SmoothPlastic
		heightOffset = 2.0

		createNeonPort(part, Vector3.new(0, 0, 2), false) -- Back Input
	else
		part.Size = Vector3.new(4, 4, 4)
		part.Color = Color3.fromRGB(120, 120, 120)
		heightOffset = 2.0
	end

	local posWithOffset = worldPos + Vector3.new(0, heightOffset, 0)
	part.CFrame = CFrame.new(posWithOffset) * CFrame.Angles(0, math.rad(orientation), 0)

	-- Update child port CFrames relative to part
	local portOffsets = {
		{ name = "InputPort", offset = Vector3.new(0, 0, 2) },
		{ name = "OutputPort", offset = Vector3.new(0, 0, -2) },
	}
	if category == "Splitter" then
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("BasePart") then
				if child.Position == Vector3.zero then
					-- position child based on local offset
				end
			end
		end
	end

	-- Positioning child ports cleanly
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BasePart") and child ~= part then
			if category == "Splitter" then
				if child.Name == "InputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, 0, 2)
				elseif child.Name == "OutputPort" then
					-- Place front, left, right outputs
					if not part:FindFirstChild("FrontSet") then
						child.CFrame = part.CFrame * CFrame.new(0, 0, -2)
						part:SetAttribute("FrontSet", true)
					elseif not part:FindFirstChild("LeftSet") then
						child.CFrame = part.CFrame * CFrame.new(-2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
						part:SetAttribute("LeftSet", true)
					else
						child.CFrame = part.CFrame * CFrame.new(2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
					end
				end
			elseif category == "Merger" then
				if child.Name == "OutputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, 0, -2)
				elseif child.Name == "InputPort" then
					if not part:FindFirstChild("LeftInSet") then
						child.CFrame = part.CFrame * CFrame.new(-2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
						part:SetAttribute("LeftInSet", true)
					elseif not part:FindFirstChild("BackInSet") then
						child.CFrame = part.CFrame * CFrame.new(0, 0, 2)
						part:SetAttribute("BackInSet", true)
					else
						child.CFrame = part.CFrame * CFrame.new(2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
					end
				end
			elseif category == "Storage" then
				if child.Name == "InputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, -1.5, 2)
				elseif child.Name == "OutputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, -1.5, -2)
				end
			else
				if child.Name == "InputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, 0, 2)
				elseif child.Name == "OutputPort" then
					child.CFrame = part.CFrame * CFrame.new(0, 0, -2)
				end
			end
		end
	end

	-- Top directional arrow GUI
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.Parent = part

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.fromScale(1, 1)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = category == "Sink" and "▼" or "▲"
	arrowLabel.TextColor3 = category == "Sink" and Color3.fromRGB(255, 120, 0) or Color3.fromRGB(255, 255, 0)
	arrowLabel.TextScaled = true
	arrowLabel.Font = Enum.Font.SourceSansBold
	arrowLabel.Parent = surfaceGui

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
	elseif category == "Drill" or category == "Smelter" or category == "Sink" or category == "Splitter" or category == "Merger" or category == "Storage" then
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
