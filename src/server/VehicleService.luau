--!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehicleConfig = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = {}

-- Distance from the pivot to the lowest colliders when upright, plus those
-- supporting parts. This works for the original chassis and the taller wheels.
function VehicleService.getGroundSupport(vehicle: Model): (number, {BasePart})
	local lowest = math.huge
	local bottoms: {[BasePart]: number} = {}
	local pivot = vehicle:GetPivot()
	for _, part in vehicle:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			local relative = pivot:ToObjectSpace(part.CFrame)
			local halfHeight = (math.abs(relative.RightVector.Y) * part.Size.X
				+ math.abs(relative.UpVector.Y) * part.Size.Y
				+ math.abs(relative.LookVector.Y) * part.Size.Z) / 2
			local bottom = relative.Position.Y - halfHeight
			bottoms[part] = bottom
			lowest = math.min(lowest, bottom)
		end
	end
	assert(lowest < math.huge, "Vehicle must contain a collidable part.")
	local supports: {BasePart} = {}
	for part, bottom in bottoms do
		if math.abs(bottom - lowest) < 0.05 then
			table.insert(supports, part)
		end
	end
	return -lowest, supports
end

local function getTemplate(): Model
	local templates = ServerStorage:FindFirstChild(VehicleConfig.TemplateFolderName)
	local template = if templates then templates:FindFirstChild(VehicleConfig.TemplateName) else nil
	assert(template and template:IsA("Model"), "Run tools/SetupPlaceholderVehicle.luau in Studio edit mode first.")
	assert(template.Archivable, "PlaceholderVehicle must be Archivable.")
	local chassis = template:FindFirstChild("Chassis")
	assert(chassis and chassis:IsA("BasePart"), "PlaceholderVehicle needs a Chassis BasePart.")
	assert(template.PrimaryPart == chassis, "PlaceholderVehicle.PrimaryPart must be Chassis.")
	local seat = template:FindFirstChild("DriverSeat")
	assert(seat and seat:IsA("VehicleSeat"), "PlaceholderVehicle needs a DriverSeat VehicleSeat.")
	return template
end

local function getActiveFolder(): Folder
	local existing = Workspace:FindFirstChild(VehicleConfig.ActiveFolderName)
	if existing then
		assert(existing:IsA("Folder"), "Workspace.Vehicles must be a Folder.")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = VehicleConfig.ActiveFolderName
	folder.Parent = Workspace
	return folder
end

-- spawnCFrame is the chassis center; its LookVector is the vehicle's forward direction.
function VehicleService.spawn(spawnCFrame: CFrame): Model
	local template = getTemplate()
	local folder = getActiveFolder()
	local vehicle = template:Clone()
	vehicle:PivotTo(spawnCFrame)
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle.Parent = folder
	-- Keep this passive physics fixture server-owned until vehicle controls define ownership.
	local chassis = vehicle.PrimaryPart
	assert(chassis)
	chassis:SetNetworkOwner(nil)
	return vehicle
end

-- The marker must be above a clear, flat surface and rotated only around world Y.
function VehicleService.spawnOnGround(markerCFrame: CFrame): Model?
	assert(markerCFrame.UpVector:Dot(Vector3.yAxis) > 0.999, "Vehicle spawn markers must be upright.")
	local template = getTemplate()
	local chassis = template.PrimaryPart
	assert(chassis)
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = {getActiveFolder()}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ground = Workspace:Raycast(
		markerCFrame.Position,
		Vector3.new(0, -VehicleConfig.GroundProbeDistance, 0),
		params
	)
	if not ground or ground.Normal:Dot(Vector3.yAxis) < 0.99 then
		warn("PlaceholderVehicle needs a flat, collidable surface below the spawn marker.")
		return nil
	end

	local groundOffset = VehicleService.getGroundSupport(template)
	local position = ground.Position + Vector3.new(0, groundOffset + VehicleConfig.GroundClearance, 0)
	local spawnCFrame = CFrame.new(position) * markerCFrame.Rotation
	local overlapParams = OverlapParams.new()
	overlapParams.RespectCanCollide = true
	for _, part in template:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			local partCFrame = spawnCFrame * template:GetPivot():ToObjectSpace(part.CFrame)
			if #Workspace:GetPartBoundsInBox(partCFrame, part.Size, overlapParams) > 0 then
				warn("PlaceholderVehicle spawn is occupied. Move the marker or remove the previous vehicle.")
				return nil
			end
		end
	end
	return VehicleService.spawn(spawnCFrame)
end

return VehicleService
