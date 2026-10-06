--!strict

local PlacementController = require(script.Controllers.PlacementController)
local ItemVisualController = require(script.Controllers.ItemVisualController)
local EconomyController = require(script.Controllers.EconomyController)
local AudioController = require(script.Controllers.AudioController)

PlacementController.Init()
ItemVisualController.Init()
EconomyController.Init()
AudioController.Init()

print("Client initialization complete!")
