--!strict

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleConfig = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local VehicleChecks = {}
local SETTLE_SECONDS = 2
local GROUND_TOLERANCE = 0.15

local function checkAssembly(vehicle: Model, expectedForward: Vector3)
	local chassis = vehicle.PrimaryPart
	assert(chassis and chassis.Name == "Chassis", "Missing chassis/pivot.")
	assert(vehicle:IsDescendantOf(Workspace), "Vehicle is not in Workspace.")
	assert(chassis.CanCollide and chassis.Transparency < 1, "Chassis must be visible and collidable.")
	assert(chassis.CFrame.LookVector:Dot(expectedForward) > 0.99, "Vehicle heading changed unexpectedly.")
	local seat = vehicle:FindFirstChild("DriverSeat")
	assert(seat and seat:IsA("VehicleSeat"), "DriverSeat is missing.")
	assert(seat:FindFirstChild("DriverAttachment"), "DriverAttachment is missing.")
	assert(seat.CFrame.LookVector:Dot(chassis.CFrame.LookVector) > 0.99, "Seat faces the wrong direction.")
	local front = vehicle:FindFirstChild("FrontMarker")
	local rear = vehicle:FindFirstChild("RearMarker")
	assert(front and front:IsA("BasePart") and rear and rear:IsA("BasePart"), "Front/rear markers are missing.")
	assert(chassis.CFrame:PointToObjectSpace(front.Position).Z < 0, "Front marker must be at local -Z.")
	assert(chassis.CFrame:PointToObjectSpace(rear.Position).Z > 0, "Rear marker must be at local +Z.")
	for _, part in vehicle:GetDescendants() do
		if part:IsA("BasePart") then
			assert(not part.Anchored, part.Name .. " is anchored.")
			assert(part.AssemblyRootPart == chassis, part.Name .. " is not connected to the chassis.")
		end
	end
end

local function checkGround(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	assert(chassis)
	assert(chassis.CFrame.UpVector:Dot(Vector3.yAxis) > 0.99, "Vehicle tipped over.")
	assert(chassis.AssemblyLinearVelocity.Magnitude < 0.5, "Vehicle has not settled on the ground.")
	assert(chassis.AssemblyAngularVelocity.Magnitude < 0.5, "Vehicle is still rotating.")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {vehicle}
	params.RespectCanCollide = true
	-- Probe each corner as well as the center; one ray can miss an unsupported edge.
	for _, offset in {Vector3.zero, Vector3.new(-0.45, 0, -0.45), Vector3.new(-0.45, 0, 0.45), Vector3.new(0.45, 0, -0.45), Vector3.new(0.45, 0, 0.45)} do
		local bottom = chassis.CFrame:PointToWorldSpace(Vector3.new(offset.X * chassis.Size.X, -chassis.Size.Y / 2, offset.Z * chassis.Size.Z))
		local hit = Workspace:Raycast(bottom + Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0), params)
		assert(hit and math.abs(hit.Position.Y - bottom.Y) < GROUND_TOLERANCE, "Chassis is floating, intersecting the floor, or missing ground support.")
	end
end

function VehicleChecks.run(visibleVehicle: Model, markerCFrame: CFrame): boolean
	assert(RunService:IsStudio() and RunService:IsServer(), "Vehicle checks are Studio-server only.")
	visibleVehicle:SetAttribute("AcceptanceCheckStatus", "Running")
	local temporaryInstances: {Instance} = {}
	local passed, failure = pcall(function()
		task.wait(SETTLE_SECONDS)
		checkAssembly(visibleVehicle, markerCFrame.LookVector)
		checkGround(visibleVehicle)
		print("[Issue 7] PASS: visible assembly, forward direction, and ground support.")

		local templates = ServerStorage:FindFirstChild(VehicleConfig.TemplateFolderName)
		assert(templates)
		local template = templates:FindFirstChild(VehicleConfig.TemplateName)
		assert(template and template:IsA("Model"))
		local originalPivot = template:GetPivot()
		local originalCount = #template:GetDescendants()
		local floor = Instance.new("Part")
		table.insert(temporaryInstances, floor)
		floor.Name = "TemporaryVehicleCheckFloor"
		floor.Size = Vector3.new(24, 1, 24)
		floor.CFrame = CFrame.new(markerCFrame.Position + Vector3.new(0, 1000, 0))
		floor.Anchored = true
		assert(#Workspace:GetPartBoundsInBox(floor.CFrame + Vector3.new(0, 5, 0), Vector3.new(24, 12, 24)) == 0, "Temporary test area is occupied.")
		floor.Parent = Workspace

		-- Independent copies on an isolated floor avoid deleting the user's visible vehicle.
		for _, degrees in {0, 90, 180} do
			local testMarker = (floor.CFrame + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(degrees), 0)
			local copy = VehicleService.spawnOnGround(testMarker)
			assert(copy and copy ~= template and copy ~= visibleVehicle, "Could not create an independent copy.")
			table.insert(temporaryInstances, copy)
			assert(#copy:GetDescendants() == originalCount, "Spawn did not preserve the whole model.")
			task.wait(SETTLE_SECONDS)
			checkAssembly(copy, testMarker.LookVector)
			checkGround(copy)
			print(string.format("[Issue 7] PASS: fresh spawn at %d degrees settled correctly.", degrees))
			copy:Destroy()
		end
		assert(template.Parent == templates and template:GetPivot() == originalPivot, "Spawning moved the saved template.")
		assert(#template:GetDescendants() == originalCount, "Spawning changed the saved template.")
	end)
	for _, instance in temporaryInstances do
		instance:Destroy()
	end
	visibleVehicle:SetAttribute("AcceptanceCheckStatus", if passed then "Passed" else "Failed")
	if passed then
		print("[Issue 7] ALL AUTOMATED CHECKS PASSED. Inspect the visible vehicle and test seating to finish acceptance.")
	else
		warn("[Issue 7] CHECK FAILED: " .. tostring(failure))
	end
	return passed
end

return VehicleChecks
