--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- This fixture is opt-in per place and never spawns in a published server.
if not RunService:IsStudio() or Workspace:GetAttribute("EnablePlaceholderVehicleTest") ~= true then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleConfig = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local marker = Workspace:FindFirstChild(VehicleConfig.TestSpawnName)
if not marker or not marker:IsA("BasePart") then
	warn("Run tools/SetupPlaceholderVehicle.luau in Studio edit mode to create the test spawn marker.")
	return
end

local vehicle = VehicleService.spawnOnGround(marker.CFrame)
if vehicle then
	print(string.format("[Issue 7] Test settings: %.1f-stud wheels; target speed %.0f studs/second.", VehicleConfig.TestWheelDiameter, VehicleConfig.TestDriveSpeed))
	print("PlaceholderVehicle spawned. Checking physics before enabling the seated motion test...")
	local VehicleChecks = require(script.Parent:WaitForChild("VehicleChecks"))
	local passed = VehicleChecks.run(vehicle, marker.CFrame)
	if passed and VehicleConfig.TestDriveEnabled then
		local VehicleTestDrive = require(script.Parent:WaitForChild("VehicleTestDrive"))
		local stopDriving = VehicleTestDrive.start(vehicle)
		script.Destroying:Connect(stopDriving)
		print("[Issue 7] Forward-motion test ready: sit to move toward the green nose; jump out to brake.")
	elseif not passed then
		warn("[Issue 7] Forward-motion test stayed off because the vehicle checks failed.")
	end
end
