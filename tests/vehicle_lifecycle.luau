-- Small event/instance simulation. run_vehicle_lifecycle.py embeds the actual
-- service source; no production lifecycle logic is copied into these tests.
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = {Connected = true}
			function connection:Disconnect() self.Connected = false end
			table.insert(listeners, {connection, callback})
			return connection
		end,
		Fire = function(_, ...)
			for _, entry in table.clone(listeners) do
				if entry[1].Connected then entry[2](...) end
			end
		end,
	}
end

local function instance(class, name)
	local result = {ClassName = class, Name = name, children = {}, attributes = {}}
	function result:IsA(expected) return self.ClassName == expected or (self.ClassName == "Part" and expected == "BasePart") end
	function result:FindFirstChild(key) return self.children[key] end
	function result:WaitForChild(key) return assert(self.children[key], key) end
	function result:FindFirstChildOfClass(key)
		for _, child in self.children do if child.ClassName == key then return child end end
		return nil
	end
	function result:IsDescendantOf(parent)
		local current = self.Parent
		while current do
			if current == parent then return true end
			current = current.Parent
		end
		return false
	end
	function result:SetAttribute(key, value) self.attributes[key] = value end
	function result:GetAttribute(key) return self.attributes[key] end
	function result:Destroy() self.Parent = nil; self.destroyed = true end
	return result
end

local frameMeta = {}
frameMeta.__mul = function(a, b)
	local c, s = math.cos(a.angle), math.sin(a.angle)
	return setmetatable({x = a.x + c*b.x + s*b.z, y = a.y + b.y,
		z = a.z - s*b.x + c*b.z, angle = a.angle + b.angle}, frameMeta)
end
local function frame(x, y, z, angle)
	return setmetatable({x = x, y = y, z = z, angle = angle or 0}, frameMeta)
end
local function near(a, b) assert(math.abs(a - b) < 0.001, tostring(a) .. " ~= " .. tostring(b)) end

local Workspace = instance("Workspace", "Workspace")
Workspace.FallenPartsDestroyHeight = -500
local folder = instance("Folder", "Vehicles")
folder.Parent = Workspace
Workspace.children.Vehicles = folder
local marker = instance("Part", "PlaceholderVehicleSpawn")
marker.CFrame = frame(10, 8, 20, math.pi / 2)
Workspace.children.PlaceholderVehicleSpawn = marker

local Players = {PlayerAdded = signal(), PlayerRemoving = signal(), list = {}}
function Players:GetPlayers() return table.clone(self.list) end
local RunService = {Heartbeat = signal()}
local now, warningCount, attempts = 0, 0, 0
local cars = {}
local blocked, assetError = false, false
local Config = {
	PlayerVehiclesEnabled = true, SpawnFolderName = "VehicleSpawns",
	TestSpawnName = "PlaceholderVehicleSpawn", ActiveFolderName = "Vehicles",
	SpawnColumns = 3, SpawnSpacing = {X = 16, Z = 20},
	SpawnRetryInterval = 1, VehicleRecoveryHeight = 50,
}
local vehicleService = {}
function vehicleService.spawnOnGround(spawnFrame, enabled, owner)
	attempts += 1
	if assetError then error("Missing template") end
	if blocked then return nil end
	assert(enabled and owner)
	local vehicle = instance("Model", "Vehicle_" .. owner.UserId)
	vehicle.Parent = folder
	vehicle.frame = spawnFrame
	vehicle:SetAttribute("OwnerUserId", owner.UserId)
	local chassis = instance("Part", "Chassis")
	chassis.Parent = vehicle
	chassis.Position = {Y = 5}
	vehicle.PrimaryPart = chassis
	local seat = instance("VehicleSeat", "DriverSeat")
	seat.Parent = vehicle
	vehicle.children.DriverSeat = seat
	table.insert(cars, vehicle)
	return vehicle
end

local storage = instance("ReplicatedStorage", "ReplicatedStorage")
local shared = instance("Folder", "shared")
storage.children.shared = shared
shared.children.VehicleConfig = Config
local parent = instance("Folder", "server")
parent.children.VehicleService = vehicleService
local services = {Players = Players, ReplicatedStorage = storage, RunService = RunService, Workspace = Workspace}
local environment = setmetatable({
	game = {GetService = function(_, key) return assert(services[key]) end},
	script = {Parent = parent},
	require = function(value) return value end,
	os = {clock = function() return now end},
	warn = function() warningCount += 1 end,
	CFrame = {new = frame},
}, {__index = getfenv()})
local chunk = assert(loadstring(__SERVICE_SOURCE__, "PlayerVehicleService"))
setfenv(chunk, environment)
local service = chunk()

local function characterFor(player, withHumanoid)
	local character = instance("Model", "Character")
	character.Parent = Workspace
	if withHumanoid ~= false then
		local humanoid = instance("Humanoid", "Humanoid")
		humanoid.Health = 100
		humanoid.Died = signal()
		humanoid.Parent = character
		character.children.Humanoid = humanoid
	end
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
local function player(id)
	local p = instance("Player", "Player" .. id)
	p.UserId = id
	p.CharacterAdded, p.CharacterRemoving = signal(), signal()
	return p
end
local function tick(seconds)
	now += seconds or 0.01
	RunService.Heartbeat:Fire()
end
local function liveCount()
	local count = 0
	for _, car in cars do if not car.destroyed then count += 1 end end
	return count
end

