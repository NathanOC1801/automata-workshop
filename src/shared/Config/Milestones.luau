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
		name = "Basic Automation",
		description = "Starter tools and basic logistics",
		requirement = {
			credits = 0,
			items = {},
		},
		unlocks = { "Basic Drills", "Conveyors", "Smelters", "Splitters", "Mergers", "Sinks" },
	},
	[2] = {
		tier = 2,
		name = "Advanced Logistics",
		description = "Higher efficiency extraction and transport",
		requirement = {
			credits = 50,
			items = {
				IronPlate = 10,
			},
		},
		unlocks = { "Fast Conveyor (2x speed)", "Tier 2 Drill (2x extraction rate)" },
	},
	[3] = {
		tier = 3,
		name = "Circuitry & Automation",
		description = "Advanced electronic manufacturing and sorting",
		requirement = {
			credits = 200,
			items = {
				Circuit = 5,
			},
		},
		unlocks = { "Fast Smelter", "Multi-Item Sorter" },
	},
}

return table.freeze(Milestones)
