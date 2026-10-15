--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceConfig"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local PlayerVehicleService = require(script.Parent:WaitForChild("PlayerVehicleService"))
local RespawnService = {}
local nextRequest: {[Player]: number} = {}
local started = false
local resetPredicate: ((Player) -> boolean)? = nil

function RespawnService.setResetPredicate(predicate: (Player) -> boolean)
	resetPredicate = predicate
end

function RespawnService.clearRacer(player: Player)
	nextRequest[player] = nil
	player:SetAttribute("ResetStatus", nil)
end

function RespawnService.requestReset(player: Player): boolean
	if resetPredicate and not resetPredicate(player) then
		player:SetAttribute("ResetStatus", "Reset available while racing")
		return false
	end
	if not CheckpointService.isRacer(player) then
		player:SetAttribute("ResetStatus", "Race unavailable: check checkpoint setup")
		return false
	end
	local now = os.clock()
	if now < (nextRequest[player] or 0) then
		player:SetAttribute("ResetStatus", "Wait a moment before resetting again")
		return false
	end
	-- Rate-limit failed requests as well as successful ones.
	nextRequest[player] = now + Config.ResetCooldown
	local ok, result = pcall(PlayerVehicleService.resetVehicle, player, CheckpointService.getResetCFrame(player))
	if not ok then warn("Vehicle reset failed: " .. tostring(result)) end
	local success = ok and result == true
	player:SetAttribute("ResetStatus", if success then "Returned to checkpoint" else "Reset blocked: check your vehicle, ground and free space")
	return success
end

function RespawnService.start()
	if started then return end
	assert(Config.ResetCooldown > 0, "ResetCooldown must be positive.")
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes:IsA("Folder"), "Remotes must be a Folder.")
	local remote = remotes:FindFirstChild(Config.ResetRemoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = Config.ResetRemoteName
		remote.Parent = remotes
	end
	assert(remote:IsA("RemoteEvent"), "ResetVehicle must be a RemoteEvent.")
	started = true
	remote.OnServerEvent:Connect(function(player)
		-- No client checkpoint, vehicle, or coordinates are accepted.
		RespawnService.requestReset(player)
	end)
	Players.PlayerRemoving:Connect(function(player) nextRequest[player] = nil end)
end

return RespawnService
