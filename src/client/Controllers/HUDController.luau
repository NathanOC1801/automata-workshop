--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)

local HUDController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local creditsLabel: TextLabel? = nil
local hotbarFrame: Frame? = nil

local planetsModal: Frame? = nil
local planetsContainer: Frame? = nil
local shopModal: Frame? = nil
local fadeOverlay: Frame? = nil
local bannerLabel: TextLabel? = nil

local previousCredits = 250

local unlockedPlanetsSet: { [string]: boolean } = { Earth = true }
local currentSunkItems: { [string]: number } = {}
local currentCredits = 250

local PLANET_CARDS = {
	{
		id = "Earth",
		name = "Earth Quarry",
		desc = "Starter industrial sector. Standard gravity (196.2). Deposits: Iron & Copper.",
		gravity = 196.2,
		creditsReq = 0,
		itemsReq = {},
	},
	{
		id = "Moon",
		name = "Lunar Basin",
		desc = "Low gravity basin (70). Deposits: Titanium & Emerald.",
		gravity = 70,
		creditsReq = 1000,
		itemsReq = { IronPlate = 50 },
	},
	{
		id = "Mars",
		name = "Mars Badlands",
		desc = "Medium gravity (120). Deposits: Cobalt & Gold.",
		gravity = 120,
		creditsReq = 10000,
		itemsReq = { Wire = 50, TitaniumIngot = 25 },
	},
	{
		id = "SolarOutpost",
		name = "Solar Outpost",
		desc = "High gravity solar core (300). Deposits: Diamond & Uranium.",
		gravity = 300,
		creditsReq = 50000,
		itemsReq = { Circuit = 50, GoldBar = 25 },
	},
}

local HOTBAR_SLOTS = {
	{ key = "1", name = "Conveyor" },
	{ key = "2", name = "Drill" },
	{ key = "3", name = "Smelter" },
	{ key = "4", name = "Splitter" },
	{ key = "5", name = "Merger" },
	{ key = "6", name = "Storage" },
	{ key = "7", name = "Sink" },
	{ key = "8", name = "Assembler" },
}

local function spawnFloatingText(amount: number)
	if not screenGui then
		return
	end

	local floatLabel = Instance.new("TextLabel")
	floatLabel.Size = UDim2.new(0, 100, 0, 30)
	floatLabel.Position = UDim2.new(1, -120, 0, 50)
	floatLabel.BackgroundTransparency = 1
	floatLabel.Text = string.format("+$%d", amount)
	floatLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
	floatLabel.TextSize = 20
	floatLabel.Font = Enum.Font.SourceSansBold
	floatLabel.Parent = screenGui

	local tweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(floatLabel, tweenInfo, {
		Position = UDim2.new(1, -120, 0, 15),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		floatLabel:Destroy()
	end)
end

local function showBannerNotification(text: string)
	if not bannerLabel then
		return
	end

	bannerLabel.Text = text
	bannerLabel.Visible = true

	task.delay(4, function()
		if bannerLabel then
			bannerLabel.Visible = false
		end
	end)
end

local function refreshPlanetsModal()
	if not planetsContainer then
		return
	end

	for _, child in ipairs(planetsContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i, pData in ipairs(PLANET_CARDS) do
		local isUnlocked = unlockedPlanetsSet[pData.id] == true

		local pFrame = Instance.new("Frame")
		pFrame.Name = pData.id
		pFrame.Size = UDim2.new(1, 0, 0, 80)
		pFrame.Position = UDim2.new(0, 0, 0, (i - 1) * 88)
		pFrame.BackgroundColor3 = isUnlocked and Color3.fromRGB(35, 42, 50) or Color3.fromRGB(28, 30, 35)
		pFrame.BorderSizePixel = 0
		pFrame.Parent = planetsContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = pFrame

		local stroke = Instance.new("UIStroke")
		stroke.Color = isUnlocked and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(60, 65, 75)
		stroke.Thickness = 1
		stroke.Parent = pFrame

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.65, 0, 0, 22)
		title.Position = UDim2.new(0, 10, 0, 6)
		title.BackgroundTransparency = 1
		title.Text = string.format("%s (Gravity: %d)", pData.name, pData.gravity)
		title.TextColor3 = isUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
		title.TextSize = 15
		title.Font = Enum.Font.SourceSansBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = pFrame

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(0.65, 0, 0, 18)
		desc.Position = UDim2.new(0, 10, 0, 28)
		desc.BackgroundTransparency = 1
		desc.Text = pData.desc
		desc.TextColor3 = Color3.fromRGB(160, 170, 180)
		desc.TextSize = 12
		desc.Font = Enum.Font.SourceSans
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Parent = pFrame

		if isUnlocked then
			local travelBtn = Instance.new("TextButton")
			travelBtn.Size = UDim2.new(0, 110, 0, 36)
			travelBtn.Position = UDim2.new(1, -120, 0.5, -18)
			travelBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
			travelBtn.Text = "Travel"
			travelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			travelBtn.TextSize = 15
			travelBtn.Font = Enum.Font.SourceSansBold
			travelBtn.Parent = pFrame

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 6)
			btnCorner.Parent = travelBtn

			travelBtn.MouseButton1Click:Connect(function()
				if planetsModal then
					planetsModal.Visible = false
				end
				Network.Remotes.TeleportToPlanet:FireServer(pData.id)
			end)
		else
			local reqText = string.format("Req: $%d", pData.creditsReq)
			for item, count in pairs(pData.itemsReq) do
				local delivered = currentSunkItems[item] or 0
				reqText ..= string.format(" | %s: %d/%d", item, delivered, count)
			end

			local reqLbl = Instance.new("TextLabel")
			reqLbl.Size = UDim2.new(0.65, 0, 0, 20)
			reqLbl.Position = UDim2.new(0, 10, 0, 48)
			reqLbl.BackgroundTransparency = 1
			reqLbl.Text = reqText
			reqLbl.TextColor3 = Color3.fromRGB(255, 180, 80)
			reqLbl.TextSize = 12
			reqLbl.Font = Enum.Font.SourceSansBold
			reqLbl.TextXAlignment = Enum.TextXAlignment.Left
			reqLbl.Parent = pFrame

			local lockBadge = Instance.new("TextLabel")
			lockBadge.Size = UDim2.new(0, 110, 0, 36)
			lockBadge.Position = UDim2.new(1, -120, 0.5, -18)
			lockBadge.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
			lockBadge.Text = "LOCKED"
			lockBadge.TextColor3 = Color3.fromRGB(150, 150, 150)
			lockBadge.TextSize = 14
			lockBadge.Font = Enum.Font.SourceSansBold
			lockBadge.Parent = pFrame

			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, 6)
			badgeCorner.Parent = lockBadge
		end
	end
