-- The runner prepends the existing lifecycle simulator and loads real modules.
local up = {Dot = function() return 1 end}
local function point(x, y, z)
	local result = {X=x, Y=y, Z=z}
	function result:Lerp(other, alpha)
		return point(self.X+(other.X-self.X)*alpha, self.Y+(other.Y-self.Y)*alpha, self.Z+(other.Z-self.Z)*alpha)
	end
	return result
end
frameMeta.__index = function(self, key)
	if key == "UpVector" then return up end
	if key == "Rotation" then return frame(0, 0, 0, self.angle) end
	if key == "Position" then return {X=self.x, Y=self.y, Z=self.z} end
	if key == "PointToObjectSpace" then return function(a, b)
		local dx, dz = b.X-a.x, b.Z-a.z
		local c, s = math.cos(a.angle), math.sin(a.angle)
		return point(c*dx-s*dz, b.Y-a.y, s*dx+c*dz)
	end end
	if key == "ToObjectSpace" then return function(a, b)
		local dx, dz = b.x-a.x, b.z-a.z
		local c, s = math.cos(a.angle), math.sin(a.angle)
		return frame(c*dx-s*dz, b.y-a.y, s*dx+c*dz, b.angle-a.angle)
	end end
end
local function loadSource(source, name)
	local chunk = assert(loadstring(source, name))
	setfenv(chunk, environment)
	return chunk()
end
environment.Vector3 = {yAxis = up}
environment.Instance = {new = function(class)
	local item = instance(class, class)
	item.Event, item.OnServerEvent = signal(), signal()
	return setmetatable(item, {__newindex = function(self, key, value)
		rawset(self, key, value)
		if key == "Parent" and value then value.children[self.Name] = self end
	end})
end}
local raceConfig = {CheckpointFolderName="Checkpoints", FinishPartName="FinishLine", TotalLaps=3, ResetRemoteName="ResetVehicle", ResetCooldown=2}
shared.children.RaceConfig = raceConfig
parent.children.PlayerVehicleService = service
local checkpoints = instance("Folder", "Checkpoints")
checkpoints.Parent = Workspace
Workspace.children.Checkpoints = checkpoints
function checkpoints:GetChildren()
	local list = {}
	for _, child in self.children do table.insert(list, child) end
	return list
end
local markers = {}
for i=1,3 do
	local part = instance("Part", tostring(i))
	part.Parent, part.CFrame, part.Touched = checkpoints, frame(i*100, 8, 20), signal()
	part.Anchored, part.CanTouch, part.CanCollide, part.CanQuery = true, true, false, false
	checkpoints.children[part.Name] = part
	markers[i] = part
end
function vehicleService.getResetMarkerCFrame(cf) return cf end
local finish = instance("Part", "FinishLine")
finish.Parent, finish.Touched = Workspace, signal()
finish.CFrame, finish.Size = frame(1000,8,200,math.pi/2), point(100,50,2)
finish.Anchored, finish.CanTouch, finish.CanCollide, finish.CanQuery = true, true, false, false
Workspace.children.FinishLine = finish
local cp = loadSource(__CHECKPOINT_SOURCE__, "CheckpointService")
parent.children.CheckpointService = cp
local respawn = loadSource(__RESPAWN_SOURCE__, "RespawnService")
parent.children.RespawnService = respawn
local manager = instance("Script", "RaceManager")
manager.Parent = parent
environment.script = manager
local function finishStep(car, z, x, y)
	local cf = finish.CFrame
	local c, s = math.cos(cf.angle), math.sin(cf.angle)
	car.PrimaryPart.Position = point(cf.x+c*(x or 0)+s*z, cf.y+(y or 0), cf.z-s*(x or 0)+c*z)
	RunService.Heartbeat:Fire()
end
local function crossFinish(car)
	finishStep(car, 20)
	finish.Touched:Fire(car.PrimaryPart)
	finishStep(car, -20)
