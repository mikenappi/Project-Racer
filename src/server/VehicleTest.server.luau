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

local vehicle = VehicleService.spawnOnGround(marker.CFrame, false)
if vehicle then
	print(string.format("[Issue 8] %.1f-stud wheels; forward %.0f / reverse %.0f studs/second.", VehicleConfig.TestWheelDiameter, VehicleConfig.MaxForwardSpeed, VehicleConfig.MaxReverseSpeed))
	print("PlaceholderVehicle spawned. Wait for stationary checks before sitting...")
	local VehicleChecks = require(script.Parent:WaitForChild("VehicleChecks"))
	local passed = VehicleChecks.run(vehicle, marker.CFrame)
	if passed then
		vehicle:SetAttribute("MovementEnabled", true)
		print("[Issue 8] Controls ready: W accelerate, S brake/reverse, A/D steer; jump out to brake.")
	else
		warn("[Issue 8] Controls stayed off because the placeholder checks failed.")
	end
end
