--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local raceState = ReplicatedStorage:WaitForChild("RaceState") :: StringValue
local shared = ReplicatedStorage:WaitForChild("shared")
local Config = require(shared:WaitForChild("RaceConfig"))
local RaceTiming = require(shared:WaitForChild("RaceTiming"))
local Format = require(shared:WaitForChild("RaceHUDFormat"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
-- StarterPlayerScripts persists through character respawns. A second synced
-- controller must not leave another GUI or another set of frame listeners.
if playerGui:FindFirstChild("RaceHUD") then return end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "RaceHUD", false, 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui
local connections: {RBXScriptConnection} = {}
local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(connections, signal:Connect(callback))
end
gui.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
end)

local function frame(name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local item = Instance.new("Frame")
	item.Name, item.Size, item.Position, item.AnchorPoint = name, size, position, anchor
	item.BackgroundTransparency = 1
	item.Parent = gui
	return item
end
local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name, item.Size, item.Position = name, size, position
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.fromRGB(255, 255, 255)
	item.TextStrokeColor3 = Color3.fromRGB(20, 25, 34)
	item.TextStrokeTransparency = 0.15
	item.TextSize, item.Text = textSize, ""
	item.Parent = parent
	return item
end
local layout = Config.HUD
local timingPanel = frame("Timing", UDim2.fromOffset(330, 100), UDim2.new(1,-layout.Margin,0,layout.TopOffset), Vector2.new(1,0))
local timerLabel = label(timingPanel, "Timer", UDim2.fromOffset(330,46), UDim2.fromOffset(0,0), 32)
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
local lapLabel = label(timingPanel, "Lap", UDim2.fromOffset(330,40), UDim2.fromOffset(0,48), 28)
lapLabel.TextXAlignment = Enum.TextXAlignment.Right
local placementPanel = frame("Placement", UDim2.fromOffset(205,110), UDim2.new(0,layout.Margin,1,-layout.Margin), Vector2.new(0,1))
local positionLabel = label(placementPanel, "Position", UDim2.fromOffset(140,110), UDim2.fromOffset(0,0), 94)
positionLabel.TextXAlignment = Enum.TextXAlignment.Right
positionLabel.TextColor3 = Color3.fromRGB(255,211,70)
local suffixLabel = label(placementPanel, "Suffix", UDim2.fromOffset(60,54), UDim2.fromOffset(142,44), 38)
suffixLabel.TextXAlignment = Enum.TextXAlignment.Left
suffixLabel.TextColor3 = positionLabel.TextColor3
local statusLabel = label(gui, "Status", UDim2.new(0.7,0,0,54), UDim2.fromScale(0.5,0.15), 18)
statusLabel.AnchorPoint = Vector2.new(0.5,0)
statusLabel.TextWrapped = true

local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.AnchorPoint, startButton.Position = Vector2.new(0.5,0.5), UDim2.fromScale(0.5,0.5)
startButton.Size = UDim2.fromOffset(320,90)
startButton.BackgroundColor3, startButton.TextColor3 = Color3.fromRGB(30,115,210), Color3.fromRGB(255,255,255)
startButton.Font, startButton.TextSize, startButton.TextWrapped = Enum.Font.GothamBold, 24, true
startButton.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0,12), startButton
local readyRemote = ReplicatedStorage:WaitForChild("RaceReady") :: RemoteEvent
connect(startButton.Activated, function()
	if raceState.Value == "Waiting" and player:GetAttribute("LobbyReady") ~= true then
		readyRemote:FireServer(raceState:GetAttribute("RaceId"))
	end
end)
local countdownLabel = label(gui, "Countdown", UDim2.fromOffset(240,100), UDim2.fromScale(0.5,0.3), 72)
countdownLabel.AnchorPoint = Vector2.new(0.5,0.5)
local scales = {}
for _, element in {timingPanel, placementPanel, startButton, countdownLabel} do
	local scale = Instance.new("UIScale")
	scale.Parent = element
	table.insert(scales, scale)
end

-- Never predict GO: only the server's Racing state authorizes it.
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
-- COUNTDOWN_END: source-test boundary.

local snapshot: RaceTiming.Snapshot? = nil
local resetFeedbackUntil = 0
connect(player:GetAttributeChangedSignal("ResetStatus"), function()
	resetFeedbackUntil = Workspace:GetServerTimeNow() + layout.ResetFeedbackDuration
end)
connect((ReplicatedStorage:WaitForChild("RaceUpdated") :: RemoteEvent).OnClientEvent, function(value)
	if typeof(value) == "table" and typeof(value.raceId) == "number" then
		if not snapshot or value.raceId >= snapshot.raceId then snapshot = value end
	end
end)

local function render()
	local state = raceState.Value
	local raceId = raceState:GetAttribute("RaceId")
	local participant = player:GetAttribute("RaceParticipant") == true
	local current = snapshot
	local elapsed = if current and current.raceId == raceId and current.state == state
		then RaceTiming.getElapsed(current, Workspace:GetServerTimeNow(), player.UserId)
		else RaceTiming.getReplicatedElapsed(raceState, player)
	timerLabel.Text = "TIME  " .. Format.time(elapsed)
	local lap = player:GetAttribute("CurrentLap")
	local total = player:GetAttribute("TotalLaps")
	lapLabel.Text = string.format("LAP  %d/%d", if typeof(lap) == "number" then lap else 1,
		if typeof(total) == "number" and total > 0 then total else Config.TotalLaps)
	timingPanel.Visible = participant and state ~= "Waiting"
	local position = player:GetAttribute("RacePosition")
	local hasPosition = participant and player:GetAttribute("RacePositionId") == raceId
		and typeof(position) == "number" and position >= 1
	placementPanel.Visible = hasPosition and state ~= "Waiting"
	if hasPosition then
		positionLabel.Text = tostring(position)
		suffixLabel.Text = Format.ordinal(position :: number)
	end
	startButton.Visible = state == "Waiting"
	if startButton.Visible then
		local ready, members = 0, Players:GetPlayers()
		for _, member in members do if member:GetAttribute("LobbyReady") == true then ready += 1 end end
		local clicked = player:GetAttribute("LobbyReady") == true
		startButton.Active, startButton.AutoButtonColor = not clicked, not clicked
		startButton.Text = string.format("%s\n%d / %d players ready", if clicked then "Waiting for everyone..." else "Start", ready, #members)
	end
	local finished = player:GetAttribute("RaceFinishId") == raceId and player:GetAttribute("RaceFinishTime") ~= nil
	statusLabel.Text = if state == "Waiting" then "" elseif not participant then "Waiting for the next race"
		elseif finished then "FINISH" elseif state == "Results" then "Race ended — DNF"
		elseif state == "Loading" then (raceState:GetAttribute("Reason") :: string? or "Preparing race") else ""
	if state == "Racing" and participant and not finished and Workspace:GetServerTimeNow() < resetFeedbackUntil then
		statusLabel.Text = player:GetAttribute("ResetStatus") :: string? or ""
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		local factor = math.clamp(math.min(viewport.X/layout.ReferenceWidth, viewport.Y/layout.ReferenceHeight), layout.MinScale, layout.MaxScale)
		for _, scale in scales do scale.Scale = factor end
	end
	showCountdown()
end
connect(RunService.RenderStepped, render)
render()
