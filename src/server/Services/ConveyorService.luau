--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local GridService = require(script.Parent.GridService)

export type ConveyorCell = {
	coord: Vector3int16,
	orientation: number, -- 0, 90, 180, 270
	slots: { Types.ConveyorSlot },
}

local ConveyorService = {}

local conveyors: { [string]: ConveyorCell } = {}

local function coordToKey(coord: Vector3int16): string
	return string.format("%d,%d,%d", coord.X, coord.Y, coord.Z)
end

function ConveyorService.GetDirectionOffset(orientation: number): Vector3int16
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

function ConveyorService.CreateConveyor(coord: Vector3int16, orientation: number): ConveyorCell
	local key = coordToKey(coord)
	local slots: { Types.ConveyorSlot } = {}
	for i = 1, 4 do
		table.insert(slots, {
			slotIndex = i,
			itemId = nil,
			progress = 0.0,
		})
	end

	local conveyor: ConveyorCell = {
		coord = coord,
		orientation = orientation,
		slots = slots,
	}

	conveyors[key] = conveyor
	GridService.SetCell(coord, {
		machineId = "Conveyor_" .. key,
		category = "Conveyor",
		orientation = orientation,
	})

	return conveyor
end

function ConveyorService.GetConveyor(coord: Vector3int16): ConveyorCell?
	local key = coordToKey(coord)
	return conveyors[key]
end

function ConveyorService.RemoveConveyor(coord: Vector3int16)
	local key = coordToKey(coord)
	conveyors[key] = nil
	GridService.ClearCell(coord)
end

function ConveyorService.StepConveyors(dt: number)
	-- Phase 1: Internal slot advances within each conveyor (slots 3 down to 1)
	for _, conveyor in pairs(conveyors) do
		for s = 3, 1, -1 do
			local currentSlot = conveyor.slots[s]
			local nextSlot = conveyor.slots[s + 1]
			if currentSlot.itemId ~= nil and nextSlot.itemId == nil then
				nextSlot.itemId = currentSlot.itemId
				nextSlot.progress = 1.0
				currentSlot.itemId = nil
				currentSlot.progress = 0.0
			end
		end
	end

	-- Phase 2: Inter-conveyor transfers (Slot 4 -> Target Conveyor Slot 1)
	-- Running transfers AFTER internal slot advances prevents items transferred into Slot 1
	-- from double-stepping into Slot 2 during the same tick!
	for _, conveyor in pairs(conveyors) do
		local slot4 = conveyor.slots[4]
		if slot4.itemId ~= nil then
			local dirOffset = ConveyorService.GetDirectionOffset(conveyor.orientation)
			local targetCoord = Vector3int16.new(
				conveyor.coord.X + dirOffset.X,
				conveyor.coord.Y + dirOffset.Y,
				conveyor.coord.Z + dirOffset.Z
			)
			local targetConveyor = ConveyorService.GetConveyor(targetCoord)
			if targetConveyor then
				local targetSlot1 = targetConveyor.slots[1]
				if targetSlot1.itemId == nil then
					targetSlot1.itemId = slot4.itemId
					targetSlot1.progress = 1.0
					slot4.itemId = nil
					slot4.progress = 0.0
				end
			end
		end
	end
end

return ConveyorService
