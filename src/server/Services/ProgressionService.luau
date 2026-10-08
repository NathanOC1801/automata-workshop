--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Milestones = require(ReplicatedStorage.Shared.Config.Milestones)
local Network = require(ReplicatedStorage.Shared.Network)
local EconomyService = require(script.Parent.EconomyService)

export type PlanetRequirement = {
	planetId: string,
	displayName: string,
	credits: number,
	items: { [string]: number },
}

local PLANET_REQUIREMENTS: { [string]: PlanetRequirement } = {
	Moon = {
		planetId = "Moon",
		displayName = "Lunar Basin",
		credits = 1000,
		items = {
			IronPlate = 50,
		},
	},
	Mars = {
		planetId = "Mars",
		displayName = "Mars Badlands",
		credits = 10000,
		items = {
			Wire = 50,
			TitaniumIngot = 25,
		},
	},
	SolarOutpost = {
		planetId = "SolarOutpost",
		displayName = "Solar Outpost",
		credits = 50000,
		items = {
			Circuit = 50,
			GoldBar = 25,
		},
	},
}

type PlayerProgress = {
	unlockedTier: number,
	sunkItems: { [string]: number },
	unlockedPlanets: { [string]: boolean },
}

local ProgressionService = {}

local playerProgression: { [number]: PlayerProgress } = {}

local function getPlayerData(player: Player): PlayerProgress
	local userId = player.UserId
	if not playerProgression[userId] then
		playerProgression[userId] = {
			unlockedTier = 1,
			sunkItems = {},
			unlockedPlanets = { Earth = true },
		}
	end
	return playerProgression[userId]
end

function ProgressionService.GetUnlockedTier(player: Player): number
	return getPlayerData(player).unlockedTier
end

function ProgressionService.IsPlanetUnlocked(player: Player, planetId: string): boolean
	local planets = getPlayerData(player).unlockedPlanets
	return planets[planetId] == true
end

function ProgressionService.GetUnlockedPlanets(player: Player): { string }
	local planets = getPlayerData(player).unlockedPlanets
	local list: { string } = {}
	for id, unlocked in pairs(planets) do
		if unlocked then
			table.insert(list, id)
		end
	end
	return list
end

function ProgressionService.SetUnlockedPlanets(player: Player, planetsList: { string }?)
	local data = getPlayerData(player)
	data.unlockedPlanets = { Earth = true }
	if planetsList then
		for _, planetId in ipairs(planetsList) do
			data.unlockedPlanets[planetId] = true
		end
	end
end

function ProgressionService.SetProgression(player: Player, tier: number, sunkItems: { [string]: number }?, unlockedPlanets: { string }?)
	local data = getPlayerData(player)
	data.unlockedTier = tier
	if sunkItems then
		data.sunkItems = sunkItems
	end
	ProgressionService.SetUnlockedPlanets(player, unlockedPlanets)
	ProgressionService.SendMilestoneProgress(player)
end

function ProgressionService.GetSunkItems(player: Player): { [string]: number }
	return getPlayerData(player).sunkItems
end

function ProgressionService.GetPlanetRequirements(): { [string]: PlanetRequirement }
	return PLANET_REQUIREMENTS
end

function ProgressionService.SendMilestoneProgress(player: Player)
	local data = getPlayerData(player)
	local currentTier = data.unlockedTier
	local nextTier = currentTier + 1
	local milestone = Milestones[nextTier]

	local credits = EconomyService.GetCredits(player)

	local unlockedPlanetsList = ProgressionService.GetUnlockedPlanets(player)

	local payload = {
		currentTier = currentTier,
		nextTier = nextTier,
		milestoneName = milestone and milestone.name or "Max Tier Reached",
		requiredCredits = milestone and milestone.requirement.credits or 0,
		currentCredits = credits,
		requiredItems = milestone and milestone.requirement.items or {},
		sunkItems = data.sunkItems,
		unlockedPlanets = unlockedPlanetsList,
		planetRequirements = PLANET_REQUIREMENTS,
	}

	Network.Remotes.MilestoneProgressUpdated:FireClient(player, payload)
end

local function checkPlanetaryUnlocks(player: Player)
	local data = getPlayerData(player)
	local credits = EconomyService.GetCredits(player)

	for planetId, req in pairs(PLANET_REQUIREMENTS) do
		if not data.unlockedPlanets[planetId] then
			local meetsRequirements = true

			if credits < req.credits then
				meetsRequirements = false
			end

			if meetsRequirements then
				for itemId, reqCount in pairs(req.items) do
					local sunk = data.sunkItems[itemId] or 0
					if sunk < reqCount then
						meetsRequirements = false
						break
					end
				end
			end

			if meetsRequirements then
				if req.credits > 0 then
					EconomyService.DeductCredits(player, req.credits)
				end
				data.unlockedPlanets[planetId] = true
				print(string.format("[ProgressionService] Player %s unlocked planet %s (%s)!", player.Name, planetId, req.displayName))
				Network.Remotes.PlanetUnlocked:FireClient(player, planetId, req.displayName)
				ProgressionService.SendMilestoneProgress(player)
			end
		end
	end
end

local function checkMilestoneCompletion(player: Player)
	local data = getPlayerData(player)
	local currentTier = data.unlockedTier
	local nextTier = currentTier + 1
	local milestone = Milestones[nextTier]

	checkPlanetaryUnlocks(player)

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
