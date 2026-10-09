--!strict

local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local RespawnService = require(script.Parent:WaitForChild("RespawnService"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))

PlayerVehicleService.setRecoveryDestination(CheckpointService.getResetCFrame)
PlayerVehicleService.start() -- Shared idempotent lifecycle, regardless of script startup order.
RespawnService.start()
RaceService.start()

-- A server-only entry point for subsequent races; clients cannot fire it.
local startEvent = script:FindFirstChild("StartRace")
if not startEvent then
	startEvent = Instance.new("BindableEvent")
	startEvent.Name = "StartRace"
	startEvent.Parent = script
end
assert(startEvent:IsA("BindableEvent"), "StartRace must be a BindableEvent.")
startEvent.Event:Connect(function() RaceService.requestStart() end)
