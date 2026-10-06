--!strict

local Players = game:GetService("Players")
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local RespawnService = require(script.Parent:WaitForChild("RespawnService"))

PlayerVehicleService.setRecoveryDestination(CheckpointService.getResetCFrame)
PlayerVehicleService.start() -- Shared idempotent lifecycle, regardless of script startup order.
RespawnService.start()
Players.PlayerAdded:Connect(CheckpointService.addRacer)
Players.PlayerRemoving:Connect(CheckpointService.removeRacer)

local function startRace()
	local success, reason = CheckpointService.startRace(Players:GetPlayers())
	if not success then warn("Race start failed: " .. tostring(reason)) end
end

-- A server-only entry point for subsequent races; clients cannot fire it.
local startEvent = script:FindFirstChild("StartRace")
if not startEvent then
	startEvent = Instance.new("BindableEvent")
	startEvent.Name = "StartRace"
	startEvent.Parent = script
end
assert(startEvent:IsA("BindableEvent"), "StartRace must be a BindableEvent.")
startEvent.Event:Connect(startRace)
startRace()
