--!strict

local PlacementController = require(script.Controllers.PlacementController)
local ItemVisualController = require(script.Controllers.ItemVisualController)

PlacementController.Init()
ItemVisualController.Init()

print("Client initialization complete!")
