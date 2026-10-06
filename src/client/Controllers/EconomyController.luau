--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)

local EconomyController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local creditsLabel: TextLabel? = nil

local previousCredits = 250

local function spawnSinkFlyText(amount: number)
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if not placedFolder then
		return
	end

	-- Find all active Sink instances to attach a floating fly-text
	for _, child in ipairs(placedFolder:GetChildren()) do
		if child:IsA("BasePart") and string.split(child.Name, "_")[1] == "Sink" then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "SinkFlyText"
			billboard.Size = UDim2.new(0, 100, 0, 40)
			billboard.StudsOffset = Vector3.new(0, 2.5, 0)
			billboard.AlwaysOnTop = true
			billboard.Adornee = child

			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = string.format("+$%d", amount)
			textLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
			textLabel.TextSize = 22
			textLabel.Font = Enum.Font.SourceSansBold
			textLabel.Parent = billboard

			billboard.Parent = child

			local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local posTween = TweenService:Create(billboard, tweenInfo, { StudsOffset = Vector3.new(0, 5.5, 0) })
			local textTween = TweenService:Create(textLabel, tweenInfo, { TextTransparency = 1 })

			posTween:Play()
			textTween:Play()

			posTween.Completed:Connect(function()
				billboard:Destroy()
			end)
		end
	end
end

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
	if credits > previousCredits then
		spawnSinkFlyText(credits - previousCredits)
	end
	previousCredits = credits

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
