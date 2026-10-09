--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceConfig"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local RespawnService = require(script.Parent:WaitForChild("RespawnService"))
local RaceTiming = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceTiming"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))
local RaceService = {}

export type State = "Waiting" | "Loading" | "Countdown" | "Racing" | "Results"
export type FinishResult = {raceId: number, userId: number, finished: boolean, position: number, elapsedTime: number}
export type Snapshot = {state: State, raceId: number, deadline: number, reason: string, countdown: number, startedAt: number, endedAt: number, finishTimes: {[string]: number}, finishOrder: {number}, positions: {[string]: number}, finishResults: {[string]: FinishResult}}
type Participant = {finished: boolean, gridVehicle: Model?, gridFrame: CFrame?}
type Hook = (Snapshot) -> (() -> ())?
local state: State = "Waiting"
local raceId, deadline = 0, 0
local countdown, startedAt, endedAt = 0, 0, 0
local finishTimes: {[string]: number} = {}
local finishOrder: {number} = {}
local finishResults: {[string]: FinishResult} = {}
local positions: {[string]: number} = {}
local updates: RemoteEvent? = nil
local reason = "Waiting for players"
local started, transitioning = false, false
local participants: {[Player]: Participant} = {}
local coasting: {[Player]: boolean} = {}
local lobbyReady: {[Player]: boolean} = {}
local hooks: {[State]: {[Hook]: boolean}} = {}
local cleanups: {() -> ()} = {}
local display: StringValue? = nil
local trackReady = false
local nextAttempt, nextGridAttempt = 0, 0
local durations: {[State]: number} = {}

function RaceService.getSnapshot(): Snapshot
	return {state = state, raceId = raceId, deadline = deadline, reason = reason, countdown = countdown, startedAt = startedAt, endedAt = endedAt, finishTimes = table.clone(finishTimes), finishOrder = table.clone(finishOrder), positions = table.clone(positions), finishResults = table.clone(finishResults)}
end

function RaceService.getElapsedTime(): number
	return RaceTiming.getElapsed(RaceService.getSnapshot(), Workspace:GetServerTimeNow())
end

function RaceService.getFinishTime(userId: number, expectedRaceId: number): number?
	if expectedRaceId ~= raceId then return nil end
	return finishTimes[tostring(userId)]
end

-- Records are frozen and survive departure through Results. The containing
-- snapshot map is detached; remote clients receive serialized copies.
function RaceService.getFinishResult(userId: number, expectedRaceId: number): FinishResult?
	if expectedRaceId ~= raceId then return nil end
	return finishResults[tostring(userId)]
end

-- Hooks run once on entry and return a cleanup run once before leaving that state.
-- Hooks/cleanups must not yield. Capture snapshot.raceId for asynchronous consumers.
function RaceService.onEntered(target: State, hook: Hook): () -> ()
	assert(durations[target] ~= nil or not started, "Unknown race state")
	local listeners = hooks[target] or {}
	hooks[target] = listeners
	listeners[hook] = true
	return function() listeners[hook] = nil end
end

function RaceService.canDrive(player: Player): boolean
	local participant = participants[player]
	return state == "Racing" and participant ~= nil and not participant.finished
end

-- Keep passive coasting through Results/Waiting until the next race prepares.
function RaceService.canCoast(player: Player): boolean
	return coasting[player] == true
end

