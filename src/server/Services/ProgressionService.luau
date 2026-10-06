--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Milestones = require(ReplicatedStorage.Shared.Config.Milestones)
local Network = require(ReplicatedStorage.Shared.Network)
local EconomyService = require(script.Parent.EconomyService)

local ProgressionService = {}

type PlayerProgress = {
	unlockedTier: number,
	sunkItems: { [string]: number },
}

local playerProgression: { [number]: PlayerProgress } = {}

local function getPlayerData(player: Player): PlayerProgress
	local userId = player.UserId
	if not playerProgression[userId] then
		playerProgression[userId] = {
			unlockedTier = 1,
			sunkItems = {},
		}
	end
	return playerProgression[userId]
end

function ProgressionService.GetUnlockedTier(player: Player): number
	return getPlayerData(player).unlockedTier
end

function ProgressionService.SetProgression(player: Player, tier: number, sunkItems: { [string]: number }?)
	local data = getPlayerData(player)
	data.unlockedTier = tier
	if sunkItems then
		data.sunkItems = sunkItems
	end
end

function ProgressionService.GetSunkItems(player: Player): { [string]: number }
	return getPlayerData(player).sunkItems
end

local function checkMilestoneCompletion(player: Player)
	local data = getPlayerData(player)
	local currentTier = data.unlockedTier
	local nextTier = currentTier + 1
	local milestone = Milestones[nextTier]

	if not milestone then
		return
	end

	local credits = EconomyService.GetCredits(player)
	if credits < milestone.requirement.credits then
		return
	end

	for itemId, requiredCount in pairs(milestone.requirement.items) do
		local sunkCount = data.sunkItems[itemId] or 0
		if sunkCount < requiredCount then
			return
		end
	end

	-- Criteria met! Deduct credit requirement and unlock tier
	if milestone.requirement.credits > 0 then
		EconomyService.DeductCredits(player, milestone.requirement.credits)
	end

	data.unlockedTier = nextTier
	print(string.format("[ProgressionService] Player %s unlocked Tier %d: %s!", player.Name, nextTier, milestone.name))

	Network.Remotes.MilestoneUnlocked:FireClient(player, nextTier, milestone.name)
end

function ProgressionService.ProcessSinkConsumption(player: Player, itemId: string)
	local data = getPlayerData(player)
	data.sunkItems[itemId] = (data.sunkItems[itemId] or 0) + 1
	checkMilestoneCompletion(player)
end

function ProgressionService.Init()
	Players.PlayerAdded:Connect(function(player)
		getPlayerData(player)
	end)
end

return ProgressionService
