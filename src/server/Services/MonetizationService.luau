--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)

type PlayerMonetizationState = {
	fastDrillOwned: boolean,
	doubleConveyorOwned: boolean,
	overclockExpiresAt: number,
}

local MonetizationService = {}

local playerStates: { [number]: PlayerMonetizationState } = {}

-- Debug testing flag. When true, default test pass ownership if pcall checks fail in studio.
local DEBUG_FORCE_PASS_OWNERSHIP = false

local function getPlayerState(player: Player): PlayerMonetizationState
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			fastDrillOwned = DEBUG_FORCE_PASS_OWNERSHIP,
			doubleConveyorOwned = DEBUG_FORCE_PASS_OWNERSHIP,
			overclockExpiresAt = 0,
		}
	end
	return playerStates[userId]
end

function MonetizationService.CheckPlayerGamepasses(player: Player)
	local state = getPlayerState(player)
	local userId = player.UserId

	-- Fast Drill Pass
	task.spawn(function()
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, MonetizationConfig.FastDrillPassId)
		end)
		if success and owns then
			state.fastDrillOwned = true
		end
	end)

	-- Double Conveyor Speed Pass
	task.spawn(function()
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, MonetizationConfig.DoubleConveyorSpeedPassId)
		end)
		if success and owns then
			state.doubleConveyorOwned = true
		end
	end)
end

function MonetizationService.SetTestPassOwned(player: Player, passType: "FastDrill" | "DoubleConveyor", owned: boolean)
	local state = getPlayerState(player)
	if passType == "FastDrill" then
		state.fastDrillOwned = owned
	elseif passType == "DoubleConveyor" then
		state.doubleConveyorOwned = owned
	end
end

function MonetizationService.GetPlayerMiningMultiplier(player: Player?): number
	if not player then
		return 1.0
	end
	local state = getPlayerState(player)
	return state.fastDrillOwned and 1.5 or 1.0
end

function MonetizationService.GetPlayerConveyorSpeedMultiplier(player: Player?): number
	if not player then
		return 1.0
	end
	local state = getPlayerState(player)
	return state.doubleConveyorOwned and 2.0 or 1.0
end

function MonetizationService.GetPlayerMachineSpeedMultiplier(player: Player?): number
	if not player then
		return 1.0
	end
	local state = getPlayerState(player)
	if os.time() < state.overclockExpiresAt then
		return 2.0
	end
	return 1.0
end

function MonetizationService.GetOverclockExpiresAt(player: Player): number
	return getPlayerState(player).overclockExpiresAt
end

function MonetizationService.SetOverclockExpiresAt(player: Player, expiresAt: number)
	getPlayerState(player).overclockExpiresAt = expiresAt
end

function MonetizationService.ApplyOverclockBoost(player: Player, durationSeconds: number)
	local state = getPlayerState(player)
	local now = os.time()
	local currentExpires = math.max(state.overclockExpiresAt, now)
	state.overclockExpiresAt = currentExpires + durationSeconds
	print(string.format("[MonetizationService] Applied 15-min Overclock boost for %s. Expires in %d seconds.", player.Name, state.overclockExpiresAt - now))
end

-- MarketplaceService ProcessReceipt handler for Developer Products
local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(userId)

	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if productId == MonetizationConfig.Overclock15MinProductId then
		MonetizationService.ApplyOverclockBoost(player, 15 * 60)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	-- Handle GamePass Purchase Finished
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if wasPurchased then
			local state = getPlayerState(player)
			if gamePassId == MonetizationConfig.FastDrillPassId then
				state.fastDrillOwned = true
				print(string.format("[MonetizationService] Player %s purchased FastDrillPass!", player.Name))
			elseif gamePassId == MonetizationConfig.DoubleConveyorSpeedPassId then
				state.doubleConveyorOwned = true
				print(string.format("[MonetizationService] Player %s purchased DoubleConveyorSpeedPass!", player.Name))
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		MonetizationService.CheckPlayerGamepasses(player)
	end)
end

return MonetizationService