end
local first, second = player(101), player(202)
characterFor(first); characterFor(second)
Players.list = {first, second}
-- Component coverage deliberately drives CheckpointService directly. The real
-- RaceManager and race policies are covered by race_lifecycle.luau.
service.setRecoveryDestination(cp.getResetCFrame)
service.start()
respawn.start()
Players.PlayerAdded:Connect(cp.addRacer)
Players.PlayerRemoving:Connect(cp.removeRacer)
assert(cp.startRace(Players:GetPlayers()))
assert(cp.getLastIndex(first)==0 and cp.getLastIndex(second)==0)
local firstCar, secondCar = service.getVehicle(first), service.getVehicle(second)
firstCar.children.DriverSeat.Occupant = first.Character.children.Humanoid
secondCar.children.DriverSeat.Occupant = second.Character.children.Humanoid
local function touch(index, car) markers[index].Touched:Fire(car.PrimaryPart) end
touch(2, firstCar); touch(3, firstCar)
assert(cp.getLastIndex(first)==0, "skips must fail")
touch(1, firstCar); touch(1, firstCar)
assert(cp.getLastIndex(first)==1 and cp.getLastIndex(second)==0)
first:SetAttribute("LastCheckpoint", 99)
touch(3, firstCar)
assert(cp.getLastIndex(first)==1, "replicated attributes are not authority")
touch(2, firstCar); touch(3, firstCar); touch(1, firstCar); touch(3, firstCar)
assert(cp.getLastIndex(first)==3, "sequence must not wrap or repeat")
touch(1, secondCar)
assert(cp.getLastIndex(second)==1)
print("PASS: ordered touches, repeats/skips, independent players, spoofed attributes, terminal sequence")

local resetCalls, resetDestination = 0, nil
function vehicleService.resetOnGround(car, destination, owner)
	resetCalls += 1
	assert(car == service.getVehicle(owner))
	resetDestination = destination
	if blocked then return false end
	car.frame = destination
	return true
end
local remote = storage.children.Remotes.children.ResetVehicle
remote.OnServerEvent:Fire(first, secondCar, frame(9999, 9999, 9999), 100)
assert(resetCalls==1 and resetDestination.x==300)
remote.OnServerEvent:Fire(first)
assert(resetCalls==1, "rate limit")
markers[3].CFrame = frame(900, 8, 20)
now += 2
remote.OnServerEvent:Fire(first)
assert(resetDestination.x==300, "earned destination was snapshotted")
cp.startRace(Players:GetPlayers())
assert(cp.getLastIndex(first)==0 and cp.getLastIndex(second)==0)
now += 2
remote.OnServerEvent:Fire(second)
near(resetDestination.x, 10); near(resetDestination.z, 4)
touch(2, firstCar)
assert(cp.getLastIndex(first)==0)
touch(1, firstCar)
assert(cp.getLastIndex(first)==1, "restart reconnects exactly once")
now += 2
blocked = true
local oldFrame = firstCar.frame
assert(not respawn.requestReset(first))
assert(service.getVehicle(first)==firstCar and firstCar.frame==oldFrame)
blocked = false
now += 2
assert(respawn.requestReset(first) and resetDestination.x==100)
print("PASS: checkpoint restart, reset remote ignores payload, cooldown, spawn fallback, blocked reset")

local human = first.Character.children.Humanoid
human.Health = 0
now += 2
assert(not respawn.requestReset(first))
touch(2, firstCar)
assert(cp.getLastIndex(first)==1)
human.Health = 100
firstCar.children.DriverSeat.Occupant = second.Character.children.Humanoid
now += 2
assert(not respawn.requestReset(first))
touch(2, firstCar)
assert(cp.getLastIndex(first)==1)
firstCar.children.DriverSeat.Occupant = human
firstCar:SetAttribute("OwnerUserId", 202)
touch(2, firstCar)
now += 2
assert(not respawn.requestReset(first) and cp.getLastIndex(first)==1)
firstCar:SetAttribute("OwnerUserId", 101)
touch(2, firstCar)
assert(cp.getLastIndex(first)==2)
-- Death/replacement preserves progress, but reset targets the new owned model.
human.Died:Fire()
characterFor(first, true, false)
assert(service.getVehicle(first)==nil, "checkpoint respawn waits for character root")
first.Character.children.HumanoidRootPart = instance("Part", "HumanoidRootPart")
tick(1)
firstCar = assert(service.getVehicle(first))
near(firstCar.frame.x,200)
assert(cp.getLastIndex(first)==2 and first:GetAttribute("CheckpointCount")==3)
now += 2
assert(respawn.requestReset(first) and resetDestination.x==200)
local third = player(303)
table.insert(Players.list, third)
Players.PlayerAdded:Fire(third)
characterFor(third)
assert(cp.getLastIndex(third)==0)
Players.PlayerRemoving:Fire(third)
assert(not cp.isRacer(third) and not respawn.requestReset(third))
checkpoints.children['2'] = nil
cp.startRace(Players:GetPlayers())
assert(cp.getLastIndex(first)==2, "invalid restart must preserve current race")
checkpoints.children['2'] = markers[2]
print("PASS: eligibility, dead/wrong drivers, leave/late join, lifecycle replacement, invalid race setup")

