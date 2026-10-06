--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local GridService = require(script.Parent.GridService)

local MapService = {}

local function getOrCreateMapNodesFolder(): Folder
	local folder = Workspace:FindFirstChild("MapNodes")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "MapNodes"
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

local mapNodesFolder = getOrCreateMapNodesFolder()

local function spawnDepositNode(coord: Vector3int16, depositType: "Iron" | "Copper")
	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = string.format("%sDeposit_%d_%d_%d", depositType, coord.X, coord.Y, coord.Z)
	part.Size = Vector3.new(3.8, 0.2, 3.8)
	-- Top surface sits flush at Y = 0.2, cleanly above the Y = 0 baseplate surface to eliminate Z-fighting
	part.Position = Vector3.new(worldPos.X, 0.1, worldPos.Z)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false

	if depositType == "Iron" then
		part.Color = Color3.fromRGB(115, 120, 130)
		part.Material = Enum.Material.DiamondPlate
	else
		part.Color = Color3.fromRGB(200, 110, 60)
		part.Material = Enum.Material.CorrodedMetal
	end

	part.Parent = mapNodesFolder
	GridService.SetDeposit(coord, depositType)
end

function MapService.GenerateResourcePatches()
	-- Iron Deposit Patch (around coord X: -3..-1, Z: 0..2)
	for x = -3, -1 do
		for z = 0, 2 do
			spawnDepositNode(Vector3int16.new(x, 0, z), "Iron")
		end
	end

	-- Copper Deposit Patch (around coord X: 3..5, Z: 0..2)
	for x = 3, 5 do
		for z = 0, 2 do
			spawnDepositNode(Vector3int16.new(x, 0, z), "Copper")
		end
	end

	print("[MapService] Resource deposit nodes generated successfully!")
end

function MapService.Init()
	MapService.GenerateResourcePatches()
end

return MapService
