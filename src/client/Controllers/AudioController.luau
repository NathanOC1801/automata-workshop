--!strict

local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local AudioController = {}

local activeSounds: { [BasePart]: Sound } = {}

local function startBackgroundMusic()
	local bgm = Instance.new("Sound")
	bgm.Name = "FactoryBGM"
	bgm.SoundId = "rbxassetid://1843404009"
	bgm.Volume = 0.22
	bgm.Looped = true
	bgm.Parent = SoundService
	bgm:Play()
end

local function createSound(part: BasePart, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = "MachineHum"
	sound.SoundId = soundPath
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.LinearSquare
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 32
	sound.Parent = part
	sound:Play()

	return sound
end

local function handleChildAdded(child: Instance)
	if child:IsA("BasePart") then
		local nameParts = string.split(child.Name, "_")
		local category = nameParts[1]
		local cfg = SOUND_CONFIG[category]

		if cfg then
			activeSounds[child] = createSound(child, cfg.sound, cfg.volume, cfg.playbackSpeed)
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
	task.spawn(function()
		local placedFolder = Workspace:WaitForChild("PlacedObjects", 10)
		if placedFolder then
			for _, child in ipairs(placedFolder:GetChildren()) do
				handleChildAdded(child)
			end
			placedFolder.ChildAdded:Connect(handleChildAdded)
			placedFolder.ChildRemoved:Connect(handleChildRemoved)
		else
			warn("[AudioController] PlacedObjects folder was not found within timeout.")
		end
	end)

	print("[AudioController] Initialized.")
end

return AudioController