-- Exercise server chassis crossings for laps and the existing reset/lifecycle path.
cp.startRace(Players:GetPlayers())
local function finishTouch(car) crossFinish(car) end
local function circuit(car) for index=1,3 do touch(index, car) end end
local function lapState(owner, completed, current, complete)
	local state = assert(cp.getRaceProgress(owner))
	assert(state.completedLaps==completed and state.currentLap==current and state.lapComplete==complete)
	assert(owner:GetAttribute("CompletedLaps")==completed and owner:GetAttribute("CurrentLap")==current)
	assert(owner:GetAttribute("LapComplete")==complete and owner:GetAttribute("TotalLaps")==state.totalLaps)
end
firstCar.children.DriverSeat.Occupant = first.Character.children.Humanoid
secondCar.children.DriverSeat.Occupant = second.Character.children.Humanoid
lapState(first,0,1,false)
finishTouch(firstCar); touch(3,firstCar); finishTouch(firstCar)
lapState(first,0,1,false)
first:SetAttribute("LastCheckpoint",3)
first:SetAttribute("CompletedLaps",99)
first:SetAttribute("LapComplete",true)
finishTouch(firstCar)
assert(cp.getRaceProgress(first).completedLaps==0, "attributes cannot award a lap")
local snapshot = cp.getRaceProgress(first)
snapshot.completedLaps=99
assert(cp.getRaceProgress(first).completedLaps==0, "callers cannot mutate authority")
circuit(firstCar)
local earnedFrame = cp.getResetCFrame(first)
firstCar.children.DriverSeat.Occupant = nil
finishTouch(firstCar)
assert(cp.getRaceProgress(first).completedLaps==0, "empty car cannot finish")
firstCar.children.DriverSeat.Occupant = second.Character.children.Humanoid
finishTouch(firstCar)
assert(cp.getRaceProgress(first).completedLaps==0, "wrong driver cannot finish")
firstCar.children.DriverSeat.Occupant = first.Character.children.Humanoid
firstCar:SetAttribute("OwnerUserId",202); finishTouch(firstCar)
assert(cp.getRaceProgress(first).completedLaps==0, "wrong ownership cannot finish")
firstCar:SetAttribute("OwnerUserId",101)
first.Character.children.Humanoid.Health=0; finishTouch(firstCar)
assert(cp.getRaceProgress(first).completedLaps==0, "dead owner cannot finish")
first.Character.children.Humanoid.Health=100
tick()
firstCar = assert(service.getVehicle(first))
firstCar.children.DriverSeat.Occupant = first.Character.children.Humanoid
finishStep(firstCar, 20)
finish.Touched:Fire(firstCar.PrimaryPart)
finishStep(firstCar, 0.5)
assert(cp.getRaceProgress(first).completedLaps==0, "early contact before the center plane must not award")
finishStep(firstCar, 5)
assert(cp.getRaceProgress(first).completedLaps==0, "approach and retreat must not award")
finishStep(firstCar, 5, 60); finishStep(firstCar, -5, 60)
finishStep(firstCar, -5)
finishStep(firstCar, 5)
assert(cp.getRaceProgress(first).completedLaps==0, "outside gate and reverse crossings must not award")
finishStep(firstCar, 5, 60); finishStep(firstCar, -5, 60)
finishStep(firstCar, 5, 0, 30); finishStep(firstCar, -5, 0, 30)
assert(cp.getRaceProgress(first).completedLaps==0, "crossing beside/above gate must not award")
finishStep(firstCar, 5)
firstCar:SetAttribute("ResetVersion", (firstCar:GetAttribute("ResetVersion") or 0)+1)
finishStep(firstCar, -5)
assert(cp.getRaceProgress(first).completedLaps==0, "reset teleport must not become a crossing")
finishStep(firstCar, 5)
local originalChassis = firstCar.PrimaryPart
local replacementChassis = instance("Part", "ReplacementChassis")
replacementChassis.Parent = firstCar
firstCar.PrimaryPart = replacementChassis
finishStep(firstCar, -5)
assert(cp.getRaceProgress(first).completedLaps==0, "replacement chassis cannot inherit crossing sample")
firstCar.PrimaryPart = originalChassis
finishStep(firstCar, -5)
assert(cp.getRaceProgress(first).completedLaps==0, "restoring chassis cannot inherit crossing sample")
finishStep(firstCar, 5)
cp.setRacingPredicate(function() return false end)
finishStep(firstCar, -5)
cp.setRacingPredicate(function() return true end)
finishStep(firstCar, -6)
assert(cp.getRaceProgress(first).completedLaps==0, "paused/outside-race crossing must be discarded")
print("PASS: premature touch, direction, rotated gate bounds, reset/replacement, race gating")
finishStep(firstCar, 20); finishStep(firstCar, 0); finishStep(firstCar, 0)
lapState(first,1,2,false)
finishTouch(firstCar); finishTouch(firstCar)
lapState(first,1,2,false); lapState(second,0,1,false)
assert(cp.getLastIndex(first)==0 and cp.getResetCFrame(first)==earnedFrame)
touch(3,firstCar); touch(2,firstCar); finishTouch(firstCar)
assert(cp.getLastIndex(first)==0, "checkpoint N after lap reset cannot restore N/N")
now+=2
assert(respawn.requestReset(first) and resetDestination==earnedFrame)
touch(3,firstCar); finishTouch(firstCar)
lapState(first,1,2,false)
assert(cp.getLastIndex(first)==0, "manual recovery cannot restore the old sequence")
first.Character.children.Humanoid.Died:Fire()
characterFor(first)
first.Character.children.HumanoidRootPart=instance("Part","HumanoidRootPart")
tick(1)
firstCar=assert(service.getVehicle(first))
assert(firstCar.frame==earnedFrame, "automatic recovery preserves earned destination after lap")
firstCar.children.DriverSeat.Occupant=first.Character.children.Humanoid
touch(3,firstCar); finishTouch(firstCar)
lapState(first,1,2,false)
assert(cp.getLastIndex(first)==0)
touch(1,firstCar)
assert(cp.getLastIndex(first)==1, "checkpoint 1 is required after lap reset")
touch(2,firstCar); touch(3,firstCar); finishTouch(firstCar)
lapState(first,2,3,false)
circuit(secondCar); finishTouch(secondCar)
lapState(second,1,2,false)
circuit(firstCar); finishTouch(firstCar)
lapState(first,3,3,true)
for _=1,3 do circuit(firstCar); finishTouch(firstCar) end
lapState(first,3,3,true)
assert(cp.getLastIndex(first)==3, "final completion cannot start a fourth lap")
print("PASS: valid/duplicate/invalid finishes, independent laps, final completion, manual/death recovery across lap boundary")

