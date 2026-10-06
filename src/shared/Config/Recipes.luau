--!strict

local Types = require(script.Parent.Parent.Types)

local Recipes: { [string]: Types.Recipe } = {
	SmeltIron = {
		id = "SmeltIron",
		displayName = "Smelt Iron Ingot",
		inputs = {
			RawIron = 1,
		},
		outputs = {
			IronIngot = 1,
		},
		craftDuration = 2.0,
		machineType = "Smelter",
	},
	SmeltCopper = {
		id = "SmeltCopper",
		displayName = "Smelt Copper Ingot",
		inputs = {
			RawCopper = 1,
		},
		outputs = {
			CopperIngot = 1,
		},
		craftDuration = 2.0,
		machineType = "Smelter",
	},
	CraftIronPlate = {
		id = "CraftIronPlate",
		displayName = "Craft Iron Plate",
		inputs = {
			IronIngot = 2,
		},
		outputs = {
			IronPlate = 1,
		},
		craftDuration = 3.0,
		machineType = "Assembler",
	},
	CraftWire = {
		id = "CraftWire",
		displayName = "Craft Copper Wire",
		inputs = {
			CopperIngot = 1,
		},
		outputs = {
			Wire = 2,
		},
		craftDuration = 2.0,
		machineType = "Assembler",
	},
}

return table.freeze(Recipes)
