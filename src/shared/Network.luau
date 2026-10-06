--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = {}

local isServer = RunService:IsServer()

local function getOrCreateFolder(name: string, parent: Instance): Folder
	if isServer then
		local folder = parent:FindFirstChild(name)
		if not folder then
			local newFolder = Instance.new("Folder")
			newFolder.Name = name
			newFolder.Parent = parent
			folder = newFolder
		end
		return folder :: Folder
	else
		return parent:WaitForChild(name) :: Folder
	end
end

local function getOrCreateRemoteEvent(name: string, parent: Instance): RemoteEvent
	if isServer then
		local remote = parent:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = parent
			remote = newRemote
		end
		return remote :: RemoteEvent
	else
		return parent:WaitForChild(name) :: RemoteEvent
	end
end

local function getOrCreateRemoteFunction(name: string, parent: Instance): RemoteFunction
	if isServer then
		local remote = parent:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteFunction")
			newRemote.Name = name
			newRemote.Parent = parent
			remote = newRemote
		end
		return remote :: RemoteFunction
	else
		return parent:WaitForChild(name) :: RemoteFunction
	end
end

local remotesFolder = getOrCreateFolder("Remotes", ReplicatedStorage)
local placeObjectRemote = getOrCreateRemoteEvent("PlaceObject", remotesFolder)
local removeObjectRemote = getOrCreateRemoteEvent("RemoveObject", remotesFolder)
local syncConveyorItemsRemote = getOrCreateRemoteEvent("SyncConveyorItems", remotesFolder)
local syncCreditsRemote = getOrCreateRemoteEvent("SyncCredits", remotesFolder)
local milestoneUnlockedRemote = getOrCreateRemoteEvent("MilestoneUnlocked", remotesFolder)
local milestoneProgressUpdatedRemote = getOrCreateRemoteEvent("MilestoneProgressUpdated", remotesFolder)
local selectRecipeRemote = getOrCreateRemoteEvent("SelectRecipe", remotesFolder)
local setMachineRecipeRemote = getOrCreateRemoteEvent("SetMachineRecipe", remotesFolder)
local clearBufferRemote = getOrCreateRemoteEvent("ClearBuffer", remotesFolder)
local planetUnlockedRemote = getOrCreateRemoteEvent("PlanetUnlocked", remotesFolder)
local teleportToPlanetRemote = getOrCreateRemoteEvent("TeleportToPlanet", remotesFolder)
local openPlanetaryMapRemote = getOrCreateRemoteEvent("OpenPlanetaryMap", remotesFolder)

local getMachineStateFunction = getOrCreateRemoteFunction("GetMachineState", remotesFolder)

Network.Remotes = {
	PlaceObject = placeObjectRemote,
	RemoveObject = removeObjectRemote,
	SyncConveyorItems = syncConveyorItemsRemote,
	SyncCredits = syncCreditsRemote,
	MilestoneUnlocked = milestoneUnlockedRemote,
	MilestoneProgressUpdated = milestoneProgressUpdatedRemote,
	SelectRecipe = selectRecipeRemote,
	SetMachineRecipe = setMachineRecipeRemote,
	ClearBuffer = clearBufferRemote,
	PlanetUnlocked = planetUnlockedRemote,
	TeleportToPlanet = teleportToPlanetRemote,
	OpenPlanetaryMap = openPlanetaryMapRemote,
	GetMachineState = getMachineStateFunction,
}

return Network
