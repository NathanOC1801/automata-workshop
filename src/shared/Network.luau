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

local remotesFolder = getOrCreateFolder("Remotes", ReplicatedStorage)
local placeObjectRemote = getOrCreateRemoteEvent("PlaceObject", remotesFolder)
local syncConveyorItemsRemote = getOrCreateRemoteEvent("SyncConveyorItems", remotesFolder)

Network.Remotes = {
	PlaceObject = placeObjectRemote,
	SyncConveyorItems = syncConveyorItemsRemote,
}

return Network
