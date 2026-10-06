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

local mapNodesFolder = getOrCreateMapFolder("MapNodes")
local mapFloorsFolder = getOrCreateMapFolder("SectorFloors")
local shuttlePadsFolder = getOrCreateMapFolder("ShuttlePads")
local mapDecorationFolder = getOrCreateMapFolder("MapDecoration")

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

local function spawnIndustrialFloodlights(sector: SectorConfig)
	local corners = {
		Vector3.new(-60, 0, -60),
		Vector3.new(60, 0, -60),
		Vector3.new(-60, 0, 60),
		Vector3.new(60, 0, 60),
	}

	for i, cornerOffset in ipairs(corners) do
		local pylonPos = sector.offset + cornerOffset + Vector3.new(0, 8, 0)

		local pole = Instance.new("Part")
		pole.Name = string.format("FloodlightPylon_%s_%d", sector.id, i)
		pole.Size = Vector3.new(1.5, 16, 1.5)
		pole.Position = pylonPos
		pole.Anchored = true
		pole.CanCollide = true
		pole.CanQuery = false
		pole.CanTouch = false
		pole.Color = Color3.fromRGB(30, 32, 36)
		pole.Material = Enum.Material.Metal
		pole.Parent = mapDecorationFolder

		local head = Instance.new("Part")
		head.Name = "LightHead"
		head.Size = Vector3.new(2, 2, 2)
		head.Position = pylonPos + Vector3.new(0, 8.5, 0)
		head.Anchored = true
		head.CanCollide = true
		head.CanQuery = false
		head.CanTouch = false
		head.Color = Color3.fromRGB(45, 50, 58)
		head.Material = Enum.Material.Metal
		head.Parent = mapDecorationFolder

		local lens = Instance.new("Part")
		lens.Name = "NeonLens"
		lens.Size = Vector3.new(1.6, 0.2, 1.6)
		lens.Position = head.Position - Vector3.new(0, 1.05, 0)
		lens.Anchored = true
		lens.CanCollide = true
		lens.CanQuery = false
		lens.CanTouch = false
		lens.Color = Color3.fromRGB(255, 230, 180)
		lens.Material = Enum.Material.Neon
		lens.Parent = mapDecorationFolder

		local spot = Instance.new("SpotLight")
		spot.Name = "PylonSpotLight"
		spot.Brightness = 2.5
		spot.Range = 45
		spot.Angle = 70
		spot.Color = Color3.fromRGB(255, 230, 180)
		spot.Face = Enum.NormalId.Bottom
		spot.Parent = lens
	end
end

