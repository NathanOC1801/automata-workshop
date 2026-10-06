--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)

local HUDController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local creditsLabel: TextLabel? = nil
local hotbarFrame: Frame? = nil

local previousCredits = 250

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

local function createHeaderButton(parent: Instance, text: string, layoutOrder: number, color: Color3, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = text .. "Button"
	btn.Size = UDim2.new(0, 90, 0, 42)
	btn.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = color
	btn.TextSize = 15
	btn.Font = Enum.Font.SourceSansBold
	btn.LayoutOrder = layoutOrder
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 55, 65)
	stroke.Thickness = 1.5
	stroke.Parent = btn

	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function createHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FactoryUnifiedHUD"
	screenGui.ResetOnSpawn = false

	-- Top Right Header Container (Planets -> Shop -> Credits)
	local topBarContainer = Instance.new("Frame")
	topBarContainer.Name = "TopBarContainer"
	topBarContainer.Size = UDim2.new(0, 380, 0, 42)
	topBarContainer.Position = UDim2.new(1, -20, 0, 16)
	topBarContainer.AnchorPoint = Vector2.new(1, 0)
	topBarContainer.BackgroundTransparency = 1
	topBarContainer.Parent = screenGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = topBarContainer

	-- 1. [Planets] Button
	createHeaderButton(topBarContainer, "[Planets]", 1, Color3.fromRGB(0, 200, 255), function()
		print("[HUDController] Toggle Planets Modal")
	end)

	-- 2. [Shop] Button
	createHeaderButton(topBarContainer, "[Shop]", 2, Color3.fromRGB(255, 205, 50), function()
		print("[HUDController] Toggle Shop Modal")
	end)

	-- 3. [Credits] Pill Card
	local creditsCard = Instance.new("Frame")
	creditsCard.Name = "CreditsCard"
	creditsCard.Size = UDim2.new(0, 160, 0, 42)
	creditsCard.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
	creditsCard.BorderSizePixel = 0
	creditsCard.LayoutOrder = 3
	creditsCard.Parent = topBarContainer

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
	cText.TextSize = 18
	cText.Font = Enum.Font.SourceSansBold
	cText.Parent = creditsCard
	creditsLabel = cText

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
	screenGui.Parent = playerGui
end

function HUDController.UpdateCredits(credits: number)
	if credits > previousCredits then
		spawnFloatingText(credits - previousCredits)
	end
	previousCredits = credits

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

	print("[HUDController] Initialized.")
end

return HUDController
