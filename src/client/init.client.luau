--!strict

local PlacementController = require(script.Controllers.PlacementController)
local ItemVisualController = require(script.Controllers.ItemVisualController)
local EconomyController = require(script.Controllers.EconomyController)
local AudioController = require(script.Controllers.AudioController)
local InspectionController = require(script.Controllers.InspectionController)
local ProgressionController = require(script.Controllers.ProgressionController)

PlacementController.Init()
ItemVisualController.Init()
EconomyController.Init()
AudioController.Init()
InspectionController.Init()
ProgressionController.Init()

print("Client initialization complete!")
