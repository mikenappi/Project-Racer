--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local raceState = ReplicatedStorage:WaitForChild("RaceState") :: StringValue
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("RaceConfig"))
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RaceHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10

local panel = Instance.new("TextLabel")
panel.Name = "CheckpointStatus"
panel.Size = UDim2.new(0, 360, 0, 140)
panel.Position = UDim2.new(0, 16, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(18, 24, 32)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.TextColor3 = Color3.fromRGB(255, 255, 255)
panel.Font = Enum.Font.GothamMedium
panel.TextSize = 17
panel.TextWrapped = true
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local readyRemote = ReplicatedStorage:WaitForChild("RaceReady") :: RemoteEvent
local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.AnchorPoint = Vector2.new(0.5, 0.5)
startButton.Position = UDim2.fromScale(0.5, 0.5)
startButton.Size = UDim2.fromOffset(320, 90)
startButton.BackgroundColor3 = Color3.fromRGB(30, 115, 210)
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 24
startButton.TextWrapped = true
startButton.Visible = false
startButton.Parent = gui
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 12)
startCorner.Parent = startButton
startButton.Activated:Connect(function()
	if raceState.Value == "Waiting" and player:GetAttribute("LobbyReady") ~= true then
		readyRemote:FireServer(raceState:GetAttribute("RaceId"))
	end
end)
local function showLobby()
	startButton.Visible = raceState.Value == "Waiting"
	if not startButton.Visible then return end
	local ready, players = 0, Players:GetPlayers()
	for _, member in players do
		if member:GetAttribute("LobbyReady") == true then ready += 1 end
	end
	local clicked = player:GetAttribute("LobbyReady") == true
	startButton.Active = not clicked
	startButton.AutoButtonColor = not clicked
	startButton.Text = string.format("%s\n%d / %d players ready",
		if clicked then "Waiting for everyone..." else "Start", ready, #players)
end
RunService.Heartbeat:Connect(showLobby)
showLobby()

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.fromOffset(240, 100)
countdownLabel.Position = UDim2.fromScale(0.5, 0.3)
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.TextStrokeTransparency = 0.3
countdownLabel.Font = Enum.Font.GothamBold
countdownLabel.TextSize = 72
countdownLabel.Text = ""
countdownLabel.Parent = gui

-- Read durable server values, so late subscription and respawn need no replay.
-- Never predict GO locally: only Racing authorizes the start presentation.
local function showCountdown()
	local text = ""
	if player:GetAttribute("RaceParticipant") == true then
		local remaining = raceState:GetAttribute("Countdown")
		local startedAt = raceState:GetAttribute("StartedAt")
		if raceState.Value == "Countdown" and typeof(remaining) == "number" and remaining > 0 then
			text = tostring(remaining)
		elseif raceState.Value == "Racing" and typeof(startedAt) == "number" and startedAt > 0
			and Workspace:GetServerTimeNow() < startedAt + Config.GoDisplayDuration then
			text = "GO"
		end
	end
	countdownLabel.Text = text
end
RunService.Heartbeat:Connect(showCountdown)

local function showCurrentCheckpoint()
	local current = player:GetAttribute("LastCheckpoint")
	local total = player:GetAttribute("CheckpointCount")
	local status = player:GetAttribute("ResetStatus")
	local lap = player:GetAttribute("CurrentLap")
	local laps = player:GetAttribute("TotalLaps")
	local complete = player:GetAttribute("LapComplete") == true
	local progress = if typeof(current) == "number" and typeof(total) == "number"
		then string.format("Checkpoint %d / %d", current, total)
		else "Waiting for race / checkpoint setup"
	local lapText = if typeof(lap) == "number" and typeof(laps) == "number"
		then string.format("Lap %d / %d%s\n", lap, laps, if complete then " - Complete" else "") else ""
	local participation = if player:GetAttribute("RaceParticipant") == true then "" else " - waiting for next race"
	panel.Text = raceState.Value .. participation .. "\n" .. lapText .. progress .. "\nR - return to checkpoint"
		.. (if typeof(status) == "string" then "\n" .. status else "")
end

for _, attribute in {"LastCheckpoint", "CheckpointCount", "ResetStatus", "CurrentLap", "TotalLaps", "LapComplete", "RaceParticipant"} do
	player:GetAttributeChangedSignal(attribute):Connect(showCurrentCheckpoint)
end
raceState.Changed:Connect(showCurrentCheckpoint)
showCurrentCheckpoint()
gui.Parent = player:WaitForChild("PlayerGui")
