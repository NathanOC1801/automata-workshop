--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local EconomyService = require(script.Parent.EconomyService)
local PlacementService = require(script.Parent.PlacementService)
local GridService = require(script.Parent.GridService)

type SavedObjectData = {
	coord: { X: number, Y: number, Z: number },
	category: string,
	orientation: number,
}

type PlayerSaveData = {
	credits: number,
	placedObjects: { SavedObjectData },
}

local SaveService = {}

local DATA_STORE_NAME = "FactoryDataStore_v1"
local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

function SaveService.SavePlayerData(player: Player)
	local userId = player.UserId
	local key = "FactoryData_" .. userId

	local credits = EconomyService.GetCredits(player)
	local placedObjects: { SavedObjectData } = {}

	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if placedFolder then
		for _, child in ipairs(placedFolder:GetChildren()) do
			if child:IsA("BasePart") then
				-- Verify player ownership via OwnerUserId attribute
				local ownerId = child:GetAttribute("OwnerUserId")
				if ownerId == userId then
					local nameParts = string.split(child.Name, "_")
					if #nameParts >= 4 then
						local category = nameParts[1]
						local x = tonumber(nameParts[2])
						local y = tonumber(nameParts[3])
						local z = tonumber(nameParts[4])
						if x and y and z then
							local coord = Vector3int16.new(x, y, z)
							local cell = GridService.GetCell(coord)
							local orientation = cell and cell.orientation or 0
							table.insert(placedObjects, {
								coord = { X = x, Y = y, Z = z },
								category = category,
								orientation = orientation,
							})
						end
					end
				end
			end
		end
	end

	local saveData: PlayerSaveData = {
		credits = credits,
		placedObjects = placedObjects,
	}

	local success, err = pcall(function()
		dataStore:SetAsync(key, saveData)
	end)

	if success then
		print(string.format("[SaveService] Successfully saved data for player %s", player.Name))
	else
		warn(string.format("[SaveService] Failed to save data for player %s: %s", player.Name, tostring(err)))
	end
end

function SaveService.LoadPlayerData(player: Player)
	local userId = player.UserId
	local key = "FactoryData_" .. userId

	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if success and result then
		local data = result :: PlayerSaveData
		if typeof(data.credits) == "number" then
			EconomyService.SetCredits(player, data.credits)
		end

		if typeof(data.placedObjects) == "table" then
			for _, obj in ipairs(data.placedObjects) do
				if typeof(obj.coord) == "table" and typeof(obj.category) == "string" and typeof(obj.orientation) == "number" then
					local coord = Vector3int16.new(obj.coord.X, obj.coord.Y, obj.coord.Z)
					PlacementService.OnPlaceObjectRequest(player, coord, obj.category :: any, obj.orientation, true) -- bypassCost = true
				end
			end
		end
		print(string.format("[SaveService] Loaded data for player %s", player.Name))
	else
		print(string.format("[SaveService] No save data found or failed to load for player %s", player.Name))
	end
end

function SaveService.Init()
	Players.PlayerAdded:Connect(function(player)
		SaveService.LoadPlayerData(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		SaveService.SavePlayerData(player)
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			SaveService.SavePlayerData(player)
		end
	end)
end

return SaveService
