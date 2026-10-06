--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)
local GridService = require(script.Parent.GridService)
local ProgressionService = require(script.Parent.ProgressionService)

export type SectorConfig = {
	id: string,
	name: string,
	offset: Vector3,
	gravity: number,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	deposits: {
		{ depositType: string, gridXRange: { number }, gridZRange: { number } },
	},
}

local MapService = {}

local SECTORS: { [string]: SectorConfig } = {
	Earth = {
		id = "Earth",
		name = "Earth Quarry",
		offset = Vector3.new(0, 0, 0),
		gravity = 196.2,
		floorColor = Color3.fromRGB(100, 105, 110),
		floorMaterial = Enum.Material.SmoothPlastic,
		deposits = {
			{ depositType = "Iron", gridXRange = { -3, -1 }, gridZRange = { 0, 2 } },
			{ depositType = "Copper", gridXRange = { 3, 5 }, gridZRange = { 0, 2 } },
		},
	},
	Moon = {
		id = "Moon",
		name = "Lunar Basin",
		offset = Vector3.new(2000, 0, 0),
		gravity = 70,
		floorColor = Color3.fromRGB(180, 185, 190),
		floorMaterial = Enum.Material.Concrete,
		deposits = {
			{ depositType = "Titanium", gridXRange = { 497, 499 }, gridZRange = { 0, 2 } },
			{ depositType = "Emerald", gridXRange = { 503, 505 }, gridZRange = { 0, 2 } },
		},
	},
	Mars = {
		id = "Mars",
		name = "Mars Badlands",
		offset = Vector3.new(4000, 0, 0),
		gravity = 120,
		floorColor = Color3.fromRGB(160, 70, 50),
		floorMaterial = Enum.Material.CorrodedMetal,
		deposits = {
			{ depositType = "Cobalt", gridXRange = { 997, 999 }, gridZRange = { 0, 2 } },
			{ depositType = "Gold", gridXRange = { 1003, 1005 }, gridZRange = { 0, 2 } },
		},
	},
	SolarOutpost = {
		id = "SolarOutpost",
		name = "Solar Outpost",
		offset = Vector3.new(6000, 0, 0),
		gravity = 300,
		floorColor = Color3.fromRGB(25, 25, 30),
		floorMaterial = Enum.Material.Basalt,
		deposits = {
			{ depositType = "Uranium", gridXRange = { 1497, 1499 }, gridZRange = { 0, 2 } },
			{ depositType = "Diamond", gridXRange = { 1503, 1505 }, gridZRange = { 0, 2 } },
		},
	},
}

local function getOrCreateMapFolder(folderName: string): Folder
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = folderName
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

local mapNodesFolder = getOrCreateMapFolder("MapNodes")
local mapFloorsFolder = getOrCreateMapFolder("SectorFloors")
local shuttlePadsFolder = getOrCreateMapFolder("ShuttlePads")
local mapDecorationFolder = getOrCreateMapFolder("MapDecoration")

local function spawnDepositNode(coord: Vector3int16, depositType: string)
	local worldPos = GridMath.gridToWorld(coord)
	local part = Instance.new("Part")
	part.Name = string.format("%sDeposit_%d_%d_%d", depositType, coord.X, coord.Y, coord.Z)
	part.Size = Vector3.new(3.8, 0.2, 3.8)
	part.Position = Vector3.new(worldPos.X, 0.1, worldPos.Z)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false

	if depositType == "Iron" then
		part.Color = Color3.fromRGB(115, 120, 130)
		part.Material = Enum.Material.DiamondPlate
	elseif depositType == "Copper" then
		part.Color = Color3.fromRGB(200, 110, 60)
		part.Material = Enum.Material.CorrodedMetal
	elseif depositType == "Titanium" then
		part.Color = Color3.fromRGB(180, 190, 210)
		part.Material = Enum.Material.DiamondPlate
	elseif depositType == "Cobalt" then
		part.Color = Color3.fromRGB(30, 80, 180)
		part.Material = Enum.Material.Metal
	elseif depositType == "Gold" then
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Material = Enum.Material.Metal
	elseif depositType == "Emerald" then
		part.Color = Color3.fromRGB(0, 220, 100)
		part.Material = Enum.Material.Neon
	elseif depositType == "Diamond" then
		part.Color = Color3.fromRGB(150, 230, 255)
		part.Material = Enum.Material.Glass
	elseif depositType == "Uranium" then
		part.Color = Color3.fromRGB(100, 255, 50)
		part.Material = Enum.Material.Neon
	end

	part.Parent = mapNodesFolder
	GridService.SetDeposit(coord, depositType)
end

local function buildSectorFloor(sector: SectorConfig)
	if sector.id == "Earth" then
		return -- Earth uses the main baseplate
	end

	local floor = Instance.new("Part")
	floor.Name = string.format("Floor_%s", sector.id)
	floor.Size = Vector3.new(400, 2, 400)
	floor.Position = sector.offset + Vector3.new(0, -1, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = sector.floorColor
	floor.Material = sector.floorMaterial
	floor.Parent = mapFloorsFolder
end

local function buildShuttlePad(sector: SectorConfig)
	local padCenter = sector.offset + Vector3.new(0, 0.5, -20)

	local basePad = Instance.new("Part")
	basePad.Name = string.format("ShuttlePad_%s", sector.id)
	basePad.Size = Vector3.new(12, 1, 12)
	basePad.Position = padCenter
	basePad.Anchored = true
	basePad.CanCollide = true
	basePad.Color = Color3.fromRGB(35, 40, 50)
	basePad.Material = Enum.Material.DiamondPlate
	basePad.Parent = shuttlePadsFolder

	-- Flush neon ring pad accent
	local ring = Instance.new("Part")
	ring.Name = "NeonRing"
	ring.Size = Vector3.new(10, 0.1, 10)
	ring.Position = padCenter + Vector3.new(0, 0.51, 0)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Color = Color3.fromRGB(0, 200, 255)
	ring.Material = Enum.Material.Neon
	ring.Parent = basePad

	-- Proximity Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = string.format("Shuttle Pad [%s]", sector.name)
	prompt.ActionText = "Launch Planetary Map"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = basePad

	prompt.Triggered:Connect(function(player)
		Network.Remotes.OpenPlanetaryMap:FireClient(player)
	end)

	basePad.Touched:Connect(function(hit)
		local character = hit.Parent
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player and hit.Name == "HumanoidRootPart" then
				Network.Remotes.OpenPlanetaryMap:FireClient(player)
			end
		end
	end)
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

function MapService.TeleportPlayerToPlanet(player: Player, planetId: string): boolean
	local sector = SECTORS[planetId]
	if not sector then
		warn(string.format("[MapService] Unknown planet target: %s", tostring(planetId)))
		return false
	end

	-- Verify unlock status with ProgressionService
	if not ProgressionService.IsPlanetUnlocked(player, planetId) then
		warn(string.format("[MapService] Player %s attempt to teleport to locked planet %s!", player.Name, planetId))
		return false
	end

	local character = player.Character
	if not character then
		return false
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
	MapService.GenerateMapSectors()

	Network.Remotes.TeleportToPlanet.OnServerEvent:Connect(function(player, planetId)
		if typeof(planetId) == "string" then
			MapService.TeleportPlayerToPlanet(player, planetId)
		end
	end)
end

return MapService
