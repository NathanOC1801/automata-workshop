--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)
local HUDController = require(script.Parent.HUDController)

local EconomyController = {}

function EconomyController.Init()
	Network.Remotes.SyncCredits.OnClientEvent:Connect(function(credits)
		if typeof(credits) == "number" then
			HUDController.UpdateCredits(credits)
		end
	end)

	print("[EconomyController] Initialized.")
end

return EconomyController