local function isReady(player: Player): boolean
	local vehicle = PlayerVehicleService.getVehicle(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if vehicle then vehicle:FindFirstChild("DriverSeat") else nil
	return vehicle ~= nil and vehicle:GetAttribute("OwnerUserId") == player.UserId
		and vehicle.PrimaryPart ~= nil and character ~= nil and character:IsDescendantOf(Workspace)
		and humanoid ~= nil and humanoid.Health > 0 and seat ~= nil
		and seat:IsA("VehicleSeat") and seat.Occupant == humanoid
end

local function isPrepared(player: Player): boolean
	local participant = participants[player]
	return participant ~= nil and participant.gridVehicle ~= nil
		and participant.gridVehicle == PlayerVehicleService.getVehicle(player) and isReady(player)
end

local function refreshPositions(): boolean
	local active: {PlacementService.ActiveRacer} = {}
	for player, participant in participants do
		if participant.finished then continue end
		local progress = CheckpointService.getRaceProgress(player)
		table.insert(active, {userId = player.UserId,
			completedLaps = if progress then progress.completedLaps else 0,
			checkpoint = CheckpointService.getLastIndex(player) or 0})
	end
	local nextPositions = PlacementService.getPositions(active, finishOrder)
	local changed = false
	for key, position in nextPositions do
		if positions[key] ~= position then changed = true end
	end
	for key in positions do
		if nextPositions[key] == nil then changed = true end
	end
	positions = nextPositions
	for player in participants do
		local position = positions[tostring(player.UserId)]
		if player:GetAttribute("RacePosition") ~= position then player:SetAttribute("RacePosition", position) end
		if player:GetAttribute("RacePositionId") ~= raceId then player:SetAttribute("RacePositionId", raceId) end
	end
	return changed
end

local function publish()
	refreshPositions()
	local value = display
	if not value then return end
	value:SetAttribute("RaceId", raceId)
	value:SetAttribute("Deadline", deadline)
	value:SetAttribute("Reason", reason)
	value:SetAttribute("Countdown", countdown)
	value:SetAttribute("StartedAt", startedAt)
	value:SetAttribute("EndedAt", endedAt)
	value.Value = state -- Durable current state, including for late joiners.
	-- One payload carries a coherent generation and server time to every client.
	if updates then updates:FireAllClients(RaceService.getSnapshot()) end
end

local function removeParticipant(player: Player)
	participants[player] = nil
	CheckpointService.removeRacer(player)
	RespawnService.clearRacer(player)
	player:SetAttribute("RaceParticipant", nil)
	player:SetAttribute("RacePosition", nil)
	player:SetAttribute("RacePositionId", nil)
end

local function transition(target: State, why: string): boolean
	local nextState = {Waiting = "Loading", Loading = "Countdown", Countdown = "Racing", Racing = "Results", Results = "Waiting"}
	local abort = target == "Results" and (state == "Loading" or state == "Countdown")
	if transitioning or (nextState[state] ~= target and not abort) then return false end
	transitioning = true
	for _, cleanup in cleanups do
		local ok, err = pcall(cleanup)
		if not ok then warn("Race cleanup failed: " .. tostring(err)) end
	end
	table.clear(cleanups)
	if target == "Results" and state == "Racing" then
		for player in participants do coasting[player] = true end
	end
	state, reason = target, why
	local now = Workspace:GetServerTimeNow()
	deadline = if target == "Waiting" then 0 else now + durations[target]
	countdown = if target == "Countdown" then math.ceil(durations.Countdown) else 0
	if target == "Racing" then
		startedAt, endedAt = now, 0
	elseif target == "Results" and startedAt > 0 then
		endedAt = now
	elseif target == "Waiting" or target == "Loading" then
		startedAt, endedAt = 0, 0
		table.clear(finishTimes)
		table.clear(finishOrder)
		table.clear(finishResults)
		table.clear(positions)
		for _, player in Players:GetPlayers() do
			player:SetAttribute("RaceFinishId", nil)
			player:SetAttribute("RaceFinishTime", nil)
			player:SetAttribute("RaceFinishPosition", nil)
		end
	end
	if target == "Waiting" then
		table.clear(lobbyReady)
		for _, player in Players:GetPlayers() do player:SetAttribute("LobbyReady", false) end
		CheckpointService.stopRace()
		for player in participants do removeParticipant(player) end
		trackReady = false
	elseif target == "Loading" then
		table.clear(coasting)
		raceId += 1
		CheckpointService.stopRace()
		for _, player in Players:GetPlayers() do
			participants[player] = {finished = false}
			player:SetAttribute("RaceParticipant", true)
			RespawnService.clearRacer(player)
		end
		nextAttempt = 0
		nextGridAttempt = 0
	end
	publish()
	for hook in hooks[target] or {} do
		local ok, cleanup = pcall(hook, RaceService.getSnapshot())
		if ok and type(cleanup) == "function" then table.insert(cleanups, cleanup)
		elseif not ok then warn("Race entry hook failed: " .. tostring(cleanup)) end
	end
	transitioning = false
	return true
end

-- Existing StartRace requests only prepare a race from Waiting. Never restart an active race.
function RaceService.requestStart(): boolean
	if not started or state ~= "Waiting" or #Players:GetPlayers() < Config.MinimumPlayers then return false end
	for _, player in Players:GetPlayers() do
		if not lobbyReady[player] then return false end
	end
	return transition("Loading", "Preparing race")
end

-- Readiness is private server state; the attribute only acknowledges it to the UI.
-- The waiting generation prevents a delayed click from readying a later lobby.
function RaceService.readyPlayer(player: Player, expectedRaceId: number): boolean
	if not started or transitioning or state ~= "Waiting" or expectedRaceId ~= raceId
		or not table.find(Players:GetPlayers(), player) or lobbyReady[player] then return false end
	lobbyReady[player] = true
	player:SetAttribute("LobbyReady", true)
	RaceService.requestStart()
	return true
end

-- Server finish consumers must carry the generation and use validated lap state.
function RaceService.markFinished(player: Player, expectedRaceId: number): (boolean, number?)
	if transitioning or expectedRaceId ~= raceId or not RaceService.canDrive(player) then return false end
	local progress = CheckpointService.getRaceProgress(player)
	if not progress or not progress.lapComplete then return false end
	local finishTime = RaceService.getElapsedTime()
	local result: FinishResult = table.freeze({
		raceId = raceId, userId = player.UserId, finished = true,
		position = #finishOrder + 1, elapsedTime = finishTime,
	})
	-- Commit all authority without yielding or notifying observers partway through.
	finishResults[tostring(player.UserId)] = result
	finishTimes[tostring(player.UserId)] = result.elapsedTime
	table.insert(finishOrder, result.userId)
	participants[player].finished = true
	player:SetAttribute("RaceFinishPosition", result.position)
	coasting[player] = true
	player:SetAttribute("RaceFinishTime", finishTime)
	player:SetAttribute("RaceFinishId", raceId)
	publish()
	return true, finishTime
end

local function update()
	if transitioning then return end
	local now = Workspace:GetServerTimeNow()
	if state == "Waiting" then
		RaceService.requestStart() -- Also re-evaluate after an unready player leaves.
	elseif state == "Loading" then
		if not next(participants) then transition("Results", "No participants"); return end
		if not trackReady and now >= nextAttempt then
			nextAttempt = now + Config.LoadingRetryInterval
			local racers = {}
			for player in participants do table.insert(racers, player) end
			local ok, success, failure = pcall(CheckpointService.startRace, racers)
			trackReady = ok and success == true
			if not trackReady then
				reason = "Track unavailable: " .. tostring(if ok then failure else success)
				publish()
			end
		end
		-- Validate every assigned slot before admitting anyone. A missing slot must
		-- not silently become a smaller race or a shared fallback position.
		for player, participant in participants do
			if not participant.gridFrame then
				local ok, frame = pcall(PlayerVehicleService.getGridCFrame, player)
				if not ok or not frame then
					transition("Results", "Grid unavailable for " .. player.Name .. ": missing or insufficient slots")
					return
				end
				participant.gridFrame = frame
			end
		end
		-- Reset each current car once per race, or again after replacement/seat loss.
		-- The controller keeps preparation anchored and resetOnGround clears momentum.
		if now >= nextGridAttempt then
			nextGridAttempt = now + Config.LoadingRetryInterval
			for player, participant in participants do
				if not isPrepared(player) then
					participant.gridVehicle = nil
					local ok, placed = pcall(PlayerVehicleService.resetVehicle, player, participant.gridFrame)
					if ok and placed then
						participant.gridVehicle = PlayerVehicleService.getVehicle(player)
					else
						reason = "Grid placement waiting for " .. player.Name .. ": character, vehicle, ground, or slot blocked"
						publish()
					end
				end
			end
		end
		local ready, count = 0, 0
		for player in participants do
			count += 1
			if isPrepared(player) then ready += 1 end
		end
		if trackReady and ready == count and ready >= Config.MinimumPlayers then
			transition("Countdown", "Ready")
		elseif now >= deadline then
			for player in participants do
				if isReady(player) and not isPrepared(player) then
					transition("Results", "Grid placement timed out for " .. player.Name .. ": check ground and occupied slots")
					return
				end
			end
			for player in participants do if not isPrepared(player) then removeParticipant(player) end end
			if trackReady and ready >= Config.MinimumPlayers then transition("Countdown", "Ready players only")
			else transition("Results", "Loading timed out: " .. reason) end
		end
	elseif state == "Countdown" then
		if not next(participants) then transition("Results", "No participants")
		elseif now >= deadline then
			for player in participants do if not isPrepared(player) then removeParticipant(player) end end
			if next(participants) then transition("Racing", "Go")
			else transition("Results", "No ready participants") end
		else
			local remaining = math.ceil(deadline - now)
			if remaining ~= countdown then countdown = remaining; publish() end
		end
	elseif state == "Racing" then
		local unfinished = 0
		-- Equal completions observed in one polling tick use ascending UserId.
		local racers = {}
		for player in participants do table.insert(racers, player) end
		table.sort(racers, function(a, b) return a.UserId < b.UserId end)
		for _, player in racers do
			RaceService.markFinished(player, raceId)
			if not participants[player].finished then unfinished += 1 end
		end
		if refreshPositions() then publish() end
		if unfinished == 0 then transition("Results", "All participants finished or left")
		elseif now >= deadline then transition("Results", "Race timed out; unfinished racers DNF") end
	elseif state == "Results" and now >= deadline then
		transition("Waiting", "Waiting for players")
	end
end

function RaceService.start()
	if started then return end
	for _, key in {"MinimumPlayers", "LoadingTimeout", "LoadingRetryInterval", "CountdownDuration", "RaceTimeout", "ResultsDuration"} do
		local value = (Config :: any)[key]
		assert(typeof(value) == "number" and value > 0 and value < math.huge, key .. " must be finite and positive")
	end
	assert(Config.MinimumPlayers % 1 == 0, "MinimumPlayers must be an integer")
	durations = {Waiting = 0, Loading = Config.LoadingTimeout,
		Countdown = Config.CountdownDuration, Racing = Config.RaceTimeout, Results = Config.ResultsDuration}
	local value = ReplicatedStorage:FindFirstChild("RaceState")
	if not value then
		value = Instance.new("StringValue")
		value.Name = "RaceState"
		value.Parent = ReplicatedStorage
	end
	assert(value:IsA("StringValue"), "RaceState must be a StringValue")
	display = value
	local remote = ReplicatedStorage:FindFirstChild("RaceUpdated")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "RaceUpdated"
		remote.Parent = ReplicatedStorage
	end
	assert(remote:IsA("RemoteEvent"), "RaceUpdated must be a RemoteEvent")
	updates = remote
	started = true
	deadline = 0
	local readyRemote = ReplicatedStorage:FindFirstChild("RaceReady")
	if not readyRemote then
		readyRemote = Instance.new("RemoteEvent")
		readyRemote.Name = "RaceReady"
		readyRemote.Parent = ReplicatedStorage
	end
	assert(readyRemote:IsA("RemoteEvent"), "RaceReady must be a RemoteEvent")
	readyRemote.OnServerEvent:Connect(function(player: Player, expectedRaceId: any)
		if typeof(expectedRaceId) == "number" then RaceService.readyPlayer(player, expectedRaceId) end
	end)
	for _, player in Players:GetPlayers() do player:SetAttribute("LobbyReady", false) end
	Players.PlayerAdded:Connect(function(player) player:SetAttribute("LobbyReady", false) end)
	CheckpointService.setRacingPredicate(RaceService.canDrive)
	RespawnService.setResetPredicate(RaceService.canDrive)
	CheckpointService.stopRace()
	Players.PlayerRemoving:Connect(function(player)
		coasting[player] = nil
		lobbyReady[player] = nil
		player:SetAttribute("LobbyReady", nil)
		removeParticipant(player)
		publish()
	end)
	RunService.Heartbeat:Connect(update)
	publish()
end

return RaceService
