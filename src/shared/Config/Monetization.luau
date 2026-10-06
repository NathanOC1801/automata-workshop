--!strict

export type MonetizationConfig = {
	FastDrillPassId: number,
	DoubleConveyorSpeedPassId: number,
	Overclock15MinProductId: number,
}

local Monetization: MonetizationConfig = {
	FastDrillPassId = 1234567,
	DoubleConveyorSpeedPassId = 2345678,
	Overclock15MinProductId = 3456789,
}

return table.freeze(Monetization)
