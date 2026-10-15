-- Fixtures prepend real checkpoint, recovery, and vehicle services.
function Workspace:GetServerTimeNow() return now end
raceConfig.MinimumPlayers = 1
raceConfig.WaitingDuration, raceConfig.LoadingTimeout = 5, 30
raceConfig.LoadingRetryInterval, raceConfig.CountdownDuration = 1, 3
raceConfig.RaceTimeout, raceConfig.ResultsDuration = 300, 5
raceConfig.TotalLaps = 2
raceConfig.PlacementInterval = 0.1
raceConfig.ProgressFolderName = "RaceProgressPaths"
raceConfig.ProgressMaxSpeed, raceConfig.ProgressMaxSampleGap = 1200, 0.5
raceConfig.ProgressEntryDistance, raceConfig.ProgressSlack, raceConfig.ProgressArcRatio = 24, 2, 1.5
parent.children.TrackProgress = loadSource(__TRACK_SOURCE__, "TrackProgress")
local gateSubscriptions = {}
for _, marker in markers do
	local connect = marker.Touched.Connect
	function marker.Touched:Connect(callback)
		local connection = connect(self, callback)
		table.insert(gateSubscriptions, {connection=connection, callback=callback})
		return connection
	end
end
local clientUpdates = {{}, {}}
local newInstance = environment.Instance.new
environment.Instance.new = function(class)
	local item = newInstance(class)
	if class == "RemoteEvent" then
		function item:FireAllClients(snapshot)
			for _, received in clientUpdates do table.insert(received, table.clone(snapshot)) end
		end
	end
	return item
end
local timing = loadSource(__TIMING_SOURCE__, "RaceTiming")
shared.children.RaceTiming = timing
local placement = loadSource(__PLACEMENT_SOURCE__, "PlacementService")
parent.children.PlacementService = placement
-- Recorded finish order outranks progress and is never resorted by identity.
local activeInput = {{userId=303, completedLaps=999, checkpoint=99},
	{userId=202, completedLaps=999, checkpoint=99}}
local ranked = placement.getPositions(activeInput, {202, 101})
assert(ranked["202"] == 1 and ranked["101"] == 2 and ranked["303"] == 3)
assert(activeInput[1].userId == 303, "placement must not reorder caller data")
local tied = placement.getPositions({{userId=202, completedLaps=0, checkpoint=0},
	{userId=101, completedLaps=0, checkpoint=0}}, {})
assert(tied["101"] == 1 and tied["202"] == 2)
print("PASS: recorded finish order precedes active progress, no duplicate places, stable ties independent of input order")
local race = loadSource(__RACE_SOURCE__, "RaceService")
parent.children.RaceService = race
local first, second = player(101), player(202)
characterFor(first); characterFor(second)
Players.list = {first, second}
local transitions, cleanupCount = {}, 0
for _, name in {"Waiting", "Loading", "Countdown", "Racing", "Results"} do
	race.onEntered(name, function(snapshot)
		table.insert(transitions, snapshot.state)
		assert(not race.requestStart(), "reentrant entry cannot start another race")
		return function() cleanupCount += 1 end
	end)
end
local unsubscribe = race.onEntered("Loading", function() error("unsubscribed hook") end)
unsubscribe()
race.onEntered("Racing", function() error("intentional hook failure") end)
loadSource(__MANAGER_SOURCE__, "RaceManager")
race.start() -- Repeated startup must not install another heartbeat driver.
local replicated = storage.children.RaceState
local function expect(name)
	if name == "Countdown" or name == "Loading" or name == "Waiting" then
		assert(race.getElapsedTime() == 0)
	end
	if name == "Results" and race.getSnapshot().startedAt == 0 then
		assert(race.getElapsedTime() == 0, "aborted preparations never start timing")
	end
	assert(race.getSnapshot().state == name, race.getSnapshot().state .. " ~= " .. name)
	assert(replicated.Value == name, "durable client state must match server")
	local connected = 0
	for _, subscription in gateSubscriptions do if subscription.connection.Connected then connected += 1 end end
	if name == "Waiting" then assert(connected == 0, "gate callbacks leaked into Waiting") end
	if name == "Countdown" or name == "Racing" then assert(connected == 3, "duplicate gate subscriptions") end
