--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)

local ProgressionController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local cardFrame: Frame? = nil
local titleLabel: TextLabel? = nil
local itemsContainer: Frame? = nil
local creditsContainer: Frame? = nil
local creditsLabel: TextLabel? = nil
local creditsFill: Frame? = nil
local bannerLabel: TextLabel? = nil

type ProgressPayload = {
	currentTier: number,
	nextTier: number,
	milestoneName: string,
	requiredCredits: number,
	currentCredits: number,
	requiredItems: { [string]: number },
	sunkItems: { [string]: number },
}

local function createMilestoneHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MilestoneHUD"
	screenGui.ResetOnSpawn = false

	local card = Instance.new("Frame")
	card.Name = "MilestoneCard"
	card.Size = UDim2.new(0, 300, 0, 160)
	card.Position = UDim2.new(1, -310, 0, 70)
	card.BackgroundColor3 = Color3.fromRGB(30, 32, 36)
	card.BorderSizePixel = 0
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 65, 75)
	stroke.Thickness = 1.5
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Milestone: Loading..."
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 15
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	titleLabel = title

	local itemsFrame = Instance.new("Frame")
	itemsFrame.Name = "ItemsContainer"
	itemsFrame.Size = UDim2.new(1, -20, 0, 50)
	itemsFrame.Position = UDim2.new(0, 10, 0, 42)
	itemsFrame.BackgroundTransparency = 1
	itemsFrame.Parent = card
	itemsContainer = itemsFrame

	local credsFrame = Instance.new("Frame")
	credsFrame.Name = "CreditsContainer"
	credsFrame.Size = UDim2.new(1, -20, 0, 40)
	credsFrame.Position = UDim2.new(0, 10, 0, 95)
	credsFrame.BackgroundTransparency = 1
	credsFrame.Parent = card
	creditsContainer = credsFrame

	local cLabel = Instance.new("TextLabel")
	cLabel.Name = "CreditsText"
	cLabel.Size = UDim2.new(1, 0, 0, 18)
	cLabel.BackgroundTransparency = 1
	cLabel.Text = "Credits: $0 / $0"
	cLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	cLabel.TextSize = 13
	cLabel.Font = Enum.Font.SourceSans
	cLabel.TextXAlignment = Enum.TextXAlignment.Left
	cLabel.Parent = credsFrame
	creditsLabel = cLabel

	local cBarBg = Instance.new("Frame")
	cBarBg.Size = UDim2.new(1, 0, 0, 10)
	cBarBg.Position = UDim2.new(0, 0, 0, 20)
	cBarBg.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
	cBarBg.BorderSizePixel = 0
	cBarBg.Parent = credsFrame

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 3)
	cCorner.Parent = cBarBg

	local cFill = Instance.new("Frame")
	cFill.Size = UDim2.new(0, 0, 1, 0)
	cFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
	cFill.BorderSizePixel = 0
	cFill.Parent = cBarBg

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 3)
	fCorner.Parent = cFill
	creditsFill = cFill

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.Size = UDim2.new(1, -20, 0, 25)
	banner.Position = UDim2.new(0, 10, 1, -30)
	banner.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
	banner.Text = "TIER UNLOCKED!"
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextSize = 14
	banner.Font = Enum.Font.SourceSansBold
	banner.Visible = false
	banner.Parent = card

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 4)
	bCorner.Parent = banner
	bannerLabel = banner

	cardFrame = card
	screenGui.Parent = playerGui
end

local function tweenWidth(fillFrame: Frame, scale: number)
	local clamped = math.clamp(scale, 0, 1)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(fillFrame, tweenInfo, { Size = UDim2.new(clamped, 0, 1, 0) }):Play()
end

function ProgressionController.UpdateHUD(payload: ProgressPayload)
	if not titleLabel or not itemsContainer or not creditsLabel or not creditsFill then
		return
	end

	titleLabel.Text = string.format("Milestone: Tier %d - %s", payload.nextTier, payload.milestoneName)

	-- Clear item bars
	for _, child in ipairs(itemsContainer:GetChildren()) do
		child:Destroy()
	end

	local itemIndex = 0
	for itemId, reqCount in pairs(payload.requiredItems) do
		local sunk = payload.sunkItems[itemId] or 0

		local itemRow = Instance.new("Frame")
		itemRow.Size = UDim2.new(1, 0, 0, 40)
		itemRow.Position = UDim2.new(0, 0, 0, itemIndex * 42)
		itemRow.BackgroundTransparency = 1
		itemRow.Parent = itemsContainer

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 18)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("%s Delivered: %d / %d", itemId, sunk, reqCount)
		lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		lbl.TextSize = 13
		lbl.Font = Enum.Font.SourceSans
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = itemRow

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, 0, 0, 10)
		barBg.Position = UDim2.new(0, 0, 0, 20)
		barBg.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
		barBg.BorderSizePixel = 0
		barBg.Parent = itemRow

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 3)
		bCorner.Parent = barBg

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
		fill.BorderSizePixel = 0
		fill.Parent = barBg

		local flCorner = Instance.new("UICorner")
		flCorner.CornerRadius = UDim.new(0, 3)
		flCorner.Parent = fill

		tweenWidth(fill, reqCount > 0 and (sunk / reqCount) or 1)
		itemIndex += 1
	end

	-- Update credits bar
	local reqCreds = payload.requiredCredits
	local curCreds = payload.currentCredits
	creditsLabel.Text = string.format("Credits: $%d / $%d", curCreds, reqCreds)
	tweenWidth(creditsFill, reqCreds > 0 and (curCreds / reqCreds) or 1)
end

function ProgressionController.ShowUnlockBanner(tier: number, milestoneName: string)
	if bannerLabel then
		bannerLabel.Text = string.format("TIER %d UNLOCKED: %s!", tier, milestoneName)
		bannerLabel.Visible = true
		task.delay(4, function()
			if bannerLabel then
				bannerLabel.Visible = false
			end
		end)
	end
end

function ProgressionController.Init()
	createMilestoneHUD()

	Network.Remotes.MilestoneProgressUpdated.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ProgressionController.UpdateHUD(payload)
		end
	end)

	Network.Remotes.MilestoneUnlocked.OnClientEvent:Connect(function(tier, milestoneName)
		if typeof(tier) == "number" and typeof(milestoneName) == "string" then
			ProgressionController.ShowUnlockBanner(tier, milestoneName)
		end
	end)

	print("[ProgressionController] Initialized.")
end

return ProgressionController
