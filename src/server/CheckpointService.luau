--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceConfig"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local CheckpointService = {}

type Progress = {lastIndex: number, resetCFrame: CFrame?, completedLaps: number, lapComplete: boolean}
export type RaceProgress = {completedLaps: number, currentLap: number, totalLaps: number, lapComplete: boolean}
type FinishSample = {vehicle: Model, chassis: BasePart, resetVersion: any, position: Vector3}
local progress: {[Player]: Progress} = {}
local finishSamples: {[Player]: FinishSample} = {}
local connections: {RBXScriptConnection} = {}
local active = false
local checkpointCount = 0
local totalLaps = 0
local generation = 0
local racingPredicate: ((Player) -> boolean)? = nil

function CheckpointService.setRacingPredicate(predicate: (Player) -> boolean)
	racingPredicate = predicate
end

local function displayLaps(player: Player, state: Progress)
	player:SetAttribute("CompletedLaps", state.completedLaps)
	player:SetAttribute("CurrentLap", math.min(state.completedLaps + 1, totalLaps))
	player:SetAttribute("TotalLaps", totalLaps)
	player:SetAttribute("LapComplete", state.lapComplete)
end

-- Issue #24 consumes this validated snapshot; display attributes are not authority.
function CheckpointService.getRaceProgress(player: Player): RaceProgress?
	local state = progress[player]
	return if state then {
		completedLaps = state.completedLaps, currentLap = math.min(state.completedLaps + 1, totalLaps),
		totalLaps = totalLaps, lapComplete = state.lapComplete,
	} else nil
end

function CheckpointService.addRacer(player: Player)
	if active and not progress[player] then
		local state: Progress = {lastIndex = 0, resetCFrame = nil, completedLaps = 0, lapComplete = false}
		progress[player] = state
		displayLaps(player, state)
		player:SetAttribute("LastCheckpoint", 0)
		player:SetAttribute("CheckpointCount", checkpointCount)
	end
end

function CheckpointService.removeRacer(player: Player)
	progress[player] = nil
	finishSamples[player] = nil
	player:SetAttribute("LastCheckpoint", nil)
	player:SetAttribute("CheckpointCount", nil)
	for _, attribute in {"CompletedLaps", "CurrentLap", "TotalLaps", "LapComplete"} do
		player:SetAttribute(attribute, nil)
	end
end

function CheckpointService.isRacer(player: Player): boolean
	return progress[player] ~= nil
end

function CheckpointService.getResetCFrame(player: Player): CFrame?
	local state = progress[player]
	return if state then state.resetCFrame else nil
end

function CheckpointService.getLastIndex(player: Player): number?
	local state = progress[player]
	return if state then state.lastIndex else nil
end

-- Only server-observed vehicle touches can advance progress. Capture marker
-- frames at race start so moving a marker cannot change an earned destination.
local function touched(index: number, resetCFrame: CFrame, hit: BasePart)
	if not active then return end
	for player, state in progress do
		if racingPredicate and not racingPredicate(player) then continue end
		if state.lapComplete then continue end
		if index ~= state.lastIndex + 1 then continue end
		local vehicle = PlayerVehicleService.getVehicle(player)
		if not vehicle or vehicle:GetAttribute("OwnerUserId") ~= player.UserId
			or not hit:IsDescendantOf(vehicle) then continue end
		local seat = vehicle:FindFirstChild("DriverSeat")
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not character or not character:IsDescendantOf(Workspace)
			or not humanoid or humanoid.Health <= 0
			or not seat or not seat:IsA("VehicleSeat") or seat.Occupant ~= humanoid then continue end
		state.lastIndex = index
		state.resetCFrame = resetCFrame
		player:SetAttribute("LastCheckpoint", state.lastIndex) -- Display only; never read for validation.
		return
	end
end

