--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)

local EconomyService = {}

local STARTING_CREDITS = 250
local playerCredits: { [number]: number } = {}

function EconomyService.GetCredits(player: Player): number
	local userId = player.UserId
	if playerCredits[userId] == nil then
		playerCredits[userId] = STARTING_CREDITS
	end
	return playerCredits[userId]
end

function EconomyService.AddCredits(player: Player, amount: number)
	local userId = player.UserId
	local current = EconomyService.GetCredits(player)
	local updated = current + amount
	playerCredits[userId] = updated
	Network.Remotes.SyncCredits:FireClient(player, updated)
end

function EconomyService.DeductCredits(player: Player, amount: number): boolean
	local current = EconomyService.GetCredits(player)
	if current < amount then
		return false
	end
	local updated = current - amount
	playerCredits[player.UserId] = updated
	Network.Remotes.SyncCredits:FireClient(player, updated)
	return true
end

function EconomyService.Init()
	Players.PlayerAdded:Connect(function(player)
		local credits = EconomyService.GetCredits(player)
		Network.Remotes.SyncCredits:FireClient(player, credits)
	end)
end

return EconomyService