end
local function click(owner, generation)
	storage.children.RaceReady.OnServerEvent:Fire(owner, generation or race.getSnapshot().raceId)
end
local function startRequest()
	for _, owner in Players:GetPlayers() do click(owner) end
	manager.children.StartRace.Event:Fire()
end
local function seat(owner)
	local car = assert(service.getVehicle(owner))
	car.children.DriverSeat.Occupant = owner.Character.children.Humanoid
	return car
end
local function lap(owner)
	local before = cp.getRaceProgress(owner).completedLaps
	local car = seat(owner)
	for i=1,3 do markers[i].Touched:Fire(car.PrimaryPart) end
	finishStep(car, 20)
	finish.Touched:Fire(car.PrimaryPart)
	finishStep(car, 0.5)
	assert(cp.getRaceProgress(owner).completedLaps == before, "contact before crossing must not finish race")
	assert(race.canDrive(owner), "vehicle must remain driveable before the line")
	finishStep(car, -20)
end
local function complete(owner)
	while not cp.getRaceProgress(owner).lapComplete do lap(owner) end
end
local function places(a, b)
	local snapshot = race.getSnapshot()
	assert(snapshot.positions["101"] == a and snapshot.positions["202"] == b, "incorrect placement")
	assert(first:GetAttribute("RacePosition") == a and second:GetAttribute("RacePosition") == b)
	assert(first:GetAttribute("RacePositionId") == snapshot.raceId)
	for _, received in clientUpdates do
		local wire = received[#received]
		assert(wire.positions["101"] == a and wire.positions["202"] == b, "subscriber placement mismatch")
	end
end
local function leave(owner)
	for i,p in Players.list do if p == owner then table.remove(Players.list,i); break end end
	Players.PlayerRemoving:Fire(owner)
end
local firstCar, secondCar = seat(first), seat(second)
function vehicleService.resetOnGround(car, destination, owner)
	if blocked or not owner.Character.children.HumanoidRootPart then return false end
	car.frame = destination
	car.children.DriverSeat.Occupant = owner.Character.children.Humanoid
	car:SetAttribute("ResetVersion", (car:GetAttribute("ResetVersion") or 0)+1)
	return true
end
expect("Waiting")
assert(race.getElapsedTime() == 0 and next(race.getSnapshot().finishTimes) == nil)
assert(not race.canDrive(first) and not cp.isRacer(first))
tick(100); expect("Waiting")
assert(not race.requestStart(), "server start cannot bypass lobby consent")
first:SetAttribute("LobbyReady", true)
assert(not race.requestStart(), "display attributes cannot ready players")
click(first); click(first); tick(100); expect("Waiting")
click(second, -1); expect("Waiting")
storage.children.RaceReady.OnServerEvent:Fire(second, "0")
expect("Waiting")
-- A client joining while others are ready must also click.
local joining = player(909)
table.insert(Players.list, joining); Players.PlayerAdded:Fire(joining)
click(second); expect("Waiting")
leave(joining); tick(); expect("Loading")
local firstId = race.getSnapshot().raceId
startRequest(); assert(race.getSnapshot().raceId == firstId)
assert(not race.markFinished(first, firstId))
tick(); expect("Countdown")
local staleGateCallback = gateSubscriptions[1].callback
markers[1].Touched:Fire(firstCar.PrimaryPart)
assert(cp.getLastIndex(first) == 0 and not respawn.requestReset(first))
startRequest(); expect("Countdown")
assert(race.getSnapshot().countdown == 3)
assert(race.getElapsedTime() == 0 and timing.getReplicatedElapsed(replicated, first) == 0)
local startDeadline = race.getSnapshot().deadline
tick(1); assert(race.getSnapshot().countdown == 2 and not race.canDrive(first))
tick(1); assert(race.getSnapshot().countdown == 1 and not race.canDrive(second))
tick(1.25); expect("Racing")
assert(race.getSnapshot().startedAt == startDeadline + 0.25, "use actual GO, not scheduled deadline")
assert(race.getElapsedTime() == 0)
for _, received in clientUpdates do
	local sequence = {}
	for _, update in received do
		if update.state == "Countdown" then table.insert(sequence, tostring(update.countdown))
		elseif update.state == "Racing" then
			assert(update.startedAt == startDeadline + 0.25 and update.raceId == firstId)
			table.insert(sequence, "GO")
		end
	end
	assert(table.concat(sequence, ",") == "3,2,1,GO")
end
tick(2)
near(race.getElapsedTime(), 2)
near(timing.getReplicatedElapsed(replicated, first), 2)
for _, received in clientUpdates do
	near(timing.getElapsed(received[#received], now), race.getElapsedTime())
end
assert(race.canDrive(first) and race.canDrive(second))
assert(not race.markFinished(first, firstId), "no finish without validated laps")
local snapshot = race.getSnapshot(); snapshot.state = "Results"
expect("Racing")
places(1, 2)
crossFinish(firstCar)
markers[3].Touched:Fire(firstCar.PrimaryPart)
crossFinish(firstCar)
assert(race.getFinishResult(first.UserId, firstId) == nil, "early/skipped crossings cannot finish")
assert(cp.getRaceProgress(first).completedLaps == 0)
markers[1].Touched:Fire(secondCar.PrimaryPart); tick(); places(2, 1)
markers[1].Touched:Fire(firstCar.PrimaryPart); tick(); places(1, 2)
markers[2].Touched:Fire(secondCar.PrimaryPart); tick(); places(2, 1)
assert(respawn.requestReset(second)); tick(); places(2, 1)
lap(second); tick(); places(2, 1)
assert(cp.getRaceProgress(second).completedLaps == 1 and cp.getLastIndex(second) == 0)
assert(not race.markFinished(second, firstId) and race.getFinishResult(second.UserId, firstId) == nil,
	"a valid non-final lap is not a finish")
markers[2].Touched:Fire(firstCar.PrimaryPart)
markers[3].Touched:Fire(firstCar.PrimaryPart); tick(); places(2, 1)
first:SetAttribute("CompletedLaps", 999); first:SetAttribute("LastCheckpoint", 999)
tick(); places(2, 1)
local altered = race.getSnapshot(); altered.positions["101"] = 99
places(2, 1)
print("PASS: two racers checkpoint/lap precedence, stable ties, reset and spoof resistance, detached positions, both subscribers")
local third = player(303)
table.insert(Players.list, third); Players.PlayerAdded:Fire(third); characterFor(third)
assert(not cp.isRacer(third) and not race.canDrive(third), "late join waits")
first:SetAttribute("LapComplete", true)
assert(not race.markFinished(first, firstId), "display spoof cannot finish")
assert(respawn.requestReset(first))
local setFirstAttribute = first.SetAttribute
local observedFinishCommit = false
function first:SetAttribute(key, value)
	if key == "RaceFinishPosition" and value ~= nil then
		local snapshot = race.getSnapshot()
		local result = assert(snapshot.finishResults[tostring(self.UserId)])
		assert(not race.canDrive(self) and result.finished)
		assert(result.position == value and snapshot.finishOrder[value] == self.UserId)
		assert(snapshot.finishTimes[tostring(self.UserId)] == result.elapsedTime)
		assert(not race.markFinished(self, snapshot.raceId), "observer cannot reenter finish commit")
		observedFinishCommit = true
	end
	setFirstAttribute(self, key, value)
end
complete(first); tick()
first.SetAttribute = setFirstAttribute
assert(observedFinishCommit, "all authoritative fields committed before display notification")
expect("Racing")
assert(not race.canDrive(first) and race.canDrive(second), "first finisher does not end everyone")
assert(race.canCoast(first) and not race.canCoast(second), "only the finished racer coasts")
places(1, 2)
assert(first:GetAttribute("RaceFinishPosition") == 1)
local firstTime = assert(race.getFinishTime(first.UserId, firstId))
local firstResult = assert(race.getFinishResult(first.UserId, firstId))
assert(table.isfrozen(firstResult) and firstResult.finished and firstResult.raceId == firstId)
assert(firstResult.userId == first.UserId and firstResult.position == 1 and firstResult.elapsedTime == firstTime)
assert(not pcall(function() firstResult.position = 99 end), "results must be immutable")
local resultSnapshot = race.getSnapshot()
resultSnapshot.finishResults["101"] = nil
assert(race.getFinishResult(first.UserId, firstId) == firstResult)
assert(race.getFinishResult(first.UserId, firstId - 1) == nil)
assert(not respawn.requestReset(first), "finished racers cannot request reset")
first.Character.children.Humanoid.Died:Fire()
characterFor(first)
firstCar = seat(first)
for i=1,3 do markers[i].Touched:Fire(firstCar.PrimaryPart) end
crossFinish(firstCar)
assert(cp.getRaceProgress(first).completedLaps == raceConfig.TotalLaps)
assert(race.getFinishResult(first.UserId, firstId) == firstResult,
	"death/replacement and later crossings cannot change a result")
for _, received in clientUpdates do
	local payload = received[#received]
	local result = payload.finishResults[tostring(first.UserId)]
	assert(result.finished and result.position == 1 and result.elapsedTime == firstTime and result.raceId == firstId)
	assert(payload.finishTimes[tostring(first.UserId)] == firstTime, "wire keys must be strings")
	near(timing.getElapsed(payload, now + 10, first.UserId), firstTime)
	assert(timing.getElapsed(payload, now + 10, second.UserId) > firstTime)
end
near(firstTime, now - race.getSnapshot().startedAt)
local detached = race.getSnapshot()
detached.finishTimes[tostring(first.UserId)] = -1
detached.finishOrder[1] = 999
tick(2)
assert(race.getFinishTime(first.UserId, firstId) == firstTime)
near(timing.getReplicatedElapsed(replicated, first), firstTime)
assert(timing.getReplicatedElapsed(replicated, second) > firstTime)
assert(not race.markFinished(first, firstId), "duplicate finish rejected")
assert(race.getFinishTime(first.UserId, firstId) == firstTime)
complete(second); tick(); expect("Results")
local secondTime = assert(race.getFinishTime(second.UserId, firstId))
assert(secondTime > firstTime)
places(1, 2)
assert(second:GetAttribute("RaceFinishPosition") == 2)
assert(race.getSnapshot().finishOrder[1] == first.UserId and #race.getSnapshot().finishOrder == 2)
local finalElapsed = race.getElapsedTime()
tick(1)
assert(race.getElapsedTime() == finalElapsed)
assert(timing.getReplicatedElapsed(replicated, first) == firstTime)
assert(timing.getReplicatedElapsed(replicated, second) == secondTime)
startRequest(); expect("Results")
assert(not race.canDrive(second) and not respawn.requestReset(second))
assert(cp.getRaceProgress(first).lapComplete, "results retains final progress")
tick(5); expect("Waiting")
assert(cp.getRaceProgress(first) == nil and cp.getResetCFrame(first) == nil)
assert(first:GetAttribute("ResetStatus") == nil and first:GetAttribute("RaceParticipant") == nil)
assert(race.getElapsedTime() == 0 and next(race.getSnapshot().finishTimes) == nil)
assert(race.getFinishTime(first.UserId, firstId) == nil)
assert(race.getFinishResult(first.UserId, firstId) == nil and next(race.getSnapshot().finishResults) == nil)
assert(firstResult.position == 1 and firstResult.elapsedTime == firstTime, "retained record stays immutable after cleanup")
assert(first:GetAttribute("RaceFinishTime") == nil and second:GetAttribute("RaceFinishId") == nil)
assert(next(race.getSnapshot().positions) == nil and #race.getSnapshot().finishOrder == 0)
assert(first:GetAttribute("RacePosition") == nil and first:GetAttribute("RaceFinishPosition") == nil)
assert(cleanupCount == 4)
assert(table.concat(transitions, ",") == "Loading,Countdown,Racing,Results,Waiting")

tick(100); expect("Waiting")
assert(first:GetAttribute("LobbyReady") == false and second:GetAttribute("LobbyReady") == false)
click(first, firstId - 1); click(second, firstId - 1)
assert(not race.requestStart(), "old clicks cannot ready the next lobby")
print("PASS: lobby waits indefinitely, requires every client, rejects spoofed/duplicate/stale clicks, handles joins/leaves, resets each race")

-- A second complete lifecycle reuses one manager and one callback per gate.
firstCar.frame = frame(999, 8, 999)
secondCar.frame = frame(-999, 8, -999)
firstCar.children.DriverSeat.Occupant = nil
first.Character.children.Humanoid.SeatPart = nil
seat(third); startRequest(); expect("Loading")
local secondId = race.getSnapshot().raceId
assert(secondId == firstId + 1)
tick(); expect("Countdown")
near(firstCar.frame.x, 10); near(firstCar.frame.z, 20)
near(secondCar.frame.x, 10); near(secondCar.frame.z, 4)
near(firstCar.frame.angle, math.pi/2)
assert(firstCar.children.DriverSeat.Occupant == first.Character.children.Humanoid)
tick(3); expect("Racing")
assert(race.getElapsedTime() == 0 and next(race.getSnapshot().finishTimes) == nil)
assert(timing.getReplicatedElapsed(replicated, first) == 0)
assert(cp.getLastIndex(first) == 0 and cp.getRaceProgress(first).completedLaps == 0)
staleGateCallback(firstCar.PrimaryPart)
assert(cp.getLastIndex(first) == 0, "queued prior-race callback cannot advance new race")
places(1, 2)
assert(race.getSnapshot().positions["303"] == 3)
assert(cp.isRacer(third) and race.canDrive(third))
assert(not race.markFinished(first, firstId), "old-generation callbacks cannot finish new race")
assert(respawn.requestReset(first), "cooldown cleared for new race")
complete(first); complete(second); complete(third); tick(); expect("Results")
tick(5); expect("Waiting")
assert(cleanupCount == 9)
print("PASS: real manager, two full races, hooks/cleanup, durable state, late join, reset and progress gates, finish validation")

-- Departures in Loading/Countdown/Racing and empty server all terminate.
startRequest(); expect("Loading")
leave(first); leave(second); leave(third); tick(); expect("Results")
tick(5); expect("Waiting"); tick(100)
expect("Waiting"); assert(not race.requestStart())
Players.list = {first}; Players.PlayerAdded:Fire(first); characterFor(first); firstCar = seat(first)
startRequest(); tick(); expect("Countdown")
leave(first); tick(); expect("Results"); tick(5)
Players.list = {first, second}; Players.PlayerAdded:Fire(first); Players.PlayerAdded:Fire(second)
characterFor(first); characterFor(second); firstCar = seat(first); secondCar = seat(second)
startRequest(); tick(); tick(3); expect("Racing")
complete(first); tick()
local departedResult = race.getFinishResult(first.UserId, race.getSnapshot().raceId)
local departedTime = race.getFinishTime(first.UserId, race.getSnapshot().raceId)
leave(first)
assert(race.getSnapshot().positions["101"] == 1 and race.getSnapshot().positions["202"] == 2)
complete(second); tick(); expect("Results")
assert(race.getSnapshot().finishOrder[2] == second.UserId)
leave(second)
assert(race.getFinishResult(first.UserId, race.getSnapshot().raceId) == departedResult)
assert(race.getFinishTime(first.UserId, race.getSnapshot().raceId) == departedTime)
tick(5)
Players.list = {first}; Players.PlayerAdded:Fire(first); characterFor(first); firstCar = seat(first)
print("PASS: departures in preparation/countdown/racing and empty-race handling")

-- A bad track and an unready player cannot strand Loading; racing has a deadline.
checkpoints.children['2'] = nil
startRequest(); tick(); expect("Loading"); tick(30); expect("Results"); tick(5)
checkpoints.children['2'] = markers[2]
firstCar.children.DriverSeat.Occupant = nil
first.Character.children.HumanoidRootPart = nil
startRequest(); tick(); expect("Loading"); tick(30); expect("Results"); tick(5)
first.Character.children.HumanoidRootPart = instance("Part", "HumanoidRootPart")
seat(first); startRequest(); tick(); tick(3); expect("Racing")
tick(300); expect("Results")
assert(string.find(race.getSnapshot().reason, "timed out"))
assert(race.getFinishTime(first.UserId, race.getSnapshot().raceId) == nil, "DNF is not a finish")
assert(next(race.getSnapshot().finishResults) == nil)
assert(#race.getSnapshot().finishOrder == 0 and first:GetAttribute("RaceFinishPosition") == nil)
near(race.getElapsedTime(), 300)
tick(1); near(race.getElapsedTime(), 300)
print("PASS: GO timer, shared client origin, separate immutable finishes, duplicates, detached records, departure retention, DNF, Results freeze, next-race reset")
tick(5); expect("Waiting")
print("PASS: invalid track, readiness timeout, race timeout, clean retry")

-- Missing/insufficient slots abort explicitly instead of dropping that racer.
local savedOrigin = Workspace.children.PlaceholderVehicleSpawn
Workspace.children.PlaceholderVehicleSpawn = nil
startRequest(); tick(); expect("Results")
assert(string.find(race.getSnapshot().reason, "Grid unavailable"))
Workspace.children.PlaceholderVehicleSpawn = savedOrigin
tick(5)
local authored = instance("Folder", "VehicleSpawns")
Workspace.children.VehicleSpawns = authored
startRequest(); tick(); expect("Results")
assert(string.find(race.getSnapshot().reason, "insufficient slots"))
Workspace.children.VehicleSpawns = nil
tick(5)
local fourth = player(404)
for _, owner in {second, third, fourth} do
	table.insert(Players.list, owner); Players.PlayerAdded:Fire(owner); characterFor(owner)
end
assert(service.getVehicle(fourth)==nil, "fourth fallback slot exceeds verified capacity")
startRequest(); tick(); expect("Results")
assert(string.find(race.getSnapshot().reason, "insufficient slots"))
leave(second); leave(third); leave(fourth)
tick(5)
blocked = true
startRequest(); tick(); expect("Loading"); tick(30); expect("Results")
assert(string.find(race.getSnapshot().reason, "Grid placement timed out"))
blocked = false
tick(5)
-- Restore a completed race before the controller's coasting assertions.
startRequest(); tick(); tick(3); complete(first); tick(); expect("Results"); tick(5)
print("PASS: missing origin, insufficient authored/fallback slots, blocked grid failure, successful retry")

-- Run actual controller gate and input callback. No copied policy implementation.
environment.RaceService = race
environment.Players = Players
environment.Vector3.zero = {}
function Players:GetPlayerByUserId(id) for _, p in self.list do if p.UserId==id then return p end end end
local gate = loadSource(__DRIVE_GATE_SOURCE__, "VehicleController.gate")
local drive = {vehicle=firstCar, chassis=firstCar.PrimaryPart, velocity={}, angular={}, resetVersion=0,
	throttle=1, steer=1, lastInput=now, yawRate=5, driveForce=5, driveMode="Drive"}
gate(drive)
assert(not drive.chassis.Anchored and drive.throttle==0, "previous DNF coasts through Waiting")
assert(drive.lastInput == -math.huge)
function drive.chassis:CanSetNetworkOwnership() return true end
function drive.chassis:SetNetworkOwner(owner) assert(owner==nil); self.serverOwned=true end
environment.states = {[firstCar.children.DriverSeat]=drive}
environment.getDriver = function() return first end
environment.finiteNumber = function(n) return type(n)=="number" end
environment.Config = {InputMinReceiveInterval=0.01, InputDeadzone=0.05}
environment.typeof = function(value) return if value == firstCar.children.DriverSeat then "Instance" else typeof(value) end
local input = loadSource(__INPUT_GATE_SOURCE__, "VehicleController.input")
input(first, firstCar.children.DriverSeat, 1, 1)
assert(drive.throttle==0, "waiting rejects remote input")
startRequest(); tick(); gate(drive); expect("Countdown")
assert(drive.chassis.Anchored)
for i = 1, 2 do
	input(first, firstCar.children.DriverSeat, 1, 1)
	gate(drive)
	assert(drive.throttle == 0 and drive.steer == 0 and drive.chassis.Anchored)
	tick(1)
end
input(first, firstCar.children.DriverSeat, 1, 1)
tick(1); gate(drive); expect("Racing")
assert(not drive.chassis.Anchored and drive.chassis.serverOwned)
input(first, firstCar.children.DriverSeat, 1, 1)
assert(drive.throttle==1 and drive.steer==1, "held controls accepted immediately after GO")
local momentum, spin = {speed=70}, {yaw=2}
drive.chassis.AssemblyLinearVelocity, drive.chassis.AssemblyAngularVelocity = momentum, spin
complete(first); tick(); gate(drive); expect("Results")
assert(race.canCoast(first) and not race.canDrive(first))
assert(not drive.chassis.Anchored and drive.throttle==0 and drive.steer==0)
assert(drive.chassis.AssemblyLinearVelocity==momentum and drive.chassis.AssemblyAngularVelocity==spin,
    "finishing must preserve momentum")
input(first, firstCar.children.DriverSeat, 1, 1)
assert(drive.throttle==0, "finished racer cannot accelerate")
tick(5); gate(drive); expect("Waiting")
assert(not drive.chassis.Anchored and race.canCoast(first), "coast through intermission")
startRequest(); gate(drive)
assert(drive.chassis.Anchored and not race.canCoast(first), "new race restores preparation lock")
tick(); tick(3); expect("Racing")
gate(drive)
drive.chassis.AssemblyLinearVelocity = momentum
tick(300); gate(drive); expect("Results")
assert(not drive.chassis.Anchored and drive.chassis.AssemblyLinearVelocity==momentum, "DNF also coasts")
print("PASS: completion and timeout preserve momentum, input remains disabled, next race relocks")
print("PASS: controller locks/releases physics and clears cached input; remote gate rejects early driving")

-- Exercise the actual target/force selection, including expired input and overspeed.
environment.Config.CoastDeceleration, environment.Config.Braking = 6, 90
environment.Config.StopSpeed = 0.25
environment.Config.MaxForwardSpeed, environment.Config.MaxReverseSpeed = 100, 30
local coastTarget = loadSource(__COAST_SOURCE__, "VehicleController.coastTarget")
for _, speed in {70, 150, -40} do
	local mode, force, target = coastTarget(drive, speed, false, true, 1/60)
	assert(mode=="Coast" and force==6 and target==0, "post-race motion must use gentle coast force")
end
local mode, force = coastTarget(drive, 70, false, false, 1/60)
assert(mode=="Hold" and force==90, "ordinary missing input must retain safety braking")
print("PASS: post-race coasting uses existing deceleration even after input timeout or overspeed")

-- Every race has at most one GO, and an aborted countdown can never emit GO later.
local starts = {}
for i, snapshot in clientUpdates[1] do
	local other = clientUpdates[2][i]
	assert(other.state == snapshot.state and other.raceId == snapshot.raceId
		and other.countdown == snapshot.countdown and other.startedAt == snapshot.startedAt)
	if snapshot.state == "Racing" and (i == 1 or clientUpdates[1][i-1].state ~= "Racing") then
		assert(not starts[snapshot.raceId], "duplicate race start")
		starts[snapshot.raceId] = true
	end
end
assert(not starts[4], "departed countdown must not start after cancellation")
assert(starts[firstId] and starts[secondId], "fresh countdown must start both races")
print("PASS: identical two-subscriber countdown/GO payloads, one start per generation, cancellation without stale GO")

-- Exercise the actual HUD function, including a subscriber arriving mid-countdown.
environment.raceState, environment.player, environment.Workspace = replicated, first, Workspace
environment.countdownLabel = {}
environment.Config.GoDisplayDuration = 1
local showCountdown = loadSource(__COUNTDOWN_UI_SOURCE__, "RaceHUD.countdown")
first:SetAttribute("RaceParticipant", true)
replicated.Value = "Countdown"; replicated:SetAttribute("Countdown", 2)
showCountdown(); assert(environment.countdownLabel.Text == "2")
now += 100; showCountdown(); assert(environment.countdownLabel.Text == "2", "client cannot predict GO")
replicated.Value = "Racing"; replicated:SetAttribute("StartedAt", now)
showCountdown(); assert(environment.countdownLabel.Text == "GO")
now += 1; showCountdown(); assert(environment.countdownLabel.Text == "")
replicated.Value = "Countdown"; replicated:SetAttribute("Countdown", 3)
showCountdown(); assert(environment.countdownLabel.Text == "3", "new countdown replaces old GO")
replicated.Value = "Results"; showCountdown(); assert(environment.countdownLabel.Text == "")
first:SetAttribute("RaceParticipant", nil)
replicated.Value = "Countdown"; showCountdown(); assert(environment.countdownLabel.Text == "")
print("PASS: actual HUD countdown, server-only GO, expiry, restart, cancellation, spectator hiding")

-- Two final crossings in the same physics sample use the existing observation tie policy.
tick(5); expect("Waiting")
Players.list = {second, first}
Players.PlayerAdded:Fire(second); characterFor(second)
firstCar, secondCar = seat(first), seat(second)
startRequest(); tick(); tick(3); expect("Racing")
lap(first); lap(second)
for _, car in {secondCar, firstCar} do
	for i=1,3 do markers[i].Touched:Fire(car.PrimaryPart) end
	finishStep(car, 20)
end
for _, car in {secondCar, firstCar} do
	local cf = finish.CFrame
	car.PrimaryPart.Position = point(cf.x + math.sin(cf.angle)*-20, cf.y, cf.z + math.cos(cf.angle)*-20)
end
tick(); tick(); expect("Results")
local simultaneous = race.getSnapshot()
assert(#simultaneous.finishOrder == 2 and simultaneous.finishOrder[1] == first.UserId)
assert(simultaneous.finishResults["101"].position == 1 and simultaneous.finishResults["202"].position == 2)
assert(simultaneous.finishResults["101"].elapsedTime == simultaneous.finishResults["202"].elapsedTime)
assert(not race.markFinished(first, simultaneous.raceId) and not race.markFinished(second, simultaneous.raceId))
assert(#race.getSnapshot().finishOrder == 2)
print("PASS: immutable atomic finish records, recovery/replacement protection, non-final/early rejection, simultaneous unique stable order")

-- Real RaceService + projection + ranking, with an authored test route replacing
-- only Studio asset loading. No progression/ranking implementation is mocked.
tick(5); expect("Waiting")
local track = parent.children.TrackProgress
local route = assert(track.build({point(0,0,0),point(100,0,0)},2))
track.load = function() return {[0]=route,[1]=route,[2]=route,[3]=route}, "Continuous" end
startRequest(); tick(); tick(3); expect("Racing")
firstCar, secondCar = seat(first), seat(second)
firstCar.PrimaryPart.Position, secondCar.PrimaryPart.Position = point(0,0,0), point(0,0,0)
tick(0.11)
firstCar.PrimaryPart.Position, secondCar.PrimaryPart.Position = point(8,0,0), point(6,0,0)
tick(0.11); places(1,2)
firstCar.PrimaryPart.Position, secondCar.PrimaryPart.Position = point(12,0,0), point(15,0,0)
tick(0.11); places(2,1)
assert(cp.getLastIndex(first)==0 and cp.getLastIndex(second)==0)
local messages = #clientUpdates[1]
tick(0.11); tick(0.11)
assert(#clientUpdates[1]==messages,"unchanged ranks must not send frame traffic")
firstCar:SetAttribute("ResetVersion",(firstCar:GetAttribute("ResetVersion") or 0)+1)
firstCar.PrimaryPart.Position=point(0,0,0)
tick(0.11); places(2,1)
secondCar:SetAttribute("ResetVersion",(secondCar:GetAttribute("ResetVersion") or 0)+1)
secondCar.PrimaryPart.Position=point(90,0,0)
tick(0.11); places(1,2)
assert(cp.getLastIndex(second)==0,"teleport cannot award a checkpoint")
secondCar.PrimaryPart.Position=point(0,0,0)
tick(0.11)
secondCar.PrimaryPart.Position=point(6,0,0)
tick(0.11); places(2,1)
leave(second); tick(0.11)
assert(race.getSnapshot().positions["101"]==1 and race.getSnapshot().positions["202"]==nil)
tick(300); expect("Results"); tick(5); expect("Waiting")
assert(next(race.getSnapshot().positions)==nil)
startRequest(); tick(); tick(3); expect("Racing")
firstCar.PrimaryPart.Position=point(0,0,0)
tick(0.11)
assert(cp.getLastIndex(first)==0 and race.getSnapshot().positions["101"]==1)
print("PASS: integrated continuous overtakes, changed-only replication, reset/teleport invalidation, departure and restart")
