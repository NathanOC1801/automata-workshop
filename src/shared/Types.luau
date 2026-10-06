--!strict

export type ItemId = "RawIron" | "RawCopper" | "IronIngot" | "CopperIngot" | "IronPlate" | "Wire"

export type ItemData = {
	id: ItemId,
	displayName: string,
	description: string,
	stackSize: number,
}

export type MachineCategory = "Drill" | "Conveyor" | "Smelter" | "Assembler" | "Storage"

export type MachineData = {
	id: string,
	category: MachineCategory,
	tier: number,
	size: Vector2int16,
}

export type Recipe = {
	id: string,
	displayName: string,
	inputs: { [ItemId]: number },
	outputs: { [ItemId]: number },
	craftDuration: number,
	machineType: MachineCategory,
}

export type ConveyorSlot = {
	slotIndex: number, -- 1 to 4
	itemId: ItemId?,
	progress: number, -- 0.0 to 1.0 within the slot
}

export type PlotData = {
	plotId: string,
	ownerUserId: number,
	sharedUsers: { number },
	boundsOrigin: Vector3int16,
	sizeInCells: Vector2int16,
}

return {}
