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
	-- Raised slightly above the baseplate (Y = 0.1) with thickness 0.2 to prevent Z-fighting
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

local function spawnContiguousCluster(startCoord: Vector3int16, clusterSize: number, depositType: "Iron" | "Copper", occupiedCoords: { [string]: boolean })
	local current = startCoord
	for _ = 1, clusterSize do
		local key = string.format("%d,%d,%d", current.X, current.Y, current.Z)
		if not occupiedCoords[key] then
			occupiedCoords[key] = true
			spawnDepositNode(current, depositType)
		end

		-- Pick a contiguous neighbor step
		local dir = math.random(1, 4)
		if dir == 1 then
			current = Vector3int16.new(current.X + 1, current.Y, current.Z)
		elseif dir == 2 then
			current = Vector3int16.new(current.X - 1, current.Y, current.Z)
		elseif dir == 3 then
			current = Vector3int16.new(current.X, current.Y, current.Z + 1)
		else
			current = Vector3int16.new(current.X, current.Y, current.Z - 1)
		end
	end
end

function MapService.GenerateResourcePatches()
	local occupiedCoords: { [string]: boolean } = {}

	-- Starter guarantee: 1 Iron cluster and 1 Copper cluster within 20-35 studs (5-8 grid coords) of spawn (0,0,0)
	local starterIronCenter = Vector3int16.new(-6, 0, 0)
	local starterCopperCenter = Vector3int16.new(6, 0, 0)

	spawnContiguousCluster(starterIronCenter, 4, "Iron", occupiedCoords)
	spawnContiguousCluster(starterCopperCenter, 4, "Copper", occupiedCoords)

	-- Procedural Scattered Veins (-150 to +150 studs radius / -37 to +37 grid coords)
	-- Iron Veins: 5 clusters of 3-5 contiguous cells
	for _ = 1, 5 do
		local cx = math.random(-30, 30)
		local cz = math.random(-30, 30)
		-- Avoid starter area
		if math.abs(cx) > 8 or math.abs(cz) > 8 then
			spawnContiguousCluster(Vector3int16.new(cx, 0, cz), math.random(3, 5), "Iron", occupiedCoords)
		end
	end

	-- Copper Veins: 4 clusters of 3-4 contiguous cells
	for _ = 1, 4 do
		local cx = math.random(-30, 30)
		local cz = math.random(-30, 30)
		if math.abs(cx) > 8 or math.abs(cz) > 8 then
			spawnContiguousCluster(Vector3int16.new(cx, 0, cz), math.random(3, 4), "Copper", occupiedCoords)
		end
	end

	print("[MapService] Procedural resource veins generated across terrain grid!")
end

function MapService.Init()
	MapService.GenerateResourcePatches()
end

return MapService
