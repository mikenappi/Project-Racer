--!strict

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RaceHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10

local panel = Instance.new("TextLabel")
panel.Name = "CheckpointStatus"
panel.Size = UDim2.new(0, 360, 0, 90)
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

local function showCurrentCheckpoint()
	local current = player:GetAttribute("LastCheckpoint")
	local total = player:GetAttribute("CheckpointCount")
	local status = player:GetAttribute("ResetStatus")
	local progress = if typeof(current) == "number" and typeof(total) == "number"
		then string.format("Checkpoint %d / %d", current, total)
		else "Waiting for race / checkpoint setup"
	panel.Text = progress .. "\nR - return to checkpoint"
		.. (if typeof(status) == "string" then "\n" .. status else "")
end

for _, attribute in {"LastCheckpoint", "CheckpointCount", "ResetStatus"} do
	player:GetAttributeChangedSignal(attribute):Connect(showCurrentCheckpoint)
end
showCurrentCheckpoint()
gui.Parent = player:WaitForChild("PlayerGui")
