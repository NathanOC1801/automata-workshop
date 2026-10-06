--!strict

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
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
}

local DEFAULT_STYLE = { color = Color3.fromRGB(255, 255, 255), material = Enum.Material.SmoothPlastic }

local LOCAL_OFFSETS = {
	[1] = Vector3.new(0, 0.75, 1.5),
	[2] = Vector3.new(0, 0.75, 0.5),
	[3] = Vector3.new(0, 0.75, -0.5),
	[4] = Vector3.new(0, 0.75, -1.5),
}

local function getDirectionOffset(orientation: number): Vector3int16
	if orientation == 0 then
		return Vector3int16.new(0, 0, -1)
	elseif orientation == 90 then
		return Vector3int16.new(1, 0, 0)
	elseif orientation == 180 then
		return Vector3int16.new(0, 0, 1)
	elseif orientation == 270 then
		return Vector3int16.new(-1, 0, 0)
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
	local offset = LOCAL_OFFSETS[slotIndex] or Vector3.new(0, 0.75, 0)
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

local function getPartFromPool(): ItemVisualData
	for _, entry in ipairs(partPool) do
		if not entry.inUse then
			entry.inUse = true
			entry.part.Transparency = 0
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

local function releasePartToPool(entry: ItemVisualData)
	entry.inUse = false
	entry.part.Transparency = 1
	entry.part.CFrame = CFrame.new(0, -1000, 0)
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
			-- Start newly occupied slot's visual part at the previous slot position so it lerps smoothly!
			local startPos = calculatePreviousSlotWorldPosition(item.coord, item.slotIndex, item.orientation)
			visual.part.CFrame = CFrame.new(startPos)
			visual.targetPosition = targetPos

			local style = ITEM_STYLES[item.itemId] or DEFAULT_STYLE
			visual.part.Color = style.color
			visual.part.Material = style.material

			activeVisuals[key] = visual
		else
			visual.targetPosition = targetPos
			local style = ITEM_STYLES[item.itemId] or DEFAULT_STYLE
			visual.part.Color = style.color
			visual.part.Material = style.material
		end
	end

	-- Clean up visuals for slots that are no longer occupied
	for key, visual in pairs(activeVisuals) do
		if not seenKeys[key] then
			releasePartToPool(visual)
			activeVisuals[key] = nil
		end
	end
end

function ItemVisualController.OnRenderStepped(dt: number)
	-- Smooth frame-rate independent interpolation towards target position
	local lerpFactor = math.clamp(dt * 18, 0, 1)
	for _, visual in pairs(activeVisuals) do
		if visual.inUse then
			local currentPos = visual.part.Position
			local newPos = currentPos:Lerp(visual.targetPosition, lerpFactor)
			visual.part.CFrame = CFrame.new(newPos)
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