-- Existing-player startup, duplicate start and duplicate event delivery.
local first, second = player(101), player(202)
characterFor(first)
Players.list = {first}
service.start()
service.start()
Players.PlayerAdded:Fire(first)
local firstCar = assert(service.getVehicle(first))
assert(liveCount() == 1 and firstCar:GetAttribute("OwnerUserId") == 101)
assert(firstCar:GetAttribute("SpawnSlot") == 1)
near(firstCar.frame.x, 10); near(firstCar.frame.z, 20)

-- A joining player without a character gets one car only when ready.
Players.PlayerAdded:Fire(second)
assert(service.getVehicle(second) == nil)
local secondCharacter = characterFor(second, false)
tick()
assert(service.getVehicle(second) == nil)
local secondHumanoid = instance("Humanoid", "Humanoid")
secondHumanoid.Parent = secondCharacter
secondHumanoid.Health, secondHumanoid.Died = 100, signal()
secondCharacter.children.Humanoid = secondHumanoid
tick()
local secondCar = assert(service.getVehicle(second))
assert(liveCount() == 2 and secondCar ~= firstCar)
assert(secondCar:GetAttribute("OwnerUserId") == 202)
near(secondCar.frame.x, 10); near(secondCar.frame.z, 4)

-- Death removes only the owner's car; no dead-character respawn.
local oldCharacter = first.Character
local oldHumanoid = oldCharacter.children.Humanoid
oldHumanoid.Health = 0
oldHumanoid.Died:Fire()
tick(2)
assert(firstCar.destroyed and service.getVehicle(first) == nil and liveCount() == 1)
characterFor(first)
local replacement = assert(service.getVehicle(first))
assert(replacement ~= firstCar and replacement:GetAttribute("SpawnSlot") == 1)
-- A delayed old-character event cannot delete the replacement.
first.CharacterRemoving:Fire(oldCharacter)
oldHumanoid.Died:Fire()
assert(service.getVehicle(first) == replacement)

-- Lost cars, missing chassis/seat, and removal from the active folder recover.
replacement.PrimaryPart.Position.Y = -451
tick()
assert(replacement.destroyed and liveCount() == 2)
replacement = assert(service.getVehicle(first))
replacement.PrimaryPart = nil
tick()
assert(replacement.destroyed and liveCount() == 2)
replacement = assert(service.getVehicle(first))
replacement.children.DriverSeat = nil
tick()
assert(replacement.destroyed and liveCount() == 2)
replacement = assert(service.getVehicle(first))
replacement:Destroy()
tick()
assert(service.getVehicle(first) ~= replacement and liveCount() == 2)

-- Blocked spawns retry on schedule and warn once per failure period.
replacement = assert(service.getVehicle(first))
blocked = true
replacement:Destroy()
tick()
local previousAttempts, previousWarnings = attempts, warningCount
assert(service.getVehicle(first) == nil and liveCount() == 1)
for _ = 1, 20 do tick(0.01) end
assert(attempts == previousAttempts and warningCount == previousWarnings)
tick(1)
assert(attempts == previousAttempts + 1 and warningCount == previousWarnings)
blocked = false
tick(1)
assert(service.getVehicle(first) and liveCount() == 2)

-- Asset errors stay isolated; recovery works after the template is restored.
assetError = true
service.getVehicle(first):Destroy()
tick()
assert(service.getVehicle(first) == nil and service.getVehicle(second) == secondCar)
assetError = false
tick(1)
assert(service.getVehicle(first) and liveCount() == 2)

-- Explicit marker slots wait when missing and use their authored transforms.
local markers = instance("Folder", "VehicleSpawns")
Workspace.children.VehicleSpawns = markers
service.getVehicle(first):Destroy()
tick()
assert(service.getVehicle(first) == nil)
local explicit = instance("Part", "1")
explicit.CFrame = frame(80, 8, 90)
markers.children["1"] = explicit
tick(1)
near(service.getVehicle(first).frame.x, 80)
Workspace.children.VehicleSpawns = nil

-- Leave cleanup disconnects callbacks and reuses the freed slot.
Players.PlayerRemoving:Fire(first)
assert(service.getVehicle(first) == nil and liveCount() == 1)
characterFor(first)
tick(2)
assert(service.getVehicle(first) == nil and liveCount() == 1)
local third = player(303)
Players.PlayerAdded:Fire(third)
characterFor(third)
assert(service.getVehicle(third):GetAttribute("SpawnSlot") == 1)
assert(service.getVehicle(second) == secondCar and liveCount() == 2)
Players.PlayerRemoving:Fire(second)
Players.PlayerRemoving:Fire(third)
tick(2)
assert(liveCount() == 0)

-- Run the actual controller ownership check, including the unowned test fixture.
function Players:GetPlayerFromCharacter(character)
	if character == second.Character then return second end
	if character == third.Character then return third end
	return nil
end
local driverChunk = assert(loadstring(__DRIVER_SOURCE__, "VehicleController.getDriver"))
setfenv(driverChunk, setmetatable({Players = Players}, {__index = getfenv()}))
local getDriver = driverChunk()
local car = instance("Model", "OwnedCar")
local seat = instance("VehicleSeat", "DriverSeat")
seat.Parent = car
car:SetAttribute("OwnerUserId", second.UserId)
seat.Occupant = second.Character.children.Humanoid
assert(getDriver(seat) == second)
seat.Occupant = third.Character.children.Humanoid
assert(getDriver(seat) == nil)
car:SetAttribute("OwnerUserId", nil)
assert(getDriver(seat) == third)
seat.Occupant.Health = 0
assert(getDriver(seat) == nil)
seat.Occupant = nil
assert(getDriver(seat) == nil)
print("PASS: lifecycle, ownership records, rotated slots, retries, recovery, and cleanup")
print("PASS: controller permits only the living owner; unowned fixture stays compatible")