for _, invalid in {0,-1,1.5,math.huge,0/0,"3"} do
	raceConfig.TotalLaps=invalid
	assert(not cp.startRace({first,second}))
	assert(cp.getRaceProgress(first).completedLaps==3, "invalid config preserves race")
end
raceConfig.TotalLaps=1
finish.CanTouch=false
assert(not cp.startRace({first,second}))
assert(cp.getRaceProgress(first).completedLaps==3)
finish.CanTouch=true
cp.startRace(Players:GetPlayers())
lapState(first,0,1,false); lapState(second,0,1,false)
assert(cp.getResetCFrame(first)==nil and cp.getLastIndex(first)==0)
raceConfig.TotalLaps=5 -- In-progress races retain the captured target.
circuit(firstCar); finishTouch(firstCar); finishTouch(firstCar)
lapState(first,1,1,true)
assert(cp.getRaceProgress(first).totalLaps==1)
-- A different track count is discovered from its configured folder.
checkpoints.children['3']=nil
raceConfig.TotalLaps=2
cp.startRace(Players:GetPlayers())
assert(first:GetAttribute("CheckpointCount")==2)
touch(1,firstCar); finishTouch(firstCar)
lapState(first,0,1,false)
touch(2,firstCar); finishTouch(firstCar)
lapState(first,1,2,false)
touch(2,firstCar)
assert(cp.getLastIndex(first)==0)
touch(1,firstCar); touch(2,firstCar); finishTouch(firstCar)
lapState(first,2,2,true)
assert(cp.startRace({second}))
assert(cp.getRaceProgress(first)==nil and first:GetAttribute("CompletedLaps")==nil
	and first:GetAttribute("CheckpointCount")==nil, "omitted racers must be cleared")
checkpoints.children['3']=markers[3]
raceConfig.TotalLaps=3
cp.startRace(Players:GetPlayers())
print("PASS: configured laps/checkpoint count, target snapshot, full restart cleanup, invalid setup preserves race")

