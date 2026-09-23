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
	print("PlaceholderVehicle spawned. Green = front. Jump onto DriverSeat to sit; driving comes later.")
end
