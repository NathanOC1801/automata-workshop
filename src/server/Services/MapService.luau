--!strict

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
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
	outerFloorColor: Color3,
	outerFloorMaterial: Enum.Material,
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
		outerFloorColor = Color3.fromRGB(28, 26, 25),
		outerFloorMaterial = Enum.Material.Slate,
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
		outerFloorColor = Color3.fromRGB(150, 155, 160),
		outerFloorMaterial = Enum.Material.Basalt,
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
		outerFloorColor = Color3.fromRGB(115, 45, 30),
		outerFloorMaterial = Enum.Material.Sandstone,
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
		outerFloorColor = Color3.fromRGB(20, 20, 25),
		outerFloorMaterial = Enum.Material.Basalt,
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

local function buildDualLayerSectorFloor(sector: SectorConfig)
	-- 1. Outer Wasteland Terrain Floor (600 x 600)
	local outerFloor = Instance.new("Part")
	outerFloor.Name = string.format("OuterTerrain_%s", sector.id)
	outerFloor.Size = Vector3.new(600, 2, 600)
	outerFloor.Position = sector.offset + Vector3.new(0, -0.6, 0)
	outerFloor.Anchored = true
	outerFloor.CanCollide = true
	outerFloor.Color = sector.outerFloorColor
	outerFloor.Material = sector.outerFloorMaterial
	outerFloor.Parent = mapFloorsFolder

	-- 2. Inner Factory Foundation Pad (140 x 140)
	local innerPad = Instance.new("Part")
	innerPad.Name = string.format("FactoryPad_%s", sector.id)
	innerPad.Size = Vector3.new(140, 2, 140)
	innerPad.Position = sector.offset + Vector3.new(0, 0, 0)
	innerPad.Anchored = true
	innerPad.CanCollide = true
	innerPad.Color = Color3.fromRGB(38, 42, 48)
	innerPad.Material = Enum.Material.DiamondPlate
	innerPad.Parent = mapFloorsFolder

	-- Perimeter Curb Beams
	local curbHeight = 0.4
	local curbWidth = 2.0
	local curbY = 1.0 + curbHeight / 2 -- top surface at Y = 1.2
	local curbColor = Color3.fromRGB(55, 60, 68)

	local curbs = {
		{ name = "CurbNorth", size = Vector3.new(140, curbHeight, curbWidth), pos = Vector3.new(0, curbY, -69) },
		{ name = "CurbSouth", size = Vector3.new(140, curbHeight, curbWidth), pos = Vector3.new(0, curbY, 69) },
		{ name = "CurbEast", size = Vector3.new(curbWidth, curbHeight, 136), pos = Vector3.new(69, curbY, 0) },
		{ name = "CurbWest", size = Vector3.new(curbWidth, curbHeight, 136), pos = Vector3.new(-69, curbY, 0) },
	}

	for _, cData in ipairs(curbs) do
		local curb = Instance.new("Part")
		curb.Name = string.format("%s_%s", cData.name, sector.id)
		curb.Size = cData.size
		curb.Position = sector.offset + cData.pos
		curb.Anchored = true
		curb.CanCollide = true
		curb.CanQuery = false
		curb.CanTouch = false
		curb.Color = curbColor
		curb.Material = Enum.Material.Metal
		curb.Parent = mapDecorationFolder
	end
end

