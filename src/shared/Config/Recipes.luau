--!strict

local Types = require(script.Parent.Parent.Types)

local Recipes: { [string]: Types.Recipe } = {
	-- Smelter Recipes
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
	SmeltTitanium = {
		id = "SmeltTitanium",
		displayName = "Smelt Titanium Ingot",
		inputs = {
			RawTitanium = 1,
		},
		outputs = {
			TitaniumIngot = 1,
		},
		craftDuration = 2.5,
		machineType = "Smelter",
	},
	SmeltCobalt = {
		id = "SmeltCobalt",
		displayName = "Smelt Cobalt Ingot",
		inputs = {
			RawCobalt = 1,
		},
		outputs = {
			CobaltIngot = 1,
		},
		craftDuration = 3.0,
		machineType = "Smelter",
	},
	SmeltGold = {
		id = "SmeltGold",
		displayName = "Smelt Gold Bar",
		inputs = {
			RawGold = 1,
		},
		outputs = {
			GoldBar = 1,
		},
		craftDuration = 3.5,
		machineType = "Smelter",
	},
	CutEmerald = {
		id = "CutEmerald",
		displayName = "Thermal Cut Emerald",
		inputs = {
			RawEmerald = 1,
		},
		outputs = {
			CutEmerald = 1,
		},
		craftDuration = 3.0,
		machineType = "Smelter",
	},
	PolishDiamond = {
		id = "PolishDiamond",
		displayName = "Thermal Polish Diamond",
		inputs = {
			RawDiamond = 1,
		},
		outputs = {
			PolishedDiamond = 1,
		},
		craftDuration = 4.0,
		machineType = "Smelter",
	},

	-- Assembler Recipes
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
	TitaniumFrame = {
		id = "TitaniumFrame",
		displayName = "Titanium Frame",
		inputs = {
			TitaniumIngot = 2,
			ReinforcedPlate = 1,
		},
		outputs = {
			TitaniumFrame = 1,
		},
		craftDuration = 4.0,
		machineType = "Assembler",
	},
	SolarCell = {
		id = "SolarCell",
		displayName = "Solar Cell",
		inputs = {
			Wire = 2,
			Circuit = 1,
		},
		outputs = {
			SolarCell = 1,
		},
		craftDuration = 3.0,
		machineType = "Assembler",
	},
}

return table.freeze(Recipes)
