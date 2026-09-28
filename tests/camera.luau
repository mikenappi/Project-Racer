-- Minimal Roblox values; production camera code is loaded without rewriting it.
local vec = {}
local function v(x, y, z) return setmetatable({X = x, Y = y, Z = z}, vec) end
vec.__add = function(a, b) return v(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vec.__sub = function(a, b) return v(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vec.__mul = function(a, b) return v(a.X*b, a.Y*b, a.Z*b) end
vec.__div = function(a, b) return v(a.X/b, a.Y/b, a.Z/b) end
vec.__index = function(a, key)
	if key == 'Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
	if key == 'Unit' then return a / a.Magnitude end
	if key == 'Lerp' then return function(self, b, t) return self + (b-self)*t end end
end
local vectors = {new = v, yAxis = v(0,1,0)}
local function near(a, b, tolerance) assert(math.abs(a-b) < (tolerance or 0.00001), tostring(a)..' ~= '..tostring(b)) end
local function forward(yaw) return v(-math.sin(yaw), 0, -math.cos(yaw)) end
local function loadSource(source, env)
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable(env, {__index = getfenv()}))
	return chunk()
end
local config = loadSource(__CONFIG_SOURCE__, {})
local rig = loadSource(__RIG_SOURCE__, {Vector3 = vectors})
local origin = v(0,0,0)

-- A modest turn eases over time and converges identically at different FPS.
local previous
for _, fps in {30, 60, 144} do
	local state = rig.create(origin, forward(0))
	local angle = math.rad(45)
	rig.step(state, origin, forward(angle), 1/fps, config)
	assert(state.yaw > 0 and state.yaw < angle)
	for _ = 2, fps do rig.step(state, origin, forward(angle), 1/fps, config) end
	if previous then near(state.yaw, previous) end
	previous = state.yaw
	near(state.yaw, angle * (1-math.exp(-config.HeadingResponse)))
end
-- Wraparound takes the two-degree route, not a 358-degree spin.
local state = rig.create(origin, forward(math.rad(179)))
rig.step(state, origin, forward(math.rad(-179)), 1/60, config)
assert(state.yaw > math.rad(179))
-- Vertical nose retains heading; pitch/roll do not become horizon rotation.
local yaw = state.yaw
rig.step(state, origin, v(0,1,0), 1/60, config)
near(state.yaw, yaw)
-- Continuous turns in both directions remain smooth, bounded and behind.
for _, sign in {-1, 1} do
	state = rig.create(origin, forward(0))
	for i = 1, 600 do
		local targetYaw = sign * i/60 * 1.6
		local previousYaw = state.yaw
		rig.step(state, origin, forward(targetYaw), 1/60, config)
		local delta = math.atan2(math.sin(state.yaw-previousYaw), math.cos(state.yaw-previousYaw))
		assert(math.abs(delta) <= 1.6/60 + 0.00001)
		local lag = math.atan2(math.sin(targetYaw-state.yaw), math.cos(targetYaw-state.yaw))
		assert(math.abs(lag) <= math.rad(config.MaxHeadingLag))
	end
end
-- Current 1000 studs/s experimental speed must not outrun the camera.
state = rig.create(origin, forward(0))
for i = 1, 180 do
	local position = v(0,0,-1000*i/60)
	assert(not rig.step(state, position, forward(0), 1/60, config))
	assert((state.anchor-position).Magnitude <= config.MaxPositionLag + 0.00001)
end
local destination = v(2000,10,100)
assert(rig.step(state, destination, forward(1), 1/60, config))
near((state.anchor-destination).Magnitude, 0)
near(state.yaw, 1)
print('PASS: easing at 30/60/144 FPS, yaw wrap, level horizon, continuous turns, high-speed lag, teleport')

local function instance(class, name)
	local obj = {ClassName=class, Name=name, children={}, attributes={}}
	function obj:IsA(value) return value == self.ClassName end
	function obj:FindFirstChild(value) return self.children[value] end
	function obj:WaitForChild(value) return assert(self.children[value], value) end
	function obj:FindFirstChildOfClass(value)
		for _, child in self.children do if child.ClassName == value then return child end end
		return nil
	end
	function obj:GetAttribute(value) return self.attributes[value] end
	function obj:IsDescendantOf(value)
		local parent = self.Parent
		while parent do if parent == value then return true end; parent = parent.Parent end
		return false
	end
	return obj
end
local workspace = instance('Workspace', 'Workspace')
local fleet = instance('Folder', 'Vehicles')
fleet.Parent = workspace
workspace.children.Vehicles = fleet
local player = {UserId=123}
local character = instance('Model', 'Character')
character.Parent = workspace
player.Character = character
local humanoid = instance('Humanoid', 'Humanoid')
humanoid.Health = 100
character.children.Humanoid = humanoid
local function car(owner)
	local vehicle = instance('Model', 'Vehicle')
	vehicle.Parent = fleet
	vehicle.attributes.OwnerUserId = owner
	local chassis = instance('Part', 'Chassis')
	chassis.Parent, chassis.Position, chassis.CFrame = vehicle, origin, {LookVector=forward(0)}
	vehicle.PrimaryPart = chassis
	local seat = instance('VehicleSeat', 'DriverSeat')
	seat.Parent = vehicle
	return vehicle, chassis, seat
end
local own, chassis, seat = car(123)
local other, otherChassis, otherSeat = car(456)
local function newCamera(fov) return {CameraType='Custom', CameraSubject=humanoid, FieldOfView=fov} end
local camera = newCamera(70)
workspace.CurrentCamera = camera
local hitDistance
function workspace:Spherecast(start, radius, offset, params)
	near(radius, config.CollisionRadius)
	assert(params.RespectCanCollide and params.FilterDescendantsInstances[1] == fleet)
	return if hitDistance then {Distance=hitDistance} else nil
end
local callback, cleanup, binding
local run = {}
function run:BindToRenderStep(name, priority, fn) binding=name; callback=fn; assert(priority == 201) end
function run:UnbindFromRenderStep(name) assert(name==binding); callback=nil end
local shared = instance('Folder', 'shared')
shared.children.CameraConfig = config
shared.children.VehicleConfig = {ActiveFolderName='Vehicles'}
local storage = instance('ReplicatedStorage', 'ReplicatedStorage')
storage.children.shared = shared
local parent = instance('Folder', 'client')
parent.children.CameraRig = rig
local services = {Workspace=workspace, Players={LocalPlayer=player}, RunService=run, ReplicatedStorage=storage}
loadSource(__CONTROLLER_SOURCE__, {
	game={GetService=function(_, key) return services[key] end},
	script={Parent=parent, Destroying={Connect=function(_, fn) cleanup=fn end}},
	require=function(value) return value end,
	Vector3=vectors,
	CFrame={new=function(position) return {Position=position} end,
		lookAt=function(position, target, up) return {Position=position, Target=target, Up=up} end},
	RaycastParams={new=function() return {} end},
	Enum={RaycastFilterType={Exclude='Exclude'}, CameraType={Custom='Custom', Scriptable='Scriptable'}, RenderPriority={Camera={Value=200}}},
})
local function tick() callback(1/60) end
-- On foot and another owner's seat leave the default camera alone.
tick(); assert(camera.CameraType=='Custom')
humanoid.SeatPart = otherSeat
tick(); assert(camera.CameraType=='Custom')
humanoid.SeatPart = seat
tick(); assert(camera.CameraType=='Scriptable' and camera.CameraSubject==chassis)
near(camera.FieldOfView, config.FieldOfView)
near(camera.CFrame.Position.Z, config.Distance)
-- Wall pulls inward immediately, then eases outward after clearing.
hitDistance = 8
tick()
local castOrigin = origin + vectors.yAxis*config.FocusHeight
near((camera.CFrame.Position-castOrigin).Magnitude, 8-config.CollisionPadding)
hitDistance = nil
tick()
local resumedDistance = (camera.CFrame.Position-castOrigin).Magnitude
assert(resumedDistance > 7.7 and resumedDistance < 12)
-- Exit restores default camera/FOV and reentry rebinds without another callback.
humanoid.SeatPart = nil
tick(); assert(camera.CameraType=='Custom' and camera.CameraSubject==humanoid)
near(camera.FieldOfView,70)
humanoid.SeatPart = seat
tick(); assert(camera.CameraType=='Scriptable')
-- Replacing CurrentCamera restores the old one and acquires the new one.
local replacementCamera = newCamera(80)
workspace.CurrentCamera = replacementCamera
tick(); assert(camera.CameraType=='Custom' and replacementCamera.CameraType=='Scriptable')
camera = replacementCamera
-- Lost chassis, late replication and respawn recover without stale references.
own.PrimaryPart = nil
tick(); assert(camera.CameraType=='Custom'); near(camera.FieldOfView,80)
own.PrimaryPart = chassis
tick(); assert(camera.CameraType=='Scriptable')
humanoid.Health = 0
tick(); assert(camera.CameraType=='Custom')
local newCharacter = instance('Model', 'NewCharacter')
newCharacter.Parent = workspace
local newHumanoid = instance('Humanoid', 'Humanoid')
newHumanoid.Health = 100
newCharacter.children.Humanoid = newHumanoid
player.Character = newCharacter
local newCar, newChassis, newSeat = car(123)
newHumanoid.SeatPart = newSeat
tick(); assert(camera.CameraSubject==newChassis and camera.CameraType=='Scriptable')
newCar.Parent = nil
tick(); assert(camera.CameraType=='Custom' and camera.CameraSubject==newHumanoid)
newCar.Parent = fleet
tick()
newCar.attributes.OwnerUserId = 456
tick(); assert(camera.CameraType=='Custom')
newCar.attributes.OwnerUserId = 123
tick()
cleanup(); assert(callback==nil and camera.CameraType=='Custom'); near(camera.FieldOfView,80)
print('PASS: ownership, seat entry/exit, obstruction recovery, camera replacement, missing chassis, death/respawn, cleanup')
