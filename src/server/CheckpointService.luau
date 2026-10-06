--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceConfig"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local CheckpointService = {}

type Progress = {lastIndex: number, resetCFrame: CFrame?}
local progress: {[Player]: Progress} = {}
local connections: {RBXScriptConnection} = {}
local active = false

function CheckpointService.addRacer(player: Player)
	if active and not progress[player] then
		progress[player] = {lastIndex = 0, resetCFrame = nil}
		player:SetAttribute("LastCheckpoint", 0)
	end
end

function CheckpointService.removeRacer(player: Player)
	progress[player] = nil
	player:SetAttribute("LastCheckpoint", nil)
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
	for player, state in progress do
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
		player:SetAttribute("LastCheckpoint", index) -- Display only; never read for validation.
		return
	end
end

function CheckpointService.startRace(racers: {Player}): (boolean, string?)
	-- A bad track must not destroy an already-running race's progress.
	local folder = Workspace:FindFirstChild(Config.CheckpointFolderName)
	if not folder or not folder:IsA("Folder") then return false, "Create Workspace.Checkpoints (Folder)." end
	local markers: {[number]: BasePart} = {}
	local count = 0
	for _, child in folder:GetChildren() do
		local index = tonumber(child.Name)
		if not child:IsA("BasePart") or not index or index < 1 or index % 1 ~= 0
			or tostring(index) ~= child.Name or markers[index]
			or not child.Anchored or not child.CanTouch or child.CanCollide or child.CanQuery
			or child.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999 then
			return false, "Checkpoints must be upright, anchored, touchable, noncollidable, nonqueryable parts named 1, 2, 3, ..."
		end
		markers[index] = child
		count += 1
	end
	if count == 0 then return false, "At least one checkpoint is required." end
	for index = 1, count do
		if not markers[index] then return false, "Checkpoint numbering must be contiguous from 1." end
	end
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player in progress do player:SetAttribute("LastCheckpoint", nil) end
	table.clear(progress)
	active = true
	for _, player in racers do CheckpointService.addRacer(player) end
	for index = 1, count do
		local marker = markers[index]
		local resetCFrame = marker.CFrame
		table.insert(connections, marker.Touched:Connect(function(hit)
			if marker.Parent == folder and folder.Parent == Workspace then touched(index, resetCFrame, hit) end
		end))
	end
	return true, nil
end

return CheckpointService
