--!strict

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GridMath = require(ReplicatedStorage.Shared.Utility.GridMath)
local Network = require(ReplicatedStorage.Shared.Network)

export type ConveyorItemSyncPayload = {
	coord: Vector3int16,
	slotIndex: number,
	itemId: string,
	orientation: number,
}

type ItemVisualData = {
	part: Part,
	targetPosition: Vector3,
	inUse: boolean,
}

local ItemVisualController = {}

local ITEM_STYLES: { [string]: { color: Color3, material: Enum.Material } } = {
	RawIron = { color = Color3.fromRGB(115, 115, 115), material = Enum.Material.Slate },
	RawCopper = { color = Color3.fromRGB(184, 115, 51), material = Enum.Material.Slate },
	IronIngot = { color = Color3.fromRGB(200, 200, 205), material = Enum.Material.Metal },
	CopperIngot = { color = Color3.fromRGB(220, 130, 60), material = Enum.Material.Metal },
	IronPlate = { color = Color3.fromRGB(160, 165, 170), material = Enum.Material.CorrodedMetal },
	Wire = { color = Color3.fromRGB(255, 205, 50), material = Enum.Material.SmoothPlastic },
	Circuit = { color = Color3.fromRGB(0, 200, 100), material = Enum.Material.SmoothPlastic },
	ReinforcedPlate = { color = Color3.fromRGB(90, 100, 110), material = Enum.Material.DiamondPlate },
}

local DEFAULT_STYLE = { color = Color3.fromRGB(255, 255, 255), material = Enum.Material.SmoothPlastic }

-- Item Y offset = conveyorTopY (1.0) + itemHalfHeight (0.4) + clearance (0.15) = 1.55 studs
local LOCAL_OFFSETS = {
	[1] = Vector3.new(0, 1.55, 1.5),
	[2] = Vector3.new(0, 1.55, 0.5),
	[3] = Vector3.new(0, 1.55, -0.5),
	[4] = Vector3.new(0, 1.55, -1.5),
}

-- 0° -> -Z, 90° -> -X, 180° -> +Z, 270° -> +X (Matching Roblox CFrame.Angles(0, rad(deg), 0))
local function getDirectionOffset(orientation: number): Vector3int16
	if orientation == 0 then
		return Vector3int16.new(0, 0, -1)
	elseif orientation == 90 then
		return Vector3int16.new(-1, 0, 0)
	elseif orientation == 180 then
		return Vector3int16.new(0, 0, 1)
	elseif orientation == 270 then
		return Vector3int16.new(1, 0, 0)
	else
		return Vector3int16.new(0, 0, -1)
	end
end

local partPool: { ItemVisualData } = {}
local activeVisuals: { [string]: ItemVisualData } = {}

local function getOrCreateItemFolder(): Folder
	local folder = Workspace:FindFirstChild("ItemVisuals")
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "ItemVisuals"
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

local itemFolder = getOrCreateItemFolder()

local function calculateSlotWorldPosition(coord: Vector3int16, slotIndex: number, orientation: number): Vector3
	local tileCenter = GridMath.gridToWorld(coord)
	local conveyorCFrame = CFrame.new(tileCenter) * CFrame.Angles(0, math.rad(orientation), 0)
	local offset = LOCAL_OFFSETS[slotIndex] or Vector3.new(0, 1.55, 0)
	return (conveyorCFrame * CFrame.new(offset)).Position
end

local function calculatePreviousSlotWorldPosition(coord: Vector3int16, slotIndex: number, orientation: number): Vector3
	if slotIndex > 1 then
		return calculateSlotWorldPosition(coord, slotIndex - 1, orientation)
	else
		-- Previous slot was Slot 4 of the upstream conveyor
		local dirOffset = getDirectionOffset(orientation)
		local prevCoord = Vector3int16.new(coord.X - dirOffset.X, coord.Y - dirOffset.Y, coord.Z - dirOffset.Z)
		return calculateSlotWorldPosition(prevCoord, 4, orientation)
	end
end

local function triggerSmelterPulse(coord: Vector3int16)
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if not placedFolder then
		return
	end
	local name = string.format("Smelter_%d_%d_%d", coord.X, coord.Y, coord.Z)
	local part = placedFolder:FindFirstChild(name)
	if part then
		local light = part:FindFirstChild("FurnaceLight")
		if light and light:IsA("PointLight") then
			local pulseUp = TweenService:Create(light, TweenInfo.new(0.15), { Brightness = 5 })
			local pulseDown = TweenService:Create(light, TweenInfo.new(0.15), { Brightness = 0 })
			pulseUp:Play()
			pulseUp.Completed:Connect(function()
				pulseDown:Play()
			end)
		end
	end
