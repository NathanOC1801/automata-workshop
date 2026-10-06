--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Network = require(ReplicatedStorage.Shared.Network)
local PlacementController = require(script.Parent.PlacementController)

local InspectionController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local frame: Frame? = nil
local titleLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local inputBufferLabel: TextLabel? = nil
local progressBarFill: Frame? = nil
local recipeFrame: Frame? = nil

local currentInspectedCoord: Vector3int16? = nil
local pollAccumulator = 0
local POLL_INTERVAL = 0.2 -- Refresh inspected state every 0.2s

local function createInspectionUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InspectionHUD"
	screenGui.ResetOnSpawn = false

	local main = Instance.new("Frame")
	main.Name = "MainFrame"
	main.Size = UDim2.new(0, 320, 0, 260)
	main.Position = UDim2.new(0, 20, 0.5, -130)
	main.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
	main.BorderSizePixel = 0
	main.Visible = false
	main.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = main

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 35)
	title.Position = UDim2.new(0, 15, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Machine Inspection"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = main
	titleLabel = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 25, 0, 25)
	closeBtn.Position = UDim2.new(1, -35, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.TextSize = 14
	closeBtn.Parent = main

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		main.Visible = false
		currentInspectedCoord = nil
	end)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -30, 0, 25)
	status.Position = UDim2.new(0, 15, 0, 50)
	status.BackgroundTransparency = 1
	status.Text = "Status: Idle"
	status.TextColor3 = Color3.fromRGB(200, 200, 200)
	status.TextSize = 16
	status.Font = Enum.Font.SourceSans
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = main
	statusLabel = status

	local inputBuf = Instance.new("TextLabel")
	inputBuf.Name = "InputBuffer"
	inputBuf.Size = UDim2.new(1, -30, 0, 40)
	inputBuf.Position = UDim2.new(0, 15, 0, 80)
	inputBuf.BackgroundTransparency = 1
	inputBuf.Text = "Inputs: None"
	inputBuf.TextColor3 = Color3.fromRGB(180, 220, 255)
	inputBuf.TextSize = 15
	inputBuf.Font = Enum.Font.SourceSans
	inputBuf.TextXAlignment = Enum.TextXAlignment.Left
	inputBuf.TextWrapped = true
	inputBuf.Parent = main
	inputBufferLabel = inputBuf

	-- Progress Bar Background
	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBarBg"
	barBg.Size = UDim2.new(1, -30, 0, 20)
	barBg.Position = UDim2.new(0, 15, 0, 130)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	barBg.BorderSizePixel = 0
	barBg.Parent = main

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	fill.BorderSizePixel = 0
	fill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill
	progressBarFill = fill

	-- Recipe Selector Container
	local recFrame = Instance.new("Frame")
	recFrame.Name = "RecipeContainer"
	recFrame.Size = UDim2.new(1, -30, 0, 80)
	recFrame.Position = UDim2.new(0, 15, 0, 160)
	recFrame.BackgroundTransparency = 1
	recFrame.Parent = main
	recipeFrame = recFrame

	frame = main
	screenGui.Parent = playerGui
end

local function populateRecipeButtons(coord: Vector3int16)
	if not recipeFrame then
		return
	end
	for _, child in ipairs(recipeFrame:GetChildren()) do
		child:Destroy()
	end

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "Select Recipe:"
	title.TextColor3 = Color3.fromRGB(220, 220, 220)
	title.TextSize = 14
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = recipeFrame

	local yOffset = 25
	for recipeId, recipe in pairs(Recipes) do
		if recipe.machineType == "Assembler" then
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 22)
			btn.Position = UDim2.new(0, 0, 0, yOffset)
			btn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
			btn.Text = recipe.displayName
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextSize = 13
			btn.Font = Enum.Font.SourceSans
			btn.Parent = recipeFrame

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 4)
			btnCorner.Parent = btn

			btn.MouseButton1Click:Connect(function()
				Network.Remotes.SelectRecipe:FireServer(coord, recipeId)
			end)

			yOffset += 26
		end
	end
end

function InspectionController.InspectMachineAt(coord: Vector3int16)
	local state = Network.Remotes.GetMachineState:InvokeServer(coord)
	if state and frame and titleLabel and statusLabel and inputBufferLabel and progressBarFill then
		currentInspectedCoord = coord
		titleLabel.Text = string.format("%s Inspection", state.category)
		statusLabel.Text = string.format("Status: %s (Recipe: %s)", state.status, state.recipe)

		local inputStr = "Inputs: "
		if state.inputBuffer then
			local itemsList = {}
			for itemId, count in pairs(state.inputBuffer) do
				if count > 0 then
					table.insert(itemsList, string.format("%s: %d", itemId, count))
				end
			end
			if #itemsList > 0 then
				inputStr = inputStr .. table.concat(itemsList, ", ")
			else
				inputStr = inputStr .. "Empty"
			end
		end
		inputBufferLabel.Text = inputStr
		progressBarFill.Size = UDim2.new(state.progress or 0, 0, 1, 0)

		if state.category == "Assembler" and #recipeFrame:GetChildren() == 0 then
			populateRecipeButtons(coord)
		elseif state.category ~= "Assembler" and recipeFrame then
			for _, child in ipairs(recipeFrame:GetChildren()) do
				child:Destroy()
			end
		end

		frame.Visible = true
	end
end

function InspectionController.OnInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or PlacementController.IsPlacementActive() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local ray = mouse.UnitRay
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local excludeList: { Instance } = {}
		if player.Character then
			table.insert(excludeList, player.Character)
		end
		raycastParams.FilterDescendantsInstances = excludeList

		local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		if result and result.Instance and result.Instance:IsDescendantOf(Workspace:FindFirstChild("PlacedObjects")) then
			local hitPart = result.Instance
			while hitPart and hitPart.Parent ~= Workspace:FindFirstChild("PlacedObjects") do
				hitPart = hitPart.Parent :: BasePart
			end
			if hitPart then
				local nameParts = string.split(hitPart.Name, "_")
				if #nameParts >= 4 then
					local x = tonumber(nameParts[2])
					local y = tonumber(nameParts[3])
					local z = tonumber(nameParts[4])
					if x and y and z then
						InspectionController.InspectMachineAt(Vector3int16.new(x, y, z))
					end
				end
			end
		end
	end
end

function InspectionController.OnRenderStepped(dt: number)
	if frame and frame.Visible and currentInspectedCoord then
		pollAccumulator += dt
		if pollAccumulator >= POLL_INTERVAL then
			pollAccumulator = 0
			InspectionController.InspectMachineAt(currentInspectedCoord)
		end
	end
end

function InspectionController.Init()
	createInspectionUI()
	UserInputService.InputBegan:Connect(InspectionController.OnInputBegan)
	RunService.RenderStepped:Connect(InspectionController.OnRenderStepped)
	print("[InspectionController] Initialized.")
end

return InspectionController
