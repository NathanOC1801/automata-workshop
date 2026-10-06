--!strict

local Types = require(script.Parent.Parent.Types)

local Items: { [Types.ItemId]: Types.ItemData } = {
	-- Ores
	RawIron = {
		id = "RawIron",
		displayName = "Raw Iron",
		description = "Unrefined iron ore",
		stackSize = 50,
		baseValue = 5,
	},
	RawCopper = {
		id = "RawCopper",
		displayName = "Raw Copper",
		description = "Unrefined copper ore",
		stackSize = 50,
		baseValue = 5,
	},
	RawTitanium = {
		id = "RawTitanium",
		displayName = "Raw Titanium",
		description = "Lightweight, high-strength lunar ore",
		stackSize = 50,
		baseValue = 15,
	},
	RawCobalt = {
		id = "RawCobalt",
		displayName = "Raw Cobalt",
		description = "Magnetic mineral found in Martian strata",
		stackSize = 50,
		baseValue = 20,
	},
	RawGold = {
		id = "RawGold",
		displayName = "Raw Gold",
		description = "Dense precious metallic deposit",
		stackSize = 50,
		baseValue = 35,
	},
	RawEmerald = {
		id = "RawEmerald",
		displayName = "Raw Emerald",
		description = "Unpolished green gemstone crystal",
		stackSize = 50,
		baseValue = 50,
	},
	RawDiamond = {
		id = "RawDiamond",
		displayName = "Raw Diamond",
		description = "Ultra-dense crystalline carbon deposit",
		stackSize = 50,
		baseValue = 100,
	},
	RawUranium = {
		id = "RawUranium",
		displayName = "Raw Uranium",
		description = "Radioactive energy-dense heavy ore",
		stackSize = 50,
		baseValue = 150,
	},

	-- Processed Materials
	IronIngot = {
		id = "IronIngot",
		displayName = "Iron Ingot",
		description = "Smelted iron bar",
		stackSize = 100,
		baseValue = 12,
	},
	CopperIngot = {
		id = "CopperIngot",
		displayName = "Copper Ingot",
		description = "Smelted copper bar",
		stackSize = 100,
		baseValue = 12,
	},
	TitaniumIngot = {
		id = "TitaniumIngot",
		displayName = "Titanium Ingot",
		description = "Smelted high-grade titanium bar",
		stackSize = 100,
		baseValue = 35,
	},
	CobaltIngot = {
		id = "CobaltIngot",
		displayName = "Cobalt Ingot",
		description = "Refined magnetic cobalt alloy ingot",
		stackSize = 100,
		baseValue = 45,
	},
	GoldBar = {
		id = "GoldBar",
		displayName = "Gold Bar",
		description = "Pure refined gold bullion",
		stackSize = 100,
		baseValue = 85,
	},
	CutEmerald = {
		id = "CutEmerald",
		displayName = "Cut Emerald",
		description = "Thermal-processed precision emerald gem",
		stackSize = 100,
		baseValue = 120,
	},
	PolishedDiamond = {
		id = "PolishedDiamond",
		displayName = "Polished Diamond",
		description = "Thermal-refined brilliant diamond gem",
		stackSize = 100,
		baseValue = 250,
	},

	-- Components
	IronPlate = {
		id = "IronPlate",
		displayName = "Iron Plate",
		description = "Pressed sheet of iron",
		stackSize = 100,
		baseValue = 30,
	},
	Wire = {
		id = "Wire",
		displayName = "Copper Wire",
		description = "Extruded copper strand",
		stackSize = 150,
		baseValue = 15,
	},
	Circuit = {
		id = "Circuit",
		displayName = "Electronic Circuit",
		description = "Basic logic circuit",
		stackSize = 100,
		baseValue = 75,
	},
	ReinforcedPlate = {
		id = "ReinforcedPlate",
		displayName = "Reinforced Plate",
		description = "Heavy composite metal plate",
		stackSize = 50,
		baseValue = 100,
	},
	TitaniumFrame = {
		id = "TitaniumFrame",
		displayName = "Titanium Frame",
		description = "High-rigidity structural titanium frame",
		stackSize = 50,
		baseValue = 220,
	},
	SolarCell = {
		id = "SolarCell",
		displayName = "Solar Cell",
		description = "High-efficiency planetary power collector cell",
		stackSize = 100,
		baseValue = 180,
	},
}

return table.freeze(Items)
