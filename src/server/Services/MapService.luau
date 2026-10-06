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

local function spawnDepositNode(coord: Vector3int16, depositType: string)
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

	-- Copper Veins: 4 clusters of 3-4 contiguous cells
	for _ = 1, 4 do
		local cx = math.random(-30, 30)
		local cz = math.random(-30, 30)
		if math.abs(cx) > 8 or math.abs(cz) > 8 then
			spawnContiguousCluster(Vector3int16.new(cx, 0, cz), math.random(3, 4), "Copper", occupiedCoords)
		end
	end

	print("[MapService] Procedural resource veins generated across terrain grid!")
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

		for _, depData in ipairs(sector.deposits) do
			for x = depData.gridXRange[1], depData.gridXRange[2] do
				for z = depData.gridZRange[1], depData.gridZRange[2] do
					spawnDepositNode(Vector3int16.new(x, 0, z), depData.depositType)
				end
			end
		end
	end

	print("[MapService] Multi-planetary sectors and resource nodes generated successfully!")
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
