--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("VehicleConfig"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Config.InputRemoteName)
assert(remote:IsA("RemoteEvent"), "VehicleInput must be a RemoteEvent.")

local player = Players.LocalPlayer
local lastSeat: VehicleSeat? = nil
local elapsed = 0

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid and humanoid.Health > 0 then humanoid.SeatPart else nil
	local vehicle = if seat then seat.Parent else nil
	local folder = workspace:FindFirstChild(Config.ActiveFolderName)
	local activeSeat: VehicleSeat? = nil
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat"
		and vehicle and vehicle:IsA("Model") and folder and vehicle.Parent == folder
		and vehicle:GetAttribute("MovementEnabled") == true then
		activeSeat = seat
	end

	if activeSeat ~= lastSeat then
		if lastSeat then remote:FireServer(lastSeat, 0, 0) end
		lastSeat = activeSeat
		elapsed = Config.InputSendInterval
	end
	if not activeSeat or elapsed < Config.InputSendInterval then return end
	elapsed = 0
	-- Roblox's default seated controls supply W/S and A/D. No duplicate keybinds.
	-- Send only input; the server checks the occupant and computes all physics.
	remote:FireServer(activeSeat, activeSeat.ThrottleFloat, activeSeat.SteerFloat)
end)