end

local function buildPlanetsModal()
	local modal = Instance.new("Frame")
	modal.Name = "PlanetsModal"
	modal.Size = UDim2.new(0, 560, 0, 420)
	modal.Position = UDim2.new(0.5, -280, 0.5, -210)
	modal.BackgroundColor3 = Color3.fromRGB(22, 25, 30)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(55, 60, 75)
	stroke.Thickness = 2
	stroke.Parent = modal

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -50, 0, 40)
	header.Position = UDim2.new(0, 15, 0, 5)
	header.BackgroundTransparency = 1
	header.Text = "PLANETARY EXPANSION MAP"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 18
	header.Font = Enum.Font.SourceSansBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local container = Instance.new("Frame")
	container.Name = "PlanetsContainer"
	container.Size = UDim2.new(1, -30, 1, -60)
	container.Position = UDim2.new(0, 15, 0, 50)
	container.BackgroundTransparency = 1
	container.Parent = modal
	planetsContainer = container

	planetsModal = modal
end

local function buildShopModal()
	local modal = Instance.new("Frame")
	modal.Name = "ShopModal"
	modal.Size = UDim2.new(0, 520, 0, 360)
	modal.Position = UDim2.new(0.5, -260, 0.5, -180)
	modal.BackgroundColor3 = Color3.fromRGB(22, 25, 30)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(55, 60, 75)
	stroke.Thickness = 2
	stroke.Parent = modal

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -50, 0, 40)
	header.Position = UDim2.new(0, 15, 0, 5)
	header.BackgroundTransparency = 1
	header.Text = "EXOFACTORY SHOP & BOOSTS"
	header.TextColor3 = Color3.fromRGB(255, 215, 0)
	header.TextSize = 18
	header.Font = Enum.Font.SourceSansBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local shopItems = {
		{
			title = "Fast Drill Gamepass",
			desc = "Multiplies all drill extraction speeds by 1.5x permanently.",
			btnText = "Buy Pass",
			action = function()
				MarketplaceService:PromptGamePassPurchase(player, MonetizationConfig.FastDrillPassId)
			end,
		},
		{
			title = "Double Conveyor Speed Pass",
			desc = "Doubles conveyor belt item lerp movement speed.",
			btnText = "Buy Pass",
			action = function()
				MarketplaceService:PromptGamePassPurchase(player, MonetizationConfig.DoubleConveyorSpeedPassId)
			end,
		},
		{
			title = "15-Min Overclock Boost",
			desc = "2x crafting speed boost for all Smelters & Assemblers.",
			btnText = "Buy Boost",
			action = function()
				MarketplaceService:PromptProductPurchase(player, MonetizationConfig.Overclock15MinProductId)
			end,
		},
	}

	for i, sData in ipairs(shopItems) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -30, 0, 80)
		row.Position = UDim2.new(0, 15, 0, 50 + (i - 1) * 90)
		row.BackgroundColor3 = Color3.fromRGB(32, 36, 44)
		row.BorderSizePixel = 0
		row.Parent = modal

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 6)
		rCorner.Parent = row

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.65, 0, 0, 24)
		title.Position = UDim2.new(0, 10, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = sData.title
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextSize = 15
		title.Font = Enum.Font.SourceSansBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(0.65, 0, 0, 36)
		desc.Position = UDim2.new(0, 10, 0, 34)
		desc.BackgroundTransparency = 1
		desc.Text = sData.desc
		desc.TextColor3 = Color3.fromRGB(170, 180, 190)
		desc.TextSize = 12
		desc.Font = Enum.Font.SourceSans
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0, 120, 0, 40)
		buyBtn.Position = UDim2.new(1, -130, 0.5, -20)
		buyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
		buyBtn.Text = sData.btnText
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.TextSize = 15
		buyBtn.Font = Enum.Font.SourceSansBold
		buyBtn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(sData.action)
	end

	shopModal = modal
