--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local EPSILON = 0.001
for _, key in {"MaxForwardSpeed", "MaxReverseSpeed", "Acceleration", "Braking",
	"CoastDeceleration", "StopSpeed", "SteeringFullSpeed", "SteeringResponse",
	"LateralGrip", "AngularTorquePerMass", "InputSendInterval", "InputTimeout"} do
	assert((Config :: any)[key] > 0, key .. " must be positive.")
end
assert(Config.InputDeadzone >= 0 and Config.InputDeadzone < 1, "Invalid input deadzone.")
assert(Config.HighSpeedSteeringScale >= 0 and Config.HighSpeedSteeringScale <= 1, "Invalid steering scale.")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
assert(remotes:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder.")
local inputRemote = remotes:FindFirstChild(Config.InputRemoteName)
if not inputRemote then
	inputRemote = Instance.new("RemoteEvent")
	inputRemote.Name = Config.InputRemoteName
	inputRemote.Parent = remotes
end
assert(inputRemote:IsA("RemoteEvent"), "VehicleInput must be a RemoteEvent.")

type DriveState = {
	vehicle: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	attachment: Attachment,
	velocity: LinearVelocity,
	angular: AngularVelocity,
	params: RaycastParams,
	supports: {BasePart},
	groundOffset: number,
	throttle: number,
	steer: number,
	lastInput: number,
	yawRate: number,
	occupantConnection: RBXScriptConnection?,
}
local states: {[VehicleSeat]: DriveState} = {}
local watchers: {[Model]: RBXScriptConnection} = {}

local function getDriver(seat: VehicleSeat): Player?
	local occupant = seat.Occupant
	local character = if occupant then occupant.Parent else nil
	if not occupant or occupant.Health <= 0 or not character or not character:IsA("Model") then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function finiteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

inputRemote.OnServerEvent:Connect(function(player: Player, seat: any, throttle: any, steer: any)
	if typeof(seat) ~= "Instance" or not seat:IsA("VehicleSeat") then return end
	local state = states[seat]
	if not state or getDriver(seat) ~= player then return end
	if not finiteNumber(throttle) or not finiteNumber(steer) then return end
	local now = os.clock()
	if now - state.lastInput < Config.InputMinReceiveInterval then return end
	state.throttle = if math.abs(throttle) < Config.InputDeadzone then 0 else math.clamp(throttle, -1, 1)
	state.steer = if math.abs(steer) < Config.InputDeadzone then 0 else math.clamp(steer, -1, 1)
	state.lastInput = now
end)

-- Choose a bounded target; finite force supplies acceleration rather than
-- overwriting velocity. Opposite input must brake before changing direction.
local function getDriveTarget(speed: number, throttle: number, hasInput: boolean): (number, number)
	if not hasInput then return 0, Config.Braking end
	if throttle == 0 then
		return 0, if math.abs(speed) <= Config.StopSpeed then Config.Braking else Config.CoastDeceleration
	end
	if speed * throttle < 0 and math.abs(speed) > Config.StopSpeed then
		return 0, Config.Braking
	end
	local limit = if throttle > 0 then Config.MaxForwardSpeed else Config.MaxReverseSpeed
	return throttle * limit, Config.Acceleration
end

local function getYawTarget(speed: number, steer: number): number
	local speedFraction = math.clamp(math.abs(speed) / Config.MaxForwardSpeed, 0, 1)
	local steeringScale = 1 - (1 - Config.HighSpeedSteeringScale) * speedFraction
	local lowSpeedScale = math.clamp(math.abs(speed) / Config.SteeringFullSpeed, 0, 1)
	-- D is positive seat input but right turns need negative yaw about world up.
	return -steer * math.sign(speed) * Config.TurningStrength * lowSpeedScale * steeringScale
end

local function getGroundNormal(state: DriveState): Vector3?
	local normal = Vector3.zero
	for _, support in state.supports do
		-- Use each wheel's actual position, so ramp pitch does not shorten front probes.
		local hit = Workspace:Raycast(support.Position,
			-Vector3.yAxis * (state.groundOffset + Config.GroundContactTolerance), state.params)
		if hit and hit.Normal.Y >= Config.MinGroundNormalY then
			normal += hit.Normal
		end
	end
	return if normal.Magnitude > EPSILON then normal.Unit else nil
end

local function stepVehicle(state: DriveState, dt: number)
	local chassis = state.chassis
	local normal = getGroundNormal(state)
	local look = chassis.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)
	local hasInput = getDriver(state.seat) ~= nil and os.clock() - state.lastInput <= Config.InputTimeout
	state.vehicle:SetAttribute("MovementInputActive", hasInput)
	state.vehicle:SetAttribute("ForwardSpeed",
		if horizontal.Magnitude > EPSILON then chassis.AssemblyLinearVelocity:Dot(horizontal.Unit) else 0)
	local supported = normal ~= nil and chassis.CFrame.UpVector:Dot(normal) >= Config.MinUprightDot
		and horizontal.Magnitude > EPSILON and not chassis.Anchored
	state.velocity.Enabled = supported
	state.angular.Enabled = supported
	state.vehicle:SetAttribute("MovementGrounded", normal ~= nil)
	if not supported or not normal then
		state.yawRate = 0
		return -- Gravity, air motion, and collisions are left to the engine.
	end

	local forward = horizontal.Unit
	local right = forward:Cross(Vector3.yAxis)
	local speed = chassis.AssemblyLinearVelocity:Dot(forward)
	local throttle = if hasInput then state.throttle else 0
	local steer = if hasInput then state.steer else 0
	local target, acceleration = getDriveTarget(speed, throttle, hasInput)
	-- If a slope or impact exceeds a speed cap, recover with braking force.
	if speed > Config.MaxForwardSpeed or speed < -Config.MaxReverseSpeed then
		acceleration = Config.Braking
	end

	-- The plane is horizontal: no upward force to hover or cancel gravity.
	-- Independent force limits allow sideways grip without changing drive tuning.
	state.attachment.Position = chassis.CFrame:PointToObjectSpace(chassis.AssemblyCenterOfMass)
	state.velocity.PrimaryTangentAxis = forward
	state.velocity.SecondaryTangentAxis = right
	state.velocity.PlaneVelocity = Vector2.new(target, 0)
	state.velocity.MaxPlanarAxesForce = Vector2.new(acceleration, Config.LateralGrip) * chassis.AssemblyMass

	local yawTarget = getYawTarget(speed, steer)
	state.yawRate += (yawTarget - state.yawRate) * (1 - math.exp(-Config.SteeringResponse * dt))
	-- Align toward the ground normal, not world up, so the car can pitch on ramps.
	local correction = chassis.CFrame.UpVector:Cross(normal) * Config.StabilityStrength
	if correction.Magnitude > Config.MaxTiltCorrection then
		correction = correction.Unit * Config.MaxTiltCorrection
	end
	state.angular.AngularVelocity = normal * state.yawRate + correction
	state.angular.MaxTorque = chassis.AssemblyMass * Config.AngularTorquePerMass