-- Exercise actual VehicleService placement with deterministic ground/overlap queries.
local vectorMeta = {}
vectorMeta.__add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectorMeta) end
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
environment.Vector3 = {yAxis=up, zero=vector(0,0,0), new=vector}
environment.CFrame = {new=function(x,y,z) if type(x)=="table" then return frame(x.X,x.Y,x.Z) end return frame(x,y,z) end}
environment.RaycastParams = {new=function() return {} end}
environment.OverlapParams = {new=function() return {} end}
environment.Enum = {RaycastFilterType={Exclude="Exclude"}}
services.ServerStorage = instance("ServerStorage", "ServerStorage")
Config.GroundProbeDistance, Config.GroundClearance, Config.ResetSeatHeight = 256, 0.25, 3
environment.script = {Parent=parent}
local physical = loadSource(__VEHICLE_SOURCE__, "VehicleService")
-- Geometry support is covered by the pre-existing Studio stationary checks.
physical.getGroundSupport = function() return 2, {} end
local car = firstCar
car.frame = frame(0, 5, 0)
function car:GetPivot() return self.frame end
function car:PivotTo(value) self.frame=value end
local chassis = car.PrimaryPart
local ownerCharacter = first.Character
ownerCharacter.frame = frame(900,8,900)
ownerCharacter.GetPivot, ownerCharacter.PivotTo = car.GetPivot, car.PivotTo
function ownerCharacter:GetDescendants() return {self.children.HumanoidRootPart} end
local seat = car.children.DriverSeat
seat.Occupant = nil -- The geometry case below starts with the owner on foot.
seat.CFrame = frame(100,3,20)
function seat:Sit(humanoid) self.Occupant = humanoid; humanoid.SeatPart = self end
chassis.CanCollide, chassis.CFrame, chassis.Size = true, car.frame, vector(4,2,8)
function car:GetDescendants() return {chassis} end
function chassis:CanSetNetworkOwnership() return true end
function chassis:SetNetworkOwner(value) assert(value==nil); self.serverOwned=true end
local noGround = false
local broadPhaseOnly = false
local lastProbe
function Workspace:GetPartsInPart(probe, params)
	lastProbe = probe
	assert(probe.Parent==Workspace and not probe.CanCollide and not probe.CanTouch)
	return if blocked then {secondCar} else {}
end
function Workspace:Raycast(position, direction, params)
	assert(params.RespectCanCollide and params.FilterDescendantsInstances[1]==folder)
	if noGround then return nil end
	return {Position=vector(position.X,0,position.Z), Normal=up}
end
function Workspace:GetPartBoundsInBox(cf, size, params)
	assert(params.FilterDescendantsInstances[1]==car)
	return if blocked or broadPhaseOnly then {secondCar} else {}
end
local lowMarker = assert(physical.getResetMarkerCFrame(frame(100,31,20)))
near(lowMarker.y, 0.25)
assert(physical.resetOnGround(car, frame(100,8,20,math.pi/2), first))
near(car.frame.x,100); near(car.frame.y,2.25); near(car.frame.angle,math.pi/2)
assert(seat.Occupant==ownerCharacter.children.Humanoid, "on-foot reset must seat owner")
near(ownerCharacter.frame.x,100)
assert(ownerCharacter.children.HumanoidRootPart.AssemblyLinearVelocity==environment.Vector3.zero)
assert(chassis.AssemblyLinearVelocity==environment.Vector3.zero and chassis.AssemblyAngularVelocity==environment.Vector3.zero)
assert(chassis.serverOwned and car:GetAttribute("ResetVersion")==1)
broadPhaseOnly = true
assert(physical.resetOnGround(car, frame(100,8,20,math.pi/2), first), "hollow mesh bounds must not block")
assert(lastProbe.destroyed, "clearance probe leaked")
broadPhaseOnly = false
local savedFrame = car.frame
blocked = true
assert(not physical.resetOnGround(car, frame(200,8,20), first) and car.frame==savedFrame)
blocked, noGround = false, true
assert(not physical.resetOnGround(car, frame(200,8,20), first) and car.frame==savedFrame)
noGround = false
-- Seated owner is transported with the model while retaining the seat and model.
car.children.DriverSeat.Occupant = first.Character.children.Humanoid
first.Character.frame = car.frame * frame(0,3,0)
first.Character.GetPivot, first.Character.PivotTo = car.GetPivot, car.PivotTo
assert(physical.resetOnGround(car, frame(200,8,20), first))
near(first.Character.frame.x, 200); near(first.Character.frame.y,5.25)
assert(service.getVehicle(first)==car and car:GetAttribute("ResetVersion")==3)
-- Preparation resets must work with a real engine-style ownership rejection
-- on anchored assemblies, retain the lock, and clear both velocity components.
chassis.Anchored = true
function chassis:CanSetNetworkOwnership() return not self.Anchored end
function chassis:SetNetworkOwner(value) assert(not self.Anchored and value==nil) end
chassis.AssemblyLinearVelocity, chassis.AssemblyAngularVelocity = vector(70,0,0), vector(0,2,0)
assert(physical.resetOnGround(car, frame(300,8,20), first))
assert(chassis.Anchored and car.frame.x==300)
assert(chassis.AssemblyLinearVelocity==environment.Vector3.zero and chassis.AssemblyAngularVelocity==environment.Vector3.zero)
chassis.Anchored = false
print("PASS: anchored grid placement preserves lock and clears coasting velocity")
print("PASS: actual ground reset, upright heading, zero velocity, server ownership, occupied/missing ground, seated rider")