-- Sample the owned chassis on the server, rather than awarding on first contact
-- by a bumper/wheel. Sweeping between samples also catches fast crossings that
-- pass completely through a thin trigger between physics steps.
local function sampleFinish(finish: BasePart, finishFrame: CFrame, finishSize: Vector3)
	if finish.Parent ~= Workspace or finish.CFrame ~= finishFrame or finish.Size ~= finishSize then
		table.clear(finishSamples)
		return
	end
	for player, state in progress do
		if not active or state.lapComplete or state.lastIndex ~= checkpointCount
			or (racingPredicate and not racingPredicate(player)) then
			finishSamples[player] = nil
			continue
		end
		local vehicle = PlayerVehicleService.getVehicle(player)
		local chassis = if vehicle then vehicle.PrimaryPart else nil
		local seat = if vehicle then vehicle:FindFirstChild("DriverSeat") else nil
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not vehicle or not vehicle:IsDescendantOf(Workspace)
			or vehicle:GetAttribute("OwnerUserId") ~= player.UserId
			or not chassis or not chassis:IsDescendantOf(vehicle)
			or not character or not character:IsDescendantOf(Workspace)
			or not humanoid or humanoid.Health <= 0
			or not seat or not seat:IsA("VehicleSeat") or seat.Occupant ~= humanoid then
			finishSamples[player] = nil
			continue
		end
		local position = finishFrame:PointToObjectSpace(chassis.Position)
		local resetVersion = vehicle:GetAttribute("ResetVersion")
		local previous = finishSamples[player]
		finishSamples[player] = {
			vehicle = vehicle, chassis = chassis, resetVersion = resetVersion, position = position,
		}
		-- A reset/replacement must never become a swept crossing from the old location.
		if not previous or previous.vehicle ~= vehicle or previous.chassis ~= chassis
			or previous.resetVersion ~= resetVersion then continue end
		local before = previous.position
		-- LookVector is local -Z: only approach-side -> exit-side crossings count.
		if before.Z <= 0 or position.Z > 0 then continue end
		local fraction = before.Z / (before.Z - position.Z)
		local crossing = before:Lerp(position, fraction)
		if math.abs(crossing.X) > finishSize.X / 2
			or math.abs(crossing.Y) > finishSize.Y / 2 then continue end

		-- Consume the checkpoint sequence before publishing. Together with the
		-- directed crossing this debounces lingering, jitter and repeated contacts.
		finishSamples[player] = nil
		state.completedLaps += 1
		state.lapComplete = state.completedLaps == totalLaps
		if not state.lapComplete then state.lastIndex = 0 end
		-- Preserve the last earned checkpoint recovery destination.
		displayLaps(player, state)
		player:SetAttribute("LastCheckpoint", state.lastIndex)
	end
end

function CheckpointService.stopRace()
	active = false
	generation += 1
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player in progress do CheckpointService.removeRacer(player) end
	table.clear(progress)
	table.clear(finishSamples)
	checkpointCount, totalLaps = 0, 0
end

function CheckpointService.startRace(racers: {Player}): (boolean, string?)
	-- A bad track must not destroy an already-running race's progress.
	local configuredLaps = Config.TotalLaps
	if typeof(configuredLaps) ~= "number" or configuredLaps < 1
		or configuredLaps == math.huge or configuredLaps % 1 ~= 0 then
		return false, "RaceConfig.TotalLaps must be a finite positive integer."
	end
	local finish = Workspace:FindFirstChild(Config.FinishPartName)
	if not finish or not finish:IsA("BasePart") or not finish.Anchored
		or not finish.CanTouch or finish.CanCollide or finish.CanQuery
		or finish.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999 then
		return false, "Create Workspace." .. Config.FinishPartName .. " as an upright, anchored, touchable, noncollidable, nonqueryable finish part facing the race direction."
	end
	local folder = Workspace:FindFirstChild(Config.CheckpointFolderName)
	if not folder or not folder:IsA("Folder") then return false, "Create Workspace.Checkpoints (Folder)." end
	local markers: {[number]: BasePart} = {}
	local resetFrames: {[number]: CFrame} = {}
	local count = 0
	for _, child in folder:GetChildren() do
		local index = tonumber(child.Name)
		if not child:IsA("BasePart") or not index or index < 1 or index % 1 ~= 0
			or tostring(index) ~= child.Name or markers[index]
			or not child.Anchored or not child.CanTouch or child.CanCollide or child.CanQuery
			or child.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999 then
			return false, "Invalid checkpoint " .. child.Name .. ": use an upright, anchored, touchable, noncollidable, nonqueryable part named 1, 2, 3, ..."
		end
		local resetFrame = VehicleService.getResetMarkerCFrame(child.CFrame)
		if not resetFrame then return false, "Checkpoint " .. child.Name .. " needs flat ground below its center." end
		markers[index] = child
		resetFrames[index] = resetFrame
		count += 1
	end
	if count == 0 then return false, "At least one checkpoint is required." end
	for index = 1, count do
		if not markers[index] then return false, "Checkpoint numbering must be contiguous from 1." end
	end
	CheckpointService.stopRace()
	local raceGeneration = generation
	active = true
	checkpointCount = count
	totalLaps = configuredLaps
	for _, player in racers do CheckpointService.addRacer(player) end
	for index = 1, count do
		local marker = markers[index]
		local resetCFrame = resetFrames[index]
		table.insert(connections, marker.Touched:Connect(function(hit)
			if raceGeneration == generation and marker.Parent == folder and folder.Parent == Workspace then touched(index, resetCFrame, hit) end
		end))
	end
	local finishFrame, finishSize = finish.CFrame, finish.Size
	table.insert(connections, RunService.Heartbeat:Connect(function()
		if raceGeneration == generation then sampleFinish(finish, finishFrame, finishSize) end
	end))
	return true, nil
end

return CheckpointService
