--!strict

local Types = require(script.Parent.Parent.Types)

local Items: { [Types.ItemId]: Types.ItemData } = {
	RawIron = {
		id = "RawIron",
		displayName = "Raw Iron",
		description = "Unrefined iron ore",
		stackSize = 50,
	},
	RawCopper = {
		id = "RawCopper",
		displayName = "Raw Copper",
		description = "Unrefined copper ore",
		stackSize = 50,
	},
	IronIngot = {
		id = "IronIngot",
		displayName = "Iron Ingot",
		description = "Smelted iron bar",
		stackSize = 100,
	},
	CopperIngot = {
		id = "CopperIngot",
		displayName = "Copper Ingot",
		description = "Smelted copper bar",
		stackSize = 100,
	},
	IronPlate = {
		id = "IronPlate",
		displayName = "Iron Plate",
		description = "Pressed sheet of iron",
		stackSize = 100,
	},
	Wire = {
		id = "Wire",
		displayName = "Copper Wire",
		description = "Extruded copper strand",
		stackSize = 150,
	},
}

return table.freeze(Items)