local function buildShuttlePad(sector: SectorConfig)
	local padCenter = sector.offset + Vector3.new(0, 0.5, -20)

	-- Beveled metallic border frame sunk around shuttle pad
	local frame = Instance.new("Part")
	frame.Name = string.format("ShuttlePadFrame_%s", sector.id)
	frame.Size = Vector3.new(13.6, 1.2, 13.6)
	frame.Position = padCenter + Vector3.new(0, -0.1, 0)
	frame.Anchored = true
	frame.CanCollide = true
	frame.CanQuery = false
	frame.CanTouch = false
	frame.Color = Color3.fromRGB(25, 28, 35)
	frame.Material = Enum.Material.Metal
	frame.Parent = mapDecorationFolder

	local basePad = Instance.new("Part")
	basePad.Name = string.format("ShuttlePad_%s", sector.id)
	basePad.Size = Vector3.new(12, 1.0, 12)
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
		Vector3.new(-68, 0, -68),
		Vector3.new(68, 0, -68),
		Vector3.new(-68, 0, 68),
		Vector3.new(68, 0, 68),
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

	-- Compound Rock Bluff Clusters (12-16 clusters)
	local clusterCount = 14
	for i = 1, clusterCount do
		local angle = (i / clusterCount) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local radius = rng:NextNumber(85, 260)

		local dx = math.cos(angle) * radius
		local dz = math.sin(angle) * radius

		local coreW = rng:NextNumber(12, 18)
		local coreH = rng:NextNumber(25, 45)
		local coreD = rng:NextNumber(12, 18)

		local clusterCenter = sector.offset + Vector3.new(dx, coreH / 2 - 1, dz)

		-- Core Spire
		local coreSpire = Instance.new("Part")
		coreSpire.Name = string.format("BluffCore_%s_%d", sector.id, i)
		coreSpire.Size = Vector3.new(coreW, coreH, coreD)
		coreSpire.Anchored = true
		coreSpire.CanCollide = true
		coreSpire.CanQuery = false
		coreSpire.CanTouch = false

		local tiltX = math.rad(rng:NextNumber(-12, 12))
		local tiltY = math.rad(rng:NextNumber(0, 360))
		local tiltZ = math.rad(rng:NextNumber(-12, 12))
		coreSpire.CFrame = CFrame.new(clusterCenter) * CFrame.Angles(tiltX, tiltY, tiltZ)

		local mainColor = Color3.fromRGB(45, 42, 40)
		local mainMat = Enum.Material.Slate

		if sector.id == "Earth" then
			local shade = rng:NextNumber(0.8, 1.2)
			mainColor = Color3.fromRGB(
				math.clamp(math.floor(48 * shade), 0, 255),
				math.clamp(math.floor(45 * shade), 0, 255),
				math.clamp(math.floor(42 * shade), 0, 255)
			)
			mainMat = (rng:NextNumber() > 0.5) and Enum.Material.Rock or Enum.Material.Slate
		elseif sector.id == "Moon" then
			local shade = rng:NextNumber(0.85, 1.15)
			mainColor = Color3.fromRGB(
				math.clamp(math.floor(190 * shade), 0, 255),
				math.clamp(math.floor(195 * shade), 0, 255),
				math.clamp(math.floor(200 * shade), 0, 255)
			)
			mainMat = (rng:NextNumber() > 0.5) and Enum.Material.Basalt or Enum.Material.Concrete
		elseif sector.id == "Mars" then
			local shade = rng:NextNumber(0.85, 1.15)
			mainColor = Color3.fromRGB(
				math.clamp(math.floor(170 * shade), 0, 255),
				math.clamp(math.floor(65 * shade), 0, 255),
				math.clamp(math.floor(40 * shade), 0, 255)
			)
			mainMat = (rng:NextNumber() > 0.5) and Enum.Material.Sandstone or Enum.Material.CorrodedMetal
		elseif sector.id == "SolarOutpost" then
			mainColor = Color3.fromRGB(20, 20, 25)
			mainMat = Enum.Material.Basalt

			-- Glowing thermal seam ring
			local seam = Instance.new("Part")
			seam.Name = "ThermalSeam"
			seam.Size = Vector3.new(coreW * 1.05, 0.6, coreD * 1.05)
			seam.CFrame = coreSpire.CFrame
			seam.Anchored = true
			seam.CanCollide = true
			seam.CanQuery = false
			seam.CanTouch = false
			seam.Color = Color3.fromRGB(255, 120, 0)
			seam.Material = Enum.Material.Neon
			seam.Parent = mapDecorationFolder
		end

		coreSpire.Color = mainColor
		coreSpire.Material = mainMat
		coreSpire.Parent = mapDecorationFolder

		-- 2-3 smaller overlapping wedge rocks wedged into core spire
		local wedgeCount = rng:NextInteger(2, 3)
		for w = 1, wedgeCount do
			local wW = rng:NextNumber(6, 10)
			local wH = rng:NextNumber(10, 20)
			local wD = rng:NextNumber(6, 10)

			local offsetOffset = Vector3.new(rng:NextNumber(-coreW * 0.4, coreW * 0.4), rng:NextNumber(-coreH * 0.2, 0), rng:NextNumber(-coreD * 0.4, coreD * 0.4))

			local subRock = Instance.new("Part")
			subRock.Name = string.format("BluffWedge_%s_%d_%d", sector.id, i, w)
			subRock.Size = Vector3.new(wW, wH, wD)
			subRock.Anchored = true
			subRock.CanCollide = true
			subRock.CanQuery = false
			subRock.CanTouch = false
			subRock.Color = mainColor
			subRock.Material = mainMat

			local wTiltX = tiltX + math.rad(rng:NextNumber(-25, 25))
			local wTiltY = tiltY + math.rad(rng:NextNumber(-45, 45))
			local wTiltZ = tiltZ + math.rad(rng:NextNumber(-25, 25))
			subRock.CFrame = CFrame.new(clusterCenter + offsetOffset) * CFrame.Angles(wTiltX, wTiltY, wTiltZ)

			subRock.Parent = mapDecorationFolder
		end
	end

	-- Scatter periphery boulders
	local boulderCount = 18
	for i = 1, boulderCount do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(80, 250)
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
			boulder.Color = Color3.fromRGB(200, 205, 210)
			boulder.Material = Enum.Material.Concrete
		elseif sector.id == "Mars" then
			boulder.Color = Color3.fromRGB(165, 60, 35)
			boulder.Material = Enum.Material.Sandstone
		elseif sector.id == "SolarOutpost" then
			boulder.Color = Color3.fromRGB(30, 28, 35)
			boulder.Material = Enum.Material.Basalt
		end

		boulder.Parent = mapDecorationFolder
	end
end

local function setupOutpostThemingAndLighting()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		local newAtmosphere = Instance.new("Atmosphere")
		newAtmosphere.Name = "Atmosphere"
		newAtmosphere.Parent = Lighting
		atmosphere = newAtmosphere
	end

	atmosphere.Density = 0.38
	atmosphere.Offset = 0.1
	atmosphere.Haze = 2.2
	atmosphere.Color = Color3.fromRGB(160, 175, 195)
	atmosphere.Decay = Color3.fromRGB(90, 100, 120)

	Lighting.ClockTime = 17.2
	Lighting.ExposureCompensation = 0.25

	print("[MapService] Configured atmospheric volumetric lighting & dusk lighting parameters.")
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
		buildDualLayerSectorFloor(sector)
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

	print("[MapService] Dual-layer sectors, floodlights, compound terrain bluffs, and resource nodes generated successfully!")
end

function MapService.Init()
	setupOutpostThemingAndLighting()
	MapService.GenerateMapSectors()

	Network.Remotes.TeleportToPlanet.OnServerEvent:Connect(function(player, planetId)
		if typeof(planetId) == "string" then
			MapService.TeleportPlayerToPlanet(player, planetId)
		end
	end)
end

return MapService
