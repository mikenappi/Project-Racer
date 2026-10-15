--!strict
-- Versioned replacement for Workspace["Anti-Gravity"].Script.
-- Keep this template in Git; the imported Workspace script is not a Script Sync root.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local zone = script.Parent
assert(zone:IsA("BasePart"), "Anti-gravity script must be inside its zone part")

local UPDATE_INTERVAL = 0.1
local LIFT_ACCELERATION = 196.175 -- Preserve the imported zone's tuning.
local candidates: {[BasePart]: boolean} = {}
local forces: {[BasePart]: BodyForce} = {}
local connections: {RBXScriptConnection} = {}
local elapsed, stopped = 0, false
-- Preserve the imported script's supported part classes and world-axis bounds.
local classes = {Part=true, TrussPart=true, Seat=true, VehicleSeat=true, SpawnLocation=true}

local function removeForce(part: BasePart)
	local force = forces[part]
	if force then force:Destroy(); forces[part] = nil end
end

local function remember(instance: Instance)
	if instance ~= zone and instance:IsA("BasePart") and classes[instance.ClassName] then
		candidates[instance] = true
	end
end

local function inside(part: BasePart): boolean
	local offset, half = part.Position - zone.Position, zone.Size / 2
	return math.abs(offset.X) < half.X and math.abs(offset.Y) < half.Y and math.abs(offset.Z) < half.Z
end

local function stop()
	if stopped then return end
	stopped = true
	for _, connection in connections do connection:Disconnect() end
	for part in forces do removeForce(part) end
	table.clear(candidates)
end

-- One initial enumeration; streaming/spawning changes update the cache by events.
table.insert(connections, Workspace.DescendantAdded:Connect(remember))
table.insert(connections, Workspace.DescendantRemoving:Connect(function(instance)
	if instance:IsA("BasePart") then
		candidates[instance] = nil
		removeForce(instance)
	end
end))
for _, instance in Workspace:GetDescendants() do remember(instance) end
table.insert(connections, script.Destroying:Connect(stop))
table.insert(connections, zone.Destroying:Connect(stop))
table.insert(connections, script:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not script.Enabled then stop() end
end))
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if stopped then return end
	if not zone:IsDescendantOf(Workspace) then stop(); return end
	elapsed += dt
	if elapsed < UPDATE_INTERVAL then return end
	elapsed = 0 -- No catch-up bursts after a slow frame.
	for part in candidates do
		if not part.Anchored and inside(part) then
			local force = forces[part]
			if force and force.Parent ~= part then removeForce(part); force = nil end
			if not force and not part:FindFirstChildOfClass("BodyForce") then
				force = Instance.new("BodyForce")
				force.Name = "RaceAntiGravityForce"
				force.Parent = part
				forces[part] = force
			end
			if force then force.Force = Vector3.new(0, part:GetMass() * LIFT_ACCELERATION, 0) end
		else
			removeForce(part)
		end
	end
end))
