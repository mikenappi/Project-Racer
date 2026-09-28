--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local shared = ReplicatedStorage:WaitForChild("shared")
local Config = require(shared:WaitForChild("CameraConfig"))
local VehicleConfig = require(shared:WaitForChild("VehicleConfig"))
local CameraRig = require(script.Parent:WaitForChild("CameraRig"))

local player = Players.LocalPlayer
local BINDING_NAME = "ProjectRacerCamera"
local activeVehicle: Model? = nil
local activeChassis: BasePart? = nil
local controlledCamera: Camera? = nil
local originalFieldOfView = 70
local rig: CameraRig.State? = nil
local boomLength = 0
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
castParams.RespectCanCollide = true

local function getHumanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function getTarget(): (Model?, BasePart?)
	local humanoid = getHumanoid()
	local seat = if humanoid and humanoid.Health > 0 then humanoid.SeatPart else nil
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "DriverSeat" then return nil, nil end
	local vehicle = seat.Parent
	local folder = Workspace:FindFirstChild(VehicleConfig.ActiveFolderName)
	if not vehicle or not vehicle:IsA("Model") or not folder or vehicle.Parent ~= folder
		or vehicle:GetAttribute("OwnerUserId") ~= player.UserId then return nil, nil end
	local chassis = vehicle.PrimaryPart
	if not chassis or not chassis:IsDescendantOf(vehicle) then return nil, nil end
	return vehicle, chassis
end

local function releaseCamera()
	local camera = controlledCamera
	if camera then
		camera.FieldOfView = originalFieldOfView
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = getHumanoid()
		if humanoid then camera.CameraSubject = humanoid end
	end
	controlledCamera = nil
	activeVehicle = nil
	activeChassis = nil
	rig = nil
end

local function updateCamera(dt: number)
	local vehicle, chassis = getTarget()
	local camera = Workspace.CurrentCamera
	if not camera or not vehicle or not chassis then
		if controlledCamera then releaseCamera() end
		return
	end

	local targetChanged = vehicle ~= activeVehicle or chassis ~= activeChassis or camera ~= controlledCamera
	if targetChanged then
		releaseCamera()
		controlledCamera = camera
		originalFieldOfView = camera.FieldOfView
		activeVehicle = vehicle
		activeChassis = chassis
		rig = CameraRig.create(chassis.Position, chassis.CFrame.LookVector)
		boomLength = 0
	end
	local currentRig = rig
	if not currentRig then return end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = chassis
	camera.FieldOfView = Config.FieldOfView

	local teleported = CameraRig.step(currentRig, chassis.Position, chassis.CFrame.LookVector, dt, Config)
	local desiredPosition, lookTarget = CameraRig.getView(currentRig, Config)
	-- Cast from the actual car, not the lagging anchor, so a corner cannot slip
	-- between the car and the camera. Ignore the fleet to avoid bumps from racers.
	local excluded: {Instance} = {vehicle.Parent :: Instance}
	local character = player.Character
	if character then table.insert(excluded, character) end
	castParams.FilterDescendantsInstances = excluded
	local castOrigin = chassis.Position + Vector3.yAxis * Config.FocusHeight
	local offset = desiredPosition - castOrigin
	local distance = offset.Magnitude
	if distance < 0.001 then return end
	local direction = offset / distance
	local hit = Workspace:Spherecast(castOrigin, Config.CollisionRadius, offset, castParams)
	local allowedDistance = if hit then math.max(0, hit.Distance - Config.CollisionPadding) else distance
	if targetChanged or teleported then
		boomLength = allowedDistance
	elseif allowedDistance < boomLength then
		-- Obstruction wins immediately; easing inward would travel through the wall.
		boomLength = allowedDistance
	else
		boomLength += (allowedDistance - boomLength) * CameraRig.alpha(Config.CollisionReturnResponse, dt)
	end
	local position = castOrigin + direction * boomLength
	if (lookTarget - position).Magnitude > 0.001 then
		camera.CFrame = CFrame.lookAt(position, lookTarget, Vector3.yAxis)
		camera.Focus = CFrame.new(lookTarget)
	end
end

RunService:BindToRenderStep(BINDING_NAME, Enum.RenderPriority.Camera.Value + 1, updateCamera)
script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(BINDING_NAME)
	releaseCamera()
end)
