--!strict

local Types = require(script.Parent.Parent.Types)

export type MilestoneRequirement = {
	credits: number,
	items: { [Types.ItemId]: number },
}

export type Milestone = {
	tier: number,
	name: string,
	description: string,
	requirement: MilestoneRequirement,
	unlocks: { string },
}

local Milestones: { [number]: Milestone } = {
	[1] = {
		tier = 1,
		name = "Base Automation",
		description = "Starter extraction and logistics tools",
		requirement = {
			credits = 0,
			items = {},
		},
		unlocks = { "Conveyor", "Drill", "Smelter", "Splitter", "Merger", "Storage", "Sink" },
	},
	[2] = {
		tier = 2,
		name = "Assembly & Circuitry",
		description = "Unlocks Assembler machine and intermediate components",
		requirement = {
			credits = 150,
			items = {
				IronIngot = 25,
				CopperIngot = 25,
			},
		},
		unlocks = { "Assembler Machine", "Wire Recipe", "IronPlate Recipe", "Circuit Recipe" },
	},
	[3] = {
		tier = 3,
		name = "Heavy Manufacturing",
		description = "Unlocks advanced composite components and high tier extraction",
		requirement = {
			credits = 400,
			items = {
				IronPlate = 15,
				Circuit = 10,
			},
		},
		unlocks = { "ReinforcedPlate Recipe", "Tier 2 Drill (2x extraction rate)" },
	},
}

return table.freeze(Milestones)