local function spawnOutpostTerrainProps(sector: SectorConfig)
	local rng = Random.new(math.abs(math.floor(sector.offset.X + 1)))

	local monolithCount = 22
	for i = 1, monolithCount do
		local angle = (i / monolithCount) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local radius = rng:NextNumber(75, 220)

		local dx = math.cos(angle) * radius
		local dz = math.sin(angle) * radius

		local width = rng:NextNumber(6, 14)
		local height = rng:NextNumber(12, 35)
		local depth = rng:NextNumber(6, 14)

		local prop = Instance.new("Part")
		prop.Name = string.format("TerrainMonolith_%s_%d", sector.id, i)
		prop.Size = Vector3.new(width, height, depth)
		prop.Anchored = true
		prop.CanCollide = true
		prop.CanQuery = false
		prop.CanTouch = false

		local tiltX = math.rad(rng:NextNumber(-15, 15))
		local tiltY = math.rad(rng:NextNumber(0, 360))
		local tiltZ = math.rad(rng:NextNumber(-15, 15))

		local basePos = sector.offset + Vector3.new(dx, height / 2 - 1, dz)
		prop.CFrame = CFrame.new(basePos) * CFrame.Angles(tiltX, tiltY, tiltZ)

		if sector.id == "Earth" then
			local shade = rng:NextNumber(0.8, 1.2)
			prop.Color = Color3.fromRGB(
				math.clamp(math.floor(48 * shade), 0, 255),
				math.clamp(math.floor(45 * shade), 0, 255),
				math.clamp(math.floor(42 * shade), 0, 255)
			)
			prop.Material = (rng:NextNumber() > 0.5) and Enum.Material.Rock or Enum.Material.Slate

		elseif sector.id == "Moon" then
			local shade = rng:NextNumber(0.85, 1.15)
			prop.Color = Color3.fromRGB(
				math.clamp(math.floor(205 * shade), 0, 255),
				math.clamp(math.floor(210 * shade), 0, 255),
				math.clamp(math.floor(215 * shade), 0, 255)
			)
			prop.Material = (rng:NextNumber() > 0.5) and Enum.Material.Basalt or Enum.Material.Concrete

		elseif sector.id == "Mars" then
			local shade = rng:NextNumber(0.85, 1.15)
			prop.Color = Color3.fromRGB(
				math.clamp(math.floor(180 * shade), 0, 255),
				math.clamp(math.floor(75 * shade), 0, 255),
				math.clamp(math.floor(50 * shade), 0, 255)
			)
			prop.Material = (rng:NextNumber() > 0.5) and Enum.Material.Sandstone or Enum.Material.CorrodedMetal

		elseif sector.id == "SolarOutpost" then
			prop.Color = Color3.fromRGB(20, 20, 25)
			prop.Material = Enum.Material.Basalt

			-- Glowing thermal seam ring
			local seam = Instance.new("Part")
			seam.Name = "ThermalSeam"
			seam.Size = Vector3.new(width * 1.05, 0.6, depth * 1.05)
			seam.CFrame = prop.CFrame
			seam.Anchored = true
			seam.CanCollide = true
			seam.CanQuery = false
			seam.CanTouch = false
			seam.Color = Color3.fromRGB(255, 120, 0)
			seam.Material = Enum.Material.Neon
			seam.Parent = mapDecorationFolder
		end

		prop.Parent = mapDecorationFolder
	end

	-- Scatter periphery boulders
	local boulderCount = 16
	for i = 1, boulderCount do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 210)
		local dx = math.cos(angle) * radius
		local dz = math.sin(angle) * radius

		local bWidth = rng:NextNumber(3, 6)
		local bHeight = rng:NextNumber(2, 4)
		local bDepth = rng:NextNumber(3, 6)

		local boulder = Instance.new("Part")
		boulder.Name = string.format("PeripheryBoulder_%s_%d", sector.id, i)
		boulder.Size = Vector3.new(bWidth, bHeight, bDepth)
		boulder.Position = sector.offset + Vector3.new(dx, bHeight / 2, dz)
		boulder.CFrame = CFrame.new(boulder.Position) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)
		boulder.Anchored = true
		boulder.CanCollide = true
		boulder.CanQuery = false
		boulder.CanTouch = false

		if sector.id == "Earth" then
			boulder.Color = Color3.fromRGB(60, 56, 52)
			boulder.Material = Enum.Material.Slate
		elseif sector.id == "Moon" then
			boulder.Color = Color3.fromRGB(210, 215, 220)
			boulder.Material = Enum.Material.Concrete
		elseif sector.id == "Mars" then
			boulder.Color = Color3.fromRGB(175, 70, 45)
			boulder.Material = Enum.Material.Sandstone
		elseif sector.id == "SolarOutpost" then
			boulder.Color = Color3.fromRGB(30, 28, 35)
			boulder.Material = Enum.Material.Basalt
		end

		boulder.Parent = mapDecorationFolder
	end
end

function MapService.GetSectorConfig(planetId: string): SectorConfig?
	return SECTORS[planetId]
end

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

	local targetPos = sector.offset + Vector3.new(0, 3, -20)
	character:PivotTo(CFrame.new(targetPos))

	-- Notify client to set local gravity and perform screen transition
	Network.Remotes.TeleportToPlanet:FireClient(player, planetId, sector.gravity)
	print(string.format("[MapService] Teleported player %s to sector %s (%s)", player.Name, sector.id, sector.name))
	return true
end

function MapService.GenerateMapSectors()
	for _, sector in pairs(SECTORS) do
		buildSectorFloor(sector)
		buildShuttlePad(sector)
		spawnIndustrialFloodlights(sector)
		spawnOutpostTerrainProps(sector)

		for _, depData in ipairs(sector.deposits) do
			for x = depData.gridXRange[1], depData.gridXRange[2] do
				for z = depData.gridZRange[1], depData.gridZRange[2] do
					spawnDepositNode(Vector3int16.new(x, 0, z), depData.depositType)
				end
			end
		end
	end

	print("[MapService] Multi-planetary sectors, floodlights, set dressing, and resource nodes generated successfully!")
end

function MapService.Init()
	setupOutpostThemingAndLighting()
	MapService.GenerateResourcePatches()
end

return MapService