end

local function triggerDrillSquash(coord: Vector3int16)
	local placedFolder = Workspace:FindFirstChild("PlacedObjects")
	if not placedFolder then
		return
	end
	local name = string.format("Drill_%d_%d_%d", coord.X, coord.Y, coord.Z)
	local part = placedFolder:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		local originalSize = Vector3.new(4, 4, 4)
		local squashSize = Vector3.new(4.2, 3.6, 4.2)

		local squashTween = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = squashSize })
		local restoreTween = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = originalSize })

		squashTween:Play()
		squashTween.Completed:Connect(function()
			restoreTween:Play()
		end)
	end
end

local function getPartFromPool(): ItemVisualData
	for _, entry in ipairs(partPool) do
		if not entry.inUse then
			entry.inUse = true
			entry.part.Transparency = 0
			entry.part.Size = Vector3.new(0.8, 0.8, 0.8)
			return entry
		end
	end

	local part = Instance.new("Part")
	part.Name = "ItemVisual"
	part.Size = Vector3.new(0.8, 0.8, 0.8)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = itemFolder

	local newEntry: ItemVisualData = {
		part = part,
		targetPosition = Vector3.zero,
		inUse = true,
	}
	table.insert(partPool, newEntry)
	return newEntry
end

local function fadeAndReleasePart(entry: ItemVisualData)
	entry.inUse = false
	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(entry.part, tweenInfo, {
		Size = Vector3.new(0.01, 0.01, 0.01),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		entry.part.CFrame = CFrame.new(0, -1000, 0)
	end)
end

function ItemVisualController.OnSyncConveyorItems(payload: { ConveyorItemSyncPayload })
	local seenKeys: { [string]: boolean } = {}

	for _, item in ipairs(payload) do
		local key = string.format("%d,%d,%d_%d", item.coord.X, item.coord.Y, item.coord.Z, item.slotIndex)
		seenKeys[key] = true

		local targetPos = calculateSlotWorldPosition(item.coord, item.slotIndex, item.orientation)
		local visual = activeVisuals[key]

		if not visual then
			visual = getPartFromPool()
			local startPos = calculatePreviousSlotWorldPosition(item.coord, item.slotIndex, item.orientation)
			visual.part.CFrame = CFrame.new(startPos)
			visual.targetPosition = targetPos

			local style = ITEM_STYLES[item.itemId] or DEFAULT_STYLE
			visual.part.Color = style.color
			visual.part.Material = style.material

			activeVisuals[key] = visual

			-- Trigger machine flourishes
			if item.slotIndex == 1 then
				triggerDrillSquash(item.coord)
				triggerSmelterPulse(item.coord)
			end
		else
			visual.targetPosition = targetPos
			local style = ITEM_STYLES[item.itemId] or DEFAULT_STYLE
			visual.part.Color = style.color
			visual.part.Material = style.material
		end
	end

	-- Clean up visuals for slots that are no longer occupied with a smooth shrink/fade
	for key, visual in pairs(activeVisuals) do
		if not seenKeys[key] then
			fadeAndReleasePart(visual)
			activeVisuals[key] = nil
		end
	end
end

function ItemVisualController.OnRenderStepped(dt: number)
	-- Smooth frame-by-frame CFrame lerp interpolation (dt * 14) with subtle mechanical settling bob
	local lerpFactor = math.clamp(dt * 14, 0, 1)
	for _, visual in pairs(activeVisuals) do
		if visual.inUse then
			local currentPos = visual.part.Position
			local bobOffsetY = math.sin(os.clock() * 16 + (currentPos.X + currentPos.Z)) * 0.02
			local lerpedPos = currentPos:Lerp(visual.targetPosition, lerpFactor)
			visual.part.CFrame = CFrame.new(lerpedPos + Vector3.new(0, bobOffsetY, 0))
		end
	end
end

function ItemVisualController.Init()
	Network.Remotes.SyncConveyorItems.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ItemVisualController.OnSyncConveyorItems(payload)
		end
	end)

	RunService.RenderStepped:Connect(ItemVisualController.OnRenderStepped)
	print("[ItemVisualController] Initialized.")
end

return ItemVisualController