-- The shared placement refactor must still create and clean up spawn copies.
local templates = instance("Folder", "VehicleTemplates")
services.ServerStorage.children.VehicleTemplates = templates
Config.TemplateFolderName, Config.TemplateName = "VehicleTemplates", "PlaceholderVehicle"
local template = instance("Model", "PlaceholderVehicle")
template.Archivable = true
templates.children.PlaceholderVehicle = template
template.PrimaryPart = chassis
template.children.Chassis = chassis
template.children.DriverSeat = car.children.DriverSeat
local lastClone
function template:Clone()
	local copy = instance("Model", "Clone")
	copy.frame = frame(0,5,0)
	copy.GetPivot, copy.PivotTo = car.GetPivot, car.PivotTo
	local part = instance("Part", "Chassis")
	part.CanCollide, part.CFrame, part.Size = true, copy.frame, vector(4,2,8)
	part.CanSetNetworkOwnership, part.SetNetworkOwner = chassis.CanSetNetworkOwnership, chassis.SetNetworkOwner
	copy.PrimaryPart = part
	function copy:GetDescendants() return {part} end
	lastClone = copy
	return copy
end
function RunService:IsStudio() return false end
function Workspace:GetPartBoundsInBox(cf, size, params)
	assert(params.FilterDescendantsInstances==nil, "new spawns cannot ignore existing vehicles")
	return if blocked then {car} else {}
end
local spawned = assert(physical.spawnOnGround(frame(500,8,20), true, second))
assert(spawned.Parent==folder and spawned:GetAttribute("OwnerUserId")==202)
near(spawned.frame.y,2.25)
blocked=true
assert(physical.spawnOnGround(frame(500,8,20),true,second)==nil and lastClone.destroyed)
blocked=false; noGround=true
assert(physical.spawnOnGround(frame(500,8,20),true,second)==nil and lastClone.destroyed)
noGround=false
local invalid = frame(0,8,0)
invalid.UpVector={Dot=function() return 0 end}
assert(not pcall(physical.spawnOnGround, invalid, true, second) and lastClone.destroyed)
print("PASS: shared ground placement preserves spawn ownership and cleans up failed copies")

-- Execute the actual controller reset prelude to catch stale steering/input.
local resetStep = loadSource(__CONTROLLER_RESET_SOURCE__, "Controller.resetPrelude")
local drive = {vehicle=car, resetVersion=0, throttle=1, steer=1, lastInput=now, yawRate=3, driveForce=5, driveMode="Drive"}
resetStep(drive)
assert(drive.throttle==0 and drive.steer==0 and drive.lastInput==-math.huge and drive.yawRate==0)
assert(drive.driveForce==0 and drive.driveMode=="Hold" and drive.resetVersion==4)
print("PASS: controller clears cached input/steering after reset")

-- Execute client input binding; requests contain no authority-bearing payload.
local inputSignal = signal()
local focused, sent = false, 0
services.UserInputService = {InputBegan=inputSignal, GetFocusedTextBox=function() return if focused then {} else nil end}
raceConfig.ResetKey = "R"
function remote:FireServer(...) assert(select('#', ...)==0); sent+=1 end
loadSource(__CLIENT_RESET_SOURCE__, "InputController.resetBinding")
inputSignal:Fire({KeyCode="R"},true)
focused=true; inputSignal:Fire({KeyCode="R"},false)
focused=false; inputSignal:Fire({KeyCode="W"},false)
assert(sent==0)
inputSignal:Fire({KeyCode="R"},false)
assert(sent==1)
print("PASS: R control sends empty request and respects typing/processed input")
