--!strict

local Workspace = game:GetService("Workspace")

local AudioController = {}

local activeSounds: { [BasePart]: Sound } = {}

local function createSound(part: BasePart, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.MaxDistance = 30
	sound.MinDistance = 5
	sound.Parent = part
	sound:Play()
	return sound
end

local function handleChildAdded(child: Instance)
	if child:IsA("BasePart") then
		local nameParts = string.split(child.Name, "_")
		local category = nameParts[1]
		if category == "Conveyor" then
			activeSounds[child] = createSound(child, "rbxassetid://9114223166", 0.2)
		elseif category == "Drill" then
			activeSounds[child] = createSound(child, "rbxassetid://9114223166", 0.3)
		elseif category == "Smelter" then
			activeSounds[child] = createSound(child, "rbxassetid://9114223166", 0.35)
		end
	end
end

local function handleChildRemoved(child: Instance)
	if child:IsA("BasePart") and activeSounds[child] then
		local sound = activeSounds[child]
		if sound then
			sound:Stop()
			sound:Destroy()
		end
		activeSounds[child] = nil
	end
end

function AudioController.Init()
	local placedFolder = Workspace:WaitForChild("PlacedObjects", 10)
	if placedFolder then
		for _, child in ipairs(placedFolder:GetChildren()) do
			handleChildAdded(child)
		end
		placedFolder.ChildAdded:Connect(handleChildAdded)
		placedFolder.ChildRemoved:Connect(handleChildRemoved)
	end
	print("[AudioController] Initialized.")
end

return AudioController
