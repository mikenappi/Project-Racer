--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleConfig = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local VehicleTestDrive = {}

function VehicleTestDrive.start(vehicle: Model): () -> ()
	assert(RunService:IsStudio() and RunService:IsServer(), "Test driving is Studio-server only.")
	local chassis = vehicle.PrimaryPart
	local seat = vehicle:FindFirstChild("DriverSeat")
	assert(chassis and seat and seat:IsA("VehicleSeat"), "Vehicle needs a chassis and driver seat.")
	assert(not chassis:FindFirstChild("TestForwardVelocity"), "Test driving is already attached.")
	local groundOffset, supports = VehicleService.getGroundSupport(vehicle)

	local attachment = Instance.new("Attachment")
	attachment.Name = "TestDriveAttachment"
	attachment.Parent = chassis
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TestForwardVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.Enabled = false
	velocity.Parent = chassis

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {vehicle}
	params.RespectCanCollide = true
	local stepConnection: RBXScriptConnection? = nil
	local destroyConnection: RBXScriptConnection? = nil
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if stepConnection then stepConnection:Disconnect() end
		if destroyConnection then destroyConnection:Disconnect() end
		velocity:Destroy()
		attachment:Destroy()
		vehicle:SetAttribute("TestDriveActive", false)
	end

	stepConnection = RunService.PreSimulation:Connect(function()
		if not vehicle:IsDescendantOf(Workspace) then
			stop()
			return
		end
		local occupant = seat.Occupant
		local character = if occupant then occupant.Parent else nil
		local hasDriver = occupant ~= nil and occupant.Health > 0
			and character ~= nil and character:IsA("Model")
			and Players:GetPlayerFromCharacter(character) ~= nil
		local forward = chassis.CFrame.LookVector
		local horizontalForward = Vector3.new(forward.X, 0, forward.Z)
		local grounded = false
		for _, support in supports do
			local offset = chassis.CFrame:PointToObjectSpace(support.Position)
			local origin = chassis.CFrame:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
			local hit = Workspace:Raycast(origin, Vector3.new(0, -(groundOffset + 0.5), 0), params)
			if hit and hit.Normal.Y > 0.5 then
				grounded = true
				break
			end
		end
		local upright = chassis.CFrame.UpVector:Dot(Vector3.yAxis) > 0.5
		local driving = hasDriver and grounded and upright and horizontalForward.Magnitude > 0.01
		vehicle:SetAttribute("TestDriveActive", driving)

		-- A horizontal constraint leaves gravity free to act. Finite force lets walls
		-- block the car; no CFrame teleporting or per-frame velocity replacement is used.
		attachment.Position = chassis.CFrame:PointToObjectSpace(chassis.AssemblyCenterOfMass)
		velocity.MaxForce = chassis.AssemblyMass * VehicleConfig.TestDriveAcceleration
		velocity.Enabled = grounded and upright
		local target = if driving then horizontalForward.Unit * VehicleConfig.TestDriveSpeed else Vector3.zero
		-- An empty seat targets zero horizontal speed, braking through physics.
		velocity.PlaneVelocity = Vector2.new(target.X, target.Z)
	end)
	destroyConnection = vehicle.Destroying:Connect(stop)
	return stop
end

return VehicleTestDrive
