-- Run the whole file once in Studio's Command Bar while NOT playing.
-- This creates editable Studio assets outside the Script Sync roots.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "Run this in Studio edit mode, not Play mode.")

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
ChangeHistoryService:SetWaypoint("Before placeholder vehicle setup")

local templates = ServerStorage:FindFirstChild("VehicleTemplates")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "VehicleTemplates"
	templates.Parent = ServerStorage
end
assert(templates:IsA("Folder"), "ServerStorage.VehicleTemplates must be a Folder.")

local vehicle = templates:FindFirstChild("PlaceholderVehicle")
if not vehicle then
	vehicle = Instance.new("Model")
	vehicle.Name = "PlaceholderVehicle"
	vehicle:SetAttribute("ForwardAxis", "-Z")

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(6, 1.4, 10)
	chassis.CFrame = CFrame.identity
	chassis.Color = Color3.fromRGB(105, 115, 130)
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Anchored = true
	chassis.RootPriority = 127
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.5, 0, 100, 100)
	chassis.Parent = vehicle
	vehicle.PrimaryPart = chassis

	local function attach(part: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3)
		part.Name = name
		part.Size = size
		part.CFrame = chassis.CFrame * offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.Parent = vehicle
		local weld = Instance.new("WeldConstraint")
		weld.Name = name .. "Weld"
		weld.Part0 = chassis
		weld.Part1 = part
		weld.Parent = part
	end

	local seat = Instance.new("VehicleSeat")
	seat.HeadsUpDisplay = false
	seat.Torque = 0
	seat.MaxSpeed = 0
	attach(seat, "DriverSeat", Vector3.new(2, 1, 2), CFrame.new(0, 1.1, 0.5), Color3.fromRGB(35, 40, 50))
	local driverAttachment = Instance.new("Attachment")
	driverAttachment.Name = "DriverAttachment"
	driverAttachment.CFrame = CFrame.new(0, 0.5, 0)
	driverAttachment.Parent = seat

	attach(Instance.new("Part"), "FrontMarker", Vector3.new(4, 0.4, 1), CFrame.new(0, 0.9, -4.5), Color3.fromRGB(70, 220, 100))
	attach(Instance.new("Part"), "RearMarker", Vector3.new(4, 0.4, 0.6), CFrame.new(0, 0.9, 4.7), Color3.fromRGB(230, 65, 65))
	for _, side in {-1, 1} do
		for _, axle in {-1, 1} do
			local wheel = Instance.new("Part")
			wheel.Shape = Enum.PartType.Cylinder
			local name = (if axle == -1 then "Front" else "Rear") .. (if side == -1 then "Left" else "Right") .. "Wheel"
			-- Cylinders run along local X. Their bottoms align with the collision chassis.
			attach(wheel, name, Vector3.new(0.8, 1.4, 1.4), CFrame.new(side * 3.2, 0, axle * 3), Color3.fromRGB(25, 25, 30))
		end
	end
	vehicle.Parent = templates
end
assert(vehicle:IsA("Model"), "Existing PlaceholderVehicle must be a Model; setup preserves existing assets.")

local marker = Workspace:FindFirstChild("PlaceholderVehicleSpawn")
if not marker then
	marker = Instance.new("Part")
	marker.Name = "PlaceholderVehicleSpawn"
	marker.Size = Vector3.new(6, 0.2, 10)
	local playerSpawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local origin = if playerSpawn then playerSpawn.Position else Vector3.zero
	marker.CFrame = CFrame.new(origin + Vector3.new(14, 8, 0))
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Parent = Workspace
end
assert(marker:IsA("BasePart"), "Existing PlaceholderVehicleSpawn must be a BasePart.")
Workspace:SetAttribute("EnablePlaceholderVehicleTest", true)
ChangeHistoryService:SetWaypoint("Created placeholder vehicle")
game:GetService("Selection"):Set({vehicle, marker})
print("Placeholder vehicle ready. Save the place, sync the branch, then Play. Existing assets were preserved.")