end

local function buildFadeOverlay()
	local fade = Instance.new("Frame")
	fade.Name = "CameraFadeOverlay"
	fade.Size = UDim2.fromScale(1, 1)
	fade.Position = UDim2.fromScale(0, 0)
	fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.ZIndex = 10
	fade.Parent = screenGui
	fadeOverlay = fade
end

local function createHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FactoryUnifiedHUD"
	screenGui.ResetOnSpawn = false

	-- Top Bar Action Card (Planets & Shop)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBarCard"
	topBar.Size = UDim2.new(0, 220, 0, 42)
	topBar.Position = UDim2.new(1, -420, 0, 10)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = topBar

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(50, 55, 65)
	tStroke.Thickness = 1.5
	tStroke.Parent = topBar

	local planetsBtn = Instance.new("TextButton")
	planetsBtn.Name = "PlanetsBtn"
	planetsBtn.Size = UDim2.new(0, 100, 0, 32)
	planetsBtn.Position = UDim2.new(0, 6, 0, 5)
	planetsBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
	planetsBtn.Text = "Planets"
	planetsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	planetsBtn.TextSize = 14
	planetsBtn.Font = Enum.Font.SourceSansBold
	planetsBtn.Parent = topBar

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 6)
	pCorner.Parent = planetsBtn

	planetsBtn.MouseButton1Click:Connect(function()
		refreshPlanetsModal()
		if planetsModal then
			planetsModal.Visible = not planetsModal.Visible
		end
		if shopModal then
			shopModal.Visible = false
		end
	end)

	local shopBtn = Instance.new("TextButton")
	shopBtn.Name = "ShopBtn"
	shopBtn.Size = UDim2.new(0, 100, 0, 32)
	shopBtn.Position = UDim2.new(0, 114, 0, 5)
	shopBtn.BackgroundColor3 = Color3.fromRGB(210, 150, 0)
	shopBtn.Text = "Shop"
	shopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopBtn.TextSize = 14
	shopBtn.Font = Enum.Font.SourceSansBold
	shopBtn.Parent = topBar

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 6)
	sCorner.Parent = shopBtn

	shopBtn.MouseButton1Click:Connect(function()
		if shopModal then
			shopModal.Visible = not shopModal.Visible
		end
		if planetsModal then
			planetsModal.Visible = false
		end
	end)

	-- Top Right Credits Balance Card
	local creditsCard = Instance.new("Frame")
	creditsCard.Name = "CreditsCard"
	creditsCard.Size = UDim2.new(0, 180, 0, 42)
	creditsCard.Position = UDim2.new(1, -190, 0, 10)
	creditsCard.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
	creditsCard.BorderSizePixel = 0
	creditsCard.Parent = screenGui

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = creditsCard

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = Color3.fromRGB(50, 55, 65)
	cStroke.Thickness = 1.5
	cStroke.Parent = creditsCard

	local cText = Instance.new("TextLabel")
	cText.Name = "CreditsText"
	cText.Size = UDim2.fromScale(1, 1)
	cText.BackgroundTransparency = 1
	cText.Text = "Credits: $250"
	cText.TextColor3 = Color3.fromRGB(85, 255, 127)
	cText.TextSize = 20
	cText.Font = Enum.Font.SourceSansBold
	cText.Parent = creditsCard
	creditsLabel = cText

	-- Unlocked Banner Label
	local banner = Instance.new("TextLabel")
	banner.Name = "BannerLabel"
	banner.Size = UDim2.new(0, 360, 0, 36)
	banner.Position = UDim2.new(0.5, -180, 0, 60)
	banner.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
	banner.Text = "PLANET UNLOCKED!"
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextSize = 16
	banner.Font = Enum.Font.SourceSansBold
	banner.Visible = false
	banner.Parent = screenGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = banner
	bannerLabel = banner

	-- Bottom Contextual Hotbar
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.Size = UDim2.new(0, 680, 0, 50)
	hotbar.Position = UDim2.new(0.5, -340, 1, -65)
	hotbar.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
	hotbar.BorderSizePixel = 0
	hotbar.Parent = screenGui

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 8)
	hCorner.Parent = hotbar

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(50, 55, 65)
	hStroke.Thickness = 1.5
	hStroke.Parent = hotbar

	for i, slot in ipairs(HOTBAR_SLOTS) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Size = UDim2.new(0, 75, 0, 40)
		slotFrame.Position = UDim2.new(0, 10 + (i - 1) * 82, 0, 5)
		slotFrame.BackgroundColor3 = Color3.fromRGB(38, 42, 50)
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = hotbar

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 6)
		sCorner.Parent = slotFrame

		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(1, 0, 0, 18)
		keyLbl.Position = UDim2.new(0, 0, 0, 2)
		keyLbl.BackgroundTransparency = 1
		keyLbl.Text = string.format("[%s]", slot.key)
		keyLbl.TextColor3 = Color3.fromRGB(255, 205, 50)
		keyLbl.TextSize = 13
		keyLbl.Font = Enum.Font.SourceSansBold
		keyLbl.Parent = slotFrame

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, 0, 0, 18)
		nameLbl.Position = UDim2.new(0, 0, 0, 20)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = slot.name
		nameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLbl.TextSize = 11
		nameLbl.Font = Enum.Font.SourceSans
		nameLbl.Parent = slotFrame
	end

	hotbarFrame = hotbar

	buildPlanetsModal()
	buildShopModal()
	buildFadeOverlay()

	screenGui.Parent = playerGui
