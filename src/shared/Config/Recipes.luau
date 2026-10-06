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
		displayName = "Iron Plate",
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
		displayName = "Copper Wire",
		inputs = {
			CopperIngot = 2,
		},
		outputs = {
			Wire = 2,
		},
		craftDuration = 2.0,
		machineType = "Assembler",
	},
	Circuit = {
		id = "Circuit",
		displayName = "Circuit",
		inputs = {
			IronPlate = 1,
			Wire = 2,
		},
		outputs = {
			Circuit = 1,
		},
		craftDuration = 4.0,
		machineType = "Assembler",
	},
	ReinforcedPlate = {
		id = "ReinforcedPlate",
		displayName = "Reinforced Plate",
		inputs = {
			IronPlate = 2,
			Wire = 2,
		},
		outputs = {
			ReinforcedPlate = 1,
		},
		craftDuration = 5.0,
		machineType = "Assembler",
	},
}

return table.freeze(Recipes)
