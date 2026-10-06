--!strict

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
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

local function setupOutpostThemingAndLighting()
	-- Baseplate styling: dark industrial slate/rock
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(50, 48, 45)
		baseplate.Material = Enum.Material.Slate
	end

	-- Elevated 120x120 industrial factory pad under spawn area
	local pad = Workspace:FindFirstChild("FactoryPad")
	if not pad then
		local factoryPad = Instance.new("Part")
		factoryPad.Name = "FactoryPad"
		factoryPad.Size = Vector3.new(120, 0.4, 120)
		factoryPad.Position = Vector3.new(0, -0.1, 0)
		factoryPad.Color = Color3.fromRGB(38, 40, 44)
		factoryPad.Material = Enum.Material.DiamondPlate
		factoryPad.Anchored = true
		factoryPad.CanCollide = true
		factoryPad.Parent = Workspace
	end

	-- Lighting Technology Future
	Lighting.Technology = Enum.Technology.Future

	-- Warm outpost dust atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.35
	atmosphere.Haze = 1.5
	atmosphere.Color = Color3.fromRGB(180, 140, 110)
	atmosphere.Decay = Color3.fromRGB(110, 85, 70)

	-- ColorCorrectionEffect
	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = 0.15
end

local function spawnDepositNode(coord: Vector3int16, depositType: "Iron" | "Copper")
	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = string.format("%sDeposit_%d_%d_%d", depositType, coord.X, coord.Y, coord.Z)
	part.Size = Vector3.new(3.8, 0.2, 3.8)
	-- Raised slightly above floor (Y = 0.1) with thickness 0.2 to prevent Z-fighting
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

	-- Starter guarantee: 1 Iron cluster (4 cells) and 1 Copper cluster (4 cells) 20-30 studs from spawn (0,0,0)
	local starterIronCenter = Vector3int16.new(-6, 0, 0)
	local starterCopperCenter = Vector3int16.new(6, 0, 0)

	spawnContiguousCluster(starterIronCenter, 4, "Iron", occupiedCoords)
	spawnContiguousCluster(starterCopperCenter, 4, "Copper", occupiedCoords)

	-- Scatter 6-8 additional random resource veins (Iron & Copper) across 150-stud radius (-37 to +37 grid coords)
	for _ = 1, 4 do
		local cx = math.random(-30, 30)
		local cz = math.random(-30, 30)
		if math.abs(cx) > 8 or math.abs(cz) > 8 then
			spawnContiguousCluster(Vector3int16.new(cx, 0, cz), math.random(3, 5), "Iron", occupiedCoords)
		end
	end

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
	setupOutpostThemingAndLighting()
	MapService.GenerateResourcePatches()
end

return MapService
