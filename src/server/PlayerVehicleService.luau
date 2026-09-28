--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local PlayerVehicleService = {}

type PlayerState = {
	player: Player,
	slot: number,
	character: Model?,
	humanoid: Humanoid?,
	vehicle: Model?,
	deathConnection: RBXScriptConnection?,
	connections: {RBXScriptConnection},
	nextAttempt: number,
	warned: boolean,
}

local states: {[Player]: PlayerState} = {}
local slots: {[number]: Player} = {}
local started = false

local function removeVehicle(state: PlayerState)
	local vehicle = state.vehicle
	state.vehicle = nil
	if vehicle then vehicle:Destroy() end
end

local function clearCharacter(state: PlayerState)
	if state.deathConnection then state.deathConnection:Disconnect() end
	state.deathConnection = nil
	state.humanoid = nil
	state.character = nil
	removeVehicle(state)
end

local function getSpawnCFrame(slot: number): CFrame?
	local markers = Workspace:FindFirstChild(Config.SpawnFolderName)
	if markers then
		assert(markers:IsA("Folder"), "Workspace.VehicleSpawns must be a Folder.")
		local marker = markers:FindFirstChild(tostring(slot))
		return if marker and marker:IsA("BasePart") then marker.CFrame else nil
	end

	-- Preserve the existing Studio asset. Slots go right, then backward,
	-- relative to the marker's heading, and never move when another player leaves.
	local origin = Workspace:FindFirstChild(Config.TestSpawnName)
	if not origin or not origin:IsA("BasePart") then return nil end
	local index = slot - 1
	return origin.CFrame * CFrame.new(
		(index % Config.SpawnColumns) * Config.SpawnSpacing.X,
		0,
		math.floor(index / Config.SpawnColumns) * Config.SpawnSpacing.Z
	)
end

local function hasLivingCharacter(state: PlayerState): boolean
	local character = state.character
	local humanoid = state.humanoid
	return character ~= nil and character == state.player.Character
		and character:IsDescendantOf(Workspace) and humanoid ~= nil
		and humanoid.Parent == character and humanoid.Health > 0
end

local function trySpawn(state: PlayerState)
	if state.vehicle or not hasLivingCharacter(state) or os.clock() < state.nextAttempt then return end
	state.nextAttempt = os.clock() + Config.SpawnRetryInterval
	-- Asset errors should affect only this attempt, not stop every player's recovery.
	local success, result = pcall(function(): Model?
		local marker = getSpawnCFrame(state.slot)
		if not marker then return nil end
		return VehicleService.spawnOnGround(marker, true, state.player)
	end)
	if success and result then
		local vehicle = result :: Model
		state.vehicle = vehicle
		vehicle:SetAttribute("SpawnSlot", state.slot)
		state.warned = false
	else
		if not state.warned then
			warn(string.format("[Issue 9] Vehicle for %s is waiting for spawn slot %d. Check the template, marker, flat ground, and free space. %s",
				state.player.Name, state.slot, if success then "" else tostring(result)))
			state.warned = true
		end
	end
end

local function bindHumanoid(state: PlayerState)
	local character = state.character
	if not character or state.humanoid then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	state.humanoid = humanoid
	state.deathConnection = humanoid.Died:Connect(function()
		if state.character == character then removeVehicle(state) end
	end)
	trySpawn(state)
end

local function addPlayer(player: Player)
	if states[player] then return end
	local slot = 1
	while slots[slot] do slot += 1 end
	slots[slot] = player
	local state: PlayerState = {
		player = player, slot = slot, character = nil, humanoid = nil,
		vehicle = nil, deathConnection = nil, connections = {},
		nextAttempt = 0, warned = false,
	}
	states[player] = state
	player:SetAttribute("VehicleSpawnSlot", slot)

	local function onCharacterAdded(character: Model)
		if state.character == character then return end
		clearCharacter(state)
		state.character = character
		state.nextAttempt = 0
		state.warned = false
		bindHumanoid(state)
	end
	table.insert(state.connections, player.CharacterAdded:Connect(onCharacterAdded))
	table.insert(state.connections, player.CharacterRemoving:Connect(function(character)
		if state.character == character then clearCharacter(state) end
	end))
	if player.Character then onCharacterAdded(player.Character) end
end

local function removePlayer(player: Player)
	local state = states[player]
	if not state then return end
	states[player] = nil
	slots[state.slot] = nil
	for _, connection in state.connections do connection:Disconnect() end
	clearCharacter(state)
	player:SetAttribute("VehicleSpawnSlot", nil)
end

function PlayerVehicleService.getVehicle(player: Player): Model?
	local state = states[player]
	local vehicle = if state then state.vehicle else nil
	local folder = Workspace:FindFirstChild(Config.ActiveFolderName)
	return if vehicle and folder and vehicle.Parent == folder then vehicle else nil
end

-- Idempotent entry point; it also handles players already present at startup.
function PlayerVehicleService.start()
	if started or not Config.PlayerVehiclesEnabled then return end
	assert(Config.SpawnColumns >= 1 and Config.SpawnColumns % 1 == 0, "SpawnColumns must be a positive integer.")
	assert(Config.SpawnSpacing.X > 0 and Config.SpawnSpacing.Z > 0, "SpawnSpacing must be positive.")
	assert(Config.SpawnRetryInterval > 0 and Config.VehicleRecoveryHeight >= 0, "Invalid recovery settings.")
	started = true
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do addPlayer(player) end

	RunService.Heartbeat:Connect(function()
		local folder = Workspace:FindFirstChild(Config.ActiveFolderName)
		local recoveryY = Workspace.FallenPartsDestroyHeight + Config.VehicleRecoveryHeight
		for _, state in states do
			bindHumanoid(state)
			local vehicle = state.vehicle
			if vehicle then
				local chassis = vehicle.PrimaryPart
				local seat = vehicle:FindFirstChild("DriverSeat")
				if not hasLivingCharacter(state) or not folder or vehicle.Parent ~= folder
					or not chassis or not chassis:IsDescendantOf(vehicle)
					or not seat or not seat:IsA("VehicleSeat")
					or chassis.Position.Y <= recoveryY then
					removeVehicle(state)
					state.nextAttempt = 0
				end
			end
			trySpawn(state)
		end
	end)
end

return PlayerVehicleService
