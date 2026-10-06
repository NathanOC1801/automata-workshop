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
	ProgressionService.SendMilestoneProgress(player)
end

function ProgressionService.GetSunkItems(player: Player): { [string]: number }
	return getPlayerData(player).sunkItems
end

function ProgressionService.SendMilestoneProgress(player: Player)
	local data = getPlayerData(player)
	local currentTier = data.unlockedTier
	local nextTier = currentTier + 1
	local milestone = Milestones[nextTier]

	local credits = EconomyService.GetCredits(player)

	local payload = {
		currentTier = currentTier,
		nextTier = nextTier,
		milestoneName = milestone and milestone.name or "Max Tier Reached",
		requiredCredits = milestone and milestone.requirement.credits or 0,
		currentCredits = credits,
		requiredItems = milestone and milestone.requirement.items or {},
		sunkItems = data.sunkItems,
	}

	Network.Remotes.MilestoneProgressUpdated:FireClient(player, payload)
end

local function checkMilestoneCompletion(player: Player)
	local data = getPlayerData(player)
	local currentTier = data.unlockedTier
	local nextTier = currentTier + 1
	local milestone = Milestones[nextTier]

	if not milestone then
		ProgressionService.SendMilestoneProgress(player)
		return
	end

	local credits = EconomyService.GetCredits(player)
	if credits < milestone.requirement.credits then
		ProgressionService.SendMilestoneProgress(player)
		return
	end

	for itemId, requiredCount in pairs(milestone.requirement.items) do
		local sunkCount = data.sunkItems[itemId] or 0
		if sunkCount < requiredCount then
			ProgressionService.SendMilestoneProgress(player)
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
	ProgressionService.SendMilestoneProgress(player)
end

function ProgressionService.ProcessSinkConsumption(player: Player, itemId: string)
	local data = getPlayerData(player)
	data.sunkItems[itemId] = (data.sunkItems[itemId] or 0) + 1
	checkMilestoneCompletion(player)
end

function ProgressionService.Init()
	Players.PlayerAdded:Connect(function(player)
		getPlayerData(player)
		task.delay(1, function()
			ProgressionService.SendMilestoneProgress(player)
		end)
	end)
end

return ProgressionService