end

function HUDController.UpdateCredits(credits: number)
	if credits > previousCredits then
		spawnFloatingText(credits - previousCredits)
	end
	previousCredits = credits
	currentCredits = credits

	if creditsLabel then
		creditsLabel.Text = string.format("Credits: $%d", credits)
	end
end

function HUDController.Init()
	createHUD()

	Network.Remotes.SyncCredits.OnClientEvent:Connect(function(credits)
		if typeof(credits) == "number" then
			HUDController.UpdateCredits(credits)
		end
	end)

	Network.Remotes.OpenPlanetaryMap.OnClientEvent:Connect(function()
		refreshPlanetsModal()
		if planetsModal then
			planetsModal.Visible = true
		end
	end)

	Network.Remotes.PlanetUnlocked.OnClientEvent:Connect(function(planetId, displayName)
		if typeof(planetId) == "string" then
			unlockedPlanetsSet[planetId] = true
			local text = string.format("PLANET UNLOCKED: %s!", displayName or planetId)
			showBannerNotification(text)
			refreshPlanetsModal()
		end
	end)

	Network.Remotes.TeleportToPlanet.OnClientEvent:Connect(function(planetId, targetGravity)
		if fadeOverlay then
			local fadeOut = TweenService:Create(fadeOverlay, TweenInfo.new(0.25), { BackgroundTransparency = 0 })
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if typeof(targetGravity) == "number" then
					Workspace.Gravity = targetGravity
				end
				task.wait(0.1)
				local fadeIn = TweenService:Create(fadeOverlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
				fadeIn:Play()
			end)
		end
	end)

	Network.Remotes.MilestoneProgressUpdated.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			if typeof(payload.unlockedPlanets) == "table" then
				unlockedPlanetsSet = {}
				for _, pId in ipairs(payload.unlockedPlanets) do
					unlockedPlanetsSet[pId] = true
				end
			end
			if typeof(payload.sunkItems) == "table" then
				currentSunkItems = payload.sunkItems
			end
			refreshPlanetsModal()
		end
	end)

	print("[HUDController] Initialized.")
end

return HUDController
