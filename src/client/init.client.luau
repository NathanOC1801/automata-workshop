--!strict

local PlacementController = require(script.Controllers.PlacementController)
local ItemVisualController = require(script.Controllers.ItemVisualController)
local EconomyController = require(script.Controllers.EconomyController)

PlacementController.Init()
ItemVisualController.Init()
EconomyController.Init()

print("Client initialization complete!")
