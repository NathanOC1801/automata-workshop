--!strict

local Types = require(script.Parent.Parent.Parent.shared.Types)

export type CellData = {
	machineId: string,
	category: Types.MachineCategory,
	orientation: number,
}

local GridService = {}

local cells: { [string]: CellData } = {}

local function coordToKey(coord: Vector3int16): string
	return string.format("%d,%d,%d", coord.X, coord.Y, coord.Z)
end

function GridService.SetCell(coord: Vector3int16, data: CellData)
	local key = coordToKey(coord)
	cells[key] = data
end

function GridService.GetCell(coord: Vector3int16): CellData?
	local key = coordToKey(coord)
	return cells[key]
end

function GridService.ClearCell(coord: Vector3int16)
	local key = coordToKey(coord)
	cells[key] = nil
end

function GridService.IsCellEmpty(coord: Vector3int16): boolean
	local key = coordToKey(coord)
	return cells[key] == nil
end

return GridService