end

local function stopVehicle(vehicle: Model)
	for seat, state in states do
		if state.vehicle ~= vehicle then continue end
		states[seat] = nil
		if state.occupantConnection then state.occupantConnection:Disconnect() end
		state.velocity:Destroy()
		state.angular:Destroy()
		state.attachment:Destroy()
		vehicle:SetAttribute("MovementInputActive", false)
	end
end

local function startVehicle(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	local seat = vehicle:FindFirstChild("DriverSeat")
	if not chassis or not seat or not seat:IsA("VehicleSeat") or states[seat] then return end
	if chassis.Anchored then
		warn("Vehicle movement needs an unanchored Chassis: " .. vehicle:GetFullName())
		return
	end
	-- Also handle an old Studio copy that retained Issue 7's temporary mover.
	for _, name in {"TestForwardVelocity", "TestDriveAttachment"} do
		local legacy = chassis:FindFirstChild(name)
		if legacy then legacy:Destroy() end
	end
	local groundOffset, supports = VehicleService.getGroundSupport(vehicle)
	local attachment = Instance.new("Attachment")
	attachment.Name = "MovementAttachment"
	attachment.Parent = chassis
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "MovementVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.Enabled = false
	velocity.Parent = chassis
	local angular = Instance.new("AngularVelocity")
	angular.Name = "MovementRotation"
	angular.Attachment0 = attachment
	angular.RelativeTo = Enum.ActuatorRelativeTo.World
	angular.ReactionTorqueEnabled = false
	angular.Enabled = false
	angular.Parent = chassis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local state: DriveState = {
		vehicle = vehicle, chassis = chassis, seat = seat,
		attachment = attachment, velocity = velocity, angular = angular,
		params = params, supports = supports, groundOffset = groundOffset,
		throttle = 0, steer = 0, lastInput = -math.huge, yawRate = 0,
		occupantConnection = nil,
	}
	states[seat] = state
	local function resetDriver()
		state.throttle, state.steer, state.lastInput, state.yawRate = 0, 0, -math.huge, 0
		local character = if seat.Occupant then seat.Occupant.Parent else nil
		params.FilterDescendantsInstances = if character then {vehicle, character} else {vehicle}
		-- Reassert ownership when the seat weld changes the physical assembly.
		local canSet = chassis:CanSetNetworkOwnership()
		if canSet then chassis:SetNetworkOwner(nil) end
	end
	resetDriver()
	state.occupantConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(resetDriver)
end

local activeFolder = Workspace:FindFirstChild(Config.ActiveFolderName)
if not activeFolder then
	activeFolder = Instance.new("Folder")
	activeFolder.Name = Config.ActiveFolderName
	activeFolder.Parent = Workspace
end
assert(activeFolder:IsA("Folder"), "Workspace.Vehicles must be a Folder.")

local function watchVehicle(instance: Instance)
	if not instance:IsA("Model") or watchers[instance] then return end
	local function refresh()
		if instance:GetAttribute("MovementEnabled") == true then
			startVehicle(instance)
		else
			stopVehicle(instance)
		end
	end
	watchers[instance] = instance:GetAttributeChangedSignal("MovementEnabled"):Connect(refresh)
	refresh()
end
activeFolder.ChildAdded:Connect(watchVehicle)
activeFolder.ChildRemoved:Connect(function(instance)
	if not instance:IsA("Model") then return end
	stopVehicle(instance)
	local connection = watchers[instance]
	if connection then connection:Disconnect() end
	watchers[instance] = nil
end)
for _, vehicle in activeFolder:GetChildren() do watchVehicle(vehicle) end

RunService.PreSimulation:Connect(function(dt)
	for _, state in states do stepVehicle(state, dt) end
end)
