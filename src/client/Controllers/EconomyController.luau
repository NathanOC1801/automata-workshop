--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)

local EconomyController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local creditsLabel: TextLabel? = nil

local function createHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EconomyHUD"
	screenGui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "CreditsFrame"
	frame.Size = UDim2.new(0, 200, 0, 50)
	frame.Position = UDim2.new(1, -210, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "CreditsLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Credits: $250"
	label.TextColor3 = Color3.fromRGB(85, 255, 127)
	label.TextSize = 22
	label.Font = Enum.Font.SourceSansBold
	label.Parent = frame

	creditsLabel = label
	screenGui.Parent = playerGui
end

function EconomyController.UpdateCreditsDisplay(credits: number)
	if creditsLabel then
		creditsLabel.Text = string.format("Credits: $%d", credits)
	end
end

function EconomyController.Init()
	createHUD()

	Network.Remotes.SyncCredits.OnClientEvent:Connect(function(credits)
		if typeof(credits) == "number" then
			EconomyController.UpdateCreditsDisplay(credits)
		end
	end)

	print("[EconomyController] Initialized.")
end

return EconomyController
