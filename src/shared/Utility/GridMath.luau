--!strict

local GridMath = {}

local GRID_SIZE = 4

function GridMath.worldToGrid(worldPos: Vector3): Vector3int16
	local x = math.floor(worldPos.X / GRID_SIZE)
	local y = math.floor(worldPos.Y / GRID_SIZE)
	local z = math.floor(worldPos.Z / GRID_SIZE)
	return Vector3int16.new(x, y, z)
end

function GridMath.gridToWorld(gridPos: Vector3int16): Vector3
	local x = gridPos.X * GRID_SIZE + (GRID_SIZE / 2)
	local y = gridPos.Y * GRID_SIZE
	local z = gridPos.Z * GRID_SIZE + (GRID_SIZE / 2)
	return Vector3.new(x, y, z)
end

return GridMath
